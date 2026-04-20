#!/bin/bash
# Hook: Tool Usage Logger
# Event: PostToolUse
# Matcher: *
# Purpose: Logs all tool invocations for audit and analysis
#
# Install in .claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [
#       { "matcher": "*", "command": "./hooks/tool-logger.sh" }
#     ]
#   }
# }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
PROJECT=$(echo "$INPUT" | jq -r '.project_dir // "unknown"')

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="$LOG_DIR/tool-usage.jsonl"
MAX_SIZE=10485760   # 10 MiB — rotate when exceeded
KEEP=3              # keep N rotated files

mkdir -p "$LOG_DIR"

# Rotate if over size threshold
if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_SIZE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date -u +%Y%m%dT%H%M%SZ)"
        # shellcheck disable=SC2012
        ls -1t "${LOG_FILE}".* 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f
    fi
fi

echo "{\"timestamp\":\"$TIMESTAMP\",\"tool\":\"$TOOL\",\"session\":\"$SESSION\",\"project\":\"$PROJECT\"}" \
    >> "$LOG_FILE"

exit 0
