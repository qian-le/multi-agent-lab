# Contributing to Multi Agent Lab

## Adding a New Agent

1. Create a new file in `.multi-agent/agents/your_agent.md`
2. Follow the existing agent template format:

```markdown
# Your Agent Name

## Responsibility
One sentence on what this agent does.

## Inputs
What this agent reads (goals, findings, plans, etc.)

## Outputs
What this agent produces.

## Safety Considerations
Any specific safety concerns for this role.
```

3. Add the agent to the coordinator's agent list in `config.yaml`
4. Add a corresponding workflow type in `.multi-agent/workflows/` if needed
5. Update `docs/architecture.md` to document the new agent role
6. Run `bash tests/smoke_public.sh` to verify structure

## Adding a New Workflow

1. Create a new file in `.multi-agent/workflows/your_workflow.yaml`
2. Define which agents run and in what order:

```yaml
name: your_workflow
agents:
  - router
  - scout
  - analyst
  - guard
  - executor
  - verifier
stop_conditions:
  - guard_denied
  - verifier_failed
```

3. Update `docs/workflows.md` with the new workflow
4. Add an example in `examples/` if applicable

## Safety-First Contribution Rules

- **Never commit secrets** — no API keys, tokens, passwords, or credentials
- **Never commit runtime artifacts** — no `logs/`, `memory/daily/`, `memory/failures/`, `memory/decisions/`
- **Workspace files only** — executor writes must stay in `.multi-agent/workspace/`
- **Test before push** — run `bash tests/smoke_public.sh` before submitting a PR
- **Describe what was implemented** — do not claim aspirational features as implemented

## Before Opening a PR

Run the full pre-push checklist:

```bash
# 1. Smoke test passes
bash tests/smoke_public.sh

# 2. No forbidden files in git status
git status --short | grep -E 'logs|memory/daily|memory/failures|memory/decisions|workspace/.*\.txt|\.env'

# 3. No accidental secrets
grep -rInE 'api[_-]?key|token|secret|password|credential|BEGIN PRIVATE|sk-' \
  --exclude-dir=.git \
  --exclude="*.md" .

# 4. All new scripts pass syntax checks
bash -n new_script.sh
python3 -m py_compile new_script.py
```

## Repository Hygiene

This is a public repository. Assume everything you push is visible to the internet.

- The `.gitignore` covers most secret patterns — extend it if you add new tools
- Do not add `.env` files, `*.pem` keys, or credential caches
- If you accidentally push a secret, treat it as compromised and rotate immediately
- When in doubt, ask before pushing

## Code of Conduct

Be respectful and collaborative. This is an educational and experimental project.
