---
title: Linux iSCSI 服务器
desc: iSCSI 原理 + target/initiator + LUN + CHAP 认证 + multipath 多路径 + 性能调优
type: 笔记
module: LinuxiSCSI
pdf: iSCSI 服务器-new.pdf
pdf_size: 0.6 MB
scope: iSCSI 协议 + targetcli/tgtd 部署 + 客户端挂载 + multipath + 实战
status: 完成
---

# Linux iSCSI 服务器

> **范围**：基于《iSCSI 服务器-new.pdf》整理，覆盖 **iSCSI 协议原理** + **targetcli 部署 Target** + **iscsiadm 客户端连接** + **CHAP 单/双向认证** + **dm-multipath 多路径** + **故障切换 + 性能调优**。
>
> **适用**：CentOS-7 / RHEL 系（targetcli + iscsi-initiator-utils）。

## 目录

- [[#§0 心智模型：iSCSI = 把 SCSI 协议装进 TCP/IP 网络，让远程盘像本地盘]]
- [[#§1 iSCSI 是什么：Internet Small Computer System Interface]]
- [[#§2 iSCSI 架构：Initiator + Target + LUN + IQN + Portal]]
- [[#§3 iSCSI 命名：IQN 格式 iqn.YYYY-MM.reversed.domain.name]]
- [[#§4 iSCSI vs FC SAN：成本 + 性能 + 适用场景]]
- [[#§5 targetcli 工具：yum install targetcli + 树形配置]]
- [[#§6 backstore 类型：block + fileio + pscsi + ramdisk]]
- [[#§7 创建 iSCSI Target：backstore + IQN + LUN + Portal + ACL 五步]]
- [[#§8 iSCSI Initiator 客户端：yum install iscsi-initiator-utils]]
- [[#§9 iscsiadm 发现 / 登录 / 登出命令]]
- [[#§10 客户端挂载 iSCSI 设备：fdisk + mkfs + mount + _netdev]]
- [[#§11 CHAP 单向认证：target + initiator 双向配置]]
- [[#§12 CHAP 双向认证 mutual CHAP]]
- [[#§13 ACL 访问控制：IQN 白名单]]
- [[#§14 multipath 多路径：dm-multipath + 多网卡绑定 + 故障切换]]
- [[#§15 /etc/multipath.conf 详解：path_grouping_policy + path_selector + failback]]
- [[#§16 iSCSI 性能调优：MTU 9000 巨型帧 + 多网卡 + TCP 拥塞控制]]
- [[#§17 iSCSI 与防火墙：3260 端口 + firewalld rich rule]]
- [[#§18 iSCSI 安全：CHAP + IPsec + 隔离 VLAN + IQN 白名单]]
- [[#§19 iSCSI 故障排查：iscsiadm -m session + /var/log/messages]]
- [[#§20 易错点 ×10]]
- [[#§21 速查表：端口 + 关键路径 + targetcli 命令树]]
- [[#§22 面试 6 大追问]]
- [[#§23 跨模块链接]]

---

## §0 心智模型：iSCSI = 把 SCSI 协议装进 TCP/IP 网络，让远程盘像本地盘

```
普通本地盘：
  CPU ──PCIe───> SATA / SAS 控制器 ──> 物理硬盘
                                    └─> /dev/sda

iSCSI 远程盘：
  ┌──────────── Initiator (客户端) ────────────┐     ┌──────── Target (服务端) ─────────┐
  │ 应用 ──文件系统──> SCSI 命令                │     │   iSCSI Target 提供 LUN         │
  │           ↓                                │     │   ↑                              │
  │      内核 SCSI 子系统                       │     │   │                              │
  │           ↓                                │ TCP │   本地磁盘 / 分区 / LVM / 文件   │
  │      iSCSI Initiator (iscsid)              │─────│   targetd ──> 块设备            │
  │           ↓                                │ 3260│                                  │
  │      以太网卡 ──────────────────────────────│─────│   以太网卡                       │
  └────────────────────────────────────────────┘     └──────────────────────────────────┘

客户端视角：拿到 /dev/sdb（iSCSI 远程盘），格式化、挂载，**和本地盘完全一样用**。
```

**核心抽象**：把"物理距离"隐藏掉，让客户端内核把远程盘当成 `/dev/sdX` 这种本地块设备。

**关键名词速览**：
- **Initiator**：客户端，发起 SCSI 命令的软件/硬件
- **Target**：服务端，把本地块设备变成 iSCSI LUN
- **LUN**：Logical Unit Number，Target 暴露给客户端的"块设备"
- **IQN**：iSCSI Qualified Name，全局唯一标识
- **Portal**：监听地址和端口（默认 `0.0.0.0:3260`）

> 💡 **iSCSI = IP-SAN**，是 SAN（Storage Area Network）的一种实现，基于 TCP/IP 而非 FC（光纤）。

---

## §1 iSCSI 是什么：Internet Small Computer System Interface

### 1.1 SCSI 协议回顾

**SCSI（Small Computer System Interface，小型计算机系统接口）**：一种用于计算机和智能设备之间（硬盘、软驱、光驱、打印机、扫描仪等）连接的并行总线标准。

| 时代 | 协议 | 特点 |
|------|------|------|
| 1980s | SCSI-1 / SCSI-2 | 并行 8/16 bit 总线，限于机箱内 |
| 1990s | SCSI-3 / Ultra320 | 320 MB/s，仍需物理线缆 |
| 2000s+ | SAS (Serial Attached SCSI) | 串行 SCSI，点对点，机房内 |

**问题**：SCSI 协议天生是"块级（block-level）"且"本地"的——它要求物理距离短（一根 SCSI 线最长 25 米）。

### 1.2 iSCSI 的诞生

**iSCSI（Internet Small Computer System Interface，Internet 小型计算机系统接口）**，又称为 **IP-SAN**，是 IBM 公司研究开发的 IP SAN 技术：

> **将现有 SCSI 接口与以太网络（Ethernet）技术结合**，基于 TCP/IP 协议连接 iSCSI 服务端（Target）和客户端（Initiator），使得封装后的 SCSI 数据包可以在互联网传输，最终实现 iSCSI 服务端提供存储给客户端。

```
SCSI 命令 ──> 封装进 TCP/IP ──> 以太网传输 ──> 远端解开 ──> 本地 SCSI 执行
   │                                                              │
   └────────────────── 块级 I/O，对上层透明 ──────────────────────┘
```

### 1.3 iSCSI 的关键事实

- **IETF 标准**：RFC 3720（已被 RFC 7143 取代）
- **块级存储**：对外呈现为 `/dev/sdX`，需要格式化（mkfs）
- **运行端口**：TCP **3260**
- **典型网络**：专用 10 Gb 以太网或更好，最大化性能
- **流量隔离**：从物理服务器到存储的电缆通常封闭在数据中心内，**理想情况下不直接连接到 LAN**，所以 **SAN 流量通常不加密**，最大化性能
- **WAN 安全**：为实现 WAN 安全，**iSCSI 管理员可以使用 IPsec 加密流量**

### 1.4 iSCSI 的定位

```
存储协议层级：

  ┌────────────────────────────────────────┐
  │ 文件级：NFS / SMB / CIFS               │  ← 提供"文件"
  ├────────────────────────────────────────┤
  │ 块级：iSCSI / FC / FCoE / NVMe-oF      │  ← 提供"块设备"
  ├────────────────────────────────────────┤
  │ 对象级：S3 / Swift                     │  ← 提供"对象"
  └────────────────────────────────────────┘

iSCSI = 块级 + IP 网络 = IP-SAN
```

> 💡 **对比记忆**：iSCSI 是"远程硬盘"，NFS 是"远程文件夹"。

---

## §2 iSCSI 架构：Initiator + Target + LUN + IQN + Portal

iSCSI 服务是 **C/S 架构**。

### 2.1 核心组件

| 组件            | 角色                   | 说明                                                                         |
| ------------- | -------------------- | -------------------------------------------------------------------------- |
| **Initiator** | iSCSI 客户端            | 通常以软件方式部署（`iscsi-initiator-utils`），也可使用 **iSCSI HBA**（Host Bus Adapters）硬件 |
| **Target**    | iSCSI 服务器            | 提供 iSCSI 存储资源，每个目标提供 1+ 块设备或 LUN                                           |
| **LUN**       | Logical Unit Number  | Target 提供的块设备，每个目标可提供 1+ LUN                                               |
| **IQN**       | iSCSI Qualified Name | 全局唯一名称，标识 Initiator 和 Target                                               |
| **Portal**    | 监听入口                 | 服务器监听的 IP + 端口，如 `10.1.8.10:3260`                                          |
| **ACL**       | Access Control List  | 用 Initiator 的 IQN 限制客户端访问 Target                                           |
| **TPG**       | Target Portal Group  | 目标的完整配置（Portal + LUN + ACL）                                                |

### 2.2 客户端视角

> 访问的 iSCSI 目标在客户端系统上显示为 **本地且未格式化的 SCSI 块设备**，等同于通过 SCSI 布线、FC 直连或 FC 交换光纤连接的设备。

```
客户端内核看到的：

  $ lsblk
  sda               ← 本地盘
  └─sda1 ...
  sdb               ← iSCSI 远程盘（来自 Target）
  sdc               ← 另一块 iSCSI 远程盘
```

### 2.3 节点规划示例

| 节点名 | IP | 角色 | 资源 |
|--------|-----|------|------|
| iscsi-server | 10.1.8.10/24 | Target | 增加 2 块 20G SCSI 硬盘 |
| iscsi-client | 10.1.8.11/24 | Initiator | 软件 initiator |

### 2.4 关键流程名词

- **discovery（发现）**：查询服务器上的 Target 列表
- **login（登录）**：向 Target 验证，验证通过后即可使用 Target 提供的块设备
- **logout（登出）**：停止使用某个 Target 的会话

---

## §3 iSCSI 命名：IQN 格式 iqn.YYYY-MM.reversed.domain.name

### 3.1 IQN 格式

```
iqn.YYYY-MM.reversed.domain.name:name_string
└──┘ └─────┘ └──────────────────┘ └────────┘
 │     │              │                │
 │     │              │                └─ 标识特定目标的字符串（可省略）
 │     │              └─ 反向域名
 │     └─ 年-月（保证唯一性）
 └─ 固定前缀 "iqn."
```

### 3.2 命名示例

**域名**：`www.laogao.cloud` → **反向域名**：`cloud.laogao.www`

**Target IQN**：`iqn.2026-04.cloud.laogao.iscsi-server:disk1`
```
iqn.2026-04.cloud.laogao.iscsi-server:disk1
│   │      │                          │
│   │      │                          └─ :disk1（标识第一块共享盘）
│   │      └─ 反向域名（cloud.laogao.www）
│   └─ 年月（2026 年 4 月）
└─ iqn 前缀
```

**Initiator IQN**：`iqn.2026-04.cloud.laogao.iscsi-client`
```
无 :name_string，因为一台机器通常只有一个 initiator
```

### 3.3 IQN 规则

- 最大长度 **223 字节**
- 只能包含 **小写字母、数字、点、连字符、冒号**
- **YYYY-MM** 是注册日期，不一定是创建日期——目的是保证唯一性
- IQN 一旦分配，全球唯一（不需要中央注册机构，反向域名保证唯一）

### 3.4 IQN 在配置文件中的位置

**Target 端**：在 `targetcli` 中通过 `create` 命令指定。
**Initiator 端**：存储在 `/etc/iscsi/initiatorname.iscsi` 文件中：

```bash
# /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2026-04.cloud.laogao.iscsi-client
```

> ⚠️ **重要**：客户端 IQN 必须与 Target 上的 ACL 配置一致，否则 login 失败。

---

## §4 iSCSI vs FC SAN：成本 + 性能 + 适用场景

| 维度 | iSCSI (IP-SAN) | FC SAN |
|------|----------------|--------|
| **物理介质** | 以太网（双绞线 / 光纤） | 光纤专用（Fibre Channel） |
| **协议** | TCP/IP over Ethernet | FC 协议（独立协议栈） |
| **带宽** | 1 GbE / 10 GbE / 25 GbE / 100 GbE | 8 Gb / 16 Gb / 32 Gb FC |
| **延迟** | 微秒级（10 GbE） | 微秒级（更稳定） |
| **最大距离** | WAN 可达（IP 网络通就通） | 取决于光纤，典型 10-50 km |
| **成本** | **低**（复用现有以太网设备） | **高**（FC 交换机 + HBA 贵） |
| **运维** | 复用网络技能 | 需要 FC 专业知识 |
| **适用场景** | 中小企业、虚拟化、备份 | 高端数据库、高性能计算 |
| **加密** | IPsec | 硬件级或上层软件 |
| **典型操作系统** | Linux / Windows / VMware 全支持 | 企业级，需 HBA 驱动 |

### 选择建议

- **预算有限 + 中小规模**：iSCSI（10 GbE + 普通交换机就够）
- **极致性能 + 关键业务**：FC SAN（数据库 OLTP、大规模虚拟化）
- **超融合 / 云环境**：iSCSI / NVMe-oF
- **跨数据中心 / DR**：iSCSI over WAN（便宜）

---

## §5 targetcli 工具：yum install targetcli + 树形配置

### 5.1 安装

```bash
# 安装服务端软件
[root@iscsi-server ~]# yum install -y targetd targetcli

# targetd    = 服务端 daemon
# targetcli  = targetd 的配置工具（树形交互 shell）

# 启用并启动服务
[root@iscsi-server ~]# systemctl enable target --now

# 配置防火墙
[root@iscsi-server --add-service=iscsi-target
firewall-cmd --permanent --reload
```

### 5.2 进入交互模式

```bash
[root@iscsi-server ~]# targetcli
targetcli shell version 2.1.53
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> ls
o- / ........................................................................... [...]
  o- backstores .................................................................... [...]
  | o- block ........................................................ [Storage Objects: 0]
  | o- fileio ....................................................... [Storage Objects: 0]
  | o- pscsi ........................................................ [Storage Objects: 0]
  | o- ramdisk ...................................................... [Storage Objects: 0]
  o- iscsi .............................................................. [Targets: 0]
  o- loopback ........................................................... [Targets: 0]
/>
```

### 5.3 树形结构

```
/                                  ← 根
├── backstores/                    ← 后端存储（实际数据来源）
│   ├── block/                     ← 块设备（磁盘、分区、LVM）
│   ├── fileio/                    ← 普通文件（作为磁盘映像）
│   ├── pscsi/                     ← 物理 SCSI 设备（透传）
│   └── ramdisk/                   ← 内存盘（重启丢数据）
├── iscsi/                         ← iSCSI 目标配置
│   └── iqn.YYYY-MM...:name/       ← 每个 IQN 一个子目录
│       └── tpg1/                  ← Target Portal Group
│           ├── acls/              ← 访问控制
│           ├── luns/              ← 共享哪些 LUN
│           └── portals/           ← 监听地址:端口
└── loopback/                      ← 本地回环（一般不用）
```

### 5.4 退出自动保存

```
退出 targetcli shell 时，配置自动保存在 /etc/target/saveconfig.json 文件中。

/> exit
Global pref auto_save_on_exit=true
Configuration saved to /etc/target/saveconfig.json
```

> 💡 **命令行模式必须显式 saveconfig**：
> ```bash
> [root@iscsi-server ~]# targetcli /backstores/block create myblock2 /dev/sdc
> ...
> [root@iscsi-server ~]# targetcli saveconfig
> Configuration saved to /etc/target/saveconfig.json
> ```
> 与交互式不同，**命令行模式必须显式运行 saveconfig 子命令以保存配置**。

---

## §6 backstore 类型：block + fileio + pscsi + ramdisk

backstore 是 Target 实际数据的"后端来源"。

| 类型 | 说明 | 持久性 | 典型用途 |
|------|------|--------|---------|
| **block** | 块设备（磁盘、分区、LVM） | ✅ 持久 | **最常用**——直接共享整个磁盘 |
| **fileio** | 普通文件作为磁盘映像 | ✅ 持久 | 没有专用盘时，用文件模拟磁盘 |
| **pscsi** | 物理 SCSI 设备（透传） | ✅ 持久 | 透传物理 SCSI 硬件（少用） |
| **ramdisk** | 内存盘 | ❌ 重启丢失 | 测试 / 临时场景 |

### 6.1 block（块设备）—— 最常用

```bash
# 创建 block backstore
/> cd /backstores/block
/backstores/block> create myblock1 /dev/sdb
Created block storage object myblock1 using /dev/sdb.

# 验证
/> /backstores/block ls
o- block ............................................................ [Storage Objects: 1]
  o- myblock1 ............................................ [/dev/sdb (20.0GiB) write-thru activated]
```

`myblock1` 是 backstore 名称（自定义），`/dev/sdb` 是实际块设备。

### 6.2 fileio（文件映像）

```bash
# 先创建一个空文件
[root@iscsi-server ~]# mkdir -p /iscsi_disks
[root@iscsi-server ~]# dd if=/dev/zero of=/iscsi_disks/disk1.img bs=1M count=10240

# 在 targetcli 中创建 fileio backstore
/> cd /backstores/fileio
/backstores/fileio> create disk1 /iscsi_disks/disk1.img 10G
Created fileio disk1 with size 10737418240.
```

> ⚠️ fileio 在每次写入时会同步刷新到磁盘（默认 write-back），性能略差，但方便测试。

### 6.3 pscsi（透传物理 SCSI）

```bash
/> cd /backstores/pscsi
/backstores/pscsi> create mypscsi /dev/sg0
```

> ⚠️ **慎用**：透传会暴露 Target 上的物理设备，客户端可绕过 Target 直接访问。

### 6.4 ramdisk（内存盘）

```bash
/> cd /backstores/ramdisk
/backstores/ramdisk> create myram 1G
Created ramdisk myram with size 1GB.
```

> 服务器重启后数据丢失，仅用于测试。

---

## §7 创建 iSCSI Target：backstore + IQN + LUN + Portal + ACL 五步

### 7.1 配置流程总览

```
┌─────────────────────────────────────────────┐
│ 步骤 1：建 backstores/block 绑定本地硬盘/分区│
│ 步骤 2：建 iscsi 目标（指定 IQN）           │
│ 步骤 3：绑定 LUN（共享哪些后端存储）        │
│ 步骤 4：设置权限（ACL 允许哪些 Initiator）  │
│ 步骤 5：客户端连接使用                      │
└─────────────────────────────────────────────┘
```

### 7.2 实战 1：基础 Target 配置（交互式）

```bash
# 步骤 1：创建 backstore
/> /backstores/block create myblock1 /dev/sdb
Created block storage object myblock1 using /dev/sdb.

# 步骤 2：创建 Target IQN
/> cd /iscsi
/iscsi> create iqn.2026-04.cloud.laogao.iscsi-server:disk1
Created target iqn.2026-04.cloud.laogao.iscsi-server:disk1.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.

# 此时已经自动创建了 TPG 1，并默认监听 0.0.0.0:3260
/iscsi> ls
o- iscsi ............................................................ [Targets: 1]
  o- iqn.2026-04.cloud.laogao.iscsi-server:disk1 ................. [TPGs: 1]
    o- tpg1 ............................................. [no-gen-acls, no-auth]
      o- acls ..................................................... [ACLs: 0]
      o- luns ..................................................... [LUNs: 0]
      o- portals ............................................... [Portals: 1]
        o- 0.0.0.0:3260 ............................................... [OK]

# 步骤 3：绑定 LUN（把后端存储 myblock1 共享出去）
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/luns
/iscsi/iqn.20...sk1/tpg1/luns> create /backstores/block/myblock1
Created LUN 0.

# 步骤 4：配置 ACL（允许哪些 Initiator 访问）
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls
/iscsi/iqn.20...sk1/tpg1/acls> create iqn.2026-04.cloud.laogao.iscsi-client
Created Node ACL for iqn.2026-04.cloud.laogao.iscsi-client
Created mapped LUN 0.

# 步骤 5：删除默认 Portal（0.0.0.0 太宽），新建指定 IP 的 Portal
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals/
/iscsi/iqn.20.../tpg1/portals> delete 0.0.0.0 3260
Deleted network portal 0.0.0.0:3260

/iscsi/iqn.20.../tpg1/portals> create 10.1.8.10 3260
Using default IP port 3260
Created network portal 10.1.8.10:3260.

# 退出（自动保存）
/> exit
Global pref auto_save_on_exit=true
Configuration saved to /etc/target/saveconfig.json
```

### 7.3 实战 2：批量配置多块盘（命令行模式）

```bash
# 第二块盘（/dev/sdc）用命令行模式，演示"非交互式"操作

# 创建 backstore
[root@iscsi-server ~]# targetcli /backstores/block create myblock2 /dev/sdc
Created block storage object myblock2 using /dev/sdc.

# 创建 Target
[root@iscsi-server ~]# targetcli /iscsi create iqn.2026-04.cloud.laogao.iscsi-server:disk2
Created target iqn.2026-04.cloud.laogao.iscsi-server:disk2.
Created TPG 1.

# 绑定 LUN
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/luns create /backstores/block/myblock2
Created LUN 0.

# 配置 ACL
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/acls create iqn.2026-04.cloud.laogao.iscsi-client
Created Node ACL for iqn.2026-04.cloud.laogao.iscsi-client
Created mapped LUN 0.

# 替换 Portal 为指定 IP
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/portals delete 0.0.0.0 3260
Deleted network portal 0.0.0.0:3260
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/portals create 10.1.8.10 3260
Using default IP port 3260
Created network portal 10.1.8.10:3260.

# 显式保存（命令行模式必须！）
[root@iscsi-server ~]# targetcli saveconfig
Last 10 configs saved in /etc/target/backup/.
Configuration saved to /etc/target/saveconfig.json
```

### 7.4 验证 Target 配置

```bash
# 查看所有配置
[root@iscsi-server ~]# targetcli ls

# 查看 portals
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals ls
o- portals ........................................................... [Portals: 1]
  o- 10.1.8.10:3260 .......................................................... [OK]
```

### 7.5 删除 Target

```bash
# 整个 Target 删掉（连同 ACL / LUN / Portal）
[root@iscsi-server ~]# targetcli /iscsi delete iqn.2026-04.cloud.laogao.iscsi-server:disk2

# 单个 ACL 删除
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.../tpg1/acls delete iqn.2026-04.cloud.laogao.iscsi-client

# 删 LUN
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.../tpg1/luns delete 0
```

---

## §8 iSCSI Initiator 客户端：yum install iscsi-initiator-utils

### 8.1 安装与配置

```bash
# 安装 Initiator 软件包
[root@iscsi-client ~]# yum install -y iscsi-initiator-utils
```

软件包提供：
- **iscsid 服务**：iSCSI initiator daemon，处理发现 / 登录
- **iscsi 服务**：开机自动启动，扫描登录已发现的目标
- **`/etc/iscsi/iscsid.conf`**：连接目标的默认配置（超时、重试、CHAP 等）
- **`/etc/iscsi/initiatorname.iscsi`**：本机 IQN

> 软件包安装会自动配置 iscsid 服务，以便启动器在系统启动时自动重新连接到任何已发现的目标。**每当您修改启动程序的配置文件时，请重新启动 iscsid 服务。**

### 8.2 关键配置文件

#### `/etc/iscsi/initiatorname.iscsi`

```ini
# 客户端 IQN（必须与 Target 上的 ACL 一致）
InitiatorName=iqn.2026-04.cloud.laogao.iscsi-client
```

#### `/etc/iscsi/iscsid.conf`

```ini
# 默认超时、重试、CHAP 用户名/密码等
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.login_timeout = 30
node.conn[0].timeo.logout_timeout = 15
# CHAP 默认配置（如果启用）
node.session.auth.authmethod = CHAP
node.session.auth.username = <username>
node.session.auth.password = <password>
```

### 8.3 服务管理

```bash
# iscsid = 守护进程，处理 iscsiadm 命令的发现/登录
# iscsi  = 启动时自动连接已登录的目标

systemctl enable iscsid --now
systemctl enable iscsi --now

# 修改配置后必须重启
systemctl restart iscsid
```

---

## §9 iscsiadm 发现 / 登录 / 登出命令

`iscsiadm` 是 Initiator 的命令行管理工具，按 **mode（模式）** 操作。

### 9.1 iscsiadm 的 4 大模式

| 模式 | 说明 |
|------|------|
| `-m discovery` | 发现 Target |
| `-m node` | 管理已发现但未连接的 Target |
| `-m session` | 管理已建立的会话（已连接的 Target） |
| `-m iface` | 管理网络接口（多网卡场景） |

### 9.2 发现 Target（discovery）

```bash
# 语法：iscsiadm -m discovery -t st -p portal_ip[:port]
#         │              │          │      └─ 发送 discovery 的门户
#         │              │          └─ discovery 类型（st = sendtargets）
#         │              └─ discovery 模式
#         └─ iscsiadm 命令

# 默认端口 3260
[root@iscsi-client ~]# iscsiadm -m discovery -t st -p 10.1.8.10
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk2
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1
#           └─Portal  └─ TPG 号  └─ Target IQN

# 自定义端口
[root@iscsi-client ~]# iscsiadm -m discovery -t st -p 10.1.8.10:3260
```

发现结果存储在 `/var/lib/iscsi/nodes/` 目录中：
```bash
[root@iscsi-client ~]# ls /var/lib/iscsi/nodes/
iqn.2026-04.cloud.laogao.iscsi-server:disk1/
iqn.2026-04.cloud.laogao.iscsi-server:disk2/
```

### 9.3 登录 Target（login）

```bash
# 语法：iscsiadm -m node -T Target -p portal_ip[:port] -l
#         │              │   │       │                  └─ login
#         │              │   │       └─ Portal IP:port
#         │              │   └─ Target IQN
#         │              └─ node 模式
#         └─ iscsiadm

# 登录指定 Target
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -l
Logging in to [iface: default, target: iqn.2026-04.cloud.laogao.iscsi-server:disk1, portal: 10.1.8.10,3260] (multiple)
Login to [iface: default, target: iqn.2026-04.cloud.laogao.iscsi-server:disk1, portal: 10.1.8.10,3260] successful.

# 登录所有已发现但未登录的 Target
[root@iscsi-client ~]# iscsiadm -m node -L all

# 登录所有 Target（包括已登录的）
[root@iscsi-client ~]# iscsiadm -m node -L all -w
```

### 9.4 查看连接状态

```bash
# 简短列表：当前活跃会话
[root@iscsi-client ~]# iscsiadm -m session
tcp: [1] 10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk2 (non-flash)
tcp: [2] 10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1 (non-flash)

# 详细列表：已发现的所有目标
[root@iscsi-client ~]# iscsiadm -m node
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk2
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1

# 完整会话信息（打印级别 3 = 最详细）
[root@iscsi-client ~]# iscsiadm -m session -P 3
iSCSI Transport Class version 2.0-870
version 6.2.0.874-22
Target: iqn.2026-04.cloud.laogao.iscsi-server:disk1 (non-flash)
    Current Portal: 10.1.8.10:3260,1
    Persistent Portal: 10.1.8.10:3260,1
    **********
    Interface:
    **********
    Iface Name: default
    Iface Transport: tcp
    Iface Initiatorname: iqn.2026-04.cloud.laogao.iscsi-client
    Iface IPaddress: 10.1.8.11
    *********
    Timeouts:
    *********
    Recovery Timeout: 120
    Target Reset Timeout: 30
    LUN Reset Timeout: 30
    Abort Timeout: 15
    *****
    CHAP:
    *****
    username: <empty>
    password: ********
    ************************
    Attached SCSI devices:
    ************************
    Host Number: 3  State: running
    scsi3 Channel 00 Id 0 Lun: 0
        Attached scsi disk sdb      State: running
```

### 9.5 登出 Target（logout）

```bash
# 语法：iscsiadm -m node -T Target -p portal_ip[:port] -u

# 登出指定 Target
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -u
Logging out of session [sid: 2, target: iqn.2026-04.cloud.laogao.iscsi-server:disk1, portal: 10.1.8.10,3260]
Logout successful.

# 登出所有会话
[root@iscsi-client ~]# iscsiadm -m session -u
```

### 9.6 删除发现记录

```bash
# 语法：iscsiadm -m node -T Target -p portal_ip[:port] -o delete

# 删除本地记录，避免重启自动登录
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -o delete

# 验证：已无此 Target 记录
[root@iscsi-client ~]# iscsiadm -m node
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk2
```

> ⚠️ `iscsiadm -m session -u` 是 logout（断开连接），`-m node -o delete` 是删除记录（开机不再自动连接）。**先 logout 再 delete**。

### 9.7 登录后看新设备

```bash
[root@iscsi-client ~]# lsblk
NAME           MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda               8:0    0   200G  0 disk
├─sda1            8:1    0     1G  0 part /boot
└─sda2            8:2    0   199G  0 part
  ├─centos-root 253:0    0    50G  0 lvm  /
  ├─centos-swap 253:1    0   7.9G  0 lvm  [SWAP]
  └─centos-home 253:2    0 141.1G  0 lvm  /home
sdb               8:16   0    20G  0 disk          # ← 来自 iscsi-server 的远程盘！
sr0              11:0    1   4.4G  0 rom

# 也可以从其他角度查看
dmesg | tail                     # 看内核新识别的 SCSI 设备
tail /var/log/messages           # 看 iscsid 日志
ls -l /dev/disk/by-path/*iscsi*  # 通过 by-path 路径查看
```

---

## §10 客户端挂载 iSCSI 设备：fdisk + mkfs + mount + _netdev

### 10.1 准备系统

登录 iSCSI Target 后，客户端会看到新 SCSI 块设备（如 `/dev/sdb`）。可以直接使用。

### 10.2 格式化

```bash
# 假设客户端发现的设备名称是 /dev/sdb
[root@iscsi-client ~]# mkfs.xfs /dev/sdb
meta-data=/dev/sdb               isize=512    agcount=4, agsize=1310720 blks
         =                       sectsz=512   attr=2, projid32bit=1
data     =                       bsize=4096   blocks=5242880, imaxpct=25
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
realtime =none

# 验证
[root@iscsi-client ~]# blkid
/dev/sda1: UUID="53d865c3-ed9c-4070-86dc-84558ed00ed1" TYPE="xfs"
/dev/sda2: UUID="yNXcrK-NYTG-XipO-fTBm-qmZf-bXbB-2fTRGj" TYPE="LVM2_member"
/dev/sr0: UUID="2020-11-04-11-36-43-00" LABEL="CentOS 7 x86_64" TYPE="iso9660"
/dev/mapper/centos-root: ...
/dev/mapper/centos-swap: ...
/dev/mapper/centos-home: ...
/dev/sdb: UUID="81629560-cb56-4c19-814f-7f946d731b02" TYPE="xfs"     ← 新增
```

### 10.3 临时挂载测试

```bash
[root@iscsi-client ~]# mkdir /sdb
[root@iscsi-client ~]# mount /dev/sdb /sdb
[root@iscsi-client ~]# echo xixihaha > /sdb/test
[root@iscsi-client ~]# cat /sdb/test
xixihaha
[root@iscsi-client ~]# lsblk
sdb               8:16   0    20G  0 disk /sdb
```

### 10.4 ⚠️ 多客户端并发挂载：会导致文件系统损坏

> **多个启动程序同时从同一目标安装同一文件系统，会导致文件系统损坏或尝试读取数据时出现不一致。**
>
> 本地文件系统（例如 ext4 或 XFS）**不支持从多个系统并发安装**。
> 如果需要允许从多个系统同时访问基于 iSCSI 的块设备，请使用群集文件系统（例如 GFS2）。

**解决**：
- **共享文件级访问**：用 NFS / SMB 代替 iSCSI
- **共享块级访问**：用 **GFS2 / OCFS2** 集群文件系统
- **互斥访问**：用 **iSCSI 预留（persistent reservation）** 或外部锁

### 10.5 持久化挂载：UUID + _netdev

在 `/etc/fstab` 中的 iSCSI 目标上持久地挂载文件系统时，请确保遵循以下建议：

#### 规则 1：用 UUID 挂载，不要用 /dev/sdX

```bash
# ❌ 错误：设备名会变
/dev/sdb  /sdb  xfs  defaults  0 0

# ✅ 正确：用 blkid 查到的 UUID
UUID="81629560-cb56-4c19-814f-7f946d731b02"  /sdb  xfs  defaults,_netdev  0 0
```

> **原因**：设备的名称取决于 iSCSI 设备通过网络响应的顺序，因此设备名称可能会在引导之后更改。如果在 `/etc/fstab` 中使用设备名称，则系统可能会将设备挂载在错误的挂载点下。

#### 规则 2：使用 `_netdev` 挂载选项

```bash
UUID="81629560-cb56-4c19-814f-7f946d731b02"  /sdb  xfs  defaults,_netdev  0 0
#                                                       └─ 关键！告诉系统"这是网络设备，等网络起来再挂载"
```

> 因为 iSCSI 依赖网络访问远程设备，所以此选项可确保在网络和启动器启动之前，系统不会尝试挂载文件系统。

#### 规则 3：iscsi 服务必须开机自启

```bash
systemctl enable iscsi
```

### 10.6 完整 fstab 示例

```bash
# /etc/fstab
UUID="81629560-cb56-4c19-814f-7f946d731b02"  /sdb  xfs  defaults,_netdev  0 0
```

### 10.7 断开目标的标准流程

要停止使用 iSCSI 目标，请执行以下步骤：

```
1. 确保没有使用目标提供的任何设备。  例如，卸载文件系统。
2. 从 /etc/fstab 等位置删除对目标的所有持久引用。
3. 从 iSCSI 目标注销（logout）。
4. 删除 iSCSI 目标的本地记录，以使启动器在引导过程中不会自动登录到目标。
```

```bash
# 1. 卸载
[root@iscsi-client ~]# umount /sdb

# 2. 删除 fstab 行（vim /etc/fstab）

# 3. 登出
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -u

# 4. 删除本地记录
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -o delete
```

---

## §11 CHAP 单向认证：target + initiator 双向配置

### 11.1 CHAP 是什么

**CHAP（Challenge-Handshake Authentication Protocol）**：iSCSI 的认证协议，基于"挑战-应答"机制。

```
单向 CHAP 流程：

  Initiator                            Target
      │                                  │
      │──── Login Request ──────────────>│
      │                                  │
      │<──── CHAP Challenge ─────────────│  (含随机数)
      │                                  │
      │──── CHAP Response ──────────────>│  (MD5(密码 + Challenge))
      │                                  │
      │<──── Login Accept ───────────────│
```

**单向**：只有 Target 验证 Initiator（Initiator 信任任何人）。

### 11.2 Target 配置 CHAP

```bash
# 进入 targetcli
[root@iscsi-server ~]# targetcli

# 进入目标 TPG 的 acls
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls

# 创建 ACL（如果还没有）
/iscsi/iqn.20...sk1/tpg1/acls> create iqn.2026-04.cloud.laogao.iscsi-client
Created Node ACL for iqn.2026-04.cloud.laogao.iscsi-client

# 设置 CHAP 密码（12 字符以上）
/iscsi/iqn.20...sk1/tpg1/acls> cd iqn.2026-04.cloud.laogao.iscsi-client

/iscsi/iqn.20...sk1/tpg1/acls/iqn...client> set auth userid=laogao_user
Parameter userid is now 'laogao_user'.

/iscsi/iqn.20...sk1/tpg1/acls/iqn...client> set auth password=laogao_pass123
Parameter password is now 'laogao_pass123'.

# 退出保存
/> exit
Configuration saved to /etc/target/saveconfig.json
```

### 11.3 Initiator 配置 CHAP

修改 `/etc/iscsi/iscsid.conf`：

```ini
# 启用 CHAP
node.session.auth.authmethod = CHAP

# Initiator 提供给 Target 验证的用户名/密码
node.session.auth.username = laogao_user
node.session.auth.password = laogao_pass123
```

重启 iscsid：

```bash
systemctl restart iscsid
```

### 11.4 重新登录生效

```bash
# 登出再登录（让新配置生效）
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -u
[root@iscsi-client ~]# iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -l
```

### 11.5 验证

```bash
# 看会话是否带 CHAP 信息
[root@iscsi-client ~]# iscsiadm -m session -P 3
*****
CHAP:
*****
username: laogao_user
password: ********
```

---

## §12 CHAP 双向认证 mutual CHAP

### 12.1 mutual CHAP 是什么

**单向 CHAP 风险**：Initiator 信任 Target（万一 Target 是假的呢？）。

**双向 CHAP（mutual CHAP）**：Target 也向 Initiator 证明自己的身份。

```
双向 CHAP 流程：

  Initiator                            Target
      │                                  │
      │──── Login + CHAP_N (I 身份) ───>│
      │<──── CHAP Challenge ─────────────│
      │──── CHAP Response ──────────────>│  ← Target 验证 I
      │                                  │
      │<──── CHAP Challenge ─────────────│  ← Target 提供身份
      │──── CHAP Response ──────────────>│
      │                                  │
      │<──── Login Accept ───────────────│
```

### 12.2 Target 配置双向 CHAP

```bash
# 除了上面设置 Initiator 用户名/密码，还要设 Target 自己的用户名/密码

/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls/iqn.2026-04.cloud.laogao.iscsi-client

# 设 Target 端的 userid / password（mutual CHAP）
/iscsi/iqn.20...sk1/tpg1/acls/iqn...client> set auth userid_mutual=laogao_target
Parameter userid_mutual is now 'laogao_target'.

/iscsi/iqn.20...sk1/tpg1/acls/iqn...client> set auth password_mutual=laogao_target_pass456
Parameter password_mutual is now 'laogao_target_pass456'.

/> exit
```

### 12.3 Initiator 配置 mutual CHAP

`/etc/iscsi/iscsid.conf`：

```ini
# 启用 CHAP
node.session.auth.authmethod = CHAP

# Initiator 自己的用户名/密码
node.session.auth.username = laogao_user
node.session.auth.password = laogao_pass123

# Target 的用户名/密码（mutual CHAP）
node.session.auth.username_in = laogao_target
node.session.auth.password_in = laogao_target_pass456
```

```bash
systemctl restart iscsid
iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -u
iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -l
```

### 12.4 CHAP 密码规则

- 长度 **12 字符**以上
- 包含大小写字母、数字、特殊字符
- **Target 和 Initiator 的密码不能相同**（mutual CHAP 中）

---

## §13 ACL 访问控制：IQN 白名单

### 13.1 ACL 原理

**ACL（Access Control List）**：Target 上的 IQN 白名单。

```
Target: iqn.2026-04.cloud.laogao.iscsi-server:disk1
  ACL: 允许 iqn.2026-04.cloud.laogao.iscsi-client  ← 白名单
       拒绝其他所有 Initiator
```

### 13.2 配置 ACL

```bash
# 列出当前 ACL
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls ls

# 添加 ACL
/> /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls create iqn.2026-04.cloud.laogao.iscsi-client

# 删除 ACL
/> /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls delete iqn.2026-04.cloud.laogao.iscsi-client
```

### 13.3 `no-gen-acls` vs `gen-acls`

| 属性 | 行为 |
|------|------|
| `no-gen-acls`（默认） | 只有显式添加的 IQN 才能访问 |
| `gen-acls` | 自动为每个新连接的 Initiator 创建 ACL |

`gen-acls` 用于简化多客户端场景（如 50 台客户端），但**降低安全性**。

```bash
# 启用自动 ACL（不推荐生产环境）
/> /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1 set attribute generate_node_acls=1
```

---

## §14 multipath 多路径：dm-multipath + 多网卡绑定 + 故障切换

### 14.1 什么是多路径

> 多路径是指服务器和存储阵列存在多个物理连接方式使用虚拟设备，这种方式可以**提供更加弹性的存储连接**（一个路径 down 掉不会影响连接性），也可以**聚合存储带宽提供性能**。

```
多路径架构：

  ┌──────────── Initiator ────────────┐
  │                                   │
  │   网卡1 (10.1.8.11) ─┐           │
  │                       ├─→ mpatha (虚拟设备) ─→ 上层文件系统
  │   网卡2 (10.1.1.11) ─┘           │
  │                                   │
  └─────────────┬─────────────────────┘
                │ TCP/IP（两条物理路径）
  ┌─────────────┴─────────────────────┐
  │                                   │
  │   网卡1 (10.1.8.10) ─┐   Target   │
  │                       ├─→ 共享存储 │
  │   网卡2 (10.1.1.10) ─┘            │
  │                                   │
  └───────────────────────────────────┘
```

### 14.2 节点规划（多路径）

| 节点名 | IP | 角色 |
|--------|-----|------|
| iscsi-server | 10.1.8.10/24 (vmnet8), 10.1.1.10/24 (vmnet1) | Target（双网卡） |
| iscsi-client | 10.1.8.11/24 (vmnet8), 10.1.1.11/24 (vmnet1) | Initiator（双网卡） |

### 14.3 Target 端：创建双 Portal

```bash
# 安装 targetd / targetcli
yum install -y targetd targetcli
systemctl enable target --now
firewall-cmd --permanent --add-service=iscsi-target
firewall-cmd --reload

# 创建 backstore
targetcli /backstores/block create myblock1 /dev/sdb

# 创建 Target
targetcli /iscsi create iqn.2026-04.cloud.laogao.iscsi-server:disk1

# 绑定 LUN
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/luns create /backstores/block/myblock1

# 配置 ACL
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls create iqn.2026-04.cloud.laogao.iscsi-client

# 删除默认 Portal
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals delete 0.0.0.0 3260

# 添加两个 Portal（双网卡）
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals create 10.1.8.10 3260
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals create 10.1.1.10 3260

# 保存
targetcli saveconfig
```

### 14.4 验证 Target 端 Portal

```bash
[root@iscsi-server ~]# targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals ls
o- portals ........................................................... [Portals: 2]
  o- 10.1.1.10:3260 .......................................................... [OK]
  o- 10.1.8.10:3260 .......................................................... [OK]
```

### 14.5 multipath 由谁提供

> 多路径由 **dm-multipath** 子系统提供，使用内核 **device mapper** 系统获得虚拟设备，有 **multipathd 进程**和 **multipath 命令行工具**管理。
>
> 软件包 **device-mapper-multipath** 提供必要的 binaries、daemon 和 kernel modules。安装、配置、启动后，多路径设备节点会创建在两个位置。

### 14.6 multipath 设备节点位置

出于管理目的，multipath 设备创建在 **`/dev/mapper`**：
- 如果选择了 user-friendly 名称，这些设备也可以命名为 **`mpathN`**（如 `mpatha`）
- 也可以配置在 **WWID（World Wide ID）**之后
- 管理员也可以自定义多路径设备名（`multipath.conf` 中用 `alias` 选项）

多路径设备也会创建在 **`/dev`** 目录，格式为 **`/dev/dm-N`**（与 `/dev/mapper` 下的文件匹配）。
> 这些设备提供给系统内部使用，**禁止管理目的直接使用**。

```
/dev/mapper/mpatha   ← 管理员用这个
/dev/dm-3            ← 内核内部用，管理员别碰
```

### 14.7 安装 multipath

```bash
# Initiator 端
[root@iscsi-client ~]# yum install -y device-mapper-multipath

# 启用 multipath（生成 /etc/multipath.conf 配置文件）
[root@iscsi-client ~]# mpathconf --enable

# 等价形式（带 chkconfig）
[root@iscsi-client ~]# mpathconf --enable --with_multipathd y --with_chkconfig y

# 启动 multipathd
[root@iscsi-client ~]# systemctl enable multipathd --now
```

### 14.8 实战 3：完整 multipath 配置流程

```bash
# 步骤 1：配置 Initiator IQN
[root@iscsi-client ~]# vim /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2026-04.cloud.laogao.iscsi-client

# 步骤 2：从两个 Portal 发现 Target
[root@iscsi-client ~]# iscsiadm -m discovery -t st -p 10.1.8.10
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1
10.1.1.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1

[root@iscsi-client ~]# iscsiadm -m discovery -t st -p 10.1.1.10
10.1.8.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1
10.1.1.10:3260,1 iqn.2026-04.cloud.laogao.iscsi-server:disk1

# 步骤 3：登录所有 Target
[root@iscsi-client ~]# iscsiadm -m node -L all
```

### 14.9 ⚠️ 重要限制

> **重要：多路径提供存储访问路径 down 情况的保护。如果存储本身不可用，访问存储也会不可用。**

多路径是"路径冗余"，**不是"存储冗余"**。如果 Target 服务器整个宕机，multipath 也救不了。

### 14.10 Path Group 与切换

> 创建多路径设备，不同的路径将会合并到组中，取决于 `/etc/multipath.conf` 配置。
> 典型情况，**同一时刻只能激活一个组**，一个组可以包含多个路径。
> 当某个组故障，多路径进程将切换流量到不同组中。

### 14.11 确定路径是否指向同一设备：WWN / scsi_id / udevadm

> **WWN（World Wide Name）**，全球唯一名称，是由 IEEE 标准化的全球唯一标识符，用于标识存储设备（如硬盘、RAID 阵列、光纤交换机等），每个设备具有全球唯一名称。
>
> **应用场景**：在光纤通道（FC）、iSCSI 等存储网络中，用于识别和定位存储设备。
>
> WWN 是判断多路径设备是否指向同一存储设备的**核心依据**：所有属于同一多路径设备的物理路径（如 sdb、sdc），其对应的存储设备 WWN 必然相同。

#### 方法 1：`scsi_id` 命令

```bash
[root@iscsi-client ~]# /usr/lib/udev/scsi_id -g -u /dev/sdb
360014059a4a72ad3bf84b9bbb2ec0ffb

[root@iscsi-client ~]# /usr/lib/udev/scsi_id -g -u /dev/sdc
360014059a4a72ad3bf84b9bbb2ec0ffb
#                                                      ↑ WWN 完全相同
```

#### 方法 2：`udevadm` 命令

```bash
[root@iscsi-client ~]# udevadm info --query=property --name=/dev/sdb | grep ID_WWN_W
ID_WWN_WITH_EXTENSION=0x60014059a4a72ad3bf84b9bbb2ec0ffb

[root@iscsi-client ~]# udevadm info --query=property --name=/dev/sdc | grep ID_WWN_W
ID_WWN_WITH_EXTENSION=0x60014059a4a72ad3bf84b9bbb2ec0ffb
```

### 14.12 监控多路径：`multipath -ll`

```
-l   显示多路径拓扑简介
-ll  检测所有路径是否 active；包含每个多路径设备的三个部分：
     多路径设备 / path group / path group 成员
```

```bash
[root@iscsi-client ~]# multipath -ll
mpatha (360014059a4a72ad3bf84b9bbb2ec0ffb) dm-3 LIO-ORG ,myblock1
size=20G features='0' hwhandler='0' wp=rw
|-+- policy='service-time 0' prio=1 status=active
| `- 3:0:0:0 sdb 8:16 active ready running       ← 主路径（active）
`-+- policy='service-time 0' prio=1 status=enabled
  `- 4:0:0:0 sdc 8:32 active ready running       ← 备路径（enabled）
```

**字段解读**：

| 字段 | 含义 |
|------|------|
| `mpatha` | 用户友好名称（`user_friendly_names yes` 时） |
| `360014059a4...` | WWID |
| `dm-3` | 内核 device mapper 编号 |
| `LIO-ORG ,myblock1` | 厂商 / 设备名（来自 backstore 名） |
| `policy='service-time 0'` | 路径选择算法 |
| `prio=1` | 优先级 |
| `status=active` | 当前活动路径（主路径） |
| `status=enabled` | 备用可用路径（从路径） |
| `active ready running` | 路径在线 + 就绪 + 运行中 |
| `failed faulty running` | 路径故障 |

**默认行为**：policy `service-time 0` 属于 **主备模式（Active-Passive）**：
- 同一时间只走一条主路径
- 主路径断了，自动切到 sdc
- 平时 sdc 闲着，不跑流量

---

## §15 /etc/multipath.conf 详解：path_grouping_policy + path_selector + failback

### 15.1 配置文件 5 个部分

`/etc/multipath.conf` 包含 5 个 section：

| Section | 作用 | 优先级 |
|---------|------|--------|
| **defaults** | 所有多路径的默认配置 | 最低 |
| **blacklist** | 不允许使用的设备 | — |
| **blacklist_exceptions** | 应包含的设备（即使在 blacklist 中） | — |
| **devices** | 特定设备类型（按 vendor / product / revision 识别） | 覆盖 defaults |
| **multipaths** | 指定路径的特定配置（按 WWID 识别） | 最高 |

**覆盖优先级**：`multipaths > devices > defaults`

> 完整的默认设置可以参考 `/usr/share/doc/device-mapper-multipath-*/multipath.conf.defaults`。

### 15.2 defaults 关键选项

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `path_selector` | `"service-time 0"` | IO 路径选择算法 |
| `path_grouping_policy` | `failover` | 路径如何分组 |
| `path_check` | `directio` | 路径健康检查方法 |
| `features` | — | 启用的多路径功能 |
| `user_friendly_names` | `yes` | 是否用 `mpathN` 命名 |

#### path_selector：IO 路径选择算法

| 值 | 行为 |
|----|------|
| `"service-time 0"` | **默认**——选服务时间最少的路径 |
| `"round-robin 0"` | **轮询**——分发 IO 给所有路径（active-active） |
| `"queue-length 0"` | 选队列最短的路径 |

`rr_min_io_rq`：每个路径发多少 IO 后切换（用于 round-robin）。

#### path_grouping_policy：路径分组

| 值 | 行为 |
|----|------|
| `failover` | **默认**——每个路径独立一组（主备） |
| `multibus` | 所有路径合并到一组（active-active，需存储支持） |

> 在使用 `multibus` 前，**确保存储控制器支持 active-active 连接**。

#### features：多路径功能

```
features "1 queue_if_no_path"
            ↑    └─ 功能列表
            └─ 启用的功能数
```

| 功能 | 行为 |
|------|------|
| `queue_if_no_path` | 路径 fail 时，**IO 进程挂起**直到路径恢复 |
| `no_partitions` | 禁用分区识别 |

#### ⚠️ queue_if_no_path 的风险

> **警告**：如果启用了 `queue_if_no_path`，设置 features `"1 queue_if_no_path"`，路径 fail，处理 IO 的进程将挂起直到路径恢复。**这个行为在集群部署中是不希望看到的**，因为一个节点的 IO 挂起会导致集群其他节点访问存储。
>
> 解决方法：指定 `no_path_retry` 参数值为 `fail`，路径失败后将会**立刻通知更高层**，而非阻塞 IO 直到路径恢复。

### 15.3 multipaths 段：自定义特定 WWID

```bash
multipaths {
       multipath {
               wwid                   360014057202ac29e3cd4d24850ed82f3
               alias                  ClusterStorage
               path_grouping_policy   failover
       }
}

# 第二个例子：multibus 策略（active-active）
multipaths {
       multipath {
               wwid                   36001405bbc2fa575d0d46ec8951bc465
               alias                  ClusterStorage
               path_grouping_policy   multibus
       }
}
```

**验证别名生效**：

```bash
[root@iscsi-client ~]# multipath -ll
ClusterStorage (360014057202ac29e3cd4d24850ed82f3) dm-0 LIO-ORG ,clusterstor
size=4.0G features='0' hwhandler='0' wp=rw
`-+- policy='service-time 0' prio=1 status=active
  |- 2:0:0:0 sdb 8:16 active ready running
  `- 3:0:0:0 sda 8:0  active ready running
```

### 15.4 devices 段：按厂商/型号配置

```bash
devices {
       device {
               vendor                  "COMPAQ  "
               product                 "HSV110 (C)COMPAQ"
               path_grouping_policy    multibus
               path_checker            readsector0
               path_selector           "round-robin 0"
               hardware_handler        "0"
               failback                15
               rr_weight               priorities
               no_path_retry           queue
       }
}
```

按 `vendor` / `product` / `revision` 匹配（sysfs 正则）。

### 15.5 blacklist 段

```bash
blacklist {
       devnode "^vd[a-z]"        # 排除所有 virtio 块设备（/dev/vda, /dev/vdb...）
       wwid 1234567890abcde      # 排除特定 WWID
}
```

**查看磁盘 WWID**：

```bash
[root@iscsi-client ~]# /usr/lib/udev/scsi_id -g -u /dev/sda
360014057202ac29e3cd4d24850ed82f3
```

### 15.6 blacklist_exceptions 段

```bash
blacklist_exceptions {
       device {
               vendor  "IBM"
               product "S/390.*"
       }
}
```

> 即使设备在 blacklist 中，也强制包含。

### 15.7 实战 4：完整 multipath.conf 示例（生产环境）

```bash
# /etc/multipath.conf

defaults {
    user_friendly_names     yes
    path_grouping_policy    failover
    path_selector           "service-time 0"
    failback                immediate
    no_path_retry           fail            # 关键！避免 queue_if_no_path 阻塞
    polling_interval        5
}

blacklist {
    devnode "^vd[a-z]"       # 排除本地 virtio 盘
    devnode "^sda"           # 排除第一块本地盘
}

multipaths {
    multipath {
        wwid                   360014059a4a72ad3bf84b9bbb2ec0ffb
        alias                  iscsi_data
        path_grouping_policy   multibus       # active-active（需存储支持）
        path_selector          "round-robin 0"
    }
}

devices {
    device {
        vendor                 "LIO-ORG"
        product                ".*"
        path_grouping_policy   multibus
        path_selector          "round-robin 0"
    }
}
```

### 15.8 加载新配置

```bash
# 重新加载 multipathd（无需重启）
[root@iscsi-client ~]# multipath -r
# 或
[root@iscsi-client ~]# systemctl reload multipathd
```

### 15.9 使用多路径设备

```bash
# 多路径设备名是 /dev/mapper/mpatha（或自定义 alias 名）
[root@iscsi-client ~]# ls -l /dev/mapper/
mpatha -> ../dm-3

# 格式化
[root@iscsi-client ~]# mkfs.xfs /dev/mapper/mpatha

# 挂载
[root@iscsi-client ~]# mkdir /mpatha
[root@iscsi-client ~]# mount /dev/mapper/mpatha /mpatha
[root@iscsi-client ~]# df -h /mpatha/
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/mpatha     20G   33M   20G  1% /mpatha

# 持久化挂载（用 _netdev 等网络就绪）
[root@iscsi-client ~]# vim /etc/fstab
/dev/mapper/mpatha /mpatha xfs _netdev 0 0

[root@iscsi-client ~]# systemctl daemon-reload
[root@iscsi-client ~]# umount /mpatha
[root@iscsi-client ~]# mount -a
[root@iscsi-client ~]# df -h /mpatha
Filesystem            Size  Used Avail Use% Mounted on
/dev/mapper/mpatha     20G   33M   20G  1% /mpatha
```

---

## §16 iSCSI 性能调优：MTU 9000 巨型帧 + 多网卡 + TCP 拥塞控制

### 16.1 性能瓶颈分析

iSCSI 性能受三大因素影响：

```
网络带宽 ──> TCP 协议开销 ──> SCSI 命令开销
   │             │                  │
   │             │                  └─ 块级 I/O 路径
   │             └─ 拥塞控制、重传
   └─ MTU 大小、网卡速率
```

### 16.2 调优手段汇总

| 手段 | 性能提升 | 难度 | 风险 |
|------|----------|------|------|
| **MTU 9000 巨型帧** | 30-50% | 中 | 需全链路支持 |
| **多网卡绑定 / multipath** | 100%（聚合带宽） | 高 | 配置复杂 |
| **TCP 拥塞控制算法** | 10-20% | 低 | — |
| **专用存储网络（VLAN 隔离）** | 减少干扰 | 中 | — |
| **RSS / 多队列网卡** | CPU 占用分摊 | 中 | — |
| **IRQ 亲和性 / 中断合并** | 减少 CPU 中断 | 高 | 调错风险 |

### 16.3 MTU 9000 巨型帧

默认以太网 MTU = 1500 字节。巨型帧（jumbo frame）MTU = 9000 字节。

**优势**：单次传输更多数据 → 减少包头开销 → 提升吞吐 30-50%。

**前提**：**全链路所有设备必须支持**（网卡、交换机、Target、Initiator）。

#### 检查与配置

```bash
# 查看当前 MTU
ip link show ens33 | grep mtu

# 临时设置 MTU 9000
ip link set ens33 mtu 9000

# 持久化（CentOS 7）
# /etc/sysconfig/network-scripts/ifcfg-ens33
MTU=9000

systemctl restart network
```

**验证**：

```bash
# 测试 MTU（不要分片）
ping -M do -s 8972 10.1.8.10
#      ↑ 不要分片   ↑ payload 8972 + 8 ICMP + 20 IP = 9000
```

### 16.4 TCP 拥塞控制算法

CentOS 7 默认是 **cubic**。存储场景可考虑 **hybla**（高带宽长延迟链路）或 **bbr**（低延迟高带宽）。

```bash
# 查看当前算法
sysctl net.ipv4.tcp_congestion_control

# 临时切换
sysctl -w net.ipv4.tcp_congestion_control=hybla

# 持久化
# /etc/sysctl.d/10-iscsi.conf
net.ipv4.tcp_congestion_control = hybla
```

### 16.5 内核网络缓冲区

```bash
# /etc/sysctl.d/10-iscsi.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 30000
```

### 16.6 多网卡绑定 + multipath 聚合

参考 [[#§14 multipath 多路径]] 和 [[#§15 /etc/multipath.conf 详解]]。

| 模式 | 性能 | 冗余 |
|------|------|------|
| bond + iSCSI（无 multipath） | 单路径带宽 | 切换时短暂中断 |
| multipath + failover | 单路径带宽 | 秒级自动切换 |
| multipath + multibus + round-robin | **聚合带宽** | 任意路径 down 不中断 |

### 16.7 iSCSI 节点级调优

```bash
# 替换 timeout 参数（提升重试容忍度）
iscsiadm -m node -T iqn...disk1 -o update -n node.session.timeo.replacement_timeout -v 300
```

---

## §17 iSCSI 与防火墙：3260 端口 + firewalld rich rule

### 17.1 防火墙必须放行 3260

iSCSI 默认端口 **TCP 3260**。

```bash
# firewalld 简单方式（使用预定义服务）
firewall-cmd --permanent --add-service=iscsi-target
firewall-cmd --reload

# 等价的 rich rule
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.1.8.0/24 port port=3260 protocol=tcp accept'
firewall-cmd --reload

# iptables
iptables -A INPUT -p tcp --dport 3260 -s 10.1.8.0/24 -j ACCEPT
```

### 17.2 多路径防火墙：源 IP 限制

```bash
# 仅允许来自存储子网的连接
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.1.8.11/32 port port=3260 protocol=tcp accept'
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.1.1.11/32 port port=3260 protocol=tcp accept'
firewall-cmd --reload
```

### 17.3 SELinux 注意事项

CentOS 7 / RHEL 默认开启 SELinux。iSCSI 通常无需特别调整 SELinux 策略，但有些场景需要：

```bash
# 查看 SELinux 拒绝日志
ausearch -m avc -ts recent | grep iscsi

# 临时宽容
setenforce 0

# 永久：/etc/selinux/config
SELINUX=permissive
```

---

## §18 iSCSI 安全：CHAP + IPsec + 隔离 VLAN + IQN 白名单

### 18.1 多层安全模型

```
┌────────────────────────────────────────┐
│ 1. 物理 / 网络层：VLAN 隔离、专用交换机 │
│ 2. 认证层：CHAP 单/双向                │
│ 3. 授权层：ACL（IQN 白名单）           │
│ 4. 加密层：IPsec（可选，跨 WAN 必选）  │
│ 5. 防火墙层：3260 端口 + 源 IP 限制    │
└────────────────────────────────────────┘
```

### 18.2 安全建议清单

| 层级 | 措施 | 优先级 |
|------|------|--------|
| 网络 | 专用 VLAN / 物理隔离存储网络 | 必须 |
| 认证 | CHAP 单向（最低），双向（推荐） | 必须 |
| 授权 | ACL 显式指定允许的 IQN | 必须 |
| 加密 | IPsec（WAN 必选，LAN 可选） | 推荐 |
| 防火墙 | 3260 端口 + 源 IP 限制 | 必须 |
| 监控 | 审计登录日志 | 推荐 |
| 操作 | 禁用 `gen-acls`，手动管理 ACL | 必须 |

### 18.3 IPsec 加密 iSCSI

**场景**：iSCSI 流量需要跨 WAN 或不可信网络。

```bash
# CentOS 7 使用 libreswan
yum install -y libreswan

# /etc/ipsec.d/iscsi.conf
conn iscsi-encrypted
    left=10.1.8.10          # Target 公网 IP
    right=10.1.8.11         # Initiator 公网 IP
    authby=secret
    esp=aes256-sha256
    auto=start
```

> ⚠️ **性能代价**：IPsec 加解密会消耗 CPU，导致吞吐量下降 20-40%。

---

## §19 iSCSI 故障排查：iscsiadm -m session + /var/log/messages

### 19.1 排查清单

| 现象 | 排查点 |
|------|--------|
| discovery 失败 | 网络连通性、3260 端口、Target 服务状态、防火墙 |
| login 失败 | ACL IQN 不匹配、CHAP 密码错误、Target IQN 拼写 |
| 看不到新设备 | dmesg、lsblk、iscsiadm -m session |
| 性能差 | 网络 MTU、TCP 拥塞、网卡绑定、存储本身 |
| multipath 切换失败 | multipathd 状态、/etc/multipath.conf、scsi_id |
| 开机不自动挂载 | `_netdev` 缺失、iscsi 服务未自启、UUID 错误 |

### 19.2 关键排查命令

```bash
# 查看会话状态
iscsiadm -m session -P 3

# 查看已发现目标
iscsiadm -m node

# 查看 Initiator IQN
cat /etc/iscsi/initiatorname.iscsi

# 查看 Target 服务状态
systemctl status target

# 查看 Target 配置
targetcli ls

# 查看内核日志（新设备识别）
dmesg | tail -50

# 查看系统日志（iscsid）
tail -f /var/log/messages

# 查看通过 by-path 的 iSCSI 设备
ls -l /dev/disk/by-path/*iscsi*

# 网络连通性
ping 10.1.8.10
nc -zv 10.1.8.10 3260

# multipath 状态
multipath -ll
systemctl status multipathd
```

### 19.3 典型故障案例

#### 故障 1：discovery 成功但 login 失败

```
错误信息：
Login failed: initiator failed authorization
```

**原因**：客户端 IQN 与 Target ACL 不匹配。

**修复**：
```bash
# 1. 查看 Initiator 实际 IQN
cat /etc/iscsi/initiatorname.iscsi

# 2. 在 Target 端添加 ACL
targetcli /iscsi/iqn.2026-04.../tpg1/acls create iqn.2026-04.cloud.laogao.iscsi-client

# 3. 重启 iscsid
systemctl restart iscsid
```

#### 故障 2：客户端 IQN 不正确

> 可能是客户端上的启动器 IQN 不正确引起的，请在客户端的 `/etc/iscsi/initiatorname.iscsi` 文件中修复 IQN，然后**重新启动 iscsid 服务**以使更改生效。

#### 故障 3：CHAP 密码不一致

```bash
# 检查 Target 端的 CHAP 配置
targetcli /iscsi/iqn.2026-04.../tpg1/acls/iqn...client ls

# 检查 Initiator 端的 iscsid.conf
grep -E 'authmethod|username|password' /etc/iscsi/iscsid.conf
```

---

## §20 易错点 ×10

| # | 易错点 | 后果 | 正确做法 |
|---|--------|------|----------|
| 1 | **IQN 写错（大小写/拼写）** | login 失败 | 严格按 `iqn.YYYY-MM.reversed.domain` 格式 |
| 2 | **ACL 没添加** | discovery 成功但 login 失败 | Target 端 `acls create <initiator IQN>` |
| 3 | **CHAP 密码不一致** | login 失败 | Target 与 Initiator 密码必须一致，密码长度 ≥12 |
| 4 | **multipath 没启用** | 一条路径 down 就挂 | 安装 `device-mapper-multipath` + `mpathconf --enable` |
| 5 | **fstab 用 /dev/sdX 不用 UUID** | 启动时设备名变化导致挂错 | 必须用 `blkid` 查到的 UUID |
| 6 | **fstab 没用 _netdev** | 网络未就绪就尝试挂载，失败 | 加上 `_netdev` 选项 |
| 7 | **iscsi 服务没设开机自启** | 重启后无法自动连接 | `systemctl enable iscsi iscsid multipathd` |
| 8 | **多客户端同时挂载同一 iSCSI 文件系统** | 文件系统损坏 | 用 GFS2/OCFS2，或 NFS 代替文件共享 |
| 9 | **Portal 用 0.0.0.0 太宽** | 任何 IP 都能连，不安全 | 改为指定 IP（如 `10.1.8.10 3260`） |
| 10 | **targetcli 命令行模式不 saveconfig** | 重启后配置丢失 | 命令行模式必须显式 `targetcli saveconfig` |

---

## §21 速查表：端口 + 关键路径 + targetcli 命令树

### 21.1 关键端口与路径

| 项 | 值 |
|----|----|
| **iSCSI 端口** | TCP **3260** |
| **Target 软件包** | `targetd`, `targetcli` |
| **Initiator 软件包** | `iscsi-initiator-utils` |
| **multipath 软件包** | `device-mapper-multipath` |
| **Target 配置保存** | `/etc/target/saveconfig.json` |
| **Target 配置备份** | `/etc/target/backup/` |
| **Initiator IQN 文件** | `/etc/iscsi/initiatorname.iscsi` |
| **Initiator 配置** | `/etc/iscsi/iscsid.conf` |
| **发现记录** | `/var/lib/iscsi/nodes/` |
| **multipath 配置** | `/etc/multipath.conf` |
| **multipath 默认配置参考** | `/usr/share/doc/device-mapper-multipath-*/multipath.conf.defaults` |
| **multipath 设备** | `/dev/mapper/mpathN` 或 `/dev/mapper/<alias>` |
| **内核内部设备** | `/dev/dm-N`（管理员别直接用） |

### 21.2 targetcli 命令树

```
/                                                  ← 根
├── backstores/
│   ├── block/        create <name> <device>        ← 创建块设备 backstore
│   ├── fileio/       create <name> <file> <size>  ← 创建文件 backstore
│   ├── pscsi/        create <name> <device>        ← 物理 SCSI 透传
│   └── ramdisk/      create <name> <size>          ← 内存盘
├── iscsi/
│   └── create <iqn>                                ← 创建 Target
│       └── tpg1/
│           ├── acls/       create <initiator_iqn>  ← 添加 ACL
│           │               set auth userid/password[/userid_mutual/password_mutual]
│           ├── luns/       create <backstore_path> ← 绑定 LUN
│           └── portals/    delete <ip> <port>      ← 删除 Portal
│                          create <ip> <port>       ← 新建 Portal
└── loopback/

全局命令：
  ls                          ← 查看当前路径结构
  cd <path>                   ← 切换路径
  saveconfig                  ← 显式保存（命令行模式必须）
  exit                        ← 退出（交互模式自动保存）
```

### 21.3 iscsiadm 命令速查

```bash
# 发现
iscsiadm -m discovery -t st -p <portal_ip>[:port]

# 登录
iscsiadm -m node -T <target_iqn> [-p <portal_ip>[:port]] -l

# 登录所有
iscsiadm -m node -L all

# 查看会话
iscsiadm -m session [-P <0-3>]

# 查看已发现目标
iscsiadm -m node

# 登出
iscsiadm -m node -T <target_iqn> -p <portal_ip>[:port] -u

# 删除本地记录
iscsiadm -m node -T <target_iqn> -p <portal_ip>[:port] -o delete

# 更新参数
iscsiadm -m node -T <target_iqn> -o update -n <param> -v <value>
```

### 21.4 multipath 命令速查

```bash
# 查看状态
multipath -ll

# 重新加载配置
multipath -r

# 查看拓扑（简介）
multipath -l

# 查看路径 WWID
/usr/lib/udev/scsi_id -g -u /dev/sdX

# 启动 multipathd
systemctl start multipathd
```

---

## §22 面试 6 大追问

### Q1：iSCSI 和 NFS 的区别？什么场景用哪个？

**答**：

| 维度 | iSCSI | NFS |
|------|-------|-----|
| 协议层级 | 块级 | 文件级 |
| 客户端看到 | `/dev/sdX`（裸盘） | 挂载的目录（已格式化） |
| 客户端处理 | 自己分区、格式化、挂载 | 直接读写文件 |
| 共享方式 | 共享"整块盘" | 共享"目录树" |
| 性能 | 高（少一层协议栈） | 略低 |
| 并发共享 | 不支持（除非集群 FS） | 支持（文件级锁） |
| 适用场景 | 数据库、虚拟化裸设备映射 | 文件共享、Web 静态资源 |

**判断**：需要"裸盘"用 iSCSI；需要"文件共享"用 NFS。

### Q2：CHAP 双向认证的原理？Target 和 Initiator 各自的密码怎么配置？

**答**：

```
单向 CHAP：Initiator 知道密码 → Target 验证它
双向 CHAP：双方各自持有对方知道的密码，互相验证
```

**Target 端（targetcli）**：
```bash
# Initiator 验证用的密码
set auth userid=<initiator_user>
set auth password=<initiator_password>

# Target 自己出示给 Initiator 验证的密码
set auth userid_mutual=<target_user>
set auth password_mutual=<target_password>
```

**Initiator 端（iscsid.conf）**：
```ini
node.session.auth.authmethod = CHAP

# 我出示给 Target 的
node.session.auth.username = <initiator_user>
node.session.auth.password = <initiator_password>

# 我用来验证 Target 的
node.session.auth.username_in = <target_user>
node.session.auth.password_in = <target_password>
```

### Q3：multipath 故障切换流程是什么？

**答**：

```
正常状态：
  mpatha (WWID)
    ├─ path group 1 (status=active)
    │    └─ sdb (active ready running)        ← 主路径
    └─ path group 2 (status=enabled)
         └─ sdc (active ready running)        ← 备路径

sdb 网线断开 → multipathd 检测到路径 down（默认 5s 轮询）：

  mpatha (WWID)
    ├─ path group 1 (status=enabled)          ← 旧的 active 变 enabled
    │    └─ sdb (failed faulty running)       ← 标记故障
    └─ path group 2 (status=active)           ← 切换成功
         └─ sdc (active ready running)        ← 接管流量

sdb 恢复 → 默认 failback=manual（不自动切回）：
  multipathd 会标记 sdb 为 enabled，但 active 路径保持 sdc
  如要切回：multipathd reconfigure 或修改 failback=immediate
```

**重要**：**故障路径恢复后，当前的 active path 保持不变，即使恢复的路径之前是 active path，可以通过手动切换回来**。

### Q4：iSCSI Target 上的 LUN 和 Initiator 上的磁盘是什么关系？

**答**：

```
Target 端：
  backstores/block/myblock1  ← /dev/sdb（一块物理盘或 LVM）
    ↓ 绑定为
  LUN 0（Target 视图的"第一个 LUN"）

Initiator 端：
  Login 后，看到 sdb（不一定叫 sdb，取决于内核 SCSI 扫描顺序）
  sdb ← 对应 Target 的 LUN 0
  此时 /dev/disk/by-path/ 下会有 ip-...-iscsi-...-lun-0 的符号链接

常见误解：
  - LUN 不是"磁盘号"，而是"逻辑单元号"
  - 一个 Target 可以暴露多个 LUN（多块盘）
  - 一个 Initiator 可以登录多个 Target，看到多个 sdb/sdc/sdd
```

### Q5：为什么 fstab 必须用 UUID + _netdev？

**答**：

```
/dev/sdb 的命名问题：
  - iSCSI 设备出现顺序由网络扫描顺序决定
  - 重启后 /dev/sdb 可能变成 /dev/sdc
  - 直接用设备名 → 挂载错乱 / 失败

UUID 解决方案：
  blkid → 拿到 UUID → /etc/fstab 用 UUID=xxx
  UUID 跟随文件系统，不跟随设备名 → 永远正确

_netdev 解决方案：
  iSCSI 是网络设备，启动时如果网络没起来就尝试挂载 → 失败
  _netdev 告诉 systemd："等网络起来再挂这个"
  
顺序：网络 → iscsid/iscsi 启动 → 发现+登录 Target → 看到块设备 → 挂载
```

### Q6：iSCSI 性能瓶颈通常在哪？怎么优化？

**答**：

**瓶颈 1：网络**（最常见）
- 默认 MTU 1500 → **改 9000 巨型帧**（全链路支持）
- 单网卡 → **多网卡绑定 + multipath multibus**

**瓶颈 2：TCP 协议**
- 默认 cubic → **hybla / bbr**（长延迟链路）
- 调整 `tcp_rmem` / `tcp_wmem` 缓冲区

**瓶颈 3：存储后端**
- 单块 HDD → **RAID 10 / SSD**
- 单机本地盘 → **共享存储（FC SAN）**

**瓶颈 4：iSCSI 协议**
- 默认 `MaxBurstLength=262144`（256 KB）→ 调大
- `ImmediateData=Yes` → 减少 R2T 往返

**最佳实践**：专用 10 GbE 网络 + MTU 9000 + multipath multibus + TCP bbr。

---

## §23 跨模块链接

| 主题 | 链接 |
|------|------|
| 块设备基础（lsblk / df / fdisk） | [[Linux存储#§2 lsblk 看设备树]] |
| LVM（在 iSCSI 上做 LVM） | [[Linux存储#§15-19 LVM]] |
| 多路径与多网卡（bonding） | [[Linux网络#bonding]] |
| MTU 巨型帧配置 | [[Linux网络#mtu]] |
| 防火墙放行 iSCSI 端口 | [[Linux防火墙#iscsi]] |
| iSCSI 与 NFS 块级 vs 文件级 | [[LinuxNFS#vs-iscsi]] |
| 服务自启（systemctl） | [[Linux服务与SSH#systemctl]] |
| 日志分析（/var/log/messages） | [[Linux日志与时间]] |
| 文件系统（mkfs.xfs / fstab） | [[Linux存储#§8-10 mkfs mount fstab]] |
| SSH 远程管理（多主机操作） | [[Linux服务与SSH#ssh]] |
| 阿里云 / 云上 iSCSI 替代品 | [[Linux云与虚拟化#EBS]] |
| RAID + iSCSI 后端 | [[Linux存储#§11-14 RAID]] |

---

## 附录 A：完整命令历史示例（PDF 第 2-18 页实战摘录）

```bash
# ====== Target 端 ======
# iscsi-server 10.1.8.10
yum install -y targetd targetcli
systemctl enable target --now
firewall-cmd --permanent --add-service=iscsi-target
firewall-cmd --reload

# 创建 disk1（/dev/sdb）
targetcli
/> /backstores/block create myblock1 /dev/sdb
/> /iscsi create iqn.2026-04.cloud.laogao.iscsi-server:disk1
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/luns
/> create /backstores/block/myblock1
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/acls
/> create iqn.2026-04.cloud.laogao.iscsi-client
/> cd /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals
/> delete 0.0.0.0 3260
/> create 10.1.8.10 3260
/> exit

# 创建 disk2（/dev/sdc），命令行模式
targetcli /backstores/block create myblock2 /dev/sdc
targetcli /iscsi create iqn.2026-04.cloud.laogao.iscsi-server:disk2
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/luns create /backstores/block/myblock2
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/acls create iqn.2026-04.cloud.laogao.iscsi-client
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/portals delete 0.0.0.0 3260
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk2/tpg1/portals create 10.1.8.10 3260
targetcli saveconfig

# ====== Initiator 端 ======
# iscsi-client 10.1.8.11
yum install -y iscsi-initiator-utils
vim /etc/iscsi/initiatorname.iscsi
# InitiatorName=iqn.2026-04.cloud.laogao.iscsi-client

# 发现 + 登录
iscsiadm -m discovery -t st -p 10.1.8.10
iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -l
lsblk                                # 看到 sdb
iscsiadm -m session -P 3             # 看详细信息

# 格式化 + 挂载
mkfs.xfs /dev/sdb
mkdir /sdb
mount /dev/sdb /sdb
echo xixihaha > /sdb/test

# 持久化
echo 'UUID="81629560-cb56-4c19-814f-7f946d731b02" /data xfs defaults,_netdev 0 0' >> /etc/fstab
systemctl enable iscsi

# 断开
umount /data
iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -u
iscsiadm -m node -T iqn.2026-04.cloud.laogao.iscsi-server:disk1 -p 10.1.8.10:3260 -o delete

# ====== multipath ======
# Target 端：添加第二个 Portal（10.1.1.10）
targetcli /iscsi/iqn.2026-04.cloud.laogao.iscsi-server:disk1/tpg1/portals create 10.1.1.10 3260
targetcli saveconfig

# Initiator 端
yum install -y device-mapper-multipath
mpathconf --enable
systemctl enable multipathd --now

# 从两个 Portal 发现
iscsiadm -m discovery -t st -p 10.1.8.10
iscsiadm -m discovery -t st -p 10.1.1.10

# 登录所有
iscsiadm -m node -L all

# 验证 WWN 一致
/usr/lib/udev/scsi_id -g -u /dev/sdb
/usr/lib/udev/scsi_id -g -u /dev/sdc
# 两个应该相同

# 看 multipath 拓扑
multipath -ll
# mpatha (360014059a4a72ad3bf84b9bbb2ec0ffb) dm-3 LIO-ORG ,myblock1
# size=20G features='0' hwhandler='0' wp=rw
# |-+- policy='service-time 0' prio=1 status=active
# | `- 3:0:0:0 sdb 8:16 active ready running
# `-+- policy='service-time 0' prio=1 status=enabled
#   `- 4:0:0:0 sdc 8:32 active ready running

# 挂载多路径设备
mkfs.xfs /dev/mapper/mpatha
mkdir /mpatha
mount /dev/mapper/mpatha /mpatha

# 持久化
echo '/dev/mapper/mpatha /mpatha xfs _netdev 0 0' >> /etc/fstab

# ====== 高可用性测试 ======
# 测试 1：断开第二块网卡（vmnet1）
nmcli device disconnect ens36

# multipath -ll 显示：
# |-+- policy='service-time 0' prio=1 status=active
# | `- 3:0:0:0 sdb 8:16 active ready running           ← active 不变
# `-+- policy='service-time 0' prio=0 status=enabled
#   `- 4:0:0:0 sdc 8:32 failed faulty running          ← sdc 故障

# 测试 2：恢复第二块网卡，断开第一块网卡
# active path group 发生故障
# active path group 状态变更：active → enabled
# passive path group 状态变更：enabled → active
# sdb 变 failed faulty running
# sdc 变 active ready running
```

---

## 附录 B：常见错误信息速查

| 错误信息 | 原因 | 修复 |
|----------|------|------|
| `iscsiadm: cannot make connection to 10.1.8.10: Connection refused` | Target 服务未启动 / 3260 端口未监听 | `systemctl start target` |
| `iscsiadm: discovery login to 10.1.8.10 rejected: initiator failed authorization` | ACL 不匹配 | Target 端 `acls create <initiator_iqn>` |
| `iscsiadm: CHAP authentication failed` | CHAP 密码错误 | 检查 `iscsid.conf` 与 Target 端密码 |
| `Login failed: could not connect to iscsid` | iscsid 服务未启动 | `systemctl start iscsid` |
| `mount: special device /dev/sdb does not exist` | 未登录 Target | `iscsiadm -m node -l` |
| `mount: wrong fs type, bad option, bad superblock` | 文件系统未格式化 / 损坏 | `mkfs.xfs /dev/sdb` |
| `kernel: sd 3:0:0:0: [sdb] Write Protect is on` | backstore 配置为只读 | `targetcli` 中 LUN 改为 `wp=false` |
| `multipathd: dm-3: remove path (8:16) failed` | multipath 路径丢失 | 检查物理连接 / 重启 multipathd |

---

> **总结**：iSCSI 是把"远端硬盘"接到本地最经典的方案。掌握 **targetcli 5 步法** + **iscsiadm 4 大模式** + **multipath 配置** + **CHAP 认证**，就能覆盖 80% 的生产场景。
