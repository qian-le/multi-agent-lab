# OpenClaw Adapter

OpenClaw 是总调度入口。`.multi-agent` 不破坏已有 `.openclaw/`，只通过配置引用它。

## 角色

- 接收用户目标。
- 选择 Router 和 workflow。
- 调用子 agent。
- 汇总状态。
- 触发 Guard、Verifier、Memory。

## 集成边界

- `.openclaw/` 保持为现有运行时目录。
- `multi_agent/config.yaml` 中的 `project.openclaw_config` 指向 `.openclaw`。
- `scripts/call_openclaw.sh` 只做受限调用或生成 fallback 调度模板。

## 禁止

- 自动修改 `.openclaw/credentials`。
- 打印 OpenClaw 内部凭据。
- 绕过 Guard 直接执行。

