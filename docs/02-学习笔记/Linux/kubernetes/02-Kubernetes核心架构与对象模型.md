---
title: Kubernetes 核心架构与对象模型
desc: 建立控制平面、Worker、API Server、etcd、Controller、Scheduler、kubelet 和 Kubernetes API 对象之间的整体关系。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0622.md、课堂笔记-0624 (1).md（Markdown课堂资料）
pdf_size: 课堂架构与 Pod 相关内容
scope: Kubernetes 架构、声明式 API、Namespace/Context、对象字段和控制循环
status: 完成
---

# Kubernetes 核心架构与对象模型

> **一句话**：Kubernetes 是围绕 API Server 构建的声明式控制系统；对象记录期望状态，控制器不断把实际状态拉回期望状态。

## 目录

- [[#§0 总体架构]]
- [[#§1 控制平面组件]]
- [[#§2 Worker 节点组件]]
- [[#§3 一次 kubectl apply 发生了什么]]
- [[#§4 声明式 API 与对象结构]]
- [[#§5 Namespace、Context 与 kubeconfig]]
- [[#§6 Label、Selector、OwnerReference 与 Annotation]]
- [[#§7 控制器和控制循环]]
- [[#§8 静态 Pod]]
- [[#§9 API 观察命令]]
- [[#§10 易错点]]
- [[#§11 面试追问]]
- [[#§12 与已有知识的链路]]

---

## §0 总体架构

```text
                    ┌──────────────────────────────┐
                    │          Control Plane        │
                    │                              │
kubectl ───────────▶│  kube-apiserver              │
                    │       ├── etcd               │
                    │       ├── kube-scheduler      │
                    │       └── controller-manager  │
                    └──────────────┬───────────────┘
                                   │ API Watch
             ┌─────────────────────┴─────────────────────┐
             │                                           │
        Worker Node 1                              Worker Node 2
        kubelet                                     kubelet
        kube-proxy                                  kube-proxy
        containerd                                  containerd
        CNI                                         CNI
        Pod                                         Pod
```

### 组件通信原则

- 大多数控制平面组件通过 API Server 读写对象
- kubelet 从 API Server 获取自己负责的 Pod，并回报状态
- Scheduler 为没有绑定节点的 Pod 写入节点信息
- Controller 观察对象变化并创建、更新或删除其他对象
- etcd 是 API 对象的持久化存储，不是普通业务数据库

---

## §1 控制平面组件

### 1.1 kube-apiserver

API Server 是：

- Kubernetes API 的统一入口
- 认证、鉴权、准入控制的入口
- 对象校验、转换和持久化的入口
- 各组件 Watch 资源变化的入口

请求大致经过：

```text
TLS / HTTP
  ↓
Authentication
  ↓
Authorization
  ↓
Admission
  ↓
Schema / Object Validation
  ↓
etcd 持久化
  ↓
返回响应
```

### 1.2 etcd

etcd 保存 Kubernetes 的集群状态，例如：

- Namespace
- Deployment
- Pod 对象
- Service
- Secret
- ConfigMap
- RBAC
- 节点和租约信息

etcd 不负责：

- 直接运行容器
- 直接转发 Service 流量
- 直接调度 Pod
- 直接挂载业务卷

### 1.3 kube-scheduler

Scheduler 负责给尚未绑定节点的 Pod 选择节点。它考虑：

- 节点资源是否满足 requests
- Node Selector / Affinity
- Taint / Toleration
- 拓扑分布
- 优先级和抢占

Scheduler 不是容器启动器；它只负责做出调度决策并写入 Pod 的节点绑定信息。

### 1.4 kube-controller-manager

Controller 通过 Watch 资源，比较：

```text
期望状态 spec
      vs
实际状态 status
```

然后执行修正动作。常见控制器：

- Deployment Controller
- ReplicaSet Controller
- StatefulSet Controller
- DaemonSet Controller
- Job Controller
- Node Controller
- EndpointSlice Controller
- Namespace Controller
- ServiceAccount Controller

---

## §2 Worker 节点组件

### 2.1 kubelet

kubelet 是节点代理，职责包括：

- 从 API Server 获取 PodSpec
- 创建和管理 Pod Sandbox
- 调用 CRI 创建容器
- 调用 CNI 配置网络
- 调用 CSI 挂载存储
- 执行探针
- 回报 Pod 和节点状态
- 执行 Pod 的重启策略

kubelet 不负责：

- 决定 Pod 调度到哪台机器
- 维护 Deployment 副本数
- 提供 Service 虚拟 IP

### 2.2 Container Runtime

Containerd 负责：

- 拉取和存储镜像
- 创建 Pod Sandbox
- 创建、启动、停止容器
- 管理容器进程和文件系统

详见 [[01-容器运行时与集群安装]]。

### 2.3 kube-proxy

kube-proxy 在节点上根据 Service 和 EndpointSlice 编程转发规则。传统课堂重点是：

- iptables 模式
- IPVS 模式
- 会话保持
- Service ClusterIP 和 NodePort 转发

新版本还可能存在 nftables 等模式，实际集群要以当前版本为准。

### 2.4 CNI、CSI

- CNI：为 Pod 创建网络命名空间、网卡、IP 和路由
- CSI：为 Pod 提供卷的创建、挂载和卸载

---

## §3 一次 `kubectl apply` 发生了什么

以 Deployment 为例：

```text
1. kubectl 读取 YAML
2. 通过 kubeconfig 找到 API Server
3. TLS 认证客户端
4. API Server 执行认证、鉴权、准入和字段校验
5. Deployment 对象写入 etcd
6. Deployment Controller 发现对象
7. 创建 ReplicaSet
8. ReplicaSet Controller 创建 Pod
9. Scheduler 发现未调度 Pod
10. Scheduler 选择节点并写入 spec.nodeName
11. 目标节点 kubelet 发现 Pod
12. kubelet 调用 CRI 创建 Sandbox 和容器
13. CNI 配置 Pod 网络
14. CSI 挂载卷
15. kubelet 执行探针
16. kubelet 回写 Pod status
17. EndpointSlice Controller 根据 Ready 状态更新后端
18. Service 流量可以到达 Pod
```

这条流程是理解故障排查的主线。

### 不同故障对应的层次

| 现象 | 可能停在哪一步 |
|---|---|
| 对象创建失败 | API 校验、鉴权或 Admission |
| Deployment 有但没有 ReplicaSet | Controller 或 API Server |
| Pod Pending | Scheduler、资源、亲和性或污点 |
| ContainerCreating | kubelet、CRI、CNI、CSI |
| CrashLoopBackOff | 容器进程、命令、配置或依赖 |
| Pod Running 但不 Ready | Readiness Probe 或应用健康 |
| Service 无后端 | Selector、EndpointSlice、Ready 状态 |

---

## §4 声明式 API 与对象结构

### 4.1 声明式和命令式

命令式：

```bash
kubectl create deployment web --image=nginx --replicas=3
```

声明式：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
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
          image: nginx
```

命令式告诉系统“现在做一个动作”；声明式描述“我希望最终是什么状态”。

### 4.2 Object 的四个核心部分

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: default
spec:
  replicas: 3
status:
  availableReplicas: 3
```

| 字段 | 作用 |
|---|---|
| `apiVersion` | API 组和版本 |
| `kind` | 对象类型 |
| `metadata` | 名称、命名空间、标签、注解、UID 等元数据 |
| `spec` | 用户声明的期望状态 |
| `status` | 控制器或 kubelet 回报的实际状态 |

### 4.3 Spec 和 Status

不要手动把 `status` 当成配置入口。通常：

- 用户修改 `spec`
- 控制器根据 `spec` 执行动作
- 系统把结果写入 `status`

### 4.4 API Group

```bash
kubectl api-resources
kubectl api-versions
kubectl explain deployment
kubectl explain deployment.spec.template.spec.containers
```

常见资源：

| 资源 | API |
|---|---|
| Pod | `v1` |
| Service | `v1` |
| ConfigMap | `v1` |
| Deployment | `apps/v1` |
| StatefulSet | `apps/v1` |
| DaemonSet | `apps/v1` |
| Job | `batch/v1` |
| Ingress | `networking.k8s.io/v1` |
| HPA | `autoscaling/v2` |
| RBAC | `rbac.authorization.k8s.io/v1` |

---

## §5 Namespace、Context 与 kubeconfig

### Namespace

Namespace 提供逻辑隔离和资源命名范围：

```bash
kubectl get ns
kubectl create ns dev
kubectl get pods -n dev
kubectl config set-context --current --namespace=dev
```

Namespace 不是完整的安全边界；真正的权限和网络隔离还需要 RBAC、ResourceQuota、NetworkPolicy 等。

### Context

Context 通常由三部分组成：

```text
cluster + user + namespace
```

```bash
kubectl config get-contexts
kubectl config current-context
kubectl config use-context <context>
kubectl config set-context --current --namespace=<namespace>
```

### kubeconfig

kubeconfig 保存：

- API Server 地址
- 集群 CA
- 用户凭据
- Context

注意：kubeconfig 可能包含高权限证书或 Token，不能提交到公开仓库。

---

## §6 Label、Selector、OwnerReference 与 Annotation

### Label 和 Selector

Label 是对象的索引标签；Selector 是控制器或 Service 查找对象的条件。

```yaml
metadata:
  labels:
    app: web
    version: v1
```

```yaml
selector:
  matchLabels:
    app: web
```

最常见的 Service 故障是：Service Selector 与 Pod Label 不匹配。

### OwnerReference

OwnerReference 表示对象的管理关系：

```text
Deployment
  ↓ ownerReference
ReplicaSet
  ↓ ownerReference
Pod
```

查看：

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences}'
kubectl describe pod <pod>
```

### Annotation

Annotation 用来保存不适合做筛选标签的元数据，例如：

- Ingress Controller 配置
- 部署工具信息
- 变更原因
- 证书或外部控制器的附加信息

---

## §7 控制器和控制循环

控制器的一般伪代码：

```text
while true:
    actual = observe()
    desired = read_spec()
    if actual != desired:
        reconcile(actual, desired)
    update_status()
```

这解释了：

- 删除 Deployment 管理的 Pod 后，Pod 会重新出现
- 手动改动控制器管理的 Pod，改动可能被覆盖
- 节点故障后，控制器会尝试维持副本数
- Service 后端会随 Pod 标签和 Ready 状态变化

### Controller 和 Operator

- Controller 是控制循环思想的实现
- Operator 通常是使用 Kubernetes API 管理某类复杂应用的自定义控制器
- CRD 让用户可以增加新的 API 对象类型

---

## §8 静态 Pod

静态 Pod 由 kubelet 直接根据本地目录中的清单管理，不由 API Server 中的普通控制器创建：

```text
/etc/kubernetes/manifests/
```

kubelet 通过配置中的 `staticPodPath` 定期扫描：

- 文件新增：创建静态 Pod
- 文件修改：重建或更新 Pod
- 文件删除：删除静态 Pod

kubeadm 集群中的控制平面组件通常以静态 Pod 运行。查看：

```bash
ls -l /etc/kubernetes/manifests/
kubectl get pods -n kube-system -o wide
journalctl -u kubelet -f
```

静态 Pod 的镜像或配置异常时，应同时看本地 manifest、kubelet 日志和 `crictl`。

---

## §9 API 观察命令

```bash
kubectl get all
kubectl get deployment,replicaset,pod -o wide
kubectl get <resource> <name> -o yaml
kubectl describe <resource> <name>
kubectl get events --sort-by=.lastTimestamp
kubectl get events -A --sort-by=.lastTimestamp
kubectl explain <resource>
kubectl api-resources
kubectl get --raw='/api'
kubectl get --raw='/apis'
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
```

调试对象关系：

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences}'
kubectl get pod <pod> -o jsonpath='{.spec.nodeName}'
kubectl get pod <pod> -o jsonpath='{.status.conditions}'
```

---

## §10 易错点

1. API Server 是中心入口，但不是所有控制器都直接操作 etcd。
2. Scheduler 只负责调度，不负责启动容器。
3. kubelet 负责节点落实，不负责 Deployment 副本数。
4. `spec` 是期望状态，`status` 是实际状态。
5. Namespace 是逻辑隔离，不是天然安全边界。
6. Label 是标签，Selector 是匹配条件，两者必须相容。
7. Service 通过 Selector 找后端，不是通过 Deployment 名称找后端。
8. 删除 Pod 是否会重建，取决于是否有控制器管理它。
9. 静态 Pod 的源文件在节点本地，不一定有普通的创建控制器。
10. `kubectl get all` 不是“所有资源”的完整列表。

---

## §11 面试追问

### Q1：为什么 API Server 是 Kubernetes 的中心？

它统一提供认证、鉴权、准入、对象校验和 Watch API；控制器、Scheduler、kubelet 等通过它观察和更新集群状态，从而让组件之间解耦。

### Q2：删除 Pod 后为什么会重建？

如果 Pod 属于 Deployment/ReplicaSet 等控制器，控制器观察到实际副本数少于期望副本数，就会创建新的 Pod。

### Q3：Scheduler 和 kubelet 的边界？

Scheduler 决定“在哪个节点运行”；kubelet 负责“在该节点把 Pod 真正运行起来并维护状态”。

### Q4：Kubernetes 的声明式体现在哪里？

用户提交 spec，系统通过控制循环不断把实际状态调整到 spec，而不是要求用户逐条执行创建、重启和修复命令。

---

## §12 与已有知识的链路

- [[Linux进程与负载]]：控制器、kubelet、容器进程和 cgroup
- [[Linux服务与SSH]]：systemd 服务和 kubelet 日志
- [[Linux启动原理]]：静态 Pod 与系统启动
- [[Linux网络]]：API Server、Service、Pod 网络
- [[Linux存储]]：etcd、Volume、PV/PVC 的底层理解
