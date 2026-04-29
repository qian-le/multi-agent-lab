# Architecture Review Example

This example demonstrates an `architecture` workflow — a dry-run review of the agent system design with no execution.

## Goal

> "Review the current agent role definitions and summarize the Guard-verifier safety pattern"

## Stage-by-Stage Execution

### 1. Router.classify()

**Input:** `"Review the current agent role definitions and summarize the Guard-verifier safety pattern"`
**Output:** `workflow_type = architecture`
**Reasoning:** Keywords "review" and "summarize" indicate a design analysis task.

### 2. Scout.inspect()

**Actions:**
- Reads all agent definition files in `.multi-agent/agents/`
- Reads `docs/architecture.md` for system overview
- Reads `.multi-agent/memory/lessons/` for past architecture decisions

**Findings:**
```
Agent files (9 total):
- main.md           : Coordinator, final authority
- router.md         : Workflow classification
- scout.md          : Read-only inspection
- analyst.md        : Plan generation
- hermes_reviewer.md : Fallback complex-task reviewer
- guard.md          : Safety gate, deny-list checking
- executor.md       : Shell/Python/Claude Code backend
- verifier.md       : Post-execution result checking
- memory_manager.md : Structured memory read/write

Architecture doc: exists, up to date
Lessons: 1 file (guard-before-executor.md)
```

### 3. Analyst.plan()

**Input:** Scout findings + original goal
**Output:**
```yaml
steps:
  - id: "1"
    kind: "inspect"
    task: "Read guard.md and verifier.md in full"
  - id: "2"
    kind: "analyze"
    task: "Summarize the Guard-verifier safety pattern design"
  - id: "3"
    kind: "analyze"
    task: "Identify any gaps or missing safety considerations"
```

### 4. Hermes.review()

**Input:** Analyst plan for a complex multi-step review
**Output:**
```markdown
## Hermes Review Notes

The Guard-verifier pattern provides two-layer safety:
1. Guard prevents execution of risky operations
2. Verifier checks output even for approved operations

This is a defense-in-depth approach. The separation is sound.

One consideration: the current deny-list is pattern-based.
Future MiMo-V2.5 integration could enable semantic risk assessment.

Confidence: HIGH for current implementation.
```

### 5. Guard.evaluate()

**Input:**
```json
{
  "action": "architecture_review",
  "note": "This is a read-only analysis task"
}
```

**Output:** `APPROVED`
**Reasoning:** No execution requested. Read-only review.

### 6. Executor.run()

**Does NOT run** — architecture workflows never execute.

### 7. Verifier.check()

**Does NOT run** — Verifier only runs after Executor.

### 8. MemoryManager.write()

**Action:** Writes `daily.md` and `decision.md` for this architecture review.

---

## Expected Output

The workflow produces an architecture review document:

```markdown
# Architecture Review — 2026-04-29

## Goal
Review the current agent role definitions and summarize the Guard-verifier safety pattern

## Workflow
architecture

## Agents Used
Router → Scout → Analyst → Hermes → Guard → MemoryManager

## Executor
Did not run (architecture workflow)

## Key Findings
- 9 agent roles defined, all with documented responsibilities
- Guard-verifier provides two-layer safety: block at gate + verify after run
- Pattern-based deny-list is current implementation; semantic review planned

## Hermes Notes
The separation of Guard and Verifier is sound.
Defense-in-depth approach confirmed.

## Result
SUCCESS — Review complete. No execution.
```

---

## Safety Notes

- No commands were executed
- No files were created or modified
- This is a pure design review pipeline
- Suitable for auditing the system itself
