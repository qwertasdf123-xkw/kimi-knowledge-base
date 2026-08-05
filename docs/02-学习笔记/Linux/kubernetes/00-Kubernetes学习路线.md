---
title: Kubernetes 学习路线与课堂知识地图
desc: 以课堂笔记为基础，将容器运行时、集群安装、核心对象、工作负载、网络、存储、资源、安全和故障排查串成一条复习主线。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0617.md～课堂笔记-0702.md（Markdown课堂资料）
pdf_size: 约 22000 行课堂记录
scope: 方案 A 快速回顾 + 后续架构、命令、故障、面试深化
status: 进行中
---

# Kubernetes 学习路线与课堂知识地图

> **目标**：先快速把课堂学过的 Kubernetes 知识完整过一遍，再进入架构理解、命令强化、故障排查、面试和生产架构设计。
>
> **学习方式**：不重新把 K8s 当成零基础课程，而是使用“知识点回顾 → 最小实验 → 画出关系 → 制造一个故障 → 用命令解释现象”的循环。

## 目录

- [[#§0 总体心智模型：Kubernetes 是控制循环系统]]
- [[#§1 课堂资料覆盖范围]]
- [[#§2 方案 A 快速复习顺序]]
- [[#§3 复习时每个主题都要回答的 7 个问题]]
- [[#§4 实验环境策略：16GB 主机]]
- [[#§5 第一轮复习验收标准]]
- [[#§6 后续深化路线]]
- [[#§7 课堂资料映射]]

---

## §0 总体心智模型：Kubernetes 是控制循环系统

Kubernetes 不是一组孤立的命令，也不只是“运行容器的平台”。它的核心是：

```text
用户提交期望状态
        ↓
API Server 接收并持久化对象（动作）
        ↓
etcd 保存集群状态（执行）
        ↓
Controller 持续对比期望状态与实际状态（watch）
        ↓
Scheduler 为未调度 Pod 选择节点
        ↓
kubelet 在节点上落实 Pod
        ↓
CRI / containerd 创建容器
CNI 配置网络
CSI 提供存储
        ↓
状态回报 API Server
        ↓
控制器继续修正偏差
```

所有后续对象都可以放回这个模型：

| 对象或组件         | 解决的问题                         |
| ------------- | ----------------------------- |
| Pod           | 一组共享网络、存储和生命周期的容器运行单元         |
| Deployment    | 维持无状态应用副本和版本                  |
| StatefulSet   | 维持有稳定身份和稳定存储的副本               |
| DaemonSet     | 保证每个符合条件的节点运行一个 Pod           |
| Job / CronJob | 执行一次性或定时任务                    |
| Service       | 为易变的 Pod 提供稳定访问入口             |
| Ingress       | 根据域名或路径把外部 HTTP 请求转发到 Service |
| PV / PVC      | 把应用存储申请与实际存储资源解耦              |
| HPA           | 根据指标调整副本数                     |
| RBAC          | 决定谁能对哪些资源执行哪些动作               |
| NetworkPolicy | 控制 Pod 网络流量                   |

---

## §1 课堂资料覆盖范围

### 1.1 容器运行时与集群基础

来源：`课堂笔记-0617.md`、`课堂笔记-0622.md`

- Containerd 架构和工作流程
- Containerd namespace
- `ctr` 镜像管理
- `nerdctl` 容器、网络、存储和镜像管理
- `crictl` 的定位和命令
- CNI、CRI、容器运行时的关系
- `br_netfilter`、`overlay`、IPVS 模块
- `net.ipv4.ip_forward`
- `SystemdCgroup`
- 镜像仓库和镜像加速
- kubeadm 集群初始化
- 节点加入
- Calico 网络部署
- kubeconfig、命令补全和基础验证

### 1.2 Pod 与工作负载

来源：`课堂笔记-0624 (1).md`、`课堂笔记-0626.md`

- Pod 创建、查看、编辑、删除
- `kubectl run` 和 YAML
- `exec`、`logs`、`cp`
- 多容器 Pod
- Pod 共享网络和存储
- Pod 关键属性
- 静态 Pod
- ReplicaSet
- Deployment
- 滚动更新和回滚
- DaemonSet
- Job
- CronJob
- WordPress 综合案例

### 1.3 存储和配置

来源：`课堂笔记-0625.md`、`课堂笔记-0702.md`

- `emptyDir`
- `hostPath`
- NFS
- PV / PVC
- Access Modes
- Volume Modes
- 回收策略
- ConfigMap
- Secret
- StorageClass
- Local Path Provisioner
- NFS Provisioner
- 动态卷供应
- StatefulSet
- Nginx、Etcd、Redis、MySQL 等有状态示例

### 1.4 网络与流量

来源：`课堂笔记-0626.md`、`课堂笔记-0629.md`

- Pod IP 的局限
- Service
- ClusterIP
- NodePort
- LoadBalancer
- ExternalName
- Headless Service
- Service 发现：环境变量和 DNS
- 会话保持
- kube-proxy
- iptables 和 IPVS
- Ingress
- ingress-nginx
- 域名、路径和 TLS 规则
- 金丝雀发布基础

### 1.5 资源、弹性和健康

来源：`课堂笔记-0701 (2).md`

- Metrics Server
- `kubectl top`
- HPA
- VPA 概念
- CPU 和内存伸缩
- ResourceQuota
- LimitRange
- requests 和 limits
- QoS
- HTTP、Exec、TCP 探针
- Readiness、Liveness、Startup 的职责边界
- 健康检查对 Service、扩容和滚动更新的影响

### 1.6 认证、授权和可视化

来源：`课堂笔记-0701 (2).md`、`课堂笔记-0702.md`、`课堂笔记-0702 (1).md`

- API 访问控制链路
- TLS 传输安全
- 普通用户和 ServiceAccount
- X.509 客户端证书
- kubeconfig
- Authentication
- Authorization
- Admission
- Audit
- Role / ClusterRole
- RoleBinding / ClusterRoleBinding
- ServiceAccount Token
- Kuboard
- Kubernetes Dashboard

---

## §2 方案 A 快速复习顺序

### 第 1 组：先补底层运行环境

1. [[01-容器运行时与集群安装]]
2. [[02-Kubernetes核心架构与对象模型]]

必须先弄清楚：

```text
kubectl → API Server → etcd / Controller / Scheduler
                                  ↓
                              kubelet
                                  ↓
                       CRI → containerd → 容器
```

### 第 2 组：回顾资源对象

3. [[03-Pod与工作负载]]
4. [[04-配置与安全]]

重点不是背 YAML，而是知道：

```text
Deployment → ReplicaSet → Pod → Container
```

以及：

```text
请求者 → Authentication → Authorization → Admission
```

### 第 3 组：回顾流量和数据

5. [[05-Kubernetes网络与Service]]
6. [[06-Kubernetes存储与StatefulSet]]

需要分别追踪两条链：

```text
客户端 → Ingress → Service → EndpointSlice → Pod
```

```text
Pod → PVC → PV → StorageClass / CSI → 底层存储
```

### 第 4 组：回顾运行质量和运维

7. [[07-调度资源弹性与健康检查]]
8. [[08-Kubernetes命令与故障排查]]

### 第 5 组：回顾表达和架构

9. [[09-Kubernetes面试与架构设计]]

---

## §3 复习时每个主题都要回答的 7 个问题

对每一个对象或组件，不要只写定义，必须回答：

1. 它解决了什么实际问题？
2. 它由谁创建、谁观察、谁维护？
3. 它在 API 中是什么对象？
4. 它的生命周期是什么？
5. 如何用 `kubectl` 或节点命令观察？
6. 出故障时最常见的现象是什么？
7. 面试中如何在 1 分钟内讲清楚？

### 示例：Service

| 问题 | 答案方向 |
|---|---|
| 解决什么问题 | Pod IP 会变化，需要稳定入口和负载分发 |
| 谁维护 | Service Controller、EndpointSlice Controller、kube-proxy 等共同参与 |
| API 对象 | `v1/Service` |
| 生命周期 | 创建 Service → 选择 Pod → 生成 EndpointSlice → kube-proxy 编程转发规则 |
| 如何观察 | `get svc`、`describe svc`、`get endpointslice`、检查节点规则 |
| 常见故障 | Selector 不匹配、端口错误、后端未 Ready、网络策略阻断 |
| 面试表达 | 先讲稳定入口，再讲 Selector、EndpointSlice 和转发路径 |

---

## §4 实验环境策略：16GB 主机

### 常态集群

```text
1 个 Control Plane：2 vCPU / 4GB
1 个 Worker：2 vCPU / 4GB
```

### 按需实验

- 调度、DaemonSet、节点故障时再启动第 2 个 Worker
- 做完实验关闭不需要的虚拟机
- Metrics Server 使用轻量部署
- Prometheus、Grafana、Loki 暂时只学习架构，不强行全部常驻
- HA 控制平面重点理解 quorum、负载均衡、etcd 和证书，不在 16GB 主机上长期运行

### 实验纪律

每个实验完成后记录：

```text
实验目标：
使用的对象：
关键命令：
观察到的状态：
底层发生了什么：
主动制造的故障：
排查路径：
清理命令：
```

---

## §5 第一轮复习验收标准

完成第一轮后，应能不看资料回答：

- Kubernetes 控制平面和 Worker 上分别有哪些组件？
- 一个 Deployment 创建后，Pod 是如何被创建和运行的？
- Pod、容器、Pod Sandbox 的关系是什么？
- Service 如何找到 Pod？
- ClusterIP 是真实网卡地址吗？
- Ingress 和 Service 的职责有什么不同？
- PVC 为什么可能一直 Pending？
- Deployment 和 StatefulSet 的区别是什么？
- Readiness 和 Liveness 的区别是什么？
- HPA 为什么需要 Metrics Server？
- `requests` 和 `limits` 分别影响什么？
- Role 和 ClusterRole 有什么区别？
- 普通用户和 ServiceAccount 的区别是什么？
- Pod Pending、CrashLoopBackOff、Node NotReady 分别怎么查？

---

## §6 后续深化路线

第一轮完成后进入三条并行主线：

### 架构线

- 控制循环
- API Server 请求链路
- Pod 创建链路
- Service 请求链路
- PVC 绑定链路
- 认证授权链路
- 集群升级、备份和高可用

### 命令线

```bash
kubectl get
kubectl describe
kubectl logs
kubectl exec
kubectl events
kubectl explain
kubectl rollout
kubectl auth can-i
kubectl top
crictl
journalctl -u kubelet
ip / ss / nsenter / mount / findmnt
```

### 故障线

- Pod 状态故障
- 网络故障
- 存储故障
- 节点故障
- 资源不足
- 权限故障
- 控制平面故障

---

## §7 课堂资料映射

| 新笔记 | 主要来源 |
|---|---|
| `01-容器运行时与集群安装.md` | 0617、0622 |
| `02-Kubernetes核心架构与对象模型.md` | 0622、0624 |
| `03-Pod与工作负载.md` | 0624、0626 |
| `04-配置与安全.md` | 0625、0701、0702 |
| `05-Kubernetes网络与Service.md` | 0626、0629 |
| `06-Kubernetes存储与StatefulSet.md` | 0625、0702 |
| `07-调度资源弹性与健康检查.md` | 0701 |
| `08-Kubernetes命令与故障排查.md` | 全部课堂笔记 |
| `09-Kubernetes面试与架构设计.md` | 全部课堂笔记 + 深化整理 |

### 相关已有笔记

- [[Linux网络]]
- [[网络基础原理]]
- [[路由与VLAN]]
- [[Linux存储]]
- [[LinuxSELinux]]
- [[Linux进程与负载]]
- [[Linux服务与SSH]]
- [[Linux防火墙]]
- [[shell实战]]
