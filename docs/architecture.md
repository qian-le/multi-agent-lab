# System Architecture

## Overview

Multi Agent Lab is a workflow skeleton that routes tasks through a chain of specialized agents. Each agent has a single responsibility. The coordinator (Main) orchestrates the pipeline and holds final decision authority.

The system is designed for local execution on a single machine. It does not involve remote agent hosting or hosted LLM backends in its current form.

## Agent Roles

| Agent | Responsibility | Reads | Writes |
|---|---|---|---|
| **Router** | Classifies task type from goal | goal text | workflow type |
| **Scout** | Inspect workspace, memory, files | filesystem, memory | scout findings |
| **Analyst** | Generate sub-step plan | scout findings, memory | plan with steps |
| **Hermes Reviewer** | Fallback review for complex tasks | analyst plan | review notes |
| **Guard** | Safety gate before execution | action, context | APPROVED / DENIED |
| **Executor** | Perform the action | guard approval | stdout, files |
| **Verifier** | Check executor output | executor result, goal | verified / failed |
| **Memory Manager** | Record session to templates | all agent outputs | memory templates |

## Stage-by-Stage Lifecycle

```
User Goal
  │
  ▼
Router.classify(goal)  ──►  workflow type
  │
  ▼
Scout.inspect()  ──►  findings (workspace state + memory)
  │
  ▼
Analyst.plan()  ──►  step list (id / kind / task)
  │
  ▼
Hermes.review()  [only if complexity == complex]
  │
  ▼
Guard.evaluate()  ──►  APPROVED / DENIED / NEEDS_CONFIRMATION
  │
  ▼  [APPROVED only]
Executor.run()
  │
  ▼
Verifier.check()
  │
  ▼
MemoryManager.write()
```

## Why Guard and Verifier Exist

Most agent demos skip the step before execution. Guard enforces a checklist:

- Is this a forbidden command (sudo, rm -rf, system paths)?
- Is this writing outside the workspace boundary?
- Are credentials or secrets involved?

Guard can block execution entirely. When it does, the pipeline stops.

Verifier checks the executor's output against the original goal. Even approved executions can fail. Verifier's job is to detect that failure and report it.

## Adapter Layer

Each backend (shell, OpenClaw, Hermes, Claude Code) is behind a uniform adapter interface. This makes it possible to:

- Swap the shell executor for a Python executor
- Route to Claude Code for specific tasks
- Keep Hermes as a reviewer without making it a primary executor

Current adapters:

```
adapters/
├── shell_adapter.md       # bash / python3 / node execution
├── openclaw_adapter.md    # OpenClaw agent dispatch
├── hermes_adapter.md      # Hermes advisory review
└── claude_code_adapter.md # Claude Code session dispatch
```

## Memory Layer

Memory is structured as templates, not raw logs. Each task produces a structured record:

```
memory/
├── templates/
│   ├── daily.md       # Per-task session record
│   ├── decision.md    # Guard decision with reasoning
│   ├── failure.md     # Failed execution with diagnosis
│   └── lesson.md      # Cross-task learnings
├── project/
│   └── status.md      # Current project state summary
└── lessons/
    └── guard-before-executor.md  # Safety lessons learned
```

The memory layer is **read by Scout** at startup so future tasks have context. It is **written by Memory Manager** at task end.

## Workspace Boundary

The executor may only write to:

```
multi_agent/workspace/
```

Files outside this boundary require Guard approval with elevated justification. The shell adapter checks all write paths before executing.
