---
title: Linux 文件传输 — tar / scp / rsync
desc: 基于 05.CentOS-7-系统管理-1/19. Linux tar文档管理.pdf + 20. 系统间复制文档.pdf 的实操笔记。覆盖 tar 打包压缩（gzip/bzip2/xz）、scp 安全拷贝、rsync 增量同步、lrzsz、SSH 隧道传输。
type: 笔记
module: Linux文件传输
pdf: 05.19 tar文档管理.pdf + 05.20 系统间复制文档.pdf
pdf_size: 189 + 210 = 399 行
scope: CentOS-7 (tar + openssh-clients + rsync)
status: 完成
---

# Linux 文件传输 — tar / scp / rsync

> **范围**：基于《CentOS-7 系统管理 1》第 19、20 章 整理。
> 覆盖 **tar**（打包压缩）+ **scp**（远程拷贝）+ **rsync**（增量同步）+ **lrzsz**（终端 zmodem）。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：传输 = 移动 + 验证]]
- [[#§1 tar 是什么：磁带归档（**T**ape **AR**chive）]]
- [[#§2 tar 五大操作：c/x/t/r/d]]
- [[#§3 tar 选项速查]]
- [[#§4 tar 实战：备份 /etc]]
- [[#§5 tar 增量：-r 添加 + --delete 删除]]
- [[#§6 三种压缩对比：gzip / bzip2 / xz]]
- [[#§7 tar 综合实战：备份脚本]]
- [[#§8 scp 是什么：基于 SSH 的安全拷贝]]
- [[#§9 scp 基础语法]]
- [[#§10 scp 实战：上传/下载/目录]]
- [[#§11 scp vs cp vs ftp]]
- [[#§12 rsync 是什么：Remote Synchronize]]
- [[#§13 rsync vs scp：增量 vs 全量]]
- [[#§14 rsync 语法与选项]]
- [[#§15 rsync 实战：Pictures 同步]]
- [[#§16 rsync --delete 镜像同步]]
- [[#§17 rsync daemon 模式（rsync://）]]
- [[#§18 lrzsz 终端 ZMODEM（xshell/xftp）]]
- [[#§19 速查表]]
- [[#§20 易错点 ×12]]
- [[#§21 面试 6 大追问]]
- [[#§22 链路]]

---

## §0 心智模型：传输 = 移动 + 验证

```
Linux 文件传输三大场景：

1. 备份归档（本地）
   tar / 7z / zip
   目的：把一堆文件打包成一个，便于存储/分发

2. 远程拷贝（机器间）
   scp / sftp / rsync
   目的：在不同主机之间搬文件

3. 增量同步（机器间）
   rsync
   目的：只传变化的部分（省带宽 + 快）
```

**类比**：
- **tar** = 把书装箱子（多个文件 → 一个）
- **scp** = 把箱子搬运到另一台机器
- **rsync** = 两台机器对比，只搬"变了的东西"

---

## §1 tar 是什么：磁带归档（Tape Archive）

```
tar = Tape Archive（磁带归档）
最初为了把文件写到磁带，现在是 Linux 标准归档工具

tar 本身只打包，不压缩
要压缩：tar + gzip/bzip2/xz
```

**常见扩展名**：
```
.tar            纯打包（没压缩）
.tar.gz / .tgz gzip 压缩（最常用）
.tar.bz2       bzip2 压缩（更高压缩率）
.tar.xz        xz 压缩（最高压缩率）
```

---

## §2 tar 五大操作：c/x/t/r/d

| 操作 | 选项 | 含义 |
|---|---|---|
| **c** | `--create` | 创建新归档 |
| **x** | `--extract` | 解包 |
| **t** | `--list` | 查看（不解包）|
| **r** | `--append` | 追加文件 |
| **d** | `--delete` | 删除归档内文件 |
| `-A` | `--catenate` | 合并两个归档 |

### 2.1 c（创建）

```bash
# 普通用户打包 /etc 会失败（权限不够）
[xkw@centos7 ~]$ tar -cf etc.tar /etc
tar: 从成员名中删除开头的"/"
tar: /etc/crypttab：open: 权限不够
# ... 一堆权限错

# 用 root
[root@centos7 ~]# tar -cf etc.tar /etc
tar: 从成员名中删除开头的"/"
# 即使 root 也会"警告"去掉了开头的 /（安全设计！）
# 这样解包不会覆盖 /etc 本体

# 加日期备份
[root@centos7 ~]# tar -cf etc-$(date +%Y%m%d).tar /etc
[root@centos7 ~]# ls -l etc*
-rw-r--r--. 1 root root 31262720 7 26 14:11 etc-20240726.tar
```

### 2.2 t（查看）

```bash
# 看归档内文件清单
[root@centos7 ~]# tar -t -f etc-20240726.tar
etc/
etc/mtab
etc/fstab
etc/crypttab
etc/resolv.conf
etc/dnf/
etc/dnf/modules.d/
......

# 配合 grep
[root@centos7 ~]# tar -t -f etc-20240726.tar | grep etc/host
etc/host.conf
etc/hosts
etc/hostname
```

### 2.3 x（解包）

```bash
# 解包到当前目录
[root@centos7 ~]# tar -xf etc-20240726.tar

# 解包指定文件（从归档里提取）
[root@centos7 ~]# tar -xf etc-20240726.tar $(tar -t -f etc-20240726.tar | grep etc/host)
[root@centos7 ~]# tree etc
etc
├── host.conf
├── hostname
└── hosts

# 解包到指定目录
[root@centos7 ~]# tar -xf etc-20240726.tar -C /tmp/
```

### 2.4 r（追加）

```bash
# 往归档里追加文件
[root@centos7 ~]# tar -r -f etc-20240726.tar /usr/share/doc/at-3.1.13/timespec

# 验证
[root@centos7 ~]# tar -tf etc-20240726.tar | grep timespec
usr/share/doc/at-3.1.13/timespec
```

### 2.5 --delete（删除归档内文件）

```bash
# 删掉归档里的某文件
[root@centos7 ~]# tar --delete -f etc-20240726.tar usr/share/doc/at-3.1.13/timespec

# 验证（空了）
[root@centos7 ~]# tar -tf etc-20240726.tar | grep timespec
# （空）
```

---

## §3 tar 选项速查

| 选项 | 长选项 | 含义 |
|---|---|---|
| `-c` | `--create` | 创建归档 |
| `-x` | `--extract` | 解包 |
| `-t` | `--list` | 列表查看 |
| `-r` | `--append` | 追加 |
| `-f` | `--file` | 指定归档文件（必须放最后！）|
| `-v` | `--verbose` | 显示详细 |
| `-z` | `--gzip` | gzip 压缩/解压 |
| `-j` | `--bzip2` | bzip2 压缩/解压 |
| `-J` | `--xz` | xz 压缩/解压 |
| `-C` | `--directory` | 切换目录后操作 |
| `-p` | `--preserve-permissions` | 保留权限 |
| `-P` | `--absolute-names` | 保留绝对路径（危险）|
| `--exclude` | | 排除文件 |
| `--delete` | | 删除归档内文件 |
| `-A` | `--catenate` | 合并归档 |
| `-X` | `--exclude-from` | 从文件读排除列表 |
| `-T` | `--files-from` | 从文件读要打包列表 |

### 经典组合

```bash
tar -czf etc.tar.gz /etc          # 创建 + gzip 压缩
tar -cjf etc.tar.bz2 /etc         # 创建 + bzip2 压缩
tar -cJf etc.tar.xz /etc          # 创建 + xz 压缩

tar -xzf etc.tar.gz               # 解压 gz
tar -xjf etc.tar.bz2              # 解压 bz2
tar -xJf etc.tar.xz               # 解压 xz

tar -tzf etc.tar.gz               # 看 gz 内容
tar -tjf etc.tar.bz2              # 看 bz2 内容
```

> ⚠️ **`-f` 必放最后**！`-f` 后面就是文件名。

---

## §4 tar 实战：备份 /etc

```bash
# 完整备份
[root@centos7 ~]# tar -czf /backup/etc-$(date +%Y%m%d).tar.gz /etc

# 加排除（不要某些目录）
[root@centos7 ~]# tar -czf etc.tar.gz --exclude=/etc/selinux /etc

# 从文件读排除列表
[root@centos7 ~]# vim /root/exclude.txt
/etc/selinux
/etc/sudoers.d
/etc/ssh/ssh_host_*

[root@centos7 ~]# tar -czf etc.tar.gz -X /root/exclude.txt /etc

# 保留权限（恢复时不改）
[root@centos7 ~]# tar -czpf etc.tar.gz /etc

# 看进度（v）
[root@centos7 ~]# tar -czvpf etc.tar.gz /etc
etc/
etc/mtab
etc/fstab
... (verbose 输出)
```

---

## §5 tar 增量：-r 添加 + --delete 删除

```bash
# 创建归档
[root@centos7 ~]# tar -cf logs.tar /var/log

# 后来有新日志，追加
[root@centos7 ~]# tar -rf logs.tar /var/log/messages.new

# 删归档里的旧备份
[root@centos7 ~]# tar --delete -f logs.tar oldfile.log
```

> 💡 **生产实战**：每周一次完整 tar，每天一次 `-r` 追加增量。

---

## §6 三种压缩对比：gzip / bzip2 / xz

```
压缩率（越小越好）：xz > bzip2 > gzip
速度（越快越好）：gzip > bzip2 > xz
```

### 6.1 安装

```bash
[root@centos7 ~]# yum install gzip bzip2 xz
```

### 6.2 三种压缩实战对比

```bash
# gzip（默认）
[root@centos7 ~]# time tar -czf etc.tar.gz /etc
real 0m0.815s    ← 0.8 秒

# bzip2
[root@centos7 ~]# time tar -cjf etc.tar.bz2 /etc
real 0m1.740s    ← 1.7 秒

# xz
[root@centos7 ~]# time tar -cJf etc.tar.xz /etc
real 0m10.721s   ← 10.7 秒

# 大小对比
[root@centos7 ~]# ls -lh etc.tar.*
-rw-r--r--. 1 root root 5.2M etc.tar.bz2    ← 最小
-rw-r--r--. 1 root root 7.0M etc.tar.gz     ← 中等
-rw-r--r--. 1 root root 4.2M etc.tar.xz     ← 最大压缩

# 总结：
# xz 压缩率最高但慢（适合大文件、不常压缩）
# gzip 速度适中（最常用）
# bzip2 居中
```

### 6.3 解压

```bash
tar -xzf etc.tar.gz -C /tmp/
tar -xjf etc.tar.bz2 -C /tmp/
tar -xJf etc.tar.xz -C /tmp/

# 看大小不解压
tar -tzf etc.tar.gz | xargs ls -la 2>/dev/null
# 或
ls -lh etc.tar.gz
```

---

## §7 tar 综合实战：备份脚本

```bash
#!/bin/bash
# /usr/local/bin/backup.sh - 每天 0 点跑

BACKUP_DIR=/backup
DATE=$(date +%Y%m%d)
HOSTNAME=$(hostname)

# 1. 备份 /etc
tar -czpf $BACKUP_DIR/etc-${HOSTNAME}-${DATE}.tar.gz /etc --exclude=/etc/ssh/ssh_host_*

# 2. 备份 /var/log（gzip 即可）
tar -czpf $BACKUP_DIR/logs-${HOSTNAME}-${DATE}.tar.gz /var/log

# 3. 备份网站（如果有）
[ -d /var/www/html ] && tar -czpf $BACKUP_DIR/web-${HOSTNAME}-${DATE}.tar.gz /var/www/html

# 4. 删除 30 天前的备份
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
```

加到 cron：

```bash
0 0 * * * /usr/local/bin/backup.sh >/dev/null 2>&1
```

---

## §8 scp 是什么：基于 SSH 的安全拷贝

```
scp = Secure Copy（基于 SSH）
  用 SSH 加密传输
  默认端口 22
  走和 ssh 一样的认证（密码或密钥）

语法和 cp 几乎一样：
  scp [选项] src dst
```

**和 cp 的区别**：
```
cp file1 file2                 # 本地拷贝
scp file1 user@host:/path      # 远程拷贝
```

---

## §9 scp 基础语法

```bash
# 本地 → 远程
scp local_file user@host:/remote/path/

# 远程 → 本地
scp user@host:/remote/file /local/path/

# 远程 A → 远程 B（通过本地中转）
scp userA@hostA:/file userB@hostB:/path/
```

---

## §10 scp 实战：上传/下载/目录

### 10.1 下载

```bash
# 远程文件下载到当前目录（.）
[root@client ~]# scp root@server:/root/etc-20240726.tar .
etc-20240726.tar          100%   30MB  188.5MB/s   00:00

# 下载到指定目录
[root@client ~]# scp root@server:/root/etc-20240726.tar /tmp/

# 多个文件（用大括号展开）
[root@client ~]# scp root@server:/root/{etc-20240726.tar,etc.tar} .
etc-20240726.tar          100%   30MB  192.6MB/s   00:00
etc.tar                   100%   30MB  214.3MB/s   00:00
```

### 10.2 上传

```bash
# 上传到远程家目录（: 等价于 :~）
[root@client ~]# scp etc.tar root@server:

# 上传到指定目录
[root@client ~]# scp etc.tar root@server:/tmp/

# 多个文件
[root@client ~]# scp etc.tar etc-20240726.tar root@server:
```

### 10.3 目录递归（-r）

```bash
# 目录拷贝必须 -r
[root@client ~]# scp root@server:/etc/selinux/ .
scp: /etc/selinux: not a regular file    # ⚠️ 报错

[root@client ~]# scp -r root@server:/etc/selinux/ .
semanage.conf            100% 2647    2.3MB/s   00:00
config                   100%  548  435.5KB/s   00:00
file_contexts            100%  404KB 108.9MB/s   00:00
...

[root@client ~]# scp -r selinux/ root@server:
# ↑ 上传目录
```

### 10.4 常用选项

```bash
scp -P 2222 file user@host:/path    # 指定端口（注意是大 P）
scp -r dir user@host:/path           # 递归目录
scp -p file user@host:/path          # 保留权限和时间戳
scp -C file user@host:/path          # 压缩传输（提速）
scp -l 8000 file user@host:/path     # 限速 8000 Kbit/s = 1 MB/s
scp -q file user@host:/path          # 安静模式（不显示进度）
scp -i keyfile file user@host:/path  # 指定密钥
scp -v file user@host:/path          # 调试
```

---

## §11 scp vs cp vs ftp

| | scp | cp | ftp |
|---|---|---|---|
| 加密 | ✅ SSH | ❌ | ❌（vsftpd 可 TLS）|
| 远程 | ✅ | ❌ | ✅ |
| 速度 | 中 | 快 | 中 |
| 断点续传 | ❌ | ❌ | ✅ |
| 性能（大文件）| 一般 | 快 | 中 |

> 💡 **大文件用 rsync**（支持断点续传、增量）。

---

## §12 rsync 是什么：Remote Synchronize

```
rsync = Remote Synchronize（远程同步）
  比 scp 高级：只传"差异"（增量）
  本地同步也行
  支持 SSH 或 rsync daemon 模式
```

**核心算法**：
```
rsync 不会传整个文件
它会先比较两端的文件，只传"变了的部分"
小改动 = 传得少 = 快
```

---

## §13 rsync vs scp：增量 vs 全量

```
场景：服务器有 1 GB 日志，你改了 1 KB

scp：传整个 1 GB（约 5 分钟）
rsync：只传 1 KB（约 0.01 秒）

→ 大文件 / 频繁同步 → rsync 完胜
```

---

## §14 rsync 语法与选项

### 14.1 语法

```bash
# 3 种用法
rsync [OPTION]... SRC DEST                       # 本地
rsync [OPTION]... SRC [USER@]HOST:DEST           # 推送
rsync [OPTION]... [USER@]HOST:SRC DEST           # 拉取
```

### 14.2 常用选项

| 选项 | 含义 |
|---|---|
| `-a` | **归档模式**（-rlptgoD）|
| `-r` | 递归目录 |
| `-l` | 保留符号链接 |
| `-p` | 保留权限 |
| `-t` | 保留时间戳 |
| `-g` | 保留组 |
| `-o` | 保留所有者 |
| `-D` | 保留设备文件 |
| `-v` | 详细 |
| `-n` | 空跑（看会传啥）|
| `-z` | 压缩传输 |
| `--delete` | 删除目标有而源没有的文件（镜像）|
| `-A` | 保留 ACL |
| `-X` | 保留 SELinux context |

> 💡 **`-a` = 几乎全保**（归档模式），最常用。

---

## §15 rsync 实战：Pictures 同步

### 场景：把本地的 Pictures/ 同步到 server

```bash
# 1) 准备测试数据
[root@client ~]# mkdir Pictures
[root@client ~]# touch Pictures/snap{1..5}.jpg

# 2) 第一次全量同步
[root@client ~]# rsync -av Pictures root@server:
sending incremental file list
Pictures/
Pictures/snap1.jpg
Pictures/snap2.jpg
Pictures/snap3.jpg
Pictures/snap4.jpg
Pictures/snap5.jpg

sent 351 bytes  received 115 bytes  932.00 bytes/sec
total size is 0  speedup is 0.00

# 3) 第二次同步（没变化）→ 啥也不传
[root@client ~]# rsync -av Pictures root@server:
sending incremental file list

sent 153 bytes  received 17 bytes  340.00 bytes/sec
total size is 0  speedup is 0.00

# 4) 改了 snap1 snap2 → 只传这两个
[root@client ~]# touch Pictures/snap{1,2}*
[root@client ~]# rsync -av Pictures root@server:
sending incremental file list
Pictures/snap1.jpg
Pictures/snap2.jpg

sent 237 bytes  received 55 bytes  194.67 bytes/sec
```

### 关键看 `--delete` 的行为

```bash
# 场景：本地删了 snap5.jpg，server 还在
[root@client ~]# rm -f Pictures/snap5.jpg

# 默认：server 不会删（增量不同步删除）
[root@client ~]# rsync -av Pictures root@server:
sending incremental file list
Pictures/
# ↑ 只检测到目录，但 snap5 没删

# 加 --delete：保持完全一致
[root@client ~]# rsync -av Pictures root@server: --delete
sending incremental file list
deleting Pictures/snap5.jpg    # ← server 上的删了

sent 146 bytes  received 39 bytes  370.00 bytes/sec
```

---

## §16 rsync --delete 镜像同步

```
镜像同步（rsync -av --delete SRC DEST）：
  把 DEST 变成 SRC 的"镜子"
  SRC 有的，DEST 也有
  SRC 没有的，DEST 删掉
```

**实战：网站同步**

```bash
# 把本地网站同步到服务器（保持完全一致）
[root@client ~]# rsync -av --delete /var/www/html/ root@server:/var/www/html/

# 排除某些目录
[root@client ~]# rsync -av --delete \
  --exclude='cache/' \
  --exclude='*.log' \
  /var/www/html/ root@server:/var/www/html/

# 空跑测试（看会传啥，不真传）
[root@client ~]# rsync -avn --delete /var/www/html/ root@server:/var/www/html/
```

> ⚠️ **--delete 很危险**：方向写反会把服务器上的删光！

---

## §17 rsync daemon 模式（rsync://）

```
默认：rsync 走 SSH（要密码或密钥）
daemon 模式：rsync 自己当服务（端口 873），免 SSH
```

### 17.1 语法变化

```bash
# SSH 模式（默认）
rsync -av SRC [USER@]HOST::DEST           # 注意是两个冒号 ::
rsync -av [USER@]HOST::SRC DEST

# daemon 模式（rsync:// 协议）
rsync -av rsync://[USER@]HOST[:PORT]/SRC [DEST]
```

### 17.2 配 daemon 服务（简化）

```bash
# 服务端
[root@server ~]# vim /etc/rsyncd.conf
[backup]
    path = /backup
    comment = Backup Share
    read only = no
    auth users = rsyncuser
    secrets file = /etc/rsyncd.secrets

[root@server ~]# systemctl enable rsyncd --now

# 客户端
[root@client ~]# rsync -av rsync://rsyncuser@server/backup/ /local/backup/
```

---

## §18 lrzsz 终端 ZMODEM（xshell/xftp）

```
lrzsz = 古老的 ZMODEM 协议工具
  在 SSH 终端（xshell/secureCRT）里直接传文件
  不用单独开 FTP
```

```bash
# 安装
[root@centos7 ~]# yum install -y lrzsz

# 上传（弹窗选文件）
[root@centos7 ~]# rz

# 下载
[root@centos7 ~]# sz filename
```

> 💡 **适合**：临时传小文件，没有 scp / sftp 时。

---

## §19 速查表

### 19.1 tar

```bash
# 创建
tar -cf file.tar dir/
tar -czf file.tar.gz dir/        # gzip
tar -cjf file.tar.bz2 dir/       # bzip2
tar -cJf file.tar.xz dir/        # xz

# 查看
tar -tf file.tar
tar -tzf file.tar.gz

# 解压
tar -xf file.tar -C /tmp/
tar -xzf file.tar.gz -C /tmp/

# 追加/删除
tar -rf file.tar newfile
tar --delete -f file.tar oldfile

# 排除
tar -czf file.tar.gz --exclude=dir/ src/
tar -czf file.tar.gz -X exclude.txt src/
```

### 19.2 scp

```bash
scp local user@host:/remote/         # 上传
scp user@host:/remote local           # 下载
scp -r dir user@host:/remote/         # 目录
scp -P 2222 file user@host:/path     # 指定端口
scp -C file user@host:/path          # 压缩
scp -l 8000 file user@host:/path     # 限速
scp -p file user@host:/path          # 保留权限
```

### 19.3 rsync

```bash
# 同步
rsync -av src/ dst/                       # 本地
rsync -av src/ user@host:/dst/            # 推送
rsync -av user@host:/src/ dst/            # 拉取

# 镜像（删除多的）
rsync -av --delete src/ user@host:/dst/

# 排除
rsync -av --exclude='*.log' src/ dst/

# 空跑
rsync -avn --delete src/ dst/

# 压缩传输
rsync -avz src/ user@host:/dst/
```

---

## §20 易错点 ×12

### 1. ❌ tar -f 放错位置

```bash
tar -cjf etc.tar.gz /etc   # ⚠️ -f 后面是 etc.tar.gz，但 bz2 才是 bz2
# -f 是文件，扩展名只是标识，不影响格式
# 真正控制压缩的是 -z / -j / -J
```

### 2. ❌ tar -cf 后没给文件名

```bash
tar -c /etc       # ⚠️ 默认从 stdin 读文件名？
# 解：tar -cf file.tar /etc
```

### 3. ❌ scp 不加 -r 拷贝目录

```bash
scp dir/ user@host:/path      # ⚠️ not a regular file
scp -r dir/ user@host:/path   # ✅
```

### 4. ❌ scp 端口写成小写 -p

```bash
scp -p 2222 file user@host:/path   # ⚠️ 小写 -p = 保留权限，不是端口
scp -P 2222 file user@host:/path   # ✅ 大写 -P = 端口
```

### 5. ❌ rsync --delete 方向写反

```bash
# ⚠️ 本地没的，远端有 → 远端被删
rsync -av --delete empty_local/ user@host:/important_data/
# 反向写就完蛋了
```

### 6. ❌ rsync 路径 / 加不加区别

```bash
rsync -av src/ dst/             # 复制 src 内文件到 dst
rsync -av src dst/              # 复制整个 src 目录到 dst

# 区别：
# src/  → dst/file1, dst/file2
# src   → dst/src/file1, dst/src/file2
```

### 7. ❌ rsync daemon 模式一个冒号

```bash
rsync -av user@host:/path  # SSH 模式
rsync -av user@host::path  # daemon 模式（两个冒号！）
rsync -av rsync://user@host/path  # URL 模式
```

### 8. ❌ tar -P 绝对路径危险

```bash
tar -cPf backup.tar /etc   # ⚠️ 保留开头的 /
# 解包时会覆盖 /etc 本体！
# 一般不要用 -P
```

### 9. ❌ rsync 不指定协议默认 SSH

```bash
# 默认走 SSH（要密码或密钥）
# daemon 模式要明确：rsync:// 或 ::
```

### 10. ❌ lrzsz 在非 xshell/secureCRT 用不了

```bash
# rz/sz 依赖终端的 ZMODEM 协议
# Windows terminal / MobaXterm 默认不支持
```

### 11. ❌ 大文件用 scp

```bash
# 100 GB 文件，scp 传完才能用
# 用 rsync 至少能断点续传
```

### 12. ❌ rsync -a 不等于 -r

```bash
# -a = -rlptgoD（包含很多东西）
# -r 只递归（不带权限、时间戳等）
# 同步建议永远 -a
```

---

## §21 面试 6 大追问

### Q1：tar 和 zip 区别？

**答**：
- **tar**：Linux 标准，只打包不压缩（要 + gzip/bzip2/xz），保留 Unix 权限/时间戳
- **zip**：Windows 友好，打包+压缩合一
- 生产备份用 tar.gz；跨平台给 Windows 用 zip

### Q2：scp 和 rsync 怎么选？

**答**：
- **scp**：简单、加密、单次传输
- **rsync**：增量、断点续传、镜像同步
- 大文件 / 频繁同步 → **rsync**
- 一次性小文件 → scp 够用

### Q3：rsync 增量同步原理？

**答**：rsync 把文件分成小块，对比两端 hash：
- 相同块 → 不传
- 不同块 → 只传不同部分

### Q4：rsync -a 包含哪些选项？

**答**：-a = -rlptgoD
- -r 递归
- -l 软链
- -p 权限
- -t 时间戳
- -g 组
- -o 所有者
- -D 设备文件

### Q5：tar.gz 和 tar.xz 选哪个？

**答**：
- **tar.gz**：速度快、压缩率中（最常用）
- **tar.xz**：压缩率高、速度慢（适合归档、不常备份）
- 临时备份用 gz；长期归档用 xz

### Q6：怎么实现两台服务器实时同步？

**答**：
1. **rsync + cron**：定时同步（分钟级）
2. **rsync + inotify**：文件变化触发同步
3. **lsyncd**：基于 inotify + rsync
4. 生产环境大型架构：**drbd / glusterfs / ceph**

---

## §22 链路

| 笔记 | 关系 |
|---|---|
| [[LinuxShell/shell]] | `$(date +%Y%m%d)` 用于备份命名 |
| [[Linux服务与SSH/Linux服务与SSH]] | scp / rsync 都走 SSH 协议 |
| [[Linux计划任务/cron]] | 定时同步可写 cron |
| [[Linux包管理/package]] | yum install rsync lrzsz |
| [[Linux日志与时间/Linux日志与时间]] | 备份日志文件用 tar |
| [[Linux用户权限/user-permission]] | scp 权限涉及文件所有者 |

**下一步**：完成 Linux文件传输 后可以选择：
- 🎯 **第 4 波 ①** [[Linux存储/]]（06.4-8 共 5 PDF）—— 文件系统 / 分区 / RAID / LVM / swap
- 🎯 **第 4 波 ②** [[Linux网络/]]（05.18 共 1 PDF）—— ip / ss / nmcli / DNS
- 🎯 **第 4 波 ③** [[Linux防火墙/]]（06.10 共 1 PDF）—— firewalld / zone / rich-rules