---
title: linux文件查询
desc: 打包复习 ls / cat / less / head / tail / file / stat 七条查看类命令，强调三种时间戳与大文件处理。
type: 笔记
module: Linux目录
pdf: 未知
pdf_size: 未知
scope: 7 条文件查看命令 + 时间戳（atime/mtime/ctime/birth）
status: 完成
---
# Linux 文件查看类命令：`ls` / `cat` / `less` / `head` / `tail` / `file` / `stat`

> 本篇把"看文件"相关的 7 条命令打包复习，刻意强调：
> 
> 1. **三种时间戳**（access / modify / change / birth）—— 很多坑的源头；
>     
> 2. **`ls` vs `stat`** 的差异；
>     
> 3. **大文件** 必须用 `less` 而不是 `cat`；
>     
> 4. **`tail -F`** 比 `-f` 更适合"日志滚动场景"。
>     

---

## 1. `ls` —— 列目录

### 1.1 输出格式（默认 vs `-l`）

 $ ls  
 file.txt  dir/  script.sh

 $ ls -l  
 total 12  
 -rw-r--r-- 1 alice devops   523 Jun 10 09:11 file.txt  
 drwxr-xr-x 2 alice devops  4096 Jun 10 09:11 dir  
 -rwxr-xr-x 1 alice devops   134 Jun 10 09:11 script.sh

逐列解读：

 -  rw-r--r--  1  alice  devops   523  Jun 10 09:11  file.txt  
 │  │         │   │       │       │        │             │  
 │  │         │   │       │       │        │             └── 文件名  
 │  │         │   │       │       │        └──── 修改时间（mtime，未指定 -l 时为 6 个月内不显年）  
 │  │         │   │       │       └──── 大小（字节）  
 │  │         │   │       └──── 属组  
 │  │         │   └──── 属主  
 │  │         └──── 硬链接数  
 │  └──── 权限位（与 chmod 对应）  
 └──── 文件类型（见 1.2）

### 1.2 文件类型字符

| 字符        | 含义                            |
| --------- | ----------------------------- |
| `-`       | 普通文件                          |
| `d`       | 目录                            |
| `l`       | 符号链接                          |
| `b`       | 块设备                           |
| `c`       | 字符设备                          |
| `p`       | 命名管道（FIFO）                    |
| `s`       | 套接字                           |
| `D` / `T` | door / sticky（少见，BSD/Solaris） |

### 1.3 必背选项

| 选项             | 作用                      | 备注                       |
| -------------- | ----------------------- | ------------------------ |
| `-l`           | 长格式                     | 显示权限/属主/大小/时间            |
| `-a`           | 显示隐藏文件（`.` 和 `..` 也显示）  |                          |
| `-A`           | 显示隐藏文件（**不**含 `.` `..`） | 推荐日常用                    |
| `-h`           | 人类可读大小（`K`/`M`/`G`）     | 配合 `-l`                  |
| `-F`           | 给文件名追加类型指示符             | `dir/`、`link@`、`script*` |
| `-d`           | 显示目录**本身**的信息（不展开内容）    | `ls -ld /etc`            |
| `-R`           | 递归列                     | 谨慎，可能卡死                  |
| `-i`           | 显示 inode 号              |                          |
| `-n`           | UID/GID 用数字显示           | 解析 chown 数字更方便           |
| `-s`           | 显示占用的块数                 |                          |
| `-1`           | 每行一个文件                  | 配合 `\| xargs`            |
| `-t`           | 按 mtime 排序              |                          |
| `-S`           | 按大小排序                   |                          |
| `-r`           | 反向                      | 配合 `-t` / `-S` 变"最旧/最小"  |
| `-X`           | 按扩展名排序                  |                          |
| `-c`           | 用 ctime 代替 mtime 排序/显示  | 见第 6 节                   |
| `-u`           | 用 atime                 |                          |
| `--color=auto` | 彩色输出                    | Linux 默认开启               |

### 1.4 排序与时间字段

