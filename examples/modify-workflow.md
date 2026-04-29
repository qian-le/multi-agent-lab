# Modify Workflow Example

This example demonstrates a `modify` workflow that safely creates a file inside the workspace boundary.

## Goal

> "Create a file `demo.txt` in the workspace directory with the content: `hello agent`"

## Stage-by-Stage Execution

### 1. Router.classify()

**Input:** `"Create a file demo.txt in the workspace directory with the content: hello agent"`
**Output:** `workflow_type = modify`
**Reasoning:** Keyword "create" indicates a file modification task.

### 2. Scout.inspect()

**Actions:**
- Confirms `.multi-agent/workspace/` directory exists and is writable
- No existing `demo.txt` (first creation)

**Findings:**
```
workspace/
  - exists: true
  - writable: true
  - demo.txt exists: false
```

### 3. Analyst.plan()

**Input:** Scout findings + original goal
**Output:**
```yaml
steps:
  - id: "1"
    kind: "action"
    task: "Write 'hello agent' to .multi-agent/workspace/demo.txt"
```

### 4. Guard.evaluate()

**Input:**
```json
{
  "action": "write_file",
  "path": ".multi-agent/workspace/demo.txt",
  "content": "hello agent"
}
```

**Output:** `APPROVED`
**Reasoning:**
- Write target is inside workspace boundary
- Content is plain text, no credential access
- No system paths involved

### 5. Executor.run()

**Command executed:**
```bash
echo "hello agent" > .multi-agent/workspace/demo.txt
```

**Output:**
```
File created: .multi-agent/workspace/demo.txt
Bytes written: 12
```

### 6. Verifier.check()

**Input:**
```json
{
  "goal": "Create demo.txt with content 'hello agent'",
  "executor_output": "File created: .multi-agent/workspace/demo.txt\nBytes written: 12"
}
```

**Actions:**
- Reads `.multi-agent/workspace/demo.txt`
- Compares content to expected value

**Output:** `VERIFIED`
**Reasoning:** File exists and contains exactly `hello agent`.

### 7. MemoryManager.write()

**Action:** Writes `daily.md` entry and `decision.md` for the Guard pass.

---

## Expected Output

After running:
```bash
bash .multi-agent/scripts/run_workflow.sh \
  --type modify \
  --goal "Create demo.txt in workspace with content hello agent"
```

**Workspace result:**
```bash
$ cat .multi-agent/workspace/demo.txt
hello agent
```

**Memory record (decision.md):**
```markdown
# Guard Decision — 2026-04-29

## Action
write_file: .multi-agent/workspace/demo.txt

## Decision
APPROVED

## Reasoning
Inside workspace boundary. Plain text content. No credential access.
```

---

## Safety Notes

- The write is constrained to `.multi-agent/workspace/`
- Guard would block any write to `~/.ssh/`, `/etc/`, or system paths
- The file content is verified by Verifier after creation
- No secrets or tokens were involved
