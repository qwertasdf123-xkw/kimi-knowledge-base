---
title: Linux 启动原理 — 从加电到登录的全链路
desc: 基于 06.CentOS-7-系统管理-2/9. Linux 系统启动原理.pdf 的实操笔记（21 页）。覆盖 CentOS7 启动 9 步流程、systemd target、运行级别、救援模式、密码重置（rd.break + init=/bin/bash）、/etc/fstab 启动故障、GRUB2 配置与加密、GRUB2 故障恢复、LUKS 磁盘加密。
type: 笔记
module: Linux启动原理
pdfs:
  - 06.9 Linux 系统启动原理.pdf (3.0 MB / 21 页)
pdf_size: 3019522 字节
scope: CentOS-7.x（参考 RHEL 7）
status: 完成
---

# Linux 启动原理 — 从加电到登录提示符的全链路

> **范围**：基于《CentOS-7 系统管理 2》第 9 章 整理（21 页 PDF，3.0 MB）。
> 覆盖 **启动 9 步流程** + **systemd target 入门** + **运行级别对照** + **救援模式** + **密码重置** + **/etc/fstab 引起的启动问题** + **GRUB2 配置与加密** + **GRUB2 故障处理** + **LUKS 磁盘加密**。
>
> **适用**：CentOS-7 / RHEL 7 系。
>
> **前置**：[[Linux服务与SSH/Linux服务与SSH]] 已有 systemd / systemctl 基础；[[Linux存储/Linux存储]] 已有 RAID/LVM/swap；本章是它们的**启动链路底层原理 + 故障恢复终极方案**。

## 目录

