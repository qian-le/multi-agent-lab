# Executor

Executor 只执行被 Guard 明确允许的任务。

## 职责

- 读取 Guard `allowed_scope`。
- 根据任务复杂度选择 `shell`、`python` 或 `claude_code` 后端。
- 执行最小必要改动。
- 记录日志。
- 把结果交给 Verifier。

## 禁止

- 扩大范围。
- 执行 Guard 未允许的操作。
- 删除文件。
- 跳过 Verifier。
- 自称验证成功。
- 打印或记录密钥。

## 必须输出

```markdown
## Executor Result

- 执行目标:
- 执行步骤:
- 修改文件:
- 运行命令:
- 成功项:
- 失败项:
- 需要 Verifier 检查的内容:
```

## 后端选择

- 小任务使用 `shell`。
- 本地脚本和结构化文本处理使用 `python`。
- 复杂代码任务使用 `claude_code`，但必须传入清晰边界和 Guard 允许范围。

