# Security Model

## Threat Model

This system runs entirely on a single local machine. The threat model assumes:

- The operator is the only human with access to the machine
- Agents execute local commands only (shell, Python, Claude Code)
- No network access beyond what individual tools allow
- No multi-user isolation is implemented — all agents run under the same OS user

The system's job is not to protect against a malicious operator, but to prevent **accidental destructive actions** from escalating — a mis-typed command, a wrong path, or a runaway script.

## What the System Refuses

Guard evaluates every execution request against a deny-list. The following are always blocked:

| Pattern | Example |
|---|---|
| `sudo` | `sudo apt install anything` |
| Recursive force remove | `rm -rf /` or `rm -rf /home/*` |
| Recursive chmod/chown | `chmod -R 777 /` |
| System directories | `/etc`, `/usr`, `/var`, `/opt`, `/root` |
| Credential access | Commands that read `~/.ssh/`, `~/.aws/`, `~/.netrc` |
| Attempt to escape workspace | Any write outside `multi_agent/workspace/` |

Guard returns `DENIED` for these cases. The executor never runs.

## Workspace-Only Write Policy

The executor may only write to:

```
multi_agent/workspace/
```

Write operations that target paths outside this boundary are blocked by the shell adapter **before** Guard is even consulted. This is enforced as a path check in the adapter layer.

## Forbidden Commands

These commands are blocked at the shell adapter level, regardless of Guard's decision:

- `curl` or `wget` that write to system paths
- `tee` targeting `/etc`, `/usr`, `/var`
- `git` commands that push or commit to non-local remotes
- `ssh` with user@host targets
- `chmod +x` on paths outside workspace

## Credential Handling

The system **never logs credentials**. Specifically:

- No API keys, tokens, passwords, or secrets are written to memory templates
- The `logs/` directory is excluded from version control
- Shell commands that would echo or export credentials are flagged by Guard
- Claude Code adapter is configured to never log raw `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` values

## Public Repository Hygiene

Before pushing to a public branch, run:

```bash
# Check for accidental secrets
grep -rInE 'api[_-]?key|token|secret|password|credential|BEGIN PRIVATE|sk-' .

# Ensure runtime artifacts are not staged
git status --short | grep -E 'logs|memory/daily|memory/failures|memory/decisions|workspace/.*\.txt'
```

If either command produces output, investigate before pushing.

The `.gitignore` in this repository blocks all common secret patterns. If you add new tools or adapters, extend the ignore list accordingly.

## How to Safely Run Local Tests

```bash
# 1. Always run from the project root
cd /path/to/multi-agent-lab

# 2. Run the smoke test first — no side effects
bash tests/smoke_public.sh

# 3. Run a workflow with a sandboxed goal
bash multi_agent/scripts/run_workflow.sh \
  --type info \
  --goal "list all markdown files in this project"

# 4. Inspect what was written before committing
git status --short

# 5. If logs/ or memory/daily/ appeared, clean them up
rm -rf multi_agent/logs multi_agent/memory/daily/*
git checkout -- multi_agent/logs multi_agent/memory/daily
```

## Safe Contributor Checklist

Before opening a PR:

- [ ] `bash tests/smoke_public.sh` passes
- [ ] No `logs/`, `memory/daily/`, `memory/failures/`, `memory/decisions/` in `git status`
- [ ] No `.env`, `.key`, `.pem`, `*.token`, `credentials*` files staged
- [ ] All new scripts pass `bash -n`
- [ ] All new Python files pass `python3 -m py_compile`
- [ ] README/docs reflect what was actually implemented (not aspirational claims)
