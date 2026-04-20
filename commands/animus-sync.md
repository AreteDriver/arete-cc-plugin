---
description: Manually trigger Animus sync — push Claude Code memory to ChromaDB
---

Manually trigger the Animus sync tool to push Claude Code auto-memory files to the Animus ChromaDB.

Script path: `~/projects/animus/tools/animus_sync.py`

Steps:
1. Run the sync script with `python3 ~/projects/animus/tools/animus_sync.py` (activate venv first if needed: `source ~/projects/animus/packages/core/.venv/bin/activate`)
2. Report results: memories synced, duplicates skipped, any errors
3. If sync fails, check `~/.animus/sync_state.json` for the last successful state

Context: scheduled cron runs every 4h. Use this command only when you want to force a sync (e.g., after adding several memory files and wanting Animus context updated before proceeding).

If `$ARGUMENTS` is `--dry-run`, pass that flag to the script.
