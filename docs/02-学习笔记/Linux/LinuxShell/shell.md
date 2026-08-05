---
title: Shell 基础 — 变量与环境变量
desc: 基于《CentOS-7 系统管理 1》8. Shell 基础.pdf 的实操笔记。覆盖自定义变量、环境变量、PATH、PS1、HISTTIMEFORMAT、profile 加载顺序、命令替换、引号转义、算术运算。
type: 笔记
module: LinuxShell
pdf: 8. Shell 基础.pdf
pdf_size: 245 KB
scope: 仅变量与环境变量篇（PDF 实际范围）
status: 完成
---

# Shell 基础 — 变量与环境变量

> **范围说明**：本笔记严格基于 `8. Shell 基础.pdf` 实际内容，**仅覆盖变量与环境变量**。流程控制（if/for/while）、函数、数组等内容**不在本 PDF 中**，留待后续 PDF 笔记补充。

## 目录

- [[#§0 心智模型：Shell = 翻译官，变量 = 便利贴]]
- [[#§1 自定义变量：var=key 与 $var]]
- [[#§2 变量拼接与 ${} 解决歧义]]
- [[#§3 环境变量：export 让子 Shell 也能看到]]
- [[#§4 常用环境变量速查]]
- [[#§5 PATH 详解：PATH 改坏的救命方法]]
- [[#§6 PS1 提示符定制（颜色 + 时间）]]
- [[#§7 HISTTIMEFORMAT：让 history 显示时间]]
- [[#§8 启动文件加载顺序（login vs nologin）]]
- [[#§9 命令替换：$(cmd) vs 反引号 `cmd`]]
- [[#§10 算术运算：$[1+2] + {1..100}]]
- [[#§11 引号与转义：\ / "" / '']]
- [[#§12 多行 echo + 重定向]]
- [[#§13 速查表]]
- [[#§14 易错点 ×12]]
- [[#§15 面试 6 大追问]]
- [[#§16 与其他笔记的链路]]
- [[#§17 进一步阅读]]

---

## §0 心智模型：Shell = 翻译官，变量 = 便利贴

```
你（人）          Shell（bash）         内核
  |                  |                   |
  |-- "显示日期" --->|                   |
  |                  |--- date --------->|
  |                  |<-- 2025-07-09 ----|
  |<-- 显示出来 ----|                    |
```

**Shell 的角色**：人和 Linux 内核之间的**翻译官**。
你输入人类可读的命令，Shell 帮你转成内核能懂的系统调用；内核返回结果，Shell 再翻译成人能看的文字。

**变量的角色**：Shell 在内存里贴的**便利贴**。
- 写：`var=key` 把"key"贴在叫 var 的便利贴上
- 读：`$var` 让 Shell 把便利贴上的字念出来
- 删：`unset var` 把便利贴撕掉

> 💡 **整个 Shell 基础都在解决 3 件事**：
> 1. **写**变量（赋值、类型）
> 2. **传**变量（环境、子 shell）
> 3. **用**变量（拼接、替换、算术、显示）

---

## §1 自定义变量：var=key 与 $var

### 1.1 基本三连：赋值、引用、删除

```bash
# 1) 赋值（等号两边不能有空格！）
[xkw@centos7 ~]$ var1=key1

# 2) 引用（$ + 变量名）
[xkw@centos7 ~]$ echo $var1
key1

# 3) 查看所有变量
[xkw@centos7 ~]$ set | grep first_name
first_name=facai

# 4) 删除
[xkw@centos7 ~]$ unset var1
[xkw@centos7 ~]$ echo $var1
                        # 输出空行（变量不存在）
```

### 1.2 显式声明（等价但不常用）

```bash
# 显式声明（与 var1=key1 等价）
[xkw@centos7 ~]$ declare var1=key1
```

> 💡 `declare` 主要用于声明**特殊属性**（大小写、数组、只读等），见下节。

### 1.3 declare -l / -u：强制大小写

```bash
# 强制小写
[xkw@centos7 ~]$ declare -l name=James
[xkw@centos7 ~]$ echo $name
james                            # 变成小写

# 强制大写
[xkw@centos7 ~]$ declare -u name=James
[xkw@centos7 ~]$ echo $name
JAMES                            # 变成大写
```

> ⚠️ `declare -l name=James` 改的是**变量内容**的大小写，**不是**变量名本身的。

### 1.4 实战练习（在共享文件夹里）

```bash
# 1) 在共享文件夹建一个测试文件
cd /mnt/hgfs/Linux
touch test.sh

# 2) 给文件路径赋给变量
filepath=/mnt/hgfs/Linux/test.sh
echo "文件在: $filepath"

# 3) 看看变量存不存在
set | grep filepath

# 4) 删掉
unset filepath
echo "现在 filepath 是: '$filepath'"   # 应该是空
```

---

## §2 变量拼接与 ${} 解决歧义

### 2.1 两个变量挨着时遇到的问题

```bash
[xkw@centos7 ~]$ first_name=facai
[xkw@centos7 ~]$ last_name=zhang
[xkw@centos7 ~]$ echo $last_name $first_name
zhang facai                       # 空格分隔，没问题

[xkw@centos7 ~]$ echo $last_name-$first_name
zhang-facai                       # - 是普通字符，没问题

[xkw@centos7 ~]$ echo $last_name_$first_name
facai                             # ⚠️ 出错了！Shell 找的是 last_name_ 这个变量
                                  # 找不到，就把 _ 前的也丢了，只剩 $first_name
```

### 2.2 解决：${} 把变量名框起来

```bash
# 用 ${} 明确边界
[xkw@centos7 ~]$ echo ${last_name}_$first_name
zhang_facai                       # ✓ 正确拼接
```

### 2.3 一图看懂歧义

```
Shell 看到 $last_name_$first_name 后是这样解析的：

  变量 1: $last_name_      ← 想找 last_name_，没找到 → 空
  变量 2: $first_name      ← 找到 facai

结果: "" + "facai" = "facai"  ← 丢了 last_name！

用 ${} 框起来后：
  ${last_name}  +  "_"  +  $first_name
  "zhang"       +  "_"  +  "facai"
  = "zhang_facai"            ← 正确
```

### 2.4 实战：拼接命令行

```bash
# 拼接命令（结合 [[Linux文本处理/输入输出重定向|输入输出重定向]]）
backup_dir=/tmp
filename=app_$(date +%Y%m%d)
filepath=${backup_dir}/${filename}.log
echo $filepath
# 输出: /tmp/app_20250709.log
```

---

## §3 环境变量：export 让子 Shell 也能看到

### 3.1 本地变量 vs 环境变量

| 类型 | 作用范围 | 子 Shell 能看到吗？ | 创建方式 |
|---|---|---|---|
| **本地变量** | 当前 Shell | ❌ 不能 | `var=value` |
| **环境变量** | 当前 Shell **+** 子 Shell | ✅ 能 | `export var=value` |

### 3.2 没有 export 的悲剧

```bash
# 父 Shell 设了个变量
[xkw@centos7 ~]$ username=tom
[xkw@centos7 ~]$ echo $username
tom                                # 父 Shell 自己能看到

# 父 Shell 开个"子 Shell"（嵌套 bash）
[xkw@centos7 ~]$ bash           # 进入子 Shell
[xkw@centos7 ~]$ echo $username
                                  # ⚠️ 输出空行！子 Shell 看不到
```

### 3.3 解决办法：export

```bash
# 方法 1：定义 + 导出 两步
[xkw@centos7 ~]$ username=tom
[xkw@centos7 ~]$ export username

# 方法 2：一步到位（推荐）
[xkw@centos7 ~]$ export username=tom

# 验证：子 Shell 也能看到
[xkw@centos7 ~]$ bash
[xkw@centos7 ~]$ echo $username
tom                                # ✓ 这次能看到了
```

### 3.4 一图看懂 export 的作用域

```
父 Shell (PID 1000)
├── username=tom           ← 本地变量
├── export username        ← 把它"升级"成环境变量
│
└── 子 Shell (PID 1001)    ← bash 命令进入
    ├── 本地变量: 空       ← 父 Shell 的本地变量传不过来
    └── 环境变量: username=tom  ← export 过的能传过来

子 Shell 改 username 不会影响父 Shell（单向继承）
```

### 3.5 实战：环境变量 vs 本地变量的应用

```bash
# 场景：给当前项目临时加个搜索路径
export PROJECT_HOME=/opt/myapp
export PATH=$PATH:$PROJECT_HOME/bin

# 验证
which mycmd                       # 应该能找到 /opt/myapp/bin/mycmd
```

> 💡 临时设置关闭 Shell 就消失；想永久生效要写到 `~/.bashrc` 或 `/etc/profile`（见 §8）。

---

## §4 常用环境变量速查

```bash
# 查看所有环境变量
[xkw@centos7 ~]$ env
# 或者
[xkw@centos7 ~]$ printenv
```

| 变量               | 含义          | 典型用途                       |
| ---------------- | ----------- | -------------------------- |
| `HOME`           | 当前用户的家目录    | `cd $HOME`                 |
| `USER`           | 当前登录用户名     | 脚本里判断权限                    |
| `PWD`            | 当前工作目录      | 脚本里记日志路径                   |
| `SHELL`          | 默认 Shell 程序 | `/bin/bash`                |
| `PATH`           | 命令搜索路径      | `:` 分隔                     |
| `LANG`           | 语言 / 字符集    | 影响 `date` 输出格式             |
| `EDITOR`         | 默认编辑器       | 影响 `visudo` / `crontab -e` |
| `PS1`            | 主提示符        | `[\u@\h \W]\$`             |
| `PS2`            | 续行提示符       | `> `                       |
| `HISTSIZE`       | 历史命令条数（内存）  | 默认 1000                    |
| `HISTFILESIZE`   | 历史文件条数（磁盘）  | 默认 1000                    |
| `HISTFILE`       | 历史文件路径      | `~/.bash_history`          |
| `HISTTIMEFORMAT` | 历史命令时间戳格式   | 见 §7                       |
| `LOGNAME`        | 登录名         | 与 USER 类似                  |
| `TERM`           | 终端类型        | `xterm-256color`           |
| `HOSTNAME`       | 主机名         | 同 `hostname` 命令            |

### 4.1 演示：用 EDITOR 控制 visudo

```bash
# 默认可能是 nano（CentOS-7 是 vim，但有些系统是 nano）
[root@centos7 ~]# visudo
#         vi  ← 左下角显示编辑器

# 改用 vim
[root@centos7 ~]# export EDITOR=/bin/vim
[root@centos7 ~]# visudo
#       vim  ← 改成了 vim
```

> 💡 `visudo` 故意调用 `$EDITOR` 而不是直接写死，就是为了让你**可以改**。

### 4.2 演示：用 LANG 控制 date 输出

```bash
# 改 LANG 之前
[root@centos7 ~]# date
2022年 11月 07日 星期一 13:38:31 CST       # 中文

# 改 LANG
[root@centos7 ~]# export LANG=en_US.utf8
[root@centos7 ~]# date
Mon Nov 7 13:38:55 CST 2022               # 英文

# 改回中文
[root@centos7 ~]# export LANG=zh_CN.utf8
```

> 💡 LANG 影响**所有**依赖 locale 的命令（date、ls、sort 排序顺序等）。

---

## §5 PATH 详解：PATH 改坏的救命方法

### 5.1 PATH 是什么

```bash
[xkw@centos7 ~]$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
```

> Shell 找你输入的 `ls` 时，按这个列表**从左到右**挨个目录找，找到就执行。

### 5.2 PATH 改坏的经典陷阱

```bash
# 1) 把 ls 命令移到当前目录
[root@centos7 ~]# mv /usr/bin/ls .
                              # ↑ 注意末尾的点 = 当前目录

# 2) 当前目录下还能用（因为当前目录优先级不在 PATH 里）
[root@centos7 ~]# ./ls        # ✓ 用相对路径能找到

# 3) 直接输入 ls 就找不到了
[root@centos7 ~]# ls
bash: ls: command not found...
Similar command is: 'lz'      # bash 提示接近的命令

# 4) which 也找不到
[root@centos7 ~]# which ls
alias ls='ls --color=auto'    # 其实是 alias，但找不到实体
```

> ⚠️ **这就是改坏 PATH 的真实写照**：明明命令在系统里，Shell 就是找不到。

### 5.3 救法 1：临时加 PATH（用绝对路径走程序）

```bash
# 把当前目录临时加到 PATH
[root@centos7 ~]# export PATH=$PATH:/root
                              # ↑ $PATH 是原值，: /root 是新加的
[root@centos7 ~]# ls
anaconda-ks.cfg initial-setup-ks.cfg ls
                              # ✓ 找到了！但显示的是当前目录的文件
                              # 实际执行的是 /root/ls（移到这的那个）

# 验证 which
[root@centos7 ~]# which ls
alias ls='ls --color=auto'    # alias 还是优先
                              # 但执行的是 /root/ls（PATH 里有 alias 优先）
```

### 5.4 救法 2：直接 mv 回去（最彻底）

```bash
# 把 ls 还原
[root@centos7 ~]# mv ./ls /usr/bin
[root@centos7 ~]# ls
anaconda-ks.cfg initial-setup-ks.cfg   # ✓ 系统正常了
```

### 5.5 救法 3：用绝对路径（不用改 PATH）

```bash
# 就算 PATH 是空的也能用
[root@centos7 ~]# /usr/bin/ls
[root@centos7 ~]# /bin/cp /root/ls /usr/bin/ls    # 复制回去
```

> 💡 **生产环境应急**：第一件事就是用**绝对路径**，不要折腾 PATH。

### 5.6 PATH 修改最佳实践

```bash
# ✅ 推荐：写到 ~/.bashrc 或 /etc/profile
echo 'export PATH=$PATH:/opt/myapp/bin' >> ~/.bashrc
source ~/.bashrc                # 立即生效

# ❌ 危险：覆盖 PATH（如果忘了原值就没了）
export PATH=/opt/myapp/bin      # 覆盖！原 PATH 全丢

# ❌ 危险：把当前目录加进去（安全风险）
export PATH=.:$PATH             # 别人在你目录里放个 ls 就能冒名执行
```

---

## §6 PS1 提示符定制（颜色 + 时间）

### 6.1 PS1 是什么

```bash
# 默认 PS1
[xkw@centos7 ~]$ echo $PS1
[\u@\h \W]\$
              ↑ ↑     ↑
              | |     └ $（UID=0 显示 #, 否则 $）
              | └ \W（当前目录 basename）
              └ \h（主机名 basename）
```

### 6.2 常用 PS1 转义符号

| 转义 | 含义 | 例子 |
|---|---|---|
| `\u` | 当前用户名 | `root` |
| `\h` | 主机名（短） | `centos7` |
| `\H` | 主机名（完整） | `centos7.example.com` |
| `\n` | 换行 | — |
| `\t` | 24h 时间 `HH:MM:SS` | `13:52:08` |
| `\T` | 12h 时间 `HH:MM:SS` | `01:52:08` |
| `\@` | 12h am/pm | `1pm` |
| `\A` | 24h 时:分 | `13:52` |
| `\w` | 当前目录（完整路径） | `/usr/share/doc` |
| `\W` | 当前目录（basename） | `doc` |
| `\$` | UID 0 显示 `#`，否则 `$` | `#` 或 `$` |
| `\d` | 日期 | `Mon Nov 7` |

### 6.3 自定义 PS1 示例

```bash
# 例 1：去掉用户名前缀，只显示 "HELLO "
[xkw@centos7 ~]$ PS1='HELLO '
HELLO echo hello world
hello world

# 例 2：加时间
[xkw@centos7 ~]$ PS1='[\u@\h \W \t]\$ '
[xkw@centos7 ~ 13:52:08]$        # 多了时间

# 例 3：显示完整路径
[xkw@centos7 ~ 13:52:08]$ PS1='[\u@\h \w \t]\$ '
[xkw@centos7 ~ 13:52:56]$ cd /usr/share/doc
[xkw@centos7 /usr/share/doc 13:53:04]$
```

### 6.4 加颜色：\[\e[Xm\]

```bash
# 颜色代码（30=黑 31=红 32=绿 33=黄 34=蓝 35=紫 36=青 37=白）
# \[\e[0;30m\]   黑色
# \[\e[0;31m\]   红色
# \[\e[0;32m\]   绿色
# \[\e[0;33m\]   黄色
# \[\e[0;34m\]   蓝色
# \[\e[0;35m\]   紫色
# \[\e[0;36m\]   青色
# \[\e[0;37m\]   白色
# \[\e[0m\]      关闭颜色（重要！必须还原）

# ⚠️ 必须用 \[\e[...m\] 包裹，不能直接 \e[...m（命令行长度会算错）
```

### 6.5 完整的彩色 PS1

```bash
# 推荐配置（写到 /etc/bashrc，所有用户生效）
PS1='[\[\e[91m\]\u\[\e[0m\]\[\e[93m\]@\[\e[0m\]\[\e[92;1m\]\h\[\e[0m\]\[\e[94m\] \W\[\e[0m\] \[\e[35m\]\t\[\e[0m\]]\[\e[93m\]\$\[\e[0m\] '

# 效果：
# [xkw@centos7 ~ 13:52:08]$     ← 用户名红、@黄、主机绿粗、目录蓝、时间紫、$黄
```

> 💡 写到 `/etc/bashrc` 用 echo + 注释（PDF 提示：单引号里 `\$` 要写成 `\\\$` 转义）。

```bash
# 写入方法 1：用 vim 编辑 /etc/bashrc
vim /etc/bashrc
# 在文件末尾加一行：
PS1='[\[\e[91m\]\u\[\e[0m\]\[\e[93m\]@\[\e[0m\]\[\e[92;1m\]\h\[\e[0m\]\[\e[94m\] \W\[\e[0m\] \[\e[35m\]\t\[\e[0m\]]\[\e[93m\]\$\[\e[0m\] '

# 写入方法 2：用 echo 追加（注意 \\\$ 转义）
echo "PS1='[\[\e[91m\]\u\[\e[0m\]\[\e[93m\]@\[\e[0m\]\[\e[92;1m\]\h\[\e[0m\]\[\e[94m\] \W\[\e[0m\] \[\e[35m\]\t\[\e[0m\]]\[\e[93m\]\\\$\[\e[0m\] '" >> /etc/bashrc
```

> ⚠️ 改完 PS1 不会自动重载！要 `source /etc/bashrc` 或重新登录。

---

## §7 HISTTIMEFORMAT：让 history 显示时间

### 7.1 默认 history 不显示时间

```bash
[xkw@centos7 ~]$ history | head -3
    1  ls -l
    2  cd /tmp
    3  pwd
                              # 没有时间戳
```

### 7.2 加时间戳

```bash
# 完整时间：年-月-日 时:分:秒
[xkw@centos7 ~]$ export HISTTIMEFORMAT="%F %T "
[xkw@centos7 ~]$ history | head -3
    1  2024-10-24 15:30:45 ls -l
    2  2024-10-24 15:30:50 cd /tmp
    3  2024-10-24 15:30:55 pwd

# 短时间：月-日 时:分
[xkw@centos7 ~]$ export HISTTIMEFORMAT="%m-%d %H:%M "
[xkw@centos7 ~]$ history | head -3
    1  10-24 15:30 ls -l
    2  10-24 15:30 cd /tmp
    3  10-24 15:30 pwd
```

### 7.3 格式符号（与 date 共用一套）

| 格式 | 含义 | 例子 |
|---|---|---|
| `%F` | 年-月-日 | `2024-10-24` |
| `%T` | 时:分:秒 | `15:30:45` |
| `%Y` | 年（4 位） | `2024` |
| `%m` | 月（01-12） | `10` |
| `%d` | 日（01-31） | `24` |
| `%H` | 时（24h 00-23） | `15` |
| `%M` | 分（00-59） | `30` |
| `%S` | 秒（00-59） | `45` |

> 💡 这是 `date` 命令的格式 + history 的应用。详见 [[Linux文本处理/辅助工具]] 里 date 的章节（若未补充可先 `man date`）。

### 7.4 永久生效

```bash
# 写到 ~/.bashrc（用户级）
echo 'export HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
source ~/.bashrc

# 写到 /etc/bashrc（系统级，所有用户）
echo 'export HISTTIMEFORMAT="%F %T "' >> /etc/bashrc
source /etc/bashrc
```

---

## §8 启动文件加载顺序（login vs nologin）

### 8.1 两种登录方式

| 登录方式 | 场景 | 加载文件（按顺序） |
|---|---|---|
| **login shell** | SSH 登录、`su -`、tty 终端 | `/etc/profile` → `~/.bash_profile` → `~/.bashrc` → `/etc/bashrc` |
| **nologin shell** | 已登录后新开终端、`bash` 命令、`su` | `~/.bashrc` → `/etc/bashrc` |

### 8.2 流程图

```
┌──────────────┐
│ 用户登录系统 │  ← login shell
└──────┬───────┘
       │
       ↓
  /etc/profile            ← 系统级
       │
       ↓
  ~/.bash_profile         ← 用户级（如果有 .bash_profile，bash 不会去读 .bash_login 和 .profile）
       │  └── 通常在这里 source ~/.bashrc
       ↓
  ~/.bashrc               ← 用户级
       │
       ↓
  /etc/bashrc             ← 系统级（CentOS-7 里有 PS1 兜底）

==========================================

┌──────────────┐
│ 已登录后 bash │  ← nologin shell
└──────┬───────┘
       │
       ↓
  ~/.bashrc
       │
       ↓
  /etc/bashrc
```

### 8.3 演示：login shell 设 LANG

```bash
# 写到 /etc/profile（所有用户登录生效）
[root@centos7 ~]# echo 'export LANG=en_US.utf8' >> /etc/profile

# SSH 登录验证
[c:\~]$ ssh xkw@10.1.8.88
Last login: Mon Nov 7 14:19:57 2022 from 10.1.8.1
[xkw@centos7 ~]$ date
Mon Nov 7 14:20:42 CST 2022       # 立刻英文了
```

### 8.4 演示：nologin shell 设 EDITOR

```bash
# 写到 /etc/bashrc（所有用户新开 bash 生效）
[root@centos7 ~]# echo 'export EDITOR=vim' >> /etc/bashrc

# 当前 bash 不会自动加载，要新开
[xkw@centos7 ~]$ bash
[xkw@centos7 ~]$ echo $EDITOR
vim                               # ✓ 这次生效了
```

### 8.5 该写哪个文件？

| 想要... | 写到 |
|---|---|
| 所有用户登录时生效 | `/etc/profile` |
| 当前用户登录时生效 | `~/.bash_profile` |
| 所有用户新开 bash 生效 | `/etc/bashrc` |
| 当前用户新开 bash 生效 | `~/.bashrc` |
| PATH、PS1 之类的**通用**配置 | `~/.bashrc` 或 `/etc/bashrc`（推荐后者） |

> 💡 **简化原则**：不确定就写 `~/.bashrc`，然后 `source ~/.bashrc`。

---

## §9 命令替换：$(cmd) vs 反引号 `cmd`

### 9.1 两种写法

```bash
# 写法 1：$(cmd)  ← 推荐
[xkw@centos7 ~]$ echo Today is $(date +%A)
Today is Monday

# 写法 2：`cmd`  ← 老式，不推荐
[xkw@centos7 ~]$ echo Today is `date +%A`
Today is Monday
```

### 9.2 实战：嵌入消息

```bash
[xkw@centos7 ~]$ echo The time is $(date +%M) minutes past $(date +%l%p).
The time is 38 minutes past 1PM.
```

### 9.3 实战：动态文件名

```bash
# 创建带日期的文件
[xkw@centos7 ~]$ touch file-$(date +%Y%m%d)
[xkw@centos7 ~]$ ls
file-20221107                     # ✓ 文件名带日期
```

### 9.4 $(cmd) vs `cmd` 的本质区别

| 维度 | `$(cmd)` | `` `cmd` `` |
|---|---|---|
| 嵌套 | ✅ 容易（内层加 `$(...)`） | ❌ 难（内层要 `\` 转义反引号） |
| 可读性 | ✅ 高（一眼能数清括号） | ❌ 低（反引号和单引号长得像） |
| 兼容性 | ✅ POSIX 标准 | ✅ Bash / sh 都支持 |
| 复杂度 | ✅ 适合复杂表达式 | ⚠️ 简单情况够用 |

```bash
# 嵌套对比
[xkw@centos7 ~]$ echo $(echo $(date +%Y))      # $( 嵌套 2 层，一目了然
2025
[xkw@centos7 ~]$ echo `echo \`date +%Y\``      # ` 嵌套要 \ 转义
2025
                              # ↑ 是不是晕了？
```

> 💡 **CentOS-7 规范**：新代码一律用 `$(cmd)`，禁用反引号（除非维护老脚本）。

---

## §10 算术运算：$[1+2] + {1..100}

### 10.1 简单求和

```bash
# 1+2+3 = 6
[xkw@centos7 ~]$ echo $[ 1+2+3 ]
6

# bash 内置算术（空格不影响）
[xkw@centos7 ~]$ echo $[ 10*2+5 ]
25
```

### 10.2 序列展开 {1..100}

```bash
# 连续序列
[xkw@centos7 ~]$ echo {1..3}
123                               # ⚠️ 默认无空格

# 加号分隔
[xkw@centos7 ~]$ echo {1..3} | tr ' ' '+'
1+2+3
```

### 10.3 求 1+2+...+100

```bash
# 思路：{1..100} 展开成 "1 2 3 ... 100"，tr 替换成 "1+2+3+...+100"，再用 $[ ... ] 求值
[xkw@centos7 ~]$ echo $[ $(echo {1..100} | tr ' ' '+') ]
5050                              # ✓ 1+2+...+100 = 5050
```

### 10.4 算术运算符速查

| 运算符 | 含义 | 例子 | 结果 |
|---|---|---|---|
| `+` `-` | 加减 | `$[ 5+3 ]` | `8` |
| `*` `/` | 乘除 | `$[ 10/3 ]` | `3`（整数除法） |
| `%` | 取模 | `$[ 10%3 ]` | `1` |
| `**` | 幂 | `$[ 2**10 ]` | `1024` |

> ⚠️ `$[ ... ]` 是 bash 的**旧语法**；新写法是 `$(( ... ))`（POSIX 标准）。两者**功能相同**。

```bash
# 新写法（推荐）
[xkw@centos7 ~]$ echo $(( 1+2+3 ))
6

# 求 1+2+...+100
[xkw@centos7 ~]$ echo $(( $(echo {1..100} | tr ' ' '+') ))
5050
```

> 💡 `$(( ... ))` 还可以用在 `if`、`for` 等控制流中，详见后续 PDF 笔记。

---

## §11 引号与转义：\ / "" / ''

### 11.1 三大引号总览

| 类型 | 变量替换 | 命令替换 | 转义 | 典型用途 |
|---|---|---|---|---|
| **无引号** | ✅ | ✅ | ✅ | 简单词 |
| **双引号 `""`** | ✅ | ✅ | ✅ | **大部分情况推荐** |
| **单引号 `''`** | ❌ | ❌ | ❌ | 原样输出 |
| **反引号 `` ` ``** | — | — | — | 老式命令替换（用 `$(cmd)` 替代） |
| **反斜杠 `\`** | — | — | — | 单字符转义 |

### 11.2 反斜杠 `\`：单字符转义

```bash
# 取消 $ 的特殊含义
[xkw@centos7 ~]$ echo $PATH
/usr/local/bin:/usr/bin:...
[xkw@centos7 ~]$ echo \$PATH
$PATH                             # 看到字面 $PATH

# 取消 \ 自身的含义
[xkw@centos7 ~]$ echo \\
\                                 # 一个 \

# 反斜杠也能"延续"长命令
[xkw@centos7 ~]$ echo hello \
> world
hello world
```

### 11.3 双引号 `""`：弱引用（变量会展开）

```bash
[xkw@centos7 ~]$ username=XieBaiQi
[xkw@centos7 ~]$ echo ******* Welcome $username to Linux Classroom On $(date +%F) *******
******* Welcome XieBaiQi to Linux Classroom On 2025-07-23 *******    # 变量 + 命令替换都展开了
```

> 注意：**不带引号** 和 **带双引号** 上面这个例子的**结果相同**。区别在下面：

```bash
# 用 \" 在双引号内插入字面 $
[xkw@centos7 ~]$ echo "******* Welcome \$username to Linux Classroom On $(date +%F) *******"
******* Welcome $username to Linux Classroom On 2025-07-23 *******    # $username 没展开，$(date) 还是展开了
```

### 11.4 单引号 `''`：强引用（全部原样）

```bash
[xkw@centos7 ~]$ echo '******* Welcome $username to Linux Classroom On $(date +%F) *******'
******* Welcome $username to Linux Classroom On $(date +%F) *******  # 全部原样输出
```

### 11.5 三个对比（一图看全）

```
输入:   ******* Welcome $username to Linux Classroom On $(date +%F) *******

无引号: ******* Welcome XieBaiQi to Linux Classroom On 2025-07-23 *******
        ↑ 变量和命令都展开

双引号: "******* Welcome $username to Linux Classroom On $(date +%F) *******"
        ******* Welcome XieBaiQi to Linux Classroom On 2025-07-23 *******
        ↑ 同上（双引号内的变量和命令也会展开）

单引号: '******* Welcome $username to Linux Classroom On $(date +%F) *******'
        ******* Welcome $username to Linux Classroom On $(date +%F) *******
        ↑ 全部原样，连 $ 都不展开
```

### 11.6 单引号里要插单引号怎么办？

```bash
# 错误：单引号里直接放 ' 会被当成结束
[xkw@centos7 ~]$ echo 'Let's go'
> '                                # bash 等你输入剩下的
                                  # 实际是 Let\s go（被错误地转义了）

# 正确：先结束单引号 + 转义 + 重新进入单引号
[xkw@centos7 ~]$ echo 'Let'\''s go'
Let's go                           # ✓ 正确输出

# 拆分理解：
#   'Let'   ← 第一个单引号字符串 'Let'
#   \'      ← 转义的单引号 '
#   's go'  ← 第二个单引号字符串 's go'
#   拼接 = 'Let' + "'" + 's go' = "Let's go"
```

> 💡 这个 `'\''` 是老 Shell 程序员最熟的"四字符"。**CentOS-7 实务里建议改用双引号 + 转义**：

```bash
# 更易读：用双引号 + 反斜杠
[xkw@centos7 ~]$ echo "Let's go"
Let's go
```

---

## §12 多行 echo + 重定向

### 12.1 用 echo 一次写多行

```bash
# 注意 "..." 是双引号，按回车不会结束
[xkw@centos7 ~]$ echo "hello 1
hello 2
hello 3" > hello.txt

[xkw@centos7 ~]$ cat hello.txt
hello 1
hello 2
hello 3
```

> ⚠️ 这里多行靠的是**双引号包住**，按回车不会结束 echo（因为 bash 在等右引号）。一旦按 `"` + `>` 才真正结束。

### 12.2 与 [[Linux文本处理/输入输出重定向|输入输出重定向]] 配合

```bash
# 写入多行日志
echo "===== Start at $(date) =====
Server: $(hostname)
User: $USER
=====" > /tmp/info.txt

cat /tmp/info.txt
```

### 12.3 实战：快速生成配置文件

```bash
# 一次性生成 nginx 简化配置
cat > /tmp/nginx.conf << 'EOF'
server {
    listen 80;
    server_name $HOSTNAME;        # 这里是字面值，不会被 Shell 展开
    root /var/www/html;
}
EOF
```

> 💡 多行配置用 [[Linux文本处理/awk]] 笔记里讲的 `cat << EOF` 更合适（这里是 PDF 演示的 `echo "..."` 写法）。

---

## §13 速查表

### 13.1 变量三连

```bash
var=value         # 赋值（等号两边无空格）
echo $var         # 引用
unset var         # 删除
```

### 13.2 变量类型

```bash
declare var=val           # 默认（字符串）
declare -i var=10         # 整数
declare -l var=ABC        # 强制小写
declare -u var=abc        # 强制大写
declare -r var=val        # 只读
declare -a arr=(a b c)    # 数组（见后续 PDF 笔记）
```

### 13.3 环境变量

```bash
var=val                    # 本地变量
export var=val             # 环境变量（子 Shell 可见）
env                        # 查看所有环境变量
unset var                  # 删除（本地 + 环境都删）
```

### 13.4 PATH 操作

```bash
echo $PATH                 # 查看
export PATH=$PATH:/new     # 追加（不丢原值）
./cmd                      # 用相对路径（不进 PATH）
/usr/bin/cmd               # 用绝对路径（PATH 坏了也能用）
```

### 13.5 PS1 转义

```
\u  \h  \H  \w  \W  \t  \T  \@  \A  \n  \d  \$
```

### 13.6 HISTTIMEFORMAT 格式

```
%F  %T  %Y  %m  %d  %H  %M  %S
```

### 13.7 启动文件

```
login shell:    /etc/profile → ~/.bash_profile → ~/.bashrc → /etc/bashrc
nologin shell:  ~/.bashrc → /etc/bashrc
```

### 13.8 命令替换

```bash
$(command)                # 推荐
`command`                 # 不推荐（除非维护老脚本）
```

### 13.9 算术

```bash
echo $[ 1+2 ]            # 旧写法
echo $(( 1+2 ))          # 新写法（推荐）
echo {1..5}              # 序列展开
```

### 13.10 引号

```
"..."     弱引用（变量和命令替换会展开）
'...'     强引用（全部原样）
\$        在双引号内转义 $
```

---

## §14 易错点 ×12

### 1. ❌ `var = value` 等号两边有空格

```bash
[xkw@centos7 ~]$ var = key1
bash: var: command not found...   # ⚠️ bash 把 var 当命令名了
```

> ✅ **正确**：`var=key1`（**无空格**）

### 2. ❌ 变量名以数字开头

```bash
[xkw@centos7 ~]$ 1var=hello
bash: 1var=hello: command not found...
```

> ✅ **正确**：变量名只能字母或下划线开头

### 3. ❌ 变量拼接忘了 `${}`

```bash
$ echo $last_name_$first_name
facai                              # ⚠️ last_name_ 不存在，被吞了
```

> ✅ **正确**：`${last_name}_$first_name`

### 4. ❌ 改完 PATH 不备份原值

```bash
export PATH=/opt/myapp/bin         # ⚠️ 原 PATH 全没了
```

> ✅ **正确**：`export PATH=$PATH:/opt/myapp/bin`（保留原值）

### 5. ❌ 改完 PS1 不重载

```bash
PS1='new prompt'                   # 当前窗口立刻生效
# 但如果改的是 /etc/bashrc...
vim /etc/bashrc
# 当前窗口不会自动加载！
```

> ✅ **正确**：改完执行 `source /etc/bashrc` 或重新登录

### 6. ❌ PS1 颜色忘了 `\[\e[0m\]`

```bash
PS1='\e[31m$ \e[0m'                # ⚠️ 没有 \[\] 包裹
# 命令行长度算错，删除时光标乱跳
```

> ✅ **正确**：`PS1='\[\e[31m\]$ \[\e[0m\]'`（`\[\]` 包裹）

### 7. ❌ 单引号里嵌套单引号

```bash
echo 'Let's go'                    # ⚠️ 错误，被当成 'Let' + s go
```

> ✅ **正确**：`echo "Let's go"`（用双引号）或 `echo 'Let'\''s go'`

### 8. ❌ 子 Shell 改 PATH 以为父 Shell 也能用

```bash
[parent]$ PATH=$PATH:/opt
[parent]$ bash
[child]$  PATH=$PATH:/new         # 只在 child 生效
[child]$ exit
[parent]$ echo $PATH | grep /new  # 找不到！
```

> ✅ **正确**：子 Shell 改的环境变量**不传回**父 Shell

### 9. ❌ echo $username 不带引号

```bash
username="Hello World"
echo $username                    # 输出: Hello World（没问题）
echo "$username"                  # 输出: Hello World（更安全）

# 但如果 username 里有 * 之类的通配符：
username="*"
echo $username                    # 输出当前目录所有文件（被通配了！）
echo "$username"                  # 输出: *（原样）
```

> ✅ **最佳实践**：含变量用**双引号包**：`echo "$username"`

### 10. ❌ HISTTIMEFORMAT 没写 bashrc

```bash
export HISTTIMEFORMAT="%F %T "    # 当前 Shell 生效
# 关闭 Shell 再开 → 没了！
```

> ✅ **正确**：写 `~/.bashrc` 并 `source`

### 11. ❌ declare -l 改的是变量内容，不是变量名

```bash
declare -l NAME=ABC               # 变量名是 NAME（大写）
echo $NAME                        # 输出: abc（内容变小写）
echo ${!NAME}                     # 想看变量名是什么？这种用法很罕见
```

> 💡 理解：`-l` 控制**值**，不影响**变量名本身**。

### 12. ❌ 把当前目录加进 PATH

```bash
export PATH=.:$PATH               # ⚠️ 安全风险！
# 黑客在 /tmp 放一个 ls，你 cd /tmp 再 ls 就执行他的版本
```

> ✅ **正确**：用 `./cmd` 显式调用，或把命令移到 `/usr/local/bin/`

---

## §15 面试 6 大追问

### Q1：`var=value` 和 `var = value` 有什么区别？

**答**：
- `var=value`（无空格）= **赋值**
- `var = value`（有空格）= 试图执行命令 `var`，参数 `=` 和 `value`

```bash
[xkw@centos7 ~]$ var=value    # var 存了 "value"
[xkw@centos7 ~]$ var = value
bash: var: command not found... # 找不到 var 命令
```

> 进阶：唯一有空格合法的场景是**命令位置**的赋值，如 `PATH=$PATH:/new` 的**等号前后**仍无空格。

### Q2：`$var_x` 和 `${var}_x` 有什么区别？

**答**：
- `$var_x` = 找变量 `var_x`
- `${var}_x` = 变量 `var` + 字面 `_x`

```bash
[xkw@centos7 ~]$ var=hello
[xkw@centos7 ~]$ echo ${var}_x
hello_x                           # ✓

[xkw@centos7 ~]$ echo $var_x
                                  # 输出空（找不到 var_x 变量）
```

### Q3：什么场景必须用 `export`？

**答**：**当子进程需要继承时**。
- 当前 Shell 用：不需要
- 脚本里要用外部命令读：必须
- SSH / su 进入子 Shell：必须

```bash
# 写脚本的常见坑
# 父 Shell
export DB_HOST=192.168.1.1        # 必须 export
./deploy.sh                       # deploy.sh 里才能 $DB_HOST

# 不 export
DB_HOST=192.168.1.1
./deploy.sh                       # deploy.sh 里 $DB_HOST 是空！
```

### Q4：PS1 的 `\W` 和 `\w` 有什么区别？

**答**：
- `\W` = 当前目录的 basename（最后一段）
- `\w` = 完整路径

```bash
[xkw@centos7 /usr/share/doc]$ PS1='\W\$ '
doc$                              # 只显示 doc
[xkw@centos7 /usr/share/doc]$ PS1='\w\$ '
/usr/share/doc$                   # 完整路径
```

> 💡 `\w` 路径很长时显得很挤；常见做法是 `\W` + 自己 `cd` 到想要的目录。

### Q5：单引号、双引号、反引号各有什么特点？

**答**：

| 引号 | 变量替换 | 命令替换 | 转义 | 别名 |
|---|---|---|---|---|
| `'...'` | ❌ | ❌ | ❌ | 强引用 / hard quote |
| `"..."` | ✅ | ✅ | ✅ | 弱引用 / soft quote |
| `` `...` `` | — | — | — | 命令替换（推荐用 `$(...)`） |

> 进阶：反引号其实是**命令替换**不是"引号"，但常被并列比较。

### Q6：子 Shell 改的 PATH 父 Shell 看得见吗？

**答**：**看不见**。子 Shell 是独立的进程空间。

```bash
[parent]$ export PATH=$PATH:/opt  # 父 Shell 加 PATH
[parent]$ bash                    # 进子 Shell
[child]$ export PATH=$PATH:/tmp   # 子 Shell 再加
[child]$ exit                     # 回父 Shell
[parent]$ echo $PATH | grep /tmp  # 找不到 /tmp
                                  # 因为子 Shell 的 export 没传回来
```

> 进阶：但**反过来**可以（父 Shell export 的，子 Shell 看得见）。

---

## §16 与其他笔记的链路

| 笔记 | 关系 |
|---|---|
| [[linux文件查询]] | 命令替换 `$(date +%Y%m%d)` 生成文件名前缀 |
| [[Linux文本处理/输入输出重定向]] | `>` `>>` 配合 echo 写多行内容 |
| [[Linux文本处理/grep]] | 用环境变量构造 grep 模式 |
| [[Linux文本处理/awk]] | 算术 `$(( ))` 在 awk 中也有 `BEGIN` 块使用 |
| [[Linux文本处理/辅助工具]] | `date` 格式（%F %T）与 HISTTIMEFORMAT 共用 |
| [[Linux编辑器/vim]] | EDITOR 环境变量决定 visudo / crontab -e 用什么编辑器 |
| [[Linux目录/目录的使用]] | PATH 改了要找 `which ls` 验证 |
| [[Linux目录/目录的权限]] | 脚本无 export 时子进程看不到变量 |

> 💡 **未来联动**：流程控制（if/for/while）、函数、数组等章节会在后续 PDF 笔记中补全。届时本笔记会从"变量篇"扩展为"完整 Shell 基础"。

---

## §17 进一步阅读

| 资源 | 说明 |
|---|---|
| `man bash` | 查 `PARAMETERS` / `EXPANSION` / `PROMPTING` 章节 |
| 《鸟哥的 Linux 私房菜 — 基础学习篇》 | 第 13 章 认识 Bash、第 14 章 Shell Scripts |
| 《Linux 命令行与 shell 脚本编程大全》 | 第 5 章 理解 Shell、第 6 章 Linux 环境变量 |
| 《Shell 脚本实战》 | 进阶范例 |
| `info bash` | bash 完整手册（比 `man` 详细） |

### 推荐 PDF 之外的实战命令

```bash
# 1) 看看你的环境变量里有什么
env | sort > /tmp/my_env.txt
wc -l /tmp/my_env.txt

# 2) 让 PS1 显示 git 分支（高级玩法，详见后续笔记）
PS1='\u@\h:\W$(__git_ps1 " (%s)")\$ '

# 3) 把今天的命令存到带时间戳的文件
history > "cmd_history_$(date +%Y%m%d_%H%M).txt"
```

---

## 复习建议

- [ ] 能默写 `var=value` / `echo $var` / `unset var` 三连
- [ ] 能解释 `${var}_x` 和 `$var_x` 的区别
- [ ] 能默写 PS1 常用 5 个转义：`\u \h \W \w \t`
- [ ] 知道 PATH 改坏的 3 种救法（`./ls`、`/usr/bin/ls`、绝对路径重写）
- [ ] 能说出 login shell 和 nologin shell 的启动文件顺序
- [ ] 能解释 `""` 和 `''` 的本质区别
- [ ] 能默写命令替换两种写法并说出推荐 `$(cmd)` 的原因
- [ ] 能在 30 秒内求出 `1+2+...+100 = 5050`

---

# 编程篇（基于 09.shell编程实战 系列 PDF）

> **范围说明**：本篇基于 `E:\云计算学习\09.shell编程实战\shell 编程实战\` 文件夹下 11 个 PDF 笔记（2, 4-13, 15），共 7,520 行原始内容。涵盖：第一个脚本、位置参数、数值计算、条件测试、if/case/while/for/select、循环控制、函数、数组、调试。
>
> **链路呼应**：
> - ← [[#§1 自定义变量|变量篇]]：所有编程都建立在变量上
> - → [[linux-vim|vim]]：用 vim 写 Shell 脚本是最常见的开发方式
> - → [[linux-io-redirection|输入输出重定向]]：脚本里 `>` `>>` `<` `<<` 大量使用

## 目录

- [[#§18 第一个 Shell 脚本：shebang + 权限 + 执行]]
- [[#§19 位置参数与特殊变量：$0 $n $# $* $@ $?]]
- [[#§20 数值计算 7 武器：(())/let/expr/bc/$[]/awk/declare]]
- [[#§21 条件测试 4 语法：test / [ ] / [[ ]] / (())]]
- [[#§22 if 条件语句：单支/双支/多支/嵌套]]
- [[#§23 case 条件语句：通配 + 菜单]]
- [[#§24 while / until 循环：条件在前 vs 条件在后]]
- [[#§25 for / select 循环：3 种写法 + 菜单]]
- [[#§26 循环控制：break / continue / exit / return / $?]]
- [[#§27 Shell 函数：定义/参数/返回值/递归/作用域]]
- [[#§28 Shell 数组：普通数组 + 关联数组]]
- [[#§29 Shell 脚本调试：bash -x / set -x / set -e]]
- [[#§30 编程篇速查表]]
- [[#§31 编程篇易错点 ×15]]
- [[#§32 编程篇面试 8 大追问]]
- [[#§33 完整 Shell 基础总链路]]

---

## §18 第一个 Shell 脚本：shebang + 权限 + 执行

### 18.1 什么是 Shell 脚本

```
Shell 脚本 = 一堆 Shell 命令的集合，存成文件，能反复执行。

本质：脚本里每行就是一条命令
类比：脚本 = 菜谱；每行 = 一个步骤
```

### 18.2 三步写出第一个脚本

```bash
# 步骤 1：创建脚本文件
[xkw@centos7 ~]$ vim hello.sh

# 步骤 2：写内容（3 行）
#!/bin/bash
# 这是注释（# 开头）
echo "Hello, World!"

# 步骤 3：加执行权限 + 运行
[xkw@centos7 ~]$ chmod +x hello.sh
[xkw@centos7 ~]$ ./hello.sh
Hello, World!
```

### 18.3 shebang 是什么

```
#!    ← 这两个字符叫 shebang（音：#! → "sharp bang"）
/bin/bash    ← 用什么解释器执行

类比：
  #!/bin/bash     = 用 bash 读这张"菜谱"
  #!/usr/bin/python3 = 用 python3 读
  #!/bin/sh       = 用 sh 读（POSIX 标准）
```

| shebang | 解释器 | 特点 |
|---|---|---|
| `#!/bin/bash` | bash 4.x | CentOS-7 默认，最常用 |
| `#!/bin/sh` | POSIX sh | 最通用，特性少 |
| `#!/usr/bin/env bash` | bash（通过 env 找） | 跨平台友好 |
| `#!/usr/bin/python3` | Python 3 | 写 Python 脚本用 |

> 💡 **最佳实践**：用 `#!/usr/bin/env bash` 避免硬编码路径。

### 18.4 三种执行方式的区别

```bash
# 方式 1：./script.sh（必须先 chmod +x）
[xkw@centos7 ~]$ ./hello.sh
Hello, World!

# 方式 2：bash script.sh（不需要执行权限）
[xkw@centos7 ~]$ bash hello.sh
Hello, World!

# 方式 3：source script.sh 或 . script.sh（在当前 Shell 执行）
[xkw@centos7 ~]$ source hello.sh
Hello, World!
```

| 方式 | 是否需要 `chmod +x` | 启动子 Shell？ | 修改变量父 Shell 可见？ | 调试用 |
|---|---|---|---|---|
| `./script.sh` | ✅ 需要 | ✅ 启动 | ❌ 不可见 | 正常执行 |
| `bash script.sh` | ❌ 不需要 | ✅ 启动 | ❌ 不可见 | 调试语法 |
| `source script.sh` | ❌ 不需要 | ❌ **不启动**（在当前 Shell） | ✅ **可见** | 加载配置 |

```bash
# 演示 source 修改当前 Shell
[xkw@centos7 ~]$ cat setvar.sh
export DB_HOST=192.168.1.1

[xkw@centos7 ~]$ bash setvar.sh        # 子 Shell 设置
[xkw@centos7 ~]$ echo $DB_HOST         # 空
                                  # ⚠️ 子 Shell 退出后变量没了

[xkw@centos7 ~]$ source setvar.sh      # 当前 Shell 执行
[xkw@centos7 ~]$ echo $DB_HOST
192.168.1.1                       # ✓ 生效了
```

### 18.5 一个完整的脚本模板

```bash
#!/bin/bash
#
# File: deploy.sh
# Desc: 部署脚本模板
# Date: 2025-07-09
#

# 1. 严格模式（见 §29 调试）
set -euo pipefail

# 2. 变量
APP_NAME="myapp"
APP_HOME="/opt/${APP_NAME}"
LOG_FILE="/var/log/${APP_NAME}.log"

# 3. 函数
log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

# 4. 主流程
main() {
    log "部署开始"
    # 部署逻辑...
    log "部署完成"
}

main "$@"
```

### 18.6 实战练习（在共享文件夹里）

```bash
cd /mnt/hgfs/Linux
mkdir -p shell_lab && cd shell_lab

# 写第一个脚本
cat > hello.sh << 'EOF'
#!/bin/bash
echo "Hello from $(hostname) at $(date '+%F %T')"
EOF

chmod +x hello.sh
./hello.sh
bash hello.sh
source hello.sh    # 3 种方式都试一遍
```

---

## §19 位置参数与特殊变量：$0 $n $# $* $@ $?

### 19.1 位置参数全景

```bash
# 执行：bash showargs.sh {a..z}

$0    = 脚本名 (showargs.sh)
$1    = 第 1 个参数 (a)
$2    = 第 2 个参数 (b)
...
$9    = 第 9 个参数 (i)
$10   = ⚠️ 不是第 10 个参数！是 $1 + 字面 0 = "a0"
${10} = ✓ 第 10 个参数 (j)
$#    = 参数个数 (26)
$*    = 全部参数 (a b c ... z)
$@    = 全部参数 (推荐使用)
$$    = 当前 Shell 的 PID
$!    = 上一个后台进程的 PID
$?    = 上一个命令的退出状态 (0=成功)
```

### 19.2 经典演示：showargs.sh

```bash
#!/bin/bash
# 演示位置参数
echo "脚本名: $0"
echo "第 1 个参数: $1"
echo "第 2 个参数: $2"
echo "第 10 个参数(错): $10"
echo "第 10 个参数(对): ${10}"
echo "参数个数: $#"
echo "全部参数(\$*): $*"
echo "全部参数(\$@): $@"
echo "加引号的 \$@: \"$@\""
```

```bash
# 运行
[xkw@centos7 ~]$ bash showargs.sh {a..z}
脚本名: showargs.sh
第 1 个参数: a
第 2 个参数: b
第 10 个参数(错): a0          # ← $1 + "0" = "a0"，错了！
第 10 个参数(对): j            # ← ${10} 才是第 10 个
参数个数: 26
全部参数($*): a b c d e f g h i j k l m n o p q r s t u v w x y z
全部参数($@): a b c d e f g h i j k l m n o p q r s t u v w x y z
加引号的 $@: "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
```

### 19.3 `$*` vs `$@` 的本质区别

```bash
# 演示脚本
#!/bin/bash
echo "--- 不加引号 ---"
echo "循环 \$*:"; for x in $*; do echo "[$x]"; done
echo "循环 \$@:"; for x in $@; do echo "[$x]"; done

echo "--- 加双引号 ---"
echo "循环 \"\$*\":"
for x in "$*"; do echo "[$x]"; done       # 1 个参数，整体
echo "循环 \"\$@\":"
for x in "$@"; do echo "[$x]"; done       # N 个参数，分别
```

```
假设执行：bash test.sh "hello world" "foo bar"

不加引号：
  "$*" → "hello world foo bar"  → 循环 3 次: [hello] [world] [foo] [bar] (其实是 4 次)
  "$@" → "hello world" "foo bar" → 循环 2 次: [hello world] [foo bar]

加双引号：
  "$*" → "hello world foo bar"  → 循环 1 次: [hello world foo bar]（一个整体）
  "$@" → "hello world" "foo bar" → 循环 2 次: [hello world] [foo bar]（保持原样）
```

> 💡 **黄金法则**：**遍历参数永远用 `for x in "$@"`**

### 19.4 `$?` 退出状态码

```bash
# 0 = 成功，非 0 = 失败
[xkw@centos7 ~]$ ls
hello.sh showargs.sh
[xkw@centos7 ~]$ echo $?
0                                # 成功

[xkw@centos7 ~]$ ls /root
ls: cannot open directory '/root': Permission denied
[xkw@centos7 ~]$ echo $?
2                                # 失败，错误码 2

# 在脚本里用
if [ $? -eq 0 ]; then
    echo "成功"
else
    echo "失败，错误码: $?"
fi
```

> ⚠️ 常见错误码：0=成功、1=通用失败、2=命令错用、126=不能执行、127=找不到命令、130=Ctrl+C

### 19.5 `$$` 和 `$!`

```bash
# $$ = 当前 Shell 的 PID
[xkw@centos7 ~]$ echo $$
12345

# $! = 上一个后台进程的 PID
sleep 60 &
[1] 67890                       # 后台进程 PID 是 67890
[xkw@centos7 ~]$ echo $!
67890

# 实战：写带 PID 的日志
echo "Process $$ started at $(date)" >> /tmp/process_$$.log
```

### 19.6 实战：参数处理脚本

```bash
#!/bin/bash
# file: ssh_ctl.sh（用位置参数控制 sshd）
# 用法: sudo ./ssh_ctl.sh {start|stop|status|restart}

systemctl $1 sshd
```

```bash
[xkw@centos7 ~]$ sudo ./ssh_ctl.sh stop
[xkw@centos7 ~]$ sudo ./ssh_ctl.sh status
● sshd.service - OpenSSH server daemon
   ...
[xkw@centos7 ~]$ sudo ./ssh_ctl.sh start
```

### 19.7 实战：通用服务控制

```bash
#!/bin/bash
# file: service_ctl.sh
# 用法: sudo ./service_ctl.sh {start|stop|status|restart} <服务名>

ACTION=$1
SERVICE=$2

if [[ $# -ne 2 ]]; then
    echo "用法: $0 {start|stop|status|restart} <服务名>"
    exit 1
fi

systemctl $ACTION $SERVICE
```

---

## §20 数值计算 7 武器：(())/let/expr/bc/$[]/awk/declare

### 20.1 七种数值计算方法对比

| 方法 | 语法 | 适合场景 | 性能 | 支持浮点 |
|---|---|---|---|---|
| `(())` | `((i=i+1))` | 整数运算、循环 | ⭐⭐⭐ | ❌ |
| `let` | `let i=i+1` | 整数运算（古老） | ⭐⭐⭐ | ❌ |
| `expr` | `expr 1 + 1` | 兼容性最好 | ⭐ | ❌ |
| `bc` | `echo "1.5*2" \| bc` | **浮点 + 高精度** | ⭐⭐ | ✅ |
| `$[]` | `$[1+2]` | bash 内置（旧） | ⭐⭐⭐ | ❌ |
| `awk` | `awk 'BEGIN{print 1.5*2}'` | 浮点 + 复杂表达式 | ⭐⭐ | ✅ |
| `declare -i` | `declare -i i=1+2` | 变量类型声明 | ⭐⭐ | ❌ |

### 20.2 (()) 双括号（最推荐）

```bash
# 基本运算
[xkw@centos7 ~]$ echo $((1+1))
2
[xkw@centos7 ~]$ echo $((6*3))
18

# 赋值
[xkw@centos7 ~]$ ((i=5))
[xkw@centos7 ~]$ ((i=i*2))
[xkw@centos7 ~]$ echo $i
10

# 复杂表达式
[xkw@centos7 ~]$ ((a=1+2**3-4%3))
              # ↑ ** 幂 = 8, 4%3 = 1, 所以 a = 1 + 8 - 1 = 8
[xkw@centos7 ~]$ echo $a
8

# 同时赋值和取值
[xkw@centos7 ~]$ b=$((a=1+2**3-4%3))
[xkw@centos7 ~]$ echo $b
8                                # b = a = 8

# 条件判断（if 里）
if ((a > 5)); then
    echo "a 大于 5"
fi

# 自增自减
[xkw@centos7 ~]$ i=5
[xkw@centos7 ~]$ echo $((i++))
5                                # 先取值再 +1
[xkw@centos7 ~]$ echo $i
6
[xkw@centos7 ~]$ echo $((++i))
7                                # 先 +1 再取值
```

### 20.3 let 命令（与 (()) 等价）

```bash
# 用法 1：let 表达式
[xkw@centos7 ~]$ i=5
[xkw@centos7 ~]$ let i=i*2
[xkw@centos7 ~]$ echo $i
10

# 用法 2：let "表达式"（推荐，引号保护特殊字符）
[xkw@centos7 ~]$ i=5
[xkw@centos7 ~]$ let "i = i + 2"
[xkw@centos7 ~]$ echo $i
7
```

> 💡 `let` 和 `(())` 功能几乎一样。`((` 在脚本里更清晰，**推荐用 (())**。

### 20.4 expr（兼容性最好，但语法繁琐）

```bash
# 注意：运算符两边必须有空格！
[xkw@centos7 ~]$ expr 1 + 2
3
[xkw@centos7 ~]$ expr 6 \* 3
18                               # * 要转义！

# 变量计算
[xkw@centos7 ~]$ i=5
[xkw@centos7 ~]$ i=$(expr $i + 1)
[xkw@centos7 ~]$ echo $i
6

# 字符串长度
[xkw@centos7 ~]$ expr length "hello"
5
```

> ⚠️ `expr` 的运算符两边**必须有空格**，`*` 要转义，非常容易出错。新代码**别用**。

### 20.5 bc（处理浮点 + 高精度）

```bash
# 整数
[xkw@centos7 ~]$ echo "5+3" | bc
8

# 浮点（关键能力！）
[xkw@centos7 ~]$ echo "10/3" | bc
3                                # ⚠️ 默认整数除法
[xkw@centos7 ~]$ echo "scale=2; 10/3" | bc
3.33                             # scale=2 保留 2 位小数

# 复杂计算
[xkw@centos7 ~]$ echo "scale=3; (5+3)*2/3" | bc
5.333

# 高级：平方根、幂
[xkw@centos7 ~]$ echo "scale=4; sqrt(2)" | bc
1.4142
[xkw@centos7 ~]$ echo "2^10" | bc
1024
```

### 20.6 $[]（老语法，已废弃）

```bash
[xkw@centos7 ~]$ echo $[ 1+2 ]
3
[xkw@centos7 ~]$ echo $[ 10*2+5 ]
25

# ⚠️ $[] 是 bash 旧写法，POSIX 不支持。新代码用 $(( ))
```

### 20.7 awk（处理浮点 + 复杂）

```bash
# 浮点
[xkw@centos7 ~]$ awk 'BEGIN{print 1.5*2}'
3
[xkw@centos7 ~]$ awk 'BEGIN{print 10/3}'
3.33333

# 复杂计算
[xkw@centos7 ~]$ awk 'BEGIN{print sqrt(2), 2^10}'
1.4142 1024

# 在脚本里用
result=$(awk "BEGIN{print ${x}*${y}}")
```

### 20.8 declare -i（声明整数变量）

```bash
# 默认是字符串
[xkw@centos7 ~]$ a=1+2
[xkw@centos7 ~]$ echo $a
1+2                              # 字面字符串

# 声明为整数
[xkw@centos7 ~]$ declare -i a=1+2
[xkw@centos7 ~]$ echo $a
3                                # 自动算出来

# ⚠️ 但 declare -i 也不支持浮点
[xkw@centos7 ~]$ declare -i a=1.5
bash: 1.5: syntax error: invalid arithmetic operator
                                  # 报错，要浮点用 bc
```

### 20.9 七武器决策树

```
                需要做数值计算
                       │
              ┌────────┴────────┐
              │                 │
            整数              浮点
              │                 │
        ┌─────┴─────┐          │
        │           │          │
   脚本里     命令行快速       │
        │           │          │
     (())        $[ ]      ┌───┴───┐
   (推荐)       (旧语法)   │       │
                          bc     awk
                       (高精度) (复杂)
```

> 💡 **黄金组合**：脚本里用 `(())` 或 `let`，要浮点用 `bc` 或 `awk`。

### 20.10 实战：菜单价格计算

```bash
#!/bin/bash
# 计算折扣价

price=100
discount=0.85
qty=3

# 整数：用 (())
total=$((price * qty))
echo "原价: $total"

# 浮点：用 awk 或 bc
final=$(awk "BEGIN{print $total * $discount}")
echo "折后: $final"
```

---

## §21 条件测试 4 语法：test / [ ] / [[ ]] / (())

### 21.1 四种语法对比

| 语法 | 写法 | 兼容性 | 特性 | 推荐度 |
|---|---|---|---|---|
| `test` | `test -f file` | POSIX ✅ | 功能完整，繁琐 | ⭐⭐ |
| `[ ]` | `[ -f file ]` | POSIX ✅ | test 的简写，常用 | ⭐⭐⭐ |
| `[[ ]]` | `[[ -f file ]]` | bash 扩展 | 支持 `&&` `||` `<` `>`，**无需引号** | ⭐⭐⭐⭐⭐ |
| `(( ))` | `(( a > b ))` | bash 扩展 | 整数专用，类 C 语法 | ⭐⭐⭐⭐ |

> 💡 **黄金法则**：**新脚本用 `[[ ]]`，整数用 `(( ))`**。

### 21.2 文件测试（最常用）

```bash
# 常用文件测试
test -e file      # 文件或目录存在
test -f file      # 是普通文件
test -d file      # 是目录
test -L file      # 是符号链接
test -r file      # 可读
test -w file      # 可写
test -x file      # 可执行
test -s file      # 存在且非空
test -S file      # 是 socket
test -p file      # 是命名管道
test -b file      # 是块设备
test -c file      # 是字符设备
test -u file      # 有 suid
test -g file      # 有 sgid
test -k file      # 有 sticky
test -O file      # 属主是当前用户
test -G file      # 属组是当前用户
test -nt file2    # 比 file2 新
test -ot file2    # 比 file2 旧
```

```bash
# 演示
[xkw@centos7 ~]$ [ -f /etc/passwd ] && echo "是普通文件"
是普通文件
[xkw@centos7 ~]$ [ -d /etc ] && echo "是目录"
是目录
[xkw@centos7 ~]$ [ -x /bin/bash ] && echo "可执行"
可执行
```

### 21.3 字符串比较

```bash
# == 判断相等（在 [[ ]] 里还能用通配）
[xkw@centos7 ~]$ [[ "hello" == "hello" ]] && echo "相等"
相等

# != 不等
[xkw@centos7 ~]$ [[ "hello" != "world" ]] && echo "不等"
不等

# -z 长度为 0
[xkw@centos7 ~]$ [[ -z "" ]] && echo "空字符串"
空字符串

# -n 长度非 0
[xkw@centos7 ~]$ [[ -n "abc" ]] && echo "非空"
非空

# [[ ]] 里的 < > 是字典序
[xkw@centos7 ~]$ [[ "apple" < "banana" ]] && echo "apple 在前"
apple 在前

# ⚠️ [ ] 里的 < > 是重定向！要用 \ 转义或改用 [[ ]]
[xkw@centos7 ~]$ [ "apple" \< "banana" ] && echo "OK"
OK
```

### 21.4 整数比较

```bash
# 推荐用 (())
(( a == b ))   # 等于
(( a != b ))   # 不等
(( a > b ))    # 大于
(( a >= b ))   # 大于等于
(( a < b ))    # 小于
(( a <= b ))   # 小于等于

# [ ] / [[ ]] 里要用字母（POSIX 标准）
[ "$a" -eq "$b" ]   # equal 等于
[ "$a" -ne "$b" ]   # not equal 不等
[ "$a" -gt "$b" ]   # greater than
[ "$a" -ge "$b" ]   # greater or equal
[ "$a" -lt "$b" ]   # less than
[ "$a" -le "$b" ]   # less or equal
```

```bash
# 演示
[xkw@centos7 ~]$ a=10; b=5
[xkw@centos7 ~]$ (( a > b )) && echo "a 大"
a 大
[xkw@centos7 ~]$ [ "$a" -gt "$b" ] && echo "a 大"
a 大
```

### 21.5 逻辑运算

```bash
# [[ ]] 里：&& || （类 C）
[xkw@centos7 ~]$ [[ -f /etc/passwd && -r /etc/passwd ]] && echo "可读文件"
可读文件

# [ ] 里：-a -o （POSIX，老式）
[xkw@centos7 ~]$ [ -f /etc/passwd -a -r /etc/passwd ] && echo "可读文件"
可读文件

# 否定 !
[xkw@centos7 ~]$ [[ ! -d /tmp/nonexistent ]] && echo "目录不存在"
目录不存在
```

### 21.6 [[ ]] 的高级特性

```bash
# 1) 模式匹配（== 右侧可以是 glob）
[xkw@centos7 ~]$ [[ "hello.txt" == *.txt ]] && echo "是 txt 文件"
是 txt 文件

[xkw@centos7 ~]$ [[ "abc" == [a-z][a-z][a-z] ]] && echo "是 3 字母"
是 3 字母

# 2) 正则匹配（=~）
[xkw@centos7 ~]$ [[ "abc123" =~ ^[a-z]+[0-9]+$ ]] && echo "匹配"
匹配

# 3) 无需引号（变量空也安全）
[xkw@centos7 ~]$ name=""
[xkw@centos7 ~]$ [[ $name == "" ]] && echo "空"      # ✓ 安全
空
[xkw@centos7 ~]$ [ "$name" == "" ] && echo "空"      # [ ] 必须加引号
空

# 4) [ ] 里不加引号会出错
[xkw@centos7 ~]$ [ $name == "" ] && echo "空"
bash: [: argument expected         # ⚠️ 报错
```

### 21.7 命令测试（不写 [ ]）

```bash
# 直接用命令的退出状态
if grep -q "root" /etc/passwd; then
    echo "找到 root"
fi

if ping -c 1 8.8.8.8 &>/dev/null; then
    echo "网络通"
fi
```

### 21.8 实战：服务检查脚本

```bash
#!/bin/bash
# 检查服务是否运行

SERVICE=$1

if [[ -z $SERVICE ]]; then
    echo "用法: $0 <服务名>"
    exit 1
fi

if systemctl is-active --quiet $SERVICE; then
    echo "✓ $SERVICE 正在运行"
    exit 0
else
    echo "✗ $SERVICE 未运行"
    exit 1
fi
```

---

## §22 if 条件语句：单支/双支/多支/嵌套

### 22.1 语法三要素：if / then / fi

```bash
# 最小骨架
if <条件>; then
    命令
fi

# fi = if 反写 = 结束标记
```

### 22.2 单支 if

```bash
# 模式：条件成立才执行
if <条件>; then
    命令
fi
```

```bash
# 例子：目录不存在就创建
if [[ ! -d /tmp/xkw ]]; then
    mkdir /tmp/xkw
fi

# 简化（用 &&）
[ ! -d /tmp/xkw ] && mkdir /tmp/xkw
```

### 22.3 双支 if/else

```bash
# 模式
if <条件>; then
    命令1
else
    命令2
fi
```

```bash
# 例子：判断文件类型
if [[ -f /etc/passwd ]]; then
    echo "passwd 是普通文件"
else
    echo "passwd 不是普通文件"
fi
```

### 22.4 多支 if/elif/else

```bash
# 模式
if <条件1>; then
    命令1
elif <条件2>; then
    命令2
elif <条件3>; then
    命令3
else
    兜底命令
fi
```

```bash
# 例子：成绩评级
#!/bin/bash
read -p "输入分数: " score

if (( score >= 90 )); then
    echo "A"
elif (( score >= 80 )); then
    echo "B"
elif (( score >= 70 )); then
    echo "C"
elif (( score >= 60 )); then
    echo "D"
else
    echo "F"
fi
```

### 22.5 嵌套 if

```bash
# 例子：检查文件 + 检查大小
if [[ -f /var/log/messages ]]; then
    if [[ -s /var/log/messages ]]; then
        echo "日志存在且非空"
    else
        echo "日志存在但是空的"
    fi
else
    echo "日志不存在"
fi
```

### 22.6 常见陷阱

```bash
# ❌ 错：if 后面直接写命令，没用 [[ ]] 或 test
if ls /root; then
    echo "可以列出"
fi
              # 上面这样写语法对，但语义危险：
              # ls 失败（返回非0）会当成"条件不成立"

# ✅ 对：用 [[ ]] 明确表达
if [[ -d /root ]]; then
    echo "root 是目录"
fi

# ❌ 错：if [[ ]] 里忘记空格
if[[-d /root]]; then
              # bash: syntax error

# ✅ 对：[[ ]] 内必须空格
if [[ -d /root ]]; then
              # ✓ 正确
```

### 22.7 实战：用户管理脚本

```bash
#!/bin/bash
# 批量创建用户

USER_LIST="alice bob charlie"
PASSWORD="default123"

for user in $USER_LIST; do
    if id $user &>/dev/null; then
        echo "✗ $user 已存在，跳过"
    else
        useradd $user
        echo "$user:$PASSWORD" | chpasswd
        echo "✓ $user 创建成功"
    fi
done
```

---

## §23 case 条件语句：通配 + 菜单

### 23.1 语法三要素：case / in / esac

```bash
case "变量值" in
    模式1)
        命令1
        ;;                    # ;; = break
    模式2)
        命令2
        ;;
    *)
        兜底命令
        ;;
esac                          # esac = case 反写
```

### 23.2 最简示例

```bash
#!/bin/bash
# 服务控制

ACTION=$1

case "$ACTION" in
    start)
        systemctl start nginx
        ;;
    stop)
        systemctl stop nginx
        ;;
    restart)
        systemctl restart nginx
        ;;
    status)
        systemctl status nginx
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

### 23.3 通配符（模式部分）

```bash
case "$input" in
    yes|Y|y|Yes|YES)              # 或：匹配其中之一
        echo "同意"
        ;;
    *)
        echo "其他"
        ;;
esac
```

| 模式 | 含义 | 例子 |
|---|---|---|
| `a)` | 精确匹配 `a` | `a)` |
| `[Yy]` | 字符类，匹配 Y 或 y | `[Yy]es)` |
| `*` | 匹配任意 | `*)` 兜底 |
| `?` | 匹配任意单个字符 | `???)` 3 字符 |
| `[0-9]*)` | 数字开头 | — |

### 23.4 case vs if/elif

```bash
# if/elif 版本（3 个分支）
if [[ $cmd == "start" ]]; then
    echo "启动"
elif [[ $cmd == "stop" ]]; then
    echo "停止"
else
    echo "其他"
fi

# case 版本（更清晰）
case "$cmd" in
    start)
        echo "启动"
        ;;
    stop)
        echo "停止"
        ;;
    *)
        echo "其他"
        ;;
esac
```

> 💡 **判断标准**：>2 个分支、变量值匹配时，用 `case`；**条件是范围或复合表达式**用 `if`。

### 23.5 实战：菜单选择

```bash
#!/bin/bash
# 简易计算器

cat << 'EOF'
==== 简易计算器 ====
1) 加法
2) 减法
3) 乘法
4) 除法
q) 退出
EOF

read -p "选择: " choice
read -p "输入 a: " a
read -p "输入 b: " b

case "$choice" in
    1)
        echo "结果: $((a + b))"
        ;;
    2)
        echo "结果: $((a - b))"
        ;;
    3)
        echo "结果: $((a * b))"
        ;;
    4)
        if (( b == 0 )); then
            echo "除数不能为 0"
        else
            echo "结果: $((a / b))"
        fi
        ;;
    q|Q)
        echo "再见"
        exit 0
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac
```

### 23.6 实战：SSH 连接菜单

```bash
#!/bin/bash
# ssh_menu.sh

case "$1" in
    prod)
        ssh admin@prod.example.com
        ;;
    stage)
        ssh admin@stage.example.com
        ;;
    dev)
        ssh dev@dev.example.com
        ;;
    *)
        echo "用法: $0 {prod|stage|dev}"
        exit 1
        ;;
esac
```

---

## §24 while / until 循环：条件在前 vs 条件在后

### 24.1 while 循环（条件为真才循环）

```bash
# 语法
while <条件>; do
    命令
done
```

```bash
# 经典：5 4 3 2 1
#!/bin/bash
i=5
while (( i > 0 )); do
    echo $i
    (( i-- ))
done
```

### 24.2 until 循环（条件为假才循环）

```bash
# 语法
until <条件>; do
    命令
done
```

```bash
# 同样的 5 4 3 2 1
#!/bin/bash
i=5
until (( i == 0 )); do
    echo $i
    (( i-- ))
done
```

### 24.3 while vs until 对比

| 维度 | while | until |
|---|---|---|
| 何时循环 | 条件**为真** | 条件**为假** |
| 结束时机 | 条件**为假** | 条件**为真** |
| 类比 | "当 ... 时做" | "直到 ... 时停" |
| 常用场景 | 监控日志、读取文件 | 重试直到成功 |

### 24.4 死循环（最常用模式）

```bash
# 写法 1：while true
while true; do
    echo "无限循环，Ctrl+C 退出"
    sleep 1
done

# 写法 2：while :
while :; do
    echo "同上，更简洁"
    sleep 1
done

# 写法 3：until false
until false; do
    echo "同上"
    sleep 1
done
```

### 24.5 实战：监控文件变化

```bash
#!/bin/bash
# 监控日志文件

LOG=/var/log/messages
LAST_SIZE=0

while true; do
    CURRENT_SIZE=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
    if (( CURRENT_SIZE != LAST_SIZE )); then
        echo "[$(date)] $LOG 大小变化: $LAST_SIZE -> $CURRENT_SIZE"
        LAST_SIZE=$CURRENT_SIZE
    fi
    sleep 5
done
```

### 24.6 实战：逐行读取文件

```bash
#!/bin/bash
# 逐行读 users.txt 创建用户

while IFS= read -r line; do
    username=$(echo "$line" | cut -d: -f1)
    if id "$username" &>/dev/null; then
        echo "✗ $username 已存在"
    else
        useradd "$username"
        echo "✓ $username 创建成功"
    fi
done < users.txt
```

> 💡 `IFS=` 保留行首行尾空白，`-r` 不转义反斜杠。

### 24.7 实战：重试机制

```bash
#!/bin/bash
# 重试 3 次

ATTEMPTS=0
MAX_ATTEMPTS=3

until ping -c 1 8.8.8.8 &>/dev/null; do
    (( ATTEMPTS++ ))
    if (( ATTEMPTS >= MAX_ATTEMPTS )); then
        echo "网络不通，放弃"
        exit 1
    fi
    echo "尝试 $ATTEMPTS..."
    sleep 5
done

echo "网络通了"
```

### 24.8 实战：猜数字游戏

```bash
#!/bin/bash
# 猜数字 1-100

target=$((RANDOM % 100 + 1))
guess=0

echo "我想了一个 1-100 的数字"

while (( guess != target )); do
    read -p "猜: " guess
    if (( guess > target )); then
        echo "大了"
    elif (( guess < target )); then
        echo "小了"
    fi
done

echo "✓ 猜对了，是 $target"
```

---

## §25 for / select 循环：3 种写法 + 菜单

### 25.1 for 循环的三种语法

```
for 循环 3 种写法：
1) for var in list        ← 列表循环（最常用）
2) for ((i=0; i<10; i++)) ← C 风格
3) for var in "$@"        ← 遍历参数
```

### 25.2 列表循环（最常用）

```bash
# 语法
for 变量 in 列表; do
    命令
done
```

```bash
# 例子 1：打印 1-5
#!/bin/bash
for i in 1 2 3 4 5; do
    echo $i
done
```

```bash
# 例子 2：用 {} 展开序列
for i in {1..5}; do
    echo $i
done
```

```bash
# 例子 3：用 seq
for i in $(seq 1 5); do
    echo $i
done
```

```bash
# 例子 4：遍历文件
for f in /etc/*.conf; do
    echo "处理 $f"
done
```

```bash
# 例子 5：遍历命令结果
for user in $(cut -d: -f1 /etc/passwd); do
    echo "用户: $user"
done | head -5
```

### 25.3 C 风格 for

```bash
# 语法
for ((expr1; expr2; expr3)); do
    命令
done

# expr1: 初始化（只执行一次）
# expr2: 条件（每次循环前判断）
# expr3: 步进（每次循环后执行）
```

```bash
# 例子：1+2+...+100
#!/bin/bash
sum=0
for ((i=1; i<=100; i++)); do
    (( sum += i ))
done
echo "1+2+...+100 = $sum"
# 5050
```

```bash
# 例子：九九乘法表
for ((i=1; i<=9; i++)); do
    for ((j=1; j<=i; j++)); do
        echo -n "$j*$i=$((i*j)) "
    done
    echo
done
```

### 25.4 遍历参数

```bash
# 语法（必须 "$@" 加引号）
for arg in "$@"; do
    echo "参数: $arg"
done
```

```bash
# 调用
[xkw@centos7 ~]$ bash myscript.sh a b c
参数: a
参数: b
参数: c
```

### 25.5 实战：批量重命名

```bash
#!/bin/bash
# 把 .txt 改成 .md

for f in *.txt; do
    [[ -f "$f" ]] || continue       # 防御性编程：没文件跳过
    newname="${f%.txt}.md"          # % 去掉末尾 .txt
    mv "$f" "$newname"
    echo "$f -> $newname"
done
```

### 25.6 实战：批量 ping

```bash
#!/bin/bash
# 批量 ping 主机

HOSTS="192.168.1.1 192.168.1.100 8.8.8.8"

for host in $HOSTS; do
    if ping -c 1 -W 1 $host &>/dev/null; then
        echo "✓ $host 通"
    else
        echo "✗ $host 不通"
    fi
done
```

### 25.7 select 循环（菜单选择）

```bash
# 语法
select 变量 in 列表; do
    命令
done
# 自动生成带编号的菜单
# 用户输入数字赋值给变量
```

```bash
#!/bin/bash
# 简易菜单

select action in "查看时间" "查看用户" "查看磁盘" "退出"; do
    case "$action" in
        "查看时间")
            date
            ;;
        "查看用户")
            whoami
            ;;
        "查看磁盘")
            df -h
            ;;
        "退出")
            break
            ;;
        *)
            echo "无效选择: $REPLY"
            ;;
    esac
done
```

```
运行效果：
1) 查看时间
2) 查看用户
3) 查看磁盘
4) 退出
#? 1
2025年 7月 9日
#? 4
(退出)
```

### 25.8 实战：自动重启脚本

```bash
#!/bin/bash
# 多次尝试启动服务

for try in 1 2 3; do
    if systemctl start nginx; then
        echo "✓ 启动成功（尝试 $try）"
        exit 0
    fi
    echo "✗ 启动失败，等待 5s 重试..."
    sleep 5
done

echo "✗ 3 次都失败"
exit 1
```

---

## §26 循环控制：break / continue / exit / return / $?

### 26.1 四种控制命令

| 命令 | 作用 | 用在哪 | 退出码 |
|---|---|---|---|
| `break` | **跳出当前**循环 | for/while/until | 0（命令本身） |
| `continue` | **跳过本轮**，进入下一轮 | for/while/until | 0 |
| `exit` | **退出整个脚本** | 任何地方 | 后跟数字 |
| `return` | **退出函数** | 函数内 | 后跟数字 |

### 26.2 break 跳出循环

```bash
# 例子：1-10，遇到 5 停
for i in {1..10}; do
    if (( i == 5 )); then
        break
    fi
    echo $i
done
# 输出: 1 2 3 4
```

### 26.3 continue 跳过本轮

```bash
# 例子：1-10，跳过偶数
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    echo $i
done
# 输出: 1 3 5 7 9
```

### 26.4 break n / continue n（跳出多层循环）

```bash
# 例子：4x4 乘法表，遇到结果 >= 20 跳出整个外循环
for ((i=1; i<=4; i++)); do
    for ((j=1; j<=4; j++)); do
        result=$((i*j))
        if (( result >= 20 )); then
            break 2                  # ← 跳出 2 层循环
        fi
        echo -n "$result "
    done
    echo
done
```

### 26.5 exit 退出脚本

```bash
# 例子：参数错就退出
if [[ $# -ne 1 ]]; then
    echo "用法: $0 <file>"
    exit 1                          # ← 退出码 1 表示失败
fi

# 例子：成功退出
if some_command; then
    echo "成功"
    exit 0
fi
```

### 26.6 return 退出函数

```bash
#!/bin/bash
my_func() {
    if [[ -z $1 ]]; then
        echo "参数不能为空"
        return 1                    # ← 退出函数，退出码 1
    fi
    echo "参数: $1"
    return 0
}

my_func
my_func "hello"
```

### 26.7 退出码 $? 详解

```bash
# 0 = 成功，其他 = 失败
# 自定义退出码：0-255

# 例子：检查服务
if systemctl is-active nginx &>/dev/null; then
    echo "运行中"
    exit 0
else
    echo "未运行"
    exit 3                          # 退出码 3：服务未运行
fi
```

| 退出码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 通用错误 |
| 2 | 命令错用（Shell 内置） |
| 126 | 命令找到但不能执行 |
| 127 | 命令找不到 |
| 128+N | 被信号 N 终止（130 = Ctrl+C = 128+2） |
| 130 | Ctrl+C 终止 |
| 137 | SIGKILL（kill -9） |

### 26.8 实战：菜单跳出多层

```bash
#!/bin/bash
# 外层菜单 + 内层操作

while true; do
    echo "==== 主菜单 ===="
    echo "1) 操作 A"
    echo "2) 操作 B"
    echo "q) 退出"
    read -p "选择: " choice

    case "$choice" in
        1)
            # 子操作
            for i in 1 2 3; do
                echo "A-$i"
                read -p "继续? (y/n): " yn
                [[ $yn == "n" ]] && break
            done
            ;;
        2)
            echo "执行 B"
            ;;
        q|Q)
            break 2                  # 跳出外层 while
            ;;
        *)
            echo "无效"
            ;;
    esac
done
```

### 26.9 实战：批量处理 + 错误处理

```bash
#!/bin/bash
# 处理一批文件，遇到错误就停止

set -e                              # 任何命令失败就退出（见 §29）

for file in /data/*.csv; do
    [[ -f "$file" ]] || continue
    if ! process_file "$file"; then
        echo "处理失败: $file"
        exit 1
    fi
    echo "✓ 处理成功: $file"
done

echo "全部完成"
```

---

## §27 Shell 函数：定义/参数/返回值/递归/作用域

### 27.1 函数定义（两种写法）

```bash
# 写法 1：function 关键字
function func_name() {
    ...
    return n
}

# 写法 2：直接定义（推荐）
func_name() {
    ...
    return n
}
```

### 27.2 函数调用

```bash
#!/bin/bash
greet() {
    echo "Hello, $1!"
}

greet "World"         # 输出: Hello, World!
greet "CentOS"        # 输出: Hello, CentOS!
```

### 27.3 函数参数

```bash
#!/bin/bash
# 函数参数也是 $1, $2, ..., $#

add() {
    local a=$1
    local b=$2
    echo $((a + b))
}

result=$(add 3 5)
echo "3 + 5 = $result"
# 输出: 3 + 5 = 8
```

### 27.4 返回值（return vs echo）

```bash
# return：返回退出码（0-255），用于"成功/失败"判断
check_service() {
    if systemctl is-active nginx &>/dev/null; then
        return 0                    # 成功
    else
        return 1                    # 失败
    fi
}

if check_service; then
    echo "服务运行中"
else
    echo "服务未运行"
fi
```

```bash
# echo：返回数据，用于传值
get_user_home() {
    local user=$1
    grep "^$user:" /etc/passwd | cut -d: -f6
}

home=$(get_user_home "root")
echo "root 家目录: $home"
# 输出: /root
```

| 方式 | 用途 | 取值方法 |
|---|---|---|
| `return n` | 返回**退出码**（0-255） | `$?` |
| `echo 数据` | 返回**任意数据**（含字符串、数组） | `$(func)` |

### 27.5 变量作用域

```bash
# 默认：全局变量
g_var=1
modify() {
    g_var=2                        # 改全局
}
modify
echo $g_var
# 输出: 2

# local：局部变量（推荐）
g_var=1
modify() {
    local g_var=2                  # 只在函数内有效
}
modify
echo $g_var
# 输出: 1                          # 全局没被改
```

> 💡 **黄金法则**：函数内**所有变量都用 `local`**，避免污染全局。

### 27.6 递归函数

```bash
# 例子：阶乘
factorial() {
    local n=$1
    if (( n <= 1 )); then
        echo 1
    else
        local sub=$((n - 1))
        local result=$(factorial $sub)
        echo $((n * result))
    fi
}

factorial 5
# 输出: 120                       # 5! = 5*4*3*2*1
```

### 27.7 函数库（库文件）

```bash
# /etc/myfuncs.sh
log() {
    echo "[$(date '+%F %T')] $*"
}

check_root() {
    if (( EUID != 0 )); then
        log "需要 root 权限"
        exit 1
    fi
}
```

```bash
# 主脚本
#!/bin/bash
source /etc/myfuncs.sh             # 加载函数库

check_root
log "开始执行"
```

### 27.8 实战：日志函数库

```bash
#!/bin/bash
# 完整日志函数

LOG_FILE="/var/log/mylog_$(date +%Y%m).log"

log_info() {
    local msg="[INFO] [$(date '+%F %T')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

log_warn() {
    local msg="[WARN] [$(date '+%F %T')] $*"
    echo "$msg" | tee -a "$LOG_FILE" >&2
}

log_error() {
    local msg="[ERROR] [$(date '+%F %T')] $*"
    echo "$msg" | tee -a "$LOG_FILE" >&2
}

# 用法
log_info "脚本启动"
log_warn "磁盘使用率 80%"
log_error "备份失败"
```

### 27.9 实战：部署脚本

```bash
#!/bin/bash
# deploy.sh

APP_NAME="myapp"
APP_DIR="/opt/$APP_NAME"
BACKUP_DIR="/backup"

backup() {
    local ts=$(date +%Y%m%d_%H%M%S)
    log_info "备份 $APP_DIR 到 $BACKUP_DIR/$APP_NAME-$ts.tar.gz"
    tar czf "$BACKUP_DIR/$APP_NAME-$ts.tar.gz" -C "$APP_DIR" .
}

deploy() {
    log_info "部署新版本到 $APP_DIR"
    # 实际部署逻辑...
}

main() {
    check_root
    log_info "=== 部署开始 ==="
    backup
    deploy
    log_info "=== 部署完成 ==="
}

main "$@"
```

---

## §28 Shell 数组：普通数组 + 关联数组

### 28.1 三种数组定义方式

```bash
# 方式 1：括号 + 空格分隔（推荐）
array=(val1 val2 val3)

# 方式 2：单独赋值
array[0]=a
array[1]=b
array[2]=c

# 方式 3：指定索引（可跳号）
array=([0]=one [2]=three [5]=five)
```

### 28.2 数组访问

```bash
# 定义
array=(a b c d e)

# 单个元素
echo ${array[0]}                   # a（0-based）
echo ${array[2]}                   # c

# 全部元素
echo ${array[@]}                   # a b c d e
echo ${array[*]}                   # a b c d e

# 数组长度
echo ${#array[@]}                  # 5

# 单个元素长度
echo ${#array[0]}                  # 1（"a" 长度）
```

### 28.3 数组遍历

```bash
array=(a b c d e)

# 方式 1：标准
for x in "${array[@]}"; do
    echo "$x"
done

# 方式 2：带下标
for i in "${!array[@]}"; do
    echo "$i: ${array[$i]}"
done
# 0: a
# 1: b
# 2: c
# ...
```

> ⚠️ `"${array[@]}"` **必须加双引号**，否则含空格的元素会被切碎。

### 28.4 数组操作

```bash
array=(a b c d e)

# 切片（从索引 1 开始取 2 个）
echo ${array[@]:1:2}               # b c

# 替换（临时）
echo ${array[@]/b/B}               # a B c d e（原数组不变）

# 追加元素
array+=(f g)
echo ${array[@]}                   # a b c d e f g

# 删除元素
unset array[2]
echo ${array[@]}                   # a b d e f g（c 没了）

# 清空
unset array
echo ${array[@]}                   # 空
```

### 28.5 命令结果赋值给数组

```bash
# 把 /etc/passwd 用户名放进数组
mapfile -t users < <(cut -d: -f1 /etc/passwd)
echo "用户数: ${#users[@]}"
echo "第一个: ${users[0]}"          # root

# 旧写法（兼容性更好）
users=($(cut -d: -f1 /etc/passwd))
```

### 28.6 关联数组（key-value，需声明）

```bash
# 声明
declare -A user_info

# 赋值
user_info[name]="Alice"
user_info[age]=30
user_info[city]="Beijing"

# 访问
echo ${user_info[name]}            # Alice
echo ${user_info[age]}             # 30

# 遍历
for key in "${!user_info[@]}"; do
    echo "$key = ${user_info[$key]}"
done
# city = Beijing
# age = 30
# name = Alice
```

### 28.7 实战：统计日志 IP 出现次数

```bash
#!/bin/bash
# 统计 access.log 中 IP 出现次数

declare -A ip_count
mapfile -t lines < access.log

for line in "${lines[@]}"; do
    ip=$(echo "$line" | awk '{print $1}')
    (( ip_count[$ip]++ ))
done

# 打印前 10
for ip in "${!ip_count[@]}"; do
    echo "$ip ${ip_count[$ip]}"
done | sort -k2 -rn | head -10
```

### 28.8 实战：参数数组

```bash
#!/bin/bash
# 把所有参数原样传给另一个命令

# 调用：bash myscript.sh -v --name "foo bar" -f file.txt
# 期望：把全部参数转发给 inner_cmd

inner_cmd "$@"
```

### 28.9 数组 vs 字符串

```bash
# ❌ 错：把多个值塞进字符串
files="file1.txt file2.txt file3.txt"
for f in $files; do                # 不加引号 = 按空格切
    echo $f
done
# 文件名含空格就崩了

# ✅ 对：用数组
files=("file 1.txt" "file 2.txt" "file 3.txt")
for f in "${files[@]}"; do         # 加引号 = 整体保留
    echo "[$f]"
done
# [file 1.txt]
# [file 2.txt]
# [file 3.txt]
```

---

## §29 Shell 脚本调试：bash -x / set -x / set -e

### 29.1 常见错误类型

```
Shell 脚本错误 = 3 大类：
1) 语法错误（Syntax Error）：脚本根本跑不起来
2) 命令错误（Command Error）：命令不存在或参数错
3) 逻辑错误（Logic Error）：能跑但结果不对
```

### 29.2 语法错误示例

```bash
#!/bin/bash
# 错例 1：if 忘了 fi
if [ 10 -gt 2 ];then
    echo Yes
# 跑：
[xkw@centos7 ~]$ bash debug1.sh
debug1.sh: line 5: syntax error: unexpected end of file
# 修：加 fi

# 错例 2：for 写了 d 不是 do
for i in 1 2 3
d
    echo $i
done
# 跑：
[xkw@centos7 ~]$ bash debug2.sh
debug2.sh: line 3: syntax error near unexpected token `d'
debug2.sh: line 3: `d'
# 修：把 d 改成 do

# 错例 3：[ ] 缺右括号
if [ 10 -gt 2 ;then
    echo Yes
fi
# 跑：
[xkw@centos7 ~]$ bash debug3.sh
debug3.sh: line 2: [: missing `]'
# 修：加 ]

# 错例 4：字符串没闭合
echo "Yes
echo "No"
# 跑：
[xkw@centos7 ~]$ bash debug4.sh
debug4.sh: line 3: unexpected EOF while looking for matching `"'
# 修：补齐引号
```

### 29.3 三种调试模式

```bash
# 1) bash -x：显示执行的每条命令（最常用）
[xkw@centos7 ~]$ bash -x debug1.sh
+ '[' 10 -gt 2 ']'                  # 显示 + 开头是实际执行的
+ echo Yes
Yes

# 2) bash -v：显示读到的每行（不执行）
[xkw@centos7 ~]$ bash -v debug1.sh
if [ 10 -gt 2 ];then                # 直接显示源码
    echo Yes
fi
+ '[' 10 -gt 2 ']'
+ echo Yes
Yes

# 3) bash -n：只检查语法，不执行
[xkw@centos7 ~]$ bash -n debug1.sh
                                  # 静默通过 = 语法对
[xkw@centos7 ~]$ bash -n debug2.sh
debug2.sh: line 3: syntax error near unexpected token `d'
                                  # 报错 = 语法错
```

### 29.4 set 命令（脚本内启用调试）

```bash
#!/bin/bash
# 在脚本内启用调试

set -x                              # 开启 -x 模式
i=1
echo $i
set +x                              # 关闭 -x 模式
i=2
echo $i
```

```bash
# 输出：
+ i=1
+ echo 1
1
+ set +x
2                                  # 关闭后不再显示
```

### 29.5 严格模式（生产脚本必加）

```bash
#!/bin/bash
# 严格模式

set -e                              # 任何命令失败（退出码非0）就退出
set -u                              # 引用未定义变量就报错
set -o pipefail                     # 管道里任一失败就算失败
```

```bash
# 演示 set -e
set -e
ls /nonexistent                    # 这条失败
echo "这行不会执行"                  # 脚本直接退出
```

```bash
# 演示 set -u
set -u
echo $UNDEFINED_VAR                 # 报错退出
```

```bash
# 演示 set -o pipefail（默认只检查最后一个命令）
# 没有 pipefail：
false | true                       # 退出码 0（只看最后一个 true）

# 有 pipefail：
set -o pipefail
false | true                       # 退出码 1（false 失败）
```

> 💡 **黄金组合**：脚本开头写 `set -euo pipefail`（实际就是 `set -e -u -o pipefail`）。

### 29.6 实战：使用 trap 调试

```bash
#!/bin/bash
# 退出时打印调试信息

trap 'echo "ERROR: 脚本在第 $LINENO 行失败，命令: $BASH_COMMAND"' ERR

set -e

# 模拟失败
ls /nonexistent
```

```bash
# 输出：
ls: cannot access '/nonexistent': No such file or directory
ERROR: 脚本在第 8 行失败，命令: ls /nonexistent
```

### 29.7 调试清单

| 症状 | 排查 |
|---|---|
| `syntax error: unexpected end of file` | 缺 `fi` `done` `}` `esac` |
| `syntax error near unexpected token` | 多写了符号、少了空格、关键字拼错 |
| `[: missing ]` | `[` 后面没配对 `]` |
| `command not found` | 命令没装、PATH 不对、绝对路径 |
| `Permission denied` | 没 `chmod +x`、没 `sudo` |
| `bash: $VAR: unbound variable` | 开了 `set -u` + VAR 未定义 |
| 逻辑结果不对 | 加 `set -x` 逐行查 |

---

## §30 编程篇速查表

### 30.1 第一个脚本

```bash
#!/bin/bash
# 注释
chmod +x script.sh
./script.sh                          # 需要 +x
bash script.sh                       # 不需要 +x
source script.sh                     # 当前 Shell 执行
```

### 30.2 位置参数

```
$0    脚本名
$1-$9 第 1-9 个参数
${10} 第 10+ 个参数（必须大括号）
$#    参数个数
$*    全部参数（不带引号时同 $@）
$@    全部参数（带引号时保留原样）
$$    当前 PID
$!    上一个后台 PID
$?    上一命令退出码
```

### 30.3 数值计算

| 场景 | 写法 |
|---|---|
| 整数 | `$((1+2))` |
| 浮点 | `echo "1.5*2" \| bc -l` |
| 自增 | `((i++))` |
| 复杂 | `awk 'BEGIN{print 1.5*2}'` |

### 30.4 条件测试

```bash
[[ -f file ]]                        # 文件存在且是普通文件
[[ -d dir ]]                         # 目录存在
[[ -z "$str" ]]                      # 字符串空
[[ "$a" == "$b" ]]                   # 字符串相等
[[ "$a" =~ ^[0-9]+$ ]]               # 正则匹配
(( a > b ))                          # 整数比较
```

### 30.5 if / case

```bash
if [[ condition ]]; then
    ...
elif [[ condition ]]; then
    ...
else
    ...
fi

case "$var" in
    pattern1) ... ;;
    pattern2) ... ;;
    *) ... ;;
esac
```

### 30.6 循环

```bash
while condition; do ... done
until condition; do ... done
for var in list; do ... done
for ((i=0; i<n; i++)); do ... done
select var in list; do ... done
```

### 30.7 循环控制

```
break n      跳出 n 层循环
continue n   跳过本轮，进入 n 层外下一轮
exit n       退出脚本，退出码 n
return n     退出函数，退出码 n
```

### 30.8 函数

```bash
func_name() {
    local var=value                  # 局部变量
    return n                         # 退出码
    echo "data"                      # 输出数据
}

result=$(func_name arg1 arg2)        # 捕获输出
func_name arg1 arg2                  # 不捕获
```

### 30.9 数组

```bash
arr=(a b c)                          # 定义
arr[0]=x                             # 赋值
echo ${arr[0]}                        # 访问
echo ${arr[@]}                       # 全部
echo ${#arr[@]}                      # 长度
echo ${arr[@]:1:2}                   # 切片
arr+=(d)                             # 追加
unset arr[2]                         # 删除元素
for x in "${arr[@]}"; do ... done   # 遍历
declare -A map                       # 关联数组
map[key]=value                       # 关联数组赋值
```

### 30.10 调试

```bash
bash -x script.sh                    # 跟踪执行
bash -n script.sh                    # 只检查语法
bash -v script.sh                    # 显示源码
set -euo pipefail                    # 严格模式
set -x                                # 脚本内开启跟踪
set +x                                # 脚本内关闭跟踪
trap 'echo $LINENO $BASH_COMMAND' ERR # 出错打印
```

---

## §31 编程篇易错点 ×15

### 1. ❌ `if` 后直接用命令不加 `[ ]`

```bash
if ls /root; then                    # ⚠️ 能用但危险
    echo "ok"
fi
# 改：if [[ -d /root ]]; then
```

### 2. ❌ `if[[ ...]]` 没空格

```bash
if[[-d /root]]; then                 # ⚠️ syntax error
# 改：if [[ -d /root ]]; then        # 关键字内部必须有空格
```

### 3. ❌ `[ ]` 里变量不加引号

```bash
name=""
[ $name == "abc" ]                   # ⚠️ [: argument expected
# 改：[ "$name" == "abc" ]
```

### 4. ❌ `[[ ]]` 里用 `-a -o`

```bash
[[ -f file -a -r file ]]            # ⚠️ bash 警告
# 改：[[ -f file && -r file ]]
```

### 5. ❌ 忘了 `;;` 漏写 case 分支结尾

```bash
case "$x" in
    a) echo "a"
    b) echo "b" ;;                   # ⚠️ 上面 a 分支没 ;;
esac
```

### 6. ❌ for 循环变量忘了双引号

```bash
for f in $files; do                  # ⚠️ 文件名含空格崩
    echo $f
done
# 改：for f in "${files[@]}"; do
```

### 7. ❌ `for ((;;))` 用 bash 关键字

```bash
for i in {1..10}; do ((i++))         # ⚠️ i 自增混乱
done
# 改：用 C 风格 for ((i=0; i<10; i++))
```

### 8. ❌ while 写 `if` 那种条件

```bash
while [[ $count -lt 10 ]]; do        # 严格说没问题
    ...
done
# 但 (( count < 10 )) 更简洁
```

### 9. ❌ 函数参数 $1 与脚本参数 $1 混淆

```bash
#!/bin/bash
func() {
    echo $1                          # ← 这是函数的 $1
}
func "hello"                         # 函数调用
echo $1                              # ← 这是脚本的 $1
# 两者不冲突，$1 在不同上下文
```

### 10. ❌ 函数改全局变量

```bash
counter=0
increment() {
    counter=$((counter+1))           # ⚠️ 改全局
}
# 改：local counter=0; counter=$((counter+1))
```

### 11. ❌ `return` 范围超过 0-255

```bash
func() {
    return 1000                      # ⚠️ 实际只返回 1000%256=232
}
```

### 12. ❌ 数组下标越界

```bash
arr=(a b c)
echo ${arr[5]}                       # 输出空，不会报错
# 检查：if [[ ${arr[5]:-empty} == "empty" ]]; then echo "空"; fi
```

### 13. ❌ `set -e` 配合 `if` 失效

```bash
set -e
if false; then                       # 故意失败
    echo "won't print"
fi
echo "继续"                          # ⚠️ 实际"继续"会打印
# 原因：if 里的失败不算 set -e 的失败
```

### 14. ❌ `set -e` 不接管道

```bash
set -e
false | true                        # ⚠️ 退出码 0（只看最后一个）
# 改：set -euo pipefail
```

### 15. ❌ 调试时把生产脚本设成 -x 忘了关

```bash
#!/bin/bash
set -x                              # ⚠️ 生产脚本会刷屏
...                                 # 调试完必须改回 set +x 或删除
```

---

## §32 编程篇面试 8 大追问

### Q1：`(())`、`$(( ))`、`$[]` 三个有什么区别？

**答**：
- `(())`：**纯计算/赋值**，不输出，`i=$((1+1))` 才是赋值并输出
- `$(( ))`：**计算并返回结果**，`echo $((1+2))` → 3
- `$[]`：**老语法**（POSIX 不支持），`echo $[1+2]` → 3

```bash
i=5
(( i=i+1 ))                          # 改 i 为 6，不输出
echo $(( i+1 ))                      # 输出 7
echo $[ i+1 ]                        # 输出 7（旧写法）
```

### Q2：`$*` 和 `$@` 区别？什么时候必须加引号？

**答**：
- **不加引号**：两者一样（按空格切）
- **加双引号**：`"$*"` 是 1 个整体，`"$@"` 是 N 个独立

**遍历参数永远用 `for x in "$@"`**。

### Q3：`break 2` 是什么意思？

**答**：跳出**2 层**循环。`break n` 跳 n 层，`continue n` 同理。

### Q4：`exit`、`return`、`exit code` 关系？

**答**：
- `exit n` 退出**整个脚本**，n 变成 `$?`
- `return n` 退出**函数**，n 变成函数的 `$?`
- `$?` 是**上一条命令**的退出码（0-255）

```bash
func() { return 1; }
func
echo $?                              # 1
```

### Q5：`set -e` 和 `set -u` 区别？

**答**：
- `set -e`：**命令失败**（退出码非 0）就退出
- `set -u`：**未定义变量**就报错

**黄金组合**：`set -euo pipefail`。

### Q6：什么时候用 `[[ ]]` vs `[ ]`？

**答**：
- **`[[ ]]`**：bash 脚本，**新代码**默认
- **`[ ]`**：POSIX sh，跨平台脚本
- **`(())`**：**整数**比较专用

### Q7：函数怎么返回字符串/数组？

**答**：
- 用 `echo` 输出，调用时用 `$(func)` 捕获
- `return` 只能返回 0-255 退出码

```bash
get_files() {
    echo "a.txt b.txt c.txt"
}
files=$(get_files)                   # 字符串
arr=($(get_files))                   # 数组
```

### Q8：`source` 和 `bash` 区别？

**答**：
- `bash script.sh`：**子 Shell** 执行，变量不影响当前 Shell
- `source script.sh`（= `. script.sh`）：**当前 Shell** 执行，变量影响当前 Shell

**典型用途**：`source /etc/profile` 加载环境变量。

---

## §33 完整 Shell 基础总链路

```
E:\Linux\LinuxShell\shell.md（本文件）
├── 变量篇（§1-17）
│   ├── §1-3  自定义变量/变量拼接/环境变量
│   ├── §4-5  常用环境变量/PATH 详解
│   ├── §6-7  PS1/HISTTIMEFORMAT
│   ├── §8    启动文件加载顺序
│   ├── §9    命令替换 $(cmd)
│   ├── §10   算术 $[1+2]
│   ├── §11-12 引号转义/多行 echo
│   └── §13-17 速查表/易错点/面试/链路
│
└── 编程篇（§18-32）
    ├── §18   第一个脚本
    ├── §19   位置参数 $0 $1 ... $@ $?
    ├── §20   数值计算 7 武器
    ├── §21   条件测试 4 语法
    ├── §22-23 if / case
    ├── §24-25 while / until / for / select
    ├── §26   循环控制 break/continue/exit/return
    ├── §27   函数
    ├── §28   数组
    ├── §29   调试 bash -x / set
    └── §30-32 速查表/易错点/面试
```

### 与其他笔记的链路

| 笔记 | 关系 |
|---|---|
| [[linux-getting-help]] | `man bash` 查所有语法细节 |
| [[Linux目录/目录的使用]] | 路径在脚本里到处用 |
| [[Linux目录/目录的权限]] | 脚本无 `chmod +x` 跑不了 |
| [[Linux文本处理/输入输出重定向]] | `>` `>>` `<` `<<` `<<<` 在脚本里高频 |
| [[Linux文本处理/grep]] | 脚本里 `grep` 处理文本 |
| [[Linux文本处理/sed]] | 脚本里 `sed` 替换 |
| [[Linux文本处理/awk]] | 脚本里 `awk` 取列 |
| [[Linux文本处理/辅助工具]] | `xargs` 配合 `read`、cut/sort/uniq/wc |
| [[Linux编辑器/vim]] | 用 vim 写脚本、`.vimrc` 缩进 |
| [[#§21 条件测试]] | 4 种语法对比表 |
| [[#§26 循环控制]] | 5 种退出方式 |

### 实战组合（脚本 + 文本三剑客）

```bash
#!/bin/bash
# 统计 access.log 状态码分布

if [[ ! -f access.log ]]; then
    echo "文件不存在"
    exit 1
fi

echo "状态码分布："
awk '{print $9}' access.log | sort | uniq -c | sort -rn
```

**下一步**：本笔记已涵盖"完整 Shell 编程"。后续可学习：
- 19. 企业 Shell 面试题（PDF 19）— 真实场景
- 17. trap 信号处理（PDF 17）— 高级技巧
- 18. Expect 自动交互（PDF 18）— 自动化登录

→ 配合 [[Linux编辑器/vim]]、[[Linux文本处理/awk]] 实战：写一个"日志分析脚本"项目。
