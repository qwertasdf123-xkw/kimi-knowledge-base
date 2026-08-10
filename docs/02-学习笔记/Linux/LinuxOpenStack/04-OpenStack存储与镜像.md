---
title: OpenStack 存储与镜像：Cinder / Swift / Glance + 业务案例（电商云平台）
desc: 以《OpenStack管理》PDF Cinder/Swift/Glance 章节 + openstack-deploy/dual 部署项目 + 毕业论文 thesis 6 章为基础，把 Cinder（块存储）/Swift（对象存储）/Glance（镜像）三大存储服务的架构、后端选择、运维实战串成深度笔记，并以《基于 OpenStack 的电商云平台》论文作为业务案例完整展示 OpenStack 在生产中的落地形态。
type: 笔记
module: LinuxOpenStack
pdf: OpenStack管理.pdf Cinder/Swift/Glance 章节 + 基于OpenStack的电商云平台的设计与实现.pdf
pdf_size: PDF ~50 页存储章节 + 58 页论文 + 6 章 thesis + 70K kolla-ansible + KEY-CODE-EXAMPLES §2
scope: Glance/Cinder/Swift 三类存储 + 后端选择 + Cinder 多后端 + 业务案例（ECShop 部署）+ 毕业论文 thesis 整合
status: 进行中
---

# OpenStack 存储与镜像：Cinder / Swift / Glance + 业务案例

