---
title: Linux Keepalived 高可用 + LVS-DR + MariaDB 主主
desc: VRRP 协议 + Keepalived 双机热备 + LVS-DR 高可用集群 + MariaDB 主主复制 + 故障切换
type: 笔记
module: LinuxKeepalived
pdf: Keepalived + LVS（DR） + MariaDB 主主.pdf
pdf_size: 0.6 MB
scope: Keepalived 高可用 + LVS 集成 + MariaDB 主主同步 + 故障切换
status: 完成
---

# Linux Keepalived 高可用 + LVS-DR + MariaDB 主主

> **范围**：基于《Keepalived + LVS（DR） + MariaDB 主主》项目教材整理。
> 覆盖 **VRRP 协议原理** + **Keepalived 双机热备** + **LVS-DR 高可用集群** + **MariaDB 主主复制** + **故障切换与脑裂处理**。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：Keepalived = 集群的心跳，主备节点间互发信号]]
- [[#§1 高可用 HA 是什么]]
- [[#§2 单点故障 SPOF]]
- [[#§3 Keepalived 是什么]]
- [[#§4 VRRP 协议]]
- [[#§5 VRRP 状态机]]
- [[#§6 VRRP 通告]]
- [[#§7 Keepalived 架构]]
- [[#§8 Keepalived 安装]]
- [[#§9 Keepalived 全局配置]]
- [[#§10 VRRP 实例配置]]
- [[#§11 虚拟 IP 配置]]
- [[#§12 抢占模式 vs 非抢占模式]]
- [[#§13 单播 vs 多播]]
- [[#§14 认证配置]]
- [[#§15 健康检查脚本]]
- [[#§16 通知脚本]]
- [[#§17 Keepalived 日志]]
- [[#§18 双机热备实战 1：基础 VRRP]]
- [[#§19 双机热备实战 2：非抢占模式]]
- [[#§20 双机热备实战 3：互为主备]]
- [[#§21 LVS-DR + Keepalived 高可用集群]]
- [[#§22 LVS-DR + Keepalived 完整配置]]
- [[#§23 virtual_server 配置详解]]
- [[#§24 real_server 配置]]
- [[#§25 TCP 健康检查]]
- [[#§26 HTTP_GET 健康检查]]
- [[#§27 MariaDB 主主复制]]
- [[#§28 MariaDB 主主复制配置]]
- [[#§29 MariaDB 主主复制实战]]
- [[#§30 LVS-DR + Keepalived + MariaDB 主主综合实战]]
- [[#§31 故障切换演练]]
- [[#§32 脑裂问题]]
- [[#§33 Keepalived 性能调优]]
- [[#§34 易错点 ×10]]
- [[#§35 速查表]]
- [[#§36 面试 6 大追问]]
- [[#§37 跨模块链接]]

---

## §0 心智模型：Keepalived = 集群的心跳，主备节点间互发信号

```
                      Client
                         │
                         │ 连接
                         ▼
        ┌────────────────────────────────┐
        │   Virtual IP (VIP)             │ ← 漂移的 IP，对外服务的"门面"
        │   10.1.8.100                    │
        └────────────────────────────────┘
                  ▲                ▲
        ┌─────────┴──────┐  ┌──────┴─────────┐
        │   ha1 (MASTER) │  │   ha2 (BACKUP)  │
        │   priority=110 │  │   priority=100  │
        │   VRRP 心跳 ───┼──┼──→ 通告包        │
        └────────┬───────┘  └────────┬───────┘
                 │                   │
                 ▼                   ▼
        ┌────────────────────────────────────┐
        │    Real Servers (RS 池)            │
        │   db1 (10.1.8.11)  db2 (10.1.8.12)│
        └────────────────────────────────────┘
```

**Keepalived = 集群的"心跳"**：
- **主备节点间互发 VRRP 通告包**（多播 224.0.0.18）
- **活着的优先级高的当 MASTER**，持有 VIP
- **MASTER 死了，BACKUP 接管 VIP**（1-3 秒内）
- **客户端无感知切换**（VIP 不变，服务不中断）

**三层职责**：
1. **VRRP 协议** → 实现 VIP 漂移（Keepalived 的核心）
2. **IPVS（ipvsadm）** → 实现四层负载均衡
3. **健康检查** → 实时检测 RS 存活，自动剔除故障节点

> 💡 **面试题**：Keepalived 和 Heartbeat 区别？
> 答：Keepalived 基于 VRRP（路由器冗余协议），配置简单、内置 LVS 支持；Heartbeat 是通用集群消息层，配置复杂。生产环境 Keepalived 主流。

---

## §1 高可用 HA 是什么

**HA（High Availability）= 高可用性**，指系统**长时间无故障运行**的能力。

### 可用性等级

| 等级         | 可用性      | 年故障时间        | 业务场景            |
| ---------- | -------- | ------------ | --------------- |
| 99%        | 两个 9     | 87.6 小时      | 内部测试系统          |
| 99.9%      | 三个 9     | 8.76 小时      | 普通业务系统          |
| **99.99%** | **四个 9** | **52.56 分钟** | **核心业务（订单/支付）** |
| 99.999%    | 五个 9     | 5.26 分钟      | 金融/电信级          |

### 关键指标

- **MTBF（Mean Time Between Failures）**：平均故障间隔时间，越长越好
- **MTTR（Mean Time To Repair）**：平均修复时间，越短越好
- **可用性 = MTBF / (MTBF + MTTR)**

```bash
# 示例：MTBF=8760 小时（一年），MTTR=1 小时
# 可用性 = 8760 / (8760 + 1) = 99.988%
```

> 💡 **HA 的核心目标**：**缩短 MTTR**（故障自动切换，秒级恢复）+ **延长 MTBF**（消除单点、冗余设计）。

---

## §2 单点故障 SPOF

**SPOF（Single Point of Failure）= 单点故障**，整个系统中**一旦该节点失效，整个系统瘫痪**的部分。

### 常见 SPOF

- **数据库服务器**：单机数据库 → 宕机 = 业务全停
- **负载均衡器**：单 LVS → 宕机 = 全量请求无法分发
- **电源 / 磁盘 / 网卡**：硬件故障 = 服务中断

### 解决方案：备份 + 冗余

| 方案           | 描述               | 优缺点           |
| ------------ | ---------------- | ------------- |
| **冷备**       | 备机平时关机，故障后手动启动   | 成本低、切换慢（分钟级）  |
| **温备**       | 备机开机但不开服务，监控主机状态 | 折中方案          |
| **热备（双机热备）** | 主备同时运行，自动切换      | **生产主流**，切换秒级 |
| **多活**       | 多节点同时提供服务        | 复杂度高、需分布式协调   |

**Keepalived = 热备方案**：主备两节点同时运行，通过 VRRP 协议选举 MASTER，MASTER 持有 VIP 提供服务。

---

## §3 Keepalived 是什么

**Keepalived** 是基于 **VRRP 协议**实现的高可用解决方案，主要功能：

1. **VRRP 协议实现** → VIP 漂移（核心）
2. **IPVS（ipvsadm）管理** → 四层负载均衡
3. **健康检查** → 自动剔除故障 RS
4. **通知机制** → 邮件/SMS 告警

### 双机热备原理

```
       ┌─────────────────────────────────┐
       │  VRRP 通告包（多播 224.0.0.18）│
       │  src=10.1.8.13, prio=110       │
       │  dst=224.0.0.18                │
       └─────────────────────────────────┘
              ▲                ▲
              │                │
   ┌──────────┴────┐    ┌──────┴────────┐
   │ ha1 MASTER    │    │ ha2 BACKUP    │
   │ priority=110  │    │ priority=100  │
   │ 持有 VIP      │    │ 等待接管       │
   └───────────────┘    └───────────────┘
```

- **初始状态**：ha1 优先级 110 > ha2 优先级 100 → ha1 当 MASTER
- **通告周期**：每秒发送一次 VRRP 通告
- **故障切换**：ha1 死亡 → ha2 收不到通告 → 3 秒后升级为 MASTER，接管 VIP

---

## §4 VRRP 协议

**VRRP（Virtual Router Redundancy Protocol）= 虚拟路由器冗余协议**，RFC 3768 定义。

### 核心概念

| 术语 | 含义 |
|------|------|
| **Virtual Router（VR）** | 虚拟路由器，由一组物理路由器组成，对外表现为一个逻辑路由器 |
| **Virtual IP（VIP）** | 虚拟 IP，对外服务的 IP 地址，绑定到 MASTER 节点 |
| **Virtual Router ID（VRID）** | 虚拟路由器标识，同一集群 VRID 必须一致 |
| **Priority** | 优先级（0-255），数值越大越优先，0 表示放弃 MASTER |
| **Master** | 当前持有 VIP 的节点 |
| **Backup** | 备份节点，监听 MASTER 通告 |
| **Advertisement** | VRRP 通告包，MASTER 周期性发送 |
| **Advert Interval** | 通告间隔，默认 1 秒 |

### VRRP 工作流程

1. **选举 MASTER**：优先级最高的成为 MASTER
2. **MASTER 持有 VIP**：对外提供服务的 IP
3. **MASTER 发送通告**：每秒发送一次 VRRP 通告包
4. **BACKUP 监听通告**：3 秒未收到通告（3×Advert Interval），接管 VIP
5. **故障切换**：新 MASTER 接管 VIP，对外服务继续

> 💡 **VRRP 的本质**：把多个物理路由器"伪装"成一个虚拟路由器，通过优先级选举 MASTER，MASTER 死亡时自动切换。

---

## §5 VRRP 状态机

VRRP 定义了 **3 种状态**：

```
                    ┌──────────────┐
                    │  Initialize  │ ← 初始状态，启动时进入
                    └──────┬───────┘
                           │ 配置加载完成
                           ▼
              ┌────────────────────────┐
              │       Backup           │ ← 备份状态
              │  监听 MASTER 通告       │
              └─────┬──────────┬───────┘
        收到通告且 │          │ 3 秒未收到通告
        优先级低  │          │ 或收到的通告优先级低
                  ▼          ▼
           保持 BACKUP    ┌─────────┐
                          │  Master │
                          │ 持有 VIP│
                          └────┬────┘
                               │ 发送通告 + 处理请求
                               ▼
                          保持 MASTER
```

### 状态详解

| 状态 | 含义 | 行为 |
|------|------|------|
| **Initialize** | 初始状态 | 进程启动时短暂存在，加载配置后进入 Backup |
| **Backup** | 备份状态 | 监听 MASTER 通告，不响应 ARP 请求，不转发流量 |
| **Master** | 主状态 | 持有 VIP，发送 VRRP 通告，处理转发流量 |

### 状态转换触发条件

- **Initialize → Backup**：配置加载完成
- **Backup → Master**：3 秒未收到更高优先级通告
- **Master → Backup**：收到更高优先级通告（抢占模式）
- **任意状态 → Initialize**：进程重启

---

## §6 VRRP 通告

**VRRP Advertisement（通告）** = MASTER 周期性发送的心跳包。

### 报文格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version| Type  | Virtual Rtr ID|   Priority    | Count IP Addrs|
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Auth Type   |   Adver Int  |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         IP Address(es)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Authentication Data (1)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Authentication Data (2)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 关键字段

- **Version**：协议版本，VRRPv2 = 2，VRRPv3 = 3
- **Type**：报文类型，1 = Advertisement
- **Virtual Rtr ID**：虚拟路由器 ID（0-255）
- **Priority**：优先级（0-255，0 = 放弃 MASTER，255 = 物理接口 IP）
- **Count IP Addrs**：包含的 VIP 数量
- **Adver Int**：通告间隔（秒）
- **IP Address(es)**：虚拟 IP 列表

### 通告机制

- **多播地址**：`224.0.0.18`（VRRP 专用组播地址）
- **TTL = 255**：仅在局域网内传播，不会跨路由器
- **通告间隔**：默认 1 秒（`advert_int 1`）
- **失效判定**：BACKUP 在 **3 × advert_int** 时间内未收到通告，认为 MASTER 死亡

```bash
# 抓包观察 VRRP 通告
tcpdump -i ens33 -nn vrrp
# 输出示例：
# 10:23:45.123 VRRPv2, Advertisement, vrid=51, prio=110, authtype=simple, intvl=1
```

---

## §7 Keepalived 架构

Keepalived 采用**多进程 + 内核模块**架构：

```
┌────────────────────────────────────────────────────────┐
│                    Keepalived 进程                       │
├────────────────┬──────────────────┬────────────────────┤
│  WatchDog      │  VRRP Stack      │  Checkers          │
│  (监控父进程)   │  (VRRP 协议)     │  (健康检查)         │
│                │                  │                    │
│  - 监控子进程   │  - MASTER/BACKUP │  - TCP_CHECK       │
│  - 故障重启    │  - 通告发送       │  - HTTP_GET        │
│                │  - 状态切换       │  - MISC_CHECK      │
└────────────────┴──────────────────┴────────────────────┘
                       │
                       │  调用 IPVS API
                       ▼
┌────────────────────────────────────────────────────────┐
│              Linux Kernel IPVS 模块                     │
│  - 四层负载均衡（DR/NAT/TUN/FullNAT）                   │
└────────────────────────────────────────────────────────┘
```

### 三大组件

| 组件 | 作用 |
|------|------|
| **WatchDog** | 监控 Keepalived 自身进程，异常时自动重启 |
| **VRRP Stack** | 实现 VRRP 协议，管理 VIP 漂移 |
| **Checkers** | 对 RS 做健康检查（TCP/HTTP/MISC），自动剔除故障节点 |

### 用户空间 + 内核空间

- **用户空间**：Keepalived 守护进程（VRRP/Checkers）
- **内核空间**：IPVS（IP Virtual Server）内核模块，负责实际的包转发

> 💡 **关键点**：Keepalived 不是包转发器，它只是管理 IPVS 规则。实际转发由内核 IPVS 完成。

---

## §8 Keepalived 安装

```bash
# CentOS-7 安装
yum install -y keepalived ipvsadm

# 验证安装
rpm -qa | grep -E "keepalived|ipvsadm"
# keepalived-1.3.5-19.el7.x86_64
# ipvsadm-1.27-7.el7.x86_64

# 查看版本
keepalived -v
# Keepalived v1.3.5 (19.el7_9.4)
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `/etc/keepalived/keepalived.conf` | 主配置文件 |
| `/etc/sysconfig/keepalived` | 启动参数（KEEPALIVED_OPTIONS） |
| `/usr/sbin/keepalived` | 守护进程二进制 |
| `/var/log/messages` | 默认日志位置（rsyslog 收集） |

### 服务管理

```bash
# 启动服务
systemctl start keepalived

# 开机自启
systemctl enable keepalived

# 重启服务（重读配置）
systemctl restart keepalived

# 查看状态
systemctl status keepalived
```

> 💡 **注意**：Keepalived 修改配置后需要 `systemctl reload keepalived`（v2.x 支持热加载）或 `restart`。

---

## §9 Keepalived 全局配置

### 配置文件结构

```bash
# 主配置文件
/etc/keepalived/keepalived.conf
```

### 完整结构

```nginx
! Configuration File for keepalived

# ============ 全局定义 ============
global_defs {
    notification_email {
        admin@example.com          # 故障通知邮箱
        ops@example.com
    }
    notification_email_from keepalived@example.com  # 发件人
    smtp_server 127.0.0.1          # SMTP 服务器
    smtp_connect_timeout 30        # SMTP 超时
    router_id ha1                  # 本机标识（集群内唯一）
    vrrp_skip_check_adv_addr       # 跳过通告地址检查
    vrrp_strict                    # 严格模式（未配 VIP 会报错）
    vrrp_garp_interval 0           # GARP 间隔
    vrrp_gna_interval 0            # GNA 间隔
}

# ============ VRRP 实例 ============
vrrp_script check_nginx {         # 自定义健康检查脚本
    script "/usr/bin/check_nginx.sh"
    interval 2
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state MASTER                  # 初始状态
    interface ens33               # 绑定的网卡
    virtual_router_id 51          # VRID（0-255）
    priority 110                  # 优先级
    advert_int 1                  # 通告间隔
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24             # VIP
    }
    track_script {
        check_nginx               # 引用健康检查
    }
    notify_master "/usr/local/bin/notify.sh master"
    notify_backup "/usr/local/bin/notify.sh backup"
    notify_fault "/usr/local/bin/notify.sh fault"
}

# ============ 虚拟服务器（LVS）============
virtual_server 10.1.8.100 80 {
    delay_loop 6                  # 健康检查间隔
    lb_algo rr                    # 负载均衡算法
    lb_kind DR                    # LVS 模式
    persistence_timeout 50        # 会话保持
    protocol TCP
    real_server 10.1.8.11 80 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
}
```

### global_defs 全局参数

| 参数 | 作用 | 示例 |
|------|------|------|
| `notification_email` | 故障通知邮箱 | `admin@example.com` |
| `notification_email_from` | 发件人 | `keepalived@ha.com` |
| `smtp_server` | SMTP 服务器 | `127.0.0.1` |
| `smtp_connect_timeout` | SMTP 连接超时 | `30` |
| `router_id` | 本机标识（集群内唯一） | `ha1` |
| `vrrp_strict` | 严格模式（强制配 VIP） | - |

---

## §10 VRRP 实例配置

**vrrp_instance** 是 Keepalived 的核心配置块，定义一个 VRRP 实例。

### 完整配置示例

```nginx
vrrp_instance VI_1 {
    state MASTER                # 初始状态：MASTER 或 BACKUP
    interface ens33             # 绑定网卡（VIP 将出现在该网卡上）
    virtual_router_id 51        # VRID（0-255，集群内必须一致）
    priority 110                # 优先级（1-254）
    advert_int 1                # 通告间隔（秒）
    
    authentication {
        auth_type PASS          # 认证类型：PASS（明文）或 AH
        auth_pass 1111          # 认证密码（1-8 字符）
    }
    
    virtual_ipaddress {
        10.1.8.100/24           # VIP 地址（可写多个）
        10.1.8.101/24 dev ens33 # 可指定 dev
    }
    
    track_script {              # 引用健康检查脚本
        check_nginx
    }
    
    # 抢占模式（默认开启）
    preempt_delay 5             # 抢占延迟（秒）
    
    # 单播配置（替代多播）
    unicast_src_ip 10.1.8.13
    unicast_peer {
        10.1.8.14
    }
    
    # 通知脚本
    notify_master "/usr/local/bin/notify.sh master"
    notify_backup "/usr/local/bin/notify.sh backup"
    notify_fault "/usr/local/bin/notify.sh fault"
}
```

### 关键参数

| 参数 | 必填 | 含义 |
|------|------|------|
| `state` | ✅ | 初始状态：MASTER / BACKUP |
| `interface` | ✅ | 绑定的物理网卡 |
| `virtual_router_id` | ✅ | VRID（0-255），同集群必须一致 |
| `priority` | ✅ | 优先级（1-254），MASTER 应高于 BACKUP |
| `advert_int` | ✅ | 通告间隔（秒），默认 1 |
| `virtual_ipaddress` | ✅ | VIP 列表 |
| `authentication` | ✅ | 认证配置 |
| `nopreempt` | ❌ | 非抢占模式（仅 BACKUP 配） |
| `preempt_delay` | ❌ | 抢占延迟 |

---

## §11 虚拟 IP 配置

**VIP（Virtual IP）= 虚拟 IP**，对外提供服务的 IP，绑定到 MASTER 节点。

### 配置方式

```nginx
virtual_ipaddress {
    # 方式 1：仅 IP
    10.1.8.100
    
    # 方式 2：IP + 子网掩码
    10.1.8.100/24
    
    # 方式 3：IP + dev + 标签
    10.1.8.100/24 dev ens33 label ens33:0
    
    # 方式 4：多个 VIP
    10.1.8.100/24
    10.1.8.101/24
}
```

### VIP 漂移原理

```
ha1 (MASTER):                ha2 (BACKUP):
ens33: 10.1.8.13 (实IP)      ens33: 10.1.8.14 (实IP)
ens33:0: 10.1.8.100 (VIP)    （无 VIP）

↓ ha1 宕机

ha1:                        ha2 (新 MASTER):
（离线）                      ens33: 10.1.8.14 (实IP)
                              ens33:0: 10.1.8.100 (VIP) ← VIP 漂移过来
```

### 验证 VIP 漂移

```bash
# 在 MASTER 上查看 VIP
ip addr show ens33
# 2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
#     inet 10.1.8.13/24 brd 10.1.8.255 scope global ens33
#     inet 10.1.8.100/24 scope global secondary ens33:0  ← VIP

# 在 BACKUP 上查看（不应有 VIP）
ip addr show ens33
# 2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
#     inet 10.1.8.14/24 brd 10.1.8.255 scope global ens33
#     （无 VIP）
```

---

## §12 抢占模式 vs 非抢占模式

### 抢占模式（默认）

**nopreempt 不设置时 = 抢占模式**。

```
时间线：
T0: ha1 MASTER (prio=110), ha2 BACKUP (prio=100)
T1: ha1 宕机 → ha2 升级为 MASTER (prio=100)
T2: ha1 恢复 → ha1 抢占为 MASTER (prio=110)
```

- 优先级高的节点恢复后，**自动抢回 MASTER 角色**
- 适用于：**性能不对等的节点**（高性能节点优先服务）

### 非抢占模式

```nginx
# BACKUP 节点配置
vrrp_instance VI_1 {
    state BACKUP
    priority 100
    nopreempt          # ← 关键：非抢占模式
}
```

```
时间线：
T0: ha1 MASTER (prio=110), ha2 BACKUP (prio=100, nopreempt)
T1: ha1 宕机 → ha2 升级为 MASTER (prio=100)
T2: ha1 恢复 → ha2 保持 MASTER，ha1 保持 BACKUP
T3: ha2 宕机 → ha1 才升级为 MASTER
```

- 优先级高的节点恢复后，**不抢回 MASTER**
- 适用于：**对等节点**（避免 VIP 抖动）

### 选择建议

| 场景 | 推荐模式 |
|------|---------|
| 主备节点性能不对等 | 抢占模式 |
| 主备节点性能对等 | 非抢占模式 |
| 业务对 VIP 切换敏感（如数据库主写） | 非抢占模式 |
| 业务对性能要求高（如主写优先） | 抢占模式 |

---

## §13 单播 vs 多播

### 多播模式（默认）

```nginx
# 默认配置（无需额外设置）
vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    # VRRP 通告通过多播 224.0.0.18 发送
}
```

- **优点**：配置简单，无需指定对端
- **缺点**：云环境（AWS/阿里云）通常禁用多播，导致 Keepalived 无法工作

### 单播模式（云环境必须）

```nginx
vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    
    # 单播配置
    unicast_src_ip 10.1.8.13    # 本机 IP（源地址）
    unicast_peer {
        10.1.8.14               # 对端 IP（目标地址）
    }
}
```

- **优点**：兼容云环境，安全性更高（不广播到整个网络）
- **缺点**：需要手动指定对端 IP，规模大时配置繁琐

### 抓包验证

```bash
# 多播抓包
tcpdump -i ens33 -nn vrrp
# 10:23:45.123 IP 10.1.8.13 > 224.0.0.18: VRRPv2, Advertisement, vrid 51, prio 110

# 单播抓包
tcpdump -i ens33 -nn host 10.1.8.13 and host 10.1.8.14
# 10:23:45.123 IP 10.1.8.13 > 10.1.8.14: VRRPv2, Advertisement, vrid 51, prio 110
```

---

## §14 认证配置

VRRP 支持两种认证方式：

### PASS 认证（简单密码）

```nginx
authentication {
    auth_type PASS      # 明文密码认证
    auth_pass 1111      # 1-8 字符密码
}
```

- **优点**：配置简单
- **缺点**：明文传输，安全性低
- **适用**：内网环境

### AH 认证（IP 认证头）

```nginx
authentication {
    auth_type AH        # IP 认证头（IP Authentication Header）
    auth_pass 1111
}
```

- **优点**：基于 IP 头的认证，安全性高
- **缺点**：Keepalived 对 AH 支持不完善，多数场景用 PASS

### 注意事项

- **同集群的 MASTER 和 BACKUP 必须使用相同的认证方式和密码**
- 否则 VRRP 通告会被丢弃，导致双 MASTER（脑裂）

---

## §15 健康检查脚本

**vrrp_script** 自定义健康检查脚本，可用于检测应用层健康状态。

### 配置示例

```nginx
vrrp_script check_nginx {
    script "/usr/bin/check_nginx.sh"  # 检查脚本
    interval 2                         # 检查间隔（秒）
    weight -20                         # 检查失败时优先级 -20
    fall 3                             # 连续 3 次失败才判定故障
    rise 2                             # 连续 2 次成功才判定恢复
    timeout 2                          # 脚本超时（秒）
    user root                          # 执行用户
}

vrrp_instance VI_1 {
    state MASTER
    priority 110
    track_script {
        check_nginx                   # 引用检查脚本
    }
}
```

### 健康检查脚本示例

```bash
#!/bin/bash
# /usr/bin/check_nginx.sh
# 检查 nginx 进程是否存活

if pgrep -x nginx > /dev/null; then
    exit 0    # 进程存活，返回 0（成功）
else
    exit 1    # 进程不存在，返回 1（失败）
fi
```

```bash
chmod +x /usr/bin/check_nginx.sh
```

### 工作原理

- **检查成功**（exit 0）→ 优先级 +weight（如 +20）
- **检查失败**（exit 1）→ 优先级 -weight（如 -20）
- **当优先级低于 BACKUP 节点** → 自动让出 MASTER 角色

```
ha1 (MASTER, prio=110)
  ↓ 检查脚本失败
  ↓ weight=-20
ha1 (新优先级=90) < ha2 (prio=100)
  ↓ 主动让出 MASTER
ha2 升级为 MASTER
```

---

## §16 通知脚本

Keepalived 在状态切换时调用通知脚本，可用于发送告警。

### 配置

```nginx
vrrp_instance VI_1 {
    state MASTER
    priority 110
    
    notify_master "/usr/local/bin/notify.sh master"   # 切换为 MASTER 时
    notify_backup "/usr/local/bin/notify.sh backup"   # 切换为 BACKUP 时
    notify_fault "/usr/local/bin/notify.sh fault"     # 故障时
}
```

### 通知脚本示例

```bash
#!/bin/bash
# /usr/local/bin/notify.sh
# Keepalived 状态切换通知脚本

VIP=10.1.8.100
CONTACT="admin@example.com"

case "$1" in
    master)
        SUBJECT="[INFO] $(hostname) 切换为 MASTER"
        BODY="时间：$(date '+%F %T')\n主机：$(hostname)\n事件：升级为 MASTER\nVIP：${VIP}"
        ;;
    backup)
        SUBJECT="[WARN] $(hostname) 切换为 BACKUP"
        BODY="时间：$(date '+%F %T')\n主机：$(hostname)\n事件：降级为 BACKUP\nVIP：${VIP}"
        ;;
    fault)
        SUBJECT="[ALARM] $(hostname) 故障"
        BODY="时间：$(date '+%F %T')\n主机：$(hostname)\n事件：故障状态\nVIP：${VIP}"
        ;;
esac

echo -e "$BODY" | mail -s "$SUBJECT" $CONTACT
```

```bash
chmod +x /usr/local/bin/notify.sh
```

> 💡 **生产建议**：通知脚本不要写得太复杂，避免脚本本身故障导致 Keepalived 状态异常。

---

## §17 Keepalived 日志

### 日志位置

- **默认**：`/var/log/messages`（rsyslog 收集）
- **CentOS-7**：通过 systemd journal 也可查看

### 查看日志

```bash
# 实时跟踪 Keepalived 日志
tail -f /var/log/messages | grep keepalived

# 查看启动日志
grep keepalived /var/log/messages | tail -50

# journalctl 方式
journalctl -u keepalived -f
journalctl -u keepalived --since "1 hour ago"
```

### 典型日志示例

```
# 启动
Keepalived_v1.3.5 (19.el7_9.4) starting...
Configuration file: /etc/keepalived/keepalived.conf

# 进入 BACKUP 状态
VRRP_Instance(VI_1) Transition to MASTER STATE
VRRP_Instance(VI_1) Entering MASTER STATE
VRRP_Instance(VI_1) setting protocol VIPs.
VRRP_Instance(VI_1) Sending gratuitous ARP on ens33 for 10.1.8.100

# 切换为 MASTER
VRRP_Instance(VI_1) Transition to MASTER STATE
VRRP_Instance(VI_1) Entering MASTER STATE

# 健康检查
TCP_CHECK [10.1.8.11]:3306 failed
TCP_CHECK [10.1.8.11]:3306 succeeded after 2 retries
```

### 日志级别调整

```bash
# 编辑 /etc/sysconfig/keepalived
KEEPALIVED_OPTIONS="-D -S 0"   # -D 详细日志，-S 0 发送到 syslog facility local0

# 配置 rsyslog
cat >> /etc/rsyslog.conf << EOF
local0.* /var/log/keepalived.log
EOF
systemctl restart rsyslog
```

---

## §18 双机热备实战 1：基础 VRRP

### 目标

实现两台机器（ha1、ha2）的 VIP 漂移，验证主备切换。

### 环境

| 主机 | IP | 角色 | 优先级 |
|------|----|----|--------|
| ha1 | 10.1.8.13 | MASTER | 110 |
| ha2 | 10.1.8.14 | BACKUP | 100 |
| VIP | 10.1.8.100 | - | - |

### 步骤

**1. 基础配置（两台）**

```bash
# 配置主机名和 IP
hostnamectl set-hostname ha1.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.13/24 \
  ipv4.gateway 10.1.8.20 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
```

**2. 安装 Keepalived（两台）**

```bash
yum install -y keepalived
```

**3. 配置 ha1 (MASTER)**

```bash
cp /etc/keepalived/keepalived.conf{,.bak}

cat > /etc/keepalived/keepalived.conf << 'EOF'
! Configuration File for keepalived

global_defs {
    router_id ha1
}

vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}
EOF

systemctl enable keepalived.service --now
```

**4. 配置 ha2 (BACKUP)**

```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
! Configuration File for keepalived

global_defs {
    router_id ha2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}
EOF

systemctl enable keepalived.service --now
```

**5. 验证**

```bash
# ha1 上查看 VIP
ip addr show ens33
# inet 10.1.8.100/24 scope global secondary ens33  ← VIP 存在

# ha2 上查看（不应有 VIP）
ip addr show ens33
# （无 10.1.8.100）

# 查看 VRRP 状态
ipvsadm -ln
# IP Virtual Server version 1.2.1 (size=4096)

# 抓包观察
tcpdump -i ens33 -nn vrrp
```

**6. 测试切换**

```bash
# 在 ha1 上停止 Keepalived
systemctl stop keepalived.service

# ha2 上查看（应接管 VIP）
ip addr show ens33
# inet 10.1.8.100/24 scope global secondary ens33  ← VIP 漂移到 ha2

# 启动 ha1 的 Keepalived（抢占模式下，ha1 会抢回 VIP）
systemctl start keepalived.service
```

> 💡 **关键点**：切换时间约 3 秒（3 × advert_int）。

---

## §19 双机热备实战 2：非抢占模式

### 目标

避免优先级高的节点恢复后抢回 VIP 导致服务抖动。

### 配置

**ha1 配置**：

```nginx
vrrp_instance VI_1 {
    state BACKUP           # ← 注意：非抢占模式下，初始高优先级也配 BACKUP
    interface ens33
    virtual_router_id 51
    priority 110
    nopreempt              # ← 关键：非抢占模式
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}
```

**ha2 配置**：

```nginx
vrrp_instance VI_1 {
    state BACKUP           # ← 也配 BACKUP
    interface ens33
    virtual_router_id 51
    priority 100
    nopreempt              # ← 关键：非抢占模式
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}
```

### 行为差异

| 时间 | 抢占模式 | 非抢占模式 |
|------|---------|----------|
| T0 | ha1 MASTER (110), ha2 BACKUP (100) | ha1 BACKUP (110), ha2 BACKUP (100) |
| T1 | ha1 宕机 → ha2 升级 MASTER (100) | ha1 宕机 → ha2 升级 MASTER (100) |
| T2 | ha1 恢复 → **抢占为 MASTER (110)** | ha1 恢复 → **保持 BACKUP (110)** |
| T3 | ha2 降为 BACKUP (100) | ha2 保持 MASTER (100) |

### 验证

```bash
# 测试场景：ha1 恢复后，VIP 不应该漂回 ha1
# 1. 停止 ha1 Keepalived
systemctl stop keepalived.service
# 2. ha2 接管 VIP（约 3 秒）
ip addr show ens33  # VIP 应在 ha2
# 3. 启动 ha1 Keepalived
systemctl start keepalived.service
# 4. 等待 5 秒后查看（VIP 应仍在 ha2）
ssh ha2 ip addr show ens33  # VIP 仍在 ha2
```

> 💡 **关键点**：非抢占模式下，**所有节点都配 `state BACKUP` + `nopreempt`**，仅靠优先级区分。

---

## §20 双机热备实战 3：互为主备

### 场景

两台机器互为对方的主备，分别提供不同的 VIP。

```
ha1: VI_1 MASTER (VIP=10.1.8.100)
ha2: VI_1 BACKUP, VI_2 MASTER (VIP=10.1.8.101)

ha1 宕机 → ha2 同时接管 VIP=10.1.8.100 + 保持 VIP=10.1.8.101
```

### 配置

**ha1 配置**：

```nginx
# VI_1：ha1 是 MASTER，提供 VIP=10.1.8.100
vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}

# VI_2：ha1 是 BACKUP，对应 ha2 的 VIP=10.1.8.101
vrrp_instance VI_2 {
    state BACKUP
    interface ens33
    virtual_router_id 52           # ← 不同的 VRID
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 2222
    }
    virtual_ipaddress {
        10.1.8.101/24
    }
}
```

**ha2 配置**：

```nginx
# VI_1：ha2 是 BACKUP，对应 ha1 的 VIP=10.1.8.100
vrrp_instance VI_1 {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}

# VI_2：ha2 是 MASTER，提供 VIP=10.1.8.101
vrrp_instance VI_2 {
    state MASTER
    interface ens33
    virtual_router_id 52
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 2222
    }
    virtual_ipaddress {
        10.1.8.101/24
    }
}
```

### 验证

```bash
# ha1 上
ip addr show ens33
# inet 10.1.8.100/24 scope global secondary ens33  ← VI_1 VIP
# （无 10.1.8.101）

# ha2 上
ip addr show ens33
# inet 10.1.8.101/24 scope global secondary ens33  ← VI_2 VIP
# （无 10.1.8.100）

# ha1 宕机
systemctl stop keepalived.service
# ha2 上
ip addr show ens33
# inet 10.1.8.100/24 ...   ← 接管 VI_1 VIP
# inet 10.1.8.101/24 ...   ← 保持 VI_2 VIP
```

> 💡 **适用场景**：双 VIP 互备（如同时提供 Web 服务 + 数据库代理 VIP）。

---

## §21 LVS-DR + Keepalived 高可用集群

### 架构

```
            Client
               │
               │ 请求 VIP:80
               ▼
       ┌──────────────┐
       │  VIP 10.1.8.100 │
       └──────────────┘
            ▲        ▲
   ┌────────┴───┐ ┌──┴────────┐
   │ ha1 MASTER │ │ ha2 BACKUP│
   │ LVS-DR     │ │ LVS-DR    │
   └─────┬──────┘ └─────┬─────┘
         │              │
   ┌─────┴──────────────┴─────┐
   │     Real Server 池        │
   │  db1 (10.1.8.11) + lo:VIP  │
   │  db2 (10.1.8.12) + lo:VIP  │
   └────────────────────────────┘
```

### LVS-DR 原理

**DR（Direct Routing）= 直接路由**模式：

1. **Client → LVS**：请求 VIP，LVS 接收
2. **LVS → RS**：LVS 修改目标 MAC（不改 IP），转发到 RS
3. **RS → Client**：RS 直接通过 lo 接口的 VIP 回包给客户端（绕过 LVS）

**关键点**：
- **请求经 LVS，响应不经 LVS**（性能高）
- **RS 必须配置 lo:VIP**（绑定 VIP 到本地环回）
- **RS 必须关闭 ARP 响应**（避免 VIP 冲突）

### RS 端配置（两台 DB 都要做）

```bash
# 1. 增加 dummy 网卡绑定 VIP
nmcli connection add type dummy ifname dummy con-name dummy \
  ipv4.method manual ipv4.addresses 10.1.8.100/32
nmcli connection up dummy

# 2. 配置 ARP 参数（防止 VIP 冲突）
cat >> /etc/sysctl.conf << EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.dummy.arp_ignore = 1
net.ipv4.conf.dummy.arp_announce = 2
EOF
sysctl -p
```

**ARP 参数解释**：

| 参数 | 值 | 含义 |
|------|-----|------|
| `arp_ignore` | 1 | 仅在请求的目标 IP 配置在请求进来的网卡上时才响应 ARP |
| `arp_announce` | 2 | 尽量使用最精确的网卡 IP 作为 ARP 源 |

---

## §22 LVS-DR + Keepalived 完整配置

### ha1 (MASTER) 配置

```nginx
! Configuration File for keepalived

global_defs {
    router_id ha1
}

vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass laogao@123
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}

virtual_server 10.1.8.100 3306 {
    delay_loop 6                  # 健康检查间隔
    lb_algo rr                    # 负载均衡算法：rr/wrr/lc/wlc/lblc
    lb_kind DR                    # LVS 模式：DR/NAT/TUN
    persistence_timeout 50        # 会话保持时间
    protocol TCP
    sorry_server 127.0.0.1 80     # 所有 RS 故障时的备用服务器

    real_server 10.1.8.11 3306 {
        weight 1
        inhibit_on_failure        # RS 故障时权重设为 0（而不是删除）
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
        notify_up "/usr/local/bin/rs_notify.sh up 10.1.8.11"
        notify_down "/usr/local/bin/rs_notify.sh down 10.1.8.11"
    }
    
    real_server 10.1.8.12 3306 {
        weight 2
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
}
```

### ha2 (BACKUP) 配置

```nginx
! Configuration File for keepalived

global_defs {
    router_id ha2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass laogao@123
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}

virtual_server 10.1.8.100 3306 {
    delay_loop 6
    lb_algo rr
    lb_kind DR
    protocol TCP
    
    real_server 10.1.8.11 3306 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
    
    real_server 10.1.8.12 3306 {
        weight 2
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
}
```

### 关键点

- **virtual_router_id 必须一致**（51）
- **virtual_ipaddress 必须一致**（10.1.8.100）
- **virtual_server 地址 = VIP + 端口**
- **real_server 必须用 IP 地址**（不支持域名，LVS 四层不解析域名）
- **auth_pass 必须一致**

---

## §23 virtual_server 配置详解

### 完整参数

```nginx
virtual_server <VIP> <port> {
    delay_loop <秒>              # 健康检查间隔
    lb_algo <算法>               # 负载均衡算法
    lb_kind <模式>               # LVS 转发模式
    persistence_timeout <秒>     # 会话保持
    persistence_granularity <netmask>  # 会话保持粒度
    protocol TCP|UDP|SCTP        # 协议
    virtualhost <string>         # HTTP 虚拟主机
    sorry_server <IP> <port>     # 所有 RS 故障时的备用服务器
    real_server <IP> <port> {
        weight <数字>
        inhibit_on_failure
        notify_up <path>
        notify_down <path>
        <健康检查方式>
    }
}
```

### 负载均衡算法

| 算法 | 全称 | 含义 |
|------|------|------|
| `rr` | Round Robin | 轮询（默认） |
| `wrr` | Weighted Round Robin | 加权轮询 |
| `lc` | Least Connection | 最少连接 |
| `wlc` | Weighted Least Connection | 加权最少连接（推荐） |
| `lblc` | Locality-Based LC | 基于局部性的最少连接 |
| `dh` | Destination Hashing | 目标地址哈希 |
| `sh` | Source Hashing | 源地址哈希 |
| `sed` | Shortest Expected Delay | 最短预期延迟 |
| `nq` | Never Queue | 永不排队 |

### LVS 转发模式

| 模式 | 全称 | 性能 | 特点 |
|------|------|------|------|
| **DR** | Direct Routing | **最高** | 响应直返 Client，RS 同网段 |
| **TUN** | Tunneling | 高 | IP 隧道，RS 跨网段 |
| **NAT** | Network Address Translation | 低 | 请求和响应都经 LVS |
| **FULLNAT** | Full NAT | 中 | 同时修改 SIP+DIP，跨 VLAN |

### 会话保持

```nginx
persistence_timeout 50  # 同一客户端 50 秒内请求发往同一 RS
```

- **作用**：解决 Session 一致性（如登录状态）
- **适用**：TCP 长连接（如数据库、SSH）
- **不适用**：HTTP 短连接（应使用 Cookie 或 Token）

---

## §24 real_server 配置

### 完整参数

```nginx
real_server <IP> <port> {
    weight <数字>            # 权重（0 表示不参与调度）
    inhibit_on_failure       # 故障时 weight=0（而非删除 RS）
    notify_up <path>         # RS 上线通知脚本
    notify_down <path>       # RS 下线通知脚本
    <健康检查方式>            # TCP_CHECK / HTTP_GET / SSL_GET / MISC_CHECK
}
```

### 权重 weight

- **数字越大，分配的请求越多**
- `weight 0` → 不参与调度（可手动下线）
- `inhibit_on_failure` → RS 故障时权重自动置 0（恢复时自动恢复权重）

### 通知脚本示例

```bash
#!/bin/bash
# /usr/local/bin/rs_notify.sh
# RS 上下线通知

ACTION=$1
RIP=$2

case "$ACTION" in
    up)
        echo "$(date '+%F %T') RS ${RIP} 上线" >> /var/log/lvs-rs.log
        ;;
    down)
        echo "$(date '+%F %T') RS ${RIP} 下线" >> /var/log/lvs-rs.log
        # 发邮件告警
        echo "RS ${RIP} 故障" | mail -s "[LVS] RS Down" admin@example.com
        ;;
esac
```

---

## §25 TCP 健康检查

**TCP_CHECK** = 检查 RS 的 TCP 端口是否可连接。

### 配置

```nginx
real_server 10.1.8.11 3306 {
    weight 1
    TCP_CHECK {
        connect_timeout 3        # 连接超时（秒）
        retry 3                  # 重试次数
        delay_before_retry 3     # 重试间隔（秒）
        connect_port 3306        # 检查的端口（默认 = real_server 端口）
        warmup 2                 # 启动后多久开始检查（秒）
    }
}
```

### 工作原理

```
1. Keepalived 每 delay_loop 秒尝试连接 RS:3306
2. 若连接超时（connect_timeout） → 失败计数 +1
3. 若失败次数 ≥ retry → 判定 RS 故障
4. 故障 RS 自动从 LVS 调度列表中剔除（weight=0）
5. 故障 RS 恢复后，自动重新加入调度
```

### 验证

```bash
# 查看 LVS 调度表
ipvsadm -ln
# TCP  10.1.8.100:3306 rr
#   -> 10.1.8.11:3306        Masq    1      0          0
#   -> 10.1.8.12:3306        Masq    1      0          0

# 查看连接统计
ipvsadm -ln --stats

# 模拟 RS 故障（在 db1 上停止 MariaDB）
systemctl stop mariadb

# 再次查看 LVS 调度表
ipvsadm -ln
#   -> 10.1.8.11:3306        Masq    1      0          0   ← 仍显示
#   -> 10.1.8.12:3306        Masq    1      0          0
# 但 weight 已变为 0（不调度）
```

> 💡 **TCP_CHECK 局限**：仅检查端口可达，不能检查服务是否真的健康（如 MySQL 进程存在但表损坏）。

---

## §26 HTTP_GET 健康检查

**HTTP_GET** = 发送 HTTP GET 请求，检查响应码和内容。

### 配置

```nginx
real_server 10.1.8.11 80 {
    weight 1
    HTTP_GET {
        url {
            path /health           # 检查的 URL 路径
            status_code 200        # 期望的状态码
            digest <md5>           # 可选：响应内容的 MD5 校验
        }
        connect_timeout 3
        retry 3
        delay_before_retry 3
        warmup 2
    }
}
```

### 工作原理

1. Keepalived 发送 `GET /health HTTP/1.0`
2. 若响应码匹配 `status_code` → 健康
3. 若配置 `digest`，校验响应内容 MD5
4. 失败重试 retry 次，每次间隔 delay_before_retry 秒

### 应用场景

- **HTTP Web 服务**：检查 HTTP 状态码（如 `/health` 返回 200）
- **API 健康检查**：检查特定接口响应
- **REST 服务**：验证服务可用性

### 高级配置

```nginx
real_server 10.1.8.11 80 {
    weight 1
    HTTP_GET {
        url {
            path /api/health
            status_code 200
            digest 5d41402abc4b2a76b9719d911017c592   # MD5 of "hello"
        }
        connect_port 80
        connect_timeout 3
        nb_get_retry 3
        delay_before_retry 3
    }
}
```

> 💡 **生成 MD5**：在 RS 上 `echo -n "hello" | md5sum`

---

## §27 MariaDB 主主复制

**MariaDB 主主复制（Master-Master Replication）** = 两台 MariaDB 互为主从，双向同步数据。

### 原理

```
db1 (Master)  ←→  db2 (Master)
  ↑                  ↑
  binlog →→→→→→→→→→→→→ relay log → SQL Thread
  ↑                                 ↑
  relay log ← SQL Thread ←←←←←←←←←← binlog
```

- **db1 → db2**：db1 当 Master，db2 当 Slave（db1 的变更同步到 db2）
- **db2 → db1**：db2 当 Master，db1 当 Slave（db2 的变更同步到 db1）
- **双向同步**：两边都可写，数据自动同步

### 主主复制的必要性

传统主从（一主一从）：
- **读可以扩展**（多个从库分担读）
- **写仍是瓶颈**（所有写集中到主库）

主主复制的优势：
- **写性能翻倍**（两台都可处理写请求）
- **真正的双活**（任一节点故障，另一节点立即接管）
- **无需手动切换**（故障自动恢复）

### 主主复制的风险

- **自增 ID 冲突**：两边都自增主键可能冲突
- **数据冲突**：两边同时修改同一行 → 后到的覆盖先到的
- **同步延迟**：网络问题导致数据不一致

---

## §28 MariaDB 主主复制配置

### 配置要点

| 参数 | db1 | db2 | 作用 |
|------|-----|-----|------|
| `server-id` | 1 | 2 | 节点唯一标识 |
| `log_bin` | mysql-bin | mysql-bin | 开启二进制日志 |
| `log_slave_updates` | ON | ON | 从库接收的更新也写入 binlog（主主必须） |
| `relay_log` | mysql-relay-bin | mysql-relay-bin | 中继日志 |
| `auto_increment_offset` | 1 | 2 | 自增起始值（错开） |
| `auto_increment_increment` | 2 | 2 | 自增步长（必须相同） |

### db1 配置 `/etc/my.cnf.d/server.cnf`

```ini
[mysqld]
server-id = 1
log_bin = mysql-bin
relay_log = mysql-relay-bin
log_slave_updates = ON

# 自增 ID 错开（避免冲突）
auto_increment_offset = 1       # db1 从 1 开始
auto_increment_increment = 2    # 每次 +2
```

### db2 配置 `/etc/my.cnf.d/server.cnf`

```ini
[mysqld]
server-id = 2
log_bin = mysql-bin
relay_log = mysql-relay-bin
log_slave_updates = ON

# 自增 ID 错开（避免冲突）
auto_increment_offset = 2       # db2 从 2 开始
auto_increment_increment = 2    # 每次 +2
```

### 自增 ID 错开原理

```
db1: 1, 3, 5, 7, 9, 11, ...
db2: 2, 4, 6, 8, 10, 12, ...

合并后（两边数据同步后）：
db1 看到: 1, 2, 3, 4, 5, 6, 7, ...
db2 看到: 1, 2, 3, 4, 5, 6, 7, ...
```

**避免冲突的关键**：
- `auto_increment_increment` 两边必须相同（如都 = 2）
- `auto_increment_offset` 两边必须不同（如 db1=1, db2=2）

---

## §29 MariaDB 主主复制实战

### 步骤 1：安装 MariaDB（两台）

```bash
yum install -y mariadb-server
```

### 步骤 2：配置 server.cnf（两台）

**db1**：

```ini
[mysqld]
server-id = 1
log_bin = mysql-bin
relay_log = mysql-relay-bin
log_slave_updates = ON
auto_increment_offset = 1
auto_increment_increment = 2
```

**db2**：

```ini
[mysqld]
server-id = 2
log_bin = mysql-bin
relay_log = mysql-relay-bin
log_slave_updates = ON
auto_increment_offset = 2
auto_increment_increment = 2
```

```bash
# 启动服务（两台）
systemctl enable mariadb.service --now

# 安全初始化（两台）
mysql_secure_installation
# 设置 root 密码（如 huawei）
# 移除匿名用户
# 禁止 root 远程登录
# 移除 test 数据库
# 重新加载权限表
```

### 步骤 3：db1 当 Master → db2 当 Slave

**db1 上授权同步账户**：

```bash
mysql -uroot -phuawei

# 创建复制用户
MariaDB [(none)]> grant replication slave, replication client on *.* 
    to 'repl'@'10.1.8.12' identified by 'huawei';
MariaDB [(none)]> flush privileges;

# 查看 Master 状态
MariaDB [(none)]> show master status\G;
*************************** 1. row ***************************
            File: mysql-bin.000003
        Position: 327
    Binlog_Do_DB:
Binlog_Ignore_DB: mysql,information_schema,performance_schema
```

**db2 上配置同步 db1**：

```bash
mysql -uroot -phuawei

# 配置同步 db1
MariaDB [(none)]> change master to 
    master_host='10.1.8.11',
    master_user='repl',
    master_password='huawei',
    master_port=3306,
    master_log_file='mysql-bin.000003',   # 与 db1 show master status 一致
    master_log_pos=327,                     # 与 db1 show master status 一致
    master_connect_retry=30;

# 启动同步
MariaDB [(none)]> start slave;

# 查看同步状态
MariaDB [(none)]> show slave status\G;
*************************** 1. row ***************************
            Slave_IO_State: Waiting for master to send event
              Master_Host: 10.1.8.11
            Slave_IO_Running: Yes           ← 必须为 Yes
           Slave_SQL_Running: Yes           ← 必须为 Yes
```

### 步骤 4：db2 当 Master → db1 当 Slave

**db2 上授权同步账户**：

```bash
mysql -uroot -phuawei

MariaDB [(none)]> grant replication slave, replication client on *.* 
    to 'repl'@'10.1.8.11' identified by 'huawei';
MariaDB [(none)]> flush privileges;

MariaDB [(none)]> show master status\G;
*************************** 1. row ***************************
            File: mysql-bin.000002
        Position: 1769
    Binlog_Do_DB:
Binlog_Ignore_DB: mysql,information_schema,performance_schema
```

**db1 上配置同步 db2**：

```bash
mysql -uroot -phuawei

MariaDB [(none)]> change master to 
    master_host='10.1.8.12',
    master_user='repl',
    master_password='huawei',
    master_port=3306,
    master_log_file='mysql-bin.000002',
    master_log_pos=1769,
    master_connect_retry=30;

MariaDB [(none)]> start slave;
MariaDB [(none)]> show slave status\G;
Slave_IO_Running: Yes           ← Yes
Slave_SQL_Running: Yes          ← Yes
```

### 步骤 5：验证双向同步

**db1 写入数据**：

```bash
mysql -uroot -phuawei
MariaDB [(none)]> create database test;
MariaDB [(none)]> use test;
MariaDB [test]> create table linux(
    username varchar(15) not null, 
    password varchar(15) not null
);
MariaDB [test]> insert into linux values ('laogao1', 'huawei');
MariaDB [test]> insert into linux values ('laogao2', 'huawei');
MariaDB [test]> insert into linux values ('laogao3', 'huawei');
MariaDB [test]> commit;
MariaDB [test]> select * from linux;
```

**db2 查看**：

```bash
mysql -uroot -phuawei
MariaDB [(none)]> select * from test.linux;
+----------+----------+
| username | password |
+----------+----------+
| laogao1  | huawei   |
| laogao2  | huawei   |
| laogao3  | huawei   |
+----------+----------+
```

**db2 写入数据 → db1 查看**：

```bash
# db2 上
MariaDB [(none)]> create database laogao;

# db1 上
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| laogao             |  ← 已同步
| mysql              |
| performance_schema |
| test               |
+--------------------+
```

---

## §30 LVS-DR + Keepalived + MariaDB 主主综合实战

### 完整架构

```
                    Client (10.1.8.21)
                           │
                           │ 连接 10.1.8.100:3306
                           ▼
              ┌────────────────────────┐
              │     VIP 10.1.8.100     │
              └────────────────────────┘
                    ▲              ▲
        ┌───────────┴─────┐  ┌─────┴────────────┐
        │   ha1 (MASTER)  │  │   ha2 (BACKUP)   │
        │   LVS-DR        │  │   LVS-DR         │
        │   priority=110  │  │   priority=100   │
        └─────────┬───────┘  └────────┬─────────┘
                  │ 健康检查            │
                  │                    │
        ┌─────────┴────────────────────┴─────────┐
        │   Real Server 池                         │
        │   db1 (10.1.8.11:3306) weight=1          │
        │   db2 (10.1.8.12:3306) weight=2          │
        │   主主双向同步                             │
        └────────────────────────────────────────┘
```

### 网络规划

| 主机 | IP | 角色 |
|------|----|----|
| client1 | 10.1.8.21 | 测试客户端 |
| ha1 | 10.1.8.13 | LVS+Keepalived MASTER |
| ha2 | 10.1.8.14 | LVS+Keepalived BACKUP |
| db1 | 10.1.8.11 | MariaDB Master + Slave |
| db2 | 10.1.8.12 | MariaDB Master + Slave |
| router | 10.1.8.20 | 路由器（开启 IP 转发） |
| **VIP** | **10.1.8.100** | **对外服务 IP** |

### 完整配置流程

**1. 主机名和 IP 配置（所有节点）**：

```bash
# router
hostnamectl set-hostname router.laogao.cloud
nmcli connection modify ens33 ipv4.method manual ipv4.addresses 10.1.8.20/24 \
  ipv4.gateway 10.1.8.2 ipv4.dns 223.5.5.5 autoconnect yes
nmcli connection up ens33
nmcli connection add type ethernet con-name ens36 ifname ens36 \
  ipv4.method manual ipv4.addresses 10.1.1.20/24 autoconnect yes
nmcli connection up ens36
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
firewall-cmd --set-default-zone=trusted
firewall-cmd --add-masquerade --permanent
firewall-cmd --add-masquerade
```

**2. MariaDB 主主复制**（参见 §29）

**3. LVS-RS 端配置（db1 和 db2 都要做）**：

```bash
# 绑定 VIP 到 dummy 接口
nmcli connection add type dummy ifname dummy con-name dummy \
  ipv4.method manual ipv4.addresses 10.1.8.100/32
nmcli connection up dummy

# 配置 ARP 参数
cat >> /etc/sysctl.conf << EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.dummy.arp_ignore = 1
net.ipv4.conf.dummy.arp_announce = 2
EOF
sysctl -p

# 安装 Keepalived（虽然只是 RS，也需要 ipvsadm）
yum install -y keepalived ipvsadm
```

**4. HA + LVS-DS 端配置（ha1）**：

参见 §22 的 ha1 配置。

**5. HA + LVS-DS 端配置（ha2）**：

参见 §22 的 ha2 配置。

**6. 测试**：

```bash
# 在 db1 上创建测试账户
mysql -uroot -phuawei
MariaDB [(none)]> grant ALL PRIVILEGES on *.* to 'laogao'@'%' identified by 'huawei';
MariaDB [(none)]> FLUSH PRIVILEGES;

# 客户端测试连接
mysql -u laogao -p -h 10.1.8.100 -e 'show databases'

# 测试故障切换
# 1. 停止 ha1 的 Keepalived
ssh ha1 systemctl stop keepalived.service
# 客户端应继续能连接（VIP 漂移到 ha2）

# 2. 启动 ha1 的 Keepalived
ssh ha1 systemctl start keepalived.service

# 3. 停止 db1 的 MariaDB
ssh db1 systemctl stop mariadb
# LVS 应自动剔除 db1，请求发往 db2

# 4. 启动 db1 的 MariaDB
ssh db1 systemctl start mariadb
# LVS 应自动恢复 db1
```

---

## §31 故障切换演练

### 演练 1：Keepalived 故障切换

```bash
# 1. 正常状态：ha1 MASTER，VIP 在 ha1
ssh ha1 ip addr show ens33 | grep 10.1.8.100
# inet 10.1.8.100/24 scope global secondary ens33

# 2. 停止 ha1 Keepalived
ssh ha1 systemctl stop keepalived.service

# 3. 3 秒后 VIP 漂移到 ha2
sleep 5
ssh ha2 ip addr show ens33 | grep 10.1.8.100
# inet 10.1.8.100/24 scope global secondary ens33

# 4. 客户端测试（应无中断）
mysql -u laogao -p -h 10.1.8.100 -e 'show databases'

# 5. 启动 ha1 Keepalived（抢占模式：ha1 抢回 VIP）
ssh ha1 systemctl start keepalived.service
sleep 5
ssh ha1 ip addr show ens33 | grep 10.1.8.100
# inet 10.1.8.100/24 scope global secondary ens33  ← VIP 回到 ha1
```

### 演练 2：RS 故障剔除

```bash
# 1. 正常状态：两台 RS 都参与调度
ipvsadm -ln
# TCP  10.1.8.100:3306 rr
#   -> 10.1.8.11:3306    Masq  1  0  0
#   -> 10.1.8.12:3306    Masq  1  0  0

# 2. 停止 db1 的 MariaDB
ssh db1 systemctl stop mariadb

# 3. 等待 delay_loop + retry × delay_before_retry = 6 + 3×3 = 15 秒
sleep 16

# 4. 查看 LVS（db1 已被剔除）
ipvsadm -ln
# TCP  10.1.8.100:3306 rr
#   -> 10.1.8.12:3306    Masq  1  0  0   ← 仅剩 db2

# 5. 客户端测试（仅连接 db2）
mysql -u laogao -p -h 10.1.8.100 -e 'show databases'

# 6. 启动 db1 的 MariaDB
ssh db1 systemctl start mariadb
sleep 16

# 7. 查看 LVS（db1 重新加入）
ipvsadm -ln
# TCP  10.1.8.100:3306 rr
#   -> 10.1.8.11:3306    Masq  1  0  0   ← db1 恢复
#   -> 10.1.8.12:3306    Masq  1  0  0
```

### 演练 3：MariaDB 同步中断恢复

```bash
# 1. 查看同步状态
mysql -uroot -phuawei -e "show slave status\G" | grep -E "Slave_IO|Slave_SQL"
# Slave_IO_Running: Yes
# Slave_SQL_Running: Yes

# 2. 模拟同步错误（误删同步账户）
mysql -uroot -phuawei -e "drop user 'repl'@'10.1.8.12';"

# 3. 同步失败
mysql -uroot -phuawei -e "show slave status\G" | grep -E "Slave_IO|Slave_SQL"
# Slave_IO_Running: Connecting
# Slave_SQL_Running: Yes

# 4. 修复：重新创建账户
mysql -uroot -phuawei -e "grant replication slave on *.* to 'repl'@'10.1.8.12' identified by 'huawei';"
mysql -uroot -phuawei -e "flush privileges;"

# 5. 重启同步
mysql -uroot -phuawei -e "stop slave; start slave;"
mysql -uroot -phuawei -e "show slave status\G" | grep -E "Slave_IO|Slave_SQL"
# Slave_IO_Running: Yes
# Slave_SQL_Running: Yes
```

---

## §32 脑裂问题

**脑裂（Split-Brain）= 双 MASTER 现象**，两个 Keepalived 节点都认为自己是 MASTER，导致 VIP 同时出现在两台机器上。

### 脑裂原因

| 原因 | 描述 |
|------|------|
| **心跳线中断** | 主备之间网络故障，无法通信 |
| **VRID 不一致** | 两边 VRID 不同，无法识别为同一集群 |
| **认证失败** | auth_pass 不一致，VRRP 通告被丢弃 |
| **防火墙阻断** | VRRP 多播（224.0.0.18）被防火墙拦截 |
| **网卡故障** | 主节点网卡故障但未完全宕机 |

### 脑裂的危害

```
Client 请求 VIP:3306
       │
       ├──→ ha1 (MASTER)  ← 处理请求
       │
       └──→ ha2 (MASTER)  ← 也处理请求

结果：
- 数据不一致（两边都写）
- IPVS 规则冲突
- 数据库主主同步冲突
- 客户端连接随机失败
```

### 解决方案

#### 方案 1：双 VIP 互为主备

参见 §20，互为主备避免单 VIP 脑裂。

#### 方案 2：仲裁 IP 脚本

```bash
#!/bin/bash
# /usr/bin/check_split_brain.sh
# 脑裂检测脚本

VIP=10.1.8.100
REMOTE_NODE=10.1.8.14

# 检查远程节点是否存活
if ping -c 3 -W 2 $REMOTE_NODE > /dev/null 2>&1; then
    # 远程节点存活
    # 检查 VIP 是否也在远程节点（通过 ARP 查询）
    if arping -c 3 -I ens33 $REMOTE_NODE | grep -q "$VIP"; then
        # 远程节点也持有 VIP，脑裂！
        echo "Split-Brain Detected! VIP ${VIP} 同时在本地和 ${REMOTE_NODE}"
        exit 1
    fi
fi

exit 0
```

#### 方案 3：抑制脚本

```bash
#!/bin/bash
# /usr/bin/keepalived_suppress.sh
# 脑裂时自动降级

VIP=10.1.8.100
SELF_IP=10.1.8.13
REMOTE_IP=10.1.8.14

# 检查远程节点是否也持有 VIP
REMOTE_HAS_VIP=$(arping -c 3 -I ens33 $REMOTE_IP | grep -c "$VIP")

if [ "$REMOTE_HAS_VIP" -gt 0 ]; then
    # 远程节点也持有 VIP，脑裂！
    # 本地降低优先级，主动降级为 BACKUP
    echo "Split-Brain! 本地降级"
    # 关闭本地的 Keepalived VIP
    ip addr del ${VIP}/24 dev ens33
    # 或者完全停止 Keepalived
    # systemctl stop keepalived.service
fi
```

#### 方案 4：硬件方案

- **双心跳线**：主备之间用两根独立网线
- **串口线**：通过串口心跳（最可靠）
- **仲裁服务器**：第三方节点判定

### 预防脑裂的配置要点

1. **virtual_router_id 必须一致**
2. **authentication 必须一致**（auth_type + auth_pass）
3. **advert_int 不要太大**（建议 1 秒，缩短检测时间）
4. **防火墙放行 VRRP 多播**：

```bash
# firewalld 放行 VRRP
firewall-cmd --add-protocol=vrrp --permanent
firewall-cmd --reload

# iptables 放行
iptables -I INPUT -p vrrp -j ACCEPT
iptables -I OUTPUT -p vrrp -j ACCEPT
```

---

## §33 Keepalived 性能调优

### 关键调优参数

```nginx
global_defs {
    vrrp_garp_master_repeat 5      # MASTER 状态时发送 GARP 的次数
    vrrp_garp_master_refresh 30    # MASTER 状态下定期重发 GARP 的间隔（秒）
    vrrp_lower_priority_diff_delay 60  # 抢占延迟（秒）
}
```

### 优化建议

| 优化项 | 建议值 | 说明 |
|--------|--------|------|
| `advert_int` | 1 | 通告间隔，1 秒是平衡点 |
| `vrrp_garp_master_repeat` | 3-5 | GARP 次数，太多会刷交换机 |
| `vrrp_garp_master_refresh` | 30-60 | GARP 重发间隔 |
| TCP_CHECK `connect_timeout` | 3 | 太短容易误判 |
| TCP_CHECK `retry` | 3 | 失败重试次数 |
| `delay_loop` | 6 | 健康检查间隔 |

### 大规模部署优化

```nginx
# 单实例多虚拟 IP
vrrp_instance VI_1 {
    virtual_ipaddress {
        10.1.8.100/24
        10.1.8.101/24
        10.1.8.102/24
    }
}

# 多实例（不同 VRID）
vrrp_instance VI_1 { virtual_router_id 51 ... }
vrrp_instance VI_2 { virtual_router_id 52 ... }
vrrp_instance VI_3 { virtual_router_id 53 ... }
```

---

## §34 易错点 ×10

### 1. virtual_router_id 不一致

```bash
# 错误：两边 VRID 不同
ha1: virtual_router_id 51
ha2: virtual_router_id 52

# 结果：两边都收不到对方的 VRRP 通告 → 都认为自己是 MASTER → 脑裂
```

**解决**：同集群所有节点 `virtual_router_id` 必须完全一致。

### 2. 优先级错配

```bash
# 错误：BACKUP 优先级高于 MASTER
ha1: state MASTER, priority 100
ha2: state BACKUP, priority 110

# 结果：启动时 BACKUP 抢占为 MASTER，但 ha1 仍写为 MASTER → 双 MASTER 脑裂
```

**解决**：`state MASTER` 的节点优先级必须最高。

### 3. 单播配置错（云环境）

```nginx
# 错误：未配置单播或多播 IP 错误
unicast_src_ip 10.1.8.13
unicast_peer {
    10.1.8.99    # ← 错误：不是对端真实 IP
}
```

**解决**：确认对端真实可达的 IP。

### 4. MariaDB 自增 ID 冲突

```ini
# 错误：两边自增配置相同
db1: auto_increment_offset = 1, auto_increment_increment = 2
db2: auto_increment_offset = 1, auto_increment_increment = 2  ← 错误

# 结果：两边都生成 ID=1, 3, 5, ... → 主键冲突
```

**解决**：offset 必须不同（db1=1, db2=2）。

### 5. TCP_CHECK 失败

```bash
# 错误：RS 端口不可达
TCP_CHECK {
    connect_timeout 1   # ← 太短
    retry 1             # ← 重试太少
}

# 结果：偶发网络抖动被判定为故障 → RS 被剔除
```

**解决**：`connect_timeout 3` + `retry 3` 是较稳妥的配置。

### 6. ARP 参数未配置

```bash
# 错误：RS 未配置 arp_ignore / arp_announce
# 结果：客户端请求 VIP 时，ARP 广播可能被 RS 抢答 → 连接失败
```

**解决**：RS 必须设置 `arp_ignore=1` + `arp_announce=2`。

### 7. VIP 未配置在 dummy 接口

```bash
# 错误：VIP 直接配在物理网卡
nmcli connection modify ens33 +ipv4.addresses 10.1.8.100/24

# 结果：物理网卡响应 ARP → 客户端无法确定 LVS 真实路径
```

**解决**：VIP 配置在 `dummy` 接口（或 lo:0 别名）。

### 8. log_slave_updates 漏配

```ini
# 错误：主主复制时漏配
[mysqld]
server-id = 1
log_bin = mysql-bin
# ← 漏配 log_slave_updates = ON

# 结果：从 db2 同步过来的更新不会写入 db1 的 binlog → db1 当 db2 的 Master 时无 binlog 可读
```

**解决**：主主复制**必须**配置 `log_slave_updates = ON`。

### 9. real_server 误用域名

```nginx
# 错误：real_server 用域名
real_server db1.example.com 3306 {
    weight 1
}

# 错误信息：invalid IP address for real_server
```

**解决**：real_server 必须用 IP 地址（LVS 四层不解析域名）。

### 10. firewall 阻断 VRRP

```bash
# 错误：firewalld 默认阻断 VRRP
# 现象：Keepalived 启动失败，VIP 无法漂移

# 解决：放行 VRRP
firewall-cmd --add-protocol=vrrp --permanent
firewall-cmd --reload
```

---

## §35 速查表

### Keepalived 命令

```bash
# 服务管理
systemctl start keepalived
systemctl stop keepalived
systemctl restart keepalived
systemctl status keepalived
systemctl enable keepalived

# 配置重载
systemctl reload keepalived   # v2.x 支持

# 日志
tail -f /var/log/messages | grep keepalived
journalctl -u keepalived -f

# 版本
keepalived -v

# 配置检查
keepalived -t -f /etc/keepalived/keepalived.conf
```

### IPVS 查看命令

```bash
# 查看调度表
ipvsadm -ln

# 查看连接
ipvsadm -lnc

# 查看统计
ipvsadm -ln --stats

# 查看速率
ipvsadm -ln --rate

# 清空规则
ipvsadm -C
```

### MariaDB 主主同步命令

```bash
# 查看 Master 状态
mysql -e "show master status\G"

# 查看 Slave 状态
mysql -e "show slave status\G"

# 配置同步
mysql -e "change master to master_host='IP', master_user='USER', master_password='PASS', master_log_file='FILE', master_log_pos=POS;"

# 启动同步
mysql -e "start slave;"

# 停止同步
mysql -e "stop slave;"

# 重新配置同步
mysql -e "reset slave;"
```

### 关键配置模板

**VRRP 基础模板**：

```nginx
global_defs {
    router_id ha1
}
vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.100/24
    }
}
```

**LVS-DR 模板**：

```nginx
virtual_server 10.1.8.100 3306 {
    delay_loop 6
    lb_algo wlc
    lb_kind DR
    persistence_timeout 50
    protocol TCP
    real_server 10.1.8.11 3306 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
}
```

### VIP 与优先级对照表

| 节点 | role | priority | state | VIP |
|------|------|----------|-------|-----|
| ha1 | LVS+Keepalived | 110 | MASTER | 10.1.8.100 |
| ha2 | LVS+Keepalived | 100 | BACKUP | 10.1.8.100 |
| db1 | MariaDB Master+Slave | - | - | 10.1.8.11 + lo:10.1.8.100 |
| db2 | MariaDB Master+Slave | - | - | 10.1.8.12 + lo:10.1.8.100 |

### 故障切换流程速查

```
故障 → 检测（3×advert_int）→ 切换 → 通知 → 恢复
                                      ↓
                              notify_master / backup / fault
```

| 切换类型 | 检测时间 | 切换时间 | 总耗时 |
|---------|---------|---------|--------|
| ha1 Keepalived 停止 | 3 秒 | <1 秒 | ~3-4 秒 |
| ha1 网络断开 | 3 秒 | <1 秒 | ~3-4 秒 |
| db1 MariaDB 停止 | delay_loop + retry × delay_before_retry | <1 秒 | ~15 秒 |
| MariaDB 同步中断 | 即时 | - | - |

---

## §36 面试 6 大追问

### 1. VRRP 协议是什么？工作原理？

**答**：VRRP（Virtual Router Redundancy Protocol）= 虚拟路由器冗余协议。

- **核心思想**：多个物理路由器组成一个虚拟路由器，对外提供单一 IP（VIP）
- **选举机制**：通过优先级（1-254）竞选 MASTER，优先级最高的成为 MASTER
- **心跳机制**：MASTER 周期性发送 VRRP 通告（多播 224.0.0.18）
- **故障切换**：BACKUP 在 3 × advert_int 时间内未收到通告 → 升级为 MASTER

### 2. 脑裂如何避免？

**答**：脑裂 = 双 MASTER 现象，多种方案组合使用：

1. **配置一致性**：virtual_router_id + auth_pass + VIP 三者必须严格一致
2. **双心跳线**：主备之间用两根独立网线
3. **仲裁 IP 脚本**：通过第三方节点判定主备状态
4. **抑制脚本**：检测到脑裂时主动降低优先级
5. **硬件方案**：串口心跳、共享存储仲裁

### 3. LVS + Keepalived 如何集成？

**答**：LVS 提供四层负载均衡，Keepalived 提供高可用：

- **Keepalived 管理 IPVS**：通过 `virtual_server` + `real_server` 配置
- **VRRP 提供 VIP 漂移**：MASTER 持有 VIP，BACKUP 备份
- **健康检查自动剔除**：TCP_CHECK/HTTP_GET 失败 → 自动从 IPVS 调度表中剔除
- **故障自动切换**：MASTER 宕机 → VIP 漂移到 BACKUP → 服务继续

### 4. MariaDB 主主复制如何解决自增 ID 冲突？

**答**：通过 `auto_increment_offset` + `auto_increment_increment` 错开：

```ini
# db1
auto_increment_offset = 1
auto_increment_increment = 2
# 生成的 ID：1, 3, 5, 7, ...

# db2
auto_increment_offset = 2
auto_increment_increment = 2
# 生成的 ID：2, 4, 6, 8, ...
```

两边 ID 不会冲突，同步合并后是连续的奇偶数。

### 5. Keepalived 健康检查方式有哪些？

**答**：4 种健康检查方式：

| 方式 | 适用 | 配置 |
|------|------|------|
| **TCP_CHECK** | TCP 端口检查（数据库、SSH） | `connect_port + connect_timeout` |
| **HTTP_GET** | HTTP 服务（Web、API） | `url { path + status_code }` |
| **SSL_GET** | HTTPS 服务 | 类似 HTTP_GET，使用 SSL |
| **MISC_CHECK** | 自定义脚本检查 | `misc_path + misc_timeout` |

### 6. LVS-DR 模式的优缺点？

**答**：

**优点**：
- **性能最高**：响应直接 RS → Client，不经 LVS
- **LVS 负载小**：LVS 只处理入站请求
- **RS 处理能力强**：适合高并发、大流量

**缺点**：
- **RS 必须同网段**：LVS 和 RS 必须在同一 VLAN
- **RS 需要配置 VIP**：绑定 VIP 到 lo 接口
- **RS 需要关闭 ARP**：配置 arp_ignore + arp_announce
- **不支持端口映射**：LVS 和 RS 端口必须一致

---

## §37 跨模块链接

- **LVS 基础**：`[[LinuxLVS#dr模式]]` — LVS-DR 工作原理详细说明
- **Nginx upstream**：`[[LinuxNginx#upstream]]` — 七层负载均衡 vs LVS 四层
- **Keepalived Web 实战**：`[[LinuxWeb实战#keepalived双机热备]]` — Web 服务双机热备案例
- **VRRP 防火墙放行**：`[[Linux防火墙#vrrp放行]]` — firewalld 放行 VRRP 协议
- **systemd 服务管理**：`[[Linux服务与SSH#systemd]]` — Keepalived 服务管理
- **日志查看**：`[[Linux日志与时间#journalctl]]` — journalctl 查看 Keepalived 日志
- **包管理**：`[[Linux包管理#yum安装]]` — yum 安装 keepalived / ipvsadm
- **网络基础**：`[[Linux网络#ip地址]]` — VIP 地址规划
- **MariaDB 配置**：`[[Linux网络#mariadb主主]]` — MariaDB 主主复制详解
- **SELinux 限制**：`[[LinuxSELinux#keepalived端口]]` — SELinux 对 VRRP 的影响

---

## 附录：环境变量速查

### 项目环境（PDF 教材）

| 主机 | IP | 角色 |
|------|----|----|
| client1.laogao.cloud | 10.1.8.21 (vmnet8) | 客户端 |
| client2.laogao.cloud | 10.1.1.21 (vmnet1) | 客户端 |
| ha1.laogao.cloud | 10.1.8.13 (vmnet8) | LVS+Keepalived MASTER |
| ha2.laogao.cloud | 10.1.8.14 (vmnet8) | LVS+Keepalived BACKUP |
| db1.laogao.cloud | 10.1.8.11 (vmnet8) | MariaDB Master+Slave |
| db2.laogao.cloud | 10.1.8.12 (vmnet8) | MariaDB Master+Slave |
| router.laogao.cloud | 10.1.8.20 (vmnet8) / 10.1.1.20 (vmnet1) | 路由器 |
| **VIP** | **10.1.8.100** | **对外服务 IP** |

### 关键密码

- MariaDB root 密码：`huawei`
- MariaDB repl 同步用户：`repl` / `huawei`
- MariaDB laogao 测试用户：`laogao` / `huawei`
- Keepalived auth_pass：`laogao@123` 或 `1111`

---

## 附录：项目价值与预期目标

通过部署《Keepalived + LVS（DR） + MariaDB 主主》架构，预期实现以下技术与业务价值：

1. **高可用升级**：数据库层可用性从 99.9% 提升至 99.99%，年均故障中断时间从 8.76 小时降至 52.56 分钟，核心业务（订单、支付）无服务中断风险
2. **性能翻倍**：写性能从单主 500 TPS 提升至双主 1000+ TPS，读性能支持通过新增从节点无限扩展（LVS 统一分发读请求），95% SQL 查询响应时间 < 200ms
3. **数据可靠**：双主实时同步数据，任一节点故障无数据丢失；LVS 健康检查 + Keepalived 主备切换，实现"故障自动转移"，无需人工干预
4. **运维高效**：新增数据库节点时，仅需接入 LVS 集群，无需修改业务代码；负载均衡与数据库节点状态可通过监控平台实时查看，故障定位效率提升 70%

---

> **本文档基于《Keepalived + LVS（DR） + MariaDB 主主.pdf》整理，覆盖 VRRP 协议 + Keepalived 双机热备 + LVS-DR 高可用集群 + MariaDB 主主复制完整链路。**