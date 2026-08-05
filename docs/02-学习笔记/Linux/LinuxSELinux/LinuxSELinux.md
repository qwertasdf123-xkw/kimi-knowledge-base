---
title: Linux SELinux — 系统级安全保镖
desc: 基于 06.CentOS-7-系统管理-2/11. Linux SELinux 加固系统.pdf 的实操笔记（12 页）。覆盖 SELinux 概念 + DAC/MAC 对比 + 4 段标签 + 3 种模式 + chcon/restorecon + semanage fcontext + 实战 /www + semanage port + 布尔值 + sealert 排错 + 6 步 SOP。
type: 笔记
module: LinuxSELinux
pdfs:
  - 06.11 Linux SELinux 加固系统.pdf (434 KB / 12 页)
pdf_size: 444422 字节
scope: CentOS-7.x（参考 RHEL 7，targeted 策略）
status: 完成
---

# Linux SELinux — 系统级安全保镖

> **范围**：基于《CentOS-7 系统管理 2》第 11 章 整理（12 页 PDF，434 KB）。
> 覆盖 **SELinux 概念** + **DAC/MAC 对比** + **4 段标签** + **3 种模式** + **chcon / restorecon** + **semanage fcontext** + **实战 /www** + **semanage port** + **布尔值** + **sealert 排错** + **6 步 SOP**。
>
> **适用**：CentOS-7 / RHEL 7 系（默认 targeted 策略）。
>
> **前置**：[[Linux启动原理/Linux启动原理]] 已有内核参数 / 启动链知识；本章讲解的系统加固层在**内核之后、用户空间之前生效**。

## 目录

