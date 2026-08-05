---
title: Kubernetes 面试与生产架构设计
desc: 汇总 Kubernetes 面试常见追问，给出可用于 1 分钟表达的标准答案，并整理生产集群设计、CNI/Ingress/存储选型、HA 与灾备。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0617～0702 + 面试综合
pdf_size: 综合
scope: 面试题库、生产架构、选型与高可用、灾备设计
status: 完成
---

# Kubernetes 面试与生产架构设计

> **目标**：把零散的 Kubernetes 知识整理成“回答口径统一、能复述、有结构”的表达。面试题不靠背答案，靠把“组件、流程、对象、控制循环”用自己的话说清楚。

## 目录

- [[#§0 面试表达框架]]
- [[#§1 基础架构题]]
- [[#§2 Pod 与工作负载题]]
- [[#§3 网络题]]
- [[#§4 存储题]]
- [[#§5 调度与资源题]]
- [[#§6 安全与权限题]]
- [[#§7 故障排查题]]
- [[#§8 场景题与综合题]]
- [[#§9 生产集群架构设计]]
- [[#§10 高可用与灾备]]
- [[#§11 选型建议]]
- [[#§12 1 分钟标准答案示例]]
- [[#§13 易错点]]
- [[#§14 与已有知识的链路]]

---

## §0 面试表达框架

### 0.1 回答四步法

```text
1. 目的：解决什么问题
2. 组件：哪些角色参与
3. 流程：从开始到结果的关键步骤
4. 边界：什么归它管，什么不归它管
```

### 0.2 解释一个对象

```text
我是要解决 X 问题
对象 Y 由谁观察
对象的 spec 是用户期望，status 是系统实际
控制器不断对比两者并执行 reconcile
它的故障通常表现为 A 现象
排查时先 B 再 C
```

---

## §1 基础架构题

### Q1：Kubernetes 的核心是什么？

声明式 API + 控制循环。组件围绕 API Server 工作：etcd 保存对象，Controller 维护期望状态，Scheduler 决定 Pod 调度位置，kubelet 在节点落实 Pod。

### Q2：API Server 为什么是中心？

所有组件都通过 API Server 读写对象，避免互相耦合。认证、鉴权、准入都集中在 API Server。

### Q3：etcd 故障会怎样？

API Server 写入和 Watch 都会失败，集群几乎不可用；不会自动恢复，需要按 etcd 故障流程处理。

### Q4：Scheduler 和 kubelet 的边界？

Scheduler 选节点；kubelet 让节点上的 Pod 达到期望状态。

### Q5：Controller 是什么？

不断读取 spec，对比 status，必要时调谐的循环组件。Deployment Controller、StatefulSet Controller、EndpointSlice Controller 都是例子。

---

## §2 Pod 与工作负载题

### Q1：Pod 为什么是最小调度单元？

Pod 中的容器共享网络、存储和生命周期，需要共同被放置到同一节点，Kubernetes 因此把 Pod 作为调度单位。

### Q2：Pod 内部多个容器能否监听同一端口？

不能。Pod 共享 network namespace，端口会冲突。

### Q3：Deployment 与 StatefulSet 区别？

Deployment 提供滚动更新和随机 Pod 名，适合无状态；StatefulSet 提供稳定 Pod 名、稳定存储、Headless Service 稳定发现，适合有状态。

### Q4：DaemonSet 适用什么场景？

需要在每个节点运行一个 Pod 的场景，例如日志采集、节点监控、CNI、kube-proxy。

### Q5：Job 的 Pod 能否设置 `Always`？

不建议，Job 通常使用 `OnFailure` 或 `Never`。

### Q6：Pod Pending 怎么查？

`describe pod` 看 Events；查资源、亲和性、污点、PVC、Node Allocatable。

### Q7：Readiness 和 Liveness 区别？

Readiness 失败 → 流量脱离；Liveness 失败 → 容器重启。

### Q8：Pod 处于 Running 但 Service 访问失败？

可能 Readiness 未通过、容器监听 `127.0.0.1`、端口写错、Service 端口和容器端口不一致、NetworkPolicy 阻断、kube-proxy 异常。

### Q9：Pod 重启策略有哪些？

`Always`、`OnFailure`、`Never`。

### Q10：Pod 怎么拿到自己的 Service 凭据？

通过环境变量或 DNS。环境变量依赖创建顺序，不适合作为主路径；DNS 更可靠。

---

## §3 网络题

### Q1：Service 如何发现 Pod？

Service 通过 Selector 选匹配 Label 的 Pod，EndpointSlice Controller 写入后端，kube-proxy 在节点上编程转发规则。

### Q2：ClusterIP 是什么？

Service 的虚拟 IP，不是真实网卡地址。节点上的转发规则把访问 ClusterIP 的请求转发到后端。

### Q3：Ingress 和 Service 区别？

Service 解决四层服务发现；Ingress 解决 HTTP/HTTPS 路由。Ingress 本身不是转发程序，需要 Controller 实际工作。

### Q4：CNI 和 kube-proxy 关系？

CNI 为 Pod 配置网络；kube-proxy 为 Service 编程转发。两者职责不同。

### Q5：kube-proxy iptables 和 IPVS 区别？

iptables 通过大量链式规则；IPVS 通过内核虚拟服务器，更适合大规模服务。IPVS 依赖 `ip_vs` 内核模块。

### Q6：Headless Service 是什么？

没有 ClusterIP 的 Service，DNS 直接返回后端 Pod IP，常用于 StatefulSet。

### Q7：ExternalName 干什么？

通过 DNS 别名把集群内部请求转发到集群外域名，不做端口转发。

### Q8：Pod 网络 CIDR 和 Service CIDR 可以重叠吗？

不能，规划阶段必须分离。

### Q9：NodePort 范围是多少？

通常是 30000-32767，但以集群配置为准。

### Q10：NetworkPolicy 默认允许还是拒绝？

默认全部允许。启用 NetworkPolicy 后，匹配策略外的流量可能被拒绝。

### Q11：Pod 跨节点通信要解决什么？

跨节点路由、IP 不冲突、CNI 维护转发、MTU、Overlay、Service 转发、Kubelet/iptables 等组件协同。

### Q12：CoreDNS 故障会怎样？

Service 名称解析失败，但通过 ClusterIP 直接访问仍可能工作。

---

## §4 存储题

### Q1：PV 和 PVC 关系？

PV 是实际存储资源；PVC 是应用申请存储的接口。Kubernetes 把 PVC 绑定到合适的 PV。

### Q2：动态卷是怎么创建的？

PVC 创建时由 StorageClass 中的 Provisioner 动态创建 PV，再绑定 PVC。

### Q3：PVC Pending 怎么查？

`describe pvc`、StorageClass、Provisioner Pod、节点、VolumeBindingMode。

### Q4：accessModes 区别？

`ReadWriteOnce`、`ReadOnlyMany`、`ReadWriteMany`、`ReadWriteOncePod`，底层存储必须支持。

### Q5：Retain 和 Delete 策略？

Retain 不自动清理；Delete 自动清理底层数据。生产数据库卷通常用 Retain。

### Q6：StatefulSet 怎么保证数据？

`volumeClaimTemplates` 为每个 Pod 模板化生成独立 PVC，Pod 重建后仍可绑定同一 PVC。

### Q7：Local Path Provisioner 的局限？

只能使用节点本地目录，Pod 只能调度到该节点；不适合多副本跨节点。

### Q8：StorageClass volumeBindingMode 的作用？

`Immediate` 立即创建 PV；`WaitForFirstConsumer` 等 Pod 调度后再创建，避免节点选择错误。

### Q9：CSI 是什么？

容器存储接口，由外部驱动实现，负责创建、挂载、卸载底层卷。

### Q10：删除 PVC 会发生什么？

根据回收策略：Retain 保留数据；Delete 删除 PV 和底层数据；Recycle（已不推荐）清空数据。

---

## §5 调度与资源题

### Q1：Pod Pending 怎么定位？

资源不足、requests 过大、污点、亲和性、TopologySpread、PVC Pending 等。

### Q2：requests 和 limits 区别？

requests 影响调度；limits 限制运行时使用。CPU 限额会被节流，内存超额会被杀。

### Q3：QoS 如何影响驱逐？

Guaranteed 最后被驱逐；Burstable 次之；BestEffort 最先被驱逐。

### Q4：HPA 工作原理？

HPA Controller 周期从 Metrics API 读指标，计算目标副本数并写入 ReplicaSet/Deployment。

### Q5：HPA 失效常见原因？

metrics-server 异常、Pod 无 requests、指标类型错误、目标资源错误。

### Q6：VPA 和 HPA 能否同时使用？

不建议同时对同一资源使用 CPU/Memory。VPA 调整请求值，HPA 调整副本数。

### Q7：污点和容忍关系？

污点是节点拒绝的策略；容忍是 Pod 接受该策略的标识。

### Q8：Node Affinity 和 Pod Affinity 区别？

Node Affinity 把 Pod 约束到节点；Pod Affinity 把 Pod 约束到和其他 Pod 接近或远离。

### Q9：cordon、drain、uncordon 区别？

cordon 阻止新 Pod 调度；drain 驱逐并阻止新调度；uncordon 恢复调度。

### Q10：为什么需要 PDB？

避免自愿中断时所有 Pod 同时不可用。

---

## §6 安全与权限题

### Q1：API 请求的认证、授权、准入区别？

认证识别身份；授权判断权限；准入控制对请求做修改或拒绝。

### Q2：Role 和 ClusterRole 区别？

Role 是 Namespace 内的权限定义；ClusterRole 是集群级或可被多个 Namespace 复用的权限定义。

### Q3：RoleBinding 能引用 ClusterRole 吗？

可以，但授权范围仍由 Binding 决定，通常只对当前 Namespace 生效。

### Q4：ServiceAccount 是什么？

Pod 内应用访问 API 时使用的身份，属于 Namespace，通过 Secret 或 Token 投影挂载。

### Q5：Secret 是否安全？

默认 `data` 是 Base64，不是加密。安全需要 RBAC、etcd 加密、外部密钥管理、凭据轮换。

### Q6：Pod Security Standards 是什么？

替代旧 PodSecurityPolicy 的安全策略体系，包括 `privileged`、`baseline`、`restricted` 三档。

### Q7：RBAC 和 NetworkPolicy 区别？

RBAC 控制 API 权限；NetworkPolicy 控制网络流量。

### Q8：删除 CSR 能撤销用户吗？

不一定。X.509 身份由 CA 信任决定，删除 CSR 不撤销已签发证书。

---

## §7 故障排查题

### Q1：Pod Pending 怎么查？

`describe pod`、资源、亲和性、污点、PVC、调度事件。

### Q2：ImagePullBackOff 怎么查？

镜像名、tag、Secret、DNS、镜像加速、`ctr pull`。

### Q3：CrashLoopBackOff 怎么查？

`logs --previous`、退出码、启动命令、配置、依赖、探针。

### Q4：ContainerCreating 卡住？

镜像、CNI、CSI、Sandbox、RuntimeClass、挂载路径。

### Q5：Service 有 ClusterIP 但访问失败？

DNS、Selector、EndpointSlice、Pod Ready、容器端口、kube-proxy/CNI、NetworkPolicy、节点防火墙。

### Q6：Node NotReady 怎么查？

`journalctl -u kubelet`、容器运行时、CNI、节点压力、证书。

### Q7：Pod 处于 Unknown 怎么办？

确认节点可通信、kubelet 正常；必要时强制删除并重新调度。

### Q8：PVC Pending 怎么查？

StorageClass、Provisioner、accessModes、size、VolumeBindingMode。

### Q9：RBAC Forbidden 怎么查？

`auth can-i`、Role/Binding、subresource（如 `pods/log`）。

### Q10：Ingress 404 怎么查？

域名、IngressClass、规则、后端 Service、Endpoint、Controller 日志。

---

## §8 场景题与综合题

### Q1：如何把传统应用迁到 K8s？

容器化 → 拆分无状态/有状态 → 写 YAML → Service/Ingress → 监控、日志、安全 → 灰度发布。

### Q2：为什么 Pod 删除后会重建？

控制器对比 spec，发现实际副本数不足，会重新创建 Pod。

### Q3：如何滚动发布而不中断？

`maxUnavailable=0`、`maxSurge=1`、Readiness 探针、PodDisruptionBudget。

### Q4：如何做金丝雀发布？

可以创建两个 Deployment 和 Service，或者使用 Ingress Controller 灰度能力，或者使用 Service Mesh。

### Q5：如何做存储迁移？

新建 PVC，使用 `PersistentVolumeClaim` 迁移工具或底层存储快照；切换流量；旧 PVC 留作回滚。

### Q6：如何做多集群管理？

Karmada、KubeFed、Cluster API、ArgoCD 等。

### Q7：如何升级集群？

控制平面先升 → kubelet → 节点组件；先检查兼容性、备份 etcd、阅读 release notes。

### Q8：如何备份 etcd？

```bash
etcdctl snapshot save <file>
```

并把备份异地保存；备份应包含加密 key。

### Q9：如何排查流量突增？

HPA 日志、Ingress Controller 日志、`kubectl top`、Metrics Server、APM 工具。

### Q10：如何做 Pod 安全性加固？

最小镜像、SecurityContext、非 root、只读根文件系统、删除 Capability、seccomp、SELinux、Pod Security Standards、镜像签名。

---

## §9 生产集群架构设计

### 9.1 集群分层

```text
业务层
  └── Deployment / StatefulSet / DaemonSet
      ├── ConfigMap / Secret
      ├── Service / Headless Service
      ├── Ingress
      └── HPA / PDB

资源层
  ├── Requests / Limits
  ├── ResourceQuota / LimitRange
  └── StorageClass / PV / PVC

安全层
  ├── RBAC
  ├── ServiceAccount
  ├── SecurityContext
  └── NetworkPolicy

运维层
  ├── Metrics
  ├── Logs
  ├── Events
  ├── Backup
  └── Upgrade
```

### 9.2 三层业务部署示例

```text
Internet
  ↓
Ingress (TLS)
  ↓
Service frontend
  ↓
Deployment frontend (N replicas)
  ↓
Service backend
  ↓
Deployment backend (M replicas)
  ↓
Service db-headless
  ↓
StatefulSet db (3 replicas)
  ↓
PVC × 3
  ↓
StorageClass
```

### 9.3 多租户隔离

- Namespace
- ResourceQuota
- LimitRange
- NetworkPolicy
- RBAC
- 独立 Ingress Controller 入口

### 9.4 跨节点服务网格

可选 Istio / Linkerd 提供：

- 流量管理
- mTLS
- 灰度
- 策略
- 可观测

### 9.5 16GB 主机环境设计

```text
常态：
  master: 2 vCPU / 4GB
  worker1: 2 vCPU / 4GB

按需：
  worker2: 2 vCPU / 4GB（按实验启停）

存储：
  NFS server 可与 master 共享
  或者独立小 VM 跑 NFS

监控：
  Metrics Server 必装
  Prometheus + Grafana + Loki 可选
  长时间使用应降低采集频率
```

---

## §10 高可用与灾备

### 10.1 控制平面 HA

```text
负载均衡（云 LB / haproxy / keepalived）
   ↓
etcd × 3 (quorum)
   ↓
kube-apiserver × 2
   ↓
kube-scheduler × 2
   ↓
kube-controller-manager × 2
```

要点：

- `etcd` 集群需要奇数节点
- HAProxy / keepalived 提供 VIP
- kube-apiserver 之间的 etcd 数据一致

### 10.2 etcd 备份与恢复

```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db
ETCDCTL_API=3 etcdctl snapshot status backup.db
```

恢复时通常需要：

1. 停止 kube-apiserver
2. 还原 etcd 数据
3. 启动 kube-apiserver
4. 验证集群

### 10.3 灾备切换

- 跨区域集群
- Velero 备份 PV 和对象
- 数据库应用自身的备份恢复
- DNS 切换入口
- 演练恢复流程

### 10.4 升级与维护

```text
1. 阅读 release notes
2. 备份 etcd 和持久化数据
3. 升级控制平面
4. 升级 kubelet、containerd
5. 升级集群插件（CNI、Ingress、CSI、Metrics）
6. 升级应用
```

逐节点 drain、升级、重启、uncordon 是常用节奏。

### 10.5 蓝绿发布 / 灰度

- 双集群或双 Ingress
- 流量权重
- 探针和测试
- 渐进切换

---

## §11 选型建议

### 11.1 CNI

| 需求 | 候选 |
|---|---|
| 简单、广泛使用 | Calico、Flannel |
| 高性能、eBPF | Cilium |
| 多云、Overlay | Calico、Weave |
| 网络策略 | Calico、Cilium |

### 11.2 Ingress Controller

| 需求 | 候选 |
|---|---|
| 通用 | ingress-nginx |
| API Gateway | Kong、APISIX |
| 灰度/插件 | APISIX、Traefik |

### 11.3 存储

| 场景 | 选择 |
|---|---|
| 学习/小规模 | NFS、Local Path |
| 数据库 | 云厂商块存储、Ceph、Longhorn |
| 多集群 | 跨云方案 |
| 大数据 | 专用文件系统 |

### 11.4 监控

- 轻量：Metrics Server + kubectl top
- 中等：Prometheus + Grafana
- 大规模：Prometheus + Thanos 或 VictoriaMetrics
- 日志：Loki、EFK

### 11.5 镜像仓库

- Harbor
- 阿里云 ACR
- AWS ECR
- 自建 Registry

---

## §12 1 分钟标准答案示例

### A：Pod 创建流程

```text
kubectl apply 提交 Deployment
  → API Server 写入 etcd
  → Deployment Controller 创建 ReplicaSet
  → ReplicaSet Controller 创建 Pod
  → Scheduler 给未调度的 Pod 选节点
  → 目标节点 kubelet 创建 Pod Sandbox
  → 调用 CRI 启动容器
  → CNI 配置网络
  → CSI 挂载卷
  → 探针通过后 Pod Ready
  → EndpointSlice Controller 更新后端
  → Service 可以转发流量
```

### B：Service 找到 Pod

```text
Service 用 Selector 选 Pod
  → EndpointSlice Controller 收集符合条件的 Pod
  → kube-proxy 监听 Service/Endpoint 变化
  → 节点上编程 iptables 或 IPVS 规则
  → 客户端访问 ClusterIP 时，节点规则转发到后端 Pod
```

### C：Deployment 滚动更新

```text
修改 Pod Template
  → Deployment 创建新 ReplicaSet
  → 新 ReplicaSet 慢慢加 Pod
  → 旧 ReplicaSet 慢慢减 Pod
  → 通过 maxSurge 和 maxUnavailable 控制
  → Readiness 通过后继续推进
```

### D：PVC 绑定

```text
Pod 引用 PVC
  → PVC 由 StorageClass 触发 Provisioner
  → Provisioner 创建 PV
  → 控制器把 PVC 和 PV 绑定
  → kubelet 等待绑定后挂载
```

### E：RBAC 失败

```text
请求到达 API Server
  → 认证通过
  → Authorization 检查用户是否在 RoleBinding 中
  → Role 是否包含对应资源和 verbs
  → 不通过则返回 Forbidden
```

### F：Node NotReady 排查

```text
检查 kubelet 日志
  → 检查 containerd 等运行时
  → 检查网络插件
  → 检查节点资源压力
  → 检查证书过期
  → 必要时重启服务或替换节点
```

### G：etcd 故障影响

```text
API Server 写对象失败
  → 控制器无法 reconcile
  → 调度决策无法保存
  → 集群基本不可用
  → 需要从快照恢复或修复 etcd 集群
```

### H：Cluster IP 是不是真实网卡地址？

不是。Service ClusterIP 是一个虚拟 IP，节点上的转发规则把访问它的请求 DNAT 到后端 Pod IP。

### I：Pod IP 不可作为服务地址的原因？

Pod 可能因节点故障、滚动更新、调度重新创建而变化。Service 提供稳定入口和后端发现。

### J：HPA 为什么不工作？

常见原因：metrics-server 异常、Pod 没有 requests、指标类型错误、目标资源错误、HPA 与 VPA 冲突、节点资源已满。

---

## §13 易错点

1. 准备答案时不要只背名词，要解释“为什么这样做”。
2. 面试不要说“可以参考文档”，而要讲出关键步骤。
3. 一次只讲一个核心点，不要同时罗列 10 个组件。
4. 解释控制循环时一定要包括“对比期望和实际”。
5. 区分“组件”和“对象”，例如 API Server 是组件，Pod 是对象。
6. 区分 Service 类型时按 ClusterIP、NodePort、LoadBalancer、ExternalName、Headless。
7. 强调 Namespace 不是安全边界。
8. 不要把 HPA、VPA 混为同一个能力。
9. 解释状态时区分 spec 和 status。
10. 解释故障时按层次，而不是只说一个命令。

---

## §14 与已有知识的链路

- [[02-Kubernetes核心架构与对象模型]]：面试基础
- [[03-Pod与工作负载]]：工作负载对比
- [[04-配置与安全]]：认证授权
- [[05-Kubernetes网络与Service]]：网络题
- [[06-Kubernetes存储与StatefulSet]]：存储题
- [[07-调度资源弹性与健康检查]]：调度与弹性
- [[08-Kubernetes命令与故障排查]]：故障题
- [[Linux网络]]：网络基础
- [[Linux存储]]：存储基础
- [[Linux防火墙]]：网络策略理解
- [[Linux服务与SSH]]：服务管理
