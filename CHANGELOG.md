# Changelog

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
