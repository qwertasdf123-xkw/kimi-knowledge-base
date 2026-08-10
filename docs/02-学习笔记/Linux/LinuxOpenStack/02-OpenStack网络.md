---
title: OpenStack 网络：Neutron / ML2 / OVS / OVN 三层架构与浮动 IP
desc: 以《OpenStack管理》PDF Neutron 章节 + openstack-deploy-dual/NETWORK-ARCHITECTURE.md (355 行) + KEY-CODE-EXAMPLES.md (§1, 130 行) 为核心素材，把 Neutron 三层架构（ML2 plugin + OVS agent + OVN chassis）、Provider/Tenant Network、浮动 IP 完整通信流程、br-ex 桥接机制、冷启动恢复等深度主题串成可复盘的实战笔记。
type: 笔记
module: LinuxOpenStack
pdf: OpenStack管理.pdf Neutron 章节 + openstack-deploy-dual/NETWORK-ARCHITECTURE.md + KEY-CODE-EXAMPLES.md §1
pdf_size: PDF ~50 页 Neutron 章节 + 355 行 NETWORK-ARCHITECTURE + 130 行 KEY-CODE §1
scope: Neutron 三层架构 + ML2 plugin + OVS/OVN 机制 + Provider/Tenant Network + 浮动 IP 流程 + br-ex 实战 + 冷启动恢复 + 调试命令 + 故障排查
status: 进行中
---

# OpenStack 网络：Neutron / ML2 / OVS / OVN

> **一句话心智模型**：Neutron 是 OpenStack 的网络服务，核心架构是"三层"——**ML2 plugin**（决定网络类型 driver）+ **Mechanism driver**（决定底层实现，如 OVS/OVN/Linux bridge）+ **Agent**（每个节点上跑，把网络配置落到具体网卡/网桥）。所有 VM 的网络通信最终都经过 OVS 桥（br-int / br-tun / br-ex）和 OVN logical switch/router 转发。
>
> **本章范围**：Neutron 三层架构 + ML2 详解 + OVS/OVN 机制 + Provider/Tenant Network + 浮动 IP 完整通信流程 + br-ex IP 迁移实战 + 冷启动恢复 + 调试命令 + 故障分类。其他服务见 [[01]] [[03]] [[04]]。

## 目录

