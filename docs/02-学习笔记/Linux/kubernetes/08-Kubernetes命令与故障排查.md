---
title: Kubernetes 命令与故障排查
desc: 整理 kubectl、crictl、crictl 节点命令、事件和日志、常见 Pod/Service/NetworkPolicy/节点故障的统一排查路径。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0617～0702（Markdown课堂资料）
pdf_size: 综合
scope: Kubernetes 操作命令、底层 Linux 排查命令、典型故障 Runbook
status: 完成
---
 
# Kubernetes 命令与故障排查

> **核心理解**：Kubernetes 故障常常不是“K8s 自己的 bug”，而是“Linux 资源、CNI/CSI 插件、kubelet 配置、对象字段或 RBAC 中的某一条没满足”。命令体系的目的就是把问题快速定位到具体层次。

## 目录

- [[#§0 故障排查总框架]]
- [[#§1 kubectl 核心命令分层]]
- [[#§2 对象观察命令]]
- [[#§3 节点与运行时命令]]
- [[#§4 事件和日志]]
- [[#§5 调度、亲和、污点]]
- [[#§6 资源、Quota、LimitRange]]
- [[#§7 网络与服务发现]]
- [[#§8 存储排查]]
- [[#§9 RBAC 排查]]
- [[#§10 健康检查与 OOM]]
- [[#§11 节点故障]]
- [[#§12 控制平面排查]]
- [[#§13 综合故障 Runbook]]
- [[#§14 命令速查表]]
- [[#§15 易错点]]
- [[#§16 面试追问]]
- [[#§17 与已有知识的链路]]

---

## §0 故障排查总框架

排查固定流程：

```text
1. 现象：什么坏了？影响谁？
2. 范围：单个 Pod / 节点 / Namespace / 集群
3. 层次：API 对象 / 调度 / kubelet / 容器运行时 / 网络 / 存储 / RBAC
4. 命令：分层检查
5. 验证：修复后做一次完整的回归
6. 记录：写一份 Runbook
```

不同问题的常见观察入口：

| 故障 | 观察入口 |
|---|---|
| Pod 状态异常 | `get pod`、`describe pod`、`events` |
| Pod 调度异常 | `describe pod`、`describe node` |
| Service 不通 | `describe svc`、`endpointslice` |
| Ingress 异常 | `get ingress`、`describe ingress`、Controller 日志 |
| 存储异常 | `get pvc,pv`、`describe pvc,pv`、节点挂载 |
| 节点异常 | `get nodes`、`journalctl -u kubelet` |
| 权限异常 | `auth can-i`、`describe role,rolebinding` |
| 认证异常 | `config view`、`get --raw='/version'` |

---

## §1 kubectl 核心命令分层

### 1.1 get/describe

```bash
kubectl get pod <pod> -o wide
kubectl get pod <pod> -o yaml
kubectl describe pod <pod>
```

### 1.2 explain

```bash
kubectl explain pod
kubectl explain pod.spec.containers
```

### 1.3 logs

```bash
kubectl logs <pod>
kubectl logs <pod> -c <container>
kubectl logs <pod> --previous
kubectl logs -f <pod>
```

### 1.4 exec

```bash
kubectl exec -it <pod> -- sh
kubectl exec -it <pod> -c <container> -- sh
kubectl exec <pod> -- printenv
kubectl exec <pod> -- nslookup <svc>
kubectl exec <pod> -- wget -qO- http://<svc>
```

### 1.5 events

```bash
kubectl get events --sort-by=.lastTimestamp
kubectl get events -A --sort-by=.lastTimestamp
```

### 1.6 diff/apply

```bash
kubectl diff -f file.yaml
kubectl apply -f file.yaml
kubectl apply --dry-run=server -f file.yaml
```

### 1.7 rollout

```bash
kubectl rollout status deploy/<name>
kubectl rollout history deploy/<name>
kubectl rollout undo deploy/<name>
kubectl rollout restart deploy/<name>
```

### 1.8 auth

```bash
kubectl auth can-i get pods
kubectl auth can-i create deploy
kubectl auth can-i list pods -n dev
kubectl auth can-i list pods --as=system:serviceaccount:dev:app
kubectl auth can-i --list -n dev
```

### 1.9 top

```bash
kubectl top node
kubectl top pod -A
kubectl top pod -A --sort-by=memory
```

### 1.10 api

```bash
kubectl api-versions
kubectl api-resources
kubectl get --raw='/healthz'
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
```

---

## §2 对象观察命令

```bash
kubectl get deploy,rs,pod
kubectl get deploy -o wide
kubectl get pod --show-labels
kubectl get pod -l app=web
kubectl get all
```

查看对象关系：

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences}'
kubectl get pod <pod> -o jsonpath='{.spec.nodeName}'
kubectl get pod <pod> -o jsonpath='{.status.conditions}'
```

查看注释和注解：

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.annotations}'
kubectl get ingress -A
```

---

## §3 节点与运行时命令

```bash
systemctl status kubelet containerd
journalctl -u kubelet -f
journalctl -u containerd -f
```

容器运行时：

```bash
crictl info
crictl pods
crictl ps -a
crictl images
crictl inspect <container-id>
crictl inspectp <pod-id>
crictl logs <container-id>
crictl exec -it <container-id> sh
```

底层 Linux 命令：

```bash
ip addr
ip route
ss -lntp
mount | grep kubelet
findmnt
df -h
free -h
nproc
uptime
top
```

---

## §4 事件和日志

### 4.1 Kubernetes 事件

```bash
kubectl get events -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl get events --field-selector involvedObject.name=<pod>
```

事件反映：

- 调度决策
- 拉取镜像
- 创建容器
- 探针失败
- 节点失败
- 卷挂载
- 控制器动作

事件保留时间有限，长时间排障需要依赖日志和监控系统。

### 4.2 容器日志

```bash
kubectl logs <pod> -c <container>
kubectl logs <pod> --previous
```

### 4.3 kubelet 日志

```bash
journalctl -u kubelet -f
journalctl -u kubelet --since "10 minutes ago"
```

### 4.4 容器运行时日志

```bash
journalctl -u containerd -f
```

### 4.5 控制平面日志

```bash
kubectl logs -n kube-system kube-apiserver-<node>
kubectl logs -n kube-system kube-scheduler-<node>
kubectl logs -n kube-system kube-controller-manager-<node>
kubectl logs -n kube-system etcd-<node>
```

---

## §5 调度、亲和、污点

```bash
kubectl describe node <node>
kubectl get pod <pod> -o wide
kubectl describe pod <pod>
```

节点信息：

```bash
kubectl describe node <node> | less
```

重点：

- Node Conditions
- Addresses
- Taints
- Allocatable resources
- Allocated resources
- Pod 分布

调度操作：

```bash
kubectl cordon <node>
kubectl uncordon <node>
kubectl drain <node> --ignore-daemonsets
kubectl taint node <node> key=value:NoSchedule
kubectl taint node <node> key=value:NoSchedule-
```

---

## §6 资源、Quota、LimitRange

```bash
kubectl get resourcequota -n <ns>
kubectl describe resourcequota <name> -n <ns>
kubectl get limitrange -n <ns>
kubectl describe limitrange <name> -n <ns>
kubectl top pod -n <ns>
```

OOMKilled 排查：

```bash
kubectl describe pod <pod>
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses}'
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[].state}'
```

---

## §7 网络与服务发现

### 7.1 Service

```bash
kubectl get svc
kubectl describe svc <svc>
kubectl get endpointslice -A
kubectl get endpointslice -l kubernetes.io/service-name=<svc>
```

### 7.2 DNS

```bash
kubectl exec <pod> -- nslookup <svc>
kubectl exec <pod> -- cat /etc/resolv.conf
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### 7.3 节点层

```bash
iptables-save | grep KUBE
ipvsadm -Ln
ipvsadm -Ln --stats
ip route
ss -lntp
```

### 7.4 Ingress

```bash
kubectl get ingress
kubectl describe ingress <name>
kubectl get ingressclass
kubectl logs -n <ingress-ns> <pod>
```

---

## §8 存储排查

```bash
kubectl get pvc,pv
kubectl describe pvc <pvc>
kubectl describe pv <pv>
kubectl get sc
```

挂载和底层：

```bash
mount | grep kubelet
findmnt
df -h
ls -l /var/lib/kubelet/pods/
```

CSI：

```bash
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-pod>
```

---

## §9 RBAC 排查

```bash
kubectl auth can-i get pods -n <ns>
kubectl auth can-i list pods --as=laoma
kubectl auth can-i list pods \
  --as=system:serviceaccount:<ns>:<sa>
kubectl auth can-i --list -n <ns>
```

详细：

```bash
kubectl get role,rolebinding -n <ns>
kubectl describe role <name> -n <ns>
kubectl describe rolebinding <name> -n <ns>
kubectl get clusterrole,clusterrolebinding
```

---

## §10 健康检查与 OOM

```bash
kubectl describe pod <pod>
kubectl get pod <pod> -o yaml
kubectl logs <pod> --previous
```

OOM 关键检查：

- `limits.memory` 是否过小
- 进程实际内存使用
- 节点内存压力
- 是否被内核 OOM Kill
- 节点是否处于驱逐状态

```bash
dmesg -T | grep -i oom
journalctl -k | grep -i oom
```

---

## §11 节点故障

### 11.1 NotReady

```bash
kubectl get nodes
kubectl describe node <node>
journalctl -u kubelet -f
systemctl status kubelet containerd
crictl info
```

常见：

- kubelet 停掉
- 容器运行时异常
- 网络插件未运行
- 节点压力（DiskPressure、MemoryPressure、NetworkUnavailable）
- 系统时间跳变
- 证书过期

### 11.2 节点压力

```bash
df -h
mount | grep ro,
free -h
top
journalctl -u kubelet --since "30 min ago"
```

### 11.3 节点维护

```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
```

drain 前应确保：

- 业务可以在其他节点运行
- 节点上 DaemonSet 允许忽略
- 没有本地数据依赖

### 11.4 节点加入/移除

```bash
kubeadm join ...
kubeadm reset
```

---

## §12 控制平面排查

```bash
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
kubectl get componentstatuses  # 旧版本字段，谨慎解读
```

控制平面 Pod：

```bash
kubectl get pods -n kube-system
kubectl describe pod -n kube-system kube-apiserver-<node>
```

etcd：

```bash
kubectl exec -n kube-system etcd-<node> -- etcdctl member list
kubectl exec -n kube-system etcd-<node> -- etcdctl endpoint status
```

证书：

```bash
kubeadm certs check-expiration
```

---

## §13 综合故障 Runbook

### 13.1 Pod Pending

```text
现象：Pod 一直 Pending
第一步：kubectl describe pod <pod>
       找到 Events 中 FailedScheduling
第二步：检查 requests 是否过大
       检查 nodeSelector、affinity
       检查 tolerations 与节点 Taint
       检查 PVC 是否 Bound
第三步：kubectl describe node
       看 Allocatable 和 Allocated
       确认节点是否有足够资源
第四步：验证 TopologySpread、PriorityClass
```

### 13.2 ImagePullBackOff

```text
现象：Pod 状态 ImagePullBackOff
第一步：kubectl describe pod <pod>
       查看镜像名称、仓库、错误信息
第二步：检查镜像是否存在、tag 是否正确
       检查 Secret（私有仓库）
       检查 DNS
       检查镜像加速
第三步：手动拉取测试
       ctr -n k8s.io images pull <image>
       nerdctl --namespace k8s.io pull <image>
```

### 13.3 CrashLoopBackOff

```text
现象：Pod 不断重启
第一步：kubectl logs <pod> --previous
第二步：kubectl describe pod <pod>
       看 Last State、Exit Code
第三步：检查启动命令、配置、Secret
       检查依赖服务
       检查环境变量
       检查探针是否过严
```

### 13.4 ContainerCreating

```text
现象：Pod 卡在 ContainerCreating
第一步：kubectl describe pod <pod>
第二步：检查镜像
       检查 CNI
       检查 PV/PVC
       检查 RuntimeClass
       检查挂载路径
第三步：节点侧 journalctl -u kubelet -f
```

### 13.5 Service 无后端

```text
现象：访问 Service 超时或无响应
第一步：kubectl get svc
kubectl describe svc <svc>
kubectl get endpointslice -l kubernetes.io/service-name=<svc>
第二步：检查 Selector
       检查 Pod Label
       检查 Pod Ready
       检查 Namespace
第三步：kubectl logs <client-pod>
```

### 13.6 Node NotReady

```text
现象：kubectl get nodes 显示 NotReady
第一步：journalctl -u kubelet -f
       systemctl status kubelet
第二步：检查容器运行时
       systemctl status containerd
       crictl info
第三步：检查网络插件
       kubectl get pods -n kube-system | grep -E 'calico|flannel'
第四步：检查节点压力
       df -h
       free -h
       top
```

### 13.7 Pod 一直 Unknown

```text
现象：kubectl get pod 显示 Unknown
第一步：检查节点是否通信
       kubectl get node
       ssh <node>
第二步：journalctl -u kubelet
第三步：考虑强制删除
       kubectl delete pod <pod> --grace-period=0 --force
```

### 13.8 PVC Pending

```text
现象：PVC 一直 Pending
第一步：kubectl describe pvc <pvc>
第二步：kubectl get sc
       kubectl get pv
第三步：检查 Provisioner
       kubectl get pods -n kube-system
第四步：检查节点调度与 volumeBindingMode
```

### 13.9 RBAC Forbidden

```text
现象：Error from server (Forbidden)
第一步：kubectl auth can-i <verb> <resource> -n <ns>
第二步：kubectl get role,rolebinding -n <ns>
第三步：kubectl auth can-i \
       --as=system:serviceaccount:<ns>:<sa> \
       -n <ns>
```

### 13.10 Ingress 404

```text
现象：访问 Ingress 返回 404
第一步：kubectl get ingress
kubectl describe ingress <name>
第二步：检查 IngressClass
       kubectl get ingressclass
第三步：检查后端 Service
       kubectl get svc
       kubectl get endpointslice
第四步：检查 DNS 解析
       nslookup <host>
第五步：检查 Controller 日志
       kubectl logs -n <ingress-ns> <controller-pod>
```

---

## §14 命令速查表

```bash
# 对象
kubectl get -A
kubectl describe
kubectl logs
kubectl exec
kubectl events
kubectl explain
kubectl api-resources

# 调度
kubectl cordon/uncordon/drain
kubectl taint
kubectl top node/pod

# 弹性
kubectl scale
kubectl autoscale
kubectl get hpa

# 认证
kubectl auth can-i
kubectl auth can-i --list

# 节点运行时
journalctl -u kubelet
crictl pods/ps/images/inspect
ctr -n k8s.io images
nerdctl --namespace k8s.io ps
```

---

## §15 易错点

1. `kubectl get all` 不是全部资源。
2. 节点 NotReady 时 Pod 会变 Unknown，需要一段时间才重新调度。
3. Pod 删除不是立即成功，存在 Grace Period。
4. `kubectl logs` 不一定能拿到之前容器日志，需要 `--previous`。
5. kubectl 与 crictl 不是同一层次。
6. `kubectl describe` 中 Events 是诊断入口。
7. Service 有 ClusterIP 不代表能访问。
8. PVC Bound 不代表能使用。
9. RBAC Forbidden 不一定是权限不够，也可能是身份不对。
10. metrics-server 不工作会让 HPA 和 kubectl top 异常。
11. 控制平面异常时，kubectl 可能都连不上。
12. `kubectl delete --force` 不等于立即成功。

---

## §16 面试追问

### Q1：Pod 一直 Pending 怎么排查？

先 `describe pod` 看 Events，再看节点资源、亲和性、污点、requests、PVC 状态和 TopologySpread。

### Q2：Service 有 ClusterIP 但访问不通？

查 DNS、Selector、EndpointSlice、Pod Ready、容器端口、kube-proxy/CNI、NetworkPolicy 和节点防火墙。

### Q3：Node NotReady 怎么查？

`journalctl -u kubelet`，`systemctl status containerd`，`crictl info`，节点资源和网络插件，节点压力。

### Q4：RBAC Forbidden 怎么查？

`kubectl auth can-i`、Role/ClusterRole、RoleBinding/ClusterRoleBinding，确认身份、资源、verbs 和 Namespace。

---

## §17 与已有知识的链路

- [[Linux网络]]：网络故障和接口命令
- [[Linux防火墙]]：节点端口和转发
- [[Linux存储]]：挂载和存储
- [[Linux服务与SSH]]：服务状态和日志
- [[Linux进程与负载]]：资源压力和 OOM
- [[Linux启动原理]]：系统启动和服务
- [[LinuxSELinux]]：挂载和文件访问
- [[01-容器运行时与集群安装]]
- [[02-Kubernetes核心架构与对象模型]]
- [[03-Pod与工作负载]]
- [[04-配置与安全]]
- [[05-Kubernetes网络与Service]]
- [[06-Kubernetes存储与StatefulSet]]
- [[07-调度资源弹性与健康检查]]
