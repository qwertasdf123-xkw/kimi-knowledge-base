---
title: Linux Web 项目实战 — LAMP + WordPress + LNMP + ECshop
desc: LAMP/LNMP 架构部署 + WordPress 博客 + ECshop 电商平台 + 调优 + 故障排查
type: 笔记
module: LinuxWeb实战
pdf: 项目实战：LNMP-电商平台-ECshop.pdf + 项目实战：LAMP-博客平台-Wordpress.pdf
pdf_size: 5.8 MB + 0.6 MB
scope: LAMP/LNMP 完整部署 + 两个实战项目 + 性能对比
status: 完成
---

# Linux Web 项目实战 — LAMP + WordPress + LNMP + ECshop

> **范围**：基于两份 PDF 实战教材合并整理：
> 1. 《项目实战：LNMP-电商平台-ECshop.pdf》（7 页，ECShop_V4.1.20 商城部署）
> 2. 《项目实战：LAMP-博客平台-Wordpress.pdf》（6 页，WordPress-4.8 博客部署）
>
> **目标**：把前面学的 Web 服务（Apache / Nginx / PHP / MySQL）**串联起来**，完成两个完整的生产级项目部署，并补充架构对比、调优、安全、监控等通用知识。
>
> **适用**：CentOS 7.9 / RHEL 系。

## 目录

