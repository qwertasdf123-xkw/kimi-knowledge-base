---
title: 路由与 VLAN — 跨网段通信的核心技术
desc: 基于 04.网络技术基础-入门版.pdf 整合 PDF 05 路由基础 + 07 VLAN 原理与配置 + 08 实现 VLAN 间通信, 共 43 页的笔记。覆盖路由表/路由获取/静态路由/默认路由、VLAN 原理/802.1Q/Access+Trunk+Hybrid、单臂路由、三层交换。
type: 笔记
module: 路由与VLAN
pdfs:
  - 04.网络技术基础-入门版.pdf（108 页，14.3 MB）
pdf_size: 整合 05 + 07 + 08 共 3 章 ≈ 43 页
scope: 通用（华为命令为主，可对照 Cisco）
status: 完成
---

# 路由与 VLAN — 跨网段通信的核心技术

> **范围**：基于《网络技术基础-入门版》PDF 整合了 3 个章节（43 页）：
> - **05 路由基础** — 路由表 + 路由获取 + 静态路由 + 默认路由
> - **07 VLAN 原理与配置** — VLAN 原理 + 802.1Q + 3 种接口类型 + 划分方式
> - **08 实现 VLAN 间通信** — 单臂路由 + 三层交换
>
> **网络基础理论**（OSI/IP/MAC/ARP）见：[[../网络基础原理/网络基础原理]]
> **华为 VRP 命令行** 见：[[../华为VRP/华为VRP]]
>
> **前置**：[[../网络基础原理/网络基础原理]] 中 Layer 2/3 概念 + 子网划分

## 目录

