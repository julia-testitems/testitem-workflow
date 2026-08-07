# Changelog

## Unreleased

### Changed

- The `format` job now runs the [JuliaFormatApp](https://github.com/julia-vscode/JuliaFormatApp.jl)
  app in check-only mode (`juliaformat --check --diff .`): it fails when files
  are not formatted and prints the diff in the job log, but never modifies the
  repository. The previous reviewdog suggestion comments are gone. (The old job
  also contained a syntax error that made its format step fail whenever it ran
  at all.)
- A repository opts in by having a `JuliaFormat.toml` anywhere in its tree
  (previously: a `.JuliaFormatter.toml` at the repository root).
  **`.JuliaFormatter.toml` is no longer honored** — formatting configuration
  lives in `JuliaFormat.toml`, which the JuliaFormatApp app, the VS Code
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
