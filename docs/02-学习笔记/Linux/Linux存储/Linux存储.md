---
title: Linux 存储 — 设备/分区/RAID/LVM/swap 全攻略
desc: 基于 06.CentOS-7-系统管理-2/4. 文件系统基本管理.pdf + 5. 硬盘分区管理.pdf + 6. RAID 存储技术.pdf + 7. 逻辑卷管理.pdf + 8. 交换空间管理.pdf 共 5 个 PDF 的实操笔记。覆盖 lsblk/df/du、MBR/GPT、fdisk/parted 分区、mkfs/mount、RAID 0/1/5/6/10、mdadm、LVM PV/VG/LV、swap 概念与配置。
type: 笔记
module: Linux存储
pdf: 06.4 文件系统 + 06.5 硬盘分区 + 06.6 RAID + 06.7 LVM + 06.8 交换空间 = 5 个 PDF
pdf_size: 952 + 1894 + 1113 + 778 + 201 = 4938 行
scope: CentOS-7 (xfs + ext4 + mdadm + LVM2)
status: 完成
---

# Linux 存储 — 设备 / 分区 / RAID / LVM / swap 全攻略

> **范围**：基于《CentOS-7 系统管理 2》第 4-8 章 共 5 PDF 整理。
> 覆盖 **设备查看**（lsblk / df / du）+ **硬盘分区**（MBR / GPT / fdisk / parted）+ **文件系统**（mkfs / mount / fstab）+ **RAID 0/1/5/6/10** + **LVM**（PV/VG/LV）+ **swap 交换空间**。
>
> **适用**：CentOS-7 / RHEL 系。

## 目录

