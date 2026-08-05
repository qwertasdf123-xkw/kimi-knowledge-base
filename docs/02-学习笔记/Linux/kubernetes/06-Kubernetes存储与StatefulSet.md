---
title: Kubernetes 存储与 StatefulSet
desc: 回顾 emptyDir、hostPath、NFS、PV/PVC、StorageClass、动态卷供应、StatefulSet 及 Nginx/Etcd/Redis/MySQL 等有状态应用。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0625.md、课堂笔记-0702.md、课堂笔记-0702 (1).md（Markdown课堂资料）
pdf_size: 约 8000 行课堂记录
scope: Kubernetes 存储模型、动态卷供应、StatefulSet 稳定身份与稳定存储
status: 完成
---

# Kubernetes 存储与 StatefulSet

> **核心理解**：Pod 是临时的，PVC 是稳定的；StatefulSet 是为了让有状态应用也能像 Deployment 一样被 Kubernetes 自动化管理。

## 目录

- [[#§0 存储心智模型]]
- [[#§1 emptyDir]]
- [[#§2 hostPath]]
- [[#§3 NFS Volume]]
- [[#§4 PV 与 PVC 架构]]
- [[#§5 PV 关键字段]]
- [[#§6 PVC 与 PV 绑定]]
- [[#§7 回收策略与丢失数据]]
- [[#§8 动态卷与 StorageClass]]
- [[#§9 Local Path Provisioner]]
- [[#§10 NFS Provisioner]]
- [[#§11 有状态应用 vs 无状态应用]]
- [[#§12 StatefulSet 原理]]
- [[#§13 Nginx 有状态示例]]
- [[#§14 Etcd 有状态示例]]
- [[#§15 Redis 有状态示例]]
- [[#§16 MySQL 有状态示例]]
- [[#§17 存储排查]]
- [[#§18 易错点]]
- [[#§19 面试追问]]
- [[#§20 与已有知识的链路]]

---

## §0 存储心智模型

```text
应用 Pod
  ↓
Pod Volume
  ↓
PVC
  ↓
PV
  ↓
StorageClass / 动态供应
  ↓
CSI / 节点挂载
  ↓
底层存储
```

### 四类存储概念

| 概念 | 谁关心 | 责任 |
|---|---|---|
| Volume | Pod 编排者 | 决定卷如何挂到容器 |
| PVC | 应用 | 提出容量和访问方式需求 |
| PV | 集群存储管理员 | 实际存储资源 |
| StorageClass | 集群存储管理员 | 动态供应规则 |

---

## §1 emptyDir

```yaml
spec:
  volumes:
    - name: cache
      emptyDir: {}
  containers:
    - name: app
      image: app:1.0
      volumeMounts:
        - name: cache
          mountPath: /cache
```

特点：

- 生命周期与 Pod 绑定
- 节点本地存储
- Pod 删除时数据通常被清理
- 适合缓存、临时文件

```bash
kubectl exec <pod> -- ls -l /cache
```

---

## §2 hostPath

```yaml
volumes:
  - name: data
    hostPath:
      path: /var/lib/node-data
      type: DirectoryOrCreate
```

特点：

- 节点文件系统
- 跨 Pod 共享节点本地数据
- 节点故障可能造成数据风险
- 常用于 DaemonSet、CNI 插件、节点 Agent
- 课堂中应明确 type，避免节点路径不存在导致 Pod 失败

---

## §3 NFS Volume

```yaml
volumes:
  - name: web
    nfs:
      server: 10.0.0.10
      path: /data/web
```

服务端：

```bash
yum install -y nfs-utils
mkdir -p /data/web
chmod 777 /data/web
echo '/data/web *(rw,sync,no_root_squash)' > /etc/exports
systemctl enable --now nfs-server
```

客户端验证：

```bash
mount -t nfs 10.0.0.10:/data/web /mnt
umount /mnt
```

特点：

- 多节点共享
- 适合读多写少或小规模实验
- 单点故障、性能瓶颈和一致性需评估

---

## §4 PV 与 PVC 架构

```text
Pod
  ↓ 使用
PVC
  ↓ 绑定
PV
  ↓ 挂载
底层存储（NFS / 本地 / 云盘）
```

应用通过 PVC 申请存储，PV 是实际存储资源，PVC 和 PV 匹配后才挂载到 Pod。

### 4.1 静态 PV

管理员手动创建 PV，再让 PVC 匹配。

### 4.2 动态 PV

PVC 提交时由 Provisioner 自动创建 PV，依赖 StorageClass。

### 4.3 PV/PVC 的好处

- 应用不需要关心具体存储
- 控制器负责绑定和挂载
- 不同应用可以使用不同 StorageClass
- 集群升级、节点维护和存储更换时不需要应用感知

---

## §5 PV 关键字段

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-web
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.0.0.10
    path: /data/web
```

### 5.1 accessModes

| 模式 | 含义 |
|---|---|
| ReadWriteOnce | 单一节点读写 |
| ReadOnlyMany | 多节点只读 |
| ReadWriteMany | 多节点读写 |
| ReadWriteOncePod | 1.22+，单一 Pod 读写 |

底层存储必须支持对应模式。

### 5.2 volumeModes

| 模式 | 含义 |
|---|---|
| Filesystem | 挂载为目录 |
| Block | 暴露为裸块设备 |

课堂资料中提供 block 卷示例，强调部分应用需要直接使用块设备，例如某些数据库。

### 5.3 回收策略

| 策略 | 含义 |
|---|---|
| Retain | 不自动清理，保留数据 |
| Delete | 删除 PV 并清理底层数据 |
| Recycle | 旧策略，将卷数据清空 |

动态卷默认回收策略由 StorageClass 决定，常见为 `Delete`；静态卷默认 `Retain`。

### 5.4 状态

| 状态 | 含义 |
|---|---|
| Available | 可被新 PVC 绑定 |
| Bound | 已绑定到 PVC |
| Released | PVC 删除但 PV 未释放 |
| Failed | 回收或供应失败 |

---

## §6 PVC 与 PV 绑定

匹配维度：

```text
storageClassName
accessModes
volumeMode
size 1:1
```

如果 PVC 一直 Pending：

```bash
kubectl get pvc
kubectl describe pvc <pvc>
kubectl get pv
kubectl get sc
```

常见原因：

- 没有合适的 PV
- storageClassName 不匹配
- size 比现有 PV 大
- accessModes 不支持
- Volume 已被占用
- Provisioner 不可用

---

## §7 回收策略与丢失数据

课堂中的典型修复：

```text
PV 标记 Released 后
  - Retain：不会自动清理，可以手工编辑 claimRef 删除
  - Delete：被 Provisioner 回收
  - Recycle：旧版本会执行 `rm -rf`
```

修改 PV 字段时通常需要先清掉 `claimRef`，否则可能因为状态卡住而无法继续：

```bash
kubectl edit pv <pv>
```

生产环境的数据安全设计建议：

- 数据库卷使用 `Retain`
- 动态卷谨慎使用 `Delete`
- 任何删除前先做快照或备份
- PV/PVC 名称、Namespace 和底层卷保持一致

---

## §8 动态卷与 StorageClass

### 8.1 StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: 10.0.0.10
  path: /data
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

### 8.2 使用动态卷

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  storageClassName: nfs
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

PVC 创建时 Provisioner 会自动创建 PV 并完成绑定。

### 8.3 默认 StorageClass

```yaml
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
```

设置默认 StorageClass 后，PVC 不显式指定 `storageClassName` 时也会被自动供应。

### 8.4 VolumeBindingMode

- `Immediate`：PVC 创建后立即绑定 PV
- `WaitForFirstConsumer`：等 Pod 调度后再创建 PV，可以避免后端存储节点选择错误

---

## §9 Local Path Provisioner

Local Path Provisioner 适合在单机或小规模实验环境中提供动态卷，原理是在指定路径下创建目录。

课堂中的关键点：

- 通过 Deployment 或 DaemonSet 部署
- 自动创建 StorageClass
- 适用于不能使用网络存储的轻量环境
- Pod 只能调度到拥有该本地目录的节点
- 不能跨节点，多副本可能成为问题

```bash
kubectl get pods -n local-path-storage
kubectl get sc
kubectl get pvc
ls /opt/local-path-provisioner/
```

---

## §10 NFS Provisioner

课堂中的 NFS Provisioner 工作链：

```text
Pod
  ↓
PVC（storageClassName: nfs）
  ↓
StorageClass（provisioner: nfs.csi.k8s.io）
  ↓
NFS Provisioner
  ↓
NFS Server 目录
```

部署步骤概览：

1. 部署 NFS server
2. 部署 NFS Provisioner
3. 创建 StorageClass
4. 创建 PVC 验证

回收策略要谨慎选择 `Retain` 还是 `Delete`。

---

## §11 有状态应用 vs 无状态应用

| 维度 | 无状态 | 有状态 |
|---|---|---|
| 实例数 | 副本可互相替换 | 实例不能互相替换 |
| 存储 | 共享或无 | 每个实例独立 |
| 网络身份 | 随机 | 稳定 |
| 扩缩容 | 简单 | 需要顺序控制 |
| 典型 | Web、API | 数据库、消息队列、缓存 |

课堂资料展示：

```text
无状态：
  Web + Redis（外部） + 共享 NFS

有状态：
  Etcd
  Redis Cluster
  MySQL
  Cassandra
  Zookeeper
  Kafka
```

---

## §12 StatefulSet 原理

### 12.1 三个稳定

```text
稳定 Pod 名称：web-0、web-1、web-2
稳定网络身份：web-0.web.default.svc.cluster.local
稳定存储：PVC volumeClaimTemplates
```

### 12.2 顺序控制

```text
启动：web-0 → web-1 → web-2
删除：web-2 → web-1 → web-0
扩缩容：按序号增删
```

### 12.3 关键字段

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        storageClassName: nfs
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

对应 Headless Service：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
```

StatefulSet 的 PVC 命名：

```text
data-web-0
data-web-1
data-web-2
```

### 12.4 验证稳定身份

```bash
kubectl exec -it web-0 -- nslookup web-0.web
kubectl exec -it web-0 -- cat /usr/share/nginx/html/index.html
kubectl delete pod web-0
kubectl exec -it web-0 -- cat /usr/share/nginx/html/index.html
```

重启后 IP 变化，但存储和身份稳定。

---

## §13 Nginx 有状态示例

```text
NFS 共享目录 /data/web
  ├── web-0/index.html
  ├── web-1/index.html
  └── web-2/index.html
```

通过 PVC 模板为每个 Pod 分配独立目录，验证：

- 写入和读取在重启后保留
- Pod 名字稳定
- 访问 web-0 仍能找到自己之前的页面

---

## §14 Etcd 有状态示例

课堂展示 3 节点 Etcd 集群：

```text
etcd-0
etcd-1
etcd-2
```

要点：

- 使用 Headless Service
- 通过 `--initial-cluster` 加入集群
- 删除 etcd-2 后，重建的 Pod 仍是新身份，集群其余成员仍能恢复 quorum
- 数据通过 PVC 持久化

验证：

```bash
kubectl exec -it etcd-0 -- etcdctl member list
kubectl exec -it etcd-0 -- etcdctl endpoint status --cluster
```

---

## §15 Redis 有状态示例

课堂展示 Redis 主从或三主三从结构：

```text
redis-0（master）
redis-1
redis-2
```

或 6 节点：

```text
redis-0（master）
redis-1（master）
redis-2（master）
redis-3（slave）
redis-4（slave）
redis-5（slave）
```

常见验证：

- 写入数据到主节点
- 从节点能读取
- 删除某个 Pod，重建后集群自动重新选主
- 复制状态 `Replication`
- 各 Pod 的 `role`

---

## §16 MySQL 有状态示例

课堂资料中 MySQL 示例以简化集群为主：

```text
mysql-0
mysql-1
```

验证：

- 在主节点上创建数据库
- 删除 Pod 后，PVC 数据仍能保留
- 重启后 Pod 域名仍可通过 Headless Service 解析

> 注：课堂中 MySQL 集群为简化示例，生产 MySQL 主从通常需要官方 Operator 或社区方案支持更完整的高可用、备份和故障转移。

---

## §17 存储排查

### 17.1 PVC Pending

```bash
kubectl describe pvc <pvc>
kubectl get pv
kubectl get sc
kubectl get pods -n kube-system
```

检查项：

- storageClassName 是否存在
- size 超过现有 PV
- accessModes 不匹配
- Provisioner 未运行
- 节点上 volumeMode 资源不可用

### 17.2 Pod ContainerCreating

```bash
kubectl describe pod <pod>
kubectl get events --sort-by=.lastTimestamp
```

检查：

- PVC 是否 Bound
- 节点是否支持挂载
- NFS 服务是否可访问
- CSI 驱动是否运行
- 节点内核模块
- SELinux 标签

### 17.3 存储路径错误

NFS 路径不存在的常见现象：

```text
wrong fs type, bad option, bad superblock
mount(2) system call failed
```

需要确认：

- `exports` 配置
- 防火墙
- 路径
- 权限

### 17.4 节点侧排查

```bash
mount | grep <pv>
df -h
findmnt
ls -l /var/lib/kubelet/pods/
```

---

## §18 易错点

1. Pod 删除不代表 Volume 删除。
2. `Retain` 不会自动清理数据。
3. `ReadWriteOnce` 并不一定限制单 Pod 写入，要看底层存储。
4. `ReadWriteMany` 并不所有存储都支持。
5. Headless Service 没有 ClusterIP 是正常设计。
6. StatefulSet 的 PVC 命名包含 Pod 序号。
7. 删除 StatefulSet 默认会级联删除 PVC，可能丢数据。
8. Local Path Provisioner 单节点，不适合多副本跨节点。
9. 静态 PV 的 size 必须和 PVC 完全相同。
10. 动态卷的回收策略由 StorageClass 决定。
11. `claimRef` 不清空可能导致 PV 卡在 Released。
12. 简化示例的 MySQL 集群不能直接等同于生产高可用。

---

## §19 面试追问

### Q1：PVC Pending 怎么查？

先看 PVC 描述，对比 storageClassName、accessModes、size，再看现有 PV、StorageClass 状态，最后看 Provisioner Pod、节点和事件。

### Q2：StatefulSet 与 Deployment 区别？

Deployment 提供快速滚动更新和随机 Pod 名称，适合无状态；StatefulSet 提供稳定 Pod 名称、稳定存储、有序启停，适合有状态。

### Q3：为什么 StatefulSet 需要 Headless Service？

因为 StatefulSet 的每个 Pod 需要稳定可寻址的 DNS 名称，Headless Service 不做 ClusterIP 虚拟化，直接返回 Pod IP。

### Q4：StatefulSet 删除会删除 PVC 吗？

默认会级联删除 PVC。生产场景应该按需修改策略或使用 Retain，并提前备份。

---

## §20 与已有知识的链路

- [[Linux存储]]：块设备、文件系统、挂载、NFS、LVM
- [[LinuxSELinux]]：挂载点的安全上下文
- [[Linux目录]]：Pod 中 Volume 的目录视图
- [[03-Pod与工作负载]]：Pod 共享 Volume 的基础
- [[04-配置与安全]]：Secret 在 PV 中存储证书
- [[05-Kubernetes网络与Service]]：Headless Service 解析
- [[08-Kubernetes命令与故障排查]]：存储故障 Runbook
