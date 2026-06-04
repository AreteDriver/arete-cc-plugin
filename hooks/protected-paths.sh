#!/bin/bash
# Hook: Protected Paths
# Event: PreToolUse
# Matcher: Read|Write|Edit|MultiEdit
# Purpose:
#   - WRITE side (Write/Edit/MultiEdit): block MODIFICATIONS to sensitive
#     directories and files (avoid corrupting .git, node_modules, secrets).
#   - READ side (Read): block READS of secret-bearing files so credentials
#     are never pulled into the session transcript/context. Reading a private
#     key / .env / GPG store leaks it verbatim into history.
#
# The two sides use DIFFERENT lists on purpose: the write list is broad
# (it includes */.git/* and */node_modules/*), but those MUST stay readable —
# reading git internals or dependency source is normal. The read list is the
# narrow secret-bearing subset, with an allow-list for non-secret templates.
#
# Install in .claude/settings.json (or plugin hooks.json):
#   "PreToolUse": [
#     { "matcher": "Read|Write|Edit|MultiEdit",
#       "command": "bash ./hooks/protected-paths.sh" }
#   ]

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Nothing to check without a path
[[ -z "$FILE_PATH" ]] && exit 0

# --- Modifications: block writes/edits to protected paths ---
WRITE_PROTECTED=(
    "*/.git/*"
    "*/node_modules/*"
    "*/.env"
    "*/.env.*"
    "*/.ssh/*"
    "*/credentials*"
    "*/.gnupg/*"
    "*/.password-store/*"
)

# --- Reads: block reads of secret-bearing files (NARROWER than write list) ---
READ_SECRET=(
    "*/.ssh/*"
    "*/.env"
    "*/.env.*"
    "*/credentials*"
    "*/.gnupg/*"
    "*/.password-store/*"
    "*/.aws/credentials"
    "*/.config/gcloud/*"
    "*.pem"
    "*.key"
    "*/id_rsa"
    "*/id_dsa"
    "*/id_ecdsa"
    "*/id_ed25519"
)

# Read-safe exceptions: public material / templates with no secrets.
# Checked BEFORE READ_SECRET so e.g. .env.example stays readable.
READ_ALLOW=(
    "*.env.example"
    "*.env.sample"
    "*.env.template"
    "*.env.dist"
    "*.pub"
    "*/known_hosts"
    "*/known_hosts.old"
    "*/.ssh/config"
)

case "$TOOL" in
    Write|Edit|MultiEdit)
        for pattern in "${WRITE_PROTECTED[@]}"; do
            if [[ "$FILE_PATH" == $pattern ]]; then
                echo "BLOCKED: Cannot modify protected path: $FILE_PATH" >&2
                echo "This file is in a protected directory. Remove it from the protected list if this is intentional." >&2
                exit 2
            fi
        done
        ;;
    Read)
        # Allow-list first — non-secret templates / public keys are fine to read
        for allow in "${READ_ALLOW[@]}"; do
            [[ "$FILE_PATH" == $allow ]] && exit 0
        done
        for secret in "${READ_SECRET[@]}"; do
            if [[ "$FILE_PATH" == $secret ]]; then
                echo "BLOCKED: Refusing to read secret-bearing file into context: $FILE_PATH" >&2
                echo "Reading this would leak credentials verbatim into the session transcript." >&2
                echo "Inspect it off-session, or add it to READ_ALLOW if it is a non-secret template." >&2
                exit 2
            fi
        done
        ;;
esac

exit 0
