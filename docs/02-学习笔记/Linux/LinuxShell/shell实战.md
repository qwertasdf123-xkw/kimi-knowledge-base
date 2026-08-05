---
title: Shell 编程实战
desc: 21 个企业级 Shell 实战主题 - 创建脚本/特殊变量/数值计算/条件测试/IF/CASE/函数/循环/数组/规范/调试/vimrc/signal trap/Expect/面试题/子Shell 等
type: 笔记
module: LinuxShell
pdfs:
  - 09.shell编程实战/shell 编程实战/1.为什么要学习 Shell 编程.pdf (~280 KB)
  - 09.shell编程实战/shell 编程实战/2.创建第一个 Shell 脚本.pdf (~370 KB)
  - 09.shell编程实战/shell 编程实战/3.Shell 变量基础知识.pdf (~490 KB)
  - 09.shell编程实战/shell 编程实战/4.Shell 变量进阶知识.pdf (~430 KB)
  - 09.shell编程实战/shell 编程实战/5.Shell 数值计算实践.pdf (~320 KB)
  - 09.shell编程实战/shell 编程实战/6.Shell 脚本的条件测试与比较.pdf (~470 KB)
  - 09.shell编程实战/shell 编程实战/7.IF 条件语句的知识与实践.pdf (~660 KB)
  - 09.shell编程实战/shell 编程实战/8.Shell 函数的知识与实践.pdf (~290 KB)
  - 09.shell编程实战/shell 编程实战/9.CASE 条件语句的应用实践.pdf (~350 KB)
  - 09.shell编程实战/shell 编程实战/10.WHILE 循环和 UNTIL 循环的应用实践.pdf (~590 KB)
  - 09.shell编程实战/shell 编程实战/11.FOR 和 SELECT 循环语句的应用实践.pdf (~1.1 MB)
  - 09.shell编程实战/shell 编程实战/12.循环控制及状态返回值的应用实践.pdf (~640 KB)
  - 09.shell编程实战/shell 编程实战/13.Shell 数组的应用实践.pdf (~340 KB)
  - 09.shell编程实战/shell 编程实战/14.Shell 脚本开发规范.pdf (~360 KB)
  - 09.shell编程实战/shell 编程实战/15.Shell 脚本的调试.pdf (~380 KB)
  - 09.shell编程实战/shell 编程实战/16.Shell 脚本开发环境的配置和优化实践.pdf (~200 KB)
  - 09.shell编程实战/shell 编程实战/17.Linux 信号及 trap 命令的企业应用实践.pdf (~280 KB)
  - 09.shell编程实战/shell 编程实战/18.Expect 自动化交互式程序应用实践.pdf (~460 KB)
  - 09.shell编程实战/shell 编程实战/19.企业 Shell 面试题及企业运维实战案例.pdf (~310 KB)
  - 09.shell编程实战/shell 编程实战/20.子 Shell 及 Shell 嵌套模式知识应用.pdf (~470 KB)
  - 09.shell编程实战/shell 编程实战/21. 附录 Linux 重要命令汇总.pdf (~360 KB)
pdf_size: ~9 MB
scope: 企业 Shell 编程实战 21 主题（基础 + 进阶 + 高级）
status: 完成
---

# Shell 编程实战

> **范围说明**：本笔记基于 `09.shell编程实战/shell 编程实战/` 目录下 21 个企业 PDF（约 9 MB）实战整理。
> 与 [[shell|shell.md]]（变量基础）和 [[practice|practice.md]]（12 道变量练习）形成互补。
> 重点覆盖 **新主题**：脚本创建、特殊变量、数值计算、条件测试、IF/CASE/函数/循环/数组、规范、调试、vimrc、信号 trap、Expect、面试题、子 Shell。
> 变量基础（`$var`/`${}`/`export`/PATH 等）**不在此笔记范围**，详见 [[shell]]。

## 目录

