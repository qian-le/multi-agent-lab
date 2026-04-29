# MiMo Orbit Integration

## Why MiMo-V2.5

MiMo-V2.5's extended context windows and long-context reasoning capability are relevant to several bottlenecks in the current skeleton:

### Long-Context Planning

The Analyst agent currently generates plans from a fixed-context prompt (scout findings + memory). For complex tasks with many sub-steps, the plan quality degrades as the context grows. MiMo-V2.5's extended context could maintain plan coherence across dozens of sub-steps without truncation.

### Hermes as Fallback Reviewer

Hermes currently works as a rule-based reviewer. With MiMo-V2.5, the reviewer could:

- Understand nuanced safety trade-offs in execution requests
- Detect when an approved-looking command has a hidden risky side effect
- Provide natural-language reasoning for why a request was flagged

### Verifier Reasoning

The Verifier currently checks output against a simple diff or exit-code check. MiMo-V2.5's reasoning could:

- Detect partial success (e.g., 9 of 10 files created)
- Identify semantic mismatches between goal and output
- Provide a natural-language diagnosis when verification fails

### Memory Summarization

The memory layer currently stores raw structured records. Over time, these accumulate. MiMo-V2.5 could:

- Summarize a week's worth of task records into a compact lesson
- Extract reusable patterns from decision logs
- Prioritize which lessons are most relevant for a new task

## Current State vs. Future State

| Component | Current | Future with MiMo-V2.5 |
|---|---|---|
| **Router** | Keyword matching | Semantic task classification |
| **Scout** | File search + grep | Deep codebase analysis |
| **Analyst** | Fixed-context planning | Long-context multi-step planning |
| **Hermes** | Rule-based review | Reasoning-based review |
| **Guard** | Pattern deny-list | Contextual risk assessment |
| **Verifier** | Exit code + diff | Semantic output verification |
| **Memory** | Raw templates | Summarized + retrievable lessons |

## Planned Integration Points

### 1. MiMo as Analyst Backend

Replace the current fixed-prompt Analyst with a MiMo-V2.5 call. Input: scout findings + memory context. Output: structured plan with sub-steps.

### 2. MiMo as Hermes Reviewer

Route complex tasks (as detected by Router) to MiMo for a second review pass before Guard. MiMo reviews the Analyst's plan and provides a confidence score + reasoning.

### 3. MiMo as Verifier

After Executor completes, route output to MiMo for semantic verification. MiMo checks: did the execution actually satisfy the goal? Provide a natural-language verdict.

### 4. MiMo for Memory Management

Periodically run MiMo over accumulated lesson memory to produce summarized updates. Keep only the most relevant lessons in active context.

## Not Claiming Current Integration

**Important:** The skeleton currently does NOT have MiMo-V2.5 integration. The adapter layer (`adapters/`) supports shell, OpenClaw, Hermes, and Claude Code. MiMo is a planned integration target, not a current feature.

Do not claim in the README or docs that "MiMo is integrated" unless the adapter and runtime call actually exist in the codebase.

## How to Add MiMo Integration

When the integration is ready, the steps would be:

1. Create `adapters/mimo_adapter.md` following the existing adapter pattern
2. Add `mimo` to the `supported_backends` list in `config.yaml`
3. Update `scripts/call_mimo.sh` (new file) for subprocess invocation
4. Update the Coordinator to route `analyst` / `hermes` / `verifier` calls to the MiMo adapter
5. Add MiMo API key to local `.env` (never committed)
6. Update this document and the README to reflect the integration

## Eligibility Note

This skeleton is being submitted for the **MiMo Orbit** program to support the development of the planned MiMo-V2.5 integration described above. The integration does not exist yet — this application is for the capability development grant.