|选项|排序依据|
|---|---|
|默认|文件名|
|`-t`|mtime（修改时间）|
|`-S`|文件大小|
|`-X`|扩展名|
|`-c`|配合 `-t` 改为 ctime 排序|
|`-u`|配合 `-t` 改为 atime 排序|
|`-r`|反转|

### 1.5 经典组合

 # 按大小降序，人类可读  
 ls -lhS  
 ​  
 # 找最大的 5 个文件  
 ls -lS | head -5  
 ​  
 # 找最近改过的 10 个文件  
 ls -lt | head  
 ​  
 # 看目录本身的权限（不是目录里的内容）  
 ls -ld /etc  
 ​  
 # 列文件 + 显示 inode（用于排查硬链接）  
 ls -li  
 ​  
 # 只列目录  
 ls -d */  
 ​  
 # 看隐藏配置  
 ls -la ~  
 ​  
 # 文件数最多的 5 个目录  
 ls -1A | wc -l

### 1.6 颜色含义（默认配色）

|颜色|含义|
|---|---|
|蓝色|目录|
|绿色|可执行|
|红色|压缩包 / 归档|
|浅蓝|符号链接|
|黑底黄字|设备文件|
|粉色|套接字 / 管道|
|红色背景|断链（指向不存在的目标）|

> 自定义：`dircolors -p > ~/.dircolors` 改色。

### 1.7 `ls` 不显示的部分

`ls` **不会**显示：

- 文件创建时间（除非用 `stat` 或 `ls -l --time=birth` 部分系统支持）
    
- 文件内容的"实际类型"（用 `file`）
    
- 扩展属性（`xattr`、`getfattr`）
    
- ACL（`getfacl`）
    

---

## 2. `cat` —— 拼接并打印

### 2.1 基本行为

 cat file                       # 打印整个文件  
 cat a b c                      # 拼接（a+b+c）  
 cat a b > c                    # 拼接并重定向  
 cat -                          # 读 stdin  
 cat > new.txt                  # 从 stdin 创建文件（Ctrl+D 结束）  
 cat >> append.txt              # 追加

> `cat` 是 **concat** 的缩写，**不是**"读"的缩写——它的本意是合并。

### 2.2 核心选项

| 选项                  | 作用                              |
| ------------------- | ------------------------------- |
| `-n`                | 给所有行编号                          |
| `-b`                | 给**非空行**编号（覆盖 `-n`）             |
| `-s`                | 压缩连续空行为单个空行                     |
| `-v`                | 显示非打印字符（除 tab/换行外用 `^` `M-` 标记） |
| `-E`                | 行尾显 `$`                         |
| `-T`                | tab 显 `^I`                      |
| `-A` / `--show-all` | `-vET` 三合一                      |
| `--help`            | 帮助                              |

### 2.3 实用技巧

 # 快速生成文件  
 cat > hello.txt <<EOF  
 hello  
 world  
 EOF  
 ​  
 # 看文件里的不可见字符  
 cat -A file.txt  
 ​  
 # 反向输出（每行倒序，文件整体不倒）  
 tac file.txt          # tac 是 cat 的反写  
 ​  
 # 压缩格式直接看  
 zcat file.gz          # 等价 gunzip -c  
 xzcat file.xz  
 bzcat file.bz2  
 ​  
 # UUOC 警告  
 #  "Useless Use of cat" —— 能用 < 重定向就别 cat  
 grep pattern file        # 推荐  
 cat file | grep pattern  # 多余

### 2.4 `cat` 的"危险"特性

> `cat` 是把整个文件加载进内存（实际上是流式输出，但终归全量过一遍）。**绝不要**：
> 
> - 用 `cat` 读 GB 级日志（用 `less`）
>     
> - 用 `cat` 看二进制文件（用 `less` 或 `xxd`）
>     

### 2.5 `cat -A` 案例

 $ printf "a\tb\nc\n\nd\n" | cat -A  
 a^Ib$  
 c$  
 $  
 d$

立刻能看出 "tab 显 `^I`、行尾 `$`、空行只是 `$`"。

---

## 3. `less` —— 翻页查看（**首选**）

