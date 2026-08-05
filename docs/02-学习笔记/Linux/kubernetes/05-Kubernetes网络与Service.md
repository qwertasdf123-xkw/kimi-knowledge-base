---
title: Kubernetes 网络与 Service
desc: 回顾 Pod 网络、Service 服务发现、ClusterIP、NodePort、LoadBalancer、Headless Service、kube-proxy、iptables/IPVS 和 Ingress。
type: 笔记
module: kubernetes
pdf: 课堂笔记-0626.md、课堂笔记-0629.md（Markdown课堂资料）
pdf_size: 约 4237 行课堂记录
scope: Kubernetes 网络链路、Service 类型、服务发现、kube-proxy、Ingress 与网络故障
status: 完成
---

# Kubernetes 网络与 Service

> **核心理解**：Pod IP 解决 Pod 之间的基本通信，Service 解决 Pod 变化后的稳定访问，Ingress 解决 HTTP/HTTPS 的外部路由。

## 目录

- [[#§0 Kubernetes 网络模型]]
- [[#§1 Pod 网络]]
- [[#§2 Service 的作用]]
- [[#§3 Service 创建与 Selector]]
- [[#§4 Service 发现]]
- [[#§5 Service 类型]]
- [[#§6 EndpointSlice]]
- [[#§7 kube-proxy]]
- [[#§8 iptables 与 IPVS]]
- [[#§9 会话保持]]
- [[#§10 Ingress]]
- [[#§11 金丝雀发布基础]]
- [[#§12 网络排查]]
- [[#§13 易错点]]
- [[#§14 面试追问]]
- [[#§15 与已有知识的链路]]

---

## §0 Kubernetes 网络模型

Kubernetes 网络通常要求：

1. 每个 Pod 都有独立 IP
2. 同一节点 Pod 之间可以通信
3. 不同节点 Pod 之间可以通信
4. Pod 可以访问 Service
5. Pod 可以访问外部网络
6. 节点可以访问 Pod
7. 外部客户端可以通过暴露方式访问 Service

请求链路：

```text
外部客户端
   ↓
LoadBalancer / NodePort / Ingress
   ↓
Service ClusterIP
   ↓
EndpointSlice
   ↓
Pod IP:containerPort
```

集群内部：

```text
Pod A → Service DNS → ClusterIP → kube-proxy 规则 → Pod B
```

---

## §1 Pod 网络

### 1.1 Pod 的网络命名空间

Pod 内多个容器共享：

- IP 地址
- 网络接口
- 端口空间
- 路由

因此同一个 Pod 内的容器通过 `localhost` 通信，但不能监听相同端口。

```bash
kubectl exec -it <pod> -c <container> -- ip addr
kubectl exec -it <pod> -c <container> -- ip route
kubectl exec -it <pod> -c <container> -- cat /etc/resolv.conf
```

### 1.2 CNI

CNI 负责：

- 创建 Pod 网络命名空间
- 创建 veth pair
- 连接节点网桥或 Overlay
- 分配 Pod IP
- 配置路由
- 可能配置网络策略

课堂使用 Calico。不同 CNI 在路由、Overlay、BGP、eBPF、NetworkPolicy 和性能方面有差异。

### 1.3 Pod IP 的局限

Pod 删除或重新调度后 IP 可能变化，因此不能让客户端直接依赖 Pod IP。需要 Service 提供稳定入口。

---

## §2 Service 的作用

Service 是一个稳定的虚拟访问入口，核心功能：

- 稳定的 ClusterIP
- 根据 Selector 发现 Pod
- 把请求负载分发到后端
- 在 Pod 重建后继续找到新后端
- 提供 DNS 名称
- 可以通过 NodePort 或 LoadBalancer 暴露

Service 并不是一个普通的用户进程，也不是“运行在某个 Pod 中的代理”。它主要通过 API 对象和节点上的转发规则实现。

---

## §3 Service 创建与 Selector

### 3.1 Deployment 和 Service

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
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: http
```

### 3.2 三个端口

| 字段 | 含义 |
|---|---|
| `port` | Service 对外提供的端口 |
| `targetPort` | 后端 Pod 端口，可以是数字或端口名 |
| `nodePort` | NodePort 模式下节点监听的端口 |

```text
客户端 → Service:port → Pod:targetPort
节点:nodePort → Service → Pod:targetPort
```

### 3.3 Selector 故障

```bash
kubectl get svc web
kubectl describe svc web
kubectl get endpointslice -l kubernetes.io/service-name=web
kubectl get pods --show-labels
```

如果 Selector 是 `app: web`，而 Pod 只有 `app: nginx`，Service 就没有后端。

---

## §4 Service 发现

### 4.1 环境变量发现

Pod 启动时，kubelet 可以注入当前已存在 Service 的环境变量。它有顺序和时机限制，不适合作为现代应用的主要服务发现方式。

### 4.2 DNS 发现

CoreDNS 为 Service 提供 DNS：

```bash
nslookup web
nslookup web.default.svc.cluster.local
curl http://web.default.svc.cluster.local
```

标准格式：

```text
<service>.<namespace>.svc.<cluster-domain>
```

### 4.3 Pod 内测试

```bash
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- sh
nslookup web.default.svc.cluster.local
wget -qO- http://web
```

如果 DNS 失败，检查：

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl get svc -n kube-system kube-dns
kubectl exec <pod> -- cat /etc/resolv.conf
```

---

## §5 Service 类型

### 5.1 ClusterIP

默认类型，只能从集群内部访问：

```yaml
spec:
  type: ClusterIP
```

ClusterIP 是 Service 的虚拟 IP，不是一个真实网卡地址。访问它时由节点规则把流量转发到后端 Endpoint。

### 5.2 NodePort

```yaml
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

访问方式：

```text
任意节点 IP:30080
```

NodePort 的注意点：

- 节点端口范围通常是 30000–32767，但以集群配置为准
- 每个节点都可能监听该端口
- 节点防火墙必须允许访问
- kube-proxy 负责相应转发

### 5.3 LoadBalancer

在云环境中通常由云控制器创建外部负载均衡器；裸机环境中如果没有对应实现，可能长期没有 External IP。

课堂实验中的 LoadBalancer 需要检查：

```bash
kubectl get svc
kubectl describe svc <name>
```

不要把“创建 Service 成功”误认为“外部负载均衡器已经可用”。

### 5.4 ExternalName

ExternalName 通过 DNS 别名把 Service 映射到集群外域名，不提供普通 ClusterIP 转发：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

### 5.5 Headless Service

```yaml
spec:
  clusterIP: None
```

Headless Service 不提供一个虚拟 ClusterIP，而是通过 DNS 返回后端 Pod 地址，常用于 StatefulSet 的稳定发现。

```text
普通 Service：DNS → ClusterIP
Headless：DNS → Pod IP 列表
```

---

## §6 EndpointSlice

现代 Kubernetes 使用 EndpointSlice 表示 Service 后端端点。它会根据：

- Service Selector
- Pod Label
- Pod Ready 状态
- Pod IP
- 端口

动态更新后端列表：

```bash
kubectl get endpointslice
kubectl get endpointslice \
  -l kubernetes.io/service-name=web -o yaml
```

如果 Pod 进程是 Running 但 Readiness 失败，它可能不会作为可用后端进入 Service 流量路径。

---

## §7 kube-proxy

kube-proxy 观察 Service 和 EndpointSlice，在每个节点上维护转发规则。

常见工作模式：

- iptables
- IPVS
- nftables（取决于版本和配置）
- userspace（旧模式，已不作为现代首选）

检查：

```bash
kubectl get ds kube-proxy -n kube-system
kubectl logs -n kube-system -l k8s-app=kube-proxy
kubectl get cm kube-proxy -n kube-system -o yaml
```

课堂资料通过 kube-proxy 日志判断：

```text
Using iptables Proxier
Using ipvs Proxier
```

---

## §8 iptables 与 IPVS

### 8.1 iptables

iptables 模式通过大量规则完成：

```text
ClusterIP → Service 链 → Endpoint 链 → DNAT 到 Pod IP
```

查看：

```bash
iptables-save | grep KUBE-SVC
iptables-save | grep KUBE-SEP
```

### 8.2 IPVS

IPVS 使用内核中的虚拟服务器和调度算法：

```bash
ipvsadm -Ln
ipvsadm -Ln --stats
```

课堂涉及的调度算法：

- rr：轮询
- wrr：加权轮询
- lc：最少连接
- sh：源地址哈希

### 8.3 模式切换的风险

切换 kube-proxy 模式需要：

1. 确认内核模块
2. 修改 ConfigMap
3. 重启 kube-proxy DaemonSet
4. 检查日志
5. 验证 ClusterIP 和 NodePort
6. 准备回滚配置

```bash
kubectl edit cm kube-proxy -n kube-system
kubectl rollout restart ds/kube-proxy -n kube-system
kubectl rollout status ds/kube-proxy -n kube-system
```

生产环境不要只为“看一下 IPVS”而直接修改系统级配置。

---

## §9 会话保持

Service 默认可能把不同请求分发到不同 Pod。需要基于客户端 IP 的会话保持时：

```yaml
spec:
  sessionAffinity: ClientIP
```

检查：

```bash
kubectl get svc web -o yaml
```

会话保持不是完整的应用会话管理方案；它可能受到 NAT、代理、客户端地址变化和连接复用影响。

---

## §10 Ingress

### 10.1 Ingress 解决什么问题

Service 主要提供四层或基本服务入口；Ingress 为 HTTP/HTTPS 提供：

- 基于域名的路由
- 基于路径的路由
- TLS 终止
- 多个 Service 共享入口
- 部分控制器提供重写、限流和灰度能力

Ingress 对象本身不是转发进程，必须由 Ingress Controller 实现。

### 10.2 Ingress 工作链

```text
客户端
  ↓ DNS
Ingress Controller Service
  ↓
Ingress Controller Pod
  ↓ 读取 Ingress 对象
Service
  ↓
EndpointSlice
  ↓
Pod
```

### 10.3 基础规则

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: nginx
  rules:
    - host: www.example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

### 10.4 TLS

```yaml
spec:
  tls:
    - hosts:
        - www.example.local
      secretName: web-tls
```

需要确认：

- DNS 或 hosts 能解析域名
- Secret 在正确 Namespace
- Ingress Controller 能读取规则
- Controller Service 端口正确
- 后端 Service 有 Endpoint

### 10.5 Ingress 404 排查

```bash
kubectl get ingress
kubectl describe ingress <name>
kubectl get ingressclass
kubectl get pods -n <ingress-ns>
kubectl logs -n <ingress-ns> <controller-pod>
kubectl get svc <backend>
kubectl get endpointslice -l kubernetes.io/service-name=<backend>
```

---

## §11 金丝雀发布基础

金丝雀发布的思想是让一部分请求进入新版本。简单方法可能是：

- 多个 Deployment
- 不同 Label
- 多个 Service 或 Ingress 规则
- 按权重或 Header 路由

仅仅创建两个 Deployment 并不能自动完成可靠的比例流量控制，需要 Ingress Controller、Service Mesh 或发布工具提供能力。

---

## §12 网络排查

### Service 无后端

```bash
kubectl describe svc <svc>
kubectl get pods --show-labels
kubectl get endpointslice -l kubernetes.io/service-name=<svc>
```

检查 Selector、Pod Ready、Namespace、端口。

### Service 有后端但访问失败

```bash
kubectl exec <client-pod> -- nslookup <svc>
kubectl exec <client-pod> -- wget -S -O- http://<svc>:<port>
kubectl exec <client-pod> -- ip route
kubectl describe svc <svc>
```

节点侧：

```bash
iptables-save | grep KUBE
ipvsadm -Ln
ss -lntp
```

### Ingress 访问失败

按顺序：

```text
域名解析
→ Ingress Controller Service
→ Ingress Class
→ Ingress 规则
→ 后端 Service
→ EndpointSlice
→ Pod Ready
→ 容器监听端口
```

### NetworkPolicy

NetworkPolicy 可能阻断：

- 应用到应用
- 应用到 DNS
- Ingress Controller 到后端
- Pod 到外部服务

启用策略后必须明确允许 DNS 和必要的入口流量。

---

## §13 易错点

1. Pod IP 不是稳定服务地址。
2. Service Selector 不匹配时不会有后端。
3. `port` 不是 `targetPort`。
4. NodePort 的外部访问还受节点防火墙影响。
5. LoadBalancer 在裸机上不一定自动产生外部 IP。
6. Headless Service 没有 ClusterIP 是设计如此，不是故障。
7. Ingress 对象没有 Controller 就不会转发流量。
8. Ingress 的后端 Service 和 Ingress 必须在同一 Namespace。
9. Service 有 Endpoint 不代表应用一定能用，还要检查端口和协议。
10. kube-proxy 不负责创建 Pod 网络，CNI 也不等于 Service 转发。
11. 只看 `kubectl get svc` 不能完成网络排查。
12. 课堂中 IPVS 的命令和模式要以实际内核、kube-proxy 版本为准。

---

## §14 面试追问

### Q1：Service 如何发现 Pod？

Service 通过 Selector 选择带有匹配 Label 的 Pod，EndpointSlice Controller 生成后端端点，kube-proxy 根据这些端点维护节点转发规则。

### Q2：ClusterIP 是什么？

它是 Service 的虚拟 IP，不一定对应真实网卡；节点上的转发规则把访问 ClusterIP 的流量转发到后端 Pod。

### Q3：Ingress 和 Service 的职责？

Service 提供稳定服务入口和后端发现；Ingress 负责 HTTP/HTTPS 的域名、路径和 TLS 路由，实际转发由 Ingress Controller 完成。

### Q4：Service 有 ClusterIP 但访问不通怎么查？

先查 DNS，再查 Service Selector 和 EndpointSlice，然后查 Pod Ready、端口、容器监听、kube-proxy/CNI、NetworkPolicy 和节点防火墙。

---

## §15 与已有知识的链路

- [[Linux网络]]：IP、路由、DNS、端口和连接
- [[网络基础原理]]：分层、ARP、以太网和交换
- [[路由与VLAN]]：节点、Pod 网段和路由转发
- [[Linux防火墙]]：iptables、转发和端口
- [[Linux服务与SSH]]：Ingress 后端服务和端口监听
- [[04-配置与安全]]：NetworkPolicy 与 RBAC 的边界
- [[06-Kubernetes存储与StatefulSet]]：Headless Service 和 StatefulSet
- [[08-Kubernetes命令与故障排查]]：网络故障 Runbook
