---
title: Linux DHCP 服务器
desc: DHCP 协议 + 地址租约 + 作用域 + 保留地址 + 中继 + option + 实验配置
type: 笔记
module: LinuxDHCP
pdf: DHCP 服务器.pdf + dhcp实验.pdf
pdf_size: 1.3 MB + 0.7 MB
scope: DHCP 原理 + dhcpd 部署 + 实战实验 + 故障排查
status: 完成
---

# Linux DHCP 服务器

> **定位**：把 DHCP 当作局域网的“自动前台”。客户端只带着 MAC 地址来报到，服务器按作用域提供 IP、掩码、网关、DNS 和租约时间。
>
> **来源合并**：本文融合《DHCP 服务器.pdf》（原理、ISC dhcpd、作用域、固定租约、中继、dnsmasq）和《dhcp实验.pdf》（华为 VRP 地址池实验）。命令按 CentOS 7 / RHEL 系习惯整理。
>
> **关联阅读**：[[Linux网络#dhcp基础]] · [[LinuxDNS#dhcp-dns联动]] · [[路由与VLAN#dhcp中继]]

## 目录

- [[#§0 心智模型：DHCP = 自动前台 + DORA 租约]]
- [[#§1 DHCP 是什么：动态主机配置协议]]
- [[#§2 DHCP 四步租约流程：DORA]]
- [[#§3 DHCP 续租：T1、T2 与重绑定]]
- [[#§4 dhcpd 安装与服务生命周期]]
- [[#§5 作用域声明：subnet、range 与默认参数]]
- [[#§6 保留地址：host、MAC 与 fixed-address]]
- [[#§7 DHCP 中继：跨广播域转发]]
- [[#§8 DHCP option 速查与组合]]
- [[#§9 超级作用域：shared-network]]
- [[#§10 DHCP 客户端：dhclient、dhcpcd、NetworkManager]]
- [[#§11 抓包分析：tcpdump 与 Wireshark]]
- [[#§12 故障排查：日志、语法与常见错误]]
- [[#§13 多网卡场景：监听接口与路由]]
- [[#§14 实验配置：单作用域、中继、保留地址]]
- [[#§15 易错点 ×10]]
- [[#§16 速查表]]
- [[#§17 面试 6 大追问]]

---

## §0 心智模型：DHCP = 自动前台 + DORA 租约

### 0.1 一句话模型

```text
客户端没有 IPv4 地址
        │ 广播 DHCPDISCOVER（“有没有 DHCP 服务员？”）
        ▼
DHCP 服务器挑选作用域和地址
        │ 单播/广播 DHCPOFFER（“给你这个地址和参数”）
        ▼
客户端广播 DHCPREQUEST（“我选择这台服务器的报价”）
        │ 服务器确认或拒绝 DHCPACK / DHCPNAK
        ▼
客户端安装 IP、掩码、网关、DNS，并记录租约
```

- **D**iscover：发现服务器；通常源 `0.0.0.0:68`，目标 `255.255.255.255:67`。
- **O**ffer：服务器提出可用地址、租约和 option；多个服务器可以同时报价。
- **R**equest：客户端广播选择结果，`server identifier` 表明选中的服务器。
- **A**ck：服务器确认，客户端才拥有该地址的租用权。
- DORA 是初始租约协商的四类 DHCP 报文，不是四条必须手工执行的命令。
- 服务器分配的是**租用权**，不是永久所有权；租期结束前需要续租。
- 作用域决定地址池，option 决定“拿到地址后还要知道什么”。
- 中继解决广播无法跨三层设备的问题，不会改变 DORA 的逻辑顺序。
- 固定地址仍属于 DHCP 租约，只是服务器按 MAC 每次给同一个地址。

### 0.2 地址规划示例

```text
地址图：10.1.8.0/24
  服务器 10.1.8.10
  网关   10.1.8.2
  动态池 10.1.8.101-10.1.8.130
  固定   10.1.8.88

角色图：client →（二层广播）→ dhcp-server
跨网段：client → relay（10.1.1.20）→ server（10.1.8.10）
```

### 0.3 最小排查闭环

1. 服务器网卡有静态 IP，且网段与 `subnet` 声明一致。
2. `dhcpd -t` 通过，不要先重启再猜错在哪里。
3. `systemctl status dhcpd` 显示 active，UDP 67 正在监听。
4. 客户端网卡设置为自动 IPv4，并确认没有第二个 DHCP。
5. `tcpdump -ni ens33 'udp port 67 or udp port 68'` 能看到 DORA。
6. 查看 `/var/lib/dhcpd/dhcpd.leases`，确认地址没有被异常占用。

## §1 DHCP 是什么：动态主机配置协议

### 1.1 DHCP 提供什么

DHCP（Dynamic Host Configuration Protocol）集中向客户端发放网络参数，避免逐台手工写入。

| 参数 | 作用 | DHCP option |
|---|---|---:|
| IPv4 地址 | 标识客户端 | `yiaddr` 字段 |
| 子网掩码 | 判断本地/远端 | 1 |
| 默认网关 | 非本地流量的下一跳 | 3 |
| DNS 服务器 | 域名解析 | 6 |
| DNS 搜索域 | 补全短主机名 | 15 / 119 |
| 广播地址 | 发送网段广播 | 28 |
| 租约时间 | 地址有效期限 | 51 |
| T1 / T2 | 续租和重绑定时刻 | 58 / 59 |
| 启动服务器 | PXE/TFTP 场景 | 66 |
| 启动文件 | 网络引导文件 | 67 |

### 1.2 端口与传输

- DHCPv4 基于 UDP；服务器监听 **67**，客户端监听 **68**。
- 初次发现时客户端没有可用源 IP，因此使用 `0.0.0.0` 发送广播。
- `255.255.255.255` 是有限广播，普通路由器不应跨接口转发。
- 已有租约的续租阶段可以从客户端单播到原服务器。
- DHCPv6 使用 UDP 546/547，本文主体是 DHCPv4，不能混用端口。
- 防火墙必须放行 `dhcp` 服务，且只在可信接口开放。

### 1.3 手工配置与 DHCP 对比

| 手工配置的痛点 | DHCP 的集中化解决 |
|---|---|
| 地址重复 | 地址池和租约文件追踪已分配地址 |
| 网关变更要逐台改 | 修改作用域的 `option routers` |
| DNS 服务器变更 | 修改 `option domain-name-servers` |
| 新员工接入耗时 | 插网线即可执行 DORA |
| 服务器需固定地址 | `host` + `fixed-address` |
| 多 VLAN 需要多池 | 每个三层网段一个 `subnet`，通过中继定位 |

### 1.4 DHCP 与其他协议的边界

- DHCP **发放** IP，不负责解析域名；解析由 DNS 完成。
- DHCP 可以下发网关，但不替代路由器转发数据包。
- 客户端配置 IP 后会用 ARP 找到同网段网关的 MAC。
- DHCP 报文走 UDP，不能用 `ping` 单独证明 DHCP 服务工作。
- 没有三层连通性时，中继即使收到广播也无法把报文送到服务器。

### 1.5 安全提示

- 一个广播域尽量只放一台权威 DHCP 服务器。
- 未授权 DHCP 可下发恶意网关/DNS，交换机应启用 DHCP Snooping（若支持）。
- `authoritative;` 只应放在管理方确认的权威服务器配置中。
- 对外网卡不要监听或放行 DHCP 端口，避免误服务和信息泄露。
- 保留地址按 MAC 识别，虚拟机克隆后 MAC 变化会导致匹配失败。

## §2 DHCP 四步租约流程：DORA

### 2.1 报文时序

```text
客户端                         DHCP 服务器
  |                                  |
  |-- DHCPDISCOVER ----------------->|  UDP 68 → 67，广播
  |<-- DHCPOFFER --------------------|  地址、租期、option
  |-- DHCPREQUEST（广播） ----------->|  选择 server identifier
  |<-- DHCPACK -----------------------|  确认租约
  |                                  |
  |  安装 IP/route/resolv.conf        |
```

### 2.2 DHCPDISCOVER

- `op=BOOTREQUEST`，客户端硬件类型和 MAC 位于 `chaddr`。
- `xid` 是事务 ID；整个 DORA 用它关联请求和响应。
- `ciaddr` 通常为 `0.0.0.0`，客户端尚未确认地址。
- `flags` 的广播位表示客户端无法接收目的地址为 `yiaddr` 的单播。
- `Option 53 = DHCP Discover`，抓包时用它定位第一步。
- `Option 55 = Parameter Request List` 表示客户端想要哪些参数。
- 中继收到广播后会记录 `giaddr`，服务器据此选择作用域。

### 2.3 DHCPOFFER

- 服务器在 `yiaddr` 填入暂时提供的 IPv4 地址。
- `Option 54 server identifier` 标识提供报价的 DHCP 服务器。
- `Option 51 IP address lease time` 告知租约秒数。
- 报价不是最终确认；客户端可能收到多个 Offer。
- 服务器会暂时保留地址，等待 Request 或超时释放。
- Offer 中的网关、DNS、域名来自匹配作用域的 option。

### 2.4 DHCPREQUEST

- 初次获取时通常广播，告诉所有服务器“我选了谁”。
- `Option 50 requested IP address` 表示客户端请求的地址。
- `Option 54 server identifier` 表示选中的服务器。
- 未被选中的服务器看到广播后会撤销自己的 Offer。
- 续租时方式可能不同，不能只凭是否广播判断流程。
- 客户端收到旧租约、重启或网络切换时都可能发送 Request。

### 2.5 DHCPACK 与 DHCPNAK

- ACK 表示服务器同意地址和 option，客户端开始使用租约。
- 客户端应检查地址、掩码、网关和 DNS 是否与所在网段匹配。
- NAK 表示服务器拒绝请求，常见原因是旧租约属于另一网段。
- 收到 NAK 后客户端必须停止使用旧地址并重新 Discover。
- 非权威服务器可能忽略未知旧地址；权威服务器会明确 NAK。
- 服务端日志应同时关注请求地址、MAC、接口和 `giaddr`。

### 2.6 关键字段

| 字段/选项 | 看到什么 | 说明 |
|---|---|---|
| `xid` | 四个阶段相同 | 同一事务 |
| `chaddr` | 客户端 MAC | 可与 `host` 匹配 |
| `yiaddr` | Offer/ACK 的地址 | 客户端将使用的 IPv4 |
| `giaddr` | 中继接口地址 | 服务器选择作用域 |
| option 53 | Discover/Offer/Request/ACK | 报文类型 |
| option 50 | 例如 10.1.8.102 | 请求的 IP |
| option 54 | 10.1.8.10 | 服务器标识 |
| option 51 | 600 | 租约秒数 |
| option 3 | 10.1.8.2 | 默认网关 |
| option 6 | 223.5.5.5 | DNS |

### 2.7 初次启动与重启

- 初次启动：客户端没有地址，执行完整 DORA。
- 客户端重启：可能先尝试 INIT-REBOOT，用旧地址请求确认。
- 网络切换：旧地址不属于新网段，服务器应发 NAK，客户端重新发现。
- 服务器重启：租约文件应保留，避免误判仍在使用的地址为空闲。
- 清空租约文件是最后手段，生产环境先备份并确认没有并发 dhcpd。

## §3 DHCP 续租：T1、T2 与重绑定

### 3.1 两个时间点

- **T1（Renewing）**：默认租期的 50%。客户端向原 DHCP 服务器单播 DHCPREQUEST。
- **T2（Rebinding）**：默认租期的 87.5%。原服务器未响应时，客户端广播 Request。
- 租期到期仍没有 ACK，客户端必须停止使用地址，回到初始发现状态。
- 服务器可以在 ACK 中下发 option 58、59 覆盖默认比例。
- 举例：租期 600 秒，T1 约 300 秒，T2 约 525 秒。

### 3.2 时间线

```text
租约获得       T1=50%                  T2=87.5%              到期
|--------------|-----------------------|---------------------|
     正常使用   单播 Request→原服务器    广播 Request→任意服务器  停止使用
```

### 3.3 观察续租

```bash
ip addr show ens33
nmcli -f GENERAL,IP4 device show ens33
dhclient -v ens33
journalctl -u NetworkManager -f
```

- `valid_lft` 是地址的有效剩余时间，`preferred_lft` 是首选地址剩余时间。
- 租约文件中的 `renew`、`rebind`、`expire` 可用于离线分析。
- 调整 `default-lease-time` 不会强制已经发出的租约立即变短。
- 服务端临时不可用时，已有租约可能继续工作到 T2；新客户端仍无法获取地址。

### 3.4 多 DHCP 服务器

- 同一物理网络可有多个服务器，但通常只建议一台回答请求。
- 新客户端可能收到多个 Offer，Request 中广播选中服务器的 IP。
- 其他服务器释放为客户端准备的地址，避免地址池泄漏。
- 非权威服务器一般忽略自己不知道的旧地址请求。
- 权威服务器发现地址属于自己管理的范围但状态未知时，可发 NAK。
- 收到 NAK 的客户端不能继续使用旧地址，必须重新获取。

## §4 dhcpd 安装与服务生命周期

### 4.1 安装前检查

```bash
cat /etc/centos-release
ip addr
ip route
nmcli device status
nmcli connection show
```

- 实验服务器使用静态地址 `10.1.8.10/24`，主机名 `dhcp-server`。
- VMware 实验中先关闭 vmnet8/vmnet1 自带 DHCP，避免多个 Offer。
- 服务器必须有静态 IP，不能把服务器地址放入动态池。
- 网卡需要有 `BROADCAST` 标志；没有广播能力时需检查虚拟交换机。

### 4.2 yum 与防火墙

```bash
yum install -y dhcp
firewall-cmd --add-service=dhcp
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload
firewall-cmd --list-services
```

- 软件包提供 `/usr/sbin/dhcpd` 和 `/usr/share/doc/dhcp-*/dhcpd.conf.example`。
- 只执行临时规则，重启后会消失；只加永久规则不 reload，当前实例可能未放行。
- firewalld 放行只是网络许可，不能替代 dhcpd 配置。

### 4.3 路径与文件

| 路径 | 用途 |
|---|---|
| `/etc/dhcp/dhcpd.conf` | 主配置文件 |
| `/usr/share/doc/dhcp-*/dhcpd.conf.example` | 示例配置 |
| `/var/lib/dhcpd/dhcpd.leases` | DHCPv4 租约数据库 |
| `/var/log/messages` | CentOS 7 常见服务日志 |
| `journalctl -u dhcpd` | systemd 服务日志 |
| `/usr/lib/systemd/system/dhcpd.service` | 服务单元 |
| `/etc/sysconfig/dhcpd` | 部分版本的接口参数 |

### 4.4 语法、启动与验证

```bash
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl enable dhcpd --now
systemctl status dhcpd --no-pager
ss -lunp | grep ':67'
# 配置变更后的安全顺序
dhcpd -t && systemctl reload dhcpd
```

- `dhcpd -t` 返回码为 0 才继续，漏分号或括号会在这里暴露。
- `enable --now` 同时建立开机启动并立即启动。
- 服务 active 但没有 Offer，仍需检查网卡、作用域、广播和抓包。
- 修改接口、地址或服务参数时，可在语法通过后 `systemctl restart dhcpd`。

## §5 作用域声明：subnet、range 与默认参数

### 5.1 最小可用作用域

```conf
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.130;
  option subnet-mask 255.255.255.0;
  option routers 10.1.8.2;
  option domain-name-servers 223.5.5.5;
  option broadcast-address 10.1.8.255;
  default-lease-time 600;
  max-lease-time 7200;
}
```

- `subnet` 描述客户端所在网段，`range` 是动态池起止地址。
- `option routers` 必须是本网段中真实可达的网关。
- DNS 可填企业内部 DNS 或公共 DNS；生产环境优先内部解析器。
- `default-lease-time` 和 `max-lease-time` 单位均为秒。
- 动态池通常避开服务器、网关、打印机和保留地址。

### 5.2 网段匹配原则

```text
服务器 ens33：10.1.8.10/24
作用域声明：  10.1.8.0/24       ← 匹配
地址池：      10.1.8.101-130    ← 属于该网段
网关：        10.1.8.2          ← 属于该网段
广播：        10.1.8.255        ← 与掩码一致
```

- 服务器直连客户端时，`subnet` 必须与接收广播接口的网段匹配。
- 中继场景中，服务器可声明远端 `subnet`；由 `giaddr` 指示选择。
- `range` 不能跨两个不同网段，也不能包含网络地址/广播地址。
- 作用域网段不匹配时，服务可能运行但不响应 Discover。

### 5.3 地址池容量

- `/24` 共有 256 个地址，通常网络号与广播地址不可分配。
- `10.1.8.101` 到 `10.1.8.130` 含 30 个地址，两端均包含。
- 池大小按并发客户端、租期和峰值估算，不要只按当前主机数。
- 池耗尽时日志常见 `no free leases`，客户端会反复 Discover。
- 预留范围不放进动态池，即使当前看似没有设备使用。

### 5.4 全局与作用域参数

```conf
default-lease-time 600;
max-lease-time 7200;
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.130;
  option routers 10.1.8.2;
}
```

- ISC dhcpd 每条语句以分号结尾；大括号决定作用域。
- 全局 option 适用于没有更具体值的客户端，跨网段使用要谨慎。
- 一个文件可声明多个 `subnet`，每网段应有独立池和网关。
- `group` 可集中多个 host 声明，但不能替代 subnet。

## §6 保留地址：host、MAC 与 fixed-address

### 6.1 固定租约

```conf
host client-manager {
  hardware ethernet 00:0c:29:9d:fe:6e;
  fixed-address 10.1.8.88;
  option host-name "client-manager";
}
```

- `hardware ethernet` 写客户端真实 MAC，不是服务器 MAC。
- `fixed-address` 不应落在动态 `range` 中，避免地址冲突。
- 主机名只是标识和可选下发项，匹配依靠硬件地址。
- MAC 建议统一小写、冒号分隔，保持配置和审计记录一致。
- 固定地址必须属于对应接口/中继作用域，跨网段固定会不可达。

### 6.2 获取 MAC 与验证

```bash
ip link show ens33
nmcli -g GENERAL.HWADDR device show ens33
grep -n -A8 -B2 'client-manager' /etc/dhcp/dhcpd.conf
grep -n '10.1.8.88' /var/lib/dhcpd/dhcpd.leases
dhclient -r ens33
dhclient -v ens33
ip addr show ens33
```

- 虚拟机克隆后检查 MAC 是否重复；重复 MAC 会命中同一固定地址。
- 修改 host 后先 `dhcpd -t`，再 reload/restart。
- 客户端仍显示旧地址时，可能是 NetworkManager 连接缓存或旧租约。
- 固定租约仍受 option 影响，可在 host 中覆盖特殊 DNS/网关。

### 6.3 地址规划

```text
10.1.8.1       网络设备静态地址
10.1.8.2       默认网关
10.1.8.10      DHCP 服务器
10.1.8.20      DHCP Relay
10.1.8.50-80   其他服务器保留
10.1.8.88      client-manager fixed-address
10.1.8.101-130 普通客户端动态池
10.1.8.255     广播地址
```

- 规划表应是配置和变更记录的单一事实来源。
- 固定 MAC 列表定期清理离网设备，避免地址长期被占用。
- 数据库、网络设备等关键系统可使用保留地址，但仍要监控租约。

## §7 DHCP 中继：跨广播域转发

### 7.1 为什么需要 Relay

- 客户端 Discover 是二层广播，普通三层路由器不会转发有限广播。
- DHCP Relay 在客户端网段接收广播，改为单播发往 DHCP 服务器。
- 服务器通过中继设置的 `giaddr` 识别客户端来自哪个网段。
- 服务器回复中继，中继再把报文转回客户端网段。
- DORA 四步不变，变化的是报文经过了中继代理。

### 7.2 拓扑与地址

```text
客户端网段 vmnet1                  服务器网段 vmnet8
client  ── 10.1.1.0/24 ── relay ── 10.1.8.0/24 ── dhcp-server
                             │
                 ens160 10.1.1.20
                 ens33  10.1.8.20       server 10.1.8.10
```

- 源教材实验：server `10.1.8.10/24`，relay 两接口 `10.1.8.20/24` 和 `10.1.1.20/24`。
- DHCP server 必须有到 relay 客户端侧接口的返回路由。
- relay 必须启用 IPv4 转发；普通内核转发不等于 DHCP 广播代理。
- VMware 两个虚拟网络关闭自带 DHCP，避免第三方回应。

### 7.3 server 多作用域

```conf
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.200;
  option routers 10.1.8.20;
  option broadcast-address 10.1.8.255;
  option domain-name-servers 223.5.5.5;
  option domain-search "laogao.cloud";
  default-lease-time 600;
  max-lease-time 7200;
}
subnet 10.1.1.0 netmask 255.255.255.0 {
  range 10.1.1.101 10.1.1.200;
  option routers 10.1.1.20;
  option broadcast-address 10.1.1.255;
  option domain-name-servers 223.5.5.5;
  option domain-search "laogao.cloud";
  default-lease-time 600;
  max-lease-time 7200;
}
```

- 直连服务器网段和远端客户端网段都要声明。
- 远端作用域的网关应填写客户端所在网段的 relay 接口。
- 服务器默认路由不一定覆盖 relay 端；实验中显式加静态路由更容易验证。

### 7.4 dhcrelay 服务

```bash
yum install -y dhcp
cp /usr/lib/systemd/system/dhcrelay.service /etc/systemd/system/dhcrelay.service
vim /etc/systemd/system/dhcrelay.service
```

```ini
[Unit]
Description=DHCP Relay Agent Daemon
Documentation=man:dhcrelay(8)
Wants=network-online.target
After=network-online.target
[Service]
Type=notify
ExecStart=/usr/sbin/dhcrelay -d --no-pid 10.1.8.10
StandardError=null
[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable dhcrelay.service --now
systemctl status dhcrelay.service --no-pager
```

- `-d` 前台运行，适合实验观察；生产环境按发行版服务模板运行。
- `10.1.8.10` 是 DHCP server，不要写客户端网关地址。
- relay 两个接口均需 UP，且到 server UDP 67 可达。
- relay 端避免 dhcpd 和 dhcrelay 同时抢占 UDP 67。

### 7.5 路由与转发

```bash
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
nmcli connection modify ens160 ipv4.routes '10.1.1.20/32 10.1.8.20'
nmcli connection up ens160
ip route get 10.1.1.20
ip addr show
```

- 路由写错下一跳时，server 能收到 Discover，但 ACK 回不去。
- 中继回包使用客户端网段广播时，relay 端口和防火墙必须允许。
- server、relay 两侧同时抓包，比较 `giaddr` 和源/目标地址。

## §8 DHCP option 速查与组合

### 8.1 常见 option

| 编号 | dhcpd 写法 | 含义 | 示例 |
|---:|---|---|---|
| 1 | `option subnet-mask` | 子网掩码 | `255.255.255.0` |
| 3 | `option routers` | 默认网关 | `10.1.8.2` |
| 6 | `option domain-name-servers` | DNS | `223.5.5.5` |
| 12 | `option host-name` | 主机名 | `client01` |
| 15 | `option domain-name` | DNS 域名 | `laogao.cloud` |
| 28 | `option broadcast-address` | 广播地址 | `10.1.8.255` |
| 42 | `option ntp-servers` | NTP | `10.1.8.2` |
| 51 | `option dhcp-lease-time` | IP 租约 | `600` |
| 54 | `server-identifier` | 服务器标识 | `10.1.8.10` |
| 58 | `option dhcp-renewal-time` | T1 | `300` |
| 59 | `option dhcp-rebinding-time` | T2 | `525` |
| 66 | `next-server` | 启动/TFTP 服务器 | `10.1.8.10` |
| 67 | `filename` | PXE 文件 | `pxelinux.0` |
| 119 | `option domain-search` | 搜索域列表 | `laogao.cloud` |

### 8.2 常用组合

```conf
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.130;
  option subnet-mask 255.255.255.0;
  option routers 10.1.8.2;
  option domain-name-servers 223.5.5.5, 1.1.1.1;
  option domain-name "laogao.cloud";
  option domain-search "laogao.cloud";
  option broadcast-address 10.1.8.255;
  option ntp-servers 10.1.8.2;
  default-lease-time 600;
  max-lease-time 7200;
}
```

- DNS 可列多个地址，用逗号分隔。
- `domain-name` 常被 NetworkManager 映射为 resolv.conf 的 search，行为依客户端实现。
- `server-identifier` 应使用客户端可达接口的地址。
- PXE 需要 option 66/67，TFTP/HTTP 服务另行部署，DHCP 不传输启动文件本身。
- option 值必须与客户端实际拓扑相符，不要照抄公共 DNS。

### 8.3 查看最终生效值

```bash
ip addr show ens33
ip route
cat /etc/resolv.conf
nmcli -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP4.DOMAIN device show ens33
```

- 地址对而网关错：重点看 option 3。
- 能访问 IP 不能解析域名：重点看 option 6 和 resolv.conf。
- 短名解析异常：检查 option 15/119 及 NetworkManager。
- 地址租期过短：检查 option 51、default/max lease time。

## §9 超级作用域：shared-network

### 9.1 概念

- `shared-network` 把多个逻辑 `subnet` 归入同一物理网络/共享链路。
- DHCP 服务器可在同一广播域的多个 subnet 声明中选择地址池。
- 它不是三层路由，也不是中继；跨 VLAN 仍需要 relay。
- 只有确认多个 subnet 共享物理链路时才使用。

### 9.2 配置示例

```conf
shared-network lab-net {
  subnet 10.1.8.0 netmask 255.255.255.0 {
    range 10.1.8.101 10.1.8.130;
    option routers 10.1.8.2;
  }
  subnet 10.1.9.0 netmask 255.255.255.0 {
    range 10.1.9.101 10.1.9.130;
    option routers 10.1.9.2;
  }
}
```

- 每个 subnet 的网关、广播和 DNS 仍要单独核对。
- 共享网络内的地址池容量影响选择，规划时避免重叠。
- 先用单作用域验证 DORA，再引入 shared-network 降低变量数量。
- 配置改变后执行 `dhcpd -t`，再 reload 并观察日志。

## §10 DHCP 客户端：dhclient、dhcpcd、NetworkManager

### 10.1 dhclient

```bash
dhclient -v ens33
dhclient -r ens33
ls -l /var/lib/dhclient/
ls -l /var/lib/NetworkManager/
```

- `-v` 显示 Discover、Offer、Request、ACK，适合实验排查。
- 释放再请求前确认接口名，错误接口不会改变目标连接。
- 不同发行版的租约路径可能不同，先查文件实际位置。

### 10.2 NetworkManager

```bash
nmcli connection add con-name dhcp-client1 type ethernet \
  ipv4.method auto ifname ens33
nmcli connection up dhcp-client1
nmcli connection show
nmcli device status
nmcli device show ens33
```

- `ipv4.method auto` 才启动 DHCPv4，`manual` 是静态配置。
- 同一接口存在多个连接时，确保只有预期连接 active。
- `nmcli connection down` 后再 `up` 可触发重新协商。
- NetworkManager 可能把 option 写入 `/etc/resolv.conf`，不要只看旧缓存。

### 10.3 dhcpcd 与发行版差异

- `dhcpcd` 是另一种客户端守护进程，和 `dhclient` 二选一。
- 同一接口不要同时运行 dhclient、dhcpcd 和 NetworkManager。
- 命令参数以目标发行版的 `man dhcpcd` 为准，本文主线使用 dhclient/NM。
- systemd-networkd、netplan 等系统有各自配置入口，先确认网络管理者。

### 10.4 客户端实验结果

- 普通 client1 从 `10.1.8.101-130` 池中获取，例如 `10.1.8.102/24`。
- 经理 client2 MAC `00:0c:29:9d:fe:6e` 获取固定 `10.1.8.88/24`。
- 每次获取验证 `ip addr`、`ip route`、`cat /etc/resolv.conf`。
- 释放/重租后动态地址可能变化；固定客户端应仍为 `.88`。

## §11 抓包分析：tcpdump 与 Wireshark

### 11.1 tcpdump 真实命令

```bash
tcpdump -ni ens33 -vvv 'udp port 67 or udp port 68'
tcpdump -ni ens33 -s0 -w /tmp/dhcp-dora.pcap 'udp port 67 or udp port 68'
tcpdump -ni any -vvv 'udp port 67 or udp port 68'
```

- `-n` 不反查 DNS，避免抓包时产生额外流量。
- `-i any` 便于实验观察；保存 pcap 时建议指定真实接口。
- `-s0` 保留完整 options，避免看不到 option 50/54。
- 生产环境抓包要确认授权和敏感性，完成后清理临时 pcap。

### 11.2 预期输出与判断

```text
DHCPDISCOVER from 00:0c:29:38:78:83 via ens33
DHCPOFFER on 10.1.8.102 to 00:0c:29:38:78:83
DHCPREQUEST for 10.1.8.102 from 00:0c:29:38:78:83 via ens33
DHCPACK on 10.1.8.102 to 00:0c:29:38:78:83 via ens33
```

- 只有 Discover：服务器没收到、没有匹配作用域，或没有发 Offer。
- 有 Offer 无 Request：客户端选择/链路/第二 DHCP 干扰。
- 有 Request 无 ACK：配置、地址冲突、租约状态或权限问题。
- 有 ACK 但客户端无地址：客户端管理器拒绝、接口重置或地址冲突。
- 中继场景 server 端应看到 relay 单播，并看到 `giaddr`。

### 11.3 Wireshark 过滤器

```text
bootp
udp.port == 67 || udp.port == 68
bootp.option.dhcp == 1
bootp.option.dhcp == 2
bootp.option.dhcp == 3
bootp.option.dhcp == 5
bootp.ip.client
```

- Wireshark 在 DHCPv4 中通常把协议标为 BOOTP；`bootp` 过滤器适用。
- 展开 Dynamic Host Configuration Protocol 查看 options。
- 对照 Transaction ID 验证四步属于同一会话。
- 查看 `Your (client) IP address`、Server Identifier、Requested IP Address。
- 查看 Lease Time、Subnet Mask、Router、Domain Name Server。

### 11.4 中继抓包要点

```text
client → relay：广播，源 0.0.0.0:68，目标 255.255.255.255:67
relay → server：单播，目标 10.1.8.10:67，携带 giaddr=10.1.1.20
server → relay：发往 relay
relay → client：客户端网段广播或单播
```

- `giaddr` 为空常代表直连；非零代表中继提供网段线索。
- relay 收到 Discover 但 server 看不到，查 relay 服务、路由、防火墙。
- server 发 ACK 但 client 看不到，查 server 到 relay 的返回路由。
- 抓包结论要结合日志，不要只看单个报文。

## §12 故障排查：日志、语法与常见错误

### 12.1 标准顺序

1. **物理/虚拟链路**：接口 UP，虚拟交换机连接正确，vmnet DHCP 已关闭。
2. **地址规划**：服务器静态 IP、作用域、池、网关和广播一致。
3. **语法**：`dhcpd -t -cf /etc/dhcp/dhcpd.conf`。
4. **服务**：`systemctl status dhcpd`，确认没有启动失败。
5. **监听**：`ss -lunp | grep ':67'`，确认进程正确。
6. **防火墙**：`firewall-cmd --list-services`，确认 dhcp 放行。
7. **客户端**：自动 IPv4、正确连接、释放旧租约后重试。
8. **抓包日志**：确定 DORA 中断在哪一步。

### 12.2 日志命令

```bash
journalctl -u dhcpd -b --no-pager
journalctl -u dhcpd -f
grep -iE 'dhcp|lease|error|fail|no free' /var/log/messages
systemctl status dhcpd --no-pager -l
```

- `-b` 限定本次启动，`-f` 实时跟踪。
- 日志 MAC、接口、地址应与抓包和规划表互相印证。
- `Not configured to listen on any interfaces` 时优先查网卡和作用域。

### 12.3 典型日志

| 现象 | 可能原因 | 检查 |
|---|---|---|
| `No subnet declaration` | 作用域与接口不匹配 | `ip addr`、`subnet` |
| `Not configured to listen` | 没有可用接口/子网 | 服务配置与接口 |
| `no free leases` | 池耗尽或租约残留 | leases、池容量 |
| `bad range` | range 越界或顺序错误 | 起止地址、掩码 |
| `Cannot find dhcpd.conf` | 路径或权限错 | `ls -l /etc/dhcp` |
| `Address already in use` | 第二 DHCP 服务 | `ss -lunp`、vmnet |
| 有 Discover 无 Offer | 防火墙、作用域、服务 | 抓包+日志 |
| 有 ACK 无网络 | 网关/DNS/路由错误 | `ip route`、option |

### 12.4 租约文件

```bash
ls -lh /var/lib/dhcpd/dhcpd.leases
grep -nE 'lease |binding state|hardware ethernet|ends ' /var/lib/dhcpd/dhcpd.leases
```

- 同一地址可能有多个历史 lease 记录，以最新有效状态为准。
- 不要直接手工删除生产租约文件；先停止服务、备份并确认客户端影响。
- 租约文件异常增长可能表示短租约或客户端反复上线。
- 地址冲突要结合 ARP、交换机 DHCP Snooping 和租约记录确认。

### 12.5 决策树

```text
客户端无 IP
  ├─ 有 Discover 吗？没有 → 客户端连接/NM/广播/网卡
  ├─ server 收到吗？没有 → VLAN/relay/防火墙/接口
  ├─ server 发 Offer 吗？没有 → 作用域/池/租约
  ├─ client 发 Request 吗？没有 → 客户端或第二 DHCP
  ├─ server 发 ACK 吗？没有 → 配置、路由、地址冲突
  └─ 有 ACK 无地址 → 客户端管理器安装租约失败
```

## §13 多网卡场景：监听接口与路由

### 13.1 多网卡风险

- DHCP 默认可能尝试监听所有接口；不需要服务的接口会产生告警或暴露服务。
- 一台服务器服务多个网段时，必须为每个网段写 `subnet`。
- 只有直连接口能直接接收广播；远端网段需要 relay。
- 默认路由决定回复走向，静态路由决定远端 relay 是否可达。
- 防火墙规则应限制可信接口和网段，不要笼统开放所有网卡。

### 13.2 DHCPDARGS 控制接口

```bash
vim /etc/sysconfig/dhcpd
DHCPDARGS=ens33
systemctl restart dhcpd
ss -lunp | grep ':67'
```

- 某些版本由 systemd 单元参数或 NetworkManager 管理，先查看 `systemctl cat dhcpd`。
- 接口名必须真实存在且 UP。
- relay 不一定要运行 dhcpd；使用 dhcrelay 时避免两个服务抢 UDP 67。

### 13.3 多网卡验证

```bash
ip -br addr
ip route
ip route get 10.1.1.20
systemctl status dhcpd dhcrelay --no-pager
ss -lunp | grep -E ':67|:68'
```

- 目标地址的路由出口、下一跳、接口都应与拓扑一致。
- ping 只能验证 IP 路由，不代表 UDP DHCP 放行。
- 需要时分别在每个接口抓包，而不是只抓 `any`。

### 13.4 监听安全

- DHCP 服务器只应在客户端所在的受控接口监听。
- 无关接口仍需在防火墙层阻断 67/68，形成纵深防御。
- 多租户环境把作用域、接口和 VLAN 映射写入变更记录。
- 修改 DHCPDARGS 后先保存旧值，语法通过再重启服务。

## §14 实验配置：单作用域、中继、保留地址

### 14.1 实验 A：单作用域自动分配

#### 14.1.1 拓扑

```text
vmnet8 / 10.1.8.0/24
  dhcp-server  10.1.8.10/24（静态）
  dhcp-client1 自动获取（普通员工）
  dhcp-client2 后续做 MAC 保留（经理）
  网关         10.1.8.2
```

目标：client1 从 `10.1.8.101-10.1.8.130` 取得地址、网关和 DNS。

#### 14.1.2 服务器基础配置

```bash
nmcli connection modify ens33 ipv4.method manual \
  ipv4.addresses 10.1.8.10/24 ipv4.gateway 10.1.8.2 \
  ipv4.dns 10.1.8.2 autoconnect yes
nmcli connection up ens33
hostnamectl set-hostname dhcp-server
ip addr show ens33
yum install -y dhcp
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload
```

#### 14.1.3 主配置

```conf
# /etc/dhcp/dhcpd.conf
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.130;
  option subnet-mask 255.255.255.0;
  option domain-name-servers 223.5.5.5;
  option domain-name "laogao.cloud";
  option routers 10.1.8.2;
  option broadcast-address 10.1.8.255;
  default-lease-time 600;
  max-lease-time 7200;
}
```

#### 14.1.4 启动与客户端

```bash
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl enable dhcpd --now
systemctl status dhcpd --no-pager
ss -lunp | grep ':67'
```

```bash
hostnamectl set-hostname dhcp-client1
nmcli connection add con-name dhcp-client1 type ethernet \
  ipv4.method auto ifname ens33
nmcli connection up dhcp-client1
ip addr show ens33
ip route
cat /etc/resolv.conf
dhclient -r ens33
dhclient -v ens33
```

预期：获得池内地址，`valid_lft` 接近 600 秒，默认路由为 `10.1.8.2`。

### 14.2 实验 B：MAC 保留地址

#### 14.2.1 查看 MAC

```bash
hostnamectl set-hostname dhcp-client2
ip link show ens33
# 示例：00:0c:29:9d:fe:6e
```

#### 14.2.2 追加 host 声明

```conf
host client-manager {
  hardware ethernet 00:0c:29:9d:fe:6e;
  fixed-address 10.1.8.88;
}
```

- `.88` 不放入动态池。
- MAC 必须从 client2 当前接口读取，不要复用已经失效的示例 MAC。

#### 14.2.3 重启与验证

```bash
# server
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl restart dhcpd
# client2
nmcli connection add con-name dhcp-client2 type ethernet \
  ipv4.method auto ifname ens33
nmcli connection up dhcp-client2
dhclient -r ens33
dhclient -v ens33
ip addr show ens33
```

预期：client2 获得 `10.1.8.88/24`；这是 DHCP 发放的固定租约，仍应在租约记录中可追踪。

### 14.3 实验 C：DHCP Relay 跨网段

#### 14.3.1 拓扑

```text
server ens33 10.1.8.10/24 ── vmnet8 ── relay ens33 10.1.8.20/24
                                              relay ens160 10.1.1.20/24 ── vmnet1 ── client
```

关闭 vmnet1、vmnet8 自带 DHCP，只保留 ISC dhcpd。

#### 14.3.2 server 端配置

```conf
subnet 10.1.8.0 netmask 255.255.255.0 {
  range 10.1.8.101 10.1.8.200;
  option routers 10.1.8.20;
  option broadcast-address 10.1.8.255;
  option domain-name-servers 223.5.5.5;
  option domain-search "laogao.cloud";
  default-lease-time 600;
  max-lease-time 7200;
}
subnet 10.1.1.0 netmask 255.255.255.0 {
  range 10.1.1.101 10.1.1.200;
  option routers 10.1.1.20;
  option broadcast-address 10.1.1.255;
  option domain-name-servers 223.5.5.5;
  option domain-search "laogao.cloud";
  default-lease-time 600;
  max-lease-time 7200;
}
```

```bash
dhcpd -t && systemctl enable dhcpd --now
nmcli connection modify ens160 ipv4.routes '10.1.1.20/32 10.1.8.20'
nmcli connection up ens160
ip route get 10.1.1.20
```

#### 14.3.3 relay 端配置

```bash
yum install -y dhcp
cp /usr/lib/systemd/system/dhcrelay.service /etc/systemd/system/dhcrelay.service
```

```ini
# /etc/systemd/system/dhcrelay.service
[Unit]
Description=DHCP Relay Agent Daemon
Documentation=man:dhcrelay(8)
Wants=network-online.target
After=network-online.target
[Service]
Type=notify
ExecStart=/usr/sbin/dhcrelay -d --no-pid 10.1.8.10
StandardError=null
[Install]
WantedBy=multi-user.target
```

```bash
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
systemctl daemon-reload
systemctl enable dhcrelay.service --now
systemctl status dhcrelay.service --no-pager
```

#### 14.3.4 端到端验证

```bash
# relay
ip -br addr
ip route
ss -lunp | grep ':67'
tcpdump -ni any -vvv 'udp port 67 or udp port 68'
# server（另一个终端）
tcpdump -ni ens33 -vvv 'udp port 67 or udp port 68'
# client
nmcli connection add type ethernet ifname ens160 con-name dynamic ipv4.method auto
nmcli connection up dynamic
ip addr show ens160
ip route
```

预期：client 从 `10.1.1.101-200` 获得地址；server 抓包看到 relay 的 `giaddr=10.1.1.20`；网关为 `10.1.1.20`。

### 14.4 实验 D：华为 VRP DHCP 地址池

《dhcp实验.pdf》展示了华为路由器 R1 的全局地址池，作为服务器型 DHCP 的对比实验。

```text
R1 Ethernet0/0/0：192.168.1.254/24
地址池 net1：192.168.1.0/24
PC1：192.168.1.253
PC2：192.168.1.252
DNS：223.5.5.5
```

```text
<Huawei> system-view
[Huawei] undo info-center enable
[Huawei] sysname R1
[R1] interface Ethernet0/0/0
[R1-Ethernet0/0/0] ip address 192.168.1.254 24
[R1-Ethernet0/0/0] quit
[R1] dhcp enable
[R1] ip pool net1
[R1-ip-pool-net1] network 192.168.1.0 mask 24
[R1-ip-pool-net1] gateway-list 192.168.1.254
[R1-ip-pool-net1] dns-list 223.5.5.5
[R1-ip-pool-net1] quit
[R1] interface Ethernet0/0/0
[R1-Ethernet0/0/0] dhcp select global
```

- `dhcp enable` 开启设备 DHCP 功能。
- `ip pool net1` 创建地址池，`network` 定义网段。
- `gateway-list`、`dns-list` 对应 ISC dhcpd 的 option 3、option 6。
- `dhcp select global` 让接口调用全局池。
- PC1/PC2 自动获取地址后，互相 ping 验证连通。

## §15 易错点 ×10

### 1. `subnet` 与服务器接口网段不匹配

- 错误：服务器 `10.1.8.10/24`，却只声明 `10.1.9.0/24`。
- 结果：dhcpd 可能启动但不响应该接口 Discover。
- 修正：直连声明 `10.1.8.0/24`；中继额外声明远端网段。
- 检查：`ip addr`、`ip route`、`dhcpd -t`、日志。

### 2. `range` 包含网络/广播或网关

- 错误：池写成 `10.1.8.1-10.1.8.255`。
- 结果：分配不可用地址，甚至与网关冲突。
- 修正：排除 `.0`、`.255`、服务器、网关和静态设备。
- 检查：逐个计算起止地址是否同一子网。

### 3. `option routers` 写错网段

- 错误：`10.1.1.0/24` 客户端得到 `10.1.8.2`。
- 结果：有 IP 但默认路由不可达。
- 修正：每个 subnet 使用该网段真实网关或 relay 接口。
- 检查：客户端 `ip route` 和 ACK 的 option 3。

### 4. VMware 自带 DHCP 未关闭

- 错误：vmnet8 同时运行 VMware DHCP 和 ISC dhcpd。
- 结果：多个 Offer，网关和地址随机。
- 修正：关闭对应虚拟网络自带 DHCP。
- 检查：抓包比较多个 server identifier。

### 5. 忘记防火墙规则

- 错误：启动服务但未放行 UDP 67/68。
- 结果：本机监听，客户端看不到 Offer/ACK。
- 修正：永久放行 dhcp 后 reload。
- 检查：`firewall-cmd --list-services` 和两端抓包。

### 6. 改完未做语法验证

- 错误：漏分号或括号后直接 restart。
- 结果：服务停止，影响已有客户端续租。
- 修正：`dhcpd -t -cf /etc/dhcp/dhcpd.conf` 后 reload。
- 检查：systemd 状态中的错误行号。

### 7. 保留 MAC 写错或克隆后变化

- 错误：`hardware ethernet` 使用旧虚拟机 MAC。
- 结果：固定地址不生效，客户端从动态池取地址。
- 修正：目标机重新执行 `ip link show ens33`。
- 检查：抓包 `chaddr` 与配置逐字符比较。

### 8. 固定地址落在动态池内

- 错误：`fixed-address 10.1.8.110`，range 是 `.101-.130`。
- 结果：普通客户端和固定客户端争用地址。
- 修正：从池中排除 fixed-address。
- 检查：维护地址规划表并复核重叠。

### 9. Relay 缺少远端作用域或返回路由

- 错误：服务器只配 `10.1.8.0/24`，无 `10.1.1.0/24` 或返回路由。
- 结果：收到 Discover 不分配，或 ACK 回不去。
- 修正：增加远端 subnet，检查 `giaddr` 和路由。
- 检查：relay/server 两侧同时 tcpdump。

### 10. 多个 DHCP 客户端管理器并行运行

- 错误：NetworkManager、dhclient、dhcpcd 同时管理网卡。
- 结果：重复请求、租约覆盖、地址频繁变化。
- 修正：明确网络管理者，只启用一种 DHCP 客户端。
- 检查：进程列表和 NM 连接状态。

## §16 速查表

### 16.1 端口、路径、服务

| 项目 | 值 |
|---|---|
| DHCPv4 server | UDP 67 |
| DHCPv4 client | UDP 68 |
| 主配置 | `/etc/dhcp/dhcpd.conf` |
| 示例 | `/usr/share/doc/dhcp-*/dhcpd.conf.example` |
| 租约 | `/var/lib/dhcpd/dhcpd.leases` |
| 常见日志 | `/var/log/messages` |
| systemd 日志 | `journalctl -u dhcpd` |
| 服务 | `dhcpd` |
| 中继 | `dhcrelay` |
| 语法 | `dhcpd -t -cf /etc/dhcp/dhcpd.conf` |
| 监听 | `ss -lunp | grep ':67'` |

### 16.2 DORA

```text
Discover：客户端广播，寻找服务
Offer：服务器报价，携带 yiaddr/options
Request：客户端广播选择 server identifier
ACK：服务器确认租约；失败为 NAK
```

### 16.3 dhcpd 配置骨架

```conf
default-lease-time 600;
max-lease-time 7200;
subnet NETWORK netmask MASK {
  range START END;
  option subnet-mask MASK;
  option routers GATEWAY;
  option domain-name-servers DNS1, DNS2;
  option broadcast-address BROADCAST;
}
host NAME {
  hardware ethernet MAC;
  fixed-address IP;
}
```

### 16.4 常用命令

```bash
dhcpd -t
systemctl enable dhcpd --now
systemctl restart dhcpd
systemctl status dhcpd
journalctl -u dhcpd -f
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload
ss -lunp | grep ':67'
tcpdump -ni ens33 'udp port 67 or udp port 68'
dhclient -r ens33
dhclient -v ens33
ip addr
ip route
cat /etc/resolv.conf
```

### 16.5 Option 编号记忆

```text
1 掩码，3 路由，6 DNS，15 域名，28 广播
42 NTP，51 租约，54 服务器标识，58 T1，59 T2
66 启动服务器，67 启动文件，119 搜索域
```

## §17 面试 6 大追问

### 追问 1：DORA 为什么是四步，Offer 后为什么还要广播 Request？

**答**：Discover 找服务器，Offer 报价，Request 广播选择，ACK 确认租约。Request 广播是让所有候选服务器知道客户端选择了哪个 `server identifier`，未被选中的服务器回收暂存地址。

### 追问 2：DHCP 为什么通常使用广播？如何跨网段？

**答**：客户端初始没有 IP，Discover 使用 `0.0.0.0:68` 到 `255.255.255.255:67`。普通路由器不转发有限广播，因此跨网段需要 DHCP Relay。Relay 用 `giaddr` 标记客户端网段，服务器据此选择 subnet。

### 追问 3：T1 和 T2 分别做什么？

**答**：T1 默认租期 50%，客户端向原服务器单播续租；T2 默认 87.5%，原服务器无响应时广播 Request，任意可达服务器可续租。到期仍无 ACK，客户端停止使用并重新 DORA。

### 追问 4：option routers、DNS 和 subnet 的关系是什么？

**答**：`subnet` 决定作用域和地址池；option 1/3/6 决定客户端网络参数。`option routers` 应是该网段可达网关，DNS 只负责名字解析，不负责转发。写错分别表现为无 Offer、无法出网、无法解析。

### 追问 5：固定 IP 与静态配置有什么区别？

**答**：`host` + `fixed-address` 仍是客户端通过 DHCP 获取地址，服务器按 MAC 每次发同一个地址，集中管理并有租约记录。静态配置由客户端本地手工设置，不经过 DHCP。固定地址应避开动态池并确保 MAC 唯一。

### 追问 6：如何定位客户端拿不到 IP？

**答**：先确认客户端有 Discover，再用 server/relay 两端 tcpdump 判断是否到达；查语法、服务、监听、防火墙、vmnet 第二 DHCP。Offer 无 Request 查客户端和竞争 DHCP；Request 无 ACK 查作用域、池、租约和路由；ACK 无地址查客户端管理器。

---

## 链路与延伸

- [[Linux网络#dhcp基础]]：网络设备、地址和路由基础。
- [[LinuxDNS#dhcp-dns联动]]：DHCP 下发 DNS 与动态解析的联动。
- [[路由与VLAN#dhcp中继]]：VLAN 间三层网关和 relay 的关系。
- [[Linux防火墙#firewalld服务]]：firewalld 放行与永久规则。
- [[Linux日志与时间#journalctl]]：用 journalctl 追踪 dhcpd 服务。

> **来源说明**：PDF 原文抽取存在分页/图片文字缺失，命令与配置按原教材地址和 CentOS 7 语境校正；华为 VRP 实验保留为独立对比章节。生产环境上线前以目标版本 man page、服务单元和拓扑复核。

### 安装前检查清单

- [ ] 1. 服务器主机名已设为 dhcp-server
  - 证据：____________________
  - 备注：____________________
- [ ] 2. 服务器网卡使用静态 IPv4 地址
  - 证据：____________________
  - 备注：____________________
- [ ] 3. 网卡带 BROADCAST 标志
  - 证据：____________________
  - 备注：____________________
- [ ] 4. 网关地址在服务器网段内
  - 证据：____________________
  - 备注：____________________
- [ ] 5. 动态池未包含服务器和网关
  - 证据：____________________
  - 备注：____________________
- [ ] 6. 虚拟网络自带 DHCP 已关闭
  - 证据：____________________
  - 备注：____________________
- [ ] 7. 所有客户端网卡名称已确认
  - 证据：____________________
  - 备注：____________________
- [ ] 8. 中继场景两侧接口均 UP
  - 证据：____________________
  - 备注：____________________
- [ ] 9. 防火墙策略已记录
  - 证据：____________________
  - 备注：____________________
- [ ] 10. 地址规划表已确认
  - 证据：____________________
  - 备注：____________________

### 配置审核清单

- [ ] 1. 每条语句以分号结束
  - 证据：____________________
  - 备注：____________________
- [ ] 2. 每个 subnet 都有 netmask
  - 证据：____________________
  - 备注：____________________
- [ ] 3. 每个动态池起止地址顺序正确
  - 证据：____________________
  - 备注：____________________
- [ ] 4. range 没有跨网段
  - 证据：____________________
  - 备注：____________________
- [ ] 5. option routers 属于对应网段
  - 证据：____________________
  - 备注：____________________
- [ ] 6. 广播地址与掩码一致
  - 证据：____________________
  - 备注：____________________
- [ ] 7. DNS 地址确实可达
  - 证据：____________________
  - 备注：____________________
- [ ] 8. default-lease-time 单位为秒
  - 证据：____________________
  - 备注：____________________
- [ ] 9. max-lease-time 不小于默认租期
  - 证据：____________________
  - 备注：____________________
- [ ] 10. host 的 MAC 来自目标客户端
  - 证据：____________________
  - 备注：____________________
- [ ] 11. fixed-address 不在动态池中
  - 证据：____________________
  - 备注：____________________
- [ ] 12. 多 subnet 的网关没有混写
  - 证据：____________________
  - 备注：____________________
- [ ] 13. 中继远端 subnet 已声明
  - 证据：____________________
  - 备注：____________________
- [ ] 14. server identifier 对客户端可达
  - 证据：____________________
  - 备注：____________________
- [ ] 15. 配置文件权限可被 dhcpd 读取
  - 证据：____________________
  - 备注：____________________

### 验证结果记录模板

- [ ] 1. 记录执行时间和服务器地址
  - 证据：____________________
  - 备注：____________________
- [ ] 2. 记录 dhcpd 软件版本
  - 证据：____________________
  - 备注：____________________
- [ ] 3. 记录 dhcpd -t 返回码
  - 证据：____________________
  - 备注：____________________
- [ ] 4. 记录 systemctl status 摘要
  - 证据：____________________
  - 备注：____________________
- [ ] 5. 记录 UDP 67 监听进程
  - 证据：____________________
  - 备注：____________________
- [ ] 6. 记录客户端 MAC 地址
  - 证据：____________________
  - 备注：____________________
- [ ] 7. 记录 Discover 的事务 ID
  - 证据：____________________
  - 备注：____________________
- [ ] 8. 记录 Offer 的 yiaddr
  - 证据：____________________
  - 备注：____________________
- [ ] 9. 记录 Request 的 requested IP
  - 证据：____________________
  - 备注：____________________
- [ ] 10. 记录 ACK 的租约秒数
  - 证据：____________________
  - 备注：____________________
- [ ] 11. 记录客户端 IP 和 valid_lft
  - 证据：____________________
  - 备注：____________________
- [ ] 12. 记录客户端默认路由
  - 证据：____________________
  - 备注：____________________
- [ ] 13. 记录 resolv.conf 的 nameserver
  - 证据：____________________
  - 备注：____________________
- [ ] 14. 记录抓包文件名和过滤器
  - 证据：____________________
  - 备注：____________________
- [ ] 15. 记录异常与处理动作
  - 证据：____________________
  - 备注：____________________

### 日志关键词释义

- [ ] 1. DHCPDISCOVER 表示服务器收到发现
  - 证据：____________________
  - 备注：____________________
- [ ] 2. DHCPOFFER 表示服务器发出报价
  - 证据：____________________
  - 备注：____________________
- [ ] 3. DHCPREQUEST 表示客户端选择或续租
  - 证据：____________________
  - 备注：____________________
- [ ] 4. DHCPACK 表示租约确认
  - 证据：____________________
  - 备注：____________________
- [ ] 5. DHCPNAK 表示地址被拒绝
  - 证据：____________________
  - 备注：____________________
- [ ] 6. no free leases 表示池无可用地址
  - 证据：____________________
  - 备注：____________________
- [ ] 7. No subnet declaration 表示没有匹配网段
  - 证据：____________________
  - 备注：____________________
- [ ] 8. Not configured to listen 表示无监听接口
  - 证据：____________________
  - 备注：____________________
- [ ] 9. reuse_lease 表示尝试复用旧租约
  - 证据：____________________
  - 备注：____________________
- [ ] 10. uid lease 表示客户端标识参与匹配
  - 证据：____________________
  - 备注：____________________
- [ ] 11. via interface 表示报文到达接口
  - 证据：____________________
  - 备注：____________________
- [ ] 12. giaddr 表示中继网关地址
  - 证据：____________________
  - 备注：____________________
- [ ] 13. ends 表示租约终止时间
  - 证据：____________________
  - 备注：____________________
- [ ] 14. starts 表示租约起始时间
  - 证据：____________________
  - 备注：____________________
- [ ] 15. binding state active 表示租约有效
  - 证据：____________________
  - 备注：____________________

### 变更后回归测试

- [ ] 1. 先备份 dhcpd.conf
  - 证据：____________________
  - 备注：____________________
- [ ] 2. 执行 dhcpd -t
  - 证据：____________________
  - 备注：____________________
- [ ] 3. reload 后查看服务状态
  - 证据：____________________
  - 备注：____________________
- [ ] 4. 新客户端释放并重新请求
  - 证据：____________________
  - 备注：____________________
- [ ] 5. 固定客户端核对地址未变化
  - 证据：____________________
  - 备注：____________________
- [ ] 6. 旧客户端续租是否成功
  - 证据：____________________
  - 备注：____________________
- [ ] 7. 检查动态池是否仍有余量
  - 证据：____________________
  - 备注：____________________
- [ ] 8. 检查网关 ping 和路由表
  - 证据：____________________
  - 备注：____________________
- [ ] 9. 检查 DNS 查询结果
  - 证据：____________________
  - 备注：____________________
- [ ] 10. 中继客户端重复 DORA
  - 证据：____________________
  - 备注：____________________
- [ ] 11. 查看 server 和 relay 两端抓包
  - 证据：____________________
  - 备注：____________________
- [ ] 12. 查看 messages 是否报错
  - 证据：____________________
  - 备注：____________________
- [ ] 13. 清理临时抓包文件
  - 证据：____________________
  - 备注：____________________
- [ ] 14. 记录实际配置差异
  - 证据：____________________
  - 备注：____________________
- [ ] 15. 通知受影响的网络管理员
  - 证据：____________________
  - 备注：____________________
