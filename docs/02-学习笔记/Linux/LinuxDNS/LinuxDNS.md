---
title: Linux DNS 服务器 — 协议原理 + BIND 9 部署 + 正反向解析 + 主从 + 子域委派
desc: 基于《DNS 服务器.pdf》整理。覆盖 DNS 协议基础、FQDN/域名层级、递归/迭代查询、资源记录类型、BIND 9 安装、ACL、listen-on、正反向 zone、主从同步、子域委派、转发(Unbound/Dnsmasq)、智能 DNS、dig/host/nslookup 排障、DNSSEC、TSIG、安全加固。
type: 笔记
module: LinuxDNS
pdf: DNS 服务器.new.pdf
pdf_size: 1.2 MB
scope: DNS 原理 + BIND 9 + Unbound + Dnsmasq + 实战部署
status: 完成
---

# Linux DNS 服务器 — 协议原理 + BIND 9 部署 + 正反向解析 + 主从 + 子域委派

> **范围**：基于《DNS 服务器》PDF 整理（1648 行原文）。
> 覆盖 **DNS 协议**（FQDN/域名层级/递归迭代/资源记录）+ **BIND 9**（named.conf/zone/ACL/主从/子域委派/视图/TSIG/DNSSEC）+ **缓存/转发器**（Unbound/Dnsmasq）+ **客户端排障**（dig/host/nslookup/whois）+ **安全加固**（allow-transfer/隐藏版本/ACL 控制）。
>
> **适用**：CentOS-7/RHEL 系（bind/bind-utils）。

## 目录

