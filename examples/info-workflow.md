# Info Workflow Example

This example demonstrates a read-only `info` workflow. No files are created or modified.

## Goal

> "List all agent role definition files in the project"

## Stage-by-Stage Execution

### 1. Router.classify()

**Input:** `"list all agent role definition files in the project"`
**Output:** `workflow_type = info`
**Reasoning:** Keyword "list" indicates a read-only inspection task.

### 2. Scout.inspect()

**Actions:**
- Reads `.multi-agent/agents/` directory contents
- Reads `.multi-agent/memory/project/status.md` for recent context
- No filesystem modification

**Findings:**
```
Agent files found:
- main.md     : Main coordinator, task routing
- router.md   : Task type classification
- scout.md    : Read-only inspection
- analyst.md  : Plan generation
- hermes_reviewer.md : Fallback review
- guard.md    : Safety gate
- executor.md : Backend execution
- verifier.md : Result verification
- memory_manager.md : Memory read/write
```

### 3. Analyst.plan()

**Input:** Scout findings + original goal
**Output:**
```yaml
steps:
  - id: "1"
    kind: "inspect"
    task: "Confirm all agent files are present and non-empty"
  - id: "2"
    kind: "analyze"
    task: "Summarize each agent's documented responsibility"
```

### 4. MemoryManager.write()

**Action:** Writes `daily.md` entry summarizing the session.

**Result:**
```
Status: SUCCESS
Workflow: info
Output: Listed 10 agent files, all non-empty
Steps run: Scout → Analyst → MemoryManager
Executor ran: NO
```

## Expected Output

The workflow produces a structured report:

```markdown
# info session — 2026-04-29

## Goal
List all agent role definition files in the project

## Workflow
info

## Findings
[Scout report listing agent files]

## Analysis
[Analyst summary of each role]

## Executor
Did not run (info workflow)

## Result
SUCCESS
```

## Notes

- No files were created or modified
- No shell commands were executed
- No credentials or secrets were accessed
- This is a dry-run document, not a runtime log
