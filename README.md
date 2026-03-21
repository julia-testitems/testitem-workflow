# Test item reusable workflow

This repository provides a reusable GitHub Workflow that lints, runs test items, deploys documentation, checks for compatability updates and creates tags for Julia packages. It only works with packages that use the test item framework.

## PRERELEASE

This is very experimental prerelease software. It might break, not work etc. I will update this notice once it is ready for everyone to use.

## Getting started

Add the following file as `.github/workflows/juliaci.yml` to the repository of your package:

```yml
name: Julia CI

on:
  push: {branches: [main,master]}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  schedule: [{cron: '0 0 * * *'}]
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [CompatHelper,DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v1
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
- `include-rc-versions` (`true` or `false`, default `false`): run tests on the latest release candidate Julia version.
- `include-beta-versions` (`true` or `false`, default `false`): run tests on the latest beta Julia version.
- `include-alpha-versions` (`true` or `false`, default `false`): run tests on the latest alpha Julia version.
- `include-nightly-versions` (`true` or `false`, default `false`): run tests on the latest nightly Julia version.
- `include-windows-x64` (`true` or `false`, default `true`): run tests on Windows x64.
- `include-windows-x86` (`true` or `false`, default `true`): run tests on Windows x86.
- `include-linux-x64` (`true` or `false`, default `true`): run tests on Linux x64.
- `include-linux-x86` (`true` or `false`, default `true`): run tests on Linux x86.
- `include-macos-x64` (`true` or `false`, default `true`): run tests on MacOS x64.
- `include-macos-aarch64` (`true` or `false`, default `true`): run tests on MacOS aarch64.
- `env` (JSON string): By passing a JSON string one can set environment variables for the Julia process that executes test items. For example `env: '{"FOO": "BAR"}'` would set an environment variable named `FOO` to the value `BAR`.
- `filter` (string, default `""`): A Julia expression used to filter which test items are run. The expression can reference the variables `name` (test item name), `tags` (vector of `Symbol` tags), `filename` (file path), and `package_name`. It should evaluate to `true` to include a test item and `false` to exclude it. The working directory is set to the repository root when the filter is evaluated. For example, `filter: '!(:slow in tags)'` would skip all test items tagged with `:slow`.
- `github_job_prep_script`: Path to a Julia file that is run once on each GitHub worker before tests are executed.
- `testitem-timeout` (number, default `1200`): Per test item timeout in seconds. If a single test item takes longer than this duration, it will be terminated and reported as errored. The default is 1200 seconds (20 minutes).

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
  push: {branches: [main,master]}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  schedule: [{cron: '0 0 * * *'}]
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [CompatHelper,DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v1
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

In the following example tests are run on release candidate versions if they are available:

```yml
name: Julia CI

on:
  push: {branches: [main,master]}
  pull_request: {types: [opened,synchronize,reopened,ready_for_review,converted_to_draft]}
  issue_comment: {types: [created]}
  schedule: [{cron: '0 0 * * *'}]
  workflow_dispatch: {inputs: {feature: {type: choice, description: What to run, options: [CompatHelper,DocDeploy,LintAndTest,TagBot]}}}

jobs:
  julia-ci:
    uses: julia-testitems/testitem-workflow/.github/workflows/juliaci.yml@v1
    with:
      include-rc-versions: true
    permissions: write-all
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```