### 3.1 为什么用 `less` 而不是 `more` / `cat`

| 命令     | 特性                            |
| ------ | ----------------------------- |
| `cat`  | 全量输出，不可控                      |
| `more` | 只能向下，不能回头                     |
| `less` | 双向滚动 + 搜索 + 过滤 + 大文件友好（不一次加载） |

> 名言："`less` is more, but `more` is less."

### 3.2 启动选项

| 选项           | 作用                             |
| ------------ | ------------------------------ |
| `-N`         | 显示行号                           |
| `-S`         | 关闭自动换行（行末不折）                   |
| `-i`         | 搜索忽略大小写（除非模式里有大写）              |
| `-I`         | 搜索完全忽略大小写                      |
| `-R`         | 允许 ANSI 颜色（看 `gcc` / `npm` 输出） |
| `-F`         | 文件能一屏显示完时自动退出                  |
| `-X`         | 退出后**不**清屏（保留在终端）              |
| `-M`         | 详细提示（含行号、百分比、字节数）              |
| `-P"prompt"` | 自定义提示符                         |
| `-K`         | 退出时清屏（默认）                      |
| `-#2`        | 水平滚动用 2 列                      |
| `+F`         | 一启动就进入"持续跟踪"模式（类似 `tail -f`）   |
| `+/pattern`  | 启动时直接跳到第一个匹配                   |

### 3.3 交互快捷键（必背）

| 键                          | 作用                                 |
| -------------------------- | ---------------------------------- |
| `q`                        | 退出                                 |
| `Space` / `f` / `PageDown` | 下翻一屏                               |
| `b` / `PageUp`             | 上翻一屏                               |
| `Enter` / `e` / `j`        | 下滚一行                               |
| `y` / `k`                  | 上滚一行                               |
| `d`                        | 下滚半屏                               |
| `u`                        | 上滚半屏                               |
| `g` / `<`                  | 跳到文件首                              |
| `G` / `>`                  | 跳到文件尾                              |
| `Ng`                       | 跳到第 N 行（如 `100g`）                  |
| `:` + 行号 + 回车              | 跳到指定行                              |
| `/pattern`                 | 向下搜索                               |
| `?pattern`                 | 向上搜索                               |
| `n` / `N`                  | 下一个 / 上一个匹配                        |
| `&pattern`                 | 仅显示匹配的行（类似 grep）                   |
| `-i`                       | 临时切换大小写                            |
| `!cmd`                     | 启动 shell 执行命令（回到 less 用 `:` + `e`） |
| `v`                        | 进入编辑器（`$VISUAL` / `$EDITOR`）       |
| `h`                        | 帮助                                 |
| `m<char>` / `'<char>`      | 标记 / 回到标记                          |
| `=`                        | 文件信息                               |

### 3.4 `&` 过滤 = 临时 grep

 less huge.log  
 # 输入：  
 &ERROR.*\b500\b  
 # 只显示含 "ERROR ... 500" 的行

### 3.5 `LESS` 环境变量

export LESS="-R -i -M -S -#4"  
# -R 颜色；-i 搜索忽略大小写；-M 详细提示；-S 不折行；-#4 水平滚动 4 列

|变量|作用|
|---|---|
|`LESS`|默认选项|
|`LESSOPEN`|预处理管道（如自动解压 `.gz`）|
|`LESSCLOSE`|后处理管道|
|`LESSHISTFILE`|历史搜索记录|
|`LESS_TERMCAP`|颜色配置|

### 3.6 实用套路

# 看彩色日志  
less -R app.log  
  
# 一行一词不换行  
less -S wide.csv  
  
# 启动跳到指定行  
less +12345 -N huge.log  
  
# 把大日志按关键字过滤后写入新文件  
less huge.log &TIMEOUT | sort -u > timeouts.log  
  
# less -F：能一屏看完就自动退出  
less -F quick.txt

### 3.7 less 与编码

# 看 GBK 文件  
LESSCHARSET=gbk less old.txt  
  
# 自动检测（less 488+ 内置）  
less --encoding=utf-8 file

---

