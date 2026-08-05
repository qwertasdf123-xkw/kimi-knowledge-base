---
title: Linux RAID 实战 — mdadm 全流程 + 故障模拟 + 性能对比
desc: 基于随堂笔记-0409 (1).md（18KB / 595 行 / RAID + LVM + SELinux）的 RAID 独立模块。专注 RAID 0/1/5 完整 mdadm 流程（创建/查看/格式化/挂载/热备/故障/扩容/重构），区别于 [[Linux存储]] 仅覆盖基础。
type: 笔记
module: LinuxRAID
pdf: 随堂笔记-0409.md
pdf_size: 18 KB
scope: RAID 原理 + mdadm 实战 + 故障恢复 + 扩容 + 重构 + 性能
status: 完成
---

# Linux RAID 实战 — mdadm 全流程

> **范围**：本模块是 **RAID 独立专题**。[[Linux存储]] 已覆盖基础理论（§11-§14），本文专注：
> - **完整 mdadm 命令实战**（create / detail / add / fail / remove / grow / assemble）
> - **随堂笔记案例的真实复盘**（raid0/raid1/raid5 三个完整流程 + 扩容 + 重构）
> - **故障模拟 + 热备自动顶替 + 重建过程**
> - **硬件 RAID vs 软件 RAID 决策**
> - **监控 + 性能基准**
>
> **适用**：CentOS-7 / RHEL 系，`mdadm` + 内核 `md` 模块。

## 目录

