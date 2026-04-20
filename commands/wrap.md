---
description: Short alias for /session-end — wrap up the current session
---

Invoke the `/session-end` skill to run the full session wrap-up workflow.

Skill location: `~/projects/ai-skills/workflows/session-end/SKILL.md`

Steps the skill performs:
1. Inventory git changes across all touched repos
2. Capture high-leverage decisions via `/decision-log`
3. Record gotchas and patterns to topic files or CC auto-memory
4. Sync Animus memory if relevant
5. Update `~/projects/notes/TODO.md`
6. Write `~/projects/notes/sessions/YYYY-MM-DD.md` (create if missing)
7. Suggest conventional commit message; wait for user confirmation before committing
8. Do NOT push without explicit approval

Respect any active code freezes (check `~/.claude/projects/-home-arete-projects/memory/project_code_freeze.md`).