## 4. `head` / `tail` —— 看头看尾

### 4.1 共同选项

|选项|作用|
|---|---|
|`-n N`|显 N 行（默认 10）|
|`-c N`|显 N **字节**|
|`-q`|多文件时不打印文件名头|
|`-v`|多文件时**总**打印文件名头|
|`-z`|以 NUL 结束行（配合 `xargs -0`）|

head -n 5 file            # 前 5 行  
head -c 100 file          # 前 100 字节  
head -n -5 file           # 全部，**去掉**最后 5 行（GNU 扩展）  
head -c -10 file          # 全部，**去掉**最后 10 字节（GNU 扩展）

### 4.2 `tail` 独有：实时跟踪

| 选项                        | 作用                              |
| ------------------------- | ------------------------------- |
| `-f`                      | 持续跟踪文件增长（文件被删/重命名会丢跟踪）          |
| `-F`                      | `-f` + **重试** + **重跟踪**（处理日志滚动） |
| `--pid=PID`               | 当 PID 进程退出后停止                   |
| `--max-unchanged-stats=N` | 多久重新 stat（默认 1s）                |
| `--retry`                 | 文件不可访问时持续重试                     |
| `-n +K`                   | 从第 K 行开始输出（**不是最后 K 行**）        |

# 经典：实时跟踪日志  
tail -f /var/log/nginx/access.log  
  
# 推荐：处理日志滚动（logrotate 重命名后 tail -f 会失联）  
tail -F /var/log/nginx/access.log  
  
# 当 nginx 进程退出后自动停  
tail -f --pid=$(pgrep nginx) /var/log/nginx/access.log  
  
# 从第 100 行开始看  
tail -n +100 file

### 4.3 经典组合

# 看日志第 5000-5010 行  
sed -n '5000,5010p' huge.log  
# 或  
head -n 5010 huge.log | tail -n 11  
  
# 看头 + 尾（中间省略）  
(head -n 5 file; echo '...'; tail -n 5 file)  
  
# 随机抽 100 行  
shuf -n 100 file | head  
  
# 跟多个文件（带文件名头）  
tail -F a.log b.log c.log    
# ==>  
# ==> a.log <==  
# ... 内容 ...  
# ==> b.log <==

### 4.4 字节/行的细节

# K/M/G 单位（GNU 扩展）  
head -c 1K file             # 前 1024 字节  
head -c 1M file             # 前 1MB

> 注意：`head -n 1G file` 不会出错，但显然没有意义（行号要乘以行长）。

---

## 5. `file` —— 猜文件类型

### 5.1 工作原理

`file` 不是靠**扩展名**判断，而是按"三段式"：

1. **文件系统测试**（区分文本 vs 二进制、目录、设备）
    
2. **魔术字节（magic bytes）**：读文件前若干字节，对照 `/usr/share/file/magic.mgc` 数据库
    
3. **语言测试**：扫描，看是否像某种脚本语言
    

$ file /etc  
/etc: directory  
  
$ file /bin/ls  
/bin/ls: ELF 64-bit LSB pie executable, x86-64, ...  
  
$ file hello.py  
hello.py: Python script, ASCII text executable  
  
$ file archive.tar.gz  
archive.tar.gz: gzip compressed data, was "archive.tar"  
# 注意：可能嵌套识别  
$ file -z archive.tar.gz  
# 显示原始压缩包信息

### 5.2 核心选项

|选项|作用|
|---|---|
|`-b` / `--brief`|简略输出（不显示文件名）|
|`-i` / `--mime`|输出 MIME 类型|
|`-z` / `--uncompress`|也看压缩包里的内容|
|`-L` / `--dereference`|跟符号链接|
|`-s` / `--special-files`|也看特殊文件（默认跳）|
|`-f LIST`|从文件**读**文件名列表|
|`-e TYPE`|排除某种测试|
|`-m FILE`|指定自定义 magic 文件|
|`-C`|编译 magic 文件|
|`-v`|打印 file 版本和 magic 文件路径|
|`-F separator`|自定义文件名与结果的间隔符（`:` 默认）|
|`-N`|强制用文件内容判断（忽略 utimensat/atime 缓存）|

