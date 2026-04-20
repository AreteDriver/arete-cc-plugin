---
description: Sanity-check the Claude Code automation stack — hooks, commands, agents, MCP servers, statusline, permissions
---

Audit the health of the Claude Code automation stack on this machine and report PASS / FAIL per check. Do NOT attempt any fixes — report only.

## Checks to run

### 1. settings.json validity

- `jq -e . ~/.claude/settings.json` → must exit 0
- `jq -e '.hooks' ~/.claude/settings.json` → must not be null
- `jq -e '.disableAllHooks' ~/.claude/settings.json` → must be null or false (flag `SILENT-DISABLE` if true — hooks won't fire)

### 2. Hook scripts

For each entry in `~/.claude/settings.json` `.hooks.*[].hooks[].command`:

- File exists
- File is executable (`test -x`)
- Quick smoke test: pipe `{}` and confirm exit code is 0 (or expected non-zero for validators)

Also pipe-test the critical hooks with matching synthesized payloads:
- `audit-bash.sh` with a safe bash payload → exit 0
- `no-force-push.sh` with a force-push-to-main payload → exit 2 (blocks correctly)
- `protected-paths.sh` with an SSH key path payload → exit 2
- `detect-secrets.py` with a file-write payload containing a fake GitHub token (construct the token string at runtime via concatenation so the test source doesn't itself contain a literal token that trips the hook on this slash-command file) → exits with deny JSON
- `wrap-it-up.sh` with `{"hook_event_name":"UserPromptSubmit","prompt":"wrap it up"}` → outputs JSON containing "session-end"

### 3. Custom slash commands

For each `.md` file in `~/.claude/commands/`:

- Valid YAML frontmatter (must have `description:` field)
- No absolute paths to files that don't exist

### 4. Custom subagents

For each `.md` file in `~/.claude/agents/`:

- Valid YAML frontmatter with `name`, `description`, `tools`, `model` fields
- `name` matches filename (kebab-case)
- Tools list contains only valid Claude Code tool names

### 5. Statusline

- `~/.claude/statusline.sh` exists and is executable
- Runs in under 500ms with `{}` on stdin
- Output is non-empty plain text (no ANSI escape codes that might break the UI)

### 6. MCP servers

Parse `~/.claude/mcp.json`:

- Valid JSON
- For each server, verify the `command` path exists
- For local Python servers, verify the venv path exists
- Report connection state via `/mcp` (if available) or skip with NOTE

### 7. Permissions

- `jq '.permissions.allow | length' ~/.claude/settings.json` → report count
- Confirm no allow rules grant arbitrary code execution (scan for `python*`, `node`, `npx`, `bun`, `sh`, `eval`, `*api *`, `curl *`)

### 8. Log hygiene

- `~/.claude/logs/tool-usage.jsonl` size — flag if over 10 MiB (should auto-rotate)
- `~/.claude/audit-log.txt` size — flag if over 50 MiB

### 9. Reference doc staleness

- `~/projects/notes/topics/claude-code-automation.md` exists
- Hook count in the doc matches actual hook count in settings.json (loose string match on the table)

## Output Format

```
CLAUDE CODE DOCTOR — <timestamp>
================================

[PASS] settings.json valid
[PASS] hooks: 11 wired across 5 events
[WARN] tool-usage.jsonl at 8.3 MiB (approaching 10 MiB rotation threshold)
[FAIL] mcp:herald — venv path /home/arete/projects/Herald/.venv does not exist
...

SUMMARY: 15 pass, 1 warn, 1 fail
NEXT ACTIONS:
  - fix herald venv
  - monitor tool-usage.jsonl
```

Exit early if any FAIL is security-critical (disableAllHooks=true, unexecutable hook, protected path bypass). Everything else is informational.