- [[#§0 心智模型：路由 = 快递分拣中心]]
- [[#§1 路由基础：路由表 4 大字段]]
- [[#§2 路由获取方式：直连/静态/动态]]
- [[#§3 静态路由 + 默认路由]]
- [[#§4 路由转发流程：最长掩码匹配]]
- [[#§5 VLAN 是什么：解决广播域问题]]
- [[#§6 VLAN 标签[[#§5 VLAN 是什么：解决广播域问题]][[#§6 VLAN 标签：802.1Q 帧格式]]：802.1Q 帧格式]]
- [[#§7 VLAN 划分方式 5 种]]
- [[#§8 VLAN 接口类型：Access / Trunk / Hybrid]]
- [[#§9 单臂路由：路由器单接口 + 子接口]]
- [[#§10 三层交换：交换机内置路由模块]]
- [[#§11 VLAN 间通信方案对比]]
- [[#§12 易错点 ×10]]
- [[#§13 速查表]]
- [[#§14 面试 6 大追问]]

---

## §0 心智模型：路由 = 快递分拣中心

把路由想象成 **快递分拣中心**：

| 路由概念 | 快递比喻 | 实际 |
|---|---|---|
| 路由器 | 分拣中心 | 网络层设备 |
| 路由表 | 分拣指南 / 地图 | 目的网段 → 下一跳 |
| 数据包 | 一个个包裹 | IP 包 |
| 目的 IP | 包裹的目的地址 | 决定走哪条路由 |
| 下一跳 | 下个分拣中心地址 | 数据包下一个交给谁 |
| 出接口 | 这条分拣线的快递员 | 路由器从哪个口出发 |
| 默认路由 | "找不到就走这条总路线" | 0.0.0.0/0 |
| 静态路由 | 手工画的地图（不自动更新） | 管理员手写 |
| 动态路由 | 智能地图（自动更新） | OSPF / RIP / BGP |

### 核心洞察

> **"路由器的工作就是查表转发：'这个包要去 X，下一跳是 Y，从我 Z 口出去'"** —— 这是 §1-§4 的全部内容。

### VLAN 心智模型：办公室格子间

把 VLAN 想象成 **办公楼的楼层 / 部门**：

```
同楼层员工 → 自由走动（同一 VLAN = 同一广播域）

    3F 财务部  ← VLAN 10
    4F 工程部  ← VLAN 20
    5F 销售部  ← VLAN 30

跨部门协作 → 必须"下楼交换信息"（路由或三层交换）
```

> **VLAN = 在一台物理交换机上切出多个逻辑广播域**，每 VLAN 一个办公室格子。

---

## §1 路由基础：路由表 4 大字段（PDF 05）

### 1.1 路由的本质

> **"网络中每个节点使用 IP 地址标识，每个 IP 地址都拥有自己的网段，各个网段可能分布在网络的不同区域。"**

**路由** = 指导报文转发的**路径信息**。

**路由器** = 依据路由、转发报文到目的网段的**网络设备**。
- 维护一张**路由表**，保存路由信息
- 通过路由表指导如何转发 IP 报文

### 1.2 路由表的 4 大字段

每条路由包含：

| 字段 | 含义 | 示例 |
|---|---|---|
| **目的网络 / 掩码** | IP 包要去的目的网段 | `10.1.1.0 / 24` |
| **出接口** | 包离开本路由器的哪个口 | `GE0/0/0` |
| **下一跳** | 包下一个交给谁（路由器 IP） | `1.1.1.2` |
| **协议（Proto）** | 这条路由是如何获取的（直连/静态/OSPF） | `Static` |

**华为命令查看**：

```bash
display ip routing-table

# 输出：
Destination/Mask   Proto   Pre   Cost    NextHop         Interface
10.1.1.0/24        Direct  0     0       10.1.1.1        GigabitEthernet0/0/1
0.0.0.0/0          Static  60    0       192.168.1.1     GigabitEthernet0/0/0
```

### 1.3 路由表字段详解

#### Destination/Mask（目的网络/掩码）

```
将目的 IP 和子网掩码 "逻辑与" 后得到目的主机所在网段。
例：目的地址 = 1.1.1.1，掩码 = 255.255.255.0
1.1.1.1 AND 255.255.255.0 = 1.1.1.0  ← 网段
```

#### Proto（协议类型）

| 值 | 含义 |
|---|---|
| `Direct` | 直连路由（接口配上 IP 自动产生） |
| `Static` | 静态（管理员手写） |
| `OSPF` | 动态路由协议 OSPF |
| `RIP` | 动态路由协议 RIP |
| `BGP` | 动态路由协议 BGP |

#### Pre（Preference 优先级）

**值越小越优先**。同一目的地多条路由时，Pre 最小者胜出。

| 路由类型 | 默认 Pre |
|---|---|
| 直连 | 0 |
| 静态 | 60 |
| OSPF | 10 |
| ISIS | 15 |
| RIP | 100 |
| BGP | 255 |

#### Cost（开销）

**Pre 相同时，Cost 最小者胜出**。

```
到达同一目的的 2 条路由：
  路由 A：Pre=60, Cost=3
  路由 B：Pre=60, Cost=1  ← 胜出（成本低）
```

#### NextHop + Interface（下一跳 + 出接口）

**告诉路由器**：包发往**这个 IP**，从我**这个接口**出去。

### 1.4 路由表匹配规则

> **最长前缀匹配（Longest Prefix Match）**：从最具体的路由开始查。

```
路由表：
  10.1.0.0/16  → 1.1.1.1   （最不具体）
  10.1.1.0/24  → 2.2.2.2   （中等）
  10.1.1.0/28  → 3.3.3.3   （最具体）

要访问 10.1.1.5？
  ↓
匹配 10.1.1.0/28（最具体）→ 下一跳 3.3.3.3  ✓ 胜出
```

### 1.5 显示路由表

```bash
# Cisco
show ip route

# 华为 VRP
display ip routing-table

# 输出关键字段详解
[Huawei] display ip routing-table
Route Flags: R - relay, D - download to fib
------------------------------------------------------------------------------
Routing Tables: Public
         Destinations : 6        Routes : 6

Destination/Mask    Proto   Pre  Cost  Flags NextHop         Interface
        0.0.0.0/0   Static  60   0     RD    192.168.1.1    GE0/0/0
     192.168.1.0/24 Direct  0    0     D     192.168.1.254  GE0/0/0
```

### 易错点

- ❌ "Pre 越大越优先" → **Pre 越小越优先**
- ❌ 直连路由是路由协议一种 → 直连不算协议，是默认存在（Pre=0）
- ❌ 路由表里没条目就丢包 → 默认路由兜底（0.0.0.0/0）

---

## §2 路由获取方式：直连/静态/动态（PDF 05）

### 2.1 三种获取方式

| 方式 | 谁添加 | 怎么来 | 适用 |
|---|---|---|---|
| **直连路由**（Direct） | 路由器自动 | 接口配上 IP + up 状态就出现 | 直连网段 |
| **静态路由**（Static） | 管理员手写 | 手动 `ip route-static` | 小型稳定网络 |
| **动态路由**（Dynamic） | 路由协议自动学 | OSPF / RIP / BGP 自动交换 | 中大型网络 |

### 2.2 直连路由

**何时产生**：接口配了 IP 地址、链路是 up/up。

```bash
[Huawei] interface GigabitEthernet0/0/0
[Huawei-GigabitEthernet0/0/0] ip address 192.168.1.254 24
[Huawei-GigabitEthernet0/0/0] quit

# 自动出现
[Huawei] display ip routing-table
# Destination/Mask   Proto  Pre  Cost  NextHop       Interface
# 192.168.1.0/24    Direct  0   0     192.168.1.254 GE0/0/0
```

**特点**：
- Pre = 0（最高优先级）
- 路由器只对**直连**网段"天然可达"
- 跨网段通信必须**配置路由**

### 2.3 静态路由

**适用**：拓扑结构简单并且稳定的小型网络。
**缺点**：不能自动适应网络拓扑的变化，需要人工干预。

### 2.4 动态路由协议（核心对比）

| 协议 | 算法 | 度量值 | 网络规模 | 厂商 |
|---|---|---|---|---|
| **RIP** | 距离矢量 | 跳数 | ≤ 15 跳 | 所有 |
| **OSPF** | 链路状态 | Cost（带宽反比） | 大 | 所有 |
| **IS-IS** | 链路状态 | Cost | 运营商级 | 大厂 |
| **BGP** | 路径矢量 | 路径属性 | 互联网骨干 | 所有 |

### 2.5 什么时候用什么？

```
小型网络（< 10 路由器）：静态 + 默认路由
中型网络（10-100）：OSPF
大型园区 / 企业骨干：OSPF 多区域 + IS-IS
跨运营商 / 互联网：BGP
```

---

## §3 静态路由 + 默认路由（PDF 05）

### 3.1 静态路由配置（华为命令）

```bash
<Huawei> system-view                    # 进系统视图
[Huawei] ip route-static 目的网络 掩码 下一跳 [出接口]
[Huawei] ip route-static 192.168.2.0 24 192.168.3.2   # 路由器 R1 的标准配置
```

### 3.2 静态路由实战（双路由器互联）

**场景**：
```
[PC1] ←→ [R1] ←→ [R2] ←→ [PC2]
 192.168.1.0/24 192.168.3.0/24   192.168.2.0/24
```

**配置 R1**：
```bash
<Huawei> system-view
[Huawei] sysname R1
[R1] interface Ethernet0/0/0
[R1-Ethernet0/0/0] ip address 192.168.1.254 24   # 配 E0/0/0 给 PC1 网段
[R1-Ethernet0/0/0] quit
[R1] interface GigabitEthernet0/0/0
[R1-GigabitEthernet0/0/0] ip address 192.168.3.1 24   # 配 G0/0/0 连 R2
[R1-GigabitEthernet0/0/0] quit

# ★ 关键：加静态路由告诉 R1 "192.168.2.0 是 R2 的活"
[R1] ip route-static 192.168.2.0 24 192.168.3.2
```

**R2 镜像配置**：
```bash
[Huawei] sysname R2
[R2] interface GigabitEthernet0/0/0
[R2-GigabitEthernet0/0/0] ip address 192.168.3.2 24
[R2-GigabitEthernet0/0/0] quit
[R2] interface Ethernet0/0/0
[R2-Ethernet0/0/0] ip address 192.168.2.254 24
[R2-Ethernet0/0/0] quit

[R2] ip route-static 192.168.1.0 24 192.168.3.1   # 告诉 R2 "192.168.1.0 是 R1 的活"
```

### 3.3 路由转发流程

```
PC1 (192.168.1.10) → PC2 (192.168.2.20)

PC1 查：本机路由表有 192.168.2.0/24 走网关 192.168.1.254
  ↓
发给 R1 (192.168.1.254)
  ↓
R1 查路由表：192.168.2.0/24 → 下一跳 192.168.3.2 → 出接口 G0/0/0
  ↓
发给 R2 (192.168.3.2)
  ↓
R2 查路由表：192.168.2.0/24 是直连 → 出接口 E0/0/0
  ↓
发给 PC2 (192.168.2.20)
```

### 3.4 默认路由（Default Route）

**本质**：0.0.0.0/0 的静态路由。

**作用**：路由表查不到更具体的路由时，**兜底走默认路由**。

```
ip route-static 0.0.0.0 0.0.0.0 192.168.1.1
                  ↑   ↑   ↑     ↑
                  目的  掩码   下一跳
                  默认所有 不管去哪儿都从这里出发
```

**典型场景**：
- **家用路由器**：只有"自己 LAN 网段 + 一条默认路由指向 ISP"
- **企业边界**：内网所有路由器都指一条默认路由到边界路由器

### 3.5 默认路由 vs 静态路由

| 维度 | 静态路由 | 默认路由 |
|---|---|---|
| 目的 | 特定目的网段 | 所有未匹配的目的 |
| 优先级 | Pre = 60 | Pre = 60（一样） |
| 匹配顺序 | **最长前缀匹配** | **兜底** |
| 数量 | 多个（每个网段一条） | 通常 1 条 |

### 3.6 数据通信的双向性

> **"数据通信往往是双向的，因此要关注流量的往返（往返路由）"** —— PDF 原话

如果 PC1 能 ping 通 PC2，但 PC2 不能 ping 通 PC1，**一定是某方向的路由缺失**。

### 3.7 静态路由的优缺点

| 优点 | 缺点 |
|---|---|
| 配置简单 | **不能自动适应网络拓扑变化** |
| 不占 CPU | 大网络配置工作量大 |
| 安全性高 | 不能自动选最优路径 |
| 路由表小 | **单向故障难发现** |

---

## §4 路由转发流程：最长掩码匹配（PDF 05）

### 4.1 路由器转发的 3 大步骤

```
1. 查路由表（最长前缀匹配）
   ↓
2. 找到出接口和下一跳
   ↓
3. 包从出接口发出去（重新封装 Layer 2）
```

### 4.2 Layer 3 → Layer 2 重封装

**关键点**：**包每经过一个路由器，MAC 头换一次，但 IP 头不变**。

```
PC1 发包：
  目标 MAC = R1 的 MAC（网关）
  目标 IP  = PC2 的 IP      ← IP 跨全程不变

R1 转发：
  收包：MAC = PC1 / R1
  发包：MAC = R1 / R2   ← 换 MAC 头
       IP 不变

R2 转发：
  收包：MAC = R1 / R2
  发包：MAC = R2 / PC2  ← 换 MAC 头
       IP 不变

PC2 收到：IP 还是 PC1 的 IP
```

### 4.3 路由递归（Recursive Lookup）

**有时下一跳 IP 不直接连本路由器**，需要递归查到。

```
R1 路由表：
  192.168.2.0/24 → 10.1.1.2   ← 10.1.1.2 是 R2 的回环口
                          ↓ 不是 R1 直连
                          ↓ 需要再查
  10.1.1.0/24 → 192.168.3.2    ← R1 直连

R1 转发去 192.168.2.5：
  1. 查 192.168.2.0/24 → 下一跳 10.1.1.2
  2. 10.1.1.2 不直连 → 递归查 10.1.1.0/24 → 192.168.3.2
  3. 192.168.3.2 是 R2 直连 → 出接口 G0/0/0 → 发包
```

### 4.4 路由 ECMP（等价多路径）

**Pre + Cost 都相同的路由有多个，下一跳不同时**：路由器**轮流**用两条。

```
10.1.1.0/24 via 192.168.1.2, cost=10
10.1.1.0/24 via 192.168.2.2, cost=10  ← 等价多路径
     ↓
路由器自动负载均衡（轮询 / 哈希）
```

### 4.5 路由失败的处理

**没找到匹配路由** + **没默认路由** → **包被丢弃 + 发送 ICMP "目的不可达"**。

```
ping 4.4.4.4    ← 路由表没匹配 + 没默认路由
PC1 收 ICMP: "Destination Net Unreachable"
```

### 4.6 路由器收到自己 IP 的包怎么办？

```
包的目标 IP = 路由器自己的接口 IP
  ↓
1. 收下，交给上层协议处理（ping 响应 / TCP 握手等）
2. 不会再转发（不是路由器的工作）
```

---

## §5 VLAN 是什么：解决广播域问题（PDF 07）

### 5.1 传统以太网的问题

> **"上图中一个典型的交换网络，网络中只有终端计算机和交换机。在这样的网络中，如果某一台计算机发送了一个广播帧，由于交换机对广播帧执行泛洪操作，结果所有其他的计算机都会收到这个广播帧。"**

**一个交换网络 = 一个广播域**。

### 5.2 广播带来的 3 大问题

| 问题 | 后果 |
|---|---|
| **网络安全** | 所有 PC 都能收到广播，能听别人之间的通信（如 ARP、DHCP） |
| **垃圾流量** | 广播占带宽，PC 处理广播浪费 CPU |
| **广播风暴** | 环路 + 广播 = 网络瘫痪（雪崩式泛洪） |

### 5.3 广播域越大，问题越严重

```
例：PC1 单播给 PC2，但 SW2/SW5 没 PC2 的 MAC 表
   ↓
SW1：转发（已知 PC2）
SW2：泛洪（未知 PC2）
SW3：转发（已知 PC2）  
SW5：泛洪（未知 PC2）
SW7：丢弃（PC2 不在自己树）

结果：PC2 收到 + 一堆不该收到的 PC 也收到
```

### 5.4 VLAN 定义

> **"VLAN (Virtual Local Area Network) = 虚拟局域网技术。通过在交换机上部署 VLAN，可以将一个规模较大的广播域在逻辑上划分成若干个不同的、规模较小的广播域，由此可以有效地提升网络的安全性，同时减少垃圾流量，节约网络资源。"**

### 5.5 VLAN 4 大好处

| 好处 | 说明 |
|---|---|
| **限制广播域** | 广播被限制在一个 VLAN 内 |
| **增强安全性** | 不同 VLAN 报文相互隔离 |
| **灵活工作组** | 用户划分不局限于物理位置 |
| **提高健壮性** | 故障被限制在一个 VLAN 内 |

### 5.6 VLAN vs 子网 vs 广播域

| 概念 | 范围 | 隔离方式 |
|---|---|---|
| **VLAN** | 数据链路层（Layer 2） | 交换机切 VLAN |
| **子网**（Subnet） | 网络层（Layer 3） | IP + 子网掩码 |
| **广播域** | 数据链路层 | VLAN / 路由器 |

> **关系**：一个 VLAN 一般对应一个子网，**但不是必须**（可以 VLAN 10 = 192.168.1.0/24，也可以 VLAN 10 跨多个子网但这是设计反模式）。

### 5.7 VLAN 划分不受地域限制

```
总公司在 18 楼的 Switch A
分公司在 5 楼 Switch B
  ↓
同一 VLAN ID（比如 VLAN 10）= 同一广播域
  ↓
可以贯通整栋楼
```

### 5.8 一个 VLAN 的关键事实

```
1. 一个 VLAN = 一个广播域
2. 同一 VLAN 内的计算机可以直接 Layer 2 通信
3. 不同 VLAN 内的计算机**不能**直接 Layer 2 通信
4. 不同 VLAN 通信需要 Layer 3（路由或三层交换）
```

### 5.9 VLAN 实现的基本原理

```
[Switch 1]            [Switch 2]
  |                      |
  ├─ 端口 1 (VLAN 10)   ├─ 端口 5 (VLAN 10)
  ├─ 端口 2 (VLAN 10)   ├─ 端口 6 (VLAN 20)
  └─ 端口 3 (VLAN 20)   └─ 端口 7 (VLAN 20)

两台 Switch 间链路要承载多个 VLAN 的数据
→ 需要 VLAN "标记" 机制（802.1Q）
```

---

## §6 VLAN 标签：802.1Q 帧格式（PDF 07）

### 6.1 为什么需要标签？

> **"要使交换机能够分辨不同 VLAN 的报文，需要在报文中添加标识 VLAN 信息的字段。"**

未标签的帧：交换机**只能猜**用户属于哪个 VLAN。

### 6.2 IEEE 802.1Q 标签格式

```
标准以太网帧：
┌────────┬───────────────┬────────────┬─────────┬───────────┬──────┐
│ 前导码  │ 目标 MAC (6)  │ 源 MAC (6) │ 类型 (2)│ Data (可变)│ FCS  │
└────────┴───────────────┴────────────┴─────────┴───────────┴──────┘

802.1Q 标签帧（在源 MAC 后插入 4 字节 Tag）：
┌────────┬───────────────┬────────────┬──────┬─────────┬───────────┬──────┐
│ 前导码  │ 目标 MAC (6)  │ 源 MAC (6) │ TPID │ TCI (2) │ 类型 (2) │ Data  │
└────────┴───────────────┴────────────┴──────┴─────────┴───────────┴──────┘
                            ↑         ↑
                        插入 4 字节  
                          VLAN Tag
```

### 6.3 4 字节 VLAN Tag 结构

```
        TPID (16 bit)              TCI
┌──────────────────────┬──────────┬─────────┬───────┐
│     0x8100           │ Priority │ CFI     │ VLAN ID│
│ （标识这是 802.1Q 帧）│ (3 bit)  │ (1 bit) │(12 bit)│
└──────────────────────┴──────────┴─────────┴───────┘
                          ↑          ↑         ↑
                       优先级      经典格式   VLAN 号 1-4094
                       0-7        0/1       （0/4095 保留）
```

### 6.4 两种以太网帧形式

| 形式 | 别称 | 出现位置 |
|---|---|---|
| **无标记帧**（Untagged） | 原始以太网帧 | 接入 PC 的 Access 端口 |
| **有标记帧**（Tagged） | 802.1Q 帧 | Trunk 链路、Huawei Hybrid |

### 6.5 帧类型判断流程

```
PC 发出的帧：Untagged（不带 VLAN 标签）
  ↓ 进入交换机 Access 端口
交换机：给帧**打 Tag** 标记 VLAN ID（来自 PVID 配置）
  ↓
从 Trunk 端口转发：**保留 Tag**
  ↓
到达目的交换机：识别 Tag → 决定从哪个 Access 端口发
  ↓
出 Access 端口时：**去掉 Tag**（变成 Untagged）
  ↓
PC 收到：Untagged 帧（PC 不感知 VLAN 存在）
```

### 6.6 802.1Q 帧其他用途

- **QinQ**（Stack VLAN）：打双重 Tag，运营商用来隔离客户流量
- **优先级位**：3 位 = 8 个优先级（CoS），用于 QoS

---

## §7 VLAN 划分方式 5 种（PDF 07）

> **"VLAN 的划分包括如下 5 种方法"** —— PDF 原话。

### 7.1 5 种划分方式

| # | 方式 | 依据 | 适合 |
|---|---|---|---|
| 1 | **基于接口** | 交换机的物理端口 | **最常用** |
| 2 | **基于 MAC 地址** | 帧的源 MAC | MAC 固定设备 |
| 3 | **基于 IP 子网** | 帧的源 IP + 子网掩码 | 按 IP 网段 |
| 4 | **基于协议** | 帧所属协议（IPv4/IPv6/IPX） | 多协议网络 |
| 5 | **基于策略** | 多种组合（接口 + MAC + IP） | 灵活需求 |

### 7.2 最常用：基于接口划分

```bash
# 华为交换机命令
[Huawei] vlan 10
[Huawei-vlan10] quit

[Huawei] interface GigabitEthernet0/0/1
[Huawei-GigabitEthernet0/0/1] port link-type access
[Huawei-GigabitEthernet0/0/1] port default vlan 10
```

### 7.3 基于 MAC 划分

**场景**：MAC 固定（比如网络打印机、IP 电话）。

```bash
# 华为
[Huawei] vlan 20
[Huawei-vlan20] mac-vlan mac-address 0025-xxxx-xxxx
```

### 7.4 基于 IP 子网划分

**场景**：同一交换机端口接多个 IP 网段（如路由器子接口）。

```bash
# 华为
[Huawei] vlan 30
[Huawei-vlan30] ip-subnet-vlan ip 192.168.30.0 24 30
```

### 7.5 5 种方式对比

| 维度 | 接口 | MAC | IP 子网 | 协议 | 策略 |
|---|---|---|---|---|---|
| 复杂度 | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| 移动性 | ❌（换口就变） | ✅ | ✅ | ✅ | ✅ |
| 配置灵活性 | 中 | 中 | 中 | 高 | 极高 |
| 实际使用 | **最广泛** | 特殊场景 | 子接口 | 罕见 | 高级需求 |

---

## §8 VLAN 接口类型：Access / Trunk / Hybrid（PDF 07）

> **"基于接口的 VLAN 划分依赖于交换机的接口类型。"**

### 8.1 三种接口类型对比

| 类型 | 发出的帧 | 收到的帧处理 | 用在 |
|---|---|---|---|
| **Access** | **去 Tag**（Untagged） | 给帧**打 PVID** | 接 PC（不知道 VLAN） |
| **Trunk** | **保留 / 加 Tag**（除非是 native VLAN） | 接收任何 VLAN 的 Tag 帧 | 接交换机 / 路由器 / AP |
| **Hybrid**（华为默认） | **可配**：带 Tag / 去 Tag 任意 VLAN | 接收 Tag 帧 | 一台接口接多种设备 |

### 8.2 关键概念

#### PVID（Port VLAN ID）
**端口默认 VLAN ID**。Untagged 帧打上 PVID 算 VLAN。

#### VLAN ID 列表
**Access / Trunk / Hybrid 都维护一个允许通过的 VLAN ID 列表**。

```
Access 端口：默认允许 1 个 VLAN（就是 PVID）
Trunk 端口：默认允许 1-4094 所有 VLAN，可以配置白名单
Hybrid 端口：可同时有 Tagged + Untagged 两个列表
```

### 8.3 Access 接口详解

**特点**：
- **只属于 1 个 VLAN**（Untagged 列表只能 1 个 VLAN）
- 收：Untagged → 打 PVID Tag；Tagged 且 VLAN 在允许列表 → 接收
- 发：**去掉** Tag（Untagged 出去）
- 典型用法：**接 PC**

```bash
[Huawei-GigabitEthernet0/0/1] port link-type access
[Huawei-GigabitEthernet0/0/1] port default vlan 10
```

### 8.4 Trunk 接口详解

**特点**：
- **可属于多个 VLAN**（Tagged 列表）
- 收：Tagged + VLAN 在允许列表 → 收；Untagged → 打 PVID Tag（默认 1）
- 发：除 PVID (native VLAN) **去掉 Tag**；其他 VLAN **保留 Tag**
- 典型用法：**交换机间互联 / 接路由器子接口**

```bash
[Huawei-GigabitEthernet0/0/24] port link-type trunk
[Huawei-GigabitEthernet0/0/24] port trunk pvid vlan 1      # native VLAN
[Huawei-GigabitEthernet0/0/24] port trunk allow-pass vlan 10 20 100
```

### 8.5 Trunk 的 native VLAN

**Native VLAN = 不打 Tag 的 VLAN**。

```
默认 native = VLAN 1
  ↓
Trunk 端口发 VLAN 1 流量 → 不打 Tag（Untagged）
Trunk 端口发 VLAN 10 流量 → 打 Tag（Tagged）

对端收到 Untagged → 当 VLAN 1 处理（打 PVID）
对端收到 Tagged → 识别 VLAN ID
```

> **建议**：生产中把 native VLAN 改成非 1（如 VLAN 666），**避免与默认 VLAN 1 冲突**。

### 8.6 Hybrid 接口详解

**华为默认类型**（不像 Cisco 默认 Access）。

**特点**：
- 同时维护 **Tagged + Untagged 2 个 VLAN 列表**
- 可以自由配置"哪些 VLAN 打 Tag / 哪些 VLAN 去 Tag"
- 比 Trunk 更灵活
- 典型用法：**服务器多 VLAN 网卡接入、混杂场景**

```bash
[Huawei-GigabitEthernet0/0/1] port link-type hybrid
[Huawei-GigabitEthernet0/0/1] port hybrid pvid vlan 10
[Huawei-GigabitEthernet0/0/1] port hybrid tagged vlan 100        # 管理 VLAN 打 Tag
[Huawei-GigabitEthernet0/0/1] port hybrid untagged vlan 10 20    # 业务 VLAN 不打 Tag
```

### 8.7 三种接口包收包行为对比

| 收到 | Access | Trunk | Hybrid |
|---|---|---|---|
| Untagged 帧 | 打 PVID Tag | 打 PVID Tag | 打 PVID Tag |
| Tagged 帧 + VLAN 在允许 | 收（注：可能剥 Tag） | 收 | 收 |
| Tagged 帧 + VLAN 不在允许 | 丢 | 丢 | 丢 |

### 8.8 什么时候用什么？

```
接普通 PC/服务器：         Access
接其他交换机/路由器/AC：    Trunk
接服务器多 VLAN 网卡：      Hybrid
服务器单 VLAN 网卡：        Access 或 Hybrid
接 IP 电话（电脑+电话串）： Hybrid
```

### 易错点

- ❌ Access 端口能接交换机 → 不能，只能接终端
- ❌ Trunk 接 PC 也能通 → **能**（Untagged 时），但**不规范**
- ❌ VLAN ID 4095 都可用 → 0 和 4095 **保留**，实际可用 1-4094

---

## §9 单臂路由：路由器单接口 + 子接口（PDF 08）

### 9.1 什么是单臂路由

**单臂路由（Router-on-a-Stick）** = 用**路由器的一个物理接口**（拆成多个逻辑子接口）实现不同 VLAN 间的**三层路由**。

```
                [Trunk 链路]
                  │
       ┌──────────┴──────────┐
       │                     │
   [SW] port G0/0/24      [Router] G0/0/0
                         (拆成 G0/0/0.10, G0/0/0.20)
                         
   [VLAN 10] PC1 ──────── Sub-interface 10
   [VLAN 20] PC2 ──────── Sub-interface 20
```

### 9.2 路由器子接口逻辑

```
路由器物理接口 G0/0/0：
  ├─ G0/0/0.10 = VLAN 10 的网关（IP = 192.168.10.1）
  └─ G0/0/0.20 = VLAN 20 的网关（IP = 192.168.20.1）

Trunk 链路：同时承载 VLAN 10 和 VLAN 20 的 Tagged 帧
交换机 G0/0/24 = Trunk，allow-pass vlan 10 20
```

### 9.3 单臂路由配置（华为）

```bash
# ========== 交换机侧 ==========
[Huawei] interface GigabitEthernet0/0/24
[Huawei-GigabitEthernet0/0/24] port link-type trunk
[Huawei-GigabitEthernet0/0/24] port trunk allow-pass vlan 10 20

# ========== 路由器侧（关键：dot1q 终结） ==========
[Huawei] interface GigabitEthernet0/0/0
[Huawei-GigabitEthernet0/0/0] quit   # 物理口不配 IP

[Huawei] interface GigabitEthernet0/0/0.10
[Huawei-GigabitEthernet0/0/0.10] dot1q termination vid 10    # ← 终结 VLAN 10 的 Tag
[Huawei-GigabitEthernet0/0/0.10] ip address 192.168.10.1 24  # 当 VLAN 10 的网关

[Huawei] interface GigabitEthernet0/0/0.20
[Huawei-GigabitEthernet0/0/0.20] dot1q termination vid 20    # ← 终结 VLAN 20 的 Tag
[Huawei-GigabitEthernet0/0/0.20] ip address 192.168.20.1 24  # 当 VLAN 20 的网关

# 路由器开启 ARP 广播（default）
[Huawei] interface GigabitEthernet0/0/0.10
[Huawei-GigabitEthernet0/0/0.10] arp broadcast enable
```

### 9.4 dot1q termination 干啥用？

```
Trunk 上来的 Tagged 帧（VLAN 10）：
  目标 MAC = Router G0/0/0 MAC
  VLAN Tag = 10

路由器收到：
  ↓ dot1q termination vid 10
G0/0/0.10 子接口处理
  ↓
路由表查找（直连 192.168.10.0/24）
  ↓
从 G0/0/0.20 子接口发出（带 VLAN 20 Tag）
```

### 9.5 单臂路由的优缺点

| 优点 | 缺点 |
|---|---|
| 节约路由器端口 | **Trunk 链路是瓶颈**（所有 VLAN 流量走一根线） |
| 配置集中 | 配置相对复杂 |
| 适合小型网络 | 性能不如三层交换 |

### 9.6 适用场景

```
- 小型分支机构（VLAN 数量少）
- 预算有限（不想买三层交换机）
- 临时方案 / 验证
```

---

## §10 三层交换：交换机内置路由模块（PDF 08）

### 10.1 为什么需要三层交换

**单臂路由的瓶颈**：所有 VLAN 间流量走一根 Trunk 链路，速度受限。
**三层交换**：把路由功能**集成到交换机里**，**每个 VLAN 对应一个 SVI 接口**，**背板内部交换**，速度等同 Layer 2。

### 10.2 三层交换机的两大关键

```
1. 二层交换功能（普通交换机功能）
2. 三层路由功能（路由器功能 + VLAN 接口 SVI）
```

### 10.3 SVI = Switched Virtual Interface

**每个 VLAN 都可以配置一个 SVI**，相当于"这个 VLAN 的虚拟三层接口"。

```
VLAN 10  ──→  Vlanif 10  （IP = 192.168.10.1 / 24）
VLAN 20  ──→  Vlanif 20  （IP = 192.168.20.1 / 24）
VLAN 30  ──→  Vlanif 30  （IP = 192.168.30.1 / 24）
```

### 10.4 三层交换配置（华为）

```bash
# ========== 步骤 1：建 VLAN + 加 Access 端口 ==========
[Huawei] vlan batch 10 20      # 批量创建 VLAN
[Huawei] interface GigabitEthernet0/0/1
[Huawei-GigabitEthernet0/0/1] port link-type access
[Huawei-GigabitEthernet0/0/1] port default vlan 10
[Huawei-GigabitEthernet0/0/1] quit

[Huawei] interface GigabitEthernet0/0/2
[Huawei-GigabitEthernet0/0/2] port link-type access
[Huawei-GigabitEthernet0/0/2] port default vlan 20
[Huawei-GigabitEthernet0/0/2] quit

# ========== 步骤 2：建 SVI（三层接口）==========
[Huawei] interface Vlanif 10
[Huawei-Vlanif10] ip address 192.168.10.1 24
[Huawei-Vlanif10] quit

[Huawei] interface Vlanif 20
[Huawei-Vlanif20] ip address 192.168.20.1 24
[Huawei-Vlanif20] quit

# ========== 验证 ==========
[Huawei] display ip routing-table
[Huawei] ping 192.168.10.2   # 通
```

### 10.5 数据转发流程（三层交换）

```
PC1 (VLAN 10, 192.168.10.2)  ─── ping  ───→  PC2 (VLAN 20, 192.168.20.2)
  │                                                    ↑
  │                                                    │
  │ 网关 = 192.168.10.1 (Vlanif 10)                     │
  └─ ARP 问网关 MAC                                     │
       ↓                                                │
       交换机 L2 转发到 Vlanif 10                        │
       ↓                                                │
     三层查路由表：192.168.20.0/24 → Vlanif 20            │
       ↓                                                │
     交换机 L2 转发到 PC2 端口（VLAN 20）                ─┘
```

### 10.6 三层交换的"捷径"

**首次**转发需要查路由 + 解析 ARP，**之后**通过硬件转发表**直接二层转发**。

```
PC1 → PC2：
  首次：CPU 路由 + ARP 查询
        ↓
        缓存到硬件转发表（ASIC）
  之后：纯硬件二层转发（≈ 三层路由器做不到）

这就是三层交换机的"一次路由，多次交换"
```

### 10.7 三层交换 vs 单臂路由

| 维度 | 单臂路由 | 三层交换 |
|---|---|---|
| **性能** | Trunk 链路为瓶颈 | 背板内部交换，几乎无瓶颈 |
| **配置** | 子接口 + dot1q termination | SVI（Vlanif）简单 |
| **适用** | VLAN 数少、小网络 | VLAN 多、大型网络 |
| **成本** | 路由器便宜 | 三层交换机贵 |
| **扩展性** | 差（Trunk 带宽共享） | 好（ASIC 转发） |

### 10.8 三层交换 + 单臂路由混用

**大型网络常见**：
```
[核心层] 三层交换机（核心路由器 + 高速转发）
    │
    ├─ 接 Trunk 下来 二层接入交换机
    └─ 接路由器出口
```

### 易错点

- ❌ 三层交换机所有口都是路由口 → 默认 Access 还是二层
- ❌ 三层交换机不需要 VLAN 接口 → 必须配 Vlanif X 才能跨 VLAN 路由
- ❌ Vlanif X 配 IP 就能用 → 还要进 VLAN + 配 Access 端口

---

## §11 VLAN 间通信方案对比（PDF 08 总结）

### 11.1 3 大方案 + 选型

| 方案 | 实现 | 性能 | 适用 |
|---|---|---|---|
| **单臂路由** | 路由器 + 1 子接口 / VLAN | 低 | VLAN < 5 个，小公司 |
| **三层交换机 SVI** | 交换机的 Vlanif 接口 | 高 | **主流选择**，中型网络 |
| **三层交换机 + 路由器** | 边界路由 + 内网三层 | 最高 | 大型园区 / 企业网 |

### 11.2 选型决策树

```
需要 VLAN 间通信
   ↓
VLAN 数量？
   ├─ ≤ 5 个 ─┐
   │          ├─ 预算低 → 单臂路由
   └─ > 5 个 ─┘
              预算高 → 三层交换机（Vlanif）
              预算很高 → 核心三层 + 出口路由器
```

### 11.3 实战方案：核心三层 + 接入二层

```
                ┌─────────────┐
                │ 核心三层交换机 │
                │ (S5700-SI)   │
                │ Vlanif 10/20/100 │
                └──┬────────┬─┘
              Trunk │        │ Trunk
                   │        │
       ┌────────────┴──┐ ┌──┴────────────┐
       │ 接入二层交换机  │ │ 接入二层交换机  │
       │ VLAN 10 端口   │ │ VLAN 20 端口   │
       └─┬──┬──┬──┬───┘ └─┬──┬──┬──┬───┘
         PC1 PC2 PC3      PC4 PC5 PC6
```

### 11.4 VLAN + IP 子网对应表（实用）

> **"VLAN ID 和子网关联的方式进行分配"** —— PDF 原话

| VLAN | IP 段 | 子网掩码 | 网关（Vlanif） |
|---|---|---|---|
| 10 | 192.168.10.0 | /24 | 192.168.10.1 |
| 20 | 192.168.20.0 | /24 | 192.168.20.1 |
| 30 | 192.168.30.0 | /24 | 192.168.30.1 |
| 100 | 10.0.100.0 | /24 | 10.0.100.1（管理 VLAN） |

**好处**：VLAN ID ↔ 子网末段 IP**直观对应**，便于记忆和排查。

---

## §12 易错点 ×10

1. **Pre 越大越优先** → **越小越优先**
2. **直连网段也需要写静态路由** → 不需要，直连自动出现
3. **默认路由 0.0.0.0/0 不是最优** → 它是**兜底**路由
4. **单臂路由性能高** → 实际上 Trunk 链路是瓶颈
5. **VLAN 标签 = 安全** → VLAN 隔离广播域，但**不是安全机制**（用 ACL/VPN 才安全）
6. **PC 能识别 VLAN Tag** → PC **看不到**，在网卡就被剥掉
7. **VLAN ID 4095 都可用** → 0 和 4095 **保留**，实际 1-4094
8. **三交换机所有口都是路由口** → 默认还是 Access 二层口
9. **静态路由表只有一条也可以** → 多网段必须配多条
10. **路由器不转发自己 IP 的包** → 是的（除非是路由协议的 hello 包）

---

## §13 速查表

### 路由基础命令速查

```bash
# 华为 VRP
display ip routing-table                # 看路由表
display ip routing-table protocol static   # 只看静态
ip route-static 目的 掩码 下一跳 [出接口]   # 加静态路由
ip route-static 0.0.0.0 0.0.0.0 1.1.1.1  # 默认路由

# Cisco IOS
show ip route
ip route 10.1.1.0 255.255.255.0 192.168.1.1
ip route 0.0.0.0 0.0.0.0 192.168.1.1
```

### VLAN 配置速查（华为）

```bash
# 建 VLAN
[Huawei] vlan 10
[Huawei-vlan10] description Office
[Huawei-vlan10] quit
# 或批量
[Huawei] vlan batch 10 20 100

# Access 口
[Huawei] interface GigabitEthernet0/0/1
[Huawei-GigabitEthernet0/0/1] port link-type access
[Huawei-GigabitEthernet0/0/1] port default vlan 10

# Trunk 口
[Huawei-GigabitEthernet0/0/24] port link-type trunk
[Huawei-GigabitEthernet0/0/24] port trunk pvid vlan 1
[Huawei-GigabitEthernet0/0/24] port trunk allow-pass vlan 10 20 100

# Hybrid 口
[Huawei-GigabitEthernet0/0/1] port link-type hybrid
[Huawei-GigabitEthernet0/0/1] port hybrid pvid vlan 10
[Huawei-GigabitEthernet0/0/1] port hybrid tagged vlan 100
[Huawei-GigabitEthernet0/0/1] port hybrid untagged vlan 10 20
```

### 单臂路由速查

```bash
[Huawei] interface GigabitEthernet0/0/0.10
[Huawei-GigabitEthernet0/0/0.10] dot1q termination vid 10
[Huawei-GigabitEthernet0/0/0.10] ip address 192.168.10.1 24
[Huawei-GigabitEthernet0/0/0.10] arp broadcast enable
```

### 三层交换速查

```bash
[Huawei] vlan batch 10 20
[Huawei] interface Vlanif 10
[Huawei-Vlanif10] ip address 192.168.10.1 24
[Huawei-Vlanif10] quit

[Huawei] interface Vlanif 20
[Huawei-Vlanif20] ip address 192.168.20.1 24
```

### 路由协议默认值速查

| 协议 | 默认 Pre |
|---|---|
| Direct | 0 |
| OSPF | 10 |
| IS-IS | 15 |
| Static | 60 |
| RIP | 100 |
| BGP | 255 |

### 接口类型速查

| 类型 | 发出 Tag | 接 PC | 接交换机 | 接路由器 |
|---|---|---|---|---|
| Access | 去 Tag | ✅ | ❌ | ❌ |
| Trunk | Native 去 / 其他保 | ❌ | ✅ | ✅ |
| Hybrid | 可配 | ✅ | ✅ | ✅ |

---

## §14 面试 6 大追问

1. **路由表匹配的规则是什么？当最长前缀有 2 条等价路径？**
   - **最长前缀匹配**：选网络号最长的那条
   - 等价最长前缀 + 等价 Pre + 等价 Cost → **ECMP**，路由器**轮询**或多路径哈希

2. **Pre 和 Cost 是什么关系？**
   - **Pre（Preference 优先级）**：跨协议比较，**越小越优先**
   - **Cost（开销）**：同 Pre 的多条路由，Cost 越小越优先
   - 决策顺序：**Pre 决胜负 → Cost 决胜负 → ECMP 轮询**

3. **为什么默认路由 Pre = 60？**
   - 默认路由本质是静态路由（Static），默认 Pre = 60
   - 比 OSPF (10) 低，比 RIP (100) 高
   - 适合"小网络"用，**不想让默认路由喧宾夺主**

4. **VLAN 标签会不会让包变大导致分片？**
   - 会增加 4 字节
   - 标准 MTU 1500 字节，加上 4 字节的 Tag 最大 1504
   - 交换机会调整协商成 **MTU 1504** 或者**强制不分片**

5. **Access / Trunk / Hybrid 的本质区别是什么？**
   - **Access**：1 个 VLAN，发出不带 Tag
   - **Trunk**：多个 VLAN，发出除 native 都带 Tag
   - **Hybrid**：多个 VLAN + **可控制每个 VLAN 是否带 Tag**（灵活性最大）

6. **三层交换机 vs 单臂路由，怎么选？**
   - **VLAN < 5 + 预算紧** → 单臂路由
   - **VLAN ≥ 5 或追求性能** → 三层交换机
   - **大型园区** → 核心三层 + 接入二层
   - **性能差距** = 背板 vs 单 Trunk 链路（差距能达 10 倍以上）

---

## 📎 跨模块链接

- **[[../网络基础原理/网络基础原理]]** — 子网划分、IP 编址、ARP、交换机原理
- **[[../华为VRP/华为VRP]]** — 华为 VRP 文件系统、命令行模式
- **[[../Linux网络/Linux网络]]** — Linux 单机网络命令实操
- **[[../Linux防火墙/Linux防火墙]]** — VLAN 间通信 + 防火墙实现多层防护

## 📦 镜像

- `E:\notes\路由与VLAN.md`（同步备份）