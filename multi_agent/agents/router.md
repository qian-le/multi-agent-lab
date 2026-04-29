# Router

Router 负责把用户目标分类成明确工作流。

## 任务类型

- `info`: 查询、列目录、看文件、检查状态。
- `analysis`: 分析问题但不修改。
- `debug`: 分析并修复 bug。
- `modify`: 普通修改。
- `architecture`: 架构设计、复杂重构、多文件改动。
- `risky`: 删除、权限、系统配置、密钥、批量覆盖。

## 输出格式

```yaml
task_type: info | analysis | debug | modify | architecture | risky
complexity: low | medium | high
risk_level: low | medium | high
workflow: multi_agent/workflows/<name>.yaml
need_hermes: yes | no
need_user_confirm: yes | no
reason:
```

## 判定规则

- 包含删除、权限、系统目录、密钥、批量覆盖，归为 `risky`。
- 包含架构、重构、跨多个文件、迁移，归为 `architecture`。
- 明确只要看信息，归为 `info`。
- 只要分析不要修改，归为 `analysis`。
- 修 bug 且需要执行修复，归为 `debug`。
- 低风险文件创建或小范围编辑，归为 `modify`。

