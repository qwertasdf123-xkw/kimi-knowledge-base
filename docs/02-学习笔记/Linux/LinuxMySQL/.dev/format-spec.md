# LinuxMySQL 子章节笔记格式规范（sub-agent 共用）

> 适用：02~08 七个分章节笔记的 sub-agent 写作
> 目标：保证格式统一、YAML 完整、跨模块链接到位

## 1. 文件命名

```
NN-<主题>.md
```
- NN = 两位数字序号（02/03/04/05/06/07/08）
- 主题 = 中文短语，用 "-" 连接（不用空格）

## 2. YAML Frontmatter（必须）

```yaml
---
title: <笔记标题>
desc: <一句话描述>
type: 笔记
module: LinuxMySQL
pdf: <关联 PDF 章节>
pdf_size: <页数或 KB>
scope: <覆盖范围说明>
status: 完成
---
```

## 3. 文件结构（标准 11 节）

```
# <标题>

> 一句话心智模型：...

## 目录（可选，超过 5 节时建议）

## §0 心智模型（含 mermaid）

## §1 <核心主题>

## §2 <核心主题>

...

## §N 易错 ×N + 速查表 + 跨模块链接

## §N+1 资源链接

## §N+2 模块历史

最后更新: 2026-08-11
```

## 4. 必须包含的元素

- **mermaid 图** ≥ 3 个（流程图 / 架构图 / 序列图 / 类图）
- **表格** ≥ 5 个（对比表 / 速查表 / 故障 Runbook）
- **代码块** ≥ 10 个（SQL / bash / my.cnf / Python）
- **跨模块链接** ≥ 3 个 `[[LinuxShell]]` `[[Linux存储]]` `[[Linux网络]]` `[[Linux服务与SSH]]` `[[Linux包管理]]` `[[LinuxOpenStack]]`
- **callout**：至少 1 个 `> [!warning]` 或 `> [!info]`
- **字数**：≥ 600 行

## 5. 章节映射（PDF 文本位置）

| 笔记文件 | PDF 文本位置 | 章节 |
|---------|------------|------|
| 01-数据库原理与MySQL概述 | .dev/pdf-text/p001-p013.txt | ch1 |
| 02-MySQL安装与配置 | .dev/pdf-text/p014-p043.txt + p145-p154.txt | ch2 + ch4 |
| 03-SQL语言基础与数据类型 | .dev/pdf-text/p044-p070.txt | ch3 上 |
| 04-数据查询与子查询 | .dev/pdf-text/p071-p100.txt | ch3 中 |
| 05-索引视图存储过程触发器 | .dev/pdf-text/p101-p144.txt | ch3 下 |
| 06-备份与恢复 | .dev/pdf-text/p155-p159.txt | ch5 |
| 07-主从复制与读写分离 | .dev/pdf-text/p160-p175.txt | ch6 |
| 08-MHA高可用集群 | .dev/pdf-text/p176-p196.txt | ch7 |

## 6. 写作要求

1. **基于教材内容，不要瞎编**：所有命令、配置、概念都要在 PDF 文本里有据可查
2. **添加实战注解**：PDF 内容之外，可补充运维实战经验（标注 `> [!tip]`）
3. **代码必须能跑**：SQL 命令、bash 命令、my.cnf 配置要语法正确
4. **故障 Runbook**：每个章节末尾给 1-2 个常见故障 + 排查步骤

## 7. 禁止

- ❌ 虚构命令/参数（PDF 没有的不写）
- ❌ 复制大段教材原文（保留概念，重写表达）
- ❌ 省略 YAML frontmatter
- ❌ mermaid 图语法错误（必须能渲染）
- ❌ 死链（`[[不存在的笔记]]`）

## 8. 输出位置

```
E:\Linux\LinuxMySQL\
├── 00-MySQL学习路线.md         # 主会话写
├── 01-数据库原理与MySQL概述.md   # sub-agent 1
├── 02-MySQL安装与配置.md        # sub-agent 2
├── 03-SQL语言基础与数据类型.md   # sub-agent 3
├── 04-数据查询与子查询.md       # sub-agent 4
├── 05-索引视图存储过程触发器.md  # sub-agent 5
├── 06-备份与恢复.md            # sub-agent 6
├── 07-主从复制与读写分离.md      # sub-agent 7
└── 08-MHA高可用集群.md         # sub-agent 8
```