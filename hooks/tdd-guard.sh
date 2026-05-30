#!/usr/bin/env bash
# tdd-guard.sh — PreToolUse(Bash): block `git commit` unless tests have passed
# this session.
#
# The companion test-marker.sh (PostToolUse/Bash) creates /tmp/.claude-tests-passed
# after a passing test run, so the normal loop is: run tests (pass) -> commit allowed.
#
# Escape hatch: export TDD_GUARD_OFF=1 to bypass (e.g. docs-only commits). This
# guards against the marker logic ever becoming a hard lock on all commits.

set -uo pipefail

# Bypass when explicitly disabled.
if [ "${TDD_GUARD_OFF:-}" = "1" ]; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
MARKER="/tmp/.claude-tests-passed"

case "$COMMAND" in
    *"git commit"*)
        if [ ! -f "$MARKER" ]; then
            echo "TDD guard: no passing test run recorded this session — commit blocked." >&2
            echo "Run your test suite (a passing run is auto-detected), or bypass with: export TDD_GUARD_OFF=1" >&2
            exit 2
        fi
        ;;
esac

exit 0
