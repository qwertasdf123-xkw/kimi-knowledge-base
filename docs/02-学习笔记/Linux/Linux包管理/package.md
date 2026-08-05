---
title: Linux 包管理 — RPM / YUM / DNF / 源码编译
desc: 基于 06.CentOS-7-系统管理-2/1. Linux 软件包管理.pdf 的实操笔记。覆盖 RPM 包命名、rpm 查询安装卸载验证、YUM 仓库、EPEL、第三方仓库 (Docker/K8s)、源码编译 nginx 完整流程。
type: 笔记
module: Linux包管理
pdf: 06.1 Linux 软件包管理.pdf
pdf_size: 1.4 MB / 1,539 行
scope: CentOS-7 / RHEL 系（YUM + RPM）
status: 完成
---

# Linux 包管理 — RPM / YUM / DNF / 源码编译

> **范围**：基于《CentOS-7 系统管理 2》PDF 1 整理。覆盖 **RPM** + **YUM/DNF** + **仓库配置** + **源码编译** 完整流程。
>
> **适用**：CentOS-7 / RHEL 系。Debian/Ubuntu 系（apt/dpkg）流程类似，命令名不同。

## 目录

- [[#§0 心智模型：包管理 = 购物车 + 安装器]]
- [[#§1 Linux 包管理三大流派]]
- [[#§2 RPM 包命名规则]]
- [[#§3 GPG 签名验证]]
- [[#§4 rpm 查询 8 件套]]
- [[#§5 rpm 安装 / 卸载 / 验证]]
- [[#§6 YUM / DNF 基础 4 件套]]
- [[#§7 YUM 仓库配置 /etc/yum.repos.d/]]
- [[#§8 EPEL 第三方仓库]]
- [[#§9 yumdownloader 下载但不安装]]
- [[#§10 yum group 组管理]]
- [[#§11 实战：装 Docker CE]]
- [[#§12 实战：装 Kubernetes]]
- [[#§13 源码编译 3 步走：configure / make / make install]]
- [[#§14 实战：编译 nginx + systemd 服务化]]
- [[#§15 速查表]]
- [[#§16 易错点 ×12]]
- [[#§17 面试 6 大追问]]
- [[#§18 链路]]

---

## §0 心智模型：包管理 = 购物车 + 安装器

```
Windows 装软件：百度搜 → 下载 .exe → 双击 → 下一步 → 完成
Linux 装软件  ：YUM 搜 → 仓库里下 → 一行命令 → 自动装

包管理器 = 帮你做了 4 件事：
  1. 软件搜索（不用百度）
  2. 依赖解析（自动装所依赖的库）
  3. 下载安装（一行命令搞定）
  4. 升级/卸载（统一管理）
```

**核心三角色**：
- **包**：软件的"压缩包"（.rpm / .deb）
- **仓库**：包们住的"商场"（base / epel / docker-ce）
- **工具**：帮你"逛商场"（rpm / yum / dnf）

---

## §1 Linux 包管理三大流派

| 流派           | 包格式     | 包工具                          | 典型发行版                            |
| ------------ | ------- | ---------------------------- | -------------------------------- |
| **RedHat 系** | `.rpm`  | `rpm` / `yum` / `dnf`        | RHEL, CentOS, Rocky, Fedora, OEL |
| **Debian 系** | `.deb`  | `dpkg` / `apt`               | Debian, Ubuntu, Kali             |
| **其他**       | 源码 / 自有 | `pacman` / `emerge` / `xbps` | Arch / Gentoo / Void             |

> 💡 **本笔记专注 RedHat 系**（CentOS-7）。Debian 系用 `apt-get` / `dpkg`，原理一样。

---

## §2 RPM 包命名规则

```
完整文件名格式：
name-version-release.architecture.rpm

例：
lrzsz-0.12.20-36.el7.x86_64.rpm
^^^^^ ^^^^^^^ ^^^^^^ ^^^^^^^
name  version release arch
```

| 字段               | 含义          | 例子                                            |
| ---------------- | ----------- | --------------------------------------------- |
| **name**         | 包名          | `lrzsz`                                       |
| **version**      | 原始版本        | `0.12.20`                                     |
| **release**      | 发行版打包号 + OS | `36.el7`（第 36 次打包，el7 = Enterprise Linux 7）   |
| **architecture** | 架构          | `x86_64` / `aarch64`（ARM 64）/ `noarch`（无架构限制） |

### 2.1 常见架构

| arch            | 含义             |
| --------------- | -------------- |
| `x86_64`        | 64 位 Intel/AMD |
| `i386` / `i686` | 32 位 Intel/AMD |
| `aarch64`       | 64 位 ARM       |
| `noarch`        | 无架构限制（脚本、文档等）  |

---

## §3 GPG 签名验证

```
GPG = GNU Privacy Guard，签名验证机制

每个 RPM 包由 CentOS 官方用私钥签名
你的机器用对应的公钥验证：
  - 签名有效 → 包没被篡改，安全
  - 签名无效 → 包可能损坏或被改，拒绝

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7   # 导入 CentOS-7 公钥
```

> 💡 `gpgcheck=0` 会跳过验证——方便装第三方包，但**不安全**。生产环境**别关**。

---

## §4 rpm 查询 8 件套

### 4.1 基本查询

```bash
# 查所有已装的包（很长，配合 | grep）
[root@centos7 ~]# rpm -qa
libqmi-utils-1.18.0-2.el7.x86_64
libmpcdec-1.2.6-12.el7.x86_64
gtkmm30-3.22.2-1.el7.x86_64
nss-sysinit-3.67.0-4.el7_9.x86_64
......

# 查指定包
[root@centos7 ~]# rpm -q httpd
未安装软件包 httpd

[root@centos7 ~]# rpm -q kernel
kernel-3.10.0-1160.71.1.el7.x86_64
```

### 4.2 详细信息 -i (info)

```bash
[root@centos7 ~]# rpm -q coreutils -i
Name        : coreutils
Version     : 8.22
Release     : 24.el7_9.2
Architecture: x86_64
Install Date: 2025年07月18日 星期五 10时29分40秒
Group       : System Environment/Base
Size        : 14594210
License     : GPLv3+
Signature   : RSA/SHA256, 2020年11月18日, Key ID 24c6a8a7f4a80eb5
Source RPM  : coreutils-8.22-24.el7_9.2.src.rpm
Build Date  : 2020年11月17日 星期二 06时24分59秒
Build Host  : x86-01.bsys.centos.org
URL         : http://www.gnu.org/software/coreutils/
Summary     : A set of basic GNU tools commonly used in shell scripts
```

### 4.3 文件列表 -l (list)

```bash
[root@centos7 ~]# rpm -q openssh-server -l
/etc/pam.d/sshd
/etc/ssh/sshd_config
/etc/sysconfig/sshd
/usr/lib/systemd/system/sshd-keygen.service
/usr/lib/systemd/system/sshd.service
/usr/sbin/sshd
/usr/sbin/sshd-keygen
/usr/share/man/man5/sshd_config.5.gz
/usr/share/man/man8/sshd.8.gz
/var/empty/sshd
```

### 4.4 配置文件 -c (config files)

```bash
[root@centos7 ~]# rpm -q openssh-server -c
/etc/pam.d/sshd
/etc/ssh/sshd_config
/etc/sysconfig/sshd
```

### 4.5 文档 -d (doc files)

```bash
[root@centos7 ~]# rpm -q openssh-server -d
/usr/share/man/man5/moduli.5.gz
/usr/share/man/man5/sshd_config.5.gz
/usr/share/man/man8/sftp-server.8.gz
/usr/share/man/man8/sshd.8.gz
```

### 4.6 反查：哪个包提供了这个文件 -f (file)

```bash
[root@centos7 ~]# rpm -q -f /etc/ssh/sshd_config
openssh-server-7.4p1-22.el7_9.x86_64
```

### 4.7 安装脚本 --scripts

```bash
[root@centos7 ~]# rpm -q openssh-server --scripts
preinstall scriptlet (using /bin/sh):
    ......
postinstall scriptlet (using /bin/sh):
    ......
preuninstall scriptlet (using /bin/sh):
    ......
postuninstall scriptlet (using /bin/sh):
    ......
```

### 4.8 变更日志 --changelog

```bash
[root@centos7 ~]# rpm -q openssh-server --changelog
* 三  9 30 2021 Dmitry Belyavskiy <dbelyavs@redhat.com> - 7.4p1-22 + 0.10.3-2
- avoid segfault in Kerberos cache cleanup (#1999263)
- fix CVE-2021-41617 (#2008884)
```

### 4.9 查未安装包 -p (package file)

```bash
# 下载 httpd 但不装
[root@centos7 ~]# yumdownloader httpd
[root@centos7 ~]# ls httpd-*
httpd-2.4.6-99.el7.centos.1.x86_64.rpm

# 查这个 .rpm 的文件列表（加 -p）
[root@centos7 ~]# rpm -q -p httpd-2.4.6-99.el7.centos.1.x86_64.rpm -l
/etc/httpd/conf.d/autoindex.conf
/etc/httpd/conf.d/userdir.conf
/etc/httpd/conf.d/welcome.conf
......

# ⚠️ -l / -c / -d / -i 都要加 -p 才能用于未装包
```

### 4.10 按组查 -g (group)

```bash
[root@centos7 ~]# rpm -qg 'System Environment/Base'
grub2-common-2.02-0.87.0.1.el7.centos.9.noarch
centos-release-7-9.2009.1.el7.centos.x86_64
setup-2.8.71-11.el7.noarch
filesystem-3.2-25.el7.x86_64
```

---

## §5 rpm 安装 / 卸载 / 验证

### 5.1 安装 -i (--install)

```bash
# 1) 下载包
[root@centos7 ~]# wget http://mirrors.aliyun.com/centos/7/os/x86_64/Packages/lrzsz-0.12.20-36.el7.x86_64.rpm

# 2) 安装（-i 是 install）
[root@centos7 ~]# rpm -i lrzsz-0.12.20-36.el7.x86_64.rpm

# 3) 验证
[root@centos7 ~]# rpm -q lrzsz
lrzsz-0.12.20-36.el7.x86_64

# 4) 卸载
[root@centos7 ~]# rpm -e lrzsz
```

### 5.2 安装选项 -ivh（推荐）

```bash
# -i = install
# -v = verbose（显示详情）
# -h = hash（显示进度条 #####）

[root@centos7 ~]# rpm -ivh lrzsz-0.12.20-36.el7.x86_64.rpm
Verifying...                          ################################# [100%]
准备中...                             ################################# [100%]
正在升级/安装...
   1:lrzsz-0.12.20-36.el7             ################################# [100%]
```

### 5.3 依赖问题演示

```bash
# 装 httpd：要先装 apr / apr-util / httpd-tools / mailcap
[root@centos7 ~]# rpm -ivh httpd-2.4.6-99.el7.centos.1.x86_64.rpm
错误：依赖检测失败：
    /etc/mime.types          被 httpd-2.4.6-99.el7.centos.1.x86_64 需要
    apr-util = 2.4.6-99.el7.centos.1     被 httpd-2.4.6-99.el7.centos.1.x86_64 需要
    libapr-1.so.0()(64bit)   被 httpd-2.4.6-99.el7.centos.1.x86_64 需要
    libaprutil-1.so.0()(64bit) 被 httpd-2.4.6-99.el7.centos.1.x86_64 需要

# 解决：用 yum 自动解决依赖（推荐）
[root@centos7 ~]# yum install httpd
# 或者用 --nodeps 强制（不推荐，可能崩）
[root@centos7 ~]# rpm -ivh httpd-*.rpm --nodeps
```

### 5.4 卸载 -e (--erase)

```bash
# 基本卸载
[root@centos7 ~]# rpm -e lrzsz

# 显示进度
[root@centos7 ~]# rpm -evh lrzsz
正在升级/安装...
   1:lrzsz-0.12.20-36.el7             ################################# [100%]

# 卸依赖
[root@centos7 ~]# rpm -e apr apr-util httpd-tools mailcap
```

### 5.5 验证 -V (--verify)

```bash
# 验证 openssh-server 是否被改过
[root@centos7 ~]# rpm -V openssh-server
# 空输出 → 没被改

# 故意改一下配置
[root@centos7 ~]# sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
[root@centos7 ~]# rpm -V openssh-server
S.5....T. c /etc/ssh/sshd_config
# ↑ 输出有内容 = 被改了
# 含义：
#   S = 文件大小变了
#   5 = MD5 校验和不匹配
#   T = mtime 改了
#   c = 这是配置文件
```

### 5.6 重装 --reinstall

```bash
# 配置乱了？直接重装（配置文件会被覆盖，谨慎！）
[root@centos7 ~]# rpm --reinstall -vh lrzsz*
Verifying...                          ################################# [100%]
准备中...                             ################################# [100%]
正在升级/安装...
   1:lrzsz-0.12.20-36.el7             ################################# [100%]
```

---

## §6 YUM / DNF 基础 4 件套

> 💡 **YUM = Yellowdog Updater Modified**，CentOS-7 默认；**DNF = Dandified Yum**，CentOS-8+ 默认。本质一样。

### 6.1 查找 + 安装 install

```bash
# 搜索
[root@centos7 ~]# yum search httpd

# 安装（自动解决依赖）
[root@centos7 ~]# yum install -y httpd

# 装本地包（解决依赖）
[root@centos7 ~]# yum localinstall ./vsftpd-3.0.2-29.el7_9.x86_64.rpm

# 不检查签名（第三方仓库常用）
[root@centos7 ~]# yum install kubectl --nogpgcheck
```

### 6.2 升级 update

```bash
# 升级指定包
[root@centos7 ~]# yum update vsftpd-3.0.2-29.el7_9

# 升级所有
[root@centos7 ~]# yum update

# 检查可升级的（不真升）
[root@centos7 ~]# yum check-update
```

### 6.3 降级 downgrade

```bash
# 装新版后发现有 bug？降回去
[root@centos7 ~]# yum downgrade -y vsftpd-3.0.2-28.el7

# 降级 httpd（解决 httpd-tools 冲突）
[root@centos7 ~]# yum downgrade -y httpd-tools-2.4.6-97.el7.centos httpd-2.4.6-97.el7.centos
```

### 6.4 卸载 remove

```bash
# 卸载（自动卸依赖，但可能留配置文件）
[root@centos7 ~]# yum remove -y vsftpd

# 完整清理（含配置）
[root@centos7 ~]# yum remove -y vsftpd && rm -rf /etc/vsftpd
```

---

## §7 YUM 仓库配置 /etc/yum.repos.d/

### 7.1 仓库在哪里

```bash
[root@centos7 ~]# ls /etc/yum.repos.d/
CentOS-Base.repo       # 基础仓库（base + extras + updates）
CentOS-Media.repo      # 本地光盘
epel.repo              # EPEL 仓库
docker-ce.repo         # Docker 仓库（自建）
```

### 7.2 仓库文件结构（epel.repo 示例）

```ini
[epel]                                    # 仓库 ID（[] 包起来）
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=http://mirrors.aliyun.com/epel/7/$basearch
failovermethod=priority
enabled=1                                 # 1 = 启用，0 = 禁用
gpgcheck=0                                # 1 = 检查 GPG 签名，0 = 不检查
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/7/$basearch/debug
enabled=0                                 # ← 默认禁用
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
```

| 字段         | 含义                                      |
| ---------- | --------------------------------------- |
| `[name]`   | 仓库 ID，唯一标识                              |
| `name`     | 仓库描述（人类可读）                              |
| `baseurl`  | 仓库 URL（支持 `$basearch`/`$releasever` 变量） |
| `enabled`  | 是否启用（1/0）                               |
| `gpgcheck` | 是否检查 GPG 签名（1/0）                        |
| `gpgkey`   | GPG 公钥文件路径                              |

### 7.3 列出所有仓库

```bash
# 看启用的
[root@centos7 ~]# yum repolist
repo id            repo name                                   status
base/7/x86_64      CentOS-7 - Base - mirrors.aliyun.com        10,072
epel/x86_64        Extra Packages for Enterprise Linux 7       13,791
extras/7/x86_64    CentOS-7 - Extras - mirrors.aliyun.com          526
updates/7/x86_64   CentOS-7 - Updates - mirrors.aliyun.com      6,173
repolist: 30,562

# 看所有（含禁用的）
[root@centos7 ~]# yum repolist all
```

### 7.4 启用 / 禁用仓库

```bash
# 启用（命令方式）
[root@centos7 ~]# yum-config-manager --enable epel-debuginfo

# 禁用
[root@centos7 ~]# yum-config-manager --disable epel-debuginfo

# 或直接改 enabled=1/0
[root@centos7 ~]# vim /etc/yum.repos.d/epel.repo
```

### 7.5 添加新仓库

```bash
# 方法 1：手写 repo 文件
cat > /etc/yum.repos.d/my.repo << 'EOF'
[myrepo]
name=My Custom Repo
baseurl=http://mirrors.example.com/centos/7/
enabled=1
gpgcheck=0
EOF

# 方法 2：用 yum-config-manager 一键加
[root@centos7 ~]# yum-config-manager --add-repo=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
# 自动生成文件 /etc/yum.repos.d/mirrors.aliyun.com_kubernetes_*.repo
```

### 7.6 缓存清理

```bash
# 清所有缓存
[root@centos7 ~]# yum clean all

# 重建元数据缓存
[root@centos7 ~]# yum makecache
base                                       | 3.6 kB
epel                                       | 2.9 kB
......

# 改完仓库配置后必跑！
```

---

## §8 EPEL 第三方仓库

### 8.1 什么是 EPEL

```
EPEL = Extra Packages for Enterprise Linux
由 Fedora Special Interest Group 维护
给 RHEL / CentOS 提供"额外"的包（base 仓库没有的）
```

### 8.2 一键装 EPEL

```bash
# 阿里云镜像（推荐国内用）
[root@centos7 ~]# curl -s -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# 或 yum 直接装
[root@centos7 ~]# yum install epel-release

# 验证
[root@centos7 ~]# yum repolist | grep epel
epel/x86_64       Extra Packages for Enterprise Linux 7 - x86_64     13,791
```

---

## §9 yumdownloader 下载但不安装

> 💡 **场景**：只想下包给别处用，或者想本地验包信息

```bash
# 下载到当前目录
[root@centos7 ~]# yumdownloader httpd
[root@centos7 ~]# ls httpd-*
httpd-2.4.6-99.el7.centos.1.x86_64.rpm

# 下载 + 依赖（不解压）
[root@centos7 ~]# yumdownloader --resolve httpd

# 查包文件列表（不装！）
[root@centos7 ~]# rpm -q -p httpd-2.4.6-99.el7.centos.1.x86_64.rpm -l
```

---

## §10 yum group 组管理

### 10.1 列组

```bash
# 列所有组（含中文环境）
[root@centos7 ~]# yum grouplist
可用环境组：
   最小安装
   计算节点
   基础设施服务器
   文件和打印服务器
   基本 Web 服务器
   虚拟化主机
   带 GUI 的服务器
   GNOME 桌面
   KDE Plasma Workspaces
   开发及生成工作站
可用组：
   Cinnamon
   Fedora Packager
   Haskell
......

# 详细列表（带 ID）
[root@centos7 ~]# yum grouplist -v
```

### 10.2 看组里有什么

```bash
[root@centos7 ~]# yum groupinfo 'Server with GUI'
# 或
[root@centos7 ~]# yum groupinfo "带 GUI 的服务器"

# 输出包含：
#   Group: 带 GUI 的服务器
#   Description: ...
#   Mandatory Packages:   ← 必装
#       NetworkManager
#       ...
#   Default Packages:     ← 默认装
#       ...
#   Optional Packages:    ← 选装
#       ...
```

### 10.3 装组

```bash
[root@centos7 ~]# yum groupinstall -y 'Development Tools'

# 或用 group ID
[root@centos7 ~]# yum groupinstall -y development
```

### 10.4 卸组

```bash
[root@centos7 ~]# yum groupremove -y 'Development Tools'
```

---

## §11 实战：装 Docker CE

```bash
# 1) 卸载旧版（如果有）
[root@centos7 ~]# yum remove docker docker-common docker-selinux docker-engine

# 2) 添加 docker-ce 仓库
[root@centos7 ~]# cat > /etc/yum.repos.d/docker-ce.repo << 'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/$releasever/$basearch/stable
enabled=1
gpgcheck=0
EOF

# 3) 验证能看到 docker-ce
[root@centos7 ~]# yum list docker-ce
Available Packages
docker-ce.x86_64                3:20.10.22-3.el7                docker-ce-stable

# 4) 安装
[root@centos7 ~]# yum install -y docker-ce

# 5) 启动 + 开机自启
[root@centos7 ~]# systemctl start docker
[root@centos7 ~]# systemctl enable docker

# 6) 验证
[root@centos7 ~]# docker version
```

---

## §12 实战：装 Kubernetes

```bash
# 1) 加阿里云 k8s 仓库
[root@centos7 ~]# yum-config-manager --add-repo=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/

# 2) 装 kubectl（不验签名）
[root@centos7 ~]# yum install kubectl --nogpgcheck

# 3) 验证
[root@centos7 ~]# kubectl version --client
```

---

## §13 源码编译 3 步走：configure / make / make install

> 💡 **场景**：仓库里没有 / 要最新版 / 要定制功能。代价：复杂、慢、易失败。

### 13.1 经典流程

```bash
# 1) 装编译工具（gcc / make / 开发库）
[root@centos7 ~]# yum install gcc make pcre-devel zlib-devel

# 2) 下源码（官网 / GitHub）
[root@centos7 ~]# wget https://nginx.org/download/nginx-1.24.0.tar.gz

# 3) 解压
[root@centos7 ~]# tar -xf nginx-1.24.0.tar.gz

# 4) configure（检查环境 + 生成 Makefile）
[root@centos7 ~]# cd nginx-1.24.0/
[root@centos7 nginx-1.24.0]# ./configure --prefix=/usr/local/nginx
# 默认装到 /usr/local/nginx（可用 --prefix 改）

# 5) 编译（生成可执行文件）
[root@centos7 nginx-1.24.0]# make

# 6) 安装（复制到 prefix）
[root@centos7 nginx-1.24.0]# make install

# 7) 看结果
[root@centos7 ~]# ls /usr/local/nginx/
conf html logs sbin
```

### 13.2 流程图

```
源码包 (.tar.gz)
    │
    ↓ tar -xf
源码目录（含 configure 脚本）
    │
    ↓ ./configure --prefix=...
检查系统环境（编译器、依赖库）
    ↓
生成 Makefile（编译规则）
    │
    ↓ make
调用 gcc 编译 → 生成可执行文件（二进制）
    │
    ↓ make install
复制到 prefix 指定的目录
    │
    ↓ /usr/local/.../
可用了！
```

### 13.3 常见 configure 选项

| 选项 | 含义 |
|---|---|
| `--prefix=PATH` | 安装目录（默认 /usr/local）|
| `--with-XXX` | 启用某功能 |
| `--without-XXX` | 禁用某功能 |
| `--enable-XXX` | 启用某模块 |
| `--help` | 看所有选项 |

```bash
# 例：nginx 加 SSL 模块 + 改路径
./configure --prefix=/opt/nginx \
            --with-http_ssl_module \
            --with-http_stub_status_module
```

---

## §14 实战：编译 nginx + systemd 服务化

```bash
# 1) 装依赖
[root@centos7 ~]# yum install gcc make pcre-devel zlib-devel openssl-devel

# 2) 下 + 解压（见 §13）

# 3) configure
[root@centos7 ~]# cd nginx-1.24.0/
[root@centos7 nginx-1.24.0]# ./configure --prefix=/usr/local/nginx

# 4) 编译 + 安装
[root@centos7 nginx-1.24.0]# make && make install

# 5) 启动 nginx
[root@centos7 ~]# /usr/local/nginx/sbin/nginx

# 6) 验证
[root@centos7 ~]# curl -s http://localhost | grep Thank
<p><em>Thank you for using nginx.</em></p>

# 7) 把 nginx 加到 PATH（永久）
[root@centos7 ~]# echo 'export PATH=$PATH:/usr/local/nginx/sbin/' >> ~/.bashrc
[root@centos7 ~]# source ~/.bashrc

# 8) 写 systemd 服务（推荐）
[root@centos7 ~]# cp /usr/lib/systemd/system/sshd.service /etc/systemd/system/nginx.service
[root@centos7 ~]# vim /etc/systemd/system/nginx.service

[Unit]
Description=Nginx server daemon

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit

[Install]
WantedBy=multi-user.target

# 9) 重载 + 启动 + 开机自启
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl enable nginx.service --now

# 10) nginx 控制
nginx                  # 启动
nginx -s reload        # 重载配置（不中断）
nginx -s quit          # 优雅停止
nginx -s stop          # 快速停止
```

---

## §15 速查表

### 15.1 rpm 查询

```bash
rpm -qa                       # 全部
rpm -q 包名                   # 单包
rpm -q -i 包名                # 信息
rpm -q -l 包名                # 文件列表
rpm -q -c 包名                # 配置文件
rpm -q -d 包名                # 文档
rpm -q -f 文件路径            # 反查
rpm -q --scripts 包名         # 安装脚本
rpm -q --changelog 包名       # 变更日志
rpm -q -p 文件.rpm -l         # 查未装包
rpm -qg '组名'                # 按组查
```

### 15.2 rpm 安装/卸载

```bash
rpm -ivh 文件.rpm             # 装（推荐）
rpm -i 文件.rpm               # 装（无进度）
rpm -Uvh 文件.rpm             # 升级装
rpm -e 包名                   # 卸载
rpm -V 包名                   # 验证
rpm --reinstall -vh 包名       # 重装
rpm -ivh 文件.rpm --nodeps    # 强制不检依赖
rpm -q --whatprovides "能力"   # 哪个包提供
rpm -q --whatrequires "能力"  # 哪个包依赖
```

### 15.3 YUM 基础

```bash
yum install -y 包名           # 安装
yum remove -y 包名            # 卸载
yum update                    # 升级所有
yum update 包名               # 升级单个
yum downgrade -y 包名-版本   # 降级
yum search 关键字             # 搜索
yum list                      # 列出所有
yum info 包名                 # 详细信息
yum provides 文件路径         # 反查（哪个包提供）
yum localinstall 文件.rpm     # 装本地包
yum install 包名 --nogpgcheck # 不验签名
yum clean all                 # 清缓存
yum makecache                 # 重建缓存
```

### 15.4 YUM 仓库

```bash
yum repolist                  # 列启用的仓库
yum repolist all              # 列所有（含禁用）
yum-config-manager --enable ID
yum-config-manager --disable ID
yum-config-manager --add-repo URL

# 编辑仓库文件
vim /etc/yum.repos.d/*.repo
```

### 15.5 YUM 组

```bash
yum grouplist                 # 列组
yum grouplist -v              # 详细
yum groupinfo '组名'         # 看组
yum groupinstall -y '组名'   # 装组
yum groupremove -y '组名'    # 卸组
```

### 15.6 源码编译

```bash
./configure --prefix=/usr/local/app  # 配置
make                                  # 编译
make install                          # 安装
make clean                            # 清理编译产物
```

---

## §16 易错点 ×12

### 1. ❌ rpm 直接装 .rpm，不解决依赖

```bash
rpm -ivh httpd.rpm
# 错误：依赖检测失败...
# 解决：用 yum install httpd（自动解依赖）
```

### 2. ❌ rpm -e 卸包时还有别的包依赖它

```bash
rpm -e openssh-server
# 错误：依赖检测失败...
# 解决：先卸依赖包，或 yum remove openssh-server
```

### 3. ❌ yum install 后忘了 systemctl start

```bash
yum install -y nginx
# ⚠️ 没启动！要 systemctl start nginx
```

### 4. ❌ yum 找不到包

```bash
yum install docker
# 没找到？
# 检查：① 仓库配置错了 ② 网络不通 ③ 包名打错了 ④ 包不在该仓库
# 解决：yum search docker / yum repolist all
```

### 5. ❌ yum update 跨大版本

```bash
yum update
# CentOS-7 的 yum update 不会跨大版本（不会变 8.0）
# 但可能装不兼容的新版内核！→ 需要锁定 kernel 包
```

### 6. ❌ 源码编译装到默认路径（污染 /usr/local）

```bash
./configure       # 默认 --prefix=/usr/local
# 不指定 prefix 会装到 /usr/local/bin /usr/local/lib
# 建议：每个应用单独目录 /opt/myapp 或 /usr/local/myapp
```

### 7. ❌ 源码编译忘了装依赖

```bash
./configure
# checking for ... not found
# 解决：yum install gcc make pcre-devel zlib-devel ...
```

### 8. ❌ make install 后忘了设 PATH

```bash
make install                          # 装到 /usr/local/nginx/sbin/
nginx                                 # bash: nginx: command not found
# 解决：export PATH=$PATH:/usr/local/nginx/sbin/
```

### 9. ❌ 源码升级 nginx 忘了 systemctl daemon-reload

```bash
# 改了 /etc/systemd/system/nginx.service
systemctl daemon-reload               # ← 必须！
systemctl restart nginx
```

### 10. ❌ /etc/yum.repos.d/ 写错 enabled 字段

```ini
[myrepo]
enabled=Yes    # ⚠️ 大小写错！
# 应该是 enabled=1（数字）
```

### 11. ❌ 第三方仓库忘了 --nogpgcheck

```bash
yum install kubectl
# 警告：无法信任的签名...
# 解决：要么导入公钥，要么 --nogpgcheck
```

### 12. ❌ 升级内核导致服务器起不来

```bash
yum update kernel
# ⚠️ 新内核可能不兼容硬件！
# 备份：开机时选 GRUB 旧内核
# 预防：vim /etc/yum.conf 加 exclude=kernel*
```

---

## §17 面试 6 大追问

### Q1：RPM 和 YUM 区别？

**答**：
- **rpm**：底层工具，只管**装/卸/查单个 .rpm**，**不解决依赖**
- **yum**：上层工具，从**仓库**自动**解析依赖**后调用 rpm

**类比**：rpm 是手动挡，yum 是自动挡。

### Q2：`rpm -qa | grep xxx` 和 `yum list installed` 区别？

**答**：
- `rpm -qa`：RPM 数据库（本地事实）
- `yum list installed`：yum 缓存（可能稍旧）

**实际差不多**，`rpm -qa` 更权威。

### Q3：`yum update` 和 `yum upgrade` 区别？

**答**：
- 在 CentOS-7 上**完全一样**（`upgrade` 是 `update` 的别名）
- 历史上：`update` 会保留旧包，`upgrade` 会删除
- **现在用 `update` 就行**

### Q4：源码编译 vs RPM 包 怎么选？

**答**：

| 场景      | 选择            |
| ------- | ------------- |
| 仓库里有稳定版 | RPM（推荐）       |
| 要最新版    | 源码 / 第三方仓库    |
| 要定制功能   | 源码            |
| 生产服务器   | RPM（稳定）       |
| 无网络环境   | 源码或 RPM（提前下好） |

### Q5：怎么降级一个包？

**答**：
```bash
yum downgrade -y 包名-版本号
# 例：yum downgrade -y vsftpd-3.0.2-28.el7
```

### Q6：YUM 仓库优先级怎么设？

**答**：
- 在 /etc/yum.repos.d/*.repo 加 `priority=N`（数字越小越优先）
- 需要装 yum-plugin-priorities：`yum install yum-plugin-priorities`
- **建议**：base 仓库 priority=1，epel priority=10，第三方 priority=20

---

## §18 链路

| 笔记 | 关系 |
|---|---|
| [[LinuxShell/shell#§7 HISTTIMEFORMAT]] | shell 环境变量 |
| [[LinuxShell/shell#§20 数值计算 7 武器]] | `./configure` 时常算依赖版本 |
| [[Linux文本处理/sed]] | 批量改 yum 仓库配置 |
| [[Linux文本处理/awk]] | 解析 rpm -qa 输出 |
| [[LinuxShell/shell#§27 Shell 函数]] | 写"自动部署"函数（含 install + start）|
| [[Linux目录/Linux目录导航]] | 路径查找（/usr/bin / /usr/local）|

### 包管理完整流程图

```
              ┌─────────────────────────────────┐
              │   仓库 (Repository)              │
              │  base / epel / docker-ce / k8s  │
              └────────────┬────────────────────┘
                           │ yum install
                           ↓
              ┌─────────────────────────────────┐
              │   YUM/DNF（解依赖 + 下载）        │
              └────────────┬────────────────────┘
                           │ 自动调用
                           ↓
              ┌─────────────────────────────────┐
              │   RPM（底层安装器）              │
              │  -i / -e / -V / -q              │
              └────────────┬────────────────────┘
                           │
                           ↓
              ┌─────────────────────────────────┐
              │   文件系统 /usr /etc /var       │
              └─────────────────────────────────┘

备选路径（仓库里没有时）：
源码 → configure → make → make install → /usr/local
```

**下一步**：进入 [[Linux计划任务]]（PDF 06.2），继续第一波三件套；或跳到第二波 [[Linux进程与负载]]。