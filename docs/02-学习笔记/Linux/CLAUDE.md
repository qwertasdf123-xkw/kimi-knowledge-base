# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

这是一个 **Obsidian 笔记 vault**（非代码仓库），内容为 Linux 系统管理 + 网络基础的学习笔记，基于 CentOS-7 系列 PDF 教材整理。

## 目录结构约定

```
E:\Linux\
├── Linux总览.canvas          ← 根级全景图，28 个模块的依赖关系
├── <主题目录>/               ← 每个模块一个目录
│   ├── <主题目录>.canvas     ← 模块 canvas（命名 = 目录名）
│   ├── xxx.md                ← 笔记文件
│   └── ...
├── .claude/commands/         ← 自定义 slash 命令
└── .claude/settings.local.json
```

**核心规则：子目录 `<Dir>/` 必须有一个 `<Dir>.canvas` 才算模块健康。** 如 `LinuxShell/shell.md` ↔ `LinuxShell/LinuxShell.canvas`。

## 笔记元数据规范

每个 .md 文件顶部有 YAML frontmatter：

```yaml
---
title: ...       # 笔记标题
desc: ...        # 一句话描述
type: 笔记       # 固定值
module: ...      # 所属模块目录名
pdf: ...         # 来源 PDF 文件名
pdf_size: ...    # PDF 大小
scope: ...       # 覆盖范围说明
status: 完成     # 完成 | 进行中 | 占位
---
```

内部链接使用 Obsidian 原生语法 `[[#section-id]]`。

## 镜像规范

每个模块的产物必须同步镜像到 `E:\notes\`，便于跨设备查阅和备份：

```
E:\Linux\<模块>\                  主仓库（Obsidian vault 主目录）
├── <模块>.md                     主笔记（≥800 行 + YAML frontmatter）
└── <模块>.canvas                 模块画布（3 节点 2 边）

E:\notes\                         镜像
├── linux-<模块名>.md             主笔记镜像（与主仓库 MD5 一致）
└── linux-<模块名>.canvas         画布镜像（与主仓库 MD5 一致）
```

**强制规范**（Agent 完成标准必查项）：

1. ✅ `E:\Linux\<模块>\<模块>.md` 已生成且 ≥800 行
2. ✅ `E:\Linux\<模块>\<模块>.canvas` 已生成
3. ✅ `E:\notes\linux-<模块名>.md` 镜像已生成且 **MD5 一致**
4. ✅ `E:\notes\linux-<模块名>.canvas` 镜像已生成且 **MD5 一致**
5. ✅ YAML frontmatter 完整
6. ✅ 临时目录已清理

**历史教训**：

- 2026-07-16 第二批 RAID agent 镜像 bug：仅复制 20% 内容到 `E:\notes\linux-raid.md`，由主会话 `cp` 修复
- 2026-07-16 第二批 canvas 镜像缺失：8 个模块（DHCP/NFS/RAID/iSCSI/Nginx/Web实战/LVS/Keepalived）缺失 `.canvas` 镜像，由主会话 `cp` 修复
- 教训：Agent prompt 必须显式检查 **`.md` 和 `.canvas` 两个文件的 MD5**，缺一不可

## 模块总览（31 个）

| 类别 | 模块 |
|------|------|
| Linux 内核/基础 | Linux目录(10) Linux文本处理(7) LinuxShell(3) Linux编辑器 Linux用户权限 Linux包管理 |
| Linux 服务/运维 | Linux进程与负载 Linux服务与SSH Linux计划任务 Linux日志与时间 Linux文件传输 LinuxDNS LinuxDHCP LinuxNFS LinuxNginx LinuxWeb实战 LinuxLVS LinuxKeepalived **LinuxRedis** **LinuxKVM** **Linux网络工具** |
| Linux 底层/安全 | Linux存储 Linux启动原理 LinuxSELinux Linux防火墙 LinuxRAID LinuxiSCSI |
| 网络 | Linux网络 网络基础原理(2) 路由与VLAN 华为VRP |

括号内为笔记数（>1 的标注）。完整依赖关系见 `Linux总览.canvas`。

## 可用命令

- `/vault-audit [--fix] [--empty] [--help]` — 扫描 vault 健康度，检测孤儿笔记、空文件、模块覆盖率
- `claude /init` — 重新生成此 CLAUDE.md

## 操作注意事项

- 笔记文件使用 **绝对路径**（含 `E:\Linux\` 前缀）
- 不要直接删除 0 字节 .md 文件——它们可能是占位符，指向其他模块的真身
- Canvas 文件是 JSON，编辑时注意不要破坏 `nodes`/`edges` 结构
- 排除目录：`.obsidian/` `.claude/` `.git/`