# 批量看（一次性给一组文件）  
file -f filelist.txt  
  
# 一行行  
file -F: *.log  
# 输出：app.log:ASCII text  
#      web.log:UTF-8 Unicode text  
  
# 自定义 magic  
file -m my-magic.mgc mystery

### 5.3 常见输出

|输出|含义|
|---|---|
|`ASCII text`|普通文本|
|`UTF-8 Unicode text`|UTF-8 文本|
|`UTF-8 Unicode (with BOM) text`|含 BOM|
|`HTML document, ASCII text`|自动识别|
|`ELF 64-bit LSB executable`|可执行|
|`ELF 64-bit LSB shared object`|动态库|
|`Bourne-Again shell script, ASCII text executable`|bash 脚本|
|`Python script, ASCII text executable`|Python 脚本|
|`gzip compressed data`|gzip|
|`POSIX tar archive (GNU)`|tar|
|`PDF document, version 1.7`|PDF|
|`PNG image data, 800 x 600, 8-bit/color RGB, non-interlaced`|PNG|
|`data`|完全识别不出来|

### 5.4 常见场景

# 看脚本到底是不是 shell  
file script.sh  
  
# 看上传文件是不是伪装的木马（扩展名 .jpg 实际是 .php）  
file user-upload.jpg  
# 输出: PHP script, ASCII text  
# 危险！  
  
# 递归看一个目录下所有文件的真实类型  
find . -type f -exec file {} \;

### 5.5 magic 文件维护

# 升级 magic 数据库  
sudo update-magic  
  
# 看 file 命令用哪个数据库  
file -v  
# ===> file-5.39 magic 4 /usr/share/file/magic.mgc 32781 52867

---

## 6. `stat` —— 元数据大总管

### 6.1 默认输出

$ stat file.txt  
  File: file.txt  
  Size: 523            Blocks: 8          IO Block: 1024   regular file  
Device: 803h/2051d      Inode: 131073      Links: 1  
Access: (0644/-rw-r--r--)  Uid: ( 1000/   alice)   Gid: ( 1000/   devops)  
Access: 2024-06-10 09:11:00.000000000 +0800  
Modify: 2024-06-10 09:11:00.000000000 +0800  
Change: 2024-06-10 09:11:00.000000000 +0800  
 Birth: 2024-06-10 09:11:00.000000000 +0800

### 6.2 三/四种时间字段（**核心**）

| 字段                | 缩写     | 何时更新                 | 含义                                             |
| ----------------- | ------ | -------------------- | ---------------------------------------------- |
| **atime**         | Access | 读文件内容时               | "最后访问时间"——但**写文件不一定改它**（mount 选项 `noatime` 关闭） |
| **mtime**         | Modify | **文件内容**被改时          | "最后修改时间"——`echo x >> file` 会改                  |
| **ctime**         | Change | 元数据（权限/属主/链接数/内容）变化时 | "状态变更时间"——`chmod` 改 mtime 不改，但 ctime 一定改       |
| **btime / birth** | —      | 文件**被创建**时           | "创建时间"——`stat` 才有，GNU 扩展                       |

> **关键记忆点**：
> 
> - mtime 改 → ctime 必改（内容变了就是元数据变了）
>     
> - ctime 改 → mtime **不一定**改（`chmod` 改权限，mtime 不动，ctime 动）
>     
> - atime 容易被 `noatime`、读盘缓存、备份工具刷新，可信度最低
>     

### 6.3 `ls` 显示的是哪个时间？

|命令|字段|
|---|---|
|`ls -l`|mtime|
|`ls -lc`|ctime|
|`ls -lu`|atime|
|`ls -l --time=birth`|btime（部分系统）|
|`stat`|全显|

### 6.4 自定义输出格式

