# Multi Agent Lab

[![Public Smoke Test](https://github.com/qian-le/multi-agent-lab/actions/workflows/public-smoke.yml/badge.svg)](https://github.com/qian-le/multi-agent-lab/actions/workflows/public-smoke.yml)

A local multi-agent workflow skeleton demonstrating how to route tasks through specialized agents — Scout, Analyst, Hermes Reviewer, Guard, Executor, and Verifier — with a mandatory safety gate before any execution.

This is a **learning and experimentation skeleton**, not a production system. It runs entirely on a single machine and is designed to teach agent role separation, safety-first execution, and memory management.

## Project Structure

```
multi_agent_lab/
├── multi_agent/                 # Core skeleton code
│   ├── agents/                # Agent role definitions
│   ├── adapters/              # Backend adapter layer
│   ├── workflows/             # Workflow type definitions
│   ├── scripts/               # Shell/Python runner scripts
│   ├── memory/templates/       # Structured memory templates
│   └── config.yaml            # Workflow routing configuration
├── docs/                      # Architecture, workflow, and integration docs
├── examples/                  # Sanitized example runs (no real logs)
├── tests/                    # Public smoke test
├── templates/                # Example config templates
│   └── .multi-agent/          # Example local config (no real secrets)
├── .github/workflows/
└── README.md
```

## Quick Start

```bash
# Check that all scripts have valid syntax
bash tests/smoke_public.sh

# Detect available backends
bash multi_agent/scripts/detect_tools.sh

# Dry-run an info workflow (read-only, never executes)
bash multi_agent/scripts/run_workflow.sh --type info --goal "list all agent files"

# Dry-run a modify workflow (stops at Guard)
bash multi_agent/scripts/run_workflow.sh --type modify --goal "create a hello world file"
```

## Core Agent Roles

| Agent | Responsibility |
|---|---|
| **Router** | Classifies incoming goal into workflow type |
| **Scout** | Read-only inspection of workspace and memory |
| **Analyst** | Plans approach and sub-steps |
| **Hermes Reviewer** | Fallback reasoning for complex tasks |
| **Guard** | Mandatory safety gate — blocks before Executor runs |
| **Executor** | Runs actions via shell, Python, or Claude Code |
| **Verifier** | Checks executor output matches the original intent |
| **Memory Manager** | Reads/writes structured memory templates |

## Safety Model

- **Guard before Executor**: Every execution passes through Guard first
- **Workspace-only writes**: Executor can only write to `multi_agent/workspace/`
- **No secret logging**: API keys, tokens, and credentials are never written to memory or logs
- **Deny list**: Commands like `sudo`, `rm -rf /`, recursive chmod/chown on system paths are blocked by default

See [docs/security.md](docs/security.md) for the full threat model.

## Environment Setup

This project requires **no external services** to run the skeleton. The smoke test and dry-runs work out of the box.

For real agent runtime calls (OpenClaw, Hermes, Claude Code), you need to set up your own backend:

```bash
# Required environment variables (copy templates and fill in your values)
cp templates/env.example .env

# Edit .env with your actual API keys and paths
nano .env
```

See `templates/.multi-agent/config.yaml.example` for the full config template with field documentation.

## What Cannot Be Committed

The following are automatically excluded via `.gitignore`. If you see them in a commit, something is wrong:

- `multi_agent/logs/` — runtime message logs
- `multi_agent/memory/daily/` — session day logs
- `multi_agent/memory/failures/` — failure records
- `multi_agent/memory/decisions/` — decision logs
- `multi_agent/workspace/` — executor output files
- `.env` — contains real API keys and tokens
- `~/.openclaw/`, `~/.ssh/`, `~/.aws/`, `~/.claude/` — private runtime dirs
- `*.pyc`, `__pycache__/`, `*.pyo`
- Any file containing real tokens, API keys, or secrets

## Smoke Test

```bash
bash tests/smoke_public.sh
```

The smoke test checks:
1. All required files exist
2. All bash scripts have valid syntax
3. All Python scripts compile without error
4. Forbidden directories (logs, memory, workspace) are not tracked by git
5. `.gitignore` covers all critical items
6. README makes no inflated claims
7. Integration docs clearly mark planned items as planned

## Backend Adapters

The skeleton ships with four backend adapters in `multi_agent/adapters/`:

| Adapter | Backend | Status |
|---|---|---|
| `shell_adapter.md` | Direct `bash` / `python3` | Always available |
| `openclaw_adapter.md` | OpenClaw agent dispatch | Requires OpenClaw runtime |
| `hermes_adapter.md` | Hermes advisory review | Requires Hermes CLI |
| `claude_code_adapter.md` | Claude Code session | Requires Claude Code |

Each adapter documents how to configure the backend and what the call/response format looks like.

## Model Integration Roadmap

Planned integration targets for a long-context reasoning model (e.g. MiMo-V2.5-Pro):

- **Analyst** — multi-step planning with long task history
- **Verifier** — semantic output verification beyond diff/exit-code
- **Hermes-style review** — contextual risk reasoning instead of pattern deny-lists
- **Memory summarization** — condensing accumulated session records

See [docs/model-integration-roadmap.md](docs/model-integration-roadmap.md) for the full plan. MiMo-V2.5-Pro integration is **planned**, not currently implemented.

## License

MIT
