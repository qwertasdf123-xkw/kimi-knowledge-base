---
title: Linux 进程与负载 — ps/top/kill/nice/负载/sar
desc: 基于 05.CentOS-7-系统管理-1/12+13 + 06.CentOS-7-系统管理-2/3 三个 PDF 的实操笔记。覆盖进程查看（ps / top）、信号与 kill、jobs 控制、screen 长会话、nice/renice 优先级、chrt 实时调度、负载与 load average、stress 压测、free/sar 监控、僵尸/孤儿进程。
type: 笔记
module: Linux进程与负载
pdf: 05.12 进程管理.pdf + 05.13 系统负载监控.pdf + 06.3 进程调度管理.pdf
pdf_size: 1266+377+408 行（2051 行合计）
scope: CentOS-7 (procps-ng + util-linux + rtkit)
status: 完成
---

# Linux 进程与负载 — ps / top / kill / nice / load / sar

> **范围**：基于《CentOS-7 系统管理 1》第 12、13 章 + 《CentOS-7 系统管理 2》第 3 章 三个 PDF 整理。
> 覆盖 **进程查看**（ps / top / pstree）+ **前后台控制**（jobs / bg / fg / screen）+ **信号与 kill** + **优先级调度**（nice / renice / chrt）+ **系统负载**（load average）+ **压测**（stress）+ **性能监控**（free / sar / vmstat）+ **僵尸/孤儿进程**。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：进程 = 程序的"运行实例"]]
- [[#§1 进程的"户口本"：/proc]]
- [[#§2 ps 三派系：UNIX / GNU / BSD]]
- [[#§3 ps -e / -ef：最常用基础]]
- [[#§4 ps -u / -t：按用户/终端过滤]]
- [[#§5 ps axu / axf：BSD 派 + 进程树]]
- [[#§6 ps 自定义字段：-o 与 --sort]]
- [[#§7 进程状态 STAT 详解]]
- [[#§8 top 实时监控]]
- [[#§9 进程前后台：jobs / bg / fg / &]]
- [[#§10 Ctrl+Z vs Ctrl+C 区别]]
- [[#§11 nohup：脱离终端]]
- [[#§12 screen：长会话保持]]
- [[#§13 信号系统：kill -l 的 64 个信号]]
- [[#§14 kill / killall / pkill / pgrep / xkill]]
- [[#§15 whoami / who / w / last 谁在线]]
- [[#§16 nice 启动时设优先级]]
- [[#§17 renice 运行时改优先级]]
- [[#§18 chrt 实时调度策略]]
- [[#§19 top 里改优先级（r）]]
- [[#§20 系统负载 load average 三数字解读]]
- [[#§21 uptime / w 的负载]]
- [[#§22 stress 压测：CPU / 内存 / IO]]
- [[#§23 free 内存监控]]
- [[#§24 sar 全能监控]]
- [[#§25 vmstat / iostat 轻量监控]]
- [[#§26 僵尸进程 Z]]
- [[#§27 孤儿进程被 systemd 收养]]
- [[#§28 速查表]]
- [[#§29 易错点 ×12]]
- [[#§30 面试 6 大追问]]
- [[#§31 链路]]

---

## §0 心智模型：进程 = 程序的"运行实例"

```
程序（程序）：磁盘上的可执行文件（静态）
              ↓ 加载到内存
进程（process）：正在运行的程序实例（动态）

一个程序可以启动多次 → 多个进程
一个进程可以被多次执行 → 通过 fork 产生子进程
```

**类比**：
- **程序** = 菜谱（写好的步骤）
- **进程** = 真正在厨房炒这道菜的厨师
- 一个菜谱多个厨师同时做 → 一份程序多进程

**关键概念**：
```
PID  = Process ID，进程"身份证号"（唯一）
PPID = Parent PID，父进程 ID（谁启动了我）
UID  = User ID，谁在跑这个进程
STAT = State，当前状态（R/S/D/Z/T 等）
```

> 💡 每个进程都有"三张表"：**文件描述符表**（打开了啥）+ **内存映射表**（用了啥内存）+ **信号表**（能收到啥信号）。

---

## §1 进程的"户口本"：/proc

Linux 把进程信息暴露成**伪文件系统** `/proc`：

```bash
[xkw@centos7 ~]$ ls /proc
1       # ← PID 1 = systemd（所有进程的"祖先"）
2       # ← PID 2 = kthreadd（内核线程管家）
...     # ← 每个数字 = 一个进程目录
self    # ← 当前进程的软链接
cpuinfo # ← CPU 信息
meminfo # ← 内存信息
loadavg # ← 负载平均
```

```bash
# 看某个进程的所有信息
[xkw@centos7 ~]$ ls /proc/1
ls: cannot read symbolic link '/proc/1/exe': Permission denied
arch_status  cmdline  comm  cwd  environ  exe  fd  ...
# ↑
#  cmdline = 启动命令
#  exe     = 可执行文件路径（软链接）
#  fd      = 打开的文件描述符
#  status  = 进程状态（人话）
#  stat    = 进程状态（机器读）

# 看进程的当前工作目录
[xkw@centos7 ~]$ readlink /proc/$$/cwd
/home/xkw
# $$ = 当前 shell 的 PID
```

> 💡 `/proc/$$/cwd` = 当前 shell 所在目录（pwd 来自这）。
> `/proc/$$/exe` = 当前 shell 的可执行文件（bash）。

---

## §2 ps 三派系：UNIX / GNU / BSD

`ps` 命令的选项**混乱** —— 因为历史上三个流派各自演进：

| 派系 | 选项风格 | 是否要 `-` |
|---|---|---|
| **UNIX** | `-e -f` | **要** |
| **GNU** | `--user --sort` | **要** |
| **BSD** | `aux axf` | **不要** |

```bash
# UNIX 派（标准）
ps -e              # 所有进程
ps -ef             # 所有 + 完整格式
ps -eo pid,cmd     # 所有 + 自定义字段

# BSD 派（最常用！）
ps aux             # 所有 + 用户导向格式
ps axf             # 所有 + 森林树状
ps axo pid,%cpu    # 所有 + 自定义字段（无 -）

# GNU 派（长选项）
ps --user xkw      # 只看 xkw
ps --sort=-%cpu    # 按 CPU 降序
```

> ⚠️ **`aux` 不要写 `-aux`**！传统写法 `-aux` 实际是 BSD 的 `aux` + UNIX 的 `-U user`，行为不确定。

### 2.1 ps 最常用的 5 种组合

| 命令 | 含义 |
|---|---|
| `ps -e` | 所有进程（简表） |
| `ps -ef` | 所有进程（完整） |
| `ps aux` | BSD 风格（最常用） |
| `ps axf` | 进程树 |
| `ps -eo pid,%cpu,cmd` | 自定义字段 |

---

## §3 ps -e / -ef：最常用基础

### 3.1 ps -e（简表）

```bash
[xkw@centos7 ~]$ ps -e
  PID TTY          TIME CMD
    1 ?        00:00:02 systemd
    2 ?        00:00:00 kthreadd
    4 ?        00:00:00 kworker/0:0H
    6 ?        00:00:00 ksoftirqd/0
    ...
```

字段含义：
- **PID**：进程号
- **TTY**：终端（`?` = 不需要终端，如守护进程）
- **TIME**：累计占用的 CPU 时间
- **CMD**：启动命令

### 3.2 ps -ef（完整）

```bash
[xkw@centos7 ~]$ ps -ef | head -n 5
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 08:45 ?        00:00:02 /usr/lib/systemd/systemd --switched-root --system --deserialize 22
root         2     0  0 08:45 ?        00:00:00 [kthreadd]
root         4     2  0 08:45 ?        00:00:00 [kworker/0:0H]
root         6     2  0 08:45 ?        00:00:00 [ksoftirqd/0]
```

字段含义：
- **UID**：启动用户
- **PID**：进程号
- **PPID**：父进程号
- **C**：CPU 使用率（百分比整数）
- **STIME**：启动时间
- **TTY**：终端
- **TIME**：累计 CPU 时间
- **CMD**：启动命令（**含参数**，vs ps -e 是只有命令名）

---

## §4 ps -u / -t：按用户/终端过滤

### 4.1 ps -u user：只看某用户

```bash
[xkw@centos7 ~]$ ps -u xkw u
USER       PID %CPU %MEM    VSZ   RSS TTY        STAT START   TIME COMMAND
xkw       2810  0.0  0.2  89844  9912 ?        Ss   10:16   0:00 /usr/lib/systemd/systemd --user
xkw       2816  0.1  0.1 235408  5332 ?        S    10:16   0:00 (sd-pam)
xkw       2831  0.2  0.2 1038956 10400 ?      Ssl  10:16   0:00 /usr/bin/pulseaudio --daemonize=no --log-target=journal
...
```

加了 `u` 会显示 **%CPU %MEM VSZ RSS STAT** 等扩展字段。

### 4.2 ps -t pts/1：只看某终端

```bash
[xkw@centos7 ~]$ ps -t pts/1 u
USER       PID %CPU %MEM    VSZ   RSS TTY        STAT START   TIME COMMAND
xkw       2843  0.0  0.1 226452  5396 pts/1    Ss   10:16   0:00 -bash
xkw       4233  0.0  0.0 257508  3952 pts/1    R+   10:40   0:00 ps -t pts/1 u
```

`R+` 的 `+` 表示**前台进程**（占用这个终端）。

### 4.3 实战：找出"我"的所有进程

```bash
# 方法 1：pgrep + ps
[xkw@centos7 ~]$ pgrep -u xkw
2810
2816
2831
2843

# 方法 2：ps -u 自带
[xkw@centos7 ~]$ ps -u xkw

# 方法 3：whoami 配合
[xkw@centos7 ~]$ ps -u $(whoami)
```

---

## §5 ps axu / axf：BSD 派 + 进程树

### 5.1 ps axu：BSD 派（最常用）

```bash
[xkw@centos7 ~]$ ps axu | head
USER   PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root     1  0.0  0.3 183984 14136 ?        Ss   08:55   0:02 /usr/lib/systemd/systemd --switched-root --system --deserialize 18
root     2  0.0           0    0 ?        S    08:55   0:00 [kthreadd]
root     3  0.0           0    0 ?        I<   08:55   0:00 [rcu_gp]
root     4  0.0           0    0 ?        I<   08:55   0:00 [rcu_par_gp]
...
```

> 💡 **面试题**：进程最常用查看命令？答：`ps aux | grep xxx` 或 `ps axu | grep xxx`。

### 5.2 ps axf：进程树（森林）

```bash
[xkw@centos7 ~]$ ps axf
    PID TTY      STAT   TIME COMMAND
      2 ?        S      0:00 [kthreadd]
      3 ?        I<     0:00  \_ [rcu_gp]
...
   1159 ?        Ss     0:00 /usr/sbin/sshd -D -oCiphers=aes256-gcm@openssh.com...
   2033 ?        Ss     0:00  \_ sshd: root [priv]
   2064 ?        S      0:00  |   \_ sshd: root@pts/0
   2075 pts/0   Ss     0:00  |       \_ -bash
   2950 pts/0   S+     0:00  |           \_ man ps
   2963 pts/0   S+     0:00  |             \_ less
   2800 ?        Ss     0:00  \_ sshd: xkw [priv]
   2833 ?        S      0:00      \_ sshd: xkw@pts/1
   2843 pts/1   Ss     0:00          \_ -bash
   4278 pts/1   R+     0:00              \_ ps axf
```

`\_` 表示**缩进**，纵向就能看出**父子关系**。

> 💡 **实战**：用 `ps axjf` 加 `j` 字段能看到 PGID（进程组）+ SID（会话）。

### 5.3 ps -ejH / ps --forest

```bash
# -H = 显示进程层级
[xkw@centos7 ~]$ ps -ejH | head

# --forest = ASCII 树
[xkw@centos7 ~]$ ps --forest -e

# pstree 命令（更直观！）
[xkw@centos7 ~]$ pstree
systemd─┬─NetworkManager───2*[{NetworkManager}]
        ├─sshd───sshd───bash───pstree
        ├─tuned───4*[{tuned}]
        ...
```

---

## §6 ps 自定义字段：-o 与 --sort

### 6.1 -o：自定义输出列

```bash
# 只看 PID 1159 的某些字段
[xkw@centos7 ~]$ ps -o pid,%cpu,%mem,command 1159
  PID %CPU %MEM COMMAND
 1159  0.0  0.1 /usr/sbin/sshd -D -oCiphers=aes256-gcm@openssh.com...
```

可用字段（部分）：

| 字段                          | 含义            |
| --------------------------- | ------------- |
| `pid`                       | 进程号           |
| `ppid`                      | 父进程号          |
| `pgid`                      | 进程组 ID        |
| `sid`                       | 会话 ID         |
| `user` / `ruser` / `euser`  | 实际/真实/有效用户    |
| `comm`                      | 命令名（短）        |
| `cmd` / `command` / `args`  | 完整命令          |
| `%cpu` / `%mem`             | CPU/内存占比      |
| `vsz` / `rss`               | 虚拟内存/物理内存（KB） |
| `stat`                      | 状态码           |
| `nice` / `ni`               | nice 值        |
| `etime`                     | 启动后运行时间       |
| `start` / `etime` / `stime` | 启动时间/累计/启动时刻  |

### 6.2 实战：看 passwd 进程的用户切换

```bash
[xkw@centos7 ~]$ ps -C passwd -o pid,ruser,euser,command
  PID RUSER EUSER    COMMAND
 4420 xkw    root     passwd
```

RUSER = 真实用户，EUSER = **有效用户**。
→ passwd 是用 **setuid root** 启动的，普通用户能改自己密码。

### 6.3 --sort：排序

```bash
# 按 CPU 降序（最耗 CPU 在前面）
[xkw@centos7 ~]$ ps axu --sort=-%cpu | head -n 5
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root      1786  0.4  5.1 1092936 205568 ?      Ssl  08:55   0:01 /usr/libexec/packagekitd
xkw       3356  0.3  4.9 3042676 197256 tty2   Sl+  10:36   0:03 /usr/bin/gnome-shell
root      1150  0.1  0.8 618372  32088 ?      Ssl  08:55   0:00 /usr/libexec/platform-python ...
xkw       3728  0.1  2.7 1379632 109476 tty2  Sl+  10:36   0:12 /usr/bin/gnome-software --gapplication-service

# 按内存升序
ps axu --sort=%mem

# 按 PID 倒序
ps axu --sort=-pid
```

> ⚠️ `--sort=%cpu`（不带 `-`）= 升序；`--sort=-%cpu` = 降序。

---

## §7 进程状态 STAT 详解

```
STAT 字段是一个"编码"，组合状态：

基础状态（第一位）：
  R    Running       运行中
  S    Sleeping      可中断睡眠（最常见，等用户输入/IO）
  D    Disk sleep    不可中断睡眠（等 IO，不能被信号打断）
  T    Stopped       已停止（被信号 SIGSTOP 暂停）
  Z    Zombie        僵尸（已退出，等父进程收尸）
  X    Dead          死进程
  I    Idle          空闲内核线程

附加标志（第二位以后）：
  <    高优先级进程（nice < 0）
  N    低优先级进程（nice > 0）
  L    内存锁定页
  s    会话领导者（session leader）
  l    多线程进程
  +    前台进程组
```

实战对照：

```bash
[xkw@centos7 ~]$ ps axu | grep nginx
root     1234  0.0  0.1  12345  6789 ?        Ss    # Ss = S + s，可中断睡眠 + 会话领导
root     1235  0.0  0.1  12345  6789 ?        S<    # S< = S + <，高优先级
xkw      5678  0.0  0.1  12345  6789 pts/0    R+    # R+ = R + +，前台运行

# 关键状态识别
# D  ← 不能 kill -15，要 kill -9（或修 IO）
# Z  ← 父进程有问题（见 §26 僵尸）
# T  ← 进程被 SIGSTOP 暂停，kill -18 唤醒
```

---

## §8 top 实时监控

```bash
[xkw@centos7 ~]$ top
top - 14:18:22 up 47 min,  2 users,  load average: 1.37, 0.50, 0.47
Tasks: 187 total,   4 running, 183 sleeping,   0 stopped,   0 zombie
%Cpu(s):100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem : 4026124 total, 1535676 free,  490668 used, 1999780 buff/cache
KiB Swap: 4063228 total, 4063228 free,        0 used. 3277584 avail Mem

  PID USER      PR  NI    VIRT  RES  SHR S  %CPU %MEM     TIME+ COMMAND
 2596 root      20   0    7312   100     0 R 100.0  0.0   1:01.42 stress
 2597 root      20   0    7312   100     0 R 100.0  0.0   1:01.25 stress
 2594 root      20   0  162100  2320  1588 R   0.6  0.1   0:00.12 top
```

### 8.1 top 输出详解

**头部 5 行（汇总信息）**：

| 行 | 字段 | 含义 |
|---|---|---|
| 第 1 行 | 当前时间 + up 时间 + 用户数 + **load average** | 系统健康度核心 |
| 第 2 行 | Tasks: total/running/sleeping/stopped/zombie | 进程分布 |
| 第 3 行 | %Cpu(s): us/sy/ni/id/wa/hi/si/st | CPU 时间分布 |
| 第 4 行 | KiB Mem: total/free/used/buff/cache | 内存分布 |
| 第 5 行 | KiB Swap: total/free/used/avail | 交换分区 |

**CPU 时间拆解**：
```
us = user   用户进程（应用层）
sy = system 内核（系统调用/IO/调度）
ni = nice   低优先级进程消耗
id = idle   空闲（100% - 各项 = 你的可用率）
wa = iowait 等 IO 完成（高 = 磁盘慢）
hi = hardirq 硬中断
si = softirq 软中断
st = steal  被其他 VM 偷走的时间（云服务器用）
```

> 💡 **`%Cpu(s): 100.0 us, 0.0 sy` + 0.0 id** = CPU 满载（用户态）。

### 8.2 top 进程列表字段

| 字段 | 含义 |
|---|---|
| `PID` | 进程号 |
| `USER` | 用户 |
| `PR` | 优先级（Linux 内核视角，20 = nice 0）|
| `NI` | nice 值（-20 ~ 19，负数 = 高优先级）|
| `VIRT` | 虚拟内存 |
| `RES` | 实际占用物理内存 |
| `SHR` | 共享内存 |
| `S` | 状态 |
| `%CPU` | CPU 占比 |
| `%MEM` | 内存占比 |
| `TIME+` | 累计 CPU 时间 |
| `COMMAND` | 命令 |

### 8.3 top 交互命令

| 按键 | 含义 |
|---|---|
| `h` | 帮助 |
| `q` | 退出 |
| `k` | 输入 PID → kill（默认 SIGTERM，可输入信号号） |
| `r` | 输入 PID → renice（改优先级） |
| `P` | 按 CPU 排序 |
| `M` | 按内存排序 |
| `T` | 按 TIME+ 排序 |
| `1` | 展开多个 CPU（看每个核的负载）|
| `c` | 切换显示命令/命令行 |
| `u` | 按用户过滤 |
| `f` | 自定义字段 |

### 8.4 top 实战：找出最耗 CPU 的进程

```bash
# 进入 top
top

# 输 P（按 CPU 排序）
# 输 k → 输入 PID → 9（kill -9）
# 输 q 退出
```

### 8.5 top 批处理模式

```bash
# 跑 1 次（不持续）+ 指定输出字段
[xkw@centos7 ~]$ top -bn1 | head -n 20
# -b = 批处理模式（不像交互）
# -n1 = 只跑 1 次

# 跑 N 次，每次间隔 M 秒
top -bn 3 -d 1    # 跑 3 次，每次间隔 1 秒
```

> 💡 **面试题**：如何把 top 输出存到日志？答：`top -bn 3 > top.log`。

---

## §9 进程前后台：jobs / bg / fg / &

```bash
# 1) 准备：写个小循环程序
[xkw@centos7 ~]$ cat << 'EOF' > study
#!/bin/bash
while true
do
  echo "I'm studying [ $@ ]" >> study.log
  sleep 1
done
EOF
[xkw@centos7 ~]$ chmod +x study
```

### 9.1 &：启动后台

```bash
# & = 立即返回，进程在后台跑
[xkw@centos7 ~]$ ./study Linux &
[1] 67307    # ← [1] = job 编号，67307 = PID
[xkw@centos7 ~]$ jobs
[1]+  ./study Linux &    # + = 当前 job（最新）
```

> ⚠️ **shell 关闭 = 后台进程死**（除非 nohup）。

### 9.2 Ctrl+Z：暂停到后台

```bash
[xkw@centos7 ~]$ ./study Python
^Z                          # ← Ctrl+Z 暂停
[2]+  ./study Python        # ← 自动变后台 Stopped

[xkw@centos7 ~]$ jobs
[1]-  ./study Linux &       # - = 上一个 job
[2]+  ./study Python        # + = 当前 job（Stopped）
```

### 9.3 bg：让 Stopped 的在后台继续

```bash
[xkw@centos7 ~]$ bg %2
[2]+ ./study Python &       # ← Python 从 Stopped → 后台跑

[xkw@centos7 ~]$ jobs
[1]-  ./study Linux &
[2]+  ./study Python &
```

### 9.4 fg：调到前台（占用终端）

```bash
[xkw@centos7 ~]$ fg %1
./study Linux               # ← 占前台，Ctrl+C 才能退

^C                          # ← Ctrl+C 终止（前台专属信号）

[xkw@centos7 ~]$ fg %2
./study Python
^C

[xkw@centos7 ~]$ fg %3
./study MySQL
^C

[xkw@centos7 ~]$ jobs      # 全没了
```

### 9.5 总结口诀

```
&   = 启动就后台
fg  = 后台 → 前台
bg  = Stopped → 后台运行
Ctrl+Z = 前台 → Stopped 后台
Ctrl+C = 终止前台进程
```

> ⚠️ **Ctrl+C 只能杀前台**！后台进程的 Ctrl+C 不起作用。

### 9.6 passwd 特殊行为

```bash
[xkw@centos7 ~]$ passwd &
[3] 3135

# 输入新密码时（后台）：
xkw     # ← 仍然要求输入密码，因为 passwd 必须挂 tty
# 但因为在后台，可能没法输入完整

[1]+  passwd              # 显示结束（密码修改完成）
```

---

## §10 Ctrl+Z vs Ctrl+C 区别

| 信号 | Ctrl+Z | Ctrl+C |
|---|---|---|
| 名称 | SIGTSTP（**T**erminal **s**top）| SIGINT（**Int**errupt）|
| 行为 | **暂停**进程（Stopped）| **终止**进程 |
| 进程状态 | T（可被 SIGCONT 唤醒）| 消失 |
| 用法 | 临时让前台程序让出 CPU | 取消操作 |

```bash
# Ctrl+Z → bg 的经典用法
sleep 100
^Z                                  # 暂停
[1]+  Stopped                  sleep 100
bg %1
[1]+ sleep 100 &                   # 后台跑

# Ctrl+C 直接终止
sleep 100
^C
$
```

---

## §11 nohup：脱离终端

```bash
# 终端关了 → 进程被 SIGHUP 杀掉（默认）
# nohup = No HangUP，忽略 SIGHUP

[xkw@centos7 ~]$ nohup ./study English &
[1] 1234

[xkw@centos7 ~]$ ls nohup.out
nohup.out                            # ← 默认输出到这个文件
```

> 💡 `nohup` 适合：用 SSH 启动长任务，断网后任务不丢。

---

## §12 screen：长会话保持

### 12.1 安装

```bash
[root@centos7 ~]# yum install -y epel-release
[root@centos7 ~]# yum install -y screen
```

### 12.2 三种用法

```bash
# 1) 创建新窗口（类似开新 tab）
[xkw@centos7 ~]$ screen
[xkw@centos7 ~]$ sleep 1234

# 按 Ctrl+A → D（detach）退出但不杀进程
[xkw@centos7 ~]$ screen -ls
There is a screen on:
       40398.pts-7.centos7         (Detached)
1 Socket in /run/screen/S-xkw.

# 2) 重连回会话
[xkw@centos7 ~]$ screen -r 40398.pts-7.centos7

# 3) 完全杀掉会话
# 方法 1：quit
[xkw@centos7 ~]$ screen -X -S 40398.pts-7.centos7 quit
# 方法 2：直接 kill 进程
[xkw@centos7 ~]$ kill 40398     # 40398 是 screen 主进程 PID
```

### 12.3 screen 速查

```bash
screen                      # 新建 session
screen -ls                  # 列出现有 session
screen -r <id>              # 重新连接
screen -X -S <id> quit      # 杀 session
Ctrl+A, D                   # detach（保留后台）

# 适合 ssh 远程跑长任务（编译/下载大文件）
# tmux 是同款但更现代
```

---

## §13 信号系统：kill -l 的 64 个信号

```bash
[xkw@centos7 ~]$ kill -l
 1) SIGHUP    2) SIGINT     3) SIGQUIT   4) SIGILL    5) SIGTRAP
 6) SIGABRT   7) SIGBUS     8) SIGFPE    9) SIGKILL   10) SIGUSR1
11) SIGSEGV  12) SIGUSR2   13) SIGPIPE  14) SIGALRM  15) SIGTERM
16) SIGSTKFLT 17) SIGCHLD  18) SIGCONT  19) SIGSTOP  20) SIGTSTP
21) SIGTTIN  22) SIGTTOU  23) SIGURG   24) SIGXCPU  25) SIGXFSZ
26) SIGVTALRM 27) SIGPROF 28) SIGWINCH 29) SIGIO    30) SIGPWR
31) SIGSYS   34) SIGRTMIN+... 35)...     ...64) SIGRTMAX
```

### 13.1 必须记住的 9 大信号

| 编号 | 名称 | 默认行为 | 用途 |
|---|---|---|---|
| **1** | **SIGHUP** | 终止 | 终端断开 |
| **2** | **SIGINT** | 终止 | Ctrl+C |
| **3** | SIGQUIT | 终止 + core | Ctrl+\\ |
| **9** | **SIGKILL** | **强制终止** | `kill -9`，绝不能被捕获或忽略 |
| **15** | **SIGTERM** | 终止（优雅）| `kill` 默认 |
| **18** | **SIGCONT** | 恢复运行 | 把 Stopped 唤醒 |
| **19** | **SIGSTOP** | **暂停** | 类似 Ctrl+Z，不可被捕获 |
| **20** | SIGTSTP | 暂停 | Ctrl+Z |
| **17** | SIGCHLD | 忽略 | 子进程退出时通知父进程 |

### 13.2 信号 vs 进程

```bash
# job 1 = ./study Linux
# job 2 = ./study Python

[xkw@centos7 ~]$ kill -19 %1       # SIGSTOP（暂停 job 1）
[xkw@centos7 ~]$ jobs
[1]+  ./study Linux               # ← 没 & 了（变成前台样式）
[2]-  ./study Python &

[xkw@centos7 ~]$ kill -18 %1       # SIGCONT（唤醒 job 1）
[xkw@centos7 ~]$ jobs
[1]+  ./study Linux &             # ← 又变后台了
[2]-  ./study Python &

[xkw@centos7 ~]$ kill -SIGTERM %2 # SIGTERM（优雅退出 job 2）
[xkw@centos7 ~]$ jobs
[1]+  ./study Linux &
[2]+  ./study Python              # 终止中…

[xkw@centos7 ~]$ kill %1          # 默认 SIGTERM
[xkw@centos7 ~]$ jobs
[1]+  ./study Linux               # 终止中…
[xkw@centos7 ~]$ jobs
（空）
```

### 13.3 实战：杀掉 md5sum 抢 CPU 进程

```bash
# 找最耗 CPU 的
[xkw@centos7 ~]$ ps axo pid,%cpu,command --sort -%cpu | head -n 5
  PID %CPU COMMAND
73712 99.7 md5sum /dev/zero
 1150  0.1 /usr/libexec/platform-python -Es /usr/sbin/tuned -l -P
 1786  0.1 /usr/libexec/packagekitd
69280  0.1 /usr/bin/gnome-shell

# kill -15（优雅退，允许清理）
[xkw@centos7 ~]$ kill 73712
# 等几秒还没死 → kill -9（强制）
[xkw@centos7 ~]$ kill -9 73712
```

### 13.4 用 PID 杀独立（不通过 job）

```bash
# 启动了 study 但忘了 &
[xkw@centos7 ~]$ ./study MySQL &
[1] 10123      # ← 记住 PID

[xkw@centos7 ~]$ ps axu | grep study
xkw  10123  0.0  0.0 113284  1416 pts/4 S 14:53   0:00 /bin/bash ./study MySQL
xkw  10157  0.0  0.0 112824   984 pts/4 R  14:53   0:00 grep --color=auto study

[xkw@centos7 ~]$ kill 10123
[xkw@centos7 ~]$ jobs
[1]+  ./study MySQL
（终止中）
```

> 💡 **面试题**：kill -9 和 kill -15 区别？答：
> - `-15`（SIGTERM）= 优雅退，给进程清理资源的机会
> - `-9`（SIGKILL）= 强制退，**进程不能 catch 或 ignore**
> - 先 `-15`，不响应再 `-9`

---

## §14 kill / killall / pkill / pgrep / xkill

### 14.1 kill：按 PID 杀

```bash
kill <PID>            # 默认 SIGTERM
kill -9 <PID>         # SIGKILL
kill -SIGTERM <PID>   # 等价 kill <PID>
```

### 14.2 pgrep：按名字找 PID

```bash
[xkw@centos7 ~]$ sleep 1231 &
[1] 3517
[xkw@centos7 ~]$ sleep 1232 &
[2] 3518
[xkw@centos7 ~]$ sleep 1233 &
[3] 3519

[xkw@centos7 ~]$ pgrep sleep
3517
3518
3519

[xkw@centos7 ~]$ pgrep -l sleep
3517 sleep
3518 sleep
3519 sleep
```

### 14.3 pkill：按名字杀（批量）

```bash
[xkw@centos7 ~]$ pkill sleep
[1]   sleep 1231
[2]-  sleep 1232
[3]+  sleep 1233
# ↑ 三个全死

[xkw@centos7 ~]$ ps axu | grep sleep
xkw  3535  0.0  0.0  112824 980 pts/2 S 11:36   0:00 grep --color=auto sleep
# 只有 grep 自己
```

### 14.4 按用户杀

```bash
# root 看某个用户所有进程
[xkw@centos7 ~]$ pgrep -u xkw
3403
3404

# 杀掉 xkw 所有进程（暴力！）
[root@centos7 ~]# pkill -u xkw
# ⚠️ xkw 自己也会被踢下线！
```

### 14.5 按终端杀

```bash
[xkw@centos7 ~]$ tty
/dev/pts/0

[xkw@centos7 ~]$ pgrep -t pts/0 -l
3555 bash
3607 sleep
3608 sleep

[xkw@centos7 ~]$ pkill -t pts/0
# ↑ 杀这个终端所有进程（包括 bash 自己！）
# ⚠️ 杀掉 bash 就断开了 pts/0
```

### 14.6 按 PPID 杀（杀所有子进程）

```bash
[xkw@centos7 ~]$ sleep 1231 &
[1] 3708
[xkw@centos7 ~]$ sleep 1232 &
[2] 3709
[xkw@centos7 ~]$ ps jf
PPID  PID PGID  SID TTY       TPGID STAT UID   TIME COMMAND
 3663 3664 3664 3664 pts/0     3711 Ss  1000  0:00 \_ -bash          # ← bash PPID 3664
 3664 3708 3708 3664 pts/0     3711 S   1000  0:00 \_ sleep 1231
 3664 3709 3709 3664 pts/0     3711 S   1000  0:00 \_ sleep 1232
 3664 3711 3711 3664 pts/0     3711 R+  1000  0:00 \_ ps jf

[xkw@centos7 ~]$ pkill -P 3664
# ↑ 杀 3664 的所有子进程（两个 sleep）
```

### 14.7 yum 装包卡住？批量杀

```bash
# yum install 被 Ctrl+Z 暂停了 3 个，挂死了
[xkw@centos7 ~]$ ps axu | grep yum
root  8191  0.8  2.9 631840 115748 pts/0 T 11:09  0:00 /usr/libexec/platform-python /usr/bin/yum install httpd
root  8193  0.8  2.8 631840 114060 pts/0 T 11:09  0:00 /usr/libexec/platform-python /usr/bin/yum install httpd
root  8195  0.8  2.8 631840 115336 pts/0 T 11:09  0:00 /usr/libexec/platform-python /usr/bin/yum install httpd
root  8221  0.0  0.0 222016  1104 pts/0 S+ 11:10  0:00 grep --color=auto yum
# 注意 STAT 列都是 T（Stopped）

# 取出所有 PID（排除 grep 自身）
[xkw@centos7 ~]$ ps axu | grep yum | grep -v grep | awk '{print $2}'
8191
8193
8195

# 一把梭
[xkw@centos7 ~]$ kill -9 $(ps axu | grep yum | grep -v grep | awk '{print $2}')
```

### 14.8 xkill：图形界面点谁杀谁

```bash
[xkw@centos7 ~]$ xkill
# 鼠标变骷髅，点击哪个窗口就强杀那个进程
```

---

## §15 whoami / who / w / last 谁在线

### 15.1 whoami

```bash
[xkw@centos7 ~]$ whoami
xkw    # ← 当前用户
```

### 15.2 who

```bash
[xkw@centos7 ~]$ who
xkw      pts/0        2024-07-23 14:54 (10.1.8.1)
xkw      pts/1        2024-07-23 14:56 (10.1.8.1)
root     pts/3        2024-07-23 14:17 (10.1.8.1)
# 用户    终端          登录时间        来源 IP
```

### 15.3 w

```bash
[xkw@centos7 ~]$ w
 15:04:35 up 6:08, 4 users, load average: 0.00, 0.02, 0.02
USER     TTY      FROM         LOGIN@   IDLE   JCPU   PCPU WHAT
xkw    pts/0 10.1.8.1          14:54    1.00s  0.14s  0.00s w
xkw    pts/1 10.1.8.1          14:56    2:27   0.01s  0.01s -bash
root   pts/3 10.1.8.1          14:17   10:11   0.04s  0.04s -bash
# ↑ 头部 = uptime 简化版（含 load average）
# LOGIN@ = 登录时间
# IDLE   = 空闲时间
# JCPU   = 该 TTY 所有进程占的 CPU 时间
# PCPU   = WHAT 字段里那个进程占的 CPU
```

### 15.4 last

```bash
[xkw@centos7 ~]$ last
xkw    pts/0   10.1.8.1  Wed Nov 9 11:42  still logged in    # ← 当前
xkw    pts/0   10.1.8.1  Wed Nov 9 11:37 - 11:41  (00:03)     # ← 已断开
xkw    pts/2   10.1.8.1  Wed Nov 9 11:31 - 11:37  (00:05)
root   pts/1   10.1.8.1  Wed Nov 9 10:06  still logged in
xkw    pts/0   10.1.8.1  Wed Nov 9 08:50 - 11:31  (02:40)
reboot  system boot  3.10.0-1160.el7.  Wed Nov 9 08:45 - 11:51  (03:05)
...
wtmp begins Thu Nov 3 09:42:18 2022
```

`last` 读 `/var/log/wtmp` 文件：

```bash
[xkw@centos7 ~]$ last -n 5         # 只看 5 条
[xkw@centos7 ~]$ last xkw          # 只看 xkw
[xkw@centos7 ~]$ last -F           # 完整时间
[xkw@centos7 ~]$ last reboot       # 看重启记录
```

---

## §16 nice 启动时设优先级

### 16.1 nice 是什么

```
进程优先级（CPU 调度顺序）：
  -20  ← 最高（最先被调度）
    0  ← 普通（默认值）
   19  ← 最低（最后被调度）

nice 值 = 偏移量
  nice -20 = "-20 没礼貌" = 最应该多跑 = 高优先级
  nice  19 = "+19 有礼貌" = 让出 CPU = 低优先级

谁能设？
  普通用户：只能往上加（0 ~ 19）= 只能降低自己优先级
  root    ：能往下降（-20 ~ 19）= 可以提高优先级
```

### 16.2 不带参数：查自己 nice

```bash
[xkw@centos7 ~]$ nice
0
```

### 16.3 带命令：启动时设 nice

```bash
# 默认 +10
[xkw@centos7 ~]$ nice md5sum /dev/zero &
[1] 55742

[xkw@centos7 ~]$ ps -o pid,nice,command
  PID  NI COMMAND
52751   0 -bash
55742  10 md5sum /dev/zero       # ← NI = 10
55773   0 ps -o pid,nice,command

# 显式指定 +2
[xkw@centos7 ~]$ nice -n 2 md5sum /dev/zero &
[3] 55785

[xkw@centos7 ~]$ ps -o pid,nice,command 55785
  PID  NI COMMAND
55785   2 md5sum /dev/zero       # ← NI = 2

# 普通用户想设负值（提高优先级）→ 失败
[xkw@centos7 ~]$ nice -n -2 md5sum /dev/zero &
[2] 55782
[xkw@centos7 ~]$ nice: cannot set niceness: Permission denied
# ↑ NI 还是 0，没生效
```

### 16.4 systemd 是 nice 0

```bash
[xkw@centos7 ~]$ ps -o nice,cmd $(pgrep systemd)
 NI CMD
  0 /usr/lib/systemd/systemd --switched-root --system --deserialize 22
  0 /usr/lib/systemd/systemd-journald
  0 /usr/lib/systemd/systemd-udevd
  0 /usr/lib/systemd/systemd-logind
```

> 默认所有用户进程都是 nice 0。

---

## §17 renice 运行时改优先级

### 17.1 renice 语法

```bash
renice -n <priority> -p <pid>...        # 按 PID（默认）
renice -n <priority> -g <pgid>...       # 按进程组
renice -n <priority> -u <user>...       # 按用户
```

### 17.2 按 PID

```bash
# 把 PID 55782 的 nice 改成 2
[xkw@centos7 ~]$ renice -n 2 55782
55782 (process ID) old priority 0, new priority 2

# 想改成 -2（提权）→ 失败
[xkw@centos7 ~]$ renice -n -2 55782
renice: failed to set priority for 55782 (process ID): Permission denied

# root 可以
[root@centos7 ~]# renice -n -2 55782
55782 (process ID) old priority 2, new priority -2

[root@centos7 ~]# ps -o pid,nice,command 55782 55785
  PID  NI COMMAND
55782  -2 md5sum /dev/zero       # ← 提高了！
55785  -2 md5sum /dev/zero
```

### 17.3 按用户

```bash
# 把 xkw 所有进程 nice 改成 +5
[root@centos7 ~]# renice -n 5 -u xkw
```

### 17.4 按进程组

```bash
# 把进程组 1234 所有进程 nice 改成 +10
[xkw@centos7 ~]# renice -n 10 -g 1234
```

### 17.5 top 里按 r 改

```bash
top
> r
PID to renice [default pid = 2596]:
Renice PID 2596 to value: -5
# ↑ 直接在 top 里改（root 才能改负值）
```

> ⚠️ **top 里 r 也是调 renice**。普通用户只能往上加。

---

## §18 chrt 实时调度策略

### 18.1 五种调度策略

```
普通（分时）调度：
  SCHED_OTHER (SCHED_NORMAL)  99% 的进程
  SCHED_BATCH                 批量任务（编译）
  SCHED_IDLE                  空闲才跑

实时调度（高优先级 → 内核承诺尽快调度）：
  SCHED_FIFO    先入先出，跑完才让出（不能被其他 SCHED_OTHER 抢占）
  SCHED_RR      时间片轮转（round-robin）
  SCHED_DEADLINE 截止时间调度（红内核用得多）
```

### 18.2 chrt -m 看范围

```bash
[root@centos7 ~]# chrt -m
SCHED_OTHER min/max priority  : 0/0
SCHED_FIFO min/max priority   : 1/99   # ← 比 nice 范围大
SCHED_RR min/max priority     : 1/99
SCHED_BATCH min/max priority  : 0/0
SCHED_IDLE min/max priority   : 0/0
SCHED_DEADLINE min/max priority : 0/0
```

### 18.3 启动时设置实时策略

```bash
# SCHED_RR，优先级 5，跑 md5sum
[root@centos7 ~]# chrt -r 5 md5sum /dev/zero &
[1] 56225

[root@centos7 ~]# ps -o pid,cls,rtprio,command 56225
  PID CLS RTPRIO COMMAND
56225 RR      5 md5sum /dev/zero
#            ↑     ↑
#         实时策略 时间片优先级（1-99）
```

> CLS 列：`TS` = SCHED_OTHER；`FF` = SCHED_FIFO；`RR` = SCHED_RR。

### 18.4 改运行中进程的策略

```bash
# 改 SCHED_FIFO，优先级 10
[root@centos7 ~]# chrt -f --pid 10 56225
[root@centos7 ~]# ps -o pid,cls,rtprio,command 56225
  PID CLS RTPRIO COMMAND
56225 FF     10 md5sum /dev/zero    # ← FF 了！

# 改回 SCHED_OTHER
[root@centos7 ~]# chrt -o --pid 0 56225
[root@centos7 ~]# ps -o pid,cls,rtprio,command 56225
  PID CLS RTPRIO COMMAND
56225 TS      - md5sum /dev/zero    # ← TS = 普通
```

### 18.5 普通用户用 chrt？

```bash
[xkw@centos7 ~]$ chrt -f -p 10 56225
chrt: failed to set pid 56225's policy: Operation not permitted

# 只有 root 能用实时调度
# 防止普通用户用实时策略把系统整崩
```

### 18.6 内核实时上限（sysctl）

```
实时进程会"霸占" CPU，普通进程没分。
内核默认限制：99% 时间给实时，1% 给普通。
参数：/proc/sys/kernel/sched_rt_runtime_us（默认 950000）
     /proc/sys/kernel/sched_rt_period_us（默认 1000000）
```

---

## §19 top 里改优先级（r）

```bash
top
> r          # ← 输入 r 命令
PID to renice [default pid = 2596]:
2596
Renice PID 2596 to value: -5
# top 会自动调 renice
# 普通用户 r 也只能往上加

# 退出：q
```

---

## §20 系统负载 load average 三数字解读

### 20.1 是什么

```
uptime / w / top 都会显示：
load average: 1.02, 0.28, 0.13

三个数字分别是：
  1 分钟内 / 5 分钟内 / 15 分钟内 的负载平均值
```

### 20.2 负载 = 多少个任务在"等"

```
load = 当前活跃任务数（可运行 + 不可中断睡眠）

假设 CPU 核心数 = 4：
  load = 0.0   → 啥都没跑
  load = 1.0   → 1 个任务在用 CPU（其实空闲 3 核）
  load = 4.0   → 满载（每核 1 个）
  load = 8.0   → 排队中，平均每核 2 个
```

> ⚠️ **负载 > CPU 核数 = 排队，不是崩溃**，但响应会变慢。

### 20.3 怎么算"健康"

```
规则 1：load < CPU 核数 = 健康
规则 2：load ≈ CPU 核数 = 临界
规则 3：load > CPU 核数 = 过载

怎么知道 CPU 核数？
lscpu | grep "^CPU(s):"
# CPU(s):             2
nproc
# 2
```

### 20.4 三数字怎么看

```
load average: 0.50, 1.20, 2.00

1 分钟低 + 5 分中 + 15 分钟高 → 负载在上升
1 分钟高 + 5 分中 + 15 分钟低 → 负载在下降（尖刺）

稳定判断：看 15 分钟那个
```

### 20.5 实验：让负载飙升

```bash
# 1) 先看基准
[xkw@centos7 ~]$ uptime
13:47:10 up 5:01, 2 users, load average: 0.00, 0.01, 0.05

# 2) 启动 30 秒的满载
[xkw@centos7 ~]$ md5sum /dev/zero &
[xkw@centos7 ~]$ md5sum /dev/zero &

# 3) 再看（升高了）
[xkw@centos7 ~]$ uptime
13:48:57 up 5:03, 2 users, load average: 1.02, 0.28, 0.13
# ↑ 1 分项从 0.00 → 1.02（尖峰）
#   5 分项从 0.01 → 0.28（还在涨）
#   15 分项从 0.05 → 0.13（开始涨）
```

### 20.6 为什么会"过载但没崩溃"

```
load = 10 不代表系统挂了，只代表队列长
任务"慢"完成 = 排队效应（银行窗口理论）

4 核跑 4 个 md5sum：
  load = 4 → 每核满载 → 快

4 核跑 10 个 md5sum：
  load = 10 → 排队 → 但都能跑完（慢一点）
```

---

## §21 uptime / w 的负载

```bash
[xkw@centos7 ~]$ uptime
 15:04:35 up 6:08, 2 users, load average: 0.00, 0.02, 0.02

[xkw@centos7 ~]$ w
 15:04:35 up 6:08, 4 users, load average: 0.00, 0.02, 0.02
```

`uptime` = `w` 的第一行 + 系统启动时长 + 用户数 + load average。

> 💡 启动时长 = 重启到现在多久。可以拿这个判断"上次崩溃时间"。

---

## §22 stress 压测：CPU / 内存 / IO

### 22.1 安装

```bash
[root@centos7 ~]# yum install -y stress
```

### 22.2 stress 参数

```bash
[root@centos7 ~]# stress --help

-?, --help         帮助
-v, --verbose      详细
-q, --quiet        安静
-n, --dry-run      空跑
-t, --timeout N    跑 N 秒自动停
   --backoff N     启动前等 N 微秒
-c, --cpu N        跑 N 个 sqrt 进程（吃 CPU）
-i, --io N         跑 N 个 sync 进程（吃 IO）
-m, --vm N         跑 N 个 malloc/free（吃内存）
   --vm-bytes B    每个 vm worker 用 B 字节（默认 256M）
   --vm-stride B   每 B 字节写一次（默认 4096）
   --vm-hang N     分配后挂 N 秒再释放（默认 0 = 永远挂着）
   --vm-keep       脏页保留不释放
-d, --hdd N        跑 N 个 write/unlink（吃磁盘）
   --hdd-bytes B   每个 hdd worker 写 B 字节（默认 1G）

# 数字后缀：时间 s/m/h/d/y，大小 B/K/M/G

Example:
stress --cpu 8 --io 4 --vm 2 --vm-bytes 128M --timeout 10s
```

### 22.3 实战：跑满 2 个 CPU

```bash
[root@centos7 ~ 14:17:19]# stress -c 2
stress: info: [2595] dispatching hogs: 2 cpu, 0 io, 0 vm, 0 hdd

# 旁边窗口看 top
[root@centos7 ~ 14:18:22]# top
top - 14:18:22 up 47 min,  2 users,  load average: 1.37, 0.50, 0.47
Tasks: 187 total,   4 running, 183 sleeping,   0 stopped,   0 zombie
%Cpu(s):100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
# ↑ us 100%，id 0% = CPU 跑满

KiB Mem : 4026124 total, ...

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM     TIME+ COMMAND
 2596 root      20   0  7312  100     0 R 100.0  0.0   1:01.42 stress
 2597 root      20   0  7312  100     0 R 100.0  0.0   1:01.25 stress
 2594 root      20   0  162100  2320  1588 R  0.6  0.1   0:00.12 top
```

### 22.4 实战：吃 1G 内存

```bash
[root@centos7 ~ 14:19:11]# stress -m 1 --vm-bytes 1G
stress: info: [2623] dispatching hogs: 0 cpu, 0 io, 1 vm, 0 hdd

# 旁边窗口看 free
[root@centos7 ~ 14:21:44]# free -m
              total        used        free      shared  buff/cache   available
Mem:           3931        1403         575          14        1952        2274
# used 从 478M → 1403M（多吃了 1G）
Swap:          3967           0        3967
```

### 22.5 实战：吃 IO

```bash
[root@centos7 ~ 14:22:21]# stress -d 1 --hdd-bytes 2G

# 旁边窗口看 sar -dp（磁盘 IO）
[root@centos7 ~ 14:23:31]# sar -dp 1
14 23 29     DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz   await  svctm  %util
14 23 30     sda    2699.00     0.00 2762752.00   1023.62      6.11    2.26    0.29   79.50
# ↑ sda 写入 2.7MB/s，%util 79.5%（磁盘满载）

14 23 30     sr0       0.00     0.00      0.00      0.00      0.00    0.00    0.00    0.00
14 23 30     centos-root  2698.00  0.00 2761728.00  1023.62   6.11    2.26    0.29   79.50
# centos-root 是 sda 上的 LVM 分区
```

### 22.6 实战：吃网络（测带宽）

```bash
# 下个 CentOS ISO
[root@centos7 ~ 14:27:17]# wget http://192.168.43.100/isos/CentOS-7-x86_64-DVD-2207-02.iso

# 看网卡流量
[root@centos7 ~ 14:29:13]# sar -n DEV 1
14 29 07       IFACE   rxpck/s  txpck/s  rxkB/s    txkB/s   rxcmp/s  txcmp/s  rxmcst/s
14 29 08       ens32  69961.00  5404.00 96338.71  513.95    0.00     0.00     0.00
# ↑ ens32 收 96MB/s = 千兆网卡跑满
14 29 08       lo       0.00     0.00      0.00     0.00     0.00     0.00     0.00
14 29 08       virbr0-nic  0.00  0.00     0.00     0.00     0.00     0.00     0.00
14 29 08       virbr0     0.00     0.00      0.00     0.00     0.00     0.00     0.00
```

> 💡 **面试题**：如何看网卡有没有跑满？答：`sar -n DEV 1` 看 `rxkB/s` / `txkB/s` ≈ 网卡额定带宽。

---

## §23 free 内存监控

### 23.1 free -m

```bash
[xkw@centos7 ~ 14:21:06]# free -m
              total        used        free      shared  buff/cache   available
Mem:           3931         478        1500          14        1952        3201
Swap:          3967           0        3967
```

| 列 | 含义 |
|---|---|
| **total** | 总内存 |
| **used** | 已用（= 进程实际占用）|
| **free** | 完全空闲（这部分马上能用）|
| **shared** | 共享内存（tmpfs 等）|
| **buff/cache** | 内核缓存/缓冲（被吃满不算"被占用"，可随时释放）|
| **available** | 真实可用 ≈ free + buff/cache 可回收部分 |

> 💡 **真正可用内存看 `available` 不是 `free`**！
> 因为 `buff/cache` 内核随时能释放给进程。

### 23.2 实战对比

```bash
# 正常
Mem:  total=3931  used=478   free=1500  buff/cache=1952  available=3201
# ↓
# 跑 stress -m 1 --vm-bytes 1G
Mem:  total=3931  used=1403  free=575   buff/cache=1952  available=2274
# ↑ used +925M（吃了 1G），available 从 3201 → 2274，少了 927M
```

### 23.3 free 的可选项

```bash
free -h         # 人类可读（G/M/K）
free -m         # MB
free -g         # GB
free -s 1       # 每 1 秒刷一次
free -t         # 加一行 total
free -c 3       # 显示 3 次后退出（-s 配合）
```

---

## §24 sar 全能监控

### 24.1 sar 是什么

```
sar = System Activity Reporter（系统活动报告）
sysstat 包提供，可以收集 CPU/内存/IO/网络 等历史数据。
默认每 10 分钟采一次样（cron 里 logsa）。
```

```bash
[root@centos7 ~]# yum install -y sysstat
```

### 24.2 sar -u：CPU

```bash
[root@centos7 ~]# sar -u 1 3
# 1 秒 1 次，采 3 次
```

### 24.3 sar -dp：磁盘 IO

```bash
[root@centos7 ~]# sar -dp 1
# DEV  tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz  await  svctm  %util
# sda  2699  0.00      2762752  1023.62    6.11      2.26   0.29    79.50
#
# %util ≥ 80%  = 磁盘满载
# await > 10ms = 排队长（磁盘慢）
```

### 24.4 sar -n DEV：网卡

```bash
[root@centos7 ~]# sar -n DEV 1
# IFACE  rxpck/s  txpck/s  rxkB/s  txkB/s  ...
# ens32  69961    5404     96338   513
```

### 24.5 sar -r：内存

```bash
[xkw@centos7 ~]$ sar -r 1
# memused  ...  ...
```

### 24.6 sar 历史数据

```bash
# sar 默认每 10 分钟采一次样，存在 /var/log/sa/
ls /var/log/sa
sa01 sa02 ... sar01 sar02 ...

# 看昨天（本月第 1 天）所有 CPU 数据
sar -u -f /var/log/sa/sa01

# 看 5 天前的负载
sar -q -f /var/log/sa/sa05
```

---

## §25 vmstat / iostat 轻量监控

### 25.1 vmstat：虚拟内存 + CPU + IO

```bash
[root@centos7 ~]# vmstat 1 5
# 1 秒 1 次，采 5 次

procs  -----------memory----------  ---swap--  -----io----  -system-- ------cpu-----
 r  b   swpd  free   buff   cache    si  so    bi    bo     in   cs   us sy id wa st
 1  0   0    1535676  0   1999780   0   0     0    0      65  110   0  0  99 0  0
 2  0   0    1535676  0   1999780   0   0     0    0      68  115   0  0 100 0 0
...
```

| 列 | 含义 |
|---|---|
| `r` | 等待运行的进程数（≥ CPU 数 = 排队）|
| `b` | 不可中断睡眠数（IO 阻塞）|
| `swpd` | 虚拟内存已用 |
| `free` | 空闲内存 |
| `buff` / `cache` | 缓冲/缓存 |
| `si` / `so` | swap in / out（高 = 内存紧张）|
| `bi` / `bo` | 块设备 read / write |
| `us` / `sy` / `id` / `wa` / `st` | CPU 时间 |

> 💡 **重点看 `r`（排队）+ `wa`（等 IO）+ `si`/`so`（swap）**。

### 25.2 iostat：磁盘 IO

```bash
[root@centos7 ~]# iostat -dx 1
# -d 磁盘模式，-x 扩展统计，1 = 1 秒 1 次
Device  r/s   w/s   rkB/s  wkB/s  await  %util
sda     2.0   100   100    50000  5.0    80.5
#              ↑
# %util ≥ 70% → 磁盘忙
```

---

## §26 僵尸进程 Z

### 26.1 什么是僵尸

```
僵尸进程 = Zombies（状态 Z）
  子进程退出，但父进程没"收尸"（调用 wait）
  → 子进程变成没人管的 PID，但 PCB 还占着位置（浪费 slot）

特点：
  1. 不能 kill（已经死了，只是占位置）
  2. 不占 CPU 和内存
  3. 但占 PID 数字（PID 是有限的）
  4. 大量 zombie 会耗尽 PID
```

### 26.2 实验：用 C 产生僵尸

```c
// zombies.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main()
{
    pid_t id = fork();
    if (id < 0) {
        perror("fork");
        return 1;
    } else if (id > 0) {
        // parent
        printf("parent[%d] is sleeping ...\n", getpid());
        sleep(60);              // ← 父进程睡 60 秒不管子进程
    } else {
        // child
        printf("child[%d] is begin Z ...\n", getpid());
        sleep(10);              // ← 子进程睡 10 秒后退出
        exit(EXIT_SUCCESS);
    }
    return 0;
}
```

```bash
# 编译
[root@centos7 ~]# yum install -y gcc
[root@centos7 ~]# gcc zombies.c -o zombies
[root@centos7 ~]# chmod +x zombies
[root@centos7 ~]# ./zombies
parent[1703] is sleeping ...
child[1704] is begin Z ...

# 循环观察
[root@centos7 ~]# while true; do ps -C zombies u; sleep 1; echo; done
USER  PID  %CPU %MEM  VSZ RSS TTY STAT START TIME COMMAND
root  1703  0.0  0.0  4216 356 pts/1 S+ 00:07 0:00 ./zombies   # ← 父进程 S+
root  1704  0.0  0.0   0   0  pts/1 S+ 00:07 0:00 ./zombies   # ← 子进程在睡

# 10 秒后子进程退出，变成僵尸
USER  PID  %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
root  1703  0.0  0.0 4216 356 pts/1 S+ 00:07 0:00 ./zombies
root  1704  0.0       0 0     pts/1 Z+ 00:07 0:00 [zombies] <defunct>
#                                          ↑                       ↑
#                                          Z                       defunct
```

### 26.3 怎么处理

```bash
# 方法 1：杀掉父进程（孤儿化 → systemd 收养 → 收尸）
[root@centos7 ~]# kill 1703
# → 1704 被 init/systemd 收养，立即被回收

# 方法 2：父进程自己写个 signal handler 处理 SIGCHLD
# （开发角度）

# 方法 3：重启父进程
```

> ⚠️ **kill 僵尸本身没用！** 因为它已经死了，要 kill 它的**父进程**。

### 26.4 怎么快速识别

```bash
# 看 STAT 列有 Z
ps axu | grep -v "STAT" | awk '$8 ~ /Z/' {print $0}'

# 一行命令
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/' 
# 输出 PID 列表

# 统计数量
ps -eo stat | grep -c "^Z"
# 5   ← 当前有 5 个僵尸
```

---

## §27 孤儿进程被 systemd 收养

### 27.1 什么是孤儿

```
孤儿进程 = 父进程先于子进程退出
  → 子进程的 PPID 变成 1（systemd/init）
  → 由 systemd 接管（回收 zombie、清理资源）
```

### 27.2 实验：用 C 产生孤儿

```c
// lonely.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main()
{
    pid_t id = fork();
    if (id < 0) {
        perror("fork");
        return 1;
    } else if (id == 0) {
        // 注释掉父进程逻辑 → 这是子进程
        // printf("parent[%d] is sleeping ...\n", getpid());
        printf("I am child, pid:%d\n", getpid());
        sleep(60);
    } else {
        // 父进程逻辑 → 这是父进程
        printf("I am parent, pid:%d\n", getpid());
        sleep(3);
    }
    return 0;
}
```

```bash
[root@centos7 ~]# gcc lonely.c -o lonely
[root@centos7 ~]# ./lonely
I am parent,pid:1882
I am child, pid:1883

# 观察（30s 后父进程退出，3s 后子进程变成孤儿）
[root@centos7 ~]# while true; do ps -fC lonely; sleep 1; echo; done
UID    PID  PPID C STIME TTY      TIME CMD
root   1882 1223 0 00:14 pts/1   00:00:00 ./lonely    # ← 父进程 PPID=1223
root   1883 1882 0 00:14 pts/1   00:00:00 ./lonely    # ← 子进程 PPID=1882

# 父进程退出后
UID    PID  PPID C STIME TTY      TIME CMD
root   1883    1 0 00:14 pts/1   00:00:00 ./lonely    # ← PPID 变成 1（systemd）
```

> **PID 1882 没了，子进程被 systemd 收养**。

### 27.3 systemd 收养的实际作用

```
孤儿不会变成僵尸，因为 systemd 会自动调用 wait() 收尸。
所以一般不需要人工处理孤儿进程。
```

### 27.4 kill / pkill 处理

```bash
# 杀孤儿
pkill lonely
kill 1883
# 都可以
```

---

## §28 速查表

### 28.1 ps

```bash
ps -e                # 简表所有
ps -ef               # 完整所有
ps aux               # BSD 风格（最常用）
ps axf               # 进程树
ps axo pid,%cpu,cmd  # 自定义字段
ps -u xkw            # 按用户
ps -t pts/1          # 按终端
ps -C nginx          # 按命令名
ps --sort=-%cpu      # 按 CPU 降序
ps --sort=%mem       # 按内存升序
ps -ejH              # 层级
ps --forest          # ASCII 树
ps jf                # 加 j 字段（PGID/SID）

# pstree 更直观
pstree
pstree -p            # 显示 PID
pstree xkw           # 只看 xkw
```

### 28.2 top / htop

```bash
top                  # 实时监控（交互）
top -bn1             # 一次批模式
top -bn3 -d 1        # 跑 3 次，每次 1 秒

# top 内键
k <pid>              # 输入信号号 → kill
r <pid>              # 改 nice
P M T 1 c u f        # 排序/展开
q                    # 退出
```

### 28.3 信号

```bash
kill -l              # 列 64 个信号
kill <pid>           # SIGTERM（默认）
kill -9 <pid>        # SIGKILL（强制）
kill -SIGTERM <pid>  # 同上
kill -19 <pid>       # SIGSTOP（暂停）
kill -18 <pid>       # SIGCONT（继续）

# Ctrl+Z = SIGTSTP = -20
# Ctrl+C = SIGINT = -2
```

### 28.4 前后台

```bash
&                   # 启动后台
jobs                # 看后台
fg %1               # 调到前台
bg %1               # 后台继续
Ctrl+Z              # 前台 → 暂停
Ctrl+C              # 终止前台
nohup cmd &         # 脱离终端
screen              # 长会话
screen -ls          # 列会话
screen -r <id>      # 重连
screen -X -S <id> quit  # 杀会话
```

### 28.5 pkill / pgrep

```bash
pgrep sleep                    # 找 PID
pgrep -l sleep                 # 找 PID + 名字
pgrep -u xkw                   # 按用户
pgrep -t pts/0                 # 按终端
pgrep -P 1234                  # 按父 PID
pkill sleep                    # 按名字杀
pkill -u xkw                   # 按用户杀（踢下线！）
pkill -t pts/0                 # 按终端杀
pkill -P 1234                  # 按父 PID 杀子进程
```

### 28.6 nice / renice / chrt

```bash
nice                           # 看自己 nice
nice cmd                       # 启动（默认 +10）
nice -n 5 cmd                  # 启动 nice +5
renice -n 5 -p <pid>           # 改运行中（普通用户只能 ≥ 0）
renice -n -5 -u xkw            # 改 xkw 所有（root 才能 < 0）
chrt -m                        # 看策略范围
chrt -r 10 cmd                 # SCHED_RR，优先级 10
chrt -f --pid 10 <pid>         # 改 SCHED_FIFO
chrt -o --pid 0 <pid>          # 改 SCHED_OTHER
```

### 28.7 负载 / 监控

```bash
uptime                         # 负载 + 启动时间
w                              # uptime + 谁在线
top                            # 实时监控
free -m                        # 内存
vmstat 1                       # 虚拟内存 + IO
iostat -dx 1                   # 磁盘 IO
sar -u 1                       # CPU
sar -r 1                       # 内存
sar -dp 1                      # 磁盘
sar -n DEV 1                   # 网络
nproc                          # CPU 核数
lscpu                          # CPU 详情
stress -c 2                    # 压 CPU
stress -m 1 --vm-bytes 1G      # 压内存
stress -d 1 --hdd-bytes 2G     # 压 IO
```

---

## §29 易错点 ×12

### 1. ❌ ps -aux 写法歧义

```bash
# -aux 实际是 BSD aux + UNIX -U user
# 行为不确定（不同 ps 版本可能解释不同）
# 推荐：单独写 ps aux（BSD）或 ps -ef（UNIX）
```

### 2. ❌ kill -9 杀僵尸

```bash
# Zombie 已死，kill -9 无效
# 要杀它的父进程
```

### 3. ❌ Ctrl+C 杀后台

```bash
sleep 100 &
# Ctrl+C 没用！Ctrl+C 只对前台进程起作用
# 用 kill $!
```

### 4. ❌ 后台进程因 SIGHUP 死

```bash
# SSH 断开时，shell 退出 → 给所有子进程发 SIGHUP
# 用 nohup 或 setsid 或 disown
```

### 5. ❌ Ctrl+Z 暂停的任务忘了 bg

```bash
yum install httpd
^Z                # 暂停了
# 忘了 bg，任务卡死
# 解：bg %1
```

### 6. ❌ nice 普通用户 -n -5

```bash
[xkw@centos7 ~]$ nice -n -5 cmd
nice: cannot set niceness: Permission denied
# 普通用户只能加大 nice（降低优先级）
```

### 7. ❌ 看 load 1.5 觉得"没事"

```bash
# 单核 CPU 1.5 = 过载 50%
# 多核要 nproc 后对比
# load 1.5, nproc=4 = 健康
# load 1.5, nproc=1 = 完蛋
```

### 8. ❌ free 看 free 不用 available

```bash
# buff/cache 是会被回收的（不算"不可用"）
# available 才是真正可以分配给新进程的
free -m | awk '$1 == "Mem:" {print $7}'  # available 不是 $4！
```

### 9. ❌ top -b 直接输给别处不带 -n1

```bash
top > top.log     # 进入交互模式（永远不退出）
# 解：top -bn 1 > top.log  # 跑 1 次退出
```

### 10. ❌ stress 没设超时

```bash
stress -c 2       # 默认无限跑
# 终端关掉才能停（除非用 -t 30s）
```

### 11. ❌ pkill 杀自己的 bash

```bash
[xkw@centos7 ~]$ pgrep -t pts/0
3555 bash           # ← pts/0 是当前终端
[xkw@centos7 ~]$ pkill -t pts/0  # 杀 bash = 断开连接！
```

### 12. ❌ kill -9 数据库

```bash
# MySQL kill -9 = 数据损坏（来不及刷盘）
# 先 kill -15 等 30s → 再 kill -9
kill <mysql_pid>   # SIGTERM
sleep 30
kill -9 <mysql_pid>  # 最后手段
```

---

## §30 面试 6 大追问

### Q1：进程和线程的区别？

**答**：

| | 进程 | 线程 |
|---|---|---|
| 资源 | 独立的地址空间 | 共享进程的资源 |
| 创建 | fork() / exec() | pthread_create() |
| 切换 | 慢（切换页表）| 快（共享页表）|
| 通信 | IPC（管道/信号/共享内存）| 直接共享内存 |
| 崩溃 | 不影响其他进程 | 把整个进程搞崩 |

> Linux 里线程本质上是**轻量级进程**（LWP），`ps -L` 能看线程。

### Q2：kill -9 和 kill -15 区别？

**答**：
- `-15` SIGTERM = 优雅退，进程可以 cleanup（关文件、释放锁）
- `-9` SIGKILL = 强制退，**不能 catch/ignore**
- 原则：先 `-15`，等 N 秒，没响应再 `-9`

### Q3：load average 多大算高？

**答**：
- **< CPU 核数**：健康
- **≈ CPU 核数**：临界
- **> CPU 核数**：有排队，响应变慢
- 几十倍：严重过载或进程死循环

> ⚠️ 不是说 > 1 就有问题，要看 nproc。

### Q4：僵尸进程怎么产生的？怎么清理？

**答**：
- **产生**：子进程 `exit()` 后，PCB 还占着位置，等父进程 `wait()`
- **不清理会怎样**：Zombie 占 PID，PID 用尽后系统无法启动新进程
- **清理方法**：
  1. 杀父进程（孤儿化，systemd 收养并 wait）
  2. 父进程写 SIGCHLD handler（开发角度）
  3. 杀父进程所在进程组

### Q5：nice 和 chrt 的关系？

**答**：

| | nice | chrt |
|---|---|---|
| 调度器 | SCHED_OTHER（普通）| SCHED_RR/FIFO/DEADLINE（实时）|
| 范围 | -20 ~ 19 | 1 ~ 99 |
| 谁能用 | 普通用户仅 ≥ 0 | 只有 root |
| 谁优先 | 普通进程之间比 | 实时进程绝对压制普通 |

> nice 是"礼貌等级"，chrt 是"硬实时通道"。

### Q6：top 里 %CPU 怎么算的？

**答**：
- 单 CPU：100% 满载
- 多 CPU：N * 100% 满载（如 4 核 = 400%）
- 100.0 us 表示**一个 CPU 跑满**
- 按 `1` 看每个核，每个核 100% 才是满

---

## §31 链路

| 笔记 | 关系 |
|---|---|
| [[LinuxShell/shell#§18 第一个 Shell 脚本]] | 进程是 shell 脚本的运行时 |
| [[LinuxShell/shell#§10 算术 7 武器]] | nice 19 = 优先级最低 |
| [[Linux用户权限/user-permission]] | 普通用户 nice 范围受限（root 才能 < 0）|
| [[Linux包管理/package]] | yum install stress / sysstat |
| [[Linux计划任务/cron]] | cron 任务也都是进程 |
| [[Linux文本处理/grep]] | `ps aux | grep xxx` 是经典套路 |
| [[Linux文本处理/awk]] | `ps aux | awk '{print $2}'` 取 PID |

### 进程与负载全景图

```
                     ┌────────────────────────────────────┐
                     │         Linux Kernel               │
                     │   ┌─────────────────────────┐      │
                     │   │  Scheduler (CFS/RT)     │      │
                     │   │  - SCHED_OTHER (nice)    │      │
                     │   │  - SCHED_RR / SCHED_FIFO│      │
                     │   └─────────────────────────┘      │
                     └────────────────┬───────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ↓                       ↓                       ↓
        ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
        │  User Space  │       │  Kernel Space │       │  Init (PID 1)│
        │  Processes   │       │  Threads       │       │  systemd     │
        │              │       │  (kthreadd)    │       │  (orphan收养) │
        └──────────────┘       └──────────────┘       └──────────────┘
              │                       │
              ↓                       ↓
         ┌────────────────────────────────────┐
         │  /proc filesystem                  │
         │  - /proc/[pid]/cmdline             │
         │  - /proc/[pid]/fd/                 │
         │  - /proc/loadavg                   │
         └────────────────────────────────────┘
              │
              ↓
         ┌────────────────────────────────────┐
         │  Performance Tools                 │
         │  - ps / top / htop / pstree        │
         │  - kill / pkill / pgrep            │
         │  - nice / renice / chrt            │
         │  - free / vmstat / iostat / sar    │
         │  - stress                          │
         └────────────────────────────────────┘
```

**下一步**：完成 Linux进程与负载 后可以选择：
- 🎯 **第 2 波 ②** [[Linux服务与SSH/]]（05.14+15 共 2 PDF）—— systemd unit + sshd 配置
- 🎯 **第 3 波 ①** [[Linux日志与时间/]]（05.16+17 共 2 PDF）—— rsyslog + journalctl + chrony
- 🎯 **第 3 波 ②** [[Linux文件传输/]]（05.19+20 共 2 PDF）—— scp/rsync/nfs