# 单字段  
stat -c '%n' file            # 文件名  
stat -c '%s' file            # 大小  
stat -c '%a' file            # 权限数字（644）  
stat -c '%A' file            # 权限字符串  
stat -c '%U %G' file         # 属主 属组  
stat -c '%y' file            # mtime (人类)  
stat -c '%Y' file            # mtime (epoch 秒)  
stat -c '%x' file            # atime  
stat -c '%z' file            # ctime  
stat -c '%w' file            # btime  
stat -c '%i' file            # inode  
stat -c '%h' file            # 硬链接数  
stat -c '%F' file            # 文件类型（regular file / directory ...）

| 转义   | 含义                     |
| ---- | ---------------------- |
| `%n` | 文件名                    |
| `%N` | 文件名（符号链接含 `-> target`） |
| `%s` | 大小（字节）                 |
| `%b` | 占用块数                   |
| `%a` | 八进制权限                  |
| `%A` | 字符串权限                  |
| `%F` | 文件类型                   |
| `%f` | 原始 mode（hex）           |
| `%u` | UID 数字                 |
| `%U` | UID 用户名                |
| `%g` | GID 数字                 |
| `%G` | GID 组名                 |
| `%h` | 硬链接数                   |
| `%i` | inode                  |
| `%m` | 挂载点                    |
| `%w` | btime 人类               |
| `%W` | btime epoch            |
| `%x` | atime 人类               |
| `%X` | atime epoch            |
| `%y` | mtime 人类               |
| `%Y` | mtime epoch            |
| `%z` | ctime 人类               |
| `%Z` | ctime epoch            |

