# Workflow Reference

Each workflow type defines which agents run and where the pipeline stops.

---

## info

**Trigger:** Task is read-only (search, inspect, read, analyze without modification).

**Pipeline:**
```
Router → Scout → Analyst → MemoryManager
```
No execution. No files written. No changes made.

**Use when:** You want to understand a codebase, inspect memory, or review file contents without touching anything.

**Stop conditions:** None. Always completes with a Scout + Analyst report.

---

## analysis

**Trigger:** Task requires multi-step reasoning and comparison (not just inspection).

**Pipeline:**
```
Router → Scout → Analyst → Hermes Reviewer → MemoryManager
```
Executor never runs. Analyst produces a plan, Hermes reviews it.

**Use when:** Evaluating trade-offs, comparing approaches, planning a refactor, reviewing a design.

**Stop conditions:** Stops after Analyst + Hermes review. No side effects.

---

## modify

**Trigger:** Task creates or updates files inside `.multi-agent/workspace/`.

**Pipeline:**
```
Router → Scout → Analyst → Guard → Executor → Verifier → MemoryManager
```
Full pipeline. Guard must approve. Verifier checks result.

**Use when:** Creating a new file, editing an existing file, generating code.

**Stop conditions:**
- Guard DENIED: blocked before executor
- Verifier FAILED: execution result does not match goal

---

## debug

**Trigger:** Diagnosing a failure, running diagnostics, or investigating runtime behavior.

**Pipeline:**
```
Router → Scout → Analyst → Guard → Executor → Verifier → MemoryManager
```
Same as modify, but with extra Scout inspection and workspace state capture.

**Use when:** Running test scripts, inspecting logs, checking exit codes.

**Stop conditions:**
- Guard DENIED on risky commands
- Verifier detects unexpected output

---

## architecture

**Trigger:** Design review, dry-run, or documentation of agent roles.

**Pipeline:**
```
Router → Scout → Analyst → Hermes Reviewer → MemoryManager
```
No executor. No side effects. A pure review pipeline.

**Use when:** Reviewing system design, planning new agent roles, auditing the workflow itself.

**Stop conditions:** None. Always ends with a review document.

---

## risky

**Trigger:** Task touches system paths, uses sudo, or modifies outside `.multi-agent/workspace/`.

**Pipeline:**
```
Router → Scout → Analyst → Guard → [BLOCKED] → MemoryManager
```
Guard blocks by default for risky tasks. Executor is never reached unless Guard has an explicit allow rule.

**Use when:** Cleaning logs, installing packages, modifying system config.

**Default Guard behavior:** DENIED.

**Stop conditions:** Always blocked at Guard unless an explicit override rule is configured (not recommended for public use).

---

## Workflow Type Detection

Router classifies based on keywords in the goal:

| Keyword | Workflow |
|---|---|
| `inspect`, `list`, `find`, `read`, `search` | `info` |
| `analyze`, `compare`, `evaluate`, `review` | `analysis` |
| `create`, `write`, `edit`, `modify`, `generate` | `modify` |
| `debug`, `diagnose`, `check`, `test` | `debug` |
| `design`, `plan`, `dry-run`, `architecture` | `architecture` |
| `sudo`, `rm -rf`, `chmod -R`, `system`, `/etc`, `/usr` | `risky` |
