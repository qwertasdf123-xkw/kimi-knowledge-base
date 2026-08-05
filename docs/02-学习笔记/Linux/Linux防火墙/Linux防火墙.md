---
title: Linux 防火墙 — firewalld 9 大 zone + 规则实战
desc: 基于 06.CentOS-7-系统管理-2/10. Linux firewall 防火墙管理.pdf 的实操笔记。覆盖防火墙分类、Netfilter/iptables/nftables、firewalld 与 iptables 对比、9 大 zone、firewall-cmd 命令大全、service/port/masquerade/forward-port/rich-rule。
type: 笔记
module: Linux防火墙
pdf: 06.10 Linux firewall 防火墙管理.pdf
pdf_size: 1268 行
scope: CentOS-7 (firewalld 0.6.x)
status: 完成
---

# Linux 防火墙 — firewalld 9 大 zone + 规则实战

> **范围**：基于《CentOS-7 系统管理 2》第 10 章 整理。
> 覆盖 **防火墙分类** + **Netfilter / iptables / nftables 原理** + **firewalld 9 大 zone** + **firewall-cmd 命令大全** + **service / port / masquerade / forward-port / rich-rule 实战**。
>
> **适用**：CentOS-7 / RHEL 系（默认 firewalld）。

## 目录

- [[#§0 心智模型：防火墙 = 门口的保安]]
- [[#§1 防火墙分类：包过滤 / 状态检测 / 应用层 / WAF]]
- [[#§2 Netfilter 是什么：Linux 内核的"过滤网"]]
- [[#§3 iptables / ip6tables / arptables / ebtables]]
- [[#§4 nftables：iptables 替代品]]
- [[#§5 firewalld 是什么]]
- [[#§6 firewalld vs iptables]]
- [[#§7 9 大 zone 详解]]
- [[#§8 firewall-cmd 命令基础]]
- [[#§9 zone 操作：查 / 改 / 新建]]
- [[#§10 service 操作]]
- [[#§11 port 端口操作]]
- [[#§12 interface 接口绑 zone]]
- [[#§13 source 源地址绑 zone]]
- [[#§14 masquerade NAT 伪装]]
- [[#§15 port-forward 端口转发]]
- [[#§16 rich-rule 富规则]]
- [[#§17 实战：开 HTTP/HTTPS/SSH]]
- [[#§18 实战：内网穿透 + 跳板]]
- [[#§19 配置持久化：--permanent]]
- [[#§20 速查表]]
- [[#§21 易错点 ×12]]
- [[#§22 面试 6 大追问]]
- [[#§23 链路]]

---

## §0 心智模型：防火墙 = 门口的保安

```
            外网（公网）
               │
       ┌───────┴───────┐
       │   防火墙       │   ← 检查每个数据包
       │   （门卫）      │     允许？拒绝？丢弃？
       └───────┬───────┘
               │
            内网（公司服务器）
```

**作用**：
- ✅ 阻挡外部攻击
- ✅ 控制内网对外的访问
- ✅ 隐藏内网结构（NAT）
- ✅ 记录访问日志

**类比**：
- **包过滤防火墙** = 只看信封地址
- **状态检测** = 看信封 + 检查序列号
- **应用层防火墙（WAF）** = 看信封 + 拆开看内容

---

## §1 防火墙分类：包过滤 / 状态检测 / 应用层 / WAF

| 类型          | 工作层次      | 检查内容                      | 代表产品              |
| ----------- | --------- | ------------------------- | ----------------- |
| **包过滤**     | 网络层（L3）   | 源/目标 IP、端口、协议             | iptables          |
| **状态检测**    | 传输层（L4）   | 包 + 连接状态（NEW/ESTABLISHED） | iptables state 模块 |
| **应用层**     | 应用层（L7）   | 协议内容（HTTP/SMTP）           | squid             |
| **代理 / 网关** | 应用层       | 替客户端请求                    | nginx 反向代理        |
| **WAF**     | 应用层（HTTP） | SQL 注入、XSS                | ModSecurity       |

> 💡 **Linux 防火墙基本都是 L3/L4**（包过滤 + 状态检测）。

---

## §2 Netfilter 是什么：Linux 内核的"过滤网"

```
Netfilter = Linux 内核的包过滤框架
  - 内核模块
  - 提供 5 个钩子点（hook）
  - iptables / nftables / firewalld 都是"前端"，真正干活的是 Netfilter

数据包流向（5 个钩子点）：
  PREROUTING → INPUT → FORWARD → OUTPUT → POSTROUTING
       ↓          ↓         ↓        ↓          ↓
      路由前     本机收     转发     本机发      路由后
```

---

## §3 iptables / ip6tables / arptables / ebtables

| 命令 | 协议层 | 功能 |
|---|---|---|
| **iptables** | IPv4 | IP 层过滤、NAT |
| **ip6tables** | IPv6 | IPv6 过滤 |
| **arptables** | ARP | ARP 过滤（防 ARP 欺骗）|
| **ebtables** | 以太网帧 | L2 过滤、VLAN ID 过滤 |

```bash
# 看 Netfilter 工具链
[root@centos7 ~]# ls -l /sbin/*tables
-rwxr-xr-x 1 root root 59872 /sbin/arptables
-rwxr-xr-x 1 root root  7016 /sbin/ebtables
lrwxrwxrwx 1 root root    13 /sbin/ip6tables -> xtables-multi
lrwxrwxrwx 1 root root    13 /sbin/iptables -> xtables-multi
# ↑ 都指向 xtables-multi（统一二进制）
```

> ⚠️ **iptables 服务（iptables.service）在 CentOS-7 已废弃**，改用 firewalld。
> 想用 iptables 需装 iptables-services 包。

---

## §4 nftables：iptables 替代品

```
nftables = iptables 的"接班人"
  - 更简单（一个 nft 工具替代 4 个）
  - 更快（内核 O(1) 查找）
  - RHEL 8+/Debian 10+ 默认
```

> 💡 CentOS-7 仍是 iptables 后端，firewalld 内部用 iptables 命令写规则。

---

## §5 firewalld 是什么

```
firewalld = Red Hat 开发的防火墙管理工具
  - CentOS-7 默认装
  - 内部调用 iptables 命令
  - 提供动态管理（不丢现有连接）
  - 区分 runtime / permanent 两种配置
```

**3 个核心概念**：

| 概念                | 含义                             |
| ----------------- | ------------------------------ |
| **zone（区域）**      | 一组预定义规则（信任级别）                  |
| **service（服务）**   | 预定义的"端口 + 协议"（如 http = 80/tcp） |
| **interface（接口）** | 网卡绑到哪个 zone                    |

---

## §6 firewalld vs iptables

|      | firewalld           | iptables      |
| ---- | ------------------- | ------------- |
| 配置   | zone 化（高级）          | 表/链（低级）       |
| 改规则  | 不丢连接（dynamic）       | 全刷（reload）    |
| 持久化  | runtime + permanent | 直接保存          |
| 学习曲线 | 易                   | 陡             |
| 后端   | 调用 iptables         | 直接写 Netfilter |
| 适用   | 桌面/服务器新手            | 专业运维          |

> 💡 **生产建议**：日常用 firewalld 够；要复杂规则（如七层过滤）用 iptables。

---

## §7 9 大 zone 详解

```
firewalld 的"区域"概念 = 按"信任级别"分组规则

默认 zone：public
```

| Zone         | 信任级别               | 默认服务                                   | 适用      |
| ------------ | ------------------ | -------------------------------------- | ------- |
| **trusted**  | 全部接受               | （空）                                    | 内网信任    |
| **public**   | 默认拒绝（除 ssh/dhcpv6） | ssh, dhcpv6-client, cockpit            | 公网      |
| **external** | 仅 ssh              | ssh                                    | 外网（NAT） |
| **home**     | 中等                 | ssh, mdns, samba-client, dhcpv6-client | 家庭      |
| **internal** | 同 home             | ssh, mdns, samba-client, dhcpv6-client | 内网      |
| **work**     | 工作区                | ssh, dhcpv6-client                     | 公司      |
| **dmz**      | 隔离区                | ssh                                    | DMZ 服务器 |
| **block**    | 拒绝（返回 ICMP 不可达）    | （空）                                    | 屏蔽      |
| **drop**     | 丢弃（不回包）            | （空）                                    | 静默屏蔽    |

**target（默认行为）**：

| target       | 含义                   |
| ------------ | -------------------- |
| `default`    | 跟随 zone 默认           |
| `ACCEPT`     | 接受所有（zone 内的额外规则仍生效） |
| `%%REJECT%%` | 拒绝（block zone）       |
| `DROP`       | 丢弃（drop zone）        |

> 💡 **block vs drop**：
> - block → 回 ICMP "host unreachable"（对方知道被挡）
> - drop → 啥也不回（对方不知道）

---

## §8 firewall-cmd 命令基础

```bash
# 看所有 zone
[root@centos7 ~]# firewall-cmd --get-zones
block dmz drop external home internal public trusted work

# 看活跃 zone
[root@centos7 ~]# firewall-cmd --get-active-zones
public
  interfaces: ens32

# 看默认 zone
[root@centos7 ~]# firewall-cmd --get-default-zone
public

# 看 public zone 详情
[root@centos7 ~]# firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: ens32
  sources:
  services: cockpit dhcpv6-client ssh
  ports:
  protocols:
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:

# 看所有 zone 的详情
[root@centos7 ~]# firewall-cmd --list-all-zones
```

**两个状态**：
- **runtime**（运行时）：当前生效，重启 firewalld 丢失
- **permanent**（永久）：写到配置文件，重启保留

> ⚠️ **不加 `--permanent` 默认是 runtime**！

```bash
# 改 runtime 立即生效，但重启丢失
firewall-cmd --add-service=http

# 改 permanent 重启才生效
firewall-cmd --permanent --add-service=http

# 立即应用 permanent（无需重启）
firewall-cmd --reload
# 完全重载（断现有连接）
firewall-cmd --complete-reload
```

---

## §9 zone 操作：查 / 改 / 新建

### 9.1 改默认 zone

```bash
# 设默认 zone = trusted（接受所有）
[root@centos7 ~]# firewall-cmd --set-default-zone=trusted
success
[root@centos7 ~]# firewall-cmd --get-default-zone
trusted

# 改回
[root@centos7 ~]# firewall-cmd --set-default-zone=public
success
```

### 9.2 新建 zone

```bash
# 新建（必须 --permanent）
[root@centos7 ~]# firewall-cmd --permanent --new-zone=myweb
success

[root@centos7 ~]# firewall-cmd --permanent --get-zones
block dmz drop external home internal myweb public trusted work
# ↑ myweb 已加

[root@centos7 ~]# firewall-cmd --get-zones
block dmz drop external home internal public trusted work
# ↑ runtime 还没，要 reload

[root@centos7 ~]# firewall-cmd --reload
[root@centos7 ~]# firewall-cmd --get-zones
block dmz drop external home internal myweb public trusted trusted work
```

### 9.3 改 zone 的 target

```bash
# 看 myweb target
[root@centos7 ~]# firewall-cmd --permanent --zone=myweb --get-target
default

# 改 REJECT
[root@centos7 ~]# firewall-cmd --permanent --zone=myweb --set-target=REJECT

# 选项：default / ACCEPT / DROP / REJECT

# 删 zone
[root@centos7 ~]# firewall-cmd --permanent --delete-zone=myweb
```

---

## §10 service 操作

**service** = firewalld 预定义的"服务名 → 端口/协议"映射

```bash
# 看所有预定义 service
[root@centos7 ~]# firewall-cmd --get-services
RH-Satellite-6 amanda-client amanda-k5-client ...
cockpit dhcp dhcpv6 dhcpv6-client dns docker-registry ...
http https imap imaps ipp ipp-client ...
mysql nfs nfs3 nfs4 ...
ssh telnet tftp ...

# 加 service
[root@centos7 ~]# firewall-cmd --add-service=http
success

# 看 public zone 的 services
[root@centos7 ~]# firewall-cmd --list-services
cockpit dhcpv6-client http ssh
# ↑ http 加进来了

# 查某 service 是否启用
[root@centos7 ~]# firewall-cmd --query-service=http
yes

# 删 service
[root@centos7 ~]# firewall-cmd --remove-service=http
success
```

### 10.1 service 配置文件

```bash
# /usr/lib/firewalld/services/http.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>WWW (HTTP)</short>
  <description>HTTP is the protocol used to serve Web pages...</description>
  <port protocol="tcp" port="80"/>
</service>
# ↑ 就是"80/tcp"的人话版
```

### 10.2 自定义 service

```bash
# 新建（--permanent）
firewall-cmd --permanent --new-service=myservice
firewall-cmd --permanent --service=myservice --set-description="My App"
firewall-cmd --permanent --service=myservice --add-port=8080/tcp
firewall-cmd --reload
```

---

## §11 port 端口操作

```bash
# 加端口
[root@centos7 ~]# firewall-cmd --add-port=5900/tcp
success

# 看
[root@centos7 ~]# firewall-cmd --list-ports
5900/tcp

# 查
[root@centos7 ~]# firewall-cmd --query-port=5900/tcp
yes

# 删
[root@centos7 ~]# firewall-cmd --remove-port=5900/tcp
success

# 多个端口
firewall-cmd --add-port=5900-5905/tcp
# ↑ 范围
```

---

## §12 interface 接口绑 zone

```bash
# 看
[root@centos7 ~]# firewall-cmd --list-interfaces
ens32

# 看某接口所属 zone
[root@centos7 ~]# firewall-cmd --get-zone-of-interface=ens32
public

# 改接口 zone
[root@centos7 ~]# firewall-cmd --change-interface=ens32 --zone=home

# 加接口到 zone
[root@centos7 ~]# firewall-cmd --add-interface=ens32 --zone=public

# 删
[root@centos7 ~]# firewall-cmd --remove-interface=ens32 --zone=home
```

---

## §13 source 源地址绑 zone

```bash
# 192.168.1.0/24 这网段走 home zone（信任）
[root@centos7 ~]# firewall-cmd --add-source=192.168.1.0/24 --zone=home

# 看
[root@centos7 ~]# firewall-cmd --list-sources --zone=home
192.168.1.0/24

# 查某源所属 zone
[root@centos7 ~]# firewall-cmd --get-zone-of-source=192.168.1.0/24
home

# 改 zone
[root@centos7 ~]# firewall-cmd --change-source=192.168.1.0/24 --zone=public

# 删
[root@centos7 ~]# firewall-cmd --remove-source=192.168.1.0/24 --zone=public
```

> 💡 **实战**：把办公网 IP 加到 trusted zone，省得每次连 SSH 都要放行。

---

## §14 masquerade NAT 伪装

```
masquerade = IP 伪装（源 NAT）
  把内网 IP 翻译成公网 IP
  多个内网主机共享一个公网 IP 上网
```

```bash
# 看是否启用
[root@centos7 ~]# firewall-cmd --query-masquerade
no

# 启用（开 IP 转发）
[root@centos7 ~]# firewall-cmd --add-masquerade
success
[root@centos7 ~]# firewall-cmd --query-masquerade
yes

# 关
[root@centos7 ~]# firewall-cmd --remove-masquerade
success
```

**架构示意**：
```
内网 client (10.1.1.11) ─→ server (10.1.1.10 / 10.1.8.10) ─→ 公网
                                       ↑
                              masquerade 把 10.1.1.11
                              翻译成 10.1.8.10
```

---

## §15 port-forward 端口转发

**场景**：把外网访问 server:8000 的请求转到内网 client:80

```bash
# 1) 开 masquerade
[root@centos7 ~]# firewall-cmd --add-masquerade

# 2) 加转发规则：8000 → 80
[root@centos7 ~]# firewall-cmd --add-forward-port=port=8000:proto=tcp:toport=80
success

# 3) 查
[root@centos7 ~]# firewall-cmd --query-forward-port=port=8000:proto=tcp:toport=80
yes

# 4) 转发到其他机器：1022 → 10.1.1.11:22
[root@centos7 ~]# firewall-cmd --add-forward-port=port=1022:proto=tcp:toport=22:toaddr=10.1.1.11
```

> ⚠️ **必须先开 masquerade**！

---

## §16 rich-rule 富规则

```
rich-rule = 富规则
  - 比 service/port 更灵活
  - 支持按源/目标、限速、日志等
```

### 16.1 语法

```
rule [family=ipv4|ipv6]
  [source address=...]
  [destination address=...]
  [service name=... | port port=... protocol=...]
  [action accept|reject|drop|mark]
  [log [prefix=...]]
```

### 16.2 实战

```bash
# 允许 192.168.1.0/24 访问 80
firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 service name=http accept'

# 拒绝 10.1.8.0/24 访问 22
firewall-cmd --add-rich-rule='rule family=ipv4 source address=10.1.8.0/24 service name=ssh reject'

# 限速（每秒最多 10 个新连接）
firewall-cmd --add-rich-rule='rule service name=http limit value=10/s accept'

# 看
firewall-cmd --list-rich-rules

# 删
firewall-cmd --remove-rich-rule='...'
```

---

## §17 实战：开 HTTP/HTTPS/SSH

```bash
# 1) 看默认 zone
firewall-cmd --get-default-zone    # public

# 2) 开 HTTP
firewall-cmd --add-service=http
firewall-cmd --add-service=https

# 3) 验证
firewall-cmd --list-services
# cockpit dhcpv6-client http https ssh

# 4) 永久生效
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# 5) 测
curl http://localhost
```

---

## §18 实战：内网穿透 + 跳板

**场景**：把外网访问 server:8000 的请求转到内网 client:80

```bash
# server 上
# 1) 开 IP 转发（系统层）
[root@server ~]# echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
[root@server ~]# sysctl -p

# 2) 开 masquerade
[root@server ~]# firewall-cmd --add-masquerade

# 3) 转发 8000 → 10.1.1.11:80
[root@server ~]# firewall-cmd --add-forward-port=port=8000:proto=tcp:toport=80:toaddr=10.1.1.11
firewall-cmd --permanent --add-forward-port=port=8000:proto=tcp:toport=80:toaddr=10.1.1.11
firewall-cmd --reload

# 4) 测试
curl http://server:8000  # 实际访问到 client
```

---

## §19 配置持久化：--permanent

```
两个状态：
  runtime    = 当前生效（默认）
  permanent  = 写到磁盘（重启保留）

3 个常用组合：
  1. 只改 runtime：firewall-cmd --add-service=http
     → 立即生效，重启失效
  2. 改 permanent：firewall-cmd --permanent --add-service=http
     → 重启后生效
  3. 改 permanent + reload：--permanent + --reload
     → 立即生效 + 重启保留（推荐）
```

```bash
# 推荐流程
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

# 看区别
firewall-cmd --list-services           # runtime
firewall-cmd --permanent --list-services  # permanent
```

**配置文件路径**：
- 系统自带：`/usr/lib/firewalld/`（不要改）
- 自定义：`/etc/firewalld/`（zone 配置在这）

```bash
# 自定义 zone 在这里
ls /etc/firewalld/zones/

# 修改示例
cat /etc/firewalld/zones/myweb.xml
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>MyWeb</short>
  <description>My custom web zone</description>
  <service name="http"/>
  <service name="https"/>
</zone>
```

---

## §20 速查表

### 20.1 zone

```bash
firewall-cmd --get-zones
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --new-zone=myzone
firewall-cmd --permanent --delete-zone=myzone
firewall-cmd --list-all-zones
firewall-cmd --list-all --zone=home
```

### 20.2 service

```bash
firewall-cmd --get-services
firewall-cmd --add-service=http
firewall-cmd --remove-service=http
firewall-cmd --list-services
firewall-cmd --query-service=http
firewall-cmd --permanent --new-service=myservice
firewall-cmd --permanent --service=myservice --add-port=8080/tcp
```

### 20.3 port

```bash
firewall-cmd --add-port=80/tcp
firewall-cmd --add-port=8000-9000/udp
firewall-cmd --remove-port=80/tcp
firewall-cmd --list-ports
firewall-cmd --query-port=80/tcp
```

### 20.4 interface / source

```bash
firewall-cmd --list-interfaces
firewall-cmd --change-interface=ens32 --zone=home
firewall-cmd --add-source=192.168.1.0/24 --zone=home
firewall-cmd --get-zone-of-interface=ens32
firewall-cmd --get-zone-of-source=192.168.1.0/24
```

### 20.5 masquerade / forward

```bash
firewall-cmd --add-masquerade
firewall-cmd --remove-masquerade
firewall-cmd --add-forward-port=port=8000:proto=tcp:toport=80
firewall-cmd --add-forward-port=port=8000:proto=tcp:toport=22:toaddr=10.1.1.11
firewall-cmd --list-forward-ports
firewall-cmd --remove-forward-port=port=8000:proto=tcp:toport=80
```

### 20.6 rich-rule

```bash
firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 service name=http accept'
firewall-cmd --add-rich-rule='rule service name=http limit value=10/s accept'
firewall-cmd --list-rich-rules
firewall-cmd --remove-rich-rule='...'
```

### 20.7 持久化

```bash
firewall-cmd --reload                # 应用 permanent
firewall-cmd --complete-reload       # 完全重载（断连接）
firewall-cmd --runtime-to-permanent  # runtime → permanent（一次性）

# 看状态
firewall-cmd --state                 # running / not running
systemctl status firewalld
```

---

## §21 易错点 ×12

### 1. ❌ 改完忘 --permanent

```bash
firewall-cmd --add-service=http    # runtime，重启丢
firewall-cmd --permanent --add-service=http    # permanent
firewall-cmd --reload    # 或这个应用
```

### 2. ❌ zone 改错

```bash
# 在 public zone 加 service，但实际是 dmz zone
firewall-cmd --zone=dmz --add-service=http
# 没指定 zone 用默认（public），但网卡可能在 dmz
```

### 3. ❌ forward 忘开 masquerade

```bash
firewall-cmd --add-forward-port=...
# ⚠️ 没 masquerade 不能转发！
firewall-cmd --add-masquerade
```

### 4. ❌ service 没启用对应 zone

```bash
firewall-cmd --add-service=http --zone=public
# 但 ens32 在 dmz zone → 不生效
firewall-cmd --change-interface=ens32 --zone=public
# 或直接 --zone=public 加 service
```

### 5. ❌ 重启 firewalld 断现有连接

```bash
firewall-cmd --reload                # 不断
firewall-cmd --complete-reload       # 断！
# SSH 连接用 complete-reload 会掉
```

### 6. ❌ 把 trusted 设默认

```bash
firewall-cmd --set-default-zone=trusted
# ⚠️ 等于关防火墙！生产危险
```

### 7. ❌ 同一 service 加多次

```bash
firewall-cmd --add-service=http
firewall-cmd --add-service=http    # 不会重复，但 list 会只显示一次
```

### 8. ❌ rich-rule 语法错

```bash
firewall-cmd --add-rich-rule='rule source 192.168.1.0/24 accept'
# ⚠️ 语法错（必须 family=ipv4 source address=...）
firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 accept'
```

### 9. ❌ masquerade 改后忘永久

```bash
firewall-cmd --add-masquerade
firewall-cmd --permanent --add-masquerade    # 别忘
```

### 10. ❌ 端口写错协议

```bash
firewall-cmd --add-port=80        # ⚠️ 默认是 tcp 吗？
firewall-cmd --add-port=80/tcp    # 明确写
firewall-cmd --add-port=53/udp    # DNS 是 udp
```

### 11. ❌ 防火墙全关排查

```bash
# 排查"连不上"时先关防火墙
systemctl stop firewalld    # ⚠️ 等于裸奔
# 临时放行更安全
firewall-cmd --add-service=xxx
```

### 12. ❌ 不分 runtime / permanent

```bash
firewall-cmd --add-port=80/tcp                  # runtime（默认）
firewall-cmd --permanent --add-port=80/tcp      # permanent
# 两个独立！都不会互相覆盖
```

---

## §22 面试 6 大追问

### Q1：firewalld 和 iptables 区别？

**答**：
- **firewalld**：zone 化、动态（reload 不丢连接）、易用
- **iptables**：表/链结构、静态（一改就刷）、强大但难
- 日常用 firewalld；复杂规则用 iptables（直接改底层规则）

### Q2：9 大 zone 怎么选？

**答**：
| 场景 | zone |
|---|---|
| 公网服务器 | public（默认）|
| 内网信任 | trusted |
| 公司办公 | work |
| 家庭 | home / internal |
| 隔离区服务器 | dmz |
| 屏蔽来源 IP | block / drop |

### Q3：block 和 drop 区别？

**答**：
- **block**：拒绝并回 ICMP "host unreachable"（对方知道被挡）
- **drop**：丢弃不回包（对方以为你不存在）
- 防扫描用 **drop**（更隐蔽）

### Q4：runtime 和 permanent 区别？

**答**：
- **runtime**：当前生效，重启 firewalld 丢失
- **permanent**：写到磁盘，重启保留
- 推荐：`--permanent --reload` 一起用

### Q5：如何放行特定 IP 的 SSH？

**答**：
```bash
# 方法 1：放行 IP 到 trusted zone
firewall-cmd --add-source=192.168.1.0/24 --zone=trusted

# 方法 2：rich-rule
firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 service name=ssh accept'
```

### Q6：如何做端口转发？

**答**：
```bash
# 1) 开 IP 转发
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# 2) 开 masquerade
firewall-cmd --add-masquerade

# 3) 转发
firewall-cmd --add-forward-port=port=8000:proto=tcp:toport=80:toaddr=10.1.1.11
```

---

## §23 链路

| 笔记 | 关系 |
|---|---|
| [[Linux网络/Linux网络]] | ss 查端口被谁占 |
| [[Linux服务与SSH/Linux服务与SSH]] | 防火墙放行 SSH 端口 |
| [[Linux包管理/package]] | yum install firewalld |
| [[LinuxShell/shell]] | firewall-cmd 在脚本里用 |

**全部 4 波完成！** 🎉
```
✅ 模块 10: Linux日志与时间/
✅ 模块 11: Linux文件传输/
✅ 模块 12: Linux存储/
✅ 模块 13: Linux网络/
✅ 模块 14: Linux防火墙/
```