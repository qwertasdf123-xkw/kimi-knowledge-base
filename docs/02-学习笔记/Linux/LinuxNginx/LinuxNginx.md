---
title: Linux Nginx 服务器
desc: Nginx 架构 + 编译安装 + location 规则 + 反向代理 + 负载均衡 + rewrite + HTTPS + 性能调优
type: 笔记
module: LinuxNginx
pdf: Nginx 服务器.pdf
pdf_size: 1.2 MB
scope: Nginx 架构 + 配置详解 + 反向代理 + HTTPS + 性能优化
status: 完成
---

# Linux Nginx 服务器

> **范围**：基于《Nginx 服务器.pdf》整理。覆盖 **Nginx 起源与架构**（事件驱动 + master/worker）+ **编译/YUM 安装** + **配置结构**（main / events / http / server / location 四层）+ **location 匹配规则**（= / ^~ / ~ / ~*）+ **反向代理**（proxy_pass + upstream）+ **负载均衡 5 算法**（rr / weight / ip_hash / hash / least_conn）+ **HTTPS + Let's Encrypt** + **rewrite / return / 防盗链 / 限流 / 访问控制 / 日志** + **性能调优 + 平滑升级 + systemd**。
>
> **适用**：CentOS-7 / RHEL 系，Nginx 1.20.x（教材版本）。

## 目录

