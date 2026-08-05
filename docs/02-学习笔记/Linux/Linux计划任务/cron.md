---
title: Linux 计划任务 — cron / at / anacron
desc: 基于 06.CentOS-7-系统管理-2/2. Linux 计划任务管理.pdf 的实操笔记。覆盖 crontab 用户级/系统级、crond、/etc/cron.d/、anacrontab、at 一次性任务、at 黑白名单。
type: 笔记
module: Linux计划任务
pdf: 06.2 Linux 计划任务管理.pdf
pdf_size: 338 KB / 426 行
scope: CentOS-7 (cronie + at)
status: 完成
---

# Linux 计划任务 — cron / at / anacron

> **范围**：基于《CentOS-7 系统管理 2》PDF 2 整理。覆盖 **cron**（周期）+ **at**（一次）+ **anacron**（补偿）三大任务调度器。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：计划任务 = 闹钟叫 Linux 干活]]
- [[#§1 cron vs at vs anacron 三选一]]
- [[#§2 crontab 用户级：crontab -e / -l / -r]]
- [[#§3 crontab 时间格式：5 字段详解]]
- [[#§4 crontab 特殊字符：* / , -]]
- [[#§5 crontab 环境变量]]
- [[#§6 crontab 实战：每 2 分钟 date]]
- [[#§7 crontab -u：root 给别人加任务]]
- [[#§8 crontab 文件名：从文件加载]]
- [[#§9 crond 系统级：/etc/crontab]]
- [[#§10 /etc/cron.d/ 子目录]]
- [[#§11 /etc/cron.{hourly,daily,weekly,monthly}]]
- [[#§12 anacrontab：关机补偿]]
- [[#§13 at 一次性任务]]
- [[#§14 at 时间格式（timespec）]]
- [[#§15 at 命令：atq / atrm / at -c]]
- [[#§16 at 黑白名单：/etc/at.allow /etc/at.deny]]
- [[#§17 实战：3 个 cron + 2 个 at 综合案例]]
- [[#§18 速查表]]
- [[#§19 易错点 ×12]]
- [[#§20 面试 5 大追问]]
- [[#§21 链路]]

---

## §0 心智模型：计划任务 = 闹钟叫 Linux 干活

```
场景：你每天 9 点要上班
闹钟：每天 9:00 响 → 叫你起床
计划任务：每天 9:00 执行某个命令

Linux 计划任务 = 自动运行的"闹钟"

三种闹钟：
  cron  = 周期任务（每天 9 点）
  at    = 一次性任务（明天下午 3 点提醒我）
  anacron = 漏掉的闹钟补响（昨晚关机，今天补跑）
```

**核心三角色**：
- **cron**：周期调度器，守护进程叫 `crond`
- **at**：一次性调度器，守护进程叫 `atd`
- **anacron**：补偿器，关机期间错过的任务"补回来"

---

## §1 cron vs at vs anacron 三选一

| 工具 | 类型 | 适合场景 | 最小时间粒度 | 关机补偿 |
|---|---|---|---|---|
| **cron** | 周期任务 | 每天/每周/每月重复 | **1 分钟** | ❌ |
| **at** | 一次性任务 | 未来某一刻跑一次 | **1 分钟** | ❌ |
| **anacron** | 补偿任务 | 笔记本/家用机不关机不跑 | **1 天** | ✅ |

> 💡 **服务器**用 cron，**桌面**用 anacron 补偿，**临时提醒**用 at。

---

## §2 crontab 用户级：crontab -e / -l / -r

### 2.1 三个核心选项

```bash
# 1) 编辑当前用户的 crontab
[laoma@centos7 ~]$ crontab -e
# 第一次打开默认是 vi
# 建议先设 EDITOR
[laoma@centos7 ~]$ export EDITOR=vim

# 2) 查看当前用户的 crontab
[laoma@centos7 ~]$ crontab -l
*/2 2,3-23 * * * date >> /tmp/date.log

# 3) 删除当前用户的 crontab（⚠️ 整删）
[laoma@centos7 ~]$ crontab -r
[laoma@centos7 ~]$ crontab -l
no crontab for laoma
```

> ⚠️ **`crontab -r` 是删全部！** 没有"删一行"的功能，要删只能 `crontab -e` 进去手动改。

### 2.2 root 专属：crontab -u

```bash
# root 可以给别人设任务
[root@centos7 ~]# crontab -u laoma -e
0 9 2 2 * /usr/local/bin/yearly_backup
0 9 * * 1-5 mutt -s "Checking in" boss@example.com % Hi boss, just checking in.

# 也可以删
[root@centos7 ~]# crontab -u laoma -r
[root@centos7 ~]# crontab -u laoma -l
no crontab for laoma
```

---

## §3 crontab 时间格式：5 字段详解

```
格式：分 时 日 月 周 命令
     *  *  *  *  *  command
```

| 字段 | 范围 | 说明 |
|---|---|---|
| **分 (minute)** | 0-59 | 每小时的第几分钟 |
| **时 (hour)** | 0-23 | 每天的第几小时（0 = 午夜）|
| **日 (day of month)** | 1-31 | 每月第几天 |
| **月 (month)** | 1-12 | 或 jan,feb,mar,apr... |
| **周 (day of week)** | 0-6 | 0 或 7 = 周日；或 sun,mon,tue... |

```bash
# 经典示例
0 9 2 2 * /usr/local/bin/yearly_backup
# 分=0  时=9  日=2  月=2  周=*
# 含义：每年 2 月 2 日 9:00 整执行

*/5 9-16 * Jul 5 echo "Chime"
# 分=*/5  时=9-16  日=*  月=Jul  周=5
# 含义：7 月每周五 9:00-16:59 每 5 分钟执行一次

58 23 * * 1-5 /usr/local/bin/daily_report
# 分=58  时=23  日=*  月=*  周=1-5
# 含义：每周一到周五 23:58 执行日报

0 9 * * 1-5 mutt -s "Checking in" boss@example.com % Hi boss, just checking in.
# 分=0  时=9  日=*  月=*  周=1-5
# 含义：周一到周五 9:00 发邮件（% 后是邮件正文）
```

> ⚠️ `%` 在 crontab 里是**换行符**，会被替换成 newline。常用于邮件正文。

---

## §4 crontab 特殊字符：* / , -

### 4.1 四种特殊字符

| 字符 | 含义 | 例子 | 解释 |
|---|---|---|---|
| `*` | 每（任意）| `* * * * *` | 每分钟 |
| `/` | 步长 | `*/5` | 每 5 |
| `,` | 多选 | `1,15,30` | 1 分、15 分、30 分 |
| `-` | 范围 | `1-5` | 1 到 5（含两端）|

### 4.2 实战例子

```bash
# 每分钟
* * * * * cmd

# 每 5 分钟
*/5 * * * * cmd

# 1 分、15 分、30 分
1,15,30 * * * * cmd

# 1-5 分钟（含两端）
1-5 * * * * cmd

# 周一到周五 9 点
0 9 * * 1-5 cmd

# 工作时间（9-17 点）每 30 分钟
*/30 9-17 * * * cmd

# 每月 1 号 0 点
0 0 1 * * cmd

# 每周日 3 点
0 3 * * 0 cmd
# 或 0 3 * * 7
```

### 4.4 范围 vs 步长

```bash
# 范围 + 步长
1-30/5 * * * * cmd
# 含义：1-30 分钟里，每 5 分钟
# 实际：1, 6, 11, 16, 21, 26

# 简单步长
*/7 * * * * cmd
# 含义：每 7 分钟
# 实际：0, 7, 14, 21, 28, 35, 42, 49, 56
```

---

## §5 crontab 环境变量

```bash
# crontab 里的环境变量要在文件顶部用 NAME=value 设
[laoma@centos7 ~]$ crontab -e
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
# ↑ 这些必须在任务前定义（不能用 export）

0 9 * * * /usr/local/bin/backup.sh
# ↑ 推荐用绝对路径（PATH 可能不全）
```

| 变量 | 默认值 | 用途 |
|---|---|---|
| `SHELL` | `/bin/sh` | 用什么 shell 执行 |
| `PATH` | `/usr/bin:/bin` | 命令搜索路径 |
| `MAILTO` | 用户名 | 任务输出发给谁 |
| `HOME` | 用户家目录 | 脚本里 `~` 指向 |

> ⚠️ crontab 的环境**和你的 Shell 不一样**！很多命令找不到就是因为 PATH 缺。

---

## §6 crontab 实战：每 2 分钟 date

```bash
# 1) 准备
[laoma@centos7 ~]$ export EDITOR=vim
[laoma@centos7 ~]$ crontab -e

# 2) 编辑（每个奇数分钟跑一次）
*/2 2,3-23 * * * date >> /tmp/date.log
# 或 0-59/2 = 每 2 分钟
# 但 PDF 里写 */2 2,3-23 = 2 点、3-23 点之间每 2 分钟（避开 1 点）

# 3) 保存退出（自动加载）

# 4) 验证
[laoma@centos7 ~]$ crontab -l
*/2 2,3-23 * * * date >> /tmp/date.log

# 5) 看日志（实时追踪）
[laoma@centos7 ~]$ tail -f /tmp/date.log
2025年 07月 09日 星期三 21:02:01 CST
2025年 07月 09日 星期三 21:04:01 CST
...
```

---

## §7 crontab -u：root 给别人加任务

> 已在 §2.2 演示。

```bash
# 给 laoma 加任务
[root@centos7 ~]# crontab -u laoma -e

# 看 laoma 的任务
[root@centos7 ~]# crontab -u laoma -l

# 删 laoma 的任务
[root@centos7 ~]# crontab -u laoma -r
```

> 普通用户**不能** `crontab -u otheruser -e`，会报 `must be privileged`。

---

## §8 crontab 文件名：从文件加载

```bash
# 1) 编辑文件
[laoma@centos7 ~]$ vim mycron
0 9 2 2 * /usr/local/bin/yearly_backup
0 9 * * 1-5 mutt -s "Checking in" boss@example.com % Hi boss, just checking in.

# 2) 加载到 crontab
[laoma@centos7 ~]$ crontab mycron

# 3) 验证
[laoma@centos7 ~]$ crontab -l
0 9 2 2 * /usr/local/bin/yearly_backup
0 9 * * 1-5 mutt -s "Checking in" boss@example.com % Hi boss, just checking in.
```

> 💡 **好处**：可以从 Git 仓库同步 cron 配置；脚本化部署。

---

## §9 crond 系统级：/etc/crontab

```bash
[root@centos7 ~]# cat /etc/crontab
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# For details see man 4 crontabs

# Example of job definition:
# .---------------- minute (0 - 59)
# | .------------- hour (0 - 23)
# | | .---------- day of month (1 - 31)
# | | | .------- month (1 - 12) OR jan,feb,mar,apr ...
# | | | | .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,...
# | | | | |
# * * * * * user-name command to be executed
```

### 9.1 与用户级 crontab 的区别

| 维度 | `crontab -e`（用户）| `/etc/crontab`（系统）|
|---|---|---|
| 编辑命令 | `crontab -e` | `vim /etc/crontab` |
| 语法 | `分 时 日 月 周 命令` | `分 时 日 月 周 用户 命令`（**多一个用户字段**）|
| 谁能编辑 | 各用户自己 | 只有 root |
| 适用 | 个人任务 | 系统任务（如日志轮转、备份）|

```bash
# /etc/crontab 示例：每天 4 点以 root 跑 logrotate
0 4 * * * root /usr/sbin/logrotate /etc/logrotate.conf
#                          ↑ 这里多一个 root
```

---

## §10 /etc/cron.d/ 子目录

```bash
# 看默认配置
[root@centos7 ~]# ls /etc/cron.d
0hourly  raid-check  sysstat

[root@centos7 ~]# cat /etc/cron.d/0hourly
# Run the hourly jobs
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
01 * * * * root run-parts /etc/cron.hourly
# ↑ 每小时 01 分跑 /etc/cron.hourly 目录下所有脚本
```

> 💡 **`/etc/cron.d/`** = 多个"小 crontab"，适合第三方软件放自己的定时任务（如 MySQL、Nginx）。

---

## §11 /etc/cron.{hourly,daily,weekly,monthly}

```bash
# 系统级周期目录
ls /etc/cron.hourly    # 每小时跑
ls /etc/cron.daily     # 每天跑
ls /etc/cron.weekly    # 每周跑
ls /etc/cron.monthly   # 每月跑
```

> 这些目录的脚本**不用 chmod +x**（run-parts 会执行）。  
> 由 **anacron** 调度（见下）。

### 11.1 自定义 daily 任务

```bash
# 把脚本放到 /etc/cron.daily/
cat > /etc/cron.daily/mybackup << 'EOF'
#!/bin/bash
tar czf /backup/home-$(date +%F).tar.gz /home/
EOF
chmod +x /etc/cron.daily/mybackup
# 明天会自动跑（具体时间看 anacrontab）
```

---

## §12 anacrontab：关机补偿

### 12.1 为什么需要 anacron

```
场景：服务器关机了几天，开机后……
  cron：错过的任务**不补**，永远错过
  anacron：开机时检查，**补跑**错过的任务

适合：笔记本、家用机、不常开机的机器
不适合：7x24 服务器（用 cron 即可）
```

### 12.2 /etc/anacrontab 配置

```bash
[root@centos7 ~]# cat /etc/anacrontab
# /etc/anacrontab: configuration file for anacron

SHELL=/bin/sh
PATH=/sbin:/bin:/usr/sbin:/usr/bin

# 任务最大随机延迟（开机后等多久才跑）
RANDOM_DELAY=45

# 任务只在 3-22 点之间跑（避免深夜）
START_HOURS_RANGE=3-22

# 格式：period delay job-id command
1       5       cron.daily        nice run-parts /etc/cron.daily
7       25      cron.weekly       nice run-parts /etc/cron.weekly
@monthly 45     cron.monthly      nice run-parts /etc/cron.monthly
```

| 字段 | 含义 |
|---|---|
| **period** | 周期（天）。`1`=每天，`7`=每周，`@monthly`=每月 |
| **delay** | 开机后等多少分钟才跑（避免开机风暴）|
| **job-id** | 任务标识（写到 /var/spool/anacron/）|
| **command** | 要执行的命令 |

### 12.3 工作原理

```
开机
  ↓
anacron 检查 /var/spool/anacron/cron.daily
  ↓
如果时间戳 > 1 天 → 跑 /etc/cron.daily
  ↓
更新时间戳到当前
```

---

## §13 at 一次性任务

### 13.1 装 + 启 atd

```bash
# atd 默认可能没装
[root@centos7 ~]# yum install at

# 看 atd 状态
[root@centos7 ~]# systemctl status atd
● atd.service - Job spooling tools
   Loaded: loaded (/usr/lib/systemd/system/atd.service; enabled)
   Active: active (running) since Wed 2022-12-21 16:54:08 CST; 3min ago
 Main PID: 1184 (atd)
```

### 13.2 at 基础用法

```bash
# 5 分钟后跑
[root@centos7 ~]# at now +5 minutes
at> echo hello world > /tmp/hello.log
at> <EOT>                        ← Ctrl+D 结束输入
job 1 at Wed Dec 21 17:09:00 2022
```

### 13.3 从文件读

```bash
# 先写脚本
[root@centos7 ~]# vim myscript.sh
#!/bin/bash
date >> /tmp/myscript.log
echo hello myscript >> /tmp/myscript.log

# 5 分钟后跑（-f 从文件读）
[root@centos7 ~]# at now +5 minutes < myscript.sh
job 2 at Wed Dec 21 17:10:00 2022

# 100 分钟后跑（更简洁）
[root@centos7 ~]# at now +100 minutes -f myscript.sh
job 3 at Wed Dec 21 18:46:00 2022
```

### 13.4 at 的退出码

```
atd 退出码 26 = 拒绝（不在白名单 / 黑名单）
```

---

## §14 at 时间格式（timespec）

### 14.1 完整 time spec 表

| 时间 | 含义 |
|---|---|
| `now +5 minutes` | 5 分钟后 |
| `now +5 hours` | 5 小时后 |
| `now +3 days` | 3 天后 |
| `02:00 pm` | 下午 2 点（今天或明天）|
| `15:43` | 下午 3:43 |
| `teatime` | 下午 4 点（英国下午茶时间）|
| `noon` | 中午 12 点 |
| `midnight` | 午夜 0 点 |
| `teatime tomorrow` | 明天下午 4 点 |
| `noon +4 days` | 4 天后中午 12 点 |
| `5 pm August 3 2016` | 2016 年 8 月 3 日下午 5 点 |

> 完整列表：`/usr/share/doc/at/timespec`

---

## §15 at 命令：atq / atrm / at -c

### 15.1 查看任务

```bash
# at -l = atq
[root@centos7 ~]# atq
1 Wed Dec 21 17:09:00 2022 a root
2 Wed Dec 21 17:10:00 2022 a root
3 Wed Dec 21 18:46:00 2022 a root
# ↑ 编号  时间             队列 用户

# 按队列看（默认队列是 a，字母越小越优先）
[root@centos7 ~]# at -l -q b
4 Wed Dec 21 17:11:00 2022 b root
```

### 15.2 看具体任务内容 -c

```bash
[root@centos7 ~]# at -c 3
......
${SHELL:-/bin/sh} << 'marcinDELIMITER4bf95eea'
#!/bin/bash
date >> /tmp/myscript.log
echo hello myscript >> /tmp/myscript.log

marcinDELIMITER4bf95eea
```

### 15.3 删除任务

```bash
# at -d 或 atrm
[root@centos7 ~]# atrm 3
[root@centos7 ~]# atq
# 3 没了
```

### 15.4 队列（-q）

```bash
# 指定队列（默认 a-z，a 优先级最高）
[root@centos7 ~]# at -q b now +5 minutes < myscript.sh
job 4 at Wed Dec 21 17:11:00 2022

# 高优先级队列的任务先跑
```

---

## §16 at 黑白名单：/etc/at.allow / /etc/at.deny

### 16.1 规则

| 文件存在情况 | 规则 |
|---|---|
| `/etc/at.allow` 存在 | 只有 allow 里的用户能用 at |
| 只有 `/etc/at.deny` | deny 里的用户不能用 at（其他都行）|
| 两个都不存在 | 只有 root 能用 at（CentOS-7 默认）|

### 16.2 CentOS-7 默认

```bash
[root@centos7 ~]# ls /etc/at.*
/etc/at.deny
[root@centos7 ~]# cat /etc/at.deny
# 空 → 没有 deny
# 也没有 /etc/at.allow → 只有 root 能用 at
```

### 16.3 实战：允许 laoma 用 at

```bash
# 方法 1：建 /etc/at.allow
[root@centos7 ~]# echo laoma > /etc/at.allow
# 现在只有 root 和 laoma 能用 at

# 方法 2：把 laoma 加到 deny 之外（默认就行）
# 默认 /etc/at.allow 不存在，只有 /etc/at.deny（空）
# → laoma 默认能用

# 验证
[laoma@centos7 ~]$ at now +1 minutes
at> echo hello
at> <EOT>
job 5 at ...
```

---

## §17 实战：3 个 cron + 2 个 at 综合案例

### 17.1 综合场景

```
业务需求：
1. 每 5 分钟检查一次 nginx 进程，挂了就重启（cron）
2. 每天 23:00 备份 /var/log 到 /backup（cron）
3. 每周一 3 点清理 /tmp 下 7 天前的文件（cron）
4. 30 分钟后提醒开会（at 一次性）
5. 今晚 23:00 重启服务器（at 一次性）
```

### 17.2 实现

```bash
# === 1. nginx 守护（cron）===
[laoma@centos7 ~]$ crontab -e
*/5 * * * * systemctl is-active nginx >/dev/null 2>&1 || systemctl restart nginx

# === 2. 每天 23:00 备份日志 ===
[laoma@centos7 ~]$ crontab -e
0 23 * * * tar czf /backup/log-$(date +\%F).tar.gz /var/log/

# === 3. 每周一 3 点清 /tmp ===
0 3 * * 1 find /tmp -type f -mtime +7 -delete

# === 4. 30 分钟后提醒开会（at）===
[root@centos7 ~]# at now +30 minutes
at> echo "【开会提醒】30 分钟到了！" | mail -s "Meeting" laoma@example.com
at> <EOT>

# === 5. 今晚 23:00 重启（at）===
[root@centos7 ~]# at 23:00
at> /sbin/shutdown -r now
at> <EOT>
```

> ⚠️ `date +\%F` 中的 `\` 是为了**转义** `%`（crontab 里 `%` 是换行符）。

---

## §18 速查表

### 18.1 cron 用户级

```bash
crontab -e                       # 编辑
crontab -l                       # 查看
crontab -r                       # 删除（整删）
crontab -u user -e               # root 编辑别人的
crontab 文件名                    # 从文件加载
```

### 18.2 cron 时间格式

```
分 时 日 月 周
*  *  *  *  *   command
*/5 9-17 * * 1-5 command      # 周一-周五 9:00-17:59 每 5 分钟
0 0 1 * * command              # 每月 1 号 0 点
```

### 18.3 系统 cron

```bash
/etc/crontab                    # 系统级（root 编辑）
/etc/cron.d/                    # 第三方软件任务
/etc/cron.hourly/               # 每小时
/etc/cron.daily/                # 每天
/etc/cron.weekly/               # 每周
/etc/cron.monthly/              # 每月
/etc/anacrontab                 # 关机补偿
```

### 18.4 at

```bash
at <time>                       # 一次性任务
at now +5 minutes               # 5 分钟后
at now +5 minutes -f file        # 从文件
at 23:00                        # 今天 23:00
at noon +4 days                 # 4 天后中午

atq                             # 查看
atrm N                          # 删任务 N
at -c N                         # 看任务 N 内容
at -q b                         # 用 b 队列（高优先级）

/etc/at.allow                   # 白名单
/etc/at.deny                    # 黑名单
```

### 18.5 实战命令

```bash
# 看 crond 日志
journalctl -f -u crond

# 看 at 日志
journalctl -f -u atd

# 看 cron 是否运行
systemctl status crond

# 重启 cron
systemctl restart crond
```

---

## §19 易错点 ×12

### 1. ❌ crontab 时间字段顺序错

```bash
# 错
30 9 * * 1 cmd    # 这是周一，不是 9 月 30 日

# 对（5 个字段：分 时 日 月 周）
```

### 2. ❌ 写错日期范围

```bash
# 错（day 字段范围 1-31，写 32 永远不会跑）
* * 32 * * cmd
```

### 3. ❌ 没设 PATH 就跑命令

```bash
# crontab 里默认 PATH=/usr/bin:/bin
0 9 * * * mysql -e "show databases"     # ⚠️ 找不到 mysql

# 解：crontab 顶部加 PATH 或用绝对路径
PATH=/usr/local/mysql/bin:/usr/bin:/bin
0 9 * * * /usr/local/mysql/bin/mysql -e "show databases"
```

### 4. ❌ 输出文件没 >/dev/null 导致邮件爆炸

```bash
# 错：crond 会把 stdout 发邮件给用户
* * * * * echo hello    # 邮件塞满

# 对：丢掉输出
* * * * * echo hello >/dev/null 2>&1
```

### 5. ❌ `%` 忘了转义

```bash
# 错：% 在 crontab 里是换行符
0 9 * * * mail -s "Hi $(date)" user@x.com   # 解析出错

# 对：转义 %
0 9 * * * mail -s "Hi $(date +\%F)" user@x.com
```

### 6. ❌ crontab -r 不小心

```bash
# 没有"删一行"功能，-r = 删全部
crontab -r    # ⚠️ 一秒删光

# 解：先备份
crontab -l > mycron.bak
# 编辑时只动需要改的行
```

### 7. ❌ at 时间格式误写

```bash
# 错（语法错）
at 5pm       # 没空格

# 对
at 5 pm
at 17:00
at "5pm"     # 引号也行
```

### 8. ❌ 临时改了时间字段没测

```bash
# 改了 crontab 后，至少 journalctl 验证一下
crontab -e                       # 改
crontab -l                       # 看
journalctl -u crond -f           # 实时日志
```

### 9. ❌ anacrontab 用错格式

```bash
# 错：写成 cron 格式
0 4 * * * run-parts /etc/cron.daily

# 对：anacrontab 4 字段（period delay job-id command）
1 5 cron.daily nice run-parts /etc/cron.daily
```

### 10. ❌ /etc/cron.daily 脚本没 chmod

```bash
# run-parts 默认只跑 +x 的脚本
chmod +x /etc/cron.daily/mybackup    # 必须！
```

### 11. ❌ MAILTO 没设，输出全给本地用户

```bash
# 没设 MAILTO → 输出发到运行用户（堆积本地邮件）
MAILTO=admin@x.com                  # 集中发到一个人
```

### 12. ❌ cron 跑大量任务导致邮件炸弹

```bash
# 一个错任务每分钟报错 → 60 条/小时邮件
* * * * * /wrong/cmd 2>&1

# 加错误处理
* * * * * /wrong/cmd >/dev/null 2>&1 || true
```

---

## §20 面试 5 大追问

### Q1：cron 和 at 区别？

**答**：
- **cron**：**周期任务**（可重复），最小粒度 1 分钟
- **at**：**一次性任务**，到点跑一次就消失

```bash
# cron 每天 9 点
0 9 * * * /backup.sh

# at 明天下午 3 点（一次性）
at 15:00 tomorrow
```

### Q2：crontab -e 和 /etc/crontab 区别？

**答**：

| 维度 | crontab -e | /etc/crontab |
|---|---|---|
| 谁编辑 | 各用户自己 | 只有 root |
| 语法 | `分 时 日 月 周 命令` | `分 时 日 月 周 用户 命令`（多一列）|
| 适用 | 个人 | 系统 |

### Q3：`/etc/cron.d/0hourly` 跑什么？

**答**：每小时 01 分跑 `run-parts /etc/cron.hourly`，执行 `/etc/cron.hourly/` 下所有脚本。

### Q4：anacron 适合什么场景？

**答**：**不常开机的机器**（笔记本、家用）。
- 服务器（7x24）用 cron 即可，anacron 不必要
- anacron 开机时检查 `/var/spool/anacron/` 时间戳，**补跑**错过的任务

### Q5：crontab 的 `%` 是什么？

**答**：`%` 在 crontab 里是**换行符**，不是字面百分号。
- 常用于邮件：`mutt -s "Hi" a@x.com % body` → 第一行命令，第二行正文
- 字面 `%` 要写 `\%`

---

## §21 链路

| 笔记 | 关系 |
|---|---|
| [[LinuxShell/shell#§5 PATH 详解]] | cron PATH 决定命令是否能找到 |
| [[LinuxShell/shell#§27 Shell 函数]] | crontab 里调函数库 |
| [[LinuxShell/shell#§18 第一个 Shell 脚本]] | crontab 跑脚本要有 +x |
| [[LinuxShell/shell#§10 算术 7 武器]] | 时间字段不用算 |
| [[Linux用户权限/user-permission]] | crontab -u 要 root 权限 |
| [[Linux包管理/package]] | yum install at / cronie |

### 计划任务全景图

```
                ┌────────────────────────────────┐
                │  crond (周期守护进程)           │
                │  atd  (一次性守护进程)          │
                │  anacron (开机补偿)             │
                └────────────┬───────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ↓                    ↓                    ↓
   crontab -e           /etc/crontab         /etc/cron.d/*
   (用户级)              (系统级)              (第三方)
        │                    │                    │
        ↓                    ↓                    ↓
   个人定时              系统定时             应用自带
   (如我的备份)           (如 logrotate)      (如 mysql)
                             │
                             ↓
                    /etc/cron.{hourly,daily,
                                 weekly,monthly}
                             │
                             ↓
                      anacron 调度
```

**下一步**：第 1 波三件套完成！可以选择：
- 🎯 **第 2 波**：[[Linux进程与负载/]]（05.12+13 + 06.3 共 3 PDF）
- 🎯 **第 2 波**：[[Linux服务与SSH/]]（05.14+15 共 2 PDF）