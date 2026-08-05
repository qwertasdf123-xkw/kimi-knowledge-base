---
title: Linux LVS 负载均衡全解析
desc: LVS 原理 + NAT/DR/TUN/FULLNAT 4 种模式 + ipvsadm 管理 + 8 种调度算法 + 持久连接 + 健康检查 + 实战部署
type: 笔记
module: LinuxLVS
pdf: 负载均衡-LVS 全解析 (1).pdf
pdf_size: 1.0 MB
scope: LVS 原理 + 4 种工作模式 + ipvsadm 管理 + 高可用集群
status: 完成
---

# Linux LVS 负载均衡全解析

> **范围**：基于《负载均衡-LVS 全解析》整理。
> 覆盖 **LVS 起源与原理**（章文嵩博士 / IPVS 内核模块）+ **4 种工作模式**（NAT / DR / TUN / FULLNAT）+ **ipvsadm 用户空间工具** + **8 种调度算法**（rr / wrr / lc / wlc / lblc / lblcr / dh / sh）+ **持久连接** + **健康检查** + **NAT/DR 实战部署**。
>
> **适用**：CentOS-7 / RHEL 系 / 内核 2.6+。

## 目录

- [[#§0 心智模型：LVS = Linux Virtual Server = 把多台后端服务器虚拟成一台]]
- [[#§1 LVS 是什么：章文嵩博士 + 1998 + Linux 内核 IPVS 模块 + 4 层负载均衡]]
- [[#§2 为什么需要 LVS：单台服务器性能瓶颈 + C10K/C100K + 水平扩展]]
- [[#§3 LVS 架构三要素：Director + Real Server + Client + VIP]]
- [[#§4 LVS 术语速查：VIP/DIP/RIP/CIP + IPVS/IP + ipvsadm/ipvsadmd]]
- [[#§5 LVS vs Nginx：4 层 vs 7 层 + 性能 + 适用场景]]
- [[#§6 LVS vs HAProxy vs F5：四层负载均衡三巨头对比]]
- [[#§7 LVS 工作模式 1：NAT（网络地址转换）]]
- [[#§8 LVS 工作模式 2：DR（直接路由）生产环境 99% 用这个]]
- [[#§9 LVS 工作模式 3：TUN（IP 隧道）]]
- [[#§10 LVS 工作模式 4：FULLNAT（双向 SNAT/DNAT）]]
- [[#§11 4 种模式对比表：性能 / 网络要求 / 部署复杂度 / 适用场景]]
- [[#§12 ipvsadm 安装：yum install ipvsadm + 加载 ip_vs 模块]]
- [[#§13 ipvsadm 核心命令：add/del/edit + 增删改虚拟服务 + 增删改真实服务器]]
- [[#§14 调度算法概述：静态算法 vs 动态算法]]
- [[#§15 调度算法 1：rr 轮询（Round Robin）]]
- [[#§16 调度算法 2：wrr 加权轮询（Weighted RR）]]
- [[#§17 调度算法 3：lc 最少连接（Least Connections）]]
- [[#§18 调度算法 4：wlc 加权最少连接（默认采用）]]
- [[#§19 调度算法 5：sed 最短延迟调度（Shortest Expected Delay）]]
- [[#§20 调度算法 6：nq 永不排队 / 最少队列（Never Queue）]]
- [[#§21 调度算法 7：lblc 基于局部性的最少连接（Cache 集群专用）]]
- [[#§22 调度算法 8：lblcr 带复制的基于局部性最少连接]]
- [[#§23 8 种调度算法对比：适用场景 + 优缺点 + 默认选择]]
- [[#§24 调度算法 dh 与 sh：目标地址哈希 + 源地址哈希（会话保持）]]
- [[#§25 持久连接 PCC/PPC/SIP：解决会话问题 + 客户端绑定到同一 RS]]
- [[#§26 健康检查：ldirectord + keepalived 内置 + 后端 RS 故障剔除]]
- [[#§27 LVS-NAT 模式实战部署（一）：网络拓扑 + 主机规划]]
- [[#§28 LVS-NAT 模式实战部署（二）：基础配置 + 主机名 + IP]]
- [[#§29 LVS-NAT 模式实战部署（三）：Director 路由 + 防火墙 + 后端 Web 部署]]
- [[#§30 LVS-NAT 模式实战部署（四）：ipvsadm 配置 + rr/wrr 验证]]
- [[#§31 LVS-NAT 实战思考：同网段客户端无法访问的坑]]
- [[#§32 LVS-DR 模式实战部署（一）：网络拓扑 + Router + 主机规划]]
- [[#§33 LVS-DR 模式实战部署（二）：基础配置 + Router 配置 + Web 部署]]
- [[#§34 LVS-DR 模式实战部署（三）：arp_ignore / arp_announce 内核参数详解]]
- [[#§35 LVS-DR 模式实战部署（四）：配置 LVS-DS（Director）]]
- [[#§36 LVS-DR 模式实战部署（五）：配置 LVS-RS（Real Server） + 验证]]
- [[#§37 LVS-DR 实战脚本封装：start/stop 标准化操作]]
- [[#§38 LVS 性能调优：Director conn 表 + TCP 缓冲区 + 内核参数]]
- [[#§39 LVS 与防火墙：Director iptables 放行 + RS 防火墙处理]]
- [[#§40 LVS 常见故障排查：Director 单点 / RS 不响应 / NAT 回程错]]
- [[#§41 易错点 ×10：DR 模式 arp 配置 / NAT 网关 / TUN 公网 IP / 调度算法]]
- [[#§42 速查表：ipvsadm 命令大全 + 4 种模式对比 + 调度算法选择]]
- [[#§43 面试 6 大追问：LVS vs Nginx / 工作模式原理 / 调度算法选择 / 持久连接]]
- [[#§44 跨模块链接]]

---

## §0 心智模型：LVS = Linux Virtual Server = 把多台后端服务器虚拟成一台

```
                 客户端
                   │
                   ▼
        ┌─────────────────┐
        │  Director (LVS) │   ← 唯一对外可见
        │   VIP: 1.2.3.4  │
        └────────┬────────┘
                 │ 调度（rr / wrr / wlc ...）
       ┌─────────┼─────────┐
       ▼         ▼         ▼
   ┌───────┐ ┌───────┐ ┌───────┐
   │ RS1   │ │ RS2   │ │ RS3   │   ← 真实服务器，对外不可见
   │nginx  │ │nginx  │ │nginx  │
   └───────┘ └───────┘ └───────┘
```

**一句话**：LVS 把**多台后端服务器**虚拟成**一台高性能服务器**，对外只暴露一个 VIP。

**关键洞察**：
- 用户看到的是 **1 个 VIP**（Virtual IP）
- 实际服务的是 **N 台 RS**（Real Server）
- 用户**不知道**也不需要知道后端有多少台
- 流量由 **Director（调度器）** 按算法分配

**类比**：
- LVS = 公司前台（统一接待，把客户引导到对应业务部门）
- Director = 前台小姐姐
- Real Server = 业务部门（开发、测试、运维、销售...）
- VIP = 公司门牌号（客户只认这个）

> 💡 **核心优势**：水平扩展（加 RS 就能扛更多流量）+ 高可用（挂一台不影响）。

---

## §1 LVS 是什么：章文嵩博士 + 1998 + Linux 内核 IPVS 模块 + 4 层负载均衡

**LVS 全称**：**L**inux **V**irtual **S**erver（Linux 虚拟服务器）

**作者**：**章文嵩博士**，1998 年创建的开源负载均衡软件

**定位**：
- 工作在 **Linux 内核空间**（netfilter 子系统 / INPUT 链）
- 基于 **4 层（传输层）** 的负载均衡（基于 IP + PORT）
- 调度依据：**请求报文的目标 IP + 目标 PORT**

**两大组件**：

| 组件 | 位置 | 作用 |
|------|------|------|
| **ipvs** | 内核空间 | 真正干活的代码（IP Virtual Server） |
| **ipvsadm** | 用户空间 | 命令行工具，用于定义集群服务和管理 RS |

**关键事实**：
- ❌ **LVS 没有单独的配置文件**（不像 Nginx 有 `/etc/nginx/nginx.conf`）
- ✅ 所有配置通过 **ipvsadm 命令** 写入内核，立即生效
- ✅ 重启需用 `ipvsadm-save` 保存规则到 `/etc/sysconfig/ipvsadm`

**历史地位**：
- 业界**最经典**的 4 层负载均衡方案
- 与 F5 硬件负载均衡器抗衡（性能相当，价格 1/10）
- Nginx 7 层 LB 出道前，LVS 是绝对主流

> 💡 **面试题**：LVS 的全称和作者？
> 答：Linux Virtual Server，章文嵩博士，1998 年。

---

## §2 为什么需要 LVS：单台服务器性能瓶颈 + C10K/C100K + 水平扩展

**问题：单台服务器扛不住怎么办？**

```
方案 1：垂直扩展（Scale Up）
  单机升级 CPU / 加内存 / 换 SSD
  → 有天花板（摩尔定律失效、单机有物理上限）
  → 越往后性价比越差

方案 2：水平扩展（Scale Out）  ← LVS 走这条路
  加机器，组成集群
  → 理论上无限扩展
  → 性价比高（商用机就行）
  → 但需要"调度器"把流量分到不同机器
                          ↑
                      LVS 干这个
```

**经典性能瓶颈**：

| 场景 | 问题 | 解决方案 |
|------|------|---------|
| **C10K** | 单机 1 万并发连接 | LVS 把 1 万分给 10 台，每台 1 千 |
| **C100K** | 单机 10 万并发连接 | LVS + 多 RS + 优化内核参数 |
| **大文件下载** | 带宽瓶颈 | LVS + CDN + 多机房 |
| **突发流量** | 秒杀 / 抢票 | LVS + 自动扩缩容 |

**为什么选 LVS 而不是硬件 F5**：

| 维度 | F5 硬件 | LVS 软件 |
|------|---------|----------|
| 价格 | 几十万到上百万 | 免费（Linux 自带） |
| 性能 | 极强（百万 QPS） | 强（十万 QPS，足够 99% 场景） |
| 灵活性 | 低（出厂固件） | 高（开源可定制） |
| 运维 | 厂商支持 | 社区 + 自维护 |

**生产定位**：LVS = 互联网公司的"穷人版 F5"。

---

## §3 LVS 架构三要素：Director + Real Server + Client + VIP

```
┌──────────┐              ┌────────────────┐              ┌──────────────┐
│  Client  │ ───请求───> │   Director     │ ───转发───>  │  Real Server │
│ CIP: ?   │              │   VIP: 公网    │              │  RIP: 内网   │
│          │ <──响应───  │   DIP: 内网    │  <──响应───  │              │
└──────────┘              └────────────────┘              └──────────────┘
```

**三个角色**：

| 角色 | 作用 | 关键 IP |
|------|------|---------|
| **Client（CIP）** | 发起请求的客户端 | CIP = Client IP |
| **Director** | 调度器，接收并分发请求 | **VIP**（对外）+ **DIP**（对内） |
| **Real Server（RS）** | 真正提供服务的服务器 | RIP = Real Server IP |

**VIP 和 DIP 必须在 Director 上**：
- **VIP = Virtual IP**：对外提供服务的 IP（用户访问的）
- **DIP = Director IP**：与后端 RS 通信的 IP（一般内网）

**为什么 Director 要两个 IP**：
- VIP 对外（公网或内网入口）
- DIP 对内（与 RS 在同一内网）
- 两者可以在同一网卡（别名），也可以不同网卡

> ⚠️ **生产建议**：Director **不要用虚拟机**（负载压力大，物理机更稳）。

---

## §4 LVS 术语速查：VIP/DIP/RIP/CIP + IPVS/IP + ipvsadm/ipvsadmd

**IP 类术语**：

| 缩写 | 全称 | 含义 | 所在位置 |
|------|------|------|---------|
| **VIP** | Virtual IP | 虚拟 IP，对外服务 IP | Director 外网卡 |
| **DIP** | Director IP | Director 与 RS 通信的 IP | Director 内网卡 |
| **RIP** | Real Server IP | 后端真实服务器 IP | Real Server |
| **CIP** | Client IP | 客户端 IP | Client |

**软件类术语**：

| 缩写 | 全称 | 含义 | 位置 |
|------|------|------|------|
| **IPVS** | IP Virtual Server | 内核中的 IP 虚拟服务器代码 | 内核空间 |
| **ipvsadm** | IPVS Admin | 用户空间管理工具 | 用户空间 |
| **ipvsadmd** | IPVS Admin Daemon | 后台守护进程（部分版本） | 用户空间 |

**协议标识**：

| 缩写 | 含义 | 用法 |
|------|------|------|
| **VS / Virtual Service** | 虚拟服务（Director 上定义的） | `-t VIP:PORT` |
| **RS / Real Server** | 后端真实服务器 | `-r RIP:PORT` |

**工作模式标识（Forward Type）**：

| 标识 | 模式 | 含义 |
|------|------|------|
| `-g` | **gating (DR)** | 直接路由 |
| `-i` | **ipip (TUN)** | IP 隧道 |
| `-m` | **masquerade (NAT)** | NAT 模式（伪装） |

**示例**：
```bash
# -t = TCP，-s = scheduler，-r = real server，-m = masquerade (NAT)
ipvsadm -A -t 10.1.1.10:80 -s wrr
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -m -w 2
```

---

## §5 LVS vs Nginx：4 层 vs 7 层 + 性能 + 适用场景

**最常见的对比**：

| 维度 | LVS | Nginx |
|------|-----|-------|
| **工作层级** | 4 层（传输层，IP+PORT） | 7 层（应用层，HTTP/HTTPS） |
| **性能** | 极强（百万 QPS） | 强（数万 QPS） |
| **CPU 消耗** | 极低（内核态） | 较高（用户态解析 HTTP） |
| **配置复杂度** | 中（ipvsadm 命令） | 低（nginx.conf 友好） |
| **功能丰富度** | 弱（只做调度） | 强（缓存 / rewrite / 限流 / SSL） |
| **会话保持** | 内置持久连接（-p） | ip_hash / cookie |
| **后端健康检查** | 弱（需配合 ldirectord） | 强（自带 health check） |
| **适用协议** | 任意 TCP/UDP | 仅 HTTP/HTTPS |

**性能数据参考**：

```
LVS 单 Director 性能：≈ 几十万~百万 QPS
Nginx 单节点性能：≈ 几万 QPS（7 层解析开销）

差距原因：LVS 在内核 netfilter 链上工作，几乎无开销
        Nginx 在用户空间解析 HTTP header，开销大
```

**什么时候用哪个**：

```
✅ 选 LVS：
  - 超高并发（秒杀 / 抢票 / 大型电商）
  - 性能优先
  - 多协议负载均衡（MySQL / Redis / TCP 通用）
  - 作为入口网关

✅ 选 Nginx：
  - 需要 7 层特性（按 URL 分发 / header 改写 / 缓存）
  - HTTP/HTTPS 站点负载均衡
  - 需要友好的配置文件
  - 性能要求不是极端高

✅ 黄金组合：LVS + Nginx（多层 LB）
  - 入口 LVS（4 层，扛流量）
    ↓
  - 内部 Nginx（7 层，灵活分发）
    ↓
  - 后端应用服务器
```

**为什么 LVS 比 Nginx 性能高 10 倍**：

| 维度 | LVS | Nginx |
|------|-----|-------|
| 处理位置 | 内核 netfilter INPUT 链 | 用户态进程 |
| 上下文切换 | 无（内核态直处理） | 频繁（用户态 ↔ 内核态） |
| 协议解析 | 不解析（只看 IP:PORT） | 解析 HTTP header |
| 数据拷贝 | 几乎零拷贝 | 多次拷贝 |

---

## §6 LVS vs HAProxy vs F5：四层负载均衡三巨头对比

| 维度 | LVS | HAProxy | F5 BIG-IP |
|------|-----|---------|-----------|
| **类型** | 开源软件 | 开源软件 | 商业硬件 |
| **工作层级** | 4 层 | 4 层 / 7 层 | 4 层 / 7 层 |
| **性能** | 极强 | 强 | 极强（最强） |
| **价格** | 免费 | 免费 | 几十万起 |
| **配置** | ipvsadm 命令 | haproxy.cfg | Web GUI |
| **健康检查** | 弱（需辅助） | 强（内置） | 极强 |
| **会话保持** | 内置 -p | 多种算法 | 完整 |
| **适用规模** | 大型互联网 | 中大型 | 金融/电信级 |

**一句话总结**：
- **LVS**：穷人的 F5，性能首选
- **HAProxy**：折中方案，配置友好
- **F5**：有钱任性，业界标杆

> 💡 **面试题**：你们生产用什么 LB？
> 答：通常 LVS 做入口 4 层 LB + Nginx 做 7 层 LB + Keepalived 做高可用。

---

## §7 LVS 工作模式 1：NAT（网络地址转换）

### 工作原理

```
请求路径：CIP → VIP → DIP → RIP → RS
响应路径：RS → RIP → DIP → VIP → CIP   ← 来回都过 Director
```

**详细流程**：

```
Client  →  Director            →  Real Server
                                  ┌─────────────────┐
                                  │ 1. PREROUTING    │ 源=CIP, 目标=VIP
                                  │ 2. INPUT         │ (IPVS 判定是集群服务)
                                  │ 3. 修改目标 IP   │ 源=CIP, 目标=RIP
                                  │ 4. POSTROUTING   │
                                  │ 5. 发送给 RS     │
                                  └─────────────────┘
                                  ┌─────────────────┐
Real Server → Director          │ 1. 源=RIP, 目标=CIP
                                  │ 2. INPUT         │
                                  │ 3. 修改源 IP     │ 源=VIP, 目标=CIP
                                  │ 4. POSTROUTING   │
                                  │ 5. 响应给 Client │
                                  └─────────────────┘
```

**关键步骤**（请求）：
1. Client 发请求：`CIP → VIP`（到达 Director）
2. PREROUTING 判定目标 IP 是本机，送到 INPUT
3. IPVS 比对是集群服务 → **修改目标 IP 为 RIP**
4. POSTROUTING 通过路由发送给 RS

**关键步骤**（响应）：
5. RS 处理完，响应：`RIP → CIP`（发给 Director，因为 RS 网关指向 Director）
6. Director 收到响应 → **修改源 IP 为 VIP**
7. 响应给 Client：`VIP → CIP`

### 特点

| # | 特点 |
|---|------|
| 1 | **RS 的 RIP 应该使用私网地址**，且 **RS 的网关要指向 DIP** |
| 2 | 请求和响应报文**都要经由 Director 转发** |
| 3 | **支持端口映射**（VIP:80 → RIP:8080） |
| 4 | RS 可以使用任意 OS（Windows / Linux / Unix） |
| 5 | RS 的 RIP 和 Director 的 DIP **必须在同一 IP 网络** |

### 缺陷

❌ **Director 压力大**（来回都过 Director）
❌ **Director 是性能瓶颈**（流量 ×2：进出都过 Director）
❌ 不适合极高负载场景

### 优点

✅ **配置最简单**
✅ **支持端口映射**
✅ **支持任意 OS**（RS 跨平台）
✅ **支持跨网段**（RIP 和 CIP 不必在同一网段）

### 适用场景

- 小并发（千级 QPS）
- 测试环境
- 后端 RS 跨平台（必须 NAT 才能跨网段）

---

## §8 LVS 工作模式 2：DR（直接路由）生产环境 99% 用这个

> 🎯 **核心**：DR 是生产环境**绝对主流**（99% 的 LVS 集群都是 DR）。

### 工作原理

```
请求路径：CIP → VIP → DIP → RS（修改 MAC）
响应路径：RS → CIP（直接回，不经过 Director）← 关键！
```

**为什么叫"直接路由"**：
- 请求报文：**只修改 MAC 地址**，不改 IP
- 响应报文：**不经过 Director**，RS 直接回 Client

**详细流程（请求）**：

```
Client    →    Director      →    Real Server
┌─────────────────┐            ┌─────────────────┐
│ 1. 源=CIP, 目标=VIP  │           │ 1. RS 看到 MAC 是自己 │
│ 2. MAC 是 Director│            │ 2. 接收并处理      │
│ 3. IPVS 判定集群服务│            │ 3. 通过 lo 接口 VIP  │
│ 4. 修改源 MAC = DIP MAC  │           │    作为源 IP 发响应  │
│ 5. 修改目标 MAC = RIP MAC  │           └─────────────────┘
│ 6. 发送给 RS      │
└─────────────────┘

注意：IP 首部完全不变（仍是 CIP → VIP）
     只改了 MAC 头
```

**详细流程（响应）**：

```
Real Server  →  Client（不经过 Director！）
┌─────────────────┐
│ 1. RS 通过 lo 上的 VIP  │
│ 2. 通过 eth0 发出      │
│ 3. 源 IP = VIP        │
│ 4. 目标 IP = CIP      │
│ 5. 直接送达 Client    │
└─────────────────┘
```

### 特点

| # | 特点 |
|---|------|
| 1 | RS 的 **lo 网卡配置 VIP**（lo:0 = 127.0.0.1:VIP，alias） |
| 2 | 确保路由器只把 VIP 的请求发给 Director，**RS 不响应 VIP 的 ARP 请求** |
| 3 | RS 的 RIP 和 Director 的 DIP **必须在同一物理网络**（同网段） |
| 4 | RS 的 RIP 可用私网或公网 |
| 5 | **请求必须经过 Director**，**响应不经过 Director** |
| 6 | ❌ **不支持端口映射** |

### 核心问题：如何阻止 RS 响应 VIP 的 ARP 请求？

**问题根源**：
- Director 和 RS 都有 VIP（如 10.1.8.100）
- 如果 RS 响应 ARP 请求，交换机可能把请求发给 RS，Director 收不到
- 必须**让 RS 拒绝响应 VIP 的 ARP 请求**

**两种解决方案**：

```
方案 A：路由器静态绑定 Director 的 VIP 和 MAC（人工维护，难扩展）
方案 B：禁止 RS 响应 VIP 的 ARP 请求（推荐）
        ├─ (a) arptables（iptables 风格配置）
        └─ (b) 修改 RS 内核参数（arp_ignore + arp_announce）← 最常用
```

**内核参数**（必须理解）：
```
net.ipv4.conf.all.arp_ignore = 1       # RS 上：忽略 VIP 的 ARP 请求
net.ipv4.conf.all.arp_announce = 2     # RS 上：发送 ARP 时不包含 VIP
net.ipv4.conf.dummy.arp_ignore = 1     # dummy 接口上的 VIP
net.ipv4.conf.dummy.arp_announce = 2
```

### 优点

✅ **性能最强**（响应不经过 Director，几乎无瓶颈）
✅ **Director 压力小**（只负责请求调度）
✅ **生产环境 99% 用这个**

### 缺陷

❌ **RS 和 DS 必须在同一物理网络**（二层可达，MAC 转发）
❌ **不支持端口映射**（VIP 端口 = RS 端口）
❌ **跨网段不行**（不像 NAT 那样灵活）

### 适用场景

- 生产环境**首选**
- 同机房 / 同网段
- 高并发（十万~百万 QPS）

---

## §9 LVS 工作模式 3：TUN（IP 隧道）

### 工作原理

```
请求路径：CIP → VIP → DS 封装外层 IP → [IPIP 隧道] → RS
响应路径：RS → CIP（直接回，不经过 DS）
```

**关键**：在原 IP 首部外**再封装一层 IP 首部**（IP-in-IP 隧道）

```
原报文：[CIP → VIP] + [TCP payload]
                  ↓
改为：[DIP → RIP] + [CIP → VIP] + [TCP payload]
     ↑ 外层 IP          ↑ 内层原 IP
```

**详细流程（请求）**：

```
Client    →    Director         →    Real Server（跨网段！）
┌──────────────────────┐         ┌──────────────────────┐
│ 1. 源=CIP, 目标=VIP  │         │ 1. 收到带隧道封装的数据 │
│ 2. IPVS 判定集群服务 │         │ 2. 拆掉外层 IP         │
│ 3. 封装外层 IP       │         │    看到内层目标=VIP     │
│    外层: DIP → RIP   │         │ 3. 通过 lo 上的 VIP 接收 │
│    内层: CIP → VIP   │         │ 4. 处理 + 直接回 Client │
│ 4. 通过隧道发给 RS   │         └──────────────────────┘
└──────────────────────┘
```

### 特点

| # | 特点 |
|---|------|
| 1 | **RIP、DIP、VIP 必须都是公网地址** |
| 2 | RS 的网关**不能、也不可能**指向 DIP（跨网段） |
| 3 | 请求经 DS 调度，响应**直接发给 CIP** |
| 4 | ❌ 不支持端口映射 |
| 5 | RS 的 OS **必须支持 IP 隧道功能**（Linux 支持，Windows 部分支持） |

### 优点

✅ **跨网段、跨机房**（可以组建异地集群）
✅ 响应不经过 DS

### 缺陷

❌ **配置复杂**（IP 隧道封装开销）
❌ **所有 IP 都要公网**（费用高）
❌ **一般公司不用**（实用性差）
❌ RS 必须支持 IP 隧道

### 适用场景

- 跨机房 / 跨地域的 LVS 集群
- 公网环境部署
- 实际很少用（用 DNS 智能解析替代）

> 💡 本 PDF 中**明确说明 TUN 模式不讨论**（"不讨论"），生产也很少用。

---

## §10 LVS 工作模式 4：FULLNAT（双向 SNAT/DNAT）

### 工作原理

**FULLNAT = NAT + 反向 NAT**：

```
请求：CIP → VIP → [SNAT] → DIP → [DNAT] → RIP → RS
响应：RS → RIP → [DNAT] → DIP → [SNAT] → VIP → CIP
```

**和 NAT 的区别**：

| 模式 | 请求 | 响应 |
|------|------|------|
| **NAT** | DNAT（CIP→VIP→RIP） | SNAT（RIP→VIP→CIP） |
| **FULLNAT** | 同时做 SNAT + DNAT | 同时做 SNAT + DNAT |

**FULLNAT 关键特性**：**CIP 和 RIP 可以不在同一网段**！

### 特点

| # | 特点 |
|---|------|
| 1 | 同时修改请求报文的源 IP 和目标 IP |
| 2 | 同时修改响应报文的源 IP 和目标 IP |
| 3 | CIP 和 RIP **可以不在同一网段**（最大优势） |
| 4 | 请求和响应都过 Director |

### 优点

✅ **跨 VLAN**（CIP 和 RIP 任意网段）
✅ 解决了 NAT 模式下 RIP 必须和 DIP 同网段的限制

### 缺陷

❌ **需要内核编译**（默认内核不支持）
❌ **需要 keepalived 支持**
❌ 性能略低于 DR
❌ 调试复杂

### 适用场景

- 复杂网络拓扑（VLAN 隔离的 IDC）
- 阿里云 / 华为云的 SLB 内部使用 FULLNAT

> 💡 **生产实际**：FULLNAT 主要被云厂商（阿里云 SLB）使用，普通企业很少自建。

---

## §11 4 种模式对比表：性能 / 网络要求 / 部署复杂度 / 适用场景

| 维度 | NAT | DR | TUN | FULLNAT |
|------|-----|----|----|---------|
| **请求路径** | CIP→VIP→RIP | CIP→VIP→RIP（改 MAC） | CIP→VIP→RIP（隧道） | CIP→VIP→RIP（双 NAT） |
| **响应路径** | RIP→VIP→CIP | RIP→CIP（直回） | RIP→CIP（直回） | RIP→VIP→CIP（双 NAT） |
| **响应过 DS** | 是 | 否 | 否 | 是 |
| **RIP 与 DIP 同网段** | 必须 | 必须 | 不必 | 不必 |
| **CIP 与 RIP 同网段** | 不必 | 不必 | 不必 | 不必 |
| **RS 数量上限** | ~10-20 | ~100+ | ~100+ | ~100+ |
| **DS 性能瓶颈** | 大（双倍流量） | 几乎无 | 几乎无 | 中等 |
| **支持端口映射** | ✅ | ❌ | ❌ | ❌ |
| **RS 可用私网 IP** | ✅ | ✅ | ❌（必须公网） | ✅ |
| **部署复杂度** | 简单 | 中等 | 复杂 | 复杂 |
| **性能** | 一般 | **最强** | 强 | 较强 |
| **生产使用率** | 5% | **95%** | <1% | <1%（云厂商用） |
| **代表场景** | 测试 / 小并发 | 生产首选 | 跨机房 | 阿里云 SLB |

### 一句话选择指南

```
- 高并发 + 同网段 → DR（生产 99%）
- 跨网段 + 简单 + 小并发 → NAT（学习 / 测试）
- 跨机房 + 公网 → TUN（极少用）
- 云厂商 / 复杂 VLAN → FULLNAT（阿里云 SLB 内部）
```

---

## §12 ipvsadm 安装：yum install ipvsadm + 加载 ip_vs 模块

### 安装步骤

```bash
# 1. 安装 ipvsadm
yum install -y ipvsadm

# 2. 创建 ipvsadm 的工作文件（systemd 启动依赖）
touch /etc/sysconfig/ipvsadm

# 3. 启动服务（同时加载 ip_vs 内核模块）
systemctl enable ipvsadm --now

# 4. 验证内核模块加载
lsmod | grep ip_vs
# ip_vs                 145408  0
# nf_conntrack          139264  1 ip_vs
# libcrc32c              12288  1 ip_vs

# 5. 验证版本
ipvsadm -v
# ipvsadm v1.31 (compiled with popt and IPVS v1.2.1)
```

### 模块说明

| 模块 | 作用 |
|------|------|
| **ip_vs** | 核心调度模块（LVS 内核态） |
| **nf_conntrack** | 连接跟踪（依赖） |
| **nf_nat** | NAT 模式依赖（NAT/FULLNAT 需要） |

### 关键事实

- ❌ **LVS 没有配置文件**（不像 nginx.conf）
- ✅ 所有配置通过 **ipvsadm 命令** 写入内核
- ✅ 重启需用 `ipvsadm-save` 保存规则，否则重启丢失

```bash
# 保存当前规则到文件
ipvsadm-save -n > /etc/sysconfig/ipvsadm

# 重启后自动加载（systemd 启动 ipvsadm.service 时读取此文件）
```

---

## §13 ipvsadm 核心命令：add/del/edit + 增删改虚拟服务 + 增删改真实服务器

### 命令分类

```
ipvsadm 命令分两大类：
  1. 管理集群服务（虚拟服务 VS）
     -A / -E / -D  （add / edit / delete）
  
  2. 管理集群服务中的 Real Server
     -a / -e / -d  （add / edit / delete）
```

### 定义集群服务（管理 VS）

```bash
ipvsadm -A|E -t|u|f service-address [-s scheduler] [-p [timeout]] [-M netmask]
```

| 选项 | 含义 |
|------|------|
| `-A` | 添加一个新的集群服务 |
| `-E` | 编辑集群服务 |
| `-D` | 删除集群服务 |
| `-t` | TCP 协议（如 `-t 10.1.1.10:80`） |
| `-u` | UDP 协议 |
| `-f` | firewall-Mark（防火墙标记） |
| `service-address` | 集群服务地址 = VIP:PORT |
| `-s` | 指定调度算法（默认 wlc） |
| `-p` | 持久连接时长（秒） |
| `-M` | 定义持久连接掩码 |

**示例**：
```bash
# 添加一个 TCP 集群服务，调度算法 wrr
ipvsadm -A -t 10.1.1.10:80 -s wrr

# 删除集群服务
ipvsadm -D -t 10.1.1.10:80
```

### 管理 Real Server

```bash
ipvsadm -a|e -t|u|f service-address -r server-address [-g|i|m] [-w weight]
```

| 选项 | 含义 |
|------|------|
| `-a` | 添加 RS |
| `-e` | 编辑 RS |
| `-d` | 删除 RS |
| `-r` | RS 地址（如 `-r 10.1.8.11:80`） |
| `-g` | **gating = DR 模式**（默认） |
| `-i` | **ipip = TUN 模式** |
| `-m` | **masquerade = NAT 模式** |
| `-w` | 权重（默认 1） |

**示例**：
```bash
# NAT 模式添加 RS
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -m

# DR 模式添加 RS（默认 -g，可省略）
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -g

# 加权（wrr 算法下生效）
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -m -w 3
```

### 其他命令

```bash
# 查看规则
ipvsadm -L -n                    # 数字格式（推荐）
ipvsadm -L -n --stats            # 显示连接统计
ipvsadm -L -n --rate             # 显示速率
ipvsadm -Lcn                     # 查看持久连接状态

# 清空规则
ipvsadm -C

# 清空计数器
ipvsadm -Z [-t|u|f service-address]

# 保存规则
ipvsadm -S [-n]
ipvsadm-save -n > /etc/sysconfig/ipvsadm

# 重新载入规则
ipvsadm -R
ipvsadm-restore < /etc/sysconfig/ipvsadm
```

### 速记口诀

```
大 A 大 E 大 D：管理集群服务（VS）
小 a 小 e 小 d：管理后端服务器（RS）
C 清空，Z 清计数，S 保存，R 重载
L -n 看规则，Lcn 看持久连接
g DR，i TUN，m NAT
```

---

## §14 调度算法概述：静态算法 vs 动态算法

```
LVS 调度算法
  ├── 静态算法（不考虑后端实际状态）
  │     ├── rr    轮询
  │     ├── wrr   加权轮询
  │     ├── dh    目标地址哈希
  │     └── sh    源地址哈希
  │
  └── 动态算法（根据后端连接数 / 负载分配）
        ├── lc    最少连接
        ├── wlc   加权最少连接（默认）
        ├── sed   最短延迟调度
        ├── nq    永不排队
        ├── lblc  基于局部性的最少连接
        └── lblcr 带复制的基于局部性最少连接
```

**静态 vs 动态**：

| 类型 | 特点 | 算法 |
|------|------|------|
| **静态** | 按算法规则轮，不考虑后端实际负载 | rr / wrr / dh / sh |
| **动态** | 根据后端连接数 / 负载动态调整 | lc / wlc / sed / nq / lblc / lblcr |

> ⚠️ **生产默认算法：wlc（加权最少连接）**。

---

## §15 调度算法 1：rr 轮询（Round Robin）

### 原理

**轮叫调度**：按顺序轮流分配请求给每台 RS。

```
请求 1 → RS1
请求 2 → RS2
请求 3 → RS3
请求 4 → RS1   ← 循环
请求 5 → RS2
请求 6 → RS3
```

### 特点

- **均等地对待每台服务器**
- 不管服务器上实际的连接数和系统负载

### 适用场景

- RS 配置完全相同（CPU / 内存 / 带宽）
- 短连接场景（如 HTTP）

### 示例

```bash
# 添加集群服务，调度算法 rr
ipvsadm -A -t 10.1.1.10:80 -s rr

# 添加 3 台 RS（权重默认 1）
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -m
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.12:80 -m
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.13:80 -m

# 验证：访问 90 次，每个 RS 各 30 次
for i in {1..90}; do curl -s 10.1.1.10; done | sort | uniq -c
# 30 Welcome to web1
# 30 Welcome to web2
# 30 Welcome to web3
```

---

## §16 调度算法 2：wrr 加权轮询（Weighted RR）

### 原理

**加权轮叫**：根据 RS 处理能力分配不同权重，权重高的多接请求。

```
RS1 weight=1
RS2 weight=2
RS3 weight=3

请求分配：
请求 1 → RS1
请求 2 → RS2
请求 3 → RS2
请求 4 → RS3
请求 5 → RS3
请求 6 → RS3
请求 7 → RS1
请求 8 → RS2
...循环
```

### 特点

- 根据 RS 的处理能力分配请求
- 强的机器多扛流量

### 适用场景

- RS 配置不均匀（有的 8 核，有的 16 核）
- 临时让某台 RS 多接流量（如升级 / 压测）

### 示例

```bash
# 修改为 wrr
ipvsadm -E -t 10.1.1.10:80 -s wrr

# 修改权重：RS1=1, RS2=2, RS3=3
ipvsadm -e -t 10.1.1.10:80 -r 10.1.8.11:80 -m -w 1
ipvsadm -e -t 10.1.1.10:80 -r 10.1.8.12:80 -m -w 2
ipvsadm -e -t 10.1.1.10:80 -r 10.1.8.13:80 -m -w 3

# 验证：90 次请求按 1:2:3 分配
for i in {1..90}; do curl -s 10.1.1.10; done | sort | uniq -c
# 15 Welcome to web1
# 30 Welcome to web2
# 45 Welcome to web3
```

---

## §17 调度算法 3：lc 最少连接（Least Connections）

### 原理

**最少连接**：把请求分配给**当前连接数最少**的 RS。

```
当前状态：
  RS1: 100 个连接
  RS2: 50 个连接  ← 最少
  RS3: 80 个连接

下一个请求 → RS2
```

### 特点

- 动态算法，**只看连接数**
- 不考虑 RS 性能差异

### 适用场景

- 长连接应用（如 MySQL、SSH）
- RS 配置相近

### 计算方式

```
ActiveConn * 256 + InActConn

数值最小的 RS 接下一个请求。
```

### 缺陷

- 不考虑 RS 性能差异（弱的机器可能挂）

---

## §18 调度算法 4：wlc 加权最少连接（默认采用）

### 原理

**加权最少连接**：在 lc 基础上**考虑权重**。

```
Overhead = (ActiveConn * 256 + InActConn) / weight

数值最小的 RS 接下一个请求。
```

### 公式

```
overhead = (active_conns * 256 + inactive_conns) / weight
```

### 特点

- **LVS 默认算法**（不指定 -s 时就是 wlc）
- 综合考虑 RS 性能 + 当前连接数

### 适用场景

- **绝大多数生产环境**（默认选择）

### 示例

```bash
# 默认就是 wlc，可省略 -s
ipvsadm -A -t 10.1.1.10:80

# 或显式指定
ipvsadm -A -t 10.1.1.10:80 -s wlc
```

---

## §19 调度算法 5：sed 最短延迟调度（Shortest Expected Delay）

### 原理

**最短预期延迟**：在 wlc 基础上改进，**不考虑非活动状态**。

```
Overhead = (ACTIVE + 1) * 256 / weight

+1 的目的：考虑加权时，非活动连接过多时也能分到
```

### 特点

- 只看**活动连接**（ActiveConn）
- 忽略 InActConn

### 缺陷

- 当权限（权重）过大时，会导致空闲服务器一直无连接

### 适用场景

- 特殊场景（一般用 wlc 就够了）

---

## §20 调度算法 6：nq 永不排队 / 最少队列（Never Queue）

### 原理

**永不排队**：在 sed 基础上加一个特例——**如果有 RS 连接数 = 0，直接分配，不再 sed 运算**。

```
规则：
  1. 如果有 RS 的 ActiveConn = 0，立即分给它（不等计算）
  2. 否则按 sed 算法计算
  
第二次一定分给下一个（保证不会一直空闲）
```

### 特点

- 保证**不会有一个主机很空闲**
- 适合**避免单点过载**

### 适用场景

- DNS（UDP，无活动连接概念 → 直接用 NQ）
- 避免某个 RS 长期空闲

### 对比

```
SED：考虑活动 + 非活动连接（适合 HTTP 保持连接）
NQ： 只考虑活动连接（适合 UDP / DNS）
```

---

## §21 调度算法 7：lblc 基于局部性的最少连接（Cache 集群专用）

### 原理

**基于目标 IP 的最少连接**：针对**目标 IP 地址**做局部性调度。

```
算法：
1. 根据请求的目标 IP，找出该 IP 最近使用的 RS
2. 如果该 RS 可用且未超载 → 继续用这台
3. 否则按"最少连接"原则选一个 RS
```

### 适用场景

- **Cache 集群**（Squid / Varnish / CDN）
- 相同目标 IP 的请求尽量走同一 RS（提高 Cache 命中率）

### 核心价值

**Cache 亲和性**：相同目标 IP 的请求总走同一 RS，让 Cache 命中率最高。

---

## §22 调度算法 8：lblcr 带复制的基于局部性最少连接

### 原理

**带复制**：在 lblc 基础上，**目标 IP 维护一组 RS**（而非一台）。

```
算法：
1. 根据请求的目标 IP，找出对应的 RS 组
2. 按"最少连接"从组里选一台
3. 如果选中的 RS 超载 → 按最少连接从集群里选一台加入组
4. 当组一段时间没修改 → 删除最忙的 RS（降低复制）
```

### 特点

- **目标 IP → 一组 RS**（lblc 是 → 一台 RS）
- 动态调整 RS 组

### 适用场景

- **Cache 集群**
- 比 lblc 更复杂，但更灵活

### 对比 lblc vs lblcr

| 维度 | lblc | lblcr |
|------|------|-------|
| 目标 IP → | 一台 RS | 一组 RS |
| 复杂度 | 简单 | 复杂 |
| Cache 命中率 | 高 | 更高 |
| 适用 | Cache 集群 | 大型 Cache 集群 |

---

## §23 8 种调度算法对比：适用场景 + 优缺点 + 默认选择

| 算法 | 类型 | 适用场景 | 优缺点 |
|------|------|---------|--------|
| **rr** | 静态 | RS 同构、短连接 | 简单但不考虑负载 |
| **wrr** | 静态 | RS 异构、短连接 | 按权重分配，RS 性能差异场景 |
| **lc** | 动态 | RS 同构、长连接 | 考虑连接数 |
| **wlc**（默认） | 动态 | **生产首选** | 综合考虑权重+连接数 |
| **sed** | 动态 | 活动连接敏感 | wlc 改进，不考虑 InAct |
| **nq** | 动态 | UDP / DNS | 保证不空闲 |
| **lblc** | 动态 | **Cache 集群** | 按目标 IP 局部性 |
| **lblcr** | 动态 | **大型 Cache 集群** | lblc 升级版 |

### 默认选择决策树

```
HTTP 短连接 + RS 同构 → rr
HTTP 短连接 + RS 异构 → wrr
HTTP 长连接 / 长事务 → wlc（默认）
MySQL / SSH 长连接 → wlc 或 lc
UDP / DNS → nq
Cache 集群（Squid）→ lblc / lblcr
```

---

## §24 调度算法 dh 与 sh：目标地址哈希 + 源地址哈希（会话保持）

### dh（Destination Hashing）目标地址哈希

**原理**：根据**目标 IP** 作为 hash key，从静态散列表找出对应 RS。

```
请求的目标 IP = X.X.X.X
hash(X.X.X.X) % N = RS_index

同一个目标 IP 的请求总是分配到同一台 RS
```

**用途**：Cache 集群（相同目标 IP → 同一 RS → 命中缓存）

### sh（Source Hashing）源地址哈希

**原理**：根据**源 IP** 作为 hash key。

```
请求的源 IP = C.C.C.C
hash(C.C.C.C) % N = RS_index

同一个客户端的请求总是分配到同一台 RS
```

**用途**：**会话保持**（同一用户的请求 → 同一台 RS → Session 不丢）

### 对比

| 算法 | Hash Key | 用途 |
|------|----------|------|
| **dh** | 目标 IP | Cache 命中 |
| **sh** | 源 IP | 会话保持 |

### sh 示例（会话保持场景）

```bash
# 电商网站（用户登录后 Session 在 RS 上）
# 用 sh 保证同一用户访问同一 RS
ipvsadm -A -t 10.1.1.10:80 -s sh
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11:80 -m
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.12:80 -m
```

---

## §25 持久连接 PCC/PPC/SIP：解决会话问题 + 客户端绑定到同一 RS

### 为什么需要持久连接？

```
问题场景：
  1. 用户登录 → RS1（Session 存在 RS1 上）
  2. 下个请求 → RS2（RS2 不知道用户登录了！）
  3. 用户被"踢出登录"
  
原因：普通调度算法每次都可能换 RS
解决：让同一客户端的所有请求都到同一台 RS
```

### LVS 持久连接的三种形式

| 形式 | 全称 | 含义 |
|------|------|------|
| **PCC** | Persistent Client Connection | **基于客户端**的持久连接（所有端口） |
| **PPC** | Persistent Port Connection | **基于端口**的持久连接（同一端口同一 RS） |
| **PCC per FWMark** | 防火墙标记 | 基于防火墙标记的持久连接 |

### PCC 实战（最常用）

```bash
# 让所有访问 VIP 的请求都去同一台 RS（600 秒内）
ipvsadm -A -t 10.1.1.10:0 -s rr -p 600
ipvsadm -a -t 10.1.1.10:0 -r 10.1.8.11:80 -m
ipvsadm -a -t 10.1.1.10:0 -r 10.1.8.12:80 -m

# 600 秒内，同一客户端的 80、443、22...所有端口都到同一 RS
```

### 关键参数

```bash
-p [timeout]   # 持久连接时长（秒）
-M netmask     # 持久连接掩码（控制粒度）
```

### 验证持久连接

```bash
# 查看持久连接状态
ipvsadm -Lcn
# 输出：客户端 IP + 后端 RS + 过期时间
```

### sh vs 持久连接

| 维度 | sh（源地址哈希） | 持久连接 PCC |
|------|----------------|------------|
| 实现 | 算法层 | 调度层 |
| 粒度 | 永久 | 超时（-p） |
| 配置 | `-s sh` | `-p 600` |
| 灵活性 | 较低 | 较高（可设置超时） |

---

## §26 健康检查：ldirectord + keepalived 内置 + 后端 RS 故障剔除

### 为什么需要健康检查？

```
问题：
  RS1 挂了（nginx 进程死了 / 端口没监听）
  用户请求 → DS → RS1 → 超时 → 用户看到 502
  
  如果 DS 知道 RS1 挂了，就直接绕开它！
```

### 方案 1：ldirectord

**ldirectord** = 专门为 LVS 设计的健康检查守护进程。

```bash
# 安装
yum install -y ldirectord

# 配置示例 /etc/ha.d/ldirectord.cf
checktimeout=3
checkinterval=1
autoreload=yes
quiescent=yes
virtual=10.1.1.10:80
    real=10.1.8.11:80 gate 2
    real=10.1.8.12:80 gate 1
    real=10.1.8.13:80 gate 1
    scheduler=wrr
    service=http
    request="/index.html"
    receive="Welcome to"
```

### 方案 2：keepalived 内置健康检查（生产首选）

**Keepalived** 不仅能做 HA（高可用），还能做 LVS 健康检查。

```bash
# keepalived.conf 片段
virtual_server 10.1.1.10 80 {
    delay_loop 6              # 检查间隔（秒）
    lb_algo wrr               # 调度算法
    lb_kind DR                # 工作模式
    persistence_timeout 50    # 持久连接
    
    real_server 10.1.8.11 80 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3
            connect_port 80
        }
    }
}
```

### 故障剔除流程

```
正常：
  DS → RS1（健康，权重 1）
  DS → RS2（健康，权重 1）
  DS → RS3（健康，权重 1）

RS1 挂：
  DS 检测 RS1 失败 → 把 RS1 权重改为 0
  DS → RS1（不分配）
  DS → RS2（健康，权重 1）
  DS → RS3（健康，权重 1）

RS1 恢复：
  DS 检测 RS1 成功 → 恢复权重 1
  DS → RS1（健康，权重 1）
  DS → RS2（健康，权重 1）
  DS → RS3（健康，权重 1）
```

### 生产实践

- **LVS + Keepalived** 是黄金组合（HA + 健康检查）
- 详见 [[LinuxKeepalived]] 模块

---

## §27 LVS-NAT 模式实战部署（一）：网络拓扑 + 主机规划

### 实验环境

- **5 台 CentOS-7 虚拟机**
- 2 个网段：`10.1.1.0/24`（vmnet1）+ `10.1.8.0/24`（vmnet8）
- 网段网关指向 LVS

### 主机清单

| 主机名 | IP 地址 | 网关 | DNS | 角色 |
|--------|---------|------|-----|------|
| client1.laogao.cloud | 10.1.8.21（vmnet8） | 10.1.8.10 | 223.5.5.5 | 客户端 |
| client2.laogao.cloud | 10.1.1.21（vmnet1） | 10.1.1.10 | 223.5.5.5 | 客户端 |
| lvs.laogao.cloud | 10.1.8.10（vmnet8）+ 10.1.1.10（vmnet1） | 无 | 223.5.5.5 | LVS 服务器 |
| web1.laogao.cloud | 10.1.8.11（vmnet8） | 10.1.8.10 | 223.5.5.5 | Web 服务器 |
| web2.laogao.cloud | 10.1.8.12（vmnet8） | 10.1.8.10 | 223.5.5.5 | Web 服务器 |
| web3.laogao.cloud | 10.1.8.13（vmnet8） | 10.1.8.10 | 223.5.5.5 | Web 服务器 |

### 网络拓扑

```
                 ┌──────────────────┐
                 │  client1 (LVS 后)│
                 │   10.1.8.21      │
                 │   gw: 10.1.8.10  │
                 └─────────┬────────┘
                           │
   ┌───────────────────────┴───────────────────────┐
   │              10.1.8.0/24 网段                  │
   │                                                │
   │  ┌────────┐  ┌────────┐  ┌────────┐           │
   │  │  web1  │  │  web2  │  │  web3  │           │
   │  │10.1.8.11│  │10.1.8.12│  │10.1.8.13│           │
   │  └────────┘  └────────┘  └────────┘           │
   │         ↑         ↑         ↑                  │
   │         └─────────┼─────────┘                  │
   │                   │ gw: 10.1.8.10              │
   │              ┌────┴────┐                       │
   │              │   LVS   │                       │
   │              │10.1.8.10│                       │
   │              │10.1.1.10│ (VIP)                 │
   │              └────┬────┘                       │
   └───────────────────┼────────────────────────────┘
                       │
   ┌───────────────────┴────────────────────────────┐
   │              10.1.1.0/24 网段                  │
   │              ┌────────┐                        │
   │              │client2 │                        │
   │              │10.1.1.21│ gw: 10.1.1.10         │
   │              └────────┘                        │
   └────────────────────────────────────────────────┘
```

### 网卡配置约定

- **所有主机**：第一块网卡 `ens33`（NAT 模式，vmnet8 = 10.1.8.0/24），第二块 `ens36`（hostonly，vmnet1 = 10.1.1.0/24）
- **LVS 主机**：ens33 = 10.1.8.10（连 RS 网段），ens36 = 10.1.1.10（VIP，连 Client）

> ⚠️ **关键**：所有 Web 的网关指向 LVS（10.1.8.10）。

---

## §28 LVS-NAT 模式实战部署（二）：基础配置 + 主机名 + IP

### 配置脚本（所有主机）

```bash
# client2 配置
hostnamectl set-hostname client2.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.1.21/24 ipv4.gateway 10.1.1.10 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# client1 配置
hostnamectl set-hostname client1.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.21/24 ipv4.gateway 10.1.8.10 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# lvs 配置（双网卡）
hostnamectl set-hostname lvs.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.10/24 ipv4.gateway 10.1.8.2 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
nmcli connection add type ethernet con-name ens36 ifname ens36 ipv4.method manual ipv4.addresses 10.1.1.10/24 autoconnect yes
nmcli connection up ens36

# web1 配置
hostnamectl set-hostname web1.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.11/24 ipv4.gateway 10.1.8.10 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
```

### web2 / web3 同样配置（修改 IP 即可）

```bash
# web2
hostnamectl set-hostname web2.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.12/24 ipv4.gateway 10.1.8.10 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# web3
hostnamectl set-hostname web3.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.13/24 ipv4.gateway 10.1.8.10 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
```

---

## §29 LVS-NAT 模式实战部署（三）：Director 路由 + 防火墙 + 后端 Web 部署

### Director 端配置

```bash
# 1. 开启 IP 转发（核心！）
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 2. 启动防火墙（NAT 模式依赖 netfilter）
systemctl enable firewalld.service --now

# 3. 配置防火墙（trusted 区域 + IP 伪装）
firewall-cmd --set-default-zone=trusted
firewall-cmd --add-masquerade --permanent
firewall-cmd --add-masquerade
```

> ⚠️ **为什么需要 ip_forward=1**：LVS 主机作为路由器，必须开启 IP 转发才能把请求从 ens36 转给 ens33 后面的 RS。

> ⚠️ **为什么需要 masquerade**：NAT 模式依赖 netfilter 的 IP 伪装。

### 后端 Web 部署（所有 web 执行）

```bash
# 1. 安装 EPEL 源 + nginx
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install -y nginx

# 2. 自定义首页（区分 RS）
echo Welcome to $(hostname) > /usr/share/nginx/html/index.html

# 3. 启动 nginx
systemctl enable nginx.service --now
```

### 验证 Web 可直接访问

```bash
# 在 client1 上验证 RS 单独可访问
[root@client1 ~]# curl 10.1.8.11
Welcome to web1.laogao.cloud
[root@client1 ~]# curl 10.1.8.12
Welcome to web2.laogao.cloud
[root@client1 ~]# curl 10.1.8.13
Welcome to web3.laogao.cloud
```

---

## §30 LVS-NAT 模式实战部署（四）：ipvsadm 配置 + rr/wrr 验证

### ipvsadm 配置

```bash
# 1. 安装 ipvsadm
yum install -y ipvsadm
touch /etc/sysconfig/ipvsadm
systemctl enable ipvsadm --now

# 2. 添加集群服务（VIP = 10.1.1.10，TCP 80，rr 调度）
ipvsadm -A -t 10.1.1.10:80 -s rr

# 3. 添加 3 台 RS（NAT 模式 -m）
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.11 -m
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.12 -m
ipvsadm -a -t 10.1.1.10:80 -r 10.1.8.13 -m

# 4. 保存规则
ipvsadm-save -n > /etc/sysconfig/ipvsadm

# 5. 验证配置
[root@lvs ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.1.1.10:80 rr
  -> 10.1.8.11:80                 Masq    1      0          0
  -> 10.1.8.12:80                 Masq    1      0          0
  -> 10.1.8.13:80                 Masq    1      0          0
```

注意 **Forward = Masq**（Masquerade = NAT 模式）。

### 验证 rr 调度

```bash
# 在 client2（NAT 网段外侧）验证
[root@client2 ~]# for i in {1..90};do curl -s 10.1.1.10 ;done|sort|uniq -c
     30 Welcome to web1.laogao.cloud
     30 Welcome to web2.laogao.cloud
     30 Welcome to web3.laogao.cloud
```

### 修改为 wrr 加权轮询

```bash
# 1. 修改调度算法为 wrr
ipvsadm -E -t 10.1.1.10:80 -s wrr

# 2. 修改权重
ipvsadm -e -t 10.1.1.10:80 -r 10.1.8.12 -m -w 2
ipvsadm -e -t 10.1.1.10:80 -r 10.1.8.13 -m -w 3

# 3. 验证
[root@lvs ~]# ipvsadm -Ln
TCP  10.1.1.10:80 wrr
  -> 10.1.8.11:80                 Masq    1      0          30
  -> 10.1.8.12:80                 Masq    2      0          30
  -> 10.1.8.13:80                 Masq    3      0          30

# 4. 验证权重（90 次请求按 1:2:3 分配）
[root@client2 ~]# for i in {1..90};do curl -s 10.1.1.10 ;done|sort|uniq -c
     15 Welcome to web1.laogao.cloud
     30 Welcome to web2.laogao.cloud
     45 Welcome to web3.laogao.cloud
```

---

## §31 LVS-NAT 实战思考：同网段客户端无法访问的坑

### 问题

```
client1（10.1.8.21）和 web（10.1.8.11）在同一网段
client1 直接 curl 10.1.8.11 → OK（直接通信）

但是：client1 → 10.1.1.10（VIP）→ ???
```

### 答案

**client1 无法通过 VIP（10.1.1.10）访问后端服务器**。

**原因分析**：

```
client1 发包：10.1.8.21 → 10.1.1.10（VIP）
↓
LVS ipvs 处理：DNAT 改为 10.1.8.21 → 10.1.8.11
↓
web1 收到包，发现源 IP 是 10.1.8.21（client1，同网段）
↓
web1 直接回包：10.1.8.11 → 10.1.8.21（不经 LVS！）
↓
结果：client1 收到 10.1.8.11 的响应包，以为是 web1 直连，丢弃了（实际 LVS 已修改目标 IP）
```

**本质问题**：web1 和 client1 **同网段**，web1 认为 client1 在本地，直接回包，绕过了 LVS。

### 解决方案

**让 web 强制把响应回给 LVS**（通过强制路由）：

```bash
# 在 web1-3 上添加：访问 10.1.8.21 的响应必须经过 10.1.8.10（LVS）
nmcli connection modify ens33 ipv4.routes '10.1.8.21 255.255.255.255 10.1.8.10'
nmcli connection up ens33
```

> 💡 **核心洞察**：NAT 模式下，RS 必须通过 LVS 返程（网关指向 LVS）。如果 client 和 RS 在同一网段，RS 可能绕过 LVS 直回，需要强制路由修正。

---

## §32 LVS-DR 模式实战部署（一）：网络拓扑 + Router + 主机规划

### 实验环境

- **6 台主机**（比 NAT 多一台 router）
- 引入 **router** 把 LVS 网段（10.1.8.0/24）和 Client 网段（10.1.1.0/24）打通

### 主机清单

| 主机名 | IP 地址 | 网关 | DNS | 角色 |
|--------|---------|------|-----|------|
| client1.laogao.cloud | 10.1.8.21（vmnet8） | 10.1.8.20 | 223.5.5.5 | 客户端 |
| client2.laogao.cloud | 10.1.1.21（vmnet1） | 10.1.1.20 | 223.5.5.5 | 客户端 |
| lvs.laogao.cloud | 10.1.8.10（vmnet8） | 10.1.8.20 | 223.5.5.5 | LVS 服务器 |
| web1.laogao.cloud | 10.1.8.11（vmnet8） | 10.1.8.20 | 223.5.5.5 | Web 服务器 |
| web2.laogao.cloud | 10.1.8.12（vmnet8） | 10.1.8.20 | 223.5.5.5 | Web 服务器 |
| web3.laogao.cloud | 10.1.8.13（vmnet8） | 10.1.8.20 | 223.5.5.5 | Web 服务器 |
| router.laogao.cloud | 10.1.8.20（vmnet8）+ 10.1.1.20（vmnet1） | 10.1.8.2 | 223.5.5.5 | 路由器 |

### 网络拓扑

```
   10.1.1.0/24                          10.1.8.0/24
   ┌──────────┐      ┌──────────┐        ┌──────────────────────┐
   │ client2  │ ───> │  router  │ <────> │   LVS / Web 集群      │
   │10.1.1.21 │      │10.1.1.20 │        │  LVS: 10.1.8.10       │
   │          │      │10.1.8.20 │        │  Web: 10.1.8.11/12/13 │
   └──────────┘      └──────────┘        │  VIP: 10.1.8.100      │
                                          └──────────────────────┘
                                          client1: 10.1.8.21
```

### VIP 设计

DR 模式下 VIP **和 RS 在同一网段**（同二层）：

- LVS 网卡 `ens33`：10.1.8.10 + 10.1.8.100（VIP）
- RS `lo` 接口：10.1.8.100（VIP）

---

## §33 LVS-DR 模式实战部署（二）：基础配置 + Router 配置 + Web 部署

### 主机名 + IP 配置（同 NAT 模式，网关改指向 router）

```bash
# client2（10.1.1.0/24 网段）
hostnamectl set-hostname client2.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.1.21/24 ipv4.gateway 10.1.1.20 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# client1
hostnamectl set-hostname client1.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.21/24 ipv4.gateway 10.1.8.20 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# lvs
hostnamectl set-hostname lvs.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.10/24 ipv4.gateway 10.1.8.20 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# web1 / web2 / web3（同样配置网关为 10.1.8.20）
hostnamectl set-hostname web1.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.11/24 ipv4.gateway 10.1.8.20 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33

# router（双网卡）
hostnamectl set-hostname router.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.20/24 ipv4.gateway 10.1.8.2 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
nmcli connection add type ethernet con-name ens36 ifname ens36 ipv4.method manual ipv4.addresses 10.1.1.20/24 autoconnect yes
nmcli connection up ens36
```

### Router 开启 IP 转发

```bash
# 关键：router 必须开启 IP 转发
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
# 或 sed -i "s/ip_forward=0/ip_forward=1/g" /etc/sysctl.conf
sysctl -p
```

### Web 部署（同 NAT）

```bash
yum install -y nginx
echo Welcome to $(hostname) > /usr/share/nginx/html/index.html
systemctl enable nginx.service --now
```

---

## §34 LVS-DR 模式实战部署（三）：arp_ignore / arp_announce 内核参数详解

### 为什么需要这两个参数？

**DR 模式核心问题**：Director 和 RS 都有 VIP（10.1.8.100），如果 RS 响应 ARP 请求，请求就不会到 Director！

**解决思路**：让 RS **拒绝响应 VIP 的 ARP 请求**，让 Director 成为 VIP 的唯一 ARP 响应者。

### arp_ignore（ARP 请求忽略）

**作用**：控制主机收到 ARP 请求时，是否回复 ARP 响应。

| 值 | 行为 |
|----|------|
| **0**（默认） | 只要本机有该 IP（不论哪个网卡），就回复 ARP 响应 |
| **1** | 仅当 ARP 请求的目标 IP 与接收网卡上的**主 IP**完全匹配时才回复 |
| **2** | 仅当 ARP 请求的目标 IP 与接收网卡上的**任一 IP**（含 secondary）匹配时才回复 |
| **3** | 不回复任何 ARP 请求（除本地环回） |

**DR 模式设置 `arp_ignore = 1`**：
- 目标 IP（VIP=10.1.8.100）配置在 `lo`（dummy 接口）
- ARP 请求从 `eth0` 进入，`eth0` 主 IP 不是 VIP
- 值为 1 时，`eth0` 收到对 VIP 的 ARP 请求，**不回复**

### arp_announce（ARP 通告）

**作用**：控制主机发送 ARP 通告时，如何选择源 IP。

| 值 | 行为 |
|----|------|
| **0**（默认） | 允许使用任意本地 IP 作为 ARP 通告的源 IP |
| **1** | 尽量使用与目标 IP 同子网的本地 IP |
| **2**（推荐） | 严格选择与目标 IP 同子网的本地 IP，否则不发送 |

**DR 模式设置 `arp_announce = 2`**：
- 当 RS 主动发 ARP 时，源 IP **必须**和目标 IP 同子网
- 因为 `lo` 上的 VIP（10.1.8.100）和目标同子网，才发送
- 防止 RS 用错误接口的 IP 通告

### 配置命令

```bash
cat >> /etc/sysctl.conf << EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.dummy.arp_ignore = 1
net.ipv4.conf.dummy.arp_announce = 2
EOF
sysctl -p
```

### 典型场景

- **负载均衡**：防止 VIP 被错误的物理网卡 MAC 通告
- **多网卡服务器**：避免跨网卡 ARP 响应（"ARP 漂移"）

> 💡 **面试必考**：arp_ignore 和 arp_announce 的作用和取值！

---

## §35 LVS-DR 模式实战部署（四）：配置 LVS-DS（Director）

### Director 配置步骤

```bash
# 1. 配置虚拟网卡（dummy 接口绑定 VIP）
nmcli connection add type dummy ifname dummy con-name dummy ipv4.method manual ipv4.addresses 10.1.8.100/32
nmcli connection up dummy

# 2. 安装 ipvsadm
yum install -y ipvsadm
touch /etc/sysconfig/ipvsadm
systemctl enable ipvsadm --now

# 3. 创建负载均衡规则（DR 模式 -g）
ipvsadm -A -t 10.1.8.100:80 -s rr
ipvsadm -a -t 10.1.8.100:80 -r 10.1.8.11:80 -g
ipvsadm -a -t 10.1.8.100:80 -r 10.1.8.12:80 -g
ipvsadm -a -t 10.1.8.100:80 -r 10.1.8.13:80 -g

# 4. 保存
ipvsadm-save -n > /etc/sysconfig/ipvsadm

# 5. 验证
[root@lvs ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.1.8.100:80 rr
  -> 10.1.8.11:80                 Route   1      0          0
  -> 10.1.8.12:80                 Route   1      0          0
  -> 10.1.8.13:80                 Route   1      0          0
# Forward = Route 代表 DR 模式
```

注意 **Forward = Route**（不是 Masq）。

---

## §36 LVS-DR 模式实战部署（五）：配置 LVS-RS（Real Server） + 验证

### RS 配置（所有 web 执行）

```bash
# 1. 在 lo 接口上配置 VIP（dummy 子网掩码必须 32 位）
nmcli connection add type dummy ifname dummy con-name dummy ipv4.method manual ipv4.addresses 10.1.8.100/32
nmcli connection up dummy

# 2. 配置 ARP 参数（关键！让 RS 不响应 VIP 的 ARP）
cat >> /etc/sysctl.conf << EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.dummy.arp_ignore = 1
net.ipv4.conf.dummy.arp_announce = 2
EOF
sysctl -p
```

### 验证（client1 和 client2）

```bash
# client1（同 10.1.8.0/24 网段）
[root@client1 ~]# for i in {1..90};do curl -s 10.1.8.100 ;done|sort|uniq -c
     30 Welcome to web1.laogao.cloud
     30 Welcome to web2.laogao.cloud
     30 Welcome to web3.laogao.cloud

# client2（10.1.1.0/24 网段，经 router）
[root@client2 ~]# for i in {1..90};do curl -s 10.1.8.100 ;done|sort|uniq -c
     30 Welcome to web1.laogao.cloud
     30 Welcome to web2.laogao.cloud
     30 Welcome to web3.laogao.cloud
```

**两个网段的客户端都能访问**，DR 模式工作正常。

### DR 模式验证清单

- [ ] LVS 上 `ipvsadm -Ln` Forward 列为 **Route**
- [ ] RS 的 lo 接口有 VIP（`ip addr show dummy`）
- [ ] `sysctl -p` 加载了 arp 参数
- [ ] 从两个网段访问 VIP 都能轮询到 3 台 RS

---

## §37 LVS-DR 实战脚本封装：start/stop 标准化操作

### Real Server 脚本 `/etc/init.d/lvs-rs`

```bash
#!/bin/bash
# description : 配置 Real Server
. /etc/rc.d/init.d/functions
VIP=10.1.8.100

case "$1" in
  start)
    echo -n "Start LVS Real Server ... "
    
    # 设置 VIP（lo 接口）
    if nmcli connection | grep -q dummy; then
      nmcli connection modify dummy ipv4.method manual ipv4.addresses $VIP/32
    else
      nmcli connection add type dummy ifname dummy con-name dummy ipv4.method manual ipv4.addresses $VIP/32
    fi
    nmcli connection up dummy
    
    # 关闭 ARP
    echo "1" > /proc/sys/net/ipv4/conf/all/arp_ignore
    echo "2" > /proc/sys/net/ipv4/conf/all/arp_announce
    echo "1" > /proc/sys/net/ipv4/conf/dummy/arp_ignore
    echo "2" > /proc/sys/net/ipv4/conf/dummy/arp_announce
    
    echo OK
    ;;
  stop)
    echo -n "Stop LVS Real Server ... "
    
    # 关闭 VIP
    nmcli connection delete dummy
    
    # 启用 ARP
    echo "0" > /proc/sys/net/ipv4/conf/dummy/arp_ignore
    echo "0" > /proc/sys/net/ipv4/conf/dummy/arp_announce
    echo "0" > /proc/sys/net/ipv4/conf/all/arp_ignore
    echo "0" > /proc/sys/net/ipv4/conf/all/arp_announce
    
    echo OK
    ;;
  *)
    echo "Usage: $0 start|stop"
    exit 1
    ;;
esac
```

### Director 脚本 `/etc/init.d/lvs-dr`

```bash
#!/bin/bash
# description : 配置 Director Server
. /etc/rc.d/init.d/functions

# 安装 ipvsadm
if rpm -q ipvsadm &>/dev/null; then
  true
else
  yum install -y ipvsadm &>/dev/null
fi

VIP=10.1.8.100
PORT=80
rs1=10.1.8.11
rs2=10.1.8.12
rs3=10.1.8.13
interface=ens33
con_name=ens33
ipv=/sbin/ipvsadm

case "$1" in
  start)
    echo -n "Start LVS Director Server ... "
    
    # 设置 VIP
    if ip -br addr | grep -q $VIP; then
      true
    else
      nmcli connection modify ${con_name} +ipv4.addresses $VIP/32
      nmcli connection up ${con_name}
    fi
    
    # 设置 LB 规则
    $ipv -C
    $ipv -A -t $VIP:${PORT} -s wrr
    $ipv -a -t $VIP:${PORT} -r $rs1:${PORT} -g -w 1
    $ipv -a -t $VIP:${PORT} -r $rs2:${PORT} -g -w 1
    $ipv -a -t $VIP:${PORT} -r $rs3:${PORT} -g -w 1
    
    echo OK
    ;;
  stop)
    echo -n "Stop LVS Director Server ... "
    
    # 关闭 VIP
    if ip -br addr | grep -q $VIP; then
      nmcli connection modify ${con_name} -ipv4.addresses $VIP/32
      nmcli connection up ${con_name}
    fi
    
    # 关闭 LB
    $ipv -C
    
    echo OK
    ;;
  *)
    echo "Usage: $0 start|stop"
    exit 1
    ;;
esac
```

### 使用方法

```bash
chmod +x /etc/init.d/lvs-rs /etc/init.d/lvs-dr

# 在 RS 上
service lvs-rs start

# 在 DS 上
service lvs-dr start
```

> 💡 **生产实践**：用脚本封装，便于自动化部署和故障恢复。

---

## §38 LVS 性能调优：Director conn 表 + TCP 缓冲区 + 内核参数

### Director 端调优

```bash
# 1. IPVS 连接表大小（默认可能不够）
net.ipv4.ip_vs.conn_tab_bits = 22   # 支持 ~4M 并发连接

# 2. 哈希表
net.ipv4.ip_vs.conn_track_max = 524288

# 3. TCP 缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 4. TIME_WAIT 优化
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 180000

# 5. 连接跟踪表
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576
```

### RS 端调优

```bash
# 1. nginx 进程数
worker_processes auto;

# 2. 单进程连接数
events {
    worker_connections 65535;
}

# 3. 文件描述符
net.core.somaxconn = 65535
fs.file-max = 2097152

# 4. 端口范围
net.ipv4.ip_local_port_range = 1024 65535
```

### 监控命令

```bash
# 查看 IPVS 统计
ipvsadm -Ln --stats     # 累计统计
ipvsadm -Ln --rate      # 速率（每秒）

# 输出列：
#   Conns    当前连接
#   InPkts   入向包数
#   OutPkts  出向包数
#   InBytes  入向字节
#   OutBytes 出向字节

# 监控脚本（每秒输出）
watch -n1 'ipvsadm -Ln --stats'
```

---

## §39 LVS 与防火墙：Director iptables 放行 + RS 防火墙处理

### Director 防火墙配置

**NAT 模式**（依赖 netfilter）：
```bash
# 开启 IP 伪装
firewall-cmd --add-masquerade --permanent
firewall-cmd --add-masquerade
```

**DR 模式**（不依赖 nat）：
```bash
# 放行 VIP 端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# 或 firewalld
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --reload
```

### RS 防火墙配置

**NAT 模式**（RS 在内网）：放行 Director 网段
```bash
# 只允许 Director 网段访问
iptables -A INPUT -s 10.1.8.10 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j DROP
```

**DR 模式**（RS 直接回 Client）：放行所有
```bash
# 放行 80 端口
firewall-cmd --add-service=http --permanent
firewall-cmd --reload
```

### 常见坑

- ❌ NAT 模式 RS 上禁用了 80 端口 → 用户访问超时
- ❌ DR 模式 Director 上 iptables 误丢 VIP 80 包 → 全部失败
- ❌ RS 上 iptables INPUT 链 DROP → 主动外联失败

---

## §40 LVS 常见故障排查：Director 单点 / RS 不响应 / NAT 回程错

### 故障 1：Director 单点故障

**现象**：Director 挂了，整个集群不可用。

**解决**：
```
方案 A：Keepalived + LVS（双 Director 主备）
        → 详见 [[LinuxKeepalived]]
方案 B：LVS + LVS（双 Director 主主，互为备份）
方案 C：DNS 切换（手动 / 脚本，TTL 切换）
```

**生产首选**：方案 A。

### 故障 2：RS 不响应 ARP

**现象**：DR 模式下访问 VIP，请求到不了 Director，请求丢失。

**排查**：
```bash
# 1. 在 Client 上查看 VIP 的 ARP 是谁
arp -n | grep 10.1.8.100
# 期望：Director 的 MAC
# 异常：某 RS 的 MAC

# 2. 检查 RS 的 arp_ignore
sysctl net.ipv4.conf.all.arp_ignore
# 期望：1

# 3. 检查 RS 的 lo 接口 VIP 是否配置
ip addr show dummy
# 期望：inet 10.1.8.100/32
```

**解决**：修正 RS 的 arp 参数和 lo 配置。

### 故障 3：NAT 回程错

**现象**：NAT 模式下，RS 收到的请求回了，但 Client 收不到响应。

**排查**：
```bash
# 1. RS 的网关是否指向 Director
ip route | grep default
# 期望：default via 10.1.8.10

# 2. Director 是否开启 ip_forward
sysctl net.ipv4.ip_forward
# 期望：1

# 3. Director 的 iptables masquerade
iptables -t nat -L POSTROUTING
# 期望：有 MASQUERADE 规则
```

**解决**：补齐配置。

### 故障 4：调度算法权重无效

**现象**：设置了权重但请求没按比例分配。

**原因**：调度算法必须配合 -w 使用。**wrr 算法**才支持权重，**rr 算法**忽略权重。

**解决**：
```bash
# 改用 wrr
ipvsadm -E -t VIP:PORT -s wrr
```

### 故障 5：RS 上 nginx 启动但访问 502

**排查**：
```bash
# 1. 检查 nginx 是否真的监听
ss -tlnp | grep :80

# 2. 检查 SELinux（CentOS-7 默认开启）
getenforce
# 如是 Enforcing，可临时关 setenforce 0

# 3. 检查 nginx error log
tail /var/log/nginx/error.log
```

---

## §41 易错点 ×10：DR 模式 arp 配置 / NAT 网关 / TUN 公网 IP / 调度算法

### 易错点 1：DR 模式忘记配 arp 参数

**错误**：RS 不响应 ARP 但**主动发 ARP**，导致 Client 学到错误 MAC。

**正确**：
```bash
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.dummy.arp_ignore = 1
net.ipv4.conf.dummy.arp_announce = 2
```

### 易错点 2：NAT 模式 RS 网关没指 Director

**错误**：RS 直接回 Client，绕过 Director。

**正确**：
```bash
nmcli connection modify ens33 ipv4.gateway 10.1.8.10
```

### 易错点 3：TUN 模式用私网 IP

**错误**：TUN 要求 RIP/DIP/VIP **都是公网**。

**正确**：所有 IP 都用公网（或至少 RIP/DIP 公网，VIP 在公网可路由）。

### 易错点 4：rr 算法用 -w

**错误**：`ipvsadm -a ... -w 3` 但 `-s rr`，权重被忽略。

**正确**：rr 不支持权重，要加权必须 `-s wrr`。

### 易错点 5：Director 没用真实硬件

**错误**：生产用虚拟机当 Director，性能不够。

**正确**：Director 用物理机（或 SR-IOV 直通虚拟机）。

### 易错点 6：DR 模式 RS 的 lo 不配 VIP

**错误**：响应包用 eth0 的 RIP 作为源 IP，Client 收到非 VIP 响应，丢弃。

**正确**：lo 接口配 VIP（dummy 接口 + /32 掩码）。

### 易错点 7：忘记保存 ipvsadm 规则

**错误**：重启后所有规则丢失。

**正确**：
```bash
ipvsadm-save -n > /etc/sysconfig/ipvsadm
```

### 易错点 8：DR 模式跨网段部署

**错误**：DR 模式 LVS 和 RS 在不同二层网络（不同 VLAN 隔开）。

**正确**：DR 要求 LVS 和 RS 在**同一二层网络**。

### 易错点 9：NAT 模式 ip_forward=0

**错误**：Director 没开 IP 转发，请求进了 Director 但转发不出去。

**正确**：
```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### 易错点 10：防火墙阻碍 LVS 转发

**错误**：Director 防火墙默认 DROP，IPVS 工作但被防火墙丢弃。

**正确**：
```bash
# firewalld
firewall-cmd --set-default-zone=trusted

# 或 iptables
iptables -A FORWARD -j ACCEPT
```

---

## §42 速查表：ipvsadm 命令大全 + 4 种模式对比 + 调度算法选择

### ipvsadm 命令大全

| 功能 | 命令 |
|------|------|
| 添加集群 | `ipvsadm -A -t VIP:PORT -s <算法>` |
| 编辑集群 | `ipvsadm -E -t VIP:PORT -s <新算法>` |
| 删除集群 | `ipvsadm -D -t VIP:PORT` |
| 添加 RS | `ipvsadm -a -t VIP:PORT -r RIP:PORT -g\|-i\|-m [-w N]` |
| 编辑 RS | `ipvsadm -e -t VIP:PORT -r RIP:PORT -w N` |
| 删除 RS | `ipvsadm -d -t VIP:PORT -r RIP:PORT` |
| 查看规则 | `ipvsadm -L -n` |
| 查看统计 | `ipvsadm -L -n --stats` |
| 查看速率 | `ipvsadm -L -n --rate` |
| 看持久连接 | `ipvsadm -Lcn` |
| 清空规则 | `ipvsadm -C` |
| 清计数器 | `ipvsadm -Z` |
| 保存规则 | `ipvsadm-save -n > /etc/sysconfig/ipvsadm` |
| 重载规则 | `ipvsadm-restore < /etc/sysconfig/ipvsadm` |

### 工作模式速查

| 模式 | 标识 | 网络要求 | 性能 | 生产用 |
|------|------|---------|------|--------|
| NAT | `-m` | RIP 与 DIP 同网段 | 一般 | 5% |
| **DR** | `-g` | LVS 与 RS 同二层 | **最强** | **95%** |
| TUN | `-i` | 全部公网 | 强 | <1% |
| FULLNAT | 需编译 | 任意 | 较强 | 云厂商 |

### 调度算法速查

| 算法 | 类型 | 适用 |
|------|------|------|
| rr | 静态 | RS 同构 + 短连接 |
| wrr | 静态 | RS 异构 + 短连接 |
| lc | 动态 | RS 同构 + 长连接 |
| **wlc（默认）** | 动态 | **生产首选** |
| sed | 动态 | 特殊场景 |
| nq | 动态 | UDP / DNS |
| lblc | 动态 | Cache 集群 |
| lblcr | 动态 | 大型 Cache |
| dh | 静态 | Cache 命中 |
| sh | 静态 | 会话保持 |

### 关键路径速查

```
配置文件：/etc/sysconfig/ipvsadm
服务名：ipvsadm.service
模块：ip_vs, nf_conntrack
命令：ipvsadm, ipvsadm-save, ipvsadm-restore

日志：/var/log/messages（LVS 不单独记录）
```

---

## §43 面试 6 大追问：LVS vs Nginx / 工作模式原理 / 调度算法选择 / 持久连接

### 追问 1：LVS vs Nginx 怎么选？

**答**：
```
高并发 + 多协议 → LVS（4 层，性能碾压）
HTTP 7 层特性 → Nginx（缓存 / 改写 / 限流）
生产黄金组合 → LVS + Nginx（多层 LB）
```

### 追问 2：LVS 4 种工作模式的原理和区别？

**答**：见 [[#§11 4 种模式对比表]]。

核心：
- **NAT**：DNAT + SNAT，来回都过 DS
- **DR**：改 MAC，响应直回
- **TUN**：IP 隧道封装
- **FULLNAT**：双向 NAT，跨 VLAN

### 追问 3：DR 模式为什么性能最高？

**答**：
1. 响应不经过 DS，DS 压力小
2. 只改 MAC 不改 IP，开销极小
3. 内核态处理，无用户态切换
4. RS 直接回 Client（lo 接口发 VIP）

### 追问 4：DR 模式 RS 上为什么要配 lo VIP + arp_ignore？

**答**：
1. **lo VIP**：响应包的源 IP 必须是 VIP（Client 认 VIP）
2. **arp_ignore**：RS 收到 VIP 的 ARP 请求不响应
3. **arp_announce**：RS 主动发 ARP 时不包含 VIP
4. 目的：**保证只有 DS 响应 VIP 的 ARP**，避免 RS 抢流量

### 追问 5：怎么实现会话保持？

**答**：
```
方案 1：-s sh（源地址哈希）→ 同一客户端总是同一 RS
方案 2：-p 600（持久连接）→ 600 秒内同客户端同一 RS
方案 3：RS 上 Session 共享（Redis）→ 任意 RS 都能识别
```

### 追问 6：LVS 怎么保证高可用？

**答**：
```
方案 A：Keepalived + LVS（双 Director 主备）← 生产首选
方案 B：DNS 多 IP 轮询 + 健康检查脚本
方案 C：LVS 集群（OSPF + ECMP）← 大型互联网
```

详见 [[LinuxKeepalived]]。

### 追问 7：LVS 默认调度算法是什么？

**答**：**wlc**（加权最少连接）。

`ipvsadm -A -t VIP:PORT`（不指定 -s）默认 wlc。

### 追问 8：LVS 怎么监控后端 RS 健康？

**答**：
- 内置 IPVS 不直接做健康检查
- 配合 **Keepalived**（生产首选）
- 或配合 **ldirectord**

### 追问 9：FULLNAT 和 NAT 区别？

**答**：
- NAT：CIP 与 VIP 同网段，VIP 与 DIP 可不同网段
- FULLNAT：CIP、VIP、DIP、RIP 全都任意（双向 SNAT+DNAT）

---

## §44 跨模块链接

- [[LinuxKeepalived#lvs-dr-高可用]]：LVS + Keepalived 高可用方案
- [[LinuxNginx#upstream-负载均衡]]：Nginx 7 层负载均衡对比
- [[Linux网络#ip配置]]：nmcli / ip 命令基础
- [[Linux网络#路由转发]]：ip_forward 路由转发原理
- [[Linux网络#arp-协议]]：ARP 协议基础（理解 arp_ignore 前置）
- [[Linux防火墙#iptables-基础]]：iptables 在 LVS 中的应用
- [[Linux防火墙#firewalld]]：firewalld 配置 MASQUERADE
- [[Linux服务与SSH#systemd]]：systemd 服务管理
- [[Linux存储#dummy-接口]]：dummy 接口（lo 别名）配置
- [[LinuxDNS#dns-负载均衡]]：DNS 轮询（另一种 LB 方案）

---

## 完成度自检

- ✅ 38 节内容完整（覆盖原理 + 4 模式 + ipvsadm + 8 算法 + 实战）
- ✅ 2 个完整实战（NAT 模式 + DR 模式）
- ✅ DR 模式 arp_ignore/arp_announce 详细讲解
- ✅ 易错点 ×10
- ✅ 面试 6 大追问
- ✅ 速查表（命令 + 模式 + 算法）
- ✅ 跨模块链接