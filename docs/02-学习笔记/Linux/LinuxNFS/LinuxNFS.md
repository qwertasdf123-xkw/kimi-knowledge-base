---
title: Linux NFS 服务器
desc: NFS 原理 + RPC + /etc/exports + showmount + mount + autofs + NFSv4 + 性能调优
type: 笔记
module: LinuxNFS
pdf: NFS 服务器.pdf
pdf_size: 0.5 MB
scope: NFS 协议原理 + 服务端配置 + 客户端挂载 + autofs + NFSv4 + 性能优化
status: 完成
---

# Linux NFS 服务器

> **来源**：`NFS 服务器.pdf`（约 0.5 MB，7 页）与 Linux/RHEL 实战补充。
> **环境**：示例以 CentOS 7 / RHEL 系为主；不同发行版的 unit、默认端口和选项以本机 `man` 手册为准。
> **安全声明**：示例默认用于受控内网；生产环境请使用最小权限、白名单、防火墙与审计。

## 目录

- [[#§0 心智模型：NFS = 网络文件系统]]
- [[#§1 NFS 是什么：Network File System]]
- [[#§2 NFS 版本演进：v2 / v3 / v4 / v4.1]]
- [[#§3 RPC 原理：rpcbind + 动态端口]]
- [[#§4 NFS 服务端部署：nfs-utils 与启动顺序]]
- [[#§5 /etc/exports 配置详解：路径、客户端与选项]]
- [[#§6 exports 客户端选项：权限与一致性]]
- [[#§7 exportfs 命令：不重启服务管理导出]]
- [[#§8 showmount 命令：查看服务端共享清单]]
- [[#§9 NFS 客户端挂载：mount + fstab]]
- [[#§10 mount 选项：可靠性、性能与语义]]
- [[#§11 autofs 自动挂载：按需触发]]
- [[#§12 NFSv4 特性：单端口、复合操作与伪文件系统]]
- [[#§13 NFS 性能调优：先测量，再改变]]
- [[#§14 NFS 与防火墙：按版本放行]]
- [[#§15 NFS 安全：最小权限、Kerberos 与 ACL]]
- [[#§16 NFS 故障排查：从网络到权限]]
- [[#§17 易错点 ×10：记住这些就少走弯路]]
- [[#§18 速查表：端口、路径与命令]]
- [[#§19 面试 6 大追问：从原理讲到实战]]

---

## §0 心智模型：NFS = 网络文件系统

> **一句话**：NFS 把服务端目录导出，让客户端把它挂载到本地路径；用户看到的是本地目录，数据实际走网络到服务端。

```text
应用 / 用户进程
      │ open/read/write（像操作本地文件）
      ▼
客户端 VFS → NFS 客户端模块 → RPC 请求 → TCP/UDP
                                      │
                                      ▼
服务端 rpcbind 负责“问路” + nfsd 负责“办事” → 服务端文件系统
```

- **服务端**保存真实数据，配置 `/etc/exports` 决定哪些客户端可以访问。
- **客户端**安装 `nfs-utils`，通过 `mount -t nfs` 或 `autofs` 建立访问入口。
- **rpcbind**（旧名 portmapper）登记 RPC 程序与端口，像电话簿；客户端先查询，再访问 NFS 服务。
- **nfsd** 是内核 NFS 服务线程，真正处理文件句柄、读写、属性和锁请求。
- **mountd** 负责传统 NFS 的挂载授权；`exportfs` 管理当前导出表。
- **NFSv3** 的服务可能分散在 2049、mountd、lockd、statd 等多个端口。
- **NFSv4** 将主要协议固定到 TCP/UDP 2049，并通过伪文件系统组织导出树。
- 读写权限是三层叠加：导出规则、服务端 Unix 权限/ACL、客户端身份映射。
- `root_squash` 默认把远端 root 映射为匿名用户，避免客户端 root 直接获得服务端 root 权限。
- 网络文件系统不是备份：删除、损坏和误写会实时反映到所有挂载客户端。

**记忆比喻**：`/etc/exports` 是前台登记表，`rpcbind` 是电话总机，`nfsd` 是仓库管理员，客户端挂载点是用户手里的“仓库门”。

**排障起点**：先确认链路，再确认端口，再确认导出，再确认挂载，再确认 Unix 权限；不要一上来反复执行 `mount`。

## §1 NFS 是什么：Network File System

### 1.1 定义与来源

- NFS 全称 **Network File System**，中文通常译为网络文件系统。
- 20 世纪 80 年代由 Sun Microsystems 推出，最初解决 UNIX 主机之间共享文件的问题。
- NFS 采用客户端/服务器（C/S）模型，客户端通过协议访问服务端目录。
- 挂载成功后，应用通常无需知道文件存储在哪台机器上。
- Linux、UNIX、macOS 等系统普遍支持 NFS；Windows 也可通过 NFS 客户端访问。
- NFS 不等于 FTP：FTP 传输文件，NFS 提供可挂载的远程文件系统语义。
- NFS 不等于 SMB：NFS 更贴近 UNIX 权限和 POSIX 语义，SMB 更常见于 Windows 生态。

### 1.2 C/S 角色

| 角色       | 主要职责             | 常见组件                           |
| -------- | ---------------- | ------------------------------ |
| NFS 服务端  | 保存数据、导出目录、执行读写   | `nfs-server`、`nfsd`、`exportfs` |
| NFS 客户端  | 查询共享、挂载目录、发起 I/O | `nfs-utils`、NFS 内核模块           |
| RPC 注册服务 | 记录 RPC 程序和端口     | `rpcbind`                      |
| 名称解析     | 把主机名解析为 IP       | DNS、`/etc/hosts`               |
| 防火墙      | 放行必要服务端口         | firewalld、nftables             |

### 1.3 优势与边界

- 优势：透明、跨平台、集中存储、便于多台 Web 节点共享静态资源。
- 优势：服务端统一管理文件，客户端无需复制多份数据。
- 优势：配合自动挂载可以按需建立连接，减少开机等待。
- 局限：性能受网络延迟、带宽、服务端磁盘和锁竞争影响。
- 局限：早期版本的认证和加密能力有限，不宜直接暴露在公网。
- 局限：客户端 UID/GID 与服务端不一致时，权限显示可能令人困惑。
- 局限：网络中断时，正在访问的进程可能阻塞；`soft` 也可能引发数据损坏。

### 1.4 典型场景

1. Web 集群共享上传文件或静态资源。
2. 计算集群共享输入数据和输出结果。
3. 虚拟化或容器环境提供共享目录（需评估锁与一致性）。
4. 集中式用户家目录（应配合统一身份管理）。
5. Linux 主机之间的构建产物、安装包和归档共享。

## §2 NFS 版本演进：v2 / v3 / v4 / v4.1

### 2.1 版本对比

| 版本 | 主要特征 | 传输与端口 | 适用提示 |
|---|---|---|---|
| NFSv2 | 早期、文件大小与协议能力有限 | TCP/UDP；依赖 RPC | 仅用于兼容旧系统 |
| NFSv3 | 无状态、64 位文件大小、异步写与更丰富错误码 | TCP/UDP；多个 RPC 端口 | 传统 CentOS 环境常见 |
| NFSv4 | 有状态、复合操作、ACL、锁整合、单一端口 | 默认 TCP 2049 | 新部署优先考虑 |
| NFSv4.1 | 会话、并行 NFS（pNFS）、客户端委派改进 | TCP 2049 等 | 高性能或大规模场景 |
| NFSv4.2 | 服务器端复制、稀疏文件等扩展 | 依赖实现 | 检查双方版本支持 |

### 2.2 v2/v3 与 v4 的关键差异

- v2/v3 对客户端提供无状态文件操作，故障恢复模型相对简单。
- v3 支持大文件和 64 位偏移，已明显超过 v2 的限制。
- v3 挂载时常需 `mountd`；锁服务和状态服务也可能使用独立 RPC 端口。
- v4 把挂载、锁和主要文件操作纳入统一协议体系，防火墙策略更简单。
- v4 使用伪根（pseudo root）把多个导出目录组织成一棵命名空间。
- v4 引入复合操作，一次 RPC 可携带多个操作，降低往返次数。
- v4 支持 `sec=krb5`、`sec=krb5i`、`sec=krb5p` 等 Kerberos 安全模式。
- v4 的状态化能力带来更完整的锁与委派，也需要更严谨的恢复处理。

### 2.3 版本选择原则

- 新环境优先 `vers=4.1`（双方支持时），明确写出版本便于复现。
- 老旧设备或特定应用不兼容时，再退回 `vers=3`。
- 不要只因为“v4 端口少”就忽略身份、ACL、DNS 和 Kerberos 依赖。
- 用 `nfsstat -m`、`mount` 或 `/proc/mounts` 核对最终生效版本。
- 版本不匹配时常见错误是 `mount.nfs: Protocol not supported`。
- `showmount -e` 主要面向传统 mountd；NFSv4 场景不应只依赖它判断导出。

```bash
mount -t nfs -o vers=4.1,proto=tcp nfs-server:/srv/nfs/web /mnt/web
mount -t nfs -o vers=3,proto=tcp nfs-server:/shares/webapp /mnt/web
```

## §3 RPC 原理：rpcbind + 动态端口

### 3.1 为什么需要 RPC

- NFS 操作发生在远端，客户端需要调用服务端的“远程过程”。
- RPC 将远程调用封装为请求/响应，使上层 NFS 不必自行设计每个连接细节。
- 客户端根据 RPC 程序号查询服务端当前端口，再发起 NFS 请求。
- `rpcbind` 监听 TCP/UDP 111，维护程序号、版本、协议和端口的映射。
- 传统 NFSv3 的 `mountd`、`nlockmgr`、`status` 端口可能动态分配。
- 动态端口方便服务启动，但给防火墙和审计带来额外配置工作。

### 3.2 典型流程

```text
1. rpcbind 启动并监听 111
2. nfs-server / mountd / lockd / statd 向 rpcbind 注册
3. 客户端 rpcinfo 或 mount 查询程序端口
4. 客户端调用 mountd 请求文件句柄
5. 客户端用文件句柄访问 nfsd 的 2049
6. 需要锁时，再与锁/状态 RPC 协作
```

### 3.3 查询与验证

```bash
systemctl status rpcbind nfs-server
rpcinfo -p nfs-server
rpcinfo -t nfs-server nfs 4
ss -lntup | grep -E ':(111|2049)\\b'
```

| 程序 | 用途 | 常见端口 |
|---|---|---|
| `rpcbind` | RPC 端口映射 | 111/TCP、111/UDP |
| `nfs` | 文件操作 | 2049/TCP、2049/UDP |
| `mountd` | 传统挂载授权 | 动态或管理员固定 |
| `nlockmgr` | 网络锁 | 动态或管理员固定 |
| `status` | NSM 状态通知 | 动态或管理员固定 |

### 3.4 v4 的变化

- NFSv4 主要服务固定在 2049，通常不需要为 mountd 单独开放客户端挂载端口。
- `rpcbind` 仍可能因系统服务和兼容工具存在，不要未经验证就停用。
- 生产环境应按实际启用版本配置防火墙，而非照搬所有端口。
- 修改动态端口前先查发行版文档和 `/etc/nfs.conf`，避免重启后配置失效。

## §4 NFS 服务端部署：nfs-utils 与启动顺序

### 4.1 规划示例

| 节点 | 地址 | 角色 |
|---|---|---|
| `nfs-server` | `10.1.8.20/24` | 提供共享存储 |
| `nfs-client1` | `10.1.8.21/24` | NFS 客户端 |
| `nfs-client2` | `10.1.8.22/24` | NFS 客户端 |

### 4.2 安装与目录准备

```bash
yum install -y nfs-utils
mkdir -p /shares/webapp
chown apache:apache /shares/webapp
chmod 0755 /shares/webapp
```

- `nfs-utils` 提供服务端工具、客户端工具和 systemd 单元。
- 不要把服务端目录直接设成 `0777` 来“解决”权限问题。
- 先确定磁盘挂载点，再在其下创建导出目录，避免把根文件系统意外导出。
- 目录上已有数据时，先备份 `/etc/exports` 和权限信息。

### 4.3 启动顺序

```bash
systemctl enable --now rpcbind
systemctl enable --now nfs-server
systemctl is-active rpcbind nfs-server
exportfs -rav
```

- 某些发行版的 `nfs-server` unit 会拉起依赖，但显式启动 `rpcbind` 更易理解。
- 生产环境应先配置 `/etc/exports`，再 reload/exportfs。
- `systemctl reload nfs-server` 只重读配置，不中断已建立的客户端连接（具体行为看发行版）。
- `systemctl restart` 影响更大，故障处理中优先使用 `exportfs -r` 或 reload。

### 4.4 基线检查

```bash
systemctl status nfs-server --no-pager
journalctl -u nfs-server -b --no-pager
exportfs -s
rpcinfo -p localhost
findmnt -T /shares/webapp
```

- 看到 `active (running)` 不代表共享已经正确导出，必须检查 `exportfs -s`。
- 共享目录所在文件系统必须已挂载且可读写。
- 如使用 SELinux，确认上下文允许 NFS 服务访问，并保留 SELinux 开启。

## §5 /etc/exports 配置详解：路径、客户端与选项

### 5.1 基本语法

```text
<导出目录> <客户端1>(<选项>) <客户端2>(<选项>)
```

- 导出目录必须是绝对路径，例如 `/shares/webapp`。
- 客户端可以是单个主机名、通配符、IPv4、IPv4 网络、IPv6 或网络段。
- 客户端名称解析依赖 DNS 或 `/etc/hosts`；生产环境优先使用稳定 DNS。
- 客户端与括号之间**不能有空格**：`client(rw)` 正确，`client (rw)` 会被解析为不同字段。
- 多个客户端定义之间使用空格分隔。
- 同一行可为不同客户端设置不同权限。
- 未明确 `rw` 时，使用 `ro` 的只读语义更安全；建议显式写出意图。

### 5.2 示例一：基础主机导出

```exports
/shares/webapp nfs-client1.laogao.cloud(rw)
```

含义：仅允许指定主机读写 `/shares/webapp`。修改后：

```bash
exportfs -rav
exportfs -v
```

### 5.3 示例二：不同客户端不同权限

```exports
/shares/webapp nfs-client1.laogao.cloud(rw,sync) nfs-client2.laogao.cloud(ro,sync)
```

- `client1` 可写，`client2` 只读。
- 客户端定义右侧的选项只作用于紧邻的客户端。
- 不要误写成整行一个括号，否则无法表达不同主机策略。

### 5.4 示例三：限制 IPv4 网段并控制 root

```exports
/shares/webapp 10.1.8.0/24(rw,sync,root_squash,no_subtree_check,sec=sys)
```

- 仅允许 `10.1.8.0/24`。
- `root_squash` 让远端 root 映射为匿名身份。
- `no_subtree_check` 避免子目录检查带来的性能与重命名问题。
- `sec=sys` 使用 UID/GID 身份，适合受控实验网，不提供加密。

### 5.5 客户端匹配写法

```exports
/shares/webapp *.laogao.cloud(rw)
/shares/webapp 10.1.8.21(rw)
/shares/webapp 10.1.8.0/24(ro)
/shares/webapp 10.1.8.0/255.255.255.0(ro)
/shares/webapp fde2:6494:1e09:2::20(rw)
/shares/webapp fde2:6494:1e09:2::/64(ro)
/shares/webapp 10.1.8.0/24 client.laogao.cloud *.example.net(ro)
```

- 通配符范围大，需避免与更严格规则产生意外匹配。
- 生产环境用最小网段或单主机地址，避免把管理网外的主机放进共享。
- IPv6 地址含冒号但不需要像 URL 那样包方括号。

### 5.6 生效与检查

```bash
exportfs -rav
exportfs -s
exportfs -v
```

- 先用 `exportfs -rav` 报错即停，修复语法后再测试。
- 配置文件可用 `man exports` 对照当前发行版选项。
- 不要把客户端挂载路径写入 `/etc/exports`；这里写的是服务端真实目录。

## §6 exports 客户端选项：权限与一致性

### 6.1 读写与同步

| 选项 | 含义 | 使用建议 |
|---|---|---|
| `rw` | 允许读写 | 明确业务需要后使用 |
| `ro` | 只读 | 静态资源、软件仓库优先 |
| `sync` | 写请求落盘后再回复 | 数据一致性优先，默认常见 |
| `async` | 先回复、稍后落盘 | 性能优先但掉电可能丢数据 |
| `wdelay` | 合并相关写请求 | 常见默认，降低小写开销 |

- `async` 不应作为“性能万能开关”，需要评估断电、崩溃和应用重试行为。
- 数据库、锁文件和关键配置通常选择 `sync`，并从应用层设计恢复机制。

### 6.2 root 映射

- `root_squash`：默认安全策略，把远端 UID 0 映射为匿名用户。
- `no_root_squash`：保留远端 root 身份，适合少数受控备份/磁盘镜像场景。
- `all_squash`：把所有客户端用户都映射为匿名用户，适合公共上传目录。
- `anonuid=UID`：指定匿名用户的 UID。
- `anongid=GID`：指定匿名组的 GID。
- `root_squash` 不能代替 Unix 权限；匿名用户仍须有目录访问权限。

```exports
/srv/upload 10.1.8.0/24(rw,sync,all_squash,anonuid=65534,anongid=65534)
/srv/backup 10.1.8.21(rw,sync,no_root_squash)
```

### 6.3 安全与子树

- `secure`：要求来自小于 1024 的特权源端口，传统默认行为。
- `insecure`：允许非特权源端口；某些客户端或容器环境需要它，但会放宽约束。
- `subtree_check`：检查请求路径是否在导出子树内，目录移动时可能出现问题。
- `no_subtree_check`：关闭子树检查，常见推荐值，减少重命名和性能问题。
- `hide`：父目录导出中隐藏嵌套导出（具体行为依实现）。
- `crossmnt`：允许客户端穿越挂载点访问嵌套文件系统（需谨慎）。

### 6.4 身份与安全模式

- `sec=sys` 只传 UID/GID，依赖客户端身份诚实，不加密。
- `sec=krb5` 提供 Kerberos 身份认证。
- `sec=krb5i` 在认证外增加完整性保护。
- `sec=krb5p` 增加隐私保护（加密），但 CPU 与延迟开销更大。
- 选择 `krb5*` 前提是 Kerberos、时间同步、DNS 和服务主体均已配置。

## §7 exportfs 命令：不重启服务管理导出

### 7.1 常用命令

| 命令 | 作用 |
|---|---|
| `exportfs -r` | 重新读取 `/etc/exports` 并刷新导出 |
| `exportfs -a` | 导出或取消导出所有目录 |
| `exportfs -rav` | 重新导出、显示过程、显示详细信息 |
| `exportfs -s` | 以简洁格式显示当前导出 |
| `exportfs -v` | 显示当前导出及完整选项 |
| `exportfs -u client:/path` | 取消指定导出 |
| `exportfs -ua` | 取消所有导出（高风险） |

### 7.2 推荐变更流程

```bash
cp -a /etc/exports /etc/exports.bak.$(date +%F-%H%M%S)
vim /etc/exports
exportfs -rav
exportfs -s
showmount -e localhost
```

1. 备份配置并记录变更单。
2. 检查路径存在、权限正确、客户端地址准确。
3. 用 `exportfs -rav` 应用变更。
4. 从授权客户端重新查询或访问。
5. 观察 `journalctl -u nfs-server`，确认没有拒绝日志。

### 7.3 与 systemctl reload 的关系

- `exportfs -r` 直接刷新导出表，适合快速验证配置。
- `systemctl reload nfs-server` 通过服务管理器触发重载。
- 两者都不应替代配置语法检查和客户端侧验证。
- 不必要时不要 `restart`，避免所有客户端瞬时失败。
- 取消导出会让已挂载客户端后续 I/O 失败，应提前通知业务。

### 7.4 典型错误

- `exportfs: /path does not support NFS export`：路径或底层文件系统不合适。
- `bad option`：选项拼写错误或当前版本不支持。
- 导出显示正确但访问拒绝：继续检查客户端 IP、root squash 和 Unix 权限。
- 修改后客户端仍旧旧权限：确认匹配规则、刷新导出并重新挂载验证。

## §8 showmount 命令：查看服务端共享清单

### 8.1 查询导出

```bash
showmount -e 10.1.8.20
```

典型输出：

```text
Export list for 10.1.8.20:
/shares/webapp 10.1.8.0/24
```

- `-e` 查询服务端导出列表。
- `showmount -a server` 显示已挂载客户端与导出路径（依服务端记录）。
- `showmount -d server` 显示被挂载的目录。
- `showmount -v` 显示版本信息（不同实现支持略有差异）。

### 8.2 查询流程

```bash
getent hosts nfs-server
rpcinfo -p nfs-server
showmount -e nfs-server
```

- 先确认名称解析，再确认 RPC，最后查询导出。
- `showmount` 依赖 mountd，NFSv4 单端口环境中它不一定能完整反映伪根导出。
- `showmount -e` 为空不必立即判断服务故障，还要检查 `exportfs -s` 和 v4 namespace。

### 8.3 服务端自检

```bash
showmount -e localhost
exportfs -s
cat /proc/fs/nfs/exports 2>/dev/null || true
```

### 8.4 安全注意

- `showmount` 暴露共享信息，公网不应开放相关 RPC 查询。
- 客户端能看到清单不代表一定有读写权，最终权限仍由导出与文件系统共同决定。
- 修改 exports 后先在服务端检查，再在授权客户端检查，减少误诊。

## §9 NFS 客户端挂载：mount + fstab

### 9.1 安装与挂载点

```bash
yum install -y nfs-utils
mkdir -p /mnt/web
showmount -e 10.1.8.20
mount -t nfs 10.1.8.20:/shares/webapp /mnt/web
findmnt /mnt/web
df -hT /mnt/web
```

- 挂载点必须是已存在的目录，且不能被业务进程占用。
- `mount` 成功后原挂载点下文件会被远程目录遮蔽；卸载前注意本地文件。
- 使用 `findmnt` 查看文件系统类型、版本和选项比只看 `df` 更完整。

### 9.2 显式版本与参数

```bash
mount -t nfs -o vers=4.1,proto=tcp,hard,timeo=600,retrans=2 \\
  10.1.8.20:/shares/webapp /mnt/web
```

- 优先 TCP；`vers=4.1` 需服务端和客户端同时支持。
- 默认 `hard` 更适合重要数据，但网络恢复前进程可能阻塞。
- 评估 `timeo` 与 `retrans`，不要用过短超时制造假失败。

### 9.3 持久化挂载 `/etc/fstab`

```fstab
nfs-server:/shares/webapp  /var/www/html  nfs  defaults,_netdev,vers=4.1,proto=tcp  0  0
```

- `_netdev` 告诉 systemd 这是网络文件系统，网络就绪后再挂载。
- 先执行 `mount -a` 验证语法，确认无报错再重启测试。
- systemd 系统可用 `systemctl daemon-reload` 刷新生成的 mount unit。
- 服务器地址建议使用稳定 DNS 或固定 IP，避免启动时名称解析失败。
- 关键业务可加 `x-systemd.automount`，让访问时再真正连接。

### 9.4 卸载与检查

```bash
fuser -vm /mnt/web
lsof +f -- /mnt/web
umount /mnt/web
```

- `umount: target is busy` 表示仍有进程 cwd、文件或子挂载。
- 软卸载和强制卸载可能造成应用看到不一致状态，应先做业务判断。
- 卸载后用 `findmnt /mnt/web` 确认确实已移除。

## §10 mount 选项：可靠性、性能与语义

### 10.1 访问与协议

| 选项 | 含义 | 建议 |
|---|---|---|
| `rw` / `ro` | 读写 / 只读 | 与服务端策略一致 |
| `vers=4.1` | 使用 NFSv4.1 | 双方支持时优先 |
| `proto=tcp` | 使用 TCP | 广域网和生产常用 |
| `port=2049` | 指定 NFS 端口 | v4 常见，按实际检查 |
| `bg` | 后台重试挂载 | 新系统注意 systemd 行为 |
| `_netdev` | 标记网络设备 | fstab 推荐 |

### 10.2 超时与重试

- `hard`：请求持续重试，恢复后继续；重要数据通常选它。
- `soft`：达到重试后返回错误，可能导致应用处理半完成 I/O，慎用。
- `softreval`：允许属性缓存失效时更快返回（需评估语义）。
- `timeo=n`：RPC 超时单位按协议/实现解释，修改前查 `man nfs`。
- `retrans=n`：重传次数；过低会制造短暂网络抖动下的失败。
- 重要服务宁可让明确的应用监控发现阻塞，也不要盲目 `soft`。

### 10.3 缓存与 I/O

- `rsize` / `wsize`：客户端单次读写请求大小；现代 Linux 通常自动协商。
- 典型测试起点可用 `rsize=1048576,wsize=1048576`，最终以实测为准。
- `noatime`：不更新访问时间，减少元数据写入；需确认应用不依赖 atime。
- `nodiratime`：只减少目录 atime 更新，通常被 `noatime` 覆盖。
- `lookupcache=positive` 或 `none` 会改变目录项缓存语义，适合特定一致性问题排查。
- `actimeo=n` 控制属性缓存总周期；越短越新，但元数据 RPC 越多。

### 10.4 锁与安全

- `local_lock=none` 等选项影响锁行为，只有理解客户端/服务端协作后再改。
- `sec=sys` 适合受控实验网，不提供加密和强身份认证。
- `sec=krb5p` 提供隐私保护，CPU 和延迟成本应通过压测评估。
- 不要把 `no_root_squash` 当成客户端 mount 选项；它属于服务端 exports。

```bash
nfsstat -m
findmnt -t nfs,nfs4
cat /proc/mounts | grep nfs
```

## §11 autofs 自动挂载：按需触发

### 11.1 为什么用 autofs

- 静态 fstab 在网络未就绪时可能拖慢启动或产生失败日志。
- autofs 仅在访问路径时挂载，闲置一段时间后自动卸载。
- 它适合用户家目录、偶尔访问的共享和大量客户端的统一配置。
- 关键持续 I/O 业务仍需评估自动卸载与连接恢复行为。

### 11.2 安装与主配置

```bash
yum install -y autofs nfs-utils
systemctl enable --now autofs
```

`/etc/auto.master`：

```text
/misc   /etc/auto.misc
/net    -hosts
/mnt/nfs /etc/auto.nfs --timeout=300
```

- 第一列是触发根目录；第二列是映射文件；可选参数放在末尾。
- `--timeout=300` 表示闲置约 300 秒后卸载，按业务调整。
- 修改后执行 `systemctl reload autofs` 或重启服务。

### 11.3 间接映射

`/etc/auto.nfs`：

```text
web  -fstype=nfs4,rw,vers=4.1,proto=tcp,hard,_netdev  nfs-server:/shares/webapp
ro   -fstype=nfs4,ro,vers=4.1,proto=tcp                nfs-server:/srv/readonly
```

访问：

```bash
ls /mnt/nfs/web
findmnt /mnt/nfs/web
```

- `/mnt/nfs` 是触发根，`web` 是 key，实际挂载点为 `/mnt/nfs/web`。
- 访问 `ls`、`cd` 或打开文件可能触发网络连接，因此排障命令也会产生 I/O。
- 退出目录并等待超时后，`findmnt` 可观察自动卸载。

### 11.4 直接映射

`/etc/auto.master`：

```text
/-  /etc/auto.direct
```

`/etc/auto.direct`：

```text
/var/www/html  -fstype=nfs4,vers=4.1,proto=tcp  nfs-server:/shares/webapp
```

- 直接映射允许精确指定完整挂载路径。
- 同一目录不要同时被 fstab、autofs 和手工 mount 管理，避免冲突。

### 11.5 autofs 排障

```bash
systemctl status autofs
journalctl -u autofs -b --no-pager
automount -m
mount | grep nfs
```

- 路径拼写错误通常表现为访问时才失败。
- 映射文件权限、缩进和分隔空格要保持清晰。
- DNS 不可用时，优先改用可验证的 IP 做故障隔离。

## §12 NFSv4 特性：单端口、复合操作与伪文件系统

### 12.1 单一端口与状态

- NFSv4 主要通过 TCP 2049 提供文件操作，防火墙规则明显简化。
- 它把挂载、锁、状态管理等能力纳入统一体系。
- 版本 4 是有状态协议，服务器需要维护客户端会话、租约和恢复信息。
- 网络分区恢复后，客户端可能经历状态恢复；不要把瞬时卡顿误判为数据消失。

### 12.2 复合操作

- 客户端可以把 `LOOKUP`、`OPEN`、`READ` 等操作组合为一次复合请求。
- 复合操作减少网络往返，尤其对高延迟链路有帮助。
- 应用看到的 POSIX 语义仍由客户端缓存、锁和服务端实现共同提供。

### 12.3 伪根与导出组织

服务端可将目录组织为：

```text
/srv/nfs/                 # fsid=0 的 NFSv4 伪根
├── web/                  # /srv/nfs/web
└── data/                 # /srv/nfs/data
```

示例 exports：

```exports
/srv/nfs      *(ro,fsid=0,crossmnt,sec=sys)
/srv/nfs/web  10.1.8.0/24(rw,sync,no_subtree_check,sec=sys)
```

客户端可能使用：

```bash
mount -t nfs4 -o vers=4.1 nfs-server:/web /mnt/web
```

- NFSv4 的导出路径与服务端真实路径不一定一一相同，取决于 `fsid=0` 设计。
- 设计伪根前先阅读当前发行版的 nfsd/exportfs 文档。
- 不要把 `/` 或包含敏感系统目录的路径意外设为伪根。

### 12.4 安全能力

- `sec=krb5`：身份认证。
- `sec=krb5i`：身份认证与完整性保护。
- `sec=krb5p`：身份认证、完整性和加密隐私。
- NFSv4 ACL 比简单 Unix mode 更细粒度，但跨平台迁移需验证语义。
- 安全模式改变后，客户端必须使用匹配选项并验证 Kerberos ticket。

## §13 NFS 性能调优：先测量，再改变

### 13.1 性能模型

```text
NFS 延迟 ≈ 网络往返延迟 + 服务端 RPC 排队 + 文件系统/磁盘延迟 + 锁竞争
吞吐上限 ≈ min(客户端网卡, 网络链路, 服务端网卡, 服务端磁盘, nfsd 并发)
```

- 先区分带宽瓶颈、IOPS 瓶颈、元数据瓶颈和锁瓶颈。
- 调优前记录基线：文件大小、并发数、读写比例、协议版本、rsize/wsize、网络 RTT。
- 只改变一个变量，并保留回滚命令。

### 13.2 客户端参数起点

```fstab
nfs-server:/srv/data /data nfs4 vers=4.1,proto=tcp,hard,timeo=600,retrans=2,rsize=1048576,wsize=1048576,noatime,_netdev 0 0
```

- `rsize/wsize=1048576`（1 MiB）可作为现代千兆/万兆网络的测试起点。
- 若设备、内核或网络不支持，降低到 `262144` 或移除让客户端自动协商。
- `hard` 保证重要数据请求不轻易返回假成功；同时配合业务超时和监控。
- `noatime` 减少读密集目录的元数据写，但须确认应用依赖。
- NFSv4.1 + TCP 通常比旧 UDP 更适合稳定生产网络。

### 13.3 服务端与 nfsd

```bash
nproc
cat /proc/fs/nfsd/threads
# 按发行版方式调整 nfsd 线程，先小步压测
nfsstat -s
```

- 并发客户端多时可适度增加 nfsd 线程，不能超过磁盘与 CPU 的承载能力。
- 线程过少导致排队，过多会增加上下文切换和锁竞争。
- 服务端文件系统、RAID、缓存策略和磁盘队列通常比盲调 NFS 参数更关键。

### 13.4 网络与链路

- 多网卡可用 bonding/LACP 或独立流量网络，但不要把“多 IP”误认为单连接自动聚合。
- 使用 `ip -s link`、`ethtool -S`、`sar -n DEV` 检查丢包、错误和队列。
- 巨型帧（MTU 9000）必须端到端一致，包括交换机、bond、VLAN 和两端网卡。
- MTU 不一致会导致分片、丢包或完全不通；启用前做 `ping -M do` 验证。
- 低延迟局域网优先保证稳定性，别为了理论吞吐牺牲可靠性。

### 13.5 测量工具

```bash
nfsstat -m
nfsstat -c
nfsstat -s
iostat -xz 1
nfsiostat 1
sar -n TCP,DEV 1
```

- `nfsiostat` 观察每个挂载的读写吞吐、延迟和 retrans。
- `nfsstat` 观察 RPC 数量、错误与缓存命中。
- 使用 fio/业务压测时，避免直接在生产数据上运行破坏性测试。

## §14 NFS 与防火墙：按版本放行

### 14.1 端口速查

| 服务 | 端口 | 说明 |
|---|---:|---|
| `rpcbind` | 111/TCP、111/UDP | v2/v3 查询映射 |
| `nfsd` | 2049/TCP、2049/UDP | NFS 主服务 |
| `mountd` | 动态或固定 | v2/v3 挂载授权 |
| `lockd` | 动态或固定 | 文件锁 |
| `statd` | 动态或固定 | 状态通知 |

- NFSv4 主路径通常只需 2049/TCP（以及实际启用的相关服务）。
- NFSv3 若使用防火墙，建议在 `/etc/nfs.conf` 或发行版配置中固定 mountd/lockd/statd 端口。
- 固定端口后重启服务并用 `rpcinfo -p` 复核，不能只凭配置文件猜测。

### 14.2 firewalld 服务放行

```bash
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload
firewall-cmd --list-all
```

- 这些服务名是否可用取决于 firewalld service definitions，先用 `firewall-cmd --get-services` 检查。
- 仅向可信管理网或业务网放行，不要对公网开放。
- v4-only 环境可按 `ss`/`rpcinfo` 的实际监听收敛规则。

### 14.3 rich rule 限制网段

```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.8.0/24" service name="nfs" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.8.0/24" service name="rpc-bind" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.8.0/24" service name="mountd" accept'
firewall-cmd --reload
```

- rich rule 只负责网络层放行，不能绕过 `/etc/exports` 或 Unix 权限。
- 规则应用后用 `nc -vz`、`rpcinfo` 和实际 mount 逐层验证。
- 排障时临时停止 firewalld 只适合隔离问题，不是生产修复；验证后应立即恢复策略。

**关联笔记**：[[Linux防火墙#nfs放行]]、[[Linux服务与SSH#systemd]]。

## §15 NFS 安全：最小权限、Kerberos 与 ACL

### 15.1 最小权限基线

1. 只导出专用数据目录，不导出 `/`、`/home` 全树或含密钥的目录。
2. 客户端列表使用单主机或最小网段，避免无必要的 `*`。
3. 只读业务使用 `ro`；写入业务明确列出 `rw`。
4. 保持 `root_squash`，除非已经评审并确认必须保留远端 root。
5. 受控上传目录可用 `all_squash,anonuid,anongid` 统一匿名身份。
6. 通过防火墙仅允许业务网访问 RPC/NFS 端口。
7. NFS 不直接暴露公网；远程访问应通过 VPN 或受控专线。
8. 服务端启用 SELinux、审计和日志，定期复核导出列表。

### 15.2 UID/GID 一致性

- `sec=sys` 下服务端看到的是客户端发送的 UID/GID 数值。
- 客户端用户名相同不代表 UID 相同；权限按数字 ID 判断。
- 使用 LDAP/SSSD、统一 `/etc/passwd` 管理或集中身份服务减少漂移。

```bash
id apache
stat -c '%u:%g %A %n' /shares/webapp
getent passwd 48
getent group 48
```

- 不要仅用 `chown apache` 判断共享权限，必须比较两端数字 UID/GID。

### 15.3 Kerberos 安全模式

- `sec=krb5`：只做身份认证。
- `sec=krb5i`：认证并校验完整性，防止篡改。
- `sec=krb5p`：认证、完整性和加密，适合敏感数据但开销最大。
- 前置条件：Kerberos KDC、主体（principal）、keytab、DNS 和 NTP 时间同步。
- 先在隔离环境验证 ticket、服务主体和挂载，再迁移生产。

### 15.4 NFSv4 ACL

- ACL 可表达比 `rwx` 更细的继承、用户和组权限。
- 使用 `getfacl`、`setfacl` 检查时，确认客户端/服务端文件系统支持。
- 跨平台或备份迁移可能丢失 ACL，迁移前做恢复演练。
- ACL 不能替代网络隔离、身份认证和加密。

## §16 NFS 故障排查：从网络到权限

### 16.1 分层方法

```text
1. 路由/链路：ping、ip route、DNS、MTU
2. 防火墙：firewall-cmd、ss、端口连通
3. RPC：rpcbind、rpcinfo、mountd
4. 导出：/etc/exports、exportfs、showmount
5. 挂载：mount 参数、版本、路径、fstab
6. 文件系统：Unix mode、ACL、SELinux、UID/GID
7. 运行质量：nfsstat、nfsiostat、日志、磁盘
```

### 16.2 常见错误与处理

| 错误 | 常见原因 | 检查 |
|---|---|---|
| `Connection timed out` | 防火墙、路由、服务未监听 | `ping`、`ss`、firewalld |
| `No route to host` | 路由或安全组 | `ip route`、网关 |
| `access denied by server` | exports 未匹配客户端 | `exportfs -v`、客户端源 IP |
| `Protocol not supported` | 版本不兼容 | `-o vers=3/4.1` |
| `mount point does not exist` | 本地目录缺失 | `mkdir -p` |
| `Stale file handle` | 服务端目录被替换/导出变化 | 重新挂载并检查路径 |
| `Permission denied` | Unix 权限、root squash、SELinux | `id`、`stat`、`ausearch` |
| `target is busy` | cwd、文件或子挂载占用 | `fuser`、`lsof` |

### 16.3 服务端命令

```bash
systemctl status rpcbind nfs-server
journalctl -u rpcbind -u nfs-server -b --no-pager
rpcinfo -p localhost
exportfs -rav
exportfs -v
ss -lntup | grep -E ':(111|2049)\\b'
```

### 16.4 客户端命令

```bash
getent hosts nfs-server
rpcinfo -p nfs-server
showmount -e nfs-server
findmnt -t nfs,nfs4
nfsstat -m
nfsiostat 1 3
journalctl -k -b | grep -i nfs
```

### 16.5 权限与 SELinux

```bash
namei -l /shares/webapp
stat -c '%u %g %A %n' /shares/webapp
getfacl /shares/webapp
getenforce
ausearch -m AVC -ts recent
```

- 临时 `setenforce 0` 只能用于短时隔离测试，测试后必须恢复 enforcing。
- 先看 AVC 日志，再使用正确的上下文/布尔值解决，禁止直接关闭安全机制。

## §17 易错点 ×10：记住这些就少走弯路

1. **只启动 nfs-server，不检查 rpcbind**：v2/v3 客户端可能无法查询端口。先 `systemctl is-active rpcbind nfs-server`。
2. **exports 客户端与括号之间加空格**：`client (rw)` 不是规范写法，必须是 `client(rw)`。
3. **把客户端路径写进 exports**：exports 左侧必须是服务端真实目录，客户端路径只出现在 mount/fstab。
4. **修改 exports 后不刷新**：编辑文件不等于生效，执行 `exportfs -rav` 并检查 `exportfs -v`。
5. **把 no_root_squash 当修复权限的第一选择**：它会放大远端 root 权限，优先修复 UID/GID、目录 mode 和 ACL。
6. **只看 showmount 不看 NFSv4 伪根**：v4 的 namespace 可能无法由旧 mountd 查询完整表示。
7. **防火墙只放行 2049 就部署 v3**：v3 还可能需要 111、mountd、lockd、statd；先 `rpcinfo -p`。
8. **fstab 忘记 `_netdev`**：网络文件系统可能在网络就绪前启动，导致开机失败或等待过久。
9. **客户端 UID 与服务端用户名同名就以为一致**：权限按数字 UID/GID，必须用 `id` 和 `stat` 对照。
10. **网络抖动时盲目使用 soft**：过短失败会让应用收到不完整 I/O 结果，重要数据优先 hard 并做监控。
11. **共享目录设置 777**：这掩盖了身份和 ACL 问题，并扩大任意用户写入风险。
12. **把 NFS 当备份**：NFS 是实时共享，误删会同步影响所有客户端；另建备份与快照策略。
13. **重复管理一个挂载点**：不要同时让 fstab、autofs、手工 mount 争抢同一路径。
14. **MTU 只改一端**：巨型帧要求端到端一致，先验证再启用。
15. **用停止防火墙代替修规则**：停防火墙只是排查手段，定位后应恢复并收敛白名单。

## §18 速查表：端口、路径与命令

### 18.1 关键路径

| 路径 | 作用 |
|---|---|
| `/etc/exports` | 服务端导出规则 |
| `/etc/nfs.conf` | NFS 守护进程和端口等配置（依发行版） |
| `/etc/fstab` | 客户端持久化挂载 |
| `/etc/auto.master` | autofs 主映射 |
| `/etc/auto.nfs` | autofs 间接映射示例 |
| `/var/lib/nfs/` | NFS 状态数据（不要随意删除） |
| `/proc/fs/nfsd/` | 内核 nfsd 运行状态 |
| `/proc/mounts` | 当前内核挂载表 |

### 18.2 服务端命令

```bash
yum install -y nfs-utils
systemctl enable --now rpcbind nfs-server
vim /etc/exports
exportfs -rav
exportfs -s
exportfs -v
showmount -e localhost
rpcinfo -p localhost
journalctl -u nfs-server -b
```

### 18.3 客户端命令

```bash
yum install -y nfs-utils
mkdir -p /mnt/nfs
showmount -e 10.1.8.20
mount -t nfs -o vers=4.1,proto=tcp 10.1.8.20:/shares/webapp /mnt/nfs
findmnt /mnt/nfs
df -hT /mnt/nfs
nfsstat -m
umount /mnt/nfs
```

### 18.4 防火墙与检查

```bash
firewall-cmd --get-services | grep -E 'nfs|rpc|mount'
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload
ss -lntup | grep -E ':(111|2049)\\b'
```

### 18.5 最小工作示例

```exports
/srv/nfs/share 10.1.8.0/24(rw,sync,root_squash,no_subtree_check,sec=sys)
```

```bash
mkdir -p /srv/nfs/share
chmod 0755 /srv/nfs/share
exportfs -rav
mkdir -p /mnt/share
mount -t nfs -o vers=4.1,proto=tcp nfs-server:/srv/nfs/share /mnt/share
```

**关联**：[[Linux文件传输#scp-rsync]]、[[Linux存储#挂载]]、[[Linux防火墙#nfs放行]]、[[Linux服务与SSH#systemd]]。

## §19 面试 6 大追问：从原理讲到实战

### 追问 1：NFS 与 SMB 有什么区别？

- NFS 源于 UNIX/Linux，强调 POSIX 文件和 UID/GID 语义；SMB/CIFS 源于 Windows，常与 AD/域集成。
- Linux 间共享通常优先 NFS；异构办公环境和 Windows 客户端通常考虑 SMB。
- 最终选择还要看 ACL、锁、认证、加密、客户端兼容性和运维能力。

### 追问 2：为什么 NFS 需要 RPC？

- RPC 把远程文件操作抽象成调用，让 NFS 不必为每种操作重复设计连接流程。
- `rpcbind` 将程序号映射到端口，客户端先问路再调用。
- NFSv3 因多个服务端口增加防火墙复杂度；NFSv4 将主要协议收敛到 2049。

### 追问 3：NFSv4 相比 v3 改进什么？

- NFSv4 支持状态化会话、复合操作、统一锁机制、伪根、ACL 和 Kerberos。
- 单端口简化防火墙；复合操作减少往返。
- 它不代表自动安全或自动更快，仍需配置身份、网络、缓存和版本协商。

### 追问 4：root_squash 为什么重要？

- `sec=sys` 只携带 UID/GID；远端 root 若原样映射，可能以服务端 root 身份修改文件。
- `root_squash` 把 UID 0 映射为匿名身份，降低客户端被攻破后的影响。
- 仅在极少数受控场景使用 `no_root_squash`，且要配合网络隔离和审计。

### 追问 5：如何调优 NFS 性能？

- 先用 `nfsstat`、`nfsiostat`、`iostat`、网络统计建立基线，区分延迟、吞吐和元数据瓶颈。
- 以 TCP、NFSv4.1、`rsize/wsize=1048576`、`noatime` 作为可测起点，逐项压测。
- 服务端磁盘、nfsd 线程、网络丢包、锁竞争通常比单个 mount 参数更重要。

### 追问 6：NFS 挂载失败如何定位？

- 按网络/防火墙 → RPC/端口 → exports → mount 版本/路径 → Unix/SELinux 权限分层定位。
- 服务端用 `rpcinfo -p`、`exportfs -v`；客户端用 `showmount -e`、`findmnt`、日志和 `nfsstat`。
- 不要把 `Permission denied` 一律归因于防火墙，它常是 UID/GID、root squash 或 SELinux。

### 一句话总结

NFS 的核心不是背命令，而是理解“导出规则 + RPC 定位 + 客户端挂载 + Unix 身份 + 网络与性能”这条完整链路。

---

## 附录：部署验收清单

- [ ] 服务端已安装 `nfs-utils`，并确认版本。
- [ ] 共享目录位于正确文件系统，磁盘已挂载。
- [ ] `/etc/exports` 使用最小客户端范围。
- [ ] 所有客户端定义与括号之间没有空格。
- [ ] 默认使用 `root_squash`，没有无理由的 `no_root_squash`。
- [ ] 已执行 `exportfs -rav`，并核对 `exportfs -v`。
- [ ] `rpcinfo -p` 显示实际使用端口。
- [ ] 防火墙只对业务网放行需要的服务。
- [ ] 客户端用明确 `vers` 与 `proto` 做过挂载测试。
- [ ] `/etc/fstab` 使用 `_netdev`，或已经配置 autofs。
- [ ] 已用 `findmnt`、`df -hT` 验证挂载。
- [ ] 已验证读、写、跨客户端可见性和卸载。
- [ ] 已对照两端 UID/GID，并检查 ACL/SELinux。
- [ ] 已记录 nfsstat/nfsiostat 基线。
- [ ] 已准备备份、快照和故障恢复方案。

## 附录：最小演练剧本

```bash
# 服务端
mkdir -p /srv/nfs/lab
printf '/srv/nfs/lab 10.1.8.0/24(rw,sync,root_squash,no_subtree_check)\\n' >> /etc/exports
exportfs -rav
exportfs -s

# 客户端
mkdir -p /mnt/lab
showmount -e 10.1.8.20
mount -t nfs -o vers=4.1,proto=tcp 10.1.8.20:/srv/nfs/lab /mnt/lab
printf 'nfs test\\n' > /mnt/lab/healthcheck.txt
findmnt /mnt/lab
cat /mnt/lab/healthcheck.txt
umount /mnt/lab
```

> 演练结束后，删除实验导出规则并再次执行 `exportfs -rav`；不要把实验目录留作生产共享。

### 运维检查卡 1：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 2：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 3：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 4：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 5：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 6：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 7：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 8：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 9：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。

### 运维检查卡 10：NFS 变更前后记录

- 变更前时间：________________；操作者：________________。
- 服务端地址：________________；客户端地址：________________。
- 导出路径：________________；客户端匹配：________________。
- 协议版本：________________；传输协议：________________。
- 变更前 `exportfs -v`：已保存 / 未保存。
- 变更前 `rpcinfo -p`：已保存 / 未保存。
- 变更前 `findmnt`：已保存 / 未保存。
- 变更动作：________________________________________________。
- 变更后 `exportfs -s`：通过 / 不通过。
- 变更后挂载读测试：通过 / 不通过。
- 变更后挂载写测试：通过 / 不通过。
- 变更后权限测试：通过 / 不通过。
- 变更后日志检查：通过 / 不通过。
- 回滚命令：________________________________________________。