- [[#§0 心智模型：DNS = 互联网的电话簿]]
- [[#§1 DNS 是什么：域名层级与三类服务器]]
- [[#§2 DNS 查询流程：递归 vs 迭代]]
- [[#§3 资源记录（RR）总览：A/AAAA/CNAME/PTR/NS/SOA/MX/TXT/SRV]]
- [[#§4 BIND 9 安装与目录结构]]
- [[#§5 /etc/named.conf 主配置文件]]
- [[#§6 ACL 与 listen-on 访问控制]]
- [[#§7 正向解析 zone 文件]]
- [[#§8 反向解析 zone 文件]]
- [[#§9 named-checkconf/named-checkzone 校验]]
- [[#§10 启动 named 与防火墙]]
- [[#§11 客户端测试与 /etc/resolv.conf]]
- [[#§12 Unbound 缓存 DNS 部署]]
- [[#§13 Dnsmasq 轻量 DNS+DHCP]]
- [[#§14 /etc/nsswitch.conf 解析顺序]]
- [[#§15 dig/host/nslookup 排障命令]]
- [[#§16 dig +trace 与状态码 NOERROR/SERVFAIL/NXDOMAIN/REFUSED]]
- [[#§17 子域委派与通配符 *]]
- [[#§18 CNAME 互指陷阱与 FQDN 规范]]
- [[#§19 主从同步、子域委派、转发器、视图（CDN 调度）]]
- [[#§20 DNS 安全：TSIG + DNSSEC + 隐藏版本 + ACL]]
- [[#§21 速查表：记录类型 + 默认端口 + 关键路径]]
- [[#§22 易错点 ×12]]
- [[#§23 面试 8 大追问]]
- [[#§24 跨模块链接]]

---

## §0 心智模型：DNS = 互联网的电话簿

```
DNS 三大角色：

1. 用户（stub resolver）        想打"麦当劳电话"，不会自己挨个问
2. 递归服务器（recursor）       114 查号台 → 一站式代查
3. 权威服务器（authoritative）  真正的"商家电话本"，一口价答案
```

**DNS 核心思想**：
- 域名（人类友好：`www.example.com`） → IP（机器友好：`93.184.216.34`）
- **分布式数据库**：全球 13 组根服务器 → TLD 服务器 → 权威服务器
- **分层缓存**：本地浏览器 → 系统 → 路由器 → ISP → 递归 → 权威
- **协议层**：应用层协议，默认走 **UDP/53**（大响应自动切 TCP/53）

**为什么需要 DNS？**
- IP 难记（`140.205.94.189` vs `www.taobao.com`）
- IP 会变（服务器迁移只需改 DNS 记录，域名不变）
- 多 IP 负载均衡（一个域名 → 多个 A 记录，DNS 轮询）

---

## §1 DNS 是什么：域名层级与三类服务器

### 1.1 FQDN（完全限定域名）

```
FQDN = hostname + domain-name
例：www.example.com.

                .   ← 根（root，写出来是 "."）
              com   ← 顶级域 TLD（Top-Level Domain）
          example   ← 二级域（注册购买）
             www    ← 主机名（自己分配）
```

> 结尾的 `.` 是根节点，平时省略但 zone 文件里**必须写**。

### 1.2 域名层级

```
Domain（域）
├── top-level domain (TLD)        ← 顶级域，由 IANA 管理
│   ├── Generic TLD (gTLD)        ← .com / .edu / .net / .org
│   └── Country code TLD (ccTLD)  ← .cn / .us / .uk / .ru
├── Subdomain（子域）             ← 注册人自行划分，如 lab.example.com
└── Zone（区/域）                 ← DNS 服务器实际管理的"区域"
```

**Domain vs Zone 的区别**：
- Domain 是**逻辑概念**（整棵命名树）
- Zone 是**管理单元**（一个 DNS 服务器管的范围）
- 例：`example.com` 域可能拆成 `example.com`（主）+ `sub.example.com`（子域委派）两个 zone

参考列表：<https://www.iana.org/domains/root/db>

### 1.3 三类 DNS 服务器

| 类型                             | 角色              | 典型代表                      | 默认端口       |
| ------------------------------ | --------------- | ------------------------- | ---------- |
| **权威 DNS**（Authoritative）      | 拥有某 zone 的最终解释权 | 根/TLD/本企业 NS              | UDP/TCP 53 |
| **递归 DNS**（Recursive/Resolver） | 代用户递归查询，缓存结果    | 114.114.114.114 / 8.8.8.8 | UDP/TCP 53 |
| **缓存 DNS**（Caching-only）       | 只做递归+缓存，无 zone  | Unbound / Dnsmasq         | UDP/TCP 53 |

---

## §2 DNS 查询流程：递归 vs 迭代

### 2.1 报文标志位

```
DNS 报文头部关键字段：

RD（Recursion Desired）   = 1 → 请求递归查询
RA（Recursion Available） = 1 → 服务器支持递归
AA（Authoritative Answer）= 1 → 答案来自权威服务器
QR（Query/Response）      = 0 查询 / 1 响应
```

### 2.2 递归查询（Recursive Query）

```
用户 → 递归服务器
"我要 www.example.com 的 IP"

递归服务器：包在我身上，我去问，你等结果
  ↓
  全程代查，直到拿到 IP 才返回
```

### 2.3 迭代查询（Iterative Query）

```
递归服务器 → 根 DNS
"www.example.com 在哪？"

根 DNS："我不知道，但 .com 的 NS 在那，问它们去"
         返回 .com TLD 服务器地址

递归服务器 → .com DNS
"www.example.com 在哪？"

.com DNS："example.com 的 NS 在那"
          返回 example.com 权威服务器地址

递归服务器 → example.com DNS
"www.example.com 在哪？"

example.com DNS："它的 A 记录是 93.184.216.34"
                直接返回最终 IP
```

### 2.4 完整查询路径图

```
PC ──RD=1──> 本地 DNS（递归）
              │
              │   RD=0 询问
              ↓
            .com（TLD）
              │   返回 example.com NS
              ↓
            example.com（权威）
              │   返回 www 的 A 记录
              ↓
            本地 DNS 缓存 → 返回给 PC

总计查询：1 次递归 + 2~3 次迭代（99.9% 的情况）
```

---

## §3 资源记录（RR）总览：A/AAAA/CNAME/PTR/NS/SOA/MX/TXT/SRV

### 3.1 RR 通用格式

```
#                     TTL              ↓↓↓
owner-name            TTL    class  type    data
server.laogao.cloud.  300    IN     A       192.168.1.10
```

| 字段 | 含义 |
|------|------|
| owner-name | 域名（@ = 区域名 / 留空继承上一行） |
| TTL | 缓存时间（秒） |
| class | IN = Internet（99.9% 场景） |
| type | 记录类型（A/AAAA/CNAME/PTR/NS/SOA/MX/TXT/SRV） |
| data | 类型相关数据 |

### 3.2 A 记录（IPv4）

```dns
server.laogao.cloud. 86400 IN A 172.25.254.254
```

### 3.3 AAAA 记录（IPv6）

```dns
a.root-servers.net. 604800 IN AAAA 2001:503:ba3e::2:30
```

### 3.4 CNAME（别名）

```dns
www-dev.laogao.cloud. 30 IN CNAME lab.laogao.cloud.
server.laogao.cloud.  30 IN CNAME www.redhat.com.
```

> **CNAME 规则**：CNAME 不能与 NS / MX / 其他 CNAME 共存于同一域名。

CDN 场景：
```dns
; A 记录在 CDN 厂商，CNAME 指向厂商
www.example.com. IN CNAME www.example.com.cdnhwc1.com.
```

### 3.5 PTR（反向解析）

```dns
4.0.41.198.in-addr.arpa. 785 IN PTR a.root-servers.net.
0.3.0.0.2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.e.3.a.b.3.0.5.0.1.0.0.2.ip6.arpa. 86400 IN PTR a.root-servers.net.
```

- IPv4 反向域：`in-addr.arpa`（IP 倒序，如 `192.168.1.10` → `10.1.168.192.in-addr.arpa.`）
- IPv6 反向域：`ip6.arpa`（32 位 nibble 倒序）

### 3.6 NS（Name Server，权威）

```dns
laogao.cloud.                      86400 IN NS dns.laogao.cloud.
168.192.in-addr.arpa.              86400 IN NS dns.laogao.cloud.
9.0.e.1.4.8.4.6.2.e.d.f.ip6.arpa. 86400 IN NS dns.laogao.cloud.
```

> NS 记录必须配 **A 记录（glue record）**：
> ```dns
> dns.laogao.cloud. IN A 10.1.8.10
> ```

### 3.7 SOA（Start of Authority，区域起始授权）

```dns
laogao.cloud. 86400 IN SOA dns.laogao.cloud. root.laogao.cloud. (
                                  2015071700  ; SERIAL 序列号（YYYYMMDDNN）
                                  3600        ; REFRESH  从服务器刷新间隔（秒）
                                  300         ; RETRY    重试间隔
                                  604800      ; EXPIRE   失效时间（1 周）
                                  60          ; MINIMUM  否定答案 TTL
)
```

| 字段 | 全称 | 含义 |
|------|------|------|
| MNAME | Master Name | 主 DNS 服务器 |
| RNAME | Responsible Name | 管理员邮箱（`@` 用 `.` 代替） |
| SERIAL | 序列号 | 必须**递增**，主从同步靠它判断 |
| REFRESH | 刷新 | slave 多久查一次 master |
| RETRY | 重试 | 失败后多久重试 |
| EXPIRE | 失效 | slave 多久没联系 master 就放弃 |
| MINIMUM | 最小 TTL | 否定答案缓存时间 |

### 3.8 MX（邮件交换）

```dns
laogao.cloud. 86400 IN MX 10 mail.laogao.cloud.        ; 优先级 10
laogao.cloud. 86400 IN MX 20 dns.laogao.cloud.         ; 备份，优先级 20
laogao.cloud. 86400 IN MX 100 mailbackup.laogao.cloud. ; 第三备份
```

数字越小优先级越高，必须配 A 记录：
```dns
mail.laogao.cloud. IN A 10.1.8.253
```

### 3.9 TXT（文本，常用于反垃圾邮件）

```dns
lwn.net. 27272 IN TXT "google-site-verification: sVlxS_z1es5DfNSUNXrqr3n9Y4F7tOr7HNVMKUGs"
lwn.net. 27272 IN TXT "v=spf1 a:mail.lwn.net a:prod.lwn.net a:git.lwn.net a:ms.lwn.net -all"
```

用途：SPF（发送方策略）、DKIM（密钥）、DMARC（报告）、Google/Facebook 站点验证。

### 3.10 SRV（服务定位）

```dns
_ldap._tcp.laogao.cloud. 86400 IN SRV 0 100 389 server0.laogao.cloud.
```

格式：`_服务._协议.域名 IN SRV 优先级 权重 端口 目标`

---

## §4 BIND 9 安装与目录结构

### 4.1 安装

```bash
[root@dns-server ~]# yum install -y bind bind-utils
```

| 包 | 作用 |
|----|------|
| `bind` | DNS 服务主程序（named） |
| `bind-utils` | DNS 客户端工具：`dig` `nslookup` `host` |

文档位置：`/usr/share/doc/bind/`

### 4.2 关键路径

```
/etc/named.conf              ← 主配置文件
/etc/named.rfc1912.zones     ← 预置区域（localhost / 0.0.127 等）
/var/named/                  ← zone 文件存放目录
/var/log/messages            ← named 服务日志（默认）
```

### 4.3 SELinux 与权限

```
/etc/named.conf 权限：0640，属主 root:named，SELinux 类型 named_conf_t
/var/named/     zone 文件：0640，属主 root:named，SELinux 类型 named_zone_t
```

```bash
[root@dns-server ~]# touch /var/named/laogao.cloud.zone
[root@dns-server ~]# chmod 640 /var/named/laogao.cloud.zone
[root@dns-server ~]# chown root:named /var/named/laogao.cloud.zone
[root@dns-server ~]# chcon -t named_zone_t /var/named/laogao.cloud.zone
```

---

## §5 /etc/named.conf 主配置文件

### 5.1 完整示例

```bind
# vim /etc/named.conf

acl trusted-nets { 192.168.10.0/24; 192.168.20.0/24; };
acl classroom    { 10.1.8.0/24; };

options {
    listen-on port 53 { 127.0.0.1; 10.1.8.10; };
    listen-on-v6 port 53 { ::1; 2001:db8:2020::5300; };

    directory       "/var/named";      # zone 文件相对路径基准
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";

    allow-query     { any; };           # 允许查询的客户端
    allow-transfer  { none; };          # 禁止 zone 传输（安全！）
    recursion       yes;                # 是否开启递归
    allow-recursion { trusted-nets; };  # 限制递归范围
    forwarders      { 114.114.114.114; 8.8.8.8; };  # 上游 DNS
    forward only;                       # 转发失败也不迭代
};

# 根提示
zone "." IN {
    type hint;
    file "named.ca";
};

# 正向 zone
zone "laogao.cloud" IN {
    type master;
    file "laogao.cloud.zone";
    allow-transfer { 10.1.8.20; };      # 允许 slave 同步
};

# 反向 zone
zone "8.1.10.in-addr.arpa" IN {
    type master;
    file "10.1.8.zone";
};
```

### 5.2 内置 ACL 关键字

| 关键字 | 含义 |
|--------|------|
| `any` | 任意 IP |
| `none` | 无 IP |
| `localhost` | 本机所有 IP（127.0.0.1 / ::1 + 本机网卡） |
| `localnets` | 本机所在的所有子网 |

---

## §6 ACL 与 listen-on 访问控制

### 6.1 listen-on / listen-on-v6

```bind
options {
    listen-on     port 53 { 127.0.0.1; 10.1.8.10; };   # IPv4 监听
    listen-on-v6  port 53 { ::1; 2001:db8::5300; };     # IPv6 监听
};
```

> 默认只监听 `127.0.0.1`，**外部主机查询不到**！生产必须加服务器 IP。
> 测试环境可写 `any`。

### 6.2 allow-query / allow-recursion

```bind
options {
    allow-query     { any; };           # 哪些客户端能查询
    recursion       no;                 # 权威 DNS 关闭递归
    allow-recursion { trusted-nets; };  # 限制可递归的来源（防放大攻击）
};
```

### 6.3 allow-transfer（Zone Transfer）

```bind
options {
    allow-transfer { none; };           # 全局禁止
};

zone "laogao.cloud" IN {
    type master;
    file "laogao.cloud.zone";
    allow-transfer { 10.1.8.20; };      # 仅允许此 slave 同步
};
```

**测试 AXFR（区域传输）：**
```bash
$ dig axfr @classroom.laogao.cloud laogao.cloud
# axfr = Authoritative Zone Transfer = 区域传输
```

---

## §7 正向解析 zone 文件

### 7.1 $TTL 指令

```dns
$TTL 3600   ; 默认 TTL 1 小时
```

| 后缀 | 含义 | 秒数 |
|------|------|------|
| M | 分钟 | 60 |
| H | 小时 | 3600 |
| D | 天 | 86400 |
| W | 周 | 604800 |

### 7.2 SOA 记录模板

```dns
$TTL 1D
@    IN SOA dns.laogao.cloud. root.laogao.cloud. (
                2015071700  ; serial（YYYYMMDDNN）
                3600        ; refresh  从服务器刷新间隔
                300         ; retry    失败重试
                604800      ; expire   失效时间（1 周）
                60          ; minimum  否定答案 TTL
)
```

### 7.3 完整正向 zone 示例

```dns
$TTL 1D
@    IN SOA dns.laogao.cloud. root.laogao.cloud. (
                2015071700  ; serial
                3600        ; refresh
                300         ; retry
                604800      ; expire
                60          ; minimum
)

; ── NS 记录 ──
@              IN NS dns.laogao.cloud.

; ── A 记录（IPv4）──
dns            IN A  10.1.8.10
server         IN A  10.1.8.10
client         IN A  10.1.8.11
mail           IN A  10.1.8.253

; ── CNAME ──
student        IN CNAME client.laogao.cloud.

; ── MX ──
@              IN MX 10 mail.laogao.cloud.

; ── A 带 TTL 覆盖 ──
www            30 IN A  10.1.8.200
```

**简写规则**：
- `@` = 区域名（`laogao.cloud.`）
- `dns` = `dns.laogao.cloud.`（自动追加区域名）
- 继承前一行 owner-name：连续写多条空 owner 表示同主

---

## §8 反向解析 zone 文件

### 8.1 反向 zone 名规则

```
10.1.8.10  →  10.1.8.10.in-addr.arpa.
                  ↑   ↑   ↑      ↑
                  倒序倒序倒序    固定
```

**自动补全**：`8.1.10.in-addr.arpa.` 即可覆盖整个 `10.1.8.0/24` 段。

### 8.2 反向 zone 示例

```dns
$TTL 1D
@        IN SOA  dns.laogao.cloud. root.laogao.cloud. (
                                    2015071700  ; serial
                                    3600        ; refresh
                                    300         ; retry
                                    604800      ; expire
                                    60          ; minimum
)

         IN NS   dns.laogao.cloud.

10        IN PTR  dns.laogao.cloud.
10        IN PTR  server.laogao.cloud.
11        IN PTR  client.laogao.cloud.
11        IN PTR  student.laogao.cloud.
200       IN PTR  www.laogao.cloud.
253       IN PTR  mail.laogao.cloud.
```

> PTR 数字部分（`10`）自动补全为 `10.8.1.10.in-addr.arpa.`

---

## §9 named-checkconf/named-checkzone 校验

### 9.1 配置语法检查

```bash
[root@dns-server ~]# named-checkconf                    # 检查 /etc/named.conf
[root@dns-server ~]# named-checkconf /media/backups/named.conf   # 指定文件
```

### 9.2 zone 文件语法检查

```bash
[root@dns-server ~]# named-checkzone laogao.cloud /var/named/laogao.cloud.zone
zone laogao.cloud/IN: loaded serial 2015071700
OK
```

### 9.3 重载配置

```bash
[root@dns-server ~]# rndc reload                # 重载所有 zone
[root@dns-server ~]# rndc freeze laogao.cloud   # 冻结（暂停同步）
[root@dns-server ~]# rndc thaw   laogao.cloud   # 解冻
```

---

## §10 启动 named 与防火墙

### 10.1 systemd 管理

```bash
# 启动并设置开机自启
[root@dns-server ~]# systemctl enable named --now

# 查看状态
[root@dns-server ~]# systemctl status named

# 实时跟踪日志
[root@dns-server ~]# journalctl -f _SYSTEMD_UNIT=named.service
```

### 10.2 防火墙放行

```bash
[root@dns-server ~]# firewall-cmd --add-service=dns
[root@dns-server ~]# firewall-cmd --add-service=dns --permanent
```

`dns` 服务对应 `UDP 53 + TCP 53`。

---

## §11 客户端测试与 /etc/resolv.conf

### 11.1 配置客户端 DNS

```bash
[root@dns-client ~]# nmcli connection modify ens33 \
    ipv4.method manual \
    ipv4.addresses 10.1.8.11/24 \
    ipv4.gateway 10.1.8.2 \
    ipv4.dns 10.1.8.10 \
    autoconnect yes

[root@dns-client ~]# nmcli connection up ens33
```

### 11.2 测试连通性

```bash
# ping 测试
[root@dns-client ~]# ping dns.laogao.cloud
PING dns.laogao.cloud (10.1.8.10) 56(84) bytes of data.
64 bytes from dns.laogao.cloud (10.1.8.10): icmp_seq=1 ttl=64 time=0.251 ms

# host 测试
[root@dns-client ~]# host student.laogao.cloud
student.laogao.cloud is an alias for client.laogao.cloud.
client.laogao.cloud has address 10.1.8.11

# 反向
[root@dns-client ~]# host 10.1.8.10
10.8.1.10.in-addr.arpa domain name pointer dns.laogao.cloud.

# getent（绕过解析器缓存）
[root@dns-client ~]# getent hosts student.laogao.cloud
10.1.8.11  client.laogao.cloud student.laogao.cloud
```

### 11.3 /etc/resolv.conf

```
nameserver 10.1.8.10
nameserver 114.114.114.114
search laogao.cloud
```

- `nameserver`：DNS 服务器 IP（最多 3 个）
- `search`：域名补全搜索列表

> **注意**：NetworkManager 会自动覆盖此文件。如果手动改完又被覆盖，给 `/etc/resolv.conf` 头部加 `# Generated by NetworkManager`，或停 NM。

---

## §12 Unbound 缓存 DNS 部署

### 12.1 适用场景

```
网络出口放 Unbound，TTL 内重复查询直接命中缓存
↓ 减少到上游 ISP DNS 的查询量
↓ 提升响应速度（本地命中 < 1ms）
```

### 12.2 安装与配置

```bash
[root@cache ~]# yum install -y unbound
```

`/etc/unbound/unbound.conf` 关键段：

```yaml
server:
    interface: 10.1.8.20
    interface: 2001:db8:1001::f0

    # 自动接口检测
    interface-automatic: yes

    # 访问控制
    access-control: 127.0.0.0/8 allow
    access-control: 172.25.0.0/24 allow
    access-control: 2001:db8:1001::/32 allow
    access-control: 10.1.8.0/24 allow
    access-control: 10.1.7.0/24 refuse       # 拒绝段返回 REFUSED

    # 禁用 libvirtd 自动生成的 dnsmasq 占端口 53
    # libvirtd 已默认用 dnsmasq 占住 53 端口

    # 不启用 DNSSEC 校验（如果上游不稳定）
    domain-insecure: laogao.cloud
    harden-dnssec-stripped: no

forward-zone:
    name: "."
    forward-addr: 10.1.8.10      # 转发到内部权威 DNS
```

### 12.3 启动与测试

```bash
# 校验配置
[root@cache ~]# unbound-checkconf
unbound-checkconf: no errors in /etc/unbound/unbound.conf

# 启动
[root@cache ~]# systemctl enable unbound --now

# 放防火墙
[root@cache ~]# firewall-cmd --add-service=dns --permanent

# 客户端测试
[root@client ~]# dig @10.1.8.20 client.laogao.cloud
```

### 12.4 缓存管理

```bash
# 导出缓存
[root@cache ~]# unbound-control dump_cache > dns_dump

# 清除单条
[root@server ~]# unbound-control flush student.laogao.cloud

# 清除整 zone
[root@server ~]# unbound-control flush_zone laogao.cloud

# 加载导出文件
[root@server ~]# unbound-control load_cache < dns_dump
```

---

## §13 Dnsmasq 轻量 DNS+DHCP

### 13.1 适用场景

- 小型网络（< 100 主机）
- 本地 hosts 增强（自动同步 `/etc/hosts`）
- DHCP + DNS 一体化
- 广告屏蔽（黑名单 → 127.0.0.1）

### 13.2 安装

```bash
[root@cache ~]# yum install -y dnsmasq
```

### 13.3 核心配置 `/etc/dnsmasq.conf`

```bash
# 上游 DNS
resolv-file=/etc/resolv.dnsmasq.conf

# 监听地址
listen-address=127.0.0.1
listen-address=10.1.8.20

# 指定域名走指定 DNS（forward）
server=/cn/114.114.114.114
server=/taobao.com/114.114.114.114
server=/google.com/8.8.8.8
server=/laogao.cloud/10.1.8.10    # 内部域名走内网 DNS

# 强制 A 记录（广告屏蔽）
address=/ad.youku.com/127.0.0.1
address=/ad.iqiyi.com/127.0.0.1

# 自定义 A 记录
address=/freehao123.com/123.123.123.123

# 读 /etc/hosts（默认 yes，不需要 no-hosts）
# 不读上游 /etc/resolv.conf（默认 yes，不需要 no-resolv）

# 缓存大小
cache-size=1000
```

`/etc/resolv.dnsmasq.conf`（上游 DNS 列表）：
```
nameserver 8.8.8.8
nameserver 8.8.4.4
```

### 13.4 启动

```bash
# 配置测试
[root@cache ~]# dnsmasq -test
[root@cache ~]# echo $?
0

# 启动
[root@cache ~]# systemctl enable dnsmasq --now

# 防火墙
[root@cache ~]# firewall-cmd --add-service=dns --permanent
```

### 13.5 配置读取顺序

```
dnsmasq 查询顺序：
1. /etc/hosts
2. /etc/dnsmasq.d/*.conf
3. /etc/dnsmasq.conf 中的 address=/server=
4. 上游 DNS（resolv-file 指定）
```

---

## §14 /etc/nsswitch.conf 解析顺序

Linux 解析主机名**不只走 DNS**，先看 `nsswitch.conf`：

```bash
# /etc/nsswitch.conf
hosts:      files dns myhostname
```

| 来源 | 含义 | 对应文件/服务 |
|------|------|---------------|
| `files` | 读本地 hosts 文件 | `/etc/hosts` |
| `dns` | 调系统 DNS 解析器 | `/etc/resolv.conf` 配置的上游 |
| `myhostname` | 解析本机主机名 | systemd-hostnamed |

```bash
# getent 走完整 nsswitch 链
[root@client ~]# getent hosts server.laogao.cloud
10.1.8.20  server.laogao.cloud server
```

---

## §15 dig/host/nslookup 排障命令

### 15.1 host（最简单）

```bash
# 安装
[root@localhost ~]# yum install -y bind-utils

# 查询 NS 记录
[root@localhost ~]# host -t NS huawei.com
huawei.com name server nsall.huawei.com.
huawei.com name server nsall4th.huawei.cn.

# 查询 A 记录
[root@localhost ~]# host www.qq.com
www.qq.com is an alias for www.qq.com.eo.dnse2.com.
www.qq.com.eo.dnse2.com has address 43.159.109.55

# 查询 MX
[root@localhost ~]# host -t MX qq.com
qq.com mail is handled by 10 mx3.qq.com.
```

### 15.2 dig（最详细）

```bash
[root@localhost ~]# dig -t A www.qq.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7 <<>> -t A www.qq.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 10549
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; QUESTION SECTION:
;www.qq.com.           IN A

;; ANSWER SECTION:
www.qq.com.   5 IN CNAME ins-r23tsuuf.ias.tencent-cloud.net.
ins-r23tsuuf.ias.tencent-cloud.net. 5 IN A 101.91.22.57
ins-r23tsuuf.ias.tencent-cloud.net. 5 IN A 101.91.42.232

;; Query time: 2292 msec
;; SERVER: 10.1.8.2#53(10.1.8.2)
```

**常用选项**：

| 选项 | 用途 |
|------|------|
| `+short` | 只返回结果 |
| `+nocmd +noall +answer` | 干净输出 |
| `@SERVER` | 指定 DNS 服务器 |
| `-x IP` | 反向解析（PTR） |
| `-t TYPE` | 指定记录类型（A/MX/NS/TXT…） |
| `+trace` | 显示完整递归路径 |
| `+tcp` | 强制 TCP（绕过 UDP 512 字节限制） |
| `+dnssec` | 显示 DNSSEC 验证信息 |

### 15.3 nslookup（交互式）

```bash
[root@localhost ~]# nslookup www.qq.com
Server:      10.1.8.2
Address: 10.1.8.2#53

Non-authoritative answer:
www.qq.com canonical name = ins-r23tsuuf.ias.tencent-cloud.net.
Name: ins-r23tsuuf.ias.tencent-cloud.net
Address: 101.91.42.232

# 指定 DNS
[root@localhost ~]# nslookup www.qq.com 114.114.114.114

# 交互模式
[root@localhost ~]# nslookup
> www.qq.com
> set q=A
> www.qq.com
```

### 15.4 whois（查域名注册信息）

```bash
[root@localhost ~]# yum install -y whois
[root@localhost ~]# whois qq.com
```

### 15.5 Windows 客户端命令

```cmd
C:\Users\69466>ping www.huawei.com
C:\Users\69466>ipconfig /displaydns          # 查看 DNS 缓存
C:\Users\69466>ipconfig /flushdns            # 清空 DNS 缓存
```

---

## §16 dig +trace 与状态码 NOERROR/SERVFAIL/NXDOMAIN/REFUSED

### 16.1 完整递归追踪

```bash
[user@host ~]$ dig +trace www.baidu.com

.           454534 IN NS  a.root-servers.net.   ← 根
.           454534 IN RRSIG NS 8 0 ...

;; Received 1125 bytes from 172.25.254.250#53 in 1 ms

com.        172800 IN NS  b.gtld-servers.net.   ← TLD
com.        86400  IN DS  ...

;; Received 1201 bytes from 192.33.4.12#53 in 251 ms

baidu.com.  172800 IN NS  ns2.baidu.com.        ← 权威

;; Received 761 bytes from 192.33.14.30#53 in 229 ms

www.baidu.com.  1200 IN CNAME www.a.shifen.com.

;; Received 239 bytes from 14.215.178.80#53 in 35 ms
```

### 16.2 DNS 状态码

| Code | 含义 | 排查方向 |
|------|------|----------|
| `NOERROR` | 查询成功 | 查 ANSWER SECTION 是否为空（空 = 域名存在但无此类型记录） |
| `SERVFAIL` | 服务器内部错误 | 检查 zone 文件语法、master/slave 同步、DNSSEC 校验失败 |
| `NXDOMAIN` | 域名不存在 | 检查拼写、是否漏了 FQDN 末尾的点 |
| `REFUSED` | 服务器拒绝 | 检查 ACL 配置 / `recursion no` / 防火墙 |
| `FORMERR` | 报文格式错误 | 检查 EDNS / TSIG 配置 |

### 16.3 常见 dig 错误模式

```
;; connection timed out; no servers could be reached
→ UDP/TCP 53 端口不通：检查防火墙、listen-on

;; Truncated, retrying in TCP mode.
;; Connection to 172.25.1.11#53 failed: host unreachable.
→ 大响应超 512 字节 UDP 限制，自动切 TCP；TCP 也失败说明对端拒绝

dig +tcp A laogao.cloud  → 强制 TCP 测试
```

---

## §17 子域委派与通配符 *

### 17.1 子域委派（Delegation）

**场景**：父域 `laogao.cloud` 把子域 `classroom.laogao.cloud` 交给另一台 DNS 管。

父域 zone 加 NS 记录（必须配 glue record）：

```dns
; 在 laogao.cloud.zone 中
classroom.laogao.cloud.   IN NS   ns1.classroom.laogao.cloud.
classroom.laogao.cloud.   IN NS   ns2.classroom.laogao.cloud.
ns1.classroom.laogao.cloud. IN A 10.1.8.50     ; glue record
ns2.classroom.laogao.cloud. IN A 10.1.8.51     ; glue record
```

子域服务器上独立配置 `classroom.laogao.cloud.zone`。

### 17.2 通配符（Wildcard）

```dns
*.laogao.cloud. IN A 172.25.254.254
```

匹配所有未明确定义的子域：`anything.laogao.cloud` → `172.25.254.254`。

---

## §18 CNAME 互指陷阱与 FQDN 规范

### 18.1 CNAME 互指 → NXDOMAIN

```dns
test.laogao.cloud. IN CNAME lab.laogao.cloud.
lab.laogao.cloud.  IN CNAME test.laogao.cloud.
```

CNAME A → B → A 会形成循环，DNS 解析器探测到后**直接返回 NXDOMAIN**。

### 18.2 FQDN 必须以 `.` 结尾

```
server.laogao.cloud.    ← 完整 FQDN（zone 文件里要写点）
server.laogao.cloud     ← 会被自动补全为 server.laogao.cloud.laogao.cloud.
```

CNAME 目标必须带 `.`，否则会去父域找子域。

### 18.3 NS 和 MX 不能指向 CNAME

```dns
; 错误！
laogao.cloud. IN NS server.laogao.cloud.
server.laogao.cloud. IN CNAME other.example.com.

; 正确
laogao.cloud. IN NS dns.laogao.cloud.
dns.laogao.cloud. IN A 10.1.8.10
```

---

## §19 主从同步、子域委派、转发器、视图（CDN 调度）

### 19.1 主从同步（Master / Slave）

主 `named.conf`：
```bind
zone "laogao.cloud" IN {
    type master;
    file "laogao.cloud.zone";
    allow-transfer { 10.1.8.20; };     # 允许此 IP 拉取 AXFR
    also-notify    { 10.1.8.20; };     # 主动通知（可选）
};
```

从 `named.conf`：
```bind
zone "laogao.cloud" IN {
    type slave;
    file "slaves/laogao.cloud.zone";   # 自动从 master 拉取
    masters { 10.1.8.10; };            # 主服务器 IP
};
```

**同步触发条件**（任一即可）：
1. 主端 SOA 序列号变更 + 从端定时 REFRESH 到期
2. 主端 `also-notify` 主动推 NOTIFY 给从端

### 19.2 转发器（Forwarder）

```bind
options {
    forwarders { 114.114.114.114; 8.8.8.8; };
    forward only;          # 转发失败也不迭代（更可控）
    forward first;         # 默认：先转发，失败再迭代
};
```

### 19.3 智能 DNS（View + ACL，CDN 调度）

```bind
acl "telecom" { 192.168.0.0/24; 10.0.0.0/8; };       # 电信用户
acl "unicom"  { 172.16.0.0/24; };                     # 联通用户

view "view_telecom" {
    match-clients { telecom; };
    zone "example.com" {
        type master;
        file "example.com.telecom.zone";   # 解析到电信 IP
    };
};

view "view_unicom" {
    match-clients { unicom; };
    zone "example.com" {
        type master;
        file "example.com.unicom.zone";    # 解析到联通 IP
    };
};
```

> **CDN 调度场景**：电信用户解析到电信机房，联通用户解析到联通机房，降低跨网延迟。

---

## §20 DNS 安全：TSIG + DNSSEC + 隐藏版本 + ACL

### 20.1 TSIG（Transaction Signature，主从同步密钥）

主端：
```bash
# 生成密钥
dnssec-keygen -a HMAC-SHA256 -b 256 -n HOST master-slave
# 输出：Kmaster-slave.+163+12345.key  Kmaster-slave.+163+12345.private
```

`/etc/named.conf`：
```bind
key "master-slave" {
    algorithm hmac-sha256;
    secret "base64编码的密钥字符串==";
};

zone "laogao.cloud" {
    type master;
    file "laogao.cloud.zone";
    allow-transfer { key "master-slave"; };   # 需密钥才能同步
};
```

从端 `named.conf`：
```bind
key "master-slave" {
    algorithm hmac-sha256;
    secret "base64编码的密钥字符串==";
};
server 10.1.8.10 {
    keys { master-slave; };
};
```

### 20.2 DNSSEC（防 DNS 欺骗）

```bind
options {
    dnssec-enable yes;
    dnssec-validation yes;
    dnssec-lookaside auto;
};
```

### 20.3 隐藏 BIND 版本

`/etc/named.conf`：
```bind
options {
    version "unknown";          # dig @server chaos txt version 不返回真实版本
};
```

### 20.4 ACL 加固（防放大攻击）

```bind
options {
    recursion       yes;
    allow-recursion { trusted-nets; };   # 限内部网段递归
    allow-query     { any; };            # 权威记录可被任意查询
    allow-transfer  { none; };           # 全局禁 AXFR
    rate-limit {
        responses-per-second 50;
    };
};
```

---

## §21 速查表：记录类型 + 默认端口 + 关键路径

### 21.1 DNS 记录类型

| 类型 | 名称 | 数据格式 | 用途 |
|------|------|----------|------|
| A | IPv4 地址 | `192.168.1.1` | 域名→IPv4 |
| AAAA | IPv6 地址 | `2001:db8::1` | 域名→IPv6 |
| CNAME | 别名 | `target.example.com.` | 别名→主名 |
| PTR | 指针 | `host.example.com.` | IP→域名 |
| NS | 名称服务器 | `ns1.example.com.` | 委派权威 |
| SOA | 起始授权 | `(mname rname serial …)` | zone 元数据 |
| MX | 邮件交换 | `10 mail.example.com.` | 邮件路由 |
| TXT | 文本 | `"v=spf1 -all"` | SPF/DKIM/验证 |
| SRV | 服务定位 | `0 100 389 server` | 服务发现 |
| CAA | CA 授权 | `0 issue "letsencrypt.org"` | 限制签发 CA |

### 21.2 默认端口

| 协议 | 端口 | 场景 |
|------|------|------|
| UDP 53 | DNS 查询 | 99% 场景 |
| TCP 53 | DNS AXFR / 大响应（>512B）/ DNSSEC | 区域传输 / 截断重试 |
| 853 | DoT（DNS over TLS） | 加密 DNS |

### 21.3 关键路径

| 路径 | 用途 |
|------|------|
| `/etc/named.conf` | BIND 主配置 |
| `/etc/named.rfc1912.zones` | RFC1912 预置 zone |
| `/var/named/` | zone 文件目录 |
| `/var/named/slaves/` | 从服务器同步来的 zone |
| `/etc/unbound/unbound.conf` | Unbound 配置 |
| `/etc/dnsmasq.conf` | Dnsmasq 配置 |
| `/etc/dnsmasq.d/*.conf` | Dnsmasq 配置片段 |
| `/etc/resolv.conf` | 客户端 DNS 配置 |
| `/etc/nsswitch.conf` | 解析顺序 |
| `/etc/hosts` | 本地 hosts 表 |
| `/var/log/messages` | named 默认日志 |

### 21.4 命令速查

| 命令 | 用途 |
|------|------|
| `named-checkconf` | 校验主配置 |
| `named-checkzone <zone> <file>` | 校验 zone |
| `rndc reload` | 重载配置 |
| `rndc status` | 查看运行状态 |
| `systemctl {start|stop|restart|status} named` | systemd 控制 |
| `dig @server name type` | 通用查询 |
| `dig +trace name` | 递归追踪 |
| `host [-t type] name` | 简单查询 |
| `nslookup [name] [server]` | 交互式查询 |
| `unbound-control dump_cache` | 导出 Unbound 缓存 |
| `dnsmasq -test` | 测试配置 |

---

## §22 易错点 ×12

### 1. listen-on 默认只监听 127.0.0.1

**症状**：本机 `dig @server` 正常，其他机器查不到。
**解法**：`listen-on port 53 { 127.0.0.1; 服务器IP; };`

### 2. zone 文件权限错（SELinux）

**症状**：`named-checkzone OK`，但 named 启动后查不到记录。
**解法**：
```bash
chmod 640 /var/named/*.zone
chown root:named /var/named/*.zone
chcon -t named_zone_t /var/named/*.zone
```

### 3. SOA 序列号忘加

**症状**：主端改了 zone，从端不刷新。
**解法**：每次修改 zone 后 `serial + 1`（推荐 `YYYYMMDDNN` 格式）。

### 4. CNAME 与 NS/MX 共存

**症状**：`zone example.com/IN: CNAME and other data` 错误。
**解法**：NS/MX 域名必须用 A 记录指向，不能 CNAME。

### 5. FQDN 末尾漏点

**症状**：解析结果变成 `host.example.com.example.com.`。
**解法**：CNAME/PTR/NS 目标必须以 `.` 结尾。

### 6. 反向 zone IP 顺序写错

**症状**：`host 10.1.8.10` 找不到。
**解法**：IP 段倒序。`10.1.8.0/24` 的 zone 名是 `8.1.10.in-addr.arpa.`，记录写 `10 IN PTR ...`。

### 7. allow-transfer 全开被拉空

**症状**：`dig axfr @server example.com` 拿到全部记录，安全审计告警。
**解法**：`allow-transfer { slave-IP; };`，对外禁止 AXFR。

### 8. 防火墙没放行

**症状**：`connection timed out; no servers could be reached`。
**解法**：`firewall-cmd --add-service=dns --permanent`。

### 9. NM 覆盖 resolv.conf

**症状**：手改 `/etc/resolv.conf` 后重启网络就丢。
**解法**：`nmcli connection modify ... ipv4.dns "8.8.8.8"`；或停 NM。

### 10. Dnsmasq 占 53 端口冲突

**症状**：`bind: address already in use`。
**解法**：`dnsmasq` 与 `libvirtd` 默认 `dnsmasq` 都占 53，关闭 libvirtd 自带 dnsmasq：
```bash
systemctl disable libvirtd
```

### 11. 通配符 `*` 不生效

**症状**：`*.laogao.cloud` 配置后，子域名仍 NXDOMAIN。
**解法**：确保 zone 文件里**没有**显式的同名 A 记录（显式记录优先于通配符）。

### 12. 主从反向解析不一致

**症状**：`dig -x IP` 在主正常，在从端 NXDOMAIN。
**解法**：反向 zone 也必须做主从同步（同步包含正反两个 zone）。

---

## §23 面试 8 大追问

### Q1: DNS 递归 vs 迭代查询的区别？

- **递归**：客户端只发一次请求，服务器返回**最终结果**（递归服务器代查）
- **迭代**：客户端可能被返回"你去问那个服务器"，要自己再发请求（根 → TLD → 权威）

### Q2: 为什么 DNS 默认用 UDP 53？

- UDP 报文小、延迟低（无握手）
- DNS 查询通常 < 512 字节，UDP 单包即可
- 大响应会切 TCP（EDNS0 可扩到 4096 字节 UDP）

### Q3: 什么时候 DNS 用 TCP 53？

1. 响应超 512 字节（EDNS0 后是 4096）
2. AXFR 区域传输
3. 主从 NOTIFY
4. DNSSEC 大签名

### Q4: CNAME 和 A 记录的区别？CDN 怎么用？

- A 记录：域名 → IP（最终结果）
- CNAME：域名 → 另一个域名（别名）
- **CDN 用法**：用户域名 `www.x.com CNAME www.x.com.cdnhwc1.com.`，CDN 厂商控制后者 A 记录，可动态调度到最近机房。

### Q5: 什么是 Anycast？根服务器为什么用？

Anycast = 同一 IP 广播到多个地理位置，路由器选最近的实例。
根服务器全球 13 个逻辑站点，但每个站点背后是 Anycast 集群，**实际有上千个物理节点**。

### Q6: DNS 欺骗（cache poisoning）怎么防？

- **源端口随机化**（bind 默认开启）
- **DNSSEC**：用公钥签名应答，验证签名
- **0x20 编码混淆**：大小写随机化 query
- **DoH/DoT**：HTTPS/TLS 加密通道

### Q7: dig +trace 输出为什么先看到根，再看到 .com？

DNS 解析按 **"." → TLD → 二级域 → 主机** 自顶向下查询。`dig +trace` 把每一步展示出来：
1. 根（13 组 a~m.root-servers.net）
2. .com TLD（13 组 gtld-servers.net）
3. baidu.com 权威 NS
4. 最终 A/CNAME

### Q8: /etc/resolv.conf 和 /etc/nsswitch.conf 谁先？

`/etc/nsswitch.conf` 决定**顺序**：
```
hosts: files dns myhostname
```
先 `/etc/hosts`（files），再 DNS（resolv.conf 配置），最后本机主机名。所以**本地 hosts 优先于 DNS**。

---

## §24 跨模块链接

- [[Linux网络#dns基础]] — DNS 客户端配置 `/etc/resolv.conf`
- [[Linux网络#ping]] — 用 ping 测 DNS 解析
- [[Linux防火墙#firewalld]] — `firewall-cmd --add-service=dns`
- [[Linux防火墙#端口管理]] — UDP/TCP 53 端口放行
- [[Linux服务与SSH]] — 服务启停、systemd 单元
- [[LinuxSELinux]] — named_zone_t / named_conf_t 上下文
- [[Linux用户权限#权限管理]] — zone 文件 0640 权限
- [[Linux文本处理#grep]] — 排障时日志检索
- [[Linux进程与负载]] — `systemctl status named` / `journalctl`