# Security Policy

## Supported Versions

Only the latest published release is supported with security updates.

| Version | Supported |
|---|---|
| latest release | ✅ |
| older releases | ❌ |

## Reporting a Vulnerability

If you discover a security issue, please report it responsibly:

1. **Do not** open a public GitHub Issue for security vulnerabilities
2. Send a private report instead
3. Allow 48 hours for initial response

## Threat Model

This system runs on a single local machine under a single OS user account. It is designed to prevent **accidental destructive actions** from causing harm. It does not provide isolation between multiple users or machines.

## What This System Protects Against

- Accidental deletion of project files via `rm -rf` and similar commands
- Writing to system directories (`/etc`, `/usr`, `/var`, `/opt`)
- Credential exposure through log files
- Unintended modification of files outside `.multi-agent/workspace/`

## What This System Does NOT Protect Against

- Malicious operator with local shell access
- Remote code execution attacks
- Privilege escalation
- Multi-user isolation

## Safety Features

### Guard Before Executor

Every execution request passes through Guard first. Guard blocks:

- `sudo`, `su`, `doas`
- Recursive force remove (`rm -rf /`, `rm -rf /home/*`)
- Recursive chmod/chown on system paths
- Writes to `/etc`, `/usr`, `/var`, `/opt`, `/root`
- Commands that access `~/.ssh/`, `~/.aws/`, `~/.netrc`

### Workspace-Only Writes

The Executor is constrained to `.multi-agent/workspace/`. Any attempt to write outside this boundary is blocked at the adapter layer, before Guard is even consulted.

### No Secret Logging

API keys, tokens, passwords, and credentials are never written to:

- Memory templates
- Log files
- stdout / stderr

## Reporting Guidelines

- Include a clear description of the issue
- Describe the expected vs. actual behavior
- Include steps to reproduce (if applicable)
- Do not include actual secrets or credentials in reports

## Security Updates

Security fixes are applied immediately to the main branch and released as a patch version bump.