- [[#§0 心智模型：Nginx = 高性能异步事件驱动 Web 服务器]]
- [[#§1 Nginx 是什么：Igor Sysoev + 2004 公开]]
- [[#§2 Nginx vs Apache：C10K 问题]]
- [[#§3 Nginx 架构：master + worker 多进程模型]]
- [[#§4 安装方式：yum vs 源码编译]]
- [[#§5 目录结构：sbin / conf / html / logs]]
- [[#§6 nginx.conf 配置结构：main → events → http → server → location]]
- [[#§7 全局配置：user / worker_processes / worker_rlimit_nofile]]
- [[#§8 events 块：use epoll / worker_connections / multi_accept]]
- [[#§9 http 块：mime.types / sendfile / tcp_nopush / keepalive / gzip]]
- [[#§10 server 块：listen / server_name / root / index / access_log]]
- [[#§11 location 匹配规则：= / ^~ / ~ / ~* / 无修饰符]]
- [[#§12 location 优先级实战案例]]
- [[#§13 root vs alias 区别]]
- [[#§14 静态文件服务：try_files / expires 缓存]]
- [[#§15 反向代理：proxy_pass + proxy_set_header]]
- [[#§16 虚拟主机三种方式：域名 / 端口 / IP]]
- [[#§17 upstream 负载均衡基础]]
- [[#§18 调度算法 1：轮询 rr]]
- [[#§19 调度算法 2：权重 weight]]
- [[#§20 调度算法 3：ip_hash 会话保持]]
- [[#§21 调度算法 4：hash $request_uri]]
- [[#§22 调度算法 5：least_conn 最少连接]]
- [[#§23 upstream 健康检查：max_fails / fail_timeout]]
- [[#§24 URL 重写 rewrite regex replacement flag]]
- [[#§25 return 指令：直接返回状态码]]
- [[#§26 HTTPS 配置：ssl_certificate + ssl_protocols]]
- [[#§27 Let's Encrypt 免费证书 certbot]]
- [[#§28 HTTP 重定向到 HTTPS]]
- [[#§29 PHP 站点：php-fpm + fastcgi_pass]]
- [[#§30 Basic Auth：auth_basic + htpasswd]]
- [[#§31 gzip 压缩]]
- [[#§32 防盗链：valid_referers]]
- [[#§33 限流：limit_req_zone + limit_conn_zone]]
- [[#§34 访问控制：allow / deny + geo]]
- [[#§35 日志格式：log_format + access_log + logrotate]]
- [[#§36 stub_status 监控]]
- [[#§37 性能调优：worker_processes / sendfile / tcp_nopush]]
- [[#§38 平滑升级：USR2 + WINCH + QUIT 三步走]]
- [[#§39 systemd 部署 nginx.service]]
- [[#§40 易错点 ×10]]
- [[#§41 速查表]]
- [[#§42 面试 6 大追问]]
- [[#§43 跨模块链接]]

---

## §0 心智模型：Nginx = 高性能异步事件驱动 Web 服务器

```
客户端 ──HTTP 请求──> Nginx（反向代理）
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   后端 A (8080)    后端 B (8080)    后端 C (8080)   ← upstream 集群
   "Welcome A"      "Welcome B"      "Welcome C"
```

**Nginx 核心定位**：
- **Web 服务器**：静态文件服务（HTML/CSS/JS/图片）
- **反向代理**：隐藏后端，转发请求
- **负载均衡**：将流量分发给多个后端
- **API 网关**：统一入口，鉴权 / 限流 / 缓存

**核心特点**：
- **高并发**：单机可支持 **5 万并发连接数**，内存/CPU 消耗极低
- **事件驱动**：基于 epoll 多路复用，单线程处理万级连接
- **异步非阻塞**：请求处理不阻塞 worker
- **模块化**：核心 + 模块（http_ssl / stub_status / upstream 等）

> 💡 一句话：**Nginx = 异步事件驱动 + 多进程 master/worker + 模块化的 HTTP/反向代理/负载均衡服务器。**

---

## §1 Nginx 是什么：Igor Sysoev + 2004 公开

**作者与历史**：
- **Igor Sysoev**（俄国人）2002 年开发，2004 年开源
- 最初为俄罗斯大型门户 **Rambler.ru** 设计，解决 C10K 问题
- 2011 年成立 **Nginx Inc.**（F5 Networks 2019 年以 6.7 亿美元收购）
- 当前主流版本：**Nginx 1.20.x**（教材）、**1.24.x**（稳定主线）、**1.25.x**（开发版含 HTTP/3）

**Nginx 三大场景**：

| 场景 | 占比 | 说明 |
|---|---|---|
| **反向代理 + 负载均衡** | 50%+ | 微服务 / API 网关主流选择 |
| **静态文件服务** | 30% | 高效 `sendfile` 静态分发 |
| **API 网关 / 入口** | 20% | 配合 Lua（OpenResty）/ Java（Spring Cloud Gateway） |

**官网**：
- 英文：`http://nginx.org/en/docs/`
- 中文 wiki：`https://www.nginx.com/resources/wiki/`

---

## §2 Nginx vs Apache：C10K 问题

**C10K 问题**：单机同时处理 1 万并发连接。

| 维度        | **Apache**                              | **Nginx**                   |
| --------- | --------------------------------------- | --------------------------- |
| **架构**    | 多进程 / 多线程（prefork / worker / event MPM） | 异步事件驱动（epoll）               |
| **进程模型**  | 每连接 1 线程 / 进程                           | 1 个 worker 处理万级连接           |
| **内存占用**  | 高（每连接分配栈）                               | 极低（事件循环）                    |
| **并发能力**  | 千级                                      | **5 万级**                    |
| **静态文件**  | 较慢                                      | **极快**（sendfile）            |
| **动态内容**  | **强**（mod_php 直接嵌入）                     | 弱（需 fastcgi_pass 转 PHP-FPM） |
| **配置复杂度** | .htaccess 灵活                            | 集中配置，无 .htaccess            |
| **模块加载**  | 动态共享对象（DSO）                             | 静态编译 / 动态模块                 |
| **适用**    | 中小并发、动态为主                               | **高并发、静态/反向代理**             |

**核心差异原理**：

```
Apache prefork:        每连接 1 进程
client1 ──> apache child process
client2 ──> apache child process
client3 ──> apache child process
... 1万连接 = 1万进程 = 内存爆炸

Nginx event-driven:    1 个 worker 处理万级连接
client1 ─┐
client2 ─┤
client3 ─┼──> 1 个 worker 进程（epoll 事件循环）
...      │
clientN ─┘
```

> 💡 **面试题**：为什么 Nginx 比 Apache 高并发？
> 答：Nginx 用 **epoll 事件驱动**（Linux 内核 2.6+），1 个 worker 通过 epoll_wait 单线程监听万级 fd，无进程/线程切换开销；Apache prefork 每连接 1 进程，进程切换 + 内存占用是瓶颈。

---

## §3 Nginx 架构：master + worker 多进程模型

```
                    ┌──────────────────┐
                    │  master 进程     │ ← 1 个（特权用户启动）
                    │  (管理进程)       │
                    │  - 读取配置       │
                    │  - 绑定端口       │
                    │  - 管理 worker    │
                    │  - 平滑升级       │
                    └────────┬─────────┘
                             │ fork
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
      ┌──────────┐     ┌──────────┐     ┌──────────┐
      │ worker 1 │     │ worker 2 │     │ worker 3 │ ← N 个（= CPU 核心数）
      │(epoll 循环)│   │(epoll 循环)│   │(epoll 循环)│
      └──────────┘     └──────────┘     └──────────┘
            ▲                ▲                ▲
            └────────────────┼────────────────┘
                             │
                       HTTP 请求（epoll 分发）
```

**角色分工**：

| 进程         | 数量            | 职责                                   |
| ---------- | ------------- | ------------------------------------ |
| **master** | 1 个           | 读取配置、绑定端口、fork worker、接收信号、worker 管理 |
| **worker** | N 个（= CPU 核数） | 接受客户端连接、处理请求、读取后端响应                  |

**进程间通信**：
- master ↔ worker：通过 **信号**（USR2 / WINCH / QUIT）
- worker 之间：独立（无共享），通过共享内存（`shared:SSL:1m`）共享只读数据

**异步非阻塞**：

```
worker 处理请求流程：
1. epoll_wait() ──> 监听 fd 事件
2. fd 可读 ──> recv() 非阻塞读
3. 数据未到 ──> 立即返回，处理其他 fd
4. 数据到 ──> 业务处理
5. fd 可写 ──> send() 写回客户端

全程不阻塞，单 worker 可处理万级并发连接
```

---

## §4 安装方式：yum vs 源码编译

### 4.1 YUM 安装（推荐快速上手）

```bash
# 安装 EPEL 源（Nginx 在 epel 仓库）
[root@nginx-server ~]# wget -O /etc/yum.repos.d/epel.repo \
  http://mirrors.aliyun.com/repo/epel-7.repo

# 安装 Nginx
[root@nginx-server ~]# yum -y install nginx

# 启动 + 开机自启
[root@nginx-server ~]# systemctl enable nginx --now

# 防火墙放行
[root@nginx-server ~]# firewall-cmd --add-service=http --permanent
[root@nginx-server ~]# firewall-cmd --reload
```

**YUM 安装路径**（CentOS-7）：

| 路径 | 作用 |
|---|---|
| `/etc/nginx/nginx.conf` | 主配置 |
| `/etc/nginx/conf.d/*.conf` | 虚拟主机配置 |
| `/etc/nginx/default.d/*.conf` | 默认虚拟主机 |
| `/usr/share/nginx/html/` | 网站根目录 |
| `/var/log/nginx/` | 日志 |
| `/usr/libexec/nginx/` | 模块 |

### 4.2 源码编译（推荐生产环境）

**为什么生产用源码编译**：
- 可指定自定义模块（`--with-http_stub_status_module` 监控）
- 性能优化编译参数
- 版本可控

```bash
# 安装编译依赖
[root@nginx-server ~]# yum -y install gcc pcre-devel openssl-devel zlib-devel

# 解压源码（教材附件 nginx-1.24.0.tar.gz）
[root@nginx-server ~]# tar -xzf nginx-1.24.0.tar.gz
[root@nginx-server ~]# cd nginx-1.24.0

# 配置（指定安装路径 + SSL + 状态监控）
[root@nginx-server nginx-1.24.0]# ./configure \
  --prefix=/usr/local/nginx \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_gzip_static_module \
  --with-http_realip_module

# 编译 + 安装
[root@nginx-server nginx-1.24.0]# make && make install

# 创建用户
[root@nginx-server ~]# useradd -r -s /sbin/nologin nginx

# 启动
[root@nginx-server ~]# /usr/local/nginx/sbin/nginx
```

**`./configure` 关键参数**：

| 参数                               | 作用                       |
| -------------------------------- | ------------------------ |
| `--prefix=/usr/local/nginx`      | 安装根目录                    |
| `--user=nginx`                   | 运行用户                     |
| `--with-http_ssl_module`         | HTTPS 支持                 |
| `--with-http_stub_status_module` | 状态监控（Active connections） |
| `--with-http_gzip_static_module` | 预压缩文件                    |
| `--with-http_realip_module`      | 获取真实客户端 IP（配合反向代理）       |
| `--with-http_v2_module`          | HTTP/2 支持                |
| `--with-stream`                  | 四层 TCP/UDP 代理            |

---

## §5 目录结构：sbin / conf / html / logs

**源码安装版目录树**：

```
/usr/local/nginx/
├── sbin/
│   └── nginx                  # 主程序（二进制）
├── conf/
│   ├── nginx.conf             # 主配置
│   ├── mime.types             # MIME 类型映射
│   └── fastcgi_params         # FastCGI 参数
├── html/
│   ├── index.html             # 默认首页
│   └── 50x.html               # 错误页
├── logs/
│   ├── access.log             # 访问日志
│   ├── error.log              # 错误日志
│   └── nginx.pid              # master PID 文件
├── client_body_temp/          # 客户端请求体临时目录
├── proxy_temp/                # 代理后端响应临时目录
├── fastcgi_temp/              # FastCGI 临时目录
├── uwsgi_temp/                # uwsgi 临时目录
└── scgi_temp/                 # scgi 临时目录
```

**YUM 安装版路径差异**：

| 用途 | 源码路径 | YUM 路径 |
|---|---|---|
| 主程序 | `/usr/local/nginx/sbin/nginx` | `/usr/sbin/nginx` |
| 主配置 | `/usr/local/nginx/conf/nginx.conf` | `/etc/nginx/nginx.conf` |
| 站点目录 | `/usr/local/nginx/html/` | `/usr/share/nginx/html/` |
| 日志 | `/usr/local/nginx/logs/` | `/var/log/nginx/` |
| PID | `/usr/local/nginx/logs/nginx.pid` | `/run/nginx.pid` |

---

## §6 nginx.conf 配置结构：main → events → http → server → location

**层级化、模块化** 的嵌套结构：

```
nginx.conf
├── main 全局块              ← 不嵌套，根级别
├── events 块                ← 网络连接
└── http 块                  ← HTTP 核心
    ├── http 全局配置
    ├── upstream 块          ← 负载均衡池（可选）
    └── server 块 × N        ← 虚拟主机
        └── location 块 × N  ← URL 路径规则
```

**示例完整结构**：

```nginx
# ============ main 全局块 ============
user nginx;                          # 运行用户
worker_processes auto;               # worker 进程数（= CPU 核数）
error_log /var/log/nginx/error.log;  # 错误日志
pid /run/nginx.pid;                  # PID 文件
include /usr/share/nginx/modules/*.conf;

# ============ events 块 ============
events {
    worker_connections 1024;         # 每 worker 最大连接数
    use epoll;                       # 事件模型
    multi_accept on;                 # 一次性接受多连接
}

# ============ http 块 ============
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 4096;
    include /etc/nginx/conf.d/*.conf;   # 模块化加载虚拟主机

    # ============ server 块（虚拟主机） ============
    server {
        listen       80;
        server_name  www.laogao.cloud;
        root         /usr/share/nginx/html;
        access_log   /var/log/nginx/www.access.log  main;

        # ============ location 块（URL 匹配） ============
        location / {
            index  index.html index.htm;
            try_files $uri $uri/ /index.html;
        }

        location = /404.html {
            # 精确匹配 404 页
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            include fastcgi_params;
        }
    }

    # 第二个虚拟主机
    server {
        listen 8080;
        server_name test.example.com;
    }
}
```

**include 模块化**：
- `/etc/nginx/nginx.conf` → 主配置
- `/etc/nginx/conf.d/*.conf` → 虚拟主机（每个域名一个文件）
- `/etc/nginx/default.d/*.conf` → 默认虚拟主机补充

**配置优先级规则**：
1. **同层级**：后定义的覆盖先定义
2. **不同层级**：子级覆盖父级（`location` 内的 `proxy_pass` 覆盖 `server` 内的）
3. **location 匹配**：`=` > `^~` > `~` / `~*` > 普通前缀 > `/`

---

## §7 全局配置：user / worker_processes / worker_rlimit_nofile

| 指令 | 默认值 | 说明 | 推荐值 |
|---|---|---|---|
| `user` | nobody | 运行 Nginx 的用户 | `nginx`（专用用户） |
| `worker_processes` | 1 | worker 进程数 | `auto` 或 `= CPU 核数` |
| `worker_rlimit_nofile` | 系统限制 | 每 worker 打开文件数 | `65535` |
| `worker_cpu_affinity` | 未设置 | worker CPU 亲和绑定 | `auto` 或手动指定 |
| `pid` | nginx.pid | PID 文件路径 | `/run/nginx.pid` |
| `error_log` | logs/error.log | 错误日志 | `/var/log/nginx/error.log` |
| `daemon` | on | 是否以守护进程运行 | `on` |
| `master_process` | on | 是否启用 master | `on`（生产必须） |

**示例**：

```nginx
user nginx;
worker_processes auto;                  # 自动 = CPU 核数
worker_rlimit_nofile 65535;             # 系统级文件句柄上限
error_log /var/log/nginx/error.log warn;  # 只记录 warn 及以上
pid /run/nginx.pid;
```

**worker_cpu_affinity**（绑核减少 CPU 缓存失效）：

```nginx
# 4 核 CPU：每个 worker 绑 1 个核
worker_processes 4;
worker_cpu_affinity 0001 0010 0100 1000;

# 8 核 CPU：每个 worker 绑 4 个核
worker_processes 2;
worker_cpu_affinity 00001111 11110000;
```

---

## §8 events 块：use epoll / worker_connections / multi_accept

```nginx
events {
    use epoll;                  # Linux 高性能事件模型
    worker_connections 1024;    # 每 worker 最大并发连接数
    multi_accept on;            # 一次性接受所有等待连接
    accept_mutex on;            # 防止惊群（worker 抢连接）
}
```

| 指令 | 默认值 | 说明 |
|---|---|---|
| `use` | 自动选择 | 事件模型：`epoll`（Linux）/ `kqueue`（BSD）/ `eventport`（Solaris） |
| `worker_connections` | 512 | 每 worker 最大连接数（含客户端 + 后端代理） |
| `multi_accept` | off | worker 是否一次性 accept 所有新连接 |
| `accept_mutex` | on | 防止多个 worker 抢同一连接（惊群） |

**最大并发数公式**：

```
最大并发连接数 = worker_processes × worker_connections
              = 8 × 1024
              = 8192（客户端连接）

若反向代理，最大处理请求 = worker_processes × worker_connections / 2
                       （一半连客户端，一半连后端）
```

> 💡 1 万并发需要：`worker_processes=8, worker_connections=2048` → 8 × 2048 = 16384。

---

## §9 http 块：mime.types / sendfile / tcp_nopush / keepalive / gzip

```nginx
http {
    # ============ MIME 类型 ============
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    types_hash_max_size 4096;

    # ============ 日志格式 ============
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;

    # ============ 高性能文件传输 ============
    sendfile        on;            # sendfile 系统调用，零拷贝
    tcp_nopush      on;            # 累积数据包，一次性发送（配合 sendfile）
    tcp_nodelay     on;            # 禁用 Nagle 算法（小包即时发）

    # ============ 长连接 ============
    keepalive_timeout      65;     # 长连接超时 65 秒
    keepalive_requests     100;    # 单连接最大请求数

    # ============ 压缩 ============
    gzip  on;
    gzip_min_length 1k;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript;

    # ============ 模块化 ============
    include /etc/nginx/conf.d/*.conf;
}
```

**关键指令详解**：

| 指令                    | 默认   | 说明                                   |
| --------------------- | ---- | ------------------------------------ |
| `sendfile`            | off  | 零拷贝传输：内核直接从磁盘 → socket，不经过用户空间       |
| `tcp_nopush`          | off  | 在 sendfile on 时生效，累积数据包到 MSS 大小再发送   |
| `tcp_nodelay`         | on   | 禁用 Nagle 算法，小包即时发送（与 tcp_nopush 二选一） |
| `keepalive_timeout`   | 75   | 长连接保持时间（秒）                           |
| `keepalive_requests`  | 1000 | 单个长连接最大请求数（防 DOS）                    |
| `gzip`                | off  | 响应压缩                                 |
| `types_hash_max_size` | 1024 | 类型哈希桶大小，影响 server_name 哈希            |

---

## §10 server 块：listen / server_name / root / index / access_log

```nginx
server {
    listen       80;                          # 监听端口
    listen       [::]:80;                     # IPv6
    server_name  www.laogao.cloud laogao.cloud;  # 域名（空格分隔多个）
    root         /usr/share/nginx/html;       # 网站根目录
    index        index.html index.htm;        # 默认首页
    charset      utf-8;                       # 字符集
    access_log   /var/log/nginx/www.access.log main;
    error_log    /var/log/nginx/www.error.log;

    # 错误页
    error_page 404             /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /404.html { root /usr/share/nginx/html; }
    location = /50x.html { root /usr/share/nginx/html; }
}
```

**server_name 匹配规则**：

| 写法                                         | 匹配               |
| ------------------------------------------ | ---------------- |
| `server_name _;`                           | 通配，匹配所有未明确指定的域名  |
| `server_name www.example.com;`             | 精确匹配             |
| `server_name *.example.com;`               | 通配符（仅前缀或后缀单 `*`） |
| `server_name ~^www\d+\.example\.com$;`     | 正则匹配（`~` 开头）     |
| `server_name www.example.com example.com;` | 多个，空格分隔          |

**多虚拟主机路由**：Nginx 根据请求的 `Host` 头匹配 `server_name`，命中第一个匹配项。

---

## §11 location 匹配规则：= / ^~ / ~ / ~* / 无修饰符

**location 语法**：

```
location [修饰符] 匹配模式 {
    ...
}
```

| 修饰符  | 名称           | 匹配规则                      | 优先级          |
| ---- | ------------ | ------------------------- | ------------ |
| `=`  | 精确匹配         | URI 必须**完全等于**模式          | **最高**       |
| `^~` | 前缀优先匹配       | URI **以**模式开头，**不再检查正则**  | **高**        |
| `~`  | 正则匹配（区分大小写）  | URI 符合正则                  | 中            |
| `~*` | 正则匹配（不区分大小写） | URI 符合正则                  | 中            |
| 无修饰符 | 普通前缀匹配       | URI **以**模式开头，**会继续检查正则** | 低（按**最长前缀**） |
| `/`  | 通用匹配         | 所有未命中的请求                  | 最低（兜底）       |

**核心规则**：

1. **先比 `=`**：`location = /exact` 立即返回，不再检查其他规则
2. **再比 `^~`**：命中后**跳过正则**
3. **再比正则**：多个正则按**定义顺序**，**先命中先生效**
4. **最后比普通前缀**：多个无修饰符 location，**最长前缀**优先
5. **最后兜底**：`location /` 兜底

---

## §12 location 优先级实战案例

### 案例 1：四种修饰符对比

```nginx
server {
    listen 80;
    server_name www.laogao.cloud;

    # 1. 精确匹配（最高）
    location = /login {
        return 200 "exact: /login";
    }

    # 2. 前缀优先匹配（跳过正则）
    location ^~ /static/ {
        return 200 "prefix-priority: /static/";
    }

    # 3. 正则匹配（区分大小写）
    location ~ \.php$ {
        return 200 "regex-case: .php$";
    }

    # 4. 正则匹配（不区分大小写）
    location ~* \.(jpg|png|gif)$ {
        return 200 "regex-icase: image";
    }

    # 5. 普通前缀匹配（最长优先）
    location /api/user/ {
        return 200 "prefix-longest: /api/user/";
    }

    # 6. 普通前缀匹配（短）
    location /api/ {
        return 200 "prefix: /api/";
    }

    # 7. 兜底
    location / {
        return 200 "fallback: /";
    }
}
```

**测试结果**：

| 请求 URL | 命中规则 | 返回 |
|---|---|---|
| `GET /login` | `= /login` | exact: /login |
| `GET /static/css/main.css` | `^~ /static/` | prefix-priority: /static/ |
| `GET /api/index.php` | `~ \.php$` | regex-case: .php$ |
| `GET /img/photo.JPG` | `~* \.(jpg\|png\|gif)$` | regex-icase: image |
| `GET /api/user/info` | `/api/user/`（最长） | prefix-longest |
| `GET /api/data` | `/api/` | prefix |
| `GET /anything` | `/` | fallback |

### 案例 2：`^~` vs 无修饰符

```nginx
location ^~ /static {     # 命中后跳过正则
    return 200 "static-priority";
}
location ~ /static.*\.html$ {
    return 200 "regex-html";
}
location /static {
    return 200 "static-normal";
}
```

请求 `/static/page.html`：
- 如果有 `^~ /static`：命中 `^~ /static`，**跳过正则**，返回 `static-priority`
- 如果无 `^~`：检查正则，命中 `~ /static.*\.html$`，返回 `regex-html`

### 案例 3：proxy_pass 末尾 `/` 决定 URL 重构

```nginx
# ============ 场景 1：proxy_pass 末尾带 / ============
location /api/ {
    proxy_pass http://192.168.1.102:9090/;
}
# 客户端请求 http://localhost/api/user/list
# → 转发到 http://192.168.1.102:9090/user/list（**剔除** /api/）

# ============ 场景 2：proxy_pass 末尾不带 / ============
location /api/ {
    proxy_pass http://192.168.1.102:9090;
}
# 客户端请求 http://localhost/api/user/list
# → 转发到 http://192.168.1.102:9090/api/user/list（**保留** /api/）
```

> 💡 **面试题**：`location /api/ { proxy_pass http://x.com/; }` 和 `proxy_pass http://x.com;` 区别？
> 答：末尾带 `/` **剔除 location 匹配的路径前缀**；不带 `/` **保留前缀**拼接到后端。

---

## §13 root vs alias 区别

| 指令 | 路径拼接 | 用途 |
|---|---|---|
| `root /var/www;` | 拼接路径 = `/var/www` + `/uri` | location 完整目录 |
| `alias /var/www;` | 替换路径 = `/var/www` + `/uri 中 location 部分之外` | 路径映射 |

**示例对比**：

```nginx
# ============ root 用法 ============
location /img/ {
    root /var/www;
}
# 请求 /img/logo.png → 文件路径 /var/www/img/logo.png

# ============ alias 用法 ============
location /img/ {
    alias /var/www/static/;
}
# 请求 /img/logo.png → 文件路径 /var/www/static/logo.png（**不包含 img**）
```

**关键差异**：
- `root` 会**拼接**完整 URI 到 root 后
- `alias` 会**替换** location 匹配部分为 alias 后路径
- alias 路径**必须以 `/` 结尾**（否则报错）
- alias 只能在 location 内使用

**等价写法**：

```nginx
location /nginx1 {
    root /var;
    index index.html;
}
# 等效于：
# location /nginx1 {
#     alias /var/nginx1;
#     index index.html;
# }
```

---

## §14 静态文件服务：try_files / expires 缓存

### 14.1 try_files 兜底

```nginx
location / {
    try_files $uri $uri/ /index.html;
    # 流程：
    # 1. 尝试访问 $uri 文件（如 /about）
    # 2. 尝试访问 $uri/ 目录（如 /about/）
    # 3. 都失败则 fallback 到 /index.html（SPA 路由）
}
```

**SPA（React/Vue）配置**：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### 14.2 expires 缓存

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 7d;                # 客户端缓存 7 天
    add_header Cache-Control "public, max-age=604800";
}

location ~* \.(woff2?|ttf)$ {
    expires 1y;
}
```

**expires 时间值**：

| 值 | 说明 |
|---|---|
| `off` | 不设置 |
| `max` | 永不过期（10 年） |
| `1h` | 1 小时 |
| `7d` | 7 天 |
| `1M` | 1 个月 |

---

## §15 反向代理：proxy_pass + proxy_set_header

**完整反向代理配置**：

```nginx
http {
    upstream backend_nginx {
        server 192.168.1.100:8080;
        server 192.168.1.101:8080;
    }

    server {
        listen 80;
        server_name www.laogao.cloud;

        location / {
            # 必加反向代理核心参数
            proxy_pass http://backend_nginx;

            # 传递客户端真实信息（后端日志才能看到真实 IP）
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # 超时与缓冲（可选）
            proxy_connect_timeout 30s;
            proxy_send_timeout    60s;
            proxy_read_timeout    60s;
            proxy_buffering       on;
            proxy_buffer_size     8k;
            proxy_buffers         8 16k;
        }

        # 单独路径代理
        location /api/ {
            proxy_pass http://192.168.1.102:9090/;   # 末尾 /，剔除 /api/
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

**proxy_set_header 必加三件套**：

| 头 | 值 | 作用 |
|---|---|---|
| `Host` | `$host` | 客户端访问的域名（后端虚拟主机路由需要） |
| `X-Real-IP` | `$remote_addr` | 客户端真实 IP（替代 $remote_addr） |
| `X-Forwarded-For` | `$proxy_add_x_forwarded_for` | IP 链路（多层代理时累加） |

**proxy_pass 末尾 `/` 规则**（关键）：

| location | proxy_pass | 客户端请求 | 转发到后端 |
|---|---|---|---|
| `/api/` | `http://x.com/` | `/api/user` | `http://x.com/user` |
| `/api/` | `http://x.com` | `/api/user` | `http://x.com/api/user` |
| `/api` | `http://x.com/` | `/api/user` | `http://x.com/user`（不匹配，不推荐） |

> 💡 **推荐**：始终保持 location 路径和 proxy_pass 一致，末尾 `/` 要么都带要么都不带，避免混乱。

---

## §16 虚拟主机三种方式：域名 / 端口 / IP

### 16.1 基于域名（最常用）

```nginx
# /etc/nginx/conf.d/vhost-name.conf
server {
    server_name  web1.laogao.cloud;
    root         /usr/share/nginx/web1;
}
server {
    server_name  web2.laogao.cloud;
    root         /usr/share/nginx/web2;
}
```

```bash
# 准备目录
mkdir /usr/share/nginx/web{1,2}
echo "web1.laogao.cloud" > /usr/share/nginx/web1/index.html
echo "web2.laogao.cloud" > /usr/share/nginx/web2/index.html
systemctl restart nginx

# 客户端 hosts
10.1.8.10 web1.laogao.cloud web2.laogao.cloud

# 测试
curl http://web1.laogao.cloud/    # → web1.laogao.cloud
curl http://web2.laogao.cloud/    # → web2.laogao.cloud
```

### 16.2 基于端口

```nginx
# /etc/nginx/conf.d/vhost-port.conf
server {
    listen       8081;
    server_name  www.laogao.cloud;
    root         /usr/share/nginx/8081;
}
server {
    listen       8082;
    server_name  www.laogao.cloud;
    root         /usr/share/nginx/8082;
}
```

```bash
mkdir /usr/share/nginx/808{1,2}
echo "8081" > /usr/share/nginx/8081/index.html
echo "8082" > /usr/share/nginx/8082/index.html
systemctl restart nginx

curl http://www.laogao.cloud:8081  # → 8081
curl http://www.laogao.cloud:8082  # → 8082
```

### 16.3 基于 IP（几乎不用）

```nginx
server {
    listen       10.1.8.10:80;
    server_name  _;
    root         /usr/share/nginx/ip1;
}
server {
    listen       10.1.8.11:80;     # 需要服务器有多个 IP
    server_name  _;
    root         /usr/share/nginx/ip2;
}
```

---

## §17 upstream 负载均衡基础

**upstream 语法**：

```nginx
upstream name {
    server backend1.example.com:80;
    server 127.0.0.1:8080 weight=5;
    server unix:/tmp/backend2;
    keepalive 32;     # 缓存到 upstream 的连接数
}
```

**基本示例**：

```nginx
http {
    upstream backends {
        server nginx1.laogao.cloud:80;
        server nginx2.laogao.cloud:80;
        server nginx3.laogao.cloud:80;
    }

    server {
        listen 80;
        server_name www.laogao.cloud;

        location / {
            proxy_pass http://backends/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

**测试结果**（默认 rr）：

```bash
[root@client ~]# for n in {1..90}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
     30 Welcome to nginx1.laogao.cloud
     30 Welcome to nginx2.laogao.cloud
     30 Welcome to nginx3.laogao.cloud
```

**server 指令参数**：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `weight=N` | 1 | 权重（轮询比例） |
| `max_fails=N` | 1 | 最大失败次数（健康检查） |
| `fail_timeout=Ns` | 10s | 失败超时时间 |
| `backup` | - | 备用服务器（仅所有主服务器宕机时启动） |
| `down` | - | 标记为下线（永久移除） |
| `max_conns=N` | 0 | 最大并发连接数（0 = 无限） |
| `slow_start=Ns` | 0 | 慢启动时间（热上线） |

**示例**：

```nginx
upstream backends {
    keepalive 32;
    server nginx1.laogao.cloud:80 max_fails=3 fail_timeout=30s;
    server nginx2.laogao.cloud:80 max_fails=3 fail_timeout=30s weight=2;
    server nginx3.laogao.cloud:80 max_fails=3 fail_timeout=30s backup;
    server nginx4.laogao.cloud:80 max_fails=3 fail_timeout=30s down;
}
```

---

## §18 调度算法 1：轮询 rr

**轮询（round-robin）**：Nginx 默认算法。

```nginx
upstream backends {
    server nginx1.laogao.cloud:80;
    server nginx2.laogao.cloud:80;
    server nginx3.laogao.cloud:80;
}
```

**原理**：按请求顺序逐一分配给不同后端。

**测试**：

```bash
# 90 个请求均匀分配到 3 台后端
for n in {1..90}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
     30 Welcome to nginx1.laogao.cloud
     30 Welcome to nginx2.laogao.cloud
     30 Welcome to nginx3.laogao.cloud
```

**故障自动剔除**：Nginx 默认只检测 80 端口（HTTP 探测），若后端宕机则自动从池中剔除。

---

## §19 调度算法 2：权重 weight

**weight**：在 rr 基础上按权重比例分配。

```nginx
upstream backends {
    server nginx1.laogao.cloud:80 weight=10;
    server nginx2.laogao.cloud:80 weight=20;
    server nginx3.laogao.cloud:80 weight=30;
}
```

**测试**（600 个请求）：

```bash
for n in {1..600}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
    100 Welcome to nginx1.laogao.cloud   # 600 × 10/60 = 100
    200 Welcome to nginx2.laogao.cloud   # 600 × 20/60 = 200
    300 Welcome to nginx3.laogao.cloud   # 600 × 30/60 = 300
```

**公式**：`节点请求数 = 总请求数 × (本节点 weight / 权重总和)`

**场景**：
- 服务器性能不均（新机器 CPU 多，老机器配置低）
- 灰度发布（按比例切流量）
- 临时扩容（增加某个节点权重）

---

## §20 调度算法 3：ip_hash 会话保持

**ip_hash**：按客户端 IP 哈希分配，**同一 IP 固定到同一后端**。

```nginx
upstream backends {
    ip_hash;
    server nginx1.laogao.cloud:80;
    server nginx2.laogao.cloud:80;
    server nginx3.laogao.cloud:80;
}
```

**测试**（100 个请求）：

```bash
for n in {1..100}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
    100 Welcome to nginx2.laogao.cloud   # 客户端 IP 哈希命中 nginx2
```

**作用**：解决动态网页 **session 共享问题**（用户登录态保持）。

**缺点**：
- 国内 NAT 模式下，**多个客户端共享同一 IP**，会被分配到同一后端，**负载不均**
- 1:1 负载均衡难保证

**对比**：
- `ip_hash` ≈ LVS `-p` ≈ Keepalived `persistence_timeout 50`
- 都能解决 session 共享

> 💡 **面试题**：session 共享方案？
> 答：①Nginx `ip_hash`（同 IP 同后端）；②后端 session 存 Redis；③Spring Session + Redis。

---

## §21 调度算法 4：hash $request_uri

**hash**：按用户自定义键哈希（文本、变量或组合）。

```nginx
upstream backends {
    hash $request_uri;          # 按 URL 哈希
    server nginx1.laogao.cloud:80;
    server nginx2.laogao.cloud:80;
    server nginx3.laogao.cloud:80;
}
```

**测试**（100 个请求，同 URL）：

```bash
for n in {1..100}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
    100 Welcome to nginx3.laogao.cloud   # URL 哈希命中 nginx3
```

**特性**：
- 同一 URL **固定路由到同一后端**（缓存命中率提升）
- nginx 不支持 `url_hash`（需装第三方 hash 模块），但 `hash $request_uri` 等价
- hash 语句中**不能写入 weight**

**场景**：
- 后端是 **缓存服务器**（Squid/Varnish），按 URL 路由提高缓存命中
- 后端需要保持特定请求的状态

---

## §22 调度算法 5：least_conn 最少连接

**least_conn**：请求分发给**当前连接数最少**的服务器。

```nginx
upstream backends {
    least_conn;
    server nginx1.laogao.cloud:80;
    server nginx2.laogao.cloud:80;
    server nginx3.laogao.cloud:80;
}
```

**测试**（60 个请求）：

```bash
for n in {1..60}; do curl http://www.laogao.cloud -s; done | sort | uniq -c
     20 Welcome to nginx1.laogao.cloud
     19 Welcome to nginx2.laogao.cloud
     21 Welcome to nginx3.laogao.cloud
```

**原理**：动态感知后端负载，连接数少 = 处理快 = 优先分配。

**支持权重**：

```nginx
upstream backends {
    least_conn;
    server nginx1.laogao.cloud:80 weight=2;   # 高性能机器权重高
    server nginx2.laogao.cloud:80 weight=1;
}
```

**额外：Least Time（NGINX Plus 商业版）**：

```nginx
upstream backends {
    least_time header;       # 按响应第一个字节时间最短
    # 或 last_byte          # 按完整响应时间最短
    # 或 last_byte inflight # 考虑不完整请求
    server backend1.example.com;
}
```

---

## §23 upstream 健康检查：max_fails / fail_timeout

### 23.1 被动健康检查（默认）

Nginx 默认提供**被动健康检查**：通过 `max_fails` + `fail_timeout` 实现。

```nginx
upstream backends {
    server nginx1.laogao.cloud:80 max_fails=3 fail_timeout=30s;
    server nginx2.laogao.cloud:80 max_fails=3 fail_timeout=30s;
}
```

**规则**：
- `max_fails=3`：3 次失败后标记为不可用
- `fail_timeout=30s`：失败超时时间（同时是**熔断时间**）
- 30 秒后再次尝试探测，失败则继续熔断

### 23.2 主动健康检查（需第三方模块）

商业版 NGINX Plus 内置 `health_check`，开源版需 `nginx_upstream_check_module` 或 Tengine。

```nginx
upstream backends {
    server nginx1.laogao.cloud:80;
    server nginx2.laogao.cloud:80;
    check interval=3000 rise=2 fall=3 timeout=1000 type=http;
    check_http_send "GET /health HTTP/1.0\r\n\r\n";
    check_http_expect_alive http_2xx http_3xx;
}
```

---

## §24 URL 重写 rewrite regex replacement flag

**语法**：

```
rewrite regex replacement [flag];
```

| flag | 行为 |
|---|---|
| `last` | 重写后**重新匹配** location（重新走 location 优先级） |
| `break` | 重写后**不再匹配** rewrite/location |
| `redirect` | 返回 **302** 临时重定向（客户端跳转） |
| `permanent` | 返回 **301** 永久重定向（客户端跳转） |

**示例**：

```nginx
# 1. URL 路径去除前缀（配合 proxy_pass 无末尾 /）
location /nginx[12] {
    rewrite ^/nginx[12](.*)$ $1 break;
    proxy_pass http://nginx2.laogao.cloud;
}

# 2. 强制 HTTPS
server {
    listen 80;
    server_name www.laogao.cloud;
    rewrite ^(.*)$ https://$host$1 permanent;
}

# 3. 域名跳转
server {
    listen 80;
    server_name old.example.com;
    rewrite ^/(.*)$ http://new.example.com/$1 permanent;
}

# 4. 移动端跳转
if ($http_user_agent ~* "Android|iPhone") {
    rewrite ^/(.*)$ /mobile/$1 last;
}
```

**rewrite 与 return 区别**：

| 特性 | rewrite | return |
|---|---|---|
| 用途 | URL 重写（内部或外部） | **直接返回**状态码 |
| 正则 | 支持 | 不支持 |
| 性能 | 低（正则匹配） | **高**（简单） |

**推荐**：能用 `return` 就不要用 `rewrite`（性能更好）。

---

## §25 return 指令：直接返回状态码

```nginx
# ============ 强制 HTTPS（推荐）============
server {
    listen 80;
    server_name www.laogao.cloud;
    return 301 https://$host$request_uri;
}

# ============ 单页面重定向 ============
server {
    listen 80;
    server_name old.example.com;
    return 301 http://new.example.com;
}

# ============ 维护页 ============
location / {
    return 503;
    # 或返回内容：
    # return 200 "Site under maintenance\n";
}

# ============ error_page 替代 ============
location = /favicon.ico {
    return 204;
}
```

**return code [text|url]**：
- `return 200 "OK"`：返回内容
- `return 301 http://...`：永久重定向
- `return 302 http://...`：临时重定向
- `return 403`：禁止访问
- `return 404`：不存在
- `return 503`：服务不可用

---

## §26 HTTPS 配置：ssl_certificate + ssl_protocols

### 26.1 完整 HTTPS server 块

```nginx
server {
    listen       443 ssl http2;
    listen       [::]:443 ssl http2;
    server_name  www.laogao.cloud;
    root         /usr/share/nginx/html;

    # ============ 证书 ============
    ssl_certificate     "/etc/ssl/certs/www.laogao.cloud/www.crt";
    ssl_certificate_key "/etc/ssl/certs/www.laogao.cloud/www.key";

    # ============ SSL 会话优化 ============
    ssl_session_cache    shared:SSL:1m;     # 1MB 共享缓存
    ssl_session_timeout  10m;              # 会话超时 10 分钟
    ssl_session_tickets  on;

    # ============ 协议与加密套件 ============
    ssl_protocols       TLSv1.2 TLSv1.3;   # 只允许 TLS 1.2+（禁用 SSLv3）
    ssl_ciphers         ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers  on;          # 优先服务端套件

    # ============ HSTS（强制 HTTPS）============
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ============ OCSP Stapling ============
    ssl_stapling         on;
    ssl_stapling_verify  on;
    ssl_trusted_certificate /etc/ssl/certs/ca-bundle.crt;

    # ============ 其他安全头 ============
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### 26.2 SSL 指令详解

| 指令 | 推荐值 | 说明 |
|---|---|---|
| `ssl_protocols` | `TLSv1.2 TLSv1.3` | 禁 SSLv3 / TLSv1.0 / TLSv1.1 |
| `ssl_ciphers` | 见上 | 高强度加密套件 |
| `ssl_prefer_server_ciphers` | on | 优先服务端套件 |
| `ssl_session_cache` | `shared:SSL:10m` | 共享会话缓存（10MB ≈ 40000 会话） |
| `ssl_session_timeout` | `1d` | 会话超时（减少握手） |
| `ssl_stapling` | on | OCSP Stapling（验证证书状态） |

### 26.3 自签证书（测试用）

```bash
# 1. 生成私钥
openssl genrsa -out www.key 2048

# 2. 生成证书请求（CSR）
openssl req -new -key www.key -out www.csr -subj \
  "/C=CN/ST=JS/L=NJ/O=LG/OU=DEVOPS/CN=www.laogao.cloud/emailAddress=webadmin@laogao.cloud"
# CN 的值必须是网站域名

# 3. 用私钥自签名生成证书
openssl x509 -req -days 3650 -in www.csr -signkey www.key -out www.crt

# 4. 部署
mkdir /etc/ssl/certs/www.laogao.cloud
mv www* /etc/ssl/certs/www.laogao.cloud/
```

---

## §27 Let's Encrypt 免费证书 certbot

### 27.1 安装 certbot

```bash
# CentOS-7
yum -y install epel-release
yum -y install certbot python2-certbot-nginx

# Ubuntu / Debian
apt install certbot python3-certbot-nginx
```

### 27.2 申请证书（自动配置 Nginx）

```bash
# 自动模式：certbot 自动改 Nginx 配置
certbot --nginx -d www.laogao.cloud -d laogao.cloud

# 手动模式：仅申请证书，不动 Nginx
certbot certonly --nginx -d www.laogao.cloud

# 独立模式（80 端口需要可用）
certbot certonly --standalone -d www.laogao.cloud
```

**证书路径**：

```
/etc/letsencrypt/live/www.laogao.cloud/
├── fullchain.pem    ← 证书链（ssl_certificate 用）
├── privkey.pem      ← 私钥（ssl_certificate_key 用）
├── cert.pem         ← 证书
└── chain.pem        ← 链证书
```

### 27.3 自动续期

```bash
# 测试续期（不实际执行）
certbot renew --dry-run

# 自动续期（Crontab 每天检查）
0 3 * * * certbot renew --quiet --post-hook "systemctl reload nginx"
```

**证书有效期**：90 天，**必须自动续期**。

### 27.4 手工配置（certonly 模式）

```nginx
server {
    listen 443 ssl http2;
    server_name www.laogao.cloud;

    ssl_certificate     /etc/letsencrypt/live/www.laogao.cloud/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/www.laogao.cloud/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
}
```

---

## §28 HTTP 重定向到 HTTPS

### 28.1 return 方式（推荐）

```nginx
server {
    listen       80;
    listen       [::]:80;
    server_name  www.laogao.cloud;
    root         /usr/share/nginx/html;

    return       301 https://$host$request_uri;
}
```

### 28.2 rewrite 方式

```nginx
server {
    listen 80;
    server_name www.laogao.cloud;
    rewrite ^(.*)$ https://$host$1 permanent;
}
```

**测试**：

```bash
# HTTP 访问 → 301 重定向
curl http://www.laogao.cloud/
<html>
<head><title>301 Moved Permanently</title></head>
<body><center><h1>301 Moved Permanently</h1></center>
<hr><center>nginx/1.20.1</center></body></html>

# -k 跳过证书校验
curl -k https://www.laogao.cloud/

# -L 跟随重定向
curl -Lk http://www.laogao.cloud/
```

---

## §29 PHP 站点：php-fpm + fastcgi_pass

### 29.1 静态 vs 动态网页

| 类型 | 内容 | 后缀 | 生成方式 |
|---|---|---|---|
| **静态** | 文件现成 | `.html` `.htm` | 直接返回文件 |
| **动态** | 实时拼接 | `.php` `.jsp` `.asp` `.aspx` `.py` | 后端运行时生成 |

### 29.2 安装 PHP

```bash
# 安装 PHP + php-fpm
yum install -y php php-fpm

# 建议同时安装扩展
yum install -y php-gd php-common php-pear php-mbstring php-mcrypt

# 启用并启动 php-fpm
systemctl enable php-fpm --now

# 查看版本
php -v

# 测试 PHP
php -r "echo 'Hello PHP';"
echo "<?php echo 'PHP Test Page'.\"\n\"; ?>" > php_test.php
php php_test.php
```

### 29.3 PHP-FPM 工作流

```
客户端 → Nginx (fastcgi_pass :9000) → PHP-FPM (解析) → PHP (执行) → 返回结果
```

### 29.4 Nginx 配置 PHP

```nginx
server {
    listen       443 ssl http2;
    server_name  www.laogao.cloud;
    root         /usr/share/nginx/html;

    ssl_certificate     "/etc/ssl/certs/www.laogao.cloud/www.crt";
    ssl_certificate_key "/etc/ssl/certs/www.laogao.cloud/www.key";

    # ============ PHP 处理 ============
    location ~ \.php$ {
        # 防伪造 PHP 路径攻击（如 /xxx.php/yyy.jpg 被 PHP 解析）
        try_files $uri =404;

        # 转发到本地 9000 端口的 PHP-FPM
        fastcgi_pass 127.0.0.1:9000;

        # 默认索引
        fastcgi_index index.php;

        # PHP 文件绝对路径（$document_root + $fastcgi_script_name）
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        # 引入 FastCGI 参数（含 QUERY_STRING / REQUEST_METHOD 等）
        include fastcgi_params;
    }
}
```

**也可分离到 default.d**：

```nginx
# /etc/nginx/default.d/php.conf
location ~ \.php$ {
    try_files $uri =404;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

---

## §30 Basic Auth：auth_basic + htpasswd

**适用场景**：临时密码保护（**HTTP Basic Auth 是明文传输，必须配合 HTTPS**）。

```bash
# 安装工具
yum -y install httpd-tools

# 创建用户（-c 创建新文件）
htpasswd -b -c /etc/nginx/.htpasswd laogao 123456

# 添加用户（追加到现有文件）
htpasswd -b /etc/nginx/.htpasswd user2 password2
```

**Nginx 配置**：

```nginx
server {
    listen 443 ssl http2;
    server_name www.laogao.cloud;
    root         /usr/share/nginx/html;

    ssl_certificate     "/etc/ssl/certs/www.laogao.cloud/www.crt";
    ssl_certificate_key "/etc/ssl/certs/www.laogao.cloud/www.key";

    location /auth-basic/ {
        auth_basic            "Basic Auth";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

**测试**：

```bash
# 创建测试页
mkdir /usr/share/nginx/html/auth-basic
cat > /usr/share/nginx/html/auth-basic/index.html <<EOF
<html><body>
<div style="width:100%;font-size:40px;font-weight:bold;text-align:center;">
Test Page for Basic Authentication
</div></body></html>
EOF

# 测试（-u 指定用户名密码）
curl -ku laogao:123456 https://www.laogao.cloud/auth-basic/
```

**特性**：
- 用户名密码以 **Base64 编码**（**明文等价**）
- 必须配 **HTTPS** 才安全
- 浏览器会弹窗提示输入账号密码

---

## §31 gzip 压缩

```nginx
http {
    # 启用压缩
    gzip                on;
    gzip_min_length     1k;        # 小于 1KB 不压缩（CPU 不划算）
    gzip_comp_level     5;         # 压缩级别 1-9（5 平衡）
    gzip_types          text/plain
                        text/css
                        text/xml
                        application/json
                        application/javascript
                        application/xml+rss
                        application/atom+xml
                        image/svg+xml;
    gzip_vary           on;        # Vary: Accept-Encoding（让 CDN 区分压缩与否）
    gzip_disable        "MSIE [1-6]\.";  # 禁用 IE6
}
```

**性能数据**（典型场景）：

| 文件类型 | 原始大小 | gzip 后 | 压缩比 |
|---|---|---|---|
| HTML | 100 KB | 25 KB | 75% |
| CSS | 50 KB | 12 KB | 76% |
| JS | 200 KB | 60 KB | 70% |
| JSON | 80 KB | 20 KB | 75% |

**`gzip_static` 预压缩**：

```nginx
# 静态预压缩（提前生成 .gz 文件）
location ~* \.(js|css|html)$ {
    gzip_static on;
    expires 7d;
}
```

```bash
# 提前压缩源文件
gzip file.js    # 生成 file.js.gz
```

> 💡 预压缩让 Nginx 直接发送 `.gz` 文件，**零 CPU 消耗**。

---

## §32 防盗链：valid_referers

**适用场景**：防止图片 / 视频被其他网站直接引用（占带宽）。

```nginx
location ~* \.(jpg|jpeg|png|gif|bmp|swf|flv|mp4)$ {
    # 白名单 Referer
    valid_referers none blocked server_names
                   *.laogao.com laogao.com
                   *.baidu.com *.google.com;

    # 非白名单返回 403
    if ($invalid_referer) {
        return 403;
    }

    # 或返回防盗链图片
    # rewrite ^/ https://www.laogao.com/anti-steal-link.png;
}
```

**`valid_referers` 参数**：

| 值 | 含义 |
|---|---|
| `none` | 没有 Referer（直接访问、curl） |
| `blocked` | Referer 被防火墙删除 |
| `server_names` | `server_name` 列表 |
| `*.example.com` | 通配符域名 |

**测试**：

```bash
# 白名单内（带 Referer）
curl -e "http://www.baidu.com" http://www.laogao.cloud/img.jpg     # → 200

# 非白名单
curl http://www.laogao.cloud/img.jpg                                # → 403
```

---

## §33 限流：limit_req_zone + limit_conn_zone

### 33.1 请求速率限流（漏桶算法）

```nginx
http {
    # 定义限流区域：$binary_remote_addr 为 key，10MB 内存，每秒 10 个请求
    limit_req_zone $binary_remote_addr zone=req_limit:10m rate=10r/s;

    server {
        location /api/ {
            # 应用限流（burst=20 允许突发 20 个排队，nodelay 立即处理）
            limit_req zone=req_limit burst=20 nodelay;

            proxy_pass http://backend;
        }
    }
}
```

**参数详解**：

| 参数 | 含义 |
|---|---|
| `zone=name:size` | 共享内存区域（10MB ≈ 16 万 IP） |
| `rate=Nr/s` | 每秒 N 个请求（可写 `30r/m` 每分钟 30 个） |
| `burst=N` | 突发队列长度（超出 rate 的请求排队等待） |
| `nodelay` | 队列立即处理（不延迟排队） |

### 33.2 并发连接数限流

```nginx
http {
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    server {
        location /download/ {
            limit_conn conn_limit 5;    # 每 IP 最多 5 个并发连接
            limit_rate 100k;            # 每连接限速 100 KB/s
        }
    }
}
```

**返回状态码**：超出限流返回 **503**。

---

## §34 访问控制：allow / deny + geo

### 34.1 基于 IP 的访问控制

```nginx
location /admin/ {
    # 只允许内网
    allow 10.0.0.0/8;
    allow 192.168.0.0/16;
    allow 127.0.0.1;
    deny  all;
}

location / {
    allow all;   # 默认全开
}
```

**规则**：按顺序匹配，**命中即返回**（`deny all` 放最后兜底）。

### 34.2 基于地理位置（geo 模块）

```nginx
http {
    # 定义国家代码
    geo $country {
        default CN;
        10.0.0.0/8     US;       # 内网伪装成美国
        192.168.0.0/16  JP;
    }

    server {
        location / {
            if ($country = US) {
                return 200 "Welcome US visitor\n";
            }
            if ($country = CN) {
                return 200 "中国用户欢迎\n";
            }
            return 403;
        }
    }
}
```

### 34.3 map 模块（变量映射）

```nginx
http {
    map $http_user_agent $is_bot {
        default 0;
        ~*bot    1;
        ~*spider 1;
        ~*crawl  1;
    }

    server {
        location / {
            if ($is_bot) {
                return 403;
            }
        }
    }
}
```

---

## §35 日志格式：log_format + access_log + logrotate

### 35.1 自定义日志格式

```nginx
http {
    # JSON 格式（方便 ELK 收集）
    log_format json_combined escape=json
        '{'
            '"time_local":"$time_local",'
            '"remote_addr":"$remote_addr",'
            '"remote_user":"$remote_user",'
            '"request":"$request",'
            '"status":"$status",'
            '"body_bytes_sent":"$body_bytes_sent",'
            '"request_time":"$request_time",'
            '"upstream_response_time":"$upstream_response_time",'
            '"upstream_addr":"$upstream_addr",'
            '"http_referer":"$http_referer",'
            '"http_user_agent":"$http_user_agent",'
            '"http_x_forwarded_for":"$http_x_forwarded_for"'
        '}';

    access_log /var/log/nginx/access.log json_combined;
}
```

**常用日志变量**：

| 变量 | 含义 |
|---|---|
| `$remote_addr` | 客户端 IP |
| `$time_local` | 本地时间 `01/Jul/2026:12:00:00 +0800` |
| `$request` | 完整请求 `GET / HTTP/1.1` |
| `$status` | 响应状态码 |
| `$body_bytes_sent` | 发送字节数（不含响应头） |
| `$request_time` | 请求处理时间（秒，浮点） |
| `$upstream_response_time` | 上游响应时间 |
| `$upstream_addr` | 上游地址 |
| `$http_referer` | 来源页 |
| `$http_user_agent` | User-Agent |
| `$http_x_forwarded_for` | IP 链路 |

### 35.2 日志切割（logrotate）

```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily                      # 每天切割
    rotate 14                  # 保留 14 天
    missingok                  # 缺失不报错
    notifempty                 # 空文件不切割
    compress                   # 压缩旧日志
    delaycompress              # 延迟压缩
    sharedscripts              # 多个日志共享脚本
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 $(cat /var/run/nginx.pid)
    endscript
}
```

**USR1 信号**：通知 Nginx **重新打开日志文件**（不重启服务）。

### 35.3 按虚拟主机分割日志

```nginx
server {
    server_name a.example.com;
    access_log /var/log/nginx/a.access.log main;
    error_log  /var/log/nginx/a.error.log;
}

server {
    server_name b.example.com;
    access_log /var/log/nginx/b.access.log main;
    error_log  /var/log/nginx/b.error.log;
}
```

---

## §36 stub_status 监控

**启用**（需编译时 `--with-http_stub_status_module`）：

```nginx
server {
    listen 80;
    server_name status.example.com;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 10.0.0.0/8;       # 只允许内网
        deny all;
    }
}
```

**访问输出**：

```bash
$ curl http://status.example.com/nginx_status

Active connections: 3         ← 当前活跃连接数
server accepts handled requests
 100 100 200                  ← 已接受连接 / 已处理连接 / 总请求数
Reading: 0 Writing: 1 Waiting: 2
```

**字段含义**：

| 字段 | 含义 |
|---|---|
| `Active connections` | 当前活跃连接数（含 Reading/Writing/Waiting） |
| `accepts` | worker 接受的总连接数 |
| `handled` | 实际处理的连接数（accepts - 拒绝） |
| `requests` | 总请求数（HTTP/1.0 一个连接算 1 个；HTTP/1.1 长连接可多个） |
| `Reading` | 正在读客户端请求 |
| `Writing` | 正在写响应给客户端 |
| `Waiting` | 空闲长连接（keepalive） |

**监控脚本**（Zabbix / Prometheus）：

```bash
#!/bin/bash
# 监控活跃连接数
ACTIVE=$(curl -s http://status.example.com/nginx_status | awk '/Active/ {print $3}')
echo "Nginx active connections: $ACTIVE"
```

---

## §37 性能调优：worker_processes / sendfile / tcp_nopush

### 37.1 完整调优配置

```nginx
user nginx;
worker_processes auto;                  # = CPU 核数
worker_cpu_affinity auto;               # 自动绑核
worker_rlimit_nofile 65535;             # 文件句柄上限

events {
    worker_connections 20480;            # 每 worker 20480 连接
    use epoll;                           # Linux 高性能事件模型
    multi_accept on;                     # 一次性 accept
    accept_mutex off;                    # Linux 3.9+ 不需要
}

http {
    # ============ 基础性能 ============
    sendfile          on;                # 零拷贝
    tcp_nopush        on;                # 累积发送
    tcp_nodelay       on;                # 即时发送小包
    keepalive_timeout 30;
    keepalive_requests 1000;

    # ============ 压缩 ============
    gzip on;
    gzip_min_length 1k;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript;

    # ============ 缓冲 ============
    client_body_buffer_size        16k;
    client_max_body_size           16m;
    client_header_buffer_size      1k;
    large_client_header_buffers    4 8k;

    # ============ 超时 ============
    client_body_timeout   12;
    client_header_timeout 12;
    send_timeout          10;
    keepalive_timeout     30;

    # ============ 文件缓存 ============
    open_file_cache          max=10000 inactive=20s;
    open_file_cache_valid    30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors   on;

    include /etc/nginx/conf.d/*.conf;
}
```

### 37.2 系统级调优（/etc/security/limits.conf）

```bash
# 提高文件句柄上限
nginx  soft  nofile  65535
nginx  hard  nofile  65535

# 或全局
*  soft  nofile  65535
*  hard  nofile  65535
```

### 37.3 内核参数（/etc/sysctl.conf）

```bash
# 网络优化
net.core.somaxconn = 65535            # listen 队列长度
net.ipv4.tcp_max_syn_backlog = 65535  # SYN 队列长度
net.ipv4.tcp_tw_reuse = 1             # 复用 TIME_WAIT 连接
net.ipv4.tcp_keepalive_time = 600     # keepalive 探测间隔

sysctl -p                              # 生效
```

### 37.4 性能参数速查

| 参数 | 推荐值 | 说明 |
|---|---|---|
| `worker_processes` | `auto` / `= CPU 核数` | CPU 核数 |
| `worker_connections` | `10240-20480` | 单 worker 最大连接 |
| `worker_rlimit_nofile` | `65535` | 文件句柄上限 |
| `sendfile` | `on` | 零拷贝 |
| `tcp_nopush` | `on` | 累积发包 |
| `tcp_nodelay` | `on` | 即时小包 |
| `keepalive_timeout` | `30-65` | 长连接超时 |
| `keepalive_requests` | `1000-10000` | 单连接请求数 |
| `gzip_comp_level` | `5-6` | 压缩级别 |
| `client_max_body_size` | `16m-100m` | 上传大小限制 |
| `open_file_cache` | `max=10000` | 文件描述符缓存 |

---

## §38 平滑升级：USR2 + WINCH + QUIT 三步走

**场景**：升级 Nginx 版本，**不中断服务**。

### 38.1 信号含义

| 信号 | 作用 |
|---|---|
| `USR1` | 重新打开日志（logrotate 用） |
| `USR2` | **热升级**（启动新 master，老 master 不退出） |
| `WINCH` | **优雅关闭 worker**（新 master 接管后，老 master 关闭 worker） |
| `QUIT` | **优雅关闭** master |
| `HUP` | 重读配置（reload） |
| `TERM` / `INT` | 快速关闭 |

### 38.2 平滑升级步骤

```bash
# 1. 备份旧版本
cp /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx.old

# 2. 编译新版本（不覆盖旧二进制）
./configure --prefix=/usr/local/nginx ... && make

# 3. 编译新版本（**不执行 make install**，只复制新二进制）
cp objs/nginx /usr/local/nginx/sbin/nginx.new

# 4. 发送 USR2 信号：启动新 master（并存）
kill -USR2 $(cat /usr/local/nginx/logs/nginx.pid)

# 此时：
# - 旧 master 继续运行（旧 PID）
# - 新 master 启动并接管（新 PID，nginx.pid 改为新 PID）
# - 旧 master PID 保存到 nginx.pid.oldbin

# 5. 发送 WINCH 信号：优雅关闭旧 master 的 worker
kill -WINCH $(cat /usr/local/nginx/logs/nginx.pid.oldbin)
# 新 master 接管所有 worker，旧 master 进入 idle

# 6. 测试新版本正常后，关闭旧 master
kill -QUIT $(cat /usr/local/nginx/logs/nginx.pid.oldbin)

# 7. 清理
rm /usr/local/nginx/sbin/nginx.old
rm /usr/local/nginx/logs/nginx.pid.oldbin
```

### 38.3 平滑回滚

```bash
# 如果新版本有问题：
cp /usr/local/nginx/sbin/nginx.old /usr/local/nginx/sbin/nginx

# 回滚步骤
kill -USR2 $(cat /usr/local/nginx/logs/nginx.pid)      # 启动旧 master
kill -WINCH $(cat /usr/local/nginx/logs/nginx.pid.oldbin)  # 关闭新 worker
kill -QUIT $(cat /usr/local/nginx/logs/nginx.pid.oldbin)   # 关闭新 master
```

---

## §39 systemd 部署 nginx.service

**CentOS-7 自带**：`/usr/lib/systemd/system/nginx.service`

**自定义**（源码编译版）：`/etc/systemd/system/nginx.service`

```ini
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
LimitNOFILE=65535                       # 关键：提高文件句柄上限

[Install]
WantedBy=multi-user.target
```

**生效**：

```bash
systemctl daemon-reload
systemctl enable nginx --now
systemctl status nginx
```

**关键说明**：
- `Type=forking`：Nginx 后台运行（master fork 后退出）
- `LimitNOFILE=65535`：覆盖默认 1024，解决 "too many open files"
- `ExecStartPre -t`：启动前测试配置

---

## §40 易错点 ×10

### ❌ 1. proxy_pass 末尾 `/` 导致路径错误

```nginx
# 错误：客户端 /api/user/list 转发到 /api/api/user/list
location /api/ {
    proxy_pass http://backend;
}
# 正确：
location /api/ {
    proxy_pass http://backend/;
}
```

### ❌ 2. location 优先级混淆

```nginx
# 误以为 ~ 高于 ^~，实际：= > ^~ > ~ > 普通
location ~ \.php$ { return 200 "regex"; }
location ^~ /static/ { return 200 "prefix"; }   # 实际优先级高
```

### ❌ 3. root vs alias 路径混淆

```nginx
location /img {
    alias /var/www/static;       # 请求 /img/x.png → /var/www/static/x.png
}
location /img {
    root /var/www/static;        # 请求 /img/x.png → /var/www/static/img/x.png
}
```

### ❌ 4. HTTPS 证书路径错误

```nginx
# 错误：路径写错或权限不足
ssl_certificate /etc/nginx/cert/server.crt;       # Nginx 启动失败
ssl_certificate_key /etc/nginx/cert/server.key;   # 权限 600
# chmod 600 /etc/nginx/cert/server.key
```

### ❌ 5. 忘记设置 proxy_set_header

```nginx
# 错误：后端看不到真实客户端 IP
location / {
    proxy_pass http://backend;
}
# 正确：
location / {
    proxy_pass http://backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### ❌ 6. worker_connections 设置过小

```nginx
# 默认 1024，高并发远远不够
events {
    worker_connections 1024;       # 错误（8 核 = 8192 总连接）
    worker_connections 10240;      # 正确
}
```

### ❌ 7. ip_hash 后节点 down 无法访问

```nginx
# ip_hash 会一直尝试访问同一节点，down 后需用 backup
upstream backends {
    ip_hash;
    server backend1.example.com;
    server backend2.example.com;
    server backend3.example.com backup;   # 主都挂了才启动
}
```

### ❌ 8. Basic Auth 走 HTTP（明文）

```nginx
# 错误：Basic Auth 走 HTTP，用户名密码明文
server { listen 80; auth_basic ... }
# 正确：必须 HTTPS
server { listen 443 ssl; auth_basic ... }
```

### ❌ 9. rewrite 与 return 误用

```nginx
# 错误：能用 return 不用 rewrite（性能差）
location /old { rewrite ^/old(.*)$ /new$1 permanent; }
# 正确：
location /old { return 301 /new$request_uri; }
```

### ❌ 10. sendfile 与 nginx 不匹配

```nginx
# 开启 sendfile 但用 try_files 处理动态
# sendfile 适合大静态文件传输，不适合频繁拼接
# 如无 sendfile 必要（如 NFS），可关闭
sendfile off;   # NFS / 网络文件系统
```

---

## §41 速查表

### 41.1 信号

| 信号 | 作用 |
|---|---|
| `nginx -s reload` | 等价 `kill -HUP` 重读配置 |
| `nginx -s reopen` | 等价 `kill -USR1` 重新打开日志 |
| `nginx -s stop` | 快速停止（强制） |
| `nginx -s quit` | 优雅停止（处理完当前请求） |
| `kill -USR2 PID` | 热升级 |
| `kill -WINCH PID` | 关闭 worker |
| `kill -QUIT PID` | 优雅停止 |

### 41.2 命令

| 命令 | 作用 |
|---|---|
| `nginx -t` | 测试配置 |
| `nginx -T` | 测试并打印完整配置 |
| `nginx -v` | 版本 |
| `nginx -V` | 版本 + 编译参数 |
| `nginx -c file` | 指定配置文件 |
| `nginx -p prefix` | 指定 prefix |
| `nginx -s signal` | 发信号 |

### 41.3 关键路径（YUM 安装版 / CentOS-7）

| 路径 | 作用 |
|---|---|
| `/etc/nginx/nginx.conf` | 主配置 |
| `/etc/nginx/conf.d/` | 虚拟主机目录 |
| `/etc/nginx/default.d/` | 默认虚拟主机补充 |
| `/etc/nginx/mime.types` | MIME 类型 |
| `/usr/share/nginx/html/` | 网站根目录 |
| `/var/log/nginx/` | 日志 |
| `/run/nginx.pid` | PID 文件 |
| `/usr/libexec/nginx/` | 模块路径 |

### 41.4 关键路径（源码安装版）

| 路径 | 作用 |
|---|---|
| `/usr/local/nginx/sbin/nginx` | 主程序 |
| `/usr/local/nginx/conf/nginx.conf` | 主配置 |
| `/usr/local/nginx/conf/mime.types` | MIME 类型 |
| `/usr/local/nginx/html/` | 网站根目录 |
| `/usr/local/nginx/logs/` | 日志 |
| `/usr/local/nginx/logs/nginx.pid` | PID 文件 |

### 41.5 location 优先级口诀

```
= 精确 → ^~ 前缀优先 → ~ / ~* 正则 → 无修饰符（最长前缀） → / 兜底
```

### 41.6 proxy_pass 末尾 `/` 口诀

```
location 带 /  + proxy_pass 带 /    →  剔除 location 前缀
location 带 /  + proxy_pass 不带 /  →  保留 location 前缀
```

### 41.7 upstream 算法速记

```
rr 默认 → weight 权重 → ip_hash 会话保持 → hash $request_uri 缓存路由 → least_conn 动态负载
```

---

## §42 面试 6 大追问

### Q1：Nginx 为什么比 Apache 高并发？

**答**：
1. **事件驱动**：Linux epoll，单 worker 处理万级连接
2. **异步非阻塞**：IO 不阻塞 worker
3. **多进程**：master + N worker（= CPU 核数），worker 间无锁
4. **内存占用低**：每连接 1 个 fd，无独立栈
5. **sendfile 零拷贝**：静态文件直接磁盘 → socket

Apache prefork 每连接 1 进程，进程切换 + 内存爆炸，无法支撑 C10K。

### Q2：location 优先级规则？`= ^~ ~ ~*` 区别？

**答**：

| 修饰符 | 优先级 | 说明 |
|---|---|---|
| `=` | **最高** | 精确匹配 URL |
| `^~` | **次高** | 前缀匹配，命中后**跳过正则** |
| `~` | 中 | 正则，区分大小写 |
| `~*` | 中 | 正则，不区分大小写 |
| 无 | 低 | 普通前缀，**最长前缀优先** |
| `/` | 最低 | 通用匹配（兜底） |

记忆口诀：`= 精确 → ^~ 前缀优先 → ~ / ~* 正则 → 无修饰符 → / 兜底`。

### Q3：Nginx 架构？master/worker 作用？

**答**：
- **master 进程（1 个）**：读取配置、绑定端口、fork worker、接收信号（USR2/WINCH/QUIT）
- **worker 进程（N 个 = CPU 核数）**：epoll 事件循环，接受客户端连接、处理请求、读取后端响应
- 进程间通信：通过**信号**（master ↔ worker）和**共享内存**（SSL 会话缓存）

### Q4：Nginx 反向代理流程？

**答**：
1. 客户端请求 `http://www.laogao.cloud/api/user`
2. Nginx 接收，匹配 `location /api/`
3. Nginx 读取后端地址（如 `192.168.1.100:8080`）
4. Nginx 作为客户端，与后端建立新连接（反向代理 = 既是服务端又是客户端）
5. Nginx 转发请求（修改 Host / X-Real-IP / X-Forwarded-For）
6. 后端响应，Nginx 接收
7. Nginx 返回给客户端
8. **核心**：`proxy_set_header` 三件套（Host / X-Real-IP / X-Forwarded-For）

### Q5：proxy_pass 末尾 `/` 的影响？

**答**：

| location | proxy_pass | 请求 URL | 转发到后端 |
|---|---|---|---|
| `/api/` | `http://x.com/` | `/api/user` | `http://x.com/user`（**剔除**） |
| `/api/` | `http://x.com` | `/api/user` | `http://x.com/api/user`（**保留**） |

**记忆**：proxy_pass 末尾带 `/` = **替换路径**（剔除 location 部分）；不带 `/` = **拼接路径**（保留 location 部分）。

### Q6：Nginx 负载均衡算法？ip_hash 适用场景？

**答**：
- **rr（轮询）**：默认，按顺序分配
- **weight（权重）**：按比例分配（性能不均的服务器）
- **ip_hash**：按客户端 IP 哈希，**解决 session 共享**问题（同 IP 固定到同后端）
- **hash**：按 URL 哈希，**提高缓存命中率**（同 URL 固定到同后端）
- **least_conn**：按连接数最少优先，**动态负载**（长连接场景）

ip_hash 缺点：NAT 模式下多客户端共享 IP，负载不均；session 共享方案对比：
- Nginx `ip_hash` ≈ LVS `-p` ≈ Keepalived `persistence_timeout 50`
- 后端 session 存 Redis（Spring Session）

---

## §43 跨模块链接

- **systemd 服务管理**：`[[Linux服务与SSH#§2 systemd 是什么：PID 1 + 一切皆 unit]]` — Nginx 由 systemd 托管
- **防火墙放行**：`[[Linux防火墙#§firewalld 命令]]` — 80/443 端口放行
- **PHP-FPM / FastCGI**：详见 [[Linux服务与SSH#systemd]]（php-fpm.service 同样由 systemd 管理）
- **LVS 负载均衡**：LinuxLVS 模块（四层 TCP/UDP 代理，与 Nginx 七层对比）
- **Keepalived 高可用**：LinuxKeepalived 模块（VRRP 协议 + Nginx 双机热备）
- **Web 实战**：LinuxWeb实战 模块（综合 LAMP + LNMP + Nginx 反向代理实战）

---

**完成日期**：2026-07-16
**整理人**：Nginx 学习小组
**版本**：v1.0