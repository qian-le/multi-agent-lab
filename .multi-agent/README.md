# OpenClaw Multi-Agent OS

这是一个放在当前项目内的本地多 Agent 协作闭环。它不替换已有 `.openclaw/`，而是在 `.multi-agent/` 中提供稳定的调度、审查、执行、验证和记忆层。

## Agent 职责

- Main Coordinator: 理解目标、选择 workflow、调度子 agent、汇总结果、触发 memory。
- Router: 分类 `info`、`analysis`、`debug`、`modify`、`architecture`、`risky`。
- Scout: 只读侦察，只能查看文件、目录、日志和 git 状态。
- Analyst: 只分析和制定方案，不执行、不改文件。
- Hermes Reviewer: 高级审查、第二意见、风险识别，输出 `approve` / `revise` / `reject`。
- Guard: 执行前安全门，只有 `decision: allow` 才能继续。
- Executor: 按 Guard 允许范围选择 `shell`、`python` 或 `claude_code` 后端执行。
- Verifier: 检查文件、内容、命令和日志，输出 `pass` / `fail` / `partial`。
- Memory Manager: 写 daily、project、decisions、failures、lessons。

## 工作流

- 查询类: `main -> router -> scout -> memory -> main`
- 分析类: `main -> router -> scout -> analyst -> guard -> memory -> main`
- 普通修改类: `main -> router -> scout -> analyst -> guard -> executor -> verifier -> memory -> main`
- Debug 类: `main -> router -> scout -> analyst -> guard -> executor -> verifier -> memory -> main`
- 架构/复杂重构类: `main -> router -> scout -> analyst -> hermes -> analyst_revision -> guard -> executor -> verifier -> memory -> main`
- 高风险类: `main -> router -> scout -> analyst -> hermes -> guard -> ask_user -> memory -> main`

## Hermes 接入

`scripts/call_hermes.sh` 会检测 `hermes` 命令。存在时尝试把 Analyst Plan 交给 Hermes；不可用或无输出时生成 fallback review，不让流程崩溃。Hermes 不直接修改文件，只输出审查意见。

## Claude Code 接入

`scripts/call_claude_code.sh` 会检测 `claude` 命令。复杂任务选择 `--backend claude_code` 时，它会把用户目标、Analyst 方案、Hermes 审查、Guard 范围、禁止动作和验证方式打包成边界清晰的 prompt。`claude` 不存在时会优雅失败并写日志。

## Guard 安全规则

Guard 会拦截递归强删除、`sudo`、递归权限修改、系统目录修改、凭据相关操作、安装命令和范围不清晰的计划。`decision: ask_user` 或 `decision: deny` 都会停止执行。

## Verifier 验证规则

Verifier 支持检查文件存在、文件内容、命令退出码和日志存在。没有证据不会输出 `pass`。每次 Executor 运行后必须进入 Verifier。

## Memory

- `memory/daily/`: 每次任务追加当天记录。
- `memory/project/status.md`: 当前项目状态。
- `memory/decisions/`: `architecture` 任务的决策记录。
- `memory/failures/`: 验证失败的任务记录。
- `memory/lessons/`: 可复用经验。
- `memory/templates/`: daily、decision、failure、lesson 模板。

Memory 写入会做基础敏感值脱敏，不记录 API key、token、cookie、password、secret 等值。

## 常用命令

```bash
bash .multi-agent/scripts/detect_tools.sh
```

```bash
bash .multi-agent/scripts/smoke_test.sh
```

```bash
bash .multi-agent/scripts/run_workflow.sh --type info --goal "inspect project structure"
```

```bash
bash .multi-agent/scripts/run_workflow.sh --type modify --goal "create workspace/test.txt with hello multi-agent" --backend shell
```

```bash
bash .multi-agent/scripts/run_workflow.sh --type architecture --goal "review multi-agent workflow design" --backend claude_code
```

## 新增 Agent

1. 在 `agents/` 下新增 `<name>.md`。
2. 明确职责、输入、输出格式、禁止动作。
3. 在相关 workflow 的 `stages` 中加入该 agent。
4. 在 `run_workflow.sh` 或外部 OpenClaw 调度中增加对应阶段。
5. 增加验证和 memory 字段，确保可排查。

## 新增 Workflow

1. 在 `workflows/` 下新增 `<name>.yaml`。
2. 定义 stages、是否需要 Guard、Verifier、Hermes、用户确认。
3. 更新 `config.yaml` 的 `workflows`。
4. 扩展 Router 分类规则。
5. 增加 smoke 或专项验证命令。

## 故障排查

- 工具不存在: 运行 `bash .multi-agent/scripts/detect_tools.sh`。
- Guard 停止: 查看 `.multi-agent/logs/messages/*_guard.md`。
- Hermes 不可用: 查看 `.multi-agent/logs/runs/*_hermes.log`，fallback review 会写入 messages。
- Claude Code 不可用: 查看 `.multi-agent/logs/runs/*_claude_code.log`。
- 验证失败: 查看 `.multi-agent/logs/messages/*_verifier.md` 和 `memory/failures/`。
- 没有 daily memory: 检查 `write_memory.py` 是否可执行，并查看 run log。
- `workspace/test.txt` 缺失: 运行 smoke test，确认 Guard 是否 allow、Executor 是否执行、Verifier 是否 pass。