- [[#§0 心智模型：Neutron 是 OpenStack 的"网络控制平面"]]
- [[#§1 Neutron 三层架构总览]]
- [[#§2 Neutron 服务进程]]
- [[#§3 ML2 Plugin 详解]]
- [[#§4 OVS Mechanism Driver]]
- [[#§5 OVN 架构（取代 OVS 的下一代方案）]]
- [[#§6 Provider Network vs Tenant Network]]
- [[#§7 浮动 IP（Floating IP）完整通信流程]]
- [[#§8 br-ex 桥接机制与 IP 迁移]]
- [[#§9 冷启动自动恢复机制]]
- [[#§10 DVR 分布式虚拟路由器]]
- [[#§11 安全组（Security Group）]]
- [[#§12 网络命名空间（Network Namespace）]]
- [[#§13 Neutron 命令速查]]
- [[#§14 关键调试命令]]
- [[#§15 常见网络问题与诊断]]
- [[#§16 与已有 vault 模块的链接]]

---

## §0 心智模型：Neutron 是 OpenStack 的"网络控制平面"

### 0.1 Neutron 管的资源

| 资源 | 说明 |
|------|------|
| **network** | 虚拟网络（对应一个 OVS bridge + OVN logical switch） |
| **subnet** | 子网（IP 段 + 网关 + DNS） |
| **router** | 路由器（连接 subnet 与外部） |
| **port** | 端口（VM 网卡对应一个 port） |
| **security group** | 安全组（VM 网卡的防火墙规则） |
| **floating IP** | 浮动 IP（公网可访问的 IP） |
| **router gateway** | 路由器外部网关（连 Provider Network） |
| **qos policy** | QoS 策略（带宽限制） |

### 0.2 Neutron 与其他服务的关系

```mermaid
graph LR
  N[Nova 创建 VM] -->|配网卡/安全组| NE[Neutron]
  NE -->|网络拓扑| DB[(neutron DB)]
  NE -->|RPC 指令| AGENT[OVS Agent / OVN Controller]
  AGENT -->|配置 OVS 流表| BR[br-int / br-tun / br-ex]
  VM[VM 网卡 tap] --> BR
  BR -->|VXLAN/GRE 隧道| TUN[跨节点隧道]
  BR -->|通过 NIC 出去| PHY[物理网卡]
```

### 0.3 Neutron 不管的

- **物理交换机/VLAN**：那是 [[华为VRP]] / Linux bridge 的事（Neutron 通过 Provider Network 借用）
- **DNS**：那是 Designate 服务（独立组件，OpenStack 可选）
- **负载均衡**：那是 Octavia / Neutron LBaaS
- **VPN**：那是 Neutron VPNaaS（可选）

---

## §1 Neutron 三层架构总览

Neutron 的核心设计是"**三层分离**"，让每层都可替换：

```mermaid
graph TB
  subgraph L1["L1: ML2 Plugin (Type Driver)"]
    V[xlan]
    V2[vlan]
    V3[flat]
    V4[gre]
    V5[geneve]
  end

  subgraph L2["L2: Mechanism Driver"]
    O[OVS]
    O2[OVN]
    LB[Linux Bridge]
    SR[SR-IOV]
  end

  subgraph L3["L3: Agent"]
    OA[OVS Agent<br/>ovs-vswitchd]
    OC[OVN Controller<br/>ovn-controller]
    LA[Linux Bridge Agent]
    SRIOV[SR-IOV Agent]
  end

  L1 --> L2
  L2 --> L3
  L3 --> BR[OVS / Linux 网桥]
```

**每层职责**：

1. **L1 ML2 Type Driver**：决定"网络类型"是什么（VXLAN/VLAN/Flat/GRE）
2. **L2 Mechanism Driver**：决定"用什么技术实现"（OVS/OVN/Linux Bridge/SR-IOV）
3. **L3 Agent**：在每个节点上跑，把网络配置落到网桥

**好处**：可以单独升级任何一层。比如从 OVS agent 升级到 OVN controller，只需换 L2+L3，ML2 配置不变。

---

## §2 Neutron 服务进程

| 进程 | 职责 | 默认端口 | 部署位置 |
|------|------|----------|----------|
| **neutron-server** | REST API + 调度 Agent | 9696 | 控制节点 |
| **neutron-dhcp-agent** | 给 VM 分配 IP（DHCP） | 67 (DHCP) | 网络节点 |
| **neutron-l3-agent** | 路由器 + NAT + 浮动 IP | — | 网络节点 |
| **neutron-metadata-agent** | 给 VM 提供 metadata（cloud-init） | 80 | 网络节点 |
| **neutron-openvswitch-agent** | 把网络配置落到 OVS 桥 | — | 计算节点 + 网络节点 |
| **neutron-ovn-metadata-agent** | OVN 环境下的 metadata | — | 计算节点 + 网络节点 |
| **neutron-bgp-dragent** | BGP 路由（高级） | — | 网络节点（可选） |

### 2.1 控制节点 vs 网络节点

- **OpenStack 早期**：L3 agent + DHCP agent 跑在"网络节点"（专门一台）
- **OpenStack 现代**：DVR（分布式虚拟路由器）+ OVN 让 compute 节点自己处理 L3，不再需要专门的网络节点
- **kolla-ansible 默认**：control + compute 分离，network 角色可选

### 2.2 配置文件

```ini
# /etc/neutron/neutron.conf
[DEFAULT]
core_plugin = ml2
service_plugins = router,firewall,qos
auth_strategy = keystone
transport_url = rabbit://openstack:password@controller:5672

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
```

```ini
# /etc/neutron/plugins/ml2/ml2_conf.ini
[ml2]
type_drivers = flat,vlan,vxlan,gre,geneve
tenant_network_types = vxlan
mechanism_drivers = openvswitch,ovn
extension_drivers = port_security,qos

[ml2_type_flat]
flat_networks = physnet0,physnet1

[ml2_type_vlan]
network_vlan_ranges = physnet0:100:200,physnet1:300:400

[ml2_type_vxlan]
vni_ranges = 1:1000

[ovn]
ovn_nb_connection = tcp:192.168.56.10:6641
ovn_sb_connection = tcp:192.168.56.10:6642
```

---

## §3 ML2 Plugin 详解

### 3.1 ML2 是什么

**ML2 = Modular Layer 2**。它是 Neutron 的"主脑"，统一管理 L2 网络。

ML2 不直接处理网络，它：
- 维护 network/subnet/port 的元数据（DB）
- 根据 Type Driver 验证网络参数
- 通过 Mechanism Driver 把网络配置下发到 Agent

### 3.2 Type Driver 类型

| 类型 | 用途 | 隔离方式 | 适用场景 |
|------|------|----------|----------|
| **flat** | 1 个物理网卡 = 1 个网络 | 无隔离 | 简单场景 |
| **vlan** | 802.1Q VLAN ID 隔离 | VLAN tag | 企业网络（最多 4094 个） |
| **gre** | Generic Routing Encapsulation 隧道 | GRE key | 老 OpenStack（已被 VXLAN 取代） |
| **vxlan** | Virtual Extensible LAN 隧道 | VNI（24-bit） | 现代数据中心（默认） |
| **geneve** | Generic Network Virtualization Encapsulation | 24-bit VNI | 新一代（K8s CNI 也用） |

### 3.3 VXLAN vs VLAN

| 维度 | VXLAN | VLAN |
|------|-------|------|
| 隔离数量 | 16M（24-bit VNI） | 4094（12-bit VID） |
| 跨三层 | 支持（IP 隧道） | 不支持（同一 L2 域） |
| 配置复杂度 | 中（需要 VTEP） | 低（直接 trunk） |
| 性能 | 略低（封包解包） | 高（硬件 offload） |
| 适用 | 大规模云 | 企业内网 |

**生产推荐**：VXLAN（默认）。如果已有 VLAN 基础设施，用 VLAN。

### 3.4 Mechanism Driver 选择

| Driver | 时代 | 特性 | 推荐 |
|--------|------|------|------|
| **Open vSwitch (OVS)** | 老 | 经典稳定，agent 模式 | 中小规模 |
| **OVN (Open Virtual Network)** | 新 | 集中控制面，性能更好 | **生产推荐** |
| **Linux Bridge** | 旧 | 简单但功能弱 | 测试 |
| **SR-IOV** | 高级 | 直接 PCI 透传，绕过 OVS | 高性能场景 |

**OVN vs OVS agent 的本质区别**：

```mermaid
graph LR
  subgraph OVS["传统 OVS Agent 模式"]
    API1[neutron-server] -->|RPC| AGENT1[ovs-agent 每节点]
    AGENT1 --> BR1[br-int / br-tun / br-ex]
  end

  subgraph OVN["OVN 模式"]
    API2[neutron-server] --> NBG[OVN NB]
    NBG --> SBG[OVN SB]
    SBG -->|同步 logical flows| OC[ovn-controller 每节点]
    OC --> BR2[OVS 桥]
  end
```

- **OVS agent**：每个节点独立处理 RPC，性能瓶颈在 controller
- **OVN**：集中控制（NB/SB 数据库）+ 节点拉取，性能更好

---

## §4 OVS Mechanism Driver

### 4.1 OVS 是什么

**OVS = Open vSwitch**。一个高性能的虚拟交换机（运行在 Linux 内核态 + 用户态）。

```mermaid
graph TB
  subgraph Node["Compute / Network 节点"]
    VM1[VM 网卡 tap0]
    VM2[VM 网卡 tap1]
    BR_INT[br-int<br/>integration bridge<br/>VM 之间互通]
    BR_TUN[br-tun<br/>tunnel bridge<br/>跨节点 VXLAN]
    BR_EX[br-ex<br/>external bridge<br/>外部网络]
    PHY[物理网卡 ens256]
  end

  VM1 --> BR_INT
  VM2 --> BR_INT
  BR_INT -->|VXLAN/GRE| BR_TUN
  BR_INT --> BR_EX
  BR_EX --> PHY
```

### 4.2 三个桥的作用

| 桥名 | 作用 | 连接 |
|------|------|------|
| **br-int** | Integration bridge，所有 VM 网卡接到这里 | VM tap ports |
| **br-tun** | Tunnel bridge，跨节点 VXLAN 隧道 | patch-int ↔ patch-tun |
| **br-ex** | External bridge，连物理网卡到外部网络 | patch-int ↔ 物理 NIC |

### 4.3 patch port

三个桥之间通过 `patch` port 连接（性能比 veth 高）：

```bash
# patch-int 在 br-int，patch-tun 在 br-tun
ovs-vsctl add-port br-int patch-int
ovs-vsctl set interface patch-int type=patch options:peer=patch-tun
ovs-vsctl add-port br-tun patch-tun
ovs-vsctl set interface patch-tun type=patch options:peer=patch-int
```

### 4.4 流表示例

```bash
# 看 br-int 的流表
ovs-ofctl dump-flows br-int

# 输出示例
cookie=0x0, duration=1234s, table=0, n_packets=100, n_bytes=8000,
  priority=1, in_port=1 actions=resubmit(,1)

# 表 1：本地 MAC 学习
cookie=0x0, duration=1234s, table=1, n_packets=50, n_bytes=4000,
  priority=2, dl_dst=fa:16:3e:xx:xx:xx actions=output:1
```

OVS 流表（OpenFlow）是 Neutron 网络的"配置语言"。OVN 会自动生成流表；OVS agent 模式下需要手动管理（已不推荐）。

---

## §5 OVN 架构（取代 OVS 的下一代方案）

### 5.1 OVN 三大组件

```mermaid
graph TB
  NB[(OVN Northbound DB<br/>logical switch / router / port)]
  SB[(OVN Southbound DB<br/>logical flows)]
  CMS[ovn-nbctl<br/>配置工具]

  CMS --> NB
  NB -->|ovn-northd 转换| SB

  subgraph ComputeNode["Compute 节点"]
    OVC[ovn-controller]
    BR[OVS 桥]
    OVC -->|拉取 logical flow| SB
    OVC -->|配置 OVS| BR
  end

  subgraph NetworkNode["Network 节点"]
    OVNGW[ovn-controller<br/>chassis gateway]
    OVNGW --> SB
    OVNGW --> BR2[OVS br-ex]
  end
```

### 5.2 OVN 关键概念

| 概念 | 说明 |
|------|------|
| **Logical Switch** | 虚拟交换机（对应 neutron network） |
| **Logical Router** | 虚拟路由器（对应 neutron router） |
| **Logical Port** | 虚拟端口（对应 neutron port） |
| **Logical Flow** | 流表（OVS OpenFlow） |
| **Chassis** | 物理节点注册（compute/network 节点） |
| **Chassis Resident** | 某个 logical port 物理上是否在某 chassis 上 |

### 5.3 OVN 与 neutron-server 的集成

```bash
# neutron-server 通过 ML2 ovn mechanism driver 与 OVN 通信
neutron-server  --->  OVN NB (6641)
                    OVN SB (6642)

# neutron 配置（ml2_conf.ini）
[ovn]
ovn_nb_connection = tcp:192.168.56.10:6641
ovn_sb_connection = tcp:192.168.56.10:6642
ovn_l3_scheduler = leastloaded  # L3 router 调度策略
```

### 5.4 OVN 优势

1. **集中控制**：所有逻辑在 NB 数据库，节点只拉取增量
2. **性能更好**：少一层 RPC，多一层 DB 直读
3. **DVR 默认**：每个 compute 节点都能处理 L3，无需专用网络节点
4. **运维友好**：故障定位从"每个 agent 看"变为"查 SB 数据库"

参考 [[openstack-deploy-dual/NETWORK-ARCHITECTURE]] 第 3 节 OVN 详解。

---

## §6 Provider Network vs Tenant Network

### 6.1 两种网络类型对比

| 维度 | Provider Network | Tenant Network |
|------|------------------|----------------|
| 创建者 | 管理员（admin） | 租户（普通用户） |
| 网络类型 | flat / vlan / geneve | vxlan / geneve |
| 范围 | 整个 OpenStack 共享 | 单 project 内 |
| 跨 project | 可见 | 默认不可见 |
| 浮动 IP | 直接绑定 | 需 router gateway |
| 用途 | 外部网络（公网/办公网） | 内部网络（VM 之间） |

### 6.2 典型双网架构

```mermaid
graph TB
  subgraph External["Provider Network（外部）"]
    EXT[public-net<br/>192.168.100.0/24<br/>flat 或 vlan]
  end

  subgraph Internal["Tenant Network（内部）"]
    PRIV[private-net<br/>10.0.0.0/24<br/>vxlan]
    VM1[VM 1<br/>10.0.0.10]
    VM2[VM 2<br/>10.0.0.11]
    R[Router<br/>gateway 192.168.100.1]
    PRIV --> VM1
    PRIV --> VM2
  end

  R -->|floating IP NAT| EXT
  EXT --> R
```

### 6.3 创建网络示例

```bash
# Provider Network（admin）
openstack network create --provider-network-type flat \
  --provider-physical-network physnet0 \
  --external public-net

openstack subnet create --network public-net \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --no-dhcp \
  public-subnet

# Tenant Network（普通用户）
openstack network create private-net
openstack subnet create --network private-net \
  --subnet-range 10.0.0.0/24 \
  --dns-nameserver 8.8.8.8 \
  private-subnet

# Router
openstack router create provider-router
openstack router set provider-router --external-gateway public-net
openstack router add subnet provider-router private-subnet

# 启动 VM 用两个网络
openstack server create my-vm \
  --flavor m1.small \
  --image centos8 \
  --network private-net
```

---

## §7 浮动 IP（Floating IP）完整通信流程

### 7.1 浮动 IP 是什么

**浮动 IP = 公网可访问的 IP**（从 Provider Network 池中分配）。它通过 NAT 让外部能访问 VM（VM 自身 IP 在 Tenant Network 内不可直接路由）。

```mermaid
sequenceDiagram
  autonumber
  participant U as 用户
  participant N as neutron-server
  participant OV as ovn-controller
  participant GN as 网关节点 br-ex
  participant CN as compute 节点 br-int
  participant VM as VM

  U->>N: 创建 floating IP（从 public-net 池）
  N->>N: 分配 IP，记录到 DB
  U->>N: 把 floating IP 关联到 VM port
  N->>OV: 更新 OVN logical flow（DNAT + SNAT）
  Note over OV: OVN 自动在所有 chassis 同步流表
  U->>GN: 外部流量 192.168.100.10:80
  GN->>CN: OVN 隧道转交到 VM 所在 compute
  CN->>VM: tap port 送到 VM 内网 IP 10.0.0.10
  VM-->>CN: VM 响应
  CN-->>GN: OVN 隧道
  GN-->>U: 192.168.100.10:80 出口
```

### 7.2 浮动 IP 关键步骤

1. **创建 floating IP**：`openstack floating ip create public-net`
2. **关联到 VM port**：`openstack floating ip set --port <port-id> <fip-id>`
3. **OVN 自动生成 NAT 流表**（无需手动）
4. **外部流量经过 gateway chassis**
5. **gateway chassis 路由到 VM 所在 compute**

### 7.3 为什么必须 `is_chassis_resident` 为真

```bash
# 看某个 logical port 是否在 chassis 上
ovn-sbctl --columns=_uuid list port_binding <port-name>

# 输出关键字段
chassis: c2d3...  # 这是 compute 节点 ID
```

如果 `chassis` 字段为空（`is_chassis_resident` 为 false），意味着 VM 不在它声称的位置 → 浮动 IP 不通。

**排错**：

```bash
# 重启 ovn-controller 让它重新注册
systemctl restart ovn-controller

# 看 chassis 注册情况
ovn-sbctl list chassis
```

---

## §8 br-ex 桥接机制与 IP 迁移

### 8.1 br-ex 是什么

**br-ex = External bridge**，Neutron 把"外部网络"通过它连到物理网卡。

```mermaid
graph LR
  PHYS[物理网卡 ens256<br/>原 IP 192.168.100.10]
  PATCH[patch port patch-ex]
  BREX[br-ex<br/>继承 IP 192.168.100.10]

  PHYS -.OVS 接管.-|eth0 被加到 OVS| BREX
  BREX --- PATCH
  PATCH -.-> BRINT[br-int]
```

### 8.2 IP 迁移的关键

**当物理网卡被 OVS 接管后，它不应该再持有 IP**。否则内核路由绕过 OVN，浮动 IP 不通。

```bash
# 关键代码（来自 openstack-deploy-dual/KEY-CODE-EXAMPLES.md §1.1）
# === 两节点 br-ex / br-int UP ===
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex ens256
ip link set ens256 up
ip link set br-ex up

# === IP 迁移: ens256 → br-ex ===
ip addr flush dev ens256
ip addr add 192.168.100.10/24 dev br-ex
ip route add default via 192.168.100.1 dev br-ex

# 验证
ip addr show ens256  # 应该没有 IP
ip addr show br-ex   # IP 192.168.100.10
```

### 8.3 NM Dispatcher Hook（自动迁移）

**问题**：重启 VM 后 ens256 可能被 NetworkManager 重新获得 IP → 浮动 IP 又不通。

**解决**：用 NM dispatcher hook 自动迁移 IP（详见 KEY-CODE-EXAMPLES.md §1.3）：

```bash
#!/bin/bash
# /etc/NetworkManager/dispatcher.d/99-bridge-fix
# OVN br-ex 持久化 hook
# NM 在接口状态变更时调用: $1=接口名 $2=动作(up/down/...)

INTERFACE=$1
ACTION=$2

case "$ACTION" in
  up)
    if [[ "$INTERFACE" == "ens256" ]]; then
      ovs-vsctl add-port br-ex ens256 2>/dev/null
      ip addr flush dev ens256
      ip addr add 192.168.100.10/24 dev br-ex
      ip link set br-ex up
    fi
    ;;
esac
```

### 8.4 systemd 开机兜底服务

```ini
# /etc/systemd/system/ovn-bridge-fix.service
[Unit]
Description=OVN bridge IP migration fix
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/ovn-bridge-fix.sh

[Install]
WantedBy=multi-user.target
```

详见 KEY-CODE-EXAMPLES.md §1.4。

---

## §9 冷启动自动恢复机制

### 9.1 冷启动问题

VM 关机 → compute 节点重启 → VM 重新起来后：
- br-ex 的 IP 可能丢失（NM 抢占）
- ovn-controller 可能未完成 chassis 注册
- OVN 流表可能未同步

### 9.2 持久化文件清单

参考 NETWORK-ARCHITECTURE.md §6：

```bash
# 1. /etc/NetworkManager/dispatcher.d/99-bridge-fix
#    作用：ens256 up 时自动迁移 IP 到 br-ex

# 2. /etc/systemd/system/ovn-bridge-fix.service
#    作用：开机兜底执行 IP 迁移

# 3. /usr/local/bin/ovn-bridge-fix.sh
#    作用：实际执行的脚本（被 systemd + NM dispatcher 调用）

# 4. /etc/ovn/ovn-controller.log
#    作用：诊断 chassis 注册问题
```

### 9.3 冷启动后验证清单

```bash
# 1. br-ex 是否有 IP
ip addr show br-ex | grep 192.168.100

# 2. ens256 是否被 OVS 接管
ovs-vsctl list-ports br-ex | grep ens256

# 3. ovn-controller 是否注册
ovn-sbctl list chassis | grep $(hostname)

# 4. 浮动 IP 是否能 ping
ping -c 3 192.168.100.10

# 5. OVN 流表是否同步
ovn-sbctl dump-flows | grep <logical-router>
```

---

## §10 DVR 分布式虚拟路由器

### 10.1 传统集中式 L3

```mermaid
graph TB
  subgraph NetworkNode["网络节点（中心化）"]
    R[Router<br/>所有 L3 都过这里]
  end
  subgraph Compute1["Compute 1"]
    V1[VM]
  end
  subgraph Compute2["Compute 2"]
    V2[VM]
  end

  V1 --> R
  V2 --> R
  R --> EXT[外部]
```

**问题**：所有 VM 的南北向流量都过网络节点，单点瓶颈。

### 10.2 DVR 分布式

```mermaid
graph TB
  subgraph Compute1["Compute 1"]
    V1[VM]
    DVR1[DVR Router Agent<br/>本地处理]
  end
  subgraph Compute2["Compute 2"]
    V2[VM]
    DVR2[DVR Router Agent<br/>本地处理]
  end

  V1 --> DVR1
  V2 --> DVR2
  DVR1 -. SNAT .-> EXT[外部]
  DVR2 -. SNAT .-> EXT
```

**好处**：

- 南北向流量本地处理（不用绕网络节点）
- 网络节点不再瓶颈
- 单 compute 节点故障不影响其他

### 10.3 DVR 配置

```ini
# /etc/neutron/neutron.conf
[DEFAULT]
router_distributed = True
```

```ini
# ml2_conf.ini
[ovn]
ovn_l3_scheduler = leastloaded  # DVR 自动，OVN 默认
```

---

## §11 安全组（Security Group）

### 11.1 安全组是什么

**安全组 = VM 网卡的 iptables 规则**。Neutron 通过 `neutron-openvswitch-agent` 在每个 compute 节点上生成 iptables。

```bash
# 看安全组规则
openstack security group list
openstack security group rule list default

# 看具体 VM 的安全组
openstack port list --server <vm-id>
openstack port show <port-id>
```

### 11.2 创建安全组规则

```bash
# SSH 开放
openstack security group rule create default \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0

# HTTP 开放
openstack security group rule create default \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 0.0.0.0/0

# ICMP 开放
openstack security group rule create default \
  --protocol icmp \
  --remote-ip 0.0.0.0/0
```

### 11.3 安全组的实现

```bash
# 在 compute 节点看实际 iptables 规则
iptables -L -nv | grep neutron

# 看 iptables chain
iptables -L neutron-linuxbri-... -nv
```

**注意**：

- 安全组 = ingress（入站）+ egress（出站）双向规则
- 默认安全组：所有 egress 允许，所有 ingress 拒绝
- 远程安全组：可指定来源 IP 段（`--remote-ip`）或来源安全组（`--remote-group`）

### 11.4 安全组常见错误

参考 KEY-CODE-EXAMPLES.md §4：

```bash
# 错误：不指定 --remote-ip 默认仅允许 SG 内部流量
openstack security group rule create default \
  --protocol tcp --dst-port 80

# 正确：加 --remote-ip 0.0.0.0/0
openstack security group rule create default \
  --protocol tcp --dst-port 80 --remote-ip 0.0.0.0/0
```

---

## §12 网络命名空间（Network Namespace）

### 12.1 命名空间是什么

Neutron 在网络节点上为每个 router 创建独立的 network namespace（避免 IP 冲突）。

```bash
# 看所有 router namespace
ip netns list
# 输出：
# qrouter-<router-uuid>
# qdhcp-<network-uuid>

# 进入 router namespace
ip netns exec qrouter-<uuid> ip addr show
# 输出：router 在每个 subnet 的 interface + gateway

# 在 namespace 内 ping 外部
ip netns exec qrouter-<uuid> ping 8.8.8.8
```

### 12.2 命名空间内的网络

- **qrouter** namespace 包含：router interface（每个 subnet 一个）+ gateway port
- **qdhcp** namespace 包含：DHCP server（dnsmasq）
- **qmeta** namespace（可选）：metadata proxy（cloud-init）

### 12.3 namespace 调试

```bash
# 看 router namespace 内的路由表
ip netns exec qrouter-<uuid> ip route

# 看 namespace 内的 conntrack
ip netns exec qrouter-<uuid> conntrack -L

# 在 namespace 内抓包
ip netns exec qrouter-<uuid> tcpdump -i qg-xxx -n
```

---

## §13 Neutron 命令速查

### 13.1 网络与子网

```bash
# 列网络
openstack network list

# 看网络详情
openstack network show <network-id>

# 创建网络（管理员）
openstack network create --provider-network-type vlan \
  --provider-physical-network physnet0 \
  --provider-segment 100 \
  --external vlan100

# 列子网
openstack subnet list

# 创建子网
openstack subnet create --network <network-id> \
  --subnet-range 10.0.1.0/24 \
  --dns-nameserver 8.8.8.8 \
  my-subnet
```

### 13.2 路由器

```bash
# 列路由器
openstack router list

# 创建路由器
openstack router create my-router

# 设置外部网关
openstack router set my-router --external-gateway public-net

# 添加 subnet
openstack router add subnet my-router my-subnet

# 删除路由器
openstack router delete my-router
```

### 13.3 端口

```bash
# 列端口
openstack port list

# 看端口详情（含 IP 和安全组）
openstack port show <port-id>

# 创建端口
openstack port create --network <network-id> \
  --fixed-ip subnet=<subnet-id>,ip-address=10.0.1.50 \
  my-port

# 删除端口（必须先 detach VM）
openstack port delete <port-id>
```

### 13.4 浮动 IP

```bash
# 创建浮动 IP
openstack floating ip create public-net

# 关联到 VM
openstack floating ip set --port <port-id> <floating-ip-id>

# 解除关联
openstack floating ip unset <floating-ip-id>

# 看浮动 IP 列表
openstack floating ip list
```

### 13.5 安全组

```bash
# 列安全组
openstack security group list

# 创建安全组
openstack security group create my-sg

# 加规则
openstack security group rule create my-sg \
  --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0

# 给 VM 加安全组
openstack server add security group <vm-id> my-sg

# 看 VM 的安全组
openstack server show <vm-id> | grep security
```

---

## §14 关键调试命令

### 14.1 OVS 流表

```bash
# ===== br-ex 状态 =====
ovs-vsctl show
ovs-ofctl show br-ex
ovs-ofctl dump-flows br-ex

# ===== ens256 状态 =====
ip addr show ens256
ovs-vsctl list-port br-ex

# ===== OVN chassis =====
ovn-sbctl list chassis
ovn-sbctl list port_binding | grep <vm-name>

# ===== OVN gateway (OVN 24.03) =====
ovn-nbctl list logical_router
ovn-nbctl list logical_switch

# ===== NB 网关配置 =====
ovn-nbctl lr-nat-list <router-name>

# ===== 逻辑流表 (is_chassis_resident) =====
ovn-sbctl dump-flows <logical-router-name> | head -50

# ===== 浮动 IP NAT =====
ovn-nbctl lr-nat-list <router-name>

# ===== 抓包 =====
tcpdump -i br-ex -n
tcpdump -i br-int -n
tcpdump -i any port 4789  # VXLAN 端口

# ===== 持久化服务 =====
systemctl status ovn-controller
systemctl status neutron-openvswitch-agent
systemctl status NetworkManager-dispatcher
```

### 14.2 OVN 数据库查询

```bash
# NB（northbound，逻辑视图）
ovn-nbctl show
ovn-nbctl list logical_switch
ovn-nbctl list logical_router
ovn-nbctl list logical_router_port
ovn-nbctl list nat

# SB（southbound，物理视图）
ovn-sbctl show
ovn-sbctl list chassis
ovn-sbctl list port_binding
ovn-sbctl list logical_flow
ovn-sbctl dump-flows
```

### 14.3 Neutron 日志

```bash
# 控制节点
tail -f /var/log/neutron/server.log
tail -f /var/log/neutron/neutron-server.log

# 网络节点
tail -f /var/log/neutron/neutron-dhcp-agent.log
tail -f /var/log/neutron/neutron-l3-agent.log
tail -f /var/log/neutron/ovn-controller.log

# 计算节点
tail -f /var/log/neutron/openvswitch-agent.log
tail -f /var/log/neutron/ovn-controller.log
```

---

## §15 常见网络问题与诊断

详见 [[06-OpenStack故障排查与运维#§2 网络故障]]。本章列最常见入口：

| 症状 | 第一检查 | 命令 |
|------|----------|------|
| VM 之间不通 | br-int 流表 | `ovs-ofctl dump-flows br-int` |
| 浮动 IP 不通 | br-ex IP + OVN NAT | `ip addr show br-ex` + `ovn-nbctl lr-nat-list` |
| VM 不能上网 | router gateway + NAT | `openstack router show <id>` |
| VM 创建慢 | OVN 流表同步 | `ovn-sbctl show` 看 logical flow 数 |
| 主机重启后浮动 IP 不通 | NM dispatcher 是否配 | `ls /etc/NetworkManager/dispatcher.d/` |
| ovn-controller 报错 | OVN NB/SB 连接 | `ovn-sbctl show` |
| 网络性能差 | OVS offload | `ethtool -k <nic>` 看 rx-vlan-offload |
| Neutron API 慢 | DB 性能 | `mysql -e "SHOW PROCESSLIST"` 看慢查询 |

### 15.1 经典故障：浮动 IP 时通时不通

**症状**：浮动 IP ping 不通，重启后通一会又不通。

**根因**：ens256 IP 没迁到 br-ex，内核路由绕过 OVN。

**修复**：

```bash
# 1. 立即修复（手动）
ip addr flush dev ens256
ip addr add 192.168.100.10/24 dev br-ex

# 2. 持久化（NM dispatcher）
cat > /etc/NetworkManager/dispatcher.d/99-bridge-fix <<'EOF'
#!/bin/bash
case "$2" in
  up) ovs-vsctl add-port br-ex ens256 2>/dev/null
      ip addr flush dev ens256
      ip addr add 192.168.100.10/24 dev br-ex ;;
esac
EOF
chmod +x /etc/NetworkManager/dispatcher.d/99-bridge-fix
```

参考 KEY-CODE-EXAMPLES.md §1。

### 15.2 经典故障：compute 节点 ovn-controller 注册失败

**症状**：VM 启动 OK，但浮动 IP 不通，OVN SB 看不到 compute chassis。

**修复**：

```bash
# 1. 检查 ovn-controller 状态
systemctl status ovn-controller
journalctl -u ovn-controller -n 50

# 2. 检查连接配置
cat /etc/sysconfig/ovn-controller
# 或
cat /etc/default/ovn-controller

# 3. 手动重启
systemctl restart ovn-controller

# 4. 验证注册
ovn-sbctl list chassis | grep <hostname>
```

---

## §16 与已有 vault 模块的链接

- [[Linux网络]] — OVS bridge 与 Linux bridge 对比
- [[Linux防火墙]] — iptables 是安全组底层
- [[LinuxKVM]] — VM 网卡通过 tap 设备
- [[Linux服务与SSH]] — ovn-controller 通过 systemd 管理
- [[LinuxShell]] — 调试命令基于 bash + ovs-ofctl / ovn-sbctl
- [[华为VRP]] — Provider Network 用 VLAN 时对接交换机配置
- [[01-OpenStack核心概念#§7 Nova 系统架构]] — Nova 与 Neutron 协作
- [[03-OpenStack认证与多租户]] — Neutron API 需要 Keystone Token
- [[04-OpenStack存储与镜像]] — Cinder 多后端对接 Neutron 端口
- [[05-OpenStack安装配置手册]] — Neutron 在 packstack / kolla-ansible 中的部署
- [[06-OpenStack故障排查与运维]] — 网络故障分类
- [[00-OpenStack学习路线#§10 复习 Checklist]] — 网络层复习要点

---

最后更新: 2026-08-10 23:25（T4 Stage 6 Code 完成）