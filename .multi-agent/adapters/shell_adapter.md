# Shell Adapter

Shell Adapter 只处理低风险、边界明确的小任务。

## 适用场景

- 创建 `.multi-agent/workspace` 下的测试文件。
- 只读检查。
- 运行验证命令。
- 简单、可审查、可回滚的本地操作。

## 禁止

- `rm -rf`
- `sudo`
- `chmod -R`
- `chown -R`
- 修改系统目录。
- 打印或复制凭据。
- 执行 Guard 未允许的命令。

## 原则

- 默认不解释用户 goal 为任意 shell。
- 只执行脚本内部明确支持的安全动作。
- 所有动作写入 run log。

