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

printf '%s%s%s%s' "$project" "$git_info" "$shift_info" "$freeze"