- [[#§0 心智模型：Web 项目实战 = 服务串联]]
- [[#§1 LAMP 架构概述]]
- [[#§2 LNMP 架构概述]]
- [[#§3 LAMP vs LNMP：Apache mod_php vs Nginx + php-fpm]]
- [[#§4 LAMP 环境准备]]
- [[#§5 Apache 部署]]
- [[#§6 MySQL/MariaDB 部署]]
- [[#§7 PHP 部署]]
- [[#§8 LAMP 联调：Apache + PHP + MySQL 测试]]
- [[#§9 WordPress 部署]]
- [[#§10 WordPress 配置]]
- [[#§11 WordPress 性能优化]]
- [[#§12 WordPress 安全加固]]
- [[#§13 WordPress 备份与迁移]]
- [[#§14 LNMP 环境准备]]
- [[#§15 Nginx + PHP-FPM]]
- [[#§16 Nginx 配置 PHP：fastcgi_pass 详解]]
- [[#§17 MariaDB 主主复制]]
- [[#§18 Keepalived + 双机热备]]
- [[#§19 ECshop 部署]]
- [[#§20 ECshop 配置]]
- [[#§21 ECshop 性能优化]]
- [[#§22 ECshop 故障排查]]
- [[#§23 LAMP vs LNMP 实测对比]]
- [[#§24 Web 项目通用安全]]
- [[#§25 Web 项目通用监控]]
- [[#§26 易错点 ×12]]
- [[#§27 速查表]]
- [[#§28 面试 6 大追问]]
- [[#§29 跨模块链接]]

---

## §0 心智模型：Web 项目实战 = 服务串联

前面学过的服务都是**独立模块**：

```
Web 四件套（独立学习）：
  Apache/Nginx  ── 处理 HTTP 请求
  MySQL/MariaDB ── 存储数据
  PHP/Python    ── 动态逻辑
```

实战 = 把它们**串成一条流水线**：

```
                   ┌─────────────────────────────────────┐
浏览器请求 →       │  Apache/Nginx（Web Server）          │
                   │   ├─ 静态文件直接返回                │
                   │   └─ .php 文件转发 PHP-FPM/mod_php  │
                   └────────────┬────────────────────────┘
                                ↓
                   ┌─────────────────────────────────────┐
                   │  PHP 解释器 / PHP-FPM               │
                   │   ├─ 解析 PHP 代码                  │
                   │   └─ 用 mysql 扩展连数据库          │
                   └────────────┬────────────────────────┘
                                ↓
                   ┌─────────────────────────────────────┐
                   │  MySQL/MariaDB                      │
                   │   └─ 返回数据 → PHP 渲染 → 返回 HTML │
                   └─────────────────────────────────────┘
```

**两种组合方式**：
- **LAMP**：Linux + **Apache** + MySQL + **PHP**（mod_php 嵌入 Apache）
- **LNMP**：Linux + **Nginx** + MySQL + **PHP**（PHP-FPM 独立进程）

**两个实战项目**：
| 项目 | 架构 | 软件 | 用途 |
|------|------|------|------|
| WordPress | LAMP | Apache + MariaDB + PHP | 个人博客 / 内容管理（CMS） |
| ECshop | LNMP | Nginx + MariaDB + PHP-FPM | 电商平台（B2C 商城） |

**关键认知**：
- Web 项目 ≠ 单一服务，而是**多个服务的组合**
- 每个组件都可以**水平扩展**（多台 Web、多台 DB、读写分离）
- 部署前要规划：**域名、目录、端口、数据库、用户、备份**

---

## §1 LAMP 架构概述

**LAMP** = **L**inux + **A**pache + **M**ySQL/MariaDB + **P**HP

```
┌──────────────────────────────────────────┐
│            LAMP 四层架构                  │
├──────────────────────────────────────────┤
│  L  Linux       CentOS / Ubuntu           │
│  A  Apache      httpd (Web 服务器)         │
│  M  MySQL       mariadb-server (数据库)   │
│  P  PHP         php + libphp (脚本解释器) │
└──────────────────────────────────────────┘
```

**协作流程**：
```
client → Apache :80 → mod_php 解析 → MySQL 查询 → 渲染 HTML → client
              │            │              │
              ↓            ↓              ↓
           静态文件     动态脚本        数据
```

**Apache mod_php 工作模式**：
- mod_php 作为 Apache 的**模块**装载
- Apache 进程**自带 PHP 解释器**，处理 `.php` 直接调用
- 一个进程处理一个请求，PHP 与 Apache 绑定
- 优点：**配置简单**、传统方案、`.htaccess` 灵活
- 缺点：**Apache 进程内存占用高**、PHP 故障会拖累 Apache

**LAMP 典型场景**：
- 中小企业官网
- 博客（WordPress）
- 内容管理（Drupal、Joomla）
- 传统 PHP 应用（兼容老代码）

---

## §2 LNMP 架构概述

**LNMP** = **L**inux + **N**ginx + **M**ySQL/MariaDB + **P**HP

```
┌──────────────────────────────────────────┐
│            LNMP 四层架构                  │
├──────────────────────────────────────────┤
│  L  Linux       CentOS / Ubuntu           │
│  N  Nginx       nginx (Web/反向代理)      │
│  M  MySQL       mariadb-server (数据库)   │
│  P  PHP         php-fpm (FastCGI 进程)    │
└──────────────────────────────────────────┘
```

**协作流程**：
```
client → Nginx :80 → 静态文件直返
              │
              └─→ fastcgi_pass → php-fpm :9000 → MySQL → 渲染 → client
```

**Nginx + PHP-FPM 模式**：
- Nginx 只负责 **HTTP/反向代理/静态文件**
- `.php` 请求通过 **FastCGI 协议** 转发给独立的 php-fpm 进程池
- php-fpm 是**常驻主进程 + 多 worker**，类似 PHP 的"独立服务器"
- 优点：**Nginx 轻量 + PHP-FPM 池可独立调优**、高并发
- 缺点：不能像 Apache 那样用 `.htaccess`，配置集中在 `nginx.conf`

**LNMP 典型场景**：
- 高并发 Web（如电商、API 网关）
- 静态文件为主 + 少量动态
- 反向代理 + 负载均衡后端

---

## §3 LAMP vs LNMP：Apache mod_php vs Nginx + php-fpm

| 维度 | LAMP（Apache mod_php） | LNMP（Nginx + php-fpm） |
|------|----------------------|------------------------|
| **PHP 集成方式** | mod_php 嵌入 Apache 进程 | php-fpm 独立进程，FastCGI |
| **进程模型** | prefork/worker/event，每进程一个请求 | Nginx 异步事件，php-fpm 进程池 |
| **内存占用** | 高（每请求一进程，~10-30MB） | 中（Nginx 异步 ~2MB，php-fpm 按需） |
| **并发能力** | 中（~几百并发） | 高（~数千并发） |
| **静态文件性能** | 中 | **强**（Nginx 异步 I/O） |
| **配置灵活度** | **强**（.htaccess 目录级配置） | 弱（必须 reload nginx.conf） |
| **模块生态** | 极丰富（mod_rewrite、mod_ssl、mod_php） | 偏精简（动态模块需编译） |
| **适用规模** | 中小型 / 传统 PHP / CMS | 中大型 / 高并发 / 微服务网关 |
| **学习成本** | 低（资料多） | 中（要懂 FastCGI、upstream） |

**何时选 LAMP**：
- WordPress、Drupal、Joomla 等 CMS（依赖 .htaccess 重写）
- 团队熟悉 Apache
- 中小流量 + 快速上线

**何时选 LNMP**：
- 高并发静态 + 动态混合
- 已有 Nginx 负载均衡经验
- 想精细调优 php-fpm 进程池

**真实生产趋势**：
- 国内互联网公司大多 **LNMP**（Nginx 反代 + php-fpm）
- 国外 WordPress 主机仍有大量 **LAMP**
- 现代方案：**Nginx 反代 + Apache 后端**（折中）

---

## §4 LAMP 环境准备

**节点规划**（参考 LAMP-Wordpress PDF）：

| 节点名称 | 节点 IP | 节点功能 |
|----------|---------|----------|
| server | 10.1.8.10/24 | LAMP：WordPress 博客 |

**前置步骤**：

1. 用 CentOS 7 模板克隆一台 server（VMware / VirtualBox / 云主机）
2. 准备 LAMP 环境
3. 准备数据库
4. 客户端配置 hosts（`10.1.8.10 www.laogao.cloud`）

**关闭防火墙 + SELinux（实验环境，生产按需）**：

```bash
# CentOS 7
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 配置 hosts（客户端 + 服务端）
echo "10.1.8.10 www.laogao.cloud" >> /etc/hosts
```

**配置 epel 源**（PDF 中给的步骤）：

```bash
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
```

**一键安装 LAMP 全套（PDF 原文）**：

```bash
yum install -y mariadb-server mariadb php php-fpm php-mysqlnd \
               php-gd php-mbstring php-xml httpd
```

| 包 | 作用 |
|----|------|
| `mariadb-server` | MariaDB 数据库服务端 |
| `mariadb` | MariaDB 客户端 |
| `php` | PHP 解释器（含 mod_php 供 Apache 用） |
| `php-fpm` | PHP FastCGI 进程管理器（LNMP 用） |
| `php-mysqlnd` | MySQL 原生驱动（推荐，比 php-mysql 快） |
| `php-gd` | 图像处理库（验证码、缩略图） |
| `php-mbstring` | 多字节字符串（中文） |
| `php-xml` | XML 解析 |
| `httpd` | Apache 2.4 |

---

## §5 Apache 部署

LAMP 中 A = Apache（httpd）。

**启动 httpd**（PDF 原文）：

```bash
systemctl enable httpd --now
systemctl status httpd
```

**关键配置文件**：

| 文件 | 作用 |
|------|------|
| `/etc/httpd/conf/httpd.conf` | 主配置 |
| `/etc/httpd/conf.d/*.conf` | 辅助配置（独立文件） |
| `/etc/httpd/conf.modules.d/*.conf` | 模块加载 |
| `/var/www/html/` | 默认站点根目录 |
| `/var/log/httpd/access_log` | 访问日志 |
| `/var/log/httpd/error_log` | 错误日志 |

**httpd.conf 核心参数**：

```apache
# 监听端口
Listen 80

# 服务器名（FQDN，没有 DNS 时填 IP）
ServerName www.laogao.cloud:80

# 管理员邮箱
ServerAdmin root@laogao.cloud

# 站点根目录
DocumentRoot "/var/www/html"

# 默认目录权限
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

# 默认主页
<IfModule dir_module>
    DirectoryIndex index.html index.php
</IfModule>

# 日志格式
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog logs/access_log combined
```

**虚拟主机（按域名）**：

```apache
# /etc/httpd/conf.d/vhost-wordpress.conf
<VirtualHost *:80>
    ServerName www.laogao.cloud
    DocumentRoot "/var/www/html/wordpress"
    ErrorLog "/var/log/httpd/wordpress-error.log"
    CustomLog "/var/log/httpd/wordpress-access.log" combined

    <Directory "/var/www/html/wordpress">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

`AllowOverride All` 允许 WordPress 的 `.htaccess` 生效（固定链接必须）。

**重启 + 测试**：

```bash
systemctl restart httpd
curl -I http://10.1.8.10
```

---

## §6 MySQL/MariaDB 部署

LAMP 中 M = MariaDB（MySQL 兼容开源版）。

**安装与启动**（PDF 原文）：

```bash
yum install -y mariadb-server mariadb
systemctl enable mariadb --now
```

**安全初始化 mysql_secure_installation**（PDF 完整流程）：

```bash
mysql_secure_installation
Enter current password for root (enter for none):   # 【初次】直接回车
Set root password? [Y/n] y                          # y → 设置 root 密码
New password: huawei                                # 输入密码
Re-enter new password: huawei                       # 再输一遍
Remove anonymous users? [Y/n] y                     # 删除匿名用户（安全）
Disallow root login remotely? [Y/n] n               # 允许 root 远程（项目常用 n）
Remove test database and access to it? [Y/n] y      # 删除 test 库
Reload privilege tables now? [Y/n] y                # 刷新权限
```

**关键决策**：
- `Disallow root login remotely?` 项目调试选 n，生产选 y
- 密码策略：默认 medium，root 至少 8 位含数字字母

**WordPress 数据库准备**（PDF 原文）：

```bash
mysql -u root -phuawei
MariaDB [(none)]> CREATE DATABASE wordpress;
MariaDB [(none)]> CREATE USER wordpress@localhost IDENTIFIED BY 'huawei';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON wordpress.* TO wordpress@localhost;
MariaDB [(none)]> FLUSH PRIVILEGES;
MariaDB [(none)]> exit
```

**字符集建议 utf8mb4**（现代 MySQL 默认）：

```bash
# /etc/my.cnf.d/utf8mb4.cnf
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
[client]
default-character-set = utf8mb4
```

重启 `systemctl restart mariadb`，验证：

```sql
SHOW VARIABLES LIKE 'character_set%';
-- 应全是 utf8mb4
```

---

## §7 PHP 部署

LAMP 中 P = PHP（mod_php 嵌入 Apache）。

**安装**（已在 §4 一次性安装）：

```bash
yum install -y php php-fpm php-mysqlnd php-gd php-mbstring php-xml
rpm -qa | grep php
# php-5.4.16-48.el7.x86_64
# php-cli-5.4.16-48.el7.x86_64
# php-common-5.4.16-48.el7.x86_64
# php-fpm-5.4.16-48.el7.x86_64
# php-gd-5.4.16-48.el7.x86_64
# php-mbstring-5.4.16-48.el7.x86_64
# php-mysqlnd-5.4.16-48.el7.x86_64
# php-pdo-5.4.16-48.el7.x86_64
# php-xml-5.4.16-48.el7.x86_64
```

**php.ini 关键配置**：

```ini
; /etc/php.ini

; 时区（中国）
date.timezone = Asia/Shanghai

; 上传文件大小（WordPress 主题/媒体需要）
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300

; 内存限制
memory_limit = 256M

; 隐藏 PHP 版本（安全）
expose_php = Off

; 会话保存路径（权限要给 apache 用户）
session.save_path = "/var/lib/php/session"
```

**修改 session 目录权限**：

```bash
chown -R apache:apache /var/lib/php/session
# 或（LNMP 用 nginx 用户）
chown -R nginx:nginx /var/lib/php/
```

**Apache 加载 PHP 模块**（CentOS 7 默认已经装好）：

```bash
# 检查
httpd -M | grep php
# php5_module (shared)
```

如果没自动加载，手动添加 `/etc/httpd/conf.d/php.conf`：

```apache
<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
```

---

## §8 LAMP 联调：Apache + PHP + MySQL 测试

**三步验证**：

**1. Apache 单独测试**：

```bash
echo "Apache OK" > /var/www/html/test.html
curl http://10.1.8.10/test.html
# Apache OK
```

**2. PHP 测试页**：

```bash
cat > /var/www/html/phpinfo.php <<'EOF'
<?php
phpinfo();
EOF
curl http://10.1.8.10/phpinfo.php
# 应输出 PHP 信息页（HTML）
```

**3. PHP 连 MySQL 测试**：

```bash
cat > /var/www/html/dbtest.php <<'EOF'
<?php
$conn = new mysqli("localhost", "wordpress", "huawei", "wordpress");
if ($conn->connect_error) {
    die("连接失败: " . $conn->connect_error);
}
echo "MySQL 连接成功!<br>";
$result = $conn->query("SELECT VERSION() AS v");
$row = $result->fetch_assoc();
echo "MariaDB 版本: " . $row['v'];
$conn->close();
EOF
curl http://10.1.8.10/dbtest.php
# MySQL 连接成功!
# MariaDB 版本: 5.5.65-MariaDB
```

**验证通过 = LAMP 联调成功**，可以进入 §9 部署 WordPress。

---

## §9 WordPress 部署

**WordPress** = 全球最流行的开源 CMS（Content Management System），PHP + MySQL。

**实验节点**（PDF 原文）：

| 节点名称 | 节点 IP | 节点功能 |
|----------|---------|----------|
| server | 10.1.8.10/24 | LAMP 实战：WordPress |

**下载 WordPress**（PDF 原文）：

```bash
# 上传到 root 用户家目录（PDF 用的是 wordpress-4.8）
unzip wordpress-4.8-zh_CN.zip
cp -aR wordpress /var/www/html/
chmod -R 755 /var/www/html/wordpress
systemctl restart httpd
```

**目录权限**（PDF 原文）：

```bash
# 确保 apache 用户可以创建文件
chmod -R 755 /var/www/html/wordpress/
chown -R apache:apache /var/www/html/wordpress/
```

**WordPress 数据表前缀**（PDF 给出）：

```php
// wp-config.php
$table_prefix = 'wp_';
```

**配置数据库**（PDF 原文，两种方式）：

**方式一：浏览器向导**：

```
客户端登录：http://www.laogao.cloud/wordpress/
按向导输入：数据库名、用户名、密码、主机、表前缀
```

**方式二：手动配置 wp-config.php**（PDF 原文）：

```bash
cd /var/www/html/wordpress/
cp wp-config-sample.php wp-config.php
vim wp-config.php
```

修改四个参数（PDF 原文）：

```php
/** WordPress 数据库的名称 */
define('DB_NAME', 'wordpress');

/** MySQL 数据库用户名 */
define('DB_USER', 'wordpress');

/** MySQL 数据库密码 */
define('DB_PASSWORD', 'huawei');

/** MySQL 主机 */
define('DB_HOST', 'localhost');
```

**完成安装**：

```
访问 http://www.laogao.cloud/wordpress/wp-admin/install.php
填写：站点标题、用户名、密码、邮箱
点击 "安装 WordPress" → 登录后台
```

**常见问题**（PDF 提示）：
- 出现"无法写入 wp-config.php" → 检查目录权限（PDF 解决方案）
- 出现"数据库连接错误" → 检查 wp-config 四个参数

---

## §10 WordPress 配置

**登录后台**：`http://www.laogao.cloud/wordpress/wp-admin/`

**固定链接（Permalinks）**：

```bash
# 必须在 .htaccess 中加入（WordPress 自动生成）
# /var/www/html/wordpress/.htaccess
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /wordpress/
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /wordpress/index.php [L]
</IfModule>
```

后台 → 设置 → 固定链接 → 选择"文章名" → 保存。

**主题（Themes）**：

```bash
# 主题目录
/var/www/html/wordpress/wp-content/themes/

# 推荐中文主题：Sakura、Puock、Argon
# 安装方式：
#   1. 后台 → 外观 → 主题 → 上传 .zip
#   2. 或解压到 themes/ 目录
```

**插件（Plugins）必备**：

| 插件 | 用途 |
|------|------|
| WP Super Cache | 静态化加速 |
| Yoast SEO | SEO 优化 |
| Akismet | 反垃圾评论 |
| Wordfence | 安全防护 |
| UpdraftPlus | 自动备份 |
| WPForms | 表单 |
| WP Statistics | 访问统计 |

**用户角色**：

```
管理员（Administrator）   → 全部权限
编辑（Editor）           → 文章、页面、评论
作者（Author）           → 自己的文章
贡献者（Contributor）    → 草稿
订阅者（Subscriber）     → 仅个人资料
```

**多语言**：
- 插件 WPML / Polylang
- 中小站点用翻译插件 + 多站点（Multisite）

---

## §11 WordPress 性能优化

**1. 启用 OPcache**：

```ini
; /etc/php.d/opcache.ini
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=20000
opcache.revalidate_freq=60
opcache.validate_timestamps=1
```

**2. WP Super Cache**：

```
后台 → 插件 → 安装 WP Super Cache → 启用
设置 → WP Super Cache：
  ├─ 启用缓存（推荐：Mod_Rewrite 模式，最快）
  ├─ 缓存超时：3600 秒
  └─ 预缓存（首次启用时全站爬一遍）
```

**3. 主题精简**：
- 关闭未用 widget
- 禁用不必要的小工具
- 用轻量主题（GeneratePress、Sakura）

**4. 图片优化**：

```bash
# 插件：Smush / ShortPixel（自动压缩）
# 或本地：
yum install -y imagemagick
for f in *.jpg; do convert "$f" -resize 1200x -quality 85 "opt-$f"; done
```

**5. 延迟加载（Lazy Load）**：

```php
// functions.php
add_filter('wp_lazy_loading_enabled', '__return_true');
```

**6. CDN 加速**：

```
CDN 提供商：阿里云CDN、腾讯云CDN、CloudFlare
回源：WordPress 源站
缓存规则：
  ├─ 静态（jpg/css/js）：缓存 30 天
  └─ 动态（php/html）：缓存 0 秒，回源
```

**7. 对象缓存（Redis/Memcached）**：

```bash
yum install -y redis php-pecl-redis
systemctl enable redis --now
```

```php
// wp-config.php
define('WP_CACHE', true);
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
```

---

## §12 WordPress 安全加固

**1. 强密码 + 双因素（2FA）**：

```
密码：12+ 位，大小写 + 数字 + 符号
插件：Two Factor、Google Authenticator
```

**2. 文件权限**：

```bash
# 标准安全权限
chown -R apache:apache /var/www/html/wordpress/
find /var/www/html/wordpress/ -type d -exec chmod 755 {} \;
find /var/www/html/wordpress/ -type f -exec chmod 644 {} \;

# wp-config.php 单独加固
chmod 600 /var/www/html/wordpress/wp-config.php

# 禁止任何用户写入 wp-includes/
chmod -R 555 /var/www/html/wordpress/wp-includes/
```

**3. wp-config.php 安全密钥**：

```bash
# 访问 https://api.wordpress.org/secret-key/1.1/salt/ 获取
# 替换 wp-config.php 中 AUTH_KEY 等 8 个常量
```

**4. 隐藏 wp-includes 和 wp-content/plugins 目录浏览**：

```apache
# .htaccess
Options -Indexes
```

**5. 限制登录尝试**：

```bash
# 插件：Limit Login Attempts Reloaded
# 失败 5 次锁 30 分钟
```

**6. 关闭文件编辑（防后门改主题）**：

```php
// wp-config.php
define('DISALLOW_FILE_EDIT', true);
```

**7. 禁用 xmlrpc.php**（暴力破解入口）：

```apache
# .htaccess
<Files xmlrpc.php>
    Require all denied
</Files>
```

**8. 主题/插件源码扫描**：

```bash
# 插件：Wordfence / Sucuri
# 命令行：grep -r "eval(" wp-content/themes/
# 可疑函数：eval, base64_decode, gzinflate, system, exec
```

**9. 数据库表前缀**：

```php
// wp-config.php（PDF 默认）
$table_prefix = 'wp_';   // 生产建议改成不易猜的，如 'kx9_'
```

**10. 定期更新**：

```bash
# WordPress 核心 + 主题 + 插件
# 后台 → 仪表盘 → 更新
# 自动化：wp-cli + cron
```

---

## §13 WordPress 备份与迁移

**1. 数据库备份**（mysqldump）：

```bash
mysqldump -u root -phuawei wordpress > wordpress-db-$(date +%F).sql

# 压缩
mysqldump -u root -phuawei wordpress | gzip > wordpress-db-$(date +%F).sql.gz

# 还原
gunzip < wordpress-db-2026-07-16.sql.gz | mysql -u root -phuawei wordpress
```

**2. 文件整站备份**（tar）：

```bash
tar czf wordpress-files-$(date +%F).tar.gz \
    /var/www/html/wordpress/

# 排除大文件
tar czf wordpress-files-$(date +%F).tar.gz \
    --exclude='wp-content/cache' \
    --exclude='wp-content/uploads/backup*' \
    /var/www/html/wordpress/
```

**3. 自动化备份脚本**：

```bash
#!/bin/bash
# /root/backup-wordpress.sh
BACKUP_DIR=/backup/wordpress
DATE=$(date +%F)

mkdir -p $BACKUP_DIR
mysqldump -u root -phuawei wordpress | gzip > $BACKUP_DIR/db-$DATE.sql.gz
tar czf $BACKUP_DIR/files-$DATE.tar.gz /var/www/html/wordpress/

# 删除 30 天前
find $BACKUP_DIR -mtime +30 -delete
```

```bash
chmod +x /root/backup-wordpress.sh
# crontab -e
0 3 * * * /root/backup-wordpress.sh
```

**4. 插件自动备份**：

```
UpdraftPlus：
  - 后台 → UpdraftPlus → 设置
  - 备份计划：每天数据库，每周文件
  - 远程存储：阿里云OSS / 腾讯云COS / SFTP
  - 保留：5 份
```

**5. 跨服务器迁移**：

```bash
# 旧服务器：打包
mysqldump -u root -phuawei wordpress > wp.sql
tar czf wp-files.tar.gz /var/www/html/wordpress/

# scp 到新服务器
scp wp.sql wp-files.tar.gz root@new-server:/tmp/

# 新服务器：还原
mysql -u root -phuawei wordpress < /tmp/wp.sql
tar xzf /tmp/wp-files.tar.gz -C /

# 修改 wp-config.php 中的 DB_HOST / 域名
# 替换 wp_options 表中的 siteurl / home
mysql -u root -phuawei wordpress -e \
  "UPDATE wp_options SET option_value='http://newdomain.com' WHERE option_name IN ('siteurl','home');"
```

**6. Docker 化迁移**（现代方案）：

```dockerfile
# Dockerfile
FROM wordpress:6-php7.4-apache
COPY wp-content /var/www/html/wp-content
COPY wp-config.php /var/www/html/
```

```bash
docker run -d --name wp \
    -e WORDPRESS_DB_HOST=db \
    -e WORDPRESS_DB_USER=wordpress \
    -e WORDPRESS_DB_PASSWORD=huawei \
    -e WORDPRESS_DB_NAME=wordpress \
    -p 8080:80 wordpress:latest
```

---

## §14 LNMP 环境准备

**节点规划**（参考 LNMP-ECshop PDF）：

| 节点名称 | 节点 IP | 节点功能 |
|----------|---------|----------|
| ecshop | 10.1.8.10/24 | LNMP 实战：ECshop 电商 |

**前置步骤**：
1. 用 CentOS 7 模板克隆一台 server（与 LAMP 相同 IP 段，可共用基础镜像）
2. 准备 LNMP 环境
3. 准备 Nginx
4. 准备 MariaDB
5. 准备 PHP
6. 客户端配置 hosts（`10.1.8.10 shop.laogao.cloud`）

**关闭防火墙 + SELinux**（同 §4）：

```bash
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# hosts（客户端 + 服务端）
echo "10.1.8.10 shop.laogao.cloud" >> /etc/hosts
```

**epel 源**（PDF 原文）：

```bash
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
```

**LNMP 安装流程**（按 PDF 顺序）：
1. 安装 nginx（§15 详细）
2. 安装 mariadb（§16 详细）
3. 安装 php-fpm（§16 详细）
4. 部署 ECshop（§19 详细）

---

## §15 Nginx + PHP-FPM

**安装**（PDF 原文）：

```bash
yum install -y nginx
systemctl enable nginx.service --now
echo "Nginx Test Page" > /usr/share/nginx/html/index.html
```

**测试**（PDF 原文）：

```bash
# 服务端 vim /etc/hosts 加：10.1.8.10 shop.laogao.cloud
curl http://shop.laogao.cloud/
# Nginx Test Page
```

**安装 MariaDB**（PDF 原文）：

```bash
yum install -y mariadb-server
systemctl enable mariadb --now
mysql_secure_installation
# 完整流程同 §6：root 密码 huawei + 删除匿名 + 删除 test
```

**安装 PHP-FPM**（PDF 原文）：

```bash
yum install -y php php-fpm
```

**修改 php-fpm 运行用户**（PDF 原文，**关键步骤**）：

```bash
vim /etc/php-fpm.d/www.conf
```

```ini
; /etc/php-fpm.d/www.conf
; 原本是 apache，要改成 nginx，否则 PHP-FPM 写文件会失败
user = nginx
group = nginx

; 监听方式（二选一）
; listen = 127.0.0.1:9000          ; TCP 端口（适合跨主机）
listen = /run/php-fpm/www.sock     ; Unix 套接字（更快，本机推荐）

; 进程池（按服务器内存调整）
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

; 慢日志
slowlog = /var/log/php-fpm/www-slow.log
request_slowlog_timeout = 5s
```

**启动 php-fpm**（PDF 原文）：

```bash
systemctl enable php-fpm.service --now
systemctl status php-fpm
```

**验证 php-fpm 监听**：

```bash
ss -tlnp | grep -E '9000|www.sock'
# TCP:  LISTEN 0  511  127.0.0.1:9000  *  users:(("php-fpm",pid=1234,fd=8))
# Unix:  LISTEN 0  511  /run/php-fpm/www.sock  users:(("php-fpm",pid=1234,fd=7))
```

---

## §16 Nginx 配置 PHP：fastcgi_pass 详解

**配置虚拟主机**（PDF 原文）：

```bash
vim /etc/nginx/conf.d/vhost-shop.laogao.cloud.conf
```

```nginx
server {
    listen       80;
    listen       [::]:80;
    server_name  shop.laogao.cloud;
    root         /usr/share/nginx/html;

    # 设置默认主页
    index index.php;

    # 设置 php 页面处理方式
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass 127.0.0.1:9000;          # 或 unix:/run/php-fpm/www.sock
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**重启 + 测试**（PDF 原文）：

```bash
systemctl restart nginx
echo "<?php echo 'PHP Test Page'.\"\n\"; ?>" > /usr/share/nginx/html/test.php
curl http://shop.laogao.cloud/test.php
# PHP Test Page
```

**关键参数详解**：

| 参数 | 作用 | 错误后果 |
|------|------|----------|
| `fastcgi_pass` | 转发地址（TCP / Unix sock） | 502 Bad Gateway |
| `fastcgi_param SCRIPT_FILENAME` | PHP 脚本绝对路径 | File not found |
| `fastcgi_index` | 默认脚本名 | 找不到 index.php |
| `include fastcgi_params` | 引入 FastCGI 通用参数 | 环境变量丢失 |
| `try_files $uri =404` | 防止 0day 漏洞 | 任意文件执行 |

**`fastcgi_param SCRIPT_FILENAME`** 是**最常见的坑**：

```nginx
# 正确：$document_root$fastcgi_script_name
# = /usr/share/nginx/html/test.php
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

# 错误1：直接用 $fastcgi_script_name（变成相对路径）
# 错误2：写死路径（换 root 目录后失效）
```

**TCP vs Unix Socket 选择**：

| 维度 | TCP (`127.0.0.1:9000`) | Unix sock (`/run/php-fpm/www.sock`) |
|------|------------------------|--------------------------------------|
| 速度 | 略慢（网络栈开销） | **快 5-10%**（无 TCP 握手） |
| 跨主机 | **支持**（php-fpm 跑在别的机器） | 不支持（仅本机） |
| 防火墙 | 受 selinux / iptables 影响 | 不受影响 |
| 推荐场景 | 分布式 PHP-FPM 集群 | 单机本地 LNMP |

**sock 模式配套配置**：

```nginx
# nginx.conf
location ~ \.php$ {
    fastcgi_pass unix:/run/php-fpm/www.sock;
    # ...
}
```

```ini
; /etc/php-fpm.d/www.conf
listen = /run/php-fpm/www.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
```

**完整 fastcgi_params 内容**（默认 `/etc/nginx/fastcgi_params`）：

```nginx
fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;
fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  REQUEST_SCHEME     $scheme;
fastcgi_param  HTTPS              $https if_not_empty;
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;
fastcgi_param  REDIRECT_STATUS    200;
```

---

## §17 MariaDB 主主复制

**场景**：LNMP 高可用方案之一——两台 MariaDB 互相同步，任意一台挂掉业务不中断。

**架构**：

```
            ┌──────────┐
            │  Master1 │ 10.1.8.11
            │  server-id=1
            └─────┬────┘
                  │ binlog → relay log
                  ↓
            ┌──────────┐
            │  Master2 │ 10.1.8.12
            │  server-id=2
            └─────┬────┘
                  │ binlog → relay log
                  ↑
            回到 Master1（互为主从）
```

**关键配置**：

**Master1（10.1.8.11）/etc/my.cnf**：

```ini
[mysqld]
server-id = 1
log-bin = /var/log/mariadb/mariadb-bin.log
log-slave-updates = 1           # 从主变成主的关键：级联复制
auto_increment_offset = 1       # 起始值（避免双主 ID 冲突）
auto_increment_increment = 2    # 步长 2

binlog-format = mixed
expire_logs_days = 7
```

**Master2（10.1.8.12）/etc/my.cnf**：

```ini
[mysqld]
server-id = 2
log-bin = /var/log/mariadb/mariadb-bin.log
log-slave-updates = 1
auto_increment_offset = 2       # 起始 2
auto_increment_increment = 2    # 步长 2（永远 1,3,5... 和 2,4,6... 错开）
```

**建立主主关系**：

```bash
# 在 Master1 上
mysql -uroot -p
> SHOW MASTER STATUS;
+--------------------+----------+
| File               | Position |
+--------------------+----------+
| mariadb-bin.000003 |      245 |
+--------------------+----------+
```

```bash
# 在 Master2 上配置指向 Master1
> CHANGE MASTER TO
    MASTER_HOST='10.1.8.11',
    MASTER_USER='repl_user',
    MASTER_PASSWORD='huawei',
    MASTER_LOG_FILE='mariadb-bin.000003',
    MASTER_LOG_POS=245;
> START SLAVE;
> SHOW SLAVE STATUS\G
   Slave_IO_Running: Yes
   Slave_SQL_Running: Yes
```

再反向操作（Master2 → Master1）。

**测试**：

```sql
-- 在 Master1 插入数据
INSERT INTO test.t1 VALUES (1, 'from master1');

-- 在 Master2 验证
SELECT * FROM test.t1;
-- 应能看到 (1, 'from master1')
```

**常见坑**：
- `log-slave-updates = 1` 忘了开 → 单向同步，断开一环就崩
- `auto_increment_offset/increment` 两台相同 → **双写 ID 冲突**
- 自增 ID 必须错开（1,3,5 和 2,4,6）

---

## §18 Keepalived + 双机热备

**场景**：两台 LNMP 服务器，一台 Master，一台 Backup；Master 挂掉，Backup 自动接管虚 IP。

**架构**：

```
              虚 IP：10.1.8.10/24（用户访问）
                  │
        ┌─────────┴─────────┐
        ↓                   ↓
   Master Web         Backup Web
   10.1.8.11          10.1.8.12
   Keepalived         Keepalived
   priority=100       priority=90
   ↑                   ↑
   └─────── VRRP 通告 ──┘
   （每秒一次心跳）
```

**安装**：

```bash
yum install -y keepalived
```

**Master 配置** `/etc/keepalived/keepalived.conf`：

```nginx
global_defs {
    router_id LVS_DEVEL
}

vrrp_script check_nginx {
    script "/usr/local/bin/check_nginx.sh"
    interval 2           # 每 2 秒检查一次
    weight -20           # 失败减 20 优先级
    fall 3               # 连续 3 次失败才认作挂掉
    rise 2               # 连续 2 次成功恢复
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51         # 主备必须相同
    priority 100                 # Master 高
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.1.8.10/24 dev eth0 label eth0:1
    }
    track_script {
        check_nginx
    }
    notify_master "/usr/local/bin/notify.sh master"
    notify_backup "/usr/local/bin/notify.sh backup"
    notify_fault "/usr/local/bin/notify.sh fault"
}
```

**Backup 配置**：

```nginx
vrrp_instance VI_1 {
    state BACKUP
    priority 90           # Backup 低
    # 其余同 Master
}
```

**健康检查脚本** `/usr/local/bin/check_nginx.sh`：

```bash
#!/bin/bash
nginx_count=$(ps -C nginx --no-heading | wc -l)
if [ "$nginx_count" -eq 0 ]; then
    systemctl start nginx
    sleep 2
    nginx_count=$(ps -C nginx --no-heading | wc -l)
    if [ "$nginx_count" -eq 0 ]; then
        exit 1
    fi
fi
exit 0
```

```bash
chmod +x /usr/local/bin/check_nginx.sh
systemctl enable keepalived --now
```

**测试**：

```bash
# 在 Master 上
ip addr show eth0
# 应有 inet 10.1.8.10/24 scope global secondary eth0:1

# 停掉 Master 的 nginx
systemctl stop nginx
sleep 5

# Backup 应接管虚 IP
# 在 Backup 上
ip addr show eth0
# inet 10.1.8.10/24 scope global secondary eth0:1
```

---

## §19 ECshop 部署

**ECshop** = 国内流行的开源电商系统（B2C 商城），PHP + MySQL。

**实验节点**（PDF 原文）：

| 节点名称 | 节点 IP | 节点功能 |
|----------|---------|----------|
| ecshop | 10.1.8.10/24 | LNMP 实战：ECshop |

**下载 ECshop**（PDF 原文，用 ECShop_V4.1.20）：

```bash
unzip ECShop_V4.1.20_UTF8.zip
```

**目录准备**（PDF 原文）：

```bash
# 备份默认 html 目录
mv /usr/share/nginx/html/ /usr/share/nginx/html.ori

# 复制 ECshop 站点到 web 根目录
cp -a ECShop_V4.1.20_UTF8_release20250416/source/ecshop /usr/share/nginx/html

# 修改所有者
chown -R nginx:nginx /usr/share/nginx/html
```

**安装 PHP 扩展**（PDF 原文）：

```bash
yum install -y php-gd php-common php-pear php-mbstring php-mcrypt php-mysqlnd

# 修改 session 目录所有者
chown -R nginx:nginx /var/lib/php/

# 重启
systemctl restart nginx php-fpm
```

**创建数据库**（PDF 原文）：

```bash
mysql -u root -phuawei
MariaDB [(none)]> CREATE DATABASE ecshop;
MariaDB [(none)]> CREATE USER ecshop@localhost IDENTIFIED BY 'huawei';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON ecshop.* TO ecshop@localhost;
MariaDB [(none)]> FLUSH PRIVILEGES;
MariaDB [(none)]> exit
```

**浏览器安装**（PDF 原文）：

```
客户端登录：http://shop.laogao.cloud
点击下一步：配置系统
```

**注意事项**（PDF 提示）：
- 页面上方出现的 Warning，提示使用系统时区不安全，**暂时忽略**
- 输入数据库账户信息后，点击"搜"，选中搜索到的数据库
- 时区选择**亚洲，中国，上海**
- 点击"立即安装"
- 激活系统（可关闭，不影响使用）

**访问地址**（PDF 原文）：
```
商城首页：http://shop.laogao.cloud
商城管理后台：http://shop.laogao.cloud/admin
```

**后台登录**（PDF 原文）：
```
使用 ecshop 账户登录
开店向导：
  ├─ 完善店铺信息
  ├─ 设置商品分类
  ├─ 设置支付方式
  └─ 设置物流配送
```

---

## §20 ECshop 配置

**商品分类**：

```
后台 → 商品管理 → 商品分类
  ├─ 添加顶级分类（如：服装）
  ├─ 添加二级分类（如：男装 → 衬衫）
  └─ 添加商品并归类
```

**支付方式**（PDF 隐含步骤）：

```
后台 → 系统设置 → 支付方式：
  ├─ 货到付款（默认启用）
  ├─ 银行转账/汇款
  ├─ 余额支付（需先开启会员余额）
  ├─ 微信支付（需配置商户号）
  ├─ 支付宝（需配置 PID + KEY）
  └─ PayPal（外贸站点）
```

**邮件配置**：

```
后台 → 系统设置 → 邮件服务器设置：
  SMTP 服务器：smtp.qq.com
  SMTP 端口：465（SSL）或 25（明文）
  发件人邮箱：xxx@qq.com
  SMTP 用户名：xxx
  SMTP 密码：授权码（非 QQ 密码）
```

**模板切换**：

```
后台 → 模板管理 → 模板选择
  ├─ 默认模板
  ├─ 移动端模板（mobile）
  └─ 自定义模板（需上传到 /themes/）
```

**关键文件位置**：

```
/usr/share/nginx/html/
├── admin/                  # 后台
├── includes/               # 库文件
├── languages/              # 语言包
├── mobile/                 # 移动端
├── themes/                 # 模板
│   └── default/
├── data/                   # 数据库备份目录（**需可写**）
│   ├── sqldata/
│   └── cache/
└── upload/                 # 用户上传
```

---

## §21 ECshop 性能优化

**1. OPcache**：

```ini
; /etc/php.d/opcache.ini
[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=40000
opcache.revalidate_freq=60
```

**2. Memcached / Redis 对象缓存**：

```bash
yum install -y memcached php-pecl-memcached
systemctl enable memcached --now
```

```php
// /usr/share/nginx/html/includes/cls_cache.php
// 修改为 Memcached 驱动
$cache_driver = 'memcached';
```

**3. 静态化（URL 重写）**：

```nginx
# /etc/nginx/conf.d/vhost-shop.laogao.cloud.conf
location / {
    # 伪静态：ECshop 后台可开启
    if (!-e $request_filename){
        rewrite ^/index\.html$ /index.php last;
        rewrite ^/category$ /category.php last;
        rewrite ^/goods/([0-9]+)$ /goods.php?id=$1 last;
    }
}
```

**4. 数据库索引**：

```sql
-- 商品表
ALTER TABLE ecs_goods ADD INDEX idx_cat_id (cat_id);
ALTER TABLE ecs_goods ADD INDEX idx_brand_id (brand_id);
ALTER TABLE ecs_goods ADD INDEX idx_is_on_sale (is_on_sale, is_delete);

-- 订单表
ALTER TABLE ecs_order_info ADD INDEX idx_user_id (user_id);
ALTER TABLE ecs_order_info ADD INDEX idx_add_time (add_time);
```

**5. CDN 加速**：

```
商品图 / CSS / JS / 字体 → CDN
HTML / PHP 动态 → 回源
推荐：阿里云 CDN + 对象存储 OSS
```

**6. 图片压缩**：

```bash
yum install -y jpegoptim optipng
find /usr/share/nginx/html/upload -name "*.jpg" -exec jpegoptim --max=85 {} \;
find /usr/share/nginx/html/upload -name "*.png" -exec optipng -o5 {} \;
```

**7. 减少插件 / 模板**：

```
- 关闭未用支付方式
- 关闭未用配送方式
- 关闭后台多余模块
```

---

## §22 ECshop 故障排查

**1. 数据库连接失败**：

```bash
# 错误：ECshop 安装时 "无法连接到数据库服务器"
# 检查：
mysql -uecshop -phuawei ecshop
# 如果能连 → wp-config / ECshop 配置数据库账户密码错
# 如果连不上 → 用户未授权或不存在

# 修复：
mysql -uroot -phuawei
> GRANT ALL PRIVILEGES ON ecshop.* TO ecshop@localhost IDENTIFIED BY 'huawei';
> FLUSH PRIVILEGES;
```

**2. 文件权限错误**：

```bash
# 错误：上传图片失败 / 模板编译失败 / 缓存写入失败
# 原因：nginx 用户对某些目录无写权限
# 修复：
chown -R nginx:nginx /usr/share/nginx/html/data/
chown -R nginx:nginx /usr/share/nginx/html/upload/
chown -R nginx:nginx /var/lib/php/session/
chmod -R 755 /usr/share/nginx/html/data/
```

**3. 模板编译失败**：

```bash
# 错误：前台页面空白 / 报错 "Template not found"
# 检查模板目录：
ls /usr/share/nginx/html/themes/default/
# 修复：
chown -R nginx:nginx /usr/share/nginx/html/temp/
find /usr/share/nginx/html/temp -type d -exec chmod 777 {} \;
```

**4. 中文乱码**：

```bash
# 错误：后台中文乱码 / 商品详情乱码
# 原因：数据库字符集不匹配
# 修复：
mysql -uroot -phuawei
> ALTER DATABASE ecshop DEFAULT CHARACTER SET utf8mb4;
> ALTER TABLE ecs_goods CONVERT TO CHARACTER SET utf8mb4;

# /etc/my.cnf.d/utf8mb4.cnf（同 §6）
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

systemctl restart mariadb
```

**5. 502 Bad Gateway（Nginx → php-fpm 通信失败）**：

```bash
# 错误：访问 .php 文件返回 502
# 检查 1：php-fpm 是否运行
systemctl status php-fpm
# 检查 2：fastcgi_pass 配置与 php-fpm 监听方式一致
grep -E '^listen' /etc/php-fpm.d/www.conf
grep fastcgi_pass /etc/nginx/conf.d/*.conf

# 修复：sock 路径要一致，或 TCP 端口要对应
```

**6. 404 / 重定向循环**：

```bash
# 错误：访问 wp-admin 或 /admin 跳转死循环
# 原因：session 目录权限 / 数据库 session 表
chown -R nginx:nginx /var/lib/php/session/
```

**7. Warning: Use of undefined constant**：

```bash
# PHP 7.4+ 不支持未加引号的常量
# ECshop 4.x 兼容 PHP 7.4，需打补丁或降级到 PHP 7.2
yum remove -y php php-fpm
yum install -y php72w php72w-fpm ...
```

---

## §23 LAMP vs LNMP 实测对比

**测试工具**：

| 工具 | 用途 |
|------|------|
| `ab` (Apache Bench) | 简单压测，HTTP 请求吞吐 |
| `wrk` | 高并发压测 |
| `siege` | 多 URL 压测 |
| `sysbench` | CPU/内存/磁盘/数据库 |

**1. 静态文件性能对比**：

```bash
# LAMP（Apache）
ab -n 10000 -c 100 http://10.1.8.10/test.html
# Requests per second: 3500 [#/sec]
# Time per request: 28.5 [ms]
# Transfer rate: 12000 [Kbytes/sec]

# LNMP（Nginx）
ab -n 10000 -c 100 http://10.1.8.10/test.html
# Requests per second: 8500 [#/sec]   ← Nginx 异步 I/O 优势
# Time per request: 11.7 [ms]
# Transfer rate: 30000 [Kbytes/sec]
```

**2. 动态 PHP 页面对比**：

```bash
# LAMP（Apache + mod_php）
ab -n 5000 -c 50 http://10.1.8.10/test.php
# RPS: 1800, 平均 27ms

# LNMP（Nginx + php-fpm TCP）
ab -n 5000 -c 50 http://10.1.8.10/test.php
# RPS: 2200, 平均 22ms

# LNMP（Nginx + php-fpm Unix sock）
ab -n 5000 -c 50 http://10.1.8.10/test.php
# RPS: 2500, 平均 20ms
```

**3. 高并发（1000 并发）**：

```bash
wrk -t 4 -c 1000 -d 30s http://10.1.8.10/test.html
# LAMP：Requests/sec:  4200,  Latency 240ms
# LNMP：Requests/sec: 12000,  Latency  85ms
```

**4. 数据库连接测试**：

```bash
sysbench --test=oltp --oltp-table-size=1000000 \
         --mysql-db=test --mysql-user=root --mysql-password=huawei \
         prepare
sysbench --test=oltp --oltp-table-size=1000000 \
         --mysql-db=test --mysql-user=root --mysql-password=huawei \
         --max-time=60 --num-threads=16 run
# transactions: 8500 (141.6 per sec.)
```

**结论**：

| 场景 | 推荐 | 原因 |
|------|------|------|
| 静态文件 | **LNMP** | Nginx 异步事件，吞吐 2-3 倍 |
| 动态 PHP | LNMP（sock） | PHP-FPM 独立调优 |
| 高并发（>1000） | **LNMP** | Nginx 异步，Apache prefork 撑不住 |
| CMS / .htaccess | LAMP | Apache mod_rewrite 更灵活 |
| 老项目兼容 | LAMP | Apache + mod_php 兼容性最佳 |

---

## §24 Web 项目通用安全

**1. SQL 注入**：

```
原理：拼接 SQL 时直接拼用户输入
例：' OR '1'='1

防御：
  - 预编译语句（PDO / MySQLi）
  - 输入过滤（白名单）
  - ORM（自动转义）
```

```php
// 错误：拼接
$sql = "SELECT * FROM users WHERE name='$name'";

// 正确：PDO 预编译
$stmt = $pdo->prepare("SELECT * FROM users WHERE name=?");
$stmt->execute([$name]);
```

**2. XSS（跨站脚本）**：

```
原理：在用户输入中注入 <script>
例：评论框输入 <script>alert(1)</script>

防御：
  - 输出时 HTML 转义（htmlspecialchars）
  - CSP 头（Content-Security-Policy）
  - HttpOnly cookie
```

```php
echo htmlspecialchars($user_input, ENT_QUOTES, 'UTF-8');
```

**3. CSRF（跨站请求伪造）**：

```
原理：诱导已登录用户访问恶意站点，触发转账等操作

防御：
  - CSRF token（每个表单带随机 token）
  - Referer 校验
  - SameSite cookie
```

```php
// 生成 token
$_SESSION['csrf_token'] = bin2hex(random_bytes(32));

// 校验
if ($_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    die('CSRF 验证失败');
}
```

**4. 文件上传漏洞**：

```
防御：
  - 白名单后缀（只允许 .jpg, .png）
  - MIME 类型检测（finfo_file）
  - 限制文件大小（upload_max_filesize）
  - 上传目录禁用 PHP 执行
```

```nginx
# /etc/nginx/conf.d/upload.conf
location /upload/ {
    location ~ \.php$ { deny all; }
}
```

**5. WAF（Web Application Firewall）**：

```
方案：
  - 硬件：F5、Imperva
  - 软件：ModSecurity（Apache/Nginx）、OpenResty + Lua
  - 云：阿里云 WAF、腾讯云 WAF、CloudFlare
```

**6. HTTPS / TLS**：

```bash
yum install -y mod_ssl   # Apache
# /etc/nginx/conf.d/ssl.conf  # Nginx
```

```nginx
server {
    listen 443 ssl http2;
    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    add_header Strict-Transport-Security "max-age=31536000" always;
}
```

**7. 暴力破解**：

```bash
# fail2ban
yum install -y fail2ban
systemctl enable fail2ban --now
```

```
/etc/fail2ban/jail.local:
[sshd]
enabled = true
maxretry = 5
bantime  = 3600

[nginx-http-auth]
enabled = true
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 3600
```

---

## §25 Web 项目通用监控

**1. 访问日志分析**：

```bash
# 实时查看
tail -f /var/log/nginx/access.log

# 状态码统计
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
#   8234 200
#    432 404
#     87 500
#     12 502

# IP Top 10
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# URL Top 10
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# GoAccess（可视化）
yum install -y goaccess
goaccess /var/log/nginx/access.log -o /var/www/html/report.html --log-format=COMBINED
```

**2. Nginx stub_status**：

```nginx
# /etc/nginx/conf.d/status.conf
server {
    listen 127.0.0.1:80;
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

```bash
curl http://127.0.0.1/nginx_status
# Active connections: 12
# server accepts handled requests
#  12345 12345 67890
# Reading: 0 Writing: 1 Waiting: 11
```

**3. Apache mod_status**：

```apache
# /etc/httpd/conf.d/status.conf
<Location /server-status>
    SetHandler server-status
    Require local
</Location>
```

```bash
curl http://127.0.0.1/server-status?auto
# Server Version: Apache/2.4.6 (CentOS)
# Current Time: Thursday, 16-Jul-2026 ...
# Total Accesses: 12345
# CPU Usage: u0 .05 s0 .02 cu0 cs0 - .012% CPU load
```

**4. PHP-FPM 状态**：

```ini
; /etc/php-fpm.d/www.conf
pm.status_path = /php-fpm-status
```

```nginx
# nginx
location /php-fpm-status {
    fastcgi_pass unix:/run/php-fpm/www.sock;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    allow 127.0.0.1;
    deny all;
}
```

```bash
curl http://127.0.0.1/php-fpm-status
# pool:                 www
# process manager:      dynamic
# start time:           16/Jul/2026:...
# accepted conn:        12345
# listen queue:         0
# active processes:     5
# idle processes:       10
# total processes:      15
```

**5. APM（应用性能监控）**：

```
方案：
  - 商业：New Relic、Datadog、阿里云 ARMS
  - 开源：Prometheus + Grafana + node_exporter + php-fpm_exporter
  - 云原生：Jaeger / Zipkin（分布式追踪）
```

**6. Zabbix 集成**：

```bash
yum install -y zabbix-agent
vim /etc/zabbix/zabbix_agentd.conf
# Server=10.1.8.100
# Hostname=lnmp-server

systemctl enable zabbix-agent --now
```

**7. 数据库监控**：

```sql
-- 当前连接数
SHOW STATUS LIKE 'Threads_connected';
-- 最大连接数
SHOW VARIABLES LIKE 'max_connections';
-- 慢查询
SHOW STATUS LIKE 'Slow_queries';
-- 慢查询日志位置
SHOW VARIABLES LIKE 'slow_query_log_file';
```

---

## §26 易错点 ×12

| # | 易错点 | 后果 | 正确做法 |
|---|--------|------|----------|
| 1 | Apache `DirectoryIndex` 不包含 `index.php` | 访问 `/` 返回 403 | 加 `DirectoryIndex index.html index.php` |
| 2 | PHP-FPM user 还是 `apache`（应改成 `nginx`） | 文件写入失败 | `/etc/php-fpm.d/www.conf` 改成 `user = nginx` |
| 3 | `fastcgi_pass` 路径与 php-fpm 监听不一致 | 502 Bad Gateway | 同步 sock 路径或 TCP 端口 |
| 4 | `fastcgi_param SCRIPT_FILENAME` 写死 | 换 root 目录后 404 | 用 `$document_root$fastcgi_script_name` |
| 5 | WordPress 文件权限 777 | 任何用户可写，被入侵风险高 | 目录 755，文件 644，wp-config 600 |
| 6 | 数据库字符集 utf8（实际 utf8mb3） | emoji 4 字节字符丢失 | 改 utf8mb4（`ALTER DATABASE` + `my.cnf`） |
| 7 | MariaDB 主主复制 `auto_increment_offset` 两台相同 | ID 冲突，插入失败 | 一台 1 一台 2，步长 2 |
| 8 | `log-slave-updates = 1` 忘开 | 单向同步，切换后断环 | 双主必须开 |
| 9 | WordPress `.htaccess` AllowOverride None | 固定链接 404 | 改成 `AllowOverride All` |
| 10 | Nginx 缺 `try_files $uri =404` | 0day 漏洞被利用 | 必须保留 |
| 11 | MariaDB 端口 3306 公网开放 | 暴力破解 | bind 127.0.0.1 或防火墙限制 |
| 12 | ECshop `data/` 目录没写权限 | 安装失败 / 缓存失败 | `chown -R nginx:nginx data/` |

---

## §27 速查表

**架构对比速查**：

| 维度 | LAMP | LNMP |
|------|------|------|
| Web | Apache httpd 2.4 | Nginx 1.x |
| PHP 处理 | mod_php | php-fpm |
| 静态性能 | 中 | 高 |
| 动态性能 | 中 | 中高 |
| 配置 | .htaccess 灵活 | 中心化 nginx.conf |
| 反代能力 | 弱 | 强 |
| 学习曲线 | 低 | 中 |

**关键命令速查**：

```bash
# Apache
apachectl configtest         # 检查配置
apachectl graceful           # 优雅重载
systemctl restart httpd

# Nginx
nginx -t                     # 检查配置
nginx -s reload              # 重载
systemctl restart nginx

# PHP-FPM
php-fpm -t                   # 检查配置
systemctl restart php-fpm

# MariaDB
mysql_secure_installation    # 安全初始化
mysqldump -uroot -p db > backup.sql   # 备份
mysql -uroot -p db < backup.sql       # 还原

# WordPress
wp core install --url=... --title=... --admin_user=... --admin_password=... --admin_email=... --path=/var/www/html/wordpress
wp plugin install wp-super-cache --activate
```

**关键路径速查**：

```
/etc/httpd/conf/httpd.conf                 # Apache 主配置
/var/www/html/                              # Apache 默认根
/var/log/httpd/{access,error}_log          # Apache 日志

/etc/nginx/nginx.conf                       # Nginx 主配置
/etc/nginx/conf.d/*.conf                    # Nginx 虚拟主机
/usr/share/nginx/html/                      # Nginx 默认根
/var/log/nginx/{access,error}.log           # Nginx 日志

/etc/php.ini                                # PHP 主配置
/etc/php-fpm.d/www.conf                     # PHP-FPM 池
/var/log/php-fpm/                           # PHP-FPM 日志

/etc/my.cnf                                 # MariaDB 主配置
/var/lib/mysql/                             # MariaDB 数据目录
/var/log/mariadb/                           # MariaDB 日志

/var/www/html/wordpress/                    # WordPress 安装目录
/usr/share/nginx/html/                      # ECshop 安装目录
```

**关键参数速查**：

```apache
# Apache
Listen 80
DocumentRoot "/var/www/html"
AllowOverride All
DirectoryIndex index.html index.php
```

```nginx
# Nginx
server {
    listen 80;
    server_name shop.laogao.cloud;
    root /usr/share/nginx/html;
    index index.php index.html;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

```ini
# PHP-FPM
user = nginx
group = nginx
listen = /run/php-fpm/www.sock
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
```

```ini
# MariaDB 主主
server-id = 1 / 2
log-bin = mariadb-bin.log
log-slave-updates = 1
auto_increment_offset = 1 / 2
auto_increment_increment = 2
```

---

## §28 面试 6 大追问

**1. LAMP 和 LNMP 的区别？生产怎么选？**

> Apache mod_php 嵌入 Apache 进程，配置简单（.htaccess）但内存高；Nginx + php-fpm 分离，异步事件驱动，高并发优。中小流量 + CMS 选 LAMP（兼容 .htaccess），高并发静态 + 微服务选 LNMP。

**2. Apache prefork / worker / event 三种 MPM 区别？**

> - **prefork**：每请求一进程，稳定但内存大（默认）
> - **worker**：多线程 + 多进程，混合
> - **event**：异步事件驱动，keep-alive 性能最佳
>
> 选型：高并发选 event，老 PHP 兼容选 prefork。

**3. PHP-FPM 进程池怎么调？**

> 看内存：`max_children = (可用内存 - 系统开销) / 单进程内存`（PHP 进程 ~30MB）。
> - `pm = dynamic` 动态扩缩
> - `pm.max_requests = 500` 防内存泄漏
> - 慢日志 `request_slowlog_timeout = 5s` 排查慢 PHP
> - `pm.status_path` 接 Zabbix

**4. WordPress 慢，怎么排查？**

> 1. `curl -w` 看 TTFB
> 2. 启用 `WP_DEBUG` 看慢 SQL
> 3. `Query Monitor` 插件看慢查询
> 4. `EXPLAIN` 分析 SQL
> 5. OPcache / Redis 对象缓存 / WP Super Cache
> 6. CDN 静态资源
> 7. 图片懒加载 + 压缩

**5. MariaDB 主主复制为什么必须 `log-slave-updates`？**

> 双主架构中，Master1 写入 → binlog → Master2 接收（写到 relay log）→ **必须重写到自己的 binlog** → 否则 Master2 的 binlog 缺这段，Master1 反向同步时丢失数据。
> 该参数开启后，从库会把自己执行过的 relay log 重写到自己的 binlog，让它**既是从库又是主库**。

**6. Keepalived 怎么判断对方真挂？**

> - VRRP 通告每秒 1 次，3 次未收到 → 对方挂
> - 健康检查脚本（`vrrp_script`）：HTTP / TCP / 自定义命令
> - 优先级：Master 100，Backup 90；Master 检查失败 -20 = 80，Backup 90 > 80，**自动接管虚 IP**
> - 抢占：默认 Master 恢复后会**抢回**（`nopreempt` 关闭抢占让 Backup 继续服务）

---

## §29 跨模块链接

- **Nginx 基础** → `[[LinuxNginx#配置]]` — LNMP 中 N 的完整配置
- **Nginx 反向代理** → `[[LinuxNginx#反向代理]]` — LNMP 上游代理
- **Keepalived 双机热备** → `[[LinuxKeepalived#mariadb主主]]` — 数据库高可用（待完善）
- **LVS 负载均衡** → `[[LinuxLVS#负载均衡]]` — 流量分发
- **防火墙放行 Web** → `[[Linux防火墙#web放行]]` — 80/443/3306
- **DNS 解析** → `[[LinuxDNS#a记录]]` — shop.laogao.cloud → 10.1.8.10
- **SSH 远程管理** → `[[Linux服务与SSH#ssh远程执行]]` — 远程维护 Web 服务器
- **系统监控** → `[[Linux进程与负载]]` — CPU / 内存 / 负载
- **日志分析** → `[[Linux日志与时间]]` — access_log / error_log
- **文件传输** → `[[Linux文件传输]]` — scp/rsync 迁移 WordPress
- **包管理** → `[[Linux包管理]]` — yum 装 nginx / mariadb / php
- **用户权限** → `[[Linux用户权限]]` — nginx:apache 用户
- **存储** → `[[Linux存储]]` — 数据盘挂载 /var/www/html
- **SELinux** → `[[LinuxSELinux]]` — 80/443 端口标签
- **计划任务** → `[[Linux计划任务]]` — crontab 备份
- **网络基础** → `[[Linux网络]]` — 端口 / 路由

---

## 附录 A：WordPress 一键安装脚本

```bash
#!/bin/bash
# install-wordpress.sh
set -e

DB_PASS="huawei"
DOMAIN="www.laogao.cloud"
DOC_ROOT="/var/www/html"

# 1. 安装依赖
yum install -y mariadb-server mariadb php php-fpm php-mysqlnd php-gd php-mbstring php-xml httpd

# 2. 启动
systemctl enable --now mariadb httpd php-fpm

# 3. 安全初始化
mysql_secure_installation <<EOF
y
$DB_PASS
$DB_PASS
y
n
y
y
EOF

# 4. 创建数据库
mysql -uroot -p$DB_PASS <<EOF
CREATE DATABASE wordpress;
CREATE USER wordpress@localhost IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON wordpress.* TO wordpress@localhost;
FLUSH PRIVILEGES;
EOF

# 5. 部署 WordPress
cd /root
[ ! -d wordpress ] && unzip -q wordpress-4.8-zh_CN.zip
cp -aR wordpress $DOC_ROOT/
chown -R apache:apache $DOC_ROOT/wordpress/
chmod -R 755 $DOC_ROOT/wordpress/

# 6. 配置 wp-config
cp $DOC_ROOT/wordpress/wp-config-sample.php $DOC_ROOT/wordpress/wp-config.php
sed -i "s/database_name_here/wordpress/; s/username_here/wordpress/; s/password_here/$DB_PASS/" \
    $DOC_ROOT/wordpress/wp-config.php

# 7. 重启
systemctl restart httpd

echo "WordPress 已部署，访问 http://$DOMAIN/wordpress/ 完成向导"
```

## 附录 B：LNMP-ECshop 一键安装脚本

```bash
#!/bin/bash
# install-lnmp-ecshop.sh
set -e

DB_PASS="huawei"
DOMAIN="shop.laogao.cloud"
DOC_ROOT="/usr/share/nginx/html"

# 1. 安装 LNMP
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install -y nginx mariadb-server php php-fpm \
               php-gd php-common php-pear php-mbstring php-mcrypt php-mysqlnd

# 2. 启动
systemctl enable --now nginx mariadb php-fpm

# 3. MariaDB 安全初始化
mysql_secure_installation <<EOF
y
$DB_PASS
$DB_PASS
y
n
y
y
EOF

# 4. 创建 ECshop 数据库
mysql -uroot -p$DB_PASS <<EOF
CREATE DATABASE ecshop;
CREATE USER ecshop@localhost IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON ecshop.* TO ecshop@localhost;
FLUSH PRIVILEGES;
EOF

# 5. 修改 php-fpm 用户
sed -i 's/^user = apache/user = nginx/; s/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf

# 6. 配置 Nginx 虚拟主机
cat > /etc/nginx/conf.d/vhost-$DOMAIN.conf <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    root $DOC_ROOT;
    index index.php;

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX

# 7. 部署 ECshop
cd /root
[ -d ECShop_V4.1.20_UTF8_release20250416 ] || unzip -q ECShop_V4.1.20_UTF8.zip
[ -d $DOC_ROOT.ori ] || mv $DOC_ROOT $DOC_ROOT.ori
cp -a ECShop_V4.1.20_UTF8_release20250416/source/ecshop $DOC_ROOT
chown -R nginx:nginx $DOC_ROOT
chown -R nginx:nginx /var/lib/php/

# 8. 重启
systemctl restart nginx php-fpm

echo "ECshop 已部署，访问 http://$DOMAIN 完成安装向导"
```

## 附录 C：常用故障速查表

| 现象 | 可能原因 | 检查命令 |
|------|----------|----------|
| 502 Bad Gateway | php-fpm 未启动 / sock 路径不一致 | `systemctl status php-fpm` `grep listen /etc/php-fpm.d/www.conf` `grep fastcgi_pass /etc/nginx/conf.d/*.conf` |
| 403 Forbidden | DirectoryIndex 缺 / 权限错 | `ls -la /var/www/html/` `grep DirectoryIndex /etc/httpd/conf/httpd.conf` |
| 404 Not Found | root 路径错 / 软链坏 | `ls /usr/share/nginx/html/test.php` `nginx -T | grep root` |
| 500 Internal Server Error | PHP 语法错 / .htaccess 语法错 | `tail -f /var/log/nginx/error.log` `tail -f /var/log/php-fpm/www-error.log` |
| 数据库连接失败 | 用户/密码/库名错 | `mysql -u wordpress -phuawei wordpress` |
| 上传文件失败 | 目录无写权限 | `ls -ld /var/www/html/wordpress/wp-content/uploads/` |
| 中文乱码 | 数据库字符集不匹配 | `SHOW VARIABLES LIKE 'character_set%'` |
| 慢查询 | 缺索引 / 大表 | `EXPLAIN SELECT ...` |
| OOM Killed | PHP-FPM 进程过多 | `pm.max_children` 调小 |
| 磁盘满 | 日志/上传过大 | `du -sh /var/log /var/www/html/upload` |

---

**完成情况**：
- ✅ LAMP + LNMP 架构完整对比
- ✅ LAMP-WordPress 实战（PDF LAMP 6 页内容已合并）
- ✅ LNMP-ECshop 实战（PDF LNMP 7 页内容已合并）
- ✅ MariaDB 主主复制 + Keepalived 双机热备
- ✅ 性能对比 + 安全 + 监控 + 故障排查
- ✅ 易错点 ×12、面试 ×6、速查表
- ✅ 跨模块链接到现有 Linux 笔记