- [[#§0 心智模型：存储 = 物理 → 分区 → 文件系统 → 挂载]]
- [[#§1 设备命名规则：sda/vda/nvme0n1]]
- [[#§2 lsblk 看设备树]]
- [[#§3 df 看文件系统使用]]
- [[#§4 du 看目录大小]]
- [[#§5 硬盘分区：MBR vs GPT]]
- [[#§6 fdisk：MBR 分区（限 4 主分区）]]
- [[#§7 parted：GPT 分区（无限分区）]]
- [[#§8 mkfs 格式化文件系统]]
- [[#§9 mount / umount 挂载]]
- [[#§10 /etc/fstab 开机自动挂载]]
- [[#§11 RAID 是什么：磁盘阵列]]
- [[#§12 RAID 级别：0/1/5/6/10 对比]]
- [[#§13 mdadm 创建 RAID 5 实战]]
- [[#§14 RAID 故障处理]]
- [[#§15 LVM 是什么：逻辑卷管理]]
- [[#§16 LVM 三层：PV / VG / LV]]
- [[#§17 LVM 创建流程实战]]
- [[#§18 LVM 扩容 / 缩容]]
- [[#§19 LVM 删除]]
- [[#§20 swap 是什么：交换空间]]
- [[#§21 swap 创建实战]]
- [[#§22 swap 优先级与开机挂载]]
- [[#§23 速查表]]
- [[#§24 易错点 ×12]]
- [[#§25 面试 6 大追问]]
- [[#§26 链路]]

---

## §0 心智模型：存储 = 物理 → 分区 → 文件系统 → 挂载

```
一块新硬盘的使用流程：

原始硬盘（裸盘）
   ↓ 分区（fdisk / parted）
/dev/sdb1 /dev/sdb2 ...
   ↓ 格式化（mkfs.xfs / mkfs.ext4）
带文件系统（xfs / ext4 / btrfs）
   ↓ 挂载（mount）
/data /home /var/www ...
   ↓ 使用
读写文件
```

**关键名词**：
- **物理卷（PV）**：物理硬盘或分区
- **卷组（VG）**：多个 PV 组成的"资源池"
- **逻辑卷（LV）**：从 VG 划出的"虚拟分区"，可动态调大小

---

## §1 设备命名规则：sda/vda/nvme0n1

| 设备类型 | 命名规则 | 示例 |
|---|---|---|
| SATA / SAS / USB / SCSI | `/dev/sd*` | `/dev/sda`, `/dev/sdb1` |
| virtio-blk（虚拟） | `/dev/vd*` | `/dev/vda`, `/dev/vdb1` |
| NVMe SSD | `/dev/nvme*n*` | `/dev/nvme0n1`, `/dev/nvme0n1p1` |
| SD / MMC / eMMC | `/dev/mmcblk*` | `/dev/mmcblk0` |
| 光驱 | `/dev/sr*` | `/dev/sr0` |
| LVM 逻辑卷 | `/dev/mapper/...` 或 `/dev/VG/LV` | `/dev/mapper/rl-root`, `/dev/rl/swap` |

> 💡 **第一块硬盘是 a，第二块是 b**，分区号从 1 开始。
> NVMe 因为是 PCIe 协议，命名带 `n`（namespace）+ `p`（partition）。

---

## §2 lsblk 看设备树

```bash
[root@centos7 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda               8:0    0   20G  0 disk
sr0              11:0    1 13.2G  0 rom
nvme0n1         259:0    0  200G  0 disk
├─nvme0n1p1     259:1    0    1G  0 part /boot
├─nvme0n1p2     259:2    0  199G  0 part
│ ├─rl-root     253:0    0   70G  0 lvm  /
│ ├─rl-swap     253:1    0  3.9G  0 lvm  [SWAP]
│ └─rl-home     253:2    0 125.1G 0 lvm  /home
```

字段含义：
- **NAME**：设备名
- **MAJ:MIN**：主设备号:次设备号（内核标识）
- **RM**：是否可移动（1 = 是，0 = 否；光驱 sr0 RM=1）
- **SIZE**：大小
- **RO**：只读标志
- **TYPE**：`disk` / `part`（分区）/ `lvm`（逻辑卷）/ `rom`
- **MOUNTPOINT**：挂载点

> 💡 **面试题**：怎么看硬盘是不是 SSD？看 `/sys/block/sda/queue/rotational`（1=机械，0=SSD）

---

## §3 df 看文件系统使用

```bash
# 基本（KB 单位）
[root@centos7 ~]# df
Filesystem              1K-blocks    Used  Available Use% Mounted on
devtmpfs                  1971384       0   1971384   0% /dev
tmpfs                     1991520       0   1991520   0% /dev/shm
/dev/mapper/rl-root      73364480 6713888  66650592  10% /
/dev/sr0                 13880362 13880362       0  100% /dvd
/dev/mapper/rl-home     131081692  946976 130134716   1% /home

# 人类可读 + 文件系统类型
[root@centos7 ~]# df -hT
Filesystem              Type    Size  Used Avail Use% Mounted on
/dev/mapper/rl-root     xfs      70G  6.5G   64G  10% /
/dev/sr0                iso9660  14G   14G     0 100% /dvd
/dev/mapper/rl-home     xfs     126G  925M  125G   1% /home
tmpfs                   tmpfs   389M     0  389M   0% /run/user/0

# 1000 进位（不是 1024）
[root@centos7 ~]# df -H

# 看特定目录
[root@centos7 ~]# df -hT /boot
Filesystem            Type  Size  Used Avail Use% Mounted on
/dev/nvme0n1p1        xfs  1014M  202M  813M  20% /boot

# 看 inode 使用
df -i
```

> 💡 **`Use% > 90%` 就要警惕**（磁盘满会导致服务挂）。

---

## §4 du 看目录大小

```bash
# 看 /boot 目录总大小
[root@centos7 ~]# du /boot
0       /boot/efi/EFI/rl/fw
6060    /boot/efi/EFI/rl
1928    /boot/efi/EFI/BOOT
7988    /boot/efi/EFI
7988    /boot/efi
2400    /boot/grub2/i386-pc
3176    /boot/grub2/locale
2504    /boot/grub2/fonts
8096    /boot/grub2
4       /boot/grub
142368  /boot
# ↑ 每层目录大小

# 看当前目录总大小（不递归显示）
[root@centos7 ~]# du -sh /boot
4.0K    /boot/efi
...

# 找最大的子目录
[root@centos7 ~]# du -sh /var/* | sort -rh | head -5
```

**常用选项**：
```bash
du -sh dir/         # 总大小（人读）
du -ah dir/         # 所有文件 + 人读
du -h --max-depth=1 # 1 层深度
du --time dir/      # 显示修改时间
```

---

## §5 硬盘分区：MBR vs GPT

|      | MBR                           | GPT                                       |
| ---- | ----------------------------- | ----------------------------------------- |
| 别名   | Master Boot Record            | GUID Partition Table                      |
| 出现时间 | 1982（IBM PC）                  | 2009（EFI 标准）                              |
| 最大卷  | 2 TiB                         | **8 ZiB**（理论）                             |
| 分区数  | **4 个主分区**（或 3 主 + 1 扩展）      | **128 个主分区**                              |
| 元数据  | 446B + 64B DPT + 2B 签名 = 512B | LBA 0 保护 MBR + LBA 1 GPT 头 + LBA 2-33 分区表 |
| 兼容性  | 老 BIOS                        | UEFI                                      |

**MBR 分区结构（512 字节）**：
```
0 - 445       : 446 字节 引导代码（bootloader）
446 - 509     : 64 字节 分区表（4 × 16 字节 = 4 主分区）
510 - 511     : 2 字节 魔术字（55 AA）
```

**GPT 分区结构**：
```
LBA 0    : 保护 MBR（兼容老工具）
LBA 1    : GPT 头（位置、校验）
LBA 2-33 : 分区表（128 个分区项）
LBA 34+  : 数据区
最后 LBA : 备份 GPT 头
```

> 💡 **新硬盘都建议 GPT**。Windows 10+/Linux 2.6.25+ 都原生支持。

---

## §6 fdisk：MBR 分区（限 4 主分区）

### 6.1 启动

```bash
# 看磁盘信息
[root@centos7 ~]# fdisk -l /dev/sdb

Disk /dev/sdb: 21.5 GB, 21474836480 bytes, 41943040 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos                 ← MBR
Disk identifier: 0x78ceaffe

   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048    41943039    20970496   83  Linux

# 进入交互模式
[root@centos7 ~]# fdisk /dev/sdb
Command (m for help):
```

### 6.2 交互命令

| 命令  | 含义        |
| --- | --------- |
| `m` | 帮助        |
| `p` | 打印分区表     |
| `n` | 新建分区      |
| `d` | 删除分区      |
| `t` | 改分区类型     |
| `l` | 列出已知类型    |
| `w` | 写入并退出     |
| `q` | 不保存退出     |
| `g` | 改 GPT 分区表 |
| `o` | 改 MBR 分区表 |

### 6.3 实战：分一个 2G 主分区

```bash
[root@centos7 ~]# fdisk /dev/sdb
Command (m for help): n              ← 新建

Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p):                  ← 默认 p（主分区），回车

Partition number (1-4, default 1):   ← 默认 1，回车

First sector (2048-41943039, default 2048):  ← 默认 2048
Using default value 2048

Last sector, +sectors or +size{K,M,G} (2048-41943039, default 41943039): +2G
#                              ↑ 直接写 +2G = 2GB

Partition 1 of type Linux and of size 2 GiB is set

Command (m for help): p              ← 看结果
Disk /dev/sdb: 21.5 GB, 21474836480 bytes, 41943040 sectors
...
   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048     4196351     2097152   83  Linux

Command (m for help): w              ← 写入！不 w 不会生效
The partition table has been altered!
```
### 小块（如 512B / 1KB / 2048B）

适用于：大量小文件的场景

- 网页服务器：海量小的 HTML / CSS / 图片碎片
- 邮件服务器：每封邮件都是一堆小文件
- 版本控制仓库（Git 仓库）：大量小的 object
- 系统目录（/etc、/var/log）：配置文件、日志行

核心优势：减少空间浪费。一个 100 字节的文件，块越大浪费越多（4096 块浪费 3996 字节，1024 块只浪费 924 字节）。

### 大块（如 4096B / 8KB / 64KB）

适用于：大文件顺序读写的场景

- 数据库服务器：连续的大数据块读写
- 视频/音频存储：流式读取大文件
- 虚拟机磁盘镜像（qcow2 / vmdk）：大文件顺序 IO
- 备份归档：大压缩包

核心优势：减少元数据开销，提升顺序读写性能。块越大，存储同样大小的文件需要的块数越少，inode/位图追踪的压力小。
### 实际选择建议

| 场景 | 推荐块大小 |
|------|-----------|
| 通用系统盘 | 4096（默认值，兼顾性能和空间） |
| 大量小文件 | 1024 或 2048 |
| 数据库/大文件 | 4096~64KB |
| NFS 共享小文件 | 1024 |

关键限制：ext4 最大单文件 = 块大小 × 2^32 块数。块太小则单文件容量受限。
---

## §7 parted：GPT 分区（无限分区）

### 7.1 parted vs fdisk

| | fdisk | parted |
|---|---|---|
| 分区表 | MBR 优先（g 命令可切 GPT）| GPT / MBR 都行 |
| 交互 | 交互式 | **一行命令搞定**（非交互）|
| 大于 2T | ❌ | ✅ |

### 7.2 parted 命令行

```bash
# 1) 打 GPT 标签
[root@centos7 ~]# parted /dev/sdb mklabel gpt

# 2) 分一个 1G 的 linux-swap 分区
[root@centos7 ~]# parted /dev/sdb unit MiB mkpart swap01 linux-swap 1 2049

# 3) 看结果
[root@centos7 ~]# parted /dev/sdb unit MiB print
Model: ATA VBOX HARDDISK (scsi)
Disk /dev/sdb: 20480MiB
Partition Table: gpt
Number  Start    End      Size     File system  Name    Flags
 1      1.00MiB  2049MiB  2048MiB               swap01

# 4) 分一个 xfs 分区（剩余空间）
[root@centos7 ~]# parted /dev/sdb unit MiB mkpart data01 xfs 2050 100%
```

---

## §8 mkfs 格式化文件系统

```bash
# 选文件系统
mkfs.xfs    /dev/sdb1    # XFS（CentOS-7 默认）
mkfs.ext4   /dev/sdb1    # ext4（老 RHEL 默认）
mkfs.vfat   /dev/sdb1    # FAT32（U 盘）
mkfs.btrfs  /dev/sdb1    # Btrfs（新一代）

# 选项
mkfs.xfs -f /dev/sdb1           # 强制（已有 FS 时）
mkfs.xfs -L mydata /dev/sdb1    # 加标签
mkfs.ext4 -b 4096 /dev/sdb1     # block size

# 等同命令
mkfs -t xfs /dev/sdb1
```

**文件系统对比**：

| | XFS | ext4 | Btrfs |
|---|---|---|---|
| 最大卷 | 8 EiB | 1 EiB | 16 EiB |
| 单文件 | 8 EiB | 16 TiB | 16 EiB |
| 特性 | 高性能、写优化 | 通用、稳定 | CoW、快照 |
| 恢复 | 难（设计使然）| 较好（e2fsck）| 好（自带 scrub）|
| 适用 | 数据库、视频 | 通用 | NAS / 容器 |

> 💡 **CentOS-7 默认 XFS**（不可缩，只能扩）。**RHEL/CentOS-8 改回 ext4 + LUKS**。

---

## §9 mount / umount 挂载

```bash
# 临时挂载
[root@centos7 ~]# mkdir /data
[root@centos7 ~]# mount /dev/sdb1 /data
[root@centos7 ~]# mount | grep sdb1
/dev/sdb1 on /data type xfs (rw,relatime,seclabel,attr2,inode64,noquota)

# 卸载
[root@centos7 ~]# umount /data
# 或
[root@centos7 ~]# umount /dev/sdb1

# 强制卸载（有人在用）
[root@centos7 ~]# umount -f /data
# 或（lazy 模式）
[root@centos7 ~]# umount -l /data

# 常见问题：设备忙
[root@centos7 ~]# umount /data
umount: /data: device is busy
# 解决：cd / 后再 umount

# 只读挂载
mount -o ro /dev/sdb1 /data
# 重新挂载为 rw
mount -o remount,rw /data

# 临时改 owner
mount -o uid=xkw,gid=xkw /dev/sdb1 /data
```

---

## §10 /etc/fstab 开机自动挂载

```bash
# 设备  挂载点  文件系统  选项  dump  fsck
UUID=xxx  /       xfs    defaults  0 0
UUID=xxx  /boot   xfs    defaults  0 0
UUID=xxx  swap    swap   defaults  0 0
```

**6 列详解**：

| 列 | 含义 |
|---|---|
| **设备** | UUID 或设备路径（**UUID 推荐**，盘符会变） |
| **挂载点** | 目录（swap 写 swap） |
| **文件系统** | xfs / ext4 / swap / iso9660 |
| **选项** | defaults / rw / ro / noatime / nodiratime |
| **dump** | 是否被 dump 备份（0 = 否，1 = 是） |
| **fsck** | 启动时是否检查（0 = 不，1 = / 第一个，2 = 其他） |

```bash
# 查 UUID
[root@centos7 ~]# blkid /dev/sdb1
/dev/sdb1: UUID="2bf4e179-3648-4412-9495-3b278df4acd6" TYPE="xfs"

# 验证 fstab 没语法错（不会真挂）
[root@centos7 ~]# mount -a
# 或
[root@centos7 ~]# mount -fav

# 实战：加 swap 到 fstab
UUID=2bf4e179-3648-4412-9495-3b278df4acd6 swap swap pri=4 0 0
```

**常用挂载选项**：
```
defaults    = rw,suid,dev,exec,auto,nouser,async
noatime     = 不更新访问时间（提速）
nodiratime  = 不更新目录访问时间
noexec      = 不允许执行二进制（安全）
nosuid      = 忽略 SUID（安全）
ro / rw     = 只读 / 读写
sync        = 同步写（数据安全但慢）
async       = 异步写（默认）
```

---

## §11 RAID 是什么：磁盘阵列

```
RAID = Redundant Array of Independent Disks（独立磁盘冗余阵列）

1988 年 D. A. Patterson 提出
目的：
  - 提高性能（多盘并行）
  - 提高可靠性（冗余）
  - 降低成本（用小盘代替大硬盘）
```

**三种实现方式**：
1. **硬件 RAID**：RAID 卡（贵，企业级）
2. **软件 RAID**：内核 md 模块（便宜，Linux 标配）
3. **混合 RAID**：MegaCli 等半硬件方案

---

## §12 RAID 级别：0/1/5/6/10 对比

| RAID        | 别名         | 磁盘数 | 容量利用率    | 可靠性   | 性能     | 适用      |
| ----------- | ---------- | --- | -------- | ----- | ------ | ------- |
| **RAID 0**  | 条带（stripe） | ≥2  | **100%** | ❌ 无冗余 | **最快** | 临时数据    |
| **RAID 1**  | 镜像（mirror） | ≥2  | 50%      | ✅ 高   | 读快写慢   | 系统盘     |
| **RAID 5**  | 单校验        | ≥3  | (n-1)/n  | ✅ 中   | 读快写中   | **最常用** |
| **RAID 6**  | 双校验        | ≥4  | (n-2)/n  | ✅ 高   | 读快写慢   | 重要数据    |
| **RAID 10** | 1+0        | ≥4  | 50%      | ✅ 高   | 快      | 高性能高可靠  |

### RAID 0（条带）

```
A1 A2 A3 A4    →  sdb1 sdc1 sdd1
B1 B2 B3 B4    →  sdb2 sdc2 sdd2
   ↑ 写入时把数据"切条"分散到多盘
```
- ✅ **性能最佳**（n 倍速）
- ❌ **无冗余**（1 块坏 = 全完）
- ⚠️ 仅适合临时数据

### RAID 1（镜像）

```
A1 A1    A2 A2    A3 A3
   ↑ 每份数据写两份
```
- ✅ **高可靠性**（坏 1 块没事）
- ❌ **容量 50%**（n 块盘只用 n/2）
- ✅ 读性能提升（多盘并行读）

### RAID 5（单校验）

```
A1 A2 A3 Ap    A4 A5 A6 Ap    A7 A8 A9 Ap
       ↑              ↑              ↑
     校验         校验         校验
```
- 容量 (n-1)/n（每 n 块盘"牺牲"1 块放校验）
- ✅ 坏 1 块能重建
- ❌ 写性能一般（要算校验）
- 💡 **企业最常用**

### RAID 6（双校验）

```
A1 A2 A3 Ap Aq    A4 A5 A6 Ap Aq
          ↑ ↑
       双校验
```
- 容量 (n-2)/n
- ✅ 坏 2 块没事
- ❌ 写性能更差
- 💡 大容量 RAID 必备

### RAID 10（先 1 后 0）

```
RAID1+RAID1 = RAID10
   ↓ 先镜像（每对盘镜像）
      再条带（多对镜像组之间条带）
```
- ✅ **性能 + 可靠性双高**
- ❌ 容量 50%
- 💡 **数据库首选**

---

## §13 mdadm 创建 RAID 5 实战

### 13.1 准备

```bash
# 假设有 4 块 20G 盘：sdb sdc sdd sde
# 创建 RAID 5（容量 = 60G，牺牲 1 块做校验）

# 1) 创建阵列
[root@centos7 ~]# mdadm -C /dev/md0 -l 5 -n 4 -x 1 /dev/sd{b,c,d,e,f}
#                 ↑ 设备名  ↑ RAID 5  ↑ 4 个活动盘  ↑ 1 个热备
# -C = create
# -l = level
# -n = number of devices
# -x = spare disks

# 2) 看进度
[root@centos7 ~]# cat /proc/mdstat
Personalities : [raid1] [raid5]
md0 : active raid5 sdd[3] sdc[1] sdb[0] sde[4]
      62868480 blocks super 1.2 level 5, 512k chunk, algorithm 2 [4/4] [UUUU]
unused devices: <none>
# ↑ [UUUU] = 4 块都在（U = Up）

# 3) 详细查看
[root@centos7 ~]# mdadm -D /dev/md0
   Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       3       8       64        3      active sync   /dev/sde
       4       8       80        -      spare   /dev/sdf    ← 热备
```

### 13.2 格式化 + 挂载

```bash
# 4) 格式化
[root@centos7 ~]# mkfs.xfs /dev/md0

# 5) 挂载
[root@centos7 ~]# mkdir /data
[root@centos7 ~]# mount /dev/md0 /data

# 6) 验证容量
[root@centos7 ~]# df -h /data
Filesystem      Size  Used Avail Use% Mounted on
/dev/md0         60G   33M   60G   1% /data
# ↑ 4 块 20G，RAID 5 容量 = 60G（20 * 3）
```

### 13.3 开机自动挂载

```bash
# /etc/fstab 加一行
/dev/md0    /data    xfs    defaults    0 0

# 生成 mdadm 配置文件（自动重组）
[root@centos7 ~]# mdadm -D --scan > /etc/mdadm.conf
```

---

## §14 RAID 故障处理

### 14.1 模拟硬盘故障

```bash
# 标记 sdc 故障（强制下线）
[root@centos7 ~]# mdadm /dev/md0 -f /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0

# 看状态（sdc 标 F = Fault）
[root@centos7 ~]# mdadm -D /dev/md0
   Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8        0        -      faulty   /dev/sdc    ← 故障
       2       8       48        2      active sync   /dev/sdd
       3       8       64        3      active sync   /dev/sde
       4       8       80        -      spare   /dev/sdf

# 移除故障盘
[root@centos7 ~]# mdadm /dev/md0 -r /dev/sdc
mdadm: removed /dev/sdc

# 热备盘 sdf 自动顶上，重建中
[root@centos7 ~]# cat /proc/mdstat
md0 : active raid5 sdf[4] sdb[0] sdc[1](F) sdd[2] sde[3]
       62868480 blocks super 1.2 level 5, 512k chunk, algorithm 2 [4/3] [_UUU]
       [==>..................]  recovery = 12.3%
# ↑ 自动重建中
```

### 14.2 加新盘

```bash
# 换上新盘
[root@centos7 ~]# mdadm /dev/md0 -a /dev/sdc
mdadm: added /dev/sdc

# sdc 变成新的 spare（热备）
```

### 14.3 停止阵列

```bash
# 停阵列（先 umount）
[root@centos7 ~]# umount /data
[root@centos7 ~]# mdadm -S /dev/md0
# -S = stop
```

---

## §15 LVM 是什么：逻辑卷管理

```
LVM = Logical Volume Manager（逻辑卷管理器）

解决的问题：
  - 传统分区大小固定，扩/缩麻烦
  - 多盘组合成一个大池，灵活分配
  - 在线扩缩容（业务不中断）

类比：
  物理卷（PV）= 一块地
  卷组（VG）= 把几块地围起来
  逻辑卷（LV）= 在围起来的地里划一块种菜
```

**优势**：
- ✅ 动态扩容
- ✅ 多盘合一
- ✅ 快照（snapshot）
- ✅ 在线迁移

**代价**：
- ❌ 性能略低（多一层抽象）
- ❌ 恢复复杂

---

## §16 LVM 三层：PV / VG / LV

```
物理层：Physical Volume (PV)        ← /dev/sdb, /dev/sdc ...
   ↓ 加入 VG
卷组层：Volume Group (VG)             ← 资源池，名字如 webapp, dbapp
   ↓ 划出 LV
逻辑层：Logical Volume (LV)          ← /dev/webapp/lv01, /dev/mapper/webapp-lv01
   ↓ 格式化 + 挂载
文件系统层：xfs / ext4
```

**概念关系**：
- **PE**（Physical Extend）= LVM 的最小单位（默认 4 MiB）
- **LE**（Logical Extend）= 对应到 LV 的最小单位

---

## §17 LVM 创建流程实战

### 17.1 准备 3 块盘

```bash
# 看盘
[root@centos7 ~]# lsblk /dev/sd{b..d}
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sdb 8:16    0   20G  0 disk
sdc 8:32    0   20G  0 disk
sdd 8:48    0   20G  0 disk
```

### 17.2 创建 PV

```bash
# 1) 把磁盘标记为 PV
[root@centos7 ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

[root@centos7 ~]# pvcreate /dev/sd{c,d}
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.

# 2) 看 PV
[root@centos7 ~]# pvs
  PV         VG  Fmt  Attr PSize  PFree
  /dev/sdb       lvm2 ---  20.00g 20.00g
  /dev/sdc       lvm2 ---  20.00g 20.00g
  /dev/sdd       lvm2 ---  20.00g 20.00g
# ↑ Fmt = lvm2 已就绪，VG 列空（未加入 VG）

# 3) 详细
[root@centos7 ~]# pvdisplay /dev/sdb
  --- NEW Physical volume ---
  PV Name               /dev/sdb
  VG Name                                    ← 空
  PV Size               20.00 GiB
  Allocatable           NO                   ← 还没分配
  PE Size               0                    ← 加入 VG 后才有
  Total PE              0
```

### 17.3 创建 VG

```bash
# 1) 创建 webapp VG（用 sdb）
[root@centos7 ~]# vgcreate webapp /dev/sdb
  Volume group "webapp" successfully created

# 2) 创建 dbapp VG（用 sdc + sdd = 40G）
[root@centos7 ~]# vgcreate dbapp /dev/sd{c,d}
  Volume group "dbapp" successfully created

# 3) 看 VG
[root@centos7 ~]# vgs
  VG       #PV #LV #SN Attr   VSize   VFree
  dbapp      2   0   0 wz--n- 39.99g 39.99g
  webapp     1   0   0 wz--n- <20.00g <20.00g

# 4) 详细
[root@centos7 ~]# vgdisplay dbapp
  --- Volume group ---
  VG Name               dbapp
  Format                lvm2
  VG Size               39.99 GiB
  PE Size               4.00 MiB              ← 默认 PE 大小
  Total PE              10238                  ← 10238 × 4M = 40G
  Free  PE / Size       10238 / 39.99 GiB
```

### 17.4 创建 LV

```bash
# 1) 创建 LV（用 dbapp VG，划 10G）
[root@centos7 ~]# lvcreate -L 10G -n lv01 dbapp
  Logical volume "lv01" created.
# -L = 大小，-n = 名字

# 2) 创建 LV（按 PE 数）
[root@centos7 ~]# lvcreate -l 512 -n lv02 dbapp
# -l = PE 数（512 × 4M = 2G）

# 3) 用全部剩余空间
[root@centos7 ~]# lvcreate -l 100%FREE -n lv03 dbapp

# 4) 看 LV
[root@centos7 ~]# lvs
  LV    VG       Attr       LSize
  lv01  dbapp    -wi-a----- 10.00g
  lv02  dbapp    -wi-a----- 2.00g
  lv03  dbapp    -wi-a----- 27.99g
```

### 17.5 格式化 + 挂载

```bash
# 1) 格式化
[root@centos7 ~]# mkfs.xfs /dev/dbapp/lv01
# 或
[root@centos7 ~]# mkfs.xfs /dev/mapper/dbapp-lv01

# 2) 挂载
[root@centos7 ~]# mkdir /dbdata
[root@centos7 ~]# mount /dev/dbapp/lv01 /dbdata

# 3) 看挂载
[root@centos7 ~]# df -h /dbdata
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/dbapp-lv01    10G  33M  10G   1% /dbdata
```

### 17.6 fstab 自动挂载

```bash
# 查 UUID（更稳）
[root@centos7 ~]# blkid /dev/dbapp/lv01
/dev/dbapp/lv01: UUID="..." TYPE="xfs"

# /etc/fstab
UUID=xxx    /dbdata    xfs    defaults    0 0
```

---

## §18 LVM 扩容 / 缩容

### 18.1 扩容 LV（在线）

```bash
# 场景：lv01 现在 10G，想加到 15G

# 1) 扩 LV 5G
[root@centos7 ~]# lvextend -L +5G /dev/dbapp/lv01
  Size of logical volume dbapp/lv01 changed from 10.00 GiB to 15.00 GiB.

# 2) 扩文件系统（xfs 用 xfs_growfs，ext4 用 resize2fs）
[root@centos7 ~]# xfs_growfs /dbdata
# xfs 是先扩 LV 再扩 FS（一步走也行：lvextend -r）
```

**一步走 + 扩 FS**：
```bash
[root@centos7 ~]# lvextend -L +5G -r /dev/dbapp/lv01
#                                          ↑ -r = resize filesystem
```

### 18.2 加 VG 容量（加新盘）

```bash
# 场景：VG 满了，加一块盘

# 1) 创建 PV
[root@centos7 ~]# pvcreate /dev/sde

# 2) 加到现有 VG
[root@centos7 ~]# vgextend webapp /dev/sde
  Volume group "webapp" successfully extended

# 3) 现在可以扩 LV 了
[root@centos7 ~]# lvextend -l +100%FREE /dev/webapp/lv01 -r
```

### 18.3 缩容（仅 ext4 支持，xfs 不行）

```bash
# 先缩 FS（ext4）
[root@centos7 ~]# umount /data
[root@centos7 ~]# resize2fs /dev/webapp/lv01 5G
# 再缩 LV
[root@centos7 ~]# lvreduce -L 5G /dev/webapp/lv01
# 重新挂载
[root@centos7 ~]# mount /dev/webapp/lv01 /data
```

> ⚠️ **xfs 只能扩不能缩**！缩之前必须备份。

---

## §19 LVM 删除

```bash
# 从下往上删（LV → VG → PV）

# 1) 卸载
[root@centos7 ~]# umount /dbdata

# 2) 删 LV
[root@centos7 ~]# lvremove /dev/dbapp/lv01
Do you really want to remove active logical volume "lv01"? [y/n]: y

# 3) 删 VG
[root@centos7 ~]# vgremove dbapp

# 4) 删 PV
[root@centos7 ~]# pvremove /dev/sd{b,c,d}
```

---

## §20 swap 是什么：交换空间

```
swap = 交换空间 = 把磁盘当内存用
  当内存不够时，内核把"冷"数据搬到 swap
  等需要时再搬回来

类比：内存是书桌，swap 是抽屉
     书桌满了 → 把不常用的书扔抽屉
     要用了 → 从抽屉拿回来
```

**为什么需要**：
- 内存不够用时避免 OOM（Out of Memory）杀进程
- 支持休眠（Hibernate）：内存数据存到 swap

**配置建议**：

| 物理内存 | swap 大小 | 含休眠 |
|---|---|---|
| < 2 GB | 2×RAM | 2×RAM |
| 2-8 GB | 同 RAM | 1.5×RAM |
| 8-64 GB | 4 GB | 1.5×RAM |
| > 64 GB | 4 GB | 1×RAM（Hibernate）|

---

## §21 swap 创建实战

### 21.1 用文件当 swap（不重启）

```bash
# 1) 创建 1G 文件
[root@centos7 ~]# dd if=/dev/zero of=/swapfile bs=1M count=1024
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied

# 2) 改权限（必须！）
[root@centos7 ~]# chmod 600 /swapfile

# 3) 格式化为 swap
[root@centos7 ~]# mkswap /swapfile
Setting up swapspace version 1, size = 1048572 KiB

# 4) 启用
[root@centos7 ~]# swapon /swapfile

# 5) 验证
[root@centos7 ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:           3931         478        1500          14        1952        3201
Swap:          4999           0        4999   ← 多了 1G
```

### 21.2 用分区当 swap（推荐）

```bash
# 1) 分区（用 parted）
[root@centos7 ~]# parted /dev/sdb mklabel gpt
[root@centos7 ~]# parted /dev/sdb unit MiB mkpart swap01 linux-swap 1 2049

# 2) 验证
[root@centos7 ~]# parted /dev/sdb unit MiB print
Number  Start    End      Size     File system  Name    Flags
 1      1.00MiB  2049MiB  2048MiB               swap01

# 3) 格式化为 swap
[root@centos7 ~]# mkswap /dev/sdb1
Setting up swapspace version 1, size = 2097148 KiB
no label, UUID=2bf4e179-3648-4412-9495-3b278df4acd6

# 4) 启用
[root@centos7 ~]# swapon /dev/sdb1
```

### 21.3 用 LVM 逻辑卷当 swap

```bash
# 1) 划 LV
[root@centos7 ~]# lvcreate -L 4G -n swap01 dbapp

# 2) 格式化
[root@centos7 ~]# mkswap /dev/dbapp/swap01

# 3) 启用
[root@centos7 ~]# swapon /dev/dbapp/swap01
```

---

## §22 swap 优先级与开机挂载

### 22.1 优先级

```bash
# 看 swap 优先级
[root@centos7 ~]# swapon -s
Filename       Type        Size    Used   Priority
/dev/dm-1      partition   4063228 0     -2
/dev/sdb1      partition   2097148 0     -3
# ↑ 数字越小优先级越高（-2 比 -3 优先）

# 设优先级（启动时）
[root@centos7 ~]# swapon -p 4 /dev/sdb1

# 范围：0-32767
# 数值越大越优先
```

### 22.2 开机挂载

```bash
# /etc/fstab 加
UUID=2bf4e179-3648-4412-9495-3b278df4acd6  swap  swap  pri=4  0 0

# 立即按 fstab 启用所有 swap
[root@centos7 ~]# swapon -a

# 立即按 fstab 关闭所有 swap
[root@centos7 ~]# swapoff -a
```

### 22.3 swap 调优参数

```bash
# /proc/sys/vm/swappiness
# 0 = 尽量不用 swap（推荐 SSD 内存大）
# 60 = 默认
# 100 = 积极用 swap

# 临时改
[root@centos7 ~]# sysctl vm.swappiness=10

# 永久
[root@centos7 ~]# echo 'vm.swappiness=10' >> /etc/sysctl.conf
[root@centos7 ~]# sysctl -p
```

---

## §23 速查表

### 23.1 设备查看

```bash
lsblk                    # 设备树
df -hT                   # 文件系统使用
du -sh dir/              # 目录大小
fdisk -l                 # 分区表
blkid /dev/sdb1          # UUID + 类型
parted /dev/sdb print    # GPT 分区详情
```

### 23.2 分区 + 格式化

```bash
# MBR
fdisk /dev/sdb
#  n → p → 1 → 回车 → +2G → w

# GPT
parted /dev/sdb mklabel gpt
parted /dev/sdb mkpart primary xfs 1MiB 100%

# 格式化
mkfs.xfs /dev/sdb1
mkfs.ext4 /dev/sdb1
```

### 23.3 挂载

```bash
mount /dev/sdb1 /mnt
mount -o ro /dev/sdb1 /mnt
mount -o remount,rw /mnt
umount /mnt
umount -l /mnt    # 懒卸载

# /etc/fstab
UUID=xxx  /mnt  xfs  defaults  0 0
```

### 23.4 RAID

```bash
# 创建
mdadm -C /dev/md0 -l 5 -n 4 -x 1 /dev/sd{b..f}

# 查看
cat /proc/mdstat
mdadm -D /dev/md0

# 标记故障
mdadm /dev/md0 -f /dev/sdc

# 移除
mdadm /dev/md0 -r /dev/sdc

# 加新盘
mdadm /dev/md0 -a /dev/sdc

# 停止
mdadm -S /dev/md0

# 生成配置
mdadm -D --scan > /etc/mdadm.conf
```

### 23.5 LVM

```bash
# PV
pvcreate /dev/sd{b,c,d}
pvdisplay /dev/sdb
pvs

# VG
vgcreate webapp /dev/sdb
vgextend webapp /dev/sde
vgdisplay webapp
vgs

# LV
lvcreate -L 10G -n lv01 webapp
lvcreate -l 100%FREE -n lv02 webapp
lvextend -L +5G -r /dev/webapp/lv01     # 扩 + 自动扩 FS
lvreduce -L 5G /dev/webapp/lv01          # 缩（xfs 不支持）

# 删除
lvremove /dev/webapp/lv01
vgremove webapp
pvremove /dev/sdb
```

### 23.6 swap

```bash
# 文件 swap
dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# 分区 swap
mkswap /dev/sdb1
swapon /dev/sdb1

# 看 swap
free -m
swapon -s

# 关闭
swapoff /dev/sdb1
swapoff -a    # 关所有
```

---

## §24 易错点 ×12

### 1. ❌ fdisk 大于 2T 盘

```bash
# fdisk 不支持 > 2T
# 用 parted
parted /dev/sdb mklabel gpt
```

### 2. ❌ mkfs 不指定文件系统类型

```bash
mkfs /dev/sdb1    # 交互式问（容易卡住）
# 推荐：mkfs.xfs 或 mkfs.ext4
```

### 3. ❌ LVM 创建顺序错

```bash
# 必须按 PV → VG → LV 顺序
# 不能 lvcreate 之前没 vgcreate
```

### 4. ❌ xfs 想缩容

```bash
# xfs 不能缩！只能扩
# 缩之前先备份
```

### 5. ❌ swap 文件忘 chmod 600

```bash
# mkswap 之前必须 chmod 600
# 否则系统拒绝启用
chmod 600 /swapfile
mkswap /swapfile
```

### 6. ❌ mount 时没建目录

```bash
mount /dev/sdb1 /mnt/newdir    # ⚠️ No such file or directory
mkdir -p /mnt/newdir
mount /dev/sdb1 /mnt/newdir
```

### 7. ❌ fstab 写错导致开不了机

```bash
# 写错 UUID 或设备 → 启动卡在 emergency mode
# 救援：进入 emergency shell，改 /etc/fstab
mount -o remount,rw /
vi /etc/fstab   # 删掉错的行
reboot
```

### 8. ❌ LVM 设备路径用错

```bash
# /dev/webapp/lv01 和 /dev/mapper/webapp-lv01 等价
# 但别写 /dev/webapp/lv01/1（没这路径）
```

### 9. ❌ RAID 阵列没保存配置

```bash
# 创建阵列必须生成配置文件
mdadm -D --scan > /etc/mdadm.conf
# 否则重启后 /dev/md0 可能变 /dev/md127
```

### 10. ❌ RAID 误删盘

```bash
# md 设备不是 hot-swap
# 删之前必须先 -f（标记故障）→ -r（移除）
mdadm /dev/md0 -f /dev/sdc
mdadm /dev/md0 -r /dev/sdc
# 然后才能拔硬盘
```

### 11. ❌ swap 优先级理解错

```bash
# 数字越大优先级越高（不是越小！）
swapon -p 32767 /dev/sdb1    # 最高优先级
swapon -p 0 /dev/sdc1         # 最低
```

### 12. ❌ 直接对硬盘 mkfs

```bash
# 不要对整盘 /dev/sdb 格式化（除非整盘当一个分区）
# 必须先分区 → /dev/sdb1 → mkfs
```

---

## §25 面试 6 大追问

### Q1：RAID 0 / 1 / 5 / 10 怎么选？

**答**：
- **RAID 0**：临时数据、要速度不要可靠性
- **RAID 1**：系统盘、小容量高可靠
- **RAID 5**：**企业最常用**，容量利用率高 + 一块冗余
- **RAID 10**：**数据库首选**，性能 + 可靠性双高

### Q2：LVM 有什么好处？

**答**：
- **动态扩缩容**（业务不中断）
- **多盘合一**（灵活性）
- **快照**（备份/恢复）
- **在线迁移**

### Q3：xfs 和 ext4 区别？

**答**：
- xfs：**只能扩不能缩**（高性能，CentOS-7 默认）
- ext4：**可扩可缩**（通用，RHEL 8 默认）
- xfs 适合大文件（视频、数据库），ext4 适合小文件

### Q4：swap 设多大？

**答**：
- < 8 GB RAM：swap = RAM 或 2×RAM
- 8-64 GB：swap = 4-8 GB（够 OOM 缓冲）
- > 64 GB：swap = 4 GB（Hibernate）

### Q5：MBR 和 GPT 区别？

**答**：
- MBR：最大 2 TB、4 主分区、老 BIOS
- GPT：几乎无限大、128 分区、UEFI
- 新盘用 GPT

### Q6：mdadm RAID 5 重建时要多久？

**答**：
- 1 TB 盘 ≈ 1-2 小时
- 公式：大约 **200 GB/小时**（家用硬件）
- 重建期间性能下降（不要同时跑大量 IO）

---

## §26 链路

| 笔记 | 关系 |
|---|---|
| [[LinuxShell/shell]] | `dd` 是 shell 常用命令 |
| [[Linux用户权限/user-permission]] | 文件系统权限涉及 owner/group |
| [[Linux包管理/package]] | yum install mdadm lvm2 |
| [[Linux服务与SSH/Linux服务与SSH]] | NFS / iSCSI 也是存储方案 |
| [[Linux进程与负载/Linux进程与负载]] | free -m 看 swap |

**下一步**：完成 Linux存储 后可以选择：
- 🎯 **第 4 波 ②** [[Linux网络/]]（05.18 共 1 PDF）—— ip / ss / nmcli / DNS / ping
- 🎯 **第 4 波 ③** [[Linux防火墙/]]（06.10 共 1 PDF）—— firewalld / zone / rich-rules