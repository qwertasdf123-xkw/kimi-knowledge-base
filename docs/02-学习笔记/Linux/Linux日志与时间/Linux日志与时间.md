---
title: Linux 日志与时间 — rsyslog + journald + chrony
desc: 基于 05.CentOS-7-系统管理-1/16. Linux 日志管理.pdf + 17. Linux 时间管理.pdf 的实操笔记。覆盖 rsyslog 规则、facility/priority、journalctl、logger、date/hwclock/timedatectl、chrony 同步、chronyc sources。
type: 笔记
module: Linux日志与时间
pdf: 05.16 日志管理.pdf + 05.17 时间管理.pdf
pdf_size: 449 + 382 = 831 行
scope: CentOS-7 (rsyslog + systemd-journald + chrony)
status: 完成
---

# Linux 日志与时间 — rsyslog + journald + chrony

> **范围**：基于《CentOS-7 系统管理 1》第 16、17 章 整理。
> 覆盖 **rsyslog**（传统日志）+ **systemd-journald**（systemd 日志）+ **chrony**（时间同步）+ **date / hwclock / timedatectl**。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：日志 = 系统的"黑匣子"]]
- [[#§1 Linux 日志系统全景：rsyslog + journald]]
- [[#§2 /var/log 目录结构]]
- [[#§3 rsyslog 配置 /etc/rsyslog.conf]]
- [[#§4 facility 8 种日志来源]]
- [[#§5 priority 8 级严重程度]]
- [[#§6 规则语法 facility.priority target]]
- [[#§7 实战：自定义 facility + logger 写日志]]
- [[#§8 rsyslog 远程日志（TCP/UDP）]]
- [[#§9 systemd-journald 是什么]]
- [[#§10 /etc/systemd/journald.conf 配置]]
- [[#§11 Storage= 三种模式]]
- [[#§12 journalctl 用法大全]]
- [[#§13 实战：服务故障 5 个案例]]
- [[#§14 date 命令 + 时间格式]]
- [[#§15 hwclock 硬件时钟]]
- [[#§16 timedatectl 时间管家]]
- [[#§17 tzselect 时区选择]]
- [[#§18 chronyd 时间同步]]
- [[#§19 chronyc sources 查同步源]]
- [[#§20 实战：服务器 + 客户端 NTP 配置]]
- [[#§21 速查表]]
- [[#§22 易错点 ×12]]
- [[#§23 面试 6 大追问]]
- [[#§24 链路]]

---

## §0 心智模型：日志 = 系统的"黑匣子"

```
Linux 系统的"日记本"：
  应用层：app 自己写日志（access.log、error.log）
  系统层：rsyslog 统一收集 → 分类存到 /var/log
  内核层：journald 收 systemd 服务日志 → 二进制存到 /var/log/journal
  时间层：chrony 同步网络时间
```

**为什么需要日志**：
- 故障排查（系统挂了 → 看日志找原因）
- 安全审计（谁登录过 → /var/log/secure）
- 性能分析（响应慢 → 看慢查询日志）
- 合规要求（金融行业必须保存 5 年）

**CentOS-7 日志栈**：
```
                     应用层（app）
                          │
                          ↓
                  ┌───────────────────┐
                  │  systemd-journald │   ← 收所有 systemd 服务日志
                  │  （二进制索引）     │
                  └─────────┬─────────┘
                            │
                            ↓
                  ┌───────────────────┐
                  │     rsyslog       │   ← 收传统日志（按 facility 分流）
                  │  （文本分类）       │
                  └─────────┬─────────┘
                            │
                ┌───────────┼───────────┐
                ↓           ↓           ↓
          /var/log/messages /var/log/secure /var/log/cron ...
```

---

## §1 Linux 日志系统全景：rsyslog + journald

| | rsyslog | systemd-journald |
|---|---|---|
| 来源 | 老牌（syslog → syslog-ng → rsyslog）| systemd 自带 |
| 格式 | **文本** | **二进制** |
| 存储 | `/var/log/*.log` | `/var/log/journal/` |
| 配置 | `/etc/rsyslog.conf` | `/etc/systemd/journald.conf` |
| 查询 | `grep / less / tail` | `journalctl` |
| 远程 | 天然支持（TCP/UDP）| 需转发给 rsyslog |
| 性能 | 中等 | 快（索引） |

> 💡 **journald 早，rsyslog 久**。journald 诞生晚但更快，rsyslog 兼容老传统。

---

## §2 /var/log 目录结构

```bash
[xkw@centos7 ~]$ ls /var/log/
amanda           # 备份客户端日志
anaconda.*       # 安装日志
audit/           # auditd 审计日志
btmp             # 失败的登录尝试（lastb）
chrony/          # chrony 时间同步日志
cron             # cron 计划任务日志
dmesg            # 内核启动消息（dmesg 命令读）
firewalld        # firewalld 防火墙日志
lastlog          # 每个用户最后登录时间
maillog          # 邮件日志
messages         # **系统通用日志**（最重要！）
secure           # **认证日志**（SSH/su/sudo 都记这）
spooler          # UUCP 新闻打印队列
sssd/            # sssd 守护进程日志
tallylog         # pam_faillock 失败计数
wtmp             # 成功的登录记录（last 读）
```

**5 大常用日志**：

| 文件 | 内容 | 读法 |
|---|---|---|
| `/var/log/messages` | **系统通用日志**（systemd、daemon、内核等）| `tail -f` |
| `/var/log/secure` | **认证日志**（SSH 登录、su、sudo）| `tail -f` |
| `/var/log/cron` | **cron 计划任务日志** | `tail -f` |
| `/var/log/maillog` | **邮件日志** | `tail -f` |
| `/var/log/boot.log` | **启动日志** | `cat` |

**格式**：
```
Nov 10 10:27:26 centos7 sshd[2755]: Accepted password for xkw from 10.1.8.1 port 5530 ssh2
│  │   │      │      │      │                                                │
│  │   │      │      │      └─ 消息内容                                        │
│  │   │      │      └─ PID                                                   │
│  │   │      └─ 进程名                                                       │
│  │   └─ 主机名                                                              │
│  └─ 时间                                                                    │
└─ 时间戳                                                                     │
```

---

## §3 rsyslog 配置 /etc/rsyslog.conf

```bash
[root@centos7 ~]# vim /etc/rsyslog.conf

# 模块加载（UDP/TCP 接收等）
module(load="imuxsock")  # 本地系统日志
module(load="imjournal") # 接收 journald 转发

# Include 子配置（方便管理）
include(file="/etc/rsyslog.d/*.conf" mode="optional")

#### RULES ####
*.info;mail.none;authpriv.none;cron.none    /var/log/messages
authpriv.*                                   /var/log/secure
mail.*                                       -/var/log/maillog
cron.*                                       /var/log/cron
*.emerg                                      :omusrmsg:*
uucp,news.crit                              /var/log/spooler
local7.*                                    /var/log/boot.log
```

> ⚠️ `-/var/log/maillog` 前的 `-` 表示**异步写入**（不立即刷盘，性能好但崩溃可能丢日志）。

---

## §4 facility 8 种日志来源

| facility | 含义 |
|---|---|
| **auth (authpriv)** | 认证（密码、SSH、su、sudo）|
| **cron** | 计划任务 |
| **daemon** | 守护进程 |
| **kern** | 内核 |
| **lpr** | 打印 |
| **mail** | 邮件 |
| **news** | 新闻（UUCP）|
| **syslog** | syslog 自身 |
| **user** | 用户级 |
| **uucp** | UUCP |
| **local0~local7** | 自定义（程序可指定）|

---

## §5 priority 8 级严重程度

| 数字 | 级别 | 含义 |
|---|---|---|
| 0 | **emerg** | 系统不可用（紧急）|
| 1 | alert | 必须立即处理 |
| 2 | crit | 严重状态 |
| 3 | **err** | 错误 |
| 4 | **warning** | 警告 |
| 5 | notice | 重要信息 |
| 6 | **info** | 一般信息（默认）|
| 7 | debug | 调试 |
| 8 | none | 无（特殊用途）|

**严重程度递增方向**：`debug < info < notice < warning < err < crit < alert < emerg`

> 💡 **rsyslog 写 `info` 会同时记录更高级别**（emerg/alert/crit/err/warning/notice/info）。

---

## §6 规则语法 facility.priority target

```
facility.priority   target
      ↓             ↓
   日志来源      动作（写到哪）
```

**优先级前缀**：
```
.    = 该级及以上（如 .err = err/crit/alert/emerg）
.=   = 只该级（如 .=err = 只 err）
.!   = 取反（除该级外）
.none= 完全不匹配
```

**示例**：

```bash
# 所有 info 以上到 /var/log/messages（但排除 mail/authpriv/cron）
*.info;mail.none;authpriv.none;cron.none    /var/log/messages

# authpriv.* 写到 /var/log/secure
authpriv.*    /var/log/secure

# mail 写到 /var/log/maillog（异步）
mail.*    -/var/log/maillog

# cron 写到 /var/log/cron
cron.*    /var/log/cron

# 所有 emerg 消息广播给所有登录用户（墙）
*.emerg    :omusrmsg:*

# 多个 facility
auth,authpriv.*    /var/log/auth.log

# 只该级
*.=emerg    /var/log/emerg.log
*.=err      /var/log/err.log

# 取反：除 mail 外所有 info
*.*;mail.!info    /var/log/all-but-mail.log
```

---

## §7 实战：自定义 facility + logger 写日志

### 7.1 自定义 facility 写日志

```bash
# 1) 创建子配置文件（不动主配置）
[root@centos7 ~]# vim /etc/rsyslog.d/xkw.conf
local5.*    /var/log/xkw.log

# 2) 重启 rsyslog
[root@centos7 ~]# systemctl restart rsyslog.service

# 3) 用 logger 命令写一条日志
[xkw@centos7 ~]$ logger -p local5.info "test my log"

# 4) 看日志
[root@centos7 ~]# cat /var/log/xkw.log
Nov 10 10:32:26 centos7 xkw: test my log
```

### 7.2 logger 命令详解

```bash
# 基本
logger "hello world"
# 默认 facility=user, priority=notice

# 指定 facility 和 priority
logger -p local5.info "my log message"
logger -p auth.err "auth error"

# 带 tag（显示在日志里）
logger -t myapp "starting"

# 从 stdin 读
echo "another log" | logger

# 从文件读
logger -f /var/log/myapp.log

# 用 nc 把日志发给远程服务器
echo "remote log" | logger -n 10.1.8.10 -P 514
```

### 7.3 应用层指定 facility：SyslogFacility

```bash
# sshd 用 authpriv facility
[root@server ~]# grep AUTHPRIV /etc/ssh/sshd_config
SyslogFacility AUTHPRIV
# ↑ sshd 的日志会带 authpriv 标签
# → 走 /var/log/secure（因为 authpriv.* /var/log/secure）

[root@server ~]# tail -1 /var/log/secure
Jul 25 14:10:39 server sshd[20527]: pam_unix(sshd:session): session opened for user root by (uid=0)
```

---

## §8 rsyslog 远程日志（TCP/UDP）

### 8.1 服务器端（接收端）

```bash
# 1) 启用 TCP 接收
[root@server ~]# vim /etc/rsyslog.conf
module(load="imtcp")         # 加载 TCP 输入模块
input(type="imtcp" port="514")  # 监听 514 端口

# 2) 重启
[root@server ~]# systemctl restart rsyslog.service

# 3) 关防火墙（演示用，生产要放行 514）
[root@server ~]# systemctl disable firewalld.service --now
```

### 8.2 客户端（发送端）

```bash
# 1) 配转发
[root@client ~]# echo '*.* @@10.1.8.10' > /etc/rsyslog.d/remote.conf
#                                                          ↑
#                                                两个 @ = TCP
#                                                一个 @ = UDP

# 2) 重启
[root@client ~]# systemctl restart rsyslog.service
```

### 8.3 验证

```bash
# 在 client 上做 SSH 等操作
[xkw@client ~]$ ssh root@server

# 在 server 上看日志（看到 client 的）
[root@server ~]# tail -f /var/log/secure
Jul 25 14:47:28 client sshd[3901]: error: Received disconnect from 10.1.8.1 port 51521:0:
Jul 25 14:47:43 client sshd[3901]: Disconnected from user root 10.1.8.1 port 51521
# ↑ 主机名是 client！日志从 client 转发来了
```

> 💡 **生产环境**：所有服务器日志发到集中日志服务器（ELK / Loki / Splunk）。

---

## §9 systemd-journald 是什么

```
systemd-journald = systemd 自带的日志服务
  - 收所有 systemd unit 的日志
  - 索引化（快）
  - 二进制存储（不可直接看，必须 journalctl 读）
  - 自动按 service / PID / 用户 / 时间等过滤

配置文件：/etc/systemd/journald.conf
```

**查看日志路径**：

```bash
# 看 journald 存哪
ls /var/log/journal/
# b8b0960cabe3452ca432f45acb1df028   ← 机器 ID
#   ↑ 每个 journal 文件按机器 ID 分类
```

---

## §10 /etc/systemd/journald.conf 配置

```bash
[root@centos7 ~]# vim /etc/systemd/journald.conf

[Journal]
# Storage= 控制日志存哪
Storage=persistent          # 持久化（默认）
# Storage=volatile          # 内存（重启丢失）
# Storage=auto              # 自动（有 /var/log/journal 就 persistent，否则 volatile）
# Storage=none              # 不存（仅转发）

# SystemMaxUse= 日志最大占多少磁盘
SystemMaxUse=4G

# SystemKeepFree= 留多少磁盘空间
SystemKeepFree=1G

# MaxRetentionSec= 保留多久（秒）
MaxRetentionSec=1month
```

---

## §11 Storage= 三种模式

| 模式 | 存储位置 | 重启后 |
|---|---|---|
| `persistent`（默认）| `/var/log/journal/` | **保留** |
| `volatile` | `/run/log/journal/` | **丢失**（内存）|
| `auto` | 自动检测 | 看有没有 /var/log/journal |
| `none` | 不存本地 | 仅转发给 rsyslog |

```bash
# 改为持久化
[root@centos7 ~]# vim /etc/systemd/journald.conf
[Journal]
Storage=persistent

[root@centos7 ~]# systemctl restart systemd-journald

# 看日志目录
[root@centos7 ~]# ls /var/log/journal/
b8b0960cabe3452ca432f45acb1df028
```

---

## §12 journalctl 用法大全

### 12.1 基础查询

```bash
# 全看（默认分页）
journalctl

# 跟踪（实时）
journalctl -f

# 最近 N 条
journalctl -n 5
journalctl -n 50

# 错误级别
journalctl -p err
journalctl -p warning

# 时间范围
journalctl --since today
journalctl --since "2025-10-31 08:00" --until "2025-10-31 18:00"
journalctl --since "-1 hour"
journalctl --since "yesterday"

# 按 unit
journalctl -u sshd
journalctl -u nginx.service

# 按 PID
journalctl _PID=1234

# 按用户
journalctl _UID=1000

# 按可执行文件
journalctl /usr/sbin/sshd

# 启动日志
journalctl -b
journalctl -b 0          # 本次启动
journalctl -b -1         # 上次启动
journalctl -b 1          # 倒数第 1 次

# 详细字段
journalctl -o verbose
```

### 12.2 高级选项

```bash
# 不分页（适合管道）
journalctl --no-pager

# 倒序
journalctl -r

# JSON 输出
journalctl -o json

# 内核日志（dmesg 替代品）
journalctl -k

# 磁盘占用
journalctl --disk-usage

# 清理旧日志
journalctl --vacuum-time=2weeks   # 只留 2 周
journalctl --vacuum-size=100M     # 限制 100MB

# 验证日志完整性
journalctl --verify
```

### 12.3 与 dmesg 的区别

```bash
# dmesg：只显示内核 ring buffer 日志
dmesg

# journalctl -k：等价 dmesg，但更全（包括重启前的）
journalctl -k
```

---

## §13 实战：服务故障 5 个案例

### 案例 1：sshd 配置文件丢了

```bash
# 模拟故障
[root@centos7 ~]# mv /etc/ssh/sshd_config .
[root@centos7 ~]# systemctl restart sshd

# 看日志找原因
[root@centos7 ~]# journalctl -f
7 28 13:52:26 server.xkw.cloud systemd[1]: Starting OpenSSH server daemon...
7 28 13:52:26 server.xkw.cloud sshd[2045]: /etc/ssh/sshd_config: No such file or directory
7 28 13:52:26 server.xkw.cloud systemd[1]: sshd.service: main process exited, code=exited, status=1/...
7 28 13:52:27 server.xkw.cloud systemd[1]: Failed to start OpenSSH server
# ↑ 一目了然！

# 修复
[root@centos7 ~]# mv sshd_config /etc/ssh/sshd_config
[root@centos7 ~]# systemctl restart sshd
```

### 案例 2：sshd 配置加了错选项

```bash
# 模拟：加一个非法选项
[root@centos7 ~]# echo 'PermitRootLogin hahaha' >> /etc/ssh/sshd_config
[root@centos7 ~]# systemctl restart sshd
# Job for sshd.service failed...

# 看日志
[root@centos7 ~]# journalctl -f
7 28 14:30:03 server.xkw.cloud sshd[2806]: /etc/ssh/sshd_config line 141: unsupported option "hahaha".
7 28 14:30:03 server.xkw.cloud systemd[1]: sshd.service: main process exited, code=exited, status=25
# ↑ 错误码 25 = 配置错

# 修复
[root@server ~]# sed -i '/hahaha/d' /etc/ssh/sshd_config
[root@centos7 ~]# systemctl restart sshd
```

### 案例 3：httpd 端口配错

```bash
# 模拟：监听 80000（越界）
[root@centos7 ~]# sed -i 's/Listen 80/Listen 80000/g' /etc/httpd/conf/httpd.conf
[root@centos7 ~]# systemctl restart httpd
# Job for httpd.service failed...

# 看日志
[root@centos7 ~]# journalctl -f
7 28 14:34:49 server.xkw.cloud httpd[2877]: AH00526: Syntax error on line 42 of /etc/httpd/conf/httpd.conf
7 28 14:34:49 server.xkw.cloud httpd[2877]: Invalid address or port
# ↑ 错误信息直接给原因

# 修复
[root@centos7 ~]# sed -i 's/Listen 80000/Listen 80/g' /etc/httpd/conf/httpd.conf
[root@centos7 ~]# systemctl restart httpd
```

### 案例 4：磁盘写满导致服务起不来

```bash
# 症状：service 启动失败
# 看日志
journalctl -u nginx.service -n 50
# 看到 "No space left on device"

# 解决：清日志
journalctl --vacuum-size=100M
# 或删 /var/log/*

# 找到大文件
du -sh /var/log/* | sort -rh | head
```

### 案例 5：日志被改权限

```bash
# 看 sshd 报错 "Permission denied" 写日志
journalctl -u sshd
# "Failed to write to /var/log/secure: Permission denied"

# 解：恢复权限
chmod 600 /var/log/secure
chown root:root /var/log/secure
```

---

## §14 date 命令 + 时间格式

```bash
# 看时间
[root@centos7 ~]# date
2025年 10月 31日 星期五 14:23:15 CST

# 改语言为英文
[root@centos7 ~]# LANG=en_US.utf8 date
Thu Oct 31 14:23:15 CST 2025

# 设置时间
[root@centos7 ~]# date -s '2025-11-11 11:30:10 CST'
# 或
[root@centos7 ~]# date -s 'Thu Nov 11 11:30:59 CST 2025'

# 格式输出
date +%Y              # 2025（年）
date +%m              # 10（月）
date +%d              # 31（日）
date +%H              # 14（时）
date +%M              # 23（分）
date +%S              # 15（秒）
date +%F              # 2025-10-31（年-月-日）
date +%T              # 14:23:15（时分秒）
date +"%Y-%m-%d %H:%M:%S"   # 自定义格式

# 实战：备份带日期
tar -czf etc-$(date +%Y%m%d).tar.gz /etc
# etc-20251031.tar.gz
```

---

## §15 hwclock 硬件时钟

```
硬件时钟（RTC，Real Time Clock）
  - 在主板上，关机也走（电池供电）
  - 系统启动时从硬件时钟读时间
  - 关机的准确时间全靠它

系统时钟（System Clock）
  - 内核维护
  - 关机就没了
  - 开机时从硬件时钟同步
```

```bash
# 看硬件时钟
[root@centos7 ~]# hwclock -r
2025-11-11 11:35:56 -0.320836 seconds

# 把系统时间写到硬件（同步）
[root@centos7 ~]# hwclock -w
#   -w = --systohc（system → hardware）

# 把硬件时间读到系统
[root@centos7 ~]# hwclock -s
#   -s = --hctosys（hardware → system）
```

---

## §16 timedatectl 时间管家

```bash
# 看时间状态
[root@centos7 ~]# timedatectl
      Local time:  2025-11-11 11:38:00 CST      # 本地时间
  Universal time:  2025-11-11 03:38:00 UTC      # UTC（格林威治）
        RTC time:  2025-11-11 03:38:07          # 硬件时钟
        Time zone: Asia/Shanghai (CST, +0800)   # 时区
    NTP enabled: yes                             # 是否启用 NTP
NTP synchronized: no                             # 是否同步成功
 RTC in local TZ: no                             # 硬件是否用本地时间
      DST active: n/a                            # 夏令时
```

### 16.1 启用/禁用 NTP

```bash
# 禁用 NTP（手动管时间）
[root@centos7 ~]# timedatectl set-ntp no

# 启用 NTP（chronyd 自动同步）
[root@centos7 ~]# timedatectl set-ntp yes
```

### 16.2 手动设置时间

```bash
# 必须先关 NTP
[root@centos7 ~]# timedatectl set-ntp no
[root@centos7 ~]# timedatectl set-time '2025-11-10 11:42:54'

# NTP 开着会失败
[root@centos7 ~]# timedatectl set-time '2025-11-10 11:42:54'
Failed to set time: Automatic time synchronization is enabled
```

### 16.3 设置时区

```bash
# 看时区列表
timedatectl list-timezones

# 设时区
[root@centos7 ~]# timedatectl set-timezone Asia/Shanghai
```

---

## §17 tzselect 时区选择

```bash
# 交互式选时区
[root@centos7 ~]# tzselect
Please identify a location so that time zone rules can be set correctly.

Please select a continent or ocean.
1) Africa
2) Americas
3) Antarctica
...
5) Asia       ← 选 5
9) Pacific Ocean
10) none - I want to specify the time zone using the Posix TZ format.
#? 5

Please select a country.
1) Afghanistan         18) Israel            35) Palestine
...
9) China        ← 选 9（中国）
#? 9

Please select one of the following time zone regions.
1) Beijing Time
2) Xinjiang Time
#? 1       ← 选 1（北京）

Therefore TZ='Asia/Shanghai' will be used.
Local time is now: Mon Jul 28 16:03:22 CST 2025.
Universal Time is now: Mon Jul 28 08:03:22 UTC 2025.

# 永久生效：写到 ~/.profile
echo 'TZ="Asia/Shanghai"; export TZ' >> ~/.profile
```

> 💡 **面试题**：tzselect 和 timedatectl 有什么区别？
> 答：tzselect 是交互式向导（用户层 ~/.profile），timedatectl 是系统层命令（改 /etc/localtime）。

---

## §18 chronyd 时间同步

```
chrony = NTP 客户端/服务器
  替代老 ntpd
  更快适应网络抖动
  CentOS-7 默认装

配置文件：/etc/chrony.conf
服务：chronyd
```

### 18.1 客户端：指向 NTP 服务器

```bash
# 1) 改配置
[root@centos7 ~]# vim /etc/chrony.conf

# 注释掉默认 pool，加阿里云
# pool 2.rocky.pool.ntp.org iburst
server ntp.aliyun.com iburst
# ↑ iburst = 首次连发 8 个包（快速同步）

# 2) 启用并启动
[root@centos7 ~]# systemctl enable chronyd --now

# 3) 立即同步
[root@centos7 ~]# systemctl restart chronyd
```

### 18.2 服务器：对外提供时间服务

```bash
# 1) 改配置
[root@server ~]# vim /etc/chrony.conf

# 监听本机 IP（不监听 0.0.0.0 = 安全）
bindaddress 10.1.8.10

# 允许哪些网段同步
allow 10.1.8.0/24

# 2) 重启
[root@server ~]# systemctl restart chronyd

# 3) 关防火墙（演示）
[root@server ~]# systemctl stop firewalld.service
```

### 18.3 客户端：指向自己服务器

```bash
[root@client ~]# vim /etc/chrony.conf
# 指向自己的 NTP 服务器
server 10.1.8.10 iburst

[root@client ~]# systemctl restart chronyd
```

---

## §19 chronyc sources 查同步源

```bash
# 看同步状态
[root@centos7 ~]# chronyc sources -v

.-- Source mode  '^' = server, '=' = peer, '#' = local clock.
 / .- Source state '*' = current best, '+' = combined, '-' = not combined,
| /             'x' = may be in error, '~' = too variable, '?' = unusable.
||                                                .- xxxx [ yyyy ] +/- zzzz
||        Reachability register (octal) -.        | xxxx = adjusted offset,
||        Log2(Polling interval) --.   |          | yyyy = measured offset,
||                               \     |          | zzzz = estimated error.
||                                ||          \
MS Name/IP address         Stratum Poll Reach LastRx Last sample
==============================================================================
^* 203.107.6.88                  2   6   377     9  -1840us[-4378us]  +/-  23ms
# ↑ 关键字段：
# ^* = 当前最佳源（带 * = 已同步）
# ^+ = 候选源
# ^? = 不可达
# Stratum = 层数（1=根，2=二级...）
# Poll = 轮询间隔（秒）
# Reach = 可达性（377 八进制 = 全部成功）
# LastRx = 上次收到时间
# Last sample = 上次采样偏差
```

**其他命令**：

```bash
chronyc tracking          # 看同步偏差
chronyc sourcestats       # 源统计
chronyc activity          # 活跃 server/peer 数
chronyc ntpdata           # NTP 数据

# 手动立即同步
chronyc makestep
```

---

## §20 实战：服务器 + 客户端 NTP 配置

### 场景：公司内部时间同步架构

```
公司 NTP 服务器 (10.1.8.10)
      ↑ 从公网 ntp.aliyun.com 同步
      ↓ 给内网客户端同步
公司所有 Linux 服务器 (10.1.8.0/24)
```

### 服务器端配置

```bash
[root@server ~]# vim /etc/chrony.conf
# 1. 上游（公网）
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst

# 2. 监听本机内网 IP
bindaddress 10.1.8.10

# 3. 允许内网同步
allow 10.1.8.0/24

# 4. 重启
[root@server ~]# systemctl restart chronyd
```

### 客户端配置

```bash
[root@client ~]# vim /etc/chrony.conf
# 指向公司 NTP 服务器
server 10.1.8.10 iburst

# 重启
[root@client ~]# systemctl restart chronyd

# 验证
[root@client ~]# chronyc sources -v
^* server.xkw.cloud  10  6  377  ...   +0us[ +43ms]  +/-  76ms
# ↑ 显示同步源是 server.xkw.cloud（公司服务器）
```

---

## §21 速查表

### 21.1 日志

```bash
# 看日志
tail -f /var/log/messages       # 实时
tail -100 /var/log/secure        # 最近 100 行
grep "error" /var/log/messages   # 过滤
less /var/log/messages           # 分页

# journalctl
journalctl                       # 全看
journalctl -f                    # 实时
journalctl -u nginx              # 按服务
journalctl -p err                # 按级别
journalctl --since today         # 今日
journalctl --since "-1 hour"     # 最近 1 小时
journalctl -b                    # 本次启动
journalctl _PID=1234             # 按 PID
journalctl -n 50                 # 最近 50 条

# 写日志
logger "hello"
logger -p local5.info "test"
logger -t myapp "starting"

# rsyslog 重启
systemctl restart rsyslog

# 远程日志
echo '*.* @@10.1.8.10' > /etc/rsyslog.d/remote.conf
systemctl restart rsyslog

# 清理
journalctl --vacuum-time=2weeks
journalctl --vacuum-size=100M
```

### 21.2 时间

```bash
date
date +"%Y-%m-%d %H:%M:%S"
date -s '2025-11-11 11:30:10 CST'

hwclock -r              # 看硬件时钟
hwclock -w              # 系统 → 硬件
hwclock -s              # 硬件 → 系统

timedatectl
timedatectl set-time '2025-11-10 11:42:54'
timedatectl set-ntp yes/no
timedatectl set-timezone Asia/Shanghai

tzselect                # 交互式选时区

# chrony
chronyc sources -v
chronyc tracking
chronyc makestep
```

---

## §22 易错点 ×12

### 1. ❌ 直接改 /var/log/secure 权限

```bash
chmod 777 /var/log/secure    # ⚠️ sshd 会写不进去
chmod 600 /var/log/secure
chown root:root /var/log/secure
```

### 2. ❌ rsyslog 修改后忘 restart

```bash
vim /etc/rsyslog.conf
# 没重启 → 改的配置没生效
systemctl restart rsyslog
```

### 3. ❌ journald 切 persistent 后忘建目录

```bash
Storage=persistent
systemctl restart systemd-journald
# ⚠️ 第一次会建目录，但磁盘满会失败
# 解：先 mkdir -p /var/log/journal
```

### 4. ❌ timedatectl set-time 时 NTP 开着

```bash
timedatectl set-time '...'
# Failed to set time: Automatic time synchronization is enabled
# 解：先 set-ntp no
```

### 5. ❌ date 设时间却没设硬件时钟

```bash
date -s '...'
# 系统时间改了，重启后又错（硬件时钟没改）
hwclock -w     # 一定要加这一行
```

### 6. ❌ chrony 服务没启就用 chronyc

```bash
systemctl status chronyd
# inactive → chronyc 命令无效
systemctl enable chronyd --now
```

### 7. ❌ chronyc sources 看不到 `^*`

```bash
# 没同步上（Reach=0 或 ^?）
# 解：
# 1) 看 chronyd 服务在跑
# 2) 看 NTP 服务器可达（ping）
# 3) 看防火墙放行 UDP 123
firewall-cmd --add-port=123/udp
```

### 8. ❌ 远程日志的端口被防火墙挡

```bash
# TCP/UDP 514 没放行
firewall-cmd --add-port=514/tcp --permanent
firewall-cmd --add-port=514/udp --permanent
firewall-cmd --reload
```

### 9. ❌ logger 没指定 priority 默认是 notice

```bash
logger "hello"
# 默认 notice（不算低），但容易被忽略
# 调试时建议：logger -p user.err "test"
```

### 10. ❌ journalctl 不分页用了管道

```bash
journalctl | grep nginx
# 默认 less 分页 → 看不到输出
journalctl --no-pager | grep nginx
```

### 11. ❌ 时区配错导致日志时间不对

```bash
# 改时区后老日志时间仍是 UTC
# 这是正常的！历史日志保持原样
```

### 12. ❌ chrony 和 ntpd 同时装

```bash
# 同时装会冲突（都监听 123 端口）
yum remove ntp
systemctl disable ntpd --now
```

---

## §23 面试 6 大追问

### Q1：rsyslog 和 journald 区别？

**答**：

| | rsyslog | journald |
|---|---|---|
| 格式 | 文本 | 二进制（索引）|
| 速度 | 慢（grep）| 快（journalctl）|
| 远程 | 天然支持 | 需转发 |
| 查询 | grep / tail | journalctl |
| 持久化 | /var/log/*.log | /var/log/journal/ |

生产建议：**两个都开**，journald 做运行时，rsyslog 做长期归档。

### Q2：日志 8 级 priority？

**答**：debug < info < notice < warning < err < crit < alert < emerg（数字 7-0）
- 写 `.info` 等于 info + notice + warning + ... + emerg
- 写 `.=err` 只匹配 err

### Q3：/var/log/secure 记录什么？

**答**：所有认证日志，包括：
- SSH 登录（Accepted password / Failed password）
- su / sudo 切换用户
- pam_unix 认证事件

### Q4：NTP 用 chrony 还是 ntpd？

**答**：**CentOS-7 推荐 chrony**。
- chrony 更快适应网络抖动（云环境）
- ntpd 老牌但启动慢
- RHEL 8+ 已默认 chrony

### Q5：怎么把日志集中到一台服务器？

**答**：
```bash
# 客户端（rsyslog）
echo '*.* @@10.1.8.10' > /etc/rsyslog.d/remote.conf
systemctl restart rsyslog

# 服务器端（rsyslog）
# /etc/rsyslog.conf 加：
module(load="imtcp")
input(type="imtcp" port="514")
systemctl restart rsyslog
```

### Q6：journalctl 怎么按 service 查？

**答**：`journalctl -u <unit>`
```bash
journalctl -u sshd
journalctl -u nginx.service --since today
journalctl -u crond -f
```

---

## §24 链路

| 笔记 | 关系 |
|---|---|
| [[Linux服务与SSH/Linux服务与SSH]] | journalctl -u 看服务日志 |
| [[LinuxShell/shell]] | `logger` 写脚本调试日志 |
| [[Linux用户权限/user-permission]] | /var/log/secure 记录 su/sudo |
| [[Linux包管理/package]] | yum install chrony |
| [[Linux文本处理/grep]] | grep /var/log/messages |

**下一步**：完成 Linux日志与时间 后可以选择：
- 🎯 **第 3 波 ②** [[Linux文件传输/]]（05.19+20 共 2 PDF）—— tar / scp / rsync
- 🎯 **第 4 波 ①** [[Linux存储/]]（06.4-8 共 5 PDF）—— 文件系统 / 分区 / RAID / LVM / swap