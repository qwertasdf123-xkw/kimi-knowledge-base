---
description: 多 vault 知识库全量维护（健康检查 + 镜像 + 同步到 kimi-knowledge-base）
allowed-tools: Bash(bash *)
---

执行多 vault 全量维护脚本并接管后续处理：

!`bash /e/kimi-knowledge-base/tools/vault-maintain.sh --all 2>&1`

请根据上面的脚本输出完成以下工作：

1. **汇报**：按 vault 分组，用表格向用户汇总三部分结果——
   - 健康检查：各 vault 模块 canvas 完整性、frontmatter 缺失清单、0 字节占位文件
   - 镜像：MD5 校验通过/失败的文件清单（.md 和 .canvas 分开列）
   - 知识库同步：各 vault 的 diff 验证结果、是否产生新提交（给出 commit hash）、推送状态
2. **处置**：
   - 若有 [错误] 项：逐条分析原因，给出修复建议，**征得用户同意后再动手修复**
   - 若有 [警告] 项：列出并说明影响，由用户决定是否处理
   - 0 字节 .md 是占位符（可能指向其他模块的真身），**不要擅自删除**
   - Canvas 文件是 JSON，修复时注意保留 `nodes`/`edges` 结构
3. **参数说明**（用户可在命令后追加）：
   - `--vault 名称` 只维护指定 vault（可多个）；`--audit` 只检查；`--mirror` 只镜像；`--sync` 只同步；`--no-push` 提交但不推送
4. **接入新 vault**：编辑 `/e/kimi-knowledge-base/tools/vaults.conf`，按注释格式加一行 `名称|路径|镜像目录|KB子目录`，然后跑一次 `--audit` 验证
