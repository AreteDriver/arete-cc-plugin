#!/bin/bash
# statusline.sh — Custom Claude Code status line.
# Shows: project | git branch + dirty marker | shift hour | freeze warning

cat > /dev/null 2>&1

cur_dir=$(pwd 2>/dev/null)
project=$(basename "$cur_dir")

git_info=""
if git -C "$cur_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cur_dir" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch="detached"
    dirty=""
    if ! git -C "$cur_dir" diff --quiet 2>/dev/null || ! git -C "$cur_dir" diff --cached --quiet 2>/dev/null; then
        dirty="*"
    fi
    git_info=" | git:${branch}${dirty}"
fi

hour=$(date +%H)
minute=$(date +%M)
shift_info=""
if [ "$hour" -ge 16 ]; then
    shift_hour=$((hour - 16))
    shift_info=" | shift:${shift_hour}h${minute}m"
elif [ "$hour" -lt 3 ]; then
    shift_hour=$((hour + 8))
    shift_info=" | shift:${shift_hour}h${minute}m"
fi

freeze=""
if [ -f /home/arete/.claude/projects/-home-arete-projects/memory/project_code_freeze.md ]; then
    freeze=" | FREEZE-CHECK"
fi

# Animus sync freshness — the 4h cron failed silently for 5 days (2026-05-28→06-02)
# because failures only appended to ~/.animus/sync.log, which nobody reads. Surface
# staleness here (renders every prompt). Warn only after >9h = 2+ missed cycles.
sync_warn=""
if [ -f "/home/arete/.animus/sync.FAILED" ]; then
    # OnFailure handler dropped a marker — last systemd run errored (cleared on next success)
    sync_warn=" | ⚠sync:FAIL"
fi
sync_state="/home/arete/.animus/sync_state.json"
if [ -z "$sync_warn" ] && [ -f "$sync_state" ] && command -v jq >/dev/null 2>&1; then
    last=$(jq -r '.last_sync // empty' "$sync_state" 2>/dev/null | cut -d. -f1)
    if [ -n "$last" ]; then
        last_epoch=$(date -d "$last" +%s 2>/dev/null)
        if [ -n "$last_epoch" ]; then
            age=$(( $(date +%s) - last_epoch ))
            if [ "$age" -gt 32400 ]; then
                if [ "$age" -ge 86400 ]; then age_str="$(( age / 86400 ))d"; else age_str="$(( age / 3600 ))h"; fi
                sync_warn=" | ⚠sync:${age_str}"
            fi
        fi
    fi
fi

printf '%s%s%s%s%s' "$project" "$git_info" "$shift_info" "$freeze" "$sync_warn"