# 经典：看 btime（创建时间）  
stat -c '%n  created: %w  size: %s bytes' /var/log/*.log  
  
# 找最近 60 秒内创建的文件  
find / -newer /tmp/marker -mmin -1 2>/dev/null  
# 或  
find . -maxdepth 1 -type f -printf '%T@ %p\n' | sort -n  
  
# 拍快照，对比两次  
stat -c '%n %Y %Z' * > before.txt  
# ...做点修改...  
stat -c '%n %Y %Z' * > after.txt  
diff before.txt after.txt

### 6.5 文件系统级

$ stat -f /  
  File: "/"  
    ID: 80300000000 Namelen: 255     Type: ext4  
Blocks: Total: 12800000   Free: 8952311   Available: 8321900  
Inodes: Total: 3276800    Free: 2981234

|选项|含义|
|---|---|
|`-f`|看**文件系统**（不是文件）|
|`-c '%T'`|文件系统类型|
|`-c '%a %b'`|剩余 inode / 总 inode|
|`-c '%f %a'`|剩余块 / 总块|
|`-c '%s %S'`|块大小 / 块数|

# 看磁盘空间（df 替代）  
stat -f -c '剩余: %a-%c 块, 总共 %b 块, 类型 %T' /  
  
# df 的本质就是 stat -f

### 6.6 `stat -L` 跟符号链接

ln -s real.txt link.txt  
stat link.txt       # 显符号链接自己的 inode  
stat -L link.txt    # 跟到目标，显真实文件

---

## 7. 时间戳速查表

|想要|用什么|
|---|---|
|文件内容最后被改（看内容）|mtime → `ls -l`|
|文件元数据最后被改（看权限/链接/属主）|ctime → `ls -lc`|
|文件最后被读|atime → `ls -lu`|
|文件创建时间|btime → `stat -c %w`|
|最近 N 分钟修改|mmin → `find -mmin -N`|
|改 mtime 到指定时间|`touch -t 202401011200 file`|
|只刷 mtime 不改内容|`touch -m file`|
|只刷 atime|`touch -a file`|

---

## 8. 综合案例

### 案例 1：看新装的脚本

cd /opt/myapp/bin  
ls -l  
# -rwxr-xr-x 1 root root 12K  ...   run.sh  
file run.sh  
# run.sh: Bourne-Again shell script, ASCII text executable  
./run.sh --help | less  
# 翻页看

### 案例 2：定位大日志

ls -lhS /var/log/ | head  
# 看占用最大的  
  
stat -c '%n %s %y' /var/log/*.log | sort -k2 -n -r | head  
# 按大小排序的更精确写法  
  
file /var/log/app.log   # 确认是文本  
wc -l /var/log/app.log  # 多少行  
less -SN /var/log/app.log  
# 看头 N 行  
head -n 100 app.log  
# 实时跟  
tail -F app.log

### 案例 3：上传文件类型校验

for f in upload/*; do  
  echo "=== $f ==="  
  file -i "$f"  
done  
# 找出不是 image/* 的

### 案例 4：批量加权限（搭配 stat 校验）

for f in *.sh; do  
  chmod +x "$f"  
  stat -c '%A %n' "$f"   # 校验  
done

### 案例 5：找某时间之后被改过的所有文件

# 用 btime 找 1 天内创建的新文件  
find /srv -newer /tmp/marker -mtime -1 -type f -printf '%TY-%Tm-%Td %p\n'

### 案例 6：上传了 `.jpg` 实际是 PHP 的检测

$ file suspicious.jpg  
suspicious.jpg: PHP script, ASCII text  
# 不要相信扩展名

### 案例 7：比较两台机器的文件元数据

# 拍快照  
( cd /etc && stat -c '%n %s %a %U %G' * ) > etc.snapshot  
# 复制到另一台后 diff  
diff etc.snapshot /etc/...

---

## 9. 速查表

| 场景           | 命令                     |       |
| ------------ | ---------------------- | ----- |
| 看大文件         | `less -SNR huge.log`   |       |
| 实时跟日志（带滚动重试） | `tail -F app.log`      |       |
| 看头 100 行     | `head -n 100 file`     |       |
| 显行号空行压缩      | `cat -ns file`         |       |
| 找最大的 5 个文件   | `ls -lSh \\            | head` |
| 看最近修改        | `ls -lt \\             | head` |
| 文件真实类型       | `file -i upload`       |       |
| 看 inode      | `ls -i` / `stat -c %i` |       |
| 看创建时间        | `stat -c '%n %w' file` |       |
| 看 ctime      | `stat -c '%n %z' file` |       |
| 一行命令看全部      | `ls -laiF`             |       |

---

## 10. 易错点（重点记忆）

1. **`ls -l` 显示 mtime，不是 ctime**——查权限变更要用 `ls -lc`。
    
2. **`ctime` 不是 "create time"**——是 "change time"。`create time` 是 `btime`。
    
3. **mtime 改 → ctime 必改**，但 ctime 改 mtime 不一定。
    
4. **atime 易失真**——`noatime` 挂载会关闭，`relatime` 延迟更新。
    
5. **`cat` 大文件会刷屏**——用 `less`。
    
6. **`tail -f` 在日志滚动（rename）后会失联**——用 `tail -F`。
    
7. **`file` 看不出来的文件不要紧**——可能是加密或自定义格式，`file` 返回 `data`。
    
8. **不要用扩展名判类型**——`file` 才是权威；上传安全要靠 `file -i`。
    
9. **`ls -R` 在大目录树里卡死**——用 `find` 替代。
    
10. **`ls` 不显示隐藏权限细节**——ACL 用 `getfacl`，xattr 用 `getfattr`。
    

---

## 11. 进一步阅读

- `man 1 ls` / `man 1 coreutils`（ls 在 coreutils 里）
    
- `man 1 cat` / `man 1 tac`
    
- `man 1 less` —— 极长，但中间 30% 看完够用
    
- `man 1 head` / `man 1 tail`
    
- `man 1 file` / `man 5 magic`
    
- `man 1 stat` / `man 2 stat`（系统调用层）
    
- `info coreutils` —— 完整选项索引
    

---

> 复习建议：
> 
> 1. 在自己机器上 `ls -l` 找几个文件，再用 `stat` 看三种时间，记录差异；
>     
> 2. 拉一个大日志（几百 MB），分别用 `cat`、`less`、`tail -F` 体验差异；
>     
> 3. 故意把一个 `.txt` 文件加 ELF 头（`printf '\x7fELF' > xxx`）再用 `file` 看，观察 magic 的工作原理；
>     
> 4. 用 `touch -t 202001011200 file` 改 mtime，再用 `ls -lc` 验证 ctime 不会动。
>