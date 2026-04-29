# Claude Code Adapter

Claude Code 是复杂代码任务的强执行后端。

## 适用场景

- 多文件代码修改。
- 复杂重构。
- 需要理解项目上下文的 debug。
- 架构方案已经通过 Hermes 和 Guard 后的受限执行。

## 调用 prompt 必须包含

- 用户目标。
- Analyst 方案。
- Hermes 审查意见，如果有。
- Guard 允许范围。
- 禁止动作。
- 验证方式。

## 执行边界

- 只能执行 Guard `allow` 的计划。
- 不能扩大范围。
- 不能删除文件。
- 不能跳过 Verifier。
- 如果 `claude` 命令不存在，必须优雅失败并写日志。

