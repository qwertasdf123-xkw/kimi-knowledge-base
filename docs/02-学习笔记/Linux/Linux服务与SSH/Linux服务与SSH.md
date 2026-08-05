---
title: Linux 服务与 SSH — systemd + OpenSSH 全攻略
desc: 基于 05.CentOS-7-系统管理-1/14. Linux 服务管理.pdf + 15. Linux OpenSSH 服务管理.pdf 的实操笔记。覆盖 systemd 起源与 unit 类型、systemctl 命令大全、unit 文件三段式结构、自制服务、SSH 协议原理、ssh CLI、密钥认证、sshd_config 加固、SSH 端口转发、SCP/SFTP。
type: 笔记
module: Linux服务与SSH
pdf: 05.14 服务管理.pdf + 05.15 OpenSSH 服务管理.pdf
pdf_size: 460 + 436 = 896 行
scope: CentOS-7 (systemd 219 + OpenSSH 7.4)
status: 完成
---

# Linux 服务与 SSH — systemd + OpenSSH 全攻略

> **范围**：基于《CentOS-7 系统管理 1》第 14、15 章 整理。
> 覆盖 **systemd 服务管理**（unit 类型 / systemctl / unit 文件 / 自制服务）+ **SSH 全栈**（协议原理 / ssh CLI / 密钥认证 / sshd_config 加固 / 端口转发）。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：服务 = 守护进程 = 后台程序]]
- [[#§1 CentOS init 演进：SysVinit → Upstart → systemd]]
- [[#§2 systemd 是什么：PID 1 + 一切皆 unit]]
- [[#§3 unit 12 种类型]]
- [[#§4 systemctl 入门：status / list-units]]
- [[#§5 systemctl list-unit-files 与状态字段]]
- [[#§6 systemctl 命令大全]]
- [[#§7 状态字段详解：loaded/active/inactive/enabled/disabled]]
- [[#§8 systemctl enable/disable 与开机自启]]
- [[#§9 systemctl mask/unmask 屏蔽]]
- [[#§10 unit 文件路径优先级]]
- [[#§11 unit 文件结构：[Unit] / [Service] / [Install]]]
- [[#§12 实战解读 sshd.service]]
- [[#§13 Type= 服务启动类型]]
- [[#§14 ExecStart / ExecReload / ExecStop / Pre/Post]]
- [[#§15 Restart= 与 RestartSec=]]
- [[#§16 实战：自制 studyd 服务]]
- [[#§17 systemctl daemon-reload 重读配置]]
- [[#§18 journalctl -u 服务日志]]
- [[#§19 systemctl list-dependencies 依赖图]]
- [[#§20 实战：服务故障排查 5 步法]]
- [[#§21 SSH 是什么：替代 telnet/rcp/ftp/rlogin/rsh]]
- [[#§22 SSH 三大功能：远程 shell + 文件传输 + 端口转发]]
- [[#§23 SSH 协议版本：SSH1 vs SSH2]]
- [[#§24 SSH 工作原理：非对称加密 + 对称加密]]
- [[#§25 主机密钥 host key]]
- [[#§26 ssh CLI 用法]]
- [[#§27 ssh 远程执行命令]]
- [[#§28 ~/.ssh/config 客户端配置]]
- [[#§29 ssh-keygen 生成密钥对]]
- [[#§30 ssh-copy-id 上传公钥]]
- [[#§31 authorized_keys 原理]]
- [[#§32 密钥登录权限要求（700/600）]]
- [[#§33 sshd_config 服务端配置]]
- [[#§34 PermitRootLogin 安全三选项]]
- [[#§35 PasswordAuthentication / AllowUsers]]
- [[#§36 UseDNS no 反向解析加速]]
- [[#§37 实战：禁止 root 密码登录]]
- [[#§38 /var/log/secure 排错日志]]
- [[#§39 SCP 安全拷贝]]
- [[#§40 SFTP 交互传输]]
- [[#§41 SSH 端口转发：本地/远程/动态]]
- [[#§42 SSH 跳板（ProxyCommand）]]
- [[#§43 速查表]]
- [[#§44 易错点 ×12]]
- [[#§45 面试 6 大追问]]
- [[#§46 链路]]

---

## §0 心智模型：服务 = 守护进程 = 后台程序

```
Linux 系统启动 → 内核 → init 进程 (PID 1) → 启动所有服务
                                                       ↓
                                              ┌────────┴────────┐
                                              │                 │
                                            sshd             httpd
                                          (远程登录)        (网站服务)
                                              │                 │
                                          监听 :22          监听 :80
                                          等你连接         等你访问
```

**服务 = 守护进程（daemon）**：
- **后台跑**，没有终端
- **常驻**，开机自启
- **监听某端口**或文件系统事件
- 名字常带 `d` 后缀（sshd/httpd/crond/atd）

**CentOS-7 的服务管家 = systemd**（PID 1）：
- 管所有服务（start/stop/restart）
- 管所有依赖（A 服务要在 B 服务之后启动）
- 管所有日志（journalctl）

---

## §1 CentOS init 演进：SysVinit → Upstart → systemd

| 启动器          | CentOS 版本 | 特点                     | 缺点        |
| ------------ | --------- | ---------------------- | --------- |
| **SysVinit** | CentOS 5  | `/etc/init.d/` 脚本，串行启动 | 启动慢、不支持依赖 |
| **Upstart**  | CentOS 6  | 基于事件的并行启动              | 兼容性差      |
| **systemd**  | CentOS 7+ | **一切皆 unit**，并行 + 依赖管理 | 学习曲线陡     |

```bash
# CentOS-5/6 的服务管理（老）
service sshd start
chkconfig sshd on

# CentOS-7+ 的服务管理（新）
systemctl start sshd
systemctl enable sshd
```

> 💡 **面试题**：CentOS 6 和 7 启动流程区别？
> 答：6 用 init 脚本串行；7 用 systemd 并行 + 按需启动（socket 激活）。

---

## §2 systemd 是什么：PID 1 + 一切皆 unit

```
systemd = 系统和服务管理器
位置：/usr/lib/systemd/systemd（PID 1）

"一切皆 unit" = 把所有"可管理对象"都抽象成 unit
  服务（service）、挂载点（mount）、设备（device）、socket...
  每种类型都有自己的 unit 文件

unit 文件 = systemd 的"配置清单"
  默认路径：/usr/lib/systemd/system/
  自定义路径：/etc/systemd/system/   ← 优先级更高
```

> systemd 是**第一个进程**（PID 1），所有其他进程都是它的"子孙"。

---

## §3 unit 12 种类型

| 类型            | 扩展名          | 作用                               |
| ------------- | ------------ | -------------------------------- |
| **Service**   | `.service`   | 守护进程（httpd, sshd, mysqld）        |
| **Socket**    | `.socket`    | 套接字（systemd socket 激活）           |
| **Target**    | `.target`    | 一组 unit 的"集合"（multi-user.target） |
| **Timer**     | `.timer`     | 定时任务（替代 cron 部分场景）               |
| **Device**    | `.device`    | 内核识别的设备                          |
| **Mount**     | `.mount`     | 文件系统挂载点                          |
| **Automount** | `.automount` | 按需自动挂载                           |
| **Swap**      | `.swap`      | 交换分区                             |
| **Path**      | `.path`      | 文件/目录变化触发                        |
| **Snapshot**  | `.snapshot`  | systemd 状态快照                     |
| **Slice**     | `.slice`     | cgroup 资源切片                      |
| **Scope**     | `.scope`     | 外部进程（bus name 来的）                |

> 💡 **面试最常问**：service / target / timer 三种类型的作用？

---

## §4 systemctl 入门：status / list-units

### 4.1 systemctl status UNIT

```bash
[xkw@centos7 ~]$ systemctl status sshd.service
● sshd.service - OpenSSH server daemon
   Loaded: loaded (/usr/lib/systemd/system/sshd.service; enabled; vendor preset: enabled)
   Active: active (running) since  2022-11-09 08:45:45 CST; 5h 50min ago
     Docs: man:sshd(8)
           man:sshd_config(5)
 Main PID: 1167 (sshd)
    Tasks: 1
   CGroup: /system.slice/sshd.service
           └─1167 /usr/sbin/sshd -D

11 09 08:45:45 centos7.xkw.cloud systemd[1]: Started OpenSSH server daemon.
```

字段含义：
- **Loaded**：unit 文件已加载，路径 + 是否 enabled
- **Active**：当前运行状态（active running/exited/waiting/failed）
- **Main PID**：主进程 PID
- **CGroup**：cgroup 路径
- 底部：最近 N 条日志

### 4.2 systemctl list-units

```bash
[root@centos7 ~]# systemctl list-units
UNIT                                              LOAD   ACTIVE     SUB       DESCRIPTION
sys-devices-pci0000:00-0000:00:01.1-...device    loaded active     plugged   QEMU ...
sys-subsystem-net-devices-ens32.device           loaded active     plugged   Virtio ...
├─...
session-1.scope                                  loaded active     running   Session 1 of user root
sshd.service                                     loaded active     running   OpenSSH server daemon
systemd-tmpfiles-clean.timer                     loaded active     waiting   Daily Cleanup of Temporary Directories
unbound-anchor.timer                             loaded active     waiting   daily update of the root trust anchor for DNSSEC

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state.
SUB    = The low-level unit activation state.

2 loaded units listed.  # ← 默认只显示 active 的

# 显示所有（含 inactive）
systemctl list-units --all

# 按类型过滤
systemctl list-units -t timer
systemctl list-units -t service
systemctl list-units --type service --all
```

### 4.3 systemctl --failed

```bash
[root@centos7 ~]# systemctl --failed --type service
# 列出启动失败的服务（运维排查第一步！）
```

---

## §5 systemctl list-unit-files 与状态字段

```bash
# list-unit-files 看所有已安装的 unit（含 disabled/static）
[root@centos7 ~]# systemctl list-unit-files
UNIT FILE                                  STATE      VENDOR PRESET
proc-sys-fs-binfmt_misc.automount          static     disabled
tmp.mount                                  disabled   enabled
var-lib-nfs-rpc_pipefs.mount               static     enabled
brandbot.service                           disabled   disabled
sshd.service                               enabled    enabled
...
```

**STATE（unit 是否开机自启）**：
```
enabled    ← 开机自启（systemctl enable 过）
disabled   ← 不会自启（systemctl disable 过）
static     ← 不能 enable，但会被其他 unit 拉起（依赖）
masked     ← 被 mask 了，永远启不了
```

---

## §6 systemctl 命令大全

### 6.1 服务生命周期

```bash
systemctl start <unit>      # 启动
systemctl stop <unit>       # 停止
systemctl restart <unit>    # 重启（stop + start）
systemctl reload <unit>     # 重载配置（不重启进程）
systemctl try-restart <unit># 运行中才重启
systemctl status <unit>     # 看状态
```

### 6.2 开机自启

```bash
systemctl enable <unit>     # 设为开机自启
systemctl disable <unit>    # 取消自启
systemctl is-enabled <unit> # 看是否自启
systemctl enable --now <unit>   # 同时立即启动（一步到位）
systemctl disable --now <unit>  # 同时立即停止
```

### 6.3 屏蔽 / 解除

```bash
systemctl mask <unit>       # 屏蔽（指向 /dev/null）
systemctl unmask <unit>     # 解除屏蔽
```

### 6.4 查日志 / 依赖

```bash
systemctl list-units        # 活跃 unit
systemctl list-unit-files   # 所有 unit 文件
systemctl list-dependencies <unit>   # 依赖树
systemctl --failed          # 失败的
journalctl -u <unit>        # 看 unit 的日志
```

### 6.5 系统级

```bash
systemctl reboot            # 重启
systemctl poweroff          # 关机
systemctl suspend           # 挂起
systemctl hibernate         # 休眠
systemctl rescue            # 进入救援模式（单用户）
systemctl emergency         # 进入紧急模式
systemctl default           # 回到默认 target
```

### 6.6 target（运行级别）

```bash
# 查看当前 target
systemctl get-default
# multi-user.target

# 切换 target
systemctl isolate multi-user.target   # 多用户命令行（runlevel 3）
systemctl isolate graphical.target    # 图形界面（runlevel 5）

# 等价老命令
init 3
init 5
```

| systemd target | 老 runlevel | 说明 |
|---|---|---|
| `poweroff.target` | 0 | 关机 |
| `rescue.target` | 1 | 单用户救援 |
| `multi-user.target` | 3 | 多用户命令行 |
| `graphical.target` | 5 | 图形界面 |
| `reboot.target` | 6 | 重启 |

---

## §7 状态字段详解：loaded/active/inactive/enabled/disabled

| 字段                | 取值         | 含义                  |
| ----------------- | ---------- | ------------------- |
| **Loaded**        | `loaded`   | unit 文件已正确加载        |
|                   | `error`    | 加载失败                |
| **Active**        | `active`   | 高层级"激活中"            |
|                   | `inactive` | 没运行                 |
|                   | `failed`   | 启动失败                |
| **Sub**           | `running`  | 主进程在跑（service 特有）   |
|                   | `exited`   | 启动后已退出（一次性任务）       |
|                   | `waiting`  | 等其他事件（timer/socket） |
|                   | `dead`     | 死状态                 |
| **State**         | `enabled`  | 已 enable，开机会自启      |
| （list-unit-files） | `disabled` | 已 disable，不自启       |
|                   | `static`   | 不可 enable，只能被依赖拉起   |

---

## §8 systemctl enable/disable 与开机自启

```bash
# 启用 sshd 开机自启
[root@centos7 ~]# systemctl enable sshd.service
Created symlink /etc/systemd/system/multi-user.target.wants/sshd.service → /usr/lib/systemd/system/sshd.service.
# ↑ 实际是在 multi-user.target.wants/ 下建了软链接！

[root@centos7 ~]# systemctl is-enabled sshd
enabled

# 禁用
[root@centos7 ~]# systemctl disable sshd.service
Removed symlink /etc/systemd/system/multi-user.target.wants/sshd.service.

[root@centos7 ~]# systemctl is-enabled sshd
disabled

# 一步：enable + start
[root@centos7 ~]# systemctl enable --now sshd.service
# 等价于 enable sshd && start sshd
```

**底层机制**：
```
enable  = 在 /etc/systemd/system/multi-user.target.wants/ 下建软链接
disable = 删除那个软链接

启动顺序：
  systemd → multi-user.target → 读 *.wants/ 下的所有 unit → 启动
```

> 💡 **实战**：自定义服务想开机自启，必须 `WantedBy=multi-user.target`（或其他 target）。

---

## §9 systemctl mask/unmask 屏蔽

```bash
# mask = 把 unit 链接到 /dev/null，永远启不了
[root@centos7 ~]# systemctl mask sshd.service
Created symlink /etc/systemd/system/sshd.service → /dev/null.

# 即使 enable 也启不了
[root@centos7 ~]# systemctl start sshd.service
Failed to start sshd.service: Unit sshd.service is masked.

# unmask 解除
[root@centos7 ~]# systemctl unmask sshd.service
Removed /etc/systemd/system/sshd.service.

# 现在又能启动了
[root@centos7 ~]# systemctl start sshd.service
```

**mask vs disable 的区别**：
```
disable = 开机不自启，但还能手动 start
mask   = 彻底屏蔽，连手动 start 都不行（指向 /dev/null）
```

---

## §10 unit 文件路径优先级

```
systemd 找 unit 的顺序（从高到低）：

1. /etc/systemd/system/<unit>.service      ← 用户自定义（最高）
2. /run/systemd/system/<unit>.service      ← 运行时（容器/临时）
3. /usr/lib/systemd/system/<unit>.service  ← 软件包自带（最低）
```

```bash
# 实战：覆盖官方 sshd.service
[root@centos7 ~]# cp /usr/lib/systemd/system/sshd.service \
               /etc/systemd/system/sshd.service
# ↑ 改 /etc 下的那份，原版不动

# 或者用 systemctl edit
systemctl edit sshd.service
# → 自动创建 /etc/systemd/system/sshd.service.d/override.conf
```

---

## §11 unit 文件结构：[Unit] / [Service] / [Install]

unit 文件 = **3 段**配置：

```ini
[Unit]            # 元信息（描述、依赖、顺序）
Description=...   # 人话描述
Documentation=... # 文档链接
After=...         # 在哪些 unit 之后启动
Before=...        # 在哪些 unit 之前启动
Wants=...         # 弱依赖（拉不拉都行）
Requires=...      # 强依赖（拉不起就报错）
Conflicts=...     # 互斥

[Service]         # 服务行为（仅 service 类型有）
Type=...          # 启动类型
ExecStart=...     # 启动命令
ExecReload=...    # 重载命令
ExecStop=...      # 停止命令
ExecStartPre=...  # 启动前
ExecStartPost=... # 启动后
Restart=...       # 何时重启
RestartSec=...    # 重启间隔
EnvironmentFile=... # 环境变量文件
Environment=...   # 环境变量
WorkingDirectory=... # 工作目录
User=...          # 运行用户
Group=...         # 运行组
KillMode=...      # 如何杀进程

[Install]         # 安装信息（enable 时用）
WantedBy=...      # 被哪个 target 拉起
RequiredBy=...    # 强依赖拉起
Also=...          # enable 时同时 enable 这些
Alias=...         # 别名
```

---

## §12 实战解读 sshd.service

```bash
[root@centos7 ~]# cat /usr/lib/systemd/system/sshd.service
[Unit]
Description=OpenSSH server daemon
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target sshd-keygen.service
# ↑ 在网络和 ssh 密钥生成服务之后启动
Wants=sshd-keygen.service
# ↑ 弱依赖（如果密钥生成失败，sshd 也能起）

[Service]
Type=notify
# ↑ 启动类型 = notify（systemd 通过 sd_notify() 协议知道服务"准备好"了）
EnvironmentFile=/etc/sysconfig/sshd
# ↑ 环境变量文件（$OPTIONS 在这定义）
ExecStart=/usr/sbin/sshd -D $OPTIONS
# ↑ 启动命令（-D = 前台运行，systemd 能监控）
ExecReload=/bin/kill -HUP $MAINPID
# ↑ 重载命令（发 SIGHUP 给 sshd 主进程，重新读配置）
KillMode=process
# ↑ kill 时只杀主进程，不杀子进程
Restart=on-failure
# ↑ 失败时自动重启
RestartSec=42s
# ↑ 重启前等 42 秒（防止重启风暴）

[Install]
WantedBy=multi-user.target
# ↑ enable 时会在 multi-user.target.wants/ 下建软链
```

---

## §13 Type= 服务启动类型

| Type        | 行为                                | 适用            |
| ----------- | --------------------------------- | ------------- |
| **simple**  | ExecStart 命令前台跑（默认）               | 绝大多数服务        |
| **notify**  | simple + 服务通过 sd_notify() 通知"准备好" | sshd          |
| **forking** | ExecStart 启动后会 fork 父进程退出         | 传统守护进程（httpd） |
| **oneshot** | 启动后立即退出（配合 RemainAfterExit=yes）   | 一次性任务         |
| **dbus**    | 启动后获取 D-Bus 名称                    | 需要 D-Bus 的服务  |
| **idle**    | 等所有其他任务空闲才启动                      | 极少见           |

```bash
# Type=forking 的经典例子（旧版 httpd）
Type=forking
ExecStart=/usr/sbin/httpd -k start
ExecStop=/usr/sbin/httpd -k stop
PIDFile=/var/run/httpd.pid

# Type=simple 的例子（绝大多数）
Type=simple
ExecStart=/usr/bin/mysqld_safe
```

---

## §14 ExecStart / ExecReload / ExecStop / Pre/Post

```ini
[Service]
# 必填（除了 Type=oneshot）
ExecStart=/path/to/cmd arg1 arg2

# 可选：多条命令用 ; 串行，& 异步
ExecStartPre=/usr/bin/script1.sh     # 启动前
ExecStart=/usr/bin/script2.sh        # 启动
ExecStartPost=/usr/bin/script3.sh    # 启动后

# 可选
ExecReload=/bin/kill -HUP $MAINPID   # 重载（reload）
ExecStop=/usr/bin/script_stop.sh     # 停止
ExecStopPost=/bin/rm -f /var/lock/foo # 停止后清理
```

**特殊变量**：
```
$MAINPID   = 服务主进程 PID
$OPTIONS   = EnvironmentFile 中定义的
%i         = unit 模板里的 Instance 名（如 vsftpd@home.service → %i=home）
%n         = 完整 unit 名
%N         = 不带后缀的 unit 名
```

---

## §15 Restart= 与 RestartSec=

```ini
[Service]
Restart=no                # 不自动重启（默认）
Restart=on-success        # 正常退出也重启
Restart=on-failure        # 异常退出才重启（最常用）
Restart=on-abnormal       # 信号杀、超时退出才重启
Restart=always            # 一律重启

RestartSec=42s            # 重启前等 42 秒
TimeoutStartSec=90        # 启动超时 90 秒
TimeoutStopSec=90         # 停止超时 90 秒
```

> 💡 **面试题**：服务挂了怎么自动拉起？
> 答：systemd 设 `Restart=on-failure` 即可（不用额外脚本）。

---

## §16 实战：自制 studyd 服务

### 16.1 写脚本

```bash
[root@centos7 ~]# vim /usr/bin/study
#!/bin/bash
# shebang 声明解释器
while true
do
    DATE=$(date)
    echo "$DATE: I'M studying [ Linux ]" >> /var/log/study.log
    sleep 5
done

[root@centos7 ~]# chmod +x /usr/bin/study
```

### 16.2 写 unit 文件

```bash
[root@centos7 ~]# cp /usr/lib/systemd/system/sshd.service \
               /etc/systemd/system/studyd.service
[root@centos7 ~]# vim /etc/systemd/system/studyd.service

[Unit]
Description=study server daemon

[Service]
ExecStart=/usr/bin/study

[Install]
WantedBy=multi-user.target
```

### 16.3 启用 + 启动

```bash
[root@centos7 ~]# systemctl daemon-reload           # 重读 unit 文件

[root@centos7 ~]# systemctl enable studyd --now     # 启用 + 启动

[root@centos7 ~]# systemctl status studyd
● studyd.service - study server daemon
   Loaded: loaded (/etc/systemd/system/studyd.service; enabled; vendor preset: disabled)
   Active: active (running) since  2025-10-31 16:28:34 CST; 1s ago
 Main PID: 2786 (study)
    Tasks: 2
   CGroup: /system.slice/studyd.service
           ├─2786 /bin/bash /usr/bin/study
           └─2788 sleep 5
```

### 16.4 看日志

```bash
[root@centos7 ~]# tail -f /var/log/study.log
2025年 10月 31日 16:28:29 CST: I'M studying [ Linux ]
2025年 10月 31日 16:28:34 CST: I'M studying [ Linux ]
2025年 10月 31日 16:28:39 CST: I'M studying [ Linux ]
...
```

---

## §17 systemctl daemon-reload 重读配置

```bash
# 改了 unit 文件，必须 reload
[root@centos7 ~]# vim /etc/systemd/system/studyd.service
[root@centos7 ~]# systemctl daemon-reload

# 不 reload 的话：
# 1) 已经在跑的服务继续用旧配置
# 2) start 报错（提示 unit not found 或语法错）

# daemon-reexec = 重启 systemd 进程本身（极少用）
systemctl daemon-reexec
```

---

## §18 journalctl -u 服务日志

```bash
# 看 sshd 的所有日志
journalctl -u sshd

# 实时跟踪
journalctl -u sshd -f

# 最近 1 小时
journalctl -u sshd --since "1 hour ago"

# 指定时间范围
journalctl -u sshd --since "2025-10-31 08:00" --until "2025-10-31 18:00"

# 看错误
journalctl -u sshd -p err

# 不分页
journalctl -u sshd --no-pager

# 看内核日志
journalctl -k

# 看启动日志
journalctl -b
```

> 💡 **journalctl** 比 tail `/var/log/messages` 更精准（带 unit 过滤）。

---

## §19 systemctl list-dependencies 依赖图

```bash
# 看 sshd 的依赖树
[root@centos7 ~]# systemctl list-dependencies sshd
sshd.service
├─system.slice
└─sshd-keygen.service
   ├─system.slice
   └─...
# ↑ sshd 启动需要 sshd-keygen.service

# 反向依赖（哪些服务依赖 sshd）
systemctl list-dependencies sshd --reverse

# 看目标的所有 unit
systemctl list-dependencies multi-user.target
# 几百个 unit，包括 getty、sshd、crond 等
```

---

## §20 实战：服务故障排查 5 步法

```bash
# 第 1 步：看状态
systemctl status nginx
# 看到 Active: failed（启动失败）

# 第 2 步：看日志
journalctl -u nginx --since "5 minutes ago"
# 看到 "bind: address already in use"

# 第 3 步：看端口占用
ss -tlnp | grep :80

# 第 4 步：手动启动看错
systemctl start nginx
# 或者前台启动
/usr/sbin/nginx -g "daemon off;"

# 第 5 步：reload 后再试
systemctl daemon-reload
systemctl restart nginx
```

---

## §21 SSH 是什么：替代 telnet/rcp/ftp/rlogin/rsh

```
SSH = Secure Shell（安全外壳协议）
     加密的远程登录协议
     默认端口 22

老家伙们（明文传输！）：
  telnet    → 远程登录（明文）
  rlogin    → 远程登录（明文）
  rsh       → 远程 shell（明文）
  rcp       → 远程拷贝（明文）
  ftp       → 文件传输（明文）

SSH 全面替代它们，并且：
  ✅ 加密传输
  ✅ 身份认证（密码 / 密钥）
  ✅ 完整性校验（防篡改）
  ✅ 端口转发（隧道）
```

---

## §22 SSH 三大功能：远程 shell + 文件传输 + 端口转发

```
┌────────────────────────────────────────────────┐
│ SSH                                            │
│ ┌────────────────────────────────────────────┐ │
│ │ 1. 远程 Shell：ssh user@host               │ │
│ │    替代 telnet/rlogin/rsh                   │ │
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │
│ │ 2. 文件传输：scp / sftp                    │ │
│ │    替代 ftp/rcp                             │ │
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │
│ │ 3. 端口转发：ssh -L / -R / -D              │ │
│ │    替代 VPN（部分场景）                      │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

---

## §23 SSH 协议版本：SSH1 vs SSH2

| 版本 | 加密 | 完整性 | 状态 |
|---|---|---|---|
| **SSH1** | 弱 | 无 | 已淘汰（CentOS 默认禁用） |
| **SSH2** | 强（RSA/DSA/ECDSA/Ed25519） | 有 | 当前标准 |

```bash
# 看协议版本
ssh -V
# OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017

# sshd 默认只支持 SSH2
grep -i protocol /etc/ssh/sshd_config
# （默认无 Protocol 行 = SSH2 only）
```

---

## §24 SSH 工作原理：非对称加密 + 对称加密

```
连接建立（握手阶段）：
  Client                                  Server
     |                                       |
     |  1. TCP 三次握手                       |
     |------------------------------------->|
     |                                       |
     |  2. 协议版本协商                       |
     |<------------------------------------>|
     |                                       |
     |  3. 算法协商（加密/压缩/MAC）           |
     |<------------------------------------>|
     |                                       |
     |  4. 服务器发公钥（host key）           |
     |<------------------------------------|
     |                                       |
     |  5. 客户端用公钥加密"会话密钥"          |
     |------------------------------------->|
     |                                       |
     |  6. 双方用"会话密钥"加密通信            |
     |<------------------------------------>|

身份认证阶段：
  客户端认证方式：
    a) 密码认证（PasswordAuthentication）
    b) 公钥认证（PubkeyAuthentication，推荐）
    c) 主机认证（HostBasedAuthentication，几乎不用）
```

> 💡 SSH 用**非对称加密**交换**对称密钥**，之后用对称加密通信。
> 这是因为：非对称慢但安全，对称快但需要密钥交换。

---

## §25 主机密钥 host key

服务器在 `/etc/ssh/` 下有自己的密钥对：

```bash
[root@server ~]# ls /etc/ssh/
ssh_host_ecdsa_key           # 私钥（600，root 拥有）
ssh_host_ecdsa_key.pub       # 公钥（644）
ssh_host_ed25519_key         # ← Ed25519 密钥对
ssh_host_ed25519_key.pub
ssh_host_rsa_key             # ← RSA 密钥对
ssh_host_rsa_key.pub
sshd_config                  # 服务端配置
```

客户端首次连接时，**指纹会被记住**到 `~/.ssh/known_hosts`：

```
[xkw@client ~]$ cat ~/.ssh/known_hosts
server,10.1.8.10 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBA...
```

**下次连接会校验指纹**：
- 指纹一致 → 信任继续
- 指纹变了 → ⚠️ "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"
  → 可能被中间人攻击！或者服务器重装

```bash
# 清掉旧指纹
[xkw@client ~]$ > .ssh/known_hosts

# 或者只删某条
ssh-keygen -R server
```

---

## §26 ssh CLI 用法

### 26.1 基础

```bash
# 按 IP 连
[xkw@client ~]$ ssh 10.1.8.10
The authenticity of host '10.1.8.10 (10.1.8.10)' can't be established.
ECDSA key fingerprint is SHA256:pplZ4EZPQ8M/f7qvKaAffxbf+vKYJg9HCojrmqctkck.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.1.8.10' (ECDSA) to the list of known hosts.
xkw@10.1.8.10's password: ********
[xkw@server ~]$

# 按主机名连（需 /etc/hosts 或 DNS）
[xkw@client ~]$ ssh server
```

### 26.2 指定用户

```bash
# 用 root 连
[xkw@client ~]$ ssh root@server
# 或
[xkw@client ~]$ ssh -l root server
```

### 26.3 远程执行命令

```bash
# 单条命令
[xkw@client ~]$ ssh xkw@server hostname
xkw@server's password:
server.xkw.cloud

# 多条命令
[xkw@client ~]$ ssh root@server 'hostname;id'
server.xkw.cloud
uid=0(root) gid=0(root) 组=0(root) 环境=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

### 26.4 常用选项

| 选项                                | 含义                   |
| --------------------------------- | -------------------- |
| `-p 2222`                         | 指定端口（默认 22）          |
| `-l user`                         | 指定登录用户               |
| `-i keyfile`                      | 指定私钥文件               |
| `-v`                              | 调试（v → vv → vvv 详细度） |
| `-C`                              | 启用压缩                 |
| `-N`                              | 不执行远程命令（端口转发用）       |
| `-f`                              | 后台运行（端口转发用）          |
| `-L local:remote`                 | 本地端口转发               |
| `-R remote:local`                 | 远程端口转发               |
| `-D 1080`                         | SOCKS 动态转发           |
| `-o StrictHostKeyChecking=no`     | 跳过主机密钥检查             |
| `-o UserKnownHostsFile=/dev/null` | 不写 known_hosts       |

```bash
# 用 1022 端口
[xkw@client ~]$ ssh -l root -p 1022 server hostname

# 用指定密钥
[xkw@client ~]$ ssh -i /tmp/id_rsa root@server hostname
```

---

## §27 ssh 远程执行命令

```bash
# 执行单条命令
ssh user@host 'cmd'

# 多条命令（用 ; 或 &&）
ssh user@host 'cd /tmp && ls'

# 管道（本地 → 远程）
ssh user@host 'cat > /tmp/file' < local_file

# 远程 → 本地
ssh user@host 'cat /etc/passwd' > local_passwd

# 远程脚本
ssh user@host 'bash -s' < local_script.sh
```

---

## §28 ~/.ssh/config 客户端配置

```bash
# 客户端配置文件（按优先级）
~/.ssh/config             ← 当前用户（最高）
/etc/ssh/ssh_config       ← 全局（最低）
```

**示例**：

```bash
[xkw@client ~]$ vim .ssh/config

# 默认配置（对所有 host）
Host *
    StrictHostKeyChecking no      # 自动接受主机密钥（不推荐生产用）
    User root
    PreferredAuthentications password

# 针对特定 host
Host server1
    HostName 10.1.8.10
    User xkw
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host server2
    HostName 10.1.8.20
    User ops
    Port 2222
    IdentityFile ~/.ssh/ops_key
```

```bash
# 测试：连 server1 就自动用 xkw + id_rsa
ssh server1
```

**⚠️ config 文件权限必须 600**：

```bash
[xkw@client ~]$ ssh server
Bad owner or permissions on /home/xkw/.ssh/config
# ↑ 必须 chmod 600
[xkw@client ~]$ chmod 600 .ssh/config
```

---

## §29 ssh-keygen 生成密钥对

```bash
[xkw@client ~]$ ssh-keygen
Generating public/private rsa key pair.

# 1) 私钥保存路径（默认 ~/.ssh/id_rsa，直接回车）
Enter file in which to save the key (/home/xkw/.ssh/id_rsa): 【回车】

# 2) 私钥密码（空 = 不要密码，登录免输入；填了 = 双因素）
Enter passphrase (empty for no passphrase): 【回车】
Enter same passphrase again: 【回车】

# 3) 生成完成
Your identification has been saved in /home/xkw/.ssh/id_rsa.
Your public key has been saved in /home/xkw/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:OAfLyL6KIXr44DV7vhpystqqXwsbFl2tGP6HZP4GLR4 xkw@server.xkw.cloud
```

```bash
# 看生成结果
[xkw@client ~]$ ls .ssh/
config  id_rsa  id_rsa.pub  known_hosts
#        ↑       ↑           ↑
#        私钥    公钥        已信任主机

# 看公钥内容
[xkw@client ~]$ cat .ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDtFoo... xkw@client.xkw.cloud
#                ↑ 一长串 base64                                    ↑ 注释
```

**参数详解**：

```bash
ssh-keygen -t rsa -b 4096 -C 'my-key' -f ~/.ssh/id_rsa_4096 -N ''
#   ↑ 类型  ↑ 位数  ↑ 注释    ↑ 路径        ↑ 密码（空）
```

| 选项 | 含义 |
|---|---|
| `-t rsa` | 密钥类型（rsa/dsa/ecdsa/ed25519） |
| `-b 4096` | 位数（默认 2048，推荐 4096 或 Ed25519） |
| `-C '注释'` | 公钥末尾的注释（一般填邮箱或用途） |
| `-f 文件名` | 私钥保存路径 |
| `-N ''` | 私钥密码（空 = 不要密码）|

> 💡 **Ed25519 最短最强**（`-t ed25519`），SSH 新版本首选。

---

## §30 ssh-copy-id 上传公钥

```bash
# 一键把公钥传到服务器的 authorized_keys
[xkw@client ~]$ ssh-copy-id xkw@server
xkw@server's password: 【输入一次密码】

# 服务器上会生成 ~/.ssh/authorized_keys
# 内容 = 客户端的 .ssh/id_rsa.pub

# 现在可以免密登录
[xkw@client ~]$ ssh xkw@server hostname
server.xkw.cloud  # 直接进，没问密码！
```

**底层做了什么**：
```
ssh-copy-id 相当于：
  1. ssh xkw@server 'mkdir -m 700 .ssh && cat >> .ssh/authorized_keys' < ~/.ssh/id_rsa.pub
  2. chmod 600 .ssh/authorized_keys
```

---

## §31 authorized_keys 原理

```bash
# 服务器上
[xkw@server ~]$ cat ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDtFoo... xkw@client.xkw.cloud
#        ↑                                               ↑
#        客户端公钥（必须完整）                            客户端标识
```

**登录流程**：
```
Client                                          Server
  |                                              |
  |  1. 用自己的私钥签名一段数据                   |
  |                                              |
  |  2. 发："我用某个密钥" + 签名                 |
  |--------------------------------------------->|
  |                                              |
  |              3. 在 authorized_keys 里找匹配    |
  |                 找到后用对应公钥验签          |
  |                                              |
  |              4. 验签通过 → 允许登录            |
  |                                              |
  |  5. 登录成功！                                |
  |<---------------------------------------------|
```

> 💡 一句话：客户端证明"我有私钥"，服务器验证"你说的公钥在我 authorized_keys 里"。

---

## §32 密钥登录权限要求（700/600）

**服务器端**：

```bash
# 用户家目录：750 或 700（不能是 777！）
chmod 700 /root

# .ssh 目录：700
mkdir -m 700 .ssh

# authorized_keys：600
chmod 600 .ssh/authorized_keys
```

**为什么？**：
```
如果 authorized_keys 是 644（其他用户可读）：
  → 其他用户能拿到你信任的公钥
  → 重放攻击风险（虽然没私钥不行，但配合其他漏洞可能绕过）

如果 .ssh 是 755：
  → 其他用户能看到 authorized_keys 的文件名
  → 一些 SSH 配置禁止这种状态直接登录

如果 /root 是 777：
  → SSH 直接拒绝密钥登录！
```

**实战排错**：
```bash
# 客户端连不上，看服务器日志
[root@server ~]# tail -f /var/log/secure
...
Jul 31 16:13:41 server sshd[3693]: Authentication refused: bad ownership or modes for directory /root
# ↑ 这就是 /root 权限不对
```

**修复**：
```bash
[root@server ~]# chmod 700 /root
```

---

## §33 sshd_config 服务端配置

```bash
[root@server ~]# cat /etc/ssh/sshd_config
# 默认配置很宽松！需要手动加固！

# 关键选项
Port 22                                    # 监听端口（建议改高位）
PermitRootLogin yes                        # 是否允许 root 登录
PubkeyAuthentication yes                   # 是否启用公钥认证
PasswordAuthentication yes                 # 是否允许密码认证
PermitEmptyPasswords no                    # 是否允许空密码
AllowUsers user1 user2                     # 允许的用户白名单
DenyUsers user3                            # 黑名单
AllowGroups sshusers                       # 组白名单
MaxAuthTries 3                             # 最大认证尝试次数
MaxSessions 10                             # 最大并发会话数
ClientAliveInterval 300                    # 心跳间隔 300 秒
ClientAliveCountMax 2                      # 心跳失败次数
UseDNS no                                  # 关闭 DNS 反查（加速登录）
Banner /etc/issue.net                      # 登录前的告示
```

**改完配置后必须重启**：
```bash
# 推荐 reload（不断连接）
[root@server ~]# systemctl reload sshd

# 或 restart（断开所有连接）
[root@server ~]# systemctl restart sshd

# 改端口一定要 reload 而不是 restart（防止端口配错连不上）
```

> ⚠️ **改 sshd_config 前先开两个 SSH 窗口**，一个改一个测试，别把自己锁外面。

---

## §34 PermitRootLogin 安全三选项

```bash
PermitRootLogin yes                  # 允许 root 密码/密钥登录（不安全！）
PermitRootLogin no                   # 完全禁止 root 登录（最严）
PermitRootLogin prohibit-password    # 禁止密码，但允许密钥登录（折中）
```

**生产建议**：
```
方案 1（最安全）：
  PermitRootLogin no
  → 用普通用户登录 + su 切 root

方案 2（折中）：
  PermitRootLogin prohibit-password
  → 允许密钥登录（需密钥），禁止密码登录

⚠️ 永远不要 PermitRootLogin yes 上生产！
```

---

## §35 PasswordAuthentication / AllowUsers

```bash
# 完全禁止密码登录（只允许密钥）
PasswordAuthentication no
# ↑ 配密钥后才能登录，密码直接拒绝

# 允许特定用户登录（白名单）
AllowUsers xkw opsuser
# ↑ 只有 xkw 和 opsuser 能 SSH 进来，其他用户（包括 root）都不行

# 允许特定组
AllowGroups sshusers wheel
# ↑ 只允许 sshusers 和 wheel 组的成员

# 禁用特定用户
DenyUsers baduser

# 禁用特定组
DenyGroups nossh
```

**生产配置示例**：
```bash
# /etc/ssh/sshd_config
Port 2222                            # 改端口（防扫）
PermitRootLogin no                   # 禁 root
PasswordAuthentication no            # 禁密码
PubkeyAuthentication yes             # 启密钥
AllowUsers xkw opsuser               # 白名单
MaxAuthTries 3                       # 防爆破
ClientAliveInterval 300              # 5 分钟心跳
ClientAliveCountMax 2                # 2 次失败踢
UseDNS no                            # 加速
Banner /etc/issue.net                # 告示
```

---

## §36 UseDNS no 反向解析加速

```
默认 UseDNS yes：
  客户端连过来 → 反向解析 IP → 拿主机名 → 再正向解析主机名
  → 验证 IP 和主机名匹配
  
  如果 DNS 配置不当（很多云服务器默认无 PTR 记录）
  → 反查卡住 30 秒才超时
  → 用户感觉"SSH 慢"

UseDNS no：
  跳过反查，直接进认证 → 几秒连上
```

> 💡 **远程 SSH 慢？** → `UseDNS no` 一招搞定。

---

## §37 实战：禁止 root 密码登录

### 37.1 改配置

```bash
# /etc/ssh/sshd_config 改 3 行
PermitRootLogin no
PasswordAuthentication no
AllowUsers xkw
```

```bash
# reload（不断连接）
[root@server ~]# systemctl reload sshd
```

### 37.2 测试

```bash
# 客户端 1：root 直接登录（拒绝）
[xkw@client ~]$ ssh root@server
root@server's password: 【输密码】
Permission denied, please try again.
Permission denied, please try again.
Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).

# 客户端 2：root 通过密钥登录（也拒绝，因为 PermitRootLogin no）
[xkw@client ~]$ ssh -i ~/.ssh/id_rsa root@server
Permission denied (publickey).

# 客户端 3：普通用户登录（允许）
[xkw@client ~]$ ssh xkw@server
[xkw@server ~]$ su -    # su 切 root
密码：
[root@server ~]#
```

### 37.3 不在白名单的用户

```bash
# 没在 AllowUsers 里的用户
[xkw@client ~]$ ssh laowang@server
Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
# ↑ 密钥 + 密码 + 其他都不行，因为不在白名单
```

---

## §38 /var/log/secure 排错日志

SSH 服务端的所有认证失败都会记到 `/var/log/secure`：

```bash
# 实时追踪登录尝试
[root@server ~]# tail -f /var/log/secure
...
Jul 31 16:13:41 server sshd[3693]: Authentication refused: bad ownership or modes for directory /root
# ↑ /root 权限不对导致密钥认证拒绝

# 看认证失败的 IP
grep "Failed password" /var/log/secure
grep "Invalid user" /var/log/secure

# 看认证成功的
grep "Accepted password" /var/log/secure
grep "Accepted publickey" /var/log/secure
```

**常见错误信息对照表**：

| 日志 | 原因 | 解决 |
|---|---|---|
| `bad ownership or modes for directory /root` | 家目录权限不是 700 | `chmod 700 /root` |
| `Permission denied (publickey)` | 没正确配置公钥 | 检查 authorized_keys |
| `Connection refused` | sshd 没启或端口错 | `systemctl status sshd` |
| `No route to host` | 网络不通 | `ping` 主机 |
| `ssh_exchange_identification: read: Connection reset by peer` | 防火墙挡了 | `firewall-cmd --add-port` |

---

## §39 SCP 安全拷贝

```bash
# 本地 → 远程
scp local_file user@host:/remote/path/

# 远程 → 本地
scp user@host:/remote/file /local/path/

# 目录递归
scp -r local_dir user@host:/remote/path/

# 指定端口
scp -P 2222 file user@host:/path/

# 限速（KB/s）
scp -l 1000 big_file user@host:/path/
# ↑ 1000 Kbit/s ≈ 125 KB/s

# 保留权限/时间戳
scp -p file user@host:/path/

# 详细输出
scp -v file user@host:/path/
```

**实战**：
```bash
# 上传
[xkw@client ~]$ scp myfile.tar.gz xkw@server:/tmp/

# 下载
[xkw@client ~]$ scp xkw@server:/var/log/messages /tmp/

# 同步目录
[xkw@client ~]$ scp -r docs/ xkw@server:/home/xkw/docs/
```

> ⚠️ **scp 不支持断点续传**，大文件用 rsync。

---

## §40 SFTP 交互传输

```bash
# 进入 SFTP 交互
[xkw@client ~]$ sftp xkw@server
Connected to server.
sftp>

# SFTP 命令（和 ftp 类似）
sftp> ls                # 列远程目录
sftp> lls               # 列本地目录
sftp> pwd               # 远程当前目录
sftp> lpwd              # 本地当前目录
sftp> cd /tmp           # 切远程
sftp> lcd /tmp          # 切本地
sftp> put localfile     # 上传
sftp> get remotefile    # 下载
sftp> mkdir mydir       # 建远程目录
sftp> rmdir mydir       # 删远程目录
sftp> rm file           # 删远程文件
sftp> chmod 644 file    # 改远程权限
sftp> chown user file   # 改远程属主
sftp> exit              # 退出
```

**非交互式批量**：
```bash
# 用 -b 批量
sftp -b batch.txt user@host
# batch.txt 内容：
#   cd /tmp
#   put *.log
#   bye
```

---

## §41 SSH 端口转发：本地/远程/动态

### 41.1 本地端口转发 `-L`

**场景**：本地 → SSH 服务器 → 内网主机

```bash
# 访问 server 的 3306（MySQL），但 server 只监听 localhost
# 我们想从本地访问 MySQL

ssh -L 13306:localhost:3306 user@server
#   ↑         ↑          ↑      ↑
#   监听本地  目标主机    端口   通过 server 中转

# 现在本地连 localhost:13306 = server 的 MySQL
mysql -h 127.0.0.1 -P 13306 -uroot -p
```

**场景**：本地 → 跳板 → 内网主机（双层）

```bash
# 本地 → server1 → server2 的 MySQL
ssh -L 13306:server2:3306 user@server1
# 然后 mysql -h 127.0.0.1 -P 13306
```

### 41.2 远程端口转发 `-R`

**场景**：内网主机（无公网）→ 公网 SSH 服务器 → 公网访问内网服务

```bash
# 在内网机器执行
ssh -R 8080:localhost:80 user@public_server
# ↑ 公网 server 监听 8080，转发到内网的 80

# 任何连 public_server:8080 的人 → 内网 localhost:80
```

### 41.3 动态端口转发 `-D`（SOCKS 代理）

```bash
# 本地启 SOCKS5 代理 1080
ssh -D 1080 user@server
# -f 后台，-N 不开 shell
ssh -fND 1080 user@server

# 浏览器设 SOCKS5 代理 localhost:1080
# → 所有流量走 SSH 加密（科学上网）
```

### 41.4 三种转发对比

| 类型 | 命令 | 用途 |
|---|---|---|
| **本地转发** | `-L local:remote:port` | 访问内网服务 |
| **远程转发** | `-R remote:local:port` | 暴露内网到公网 |
| **动态转发** | `-D localport` | SOCKS 代理 |

---

## §42 SSH 跳板（ProxyCommand）

**场景**：直接连不上内网机器，必须先连跳板

```bash
# 方式 1：命令行 ProxyCommand
ssh -o ProxyCommand='ssh -W %h:%p user@jumpserver' user@internal_server

# 方式 2：写到 ~/.ssh/config
Host internal
    HostName 10.0.0.100
    User xkw
    ProxyCommand ssh -W %h:%p xkw@jumpserver

# 现在直接
ssh internal
```

---

## §43 速查表

### 43.1 systemd / systemctl

```bash
# 服务生命周期
systemctl start <unit>
systemctl stop <unit>
systemctl restart <unit>
systemctl reload <unit>
systemctl status <unit>

# 开机自启
systemctl enable <unit>
systemctl disable <unit>
systemctl enable --now <unit>
systemctl is-enabled <unit>

# 屏蔽
systemctl mask <unit>
systemctl unmask <unit>

# 查
systemctl list-units
systemctl list-unit-files
systemctl list-units -t service
systemctl list-units --all
systemctl --failed
systemctl list-dependencies <unit>

# 日志
journalctl -u <unit>
journalctl -u <unit> -f
journalctl -u <unit> --since "1 hour ago"

# 系统级
systemctl reboot
systemctl poweroff
systemctl get-default
systemctl set-default multi-user.target
systemctl isolate graphical.target

# 重读
systemctl daemon-reload
```

### 43.2 SSH 客户端

```bash
# 连接
ssh user@host
ssh -p 2222 user@host
ssh -i keyfile user@host
ssh -l user host
ssh -v user@host           # 调试

# 远程执行
ssh user@host 'cmd'
ssh user@host 'cmd1; cmd2'

# 文件传输
scp local user@host:/remote/
scp user@host:/remote local
scp -r dir user@host:/remote/
scp -P 2222 file user@host:/

# SFTP
sftp user@host
> put local remote
> get remote local
> ls / lls / pwd / lpwd / cd / lcd / exit

# 端口转发
ssh -L 13306:localhost:3306 user@host
ssh -R 8080:localhost:80 user@host
ssh -D 1080 user@host

# 密钥
ssh-keygen -t rsa -b 4096 -C 'comment' -f keyfile -N ''
ssh-copy-id user@host
```

### 43.3 SSH 服务端

```bash
# 配置
/etc/ssh/sshd_config        # 服务端配置
/etc/ssh/ssh_config         # 客户端全局配置
~/.ssh/config                # 客户端用户配置
~/.ssh/authorized_keys       # 信任的公钥
~/.ssh/known_hosts           # 已信任的主机指纹
/etc/ssh/ssh_host_*_key      # 服务器私钥
/etc/ssh/ssh_host_*_key.pub  # 服务器公钥

# 改完配置
systemctl reload sshd       # 推荐（不断连接）
systemctl restart sshd      # 强制重启（断开所有）

# 排错
ssh -vvv user@host          # 客户端调试
journalctl -u sshd          # 服务端日志
tail -f /var/log/secure     # 认证日志
```

---

## §44 易错点 ×12

### 1. ❌ 改了 unit 文件忘 daemon-reload

```bash
vim /etc/systemd/system/foo.service
systemctl start foo        # ⚠️ 还是旧配置
# 解：systemctl daemon-reload
```

### 2. ❌ systemctl enable 但 enable 错了 target

```bash
# 默认 enable 进 multi-user.target
# 但服务写 WantedBy=graphical.target，就没自启
# 看 unit 文件的 [Install] 段
```

### 3. ❌ PermitRootLogin no 把自己锁外面

```bash
# 永远在另一个 SSH 窗口测试 reload
# 万一连不上，物理机/控制台登录救场
```

### 4. ❌ 改了端口忘开防火墙

```bash
# 改了 Port 2222
systemctl reload sshd      # OK
# 但 firewall 还允许 22，不允许 2222 → 连不上
firewall-cmd --add-port=2222/tcp --permanent
firewall-cmd --reload
```

### 5. ❌ .ssh 目录权限错导致密钥登录失败

```bash
# /root 不是 700 → Authentication refused
chmod 700 /root
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 6. ❌ ssh-copy-id 用错用户

```bash
ssh-copy-id root@server    # 把 xkw 的公钥传到了 root 家
# 想让 xkw 免密：ssh-copy-id xkw@server
```

### 7. ❌ /etc/ssh/ssh_config 改了不生效

```bash
# 注意是 sshd_config（服务端）不是 ssh_config（客户端全局）
# 客户端用户配置是 ~/.ssh/config
```

### 8. ❌ UseDNS yes 导致 SSH 卡 30 秒

```bash
# 远程 SSH 连接卡顿 → 第一反应加 UseDNS no
UseDNS no
systemctl reload sshd
```

### 9. ❌ systemctl mask sshd 自己连不上

```bash
# mask 是屏蔽，连手动 start 都启不了
# 解：在物理机/控制台 unmask
```

### 10. ❌ kill -9 sshd 主进程会让现有连接断

```bash
# 用 systemctl stop sshd（优雅断开）
# 或 systemctl reload sshd（不影响现有）
```

### 11. ❌ SFTP 用 FTP 协议连接

```bash
# SFTP 是 SSH 自带的（端口 22）
# FTP 是另外的协议（端口 21）
# 两个完全不一样！
```

### 12. ❌ AllowUsers 没包含自己

```bash
# 加白名单时一定先确认包含自己
AllowUsers xkw myuser
# 否则直接登不出去！
```

---

## §45 面试 6 大追问

### Q1：systemd 和 init 区别？

**答**：

| | init (SysVinit) | systemd |
|---|---|---|
| 启动方式 | 串行（一个一个起）| 并行（按依赖起）|
| 配置 | shell 脚本 | unit 文件 |
| 依赖管理 | 无 | Wants/Requires/After/Before |
| 启动速度 | 慢 | 快 |
| 日志 | 各服务自己 | journalctl 统一 |
| 资源控制 | 无 | cgroup |

### Q2：systemd 的 unit 文件放在哪？优先级？

**答**：3 个路径，从高到低：
1. `/etc/systemd/system/`（用户自定义，最高）
2. `/run/systemd/system/`（运行时）
3. `/usr/lib/systemd/system/`（软件包自带）

同名 unit，优先级高的覆盖低的。

### Q3：ssh-keygen 和 ssh-copy-id 关系？

**答**：
- `ssh-keygen`：客户端**生成**密钥对（id_rsa + id_rsa.pub）
- `ssh-copy-id`：把客户端**公钥**复制到服务器的 authorized_keys
- 之后客户端可以用私钥登录（服务器用公钥验签）

### Q4：ssh 密钥登录和密码登录哪个安全？

**答**：**密钥登录更安全**。
- 密码：可爆破、字典攻击、社会工程学
- 密钥：默认 2048/4096 位 RSA 或 Ed25519，**理论上不可暴力破解**
- 建议：禁用密码，只允许密钥（`PasswordAuthentication no`）

### Q5：SSH 端口转发三种？

**答**：
- **本地转发 -L**：本地端口 → 跳板 → 内网服务（访问内网）
- **远程转发 -R**：公网服务器端口 → 内网服务（暴露内网）
- **动态转发 -D**：SOCKS 代理（科学上网/翻墙）

### Q6：systemd 的 Restart= 和 RestartSec= 怎么配合？

**答**：
- `Restart=on-failure`：失败才重启
- `RestartSec=42s`：重启前等 42 秒（防止重启风暴）
- 实战：服务挂掉等 42 秒再拉起，避免 CPU 跑满

---

## §46 链路

| 笔记 | 关系 |
|---|---|
| [[Linux进程与负载/Linux进程与负载]] | systemd 启动的进程都是 PID 1 的子孙 |
| [[LinuxShell/shell]] | unit 文件的 ExecStart 经常跑 shell 脚本 |
| [[Linux包管理/package]] | yum install openssh-server 装 sshd |
| [[Linux用户权限/user-permission]] | AllowUsers / AllowGroups 涉及用户权限 |
| [[Linux计划任务/cron]] | Timer unit 可替代部分 cron |
| [[Linux文本处理/grep]] | `grep -i ssh /var/log/secure` 排错 |

### 服务与 SSH 全景图

```
                          ┌────────────────────────────────┐
                          │   systemd (PID 1)             │
                          │   /usr/lib/systemd/systemd    │
                          └───────────────┬────────────────┘
                                          │
        ┌─────────────────┬───────────────┼───────────────┬──────────────┐
        │                 │               │               │              │
        ↓                 ↓               ↓               ↓              ↓
  ┌──────────┐      ┌──────────┐    ┌──────────┐    ┌──────────┐   ┌──────────┐
  │ sshd     │      │ crond    │    │ nginx    │    │ mysqld   │   │ atd      │
  │ .service │      │ .service │    │ .service │    │ .service │   │ .service │
  └────┬─────┘      └────┬─────┘    └────┬─────┘    └────┬─────┘   └────┬─────┘
       │                 │               │               │              │
       ↓ :22             ↓               ↓ :80           ↓ :3306        ↓
   SSH clients        cron jobs       web users       DB clients     at users
       │
       ├─ ssh user@host
       ├─ scp / sftp
       ├─ ssh-keygen + ssh-copy-id
       └─ ssh -L / -R / -D (端口转发)
```

**下一步**：完成 Linux服务与SSH 后可以选择：
- 🎯 **第 3 波 ①** [[Linux日志与时间/]]（05.16+17 共 2 PDF）—— rsyslog + journalctl + chrony
- 🎯 **第 3 波 ②** [[Linux文件传输/]]（05.19+20 共 2 PDF）—— scp/rsync/nfs
- 🎯 **第 4 波 ①** [[Linux存储/]]（06.4+5+6+7+8 RAID/LVM/文件系统）—— fdisk/md/lvm/fsck