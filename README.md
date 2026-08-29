# Test item reusable workflow

This repository provides a reusable GitHub Workflow that lints, checks formatting, runs test items, deploys documentation and creates tags for Julia packages. It only works with packages that use the test item framework.

## Getting started

Add the following file as `.github/workflows/juliaci.yml` to the repository of your package:

```yml
name: Julia CI

on:
  push: {branches: [main,master], tags: ['**']}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v2
    permissions: write-all
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```

## Configuration

The `juliaci.yml` workflow accepts a number of configuration options that control on what Julia versions tests will be run. The following options are supported:
- `include-release-versions` (`true` or `false`, default `true`): run tests on the latest stable Julia version.
- `include-lts-versions` (`true` or `false`, default `true`): run tests on the latest long-term support Julia version.
- `include-all-compatible-minor-versions` (`true` or `false`, default `false`): run tests on all Julia minor versions that are compatible with the `[compat]` section in the package's `Project.toml`.
- `include-smallest-compatible-minor-versions` (`true` or `false`, default `true`): run tests on the smallest Julia minor versions that is compatible with the `[compat]` section in the package's `Project.toml`.
- `include-rc-versions` (`true` or `false`, default `true`): run tests on the latest release candidate Julia version. Release candidates are allowed to fail by default, so a broken RC shows up in the report without failing CI — see `allow-failure` below.
- `include-beta-versions` (`true` or `false`, default `false`): run tests on the latest beta Julia version.
- `include-alpha-versions` (`true` or `false`, default `false`): run tests on the latest alpha Julia version.
- `include-nightly-versions` (`true` or `false`, default `false`): run tests on the latest nightly Julia version.
- `include-windows-x64` (`true` or `false`, default `true`): run tests on Windows x64.
- `include-windows-x86` (`true` or `false`, default `true`): run tests on Windows x86.
- `include-linux-x64` (`true` or `false`, default `true`): run tests on Linux x64.
- `include-linux-x86` (`true` or `false`, default `true`): run tests on Linux x86.
- `include-macos-x64` (`true` or `false`, default `true`): run tests on MacOS x64.
- `include-macos-aarch64` (`true` or `false`, default `true`): run tests on MacOS aarch64.
- `allow-failure` (string, default `"rc,beta,alpha,nightly"`): which matrix legs may fail without failing the run. Comma- or newline-separated globs, each matched against the leg's `<juliaup-channel>:<os>` identity (e.g. `rc~x64:ubuntu-latest`); parts a pattern leaves out are filled in with wildcards, so `rc` covers every arch and runner and `*~x86` covers every 32-bit leg. Failures on these legs are reported with a ⚠️ in the CI report but do not fail the run — note that the leg itself is still shown as failed in the GitHub checks list. Pass `none` to make every leg blocking.
- `env` (JSON string): By passing a JSON string one can set environment variables for the Julia process that executes test items. For example `env: '{"FOO": "BAR"}'` would set an environment variable named `FOO` to the value `BAR`.
- `filter` (string, default `""`): A Julia expression used to filter which test items are run. The expression can reference the variables `name` (test item name), `tags` (vector of `Symbol` tags), `filename` (file path), and `package_name`. It should evaluate to `true` to include a test item and `false` to exclude it. The working directory is set to the repository root when the filter is evaluated. For example, `filter: '!(:slow in tags)'` would skip all test items tagged with `:slow`.
- `github_job_prep_script`: Path to a Julia file that is run once on each GitHub worker before tests are executed.
- `testitem-timeout` (string, default `""`): Per test item timeout in seconds. If a single test item takes longer than this duration, it is terminated and reported as errored. Unset by default: a test item can legitimately take arbitrarily long, and a timeout that fires is unrecoverable, so this workflow does not impose a deadline you did not ask for. Set it when you want a hang diagnosed — on a timeout the worker dumps task backtraces and a CPU profile into the item's output, which you get no other way. Without one, a hung item runs until the job hits its own `timeout-minutes` (GitHub default: 360 minutes) and nothing identifies which item hung.
- `junit-path` (string, default `""`): Path to write the test results as JUnit XML. Most CI test reporters consume this format; the results JSON is richer but far less portable.
- `coverage` (`true` or `false`, default `true`): Collect line coverage and upload it to Codecov. Coverage is collected on every matrix leg that can do it — the instrumentation requires Julia 1.11 or newer, so older legs are skipped with a notice in the job log rather than uploading an empty report. Set this to `false` to switch coverage off entirely, in which case no `codecov_token` is needed.
- `coverage-lcov-path` (string, default `""`): Where to write the run's merged coverage in LCOV format. Empty means `lcov.info` in the workspace root, which is what gets uploaded to Codecov. Setting it explicitly also switches coverage on, even with `coverage: false`.
- `output-mode` (string, default `""`): Which captured test item output to echo into the job log — `issues` (only failing items), `all`, or `none`. Captured output is always present in the results JSON regardless. Empty leaves the `juliati` default.
- `threads` (string, default `""`): Value for the test processes' `--threads`, for example `4`, `auto`, or `2,1`. Empty leaves Julia's default.
- `gc-between-testitems` (string, default `""`): `true` or `false` to force a full garbage collection between test items. Empty leaves the default, which is on whenever more than one test process is used.
- `memory-threshold` (string, default `""`): Recycle a test process once system memory use exceeds this fraction, between 0 and 1. Off by default. Experimental.
- `test-log-level` (string, default `""`): Minimum log level for the code under test — your package and the test item bodies: `debug`, `info`, `warn` or `error`. Empty leaves the `juliati` default (`info`). See [Debug logging](#debug-logging).
- `schedule` (string, default `""`): How test items are distributed over test processes — `duration` orders by measured duration, past failures and warm setups; `contiguous` restores the older chunk-by-position behaviour. Set this to `contiguous` to rule the scheduler out when diagnosing a run.

These describe how the test processes behave rather than how much gets tested, so unlike `filter` and `testitem-timeout` they have no per-trigger (`pr-`, `main-`, …) overrides.

The `codecov_token` secret is only used when coverage is collected; a repository that sets `coverage: false` can leave it out.

## Versioned documentation

Documenter deploys the documentation for a release from a build of its `v*` tag. Two routes lead there, and both work without any extra secret:

- **Tags created by TagBot** (the normal registry release flow): tags pushed with the workflow's `GITHUB_TOKEN` never trigger another workflow run, so the `tags:` trigger does not fire for them. Instead, the same run that executes TagBot detects the tags it created and deploys their docs directly — no `DOCUMENTER_KEY` deploy key needs to be configured.
- **Tags pushed by hand**: the `tags: ['**']` trigger in the workflow file above fires, and the docs for the tag are deployed. A tag push runs *only* the docs job — the tagged commit already went through lint and tests on its branch, so the test matrix is not repeated.

The trigger is deliberately every tag (`'**'`) while the workflow itself only acts on tags starting with `v`: future tag-driven features can then be added to the reusable workflow without every consumer having to touch their workflow file again. If a tag's docs deployment ever needs to be re-run by hand, trigger the `DocDeploy` feature via workflow dispatch and select the tag as the ref.

## Debug logging

Two different things get called "debug logging" for a test run, and the workflow keeps them apart:

| I want to see… | Use | What it does |
| --- | --- | --- |
| my package's own `@debug` output | `test-log-level: debug` | Raises the log level applied around each test item, so `@debug` from your package and from your test item bodies reaches the job log. Needs no module name and works on every platform. |
| why the test run itself misbehaved | GitHub's **Enable debug logging** checkbox | Diagnostics from the test infrastructure — process launches, scheduling, timeouts. |

```yml
jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v2
    with:
      test-log-level: debug
    permissions: write-all
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```

The checkbox deliberately does **not** raise the level of the code under test: `ACTIONS_STEP_DEBUG` is documented as being about diagnostics from the tooling, and a debug-level run of a large suite would bury the very infrastructure diagnostics the checkbox was ticked to reveal.

To scope debug output to particular modules instead of raising the level for everything, `JULIA_DEBUG` still works via the `env` input: `env: '{"JULIA_DEBUG": "MyPkg"}'`.

## Formatting check

The workflow includes a check-only formatting job powered by the
[FormatApp](https://github.com/julia-vscode/FormatApp.jl) app. A repository
opts in by having a `JuliaFormat.toml` configuration file anywhere in its tree —
without one, the job does nothing. When enabled, the job runs
`juliaformat --check --diff .` whenever lint and tests run (pushes, pull
requests, and manual `LintAndTest` dispatches): it never modifies the
repository, fails if any file is not formatted, and prints the diff in the job
log.

To fix a failure locally, install the app once and format:

```
pkg> app add FormatApp

$ juliaformat .
```

Note that JuliaFormatter.jl's `.JuliaFormatter.toml` is **not** honored — the
formatting configuration lives in `JuliaFormat.toml`.

### Trigger-specific overrides

Any of the above options can be overridden for a specific trigger scenario by prefixing the input name with one of the following:

- `draft-pr-` — run was triggered by a pull request in draft state
- `pr-` — run was triggered by a non-draft pull request
- `main-` — run was triggered by a push to main or master
- `manual-trigger-` — run was triggered via workflow dispatch

Override inputs are strings (`true`/`false` for boolean options). If an override is not set, the base input value is used. Note that `draft-pr-` and `pr-` are mutually exclusive — a draft PR run only picks up `draft-pr-` overrides, not `pr-` overrides.

In the following example, draft PRs run only on the release version and Linux x64 to get a quick signal, while full testing applies to all other triggers:

```yml
name: Julia CI

on:
  push: {branches: [main,master], tags: ['**']}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v2
    with:
      draft-pr-include-lts-versions: false
      draft-pr-include-windows-x64: false
      draft-pr-include-windows-x86: false
      draft-pr-include-linux-x86: false
      draft-pr-include-macos-x64: false
      draft-pr-include-macos-aarch64: false
    permissions: write-all
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```

Release candidates are in the matrix by default and are allowed to fail. In the following example they are made blocking instead, so a failure on an RC fails CI:

```yml
name: Julia CI

on:
  push: {branches: [main,master], tags: ['**']}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v2
    with:
      allow-failure: none
    permissions: write-all
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```
