# arete-cc-stack

ARETE's Claude Code automation stack, packaged for portability.

Single-file reference for the underlying design lives at
`~/projects/notes/topics/claude-code-automation.md` in ARETE's knowledge base.

---

## What's in the box

### 8 security & audit hooks

| Event | Matcher | Hook | Purpose |
|---|---|---|---|
| PreToolUse | Bash | audit-bash.sh | Log + block dangerous bash (destructive removes, fork bombs, reverse shells) |
| PreToolUse | Bash | no-force-push.sh | Block `git push --force` to main/master/production/release |
| PreToolUse | Bash | detect-secrets.py | Block bash commands with embedded credentials |
| PreToolUse | Write\|Edit | protected-paths.sh | Block writes to `.git/`, env files, `.ssh/`, `.gnupg/`, password-store |
| PreToolUse | Write\|Edit | validate-files.py | Block writes to protected files (path-component matching, not substring) |
| PreToolUse | Write\|Edit | detect-secrets.py | Block file writes containing credentials |
| PostToolUse | * | tool-logger.sh | Log tool invocations; rotates at 10 MiB, keeps 3 backups |
| SessionStart/End | — | session-logger.sh | Audit trail for session boundaries |
| UserPromptSubmit | — | detect-secrets.py | Block prompts with critical secrets |
| UserPromptSubmit | — | wrap-it-up.sh | Inject `/session-end` context when user says "wrap it up" |

### 6 custom slash commands

- `/fleet-status [filter]` — audit 30+ project portfolio (git state, unpushed, test deltas)
- `/tiaid-check [area]` — TIAID consulting pipeline status
- `/hackathon-triage [project]` — rank active hackathon submissions by urgency
- `/animus-sync [--dry-run]` — manually trigger Animus ChromaDB sync
- `/wrap` — alias for `/session-end`
- `/doctor` — sanity-check the entire automation stack (hooks, commands, agents, MCP, permissions)

### 3 domain subagents

- `fleet-auditor` — portfolio-wide git/test/CI audit, read-only
- `eve-frontier-researcher` — EVE Frontier (Stillness testnet) Sui GraphQL, package IDs, API quirks
- `tiaid-content-analyst` — Human Stack article review, voice scoring, pipeline discipline

### Custom statusline

`<project> | git:<branch>[*] | shift:<Nh>Nm | FREEZE-CHECK`

Swing-shift aware (4PM–2:30AM window).

### Global permission allowlist

6 read-only Bash allow rules so common audit commands (`ruff check`, `anchormd audit`, `flyctl logs`/`status`, `npm audit`/`ls`) don't prompt.

---

## Installation

### Option A — git submodule (recommended, lets you pull updates)

```bash
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/AreteDriver/arete-cc-plugin arete-cc-stack
```

### Option B — direct clone

```bash
git clone https://github.com/AreteDriver/arete-cc-plugin.git /tmp/arete-cc-stack
mkdir -p ~/.claude/plugins
mv /tmp/arete-cc-stack ~/.claude/plugins/arete-cc-stack
```

### Option C — symlink a development copy

```bash
ln -s /path/to/arete-cc-plugin ~/.claude/plugins/arete-cc-stack
```

After install, open `/plugin` in Claude Code and enable `arete-cc-stack`, then restart Claude Code or run `/hooks` to pick up the hook config.

---

## Requirements

- Claude Code v2.1.0 or later
- `jq` installed and on `PATH` (hooks use `jq` to parse event JSON)
- `python3` for `detect-secrets.py` and `validate-files.py`
- `git` for most commands and hooks
- Unix-like environment (Linux / macOS). Not tested on Windows/WSL.

Optional integrations the slash commands reference:
- `anchormd` CLI (for `/fleet-status` checks and the `anchormd audit` permission rule)
- `flyctl` (for Fly.io log/status permission rules and TIAID-side infra checks)
- `ruff` (for the `ruff check` permission rule)
- Animus repo at `~/projects/animus/` for `/animus-sync`
- ARETE notes repo at `~/projects/notes/` for session logging + memory index

Slash commands will degrade gracefully if a referenced project path is missing — they report `NEEDS ATTENTION:` rather than crashing.

---

## Portability notes

### `${CLAUDE_PLUGIN_ROOT}`

All hook paths in `plugin.json` use the `${CLAUDE_PLUGIN_ROOT}` variable. Claude Code expands this to the plugin's install directory at hook registration time, so the plugin works regardless of where it's cloned.

### Project-specific subagents

Two of the three subagents (`eve-frontier-researcher`, `tiaid-content-analyst`) reference paths under `~/projects/` that are specific to the ARETE workstation. If you fork this plugin, replace those path references with your own project layout or drop the subagents that don't apply.

### Memory file reference

The `wrap-it-up.sh` hook instructs the model to write to `~/projects/notes/sessions/YYYY-MM-DD.md`. If you don't have an ARETE-style notes repo, either:
- Fork the hook and change the path, or
- Let the first invocation fail gracefully and create whatever path you prefer.

### `/animus-sync` assumption

The `/animus-sync` command assumes `~/projects/animus/tools/animus_sync.py` exists. If you don't run Animus, remove the command from `plugin.json`.

---

## Not included

- `tdd-guard.sh` (blocks `git commit` without tests — too aggressive for a multi-project portfolio; enable per-project if needed)
- `pre-commit-format.sh` (it's a git hook, not a Claude Code hook — install via `ln -sf` into a repo's `.git/hooks/pre-commit`)
- MCP server configs — MCP lives in your `~/.claude/mcp.json`, not in a plugin

---

## Uninstall

```bash
rm -rf ~/.claude/plugins/arete-cc-stack
```

Or via `/plugin` → disable → uninstall.

Your `~/.claude/settings.json` permissions, statusline, and hooks that were contributed by this plugin will unload automatically on Claude Code restart.

---

## Versioning

Semantic versioning. Breaking changes to hook interface or slash command behavior bump the major. See `CHANGELOG.md` (not yet created — tag releases with `git tag vX.Y.Z`).

## License

MIT — see `LICENSE`.
