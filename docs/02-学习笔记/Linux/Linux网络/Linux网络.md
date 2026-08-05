---
title: Linux 网络 — ip / ss / nmcli / DNS / ping 全攻略
desc: 基于 05.CentOS-7-系统管理-1/18. Linux 网络管理.pdf 的实操笔记。覆盖 OSI/TCP-IP 模型、设备命名、ip link/addr/route、ss 替代 netstat、/etc/services、ping/mtr、nmcli 网络配置、nmtui、/etc/resolv.conf。
type: 笔记
module: Linux网络
pdf: 05.18 网络管理.pdf
pdf_size: 951 行
scope: CentOS-7 (iproute2 + NetworkManager)
status: 完成
---

# Linux 网络 — ip / ss / nmcli / DNS / ping 全攻略

> **范围**：基于《CentOS-7 系统管理 1》第 18 章 整理。
> 覆盖 **OSI/TCP-IP 模型** + **网卡命名** + **ip 命令**（link/addr/route）+ **ss 替代 netstat** + **nmcli**（NetworkManager 命令行）+ **DNS 配置** + **ping/mtr 排查**。
>
> **适用**：CentOS-7 / RHEL 系（NetworkManager 管理）。

## 目录

- [[#§0 心智模型：网络 = 协议栈 + 设备 + 地址 + 路由]]
- [[#§1 OSI 7 层模型]]
- [[#§2 TCP/IP 4 层模型]]
- [[#§3 网卡命名规则：eno/enp/ens/eth]]
- [[#§4 ip link 看网卡]]
- [[#§5 ip addr 看 IP]]
- [[#§6 ip route 看路由]]
- [[#§7 /etc/resolv.conf DNS 配置]]
- [[#§8 ping 测试连通性]]
- [[#§9 mtr 路由追踪]]
- [[#§10 /etc/services 端口对照表]]
- [[#§11 ss 替代 netstat]]
- [[#§12 ss 实战：查 ssh 连接]]
- [[#§13 端口占用排查]]
- [[#§14 NetworkManager 介绍]]
- [[#§15 nmtui 图形配置]]
- [[#§16 nmcli 命令大全]]
- [[#§17 nmcli 实战：静态 IP 配置]]
- [[#§18 nmcli 实战：DHCP 改静态]]
- [[#§19 ifcfg 配置文件]]
- [[#§20 速查表]]
- [[#§21 易错点 ×12]]
- [[#§22 面试 6 大追问]]
- [[#§23 链路]]

---

## §0 心智模型：网络 = 协议栈 + 设备 + 地址 + 路由

```
Linux 网络四大要素：

1. 设备（device）    网卡（ens32）、回环（lo）、桥（virbr0）
2. 地址（address）   IP 地址 + 子网掩码
3. 路由（route）     数据包往哪发
4. DNS（resolver）   域名 → IP 翻译
```

**网络栈层次**：
```
应用层（HTTP/DNS/SSH）
   ↓
传输层（TCP/UDP，端口号）
   ↓
网络层（IP，路由）
   ↓
链路层（MAC，网卡驱动）
   ↓
物理层（光缆、电缆）
```

---

## §1 OSI 7 层模型

| 层   | 名称        | 单位          | 协议 / 设备           | 例子        |
| --- | --------- | ----------- | ----------------- | --------- |
| 7   | **应用层**   | 数据          | HTTP/DNS/SSH/SMTP | curl, ssh |
| 6   | 表示层       | 数据          | SSL/TLS, JPEG     | 加密        |
| 5   | 会话层       | 数据          | NetBIOS, RPC      | 会话        |
| 4   | **传输层**   | 段 (Segment) | **TCP / UDP**     | 端口 80, 22 |
| 3   | **网络层**   | 包 (Packet)  | **IP / ICMP**     | IP 地址     |
| 2   | **数据链路层** | 帧 (Frame)   | **以太网 / ARP**     | MAC 地址    |
| 1   | **物理层**   | 比特          | 光纤、电缆             | 网线        |

> 💡 **面试题**：ping 用哪几层？
> 答：网络层（ICMP）+ 数据链路层（ARP）+ 物理层。

---

## §2 TCP/IP 4 层模型

```
OSI 7 层                TCP/IP 4 层
─────────────         ─────────────
应用层                  ┐
表示层                  ├─ 应用层
会话层                  ┘
传输层                  ── 传输层（TCP/UDP）
网络层                  ── 网络层（IP/ICMP）
数据链路层              ┐
物理层                  ├─ 链路层
                       ┘
```

**关键协议**：
- **TCP**：面向连接、可靠（三次握手）
- **UDP**：无连接、快（DNS、视频）
- **IP**：寻址 + 路由
- **ICMP**：ping / traceroute 用
- **ARP**：IP → MAC 映射

---

## §3 网卡命名规则：eno/enp/ens/eth

| 命名 | 含义 | 示例 |
|---|---|---|
| **eno1** | onboard（板载）| `eno1` |
| **enp0s3** | PCI 插槽 0，slot 3 | `enp0s3` |
| **ens33** | PCI 热插拔索引 33 | `ens33`, `ens192` |
| **eth0** | 老式（RHEL6）| `eth0`, `eth1` |
| **wlp3s0** | 无线 | `wlp3s0` |
| **virbr0** | 虚拟桥（KVM） | `virbr0` |
| **lo** | 回环 | `127.0.0.1` |

**规则**：
- 以太网：en（ethernet）
- 无线：wl（wireless）
- WWAN：ww（无线广域网）

> 💡 **RHEL7+ 默认是 biosdevname + net.ifnames**（eno/enp/ens）。
> 想用 eth0：`GRUB` 加 `net.ifnames=0 biosdevname=0`。

---

## §4 ip link 看网卡

```bash
# 简表（名字 + 状态 + MAC）
[root@centos7 ~]# ip -br link
lo          UNKNOWN  00:00:00:00:00:00  <LOOPBACK,UP,LOWER_UP>
ens32       UP       00:0c:29:38:6d:bd  <BROADCAST,MULTICAST,UP,LOWER_UP>
virbr0      DOWN     52:54:00:0f:b0:ac  <NO-CARRIER,BROADCAST,MULTICAST,UP>
virbr0-nic  DOWN     52:54:00:0f:b0:ac  <BROADCAST,MULTICAST>

# 详细
[root@centos7 ~]# ip link show ens32
2: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:0c:29:38:6d:bd brd ff:ff:ff:ff:ff:ff
# ↑ mtu = 最大传输单元（默认 1500 字节）
# ↑ UP = 链路启用，LOWER_UP = 物理连接
```

**常用操作**：

```bash
# 启用网卡
ip link set ens32 up

# 禁用网卡
ip link set ens32 down

# 改 MTU
ip link set ens32 mtu 9000

# 看网卡统计
ip -s link show ens32
```

---

## §5 ip addr 看 IP

```bash
# 简表
[root@centos7 ~]# ip -br a
lo           UNKNOWN  127.0.0.1/8 ::1/128
ens32        UP       10.1.8.10/24 fe80::6763:8ca5:3559:2caa/64
virbr0       DOWN     192.168.122.1/24

# 详细
[root@centos7 ~]# ip addr show ens32
2: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    link/ether 00:0c:29:38:6d:bd brd ff:ff:ff:ff:ff:ff
    inet 10.1.8.10/24 brd 10.1.8.255 scope global noprefixroute ens32
       valid_lft forever preferred_lft forever
    inet6 fe80::6763:8ca5:3559:2caa/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

**字段含义**：
- `inet` = IPv4
- `inet6` = IPv6
- `/24` = 子网掩码（255.255.255.0）
- `brd` = 广播地址
- `scope global` = 全局可用
- `scope link` = 仅链路本地

**加 IP**：

```bash
# 加 IP
[root@centos7 ~]# ip addr add 192.168.1.100/24 dev ens32

# 删 IP
[root@centos7 ~]# ip addr del 192.168.1.100/24 dev ens32

# 清空所有 IP
[root@centos7 ~]# ip addr flush dev ens32
```

---

## §6 ip route 看路由

```bash
# 看路由表
[root@centos7 ~]# ip route
default via 10.1.8.2 dev ens32 proto static metric 100
10.1.8.0/24 dev ens32 proto kernel scope link src 10.1.8.10 metric 100
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1
# ↑ default = 默认路由（去外网走 10.1.8.2 网关）
# ↑ 10.1.8.0/24 = 直连网络
```

**字段含义**：
- `default via 10.1.8.2`：默认网关
- `dev ens32`：从哪张网卡出
- `proto static`：静态配置
- `proto kernel`：内核自动添加
- `metric 100`：优先级（越小越优先）
- `scope link`：直连链路

**老命令**（net-tools，已废弃）：
```bash
[root@centos7 ~]# route -n        # 不解析名字
[root@centos7 ~]# netstat -nr     # 等价
```

**加路由**：

```bash
# 静态路由：去 192.168.50.0/24 走 10.1.8.2
[root@centos7 ~]# ip route add 192.168.50.0/24 via 10.1.8.2 dev ens32

# 删
[root@centos7 ~]# ip route del 192.168.50.0/24

# 默认路由
[root@centos7 ~]# ip route add default via 10.1.8.2
```

**路由判断示例**：
```
1. 10.1.8.0/24 是直连 → 直接发（ARP 找 MAC）
2. 0.0.0.0/0 是 default → 走 10.1.8.2 网关
```

---

## §7 /etc/resolv.conf DNS 配置

```bash
[root@centos7 ~]# cat /etc/resolv.conf
# Generated by NetworkManager
search xkw.cloud                  # 默认搜索域
nameserver 223.5.5.5              # 阿里 DNS（首选）
nameserver 223.6.6.6              # 阿里 DNS（备）
```

**字段**：
- `search`：单 hostname 搜索（ping foo 会试 foo.xkw.cloud）
- `nameserver`：DNS 服务器 IP（最多 3 个）
- `domain`：老字段，search 替代
- `sortlist`：返回结果的优先级

**公共 DNS**：
```
阿里：223.5.5.5 / 223.6.6.6
114：114.114.114.114 / 114.114.115.115
谷歌：8.8.8.8 / 8.8.4.4
Cloudflare：1.1.1.1 / 1.0.0.1
```

**测试 DNS**：
```bash
[root@centos7 ~]# nslookup baidu.com
[root@centos7 ~]# dig baidu.com
[root@centos7 ~]# host baidu.com
```

> ⚠️ `/etc/resolv.conf` 默认被 NetworkManager 管，不要手改。
> 改 NetworkManager 的 connection 配置，让它重写。

---

## §8 ping 测试连通性

```bash
# 基本（一直 ping）
[root@centos7 ~]# ping baidu.com
PING baidu.com (110.242.68.66) 56(84) bytes of data.
64 bytes from 110.242.68.66 (110.242.68.66): icmp_seq=1 ttl=128 time=34.1 ms
...

# 限定 4 次（-c）
[root@centos7 ~]# ping baidu.com -c 4

# 限定超时（-w 秒）
[root@centos7 ~]# ping baidu.com -c 4 -w 2

# 不解析名字（-n）
[root@centos7 ~]# ping -n 8.8.8.8

# 指定包大小
[root@centos7 ~]# ping -s 1024 baidu.com

# 实战：3 步排错
# 1) ping 自己（网卡是否工作）
ping 127.0.0.1
# 2) ping 网关（局域网是否通）
ping 10.1.8.2
# 3) ping 外网（路由是否对）
ping 8.8.8.8
# 4) ping 域名（DNS 是否对）
ping baidu.com
```

---

## §9 mtr 路由追踪

```
mtr = My Traceroute（更好的 traceroute）
  - 实时追踪每一跳
  - 显示丢包率
  - 比 traceroute 直观
```

```bash
# 安装
[root@centos7 ~]# yum install -y mtr

# 用法（-n 不解析名字，-r 报告模式）
[root@centos7 ~]# mtr -n 1.1.1.1

# 输出示例
HOST: centos7                      Loss%  Snt   Last   Avg  Best  Wrst StDev
  1. 10.1.8.2                       0.0%   10    0.5   0.4   0.3   0.5   0.0
  2. ???
  3. 61.135.169.121                 0.0%   10    5.2   5.5   4.8   7.1   0.8
  4. 202.97.10.221                  0.0%   10   35.1  35.3  34.8  36.5   0.5
  ...
# ↑ Loss% 高 = 该节点丢包
```

---

## §10 /etc/services 端口对照表

```bash
[root@server ~]# vim /etc/services
...
ftp-data      20/tcp
ftp           21/tcp                  # File Transfer [Control]
ssh           22/tcp                  # The Secure Shell (SSH) Protocol
telnet        23/tcp
domain        53/tcp                  # name-domain server
http          80/tcp   www www-http   # WorldWideWeb HTTP
https         443/tcp                 # http protocol over TLS/SSL
mysql         3306/tcp                # MySQL
...
```

> 💡 **/etc/services** 让 `ss -ln` 显示服务名（如 :ssh 不用记 :22）。

---

## §11 ss 替代 netstat

```
ss = Socket Statistics
  iproute2 包提供（替代 net-tools 的 netstat）
  更快、信息更多
```

### 11.1 常用选项

| 选项 | 含义 |
|---|---|
| `-a` | 所有（LISTEN + 非 LISTEN） |
| `-l` | 只 LISTEN（监听） |
| `-n` | 不解析名字（数字端口） |
| `-p` | 显示进程 |
| `-t` | TCP |
| `-u` | UDP |
| `-x` | Unix socket |
| `-4` / `-6` | IPv4 / IPv6 |
| `-s` | 统计摘要 |

### 11.2 实战：查 SSH 连接

```bash
# 所有 ssh 状态
[root@server ~]# ss | grep :ssh
tcp ESTAB  0  0   10.1.8.10:ssh   10.1.8.1:60081    # 已建立
tcp ESTAB  0  36  10.1.8.10:ssh   10.1.8.1:60229    # 已建立

# 只看 LISTEN
[root@server ~]# ss -l | grep :ssh
tcp LISTEN 0  128  0.0.0.0:ssh     0.0.0.0:*         # IPv4 监听
tcp LISTEN 0  128  [::]:ssh        [::]:*             # IPv6 监听

# 只 IPv4
[root@server ~]# ss -a4 | grep :ssh
tcp LISTEN 0  128  0.0.0.0:22      0.0.0.0:*
tcp ESTAB 0  0    10.1.8.10:22     10.1.8.1:60081
tcp ESTAB 0  36   10.1.8.10:22     10.1.8.1:60229

# 不解析名字（-n）
[root@server ~]# ss -an4 | grep :22
tcp LISTEN 0  128  0.0.0.0:22      0.0.0.0:*

# 看进程（-p）
[root@server ~]# ss -lnp4 | grep :22
tcp LISTEN 0  128  0.0.0.0:22      0.0.0.0:*
       users:(("sshd",pid=3186,fd=3))
# ↑ 哪个进程在监听
```

---

## §12 ss 实战：查 ssh 连接

```bash
# 统计摘要
[root@server ~]# ss -s
TCP:   10 (estab 2, closed 0, orphaned 0, timewait 0)
Transport Total     IP        IPv6
RAW       0         0         0
UDP       5         3         2
TCP       10        7         3
...

# 看所有 ESTAB（已建立）
ss -tan state established

# 看所有 TIME-WAIT
ss -tan state time-wait | head

# 看某端口的连接
ss -tan dport = :80    # 所有连到 80 端口的
ss -tan sport = :22    # 所有从 22 端口出去的
```

---

## §13 端口占用排查

```bash
# 场景：httpd 启动失败，端口被占用
[root@server ~]# systemctl start httpd
Job for httpd.service failed...
# Job for httpd.service failed because the control process exited with error code.

# 1) 看 journalctl
journalctl -xe | grep httpd
# AH00072: make_sock: could not bind to address [::]:80

# 2) 看 80 端口谁占用
[root@server ~]# ss -lnp4 | grep :80
tcp LISTEN 0  511  0.0.0.0:80  0.0.0.0:*  users:(("nginx",pid=14009,fd=6))
# ↑ nginx 占着 80 端口！

# 3) 关掉 nginx（如果 httpd 更重要）
[root@server ~]# systemctl stop nginx
[root@server ~]# systemctl start httpd
```

**常见错误对照**：

| 错误 | 原因 | 解决 |
|---|---|---|
| `Address already in use` | 端口被占 | `ss -lnp` 找凶手 |
| `No route to host` | 网关/路由错 | `ip route` 检查 |
| `Permission denied`（bind 时）| 端口 < 1024 需 root | 用 sudo |
| `Connection refused` | 服务没启 | `systemctl status` |

---

## §14 NetworkManager 介绍

```
NetworkManager (NM) = CentOS-7 网络管理器
  - 服务：NetworkManager
  - 命令：nmcli / nmtui
  - 配置文件：/etc/sysconfig/network-scripts/ifcfg-*

两种配置方式：
  1. 命令：nmcli（推荐）
  2. 文件：直接改 ifcfg-*

两种访问方式：
  1. 命令行：nmcli
  2. 图形：nmtui / GNOME 网络设置
```

**常用**：
- `vmware workstations`：NAT / DHCP 模式用 NetworkManager
- 容器 / 服务器：可能不用 NM（直接 ifcfg）

---

## §15 nmtui 图形配置

```bash
# 启动图形配置（伪图形，TUI）
[root@centos7 ~]# nmtui

# 操作：Tab 切换、方向键、回车确认
# 可视化配置 IP/网关/DNS
```

---

## §16 nmcli 命令大全

### 16.1 网络开关

```bash
# 关 NetworkManager 管理
[root@server ~]# nmcli networking off
# activated → deactivating → disconnected → unmanaged → unavailable

# 开
[root@server ~]# nmcli networking on
# unavailable → disconnected → auto-activating
```

### 16.2 设备管理

```bash
# 看所有设备
[root@server ~]# nmcli device
DEVICE  TYPE      STATE      CONNECTION
ens160  ethernet  connected  ens160
ens192  ethernet  connected  ens192
virbr0  bridge    disconnected  --
lo      loopback  unmanaged  --

# 详细
[root@server ~]# nmcli device show ens192
GENERAL.DEVICE:                ens192
GENERAL.TYPE:                  ethernet
GENERAL.HWADDR:                00:0C:29:08:CF:C7
GENERAL.MTU:                   1500
GENERAL.STATE:                 100 (connected)
GENERAL.CONNECTION:            ens192
IP4.ADDRESS[1]:                10.1.8.10/24
IP4.GATEWAY:                   10.1.8.2
IP4.DNS[1]:                    223.5.5.5
IP4.DNS[2]:                    114.114.114.114
IP6.ADDRESS[1]:                fe80::20c:29ff:fe08:cfc7/64

# 断开
[root@server ~]# nmcli device disconnect ens192

# 连接
[root@server ~]# nmcli device connect ens192
```

### 16.3 连接管理

```bash
# 看所有连接
[root@server ~]# nmcli connection
NAME       UUID                                  TYPE      DEVICE
ens160     5f61d96b-a284-41e9-9bf6-5cf3de6250cd ethernet  ens160
ens192     0f5eac2c-9a92-494e-9cca-f97230d2314a ethernet  ens192

# 删除
[root@server ~]# nmcli connection delete ens192

# 新建（DHCP）
[root@server ~]# nmcli connection add type ethernet ifname ens192 con-name ens192-dynamic
# 默认 ipv4.method = auto（DHCP）

# 新建（静态）
[root@server ~]# nmcli connection add type ethernet ifname ens192 con-name ens192-static \
  ipv4.method manual ipv4.addresses 10.1.8.10/24
```

### 16.4 启停 / 重载

```bash
# 启用连接（up）
[root@server ~]# nmcli connection up ens192-static

# 停用
[root@server ~]# nmcli connection down ens192-static

# 重载
[root@server ~]# nmcli connection reload
```

### 16.5 修改配置

```bash
# 改 IPv4 为 manual + 静态 IP
[root@server ~]# nmcli connection modify ens192-static \
  ipv4.method manual \
  ipv4.addresses 10.1.8.10/24 \
  ipv4.gateway 10.1.8.2 \
  ipv4.dns 10.1.8.2

# 加静态路由
[root@server ~]# nmcli connection modify ens192-static \
  ipv4.routes "192.168.50.0/24 10.1.8.2"

# 应用
[root@server ~]# nmcli connection up ens192-static
```

---

## §17 nmcli 实战：静态 IP 配置

### 场景：DHCP 改静态 IP

```bash
# 1) 看现有连接
[root@server ~]# nmcli connection
NAME       UUID                                  TYPE      DEVICE
ens192     0f5eac2c-9a92-494e-9cca-f97230d2314a ethernet  ens192

# 2) 改配置
[root@server ~]# nmcli connection modify ens192 \
  ipv4.method manual \
  ipv4.addresses 10.1.8.10/24 \
  ipv4.gateway 10.1.8.2 \
  ipv4.dns 223.5.5.5,223.6.6.6

# 3) 激活
[root@server ~]# nmcli connection up ens192

# 4) 验证
[root@server ~]# ip -br addr show ens192
ens192 UP  10.1.8.10/24
```

---

## §18 nmcli 实战：DHCP 改静态

```bash
# 之前 DHCP 现在要静态
[root@server ~]# nmcli connection modify ens192-dynamic ipv4.method auto

# 改回 DHCP
[root@server ~]# nmcli connection modify ens192-static ipv4.method auto
```

---

## §19 ifcfg 配置文件

NetworkManager 把配置写到：

```bash
# /etc/sysconfig/network-scripts/ifcfg-ens192
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOWSER=no
BOOTPROTO=dhcp              # 或 static（手动配静态）
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
NAME=ens192
UUID=0f5eac2c-9a92-494e-9cca-f97230d2314a
DEVICE=ens192
ONBOOT=yes
IPADDR=10.1.8.10            # 静态 IP（BOOTPROTO=static 时有）
PREFIX=24
GATEWAY=10.1.8.2
DNS1=223.5.5.5
DNS2=223.6.6.6
```

**手改后必须重启连接**：
```bash
[root@server ~]# nmcli connection reload
[root@server ~]# nmcli connection up ens192
# 或
[root@server ~]# systemctl restart NetworkManager
```

**关键字段**：
```
BOOTPROTO=dhcp|static|none
ONBOOT=yes|no          # 开机是否启用
IPADDR=10.1.8.10
PREFIX=24
GATEWAY=10.1.8.2
DNS1=223.5.5.5
```

---

## §20 速查表

### 20.1 ip 命令

```bash
# 看
ip -br link                  # 网卡简表
ip link show ens32           # 网卡详细
ip -br addr                  # IP 简表
ip addr show ens32           # IP 详细
ip route                     # 路由表
ip -s link show ens32        # 网卡统计

# 改
ip link set ens32 up/down
ip link set ens32 mtu 9000
ip addr add 192.168.1.100/24 dev ens32
ip addr del 192.168.1.100/24 dev ens32
ip route add 192.168.50.0/24 via 10.1.8.2
ip route del 192.168.50.0/24
```

### 20.2 ss 命令

```bash
ss                 # 默认（ESTAB 等）
ss -a              # 所有
ss -l              # LISTEN
ss -n              # 不解析名字
ss -p              # 显示进程
ss -t              # TCP
ss -u              # UDP
ss -4              # IPv4
ss -6              # IPv6
ss -s              # 统计
ss -tan state established    # 过滤状态
ss -tan dport = :80           # 目标端口
ss -tan sport = :22           # 源端口
```

### 20.3 排错

```bash
# 3 步排错
ping 127.0.0.1       # 网卡工作？
ping 10.1.8.2        # 网关通？
ping 8.8.8.8         # 外网通？
ping baidu.com       # DNS 对？

# 端口占用
ss -lnp4 | grep :80
lsof -i :80          # 也能查

# DNS 排错
nslookup baidu.com
dig baidu.com
host baidu.com

# 路由追踪
mtr -n 8.8.8.8
traceroute 8.8.8.8
```

### 20.4 nmcli 命令

```bash
# 总体
nmcli networking off/on       # NM 开关
nmcli general status          # NM 状态

# 设备
nmcli device                  # 看
nmcli device show ens192      # 详细
nmcli device disconnect ens192
nmcli device connect ens192

# 连接
nmcli connection              # 看
nmcli connection show ens192  # 详细
nmcli connection add ...      # 新建
nmcli connection delete ens192
nmcli connection up ens192    # 启用
nmcli connection down ens192  # 停用
nmcli connection modify ens192 ipv4.method manual ipv4.addresses 10.1.8.10/24
```

---

## §21 易错点 ×12

### 1. ❌ 用 netstat 但未装 net-tools

```bash
netstat -nr    # CentOS-7 默认不装
# 用 ss / ip route 替代
```

### 2. ❌ 直接改 /etc/resolv.conf

```bash
# 会被 NetworkManager 覆盖
# 改 nmcli connection 的 ipv4.dns
```

### 3. ❌ nmcli 修改后忘 up

```bash
nmcli connection modify ens192 ipv4.addresses ...
# ⚠️ 没 up 不生效
nmcli connection up ens192
```

### 4. ❌ ONBOOT=no 启动没 IP

```bash
# 开机时网卡没启用
vim /etc/sysconfig/network-scripts/ifcfg-ens192
ONBOOT=yes    ← 必须 yes
```

### 5. ❌ ping 不到自己是网卡没启

```bash
ping 127.0.0.1
# 如果通 → 网卡本身没问题
# 不通 → lo 可能挂了，重启
```

### 6. ❌ 改了 IP 忘改 DNS

```bash
# 配了 IP 但忘了配 nameserver → 域名解析失败
nmcli connection modify ens192 ipv4.dns 223.5.5.5
```

### 7. ❌ ping 域名不通但 IP 通 = DNS 问题

```bash
ping 8.8.8.8      # 通
ping baidu.com    # 不通
# 解：查 /etc/resolv.conf 或 nmcli dns
```

### 8. ❌ fping 没用上

```bash
# 想批量 ping 多个主机
fping -g 10.1.8.0/24
# （fping 工具）
```

### 9. ❌ ss 看到 LISTEN 但连不上

```bash
# 可能是防火墙挡了！
# 查防火墙
firewall-cmd --list-all
# 或
iptables -L -n
```

### 10. ❌ BOOTPROTO=dhcp 配静态 IP

```bash
# BOOTPROTO=dhcp 时 IPADDR 无效
BOOTPROTO=static
IPADDR=10.1.8.10
PREFIX=24
```

### 11. ❌ 误删 connection

```bash
nmcli connection delete ens192
# ⚠️ 删了 connection = 配置没了，但网卡还在
# 重启 NetworkManager 或手动新建
```

### 12. ❌ 改 MTU 不改两端

```bash
# 改一端 MTU 9000，另一端 1500 → 大包丢了
# 改 MTU 必须两端一致
```

---

## §22 面试 6 大追问

### Q1：OSI 7 层和 TCP/IP 4 层对应？

**答**：
| OSI | TCP/IP |
|---|---|
| 应用/表示/会话 | **应用层** |
| 传输 | **传输层** |
| 网络 | **网络层** |
| 数据链路/物理 | **链路层** |

### Q2：ping 走哪几层？

**答**：网络层（ICMP）+ 链路层（ARP）+ 物理层。
- 跨网段：还要经过路由器（网络层）

### Q3：net-tools 和 iproute2 对比？

**答**：
| 老（net-tools） | 新（iproute2）|
|---|---|
| ifconfig | ip addr / ip link |
| route | ip route |
| netstat | ss |
| arp | ip neigh |

### Q4：怎么排查"SSH 连不上"？

**答**：
```
1. ping 自己 → 网卡？
2. ping 网关 → 局域网？
3. ping 外网 IP → 路由？
4. ping 域名 → DNS？
5. ss -lnp | grep :22 → 服务启了？
6. 防火墙放行 22 → firewalld？
7. /var/log/secure → 认证日志？
```

### Q5：BOOTPROTO=dhcp 和 static 区别？

**答**：
- `dhcp`：自动从 DHCP 服务器获取 IP
- `static`：手动配 IP（IPADDR/PREFIX/GATEWAY）
- `none`：不自动获取（一般不用）

### Q6：NetworkManager 和 network 区别？

**答**：
- CentOS-7：**NetworkManager**（默认）
- CentOS-6：network（脚本 ifup/ifdown）
- 同一台机器不能同时用两个

---

## §23 链路

| 笔记 | 关系 |
|---|---|
| [[Linux防火墙/Linux防火墙]] | firewalld 与 ip 命令配合 |
| [[Linux服务与SSH/Linux服务与SSH]] | ss 查 sshd 端口 |
| [[LinuxShell/shell]] | `if [ $? -eq 0 ]` 用于网络脚本 |
| [[Linux用户权限/user-permission]] | 网络用户特殊权限 |

**下一步**：完成 Linux网络 后可以选择：
- 🎯 **第 4 波 ③** [[Linux防火墙/]]（06.10 共 1 PDF）—— firewalld / zone / rich-rules