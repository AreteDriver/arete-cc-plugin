# arete-cc-plugin

Claude Code plugin packaging the **arete-cc-stack** skills, agents, and hooks
(`/doctor`, `/fleet-status`, `/animus-sync`, `/tiaid-check`, `/hackathon-triage`,
`/wrap`, and the `eve-frontier-researcher` agent). Canonical plugin layout:
manifest at `.claude-plugin/plugin.json`, hooks under `hooks/`.

## Committing here: tdd-guard is opt-in

The plugin ships a **`tdd-guard` PreToolUse hook** that protects repos which
*install* the plugin. As of 2026-05-30 it is **opt-in per repo**: it blocks
`git commit` only when the target repo carries a **`.tdd-guard`** sentinel file at
its root *and* no passing test run was recorded this session (the companion
`test-marker.sh` creates `/tmp/.claude-tests-passed` after a passing run).

**This repo does not carry `.tdd-guard`, so commits flow freely here** — no marker
dance, no env bypass. To enforce TDD in any repo (including this one):

```bash
touch .tdd-guard          # at the repo root — now commits require a passing test run
export TDD_GUARD_OFF=1    # hard override, anywhere
```

> The gitignored `.claude/settings.local.json` (`TDD_GUARD_OFF=1`) left over from
> the pre-opt-in era is now redundant — harmless to keep (it's a hard override) or
> delete.

> **Hook self-reference gotcha:** `audit-bash.sh` and `tdd-guard.sh` scan the
> **command string**, so a command whose *text* contains a real dangerous pattern
> (e.g. `… | sh`) or the literal `git commit` can trip the live (installed) hook
> even when you're only testing or discussing it. To exercise a hook, drive it from
> a script file and assemble trigger tokens at runtime. (The curl/wget pipe regex
> was tightened in #2 so benign cases like `… | grep dashboard` no longer block.)

## CI

`.github/workflows/validate.yml` runs a required `validate` status check on push
to `main`. Keep it green before/after commits here.
