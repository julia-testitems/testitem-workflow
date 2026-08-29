# Changelog

## Unreleased

### Added

- **Versioned documentation now deploys for release tags — without a `DOCUMENTER_KEY`.**
  Two things conspired to keep release docs from ever being built: the recommended
  caller workflow had no `tags:` trigger, and the tags TagBot creates could not use one
  anyway — TagBot authenticates with the run's `GITHUB_TOKEN`, and events created with
  that token do not trigger further workflows. The classic fix is configuring an SSH
  deploy key per repository for TagBot; instead, the run that executes TagBot now
  snapshots the repository's tags around the TagBot step and a new `deploy-tagged-docs`
  job deploys the docs for each tag it created, overriding `GITHUB_REF` and
  `GITHUB_EVENT_NAME` so Documenter sees the tag-push build it expects. This works with
  existing caller workflow files as they are.
- The recommended caller trigger gains `tags: ['**']`, which covers the other route: a
  release tag pushed by hand deploys its docs via the ordinary `push` trigger. The
  trigger is deliberately *every* tag while the workflow only acts on `v*` tags
  (`deploy-tagged-docs` filters what TagBot created; `deploy-docs` checks
  `startsWith(github.ref_name, 'v')`), so future tag-driven features need changes only
  in this repository, not in every caller's workflow file.

### Changed

- Tag pushes run only docs deployment. Lint, format and the test matrix are gated to
  branch pushes — a tag names a commit that already went through CI on its branch, so
  re-running the whole matrix on it bought nothing but CI minutes.

### Fixed

- **GitHub's "Re-run failed jobs" now works.** A partial re-run keeps the same run id
  and re-runs only the failed jobs, and — unlike a full re-run — GitHub keeps the
  previous attempt's artifacts. Two things broke on that:

  The `report-results` job ended with an artifact cleanup step that had no `if:`, so it
  was skipped whenever the report action failed the job — which is every run with a test
  failure, i.e. exactly the runs worth re-running. The first attempt's artifacts
  therefore survived, and because artifact names are unique per run rather than per
  attempt, the re-run leg's upload collided with its own earlier copy and the leg went
  red at the upload step no matter what the tests did. Both uploads now set
  `overwrite: true`, so a re-run leg replaces its own result while legs that are not
  re-run keep theirs. That also removes an ambiguity in the report job's
  `merge-multiple` downloads, which could otherwise unzip a stale copy over a fresh one.

  When the report job *did* pass in the first attempt — an `allow-failure` leg going
  red, or a lint-only failure — cleanup ran and deleted every result. The re-run then
  reported on only the legs it had re-run, rendering a green, complete-looking summary
  over a partial matrix. The cleanup step is gone, and `retention-days` on the two
  uploads goes from 1 to 30 to cover GitHub's re-run window; result artifacts now stay
  listed on the run page instead of disappearing when it finishes.

- The `report-results` job now tells `julia-report-ci-results` which legs the run should
  have heard from, so a leg whose results never arrived is named in the summary — and
  fails the job when that leg had to pass — instead of being silently left out of it.
  Previously the report only noticed when *no* blocking leg reported at all.

- Re-runs no longer contend with fresh runs for the concurrency slot. The group had no
  run or attempt component, so re-running an older run could cancel, or be cancelled by,
  whatever was currently in flight for the same ref. First attempts keep the existing
  group and cancel-in-progress behaviour; a re-run gets a group of its own.

### Added

- New `test-log-level` option: the minimum log level for the code under test — your
  package and the test item bodies — as `debug`, `info`, `warn` or `error`. This is a
  separate axis from GitHub's "Enable debug logging" checkbox, which continues to
  control only the test infrastructure's own diagnostics. Unlike setting `JULIA_DEBUG`
  by hand it needs no module name and works on every platform.
- New `allow-failure` option: which matrix legs may fail without failing the run.
  Comma- or newline-separated globs, each matched against a leg's
  `<juliaup-channel>:<os>` identity; parts a pattern leaves out are filled in with
  wildcards, so `rc` covers every arch and runner and `*~x86` covers every 32-bit
  leg. Pass `none` to make every leg blocking. Like the other matrix options it has
  `draft-pr-`, `pr-`, `main-` and `manual-trigger-` overrides.

### Changed

- `include-rc-versions` now defaults to `true`, so a Julia release candidate that
  breaks a package surfaces before the release. RC legs are covered by the default
  `allow-failure` set, so their failures are reported with a warning in the CI
  report and do not fail the run. The leg itself still shows as failed in the
  GitHub checks list, which is how `continue-on-error` renders.
- Test results are now uploaded as `testitemresults-blocking-*` or
  `testitemresults-allowfail-*` artifacts, and `report-results` downloads the two
  into separate directories. The split is by artifact rather than by profile name
  because test definition errors carry no profile, and a leg that dies before
  writing results has none at all.

### Fixed

- **Codecov no longer reports 0% for every repository.** The workflow never actually
  asked for coverage: it forwarded the `coverage-lcov-path` input, whose default is
  empty, so `juliati` ran with `--code-coverage=none`. It then ran
  `julia-actions/julia-processcoverage`, which collects the `.cov` files
  `Pkg.test(coverage=true)` leaves behind — of which a test item run produces none. That
  action therefore found no coverage for any source file, assumed each had none, and
  wrote an `lcov.info` in which every line had zero hits. Codecov faithfully reported
  that as 0%, which is worse than reporting nothing: it looked like a real measurement,
  so nothing failed and nothing looked broken. `julia-processcoverage` is gone, the run
  now writes its own merged LCOV, and the upload is skipped entirely when no coverage
  file exists.

