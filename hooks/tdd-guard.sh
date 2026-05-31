#!/usr/bin/env bash
# tdd-guard.sh — PreToolUse(Bash): block `git commit` ONLY in repos that opt in.
#
# Opt-in model (changed 2026-05-30): TDD enforcement is per-repo, not global.
# A commit is blocked only when the target repo carries a `.tdd-guard` sentinel
# file at its root AND no passing test run was recorded this session. Repos
# without the sentinel commit freely — this avoids a marker dance across a
# multi-repo portfolio where most repos are docs / config / experiments.
#
#   Enforce TDD in a repo:   touch .tdd-guard   (at the repo root)
#   Hard override anywhere:  export TDD_GUARD_OFF=1
#
# The companion test-marker.sh (PostToolUse/Bash) creates /tmp/.claude-tests-passed
# after a passing test run, so in an opted-in repo the loop is:
# run tests (pass) -> commit allowed.

set -uo pipefail

# Hard override.
if [ "${TDD_GUARD_OFF:-}" = "1" ]; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Only commits are in scope.
case "$COMMAND" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

# Resolve the target repo. Honor an explicit `git -C <dir>`; otherwise use the
# session working directory. (`git -C` appears immediately after `git`, which
# avoids confusion with `git commit -C <commit>`.)
target_dir=$(printf '%s' "$COMMAND" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
target_dir="${target_dir:-$PWD}"
repo_root=$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null || true)

# Opt-in: no sentinel at the repo root -> no enforcement.
if [ -z "$repo_root" ] || [ ! -f "$repo_root/.tdd-guard" ]; then
    exit 0
fi

MARKER="/tmp/.claude-tests-passed"
if [ ! -f "$MARKER" ]; then
    echo "TDD guard: '$repo_root' opts into TDD (.tdd-guard present) but no passing test run was recorded this session — commit blocked." >&2
    echo "Run your test suite (a passing run is auto-detected), or bypass with: export TDD_GUARD_OFF=1" >&2
    exit 2
fi

exit 0
