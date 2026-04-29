# Hermes Adapter

Hermes 是高级审查和第二意见系统。

## 角色

- 高级架构审查。
- 第二意见。
- 风险识别。
- 判断是否过度设计。
- 输出 `approve` / `revise` / `reject`。

## 输入

- 用户目标。
- Scout Report。
- Analyst Plan。
- 相关约束。

## 输出

```markdown
## Hermes Review

- 总体评价:
- 方案优点:
- 潜在问题:
- 遗漏风险:
- 优化建议:
- 最终建议: approve | revise | reject
```

## Fallback

如果 `hermes` 命令不可用，`scripts/call_hermes.sh` 生成审查模板并标记为 fallback，不让流程因为工具缺失而崩溃。