- The `run-tests` job now makes sure the General registry is present and usable
  before `julia-buildpkg` when the matrix leg runs Julia older than 1.5.
  `julia-buildpkg` installs a registry only from 1.5 on, and Pkg before that
  does not clone one on demand under `Pkg.build`, so such a leg resolved every
  dependency to "has no known versions". Because the depot is cached, a
  registry left half-written stayed broken for every later run of that leg,
  while legs whose cache held a complete one passed — which made a
  deterministic failure look intermittent. The step checks for the
  `Registry.toml` that old Pkg reads rather than for the folder alone, replaces
  anything else sitting in its place, and leaves a complete registry untouched.

### Added

- A `coverage` input (default `true`) that turns coverage collection on or off. Coverage
  is collected on every matrix leg capable of it; the instrumentation needs Julia 1.11 or
  newer, so an older leg is skipped with a `::notice` in the job log instead of uploading
  an empty report. `coverage-lcov-path` now only chooses *where* the file goes (default
  `lcov.info`), and setting it still switches coverage on by itself.

### Changed

- The `codecov_token` secret is no longer `required`. It is only used when coverage is
  collected, so a repository that sets `coverage: false` need not supply one. Callers
  that already pass it are unaffected.
- The `format` job now runs the [FormatApp](https://github.com/julia-vscode/FormatApp.jl)
  app in check-only mode (`juliaformat --check --diff .`): it fails when files
  are not formatted and prints the diff in the job log, but never modifies the
  repository. The previous reviewdog suggestion comments are gone. (The old job
  also contained a syntax error that made its format step fail whenever it ran
  at all.)
- A repository opts in by having a `JuliaFormat.toml` anywhere in its tree
  (previously: a `.JuliaFormatter.toml` at the repository root).
  **`.JuliaFormatter.toml` is no longer honored** — formatting configuration
  lives in `JuliaFormat.toml`, which the FormatApp app, the VS Code
  extension and the language server all share.
- The job now runs whenever lint and tests run — pushes, pull requests, and
  manual `LintAndTest` dispatches — instead of only on pull requests, matching
  standard practice (`cargo fmt --check` and `ruff format --check` run on
  every CI event).
- The job now uses the [julia-vscode/julia-format](https://github.com/julia-vscode/julia-format)
  action (which installs Julia and caches the depot itself) with
  `require-config: true`, so the `JuliaFormat.toml` opt-in gate lives in the
  action rather than in an `if:` condition here.
- The `run-tests` job now caches the Julia depot via `julia-actions/cache`.
  Because the cache is saved in a post-job step, it captures everything the job
  precompiled — the package's dependencies from `julia-buildpkg`, the test
  runner's own tooling, and the precompilation done by the test worker
  processes. Previously nothing in this job was cached, so every matrix leg
  rebuilt the depot from scratch. (The `julia-run-testitems` and
  `julia-report-ci-results` actions used to maintain private depots under
  `runner.tool_cache` with their own `actions/cache` steps; that machinery has
  been removed from the actions in favor of this single job-level cache.)
- The `report-results` job no longer needs a Julia installation at all:
  `julia-report-ci-results` is now a pure `node20` action that needs no
  checkout, cache, token, or GitHub API access.
- The `run-tests` job now surfaces failed test items as inline GitHub error
  annotations (via `julia-run-testitems`), in addition to the aggregated
  report.
- `include-alpha-versions` and `include-nightly-versions` now actually produce
  matrix entries: alpha was previously a declared no-op in
  `julia-compute-test-matrix`, and nightly never matched the juliaup version
  database (which does not list nightly channels). Matrix entries now also
  carry an `experimental: true/false` field for pre-release legs.

## v2

**Breaking.** Consumers must update their own `.github/workflows/juliaci.yml`, see Migration below.

### Removed

- The `compat-helper` job, and with it the need for a `schedule` trigger. Dependency updates move to Dependabot, which now supports Julia via `package-ecosystem: "julia"` and is configured per repository in `.github/dependabot.yml`. CompatHelper.jl upstream recommends this migration.

### Why the schedule trigger had to go

The `schedule` trigger was there only to drive `compat-helper`, and it carried a serious side effect. GitHub automatically disables a scheduled workflow in a public repository after 60 days with no repository activity — and that disables the *entire* workflow file, not just the scheduled trigger. The `push`, `pull_request` and `issue_comment` triggers stop firing too, pushing a commit does not re-enable it, and nothing in the repository indicates why runs stopped.

On a quiet package this meant lint, tests, documentation deployment and TagBot all died silently. Removing the cron removes that failure mode entirely.

### Migration

In each consumer repository's `.github/workflows/juliaci.yml`:

1. Point `uses:` at `@v2`.
2. Delete the `schedule: [{cron: '0 0 * * *'}]` line. This is required, not optional — leaving it in produces a nightly run in which no job matches.
3. Remove `CompatHelper` from the `workflow_dispatch` options, leaving `[DocDeploy,LintAndTest,TagBot]`.
4. Add a `.github/dependabot.yml` to take over dependency updates.

The `v1` branch is unchanged, so repositories still referencing `@v1` keep working as before — including the nightly CompatHelper run and its exposure to the 60-day disable — until they are migrated.

## v1

Initial reusable workflow: lint, format suggestions, test matrix computation, test item runs, results reporting, documentation deployment, TagBot, and a scheduled CompatHelper run.
