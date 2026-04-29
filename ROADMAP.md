# Roadmap

## Near-term (next 1-2 months)

- [ ] Polish public README and docs for clarity and accuracy
- [ ] Expand `examples/` with more workflow scenarios (debug, risky, analysis)
- [ ] Add more verifier checks in `verify.py` (file existence, content match, exit code)
- [ ] Improve `smoke_public.sh` to cover all workflow types
- [ ] Add `docs/api.md` documenting adapter interface for new backend developers

## Mid-term (3-6 months)

- [ ] Integrate OpenClaw runtime agent dispatch (real `sessions_spawn` routing instead of script simulation)
- [ ] Improve Claude Code backend adapter to support persistent sessions
- [ ] Implement Hermes non-interactive reviewer mode (`hermes chat -Q` with stdin prompt)
- [ ] Add semantic memory retrieval (keyword search → lightweight embedding search)
- [ ] Write integration tests that mock the executor for CI without needing real tool access
- [ ] Add a `docs/testing.md` guide for local testing without secrets

## Long-term (6-12 months)

- [ ] **MiMo-V2.5 based Analyst** — long-context planner using MiMo API
- [ ] **MiMo-V2.5 based Verifier** — semantic output verification with reasoning
- [ ] **MiMo-V2.5 based Hermes Reviewer** — contextual risk assessment
- [ ] Multi-model routing — route simple tasks to smaller/faster models, complex to MiMo-V2.5
- [ ] Task graph execution — dependency tracking between multi-step sub-tasks
- [ ] Self-evaluation loop — verifier output feeds back into next Analyst plan
- [ ] Optional web dashboard — visualize workflow state, Guard decisions, and memory summary
- [ ] Publish to a package index (e.g., PyPI) for easier installation

## Investigating / Backlog

- [ ] macOS compatibility (shell adapter path separators, process management)
- [ ] Windows compatibility (WSL2 vs native PowerShell adapter)
- [ ] Parallel agent execution for independent Scout + Analyst steps
- [ ] Timeout configuration per workflow type
- [ ] Memory compaction — summarize old `daily.md` records into `lesson.md`
- [ ] Guard override mechanism with justification logging (for advanced users)