- [[#§0 心智模型：RAID = 把多块盘组合成超级盘]]
- [[#§1 RAID 是什么：Redundant Array of Independent Disks]]
- [[#§2 RAID 级别对比表：0/1/5/6/10]]
- [[#§3 实现方式：软 RAID / 硬 RAID / 软硬混合]]
- [[#§4 RAID 0：条带 + 性能翻倍 + 零冗余]]
- [[#§5 RAID 1：镜像 + 100% 冗余 + 容量减半]]
- [[#§6 RAID 5：单盘校验 + (n-1)/n 容量]]
- [[#§7 RAID 6：双盘校验 + 大容量必选]]
- [[#§8 RAID 10（1+0）：数据库首选]]
- [[#§9 RAID 01 vs RAID 10：重建失败概率]]
- [[#§10 mdadm 工具安装与简介]]
- [[#§11 mdadm 核心命令速查]]
- [[#§12 RAID 0 完整实战（2 盘）]]
- [[#§13 RAID 1 完整实战（2 盘 + 热备 + 故障）]]
- [[#§14 RAID 5 完整实战（4 盘 + 热备 + 扩容 + 重构）]]
- [[#§15 配置文件 /etc/mdadm.conf 与开机装配]]
- [[#§16 /proc/mdstat 实时监控]]
- [[#§17 RAID 扩容：--grow 与 xfs_growfs]]
- [[#§18 RAID 重构：--assemble 恢复]]
- [[#§19 故障模拟完整流程总结]]
- [[#§20 RAID 与 LVM 配合]]
- [[#§21 硬件 RAID vs 软件 RAID 决策]]
- [[#§22 监控与告警：mdadm --monitor + smartd]]
- [[#§23 性能基准：dd + fio 测顺序/随机读写]]
- [[#§24 随堂笔记实战案例复盘]]
- [[#§25 易错点 ×12]]
- [[#§26 速查表]]
- [[#§27 面试 6 大追问]]
- [[#§28 跨模块链接]]

---

## §0 心智模型：RAID = 把多块盘组合成超级盘

```
        RAID = 1 个逻辑大硬盘
              ╱      │       ╲
       性能提升   冗余保护   容量叠加

单块硬盘的三大局限：
  1. 容量 = 1 块盘（要更大 = 买更大盘）
  2. 性能 = 1 块盘（更快盘 = 买 SSD）  
  3. 可靠性 = 1 块盘（坏了 = 数据丢）

RAID 的核心思路：
  把 N 块"小盘"按某种策略组织起来，
  对操作系统呈现为 1 块"逻辑盘"，
  同时获得 容量/性能/冗余 中的某几种能力。

RAID 不是备份！
  RAID 抗的是"单盘物理故障"，
  不抗"误删除 / 病毒 / 火灾 / 整个机房断电"，
  这些场景仍需要独立备份策略（tar / rsync / 云备份）。
```

**三个目标 + 三大技术**：

| 目标 | 实现技术 | 典型 RAID |
|---|---|---|
| 容量叠加 | 条带（striping） | RAID 0 |
| 性能提升 | 条带 + 多盘并行 | RAID 0 / 10 |
| 冗余保护 | 镜像（mirror）| RAID 1 |
| 性能 + 冗余（性价比） | 校验（parity） | RAID 5 / 6 |
| 高性能 + 高可靠 | 镜像+条带 | RAID 10 |

---

## §1 RAID 是什么：Redundant Array of Independent Disks

```
RAID 历史：
  1988 年：David A. Patterson 等人发表论文
  最初定义 = Redundant Array of Inexpensive Disks（廉价）
  后来改 = Redundant Array of Independent Disks（独立）
  （磁盘便宜了，"廉价"说法过时）

核心思想：
  通过"数据条带化 / 镜像 / 校验"三类技术，
  将多块物理盘组织成一个逻辑盘，
  实现性能/可靠性/容错的提升。
```

**为什么需要 RAID？**

- **性能**：`/dev/sdb` 单盘 IOPS≈200（机械盘），RAID 0 的 4 盘条带理论 800 IOPS
- **可靠性**：单盘年故障率约 2-5%，5 块盘组成 RAID 5 = 仍允许 1 块坏
- **容量**：单盘 20G → RAID 0 的 2 盘 = 40G；RAID 5 的 4 盘 = 60G
- **成本**：用 5 块 1T 普通盘组建 RAID 5 = 4T 容量 + 容错，比买单块 4T 企业盘便宜

**典型应用场景**：

| 场景 | 推荐 RAID | 原因 |
|---|---|---|
| 数据库主库（OLTP） | **RAID 10** | 性能 + 可靠性双高 |
| 文件服务器 / 备份 | **RAID 5 / 6** | 容量大 + 成本低 |
| 系统盘 / 引导盘 | **RAID 1** | 镜像冗余 |
| 临时数据 / 缓存 | **RAID 0** | 极限性能，不在乎丢 |
| 大容量归档 | **RAID 6** | 双校验扛 2 块故障 |

---

## §2 RAID 级别对比表：0/1/5/6/10

| RAID | 中文名 | 最少盘数 | 容量利用率 | 冗余能力 | 读性能 | 写性能 | 典型用途 |
|---|---|---|---|---|---|---|---|
| **RAID 0** | 条带 | 2 | **100%** | ❌ 无（坏 1 块全完） | 最高 | 最高 | 临时数据 / 缓存 |
| **RAID 1** | 镜像 | 2 | 50% | ✅ 坏 1 块 | 快 | 慢（写两遍） | 系统盘 |
| **RAID 5** | 单校验 | 3 | (n-1)/n | ✅ 坏 1 块 | 快 | 中（要算校验） | **企业最常用** |
| **RAID 6** | 双校验 | 4 | (n-2)/n | ✅ 坏 2 块 | 快 | 慢 | 大容量 / 归档 |
| **RAID 10** | 1+0 混合 | 4 | 50% | ✅ 每组可坏 1 块 | 最高 | 快 | **数据库首选** |

**容量计算公式**（每盘 20G 为例）：

```
RAID 0:  N × 盘容量     → 4 × 20G = 80G
RAID 1:  N/2 × 盘容量   → 4 × 20G = 40G（每对镜像只用 1 份）
RAID 5:  (N-1) × 盘容量 → 4 × 20G = 60G（牺牲 1 块校验）
RAID 6:  (N-2) × 盘容量 → 6 × 20G = 80G（牺牲 2 块校验）
RAID 10: N/2 × 盘容量   → 4 × 20G = 40G
```

---

## §3 实现方式：软 RAID / 硬 RAID / 软硬混合

```
按"是否依赖专用硬件芯片"分 3 类：
```

| 类型 | RAID 卡芯片 | I/O 处理芯片 | CPU 占用 | 性能 | 成本 | 适用 |
|---|---|---|---|---|---|---|
| **软 RAID** | 无 | 无 | **高**（内核 md 模块） | 差 | **0** | 学习 / 测试 / 中小应用 |
| **硬 RAID** | 有 | 有 | 无 | **最佳** | 高 | 企业生产 |
| **软硬混合** | 有 | 无 | 中 | 中 | 中 | 少数老设备 |

**关键点**：
- **软 RAID**：操作系统通过 **内核 md 模块** 管理，设备是 `/dev/md0` `/dev/md1` …
- **硬 RAID**：操作系统看到的是 RAID 卡"伪造"的设备（`/dev/sda`），**不直接管理底层物理盘**
- **生产环境**：99% 用硬件 RAID 卡（带电池 + 缓存，性能远超软 RAID）
- **学习 / 虚拟机 / 容器环境**：软 RAID 足够

**Linux 软 RAID 的本质**：

```
软 RAID 是"内核模块 + 用户态工具"的组合：

内核模块：
  drivers/md/raid0.c / raid1.c / raid5.c / raid10.c ...
  → 负责实际数据分布 / 校验计算 / 故障重建
  → 注册为块设备 /dev/mdX

用户态工具：
  mdadm (multiple devices admin)
  → 创建 / 查询 / 管理 / 监控 RAID 阵列
  → 生成 / 读取 /etc/mdadm.conf 配置

配置文件：
  /etc/mdadm.conf
  → 记录 RAID UUID + 成员盘（开机自动装配用）
  → 由 mdadm --detail --scan 生成
```

---

## §4 RAID 0：条带 + 性能翻倍 + 零冗余

```
RAID 0 = Striping（条带化）

写入逻辑：
  1 个文件 → 切成 N 个 chunk → 写到 N 块盘
  例如 4 块盘，文件 A = A1 A2 A3 A4
       sdb    →  A1
       sdc    →  A2
       sdd    →  A3
       sde    →  A4

读取逻辑：4 块盘并行读，再拼回来 → 理论速度 4 倍

但：任何 1 块盘坏 = 全部数据丢（无法找回）
```

**优缺点**：

| 优点 | 缺点 |
|---|---|
| ✅ 容量 = N × 盘容量（100% 利用率） | ❌ **零冗余**，坏 1 块全完 |
| ✅ 读/写性能最佳（N 倍带宽） | ❌ 不能加新盘扩展（chunk 大小已定） |
| ✅ 实现简单 | ❌ 不能加热备盘（无意义） |
| | ❌ 不能容错 |

**适用**：
- 临时数据处理（视频剪辑临时文件）
- 缓存盘（牺牲安全性换速度）
- 性能测试 / 基准对比

**实验验证**（本节仅原理；§12 有完整 mdadm 实战）：

```bash
# 验证：RAID 0 不能加新盘（已经条带化，新盘无位置）
[root@centos7 ~]# mdadm --add /dev/md0 /dev/sdd
mdadm: add new device failed for /dev/sdd as 2: Invalid argument

# 验证：RAID 0 单盘坏即阵列失效
[root@centos7 ~]# mdadm --fail /dev/md0 /dev/sdc
mdadm: Cannot remove /dev/sdc from /dev/md0, array will be failed.
```

---

## §5 RAID 1：镜像 + 100% 冗余 + 容量减半

```
RAID 1 = Mirroring（镜像）

写入逻辑：
  sdb    →  A1 A2 A3 A4 ...
  sdc    →  A1 A2 A3 A4 ...  ← 完全相同的副本
       两块盘数据完全一样

读取逻辑：可从任一盘读，**读性能 ≈ 2 倍**（两盘并行）

故障时：坏 1 块没关系，另一块仍在 → 自动降级运行
       可加 热备盘 → 故障后自动顶替 + 重建
```

**优缺点**：

| 优点 | 缺点 |
|---|---|
| ✅ **100% 冗余**（坏 1 块数据不丢） | ❌ 容量 = 50%（N 块只用 N/2） |
| ✅ 读性能提升（多盘并行读） | ❌ 写性能 2 倍开销（写两遍） |
| ✅ 重建简单（直接拷贝） | ❌ 加盘不增容量（仍是单盘大小） |
| ✅ 适合做 `/boot` 系统盘 | ❌ 大容量成本高 |

**RAID 1 的核心价值是冗余，不是扩容**。即使加新盘，阵列容量仍 = 单盘容量。

**实验验证**：

```bash
# 2 块 20G 盘 → RAID 1 → /dev/md1 容量 = 20G（不是 40G）
# 即便后续加 sdd（热备），可用空间仍是 20G
```

---

## §6 RAID 5：单盘校验 + (n-1)/n 容量

```
RAID 5 = Striping + 单校验（Distributed Parity）

写入逻辑（以 4 块盘为例）：
  Stripe 1: A1 A2 A3 Ap   (Ap = A1 XOR A2 XOR A3)
  Stripe 2: B1 B2 Bp B3   (Bp = B1 XOR B2 XOR B3)
  Stripe 3: C1 Cp C2 C3   (Cp = C1 XOR C2 XOR C3)
  Stripe 4: Dp D1 D2 D3   (Dp = D1 XOR D2 XOR D3)

         ↑ 校验块"轮转"分布在每块盘（不集中）！

读取逻辑：
  单盘读 → 直接读
  整条读 → 从多盘并行读
  损坏读 → 用剩余数据 + 校验 XOR 反推

故障恢复：
  坏 1 块 → 用剩余 3 块数据 + 校验 XOR 反推坏盘数据 → 重建
  重建完后 → 恢复正常（如果加了热备，热备会接管）
```

**优缺点**：

| 优点 | 缺点 |
|---|---|
| ✅ 容量 (n-1)/n（4 块 20G = 60G，只牺牲 1 块） | ❌ 写性能差（每次写要算校验） |
| ✅ 容错 1 块 | ❌ 重建期间再坏 1 块 = 数据全丢 |
| ✅ 读性能近 N 倍 | ❌ 大容量场景 RAID 6 替代 |
| ✅ **企业最常用** | ❌ 双盘校验缺位（大规模阵列风险） |

**适用**：文件服务器、邮件服务器、共享存储、通用业务。

---

## §7 RAID 6：双盘校验 + 大容量必选

```
RAID 6 = Striping + 双校验（P + Q 不同算法）

与 RAID 5 区别：
  RAID 5: 每条 stripe 1 个校验块（P）→ 容错 1 块
  RAID 6: 每条 stripe 2 个校验块（P+Q）→ 容错 2 块
```

**为什么需要 RAID 6？**

- **重建风险**：大容量盘（>2T）重建时间长（小时级），期间再坏 1 块 = 数据全丢
- **URE 问题**：磁盘有 URE（Unrecoverable Read Error）率约 10^14，8T 盘全盘扫描必遇 URE → RAID 5 重建时遇 URE 即失败
- **RAID 6 双校验**：可扛 URE + 1 块故障同时发生

**优缺点**：

| 优点 | 缺点 |
|---|---|
| ✅ 容错 2 块 | ❌ 容量 (n-2)/n（6 块 20G = 80G） |
| ✅ 大容量场景必选 | ❌ 写性能更差（算 2 次校验） |
| ✅ 抗 URE | ❌ 最少 4 块盘 |
| | ❌ 重建比 RAID 5 更慢 |

**适用**：NAS、SAN、大容量备份、视频存储、归档。

---

## §8 RAID 10（1+0）：数据库首选

```
RAID 10 = 先做 RAID 1（镜像对），再做 RAID 0（条带）

         RAID 0
        ╱       ╲
    RAID 1      RAID 1
    ╱    ╲      ╱    ╲
  sdb   sdc    sdd   sde
  (A镜像对)    (B镜像对)

数据写入 A：
  sdb ← A1
  sdc ← A1  (镜像)

数据写入 B：
  sdd ← B1
  sde ← B1  (镜像)

A B 写入到不同"条带" → 多对镜像并行写
```

**优缺点**：

| 优点 | 缺点 |
|---|---|
| ✅ **性能 + 可靠性双高** | ❌ 容量 50%（最贵） |
| ✅ 每组镜像可独立坏 1 块 | ❌ 最少 4 块盘 |
| ✅ 重建简单（仅复制镜像） | ❌ 整体坏两同组数据丢 |
| ✅ 写性能好（无校验计算） | |

**适用**：
- **数据库主库**（OLTP 高并发 + 必须可靠）
- 邮件服务器 / ERP
- 高性能 + 高可靠场景

---

## §9 RAID 01 vs RAID 10：重建失败概率

```
RAID 01（先 0 后 1）             RAID 10（先 1 后 0）
   条带                              条带
  ╱     ╲                         ╱     ╲
镜像 A  镜像 B                  镜像对 1  镜像对 2
 ╱╲      ╱╲                    ╱╲       ╱╲
sd sd   sd sd                  sd sd   sd sd
```

**关键区别**：重建时**第二个盘的故障容忍度**完全不同。

```
场景：A 组里坏 1 块，正在用 B 组的镜像数据 + C/D 重建

RAID 01 的情况：
  - A 组已坏 1 块 → A 组"裸奔"
  - 重建期间 B 组再坏 1 块 → **整盘数据丢**（两组都坏）
  - 故障域：2/4 = 50% 概率
  
RAID 10 的情况：
  - 镜像对 1 坏 1 块 → 镜像对 1"裸奔"（还有 1 块正常）
  - 重建期间只要不是镜像对 1 的另一块坏 → 没事
  - 故障域：1/4 = 25% 概率

所以 RAID 10 远比 RAID 01 安全！
（实际生产几乎只用 RAID 10）
```

---

## §10 mdadm 工具安装与简介

**安装**：

```bash
# CentOS / RHEL
[root@centos7 ~]# yum install -y mdadm

# Ubuntu / Debian
[root@ubuntu ~]# apt install -y mdadm
```

**验证**：

```bash
# 看内核是否加载 md 模块
[root@centos7 ~]# lsmod | grep md
raid1                  40960  0
raid0                  24576  0
raid10                 61440  0
raid456               155648  1
md_mod                180224  5 raid1,raid0,raid10,raid456

# 看支持的 RAID 级别
[root@centos7 ~]# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] 
unused devices: <none>
```

**mdadm 角色定位**：

| 角色 | 说明 |
|---|---|
| 创建 | `--create` |
| 管理 | `--add / --fail / --remove / --grow` |
| 监控 | `--monitor`（后台守护进程） |
| 装配 | `--assemble`（开机自动重组用） |
| 查询 | `--detail / --examine` |

---

## §11 mdadm 核心命令速查

```bash
# === 创建 ===
mdadm -C /dev/md0 -l 5 -n 4 /dev/sd{b..e}          # 基本
mdadm -C /dev/md0 -l 5 -n 4 -x 1 /dev/sd{b..f}      # 加 1 热备
mdadm -C /dev/md0 -l 1 -n 2 -c 128 /dev/sd{b,c}     # 指定 chunk
mdadm -C /dev/md0 -l 0 -n 2 --metadata=0.90 /dev/sd{b,c}  # 兼容旧引导

# === 查询 ===
mdadm -D /dev/md0                                   # 详细信息（--detail）
mdadm --detail /dev/md0 | grep -E "Level|State"     # 关键信息
cat /proc/mdstat                                    # 实时状态
lsblk /dev/md0                                      # 设备树映射
mdadm -E /dev/sdb                                   # 看磁盘上的超级块信息

# === 管理 ===
mdadm --add /dev/md0 /dev/sdf                       # 加盘（RAID 1/5/6/10 可）
mdadm --fail /dev/md0 /dev/sdb                      # 标记盘故障
mdadm --remove /dev/md0 /dev/sdb                    # 移除盘
mdadm --grow /dev/md0 -n 5                          # RAID 5 扩容（加 1 块）
mdadm --grow /dev/md0 --size=max                    # 扩容占满所有空间

# === 监控（守护进程） ===
mdadm --monitor --mail=admin@x.com --delay=60 /dev/md0

# === 装配 / 停止 ===
mdadm --assemble /dev/md0 /dev/sd{b..e}             # 装配已存在阵列
mdadm --stop /dev/md0                               # 停止阵列
mdadm --zero-superblock /dev/sdb                    # 清除磁盘上的 RAID 元数据

# === 配置文件生成 ===
mdadm --detail --scan >> /etc/mdadm.conf
```

**关键参数**：

| 参数 | 长参数 | 说明 |
|---|---|---|
| `-C` | `--create` | 创建新阵列 |
| `-l` | `--level` | RAID 级别 0/1/5/6/10 |
| `-n` | `--raid-devices` | 活动盘数 |
| `-x` | `--spare-devices` | 热备盘数 |
| `-c` | `--chunk` | chunk 大小（KB） |
| `-a` | `--add` | 添加成员盘 |
| `-f` | `--fail` | 标记盘故障 |
| `-r` | `--remove` | 移除盘 |
| `-G` | `--grow` | 扩容 |
| `-S` | `--stop` | 停止阵列 |
| `-A` | `--assemble` | 装配阵列 |
| `-D` | `--detail` | 查看详细 |
| `-E` | `--examine` | 看超级块 |

---

## §12 RAID 0 完整实战（2 盘）

### 12.1 实验环境

```
虚拟机准备 6 块 20G 硬盘：
  sdb / sdc / sdd / sde / sdf / sdg
（每块盘独立，无分区、无文件系统）
```

### 12.2 创建 RAID 0

```bash
# 安装工具
[root@centos7 ~]# yum install -y mdadm

# 创建 RAID 0：2 块盘 sdb + sdc
[root@centos7 ~]# mdadm --create /dev/md0 --level 0 --raid-devices 2 /dev/sd{b,c}
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.

# 注释：
#   --level 0       = RAID 0
#   --raid-devices 2 = 2 块盘
#   /dev/sd{b,c}    = sdb 和 sdc 的 bash 简写
```

### 12.3 查看 RAID 0 状态

```bash
# 方式 1：cat /proc/mdstat（内核态）
[root@centos7 ~]# cat /proc/mdstat 
Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] 
md0 : active raid0 sdc[1] sdb[0]
      41908224 blocks super 1.2 512k chunks
      
unused devices: <none>

# 注释：
#   [raid0] [raid1] ... = 内核已加载的 RAID 级别
#   sdc[1] sdb[0]       = 成员盘编号
#   41908224 blocks      = 总容量（约 40G，2 块 20G）
#   super 1.2            = 元数据格式（默认 1.2）
#   512k chunks          = chunk 大小
```

```bash
# 方式 2：mdadm --detail /dev/md0（详细信息）
[root@centos7 ~]# mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Fri Aug  2 17:03:58 2024
        Raid Level : raid0
        Array Size : 41908224 (39.97 GiB 42.91 GB)    ← 总容量 ≈ 2 倍单盘
      Raid Devices : 2                                  ← 活动盘数
     Total Devices : 2
       Persistence : Superblock is persistent
       Update Time : Fri Aug  2 17:03:58 2024
             State : clean                             ← 状态：clean=正常
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0
            Layout : original
        Chunk Size : 512K                              ← chunk 大小
Consistency Policy : none                              ← RAID 0 无校验
              Name : centos7.linux.fun:0  (local to host centos7.linux.fun)
              UUID : afe03287:7cfb8b2e:82844a2e:8f721e04
            Events : 0
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
```

```bash
# 方式 3：看设备映射关系
[root@centos7 ~]# lsblk /dev/md0
NAME MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
md0    9:0    0  40G  0 raid0

[root@centos7 ~]# lsblk /dev/sdb /dev/sdc
NAME  MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
sdb     8:16   0  20G  0 disk  
└─md0   9:1    0  20G  0 raid0 
sdc     8:32   0  20G  0 disk  
└─md0   9:1    0  20G  0 raid0 
```

### 12.4 格式化与挂载 RAID 0

```bash
# 格式化（XFS 文件系统）
[root@centos7 ~]# mkfs.xfs /dev/md0
meta-data=/dev/md0               isize=512    agcount=16, agsize=654720 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=10477056, imaxpct=25
         =                       sunit=128    swidth=256 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=5120, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

# 创建挂载点
[root@centos7 ~]# mkdir -p /raid/raid0

# 挂载
[root@centos7 ~]# mount /dev/md0 /raid/raid0

# 验证
[root@centos7 ~]# df -h /raid/raid0
Filesystem      Size  Used Avail Use% Mounted on
/dev/md0         40G  319M   40G   1% /raid/raid0

# 测试数据写入
[root@centos7 ~]# cp /etc/ho* /raid/raid0
[root@centos7 ~]# ls /raid/raid0/
host.conf  hostname  hosts  hosts.allow  hosts.deny
```

### 12.5 RAID 0 的限制验证

```bash
# 限制 1：不能加新盘（已条带化）
[root@centos7 ~]# mdadm --add /dev/md0 /dev/sdd
mdadm: add new device failed for /dev/sdd as 2: Invalid argument
# ↑ "2: Invalid argument" = 内核拒绝，因为条带布局已固定

# 限制 2：不能标记单盘故障（无冗余，坏 1 块就完）
[root@centos7 ~]# mdadm --fail /dev/md0 /dev/sdc
mdadm: Cannot remove /dev/sdc from /dev/md0, array will be failed.
# ↑ "array will be failed" = 整个阵列会标记为 failed
```

### 12.6 删除 RAID 0

```bash
# 步骤 1：卸载
[root@centos7 ~]# umount /dev/md0

# 步骤 2：停止阵列
[root@centos7 ~]# mdadm --stop /dev/md0
mdadm: stopped /dev/md0

# 步骤 3：清除物理盘上的超级块（恢复为普通磁盘）
[root@centos7 ~]# mdadm --zero-superblock /dev/sd{b,c}
```

---

## §13 RAID 1 完整实战（2 盘 + 热备 + 故障）

### 13.1 创建 RAID 1

```bash
# 创建 RAID 1：2 块盘 sdb + sdc
[root@centos7 ~]# mdadm --create /dev/md1 --level 1 --raid-devices 2 /dev/sd{b,c}
mdadm: Note: this array has metadata at the start and
    may not be suitable as a boot device.  If you plan to
    store '/boot' on this device please ensure that
    your boot-loader understands md/v1.x metadata, or use
    --metadata=0.90
Continue creating array? yes
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md1 started.

# 重要注释：
#   "metadata at the start" 表示 RAID 元数据放在磁盘开头
#   这会影响 /boot 分区（旧引导程序只认元数据在末尾的）
#   若要做 /boot：必须用 --metadata=0.90
#   普通数据盘：忽略警告，直接回 yes
```

### 13.2 查看 RAID 1 状态

```bash
[root@centos7 ~]# mdadm --detail /dev/md1
/dev/md1:
           Version : 1.2
     Creation Time : Fri Aug  2 17:41:25 2024
        Raid Level : raid1
        Array Size : 20954112 (19.98 GiB 21.46 GB)    ← 仅单盘容量（镜像）
     Used Dev Size : 20954112 (19.98 GiB 21.46 GB)
      Raid Devices : 2
     Total Devices : 2
             State : clean, resyncing                 ← "resyncing" 同步中
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0
Consistency Policy : resync

     Resync Status : 33% complete                     ← 同步进度
              UUID : f024b6e0:d2a5793c:f8bdebc6:6bcc7027
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc

# 关键观察：
#   Array Size = Used Dev Size ≈ 20G（即单盘容量）
#   State: clean, resyncing（resyncing 表示镜像数据在初次同步）

# 等待同步完成后再格式化（可通过 watch 持续观察）
[root@centos7 ~]# watch -n1 "cat /proc/mdstat"
```

### 13.3 设备映射

```bash
[root@centos7 ~]# lsblk /dev/md1
NAME MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
md1    9:1    0  20G  0 raid1

[root@centos7 ~]# lsblk /dev/sdb /dev/sdc
NAME  MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
sdb     8:16   0  20G  0 disk  
└─md1   9:1    0  20G  0 raid1 
sdc     8:32   0  20G  0 disk  
└─md1   9:1    0  20G  0 raid1 
```

### 13.4 格式化与挂载

```bash
# 同步完成后格式化
[root@centos7 ~]# mkfs.xfs /dev/md1

# 创建挂载点
[root@centos7 ~]# mkdir /raid/raid1

# 挂载
[root@centos7 ~]# mount /dev/md1 /raid/raid1

# 验证
[root@centos7 ~]# df -h /raid/raid1
Filesystem      Size  Used Avail Use% Mounted on
/dev/md1         20G  175M   20G   1% /raid/raid1

# 测试写入
[root@centos7 ~]# cp /etc/ho* /raid/raid1
[root@centos7 ~]# ls /raid/raid1/
host.conf  hostname  hosts  hosts.allow  hosts.deny
```

### 13.5 增加热备盘

```bash
# 加 sdd 作为热备盘
[root@centos7 ~]# mdadm --add /dev/md1 /dev/sdd
mdadm: added /dev/sdd

# 查看热备盘状态
[root@centos7 ~]# mdadm --detail /dev/md1 | tail -5
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc

       2       8       48        -      spare   /dev/sdd
# ↑ "spare" = 备用，未参与读写
```

**热备盘的作用**：
- 平时不参与读写
- 当某块活动盘故障时，**自动顶上 + 自动同步**
- 整个过程无需人工干预

### 13.6 模拟磁盘故障

```bash
# 标记 sdc 故障（手动触发模拟）
[root@centos7 ~]# mdadm --fail /dev/md1 /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md1

# 查看故障后状态
[root@centos7 ~]# mdadm --detail /dev/md1 | tail -7
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       2       8       48        1      spare rebuilding   /dev/sdd   ← 热备顶替！
       1       8       32        -      faulty   /dev/sdc          ← 故障标记

# 关键点：
#   /dev/sdd 从 spare → spare rebuilding（正在重建）
#   /dev/sdc 从 active sync → faulty（标记故障）
#   数据仍可正常访问（因为 RAID 1 镜像）
```

```bash
# 验证：数据仍可访问
[root@centos7 ~]# ls /raid/raid1/
host.conf  hostname  hosts  hosts.allow  hosts.deny

[root@centos7 ~]# cat /raid/raid1/hostname 
centos7.linux.fun
# ↑ 数据完好无损（因镜像机制，另一块盘还在）
```

### 13.7 删除故障盘 + 加新盘

```bash
# 移除故障盘
[root@centos7 ~]# mdadm --remove /dev/md1 /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md1

# 此时阵列已有 sdb + sdd（热备已顶替）
# 加新盘作为新的热备
[root@centos7 ~]# mdadm --add /dev/md1 /dev/sdg
mdadm: added /dev/sdg
```

### 13.8 删除整个 RAID 1

```bash
# 1. 卸载
[root@centos7 ~]# umount /dev/md1

# 2. 停止
[root@centos7 ~]# mdadm --stop /dev/md1
mdadm: stopped /dev/md1

# 3. 清除所有相关盘的超级块
[root@centos7 ~]# mdadm --zero-superblock /dev/sd{b..d}
#                                ↑ sdb sdc sdd 一并清除
```

### 13.9 RAID 1 的关键理解

```
RAID 1 的"容量悖论"：
  2 块 20G 盘 → RAID 1 后 /dev/md1 容量 = 20G（不是 40G）
  加再多盘 → 仍 = 20G（除非做 RAID 10）

为什么？
  镜像机制要求每块盘数据完全一致，
  所以"逻辑容量"等于"单盘容量"，
  多出来的容量全部用于冗余。
```

---

## §14 RAID 5 完整实战（4 盘 + 热备 + 扩容 + 重构）

### 14.1 创建 RAID 5

```bash
# 4 块盘 sdb sdc sdd sde → RAID 5
[root@centos7 ~]# mdadm --create /dev/md5 --level 5 --raid-devices 4 /dev/sd{b..e}
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md5 started.

# 注释：
#   4 块盘 RAID 5，1 块用于分布式校验 → 实际容量 = 3 × 20G = 60G
#   没有任何一块盘"专门"存校验（vs RAID 4）
```

### 14.2 查看 RAID 5 状态

```bash
[root@centos7 ~]# mdadm --detail /dev/md5
/dev/md5:
           Version : 1.2
     Creation Time : Sat Aug  3 17:16:10 2024
        Raid Level : raid5
        Array Size : 62862336 (59.95 GiB 64.37 GB)   ← 60G（4-1）
     Used Dev Size : 20954112 (19.98 GiB 21.46 GB)
      Raid Devices : 4
             State : clean, degraded, recovering       ← 注意这个状态！
    Active Devices : 3                                 ← 3 个（因为刚刚开始）
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 1                                 ← 自动有 1 个 spare
            Layout : left-symmetric                    ← 校验分布算法
        Chunk Size : 512K
Consistency Policy : resync

    Rebuild Status : 17% complete                      ← 正在重建

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      spare rebuilding   /dev/sde
# ↑ "State: clean, degraded, recovering"
#   为什么 degraded？因创建时只用了 4 块盘（n=4），校验占用 1 块
#   重启建完成后 → State: clean

# Layout: left-symmetric（默认）
#   校验块"从左往右"轮转分布，配合 chunk 算法
#   其他选项：right-asymmetric / left-asymmetric / right-symmetric
```

### 14.3 设备映射

```bash
[root@centos7 ~]# lsblk /dev/md5
NAME MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
md5    9:5    0  60G  0 raid5 /raid/raid5

[root@centos7 ~]# lsblk /dev/sd{b..e}
NAME  MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
sdb     8:16   0  20G  0 disk  
└─md5   9:5    0  60G  0 raid5 
sdc     8:32   0  20G  0 disk  
└─md5   9:5    0  60G  0 raid5 
sdd     8:48   0  20G  0 disk  
└─md5   9:5    0  60G  0 raid5 
sde     8:64   0  20G  0 disk  
└─md5   9:5    0  60G  0 raid5
# ↑ 所有 4 块盘都参与，但用户层看到的是"1 块 60G 设备"
```

### 14.4 格式化与挂载

```bash
# 等待 resync 完成后再格式化
[root@centos7 ~]# watch -n 5 'cat /proc/mdstat'
# 或一次
[root@centos7 ~]# cat /proc/mdstat | grep -E 'recovery|resync'
# 无输出 = 完成

# 格式化
[root@centos7 ~]# mkfs.xfs /dev/md5
# 创建挂载点
[root@centos7 ~]# mkdir /raid/raid5
# 挂载
[root@centos7 ~]# mount /dev/md5 /raid/raid5

# 验证
[root@centos7 ~]# df -h /raid/raid5/
Filesystem      Size  Used Avail Use% Mounted on
/dev/md5         60G  461M   60G   1% /raid/raid5

# 写测试
[root@centos7 ~]# cp /etc/ho* /raid/raid5
[root@centos7 ~]# ls /raid/raid5/
host.conf  hostname  hosts  hosts.allow  hosts.deny
```

### 14.5 增加热备盘

```bash
# 加 sdf 作为热备盘
[root@centos7 ~]# mdadm --add /dev/md5 /dev/sdf
mdadm: added /dev/sdf

# 查看状态
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -7
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      active sync   /dev/sde

       5       8       80        -      spare   /dev/sdf
```

### 14.6 模拟磁盘故障

```bash
# 标记 sdb 为故障
[root@centos7 ~]# mdadm --fail /dev/md5 /dev/sdb
mdadm: set /dev/sdb faulty in /dev/md5

# 关键观察：sdf 自动顶上 + 重建
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -7
     Number   Major   Minor   RaidDevice State
       5       8       80        0      spare rebuilding   /dev/sdf   ← 顶替 + 重建
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      active sync   /dev/sde

       0       8       16        -      faulty   /dev/sdb            ← 故障

# 验证数据完好
[root@centos7 ~]# ls /raid/raid5/
host.conf  hostname  hosts  hosts.allow  hosts.deny

[root@centos7 ~]# cat /raid/raid5/hostname 
centos7.linux.fun
```

### 14.7 移除故障盘

```bash
# sdb 标记为故障后移除
[root@centos7 ~]# mdadm --remove /dev/md5 /dev/sdb
mdadm: hot removed /dev/sdb from /dev/md5

# 验证
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -5
    Number   Major   Minor   RaidDevice State
       5       8       80        0      active sync   /dev/sdf
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      active sync   /dev/sde
# 注意：sdf 从 spare rebuilding → active sync（已顶替完成）
```

### 14.8 RAID 5 扩容（增加成员盘）

**重要约束**：
- ✅ RAID 5 仅支持**扩容**（加成员盘）
- ❌ 不支持**减容**
- ⚠️ 必须在阵列 "clean" 正常状态下执行
- ⚠️ 降级 / 重建中禁止扩容

```bash
# 步骤 1：加新盘（先 add，可能成 spare）
[root@centos7 ~]# mdadm --add /dev/md5 /dev/sdb /dev/sdg
mdadm: added /dev/sdb
mdadm: added /dev/sdg

# 查看 sdb/sdg 当前状态（应该是 spare）
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -8
    Number   Major   Minor   RaidDevice State
       5       8       80        0      active sync   /dev/sdf
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      active sync   /dev/sde

       6       8       16        -      spare   /dev/sdb   ← 新加的 spare
       7       8       96        -      spare   /dev/sdg

# 步骤 2：用 --grow 真正扩展阵列成员数
[root@centos7 ~]# mdadm --grow /dev/md5 --raid-devices 5
# ↑ 从 4 盘 → 5 盘

# 步骤 3：观察重建进度（reshape：数据迁移 + 校验重算）
[root@centos7 ~]# mdadm --detail /dev/md5
......
    Reshape Status : 16% complete                 ← "Reshape" = 数据迁移中
     Delta Devices : 1, (4->5)
              UUID : 1d4e3f21:1178a4fd:db214497:593e3353
            Events : 79
    Number   Major   Minor   RaidDevice State
       5       8       80        0      active sync   /dev/sdf
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       4       8       64        3      active sync   /dev/sde
       7       8       96        4      active sync   /dev/sdg    ← 提升为活动
       6       8       16        -      spare   /dev/sdb

# 步骤 4：验证容量（4 盘 → 5 盘后，60G → 80G）
[root@centos7 ~]# lsblk /dev/md5
NAME MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
md5    9:5    0  80G  0 raid5 /raid/raid5

# 步骤 5：扩展文件系统（XFS 用 xfs_growfs）
[root@centos7 ~]# xfs_growfs /raid/raid5
[root@centos7 ~]# df -h /raid/raid5/
Filesystem      Size  Used Avail Use% Mounted on
/dev/md5         80G  604M   80G   1% /raid/raid5
```

**关键步骤解释**：
- `mdadm --grow`：扩展阵列成员数，触发内部数据重新分布（"reshape"）
- `xfs_growfs`：扩展 XFS 文件系统**在线识别**新的容量
- 两个操作**必须按顺序**：先硬件阵列扩容 → 再文件系统识别

### 14.9 RAID 5 重构（assemble）

**场景**：停止阵列后，未清除超级块，下次启动希望恢复

```bash
# 直接装配
[root@centos7 ~]# mdadm --assemble /dev/md5 /dev/sd{b..g}
# 自动识别各盘超级块 → 重组阵列 → 数据不丢
```

**为什么可以？**

每块物理盘上都有 "superblock"（超级块），记录：
- 阵列 UUID
- 阵列角色（member / spare）
- 阵列级别、chunk 大小

mdadm 扫描所有盘 → 找 UUID 一致的盘 → 自动装配。

### 14.10 删除整个 RAID 5

```bash
# 1. 卸载
[root@centos7 ~]# umount /dev/md5

# 2. 停止
[root@centos7 ~]# mdadm --stop /dev/md5
mdadm: stopped /dev/md5

# 3. 清除所有相关盘（b/c/d/e/f/g 6 块）
[root@centos7 ~]# mdadm --zero-superblock /dev/sd{b..g}
```

---

## §15 配置文件 /etc/mdadm.conf 与开机装配

### 15.1 生成配置

```bash
# 把当前所有阵列写入配置
[root@centos7 ~]# mdadm --detail --scan >> /etc/mdadm.conf

# 查看配置内容
[root@centos7 ~]# cat /etc/mdadm.conf
# mdadm.conf written by David Hicks
# small /proc/mdstat
ARRAY /dev/md5 metadata=1.2 UUID=1d4e3f21:1178a4fd:db214497:593e3353
ARRAY /dev/md1 metadata=1.2 UUID=f024b6e0:d2a5793c:f8bdebc6:6bcc7027
# ↑ UUID 唯一标识，开机用这个识别阵列
```

### 15.2 开机自动装配

```bash
# /etc/mdadm.conf 存在后，
# 系统启动时会自动运行 mdadm --assemble --scan
# 把记录在案的阵列自动激活
# （前提：内核 md 模块 + 物理盘都还在）
```

### 15.3 /etc/fstab 自动挂载

```bash
# 写入 /etc/fstab（开机自动挂载 RAID）
[root@centos7 ~]# echo "/dev/md5 /raid/raid5 xfs defaults 0 0" >> /etc/fstab

# 注意：用 /dev/md5 而非 UUID（因为 mdadm 本身已通过配置文件管理 UUID）
# 也可以用 UUID：blkid /dev/md5 查
```

---

## §16 /proc/mdstat 实时监控

**最常用的实时命令**：

```bash
[root@centos7 ~]# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] 
md5 : active raid5 sdf[4] sdc[1] sdd[2] sde[3]
      83884032 blocks super 1.2 level 5, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
```

**字段解读**：

| 字段 | 含义 |
|---|---|
| `md5` | 阵列设备名 |
| `active raid5` | 状态 + 级别 |
| `sdf[4] sdc[1]...` | 各成员盘 + 槽位号 |
| `83884032 blocks` | 总块数（× 512 = 实际字节） |
| `super 1.2` | 元数据格式 |
| `level 5, 512k chunk` | 级别 + chunk 大小 |
| `algorithm 2` | 校验算法 |
| `[5/5]` | 配置 5 块 / 当前 5 块在线 |
| `[UUUUU]` | 各盘状态：U=Up，F=Faulty，`_`=down |

**重建时**：

```bash
md5 : active raid5 sdf[5] sdb[3] sdc[2] sdd[4] sde[1]
      83884032 blocks super 1.2 level 5, 512k chunk, algorithm 2 [5/4] [_UUUU]
      [==>..................]  recovery = 12.3% finish=10.2min speed=1245K/sec
```

- `[5/4]` → 5 块配置，4 块在线
- `[==>..................]` → 重建进度条
- `recovery = 12.3%` → 已完成比例
- `finish=10.2min` → 预计剩余 10 分钟
- `speed=1245K/sec` → 重建速率

**实时刷新**：

```bash
# 每 1 秒刷新一次，看重建进度
[root@centos7 ~]# watch -n 1 'cat /proc/mdstat'
```

---

## §17 RAID 扩容：--grow 与 xfs_growfs

### 17.1 两类扩容场景

| 场景 | 命令 | 是否需要新盘 |
|---|---|---|
| 阵列增加成员盘 | `mdadm --grow -n N` | ✅ |
| 阵列不变，占满现有盘空间 | `mdadm --grow --size=max` | ❌ |
| 文件系统识别新容量 | `xfs_growfs` / `resize2fs` | — |

### 17.2 XFS vs EXT4 扩容

```bash
# XFS：在线扩容（必须）
[root@centos7 ~]# xfs_growfs /raid/raid5

# EXT4：在线扩容
[root@centos7 ~]# resize2fs /dev/md5

# 注意：EXT4 还支持缩容（xfs 不支持）
# EXT4 缩容：先 umount → e2fsck → resize2fs /dev/md5 30G → 再阵列缩容
```

### 17.3 扩容实战示例（4 盘 → 5 盘）

```bash
# 假设初始为 RAID 5（4 块 20G 盘） = 60G
# 现在加 1 块 20G 盘 → 期望扩容到 80G

# 1. 加新盘
[root@centos7 ~]# mdadm --add /dev/md5 /dev/sdg

# 2. 真正扩展（数据迁移 + 校验重算）
[root@centos7 ~]# mdadm --grow /dev/md5 --raid-devices 5

# 3. 等待 reshape 完成（可能数分钟到数小时，取决于数据量）
[root@centos7 ~]# cat /proc/mdstat
md5 : active raid5 ...
      [==>..................]  reshape = X% complete

# 4. 扩展文件系统
[root@centos7 ~]# xfs_growfs /raid/raid5

# 5. 验证
[root@centos7 ~]# df -h /raid/raid5/
Filesystem      Size  Used Avail Use% Mounted on
/dev/md5         80G  604M   80G   1% /raid/raid5
```

---

## §18 RAID 重构：--assemble 恢复

### 18.1 场景

```
正常关机 → 重启 → 阵列没自动装配？
  可能原因：
  1. /etc/mdadm.conf 没写
  2. 物理盘命名变化（设备名错位）
  3. 有盘缺失

此时可用 mdadm --assemble 手动恢复
```

### 18.2 手动装配

```bash
# 语法
mdadm --assemble /dev/mdN 成员盘1 成员盘2 ...

# 示例：装配 RAID 5
[root@centos7 ~]# mdadm --assemble /dev/md5 /dev/sd{b..g}
# ↑ 自动识别 UUID（即使盘顺序变了也能识别）
```

### 18.3 高级选项

```bash
# 强制装配（即使某些盘缺失）
mdadm --assemble --force /dev/md5 /dev/sd{b..e}

# 扫描模式（自动找 /etc/mdadm.conf 中记录的阵列）
mdadm --assemble --scan

# 装配时加 missing 标记（用于测试）
mdadm --assemble /dev/md5 --run /dev/sd{b,d,e}
# ↑ 假装缺一块 sdc（可用于查看降级运行）
```

### 18.4 元数据迁移

```bash
# 跨主机迁移阵列的步骤：
# 1. 源主机：mdadm --stop /dev/md5
# 2. 物理盘拔下，插目标主机
# 3. 目标主机：mdadm --assemble /dev/md5 /dev/sd{b..e}
#   → 因为元数据在每块盘上，重组后数据可访问
```

---

## §19 故障模拟完整流程总结

### 19.1 故障演练（RAID 5 为例）

```bash
# === 步骤 1：查看初始 healthy 状态 ===
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -8
  0       8       16        0      active sync   /dev/sdb
  1       8       32        1      active sync   /dev/sdc
  2       8       48        2      active sync   /dev/sdd
  4       8       64        3      active sync   /dev/sde
# 4 块活动盘 + 1 块热备

# === 步骤 2：人为制造故障 ===
[root@centos7 ~]# mdadm --fail /dev/md5 /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md5

# 状态变为：
# sdc: faulty（标记）
# 热备自动顶替
[root@centos7 ~]# mdadm --detail /dev/md5 | tail -8
  5       8       80        0      spare rebuilding   /dev/sdf    ← 顶替 + 重建
  1       8       32        1      active sync   /dev/sdc
  2       8       48        2      active sync   /dev/sdd
  4       8       64        3      active sync   /dev/sde
  0       8       16        -      faulty   /dev/sdc             ← 故障

# === 步骤 3：观察重建进度 ===
[root@centos7 ~]# watch -n 1 'cat /proc/mdstat'
# 看到 [==>..................] recovery = XX.X%

# === 步骤 4：重建期间业务影响 ===
# 关键：重建期间 RAID 5 只有 1 块冗余
# 此时再坏 1 块 → 数据全丢
# 所以生产环境要在**低峰期**做故障演练

# === 步骤 5：移除故障盘 ===
[root@centos7 ~]# mdadm --remove /dev/md5 /dev/sdb
mdadm: hot removed /dev/sdb from /dev/md5

# === 步骤 6：插新盘作为新热备 ===
# 物理更换故障盘（或虚拟机加新盘）
[root@centos7 ~]# mdadm --add /dev/md5 /dev/sdb
mdadm: added /dev/sdb
# 自动变 spare
```

### 19.2 故障类型识别

| 状态字符 | 含义 | 处理 |
|---|---|---|
| `active sync` | 正常同步 | — |
| `spare` | 热备盘 | — |
| `spare rebuilding` | 热备盘顶替正在重建 | 等待 |
| `faulty` | 标为故障 | remove + add 新盘 |
| `_` (down) | 离线 | 检查硬件 |

### 19.3 真实物理故障 vs 模拟故障

```bash
# 真实故障：磁盘控制器报告 I/O error
#   → mdadm 自动标记 faulty（无需人工 --fail）
#   → 自动从热备盘顶替

# 模拟故障：手动标记，用于演练
#   mdadm --fail /dev/md5 /dev/sdc
```

---

## §20 RAID 与 LVM 配合

### 20.1 为何要组合？

```
RAID 解决"盘坏"问题（底层冗余）
LVM 解决"扩缩容"问题（上层灵活）

两者组合：
  RAID → 给 LVM 提供"带冗余的底层块设备"
  LVM  → 在 RAID 之上灵活切分逻辑卷

示例架构：
  物理盘 4 块 → RAID 5（冗余 + 大容量）→ /dev/md0
                                    ↓
                                  PV（物理卷）
                                    ↓
                                  VG（卷组）
                                    ↓
                            ┌────┴────┐
                           LV        LV
                          /data    /home
```

### 20.2 实施步骤

```bash
# 1. 先创建 RAID 5（具体见 §14）
mdadm --create /dev/md0 --level 5 --raid-devices 4 /dev/sd{b..e}

# 2. 在 RAID 之上做 LVM
pvcreate /dev/md0
vgcreate vg0 /dev/md0
lvcreate -L 50G -n lv_data vg0
lvcreate -L 20G -n lv_home vg0

# 3. 格式化 + 挂载
mkfs.xfs /dev/vg0/lv_data
mkfs.xfs /dev/vg0/lv_home
mount /dev/vg0/lv_data /data
mount /dev/vg0/lv_home /home
```

### 20.3 与"直接在 RAID 上分区"的对比

```
方案 A：直接用 RAID 分区
  /dev/md5 → mkfs.xfs → 挂载
  优点：简单
  缺点：扩缩容需重启 + 重建（小项目够用）

方案 B：RAID + LVM
  /dev/md5 → pvcreate → vgcreate → lvcreate → mkfs → 挂载
  优点：在线扩缩容 + 多 LV 灵活分配
  缺点：复杂一点
  推荐：生产环境（见 [[Linux存储#§15-lvm-是什么逻辑卷管理]]）
```

---

## §21 硬件 RAID vs 软件 RAID 决策

### 21.1 决策表

| 场景 | 推荐 | 原因 |
|---|---|---|
| 关键业务数据库 | **硬 RAID** | 性能 + 电池保护（BBU）|
| 虚拟化宿主机 | **硬 RAID** | 多 VM 并发 I/O 能力 |
| 学习 / 实验 | **软 RAID** | 0 成本，理解原理 |
| 小型文件服务器 | **软 RAID 5 + 热备** | 性价比 |
| 大容量备份 | **软 RAID 6** | 抗双盘故障 |
| 嵌入式 / 资源紧张 | **软 RAID** | 不增加硬件 |
| 老旧服务器无 RAID 卡 | **软 RAID** | 唯一选择 |

### 21.2 软 RAID 性能优化

```bash
# 1. 调整 chunk 大小
#    大文件（视频）：chunk = 256KB~1MB
#    小文件（数据库）：chunk = 32KB~64KB
mdadm -C /dev/md0 -l 5 -n 4 -c 64 /dev/sd{b..e}

# 2. 调整重建速度（默认可能受限）
echo 50000 > /proc/sys/dev/raid/speed_limit_min
echo 200000 > /proc/sys/dev/raid/speed_limit_max

# 3. 用 mdadm.conf 加优化参数
DEVICE /dev/sd*
CREATE group=root,mode=0660 auto=yes
HOMEHOST <system>
ARRAY /dev/md0 metadata=1.2 UUID=...

# 4. 文件系统优化
mkfs.xfs -d su=128k,sw=3 /dev/md5   # sw = 数据盘数

# 5. I/O 调度器
echo deadline > /sys/block/md5/queue/scheduler
```

### 21.3 硬 RAID 的额外能力

- **BBU（电池备份）**：意外断电时缓存数据不丢
- **大容量缓存**（512MB ~ 4GB）写入合并
- **在线扩容 / 迁移**（多数支持）
- **JBOD / HBA 切换**（部分卡支持）
- **专用管理工具**（MegaRAID Storage Manager）

---

## §22 监控与告警：mdadm --monitor + smartd

### 22.1 mdadm 守护进程模式

```bash
# 启动监控（前台，测试用）
mdadm --monitor /dev/md0 /dev/md1

# 启动后台服务
mdadm --monitor --daemonize --mail=admin@x.com --delay=60 /dev/md0

# 参数说明：
#   --daemonize = 放后台
#   --mail       = 故障时邮件给谁
#   --delay      = 检查间隔（秒）

# 完整系统监控（扫描所有 /etc/mdadm.conf 中的阵列）
mdadm --monitor --daemonize --mail=admin@x.com --scan

# systemd 单元（很多发行版已有 mdadm.service）
systemctl enable --now mdmonitor.service
```

### 22.2 邮件告警配置

```bash
# 确保本地邮件可用（postfix / sendmail / nullmailer）
[root@centos7 ~]# ss -lnt | grep :25
# LISTEN 0  100  *:25  *:*

# 测试邮件
[root@centos7 ~]# echo "test" | mail -s "raid test" admin@x.com
```

### 22.3 smartd 健康监控

```bash
# 安装
yum install -y smartmontools

# 单盘查看
smartctl -H /dev/sdb
# 关键输出：
#   PASSED = 健康
#   FAILED! = 坏

# 自检
smartctl -t short /dev/sdb        # 短自检（2分钟）
smartctl -t long /dev/sdb         # 长自检（数小时）
smartctl -l selftest /dev/sdb     # 查看结果

# 编辑 /etc/smartd.conf
# 例：每天 3 点短检，发现异常 mail 报告
DEVICESCAN -a -H -m admin@x.com -s S/../.././03
```

### 22.4 日志告警监控

```bash
# mdadm 故障事件会写 /var/log/messages
[root@centos7 ~]# tail -f /var/log/messages | grep md
# 例：md: data-degraded
#     mdadm[1234]: Fail event detected on md device /dev/md5

# 推荐：logwatch / logcheck 每日报告
```

### 22.5 集成 zabbix / nagios

```
生产环境推荐：
  zabbix agent → 监控 /proc/mdstat + smartd
  触发条件：
    - Failed Devices > 0
    - State != clean
    - smartd FAILED
  自动派单 + 通知值班运维
```

---

## §23 性能基准：dd + fio 测顺序/随机读写

### 23.1 dd 测试顺序写

```bash
# 顺序写（直接写裸设备，绕过 page cache）
# 注意：用 oflag=direct 才测真实磁盘 IOPS
dd if=/dev/zero of=/dev/md0 bs=1M count=1024 oflag=direct status=progress
# 输出大致：
#   1024+0 records in
#   1024+0 records out
#   1073741824 bytes (1.1 GB) copied, 5.32 s, 202 MB/s
```

### 23.2 dd 顺序读

```bash
# 顺序读
echo 3 > /proc/sys/vm/drop_caches    # 先清缓存
dd if=/dev/md0 of=/dev/null bs=1M count=1024 iflag=direct
```

### 23.3 fio 综合性能基准（推荐）

```bash
# 安装
yum install -y fio

# 顺序读（4KB block × 4 jobs）
fio --name=randread \
    --filename=/dev/md5 \
    --rw=randread \
    --bs=4k \
    --size=10G \
    --numjobs=4 \
    --runtime=30 \
    --time_based \
    --ioengine=libaio \
    --direct=1 \
    --iodepth=32 \
    --group_reporting

# 关键输出：
#   read: IOPS=5234, BW=20.4MiB/s (21.4MB/s)
#   ...
#   lat (usec): avg=2345, max=15672, ...
```

### 23.4 多场景对比参考

| RAID | 顺序读 MB/s | 顺序写 MB/s | 随机读 IOPS | 随机写 IOPS |
|---|---|---|---|---|
| 单盘 HDD | 100~150 | 80~120 | 100~200 | 100~200 |
| **RAID 0 (2盘)** | 200~300 | 150~250 | 200~400 | 200~400 |
| **RAID 1 (2盘)** | 200~300 | 80~120 | 200~300 | 80~120 |
| **RAID 5 (4盘)** | 300~500 | 100~150 | 300~500 | 50~150 |
| **RAID 10 (4盘)** | 300~500 | 200~300 | 500~1000 | 200~500 |

**性能规律**：
- **RAID 0** 读 ≈ N 倍，但写 ≈ N 倍（条带化零开销）
- **RAID 1** 读 ≈ 2 倍（多盘并行），写 ≈ 1 倍（写两遍）
- **RAID 5** 读 ≈ N 倍，写极差（要算校验 + 读改写）
- **RAID 10** 读写都接近 N 倍（无校验计算）

---

## §24 随堂笔记实战案例复盘

> 以下来自源文档 `随堂笔记-0409 (1).md`（2026 年 4 月 9 日课堂笔记），
> 经整理补全，作为本模块的实战章节。

### 24.1 课堂环境与目标

```
实验环境：
  虚拟机（VMware）添加 6 块 20G 硬盘
  设备名分别为：sdb / sdc / sdd / sde / sdf / sdg
  全部为空白裸盘（无分区、无文件系统）
  操作系统：CentOS 7

工具链：
  - mdadm（用户态）
  - 内核 md 模块（raid0/raid1/raid5/raid4/raid6）
  - mkfs.xfs（文件系统）
  - /proc/mdstat（内核状态）

课堂内容串联：
  1. RAID 0 → 性能极限
  2. RAID 1 → 镜像冗余
  3. RAID 5 → 性价比
  4. RAID 5 扩容（--grow + xfs_growfs）
  5. RAID 5 重构（--assemble）
  6. （后续：LVM、SELinux）
```

### 24.2 RAID 0 课堂案例（直接摘自源 .md）

**关键对话流**：

```bash
# 课堂讲："创建 RAID 0 阵列：设备名/dev/md0，级别0，成员盘2块（sdb、sdc）"
[root@centos7 ~]# mdadm --create /dev/md0 --level 0 --raid-devices 2 /dev/sd{b,c}
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```

**课堂注释摘录**（来自源 .md 的注释部分）：

```markdown
> 注释：
>   --level    指定 RAID 级别
>   --raid-devices 指定成员盘数量
>   /dev/sd{b,c}  为 sdb 和 sdc 的简写（bash 大括号展开）
```

**课堂结论**：
- RAID 0 测试中，磁盘速度体现为 2 倍率（实测约 1.8 倍，受寻道时间限制）
- 但试验了 "加新盘扩容" → 失败：`Invalid argument`
- "模拟故障" → "array will be failed" → 阵列进入 failed 状态

### 24.3 RAID 1 课堂案例

**关键警告**（来自源 .md）：

```bash
# 课堂提醒：元数据在磁盘开头会影响 /boot
[root@centos7 ~]# mdadm --create /dev/md1 --level 1 --raid-devices 2 /dev/sd{b,c}
mdadm: Note: this array has metadata at the start and
    may not be suitable as a boot device.  If you plan to
    store '/boot' on this device please ensure that
    your boot-loader understands md/v1.x metadata, or use
    --metadata=0.90
Continue creating array? yes
# ↑ 老引导程序（如 GRUB 0.97）不认识 md/v1.x → /boot 会启动失败
# → 解决办法：加 --metadata=0.90（元数据存在末尾）
```

**课堂要点**：
- 同步时间：大容量盘可能要数小时，**必须等 resync 完成才能格式化**
- 加 sdd 热备盘后，状态出现 "spare"（备用）
- 模拟 sdc 故障时，**sdd 状态从 spare → spare rebuilding（顶上）**
- 数据仍可访问（验证 `cat hostname`）

### 24.4 RAID 5 课堂案例（最完整）

**完整对话流**（摘自动手操作）：

```bash
# 创建（4 盘）
mdadm --create /dev/md5 --level 5 --raid-devices 4 /dev/sd{b..e}
# ↑ 创建后立即 "recovering" 状态
# ↑ Rebuild Status : 17% complete

# 加热备
mdadm --add /dev/md5 /dev/sdf

# 标记 sdb 故障
mdadm --fail /dev/md5 /dev/sdb
# sdf 顶上 → spare rebuilding

# 验证：sdb 标 faulty，sdf spare rebuilding
# 然后：data 仍可访问（校验机制保护）

# 扩容（关键操练）
mdadm --add /dev/md5 /dev/sdb /dev/sdg     # 加回旧 sdb + 新 sdg
mdadm --grow /dev/md5 --raid-devices 5     # 真正的扩容
# 出现：Reshape Status : 16% complete
# Delta Devices : 1, (4->5)
# lsblk /dev/md5 → 80G

# 扩展文件系统
xfs_growfs /raid/raid5
# df -h /raid/raid5/ → 80G

# 重构实验
mdadm --stop /dev/md5
mdadm --assemble /dev/md5 /dev/sd{b..g}    # 重组
```

### 24.5 案例总结：5 个核心要点

```
1. 创建后立即同步
   任何 RAID 创建后都先 resync（同步），不等待会导致后续问题
2. 热备盘的好处
   有热备 = 故障后无人工干预即可恢复，否则要手工 add
3. 扩容两步走
   mdadm --grow（硬件）→ xfs_growfs（文件系统），缺一不可
4. 重构的魔法
   物理盘超级块记 UUID → 任意主机都能 assemble 恢复
5. 课堂扩展（LVM + SELinux）
   接着做：LVM 在 RAID 之上（§20）、SELinux 安全机制（见 [[LinuxSELinux]]）
```

### 24.6 源 .md 的"坑"（学习笔记要警惕的细节）

```
从课堂笔记中提取的"反直觉"现象：

1. "metadata at the start" 警告 → 直接回 yes
   课堂学生容易误解为"创建失败"，实际只是提醒 /boot 兼容性
   
2. "State : clean, degraded, recovering" 同时出现
   "clean" 表示数据一致；"degraded" 表示活动盘少；"recovering" 表示在重建
   三者都是"正常初创"状态

3. RAID 1 "Array Size" 比 "Raid Devices" 之和还小
   这是正常的（容量 50% 利用率），但初学易误以为创建失败

4. --grow 后要 xfs_growfs
   否则 df 看容量没变（md 已扩但 fs 仍认旧容量）

5. --zero-superblock 的范围
   必须把所有参与过的盘都清，否则下次 mdadm --create 会冲突
```

---

## §25 易错点 ×12

| # | 易错点 | 后果 | 正确做法 |
|---|---|---|---|
| 1 | chunk size 选错 | 大文件+小chunk=开销大；小文件+大chunk=空间浪费 | 大文件块大（512K~1M），小文件块小（32K~64K） |
| 2 | 忘记加热备盘 | 故障后需人工加盘 | 创建时加 `-x 1` |
| 3 | UUID 写错 | 开机无法自动装配 | 让 mdadm 自动生成，不要手写 |
| 4 | rebuild 中重启 | 重建从头开始 | 等完成或用 `kill` 暂停 |
| 5 | /boot 分区用 1.2 元数据 | GRUB 不识别，无法启动 | `--metadata=0.90` |
| 6 | 多个 RAID 用同盘 | 关联错乱 | 严格按盘名单独配置 |
| 7 | 扩容后忘了 xfs_growfs | `df` 看容量不变 | **必须两步**：--grow + xfs_growfs |
| 8 | RAID 0 标记 fail | 整个阵列变 failed | RAID 0 不要手动 fail |
| 9 | 未清 superblock 重新创建 | 提示 "device busy" 或 "contain" 错 | `mdadm --zero-superblock` 清干净 |
| 10 | 用 dd 测速未用 oflag=direct | 测的是 page cache | 必须 `oflag=direct` 才真实 |
| 11 | 故障演练选在业务高峰期 | 重建时再有故障 = 数据丢 | 在**低峰期**演练，且勿同时坏多盘 |
| 12 | 把 RAID 当备份 | 误删数据无法恢复 | RAID ≠ 备份，必须独立备份 |

---

## §26 速查表

### 26.1 mdadm 命令

```bash
# === 创建 ===
mdadm -C /dev/md0 -l 0 -n 2 /dev/sd{b,c}                 # RAID 0
mdadm -C /dev/md0 -l 1 -n 2 -x 1 /dev/sd{b,c,d}          # RAID 1 + 1 热备
mdadm -C /dev/md0 -l 5 -n 4 -x 1 /dev/sd{b..f}           # RAID 5 + 1 热备
mdadm -C /dev/md0 -l 6 -n 4 -x 1 /dev/sd{b..f}           # RAID 6 + 1 热备
mdadm -C /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}            # RAID 10
mdadm -C /dev/md0 -l 1 -n 2 --metadata=0.90 /dev/sd{b,c} # /boot 兼容

# === 查询 ===
cat /proc/mdstat                                         # 实时状态
mdadm -D /dev/md0                                        # 详细
mdadm -E /dev/sdb                                        # 看盘的超级块
lsblk /dev/md0                                           # 设备树

# === 管理 ===
mdadm /dev/md0 -a /dev/sdf                               # 加盘
mdadm /dev/md0 -f /dev/sdb                               # 标故障
mdadm /dev/md0 -r /dev/sdb                               # 移除
mdadm /dev/md0 -G -n 5                                   # RAID 5 扩容
mdadm /dev/md0 -G --size=max                             # 占满空间

# === 装配 / 停止 ===
mdadm -A /dev/md0 /dev/sd{b..e}                          # 装配
mdadm -S /dev/md0                                        # 停止
mdadm --zero-superblock /dev/sdb                         # 清元数据
mdadm -D --scan >> /etc/mdadm.conf                       # 生成配置

# === 监控 ===
mdadm --monitor --daemonize --mail=a@b.com --scan         # 后台守护
```

### 26.2 RAID 级别参数速记

| 级别 | 最少盘 | 容量 | 容错 | 主要参数 |
|---|---|---|---|---|
| 0 | 2 | N | 0 | `-l 0` |
| 1 | 2 | N/2 | N-1 | `-l 1` |
| 5 | 3 | N-1 | 1 | `-l 5 -n 3` 起 |
| 6 | 4 | N-2 | 2 | `-l 6 -n 4` 起 |
| 10 | 4 | N/2 | 每组-1 | `-l 10 -n 4` |

### 26.3 关键文件路径

| 路径 | 用途 |
|---|---|
| `/dev/md*` | RAID 设备 |
| `/proc/mdstat` | 内核态 RAID 状态 |
| `/etc/mdadm.conf` | 配置文件（开机装配） |
| `/var/log/messages` | mdadm 事件日志 |
| `/proc/sys/dev/raid/speed_limit_*` | 重建速率 |

---

## §27 面试 6 大追问

### Q1：RAID 5 vs RAID 6 怎么选？

**答**：
- 容量 6T 以下 + 不是关键数据 → **RAID 5**（容量利用率高）
- 容量 8T 以上 / 关键数据 → **RAID 6**（双校验更安全）
- 原因：大容量盘重建时间长，期间再遇 URE → RAID 5 数据丢失

### Q2：为什么 RAID 10 比 RAID 01 好？

**答**：
- RAID 10（先 1 后 0）：镜像坏 1 块不影响，性能降
- RAID 01（先 0 后 1）：条带整体坏即不可用
- 实际容忍度：RAID 10 = 25%，RAID 01 = 50% 故障域
- 生产几乎只用 RAID 10

### Q3：rebuild 期间再坏一块会怎样？

**答**：
- **RAID 0**：本来就冗余 0，1 块坏即数据全丢
- **RAID 1**：原镜像坏 1 块已裸奔，再坏 1 块 = 数据丢
- **RAID 5**：原 1 块故障 + 再坏 1 块 = **数据全丢**（校验不足以反推 2 块）
- **RAID 6**：可扛同时坏 2 块
- **RAID 10**：多个镜像对可独立坏 1 块（坏其他对没事）

### Q4：软 RAID 和硬 RAID 哪个好？

**答**：
- 性能：**硬 RAID > 软 RAID**（专用芯片 + BBU 缓存）
- 成本：**软 RAID = 0**（已在内核）
- 可靠性：硬 RAID（电池保护）+ 缓存合并写
- 实际：
  - 学习 / 中小型：**软 RAID**
  - 关键业务 / 数据库：**硬 RAID**

### Q5：RAID 5 写性能为什么差？

**答**：
- 每次写：先读旧数据 → 与新数据合并 → 算校验 → 写回（4 次 I/O）
- 实际是 "read-modify-write"（RMW）开销
- 通过：升级 BBU、写合并、写回策略（write-back）改善
- 软 RAID 5 写 ≈ 单盘（甚至差）的速率

### Q6：chunk size 怎么选？

**答**：
- 太大（≥1M）：大文件顺序好，小文件浪费（每文件至少 1 个 chunk）
- 太小（≤32K）：顺序差（频繁切条），但空间利用率高
- 推荐：
  - 大文件（视频/数据库）：256K ~ 512K
  - 小文件（文件服务器）：32K ~ 64K
  - 默认 512K 一般够用
- 决定后**不可改**（创建时锁定）

---

## §28 跨模块链接

### 28.1 与其他模块的关系

```
RAID 处于"存储抽象层"的核心位置：

  Linux存储/
    ├── §5 硬盘分区 ← 物理盘要先分区（除非整盘组 RAID）
    ├── §11 RAID 基础概念（本模块的"理论速览"在 [[Linux存储#§11-raid-是什么磁盘阵列]]）
    ├── §13 RAID 5 快速实战（[[Linux存储#§13-mdadm-创建-raid-5-实战]]）
    └── §15 LVM（[[Linux存储#§15-lvm-是什么逻辑卷管理]]） ← RAID 上做 LVM 的最佳实践

  LinuxRAID/（本模块）
    ├── 完整的 RAID 0/1/5 实战（区别于 Linux存储 的"概念性"）
    ├── 故障 + 热备 + 重建完整流程
    └── 硬件 vs 软件决策 + 性能基准

  LinuxiSCSI/
    └── iSCSI target 可用 RAID 设备当 backend（[[LinuxiSCSI#底层后端]]）

  linux-fio / 性能调优/
    └── 详见性能基准章节
```

### 28.2 推荐阅读顺序

1. **第一遍**（理解）：[[Linux存储#§11-raid-是什么磁盘阵列]] + [[#§1]]
2. **第二遍**（实操）：[[#§12-§14]] 三种 RAID 完整流程
3. **第三遍**（运维）：[[#§19]] 故障模拟 + [[#§22]] 监控
4. **第四遍**（决策）：[[#§21]] 硬件 vs 软件 + [[#§20]] RAID + LVM

### 28.3 链接清单

```markdown
- [[Linux存储#§11-raid-是什么磁盘阵列]] — RAID 概念入门（精简版）
- [[Linux存储#§12-raid-级别01610-对比]] — 级别对比表（精简版）
- [[Linux存储#§13-mdadm-创建-raid-5-实战]] — RAID 5 快速创建（PDF 整理）
- [[Linux存储#§15-lvm-是什么逻辑卷管理]] — LVM 入门（RAID 上的扩展）
- [[LinuxSELinux]] — 课堂同日的 SELinux 模块（笔记下半）
- [[Linux启动原理]] — 课堂同日的启动原理（笔记）
- [[LinuxiSCSI#底层后端]] — iSCSI + RAID 后端存储
```

---

> **版本**：v1.0（2026-07-16 整理自 `随堂笔记-0409 (1).md`）
> **来源**：课堂随堂笔记 + 实战经验扩展
> **适用**：CentOS-7 / RHEL 系软 RAID，原理同样适用 Debian/Ubuntu
