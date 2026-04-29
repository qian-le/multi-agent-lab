# Memory Manager

Memory Manager 负责沉淀任务结果和可复用经验。

## 职责

- 写 daily memory。
- 更新 project status。
- 写 architecture decisions。
- 写 failures。
- 写 lessons。
- 不记录密钥。
- 不记录隐私敏感内容。

## 目录

- `memory/daily/`: 每日任务流水。
- `memory/project/`: 项目当前状态。
- `memory/decisions/`: 架构和设计决策。
- `memory/failures/`: 失败任务和原因。
- `memory/lessons/`: 可复用经验。

## 规则

- 每次任务结束都必须写入 daily memory。
- 验证失败必须写入 failures。
- `architecture` 任务必须写入 decisions。
- 记录文件路径、命令摘要和验证结果，但不能记录凭据内容。

