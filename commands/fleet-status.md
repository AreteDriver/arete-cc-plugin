---
description: Audit active Arete projects — git status, unpushed commits, test counts, CI state
---

Audit the current state of the Arete fleet. Report per-project:

- Git state: uncommitted changes, unpushed commits, current branch
- Test count and coverage (from project CLAUDE.md or memory)
- Last commit age
- Any pending CI failures

**Default scope**: the 8 most active projects from MEMORY.md project index (animus, BenchGoblins, Gatekeeper, monolith, Dossier, witness, anchormd, tiaid).

**If `$ARGUMENTS` is provided**: treat it as a filter (project name or comma-separated list) and only audit those.

Format as a punch list per project. Flag anything needing attention with `NEEDS ATTENTION:` prefix. Keep the report scannable, under 400 words. Don't perform any remediation — just report.
