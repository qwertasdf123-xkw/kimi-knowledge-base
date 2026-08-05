---
title: Pod 与 Kubernetes 工作负载
desc: 回顾 Pod 生命周期、多容器 Pod、静态 Pod、ReplicaSet、Deployment、DaemonSet、Job、CronJob、探针和滚动更新。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0624 (1).md、课堂笔记-0626.md（Markdown课堂资料）
pdf_size: 约 3900 行课堂记录
scope: Pod 与常见控制器的概念、YAML、命令、生命周期、更新和故障
status: 完成
---

# Pod 与 Kubernetes 工作负载

> **核心理解**：Pod 是 Kubernetes 调度和管理的最小运行单元；控制器负责让一组 Pod 的实际数量、版本和位置符合期望状态。

## 目录

- [[#§0 Pod 的心智模型]]
- [[#§1 Pod 与容器]]
- [[#§2 Pod 创建与观察]]
- [[#§3 Pod 生命周期和重启策略]]
- [[#§4 多容器 Pod]]
- [[#§5 Pod 关键属性]]
- [[#§6 静态 Pod]]
- [[#§7 ReplicaSet]]
- [[#§8 Deployment]]
- [[#§9 DaemonSet]]
- [[#§10 Job 与 CronJob]]
- [[#§11 探针]]
- [[#§12 工作负载选择]]
- [[#§13 易错点]]
- [[#§14 面试追问]]
- [[#§15 与已有知识的链路]]

---

## §0 Pod 的心智模型

```text
Pod = 共享网络 + 共享存储 + 共同生命周期的一组容器
```

Pod 不是虚拟机，也不是单纯的容器包装名。它是 Kubernetes 调度、网络和生命周期管理的边界。

```text
一个 Pod
  ├── pause / Pod Sandbox
  ├── 主应用容器
  ├── 可选 sidecar 容器
  ├── 共享 network namespace
  └── 共享 volume
```

Pod 的常见特点：

- 一个 Pod 可以只有一个容器，也可以包含多个容器
- Pod 内的容器总是被调度到同一节点
- Pod 内的容器共享 IP 和端口空间
- Pod 内的容器可以使用 `localhost` 互相通信
- Pod 内的容器可以共享 Volume
- Pod IP 通常是临时的，不应作为长期服务入口

---

## §1 Pod 与容器

### 1.1 为什么 Kubernetes 管理 Pod 而不是直接管理容器

容器只描述进程运行环境；业务应用还需要：

- 网络身份
- 存储挂载
- 进程协作
- 探针
- 资源限制
- 生命周期
- 调度边界

Pod 把这些资源组合成一个可以被 Kubernetes 调度和维护的单元。

### 1.2 多容器的适用条件

适合放在同一 Pod 的容器通常具有：

- 强耦合生命周期
- 需要共享网络
- 需要共享文件
- 共同扩缩容
- 必须部署在同一节点

例如：

```text
主应用容器：提供业务服务
sidecar：采集日志、代理流量或同步文件
```

如果两个服务需要独立扩缩容、独立发布或独立故障隔离，应拆成不同 Pod。

### 1.3 pause 容器

Pod Sandbox 为 Pod 提供稳定的网络命名空间。应用容器加入这个网络命名空间，因此多个容器可以共享 Pod IP 和端口空间。

查看底层对象：

```bash
kubectl get pod <pod> -o wide
crictl pods
crictl ps -a
```

---

## §2 Pod 创建与观察

### 2.1 `kubectl run`

快速创建：

```bash
kubectl run web --image=nginx
kubectl get pod web -o wide
kubectl describe pod web
kubectl logs web
```

只生成 YAML：

```bash
kubectl run web --image=nginx --dry-run=client -o yaml > web.yaml
```

### 2.2 最小 YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: web
      image: nginx:1.27
      ports:
        - name: http
          containerPort: 80
```

创建和验证：

```bash
kubectl apply -f web.yaml
kubectl get pod web -o wide
kubectl get pod web -o yaml
kubectl describe pod web
kubectl get events --sort-by=.lastTimestamp
```

### 2.3 Pod 内执行命令

```bash
kubectl exec -it web -- sh
kubectl exec web -- nginx -t
kubectl exec web -- printenv
kubectl logs -f web
kubectl cp web:/etc/nginx/nginx.conf ./nginx.conf
kubectl cp ./index.html web:/usr/share/nginx/html/index.html
```

多容器 Pod 必须指定容器：

```bash
kubectl exec -it <pod> -c <container> -- sh
kubectl logs <pod> -c <container>
```

### 2.4 编辑和删除

```bash
kubectl edit pod web
kubectl delete pod web
kubectl delete -f web.yaml
```

Pod 的很多字段不可变。需要改变不可变字段时，通常重新生成 YAML 或由 Deployment 管理滚动替换。

---

## §3 Pod 生命周期和重启策略

### 3.1 常见状态

| 状态 | 含义 |
|---|---|
| `Pending` | 已创建但尚未完成调度或运行准备 |
| `ContainerCreating` | 正在创建 Sandbox、拉镜像、配网络或挂载卷 |
| `Running` | 至少一个容器正在运行 |
| `Succeeded` | 所有容器成功退出 |
| `Failed` | 至少一个容器失败退出且不会继续运行 |
| `Unknown` | 节点或 kubelet 无法报告状态 |
| `Terminating` | 对象正在删除，等待容器、卷或 Finalizer 处理 |

注意：`Running` 不等于业务可用，必须结合 `Ready` 和探针。

### 3.2 RestartPolicy

常见值：

- `Always`：退出后总是重启，Deployment 常见
- `OnFailure`：失败时重启，Job 常见
- `Never`：不重启，适合一次性实验

### 3.3 常见异常

```text
Pending
  ├── 没有可用节点
  ├── requests 过大
  ├── Taint / Affinity 不匹配
  └── PVC 未绑定

ContainerCreating
  ├── 镜像拉取
  ├── CNI 配网
  ├── Volume 挂载
  └── Pod Sandbox

CrashLoopBackOff
  ├── 进程启动后立即退出
  ├── 启动命令错误
  ├── 配置或 Secret 缺失
  ├── 探针失败导致重启
  └── 依赖服务不可用
```

排查：

```bash
kubectl describe pod <pod>
kubectl logs <pod>
kubectl logs <pod> --previous
kubectl get events --sort-by=.lastTimestamp
```

---

## §4 多容器 Pod

示例：应用容器和共享文件的 sidecar：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
spec:
  volumes:
    - name: shared-data
      emptyDir: {}
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: shared-data
          mountPath: /usr/share/nginx/html
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c"]
      args:
        - while true; do date >> /data/index.html; sleep 5; done
      volumeMounts:
        - name: shared-data
          mountPath: /data
```

特点：

- 两个容器共享 Pod IP
- 不能监听同一个端口
- 共享同一个 Volume
- Pod 的 Ready 通常受所有必要容器状态影响
- 任一容器异常，可能影响整个 Pod 的可用性

---

## §5 Pod 关键属性

### metadata

```yaml
metadata:
  name: web
  namespace: default
  labels:
    app: web
  annotations:
    description: demo
```

### spec 常见字段

```yaml
spec:
  restartPolicy: Always
  nodeName: worker1
  nodeSelector:
    kubernetes.io/os: linux
  serviceAccountName: default
  containers:
    - name: web
      image: nginx
      command: ["nginx"]
      args: ["-g", "daemon off;"]
      ports:
        - containerPort: 80
      env:
        - name: APP_ENV
          value: test
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
```

### imagePullPolicy

- `Always`
- `IfNotPresent`
- `Never`

实际策略受镜像 tag、是否为 `latest` 和运行时缓存影响。

### command 与 args

```text
command：覆盖镜像 ENTRYPOINT
args：覆盖镜像 CMD
```

启动命令错误是 `CrashLoopBackOff` 的高频原因。

### DNS Policy

默认常见为 `ClusterFirst`。Pod 内的 `/etc/resolv.conf` 通常指向集群 DNS：

```bash
kubectl exec -it <pod> -- cat /etc/resolv.conf
kubectl exec -it <pod> -- nslookup kubernetes.default
```

---

## §6 静态 Pod

静态 Pod 由 kubelet 直接读取本地 manifest 管理，常见目录：

```bash
ls /etc/kubernetes/manifests/
```

kubeadm 控制平面通常包含：

- kube-apiserver
- kube-controller-manager
- kube-scheduler
- etcd

修改静态 Pod manifest 时，kubelet 会检测变化并重建。排查时同时看：

```bash
journalctl -u kubelet -f
crictl pods
crictl ps -a
kubectl get pod -n kube-system
```

---

## §7 ReplicaSet

ReplicaSet 的目标是维持符合 Selector 的 Pod 数量：

```yaml
apiVersion: apps/v1
kind: ReplicaSet
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
          image: nginx:1.27
```

ReplicaSet 的控制循环：

```text
实际 Pod 数 < replicas → 创建 Pod
实际 Pod 数 > replicas → 删除多余 Pod
```

ReplicaSet 通常不直接用于发布，因为它不提供版本滚动更新；Deployment 会管理 ReplicaSet。

---

## §8 Deployment

### 8.1 结构

```text
Deployment
  ├── ReplicaSet v1
  │     └── Pod v1
  └── ReplicaSet v2
        └── Pod v2
```

Deployment 的核心能力：

- 副本管理
- 滚动更新
- 暂停和恢复发布
- 回滚
- 发布历史
- 扩缩容

### 8.2 创建

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
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
```

### 8.3 常用命令

```bash
kubectl get deploy,rs,pod
kubectl scale deployment web --replicas=5
kubectl set image deployment/web web=nginx:1.28
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout pause deployment/web
kubectl rollout resume deployment/web
kubectl rollout undo deployment/web
kubectl rollout undo deployment/web --to-revision=1
```

### 8.4 更新流程

```text
修改 Pod Template
  ↓
Deployment 创建新 ReplicaSet
  ↓
新 ReplicaSet 逐步创建 Pod
  ↓
旧 ReplicaSet 逐步减少 Pod
  ↓
新 Pod Ready 后继续推进
```

如果没有 Readiness Probe，控制器可能在应用还不能接收请求时就把它当成可用 Pod，造成发布中断。

---

## §9 DaemonSet

DaemonSet 的目标是：每个符合条件的节点运行一个 Pod。典型场景：

- CNI Agent
- kube-proxy
- 日志采集
- 节点监控
- 存储 Agent

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
```

关键点：

- 新节点加入后会自动创建 Pod
- 节点不符合 Selector、Taint 或条件时可能不创建
- 控制平面节点常有 `NoSchedule` 污点
- DaemonSet Pod 不一定会因为 `kubectl drain` 被普通方式驱逐

```bash
kubectl get ds -A
kubectl describe ds <name>
kubectl get pods -l app=node-agent -o wide
kubectl taint nodes <node> key=value:NoSchedule
kubectl taint nodes <node> key=value:NoSchedule-
```

---

## §10 Job 与 CronJob

### Job

Job 目标是让任务成功完成指定次数：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  backoffLimit: 3
  completions: 1
  parallelism: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: task
          image: busybox:1.36
          command: ["sh", "-c", "echo done; exit 0"]
```

重要字段：

- `completions`：需要成功完成几次
- `parallelism`：同时运行几个 Pod
- `backoffLimit`：失败重试次数
- `activeDeadlineSeconds`：最长运行时间
- `restartPolicy`：通常 `Never` 或 `OnFailure`

删除 Job：

```bash
kubectl delete job batch-job
```

默认会级联删除它管理的 Pod；需要保留子对象时要谨慎使用级联策略。

### CronJob

CronJob 按 Cron 表达式定时创建 Job：

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: busybox:1.36
              command: ["sh", "-c", "date; echo backup"]
```

常见并发策略：

- `Allow`
- `Forbid`
- `Replace`

排查：

```bash
kubectl get cronjob
kubectl get job --sort-by=.metadata.creationTimestamp
kubectl get pod --show-labels
kubectl describe cronjob <name>
```

---

## §11 探针

### 11.1 三类探针

| 探针 | 作用 | 失败后的典型动作 |
|---|---|---|
| Startup | 判断应用是否完成启动 | 启动期间暂缓其他探针 |
| Readiness | 判断是否接收流量 | 从 Service Endpoint 中移除 |
| Liveness | 判断是否需要重启容器 | kubelet 重启容器 |

### 11.2 HTTP 探针

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

### 11.3 Exec 探针

```yaml
livenessProbe:
  exec:
    command:
      - sh
      - -c
      - test -f /tmp/healthy
  periodSeconds: 10
```

### 11.4 TCP 探针

```yaml
readinessProbe:
  tcpSocket:
    port: 8080
  periodSeconds: 5
```

### 11.5 探针故障排查

```bash
kubectl describe pod <pod>
kubectl logs <pod>
kubectl exec <pod> -- curl -f http://127.0.0.1:8080/healthz
```

### 11.6 没有探针的风险

- Pod 进程存在但业务已经不可用
- Service 继续转发到坏实例
- 滚动更新过早推进
- HPA 可能对错误的工作状态作出判断

---

## §12 工作负载选择

| 需求 | 选择 |
|---|---|
| 无状态 Web/API | Deployment |
| 每节点一个 Agent | DaemonSet |
| 一次性批处理 | Job |
| 定时任务 | CronJob |
| 稳定名称和存储 | StatefulSet |
| 临时调试 | 直接 Pod |
| 控制平面静态组件 | Static Pod |

### Deployment vs StatefulSet

| 维度 | Deployment | StatefulSet |
|---|---|---|
| Pod 名称 | 随机后缀 | 稳定序号 |
| 网络身份 | 通常不稳定 | 可通过 Headless Service 稳定发现 |
| 存储 | 通常共享或无状态 | 每个 Pod 可有独立 PVC |
| 启停顺序 | 通常不强调 | 支持有序创建和删除 |
| 适合 | Web、API | 数据库、Etcd、Redis 等 |

---

## §13 易错点

1. Pod 是调度单元，不等于容器。
2. Pod IP 会变化，不要把它当成服务入口。
3. 多容器 Pod 共享端口空间，不能监听同一个端口。
4. `Running` 不等于 `Ready`。
5. 删除 Deployment 管理的 Pod 会触发重建。
6. Deployment 更新的是 Pod Template，不能只修改现有 Pod 期待永久生效。
7. DaemonSet 是按节点，不是按副本总数。
8. Job 的 Pod 通常不能设置 `restartPolicy: Always`。
9. CronJob 可能因为并发策略产生或跳过 Job。
10. Liveness 不是“应用是否可接流量”的判断，Readiness 才负责流量资格。
11. Startup Probe 适合慢启动应用，不能简单用更大的 `initialDelaySeconds` 替代所有情况。
12. 探针路径、端口和容器实际监听地址必须一致。

---

## §14 面试追问

### Q1：Pod 为什么是最小调度单元？

因为 Pod 中的容器共享网络、存储和生命周期，需要共同被放置到同一节点，Kubernetes 因此把 Pod 作为调度和管理边界。

### Q2：Deployment 如何实现滚动更新？

修改 Pod Template 后创建新 ReplicaSet，逐步增加新版本 Pod、减少旧版本 Pod，并通过可用副本和策略控制更新速度。

### Q3：Readiness 和 Liveness 有什么区别？

Readiness 失败表示暂时不能接收流量，Pod 会从 Service 后端移除；Liveness 失败表示容器可能已经失活，kubelet 会重启容器。

### Q4：StatefulSet 为什么适合数据库？

它提供稳定的 Pod 名称、稳定网络身份、稳定存储绑定和可控的创建删除顺序。

---

## §15 与已有知识的链路

- [[Linux进程与负载]]：Pod 内进程、重启和资源
- [[Linux服务与SSH]]：systemd 服务和探针思想
- [[Linux存储]]：Volume、挂载和持久化
- [[Linux网络]]：Pod 网络、端口和 DNS
- [[LinuxShell]]：Job、CronJob 和批量运维
- [[01-容器运行时与集群安装]]：kubelet、Containerd、CRI
- [[02-Kubernetes核心架构与对象模型]]：控制器和对象关系
- [[06-Kubernetes存储与StatefulSet]]：StatefulSet 的存储实现
- [[05-Kubernetes网络与Service]]：Pod 对外提供服务

---

## 课堂实验回顾

- `kubectl run` 生成和创建 Pod
- `get`、`describe`、`logs`、`exec`、`cp`
- 多容器 Pod 共享 Volume
- WordPress + MySQL 基础案例
- ReplicaSet 删除 Pod 后自动重建
- Deployment 更新镜像、查看历史、回滚
- Worker 节点故障后的副本恢复
- DaemonSet 节点覆盖
- Job 失败重试
- CronJob 定时运行
- HTTP、Exec、TCP 三种健康检查

---

## 课堂资料中的编辑工具

课堂还使用 PyCharm 编写 Kubernetes YAML。工具不是重点，重点是：

- YAML 缩进正确
- `apiVersion`、`kind`、`metadata`、`spec` 层级清晰
- 先使用 `kubectl apply --dry-run=server -f file.yaml`
- 再正式 `kubectl apply -f file.yaml`
- 创建后一定用 `get`、`describe`、`events` 验证

```bash
kubectl apply --dry-run=client -f file.yaml
kubectl apply --dry-run=server -f file.yaml
kubectl diff -f file.yaml
kubectl apply -f file.yaml
```
