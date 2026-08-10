# AGENTS.md

本文件是 AI Agent 进入本仓库的必读指南。任何 Agent（Kimi 主会话、Kimi Work 执行端、Claude Code 等）开始工作前先读本文件，再读 `docs/02-学习笔记/Linux/CLAUDE.md` 的笔记规范。

## 项目是什么

「我们的 Kimi 知识库」——一体四面的统一知识库：

| 模块 | 形态 | 位置 |
| --- | --- | --- |
| 知识浏览 | 网页应用（实时读取本仓库） | https://gsfixhvth5fpg.ok.kimi.link |
| 文档库 | Markdown 源文件 | 本仓库 `docs/` |
| GitHub 仓库 | 唯一权威源 | 本仓库 |
| 技能包 | Kimi .skill | 由主会话打包分发，索引随模块结构变化更新 |

## 多 Agent 协作协议

**对话记忆不互通，一切上下文以共享产物为准。**

- **主会话**（Kimi 项目对话）：架构演进、网页功能开发、技能包打包、规则制定
- **执行端**（Kimi Work / 其他编码 Agent）：笔记上传、vault 同步、内容整理入库、仓库日常维护
- **任务交接**：跨会话的协作任务通过 GitHub Issues 发起和追踪；每次任务结束更新本文件「最新状态」一节

## 工作规则

1. 内容修改直接推送到本仓库 main 分支，无需通知主会话重新构建网页（网页实时拉取）
2. **推送 `docs/` 变更时必须同步更新根目录 `manifest.json`**（网页靠它获取文件列表），生成命令：

   ```bash
   git -c core.quotepath=false ls-files docs | grep '\.md$' | sort | python3 -c "import sys,json;fs=[l.strip() for l in sys.stdin];print(json.dumps({'updated':'$(date +%F)','count':len(fs),'files':fs},ensure_ascii=False,indent=2))" > manifest.json
   ```

3. 严格遵守 `docs/02-学习笔记/Linux/CLAUDE.md`：frontmatter 规范、模块目录结构、不删除 0 字节占位文件、canvas JSON 的 `nodes`/`edges` 结构保持完整
4. `tools/`（vault-maintain.sh、fix-frontmatter.py、vaults.conf）是既有维护工具，保持可用，改动需先开 issue
5. 结构级变更（新增分区、改 frontmatter 字段、改 tools/ 行为、调整目录约定）**不要直接实施**——先开 issue 描述方案，由主会话评审
6. 提交信息使用中文，格式：`<动作> <范围>：<说明>`，如 `导入 LinuxRedis 模块笔记`

## 仓库结构

```
├── AGENTS.md                 ← 本文件
├── manifest.json             ← 知识文件清单（网页拉取入口，随 docs 变更更新）
├── README.md
├── docs/
│   ├── 01-工作项目/           ← 复盘模板、会议纪要规范、周报框架
│   ├── 02-学习笔记/
│   │   ├── *.md              ← 学习方法笔记
│   │   └── Linux/            ← Linux vault（30+ 模块，规范见其 CLAUDE.md）
│   └── 03-Kimi使用技巧/       ← 提示词模板、深度研究技巧
└── tools/                    ← vault 自动维护工具
```

笔记 frontmatter 规范：`title / desc / type / module / pdf / pdf_size / scope / status`，内部链接用 Obsidian 语法 `[[#section-id]]`。

## 自检

提交推送后，打开 https://gsfixhvth5fpg.ok.kimi.link 确认新内容可见。若网页未显示：检查 manifest.json 是否已更新并包含新文件；浏览器硬刷新（Ctrl/Cmd+Shift+R）。

## 最新状态

> 由执行端在每次任务结束后更新。

- 2026-08-10：新增 LinuxOpenStack 模块（8 笔记 / 8322 行 / 57 mermaid / ~310 跨链 / 业务案例：电商云平台 ECShop）；Linux总览.canvas 接入（+1 节点 +4 边）；CLAUDE.md 模块清单更新（31→32）；manifest.json 同步至 79 条目（commit 6af1be9）
- 2026-08-09：新增 Linux/kubernetes/10-K8s安装配置手册.md（13 章 / 1622 行 / 2 mermaid / 14 Runbook 决策树）；kubernetes.canvas 增加第 10 节点（21→23 节点 / 20→22 边）；manifest.json 同步至 71 条目（commit 89767c0）
- 2026-08-07：新增 Linux网络工具模块（1525 行）；引入 manifest.json 清单机制（解决 CDN 缓存导致网页不更新）；AGENTS.md 增加清单更新规则
- 2026-08-05：仓库初始化；导入 Linux vault 30+ 模块；tools/ 自动同步上线；网页改为实时拉取架构；技能包 v2（含 Linux 索引）发布
- 待办：（暂无）
