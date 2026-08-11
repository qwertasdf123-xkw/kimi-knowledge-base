---
project: LinuxMySQL
type: spec
status: draft
date: 2026-08-11
maturity: L1
---

# LinuxMySQL 笔记整理 Spec

## 1. 目标

将 `D:/夸克/夸克下载/mysql教材.pdf`（196 页 / 7 一级章节 / 158 子章节）系统化整理为 Obsidian vault 的 **第 33 个模块** `LinuxMySQL`，供后续运维 / DBA / 后端开发查阅。

## 2. 范围

**包含**：
- 数据库原理（关系模型 / E-R / SQL 标准）
- MySQL 安装与客户端（5.x + 8.x）
- SQL 语言（DDL / DML / DQL / DCL）
- 数据类型、运算符、函数
- 表 / 索引 / 视图 / 存储过程 / 触发器
- 备份与恢复（mysqldump / xtrabackup / binlog）
- 主从复制与读写分离
- MHA 高可用

**不包含**：
- MySQL 8.x 新特性详解（JSON 表 / 窗口函数等，PDF 未涉及）
- InnoDB 存储引擎源码（PDF 浅尝辄止）
- 第三方工具（Amoeba / ProxySQL，PDF 仅提及）
- 云数据库（RDS / PolarDB，超出教材范围）

## 3. 形态

参考 `E:/Linux/LinuxOpenStack/` 模板（7 分章节 + 主笔记 + canvas）：

```
E:\Linux\LinuxMySQL\
├── LinuxMySQL.md              # 主笔记（≥800 行 / YAML 7 字段）
├── LinuxMySQL.canvas          # 模块 canvas（3 节点 2 边起步）
├── .dev/
│   ├── spec.md
│   ├── STATUS.md
│   ├── decision-log.md
│   ├── gate-report-*.md
│   └── subagents/             # sub-agent 输出暂存
├── 00-MySQL学习路线.md        # 路线 + 资料 + 复习题
├── 01-数据库原理与MySQL概述.md  # PDF ch1 + ch2.1
├── 02-MySQL安装与配置.md       # PDF ch2.2-2.4 + ch4 源码
├── 03-SQL语言基础与数据类型.md  # PDF ch3 前段
├── 04-数据查询与子查询.md      # PDF ch3 中段
├── 05-索引视图存储过程触发器.md # PDF ch3 后段
├── 06-备份与恢复.md           # PDF ch5
├── 07-主从复制与读写分离.md     # PDF ch6
└── 08-MHA高可用集群.md         # PDF ch7
```

镜像：
```
E:\notes\
├── linux-mysql.md             # MD5 == LinuxMySQL.md
└── linux-mysql.canvas         # MD5 == LinuxMySQL.canvas
```

## 4. 章节拆分映射

| 笔记文件 | PDF 章节 | 主题 | 预估页数 | 预估行数 |
|---------|---------|------|---------|---------|
| 00 学习路线 | 全部导览 | 路线图 + 7 章摘要 | — | ~400 |
| 01 数据库原理与 MySQL 概述 | ch1 (1-13) | 数据库基础 + MySQL 历史 | 13 | ~1100 |
| 02 MySQL 安装与配置 | ch2.2-2.4 + ch4 (14-43 + 145-154) | 安装 + 实例 + 客户端 + 源码 | 40 | ~1400 |
| 03 SQL 语言基础与数据类型 | ch3 上段 (44-70) | DDL + DML + 数据类型 + 运算符 + 函数 | 27 | ~1300 |
| 04 数据查询与子查询 | ch3 中段 (71-100) | SELECT / WHERE / GROUP / JOIN / 子查询 | 30 | ~1300 |
| 05 索引视图存储过程触发器 | ch3 下段 (101-144) | 索引 / 视图 / 约束 / 存储过程 / 函数 / 触发器 | 44 | ~1500 |
| 06 备份与恢复 | ch5 (155-159) | mysqldump / binlog / xtrabackup | 5 | ~600 |
| 07 主从复制与读写分离 | ch6 (160-175) | 复制原理 + 部署 + 读写分离 | 16 | ~1000 |
| 08 MHA 高可用集群 | ch7 (176-196) | MHA 架构 + 部署 + Failover | 21 | ~1100 |
| **合计** | 196 页 | — | 196 | **~8700 行** |

## 5. 质量标准

- ✅ 主笔记 `LinuxMySQL.md` ≥ 800 行（含跨章节引用 + 速查表 + 故障 Runbook + 学习路线）
- ✅ 分章节笔记 ≥ 600 行 / 章
- ✅ 每个 .md 含 YAML frontmatter 7 字段
- ✅ mermaid 图 ≥ 30 个（架构图 / 流程图 / 拓扑图）
- ✅ 跨模块引用：`[[LinuxShell]]` `[[Linux存储]]` `[[Linux网络]]` `[[Linux服务与SSH]]` `[[Linux包管理]]` 等
- ✅ 关键命令速查（按类别）
- ✅ 故障 Runbook（备份恢复 / 主从故障 / MHA 切换）
- ✅ 镜像同步：主会话 cp + md5sum 校验

## 6. 资源

| 资源 | 位置 | 说明 |
|------|------|------|
| MySQL 教材 PDF | `D:\夸克\夸克下载\mysql教材.pdf` | 11 MB / 196 页 / 主源 |
| MySQL 安装 PDF | `D:\夸克\夸克下载\mysql安装.pdf` | 3 MB / 20 页 / 补充 |
| MySQL 5.7.17 | `D:\夸克\夸克下载\mysql-5.7.17.tar.gz` | 二进制包参考 |
| MySQL 8.4.6 | `D:\夸克\夸克下载\mysql-8.4.6-winx64.zip` | Windows 二进制 |
| MHA Manager | `D:\夸克\夸克下载\mha4mysql-manager-0.57.tar.gz` | 高可用参考 |
| MHA Node | `D:\夸克\夸克下载\mha4mysql-node-0.57.tar.gz` | 高可用参考 |
| Amoeba | `D:\夸克\夸克下载\amoeba-mysql-binary-2.2.0.tar.gz` | 读写分离参考 |

## 7. 风险

| 风险 | 应对 |
|------|------|
| PDF 中文 GBK 编码乱码 | PyMuPDF 提取时强制 cp936 解码，或用 pdfplumber |
| 内容覆盖 vs 深度取舍 | 教材全覆盖（用户已选），不删减章节 |
| 笔记过长导致主笔记超 800 行 | 主笔记仅放索引 + 速查 + 故障 Runbook，详细内容放分章节 |
| 镜像 MD5 不一致 | 主会话亲自执行 cp + md5sum 比对，参考 2026-07-16 RAID 教训 |

## 8. 完成定义

- [ ] 9 个 md 文件 + 1 个 canvas 已生成
- [ ] 主笔记 ≥ 800 行
- [ ] YAML frontmatter 完整（每个 md 7 字段）
- [ ] mermaid ≥ 30 个
- [ ] 镜像 MD5 校验通过
- [ ] `E:/Linux/Linux总览.canvas` 接入新模块
- [ ] 临时目录清理