- [[#§0 心智模型：启动 = 一辆汽车发动]]
- [[#§1 高层视角：CentOS7 启动 9 步流程]]
- [[#§2 systemd target 入门]]
- [[#§3 运行级别 ↔ target 对照表]]
- [[#§4 救援模式 vs 单用户模式]]
- [[#§5 密码重置：两种方法]]
- [[#§6 /etc/fstab 引起的启动问题]]
- [[#§7 GRUB2 配置]]
- [[#§8 GRUB2 故障处理]]
- [[#§9 LUKS 磁盘加密]]
- [[#§10 思考题：为什么 vmlinuz + initramfs 分开]]
- [[#§11 易错点 ×10]]
- [[#§12 速查表]]
- [[#§13 面试 6 大追问]]

---

## §0 心智模型：启动 = 一辆汽车发动

把 Linux 启动想象成 **冷启动一辆汽车**：

| 启动阶段 | 汽车比喻 | 实际动作 |
|---|---|---|
| 1️⃣ 按电源键 | 拧钥匙 | 加电 → 主板通电 |
| 2️⃣ 仪表盘自检 | 仪表盘亮灯检查 | **BIOS/UEFI + POST** 自检硬件 |
| 3️⃣ 找启动盘 | 找车位 | 固件按顺序找启动磁盘上的 **MBR** |
| 4️⃣ 启动管理器 | 决定加什么油 | **GRUB2** 显示菜单 → 选内核条目 |
| 5️⃣ 加载内核 | 点火启动发动机 | 加载 **kernel + initramfs** 到内存 |
| 6️⃣ 临时根目录 | 用电瓶跑 | initramfs 内核驱动初始化硬件 |
| 7️⃣ 切换到真根 | 切换到主油路 | 切到磁盘上的 `/` 真文件系统 |
| 8️⃣ 启动系统服务 | 所有模块工作 | **systemd** 拉起 target + 服务 |
| 9️⃣ 登录界面 | 钥匙交给你 | **getty.target** 给出 tty 登录 |

> **核心要点**：BIOS/UEFI → GRUB2 → kernel → initramfs → systemd 是一条**严格的串行链**；**任何一环坏了都要从中断点修起**（这就是 §5/§6/§8 故障恢复的全部意义）。

### 启动链全景图

```
加电
 ↓
┌────────────────┐
│ BIOS/UEFI + POST │  ← 阶段 1：硬件自检
└────────┬───────┘
         ↓
┌─────────────────────────────┐
│ MBR 磁盘 → GRUB2            │  ← 阶段 2：引导管理器
│ /boot/grub2/grub.cfg        │
└────────┬───────────────────┘
         ↓
┌─────────────────────────────┐
│ Kernel + initramfs           │  ← 阶段 3：加载内核
│ /boot/vmlinuz-*              │
│ /boot/initramfs-*.img       │
└────────┬───────────────────┘
         ↓
┌─────────────────────────────┐
│ systemd (PID 1)              │  ← 阶段 4：系统初始化
│ /sbin/init → systemd        │
└────────┬───────────────────┘
         ↓
┌─────────────────────────────┐
│ default.target               │  ← 阶段 5：用户空间
│ multi-user.target / graphical │
│   ├─ sysinit.target (挂 fstab) │
│   ├─ basic.target            │
│   ├─ 服务 (chronyd/crond/firewalld) │
│   └─ getty.target (登录终端)  │
└─────────────────────────────┘
```

---

## §1 高层视角：CentOS7 启动 9 步流程

> **来源**：PDF 第 1-2 页 9 步流程（最经典的"教科书级"概述）。

### 1.1 启动 9 步详解

| 步 | 名称 | 谁做 | 做什么 | 配置工具 |
|---|---|---|---|---|
| 1 | 加电 + POST | 主板固件 | 通电后硬件自检（BIOS/UEFI） | 按 F2 进固件配置 |
| 2 | 找 MBR + boot loader | 固件 | 从启动盘读 MBR → GRUB2 | `grub2-install` |
| 3 | GRUB2 菜单 | GRUB2 | 读 `/boot/grub2/grub.cfg` 显示系统选择菜单 | `/etc/grub.d/` + `/etc/default/grub` + `grub2-mkconfig` |
| 4 | 加载 kernel + initramfs | GRUB2 | 把 kernel + initramfs 装入内存，把控制权交给 kernel | `/etc/dracut.conf.d/` + `dracut` + `lsinitrd` |
| 5 | initramfs 找硬件驱动 | 内核 | 在 initramfs 中找所有硬件驱动，初始化硬件 | `init=/path/to/init` 内核参数 |
| 6 | initramfs 启动 systemd | 内核 | 执行 `/sbin/init` → systemd（PID 1） | 内核参数 `init=command` |
| 7 | systemd 加载 target | systemd | 加载 default.target（multi-user/graphical） | `systemctl set-default` |
| 8 | target 拉起 sysinit | systemd | sysinit.target 读 fstab / 启动 journald | `/etc/fstab` |
| 9 | target 拉起 getty | systemd | getty.target 打开 tty1 等用户登录 | `systemctl enable xxx.service` |

### 1.2 关键概念对照

| 概念 | 含义 | 位置 |
|---|---|---|
| **POST** | Power-On Self-Test，加电自检 | 主板固件内 |
| **MBR** | Master Boot Record，主引导记录 | 磁盘第一扇区（512 字节） |
| **GRUB2** | GRand Unified Bootloader v2 | `/boot/grub2/grub.cfg` |
| **kernel** | vmlinuz-*，压缩的内核镜像 | `/boot/vmlinuz-<ver>` |
| **initramfs** | 初始 RAM 文件系统（旧称 initrd） | `/boot/initramfs-<ver>.img` |
| **systemd** | PID 1，新一代 init | `/sbin/init → /lib/systemd/systemd` |
| **default.target** | 默认启动目标（类似"运行级别"） | `/etc/systemd/system/default.target` |

### 1.3 9 步流程图

```
[1] 加电
     ↓
[2] 硬件自检 (POST)
     ↓
[3] MBR 搜索 (BIOS/UEFI 启动顺序)
     ↓
[4] GRUB2 加载
     ├─ 读取 /boot/grub2/grub.cfg
     ├─ 显示启动菜单
     └─ 等待选条目
     ↓
[5] 加载 kernel + initramfs
     ↓
[6] initramfs 阶段：临时根 → 硬件驱动初始化
     ↓
[7] 切到磁盘真根（/）
     ↓
[8] PID 1 = systemd
     ├─ 加载 default.target
     ├─ sysinit.target → 挂 fstab / 启动 journald
     ├─ basic.target
     └─ multi-user.target / graphical.target
     ↓
[9] getty.target → tty 登录
```

### 💬 回答你的疑问（必填）

> **Q1：为什么 GRUB2 要先出现在 BIOS/UEFI 之后？**

**A**：BIOS/UEFI 是主板固件，**只能理解磁盘第 1 个扇区**（MBR 的 446 字节）。但要引导一个完整的操作系统需要复杂得多，所以 BIOS 加载一段**小程序**（GRUB2），让 GRUB2 去读 `/boot/grub2/grub.cfg` 找到真正的内核。

> **Q2：vmlinuz 和 initramfs 必须配套存在？**

**A**：是的。**GRUB2 把两个文件同时加载到内存**，kernel 起来后会从 initramfs 找驱动；如果版本不匹配（升级了 kernel 但没生成 initramfs），会 panic。

```bash
uname -r   # 查看运行中内核版本
ls /boot/vmlinuz-* /boot/initramfs-*   # 查看可用内核 + 对应 initramfs
```

> **Q3：CentOS 7 的 /sbin/init 是什么？**

**A**：是个**软链接**，指向 systemd：

```bash
ls -l /sbin/init
# lrwxrwxrwx. 1 root root 22 Jan  1  1970 /sbin/init -> ../lib/systemd/systemd
```

---

## §2 systemd target 入门

> **来源**：PDF 第 2-3 页 target 概念。

### 2.1 target = 一组 service 的集合

systemd 用 **target 单元** 把一组相关的 service 打包，类似"启动套餐"：

```
multi-user.target (常用)
├── chronyd.service
├── crond.service
├── firewalld.service
├── network.service
├── sshd.service
└── ...
```

### 2.2 target 嵌套关系

target 还能包含其他 target，形成**金字塔结构**：

```
graphical.target (图形界面)
├── accounts-daemon.service
├── gdm.service
└── multi-user.target
    ├── chronyd.service
    ├── crond.service
    └── basic.target
        └── sysinit.target
            ├── systemd-journald.service
            └── ...
```

> **关键**：**graphical.target 依赖 multi-user.target** —— 这就是为什么图形界面启动后必然有 multi-user 的所有服务。

### 2.3 关键命令

```bash
# 查看 target 依赖链
systemctl list-dependencies graphical.target

# 查看反向依赖（哪些 target 依赖它）
systemctl list-dependencies sshd.service --reverse

# 查看默认 target
systemctl get-default

# 修改默认 target（重启后生效）
systemctl set-default multi-user.target

# 立即切换 target（不重启）
systemctl isolate multi-user.target

# 查看所有激活的 unit
systemctl list-units --type=target
```

### 2.4 输出解读

```
[root@centos7 ~]# systemctl list-dependencies graphical.target
graphical.target
● ├─accounts-daemon.service
● ├─gdm.service
● ├─network.service
● └─multi-user.target
......

# 看反向依赖
[root@centos7 ~]# systemctl list-dependencies sshd.service --reverse
sshd.service
● └─multi-user.target
●   └─graphical.target
```

> **易错点**：root 用户的 `graphical.target` 不一定能正常显示图形（GDM 需要视频驱动），需要先 `yum groupinstall "Server with GUI"`。

---

## §3 运行级别 ↔ target 对照表

> **来源**：PDF 第 3 页。

### 3.1 SysVinit 的 7 个运行级别（历史）

传统 SysVinit 用 **7 个运行级别（0-6）**，每个级别对应不同启动行为：

| 级别 | target | 含义 | 命令 |
|---|---|---|---|
| 0 | `halt.target` | 关机（halt）—— 终止所有进程 + 关闭电源 | `shutdown -h now` |
| 1 | `emergency.target` / `rescue.target` | 单用户模式（single user）—— 仅 root，无网络服务，用于**系统修复**（如密码找回） | (启动菜单 → 内核参数加 `single`) |
| 2 | (无明确对应) | 多用户模式（无 NFS）—— 不启动 NFS，部分 Debian 默认此级别与 3 相同 | — |
| 3 | `multi-user.target` | 完全多用户模式（文本界面）—— 启动所有网络服务，**字符界面登录** | (默认服务器) |
| 4 | (预留) | 默认未使用，用户可自定义 | — |
| 5 | `graphical.target` | 图形用户模式 —— 在级别 3 基础上启用图形界面（GNOME/KDE） | `systemctl set-default graphical.target` |
| 6 | `reboot.target` | 重启 | `reboot` / `shutdown -r now` |

### 3.2 CentOS 7 实际默认 target

```bash
systemctl get-default
# multi-user.target    ← 服务器/学习环境默认
```

> **记住**：生产服务器永远是 `multi-user.target`；只有**个人桌面**才会是 `graphical.target`。

### 3.3 切换 target 的 3 种姿势

```bash
# 方式 1：永久修改（重启生效）
systemctl set-default graphical.target
ln -sf /usr/lib/systemd/system/graphical.target \
       /etc/systemd/system/default.target

# 方式 2：临时切换（不重启）
systemctl isolate multi-user.target    # 切回字符界面
systemctl isolate graphical.target    # 切到图形界面

# 方式 3：应急修改（启动时在内核参数加 systemd.unit=）
# 在 grub 菜单按 e，linux16 行末尾加：
#   systemd.unit=multi-user.target    # 让这次启动强制进 multi-user
#   systemd.unit=rescue.target        # 让这次启动强制进救援
# 然后 Ctrl+x 启动
```

### 3.4 emergency.target vs rescue.target

| 维度 | emergency.target | rescue.target |
|---|---|---|
| 启动的服务 | 仅 emergency shell | 基本系统 + 修补 shell |
| 文件系统 | 仅 `/` 挂载，可能只读 | `/` 完整挂载（rw） |
| 网络 | ❌ 无 | ✅ 有 |
| 进入方式 | `systemd.unit=emergency.target` | `systemctl rescue` 或 `1` 级别 |
| 用途 | 救援级别（一线救急） | 修复级别（能修文件、改密码） |

---

## §4 救援模式 vs 单用户模式

> **重要前置**：PDF 把这两个概念放进了故障排查场景，**先讲清区别再进 §5**。

### 4.1 概念区别

| 模式 | 进入方式 | 用途 |
|---|---|---|
| **救援模式 (rescue)** | `systemctl isolate rescue.target` 或启动加 `1` 或 `systemd.unit=rescue.target` | 启动最小化系统，挂载 `/` 到 `/mnt/sysimage`，**可修复大部分故障**（改密码、改 fstab、修 GRUB） |
| **emergency 模式** | `systemd.unit=emergency.target` | 比 rescue 还"裸"，**只启动 emergency shell**，/ 不一定挂载 |
| **单用户模式** | 内核参数加 `single` 或 `1` | 历史叫法，CentOS 7 等价于 rescue.target |
| **rd.break** | GRUB 内核参数加 `rd.break` | **特殊方式**：在 initramfs 阶段就中断，**没切到真根**，适合找回 root 密码 |

### 4.2 救援模式能做什么

```bash
# 进入救援模式（启动时在 grub 菜单按 e，linux16 行末尾加 1，按 Ctrl+x）
# 进系统后：
mount | grep sysimage
# /dev/mapper/centos-root on /mnt/sysimage type xfs (rw,...)

# 修改 root 密码
chroot /mnt/sysimage
passwd root

# 检查 /etc/fstab
vi /mnt/sysimage/etc/fstab

# 重新安装 GRUB
chroot /mnt/sysimage
grub2-install /dev/sda

# 修改 SELinux 模式
vi /mnt/sysimage/etc/selinux/config

# 退出（输入两次 exit：一次退出 chroot，一次退出 initramfs）
```

### 4.3 什么场景进什么模式（决策树）

```
系统启动坏了
   ↓
能进正常登录吗？
   ├─ 能 → 用 systemctl isolate rescue.target 进救援模式修
   └─ 不能 → 重启，在 GRUB 菜单编辑内核参数
              ↓
              想找回 root 密码？
              ├─ 是 → §5.1 rd.break 或 §5.2 init=/bin/bash
              └─ 否 → 想修 GRUB/fstab/磁盘？
                       ├─ GRUB 坏 → §8 救援模式 grub2-install
                       ├─ fstab 错 → §6 进 emergency 重挂载
                       └─ 文件系统坏 → §6.3 xfs_repair
```

---

## §5 密码重置：两种方法

> **来源**：PDF 第 5-7 页。是**最常用、必背**的故障恢复技能。

### 5.1 心智模型：密码哈希存在哪？

```
/etc/passwd   (用户清单，无密码)
   ↓
/etc/shadow   (密码哈希 + 策略，!! 或 * 表示锁定)
   ↓
root:$6$XYZ...:19000:0:99999:7:::
```

**关键**：密码哈希存在 `/etc/shadow`。**找回密码 = 想办法能编辑 /etc/shadow**。

### 5.2 方法 1：rd.break（在 initramfs 阶段中断）

**核心原理**：用 `rd.break` 让内核**在从 initramfs 切到真根之前停下**，给一个 root shell，此时磁盘上的真根还**只读挂载在 /sysroot**。

#### 操作步骤

```bash
# 1. 重启系统
reboot

# 2. GRUB 菜单界面，按 e 编辑条目（默认 5 秒内有效）

# 3. 找到 linux16 开头的行，在末尾追加 rd.break
linux16 /vmlinuz-3.10.0-... root=/dev/mapper/centos-root ro rd.break

# 4. 按 Ctrl+x 用修改后的配置启动

# 5. 此时系统停在 initramfs 的 root shell
#    磁盘真根（/）只读挂在 /sysroot
switch_root:/# mount | grep sysroot
# /dev/mapper/centos-root on /sysroot type xfs (ro,relatime,...)

# 6. 以读写方式重新挂载
switch_root:/# mount -o remount,rw /sysroot

# 7. 切换 /sysroot 为新的根（chroot）
switch_root:/# chroot /sysroot

# 8. 重置 root 密码
sh-4.2# echo "newpassword" | passwd --stdin root
# 或交互式：passwd root

# 9. SELinux 重标记（如果开了 SELinux）
sh-4.2# touch /.autorelabel

# 10. 退出（exit 两次：第一次退出 chroot，第二次退出 initramfs）
sh-4.2# exit
switch_root:/# exit

# 11. 系统继续启动，用新密码登录验证
```

#### 流程图

```
reboot
  ↓
GRUB 菜单 (按 e)
  ↓
linux16 行加 rd.break (Ctrl+x)
  ↓
initramfs 的 root shell (磁盘真根只读挂在 /sysroot)
  ↓
mount -o remount,rw /sysroot
  ↓
chroot /sysroot
  ↓
passwd root (重置密码)
  ↓
touch /.autorelabel (SELinux 重标记)
  ↓
exit (退出 chroot)
  ↓
exit (退出 initramfs → 系统继续启动)
  ↓
新密码登录
```

### 5.3 方法 2：init=/bin/bash（绕过 init）

**核心原理**：用 `init=/bin/bash` 让内核**跳过 systemd**，直接起一个 bash shell。**严重程度比方法 1 高**——因为没启动 systemd 的重标记机制。

#### 操作步骤

```bash
# 1-4 同方法 1（GRUB 菜单编辑 + Ctrl+x）
# linux16 末尾加 init=/bin/bash

# 5. 此时是 bash shell，磁盘真根（/）只读挂载
bash-4.2# mount | grep "on / "
# /dev/mapper/centos-root on / type xfs (ro,...)

# 6. 重新挂载为读写
bash-4.2# mount -o remount,rw /

# 7. 删除 root 密码（让 root 无密码可登录）
bash-4.2# passwd -d root
# 或直接编辑 /etc/shadow，把 root 行第二字段（加密密码）清空
bash-4.2# vi /etc/shadow
# root::19000:0:99999:7:::

# 8. SELinux 重标记（**强制必须**！）
bash-4.2# touch /.autorelabel

# 9. 强制重启（不能用 reboot，systemd 没启动）
bash-4.2# exec /usr/lib/systemd/systemd
# 或 sync && reboot -f
```

#### 两种方法对比

| 维度 | 方法 1 (rd.break) | 方法 2 (init=/bin/bash) |
|---|---|---|
| 中断位置 | initramfs 阶段 | 内核之后、systemd 之前 |
| chroot 必要性 | ✅ 需要（chroot /sysroot） | ❌ 不需要（/ 已经是真根） |
| remount 挂载点 | /sysroot | / |
| passwd 命令 | `passwd --stdin root` 推荐 | `passwd -d root`（清空）或手动编辑 /etc/shadow |
| SELinux 标记 | `touch /.autorelabel` **建议**做 | `touch /.autorelabel` **强制必须** |
| 退出方式 | exit × 2 | `exec /usr/lib/systemd/systemd` 或 `sync && reboot -f` |
| 推荐度 | ⭐⭐⭐⭐⭐ 首选 | ⭐⭐⭐ 退路 |

### 5.4 SELinux 的"autorelabel"是什么？

```bash
touch /.autorelabel    # 在下次启动时强制 SELinux 重新标记所有文件
```

- 如果**忘了这一步**，登录会被 SELinux 拒绝（即便密码对），因为 `/etc/shadow` 没有正确的 SELinux 标签。
- 文件 `/.autorelabel` 是 systemd 在启动时检查的"开关"。
- 重标记过程**很慢**（要给所有文件打标签），可能 5-15 分钟。**耐心等待**。

### 5.5 易错点

- ❌ 改了密码但忘了 `touch /.autorelabel` → 重启后登录被 SELinux 拒绝
- ❌ 用方法 2 改了密码但没 `touch /.autorelabel` → 同上
- ❌ 用方法 1 时忘了 `mount -o remount,rw /sysroot` → passwd 命令报"Read-only file system"
- ❌ 用方法 1 时忘了 `chroot /sysroot` → 改的是 initramfs 的 passwd，不是真系统的

---

## §6 /etc/fstab 引起的系统启动问题

> **来源**：PDF 第 8-9 页。`fstab` 是启动必读的 3 个文件之一（另两个是 GRUB2 配置和 systemd 配置）。

### 6.1 心智模型：fstab 在启动链的位置

```
GRUB2 加载内核
  ↓
kernel + initramfs
  ↓
systemd 拉起 sysinit.target
  ↓
读取 /etc/fstab  ← 这一步！
  ↓
按 fstab 挂载所有文件系统
  ↓
拉起 multi-user.target / getty
```

**关键**：**fstab 有错 → sysinit.target 失败 → 进 emergency 模式**。

### 6.2 故障 1：挂载点不存在

#### 复现
```bash
# 环境准备
parted /dev/sdb mklabel msdos
parted /dev/sdb unit MiB mkpart primary 1 10241
mkfs.xfs /dev/sdb1
mkdir /data01
echo '/dev/sdb1 /data01 xfs defaults 0 0' >> /etc/fstab
mount -a
df -h /data01

# 删除挂载点（模拟故障）
umount /data01
rmdir /data01

# 重启
reboot
```

#### 重启后观察

```
# 系统可以正常进入！
# 在启动过程中 systemd 会自动创建缺失的挂载点
# 验证
df -h /data01
```

> **结论**：**挂载点不存在不是错**——systemd 会自动 `mkdir -p`。

### 6.3 故障 2：设备名称写错（找不到设备）

#### 复现
```bash
# 在 /etc/fstab 把正确的 /dev/sdb1 改成错的 /dev/sdb2
vi /etc/fstab
# /dev/sdb2 /data01 xfs defaults 0 0
reboot
```

#### 重启后现象

```
1. 启动过程中找不到该设备。
2. 1分30秒超时后，进入 emergency 模式，进行修复。
3. 输入 root 密码进入 emergency shell
4. 修复（改回正确的 /dev/sdb1 或注释条目）
   vi /etc/fstab
   # 改回 /dev/sdb1 或注释这一行
5. 输入 exit，继续启动。
```

> **关键数字**：**超时时间默认 90 秒**（`DefaultTimeoutStartSec=90s`）。这是给管理员"进 emergency 修"的时间。

### 6.4 故障 3：文件系统破坏

#### 复现
```bash
# 破坏文件系统
dd if=/dev/zero of=/dev/sdb1 bs=1M count=1

reboot
```

#### 重启后现象

```
1. 启动过程中尝试修复文件系统，修复失败后提示进入 emergency 模式。
2. 输入 root 密码进入 emergency 模式。
3. 修复（用 xfs_repair 命令）
   xfs_repair /dev/sdb1
4. 修复完成后输入 exit，正常启动。
```

### 6.5 fstab 6 字段详解

```
/dev/sdb1   /data01   xfs   defaults   0   0
   ↑          ↑        ↑      ↑        ↑   ↑
 设备       挂载点   文件系统 挂载选项   dump fsck
                                  顺序   顺序
```

| 字段 | 含义 | 常见值 |
|---|---|---|
| 1️⃣ 设备 | 设备名或 UUID | `/dev/sdb1` 或 `UUID=xxxx` |
| 2️⃣ 挂载点 | 文件系统入口 | `/data01` 或 `/home` |
| 3️⃣ 文件系统类型 | 文件系统格式 | `xfs`, `ext4`, `swap`, `nfs`, `iso9660` |
| 4️⃣ 挂载选项 | 默认 + 特殊 | `defaults`, `noatime`, `acl` |
| 5️⃣ dump 备份标记 | 是否被 dump 备份（0=不，1=是） | 一般填 0 |
| 6️⃣ fsck 检查顺序 | 启动时是否被 fsck 检查（0=不，1=优先） | 根分区=1，其他=2，swap=0 |

### 6.6 永久挂载的"现代化"：用 UUID 而不是设备名

```bash
# 看 UUID
blkid /dev/sdb1
# /dev/sdb1: UUID="e8d13e3a-..." TYPE="xfs"

# 写 fstab 时用 UUID（避免设备名在重启后变化）
UUID=e8d13e3a-...   /data01   xfs   defaults   0   0
```

> **为什么用 UUID**：设备名 `/dev/sda` 在不同主板、插槽顺序下可能变化（特别是多硬盘 + BIOS 重编号），**UUID 唯一**不会变。

---

## §7 GRUB2 配置

> **来源**：PDF 第 9-14 页。最实用的一节（日常 80% 启动问题都跟 GRUB 有关）。

### 7.1 GRUB2 配置文件全景

```
/boot/grub2/                          ← GRUB2 主配置目录（BIOS 模式）
├── grub.cfg                          ← 实际生效的配置（**不直接修改**）
├── grubenv                           ← 启动条目状态（saved_entry 等）
└── user.cfg                          ← 用户自定义（菜单密码等）

/etc/grub2.cfg                       ← /boot/grub2/grub.cfg 的软链接
/etc/grub2-efi.cfg                   ← UEFI 模式（EFI 系统分区）
/etc/grub.d/                         ← GRUB2 脚本目录
├── 00_header                         ← 读 /etc/default/grub 生成基础配置
├── 00_*                              ← 其他脚本（按数字升序执行）
├── 01_users                          ← 菜单加密脚本（通过 user.cfg）
└── ...

/etc/default/grub                    ← GRUB2 变量定义（超时、内核参数、主题）
```

> **黄金法则**：**永远不要直接修改 /boot/grub2/grub.cfg**！改 `/etc/default/grub` 和 `/etc/grub.d/`，然后用 `grub2-mkconfig` 重新生成。

### 7.2 grub2-mkconfig 重新生成

```bash
# 重新生成配置（基于 /etc/default/grub + /etc/grub.d/）
grub2-mkconfig -o /etc/grub2.cfg
# 或
grub2-mkconfig -o /boot/grub2/grub.cfg

# 输出会显示 "Generating grub configuration file ... done"
```

**触发时机**：改了 `/etc/default/grub`、装了新内核、改了 `/etc/grub.d/` 里脚本。

### 7.3 菜单超时：GRUB_TIMEOUT

```bash
vi /etc/default/grub
# GRUB_TIMEOUT=10                # 等 10 秒
# GRUB_TIMEOUT=-1               # 永不超时
# GRUB_TIMEOUT=0                # 立即启动默认条目
# GRUB_TIMEOUT_STYLE=menu       # 总是显示菜单（即使超时 0）
# GRUB_TIMEOUT_STYLE=hidden     # 不显示菜单，只显示倒计时
# GRUB_TIMEOUT_STYLE=countdown   # 不显示菜单，但显示倒计时

grub2-mkconfig -o /etc/grub2.cfg
reboot
```

### 7.4 内核启动参数

#### 常用参数

| 参数 | 作用 |
|---|---|
| `ro` | 只读挂载根文件系统（启动后由系统自动切换为读写） |
| `rw` | 直接以读写方式挂载根文件系统 |
| `root=` | 指定根文件系统的设备（如 `root=/dev/sda1` 或 `root=UUID=xxx`） |
| `crashkernel=auto` | 预留内存用于内核崩溃时的转储 |
| `net.ifnames=0` | 禁用网络接口的"一致性命名规则"（让 eth0 而不是 ens33） |
| `biosdevname=0` | 配合 net.ifnames=0，彻底禁用基于 BIOS 的设备命名规则 |
| `rhgb` | Red Hat Graphical Boot，启用图形化启动界面 |
| `quiet` | 减少启动日志（只显示重要信息），debug 开启调试模式 |
| `console=ttyS0` | 启动过程信息显示到 ttyS0，**不显示到 tty1**（适合远程串口） |
| `rd.break` | 在 initramfs 切真根前中断（**密码重置用**） |
| `init=/bin/bash` | 用 bash 代替 init |
| `systemd.unit=` | 指定 systemd 启动的 unit（如 `systemd.unit=rescue.target`） |
| `single` / `1` | 进入单用户模式（等价 rescue.target） |

#### 查看所有可用内核参数

```bash
yum install kernel-doc -y
less /usr/share/doc/kernel-doc-$(uname -r)/Documentation/admin-guide/kernel-parameters.txt
```

> **1 万行起步**，是内核参数权威文档。

#### 修改内核参数

```bash
vi /etc/default/grub
# GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet console=ttyS0"

grub2-mkconfig -o /etc/grub2.cfg
reboot
```

### 7.5 GRUB 菜单加密

**场景**：防止别人按 `e` 编辑启动参数（避免 §5 密码重置被滥用）。

#### 操作步骤

```bash
# 1. 用 grub2-mkpasswd-pbkdf2 生成 PBKDF2 哈希（输入两次密码）
[root@centos7 ~]# grub2-mkpasswd-pbkdf2
Enter password: redhat
Reenter password: redhat
PBKDF2 hash of your password is 
grub.pbkdf2.sha512.10000.649DDB2FE50D7D3A0DF829A21887FFD9...（很长）

# 2. 把哈希写入 /boot/grub2/user.cfg
vi /boot/grub2/user.cfg
GRUB2_PASSWORD=grub.pbkdf2.sha512.10000.649DDB2FE50D7D3A0DF829A21887FFD9...

# 3. 重新生成配置
grub2-mkconfig -o /boot/grub2/grub.cfg

# 4. 重启验证
reboot
```

#### 验证效果

```
启动菜单界面，按 e 编辑。
→ 弹出对话框：输入用户名（root）和密码
→ 输错 → 菜单不让编辑
→ 输对 → 菜单可编辑
```

#### 原理（01_users 脚本）

```bash
cat /etc/grub.d/01_users
#!/bin/sh -e
cat << EOF
if [ -f \${prefix}/user.cfg ]; then
  source \${prefix}/user.cfg
  if [ -n "\${GRUB2_PASSWORD}" ]; then
    set superusers="root"           # 超级用户 = root
    export superusers
    password_pbkdf2 root \${GRUB2_PASSWORD}   # root 的密码哈希
  fi
fi
EOF
```

> **思考**：如何解除 grub 菜单加密？
> 答：1) **进单用户/rescue 模式**（不需要经过 GRUB 校验）2) 在救援 shell 里 `rm /boot/grub2/user.cfg` + `grub2-mkconfig -o /boot/grub2/grub.cfg`

### 7.6 默认启动条目（多内核环境）

#### 查看所有可用启动条目

```bash
grep -o "^menuentry.*CentOS Linux.*Core.'" /etc/grub2.cfg
# menuentry 'CentOS Linux (3.10.0-1160.71.1.el7.x86_64) 7 (Core)'
# menuentry 'CentOS Linux (0-rescue-43c2aa8a5c024d90af4e8da0b3881cb2) 7 (Core)'
```

#### 修改默认启动条目

```bash
vi /boot/grub2/grubenv
# 把 saved_entry 改成想默认启动的条目（要完全匹配）
saved_entry=CentOS Linux (0-rescue-43c2aa8a5c024d90af4e8da0b3881cb2) 7 (Core)

grub2-mkconfig -o /etc/grub2.cfg
reboot
```

#### 用 grub2-set-default 一键设置

```bash
# 比手动改 grubenv 优雅
grub2-set-default 'CentOS Linux (0-rescue-...) 7 (Core)'
grub2-set-default 0   # 用第 N 个条目（从 0 计数）

# 查看当前默认
grub2-editenv list
```

### 7.7 临时修改（不重启后生效）

| 用途 | 操作 |
|---|---|
| 临时进入单用户 | GRUB 菜单按 `e` → linux16 行加 `single` → Ctrl+x |
| 临时重置密码 | GRUB 菜单按 `e` → linux16 行加 `rd.break` → Ctrl+x |
| 临时切救援模式 | GRUB 菜单按 `e` → linux16 行加 `systemd.unit=rescue.target` → Ctrl+x |
| 临时切 multi-user | GRUB 菜单按 `e` → linux16 行加 `systemd.unit=multi-user.target` → Ctrl+x |

---

## §8 GRUB2 故障处理

> **来源**：PDF 第 13-17 页。终极故障恢复技能。

### 8.1 MBR 三段结构回顾

```
MBR = 512 字节 = 引导程序(446) + DPT(64) + 结束标志(2)
                              ↑                ↑
                       4 个分区表项        AA55（魔数）
                       每项 16 字节
```

- **446 字节引导程序**：GRUB2 第一阶段
- **64 字节 DPT**：4 个分区表项（每项 16 字节 = 1 主分区最多 4 个）
- **2 字节结束标志**：AA55（固定值，标识这是个 MBR）

### 8.2 故障 1：grub 引导程序故障（MBR 前 446 字节损坏）

#### 复现

```bash
# 用 dd 把 MBR 前 446 字节清零（破坏引导程序但保留 DPT 和结束标志）
dd if=/dev/zero of=/dev/sda bs=1 count=446
reboot
```

#### 现象

```
系统无法从硬盘启动，则会尝试使用其他设备启动（PXE / 光盘 / U盘）。
```

#### 解决思路

**用光盘/U盘启动 → 进入救援模式 → 重新安装引导程序**。

#### 解决过程（详细）

```
1. 开机从光盘（或 U盘）启动
2. 选择 "Troubleshooting" → "Rescue a CentOS system"
3. 选 1 → 搜索到系统 → 提示系统已挂载在 /mnt/sysimage → 按回车继续
4. 切换 root 目录 + 确认文件系统是读写
   sh-4.2# chroot /mnt/sysimage
   bash-4.2# mount | grep root
   # /dev/mapper/centos-root on / type xfs (rw,relatime,seclabel,...)

5. 确认启动分区磁盘（一般是 /dev/sda）
   bash-4.2# lsblk

6. 重装引导程序
   bash-4.2# grub2-install /dev/sda
   # Installing for i386-pc platform.
   # Installation finished. No error reported.

7. 输入 exit 两次重启
   bash-4.2# exit    # 退出 chroot
   sh-4.2# exit      # 退出 initramfs
   # 系统从硬盘重新启动
```

### 8.3 故障 2：引导文件丢失（vmlinuz）

#### 复现

```bash
mv /boot/vmlinuz-3.10.0-1160.71.1.el7.x86_64{,.ori}
reboot
```

#### 现象

```
系统无法启动，提示：
"/vmlinuz-4.18.0-553.el8_10.x86_64 文件找不到"
```

#### 解决思路

**用光盘启动 → 进救援模式 → 从其他系统复制对应文件过来**。

或者从 RPM 包里提取：

```bash
# 在救援 shell 里
rpm2cpio /run/install/repo/Packages/kernel-3.10.0-1160.71.1.el7.x86_64.rpm | cpio -idmv
# 这会把 vmlinuz 提取出来，复制回 /boot

# 或直接用 yum/dnf 从救援源重装内核
yum reinstall kernel
```

### 8.4 故障处理总结

| 故障 | 现象 | 解决入口 |
|---|---|---|
| MBR 前 446 字节坏 | 启动找不到 GRUB，从 PXE/光盘启动 | 光盘救援 → `grub2-install` |
| DPT 坏 | 分区丢失 / 文件系统找不到 | 光盘救援 → 重建分区表 |
| AA55 标志坏 | 系统不认 MBR | 同上 |
| `/boot/grub2/grub.cfg` 坏 | 启动菜单消失/损坏 | 光盘救援 → `grub2-mkconfig` |
| `/boot` 整个丢失 | 启动到 initramfs 找不到 kernel | 光盘救援 → 重装 kernel 包 |
| `/etc/fstab` 错 | 进 emergency | 进 emergency shell → 改 fstab |
| 文件系统坏 | 进 emergency | 进 emergency → `xfs_repair` |
| root 密码忘 | 进不去系统 | GRUB → rd.break 或 init=/bin/bash |

> **核心思路**：**通过光盘启动** → 系统会把磁盘**挂载到 /mnt/sysimage** → `chroot /mnt/sysimage` 就能像正常系统一样操作。

### 8.5 故障处理的物理化思路

PDF 末尾的原话：

> **"我们也可以通过 U盘启动盘启动或者将故障磁盘拔下来挂载到其他系统。"**

实际生产中**最直接的做法**：把故障盘拔下来，挂到另一台 Linux 机器上直接 `mount`（甚至 `ddrescue` 整个镜像备份）。

---

## §9 LUKS 磁盘加密

> **来源**：PDF 第 17-21 页。**核心目的**：防止别人拿到磁盘后读取数据。

### 9.1 什么是 LUKS

LUKS = **Linux Unified Key Setup**，Linux 统一密钥设置。是 Linux 下主流的磁盘加密标准。**通过加密整个分区或逻辑卷保护数据安全**。

### 9.2 LUKS 加密原理

```
裸分区 /dev/sdb1
  ↓ cryptsetup luksFormat（输入密码）
LUKS 加密分区 /dev/sdb1（含 LUKS header + 加密数据）
  ↓ cryptsetup open（输入密码解锁）
映射设备 /dev/mapper/crypt_disk
  ↓ mkfs.xfs
加密的文件系统
  ↓ mount
挂载到 /mnt/encrypted
```

### 9.3 手动加密数据盘：6 步操作

```bash
# 1. 安装 cryptsetup
yum install cryptsetup -y

# 2. 初始化 LUKS 加密分区（输入密码，警告要输 YES）
cryptsetup luksFormat /dev/sdb1
# WARNING! This will overwrite data on /dev/sdb1 irrevocably.
# 输入 YES
# 输入密码（至少 8 位，含大小写+数字+特殊字符）
# ⚠️ 密码丢了数据就没了！

# 3. 打开（映射）加密分区
cryptsetup open /dev/sdb1 crypt_disk
# 输入步骤 2 的密码
# 生成 /dev/mapper/crypt_disk

# 4. 格式化映射设备
mkfs.xfs /dev/mapper/crypt_disk
# 或 mkfs.ext4 /dev/mapper/crypt_disk

# 5. 挂载使用
mkdir /mnt/encrypted
mount /dev/mapper/crypt_disk /mnt/encrypted

# 6. 卸载 + 关闭加密
umount /mnt/encrypted
cryptsetup close crypt_disk    # 关闭映射 → /dev/sdb1 又变回不可访问
```

### 9.4 开机自动挂载加密分区

```bash
# 1. 获取 LUKS 分区 UUID
blkid /dev/sdb1
# /dev/sdb1: UUID="xxxx-xxxx-xxxx" TYPE="crypto_LUKS"

# 2. 编辑 /etc/crypttab（开机自动解锁）
# 格式：[映射名] [加密分区UUID] [密钥文件路径, none=手动输密码] [luks]
echo "crypt_disk UUID=xxxx-xxxx-xxxx none luks" >> /etc/crypttab

# 3. 编辑 /etc/fstab（开机自动挂载）
echo "/dev/mapper/crypt_disk /mnt/encrypted xfs defaults 0 0" >> /etc/fstab

# 4. 验证配置
mount -a    # 触发 fstab 挂载
df -h /mnt/encrypted
```

### 9.5 自动输入密码（密钥文件）

```bash
# 1. 创建密钥文件并设置 600 权限
echo "mySecretKey123!" > /root/luks_key
chmod 600 /root/luks_key

# 2. 把密钥文件添加给加密设备
cryptsetup luksAddKey /dev/sdb1 /root/luks_key

# 3. 修改 /etc/crypttab 让它用密钥文件
# crypt_disk UUID=xxxx-xxxx-xxxx /root/luks_key luks
sed -i 's|none|/root/luks_key|' /etc/crypttab
```

### 9.6 LUKS 与 GRUB 的边界

> **关键警示**：该加密操作**不会加密 grub2 系统选择菜单**，也就是说 **/boot 目录中的数据是明文的**。

| 数据 | 是否加密 |
|---|---|
| /boot 文件系统（含 vmlinuz + grub.cfg） | ❌ 不加密 |
| /boot 里的 user.cfg（GRUB 密码） | ❌ 明文但哈希过 |
| LUKS 加密数据（密码、其他用户数据） | ✅ AES 加密 |
| 其他分区 / LVM LV | 看你用不用 LUKS |

> **生产建议**：把 `/boot` 放在 **未加密的 LVM 之外**的小分区（256 MB），把数据盘用 LUKS 加密，或者干脆**全盘加密（除了 /boot）**。

---

## §10 思考题：为什么 vmlinuz + initramfs 分开？

> **来源**：PDF 第 20 页末尾思考题，是**理解启动链设计哲学**的关键。

### 答案：职责分离 + 降低维护复杂度

#### vmlinuz（kernel 镜像）
- **职责**：Linux 内核的核心功能（进程管理、内存管理、基础调度）
- **特性**：**通用 + 稳定**，不能频繁改动
- **位置**：`/boot/vmlinuz-<version>`
- **大小**：约 5-10 MB

#### initramfs（initial RAM filesystem）
- **职责**：启动时的"辅助工具箱"——特定磁盘驱动、LVM 模块、LUKS 工具
- **特性**：**按需生成**，每次内核升级或更换硬件可能都要重新生成
- **位置**：`/boot/initramfs-<version>.img`
- **大小**：约 30-100 MB

#### 为什么不合并成一个？

1. **内核升级无需同步驱动更新**
   - 升级 kernel → 只需要新的 vmlinuz，旧 initramfs 中的驱动可能还能用
2. **驱动更新无需重新编译内核**
   - 新增 RAID 卡驱动 → 只需要重建 initramfs，不用碰 vmlinuz
3. **降低系统维护难度**
   - 升级 kernel 时如果失败，可以**回滚到旧的 vmlinuz + 新的 initramfs**（或反过来）

#### 类比

```
vmlinuz = 操作系统内核（Windows NT 内核）
initramfs = 启动盘的驱动集合（WinPE 启动盘）
两者分开 → 升级 NT 内核不需要重新打驱动包
```

---

## §11 易错点 ×10

1. **密码重置忘了 `touch /.autorelabel`** → SELinux 阻止登录
2. **改 `/etc/default/grub` 后忘了 `grub2-mkconfig`** → 修改不生效
3. **直接编辑 `/boot/grub2/grub.cfg`** → 重装内核 / grub2-mkconfig 后被覆盖
4. **方法 2 改了密码但用 `reboot` 而不是 `reboot -f`** → 系统没启动 systemd 直接挂死
5. **fstab 用设备名 `/dev/sdb1` 而不是 UUID** → 设备顺序变了启动失败
6. **救援模式没 `chroot /mnt/sysimage`** → 改的是 initramfs 不是磁盘上的真系统
7. **GRUB 加密后忘了密码 / 想解除又进不去 GRUB** → 必须用光盘救援模式删 `/boot/grub2/user.cfg`
8. **`dd if=/dev/zero of=/dev/sda bs=1 count=446`** → 破坏的是 MBR 引导区，**不是 /dev/sda1 分区**（bs=1 count=446 是 446 字节，覆盖整个磁盘的 MBR 而非特定分区）
9. **LUKS 密码丢了** → 数据**永久无法恢复**（物理销毁是最直接的结局）
10. **直接在运行的系统中 `chroot /mnt/sysimage` 而没先挂载** → chroot 失败

---

## §12 速查表

### 启动故障决策表

| 故障 | 命令 |
|---|---|
| 找回 root 密码 | GRUB → `rd.break` → `mount -o remount,rw /sysroot` → `chroot /sysroot` → `passwd root` → `touch /.autorelabel` |
| 进救援模式 | GRUB → `linux16` 行加 `1` 或 `systemd.unit=rescue.target` |
| 进 emergency 模式 | GRUB → `linux16` 行加 `systemd.unit=emergency.target` |
| 临时切 multi-user | GRUB → 加 `systemd.unit=multi-user.target` |
| 修改 GRUB 菜单超时 | `vi /etc/default/grub` + `GRUB_TIMEOUT=N` + `grub2-mkconfig -o /etc/grub2.cfg` |
| 加密 GRUB 菜单 | `grub2-mkpasswd-pbkdf2` → 写 `user.cfg` → `grub2-mkconfig` |
| 解除 GRUB 菜单加密 | 救援模式 `rm /boot/grub2/user.cfg` + `grub2-mkconfig` |
| MBR 前 446 字节坏 | 光盘救援 → `grub2-install /dev/sda` |
| /boot/vmlinuz 丢失 | 光盘救援 → 重装内核包 |
| /etc/fstab 错导致 emergency | 进 emergency → `vi /etc/fstab` → 改回正确 → `exit` |
| 文件系统破坏 | 进 emergency → `xfs_repair /dev/sdXN` |
| 加密数据盘 | `cryptsetup luksFormat` → `open` → `mkfs` → `mount` |
| 自动挂载加密盘 | 配 `/etc/crypttab` + `/etc/fstab` |

### 关键路径速查

| 路径 | 含义 |
|---|---|
| `/sbin/init` | systemd 的软链接（PID 1） |
| `/etc/systemd/system/default.target` | 默认启动目标软链接 |
| `/etc/fstab` | 文件系统开机自动挂载表 |
| `/boot/grub2/grub.cfg` | GRUB2 实际配置（不直改） |
| `/etc/default/grub` | GRUB2 变量定义 |
| `/etc/grub.d/` | GRUB2 脚本目录 |
| `/boot/grub2/grubenv` | 默认启动条目（saved_entry） |
| `/boot/grub2/user.cfg` | GRUB 菜单密码（GRUB2_PASSWORD） |
| `/etc/crypttab` | LUKS 加密映射表 |
| `/usr/share/doc/kernel-doc-*/Documentation/admin-guide/kernel-parameters.txt` | 内核参数文档 |

### 关键命令速查

| 命令 | 作用 |
|---|---|
| `systemctl get-default` | 看默认 target |
| `systemctl set-default` | 改默认 target |
| `systemctl isolate xxx.target` | 临时切 target |
| `systemctl list-dependencies` | 看 target 依赖 |
| `systemctl rescue` | 进 rescue 模式 |
| `grub2-mkconfig -o /etc/grub2.cfg` | 重新生成 GRUB 配置 |
| `grub2-install /dev/sda` | 安装引导程序到 MBR |
| `grub2-mkpasswd-pbkdf2` | 生成 GRUB 密码哈希 |
| `grub2-set-default N` | 设置默认启动条目 |
| `dmesg` | 看内核启动日志 |
| `journalctl -b` | 看本次启动的 systemd 日志 |
| `xfs_repair /dev/sdXN` | 修复 xfs 文件系统 |
| `cryptsetup luksFormat/open/close` | LUKS 加密 |

---

## §13 面试 6 大追问

> 学完后能回答这 6 个问题，说明 Linux 启动掌握扎实。

1. **CentOS 7 启动的 9 步流程是什么？哪一步最关键？**
   - 加电 → POST → MBR → GRUB2 → kernel+initramfs → systemd(PID 1) → default.target → sysinit.target → getty.target
   - **最关键：第 6 步 systemd** —— 它是用户空间的根，其他所有东西都依赖它

2. **rd.break 和 init=/bin/bash 找回密码的区别？**
   - **rd.break**：在 initramfs 阶段中断，磁盘真根在 /sysroot 只读挂载，需要 `mount -o remount,rw` + `chroot`
   - **init=/bin/bash**：在内核之后跳过 systemd，磁盘真根在 / 直接只读，需要 `mount -o remount,rw /`
   - 共同点：**都要 `touch /.autorelabel`**

3. **MBR 三段结构的字节数和作用？**
   - 引导程序 446 字节（GRUB2 stage 1）
   - DPT 64 字节（4 个分区表项 × 16 字节）
   - 结束标志 2 字节（AA55）

4. **GRUB 菜单加密的原理？**
   - 在 `/boot/grub2/user.cfg` 写 `GRUB2_PASSWORD=<pbkdf2 hash>`
   - `/etc/grub.d/01_users` 脚本读这个文件并设置 `superusers="root"` + `password_pbkdf2`
   - 按 `e` 必须输密码才能编辑

5. **systemd target 和 SysVinit 运行级别的对应？**
   - 0 → halt.target（关机）
   - 1 → rescue.target（单用户）
   - 3 → multi-user.target（字符界面多用户）
   - 5 → graphical.target（图形界面）
   - 6 → reboot.target（重启）

6. **LUKS 加密会加密 /boot 吗？**
   - **不会**。`/boot` 是 GRUB 用的，必须明文（GRUB 不能解 LUKS）
   - 加密范围：只加密数据盘
   - 全盘加密方案：用独立的 /boot 分区（不加密）+ 根分区 + 其他分区（全部 LUKS）

---

## 📎 跨模块链接

- **[[Linux服务与SSH/Linux服务与SSH]]** —— systemd / systemctl / journalctl 的基础（§2 target 入门依赖）
- **[[Linux存储/Linux存储]]** —— LVM 在启动链的早期出现（内核参数 `rd.lvm.lv=centos/root`）
- **[[Linux日志与时间/Linux日志与时间]]** —— journalctl 的启动日志是排错的第一步
- **[[Linux计划任务/Linux计划任务]]** —— crond.service 是 multi-user.target 的成员
- **[[Linux防火墙/Linux防火墙]]** —— firewalld.service 是 multi-user.target 的成员
- **[[Linux用户权限/user-permission]]** —— chroot 在救援模式里需要它（chroot 命令）

## 📦 镜像

- `E:\notes\linux-boot.md`（同步备份）
