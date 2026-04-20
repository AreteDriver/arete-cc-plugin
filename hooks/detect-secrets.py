#!/usr/bin/env python3
"""
Security Hook: Detect secrets in prompts and code before execution.
Blocks prompts/file writes containing potential secrets.

This hook runs on:
- UserPromptSubmit: Scans user prompts for accidental secret exposure
- PreToolUse (Write/Edit): Scans file content before writing
- PreToolUse (Bash): Scans commands for embedded secrets
"""
import json
import sys
import re
import os
from datetime import datetime, timezone

# Audit log location
AUDIT_LOG = os.path.expanduser("~/.claude/audit-log.txt")

# Sensitive patterns to detect (pattern, description, severity)
SENSITIVE_PATTERNS = [
    # Generic credentials
    # Tightened 2026-04-19: \b word boundaries on the keyword prevent it from
    # matching inside bash expansions like ${PWD:-...} or $(pwd), and the
    # first value character must not be a shell-expansion char (-, $, (, ),
    # {, }) so real literal secrets are still caught while dollar-brace
    # default-value patterns are ignored.
    (r'(?i)\b(password|passwd|pwd)\b\s*[:=]\s*["\']?[^\s"\'\-\$\(\)\{\}][^\s"\']{7,}', 'Password literal', 'critical'),
    (r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?[a-z0-9]{16,}', 'API key', 'critical'),
    (r'(?i)(secret|token|auth)[_-]?(key|token)?\s*[:=]\s*["\']?[a-z0-9]{20,}', 'Secret/Token', 'critical'),

    # AWS
    (r'AKIA[0-9A-Z]{16}', 'AWS Access Key ID', 'critical'),
    (r'(?i)aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*["\']?[A-Za-z0-9/+=]{40}', 'AWS Secret Key', 'critical'),

    # Private keys
    (r'-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY', 'Private key', 'critical'),
    (r'-----BEGIN PRIVATE KEY', 'Private key (PKCS8)', 'critical'),

    # Platform-specific tokens
    (r'ghp_[A-Za-z0-9_]{36,}', 'GitHub Personal Access Token', 'critical'),
    (r'gho_[A-Za-z0-9_]{36,}', 'GitHub OAuth Token', 'critical'),
    (r'ghu_[A-Za-z0-9_]{36,}', 'GitHub User Token', 'critical'),
    (r'ghs_[A-Za-z0-9_]{36,}', 'GitHub Server Token', 'critical'),
    (r'github_pat_[A-Za-z0-9_]{22,}', 'GitHub Fine-grained PAT', 'critical'),

    (r'sk_live_[A-Za-z0-9]{24,}', 'Stripe Live Secret Key', 'critical'),
    (r'sk_test_[A-Za-z0-9]{24,}', 'Stripe Test Secret Key', 'high'),
    (r'pk_live_[A-Za-z0-9]{24,}', 'Stripe Live Publishable Key', 'medium'),

    (r'xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*', 'Slack Token', 'critical'),

    (r'sk-[A-Za-z0-9]{48,}', 'OpenAI API Key', 'critical'),
    (r'sk-proj-[A-Za-z0-9-_]{48,}', 'OpenAI Project Key', 'critical'),

    # Database connection strings
    (r'mongodb(\+srv)?://[^:]+:[^@]+@[^\s]+', 'MongoDB Connection String', 'critical'),
    (r'postgresql://[^:]+:[^@]+@[^\s]+', 'PostgreSQL Connection String', 'critical'),
    (r'mysql://[^:]+:[^@]+@[^\s]+', 'MySQL Connection String', 'critical'),
    (r'redis://:[^@]+@[^\s]+', 'Redis Connection String', 'critical'),

    # Bearer tokens
    (r'Bearer\s+[a-zA-Z0-9\-_.]{20,}', 'Bearer Token', 'high'),

    # SSH keys (public - less severe but worth noting)
    (r'ssh-rsa\s+AAAA[0-9A-Za-z+/]+', 'SSH Public Key', 'low'),
    (r'ssh-ed25519\s+AAAA[0-9A-Za-z+/]+', 'SSH Public Key (ED25519)', 'low'),

    # JWT tokens
    (r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*', 'JWT Token', 'high'),

    # Generic high-entropy strings that look like secrets
    (r'(?i)(client[_-]?secret|app[_-]?secret)\s*[:=]\s*["\']?[a-z0-9]{32,}', 'Client/App Secret', 'critical'),
]

# Patterns to ignore (false positives)
IGNORE_PATTERNS = [
    r'example',
    r'sample',
    r'placeholder',
    r'your[_-]?api[_-]?key',
    r'xxx+',
    r'test[_-]?key',
    r'fake',
    r'dummy',
    r'mock',
]


def log_audit(event_type: str, message: str, severity: str = "info"):
    """Write to audit log."""
    try:
        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        with open(AUDIT_LOG, 'a') as f:
            f.write(f"[{timestamp}] [{severity.upper()}] {event_type}: {message}\n")
    except Exception:
        pass  # Don't fail the hook if logging fails


def is_false_positive(text: str, match_start: int, match_end: int) -> bool:
    """Check if a match is likely a false positive."""
    # Get context around the match
    context_start = max(0, match_start - 50)
    context_end = min(len(text), match_end + 50)
    context = text[context_start:context_end].lower()

    for pattern in IGNORE_PATTERNS:
        if re.search(pattern, context, re.IGNORECASE):
            return True

    return False


def check_for_secrets(text: str, context: str = "content") -> list:
    """Scan text for sensitive patterns."""
    findings = []

    for pattern, description, severity in SENSITIVE_PATTERNS:
        try:
            matches = list(re.finditer(pattern, text, re.MULTILINE))
            for match in matches:
                if is_false_positive(text, match.start(), match.end()):
                    continue

                findings.append({
                    'pattern': description,
                    'location': context,
                    'severity': severity,
                    'preview': text[max(0, match.start()-10):min(len(text), match.end()+10)][:50] + '...'
                })
        except re.error:
            continue

    return findings


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        log_audit("HOOK_ERROR", f"Failed to parse input: {e}", "error")
        sys.exit(1)

    hook_event = input_data.get('hook_event_name', '')
    findings = []
    block_reason = None

    # Check prompts for secrets
    if hook_event == 'UserPromptSubmit':
        prompt = input_data.get('prompt', '')
        findings = check_for_secrets(prompt, 'user_prompt')

        if findings:
            critical_count = sum(1 for f in findings if f['severity'] == 'critical')
            log_audit("SECRET_DETECTED", f"Found {len(findings)} potential secret(s) in prompt ({critical_count} critical)", "warning")

            if critical_count > 0:
                block_reason = f"Blocked: Detected {critical_count} critical secret(s) in prompt: {', '.join(f['pattern'] for f in findings if f['severity'] == 'critical')}"

    # Check file writes for secrets
    elif hook_event == 'PreToolUse':
        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})

        if tool_name in ['Write', 'Edit']:
            file_path = tool_input.get('file_path', '')
            content = tool_input.get('content', '') or tool_input.get('new_string', '')

            findings = check_for_secrets(content, f'file:{file_path}')

            if findings:
                critical_count = sum(1 for f in findings if f['severity'] == 'critical')
                log_audit("SECRET_IN_FILE", f"Found {len(findings)} potential secret(s) in {file_path}", "warning")

                if critical_count > 0:
                    output = {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "deny",
                            "permissionDecisionReason": f"Blocked: File contains {critical_count} potential secret(s): {', '.join(f['pattern'] for f in findings if f['severity'] == 'critical')}"
                        }
                    }
                    print(json.dumps(output))
                    sys.exit(0)

        elif tool_name == 'Bash':
            command = tool_input.get('command', '')
            findings = check_for_secrets(command, 'bash_command')

            if findings:
                critical_count = sum(1 for f in findings if f['severity'] == 'critical')
                if critical_count > 0:
                    log_audit("SECRET_IN_COMMAND", f"Found secret in bash command", "warning")
                    output = {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "deny",
                            "permissionDecisionReason": f"Blocked: Command contains potential secret(s): {', '.join(f['pattern'] for f in findings if f['severity'] == 'critical')}"
                        }
                    }
                    print(json.dumps(output))
                    sys.exit(0)

    # For UserPromptSubmit, output block decision if needed
    if hook_event == 'UserPromptSubmit' and block_reason:
        output = {
            "decision": "block",
            "reason": block_reason
        }
        print(json.dumps(output))
        sys.exit(0)

    # No issues found
    sys.exit(0)


if __name__ == '__main__':
    main()