> **一句话心智模型**：OpenStack 有三种存储服务分别管三类数据——**Glance** 管"系统盘模板"（镜像，VM 启动用）、**Cinder** 管"持久块存储"（卷，独立于 VM 生命周期）、**Swift** 管"对象存储"（大文件/备份，REST 风格）。三者定位完全不同，但都可对接 LVM / Ceph / NFS / 远端 HTTP 等多种后端。
>
> **本章范围**：Glance/Cinder/Swift 三类存储 + 后端选择 + Cinder 多后端 + 业务案例（电商云平台 ECShop 部署完整流程）。Glance 基础详见 [[01-OpenStack核心概念#§2 Glance]]。

## 目录

- [[#§0 心智模型：三种存储服务管三类数据]]
- [[#§1 Glance 补充（存储视角）]]
- [[#§2 Cinder：块存储]]
- [[#§3 Cinder 架构与组件]]
- [[#§4 Cinder 后端实战：LVM / Ceph / NFS / 第三方]]
- [[#§5 Cinder 多后端配置]]
- [[#§6 Cinder 卷类型与 QoS]]
- [[#§7 Swift：对象存储]]
- [[#§8 Swift 架构与 Ring]]
- [[#§9 业务案例：电商云平台（ECShop）]]
- [[#§10 业务案例部署架构]]
- [[#§11 ECShop 部署代码解析]]
- [[#§12 毕业论文 thesis 知识地图]]
- [[#§13 命令速查]]
- [[#§14 故障排查入口]]
- [[#§15 与已有 vault 模块的链接]]

---

## §0 心智模型：三种存储服务管三类数据

OpenStack 三种存储的定位完全不同，混用会出大问题：

```mermaid
graph TB
  subgraph Glance["Glance 镜像（系统盘模板）"]
    G1[CentOS 8 qcow2]
    G2[Ubuntu 22.04 raw]
    G3[Windows 2022 vhd]
  end

  subgraph Cinder["Cinder 卷（持久块设备）"]
    C1[数据库卷<br/>attached 到 VM]
    C2[日志卷<br/>独立于 VM]
    C3[应用卷<br/>挂载到多 VM]
  end

  subgraph Swift["Swift 对象（大文件）"]
    S1[VM 备份<br/>tar.xz]
    S2[用户上传文件<br/>图片/视频]
    S3[Glance 镜像后端]
  end

  VM[VM 内核] --> C1
  VM --> C2
  C1 -.独立于 VM 生命周期.-> Cinder
  Swift -.可选后端.-> Glance
```

### 0.1 三类存储对比

| 维度 | Glance 镜像 | Cinder 卷 | Swift 对象 |
|------|------------|-----------|------------|
| **数据特征** | 只读模板 | 读写块设备 | 读写大文件 |
| **访问方式** | VM 启动时下载 | 块级（iSCSI/Ceph/NFS） | HTTP REST |
| **生命周期** | 与镜像定义独立 | 独立于 VM | 永久 |
| **典型用途** | 系统盘模板 | 数据库盘/数据盘 | 备份/镜像仓库 |
| **典型后端** | 本地文件/Swift/Ceph | LVM/Ceph RBD/NFS | 多盘分布式 |
| **VM 依赖** | 启动时需要 | 可选 attach | 弱依赖 |
| **删除时机** | 引用计数 = 0 | 用户显式 detach + delete | 用户显式 delete |
| **容量** | GB 级（系统盘） | GB~TB 级 | TB~PB 级 |
| **性能** | 一次性下载 | 持续 IOPS | 吞吐优先 |

### 0.2 什么时候用哪种

- **Glance**：每个 OS 版本一个镜像（centos/ubuntu/windows），VM 启动的"地基"
- **Cinder**：数据库盘、日志盘、需要持久化的应用数据盘
- **Swift**：备份归档（VM 快照/系统备份）、静态资源（图片/视频）、Glance 多后端

**混用陷阱**：

- ❌ 把 Swift 当 Cinder 用（需要块级 IO，Swift 是 HTTP 文件接口）
- ❌ 把 Cinder 当 Glance 用（卷不能直接启动 VM）
- ❌ 把 Glance 当 Swift 用（镜像元数据优化不是对象存储）

---

## §1 Glance 补充（存储视角）

[[01-OpenStack核心概念#§2 Glance]] 已经覆盖 Glance 基础。本节聚焦"存储视角"的补充：

### 1.1 Glance 后端选型决策树

```mermaid
graph TD
  A[选择 Glance 后端] --> B{单节点测试?}
  B -->|是| C[本地文件系统<br/>简单]
  B -->|否| D{有 Ceph?}
  D -->|是| E[Ceph RBD<br/>共享 + 高可用]
  D -->|否| F{有 Swift?}
  F -->|是| G[Swift<br/>OpenStack 全栈]
  F -->|否| H[本地文件系统<br/>+ NFS 备份]

  C --> I[/var/lib/glance/images/]
  E --> J[images pool]
  G --> K[glance container]
  H --> L[/var/lib/glance/images/<br/>+ 每日 rsync 到 NFS]
```

### 1.2 多后端实战

```bash
# /etc/glance/glance-api.conf
[DEFAULT]
enabled_backends = fs:file,swift:swift,rbd:rbd

[glance_store]
default_backend = rbd

[fs]
filesystem_store_datadir = /var/lib/glance/images/

[swift]
swift_store_auth_address = http://controller:5000/v3
swift_store_user = service:glance
swift_store_key = <password>
swift_store_container = glance

[rbd]
rbd_store_pool = images
rbd_store_user = glance
rbd_store_chunk_size = 8
```

```bash
# 上传到不同后端
glance image-create --name centos-fs --file centos.qcow2 \
  --disk-format qcow2 --container-format bare --store fs

glance image-create --name centos-rbd --file centos.qcow2 \
  --disk-format qcow2 --container-format bare --store rbd
```

### 1.3 镜像缓存优化

```ini
# glance-api.conf
[image_cache]
image_cache_dir = /var/lib/glance/image-cache/
image_cache_max_size = 100  # GB
image_cache_stall_time = 86400  # 秒（一天未访问则清除）
```

Nova compute 节点本身就有镜像缓存（`/var/lib/nova/instances/_base/`），Glance 缓存主要给 glance-api 节点用。

### 1.4 Glance 私有镜像共享

```bash
# 共享给另一个 project
glance member-create --member-id <target-project-id> <image-id>

# 看共享列表
glance member-list --image-id <image-id>

# 撤销
glance member-delete <member-id> <image-id>
```

---

## §2 Cinder：块存储

### 2.1 Cinder 是什么

**Cinder = OpenStack 的块存储服务**。它管的是"持久卷"——独立于 VM 生命周期的块设备。

类比：VM 是"主机"，Cinder 卷是"外接硬盘"。

### 2.2 Cinder 管的资源

| 资源 | 说明 |
|------|------|
| **volume** | 块设备（GB~TB） |
| **volume type** | 卷规格（如 `ssd-lvm` / `ceph-rbd` / `nfs`） |
| **snapshot** | 卷快照（基于 LVM snapshot / Ceph snapshot / RBD snap） |
| **backup** | 卷备份（存到 Swift / Ceph / NFS） |
| **consistency group** | 一致性组（一组卷的快照同时打） |
| **qos** | QoS 策略（IOPS 限制） |
| **transfer** | 卷在不同 project 间转移 |

### 2.3 Cinder 与 VM 的关系

```mermaid
graph LR
  VM[VM 内核] -->|看到 /dev/vdb| TAP[tap 设备]
  TAP -->|libvirt attach| LIBV[libvirt]
  LIBV -->|iSCSI / RBD / NFS| CV[Cinder Volume]
  CV --> LVM[LVM Volume Group<br/>cinder-volumes]
  CV --> CEPH[Ceph RBD pool]
  CV --> NFS[NFS share]
```

**关键点**：

1. Cinder 卷不依赖 VM——VM 删除后卷还在
2. Cinder 卷可以 attach 到不同 VM（先 detach 再 attach）
3. Cinder 卷的 IO 性能受后端限制（LVM IOPS < Ceph RBD < NVMe-oF）

### 2.4 Cinder 卷的生命周期

```mermaid
stateDiagram-v2
  [*] --> Creating: openstack volume create
  Creating --> Available: 创建成功
  Available --> Attaching: openstack server add volume
  Attaching --> InUse: 已挂载到 VM
  InUse --> Detaching: openstack server remove volume
  Detaching --> Available: 卸载完成
  Available --> Deleting: openstack volume delete
  Deleting --> [*]
  Available --> Error: 后端错误
  Error --> Available: 重置 (admin reset-state)
```

---

## §3 Cinder 架构与组件

### 3.1 Cinder 服务进程

| 进程 | 职责 | 默认端口 | 部署位置 |
|------|------|----------|----------|
| **cinder-api** | 接收 REST 请求，校验参数 | 8776 | 控制节点 |
| **cinder-scheduler** | 卷调度（选 cinder-volume 节点） | 无 | 控制节点 |
| **cinder-volume** | 实际管 LVM/Ceph/NFS 后端 | 无 | 存储节点 |
| **cinder-backup** | 备份服务（卷 → Swift/Ceph/NFS） | 无 | 控制节点（可选） |

### 3.2 Cinder 配置文件

```ini
# /etc/cinder/cinder.conf
[DEFAULT]
enabled_backends = lvm-backend,ceph-backend
transport_url = rabbit://openstack:password@controller:5672
auth_strategy = keystone

[database]
connection = mysql+pymysql://cinder:password@controller/cinder

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000

[lvm-backend]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
volume_backend_name = LVM
iscsi_protocol = iscsi
iscsi_helper = lioadm

[ceph-backend]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
rbd_pool = cinder-volumes
rbd_user = cinder
rbd_secret_uuid = <secret-uuid>
volume_backend_name = CEPH
```

### 3.3 Cinder 调度

Cinder scheduler 类似 Nova scheduler——**filter + weigher**：

```ini
[cinder-scheduler]
scheduler_driver = cinder.scheduler.filter_scheduler.FilterScheduler
scheduler_default_filters = CapacityFilter,AvailabilityZoneFilter,CapabilitiesFilter
scheduler_default_weighers = CapacityWeigher,AllocatedCapacityWeigher
```

| Filter | 作用 |
|--------|------|
| `CapacityFilter` | 容量够不够 |
| `AvailabilityZoneFilter` | AZ 匹配 |
| `CapabilitiesFilter` | 卷 type 与 backend 能力匹配 |
| `DifferentBackendFilter` | 强制不同 backend |

---

## §4 Cinder 后端实战：LVM / Ceph / NFS / 第三方

### 4.1 LVM 后端（最常见入门级）

**准备物理卷**：

```bash
# 创建 LVM 卷组
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

# 配置 cinder.conf
[lvm-backend]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
volume_backend_name = LVM
```

**优**：

- 简单，零依赖
- 性能稳定（本地磁盘）

**劣**：

- 单点：LVM 在一台节点上，节点坏 → 该节点所有卷不可用
- 无副本：LVM 损坏 = 数据丢失
- 无 HA：cinder-volume 节点故障 = 该节点卷不可用

**适用**：开发测试、单节点实验。

### 4.2 Ceph RBD 后端（生产推荐）

**准备 Ceph 集群**（假设已有）：

```bash
# 创建 pool
ceph osd pool create cinder-volumes 128

# 创建 cinder 用户
ceph auth get-or-create client.cinder \
  mon 'allow r' \
  osd 'allow class-read object_prefix rbd_children, allow rwx pool=cinder-volumes, allow rx pool=images'
```

**配置 cinder.conf**：

```ini
[ceph-backend]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
rbd_pool = cinder-volumes
rbd_user = cinder
rbd_secret_uuid = <secret-uuid>
rbd_ceph_conf = /etc/ceph/ceph.conf
volume_backend_name = CEPH
```

**Nova 也要配置**（让 Nova 能 attach RBD）：

```ini
# nova.conf（所有 compute 节点）
[libvirt]
rbd_user = cinder
rbd_secret_uuid = <secret-uuid>
images_type = rbd
images_rbd_pool = images
```

**优**：

- 多副本：高可用
- 共享：多 compute 节点可同时 attach
- 快照便宜

**劣**：

- 需部署 Ceph（运维成本）
- 性能略低于本地 LVM（网络 IO）

**适用**：生产环境首选。

### 4.3 NFS 后端（跨节点共享）

```ini
[nfs-backend]
volume_driver = cinder.volume.drivers.nfs.NfsDriver
nfs_shares_config = /etc/cinder/nfs_shares
nfs_mount_point_base = $state_path/mnt
volume_backend_name = NFS
```

```ini
# /etc/cinder/nfs_shares
192.168.100.50:/srv/cinder  # NFS 服务器地址
```

**优**：跨节点共享简单

**劣**：

- 性能差（NFS 协议栈）
- 单点（NFS 服务器）

**适用**：少量跨节点卷。

### 4.4 第三方后端（生产级商业方案）

| 厂商 | 驱动 | 特点 |
|------|------|------|
| NetApp | `cinder.volume.drivers.netapp.*` | 企业级 NAS |
| Dell EMC | `cinder.volume.drivers.emc.*` | VMAX/VNX |
| 华为 | `cinder.volume.drivers.huawei.*` | OceanStor（参考 [[huaweistorage]]） |
| IBM | `cinder.volume.drivers.ibm.*` | Storwize |
| Pure Storage | `cinder.volume.drivers.pure.*` | FlashArray |

**适用**：企业级存储整合。

---

## §5 Cinder 多后端配置

### 5.1 启用多后端

```ini
# cinder.conf
[DEFAULT]
enabled_backends = lvm-backend,ceph-backend,nfs-backend
```

### 5.2 创建 Volume Type 关联后端

```bash
# 创建 type
openstack volume type create ssd-lvm
openstack volume type set ssd-lvm --volume-backend-name LVM

openstack volume type create ceph-ssd
openstack volume type set ceph-ssd --volume-backend-name CEPH

openstack volume type create nfs-backup
openstack volume type set nfs-backup --volume-backend-name NFS
```

### 5.3 用 type 创建卷

```bash
# 创建 LVM 后端卷
openstack volume create --size 100 --type ssd-lvm db-vol

# 创建 Ceph 后端卷（共享 / 副本）
openstack volume create --size 100 --type ceph-ssd shared-vol

# 创建 NFS 后端卷（跨节点）
openstack volume create --size 100 --type nfs-backup backup-vol
```

### 5.4 卷类型多 capability

```bash
# 给 type 加额外能力
openstack volume type set ssd-lvm \
  --property volume_backend_name=LVM \
  --property capabilities:thin_provisioning=true \
  --property capabilities:compression=true
```

这样 scheduler 在 CapabilitiesFilter 阶段会更精准匹配。

---

## §6 Cinder 卷类型与 QoS

### 6.1 QoS 策略

```bash
# 创建 QoS
openstack volume qos create high-iops \
  --consumer front-end \
  --property read_iops_sec=10000 \
  --property write_iops_sec=5000

# 关联到 type
openstack volume type set ssd-lvm --qos high-iops
```

### 6.2 加密卷

```bash
# 启用 Cinder 加密
[cinder]
key_manager_backend = barbican  # 或 vault

# 创建加密卷
openstack volume create --size 50 --type encrypted-vol encrypted-vol
```

### 6.3 薄置备（Thin Provisioning）

```ini
[lvm-backend]
# 启用薄置备
[lvm]
lvm_type = thin
thin_lvm_metadevices = /dev/sdc
```

```bash
# 创建薄置备卷
openstack volume create --size 1000 --type thin-lvm big-vol
# 实际只占用了真实数据大小
```

### 6.4 卷快照与一致性

```bash
# 打快照（瞬时）
openstack volume snapshot create --volume <vol-id> snap1

# 从快照恢复
openstack volume create --snapshot <snap-id> --size 100 restored-vol

# 备份到 Swift
openstack volume backup create --name vol-backup <vol-id>
```

**一致性快照**（跨卷同时打）：

```bash
# 一致性组（consistency group）
openstack volume group create db-group
openstack volume group add volume db-group db-vol
openstack volume group add volume db-group log-vol

# 同时打快照
openstack volume group snapshot create --group db-group cg-snap
```

---

## §7 Swift：对象存储

### 7.1 Swift 是什么

**Swift = OpenStack 的对象存储服务**。它管的是"大文件对象"——通过 HTTP REST 访问，TB~PB 级容量。

类比：Swift 是 OpenStack 自带的"MinIO"。

### 7.2 Swift 管的资源

| 资源 | 说明 |
|------|------|
| **account** | 租户账户（账号级容器） |
| **container** | 容器（类似 S3 bucket） |
| **object** | 对象（实际文件） |

URL 结构：

```
http://swift-proxy:8080/v1/{account}/{container}/{object}
```

### 7.3 Swift 与 S3 的关系

| 维度 | Swift | AWS S3 |
|------|-------|--------|
| 接口 | Swift 原生 REST + S3 兼容（中间件） | S3 REST |
| 部署 | 自建 | AWS 托管 |
| 容量 | 无限制（加节点） | 无限制（云端） |
| 性能 | 一般 | 优 |
| 成本 | 自建硬件 | 按量付费 |

**S3 兼容**：可通过 [starling](https://github.com/openstack/swift3) 中间件让 Swift 支持 S3 API。

### 7.4 Swift 典型用途

1. **VM 备份归档**（cinder-backup 的目标）
2. **Glance 多后端**（[[#§1 Glance 补充]]）
3. **静态资源**（图片/视频/用户上传文件）
4. **大文件分发**（软件包/镜像包）

### 7.5 Swift 关键命令

```bash
# 上传
swift upload my-container /path/to/big-file.iso

# 下载
swift download my-container big-file.iso

# 列容器
swift list

# 列对象
swift list my-container

# 临时 URL（分享）
swift tempurl GET 3600 /v1/my-account/my-container/file.iso
```

---

## §8 Swift 架构与 Ring

### 8.1 Swift 三大组件

```mermaid
graph TB
  P[Proxy Server<br/>接收 REST 请求]
  A[Account Server<br/>account 数据库]
  C[Container Server<br/>container 数据库]
  O[Object Server<br/>实际文件]

  U[用户/客户端] --> P
  P --> A
  P --> C
  P --> O
  A --> RING1[(Account Ring<br/>一致性哈希)]
  C --> RING2[(Container Ring)]
  O --> RING3[(Object Ring)]
```

### 8.2 Ring 是什么

**Ring = Swift 的一致性哈希环**。它决定了数据放在哪个节点、几副本。

```bash
# 创建 ring
swift-ring-builder account.builder create 18 3 1
swift-ring-builder container.builder create 18 3 1
swift-ring-builder object.builder create 18 3 1

# 加 zone
swift-ring-builder account.builder add --zone 1 --ip 192.168.56.10 --port 6002 --device sdb --weight 100

# 平衡
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

# 复制 ring 到所有节点
cp *.ring.gz /etc/swift/
```

### 8.3 副本策略

| 副本数 | 适用 |
|--------|------|
| 1 | 临时数据（丢了无所谓） |
| 2 | 中等重要性 |
| **3（默认）** | 生产标准 |
| 4+ | 极重要数据 |

### 8.4 Swift 节点角色

```mermaid
graph LR
  subgraph Cluster["Swift 集群（5 节点示例）"]
    N1[Proxy Node<br/>所有读写入口]
    N2[Storage Node 1<br/>account+container+object]
    N3[Storage Node 2]
    N4[Storage Node 3]
    N5[Storage Node 4]
    N6[Storage Node 5]
  end
```

**最小部署**：3 节点（1 proxy + 2 storage），但生产推荐 5+。

---

## §9 业务案例：电商云平台（ECShop）

### 9.1 业务背景

**论文题目**：基于 OpenStack 的电商云平台的设计与实现
**来源**：`E:\QQ下载\基于OpenStack的电商云平台的设计与实现-格式转换.pdf`（58 页）
**thesis**：`E:\openstack-deploy\thesis\` 6 章（chapter1~chapter6）

### 9.2 业务目标

构建一个基于 OpenStack 的私有云平台，支撑一个小型电商应用（ECShop）的部署：

- **可扩展**：按业务增长添加计算/存储节点
- **高可用**：OpenStack 控制平面 + 数据库双活
- **易运维**：Web 界面（Horizon）+ 命令行（CLI）

### 9.3 业务用例

```mermaid
graph LR
  USER[用户访问] -->|HTTPS| WEB[ECShop<br/>Web 服务器]
  WEB -->|MySQL| DB[ECShop 数据库]
  WEB -->|读/写图片| IMG[图片存储]

  subgraph OpenStack["OpenStack 私有云"]
    VM_WEB[VM: ECShop Web]
    VM_DB[VM: MySQL]
    VM_IMG[VM: 图片存储]
  end

  WEB -.部署在.-> VM_WEB
  DB -.部署在.-> VM_DB
  IMG -.部署在.-> VM_IMG
```

### 9.4 关键技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| 虚拟化层 | OpenStack Bobcat 2023.2 | 最新稳定版 |
| 部署工具 | kolla-ansible | 容器化，幂等 |
| VM 操作系统 | CentOS Stream 9 | 与 OpenStack 兼容 |
| 数据库 | MySQL 8.0 | ECShop 默认 |
| Web 服务器 | Apache + PHP | ECShop 默认 |
| 应用 | ECShop 2.7.3 | 开源电商 |
| 网络 | OVN | 性能优 |

### 9.5 ECShop 部署流程

```mermaid
sequenceDiagram
  autonumber
  participant U as 用户
  participant H as Horizon
  participant N as Nova
  participant NE as Neutron
  participant C as Cinder
  participant CO as nova-compute
  participant EC as ECShop

  U->>H: 创建 Web VM
  H->>N: POST /servers {flavor: m1.medium, image: centos}
  N->>NE: 配网卡 + 安全组
  N->>C: 创建 100GB 卷 (DB)
  N->>CO: spawn
  CO-->>N: VM ACTIVE
  C-->>N: 卷 AVAILABLE

  U->>H: 创建 DB VM + attach DB 卷
  H->>N: POST /servers {flavor: m1.small, image: centos}
  N->>C: attach DB 卷到 DB VM
  CO-->>N: DB VM ACTIVE

  U->>H: 装 ECShop
  H->>N: SSH 到 Web VM
  U->>EC: 部署 + 配 DB 连接
  U->>EC: 测试下单流程
```

详见 [[#§11 ECShop 部署代码解析]]。

### 9.6 业务案例 vs 其他章节的关系

| 章节 | 业务案例关联 |
|------|--------------|
| [[01-OpenStack核心概念]] | Nova/Glance 真实创建 VM |
| [[02-OpenStack网络]] | Neutron 配 Web/DB 网络 + 浮动 IP |
| [[03-OpenStack认证与多租户]] | admin user 部署 ECShop |
| [[05-OpenStack安装配置手册]] | 部署 OpenStack 的全过程 |
| [[06-OpenStack故障排查与运维]] | 部署 + 运行期排错 |

**业务案例 = 把 01~05 章串起来的"实战示例"**。

---

## §10 业务案例部署架构

### 10.1 网络架构

参考 `E:\openstack-deploy-dual\NETWORK-ARCHITECTURE.md`：

```mermaid
graph TB
  subgraph Host["宿主机 Windows 11"]
    VMnet1[VMnet1<br/>管理网 192.168.56.0/24]
    VMnet2[VMnet2<br/>外部网 192.168.100.0/24]
    VMnet8[VMnet8<br/>上网 192.168.200.0/24]
  end

  subgraph Controller["Controller1 192.168.56.10 / 192.168.100.10"]
    K[Keystone]
    N[Nova]
    NE[Neutron]
    GL[Glance]
    CI[Cinder]
    H[Horizon]
    OVN_C[ovn-controller]
  end

  subgraph Compute["Compute1 192.168.56.20 / 192.168.100.20"]
    N_C[nova-compute]
    OVS[OVS / OVN chassis]
  end

  subgraph Storage["Cinder Volume 192.168.56.30"]
    LVM[cinder-volume<br/>LVM backend]
  end

  VMnet1 --- Controller
  VMnet1 --- Compute
  VMnet1 --- Storage
  VMnet2 --- Controller
  VMnet2 --- Compute
  VMnet8 --- Controller
```

### 10.2 ECShop 部署的网络拓扑

```mermaid
graph TB
  subgraph Provider["Provider Network (public-net)"]
    FIP_WEB[Web 浮动 IP<br/>192.168.100.20]
  end

  subgraph Tenant["Tenant Network (private-net)"]
    WEB_VM[Web VM<br/>10.0.0.10]
    DB_VM[DB VM<br/>10.0.0.11]
  end

  R[Router<br/>192.168.100.1]
  USER[Internet 用户] -->|HTTPS| FIP_WEB
  FIP_WEB --> R
  R --> WEB_VM
  WEB_VM -->|MySQL 3306| DB_VM
```

### 10.3 部署脚本全景

参考 `E:\openstack-deploy-dual\` 的 7 个脚本（详见 [[05-OpenStack安装配置手册]]）：

| 脚本 | 职责 |
|------|------|
| `01-vmware-network-config.md` | 配 VMware 三网段 |
| `02-create-vms.md` | 克隆 VM 模板 |
| `03-system-init.sh` | 系统初始化（IP/Docker/cgroup） |
| `04-kolla-ansible-deploy.sh` | kolla-ansible 部署 OpenStack |
| `05-create-resources.sh` | 创建 OpenStack 资源（网络/卷/镜像） |
| `06-pxe-setup.sh` | PXE 自动装机（可选） |
| `07-deploy-ecshop.sh` | **部署 ECShop（业务）** |

---

## §11 ECShop 部署代码解析

来源：`E:\openstack-deploy-dual\KEY-CODE-EXAMPLES.md §2`

### 11.1 cloud-init 部署

```yaml
# cloud-init 配置（创建 VM 时注入）
#openstack server create ... --user-data ecshop-init.yaml

#cloud-config
packages:
  - httpd
  - mariadb-server
  - php
  - php-mysqlnd
  - php-mbstring
  - php-gd

runcmd:
  - systemctl enable --now httpd mariadb
  - mysql_secure_installation
  - cd /var/www/html && wget https://github.com/ECShop/ECShop/archive/v2.7.3.tar.gz
  - tar xf v2.7.3.tar.gz && mv ECShop-2.7.3 ecshop
  - chown -R apache:apache /var/www/html/ecshop
  - firewall-cmd --permanent --add-service=http
  - firewall-cmd --reload
```

### 11.2 离线 yum 仓库（无网络环境）

```bash
# 在内网服务器（能上网）准备 yum 仓库
yum install -y createrepo
mkdir -p /repo/centos9
# 把 CentOS-Stream-9-dvd.iso 挂载
mount -o loop CentOS-Stream-9-latest-x86_64-dvd.iso /mnt
cp -a /mnt/* /repo/centos9/
createrepo /repo/centos9

# 在 ECShop VM 配 yum 源
cat > /etc/yum.repos.d/local.repo <<'EOF'
[local]
name=Local Repo
baseurl=http://192.168.56.100/repo/centos9
enabled=1
gpgcheck=0
EOF

yum install -y httpd php php-mysqlnd  # 离线安装
```

### 11.3 CentOS 7 实例初始化（手动快速修复）

```bash
# === 1. SELinux ===
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# === 2. 防火墙 ===
firewall-cmd --permanent --add-service={http,https,mysql}
firewall-cmd --reload

# === 3. PHP 时区 ===
sed -i 's/;date.timezone =/date.timezone = Asia\/Shanghai/' /etc/php.ini

# === 4. 网站目录权限 ===
chown -R apache:apache /var/www/html/ecshop

# === 5. 安装 LAMP + 扩展（离线 yum 源） ===
yum install -y httpd mariadb-server php php-mysqlnd php-mbstring php-gd

# === 6. 启动服务 + 创建数据库用户 ===
systemctl enable --now httpd mariadb
mysql -e "CREATE DATABASE ecshop; CREATE USER 'ecshop'@'localhost' IDENTIFIED BY 'pwd'; GRANT ALL ON ecshop.* TO 'ecshop'@'localhost'; FLUSH PRIVILEGES;"

# === 7. php-mbstring 缺失时从 vault 下载 ===
# 如果 yum 仓库没有，从官网下载 rpm 包手动安装
rpm -ivh php-mbstring-7.4.30-1.el8.x86_64.rpm
```

### 11.4 ECShop 数据库初始化

```bash
# 下载 ECShop 安装包到 DB VM
wget https://github.com/ECShop/ECShop/archive/v2.7.3.tar.gz
tar xf v2.7.3.tar.gz

# 创建数据库结构
mysql ecshop < /var/www/html/ecshop/install/data/db_structure.sql
mysql ecshop < /var/www/html/ecshop/install/data/db_data.sql

# 配置 ECShop 数据库连接
cat > /var/www/html/ecshop/data/config.php <<'EOF'
<?php
$db_host = "10.0.0.11";
$db_user = "ecshop";
$db_pass = "pwd";
$db_name = "ecshop";
?>
EOF
```

### 11.5 ECShop 上线测试

```bash
# 1. 浏览器访问（Web VM 浮动 IP）
http://192.168.100.20/ecshop/install/

# 2. 跟着向导配置
# 3. 测试下单
# 4. 看日志
tail -f /var/log/httpd/access_log
```

---

## §12 毕业论文 thesis 知识地图

来源：`E:\openstack-deploy\thesis\` 6 章

### 12.1 chapter1 绪论（≈ 8 页）

- 研究背景：云计算 + OpenStack 发展现状
- 研究意义：私有云对中小企业的价值
- 研究内容：基于 OpenStack 搭建电商云平台
- 论文结构：6 章

### 12.2 chapter2 理论基础（≈ 10 页）

- 云计算三层架构（IaaS/PaaS/SaaS）
- OpenStack 7 大服务总览
- 关键技术：虚拟化（KVM）、网络（OVS）、存储（CEPH/LVM）
- 容器化部署：Docker + Ansible

### 12.3 chapter3 需求分析与设计（≈ 12 页）

- 业务需求：电商平台 + 高可用 + 可扩展
- 性能需求：100 并发 / 1000 PV / 99.9% 可用
- 架构设计：3 控制节点 + N 计算节点
- 网络设计：管理网 + 业务网 + 存储网
- 存储设计：本地 LVM + Ceph（未来）

### 12.4 chapter4 系统实现（≈ 15 页，核心章）

- 部署工具：kolla-ansible
- 部署过程：4 阶段（precheck → deploy → post-deploy）
- 关键代码：详见 `E:\openstack-deploy-dual\KEY-CODE-EXAMPLES.md`
- 业务部署：ECShop 部署脚本（详见 [[#§11 ECShop 部署代码解析]]）

### 12.5 chapter5 测试验证（≈ 8 页）

- 功能测试：VM 创建/网络/卷/快照
- 性能测试：100 并发下单 / 1000 PV
- HA 测试：拔 controller1 网线，看是否切换到 controller2/3
- 结论：满足需求

### 12.6 chapter6 总结与展望（≈ 3 页）

- 论文总结
- 不足：Ceph 未集成 / Octavia LB 未集成
- 展望：Kubernetes on OpenStack / 多 region

---

## §13 命令速查

### 13.1 Glance 命令（补充）

```bash
# 列镜像（含共享）
glance image-list --visibility shared

# 看镜像位置（多后端时）
glance image-show <image-id> | grep -A5 locations

# 镜像大小
glance image-show <image-id> | grep size

# 上传到指定后端
glance image-create --name <name> --file <file> --store <backend>
```

### 13.2 Cinder 命令

```bash
# 列卷
openstack volume list

# 创建卷
openstack volume create --size 100 --type ssd-lvm my-vol

# attach 到 VM
openstack server add volume <vm-id> <vol-id>

# detach
openstack server remove volume <vm-id> <vol-id>

# 快照
openstack volume snapshot create --volume <vol-id> snap1

# 备份
openstack volume backup create --name bk <vol-id>

# 列 type
openstack volume type list
openstack volume type show ssd-lvm

# 列 QoS
openstack volume qos list

# 看后端使用情况
cinder get-pools
```

### 13.3 Swift 命令

```bash
# 列容器
swift list

# 上传
swift upload my-container big-file.iso

# 下载
swift download my-container big-file.iso

# 临时 URL
swift tempurl GET 3600 /v1/my-account/my-container/file.iso

# 看统计
swift stat
swift stat my-container
```

### 13.4 ECShop 部署命令

```bash
# 在 OpenStack 上创建 Web VM（cloud-init 自动装 ECShop）
openstack server create ecshop-web \
  --flavor m1.medium \
  --image centos-stream-9 \
  --network private-net \
  --security-group default \
  --volume vol-db-100g \
  --user-data ecshop-init.yaml

# 创建浮动 IP
openstack floating ip create public-net
openstack floating ip set --port <web-vm-port> <fip-id>

# 浏览器访问
http://<floating-ip>/ecshop/install/
```

---

## §14 故障排查入口

详见 [[06-OpenStack故障排查与运维#§3 存储故障]]。本章列最常见入口：

| 症状 | 第一检查 | 命令 |
|------|----------|------|
| 卷创建失败 | cinder-volume log | `tail -f /var/log/cinder/cinder-volume.log` |
| 卷 attach 失败 | nova-compute + cinder-volume | `openstack volume show <vol-id>` 看 status |
| 卷 IO 慢 | 后端性能 | `iostat -x /dev/sdb` |
| Swift 上传慢 | Proxy Server 性能 | `swift stat` |
| 镜像上传失败 | glance-api + 后端 | `glance image-create --debug` |
| LVM 损坏 | pv/vg/lv 状态 | `pvs; vgs; lvs` |
| Ceph 不可达 | ceph health | `ceph health` |
| ECShop 打不开 | Web VM 内 + 安全组 | `curl http://<web-vm-ip>/` |

---

## §15 与已有 vault 模块的链接

- [[Linux存储]] — Cinder LVM 后端的物理卷基础
- [[LinuxRAID]] — Cinder 第三方后端可对接 RAID 控制器
- [[Linux网络]] — Cinder 流量走 Neutron 网络
- [[LinuxKVM]] — Cinder 卷通过 libvirt attach 到 VM
- [[LinuxShell]] — 部署脚本基于 bash + ansible
- [[Linux防火墙]] — ECShop 端口 80/443/MySQL 3306
- [[Linux服务与SSH]] — ECShop VM 通过 SSH 远程管理
- [[01-OpenStack核心概念#§2 Glance]] — Glance 基础
- [[02-OpenStack网络#§11 安全组]] — ECShop 安全组规则
- [[03-OpenStack认证与多租户]] — admin user 部署 ECShop
- [[05-OpenStack安装配置手册]] — OpenStack 部署 + ECShop 部署
- [[06-OpenStack故障排查与运维]] — 部署期 + 运行期排错
- [[00-OpenStack学习路线#§10 复习 Checklist]] — 业务层复习要点

---

## §16 高级主题

### 16.1 Cinder 卷备份策略

**3-2-1 备份原则**：

- **3 份副本**：生产卷 + 本地备份 + 异地备份
- **2 种介质**：LVM（本地）+ Ceph（共享）/ Swift（异地）
- **1 份异地**：跨 region / 跨数据中心

```bash
# 完整备份链路
openstack volume backup create --name full-bk-<date> <vol-id>
# 备份默认存到 Swift

# 异地复制（手动）
swift download my-container full-bk-<date>
scp full-bk-<date> remote-server:/backup/

# 自动备份脚本（crontab）
0 2 * * * /usr/local/bin/cinder-backup-all.sh
```

```bash
#!/bin/bash
# /usr/local/bin/cinder-backup-all.sh
# 备份所有重要卷
for vol in $(openstack volume list --status in-use -c ID -f value); do
  openstack volume backup create --force --name "auto-bk-$(date +%Y%m%d)-${vol}" "${vol}"
done
```

### 16.2 Cinder 与 Ceph 整合

参考 [[Linux存储]] 中 Ceph 部分。整合后 Cinder 可以：

- 用 Ceph RBD 当卷后端
- 用 Ceph RADOSGW 当 Swift 替代
- Glance 镜像存到 Ceph RBD

```ini
# cinder.conf 启用 RBD
[ceph-backend]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
rbd_pool = cinder-volumes
rbd_user = cinder
rbd_secret_uuid = <uuid>
volume_backend_name = CEPH

# glance-api.conf 启用 RBD
[glance_store]
default_backend = rbd
stores = rbd
rbd_store_pool = images
rbd_store_user = glance
```

### 16.3 Cinder 卷迁移

**跨后端迁移**（LVM → Ceph）：

```bash
# 1. 创建新类型（目标后端）
openstack volume type create ceph-mig

# 2. 用 cinder migrate 命令
cinder migrate <vol-id> <new-backend> --type ceph-mig

# 3. 监控进度
openstack volume show <vol-id> | grep migration_status
```

**跨可用区迁移**（cinder AZ）：

```bash
cinder migrate <vol-id> <new-backend>@<new-az>
```

### 16.4 Cinder 卷一致性组（Consistency Group）

一组卷同时打快照（适合数据库主从）：

```bash
# 创建一致性组
openstack volume group create db-cg
openstack volume group add volume db-cg db-master-vol
openstack volume group add volume db-cg db-slave-vol

# 一致性快照
openstack volume group snapshot create --group db-cg cg-snap-1

# 从一致性快照恢复（必须新建卷）
openstack volume create --snapshot cg-snap-1 --size 100 db-master-restore
```

### 16.5 Cinder 加密卷（Barbican Key Manager）

```ini
# cinder.conf
[key_manager]
backend = barbican
api_class = castellan.key_manager.barbican_key_manager.BarbicanKeyManager

# glance-api.conf
[key_manager]
backend = barbican
```

```bash
# 创建加密卷
openstack volume type create encrypted-vol \
  --encryption-provider nova.volume.encryptors.luks.LuksEncryptor \
  --encryption-cipher aes-xts-plain64 \
  --encryption-key-size 256 \
  --encryption-control-location front-end
```

### 16.6 Swift 多 region 部署

```mermaid
graph LR
  subgraph RegionA["Region A（上海）"]
    PA[Swift Proxy A]
    SA1[Storage A1]
    SA2[Storage A2]
    SA3[Storage A3]
  end

  subgraph RegionB["Region B（北京）"]
    PB[Swift Proxy B]
    SB1[Storage B1]
    SB2[Storage B2]
    SB3[Storage B3]
  end

  USER[用户] --> PA
  USER --> PB
  PA -.跨区复制.- PB
```

```ini
# Swift proxy-server.conf
[filter:cross_region]
use = egg:swift#cross_region
```

### 16.7 Swift S3 兼容

通过 `swift3` 中间件让 Swift 支持 S3 API：

```ini
# proxy-server.conf
[filter:s3api]
use = egg:swift#swift3
```

```bash
# 用 AWS CLI 操作 Swift
aws --endpoint-url http://swift-proxy:8080 s3 ls
aws --endpoint-url http://swift-proxy:8080 s3 mb s3://my-bucket
```

### 16.8 Glance 元数据高级用法

```bash
# 自定义属性
openstack image set <image-id> \
  --property hw_disk_bus=scsi \
  --property hw_vif_model= virtio \
  --property hw_cpu_policy=dedicated \
  --property hw_pin_policy=strict \
  --property hw_numa_nodes=2 \
  --property os_require_quiesce=true

# 删除属性
openstack image unset <image-id> --property hw_disk_bus

# 查镜像属性
openstack image show <image-id> -c properties
```

**典型场景**：

- `hw_disk_bus=scsi`：Windows VM 用 scsi 控制器（性能更好）
- `hw_vif_model=virtio`：Linux VM 用 virtio 网卡
- `hw_cpu_policy=dedicated`：CPU pinning（专用物理核）
- `hw_numa_nodes=2`：NUMA 亲和

---

## §17 性能调优

### 17.1 Cinder LVM 调优

```ini
# cinder.conf
[lvm-backend]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
volume_backend_name = LVM

# 启用 discard（VM 删除卷时释放空间）
target_helper = lioadm
target_protocol = iscsi
```

```bash
# 物理卷对齐
pvcreate --dataalignment 4M /dev/sdb

# I/O 调度算法（SSD 用 none，HDD 用 deadline）
echo deadline > /sys/block/sdb/queue/scheduler

# 多路径
yum install -y device-mapper-multipath
multipathd
```

### 17.2 Cinder Ceph 调优

```bash
# Ceph 端
ceph osd pool set cinder-volumes pg_autoscale_mode on

# Cinder 端
[ceph-backend]
# 大卷 chunk size
rbd_store_chunk_size = 64

# 启用 caching
rbd_cache = true
rbd_cache_size = 256  # MB
rbd_cache_max_dirty_age = 30  # 秒
```

### 17.3 Swift 调优

```ini
# /etc/swift/proxy-server.conf
[DEFAULT]
# 工作进程数
workers = 8

# 限制上传文件大小
max_file_size = 5368709120  # 5GB

# 启用 pipelining（批量上传）
object_chunk_size = 65536
```

### 17.4 Glance 调优

```ini
# glance-api.conf
[DEFAULT]
# 工作进程
workers = 8

# 镜像缓存大小
image_cache_max_size = 200  # GB

# 启用 HTTP keepalive
http_keepalive = true
```

### 17.5 ECShop 性能优化

```bash
# Apache 配置优化
cat >> /etc/httpd/conf.d/ecshop.conf <<'EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/html/ecshop
    <Directory /var/www/html/ecshop>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # 启用压缩
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/css application/javascript
    </IfModule>

    # 启用过期
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpeg "access plus 30 days"
        ExpiresByType image/png "access plus 30 days"
    </IfModule>
</VirtualHost>
EOF
```

```bash
# PHP OPcache
cat >> /etc/php.d/opcache.ini <<'EOF'
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
EOF

# MySQL 调优
cat >> /etc/my.cnf.d/ecshop.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
max_connections = 500
query_cache_size = 64M
EOF
```

### 17.6 性能监控

```bash
# Cinder 卷 IO
cinder volume-stats <vol-id>

# Swift 集群统计
swift stat

# Glance 镜像使用
glance image-list --size-format=GB

# 整体资源使用
openstack usage show --project <project-id> --start <date>
```

---

## §18 常见反直觉点

### 18.1 "Glance 镜像删了 VM 还在跑"

- Glance 镜像只是"模板"
- VM 启动时下载到 compute 节点的 `/var/lib/nova/instances/_base/`
- 启动后不依赖 Glance
- Glance 镜像删除只影响"新 VM 启动"

### 18.2 "Cinder 卷 detach 后数据还在"

- Cinder 卷独立于 VM
- detach 后数据保留，VM 还可以重新 attach
- 只有 `volume delete` 才会真删（且要求 status=available）

### 18.3 "Swift 不是文件系统"

- Swift 是 HTTP REST，不是 NFS/CIFS
- 不能直接 mount 到 Linux 文件系统
- 第三方客户端：`s3fs` / `cloudfuse`

### 18.4 "Ceph 比 LVM 慢"

- 单次 IO 性能：Ceph < 本地 LVM（因为网络）
- 但 IO 并发 + 多副本 + 可扩展：Ceph > LVM
- 100 VM 跑分：Ceph 性能远超 LVM（因为 LVM 单点瓶颈）

### 18.5 "卷类型 type 改了影响所有实例"

- volume type 是"模板"，不绑 VM
- 改 type 影响"未来新卷"
- 已存在的卷 type 不变

### 18.6 "ECShop 跑在 VM 里 vs 物理机里性能差不多"

- ECShop 是 PHP + MySQL
- 瓶颈在数据库（MySQL IO）
- VM 里跑 MySQL 性能损失 5-10%（虚拟化层）
- 生产推荐：MySQL 用物理机 / bare metal / 专用 VM

### 18.7 "快照备份等于实时备份"

- 快照是瞬时的一致点
- 但备份到 Swift 是后台异步
- 备份完成前数据丢失风险存在
- 重要数据：快照 + 实时复制（MySQL 主从）

---

## §19 ECShop 进阶运维

### 19.1 扩容场景

```bash
# 1. 创建新 VM（同镜像）
openstack server create ecshop-web-2 \
  --flavor m1.medium \
  --image centos-stream-9 \
  --user-data ecshop-init.yaml

# 2. 配负载均衡（Octavia）
openstack loadbalancer create --name ecshop-lb --vip-subnet-id <subnet-id>
openstack loadbalancer listener create --name http --protocol HTTP --protocol-port 80 ecshop-lb
openstack loadbalancer pool create --name web-pool --lb-algorithm ROUND_ROBIN --listener http
openstack loadbalancer member create --address <web1-ip> --protocol-port 80 web-pool
openstack loadbalancer member create --address <web2-ip> --protocol-port 80 web-pool

# 3. 浮动 IP 绑到 LB
openstack floating ip set --port <lb-vip-port> <fip-id>
```

### 19.2 备份恢复演练

```bash
# 1. 创建快照
openstack volume snapshot create --volume <db-vol-id> db-snap-1

# 2. 模拟故障：删除 VM
openstack server delete ecshop-db

# 3. 从快照恢复
openstack volume create --snapshot db-snap-1 --size 100 db-vol-restore

# 4. 创建新 VM + attach 恢复卷
openstack server create ecshop-db-restore \
  --flavor m1.small \
  --image centos-stream-9 \
  --volume db-vol-restore

# 5. 验证数据
mysql ecshop < /backup/db-data.sql
```

### 19.3 数据库主从（MySQL Replication）

```bash
# 主 VM 配
cat >> /etc/my.cnf <<'EOF'
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
EOF
systemctl restart mariadb

mysql -e "CREATE USER 'repl'@'%' IDENTIFIED BY 'repl-pwd'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; FLUSH PRIVILEGES;"
mysql -e "SHOW MASTER STATUS;"  # 记下 File + Position

# 从 VM 配
cat >> /etc/my.cnf <<'EOF'
[mysqld]
server-id = 2
relay_log = /var/log/mysql/relay-bin.log
read_only = ON
EOF
systemctl restart mariadb

mysql -e "CHANGE MASTER TO MASTER_HOST='10.0.0.11', MASTER_USER='repl', MASTER_PASSWORD='repl-pwd', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=1234; START SLAVE;"
mysql -e "SHOW SLAVE STATUS\G"
```

### 19.4 监控告警

```bash
# 用 Ceilometer（OpenStack 自带监控）
openstack metric list --resource-id <vm-id>

# 看 VM CPU 使用率
openstack metric show --name cpu_util --resource-id <vm-id>

# 告警规则
openstack alarm create --name vm-high-cpu \
  --type gnocchi_resources_threshold \
  --resource-id <vm-id> \
  --metric cpu_util \
  --threshold 80 \
  --comparison-operator gt \
  --evaluation-periods 60 \
  --alarm-action 'log://'
```

---

最后更新: 2026-08-11 00:55（T6 Stage 6 Code 完成，补 §16~§19）