- [[#§0 心智模型：SELinux = 系统级保镖 + 标签警察]]
- [[#§1 SELinux 是什么：从 DAC 到 MAC]]
- [[#§2 安全上下文 4 字段]]
- [[#§3 SELinux 三种模式]]
- [[#§4 新文件默认 SELinux 标签]]
- [[#§5 设置文件标签：chcon + restorecon]]
- [[#§6 semanage fcontext：永久修改规则]]
- [[#§7 实战：把 /www 配置成 web 站点]]
- [[#§8 SELinux 端口标签：semanage port]]
- [[#§9 SELinux 布尔值（booleans）]]
- [[#§10 调查和解决 SELinux 问题]]
- [[#§11 SELinux 问题处理思路 6 步 SOP]]
- [[#§12 易错点 ×10]]
- [[#§13 速查表]]
- [[#§14 面试 6 大追问]]

---

## §0 心智模型：SELinux = 系统级保镖 + 标签警察

把 SELinux 想象成 **银行金库的保安系统**：

| 层级 | 比喻 | 实际 |
|---|---|---|
| Linux 文件权限（rwx） | 大门门禁卡 | 普通用户能否读写文件 |
| **DAC**（Discretionary Access Control） | 用户可以**自己决定**要不要给别人开门 | Linux 文件权限模型 |
| **SELinux**（MAC） | 银行的**保安** + **摄像头** | 按"标签"严格规则，即使你拿到门禁卡也不能进 |
| 标签（context） | **每个人的身份牌** | 用户/文件/端口都有 user:role:type:sensitivity |
| 策略（policy） | 银行的**安保手册** | 规定什么身份的人能进什么房间 |

### 为什么需要 SELinux？

**故事时间**：你的 Web 服务器跑着 apache 进程。黑客攻击 apache 拿到 apache 用户的权限。

- **没有 SELinux**：apache 用户能访问 `/tmp`、`/var/tmp` 等所有全局可写目录，**黑客可以直接从这里把数据偷走**。
- **有 SELinux**：apache 进程的标签是 `httpd_t`，即使有 apache 权限，**也访问不了 tmp_t 标签的目录**。**数据更安全**。

### SELinux 关键行为

> **"除非显式规则授予访问权限，否则策略不允许任何交互"** —— 这是 SELinux 的**默认拒绝**原则（白名单机制）。

```
进程（P）能否访问文件（F）？
   ↓
检查规则：进程标签 P_t 是否允许访问文件标签 F_t？
   ↓
├─ 允许 → OK
└─ 不允许 → 拒绝 + 记录 AVC 日志
```

---

## §1 SELinux 是什么：从 DAC 到 MAC

> **来源**：PDF 第 1 页。

### 1.1 DAC 模型（传统 Linux 文件权限）

**Discretionary Access Control**，自主访问控制：**用户可以把自己的权限给其他人**。

```bash
chmod 777 file      # 用户把文件设成任何人都能写
chown user file     # 用户可以把文件给别人
```

**问题**：**无法限定用户访问文件的方式**。

> **例子**：结构化数据文件（比如数据库的 data 文件）应该**只能用数据库程序写入**，但其他编辑器（如 vim）仍可以打开修改，可能损坏数据。
> 
> 文件权限只能控制**谁**能读/写/运行，**不能控制用什么程序**写。

### 1.2 SELinux 模型（MAC）

**Mandatory Access Control**，强制访问控制：**管理员/系统决定规则，用户绕不过去**。

```bash
# 即使 apache 用户能读 /tmp，apache 进程也不能读 tmp_t 标签文件
# 除非显式规则打开（默认拒绝）
```

**关键差异**：

| 维度 | DAC（传统） | SELinux（MAC） |
|---|---|---|
| 规则制定者 | **用户**自己 | **管理员 / 系统策略** |
| 默认行为 | 默认允许（除显式拒绝） | 默认拒绝（除显式允许） |
| 控制粒度 | 用户/组（谁能读） | 进程级（用什么身份/什么程序读） |
| 能否绕过 | 容易（root 可破一切） | 极难（root 也受 MAC 限制） |
| 适用 | 大多数场景 | 高安全场景（金融/政府/高敏感） |

### 1.3 SELinux 的核心目标

> **"防止已遭泄露的系统服务访问用户数据"**（PDF 原话）

### 1.4 例子：apache 入侵场景

**没有 SELinux 时**：
```
apache 进程被入侵
  ↓
攻击者获得 apache 用户权限
  ↓
apache 用户对 /var/www/html 有读权限 → 能读 web 文件 ✓（这是预期的）
apache 用户对 /tmp 有 rwx 权限（因为 /tmp 是 1777）→ 能读写 /tmp ❌（这是非预期的）
  ↓
攻击者把数据库数据写到 /tmp，再读出来 → 数据泄露
```

**有 SELinux 时**：
```
apache 进程标签 = httpd_t
/var/www/html 标签 = httpd_sys_content_t   ← apache 默认能访问 ✓
/tmp 标签 = tmp_t                          ← apache 默认禁止访问 ❌
  ↓
即使 apache 用户能读写 /tmp，apache 进程也被 SELinux 阻止 → 数据无法外泄
```

> **本质**：SELinux 是**进程级的访问控制**，比 Linux 文件权限**更细粒度**。

---

## §2 安全上下文 4 字段

> **来源**：PDF 第 1 页 SELinux 标签。

### 2.1 标签四部分：user:role:type:sensitivity

每个进程/文件/端口都有 **SELinux 上下文**，由 4 部分组成：

```
system_u:system_r:httpd_sys_content_t:s0
   ↑       ↑          ↑              ↑
 SELinux  角色      类型          敏感度
 用户              (targeted 策略关注的部分)
```

| 字段 | 含义 | 常见值 | 是否关键 |
|---|---|---|---|
| **user** | SELinux 用户（不同于 Linux 用户） | `system_u`（系统进程）/ `unconfined_u`（无约束） | 关键（决定 role） |
| **role** | 角色 | `system_r` / `unconfined_r` | 关键（决定 type） |
| **type** | 类型 | `httpd_sys_content_t` / `tmp_t` / `user_home_t` | ⭐⭐⭐ **targeted 策略核心** |
| **sensitivity** | 敏感度（MLS 用） | `s0` 到 `s15` | MLS 策略用，targeted 策略一般不需要关注 |

### 2.2 类型（type）= 规则的最小单位

> **"类型部分通常以 _t 结尾"**（PDF 原话）

| 进程类型 | 文件类型（资源） | 含义 |
|---|---|---|
| `httpd_t` | `httpd_sys_content_t` | apache 默认能读的 web 文件 |
| `sshd_t` | `sshd_home_t` | sshd 进程 + ssh 密钥目录 |
| `mysqld_t` | `mysqld_db_t` | mysql 进程 + 数据库文件 |
| `unconfined_t` | `unconfined_t` | 不受限（用户 shell 默认） |
| — | `tmp_t` | /tmp 默认标签 |
| — | `user_home_t` | 用户主目录默认 |
| — | `admin_home_t` | /root 默认 |
| — | `default_t` | 自建目录默认 |
| — | `public_content_t` | 公共读文件（如 FTP 匿名） |

### 2.3 命令的 -Z 选项

**几乎所有操作文件的命令都有 `-Z` 选项**，用来显示或设置 SELinux 上下文：

```bash
# 显示 SELinux 上下文
ls -Z /home
ps -eZ | head
netstat -Z -tlnp
cp --help   # 看 cp 是否支持 -Z
mkdir --help

# 显示 + 设置
chcon -t httpd_sys_content_t /var/www/html/index.html
restorecon -v /var/www/html/index.html
```

```bash
# 示例
[root@centos7 ~]# ps -C sshd -Z
LABEL                               PID TTY   TIME CMD
system_u:system_r:sshd_t:s0-s0:c0.c1023  951 ?  00:00:00 sshd
system_u:system_r:sshd_t:s0-s0:c0.c1023 1261 ?  00:00:00 sshd
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 1276 ? 00:00:00 sshd

[root@centos7 ~]# ls -Z /home
unconfined_u:object_r:user_home_dir_t:s0 laoma

[root@centos7 ~]# cp --help 2>&1 | grep -A1 '\-Z'
  -Z                  set SELinux security context of destination file to default type

[root@centos7 ~]# mkdir --help 2>&1 | grep '\-Z'
  -Z, --context=CONTEXT  set SELinux security context of each created directory to the default type
```

### 💬 回答你的疑问

> **Q1：为什么 shell 默认是 `unconfined_u`？**

**A**：用户登录进 shell，shell 进程是**不受限的**（unconfined），它不受 SELinux 规则约束。这意味着**用户主动执行的所有操作都不受 SELinux 限制**；只有**系统服务进程**（httpd / sshd / mysqld 等）受 SELinux 限制。

> **Q2：targeted 策略下类型是重点，MLS 策略下 sensitivity 是重点？**

**A**：是的。targeted 策略只关注 type，所以日常管理基本不用管 sensitivity。MLS 策略（如政府/军方）会用 sensitivity 做多级隔离，配置极复杂。

> **Q3：标签是"贴在"文件上的吗？**

**A**：是的。文件的标签存储在 **文件系统的扩展属性 xattr** 里（需要文件系统支持，比如 xfs/ext4）。挂载文件系统时自动加载。可以用 `getfattr -n security.selinux /file` 直接看。

---

## §3 SELinux 三种模式

> **来源**：PDF 第 2-3 页。

### 3.1 三模式对比

| 模式 | 行为 | 日志 | 用途 |
|---|---|---|---|
| **enforcing** | **强制**执行访问控制规则。违反 → **拒绝** + 记录日志 | 完整 AVC 日志 | **默认模式**，生产环境 |
| **permissive** | **加载策略但不强制**。违反 → **记录日志但不拒绝** | 完整 AVC 日志 | 测试 / 调试 / 故障排查 |
| **disabled** | **完全关闭** SELinux。不拒绝、不记录 | 无 SELinux 日志 | 紧急情况（少数） |

### 3.2 查看当前模式

```bash
getenforce
# Enforcing          ← 默认

# 或更详细
sestatus
# SELinux status:                 enabled
# SELinuxfs mount:                /sys/fs/selinux
# SELinux root directory:         /etc/selinux
# Loaded policy name:             targeted
# Current mode:                   enforcing
# Mode from config file:          enforcing
# Policy MLS status:              enabled
# Policy deny_unknown status:     allowed
# Max kernel policy version:      31
```

### 3.3 运行时切换：setenforce

```bash
# 强制模式 → 允许模式
setenforce 0
# 或
setenforce Permissive

# 允许模式 → 强制模式
setenforce 1
# 或
setenforce Enforcing
```

**特点**：**运行时切换不需要重启**。`setenforce` 只是改运行时策略，**不写**到 `/etc/selinux/config`。

### 3.4 永久配置：/etc/selinux/config

```bash
vi /etc/selinux/config
# SELINUX=enforcing     ← 三选一：enforcing / permissive / disabled
# SELINUXTYPE=targeted  ← 策略类型（targeted 是默认）
```

**生效时机**：**重启后**（改了这个文件不重启不会立刻生效）。

### 3.5 模式切换的"重启"边界

| 切换场景 | 需要重启？ | 原因 |
|---|---|---|
| enforcing ↔ permissive | ❌ 不需要 | 内核已加载策略，仅切换规则应用 |
| enforcing/permissive → disabled | ✅ **需要** | 要卸载 SELinux 子系统 + 重新挂载 |
| disabled → enforcing/permissive | ✅ **需要** | 要重新加载策略 + 重标记所有文件 |

> **坑警示**：从 disabled 切回 enforcing 需要 `touch /.autorelabel`，否则文件标签全乱，**所有服务起不来**。

### 3.6 内核参数（启动时临时切换）

在 GRUB 菜单 linux16 行加：

```bash
enforcing=1       # 强制模式
enforcing=0       # 许可模式
selinux=0          # 彻底禁用 SELinux
selinux=1          # 启用 SELinux
```

**实战场景**：忘了 touch /.autorelabel 就破解了 root 密码，导致登录失败。

```
# 重启后用正确密码登录 → 失败
# 原因：/etc/shadow 文件标签被破坏，用户验证程序无法访问
# 处理：在 GRUB 菜单加 selinux=1 enforcing=0 进 permissive 模式
# 然后登录成功，重建标签
```

> **这是 §5 启动原理 + 本章的经典联动场景**。

---

## §4 新文件默认 SELinux 标签

> **来源**：PDF 第 4 页。

### 4.1 默认规则：新文件继承父目录标签

```bash
# /tmp 父目录标签是 tmp_t
# 在 /tmp 下创建的文件自动继承 tmp_t（除非是 user_tmp_t）
```

```
/tmp/tmp_t 父目录
  ↓ 创建 /tmp/laoma
/tmp/laoma → 自动继承（实际为 user_tmp_t，因为 laoma 是用户）
```

### 4.2 两个例外：标签保持不变

| 场景 | 命令 | 行为 |
|---|---|---|
| **cp -a** 保留属性复制 | `cp -a src dst` | dst 保留 src 的标签（**不**继承父目录） |
| **mv 移动** 文件 | `mv src dst` | dst 保留 src 的标签（同分区移动） |

**示例验证**：

```bash
# 例 1：默认 cp 继承父目录标签
touch /tmp/laoma
ls -Zd /tmp /tmp/laoma
# /tmp       system_u:object_r:tmp_t:s0
# /tmp/laoma unconfined_u:object_r:user_tmp_t:s0  ← user_tmp_t 是因为 user

cp /tmp/laoma /root/laoma
ls -Zd /root /root/laoma
# /root      system_u:object_r:admin_home_t:s0
# /root/laoma unconfined_u:object_r:admin_home_t:s0  ← 继承父目录 /root

# 例 2：cp -a 保留原标签
cp -a /tmp/laoma /root/laoma-a
ls -Zd /root/laoma*
# /root/laoma    admin_home_t  ← 继承 /root
# /root/laoma-a  user_tmp_t    ← 保留 /tmp 原始标签

# 例 3：mv 保留原标签
mv /tmp/laoma /root/laoma-mv
ls -Zd /root/laoma*
# /root/laoma-mv user_tmp_t    ← 保留 /tmp 原始标签
```

> **坑**：**这是 SELinux 故障最常见的来源**！比如把文件从 /tmp mv 到 /var/www/html，**标签还是 tmp_t**，apache 默认禁止访问 → 用户以为权限问题，其实是 SELinux 标签问题。

---

## §5 设置文件标签：chcon + restorecon

> **来源**：PDF 第 5-6 页。

### 5.1 两个命令对比

| 命令 | 行为 | 持久？ | 用途 |
|---|---|---|---|
| **chcon** | **直接**改变 SELinux 上下文 | ❌ 不持久（下次 restorecon/relabel 后丢失） | **临时测试** |
| **restorecon** | 根据 SELinux 上下文数据库里的规则**恢复**文件标签 | ✅ 持久（数据库里有规则） | **正确做法** |

### 5.2 chcon 临时改标签

```bash
# 把 /www 临时改成 httpd 类型（测试用）
mkdir /www
ls -Zd /www
# unconfined_u:object_r:default_t:s0

chcon -t httpd_sys_content_t /www
ls -Zd /www
# unconfined_u:object_r:httpd_sys_content_t:s0  ← 改成功了

# 但 restorecon 后会还原
restorecon -v /www
# Relabeled /www from ... httpd_sys_content_t ... to ... default_t ...
ls -Zd /www
# unconfined_u:object_r:default_t:s0  ← 还回去了
```

> **结论**：**chcon 适合测试，但正式环境必须用 semanage fcontext + restorecon**（数据库化的方法）。

### 5.3 restorecon 恢复数据库标签

```bash
# 假设数据库里 /www 已经设置为 httpd_sys_content_t（用 semanage 加的规则）
restorecon -Rv /www/
# restorecon reset /www context unconfined_u:object_r:default_t:s0-
# >unconfined_u:object_r:httpd_sys_content_t:s0
# restorecon reset /www/index.html context ...
```

| 选项 | 含义 |
|---|---|
| `-R` | 递归 |
| `-v` | 显示详细过程 |
| `-n` | 不改变文件，只显示会做什么 |
| `-F` | 强制（即使标签已对） |

---

## §6 semanage fcontext：永久修改规则

> **来源**：PDF 第 5-6 页。**这是 SELinux 标签管理的核心**。

### 6.1 semanage fcontext 是干什么的？

**管理 SELinux 上下文数据库**。你加一条规则，以后 restorecon 就按规则来。

```
semanage fcontext -a -t TYPE PATH_REGEX   ← 把规则写进数据库
restorecon -Rv PATH                       ← 让数据库规则生效
```

### 6.2 完整 4 步走：把 /www 改成 web 目录

```bash
# 第 1 步：准备目录 + 文件
mkdir /www
echo "Hello World" > /www/index.html

# 第 2 步：安装工具
yum install -y policycoreutils-python    # 提供 semanage 命令

# 第 3 步：加规则到数据库
semanage fcontext -a -t httpd_sys_content_t '/www(/.*)?'
# (/.*)? 是扩展正则，意思是 /www 后面任意字符任意次数，递归

# 第 4 步：恢复标签
restorecon -Rv /www/
# Relabeled /www from ... default_t ... to ... httpd_sys_content_t ...
# Relabeled /www/index.html from ... default_t ... to ... httpd_sys_content_t ...

ls -1Zd /www/ /www/index.html
# unconfined_u:object_r:httpd_sys_content_t:s0 /www/
# unconfined_u:object_r:httpd_sys_content_t:s0 /www/index.html
```

### 6.3 4 条 semanage fcontext 命令

| 命令 | 用途 |
|---|---|
| `semanage fcontext -a -t TYPE PATH` | **添加**规则到数据库 |
| `semanage fcontext -d -t TYPE PATH` | **删除**规则 |
| `semanage fcontext -l` | 查看**所有**规则（系统默认 + 自定义） |
| `semanage fcontext -lC` | 只看**自定义**（改动的）规则 |

### 6.4 扩展正则 (/.*)? 的意义

```
/www(/.*)?   ← 这个表达式：
   ├── 匹配 /www 本身
   ├── 匹配 /www + 任意字符任意次（/www/index.html）
   └── 匹配 /www + 任意子目录（/www/css/style.css）
```

**不写 `(/.*)?` 会怎样**：
```
semanage fcontext -a -t httpd_sys_content_t '/www'
# 只匹配 /www 本身，/www/index.html 不会被规则覆盖！
```

### 6.5 查看与清理

```bash
# 看所有规则（很长）
semanage fcontext -l | head -20

# 只看自定义规则
semanage fcontext -lC
# SELinux fcontext  type        Context
# /www(/.*)?    all files  system_u:object_r:httpd_sys_content_t:s0

# 删除自定义规则
semanage fcontext -d -t httpd_sys_content_t '/www(/.*)?'

# 然后 restorecon 让 /www 回到 default_t
restorecon -Rv /www/
```

---

## §7 实战：把 /www 配置成 web 站点

> **来源**：PDF 第 5-6 页末尾。**全链路集成案例**：标签 + httpd + 访问验证。

### 7.1 完整步骤

```bash
# ========== 1. 准备 web 目录 ==========
mkdir /www
echo "Hello World" > /www/index.html

# ========== 2. 设置 SELinux 标签（持久） ==========
yum install -y policycoreutils-python        # 装 semanage
semanage fcontext -a -t httpd_sys_content_t '/www(/.*)?'
restorecon -Rv /www/

# 验证标签
ls -1Zd /www/ /www/index.html
# 应该都是 httpd_sys_content_t

# ========== 3. 安装 httpd（如果还没装） ==========
yum install -y httpd
systemctl enable httpd --now

# ========== 4. 修改 httpd 配置 ==========
vi /etc/httpd/conf/httpd.conf
# 注释 DocumentRoot 行（约 122 行）
# DocumentRoot "/var/www/html"
# 新增：
DocumentRoot "/www"
<Directory "/www">
    AllowOverride None
    Require all granted      # 关键：允许访问
</Directory>

# ========== 5. 重启 httpd ==========
systemctl restart httpd

# ========== 6. 访问验证 ==========
curl http://server.laoma.cloud/
# Hello World
```

### 7.2 流程图

```
创建 /www + index.html
  ↓
semanage fcontext 加规则（让 /www 有 httpd 标签）
  ↓
restorecon 生效标签
  ↓
vi httpd.conf 改 DocumentRoot
  ↓
systemctl restart httpd
  ↓
浏览器/curl 访问 → 200 OK
```

### 7.3 常见失败 + 根因

| 现象 | 根因 | 解决 |
|---|---|---|
| 403 Forbidden | SELinux 标签错（仍是 tmp_t 或 default_t） | `restorecon -Rv /www/` |
| 403 Forbidden | httpd.conf 没 Require all granted | 添加 `<Directory>` 配置 |
| 404 Not Found | DocumentRoot 改错了 | 检查 httpd.conf |
| Connection refused | httpd 没启动 / 防火墙挡了 | `systemctl status httpd` + 防火墙 |

---

## §8 SELinux 端口标签：semanage port

> **来源**：PDF 第 7-8 页。

### 8.1 为什么需要端口标签？

每个 TCP/UDP 端口在 SELinux 中也有**类型**。比如：
- 80/tcp, 443/tcp → `http_port_t`
- 22/tcp → `ssh_port_t`
- 3306/tcp → `mysqld_port_t`

**如果 httpd 监听 8080 端口（默认不在 http_port_t），SELinux 也会拒绝**。

### 8.2 把 18020 加进 http_port_t

```bash
# 第 1 步：把端口加进 SELinux 数据库
semanage port -a -t http_port_t -p tcp 18020

# 第 2 步：验证
semanage port -l | grep 18020
# http_port_t   tcp   18020, 80, 81, 443, 488, 8008, 8009, 8443, 9000

# 第 3 步：只看自定义
semanage port -lC
# SELinux Port Type   Proto   Port Number
# http_port_t         tcp     18020

# 第 4 步：改 httpd 监听 18020 端口
vi /etc/httpd/conf/httpd.conf
# Listen 18020

systemctl restart httpd

# 验证
curl http://server.laoma.cloud:18020/
# Hello World
```

### 8.3 端口标签速查

| 端口类型 | 用途 | 典型端口 |
|---|---|---|
| `http_port_t` | HTTP 服务 | 80, 443, 488, 8008, 8009, 8443, 9000 |
| `ssh_port_t` | SSH | 22 |
| `mysqld_port_t` | MySQL | 3306, 33306, 63132-63164 |
| `postgresql_port_t` | PostgreSQL | 5432 |
| `dns_port_t` | DNS | 53 |
| `smtp_port_t` | SMTP | 25, 465, 587 |
| `nfs_port_t` | NFS | 2049, 20048, 875, 662 |
| `samba_port_t` | Samba | 137, 138, 139, 445 |

> **生产中**：改 SSH 默认 22 端口时**必须用 `semanage port -a -t ssh_port_t -p tcp 新端口`**！

### 8.4 三条 semanage port 命令

```bash
semanage port -a -t TYPE -p proto port     # 添加
semanage port -d -t TYPE -p proto port     # 删除
semanage port -l                          # 查看所有
semanage port -lC                         # 只看自定义
semanage port -m -t TYPE -p proto port    # 修改（不常用）
```

---

## §9 SELinux 布尔值（booleans）

> **来源**：PDF 第 8-9 页。

### 9.1 什么是 SELinux 布尔值

**可动态调整的策略开关**。相当于 SELinux 策略的"功能开关"：

```
httpd_enable_homedirs --> off    ← 默认不允许 httpd 访问用户主目录
httpd_enable_homedirs --> on     ← 打开后允许
```

**特点**：
- 不用重启
- 不需要修改策略文件
- 不需要 restorecon
- 但**影响范围大**（开错了等于放行不该放行的操作）

### 9.2 三条命令

```bash
# 查看所有布尔值（非常多）
getsebool -a | head -20

# 查看单个布尔值
getsebool httpd_enable_homedirs
# httpd_enable_homedirs --> off

# 设置布尔值（仅运行时）
setsebool httpd_enable_homedirs=1    # 开启（on/true 等价）

# 持久化设置（写进数据库）
setsebool -P httpd_enable_homedirs=1
```

| 选项 | 含义 |
|---|---|
| `-P` | **Persistent**，持久化（写 SELinux 数据库） |
| `-N` | 不刷新策略（仅当前会话） |
| `-V` | 输出过程详情 |

### 9.3 4 条 semanage boolean 命令

```bash
semanage boolean -l                       # 查看所有布尔值
semanage boolean -lC                      # 只看自定义
semanage boolean --modify --on  NAME      # 打开（-P 默认就是持久）
semanage boolean --modify --off NAME      # 关闭
```

### 9.4 常用 HTTP 布尔值

| 布尔值 | 默认 | 用途 |
|---|---|---|
| `httpd_enable_homedirs` | off | 允许 httpd 访问用户主目录 |
| `httpd_unified` | on | 把所有 httpd 相关标签统一 |
| `httpd_can_network_connect` | off | 允许 httpd 发起出站连接（如代理） |
| `httpd_can_network_connect_db` | off | 允许 httpd 连数据库 |
| `httpd_read_user_content` | off | 允许 httpd 读用户文件 |
| `httpd_use_nfs` | off | 允许 httpd 访问 NFS |
| `httpd_use_cifs` | off | 允许 httpd 访问 CIFS/SMB |
| `httpd_anon_write` | off | 允许 httpd 匿名写 |
| `httpd_sys_script_anon_write` | off | CGI 匿名写 |

> **实战**：要让 PHP 应用上传文件到 /var/www/html/uploads，需要 `httpd_anon_write=on` 或确保上传目录有正确标签。

### 9.5 易错点

- ❌ 改了布尔值忘了加 `-P` → 重启后丢失
- ❌ 一次开太多布尔值 → SELinux 等于不设防
- ❌ 改布尔值前没看 `semanage boolean -l` 文档 → 不知道会影响什么

---

## §10 调查和解决 SELinux 问题

> **来源**：PDF 第 10-11 页。

### 10.1 三大日志来源

| 文件 | 内容 |
|---|---|
| `/var/log/audit/audit.log` | **原始** SELinux AVC 拒绝日志（更详细） |
| `/var/log/messages` | **人类可读** SELinux 警告（来自 setroubleshoot） |
| `dmesg` | 内核级 SELinux 消息 |

### 10.2 setroubleshoot-server：把日志翻译成"提示"

```bash
# 安装
yum install -y setroubleshoot-server

# 监控日志
tail -f /var/log/messages

# 触发：curl http://server.laoma.cloud:18020/~laoma/
# 此时如果 httpd_enable_homedirs off，messages 会显示：

Nov 30 10:39:34 server setroubleshoot[4035]: SELinux is preventing 
/usr/sbin/httpd from getattr access on the file 
/home/laoma/public_html/index.html. For complete SELinux messages run: 
sealert -l bb10b03c-bed2-4853-85cb-92c1824fd75d
```

### 10.3 sealert：给出多种解决方案

```bash
sealert -l bb10b03c-bed2-4853-85cb-92c1824fd75d
```

输出会给出**4 种解决方案**（按置信度从高到低）：

```
SELinux is preventing /usr/sbin/httpd from getattr access on the file /home/laoma/public_html/index.html.

***** Plugin public_content (32.5 confidence) suggests *****
If you want to treat index.html as public content
Then you need to change the label on index.html to public_content_t or public_content_rw_t.
Do:
  # semanage fcontext -a -t public_content_t '/home/laoma/public_html/index.html'
  # restorecon -v '/home/laoma/public_html/index.html'

***** Plugin catchall_boolean (32.5 confidence) suggests *****
If you want to allow httpd to enable homedirs
Then you must tell SELinux about this by enabling the 'httpd_enable_homedirs' boolean.
Do:
  # setsebool -P httpd_enable_homedirs 1

***** Plugin catchall_boolean (32.5 confidence) suggests *****
If you want to allow httpd to unified
Then you must tell SELinux about this by enabling the 'httpd_unified' boolean.
Do:
  # setsebool -P httpd_unified 1

***** Plugin catchall (4.5 confidence) suggests *****
If you believe that httpd should be allowed getattr access on the index.html file by default.
Then you should report this as a bug.
You can generate a local policy module to allow this access.
Do:
  # ausearch -c 'httpd' --raw | audit2allow -M my-httpd
  # semodule -X 300 -i my-httpd.pp
```

### 10.4 4 种典型解决思路

| 思路 | 命令 | 适用场景 | 安全性 |
|---|---|---|---|
| **1. 改文件标签** | `semanage fcontext` + `restorecon` | 文件不在标准位置（如 web 站点换目录） | ⭐⭐⭐⭐⭐ 最安全 |
| **2. 改端口标签** | `semanage port` | 改了服务端口（如 SSH 改 2222） | ⭐⭐⭐⭐ |
| **3. 打开布尔值** | `setsebool -P` | 需要某些功能（如 httpd 访问家目录） | ⭐⭐⭐ 影响范围大 |
| **4. 自定义 policy 模块** | `audit2allow -M` + `semodule` | 前 3 种都不行（如罕见服务的访问） | ⭐⭐ 必要时再用 |

### 10.5 audit2allow：自动生成自定义策略

```bash
# 1. 看原始 AVC 消息
ausearch -m AVC -ts recent | head

# 2. 让 audit2allow 自动生成策略模块
ausearch -c 'httpd' --raw | audit2allow -M my-httpd

# 这会创建 my-httpd.te（源）和 my-httpd.pp（编译后的策略）

# 3. 安装策略模块
semodule -X 300 -i my-httpd.pp
```

> **警告**：audit2allow 会**接受所有拒绝**，意味着可能放行不该放行的操作。**只用于测试和临时绕过**，生产中应尽量用 1-3 的标准方法。

### 10.6 SELinux 文档

```bash
# 安装 SELinux 文档
yum install -y selinux-policy-doc
mandb

# 查某个服务的 SELinux 策略
man -k '_selinux'
man httpd_selinux    # 看 httpd 的 SELinux 规则
man sshd_selinux     # 看 sshd 的
```

---

## §11 SELinux 问题处理思路 6 步 SOP

> **来源**：PDF 第 12 页"问题处理思路"。**这是 PDF 最精华的部分**。

### 11.1 标准 6 步流程

```
第 1 步：确定是不是 SELinux 引起的
   ↓
   临时切 permissive 验证：setenforce 0
   ↓
   业务恢复正常 → 确认是 SELinux 问题
   ↓
第 2 步：检查是"正确阻止"还是"误伤"
   ↓
   是正确阻止（如 web 进程访问 /home 但 web 内容不在家目录）→ 不应放行
   是误伤 → 进入第 3 步修复
   ↓
第 3 步：检查文件上下文（最常见）
   ↓
   ls -Z 看文件标签是否符合预期
   restorecon -Rv 试修复
   ↓
第 4 步：检查布尔值（次常见）
   ↓
   setsebool -P 打开需要的布尔值
   ↓
第 5 步：检查端口标签（如果改了端口）
   ↓
   semanage port -a -t TYPE -p proto port
   ↓
第 6 步：可能是 SELinux bug（罕见）
   ↓
   提交 bug 或用 audit2allow 临时绕过
```

### 11.2 第 1 步快速验证法

**最快判断是不是 SELinux 引起的**：

```bash
# 临时切到 permissive
setenforce 0

# 测试业务
业务正常 → 100% 是 SELinux 问题，继续第 2 步
业务仍失败 → 不是 SELinux 问题，去看日志/网络/权限等其他原因

# 测试完务必切回
setenforce 1
```

### 11.3 区分"正确阻止"vs"误伤"

**正确阻止的典型场景**（不要绕过）：
- web 服务尝试访问 `/etc/shadow`（正确，web 不该读密码文件）
- web 服务尝试访问 `/var/log/messages`（正确，web 不该读系统日志）
- 用户主目录下放 web 服务去读（应该用 /var/www）

**误伤的典型场景**（需要修复）：
- web 服务访问 /www（已配好标签，但还是被挡）
- web 服务监听新端口（忘了加 semanage port）
- php-fpm 上传文件失败（upload 目录标签不对）

### 11.4 修复优先级（按"安全影响范围"从小到大）

1. **restorecon**（不改数据库，只回数据库规则）
2. **semanage fcontext**（改数据库规则，标准化）
3. **semanage port**（改端口规则）
4. **setsebool -P**（开布尔值，影响范围中等）
5. **audit2allow + semodule**（自定义策略，影响大，最后手段）

> **PDF 原话**："最常见的 SELinux 问题是不正确的文件上下文"——所以**先查标签**再说。

---

## §12 易错点 ×10

1. **mv 跨目录移动后标签没变** → apache 访问 /var/www/mv 过来的文件被拒 → `restorecon -R` 修复
2. **cp -a 后文件继承 src 标签** → 用户拷贝含敏感标签的文件到 web 目录可能绕过权限
3. **chcon 改了但没 semanage fcontext** → 重启或恢复后会丢失修改
4. **disabled → enforcing 没 touch /.autorelabel** → 重启后所有服务起不来
5. **改 SSH 端口没 semanage port** → SSH 起不来，但能 ping 通
6. **setenforce 0 临时切 permissive 测完忘切回** → 系统处于 enforcement=off，生产环境**原则上禁止**
7. **开了 httpd_enable_homedirs 但没设家目录 web 文件权限** → 用户主目录权限问题叠加 SELinux
8. **audit2allow 一键放行** → 可能接受本不该允许的访问，安全风险
9. **以为 SELinux 让服务启动失败就关闭 SELinux** → 应先 setenforce 0 验证是不是 SELinux
10. **改了 /etc/selinux/config 不重启** → 永久配置不生效，运行时还是旧设置

---

## §13 速查表

### SELinux 模式速查

| 命令 | 作用 |
|---|---|
| `getenforce` | 看当前模式 |
| `setenforce 0/1` | 临时切换（permissive/enforcing） |
| `sestatus` | 看完整状态 |
| `vi /etc/selinux/config` | 永久配置（重启生效） |

### 标签管理速查

| 命令 | 作用 |
|---|---|
| `ls -Z / ps -Z / cp -Z / mkdir -Z` | 显示/设置 SELinux 标签 |
| `chcon -t TYPE file` | **临时**改文件标签 |
| `restorecon -Rv path` | 根据数据库规则**恢复**标签 |
| `semanage fcontext -a -t TYPE path` | **永久加**规则 |
| `semanage fcontext -d -t TYPE path` | 删除规则 |
| `semanage fcontext -l` / `-lC` | 查看规则（全部/自定义） |

### 端口标签速查

| 命令 | 作用 |
|---|---|
| `semanage port -a -t TYPE -p proto port` | 加端口 |
| `semanage port -d -t TYPE -p proto port` | 删端口 |
| `semanage port -l` | 看所有 |

### 布尔值速查

| 命令 | 作用 |
|---|---|
| `getsebool -a` | 查看所有 |
| `getsebool NAME` | 查看单个 |
| `setsebool NAME=1` | 临时开 |
| `setsebool -P NAME=1` | 永久开 |
| `semanage boolean -l` | 看带说明的布尔值 |
| `semanage boolean -lC` | 自定义布尔值 |

### 排错速查

| 命令 | 作用 |
|---|---|
| `setenforce 0` | 临时切 permissive 验证是否是 SELinux |
| `tail -f /var/log/audit/audit.log` | 原始 AVC 日志 |
| `tail -f /var/log/messages` | 人类可读警告（装 setroubleshoot 后） |
| `sealert -l <UUID>` | 看详细诊断 + 解决方案 |
| `ausearch -m AVC -ts recent` | 查近期的 AVC 事件 |
| `audit2allow -M my-xxx` | 自动生成策略模块 |

### 关键路径速查

| 路径 | 含义 |
|---|---|
| `/etc/selinux/config` | 永久配置（SELINUX=, SELINUXTYPE=） |
| `/sys/fs/selinux` | SELinux 伪文件系统 |
| `/var/log/audit/audit.log` | 原始 AVC 日志 |
| `/var/log/messages` | 人类可读警告 |
| `/etc/selinux/targeted/` | targeted 策略文件 |

---

## §14 面试 6 大追问

> 学完后能回答这 6 个问题，说明 SELinux 掌握扎实。

1. **DAC 和 MAC 的本质区别是什么？**
   - **DAC**（Linux 文件权限）：用户可以**自主**决定权限（chmod/chown 自己设）。
   - **MAC**（SELinux）：管理员/系统决定规则，用户**绕不过去**（即使 root 也受 MAC 限制）。
   - **关键差异**：默认行为不同——DAC 默认**允许**（除非显式拒绝），MAC 默认**拒绝**（除非显式允许）。

2. **`getenforce` 显示 enforcing 但业务仍被拒，怎么排查？**
   - 看 `/var/log/audit/audit.log`（原始 AVC）
   - 装 `setroubleshoot-server` 看 `/var/log/messages`（人类可读）
   - 跑 `sealert -l <UUID>` 看具体方案
   - 临时 `setenforce 0` 验证是不是 SELinux

3. **`mv` 移动文件后 apache 访问不到，为什么？**
   - mv **不**改文件标签（原标签保留）
   - 比如 `mv /tmp/file /var/www/html/file`，file 还是 tmp_t
   - apache 默认禁止 tmp_t
   - 修复：`restorecon -v /var/www/html/file`

4. **`semanage fcontext` 跟 `chcon` 的区别？**
   - `chcon`：直接改标签，**不持久**（下次 relabel 会丢）
   - `semanage fcontext`：**改数据库规则**，未来 `restorecon` 都按规则来，**持久**

5. **修改 SSH 默认 22 端口后 ssh 起不来，为什么？怎么修？**
   - SELinux 端口标签没加：22 端口是 ssh_port_t，新端口默认不在
   - 修：先 `vi /etc/ssh/sshd_config` 改 Port
   - 再 `semanage port -a -t ssh_port_t -p tcp 新端口`
   - `systemctl restart sshd`

6. **永久关 SELinux 的 2 个步骤？**
   - `vi /etc/selinux/config` 改 `SELINUX=disabled`
   - `reboot`（必须）

> **生产警告**：永久关 SELinux **不可取**，等同于打开所有安全漏洞，应**只在 troubleshooting 时**临时 `setenforce 0`。

---

## 📎 跨模块链接

- **[[Linux启动原理/Linux启动原理]]** —— `selinux=0` / `enforcing=0` 内核参数；rd.break 密码破解后 `/.autorelabel`
- **[[Linux服务与SSH/Linux服务与SSH]]** —— `semanage port -a -t ssh_port_t -p tcp 2222` 改 SSH 端口
- **[[Linux防火墙/Linux防火墙]]** —— firewalld + SELinux 双层防护
- **[[Linux用户权限/user-permission]]** —— DAC 部分；与 SELinux 的 MAC 是叠加（不是替代）

## 📦 镜像

- `E:\notes\LinuxSELinux.md`（同步备份）