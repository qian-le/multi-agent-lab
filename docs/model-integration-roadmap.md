# Future Model Integration Roadmap

## Overview

Multi Agent Lab currently uses a rule-based Router, heuristic Guard checks, and shell/Python/Claude Code backends for execution. The adapter layer (`adapters/`) provides a clean separation between agent roles and backend implementations.

The natural next step for this skeleton is to replace the rule-based components with a more capable reasoning model — one that can handle long task histories, provide nuanced safety assessments, and verify execution results semantically.

## Current Backend Stack

| Adapter | Role | Status |
|---|---|---|
| `shell_adapter.md` | Direct shell execution | Working |
| `openclaw_adapter.md` | OpenClaw agent dispatch | Working |
| `hermes_adapter.md` | Hermes advisory review | Working |
| `claude_code_adapter.md` | Claude Code session dispatch | Working |

## Where a Capable Model Fits

The most impactful integration points for a stronger model backend are:

### Analyst — Multi-Step Planning

The Analyst generates sub-step plans from Scout's findings. With a longer context window, the Analyst can:

- Maintain plan coherence across dozens of sub-steps
- Reference relevant past lessons from memory without truncation
- Generate more robust tool-call sequences for complex tasks

### Verifier — Semantic Result Checking

The Verifier currently checks output with simple diffs and exit codes. A reasoning model can:

- Detect partial success (e.g., 9 of 10 files created correctly)
- Identify semantic mismatches between the goal and actual output
- Provide a natural-language diagnosis when verification fails

### Hermes-Style Review — Risk Reasoning

Guard currently uses a pattern deny-list for safety. A model-based reviewer could:

- Understand nuanced risk trade-offs in execution requests
- Detect hidden risky side effects in compound commands
- Explain in plain language why a request was flagged

### Memory — Long-Term Summarization

Over time, the memory layer accumulates structured records. A model can:

- Summarize a week's worth of task records into reusable lessons
- Extract cross-task patterns from decision logs
- Maintain a prioritized, compact lesson context for new tasks

## Candidate Models

Any model that offers:

- Extended context windows (64K+ tokens preferred)
- Strong instruction-following and tool-use capability
- Reasoning output in structured, machine-parseable format
- Reasonable latency for subprocess-style invocation

**MiMo-V2.5-Pro** is a strong candidate for this role given its long-context reasoning focus and potential for planning and review tasks.

## Integration Steps (When Ready)

1. Add `adapters/mimo_adapter.md` following the existing adapter pattern
2. Add `mimo` to `supported_backends` in `config.yaml`
3. Create `scripts/call_mimo.sh` for subprocess invocation
4. Update the Coordinator to route `analyst`, `hermes`, and `verifier` calls to the new adapter
5. Configure the API key in a local `.env` file (never committed)

## Current State

The integrations described above are **planned**, not implemented. The current system uses rule-based routing and heuristic checks. The adapter layer is designed to make this upgrade straightforward when a model backend is available.
