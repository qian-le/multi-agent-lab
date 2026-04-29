# Lesson: Guard Before Executor

- date: 2026-04-29
- source_task: initial implementation
- lesson: Executor must only run after Guard returns `decision: allow`; `ask_user` and `deny` both stop the workflow.
- applies_to: modify, debug, architecture, risky
- avoid: treating Analyst plans or Hermes reviews as execution permission.

