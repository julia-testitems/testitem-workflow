#!/usr/bin/env bash
# Per-leg CI status across the stack.
#
# Run-level conclusions lie: pre-release legs are continue-on-error, so a run stays green
# with a dead rc leg in it. This reports the individual matrix jobs instead, and flags a
# missing or failed compute-test-matrix job — which is how a whole Julia version can vanish
# from CI without anything going red.
#
#   ./ci-status.sh                 # rc legs
#   ./ci-status.sh 'rc~|beta~'     # rc and beta legs
#   ./ci-status.sh --dispatch      # trigger LintAndTest on every repo's main, then exit
set -uo pipefail

REPOS=(
  julia-vscode/TestItems.jl
  julia-vscode/CSTParser.jl
  julia-vscode/JSONRPC.jl
  julia-vscode/Salsa.jl
  julia-testitems/TestItemDetection.jl
  julia-testitems/TestItemRunner.jl
  julia-vscode/JuliaWorkspaces.jl
  julia-vscode/TestItemControllers.jl
  julia-vscode/LanguageServer.jl
  julia-vscode/FormatApp.jl
  julia-vscode/LintApp.jl
  julia-vscode/JuliaSessionControllers.jl
  julia-vscode/DebugAdapter.jl
  julia-testitems/TestItemApp.jl
  julia-testitems/TestItemRuns.jl
  julia-vscode/DevREPL.jl
  julia-vscode/JuliaMCP.jl
  julia-testitems/TestItemExamplePackage.jl
)

if [[ "${1:-}" == "--dispatch" ]]; then
  for repo in "${REPOS[@]}"; do
    if gh workflow run juliaci.yml -R "$repo" --ref main -f feature=LintAndTest 2>/dev/null; then
      printf 'dispatched  %s\n' "$repo"
    else
      printf 'FAILED      %s\n' "$repo"
    fi
  done
  exit 0
fi

pattern="${1:-rc~}"

for repo in "${REPOS[@]}"; do
  # Newest run that actually ran test legs — tagbot-only and all-skipped runs carry none.
  run=""
  for candidate in $(gh run list -R "$repo" --workflow juliaci.yml --branch main --limit 10 \
                       --json databaseId --jq '.[].databaseId' 2>/dev/null); do
    jobs=$(gh api "repos/$repo/actions/runs/$candidate/jobs" --paginate \
             --jq '.jobs[] | [.name, (.conclusion // "pending"), .html_url] | @tsv' 2>/dev/null)
    # A run whose compute-test-matrix was skipped still has run-tests jobs, but they are
    # themselves skipped and tell us nothing about Julia 1.13.
    if awk -F'	' '/run-tests/ && $2 != "skipped" {found=1} END {exit !found}' <<<"$jobs"; then
      run=$candidate
      break
    fi
  done

  if [[ -z "$run" ]]; then
    printf '%-42s no run with test legs\n' "$repo"
    continue
  fi

  created=$(gh run view "$run" -R "$repo" --json createdAt --jq '.createdAt' 2>/dev/null)
  matrix=$(awk -F'\t' '/compute-test-matrix/ {print $2}' <<<"$jobs")
  legs=$(grep -Ec "$pattern" <<<"$jobs")
  bad=$(grep -E "$pattern" <<<"$jobs" | awk -F'\t' '$2!="success"' | wc -l)

  printf '%-42s %s  matrix=%-8s legs=%-3s bad=%s\n' \
    "$repo" "${created%T*}" "${matrix:-MISSING}" "$legs" "$bad"

  grep -E "$pattern" <<<"$jobs" | awk -F'\t' '$2!="success" {printf "    %-9s %-58s %s\n", $2, $1, $3}'
  [[ "${matrix:-MISSING}" == "success" ]] || printf '    compute-test-matrix did not succeed — the matrix itself is the bug\n'
done
