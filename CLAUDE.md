# arete-cc-plugin

Claude Code plugin packaging the **arete-cc-stack** skills, agents, and hooks
(`/doctor`, `/fleet-status`, `/animus-sync`, `/tiaid-check`, `/hackathon-triage`,
`/wrap`, and the `eve-frontier-researcher` agent). Canonical plugin layout:
manifest at `.claude-plugin/plugin.json`, hooks under `hooks/`.

## Committing here: the tdd-guard caveat

This repo ships a **`tdd-guard` PreToolUse hook** (`hooks/tdd-guard.sh`). Its real
job is to protect repos that *install* the plugin — but because the hook lives
here, it also fires on commits in this source repo. It blocks any command
containing `git commit` unless one of these is true:

1. **`TDD_GUARD_OFF=1` is in the session environment**, or
2. the marker file **`/tmp/.claude-tests-passed`** exists (created by the companion
   `hooks/test-marker.sh` after a passing test run this session).

### How the bypass is wired (and its one limitation)

`TDD_GUARD_OFF=1` is set in **`.claude/settings.local.json`** (gitignored — a
per-developer choice, deliberately *not* committed so it never ships to other
clones). Verified behavior (2026-05-30):

- A Claude Code session **launched from inside this repo** loads that env block —
  `printenv TDD_GUARD_OFF` → `1`, so `git commit` flows with no extra steps.
- It is **repo-scoped, not global**: a session rooted elsewhere (e.g.
  `~/projects`, or any other repo) does **not** get the var — `printenv` → empty.

**The gotcha:** if you're committing to this repo from a session rooted somewhere
else (common when working across the fleet from `~/projects`), the env var is
absent and `tdd-guard` will block the commit. Two ways through:

- **Preferred:** start the session with `cd ~/projects/arete-cc-plugin` (or open it
  as the workspace) so the local settings load.
- **One-off, from an outside session:** create the marker *before* the commit, in
  a separate command (the hook scans the command string pre-execution, so the
  marker must already exist), then remove it after so the guard stays honest for
  the next code commit:
  ```bash
  touch /tmp/.claude-tests-passed          # separate call — must NOT contain the commit
  # ... then in a later call: git commit ...
  command rm -f /tmp/.claude-tests-passed  # restore the guard
  ```

> Note: a command whose **text** contains the literal `git commit` (even in a
> comment or a test payload) trips the guard. To test/inspect the hook without
> tripping it, assemble that substring at runtime so it never appears literally.

### Local-only vs committed (why settings.local.json)

A flag that disables a safety net should not be a shared, committed default.
Committing `TDD_GUARD_OFF=1` to `.claude/settings.json` would turn the guard off
for everyone who clones this repo for development — the opposite of dogfooding it.
Keeping it in gitignored `.claude/settings.local.json` makes the bypass a
deliberate per-developer choice. Tradeoff: it doesn't follow you to a fresh clone
or a second machine — re-create it there if needed:
```bash
mkdir -p .claude && printf '{\n  "env": { "TDD_GUARD_OFF": "1" }\n}\n' > .claude/settings.local.json
```

## CI

`.github/workflows/validate.yml` runs a required `validate` status check on push
to `main`. Keep it green before/after commits here.