- [[#§0 心智模型：Shell 脚本 = 运维自动化的瑞士军刀]]
- [[#§1 为什么要学习 Shell 编程（PDF 1）]]
- [[#§2 创建第一个 Shell 脚本（PDF 2）]]
- [[#§3 Shell 变量基础与进阶速补（PDF 3-4）]]
- [[#§4 Shell 数值计算（PDF 5）]]
- [[#§5 Shell 条件测试与比较（PDF 6）]]
- [[#§6 IF 条件语句（PDF 7）]]
- [[#§7 Shell 函数（PDF 8）]]
- [[#§8 CASE 条件语句（PDF 9）]]
- [[#§9 WHILE / UNTIL 循环（PDF 10）]]
- [[#§10 FOR / SELECT 循环（PDF 11）]]
- [[#§11 循环控制及状态返回值（PDF 12）]]
- [[#§12 Shell 数组（PDF 13）]]
- [[#§13 Shell 脚本开发规范（PDF 14）]]
- [[#§14 Shell 脚本调试（PDF 15）]]
- [[#§15 vimrc 脚本开发环境配置（PDF 16）]]
- [[#§16 Linux 信号及 trap 命令（PDF 17）]]
- [[#§17 Expect 自动化交互（PDF 18）]]
- [[#§18 企业 Shell 面试题（PDF 19）]]
- [[#§19 子 Shell 及 Shell 嵌套模式（PDF 20）]]
- [[#§20 Linux 重要命令汇总（PDF 21）]]
- [[#§21 21 主题速查表]]
- [[#§22 易错点 ×15（跨章节汇总）]]
- [[#§23 面试 8 大追问（综合）]]
- [[#§24 与其他笔记的链路]]

---

## §0 心智模型：Shell 脚本 = 运维自动化的瑞士军刀

```
人类运维         Shell 脚本（.sh）         Linux 系统
  |                  |                       |
  |-- "每天备份" --> |                       |
  |                  |-- tar + crontab ---->|
  |                  |<-- done -------------|
  |                  |-- mail --------------|
  |<-- 邮件通知 ----|                        |
```

**Shell 脚本的角色**：把"重复的人工命令序列"封进一个文件，让 `bash script.sh` 一次跑完。
企业运维 80% 重复操作（备份、监控、部署、巡检）都可以用 Shell 脚本自动化。

**21 主题的演进路径**：

```
变量基础 (shell.md)  ──→  实战（shell实战.md）
                             │
   ┌─────────────────────────┼────────────────────────┐
   ↓                         ↓                        ↓
 流程控制                 函数/数组/调试           高级特性
 (IF/CASE/循环)                                     (signal/Expect/子Shell)
   ↓                         ↓                        ↓
 简单脚本                可维护脚本               企业级脚本
```

> 💡 **一句话**：变量是便利贴，控制流是逻辑，函数是工具箱，调试是放大镜，signal/Expect/子Shell 是高阶武器。

---

## §1 为什么要学习 Shell 编程（PDF 1）

### 1.1 什么是 Shell

Shell 是命令解释器，负责：
- 接收用户输入的命令
- 把命令解释给操作系统内核
- 把内核返回的结果"翻译"给用户

**常见 Shell 类型**：

| 类别 | 名称 | 适用系统 |
|---|---|---|
| Bourne 系 | sh、ksh、bash（默认） | Linux 用 bash |
| C 系 | csh、tcsh | BSD、macOS |

> 💡 CentOS/RHEL 默认 Shell 是 bash，本笔记所有内容基于 bash。

### 1.2 什么是 Shell 脚本

把多条命令、变量、流程控制语句写进文件，交给 bash 一次性执行 = 非交互式 = 批处理。

类似 Windows 的 `.bat`，但强大得多。

### 1.3 为什么企业必须学 Shell

Linux 几乎所有配置/日志/启动文件都是纯文本（NFS、Rsync、Httpd、Nginx、LVS、MySQL），Shell 是处理纯文本的最佳工具。

**典型企业场景**：
- 检查多台服务器运行状态
- 自动化部署/升级各种服务
- 日志切割、备份、清理
- 服务健康检查 + 告警

### 1.4 学好 Shell 的基础

1. 熟练 vim，配置 `.vimrc`
2. Linux 常用命令
3. 三剑客（grep、sed、awk）
4. 正则表达式
5. 常见服务部署

### 1.5 学好 Shell 的方法

> **多练习—多思考—多总结—再练习—再思考—再总结**（循环）

老马建议：
1. 掌握基本语法
2. 从简单做起（简单判断、简单循环）
3. 多模仿、多练习、多思考
4. 变量命名用驼峰
5. 不要照抄，吸收后自己写
6. 形成自己的风格

### 1.6 Shell 脚本语言的种类

Shell 是**弱类型语言**（无须定义类型即可用）。两大类：
- **Bourne shell**：sh、ksh、bash
- **C shell**：csh、tcsh

---

## §2 创建第一个 Shell 脚本（PDF 2）

### 2.1 脚本结构三件套

```bash
#!/bin/bash        # 1. 幻数（shebang）—— 必须在第一行
# Date: 2026-07-14
# Author: laoma
# Description: 第一个 Shell 脚本
echo "Hello World !"
```

> ⚠️ `#!` 必须在第一行，否则就是注释。CentOS 默认 bash，不写也能跑，但**规范必须写**。

### 2.2 脚本的 4 种执行方式

| 方式 | 是否新开进程 | 变量是否可传递 |
|---|---|---|
| `bash script.sh` | 新开 | 不传递 |
| `./script.sh` 或 `/path/script.sh` | 新开 | 不传递 |
| `source script.sh` 或 `. script.sh` | **不开**（当前 Shell 执行） | **传递** |
| `bash < script.sh` | 新开 | 不传递 |

> 💡 **核心区别**：`source/.` 在父 Shell 执行，变量/函数留在当前 Shell；其他方式都在子 Shell。

```bash
# 写第一个脚本
[laoma@centos7 ~]$ vim script.sh
#!/bin/bash
echo "Hello World !"

# 方式 1：bash 执行
[laoma@centos7 ~]$ bash script.sh
Hello World!

# 方式 2：加执行权限 + 路径
[laoma@centos7 ~]$ chmod +x script.sh
[laoma@centos7 ~]$ ./script.sh
Hello World !

# 方式 3：source 执行
[laoma@centos7 ~]$ source script.sh
Hello World !
[laoma@centos7 ~]$ . script.sh
Hello World !

# 方式 4：重定向
[laoma@centos7 ~]$ bash < script.sh
Hello World !
[laoma@centos7 ~]$ cat script.sh | bash
Hello World !
```

### 2.3 开发规范

1. **第一行指定解释器**：`#!/bin/bash`
2. **开头加版本/版权**（用 vimrc 自动添加）
3. **注释用英文**（避免中文乱码）
4. **扩展名 `.sh`**
5. **统一目录**：`/server/scripts/`
6. **成对符号一次写完**：`{}`、`[]`、`''`、`""`、```` `` ````
7. **中括号两端留空格**：`[ "$var" ]`
8. **流程控制一次写完再填内容**：
   ```bash
   if 条件; then
       指令
   fi
   ```
9. **缩进**（推荐 2 空格或 TAB）
10. **变量赋值用双引号**：`name="test.txt"`、`week_day="$(date +%A)"`、`welcome_string='******'`
11. **所有符号必须英文状态**

### 2.4 bash 与 sh 的区别

`/bin/sh` 是 `/bin/bash` 的软链。绝大多数脚本通用，但更规范写 `#!/bin/bash`。

---

## §3 Shell 变量基础与进阶速补（PDF 3-4）

> 本节快速回顾 [[shell|shell.md]] 已讲内容，补充新主题：**特殊变量 + 变量子串 + 特殊扩展变量**。

### 3.1 特殊变量速查（PDF 4 重点）

| 变量 | 含义 |
|---|---|
| `$0` | 当前脚本名（含路径） |
| `$1` ~ `$9` | 第 1 ~ 9 个参数 |
| `${10}` | 第 10+ 个参数必须用大括号 |
| `$#` | 参数个数 |
| `$*` | 所有参数（`"$*"` = 单字符串） |
| `$@` | 所有参数（`"$@"` = 多字符串，**推荐传参方式**） |
| `$?` | 上一个命令的退出状态（0=成功，非0=失败） |
| `$$` | 当前 Shell 的 PID |
| `$!` | 上一个后台进程的 PID |
| `$_` | 上一条命令的最后一个参数 |

**示例：ssh 控制脚本**

```bash
#!/bin/bash
systemctl $1 sshd
```

```bash
[laoma@centos7 ~]$ sudo ssh_ctl stop
[laoma@centos7 ~]$ sudo ssh_ctl status
[laoma@centos7 ~]$ sudo ssh_ctl start
```

**示例：`$?` 退出码**

```bash
[laoma@centos7 ~]$ ls
hello  script.sh  showargs.sh
[laoma@centos7 ~]$ echo $?        # 0 = 成功
0
[laoma@centos7 ~]$ ls /root       # 权限不足
ls: 无法打开目录/root: 权限不够
[laoma@centos7 ~]$ echo $?        # 非0 = 失败
2
```

**企业实战案例：批量建用户脚本**

```bash
#!/bin/bash
# 用 $@ 把所有用户名参数批量传给 useradd
if [ $# -eq 0 ]; then
    echo "Usage: $0 user1 user2 ..."
    exit 1
fi
for user in "$@"; do
    useradd "$user" && echo "$user created" || echo "$user failed"
done
```

### 3.2 内置命令：echo / eval / read / exec / shift

#### 3.2.1 echo

```bash
echo -n "laoma "      # 不换行
echo -e "laoma\nlaowang"   # 解析转义
echo -e "laoma\tlaowang"   # \t 制表符
echo -e "1\b23"             # \b 退格（覆盖前一字符）
```

#### 3.2.2 eval（双重解析）

```bash
# 普通 echo：直接输出
[laoma@centos7 ~]$ echo \$$#
$2                          # 看到的是字面 $2

# eval：再解析一次
[laoma@centos7 ~]$ eval "echo \$$#"
world                       # 拿到 $2 的值

# 企业场景：ssh-agent
[laoma@centos7 ~]$ eval $(ssh-agent)
```

#### 3.2.3 read

```bash
#!/bin/sh
read -p "输入你想要说的话：" str
echo "你想要说的话是：$str"
```

#### 3.2.4 exec

不创建子进程，转去执行指定命令，命令结束后**原 Shell 终止**。

```bash
[laoma@centos7 ~]$ exec sleep 10
# sleep 命令运行完成后自动返回到原先普通用户 shell
```

**exec 读取文件**：

```bash
#!/bin/bash
# 生成序列内容文件
seq 5 > /tmp/seq.log
# 从文件中读取内容，作为 shell 的标准输入
exec < /tmp/seq.log
# read 命令接收标准输入
while read line
do
    echo $line
done
```

#### 3.2.5 shift（参数左移）

```bash
#!/bin/sh
echo $1
shift
echo $1
```

```bash
[laoma@centos7 ~]$ bash shift.sh hello world
hello
world
```

**shift 处理选项**：

```bash
#!/bin/sh
if [ "$1" = "-c" ]; then
    shift
fi
command="$1"
echo $command
```

### 3.3 变量子串（PDF 4 进阶）

| 语法 | 含义 |
|---|---|
| `${parameter}` | 返回变量内容 |
| `${#parameter}` | 字符串长度（最快方式） |
| `${parameter:offset}` | 从 offset 截取到末尾 |
| `${parameter:offset:length}` | 截取长度 |
| `${parameter#word}` | 开头删除最短匹配 |
| `${parameter##word}` | 开头删除最长匹配 |
| `${parameter%word}` | 结尾删除最短匹配 |
| `${parameter%%word}` | 结尾删除最长匹配 |
| `${parameter/pat/string}` | 替换第一个匹配 |
| `${parameter//pat/string}` | 替换所有匹配 |

```bash
[laoma@centos7 ~]$ str="abc123abc123"
[laoma@centos7 ~]$ echo ${#str}
12                                  # 字符串长度

[laoma@centos7 ~]$ echo ${str:3}
123abc123                           # 从 index=3 截取

[laoma@centos7 ~]$ echo ${str:3:4}
123a                                # 截 4 个字符

[laoma@centos7 ~]$ echo ${str#a*c}
123abc123                           # 开头最短删除
[laoma@centos7 ~]$ echo ${str##a*c}
123                                 # 开头最长删除

[laoma@centos7 ~]$ echo ${str%c*3}
abc123ab                            # 结尾最短删除
[laoma@centos7 ~]$ echo ${str%%c*3}
ab                                  # 结尾最长删除

[laoma@centos7 ~]$ echo ${str/abc/def}
def123abc123                        # 替换第一个
[laoma@centos7 ~]$ echo ${str//abc/def}
def123def123                        # 全部替换
```

**企业实战：批量改文件名**

```bash
[laoma@centos7 ~]$ touch stu-202212-snap.jpg
[laoma@centos7 ~]$ file="stu-202212-snap.jpg"
[laoma@centos7 ~]$ mv $file ${file/2022/2021}      # 2022 → 2021
[laoma@centos7 ~]$ mv $file ${file/-snap/}         # 删除 "-snap"
```

### 3.4 特殊扩展变量（防未定义）

| 语法 | 行为 |
|---|---|
| `${var:-word}` | var 为空/未定义 → 返回 word，**不修改** var |
| `${var:=word}` | var 为空/未定义 → 设置并返回 word |
| `${var:?word}` | var 为空/未定义 → 报错并退出（word 写入 stderr） |
| `${var:+word}` | var 已定义且非空 → 返回 word，否则返回空 |

```bash
[laoma@centos7 ~]$ unset test
[laoma@centos7 ~]$ echo ${test:-UNSET}
UNSET                                # 默认值

[laoma@centos7 ~]$ unset SHELL
[laoma@centos7 ~]$ echo ${SHELL:=/bin/bash}
/bin/bash
[laoma@centos7 ~]$ echo $SHELL
/bin/bash                            # 已赋值

[laoma@centos7 ~]$ unset test
[laoma@centos7 ~]$ echo ${test:?UNSET}
-bash: test: UNSET                   # 报错并退出

[laoma@centos7 ~]$ unset test
[laoma@centos7 ~]$ echo ${test:+UNSET}        # 空
[laoma@centos7 ~]$ test=hello
[laoma@centos7 ~]$ echo ${test:+UNSET}
UNSET                                # 有值时返回 word
```

**企业实战：Apache 启动脚本**

```bash
#!/bin/bash
HTTPD_LANG=${HTTPD_LANG:-"C"}
httpd=${HTTPD:-/usr/sbin/httpd}
pidfile=${PIDFILE:-/var/run/httpd.pid}
lockfile=${LOCKFILE:-/var/lock/subsys/httpd}
```

**企业实战：删除过期备份**

```bash
#!/bin/bash
# 防止 path 变量未定义
find ${path:-/tmp} -name "*.tar.gz" -type f -mtime +7 | xargs rm -f
```

---

## §4 Shell 数值计算（PDF 5）

### 4.1 算术运算符

```
+ -     加减（一元正负号）
* / %   乘除取模
**      幂
++ --   自增自减（前/后置）
! && || 逻辑非/与/或
< <= > >= 比较
== !=   相等/不等
<< >>   位移
~ | & ^ 按位运算
= += -= *= /= %=  赋值
```

### 4.2 6 种计算方式速查

| 方式 | 适用 | 示例 |
|---|---|---|
| `(())` | 整数 | `echo $((1+1))` |
| `let` | 整数 | `let i=i+1` |
| `expr` | 整数 + 字符串 | `expr 2 + 2` |
| `bc` | 整数+小数 | `echo 'scale=2;1/3' \| bc` |
| `$[]` | 整数 | `echo $[1+1]` |
| `awk` | 整数+小数 | `echo 7.7 3.8 \| awk '{print $1-$2}'` |

### 4.3 (()) 双小括号（推荐）

```bash
[laoma@centos7 ~]$ echo $((1+1))
2
[laoma@centos7 ~]$ echo $((6*3))
18
[laoma@centos7 ~]$ ((i=5))
[laoma@centos7 ~]$ ((i=i*2))
[laoma@centos7 ~]$ echo $i
10

# 复杂运算
[laoma@centos7 ~]$ a=$((100*(100+1)/2))   # 1+2+...+100
[laoma@centos7 ~]$ echo $a
5050

# 特殊运算
[laoma@centos7 ~]$ a=8; echo $((a+=1))
9
[laoma@centos7 ~]$ echo $((a**2))
81
```

**企业实战：自增与比较**

```bash
# 比较
[laoma@centos7 ~]$ if ((8>7 && 5==5)); then echo yes; fi
yes

# ++/-- 前置后置区别
[laoma@centos7 ~]$ a=10
[laoma@centos7 ~]$ echo $((a++))     # 先返回再 +1
10
[laoma@centos7 ~]$ echo $a
11
[laoma@centos7 ~]$ echo $((--a))     # 先 -1 再返回
10
```

### 4.4 let 命令

```bash
[laoma@centos7 ~]$ i=2
[laoma@centos7 ~]$ let i=i+8
[laoma@centos7 ~]$ echo $i
10
```

### 4.5 expr（多空格 + \* 转义）

```bash
[laoma@centos7 ~]$ expr 2+2       # 错误：没空格
2+2
[laoma@centos7 ~]$ expr 2 + 2     # 正确
4
[laoma@centos7 ~]$ expr 2 * 2
expr: syntax error
[laoma@centos7 ~]$ expr 2 \* 2
4
```

**企业实战：判断是否为整数**

```bash
# 原理：非整数做加法会报错
[laoma@centos7 ~]$ i=5; expr $i + 5
10
[laoma@centos7 ~]$ echo $?
0                                       # 整数 → 成功

[laoma@centos7 ~]$ i=a; expr $i + 5
expr: non-integer argument
[laoma@centos7 ~]$ echo $?
2                                       # 非整数 → 失败
```

**企业实战：判断文件扩展名**

```bash
[laoma@centos7 ~]$ file=stu-202212.jpg
[laoma@centos7 ~]$ expr "$file" : ".*\.jpg$"
14                                      # 匹配 → 返回字符数
[laoma@centos7 ~]$ echo $?
0
[laoma@centos7 ~]$ expr "$file" : ".*\.pub$"
0                                       # 不匹配 → 返回 0
[laoma@centos7 ~]$ echo $?
1
```

**企业实战：计算字符串长度**

```bash
[laoma@centos7 ~]$ str="abc123abc123"
[laoma@centos7 ~]$ expr length "$str"
12
```

### 4.6 bc（计算器 + 小数）

```bash
[laoma@centos7 ~]$ bc
1+3*4-6/3^3%4
13
scale=4                                # 设置小数位
1/3
.3333
quit

# 命令行
[laoma@centos7 ~]$ echo '1+3*4-6/3^3%4' | bc
13
[laoma@centos7 ~]$ echo 'scale=4;1/3' | bc
.3333
```

**企业实战：1+2+...+10 = 55**

```bash
[laoma@centos7 ~]$ echo $(seq -s + 10) | bc
55
```

### 4.7 awk 计算

```bash
[laoma@centos7 ~]$ echo 7.7 3.8 | awk '{ print $1-$2 }'
3.9
[laoma@centos7 ~]$ echo 358 113 | awk '{ print ($1-3)/$2 }'
3.14159
```

### 4.8 $[] 运算

```bash
[laoma@centos7 ~]$ echo $[1+1]
2
[laoma@centos7 ~]$ echo $[5%2]
1
[laoma@centos7 ~]$ count=3; echo $[(count+1)*3]
12
[laoma@centos7 ~]$ count=3; echo $[ ++count + 3 ]
7                                       # 前置：先自增
[laoma@centos7 ~]$ count=3; echo $[ count++ + 3 ]
6                                       # 后置：先返回再自增
```

---

## §5 Shell 条件测试与比较（PDF 6）

### 5.1 5 种条件测试语法

| 语法 | 特点 |
|---|---|
| `test <expr>` | 老语法，和 `[]` 等价 |
| `[ <expr> ]` | 推荐，**两端必须有空格** |
| `[[ <expr> ]]` | 扩展，**支持 =~ 正则和通配符**，支持 `&&` `||` |
| `(( <expr> ))` | 整数运算，**两端不要空格**，不支持 `-eq` |
| `command` | 命令返回值 = 表达式真值 |

> 💡 `[[]]` 是 `[]` 的超集，能用 `[[]]` 就用 `[[]]`。

### 5.2 文件测试

| 选项 | 含义 |
|---|---|
| `-d` | 目录 |
| `-f` | 普通文件 |
| `-e` | 存在（不区分文件/目录） |
| `-r` | 可读 |
| `-w` | 可写 |
| `-x` | 可执行 |
| `-s` | 存在且 size > 0 |
| `-L` | 链接文件 |
| `f1 -nt f2` | f1 比 f2 新 |
| `f1 -ot f2` | f1 比 f2 旧 |

```bash
[laoma@centos7 ~]$ data_path=/tmp/laoma
[laoma@centos7 ~]$ [ -d ${data_path} ] && echo ${data_path} is exist
/tmp/laoma is exist

[laoma@centos7 ~]$ [ -r /etc/shadow ] && cat /etc/shadow || echo hello
hello                                          # 不可读

[laoma@centos7 ~]$ [ -w ~/.bashrc ] && echo "alias pa='ps axu'" >> ~/.bashrc
```

**`[] && {}` 替代 if（多命令块）**：

```bash
# 格式
[ 条件 ] && {
    cmd1
    cmd2
}

# 实战
[laoma@centos7 ~]$ [ -w ~/.bashrc ] && {
echo "alias sa='ssh root@servera'" >> ~/.bashrc
echo "alias sb='ssh root@serverb'" >> ~/.bashrc
echo "alias sc='ssh root@serverc'" >> ~/.bashrc
}
```

### 5.3 字符串测试

| 操作符 | 含义 |
|---|---|
| `-z` | 长度为 0 |
| `-n` | 长度非 0 |
| `=` 或 `==` | 相等 |
| `!=` | 不等 |

> ⚠️ 字符串**必须用双引号**包：`[ -n "$myvar" ]`（特别是 `[]` 中）

```bash
[laoma@centos7 ~]$ unset string
[laoma@centos7 ~]$ [ -z "$string" ] && echo null string || echo $string
null string
```

### 5.4 `[[]]` 的 =~ 正则匹配

```bash
# 包含数字
[laoma@centos7 ~]$ str=123abc
[laoma@centos7 ~]$ [[ "$str" =~ [0-9]+ ]] && echo "str is a string with num" || echo "str is a string without any num"
str is a string with num

# 只有数字
[laoma@centos7 ~]$ str=123
[laoma@centos7 ~]$ [[ "$str" =~ ^[0-9]+$ ]] && echo "str is a num" || echo "str is not a num"
str is a num

# 注意：=~ 右边不要加引号，否则会变字面匹配
[laoma@centos7 ~]$ str=123
[laoma@centos7 ~]$ [[ "$str" =~ "[0-9]+" ]] && echo true || echo false
false                                       # 引号导致变字面
```

### 5.5 整数比较（注意语法差异）

| `[]` / `test` | `(())` / `[[]]` | 含义 |
|---|---|---|
| `-eq` | `==` 或 `=` | 等于 |
| `-ne` | `!=` | 不等 |
| `-gt` | `>` | 大于 |
| `-ge` | `>=` | 大于等于 |
| `-lt` | `<` | 小于 |
| `-le` | `<=` | 小于等于 |

```bash
# [] 中用 -gt
[laoma@centos7 ~]$ a=98; b=99
[laoma@centos7 ~]$ [ $a -gt $b ] && echo true || echo false
false

# 错误陷阱：[] 中用 > 必须转义
[laoma@centos7 ~]$ [ 2 > 1 ] && echo true
true                                       # 这其实在重定向
[laoma@centos7 ~]$ [ 2 \> 3 ] && echo true || echo false
false                                      # 转义后正确
```

### 5.6 逻辑操作符

| `[]` / `test` | `[[]]` / `(())` | 含义 |
|---|---|---|
| `-a` | `&&` | and |
| `-o` | `||` | or |
| `!` | `!` | not |

```bash
# -a 内部与
[laoma@centos7 ~]$ file=/etc/passwd
[laoma@centos7 ~]$ [ -f $file -a -r $file ] && head -1 $file
root:x:0:0:root:/root:/bin/bash

# [[]] 用 &&
[laoma@centos7 ~]$ [[ -f $file && -r $file ]] && head -1 $file
root:x:0:0:root:/root:/bin/bash
```

### 5.7 表达式总结表

| 表达式 | `[]` | `test` | `[[]]` | `(())` |
|---|---|---|---|---|
| 边界空格 | 需要 | 需要 | 需要 | 不需要 |
| 逻辑符 | `! -a -o` | `! -a -o` | `! && ||` | `! && ||` |
| 整数比较 | `-eq -ne -gt ...` | 同 `[]` | 同 `[]` | `= != > >= < <=` |
| 字符串 | `= == !=` | 同 `[]` | 同 `[]` | 同 `[]` |
| 通配符 | 不支持 | 不支持 | 支持（=~） | 不支持 |

---

## §6 IF 条件语句（PDF 7）

### 6.1 3 种结构

```bash
# 单分支
if 条件; then
    指令
fi

# 双分支
if 条件; then
    指令集1
else
    指令集2
fi

# 多分支
if 条件1; then
    指令1
elif 条件2; then
    指令2
else
    指令3
fi
```

> 💡 成对书写：写 `if` 就立刻写 `fi`，写 `do` 就立刻写 `done`，再回中间填内容。

### 6.2 单/双分支实战

**示例 1：检测 sshd**

```bash
#!/bin/bash
systemctl is-active sshd &>/dev/null
if [ $? -ne 0 ]; then
    echo "sshd is not running, I'll start sshd."
    systemctl start sshd
fi
```

**示例 2：检测 sshd（带 else）**

```bash
#!/bin/bash
systemctl is-active sshd &>/dev/null
if [ $? -ne 0 ]; then
    echo "sshd is not running."
    echo -n "Starting sshd ... ..."
    systemctl start sshd && echo DONE
else
    echo "sshd is running"
fi
```

**示例 3：传参控制 sshd（多分支雏形）**

```bash
#!/bin/bash
if [ "$1" == "start" ]; then
    systemctl start sshd
elif [ "$1" == "stop" ]; then
    systemctl stop sshd
elif [ "$1" == "status" ]; then
    systemctl status sshd
elif [ "$1" == "restart" ]; then
    systemctl restart sshd
else
    echo "Usage: $0 start|stop|status|restart "
fi
```

### 6.3 三个数排序（企业经典）

```bash
#!/bin/bash
a=10
b=20
c=30
# 如果 a<b，交换值，此时 a 大 b 小
if [ $a -lt $b ]; then
    num=$b; b=$a; a=$num
fi
# 比较后两个值大小并交换，此时 c 值最小
if [ $b -lt $c ]; then
    num=$c; c=$b; b=$num;
fi
# 比较前两个值大小并交换，此时 a 值最大
if [ $a -lt $b ]; then
    num=$b; b=$a; a=$num;
fi
echo "$a>$b>$c"
# 输出：30>20>10
```

### 6.4 企业级：内存监控

**开发三步法**：
1. **分析需求**：空闲内存 < 100M 报警
2. **设计思路**：获取可用内存 → 配邮件 → if 判断 → 写脚本 → 加 crontab
3. **编码实现**

**步骤 1：获取可用内存**

```bash
[laoma@centos7 ~]$ free -m
              total    used    free   shared  buff/cache   available
Mem:           3931     327     3419         11         184        3388
Swap:          3967       0     3967
[laoma@centos7 ~]$ free -m | awk 'NR==2 { print $4}'
3419
```

**步骤 2：脚本**

```bash
#!/bin/bash
# File: monitor_mem.sh
FreeMem=$(free -m | awk 'NR==2 { print $4}')
if [ $FreeMem -lt 100 ]; then
    echo "Mem is lower than 100M" | mail -s "FreeMem is ${FreeMem}M" root@localhost
fi
```

**步骤 3：加 crontab**

```bash
[laoma@centos7 ~]$ chmod +x monitor_mem.sh
[laoma@centos7 ~]$ crontab -e
*/3 * * * * /home/laoma/monitor_mem.sh
```

### 6.5 企业级：监控 MySQL

**监控方法**：
- 端口监控：`netstat / ss / lsof`（本地） + `telnet / nmap / nc`（远端）
- 进程监控：`ps -ef | grep mysql | wc -l`
- 客户端模拟：`mysql -u root -e "select version();"`

**脚本 1：端口监控**

```bash
#!/bin/bash
if ss -lnt | grep -q ':3306'; then
    echo "MySQL is Running."
else
    echo "MySQL is Not Running."
fi
```

**脚本 2：远端监控**

```bash
[laoma@centos7 ~]$ sudo yum install -y nmap nc telnet
[laoma@centos7 ~]$ nmap 127.0.0.1 -p 3306 | grep open
3306/tcp open  mysql
[laoma@centos7 ~]$ nmap 127.0.0.1 -p 3306 | grep open | wc -l
1
```

### 6.6 企业级：监控 Web

**3 种客户端模拟**：

```bash
# wget（方式 1：丢弃输出，看返回值）
[laoma@centos7 ~]$ wget --timeout=10 --tries=2 www.redhat.com 2>/dev/null
[laoma@centos7 ~]$ echo $?
0

# wget（方式 2：-q 静默）
[laoma@centos7 ~]$ wget --timeout=10 --tries=2 www.redhat.com -q
[laoma@centos7 ~]$ echo $?
0

# curl
[laoma@centos7 ~]$ curl -s www.redhat.com
[laoma@centos7 ~]$ echo $?
0
```

**脚本**：

```bash
#!/bin/bash
if wget --timeout=10 --tries=2 www.redhat.com &>/dev/null; then
    echo "Apache is Running."
else
    echo "Apache is Not Running."
fi
```

### 6.7 企业级：比较两个整数（带参数校验）

```bash
#!/bin/bash
# 判断参数个数
if [ $# -ne 2 ]; then
    echo "USAGE: $0 num1 num2"
    exit 1
fi
# 赋值
a=$1
b=$2
# 判断参数是否为整数
expr $a + 1 &>/dev/null
RETVAL1=$?
expr $b + 1 &>/dev/null
RETVAL2=$?
if [ $RETVAL1 -ne 0 -o $RETVAL2 -ne 0 ]; then
    echo "please provide two int number"
    exit 2
fi
# 比较
if [ $a -lt $b ]; then
    echo "$a<$b"
elif [ $a -eq $b ]; then
    echo "$a=$b"
else
    echo "$a>$b"
fi
```

### 6.8 判断字符串是否为数字的 4 种思路

**思路 1：sed 删除数字看是否为空**

```bash
[laoma@centos7 ~]$ [ -n "$(echo laoma123 | sed 's/[0-9]//g')" ] && echo char || echo int
char                                           # 还有内容
[laoma@centos7 ~]$ [ -z "$(echo 123 | sed 's/[0-9]//g')" ] && echo int || echo char
int                                            # 全删空
```

**思路 2：变量子串替换**

```bash
[laoma@centos7 ~]$ string=laoma123
[laoma@centos7 ~]$ [ -n "${string//[0-9]/}" ] && echo char || echo int
char
[laoma@centos7 ~]$ string=123
[laoma@centos7 ~]$ [ -n "${string//[0-9]/}" ] && echo char || echo int
int
```

**思路 3：expr**

```bash
[laoma@centos7 ~]$ expr abc + 1 &>/dev/null
[laoma@centos7 ~]$ echo $?
2                                               # 非整数
[laoma@centos7 ~]$ expr 1 + 1 &>/dev/null
[laoma@centos7 ~]$ echo $?
0                                               # 整数
```

**思路 4：`[[]] =~`**

```bash
[laoma@centos7 ~]$ [[ 123 =~ ^[0-9]+$ ]] && echo int || echo char
int
[laoma@centos7 ~]$ [[ abc123 =~ ^[0-9]+$ ]] && echo int || echo char
char
```

### 6.9 监控 memcached

```bash
#!/bin/bash
# File: check_memcache.sh
systemctl is-active memcached.service &>/dev/null
RetVal=$?
if [ $RetVal -ne 0 ]; then
    echo "Memcached is not running."
else
    # 删除缓存中的 key
    printf "del key\r\n" | nc 127.0.0.1 11211 &>/dev/null
    # 添加新值
    printf "set key 0 0 10 \r\nlaoma1234\r\n" | nc 127.0.0.1 11211 &>/dev/null
    # 查询新值
    McCount=$(printf "get key\r\n" | nc 127.0.0.1 11211 | wc -l)
    [ $McCount -eq 1 ] && \
        echo "Memcached status is ok." || \
        echo "Memcached status is error."
fi
```

### 6.10 开发 rsync 启动脚本

```bash
#!/bin/bash
# File: /etc/init.d/rsyncd
# 判断参数个数
if [ $# -ne 1 ]; then
    echo "Usage: $0 [ start | stop | restart | status ]"
    exit 1
fi
# 根据参数1做出相应动作
if [ "$1" = "start" ]; then
    rsync --daemon
    sleep 2
    if ss -lnt | grep -q ':873'; then
        echo "rsyncd is started."
        exit 0
    fi
elif [ "$1" = "stop" ]; then
    pkill rsync &>/dev/null
    sleep 2
    if ! ss -lnt | grep -q ':873'; then
        echo "rsyncd is stoped."
        exit 0
    fi
elif [ "$1" = "status" ]; then
    if ! ss -lnt | grep -q ':873'; then
        echo "rsyncd is stoped."
    else
        echo "rsyncd is started."
    fi
elif [ "$1" = "restart" ]; then
    pkill rsync &>/dev/null
    retval_1=$?
    sleep 1
    rsync --daemon
    retval_2=$?
    sleep 1
    if [ $retval_1 -eq 0 -a $retval_2 -eq 0 ]; then
        echo "rsyncd is restarted."
        exit 0
    fi
else
    echo "Usage: $0 [ start | stop | restart | status ]"
    exit 1
fi
```

---

## §7 Shell 函数（PDF 8）

### 7.1 3 种语法

```bash
# 标准写法
function 函数名 () {
    指令...
    return n
}

# 简化 1：不写 ()
function 函数名 {
    指令...
    return n
}

# 简化 2：不写 function
函数名 () {
    指令...
    return n
}
```

### 7.2 函数执行的 7 条铁律

1. **执行时函数名后不要带 `()`**：`hello` 不是 `hello()`
2. **函数必须先定义后调用**（除非 source）
3. **执行顺序**：别名 → 函数 → 系统命令 → 可执行文件
4. **函数与调用脚本共用变量**
5. **`return` 退出函数**，`exit` 退出脚本
6. **可独立写文件，用 `source` 加载**
7. **函数内用 `local` 定义局部变量**

### 7.3 4 个基础示例

**示例 1：hello 函数**

```bash
[laoma@centos7 ~]$ cat fun1.sh
#!/bin/bash
function hello () {
    echo "Hello World !"
}
hello
```

**示例 2：函数必须先定义**

```bash
[laoma@centos7 ~]$ cat fun2.sh
#!/bin/bash
hello                                # 调用在前 → 失败
function hello () {
    echo "Hello World !"
}
```

```bash
[laoma@centos7 ~]$ bash fun2.sh
fun2.sh: line 2: hello: command not found
```

**示例 3：调用外部函数（source）**

```bash
[laoma@centos7 ~]$ cat >> mylib << 'EOF'
function hello () {
    echo "Hello World !"
}
EOF

[laoma@centos7 ~]$ cat fun3.sh
#!/bin/bash
if [ -r mylib ]; then
    source mylib
else
    echo "mylib is not exist"
    exit 1
fi
hello
```

**示例 4：带参数函数**

```bash
[laoma@centos7 ~]$ cat fun4.sh
#!/bin/bash
function print () {
    if [ "$1" == "PASS" ]; then
        echo -e '\033[1;32mPASS\033[0;39m'
    elif [ "$1" == "FAIL" ]; then
        echo -e '\033[1;31mFAIL\033[0;39m'
    elif [ "$1" == "DONE" ]; then
        echo -e '\033[1;35mDONE\033[0;39m'
    else
        echo "Usage: print PASS|FAIL|DONE"
    fi
}
read -p "请输入你想要打印的内容：" str
print $str
```

> ⚠️ 函数参数用 `$1 $2`，**不继承父脚本的 `$1`**，但 `$0` 仍是脚本名。

### 7.4 企业实战：URL 检测脚本

```bash
#!/bin/bash
# File: check_url.sh
function usage () {
    echo "usage: $0 url"
    exit 1
}
function check_url () {
    wget --spider -q -o /dev/null --tries=1 -T 5 $1
    [ $? -eq 0 ] && echo "$1 is accessable" || echo "$1 is not accessable"
}
function main () {
    [ $# -ne 1 ] && usage
    check_url $1
}
main $*
```

```bash
[laoma@centos7 ~]$ bash check_url.sh www.baidu.com
www.baidu.com is accessable
[laoma@centos7 ~]$ bash check_url.sh www.laoma.com
www.laoma.com is not accessable
```

### 7.5 函数的递归

**求和：1+2+...+n**

```bash
#!/bin/bash
function sum_out () {
    if [ $1 -eq 1 ]; then
        sum=1
    else
        sum=$[ $1 + $(sum_out $[ $1 - 1 ] ) ]
    fi
    echo $sum
}
read -p "输入一个你想计算和的整数：" num
sum_out $num
```

**阶乘：n!**

```bash
#!/bin/bash
function fact_out () {
    if [ $1 -eq 1 ]; then
        sum=1
    else
        sum=$[ $1 * $(fact_out $[ $1 - 1 ] ) ]
    fi
    echo $sum
}
read -p "输入一个你想计算和的整数：" num
fact_out $num
```

### 7.6 fork 炸弹（反面教材 + 防御）

```bash
:(){ :|:& };:
```

**解释**：

```bash
:()                                 # 定义函数，函数名 ":"
{
    : | :                          # 递归调用 ":" 两次（管道产生 2 个子进程）
    &                              # 放后台
}; :
```

**防御**：

```bash
[laoma@centos7 ~]$ ulimit -u 100
```

---

## §8 CASE 条件语句（PDF 9）

### 8.1 语法

```bash
case "变量值" in
    值1)
        指令1...
        ;;
    值2)
        指令2...
        ;;
    *)                                   # 默认分支
        指令3...
        ;;
esac
```

**比喻**：找老公条件。

### 8.2 示例：判断 1-3

```bash
#!/bin/bash
read -p "请输入一个 1-3 之间数字：" num
case $num in
    1)
        echo "您输入的数字是：$num"
        ;;
    2)
        echo "您输入的数字是：$num"
        ;;
    3)
        echo "您输入的数字是：$num"
        ;;
    *)
        echo "请输入一个 1-3 之间数字。"
        ;;
esac
```

### 8.3 示例：彩色输出

```bash
#!/bin/bash
# File: case2.sh
case $1 in
    PASS)
        echo -e '\033[1;32mPASS\033[0;39m'
        ;;
    FAIL)
        echo -e '\033[1;31mFAIL\033[0;39m'
        ;;
    DONE)
        echo -e '\033[1;35mDONE\033[0;39m'
        ;;
    *)
        echo "Usage: $0 PASS|FAIL|DONE"
        ;;
esac
```

### 8.4 企业实战：控制 sshd

**简化版（多值合一）**：

```bash
#!/bin/bash
case $1 in
    start | stop | restart | reload | status)
        systemctl $1 sshd
        ;;
    *)
        echo "Usage: case-ssh start|stop|restart|reload|status"
        ;;
esac
```

### 8.5 企业实战：管理用户（带 chattr 保护）

```bash
#!/bin/bash
# run as root
[ $UID -ne 0 ] && echo 'Please run as root' && exit 1

# create users file
users_info_file=/etc/users
[ -f ${users_info_file} ] || touch ${users_info_file}

# provides two args
if [ $# -ne 2 ]; then
    echo "Usage: user-mgr [ -add | -del | -search ] username"
    exit 2
fi

# get arg value
action=$1
username=$2

# manager user
case $action in
    -search)
        if grep -q "username: $username" ${users_info_file}; then
            echo "$username is exist."
        else
            echo "$username is not exist."
        fi
        ;;
    -add)
        if grep -q "username: $username" ${users_info_file}; then
            echo "$username is exist."
        else
            chattr -i ${users_info_file}
            echo "username: $username" >> ${users_info_file}
            echo "$username has been added."
            chattr +i ${users_info_file}
        fi
        ;;
    -del)
        if grep -q "username: $username" ${users_info_file}; then
            chattr -i ${users_info_file}
            sed -i "/username: $username/d" ${users_info_file}
            chattr +i ${users_info_file}
            echo "$username has been deleted."
        else
            echo "$username is not exist."
        fi
        ;;
    *)
        echo "Usage: user-mgr [ -add | -del | -search ] username"
        ;;
esac
```

> 💡 `chattr +i` 把文件设为不可修改（防误删），改前必须 `chattr -i`。

### 8.6 case vs if 选择

- **case 适合**：变量值是少量固定字符串（如 start/stop/restart）
- **if 适合**：取值判断、范围比较、应用面更广
- 几乎所有 case 都能用 if 写

---

## §9 WHILE / UNTIL 循环（PDF 10）

### 9.1 while（条件成立时循环）

```bash
while 条件
do
    指令...
done
```

> 比喻：男朋友努力工作 → 继续相处

### 9.2 until（条件不成立时循环）

```bash
until 条件
do
    指令...
done
```

> 比喻：男朋友不努力工作 → 不继续相处

### 9.3 基础示例：竖向打印 5 4 3 2 1

**while 写法**：

```bash
#!/bin/bash
i=5
while ((i>0))
do
    echo $i
    ((i--))
done
```

**until 写法**：

```bash
#!/bin/bash
i=5
until ((i==0))
do
    echo $i
    ((i--))
done
```

### 9.4 求和 1+2+...+100

```bash
#!/bin/bash
i=1
sum=0
while ((i<=100))
do
    ((sum+=i))
    ((i++))
done
echo "1+2+3+...+99+100=$sum"
# 输出：1+2+3+...+99+100=5050
```

### 9.5 5 的阶乘

```bash
#!/bin/bash
i=1
sum=1
while ((i<=5))
do
    ((sum*=i))
    ((i++))
done
echo "5的阶乘为：$sum"
# 输出：5的阶乘为：120
```

### 9.6 经典面试题：猴子吃桃

> 第一天摘若干个，吃一半多一个；第二天再吃剩下的一半多一个；... 第 10 天早上剩 1 个。
> 求第一天摘了几个？

**迭代法**：

```bash
#!/bin/bash
# 当天桃子数量，第一天为 1
today=1
# 前一天桃子数量
lastday=0
# 只需要迭代 9 次
i=1
while ((i<=9))
do
    # 计算上一天桃子数量
    lastday=$[(today+1)*2]
    # 把上一天的数量当作今天的数量
    today=${lastday}
    ((i++))
done
echo "猴子第一天摘的桃子数量是：$today。"
# 输出：猴子第一天摘的桃子数量是：1534。
```

**递归法**：

```bash
#!/bin/bash
function sum () {
    if [[ $1 = 1 ]]; then
        echo $1
    else
        echo $[ ($(sum $[$1 - 1]) + 1) * 2 ]
    fi
}
echo "猴子第一天摘的桃子数量是：$(sum 10)。"
```

### 9.7 猜数字游戏

```bash
#!/bin/bash
# 生成随机数字，并保存到文件 /tmp/number
random_num=$[ RANDOM%50+1 ]
echo "${random_num}" >> /tmp/number
# 记录猜测次数
i=0
while true
do
    read -p "猜一猜系统产生的 50 以内随机数是：" num
    if ((num>=1 && num<=50)); then
        ((i++))
        if [ $num -eq ${random_num} ]; then
            echo "恭喜你，第 $i 次猜对了！"
            rm -f /tmp/number
            exit
        else
            echo -n "第 $i 次猜测，加油。"
            [ $num -gt ${random_num} ] && echo "太大了，往小猜。" || echo "太小了，往大猜。"
        fi
    else
        echo "请输入一个介于 1-50 之间的数字。"
    fi
done
```

### 9.8 后台运行与并发控制

**后台运行方式**：

| 方式 | 说明 |
|---|---|
| `sh script.sh &` | 后台运行 |
| `nohup script.sh &` | 忽略挂起信号 |
| `screen` | 保持会话 |

**Ctrl+Z / bg / fg / jobs / kill**：

```
Ctrl+C  停止执行
Ctrl+Z  暂停执行
bg      后台继续执行
fg      调回前台
jobs    查看后台任务
kill %n 关闭第 n 个任务
```

**让所有 CPU 满负荷**：

```bash
#!/bin/bash
cpu_count=$(lscpu | grep '^CPU(s)' | awk '{print $2}')
i=1
while ((i<=${cpu_count}))
do
    {
        while :
        do
            ((1+1))
        done
    } &
    ((i++))
done
```

**控制并发数 ≤ CPU 数**：

```bash
#!/bin/bash
# File: multi_cpu_load
cpu_count=$(lscpu | awk '/^CPU\(s\):/ { print $2 }')
while true
do
    bash /home/laoma/cpu_load &
    # 控制并发数量不能大于 CPU 数量
    while true
    do
        jobs=$(jobs -l | wc -l)
        if [ $jobs -ge $cpu_count ]; then
            sleep 3
        else
            break
        fi
    done
done
```

**`wait` 等待后台任务完成**：

```bash
#!/bin/bash
> /tmp/sleep
i=1
while [ $i -le 10 ]
do
    ( sleep $i && echo sleep $i >> /tmp/sleep ) &
    ((i++))
done
# 等待前面后台任务运行完成后再运行 wait 后指令
wait
cat /tmp/sleep
```

### 9.9 企业实战：每 2 秒输出系统负载

```bash
#!/bin/bash
# File: while1.sh
while true
do
    uptime
    sleep 2
done
```

```bash
[laoma@centos7 ~]$ bash while1.sh
 17:45:08 up  8:39,  2 users,  load average: 0.00, 0.01, 0.05
 17:45:10 up  8:39,  2 users,  load average: 0.00, 0.01, 0.05
^C
```

**记录到文件**：

```bash
#!/bin/bash
while true
do
    uptime >> /tmp/loadaverage.log
    sleep 2
done
```

### 9.10 企业实战：守护进程监控 sshd

**while 写法**：

```bash
#!/bin/bash
while true
do
    systemctl is-active sshd.service &>/dev/null
    if [ $? -ne 0 ]; then
        systemctl restart sshd.service &>/dev/null
    fi
    sleep 5
done
```

**until 写法**：

```bash
#!/bin/bash
until false
do
    systemctl is-active sshd.service &>/dev/null
    if [ $? -ne 0 ]; then
        systemctl restart sshd.service &>/dev/null
    fi
    sleep 5
done
```

### 9.11 企业实战：监控网站

```bash
#!/bin/bash
# File: check_url.sh
if [ $# -ne 1 ]; then
    echo "Usage: $0 url"
    exit 1
fi
url="$1"
while true
do
    if curl -o /dev/null -s --connect-timeout 5 $url; then
        echo "$url is ok."
    else
        echo "$url is error."
    fi
    sleep 3
done
```

### 9.12 企业实战：手机短信充值菜单（综合）

```bash
#!/bin/bash
# 默认金额
money=0.5
# 保存消息的文件
msg_file=/tmp/message
> $msg_file

# 手机操作菜单
function print_menu () {
    cat << EOF
1. 查询余额
2. 发送消息
3. 充值
4. 退出
EOF
}

# 检查数字函数
function check_digit () {
    expr $1 + 1 &> /dev/null && return 0 || return 1
}

# 显示余额函数
function check_money_all () {
    echo "余额为：$money。"
}

# 检查余额是否充足
function check_money () {
    new_money=$(echo "$money*100" | bc | cut -d . -f1)
    if [ ${new_money} -lt 15 ]; then
        echo "余额不足，请充值。"
        return 1
    else
        return 0
    fi
}

# 充值函数
function chongzhi () {
    read -p "充值金额（单位：元）：" chongzhi_money
    while true
    do
        check_digit $chongzhi_money
        if [ $? -eq 0 ] && [ ${chongzhi_money} -ge 1 ]; then
            money=$( echo "($money+${chongzhi_money})" | bc)
            echo "当前余额为：$money"
            return 0
        else
            read -p "重新输入充值金额：" chongzhi_money
        fi
    done
}

# 发送消息函数
function send_msg () {
    check_money
    if [ $? -eq 0 ]; then
        read -p "msg: " message
        echo "$message" >> ${msg_file}
        new_money=$(echo "scale=2;($money*100-15)" | bc | cut -d. -f1)
        if [ ${new_money} -ge 100 ]; then
            money=$(echo "scale=2;${new_money}/100" | bc)
        else
            money=0$(echo "scale=2;${new_money}/100" | bc)
        fi
        echo "当前余额为：$money"
    fi
}

# 主程序
while true
do
    print_menu
    echo
    read -p "请输入你的选择：" chioce
    clear
    case $chioce in
        1)
            check_money_all
            ;;
        2)
            send_msg
            ;;
        3)
            chongzhi
            ;;
        4)
            exit
            ;;
        *)
            echo "只能从 1、2、3、4 中选择。"
            ;;
    esac
    echo
done
```

### 9.13 while 读文件的 4 种方式

```bash
# 方式 1：exec 重定向
#!/bin/bash
exec < /etc/hosts
while read line
do
    echo $line
done

# 方式 2：管道（注意：会产生子 Shell，外部变量进不去）
#!/bin/bash
cat /etc/hosts | while read line
do
    echo $line
done

# 方式 3：done 后重定向
#!/bin/bash
while read line
do
    echo $line
done < /etc/hosts

# 方式 4：自定义 IFS 为换行
#!/bin/bash
IFS=$'\n'
for line in $(cat /etc/hosts)
do
    echo $line
done
```

### 9.14 企业级：抗 DDoS 攻击

**示例 1：基于 PV 封 IP**

```bash
#!/bin/bash
# File: ddos_pv.sh
logfile=$1
while true
do
    awk '{print $1}' $logfile | grep -v "^$" | sort | uniq -c > /tmp/tmp.log
    exec < /tmp/tmp.log
    while read line
    do
        # 获取 IP
        ip=$(echo $line | awk '{print $2}')
        # 获取对应数量
        count=$(echo $line | awk '{print $1}')
        # 如果数量超过 500，且防火墙无该 IP，则封掉
        if [ $count -gt 500 ] && [ $(iptables -L -n | grep "$ip" | wc -l) -lt 1 ]; then
            iptables -I INPUT -s $ip -j DROP
            echo "$ip is dropped" >> /tmp/droplist_$(date +%F).log
        fi
    done
    sleep 3600                                       # 1 小时
done
```

**示例 2：基于连接数封 IP**

```bash
#!/bin/bash
# File: ddos_conn.sh
while true
do
    ss -t | grep ESTAB | awk '{print $4}' | cut -d: -f1 | sort | uniq -c > /tmp/tmp.log
    exec < /tmp/tmp.log
    while read line
    do
        ip=$(echo $line | awk '{print $2}')
        count=$(echo $line | awk '{print $1}')
        if [ $count -gt 500 ] && [ $(iptables -L -n | grep "$ip" | wc -l) -lt 1 ]; then
            iptables -I INPUT -s $ip -j DROP
            echo "$ip is dropped" >> /tmp/droplist_$(date +%F).log
        fi
    done
    sleep 10
done
```

---

## §10 FOR / SELECT 循环（PDF 11）

### 10.1 两种 for 语法

**变量取值型**（推荐日常用）：

```bash
for 变量名 in 变量取值列表
do
    指令...
done
```

**C 语言型**（适合计数）：

```bash
for ((exp1; exp2; exp3))
do
    指令...
done
```

> 💡 省略 `in 列表` 时，等同于 `in "$@"`。

### 10.2 4 种打印 1-5 写法

```bash
# 写法 1：列表型
for i in {1..5}; do echo $i; done

# 写法 2：seq
for i in $(seq 5); do echo $i; done

# 写法 3：C 语言型
for ((i=1; i<=5; i++)); do echo $i; done

# 写法 4：while
i=1
while ((i<=5)); do
    echo $i
    ((i++))
done
```

### 10.3 降序打印 5 4 3 2 1

```bash
# 大括号（注意是反序）
for i in {5..1}; do echo $i; done

# seq 步长 -1
for i in $(seq 5 -1 1); do echo $i; done
```

### 10.4 求和 + 求积

```bash
#!/bin/bash
sum=0
for i in {1..10}
do
    sum=$[ sum + i ]
done
echo "$(seq -s '+' 10)=$sum"
# 输出：1+2+3+4+5+6+7+8+9+10=55
```

```bash
#!/bin/bash
sum=1
for i in {1..10}
do
    ((sum*=i))
done
echo "$(seq -s '*' 10)=$sum"
# 输出：1*2*3*4*5*6*7*8*9*10=3628800
```

### 10.5 水仙花数（3 位数立方和 = 自身）

```bash
#!/bin/bash
for num in {100..999}
do
    n1=$[num/100]
    n2=$[num%100/10]
    n3=$[num%10]
    if [ $[ n1**3 + n2**3 + n3**3 ] -eq $num ]; then
        echo "$n1^3 + $n2^3 + $n3^3 = $n1$n2$n3"
    fi
done
# 153, 370, 371, 407
```

### 10.6 求 100~200 之间的素数

```bash
#!/bin/bash
echo -n "100~200之间所有的素数为: "
for ((i=100; i<=200; i++))
do
    for ((j=2; j<=i-1; j++))
    do
        if [ $[i%j] -eq 0 ]; then
            break                            # 一旦能整除就跳出
        fi
    done
    [ $j -eq $i ] && echo -n "$i "           # j 自增到 i 都没整除 → 素数
done
echo
```

### 10.7 九九乘法表

```bash
#!/bin/bash
for i in {1..9}
do
    for j in $(seq 1 $i)
    do
        echo -n "$j*$i=$((i*j)) "
    done
    echo
done
```

### 10.8 SELECT 菜单循环

```bash
#!/bin/bash
select option in "查看" "添加" "删除" "退出"
do
    case $option in
        "查看")
            echo "查看中..."
            ;;
        "添加")
            echo "添加中..."
            ;;
        "删除")
            echo "删除中..."
            ;;
        "退出")
            break
            ;;
        *)
            echo "无效选择"
            ;;
    esac
done
```

> 💡 `select` 会自动生成数字菜单（1/2/3/4），用户输入数字选择。

---

## §11 循环控制及状态返回值（PDF 12）

### 11.1 循环控制三剑客

| 命令 | 作用 |
|---|---|
| `break n` | 跳出 n 层循环（n 默认 1） |
| `continue n` | 跳过 n 层本次循环 |
| `exit n` | 退出整个脚本，n 为退出码 |

### 11.2 break 跳出多层

```bash
#!/bin/bash
for i in {1..3}
do
    for j in {1..3}
    do
        if [ $j -eq 2 ]; then
            break 2                         # 跳出两层循环
        fi
        echo "i=$i j=$j"
    done
done
```

### 11.3 continue 跳过

```bash
#!/bin/bash
for i in {1..5}
do
    if [ $i -eq 3 ]; then
        continue                            # 跳过 i=3
    fi
    echo $i
done
# 输出：1 2 4 5
```

### 11.4 状态返回值（$?）

```bash
[laoma@centos7 ~]$ ls /tmp
[laoma@centos7 ~]$ echo $?
0                                          # 成功

[laoma@centos7 ~]$ ls /nonexistent
ls: cannot access '/nonexistent': No such file or directory
[laoma@centos7 ~]$ echo $?
2                                          # 失败
```

**企业实战：函数返回值**

```bash
function check_user () {
    grep -q "^$1:" /etc/passwd
    return $?                              # 0=存在，1=不存在
}
check_user root
if [ $? -eq 0 ]; then
    echo "User exists"
else
    echo "User not exists"
fi
```

### 11.5 批量生成随机字符串

```bash
#!/bin/bash
# 生成 10 个 8 位随机密码
for i in {1..10}
do
    < /dev/urandom tr -dc 'A-Za-z0-9' | head -c 8
    echo
done
```

### 11.6 批量改名

```bash
#!/bin/bash
# 把所有 .txt 改为 .bak
for file in *.txt
do
    mv "$file" "${file%.txt}.bak"
done
```

### 11.7 批量创建用户

```bash
#!/bin/bash
# 创建 10 个用户，密码随机
for i in {1..10}
do
    username="user_$i"
    password=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 8)
    useradd "$username"
    echo "$password" | passwd --stdin "$username"
    echo "$username:$password" >> /tmp/user_list.txt
done
```

---

## §12 Shell 数组（PDF 13）

### 12.1 为什么需要数组

- 多个变量逐个定义太麻烦
- 批量读取更痛苦

### 12.2 4 种定义方式

```bash
# 方式 1：小括号空格分隔（最常用）
array=(value1 value2 value3)
array=(1 2 3)

# 方式 2：键值对
array=([0]=one [1]=two [2]=three)

# 方式 3：分别定义
array[0]=a
array[1]=b
array[2]=c

# 方式 4：命令结果动态定义
array=($(ls /tmp/file*.txt))
```

### 12.3 6 种常用操作

**打印元素**：

```bash
[laoma@centos7 ~]$ array=(a b c d)
[laoma@centos7 ~]$ echo ${array[0]}     # 单个
a
[laoma@centos7 ~]$ echo ${array[*]}     # 全部（单字符串）
a b c d
[laoma@centos7 ~]$ echo ${array[@]}     # 全部（多字符串，推荐）
a b c d
```

**竖向定义**（可读性更好）：

```bash
array=(
    linux
    mysql
    httpd
    python
)
```

**元素个数**：

```bash
[laoma@centos7 ~]$ echo ${#array[*]}
4
[laoma@centos7 ~]$ echo ${#array[@]}
4
```

**赋值（覆盖/添加）**：

```bash
[laoma@centos7 ~]$ array[0]=1           # 覆盖
[laoma@centos7 ~]$ array[5]=6           # 添加（[4] 会是空）
[laoma@centos7 ~]$ echo ${array[*]}
1 b c d 6
```

**删除**：

```bash
[laoma@centos7 ~]$ unset array[5]      # 删一个
[laoma@centos7 ~]$ unset array          # 删整个
```

**截取**：

```bash
[laoma@centos7 ~]$ array=(a b c d e)
[laoma@centos7 ~]$ echo ${array[@]:1:3}
b c d                                      # 下标 1 起，3 个
[laoma@centos7 ~]$ echo ${array[@]:1}
b c d e                                    # 下标 1 起，到末尾
```

**替换**：

```bash
[laoma@centos7 ~]$ array=({a..z})
[laoma@centos7 ~]$ echo ${array[@]/b/2}
a 2 c d e f g ... z                        # 只替换第一个
[laoma@centos7 ~]$ array=(${array[@]/b/2})   # 真正修改
[laoma@centos7 ~]$ echo ${array[@]}
a 2 c d e f g ... z
```

**删除元素**：

```bash
[laoma@centos7 ~]$ array=(abc123abc123 abcd1234abcd1234)
[laoma@centos7 ~]$ echo ${array[@]#*c}
123abc123 d1234abcd1234
[laoma@centos7 ~]$ echo ${array[@]##*c}
123 d1234
[laoma@centos7 ~]$ echo ${array[@]%c*}
abc123ab abcd1234ab
```

### 12.4 3 种遍历方式

**C 型 for**：

```bash
#!/bin/bash
array=({a..d})
for ((i=0; i<${#array[@]}; i++))
do
    echo ${array[i]}
done
```

**普通 for**：

```bash
#!/bin/bash
array=({a..d})
for str in ${array[@]}
do
    echo $str
done
```

**while**：

```bash
#!/bin/bash
array=({a..d})
i=0
while ((i<${#array[@]}))
do
    echo ${array[i]}
    ((i++))
done
```

### 12.5 面试题：打印长度 ≤ 6 的单词

```bash
#!/bin/bash
# File: print_words.sh
strings=(I am linux teacher welcome to wanho training classroom)
i=0
while ((i<${#strings[@]}))
do
    if [ ${#strings[i]} -le 6 ]; then
        echo ${strings[i]}
    fi
    ((i++))
done
# 输出：
# I
# am
# linux
# to
# wanho
```

### 12.6 企业实战：批量检查 URL

```bash
#!/bin/bash
# File: check_web.sh
url_list=(
    http://www.baidu.com
    http://www.redhat.fun
    http://www.redhat.com
)
function check_url () {
    echo "==========检查站点是否可以访问=========="
    for ((i=0; i<${#url_list[@]}; i++))
    do
        echo -n "${url_list[i]}..."
        wget -o /dev/null -T3 --tries=1 --spider ${url_list[i]} &> /dev/null
        [ $? -eq 0 ] && echo "可以访问" || echo "不可以访问"
    done
    echo -e "========================================\n"
    echo -n "==========5秒后再次检查=========="
    sleep 5
    echo -e "\n"
}
function main () {
    while true
    do
        check_url
    done
}
main
```

### 12.7 合格运维必备脚本清单

1. 系统/服务监控（文件、内存、磁盘、端口、URL）
2. Web 站点目录防篡改 + 自动恢复
3. Rsync/Nginx/MySQL 等启动停止脚本
4. MySQL 主从复制监控 + 自动修复
5. 一键 MySQL 多实例 / 主从部署
6. HTTP/MySQL/Rsync/NFS/Memcached 异常监控
7. 一键软件安装 + 优化（LANMP 等）
8. MySQL 多实例启动 + 分库分表备份
9. 网络连接数 / Web PV 封 IP
10. 网站 PV/流量统计
11. 批量检查 URL 通用脚本
12. 系统基础配置一键优化
13. TCP 连接状态 + IP 报警
14. 批量创建用户 + 随机 8 位密码

---

## §13 Shell 脚本开发规范（PDF 14）

### 13.1 基本规范 6 条

1. 首行 `#!/bin/bash`
2. 加版本版权块
3. 注释用英文（防止中文乱码）
4. 扩展名 `.sh`
5. 固定目录 `/server/scripts/`
6. 字符串引号 + 等号无空格

### 13.2 变量命名规范

**全局变量**：大写 + 下划线
```bash
OLDBOY_FILE="test.txt"
export APACHE_ERR="/var/log/httpd"
```

**局部变量**：驼峰或下划线
```bash
LaoMaShell="value"
lao_ma_shell="value"
check_file=1
```

**函数内用 local**：

```bash
function print_num () {
    local num=1000            # 局部，函数外不可见
    ((num++))
    echo num=$num
}
print_num
echo num=$num                  # 100（外层变量没被改）
```

### 13.3 变量引用规范

```bash
# 必须用 ${} 避免歧义
echo "${APACHE_ERR}_suffix"

# 字符串变量加双引号
echo "${APACHE_ERR}"

# crond 中要重新 export 环境变量
```

### 13.4 函数命名规范

```bash
# 单词首字母大写
function CreateFile () { ... }
function GetValue () { ... }

# 前缀 Is/Get/Do 表示功能
function IsNumber () { ... }
function GetMax () { ... }
function DoBackup () { ... }

# 函数内用 return
```

### 13.5 高级命名规范

| 类型 | 命名 |
|---|---|
| 普通脚本 | `check_url.sh` |
| 启动脚本 | `start_xxx.sh` / `stop_xxx.sh` |
| 监控脚本 | `xxx_mon.sh` |
| 控制脚本 | `xxx_ctl.sh` |

### 13.6 代码风格

**配置和代码分离**：

```
project/
├── bin/
│   └── check_url
├── conf/
│   └── url.conf           # 配置
├── doc/
│   └── README.md
└── lib/
    └── url.lib            # 函数
```

**主脚本只写主干**：

```bash
#!/bin/bash
# 加载配置
source /server/conf/url.conf
# 加载函数
source /server/lib/url.lib
# 主程序
main $*
```

**缩进**：推荐 **2 个空格**（与 vimrc `ts=2` 配合）。

### 13.7 配置项检查

```bash
# 判断变量
[ -z "$mytmp" ] && mytmp=/tmp

# 判断目录
[ -d /tmp ] || mkdir /tmp

# 判断命令
[ -x /usr/bin/wget ] || yum install -y wget
```

---

## §14 Shell 脚本调试（PDF 15）

### 14.1 5 大常见错误

**错误 1：if 缺 fi**

```bash
#!/bin/bash
if [ 10 -gt 2 ]; then
    echo Yes
# 缺 fi
```

```
debug.sh: line 5: syntax error: unexpected end of file
```

**错误 2：循环关键字拼错**

```bash
#!/bin/bash
for i in 1 2 3
d                        # 错！应为 do
    echo $i
done
```

```
debug2.sh: line 3: syntax error near unexpected token `d'
```

**错误 3：成对符号落单**

```bash
#!/bin/bash
if [ 10 -gt 2 ; then         # 缺右括号
    echo Yes
fi
```

```
debug3.sh: line 2: [: missing `]'
```

**错误 4：双引号落单（报错行往往不准）**

```bash
#!/bin/bash
echo "Yes
echo "No"                    # 第 3 行的错，提示是 3/4
```

```
debug4.sh: line 3: unexpected EOF while looking for matching `"`
debug4.sh: line 4: syntax error: unexpected end of file
```

**错误 5：中括号两端没空格**

```bash
[10 -gt 2]                    # 错：左侧没空格
```

```
[10: command not found         # 被当成命令名
```

### 14.2 调试三剑客

**1. dos2unix（处理 Windows 换行）**

```bash
[laoma@centos7 scripts]$ ./hello.sh
-bash: ./hello.sh: /bin/bash^M: bad interpreter: No such file or directory
[laoma@centos7 scripts]$ cat -A hello.sh
#!/bin/bash^M$                                # ^M = Windows 换行
echo "Hello World !"
[laoma@centos7 scripts]$ dos2unix hello.sh
dos2unix: converting file hello.sh to Unix format ...
[laoma@centos7 scripts]$ ./hello.sh
Hello World !
```

**2. bash 命令参数**

| 参数 | 作用 |
|---|---|
| `bash -n` | 只检查语法，不执行 |
| `bash -v` | 执行前先打印脚本内容 |
| `bash -x` | 打印执行过程（**最常用**） |

```bash
[laoma@centos7 scripts]$ bash -x debug8.sh
+ '[' 10 -gt 2 ']'
+ echo Yes
Yes
```

**3. echo + exit 关键点输出**

```bash
#!/bin/bash
a=10
b=20
c=30
if [ $a -lt $b ]; then
    num=$b; b=$a; a=$num
fi
echo "DEBUG: a=$a b=$b c=$c"; exit       # 调试点
# ...
```

### 14.3 set 命令调试部分脚本

```bash
#!/bin/bash
set +x                                  # 关闭调试
for char in {a..z}
do
    echo -n "$char "
done
echo
set -x                                  # 开启调试
if [ 10 -gt 2 ]; then
    echo Yes
fi
```

```bash
[laoma@centos7 scripts]$ bash -x debug9.sh
+ set +x
a b c d e f g h i j k l m n o p q r s t u v w x y z
+ '[' 10 -gt 2 ']'
+ echo Yes
Yes
```

### 14.4 调试总结

1. **先 `dos2unix` 格式化**
2. **报错不只看一行，要关联上下文**
3. **`bash -x` 调试整脚本**
4. **`set -x` / `set +x` 调试部分**
5. **`echo $var; exit` 跟踪关键变量**
6. **最关键：语法熟练 + 良好编码习惯**

---

## §15 vimrc 脚本开发环境配置（PDF 16）

### 15.1 vi vs vim

vi 是记事本，vim 是 IDE。**先设置别名**：

```bash
[laoma@centos7 ~]$ sudo echo 'alias vi=vim' >> /etc/profile
[laoma@centos7 ~]$ source /etc/profile
```

### 15.2 完整 .vimrc 配置

```vim
" ~/.vimrc
" vim config file
" date 2022-12-12
" Created by Laoma

"""""""""""""""""""""
"     全局配置       "
"""""""""""""""""""""
" 关闭兼容模式
set nocompatible
" 设置历史记录步数
set history=100
" 开启相关插件
filetype on
filetype plugin on
filetype indent on
" 当文件在外部被修改时，自动更新该文件
set autoread
" 激活鼠标的使用
set mouse=a

"""""""""""""""""""""
"    字体和颜色     "
"""""""""""""""""""""
" 开启语法
syntax enable
" 高亮显示当前行
set cursorline
hi cursorline guibg=#00ff00
hi CursorColumn guibg=#00ff00

"""""""""""""""""""""
"     文字处理      "
"""""""""""""""""""""
" 使用空格来替换 Tab
set expandtab
" 设置所有的 Tab 和缩进为 2 个空格
set ts=2
" 设定 << 和 >> 命令移动时的宽度为 2
set shiftwidth=2
" 使得按退格键时可以一次删掉 2 个空格
set softtabstop=2
" 缩进，自动缩进
set ai
" 智能缩进
set si
" 自动换行
set wrap
" 设置软宽度
set sw=2

"""""""""""""""""""""
"     Vim 界面      "
"""""""""""""""""""""
set wildmenu
set ruler
set cmdheight=1
set nu
set noerrorbells
set novisualbell
set showmatch
set hlsearch
set ignorecase

"""""""""""""""""""""
"     编码设置      "
"""""""""""""""""""""
set encoding=utf-8
set fileencodings=utf-8
set termencoding=utf-8

"""""""""""""""""""""
"     其他设置      "
"""""""""""""""""""""
set smartindent
set cin
set laststatus=2
set pastetoggle=<F9>
set background=dark
highlight Search ctermbg=black ctermfg=white guifg=white guibg=black
```

### 15.3 自动添加脚本头

```vim
autocmd BufNewFile *.py,*.cc,*.sh exec ":call SetTitle()"
func SetTitle()
    if expand("%:e") == 'sh'
        call setline(1, "#!/bin/bash")
        call setline(2, "# Author: LaoMa")
        call setline(3, "# Time: ".strftime("%F %T"))
        call setline(4, "# Name: ".expand("%"))
    endif
endfunc
```

新建 `test.sh` 自动生成：

```bash
#!/bin/bash
# Author: LaoMa
# Time: 2022-12-08 17:10:43
# Name: test.sh
```

---

## §16 Linux 信号及 trap 命令（PDF 16/17）

### 16.1 什么是信号

信号是一个整数构成的**异步消息**：
- 进程发给其他进程
- 用户按特定键（Ctrl+C、Ctrl+Z）触发
- 系统异常事件触发

### 16.2 常用信号

| 信号 | 编号 | 触发 | 默认行为 |
|---|---|---|---|
| HUP | 1 | 终端掉线 / 用户退出 | 终止 |
| INT | 2 | Ctrl+C | 终止 |
| QUIT | 3 | Ctrl+\ | 终止 + core |
| ABRT | 6 | 严重错误 | 终止 + core |
| ALRM | 14 | 超时 | 终止 |
| TERM | 15 | kill 默认 | 终止 |
| TSTP | 20 | Ctrl+Z | 停止 |

> 需**忽略**的信号：HUP/INT/QUIT/TSTP/TERM

### 16.3 trap 语法

```bash
trap command signal
```

**捕获 Ctrl+C**：

```bash
[laoma@centos7 ~]$ trap 'echo Hello World !' 2
[laoma@centos7 ~]$ ^CHello World !                   # Ctrl+C 触发
```

**屏蔽信号**：

```bash
[laoma@centos7 ~]$ trap '' 2                          # 完全屏蔽
[laoma@centos7 ~]$ trap 'true' 2 3                    # 屏蔽 INT 和 QUIT
```

**多信号**：

```bash
[laoma@centos7 ~]$ trap 'echo Hello Ctrl !' 2 3
[laoma@centos7 ~]$ trap 'echo Hello Laoma !' INT
```

**查看所有信号**：

```bash
kill -l
trap -l
```

**`stty -a` 查看终端键位**：

```bash
[laoma@centos7 ~]$ stty -a | head -1
speed 38400 baud; rows 19; columns 83; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; susp = ^Z; ...
```

### 16.4 企业实战 1：清理临时文件

```bash
#!/bin/bash
# File: trap1.sh
trap 'find /tmp -type f -name "laoma-*.txt" -delete &>/dev/null; exit' INT
while true
do
    touch /tmp/laoma-$(date +%s).txt
    sleep 0.5
done
```

Ctrl+C 触发时自动清理 `laoma-*.txt` 后退出。

### 16.5 企业实战 2：跳板机（屏蔽所有中断）

**配置**：

```bash
# /etc/profile.d/jump.sh
[ $UID -ne 0 ] && /server/scripts/jump.sh
```

**脚本**：

```bash
#!/bin/bash
# File: /server/scripts/jump.sh
# Author: LaoMa
# Name: jump.sh

# 屏蔽所有危险信号
trap ':' INT EXIT TSTP TERM HUP

main () {
    while true
    do
        clear
        cat <<EOF
1. laoma@server101-10.1.8.101
2. laoma@server102-10.1.8.102
3. exit
EOF
        read -p "Pls input your choice: " choice
        case $choice in
            1)
                echo "login server101-10.1.8.101"
                ssh laoma@server101-10.1.8.101
                ;;
            2)
                echo "login server102-10.1.8.102"
                ssh laoma@server102-10.1.8.102
                ;;
            3)
                exit
                ;;
            *)
                echo -e "Invalid choice\n"
                ;;
        esac
    done
}

main
```

> 💡 用户登录后**只能选菜单**，Ctrl+C/Z 全部被屏蔽，无法逃逸到 Shell。

---

## §17 Expect 自动化交互（PDF 18）

### 17.1 为什么需要 Expect

很多操作是**交互式**的（SSH 输密码、`passwd` 输密码、SCP 输密码）。Expect 模拟人工输入。

### 17.2 工作流程

```
1. spawn  →  启动进程
2. expect →  匹配关键字
3. send   →  发送字符串
4. exit/eof →  退出
```

### 17.3 安装

```bash
[laoma@centos7 ~]$ sudo yum install -y expect
[laoma@centos7 ~]$ which expect
/usr/bin/expect
```

### 17.4 第一个 Expect 脚本

```bash
#!/usr/bin/expect
# File: exam.expect
spawn ssh laoma@laoma-shell-1 uptime
expect "*password"
send "redhat\n"
expect eof
```

```bash
[laoma@centos7 ~]$ expect exam.expect
spawn ssh laoma@laoma-shell-1 uptime
laoma@laoma-shell-1's password:
 15:40:29 up 57 min,  2 users,  load average: 0.00, 0.01, 0.05
```

### 17.5 4 个核心命令

#### spawn

```bash
spawn [选项] [需要自动交互的命令]
spawn ssh laoma@host "uptime"
```

#### expect

```bash
expect "字符串" {动作}                  # 匹配后执行
expect "字符串"                          # 匹配后下一行 send
expect {
    "模式1" {动作1; exp_continue}        # 多个模式
    "模式2" {动作2}
}
```

> 高级用 `-re` 走正则。

#### send / exp_send

```bash
send "redhat\r"          # \r 回车，\n 换行，\t 制表符
exp_send "yes\r"
```

#### exp_continue

继续匹配 expect 块中的下一个模式。

### 17.6 4 种实战示例

**示例 1：基本 SSH**

```bash
#!/usr/bin/expect
spawn ssh laoma@host uptime
expect "*password" {send "redhat\r"}
expect eof
```

**示例 2：分两行**

```bash
#!/usr/bin/expect
spawn ssh laoma@host uptime
expect "*password"
send "redhat\n"
expect eof
```

**示例 3：首次连接 yes/no + 密码**

```bash
#!/usr/bin/expect
# File: ssh3.expect
spawn ssh laoma@laoma-shell-2 uptime
expect {
    "yes/no" {exp_send "yes\r"; exp_continue}
    "*password" {exp_send "redhat\r"}
}
expect eof
```

**示例 4：自动回答多个 read**

```bash
# 目标脚本
#!/bin/sh
# File: read.sh
read -p "Pls input your name: " name
read -p "Pls input your age: " age
read -p "Pls input your email: " email
echo "Your name is $name."
echo "Your age is $age."
echo "Your email is $email."
```

```bash
#!/usr/bin/expect
# File: read.expect
spawn bash read.sh
expect {
    "name" {exp_send "laoma\r"; exp_continue}
    "age" {exp_send "18\r"; exp_continue}
    "email" {exp_send "laoma@redhat.fun\r"}
}
expect eof
```

### 17.7 注意事项

1. `expect {}` 多行 expect 用大括号
2. 每次匹配后加 `exp_continue` 继续
3. `exp_send` 和 `send` 类似
4. `expect eof` 结束 expect

---

## §18 企业 Shell 面试题（PDF 19）

### 18.1 扫描网络内存活主机

```bash
#!/bin/bash
# File: scan_ip.sh
. /etc/init.d/functions                       # 加载系统函数库（含 action）
CMD='ping -W 2 -c 2 '
for ip in 10.1.8.{1..254}
do
    $CMD $ip &>/dev/null && \
        action "$ip is on line." true || \
        action "$ip is on offline." false
done
```

```bash
[laoma@centos7 scripts]$ bash scan_ip.sh
10.1.8.1 is on offline.
[FAILED]
10.1.8.2 is on line.
[  OK  ]
```

### 18.2 入侵检测与报警（防篡改）

**3 步法**：

1. **建指纹库 + 文件库**（初次部署时）
2. **检测文件内容变化**（md5sum -c）
3. **检测文件数量变化**（find + diff）

**建库**：

```bash
[laoma@centos7 ~]# find /var/www/html/ -type f | xargs md5sum > /opt/zhiwei.db
[laoma@centos7 ~]# find /var/www/html/ -type f > /opt/wenjian.db
```

**检测脚本**：

```bash
#!/bin/bash
# File: ids.sh
# Author: LaoMa
CHECK_PATH=/var/www/html
[ -e ${CHECK_PATH} ] || exit
ZhiWenDb=/opt/zhiwen.db.ori
WenJianDb=/opt/wenjian.db.ori
WenJianDbNew=/opt/wenjian.db.new
[ -e ${ZhiWenDb} ] || exit
[ -e ${WenJianDb} ] || exit
# 错误日志
Errlog=/opt/err.log
> $Errlog
# check file content
echo "check file content" >> $Errlog
md5sum -c --quiet ${ZhiWenDb} &>> $Errlog
RetVal_1=$?
# check file counts
echo -e "\ncheck file counts" >> $Errlog
find ${CHECK_PATH} -type f > /opt/wenjian.db.new
diff ${WenJianDb} ${WenJianDbNew} &>> $Errlog
RetVal_2=$?
[ $RetVal_1 -ne 0 -o $RetVal_2 -ne 0 ] && \
    mail -s "error" root@localhost < $Errlog || \
    mail -s "Everything is Going on well." root@localhost
```

**crontab**：

```bash
[laoma@centos7 opt]# tail -1 /etc/crontab
*/3 * * * * root bash /scripts/ids.sh
```

### 18.3 29 道面试题清单

| # | 题目 | 参考 |
|---|---|---|
| 1 | 批量生成随机字符串 | PDF 11.5 |
| 2 | 批量改名 | PDF 11.3 |
| 3 | 批量创建用户 | PDF 11.4 |
| 4 | 扫描网络内存活主机 | PDF 19.1.4 |
| 5 | 解决 DDoS 攻击 | PDF 10.6 |
| 6 | MySQL 分库备份 | PDF 11.4 |
| 7 | MySQL 分库分表备份 | PDF 11.4 |
| 8 | 筛选符合长度的单词 | PDF 13.4 |
| 9 | MySQL 主从复制异常监控 | PDF 13.4 |
| 10 | 比较整数大小 | PDF 6.4 |
| 11 | 菜单自动化软件部署 | PDF 11.7 |
| 12 | Web/MySQL 服务异常监测 | PDF 7.2.1 |
| 13 | 监控 Memcached | PDF 7.2.5 |
| 14 | 入侵检测与报警 | PDF 19.1.14 |
| 15 | Rsync 启动脚本 | PDF 9.4 |
| 16 | MySQL 多实例启动脚本 | - |
| 17 | 学生实践抓阄脚本 | - |
| 18 | 破解 RANDOM 随机数 | - |
| 19 | 批量检查 URL | PDF 11.4 |
| 20 | 单词及字母去重排序 | - |
| 21 | LVS 管理脚本 | - |
| 22 | LVS 节点健康检查 | - |
| 23 | LVS 客户端配置 | - |
| 24 | 模拟 keepalived | - |
| 25 | 正方形/长方形 | - |
| 26 | 等腰三角形 | - |
| 27 | 直角梯形 | - |
| 28 | 51CTO 博文爬虫 | - |
| 29 | Nginx 负载节点状态监测 | - |

---

## §19 子 Shell 及 Shell 嵌套模式（PDF 20）

### 19.1 什么是子 Shell

子 Shell 是**从父 Shell 派生的新 Shell 进程**。Linux 中几乎所有应用都是 systemd（PID 1）的子进程。

```bash
[root@laoma-shell ~]# pstree -a
systemd --switched-root --system --deserialize 22
  ├─ModemManager
  ├─NetworkManager --no-daemon
  ├─sshd
  ...
```

### 19.2 5 种产生子 Shell 的方式

| 方式 | 能否继承父 Shell 变量 | 子 Shell 变量能否被父 Shell 继承 |
|---|---|---|
| `{}`（同步） | ✓ | ✓ |
| `{} &`（异步） | ✓ | ✗ |
| `()` | ✓ | ✗ |
| `\|`（管道） | ✓ | ✗ |
| `bash 子脚本` | ✗（仅继承环境变量） | ✗ |

> 💡 **核心区别**：`{}` 是**当前 Shell 内的代码块**，其他都是**真正的子 Shell**。

### 19.3 `{}` 产生子 Shell（同步）

```bash
#!/bin/bash
# File: sub_shell_1.sh
parent_var="Parent"
echo "Shell Start: ParentShell Level $BASH_SUBSHELL"
{
    echo "SubShell Level $BASH_SUBSHELL"
    sub_var="Sub"
    echo "sub_var=$sub_var"
    echo "parent_var=$parent_var"
    echo "SubShell is over."
}
echo "Now ParentShell start again."
echo "Shell Over: ParentShell Level $BASH_SUBSHELL"
if [ -z "$sub_var" ]; then
    echo "sub_var is not defined in ParentShell."
else
    echo "sub_var is defined in ParentShell."       # 会执行
fi
```

### 19.4 `() `产生子 Shell

```bash
#!/bin/bash
# File: sub_shell_3.sh
parent_var="Parent"
echo "Shell Start: ParentShell Level $BASH_SUBSHELL"
(
    echo "SubShell Level $BASH_SUBSHELL"
    export sub_var="Sub"
    echo "sub_var=$sub_var"
    echo "parent_var=$parent_var"
    echo "SubShell is over."
)
echo "Now ParentShell start again."
echo "Shell Over: ParentShell Level $BASH_SUBSHELL"
if [ -z "$sub_var" ]; then
    echo "sub_var is not defined in ParentShell."   # 会执行（继承不到）
fi
```

> 💡 小括号至少 2 个命令才产生子 Shell。

### 19.5 `| `管道产生子 Shell

```bash
#!/bin/bash
# File: sub_shell_4.sh
parent_var="Parent"
echo "Shell Start: ParentShell Level $BASH_SUBSHELL"
echo | while true
do
    echo "SubShell Level $BASH_SUBSHELL"
    export sub_var="Sub"
    echo "sub_var=$sub_var"
    echo "parent_var=$parent_var"
    echo "SubShell is over."
    break
done
echo "Now ParentShell start again."
if [ -z "$sub_var" ]; then
    echo "sub_var is not defined in ParentShell."   # 会执行
fi
```

### 19.6 bash 调用子脚本产生子 Shell

```bash
# 子脚本
#!/bin/bash
# File: sub_script.sh
echo "SubShell Level: $BASH_SUBSHELL"
export sub_var="Sub"
echo "sub_var=$sub_var"
echo "parent_var=$parent_var"                      # 空（不是环境变量）
echo "parent_env_var=$parent_env_var"              # 有值（环境变量）
```

```bash
# 父脚本
#!/bin/bash
# File: sub_shell_5.sh
parent_var="Parent"
export parent_env_var="Parent Env"                 # 必须 export
echo "Shell Start: ParentShell Level $BASH_SUBSHELL"
bash ./sub_script.sh                               # 启动子 Shell
echo "Now ParentShell start again."
if [ -z "$sub_var" ]; then
    echo "sub_var is not defined in ParentShell."   # 会执行
fi
```

### 19.7 企业"坑"：while 循环 + 管道

```bash
#!/bin/bash
# File: laoma_uid.sh（错误示例）
function read_uid () {
    local RetVal
    cat /etc/passwd | while read line               # ⚠️ 管道产生子 Shell
    do
        if echo "$line" | grep -q laoma; then
            laoma_uid=$(echo "$line" | awk -F : '{print $3}')
            echo "laoma_uid=${laoma_uid}"
            RetVal=1
            echo "RetVal=$RetVal"
            break
        fi
    done
    echo "laoma_uid=${laoma_uid}"                   # 空（变量在子 Shell）
    echo "RetVal=$RetVal"                            # 空
    return $RetVal
}
read_uid
echo "laoma_uid=${laoma_uid}"                        # 空
echo "RetVal=$?"                                     # 0（默认返回值）
```

**解法：用 exec 重定向替代管道**

```bash
#!/bin/bash
# File: laoma_uid_new.sh（正确）
function read_uid () {
    local RetVal
    exec < /etc/passwd                              # 不用管道
    while read line
    do
        if echo "$line" | grep -q laoma; then
            laoma_uid=$(echo "$line" | awk -F : '{print $3}')
            echo "laoma_uid=${laoma_uid}"
            RetVal=1
            echo "RetVal=$RetVal"
            break
        fi
    done
    echo "laoma_uid=${laoma_uid}"                   # 1000
    echo "RetVal=$RetVal"                            # 1
    return $RetVal
}
read_uid
echo "laoma_uid=${laoma_uid}"                        # 1000
echo "RetVal=$?"                                     # 1
```

### 19.8 3 种调用模式：fork / exec / source

| 模式 | 是否新开子 Shell | 父脚本能否继承子脚本变量 | 子脚本能否继承父脚本 |
|---|---|---|---|
| **fork**（默认）| ✓ | ✗ | ✓（环境变量） |
| **exec** | ✗（同进程，但替换） | ✗ | ✓ |
| **source** | ✗（同进程执行） | ✓ | ✓ |

> 💡 `exec` 调用后**父脚本 exec 之后的代码不再执行**。

**fork 模式**（最常用）：

```bash
#!/bin/bash
# bash /path/script.sh   或   /path/script.sh
```

**exec 模式**：

```bash
#!/bin/bash
# File: exec_parent.sh
echo "task 1 in ParentShell."
exec ./exec_sub.sh                  # 替换当前 Shell
echo "task 2 in ParentShell."       # 不会执行
```

```bash
[laoma@centos7 ~]$ bash exec_parent.sh
task 1 in ParentShell.
Hello World
```

**source 模式**（最强大）：

```bash
#!/bin/bash
# File: source_parent.sh
echo "task 1 in ParentShell."
source ./source_sub.sh              # 当前 Shell 执行
echo "task 2 in ParentShell."       # 会执行
```

```bash
[laoma@centos7 ~]$ bash source_parent.sh
task 1 in ParentShell.
Hello World
task 2 in ParentShell.
```

### 19.9 3 种模式应用场景

- **fork**：常规嵌套，子脚本不影响父脚本
- **exec**：嵌套脚本在主脚本末尾（已被 source 取代）
- **source**：
  - 启动服务后变量/PID 留在当前 Shell（Tomcat 启动脚本）
  - 让子脚本变量/函数被父脚本使用

---

## §20 Linux 重要命令汇总（PDF 21）

### 20.1 命令速查表

| 分类 | 数量 | 关键命令 |
|---|---|---|
| 线上查询/帮助 | 2 | `man`、`help` |
| 文件和目录操作 | 21 | `ls`、`cd`、`cp`、`find`、`mkdir`、`mv`、`pwd`、`rename`、`rm`、`rmdir`、`touch`、`tree`、`basename`、`dirname`、`chattr`、`lsattr`、`file`、`md5sum`、`sha1sum`、`sha256sum`、`sha512sum` |
| 文件内容处理 | 21 | `cat`、`tac`、`more`、`less`、`head`、`tail`、`cut`、`split`、`paste`、`sort`、`uniq`、`wc`、`iconv`、`dos2unix`、`diff`、`vimdiff`、`rev`、`grep`、`join`、`tr`、`vi/vim` |
| 文件压缩 | 6 | `tar`、`zip`、`unzip`、`gzip`、`xz`、`bz` |
| 搜索文件 | 4 | `which`、`whereis`、`find`、`locate` |
| 用户管理 | 14 | `useradd`、`usermod`、`userdel`、`groups`、`groupadd`、`groupmod`、`groupdel`、`passwd`、`chage`、`id`、`su`、`visudo`、`sudo` |
| 基础网络 | 16 | `uname`、`hostname`、`telnet`、`ssh`、`scp`、`wget`、`curl`、`ping`、`route`、`ifconfig`、`ifup/ifdown`、`nmcli`、`nmtui`、`netstat`、`ss` |
| 深入网络 | 12 | `nmap`、`lsof`、`fuser`、`mail`、`mutt`、`nslookup`、`dig`、`host`、`traceroute`、`mtr`、`tcpdump`、`nc` |
| 磁盘/文件系统 | 24 | `stat`、`mount`、`umount`、`fsck`、`dd`、`du`、`df`、`fdisk`、`gdisk`、`parted`、`mkfs`、`sync`、`resize2fs`、`lsblk`、`blkid` |
| 用户权限 | 4 | `chmod`、`chown`、`chgrp`、`umask` |
| 登录信息 | 7 | `whoami`、`who`、`w`、`last`、`lastlog`、`users`、`finger` |
| 软件包管理 | 2 | `rpm`、`dnf/yum` |
| 内置命令 | 18 | `echo`、`printf`、`watch`、`alias`、`unalias`、`date`、`cal`、`clear`、`history`、`xargs`、`exec`、`source`、`export`、`unset`、`type`、`bc` |
| 系统性能 | 15 | `chkconfig`、`systemctl`、`dmesg`、`uptime`、`free`、`vmstat`、`mpstat`、`iostat`、`pidstat`、`iotop`、`sar`、`ipcs`、`iperm`、`strace`、`ltrace` |
| 进程管理 | 16 | `bg`、`fg`、`jobs`、`kill`、`killall`、`pgrep`、`pkill`、`crontab`、`ps`、`pstree`、`top`、`nice`、`nohup`、`runlevel`、`init`、`service` |
| 关机/重启 | 6 | `shutdown`、`halt`、`poweroff`、`logout`、`exit`、`Ctrl+D` |

---

## §21 21 主题速查表

| # | 主题 | 核心语法 | 典型应用 |
|---|---|---|---|
| 1 | 为什么要学 Shell | 弱类型、纯文本处理 | 自动化 |
| 2 | 第一个脚本 | `#!/bin/bash`、4 种执行方式 | Hello World |
| 3 | 变量基础 | `var=value`、三种引号 | 字符串操作 |
| 4 | 变量进阶 | `$0` `$@` `$?`、`${}` 子串、`:- := :? :+` | 函数参数 |
| 5 | 数值计算 | `(())`、`let`、`expr`、`bc`、`$[]`、`awk` | 求和、阶乘 |
| 6 | 条件测试 | `test/[]/[[]]/(())`、5 类测试 | 文件判断 |
| 7 | IF 条件 | 单/双/多分支 | 服务启动 |
| 8 | 函数 | `function f(){}`、递归、参数 | 模块化 |
| 9 | CASE | `case $x in v) ;; esac` | 服务脚本 |
| 10 | WHILE/UNTIL | `while/until ... do ... done` | 守护进程 |
| 11 | FOR/SELECT | `for i in list; do`、`for((;;))` | 批量处理 |
| 12 | 循环控制 | `break/continue/exit` | 嵌套循环 |
| 13 | 数组 | `arr=(a b c)`、`${arr[@]}` | 批量数据 |
| 14 | 开发规范 | 命名、注释、缩进 | 团队协作 |
| 15 | 调试 | `bash -x`、`set -x`、`echo;exit` | 排错 |
| 16 | vimrc | `set nocompatible`、`syntax on` | IDE 化 |
| 17 | 信号 trap | `trap 'cmd' SIG`、`Ctrl+C` | 跳板机 |
| 18 | Expect | `spawn/expect/send/exp_continue` | 自动化 SSH |
| 19 | 面试题 | 综合实战 | 求职 |
| 20 | 子 Shell | `{} / () / | / bash`、fork/exec/source | 嵌套脚本 |
| 21 | 命令汇总 | 200+ 命令 | 速查 |

---

## §22 易错点 ×15（跨章节汇总）

1. **`#!/bin/bash` 必须放第一行**——否则变注释
2. **等号两边不能有空格**：`var=value`（不是 `var = value`）
3. **`[ ]` 两端必须有空格**：`[ -f file ]`（不是 `[ -f file]`）
4. **`<` `>` 在 `[ ]` 中需转义**：`[ 2 \> 3 ]`
5. **`(())` 不能用 `-eq` 等**：用 `==` `>` `<`
6. **`[[]] =~` 右边不加引号**：否则变字面
7. **case 结尾双分号**：`;;` 别漏
8. **while 读文件用 exec 而非管道**：管道产生子 Shell，变量出不来
9. **函数定义在调用前**：`hello()` 写在 `hello` 之前
10. **`return` 退函数，`exit` 退脚本**：别混
11. **`source` 变量才能传父 Shell**：`bash` 执行不传
12. **数组下标从 0 开始**：`${array[0]}`
13. **`$@` 加引号保留空格**：`"$@"` ≠ `$@`
14. **`$?` 是上一条命令的退出码**：不是当前命令
15. **`trap '' 2` 完全屏蔽 Ctrl+C**：`trap ':' INT EXIT TSTP TERM HUP` 跳板机

---

## §23 面试 8 大追问（综合）

### Q1：Shell 脚本开头 `#!/bin/bash` 的作用？

答：告诉内核用 `/bin/bash` 解释器执行。必须放第一行，否则变注释。

### Q2：`bash script.sh` 和 `./script.sh` 有什么区别？

答：
- `bash script.sh` 不需要执行权限，明确指定解释器
- `./script.sh` 需要 `chmod +x`，依赖 shebang 行

### Q3：`source` 和 `bash` 执行脚本的区别？

答：
- `source` 在当前 Shell 执行，变量/函数留在当前 Shell
- `bash` 启动子 Shell 执行，变量/函数不传到父 Shell

### Q4：`$*` 和 `$@` 的区别？

答：
- 不加引号：两者相同
- 加引号：`"$*"` = 整个字符串，`"$@"` = 多个独立字符串
- **传参用 `"$@"`**（保留空格）

### Q5：如何判断一个变量是否为整数？

答：4 种方法（详见 §6.8）：
1. `expr $var + 1 &>/dev/null; echo $?`
2. `[[ $var =~ ^[0-9]+$ ]]`
3. `${var//[0-9]/}` 删除数字后是否空
4. `sed 's/[0-9]//g'` 删除数字后是否空

### Q6：Shell 调试的常用方法？

答：
1. `dos2unix` 处理 Windows 换行
2. `bash -n` 检查语法
3. `bash -x` 跟踪执行
4. `set -x` / `set +x` 部分调试
5. `echo $var; exit` 关键点输出

### Q7：什么是子 Shell？为什么 while+管道变量出不来？

答：子 Shell 是从父 Shell 派生的新进程。`cat file | while read` 中管道产生子 Shell，`while` 内的变量只在子 Shell 生效。**解法**：用 `exec < file` 重定向替代管道。

### Q8：trap 在跳板机里怎么用？

答：
```bash
trap ':' INT EXIT TSTP TERM HUP
```
- `:` 是 Bash 的 no-op 命令
- 屏蔽 5 个信号（INT=Ctrl+C、EXIT、TSTP=Ctrl+Z、TERM、HUP）
- 用户登录后只能选菜单，无法逃逸

---

## §24 与其他笔记的链路

- [[shell]] — 变量基础（`var=value`、`${}`、`export`、PATH、PS1、profile、命令替换、算术、引号）
- [[practice]] — 12 道变量篇实战
- [[#§0 心智模型]] — 本笔记的全局视角
- [[#§22 易错点 ×15]] — 跨章节踩坑汇总
- [[#§21 速查表]] — 21 主题速查

**学习路径建议**：

```
shell.md（变量基础）
  ↓
practice.md（变量 12 题练习）
  ↓
shell实战.md（本笔记：流程控制 + 函数 + 数组 + 调试 + 高阶）
  ↓
企业生产脚本（跳板机、监控、备份）
```

---

## 完成情况自查

| # | 主题 | 难度 | 章节 |
|---|---|---|---|
| 1 | 为什么要学 Shell | ⭐ | §1 |
| 2 | 创建第一个脚本 | ⭐ | §2 |
| 3 | 变量基础 | ⭐ | §3.1 |
| 4 | 变量进阶 | ⭐⭐ | §3.2-3.4 |
| 5 | 数值计算 | ⭐⭐ | §4 |
| 6 | 条件测试 | ⭐⭐ | §5 |
| 7 | IF 语句 | ⭐⭐ | §6 |
| 8 | 函数 | ⭐⭐⭐ | §7 |
| 9 | CASE 语句 | ⭐⭐ | §8 |
| 10 | WHILE/UNTIL | ⭐⭐⭐ | §9 |
| 11 | FOR/SELECT | ⭐⭐ | §10 |
| 12 | 循环控制 | ⭐⭐ | §11 |
| 13 | 数组 | ⭐⭐⭐ | §12 |
| 14 | 开发规范 | ⭐⭐ | §13 |
| 15 | 调试 | ⭐⭐⭐ | §14 |
| 16 | vimrc | ⭐⭐ | §15 |
| 17 | 信号 trap | ⭐⭐⭐ | §16 |
| 18 | Expect | ⭐⭐⭐ | §17 |
| 19 | 面试题 | ⭐⭐⭐⭐ | §18 |
| 20 | 子 Shell | ⭐⭐⭐⭐ | §19 |
| 21 | 命令汇总 | ⭐ | §20 |
