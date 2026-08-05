---
title: Linux 用户、组与文件权限 — CentOS-7 实战
desc: 基于 05.CentOS-7-系统管理-1/9. 用户和组管理.pdf + 10. 提权管理.pdf + 11. 文件权限管理.pdf 的实操笔记。覆盖 UID/GID、用户/组管理、su/sudo、chmod 字符/数字法、SUID/SGID/sticky、ACL、chattr。
type: 笔记
module: Linux用户权限
pdfs:
  - 05.9 Linux 用户和组管理.pdf (558 KB)
  - 05.10 Linux 提权管理.pdf (318 KB)
  - 05.11 Linux 文件权限管理.pdf (715 KB)
status: 完成
---

# Linux 用户、组与文件权限 — CentOS-7 实战

> **范围**：基于《CentOS-7 系统管理 1》PDF 9 + 10 + 11 整理，覆盖**用户和组** + **提权** + **文件权限** 三大块。  
> **前置**：[[Linux目录/目录的权限]] 已有的 UGO/ACL 强化版可以**跳过**对应小节，本笔记提供**完整 PDF 复现**。

## 目录

- [[#§0 心智模型：Linux 权限 = 你是谁 + 文件给你什么]]
- [[#§1 用户分类：root / 系统 / 普通]]
- [[#§2 /etc/passwd：用户身份证（7 字段）]]
- [[#§3 /etc/group：组花名册（4 字段）]]
- [[#§4 用户管理：useradd / usermod / userdel]]
- [[#§5 组管理：groupadd / groupmod / groupdel / groupmems]]
- [[#§6 /etc/login.defs 和 /etc/skel/ 模板]]
- [[#§7 文件权限基础：rwx × ugo]]
- [[#§8 chmod 命令：字符法 + 数字法]]
- [[#§9 chown / chgrp：改属主与属组]]
- [[#§10 umask：默认权限掩码]]
- [[#§11 SUID：让用户临时"成为文件主人"]]
- [[#§12 SGID：组继承的目录]]
- [[#§13 sticky：粘滞位（/tmp 的秘密）]]
- [[#§14 ACL 访问控制列表]]
- [[#§15 chattr：文件属性锁定]]
- [[#§16 提权基础：su vs su -]]
- [[#§17 提权核心：sudo 与 /etc/sudoers]]
- [[#§18 实战：白名单授权 + 审计]]
- [[#§19 速查表]]
- [[#§20 易错点 ×15]]
- [[#§21 面试 8 大追问]]
- [[#§22 链路]]

---

## §0 心智模型：Linux 权限 = 你是谁 + 文件给你什么

```
Linux 权限检查 = 两个问题的答案
  Q1. 你是谁？（UID + GID + 所属组）
  Q2. 文件给你什么？（u/g/o 的 rwx）

类比：
  你 = 普通员工（xkw）
  文件 = 公司保险柜（passwd）
  保险柜权限：root 有钥匙，wheel 组能看，other 不能碰

  xkw 想看 passwd？
    1. 你是 xkw（不在 root、不在 wheel）→ 走 other 权限
    2. passwd 的 other 权限是 --- （无）
    → Permission denied！
```

**核心三问**：
1. 文件属主是谁？属组是谁？
2. 你（用户）属于哪个组？
3. 文件给你这一类人开了什么权限？

---

## §1 用户分类：root / 系统 / 普通

```bash
# 查看当前用户
[xkw@centos7 ~]$ id
uid=1000(xkw) gid=1000(xkw) groups=1000(xkw),10(wheel)
```

Linux 用户分**三类**：

| 类型 | UID 范围 | 说明 | 典型例子 |
|---|---|---|---|
| **超级用户 root** | UID 0 | 系统的"上帝"，无所不能 | root |
| **系统用户** | UID 1-999（CentOS-7）| 不允许登录（shell = `/sbin/nologin`），专门跑服务 | postfix (89), adm (3) |
| **普通用户** | UID 1000-60000 | 真人登录用 | xkw (1000) |

```bash
# 范围来自 /etc/login.defs
[root@centos7 ~]# grep -E 'UID_|GID_' /etc/login.defs
UID_MIN          1000       # 普通用户最小 UID
UID_MAX          60000      # 普通用户最大 UID
SYS_UID_MIN      201        # 系统用户最小 UID
SYS_UID_MAX      999        # 系统用户最大 UID
```

> 💡 **快速记忆**：UID 0 = 神；1-999 = 鬼（系统服务）；1000+ = 人。

---

## §2 /etc/passwd：用户身份证（7 字段）

```
文件路径：/etc/passwd
字段数：7 段，冒号分隔
格式：name:password:UID:GID:GECOS:directory:shell
```

```bash
[xkw@centos7 ~]$ grep xkw /etc/passwd
xkw:x:1000:1000:software admin:/home/xkw:/bin/bash
```

| 字段 | 含义 | 示例 |
|---|---|---|
| 1. **name** | 用户名 | `xkw` |
| 2. **password** | 密码占位符 `x`（真实密码在 `/etc/shadow`）| `x` |
| 3. **UID** | 用户 ID | `1000` |
| 4. **GID** | 主组 ID | `1000` |
| 5. **GECOS** | 备注信息（用户全名、电话等）| `software admin` |
| 6. **directory** | 家目录 | `/home/xkw` |
| 7. **shell** | 登录 shell | `/bin/bash`（系统服务是 `/sbin/nologin`）|

### 2.1 系统用户例子

```bash
[xkw@centos7 ~]$ grep postfix /etc/passwd
postfix:x:89:89::/var/spool/postfix:/sbin/nologin
                              ↑             ↑
                          无 GECOS      nologin shell（不能登录）
```

> 💡 `/sbin/nologin` 是"礼貌的拒绝"——禁止交互登录，但服务可以正常用。

---

## §3 /etc/group：组花名册（4 字段）

```
文件路径：/etc/group
字段数：4 段，冒号分隔
格式：group_name:password:GID:user_list
```

```bash
[xkw@centos7 ~]$ grep wheel /etc/group
wheel:x:10:xkw
```

| 字段 | 含义 | 示例 |
|---|---|---|
| 1. **group_name** | 组名 | `wheel` |
| 2. **password** | 组密码（基本不用）| `x` |
| 3. **GID** | 组 ID | `10` |
| 4. **user_list** | 附加组成员（用逗号分隔，**不含主组**）| `xkw` |

### 3.1 主组 vs 附加组

```bash
# 主组 = /etc/passwd 第 4 字段（GID）
# 附加组 = /etc/group 第 4 字段（user_list）

# 看 xkw 的所有组
[xkw@centos7 ~]$ id xkw
uid=1000(xkw) gid=1000(xkw) groups=1000(xkw),10(wheel)
                       ↑主组            ↑附加组
```

> 💡 **主组 vs 附加组**：
> - 主组：每用户**只能有 1 个**，在 `/etc/passwd` 里
> - 附加组：可以有**多个**，在 `/etc/group` 里

---

## §4 用户管理：useradd / usermod / userdel

### 4.1 useradd 基础

```bash
# 1) 最简：自动分配 UID、建家目录、复制 /etc/skel
[root@centos7 ~]# useradd user01
[root@centos7 ~]# grep user01 /etc/passwd
user01:x:1003:1003::/home/user01:/bin/bash
```

### 4.2 useradd 高级选项

```bash
# 2) 完整版：自定义 UID / 家目录 / 备注 / 组 / shell
[root@centos7 ~]# useradd \
  -u 8888 \                     # 指定 UID
  -d /opt/user02 \              # 自定义家目录
  -c "user for software manage" \ # 备注
  -g wheel \                    # 主组
  -s /sbin/nologin \            # 不允许登录
  user02

# 验证
[root@centos7 ~]# grep user02 /etc/passwd
user02:x:8888:10:user for software manager:/opt/user02:/sbin/nologin
```

| 选项 | 含义 |
|---|---|
| `-u UID` | 指定 UID |
| `-d 目录` | 自定义家目录 |
| `-c 备注` | GECOS 字段 |
| `-g 组` | 主组（必须已存在） |
| `-G 组1,组2` | 附加组（多个用逗号） |
| `-s shell` | 登录 shell |
| `-M` | 不创建家目录 |
| `-p ''` | 空密码（**慎用**） |

### 4.3 /etc/skel/ 模板目录

```bash
# 用户家目录的"模板"，每次 useradd 都会从这里复制
[root@centos7 ~]# ls -a /etc/skel/
.  ..  .bash_logout  .bash_profile  .bashrc

# 在 skel 里加文件 → 下次 useradd 自动复制
[root@centos7 ~]# echo 'Welcome!' > /etc/skel/WELCOME.txt
[root@centos7 ~]# useradd user03
[root@centos7 ~]# ls -a /home/user03/
.  ..  .bash_logout  .bash_profile  .bashrc  WELCOME.txt
```

### 4.4 passwd 设密码

```bash
# 交互式（推荐）
[root@centos7 ~]# passwd user01
New password: ******
Retype new password: ******

# 脚本自动化（用 stdin）
[root@centos7 ~]# echo redhat | passwd --stdin user01
Changing password for user user01.
passwd: all authentication tokens updated successfully.

# 演示：批量创建用户
for user in alice bob charlie; do
    useradd $user
    echo "default123" | passwd --stdin $user
done
```

### 4.5 usermod 修改用户

```bash
# 改主组
[root@centos7 ~]# usermod -g wheel user01

# 加附加组（-a 追加，不加则覆盖）
[root@centos7 ~]# usermod -aG docker,devops user01

# 改 shell
[root@centos7 ~]# usermod -s /bin/bash user02     # 改回可登录

# 改家目录
[root@centos7 ~]# usermod -d /new/home user01

# 锁定用户（密码前加 !）
[root@centos7 ~]# usermod -L user01               # Lock
[root@centos7 ~]# usermod -U user01               # Unlock
```

### 4.6 userdel 删除用户

```bash
# 仅删用户，保留家目录
[root@centos7 ~]# userdel user01

# 删用户 + 家目录 + 邮件池（彻底删除）
[root@centos7 ~]# userdel -r user01

# 演示：清理
[root@centos7 ~]# ls /home/                        # 确认家目录没了
```

### 4.7 实战：用户登录异常修复

```bash
# 现象：用户登录报 "Permission denied"
Could not chdir to home directory /home/zhangsan: Permission denied
-bash: /home/zhangsan/.bash_profile:                 ← 权限不够

# 修复步骤（3 步）
[root@centos7 ~]# cp -r /etc/skel/ /home/zhangsan
[root@centos7 ~]# chown -R zhangsan:zhangsan /home/zhangsan
[root@centos7 ~]# chmod u=rwx /home/zhangsan

# 验证
[root@centos7 ~]# ll -d /home/zhangsan
drwx------. 3 zhangsan zhangsan 78 ... /home/zhangsan
```

---

## §5 组管理：groupadd / groupmod / groupdel / groupmems

### 5.1 groupadd / groupmod / groupdel

```bash
# 建组（自动分配 GID）
[root@centos7 ~]# groupadd admin

# 建组（指定 GID）
[root@centos7 ~]# groupadd sysadmin -g 2000

# 改名
[root@centos7 ~]# groupmod --new-name admins admin

# 改 GID
[root@centos7 ~]# groupmod -g 2002 admins

# 删组（不能删有用户的组）
[root@centos7 ~]# groupdel sysadmin

# 验证
[root@centos7 ~]# grep 'admin' /etc/group
printadmin:x:997:
admin:x:1002:
admins:x:2002:
```

### 5.2 groupmems 管理组成员

```bash
# 查看帮助
[root@centos7 ~]# groupmems --help
# -g 组名 -a 用户（加） -d 用户（删） -l 列表 -p 清空

# 加成员
[root@centos7 ~]# groupmems -g admins -a xkw
[root@centos7 ~]# groupmems -g admins -l
xkw

# 看用户的组变化
[root@centos7 ~]# id xkw
uid=1000(xkw) gid=1000(xkw) groups=1000(xkw),10(wheel),2002(admins)

# 删成员
[root@centos7 ~]# groupmems -g admins -d xkw

# 清空组（踢走所有附加成员）
[root@centos7 ~]# groupmems -g admins -p
```

---

## §6 /etc/login.defs 和 /etc/skel/ 模板

### 6.1 /etc/login.defs 全局默认

```bash
[root@centos7 ~]# vim /etc/login.defs

MAIL_DIR        /var/spool/mail
UMASK           022              # 默认 umask
HOME_MODE       0700             # 默认家目录权限

PASS_MAX_DAYS   99999            # 密码最长有效天数
PASS_MIN_DAYS   0                # 改密最少间隔
PASS_MIN_LEN    5                # 最短密码长度
PASS_WARN_AGE   7                # 过期前 7 天警告

# UID/GID 范围
UID_MIN         1000
UID_MAX         60000
SYS_UID_MIN     201
SYS_UID_MAX     999
GID_MIN         1000
GID_MAX         60000

CREATE_HOME     yes              # 自动创建家目录
```

> 💡 **改完必须用新命令才生效**（useradd 读一次，不会重读）。

### 6.2 /etc/skel/ 模板目录

见 §4.3，useradd 会从这里复制**隐藏文件**（`.bashrc` 等）。

---

## §7 文件权限基础：rwx × ugo

### 7.1 经典 ls -l 输出

```bash
[xkw@centos7 ~]$ ls -l myfile
-rw-r-----. 1 xkw wheel 2262 Dec 23 08:47 myfile
```

```
-  rw-r-----  .   1   xkw   wheel   2262   Dec 23 08:47   myfile
↑  ↑   ↑    ↑   ↑    ↑       ↑       ↑         ↑              ↑
类  属主权限  ACL 家数 属主   属组    大小     时间           文件名
型 属组权限 标识 链接
   其他权限
```

### 7.2 三组 × 三权限

```
        user (u)   group (g)   other (o)
        ----------  ----------  ----------
权限     r w x      r w x       r w x
二进制    4 2 1      4 2 1       4 2 1
```

| 权限 | 文件含义 | 目录含义 |
|---|---|---|
| **r (read, 4)** | 可读文件内容 | 可列出目录内容（`ls`）|
| **w (write, 2)** | 可修改文件内容 | 可增删文件（但要 +x）|
| **x (execute, 1)** | 可执行（脚本/程序）| 可进入目录（`cd`）|

### 7.3 权限检查的匹配顺序

```
你是 xkw，文件 myfile 权限是 -rw-r-----  属主 xkw 属组 wheel

1) xkw 是属主 → 走 u 权限：rw- ✓ (能读能写)
2) xkw 是 wheel 组成员 → 走 g 权限（但只匹配第一个匹配的）
3) xkw 不是 other

→ xkw 只能 rw，不能执行

⚠️ 关键：Linux 权限检查只看"第一个匹配的类"
  你是属主 → 就看 u，不再看 g 或 o
```

---

## §8 chmod 命令：字符法 + 数字法

### 8.1 字符法（适合"加减权限"）

```bash
# 语法：chmod WhoHowWhat /path/to/file
#   Who: u (user) g (group) o (other) a (all)
#   How: + (加) - (减) = (设为)
#   What: r w x - (无)
```

```bash
# 1) 准备实验目录
[root@centos7 ~]# mkdir /lab
[root@centos7 ~]# cd /lab
[root@centos7 lab]# cp /etc/passwd .

# 2) 给属主加执行权限
[root@centos7 lab]# chmod u+x ./passwd
[root@centos7 lab]# ls -l passwd
-rwxr--r--. 1 root root 2312 ...

# 3) 同时改多组（逗号分隔）
[root@centos7 lab]# chmod u-wx,g+w,o=- passwd
[root@centos7 lab]# ls -l passwd
-r--rw----. 1 root root 2312 ...

# 4) 全部设为 rwx
[root@centos7 lab]# chmod a=rwx passwd
-rwxrwxrwx. 1 root root 2312 ...

# 5) 减去 w 和 x
[root@centos7 lab]# chmod a-wx passwd
-r--r--r--. 1 root root 2312 ...
```

### 8.2 数字法（适合"批量设权限"）

```
# 000 - 0：--- （全无）
# 001 - 1：--x （执行）
# 010 - 2：-w- （写）
# 011 - 3：-wx （写+执行）
# 100 - 4：r-- （读）
# 101 - 5：r-x （读+执行）
# 110 - 6：rw- （读+写）
# 111 - 7：rwx （全有）

# 三组三个数字：属主 属组 其他
```

```bash
# 1) -rw-r--r-- = 644
#    110 100 100 → 6  4  4
[root@centos7 lab]# chmod 644 passwd
[root@centos7 lab]# ls -l passwd
-rw-r--r--. 1 root root 2312 ...

# 2) -rwxrw-r-x = 765
#    111 110 101 → 7  6  5
[root@centos7 lab]# chmod 765 passwd
-rwxrw-r-x. 1 root root 2312 ...

# 3) 用 stat 看权限
[root@centos7 lab]# stat -c %A passwd       # 字符形式
-rwxrw-r-x.
[root@centos7 lab]# stat -c %a passwd       # 数字形式
765
```

### 8.3 常用数字速记

| 数字 | 权限 | 典型用途 |
|---|---|---|
| **644** | `-rw-r--r--` | 普通文件（属主读写，其他人读） |
| **755** | `-rwxr-xr-x` | 可执行文件 / 目录（属主全权，其他人读+执行）|
| **700** | `-rwx------` | 私密目录（仅自己）|
| **600** | `-rw-------` | 私密文件（如 SSH key）|
| **777** | `-rwxrwxrwx` | **危险**——任何人都能改 |
| **600** + **目录 700** | — | SSH key / 家目录标准 |

> 💡 **黄金组合**：文件 644 / 目录 755 / 私钥 600 / 私目录 700。

### 8.4 -R 递归

```bash
# 给整个目录树改权限
[root@centos7 lab]# chmod -R u+rwx dir01
[root@centos7 lab]# ls -ld dir01 dir01/*
drwx------. 2 root root 20 ... dir01
-rwx------. 1 root root  0 ... dir01/file01
```

---

## §9 chown / chgrp：改属主与属组

### 9.1 改属主（chown）

```bash
# 改属主
[root@centos7 lab]# chown xkw passwd
-rwxr-xr-x. 1 xkw root 2312 ...

# 改属主 + 属组（冒号分隔）
[root@centos7 lab]# chown laowang:root passwd
-rwxr-xr-x. 1 laowang root 2312 ...

# 改属组（用 chown 也行）
[root@centos7 lab]# chown :wheel passwd
-rwxr-xr-x. 1 laowang wheel 2312 ...
```

### 9.2 改属组（chgrp）

```bash
# 等价于 chown :wheel
[root@centos7 lab]# chgrp wheel passwd
-rwxr-xr-x. 1 laowang wheel 2312 ...
```

### 9.3 -R 递归

```bash
# 递归改整个目录
[root@centos7 lab]# chown -R xkw dir01/
drwxrwx---. 2 xkw root 20 ... dir01

# 同时改属主+属组
[root@centos7 lab]# chown -R laowang:wheel dir01/
drwxrwx---. 2 laowang wheel 20 ... dir01
```

### 9.4 实战：部署 web 服务

```bash
# 场景：web 服务器以 apache 用户运行，文件属主改成 apache
[root@centos7 ~]# chown -R apache:apache /var/www/html/
[root@centos7 ~]# chmod -R 755 /var/www/html/
```

---

## §10 umask：默认权限掩码

### 10.1 什么是 umask

```
umask = "减去的权限"
新建文件/目录的默认权限 = 基础权限 - umask

  文件基础权限 = 666 (rw-rw-rw-)
  目录基础权限 = 777 (rwxrwxrwx)
```

### 10.2 查看当前 umask

```bash
# 默认 0022
[xkw@centos7 lab]$ umask
0022
# 0022 的含义：
#   第 1 个 0 = 特殊权限（SUID/SGID/sticky）
#   022 = 属组减去 2 (w)，其他减去 2 (w)

# 新建文件的权限 = 666 - 022 = 644
[xkw@centos7 lab]$ touch f1
-rw-r--r--. 1 xkw xkw 0 ... f1

# 新建目录的权限 = 777 - 022 = 755
[xkw@centos7 lab]$ mkdir d1
drwxr-xr-x. 2 xkw xkw 6 ... d1
```

### 10.3 修改 umask

```bash
# 临时改（当前 Shell）
[xkw@centos7 lab]$ umask 0
[xkw@centos7 lab]$ touch f2
-rw-rw-rw-. 1 xkw xkw 0 ... f2

# 改严（只自己看）
[xkw@centos7 lab]$ umask 077
[xkw@centos7 lab]$ touch f3
-rw-------. 1 xkw xkw 0 ... f3

# 永久改（用户级）
[xkw@centos7 lab]$ echo 'umask 077' >> ~/.bashrc

# 永久改（系统级）
[root@centos7 ~]# echo 'umask 077' >> /etc/bashrc
```

> 💡 **生产建议**：SSH key 文件 600 / 家目录 700 时，设 `umask 077`。

---

## §11 SUID：让用户临时"成为文件主人"

### 11.1 问题：passwd 怎么改 /etc/shadow？

```bash
# /etc/shadow 是 root 才能写
[xkw@centos7 ~]$ ls -l /etc/shadow
----------. 1 root root 1264 ... /etc/shadow
# 权限是 ----------（任何人不能动）

# 但 xkw 可以执行 passwd 改自己的密码
[xkw@centos7 ~]$ passwd
Changing password for user xkw.    ← 成功了！
```

### 11.2 SUID 魔法

```bash
# 看 passwd 命令的特殊权限
[xkw@centos7 ~]$ ls -l $(which passwd)
-rwsr-xr-x. 1 root root 27856 Apr 1 2020 /usr/bin/passwd
#    ↑ 这里有个 s！
#    ↑ SUID = Set User ID

# 含义：执行 passwd 时，用户临时"变成" root
```

### 11.3 设置 SUID

```bash
# 给 vim 加 SUID（危险演示！）
[root@centos7 ~]# chmod u+s /usr/bin/vim
[root@centos7 ~]# ls -l /usr/bin/vim
-rwsr-xr-x. 1 root root 2337216 ... /usr/bin/vim

# ⚠️ 现在任何用户执行 vim 都"是 root"！
[xkw@centos7 ~]$ vim /etc/passwd
# 能改 /etc/passwd 了！极端危险！

# 撤销 SUID
[root@centos7 ~]# chmod u-s /usr/bin/vim
```

### 11.4 数字法：4xxx

```bash
# SUID = 4 + 权限
chmod 4755 file    # 4 = SUID + 755 = rwsr-xr-x
chmod 4655 file    # 4 = SUID + 655 = rwsr-xr-x
```

### 11.5 查找所有 SUID 文件

```bash
# 全盘找 SUID（安全审计常用）
[root@centos7 ~]# find / -perm -4000 -type f 2>/dev/null
/usr/bin/passwd
/usr/bin/su
/usr/bin/sudo
/usr/bin/mount
/usr/bin/umount
/usr/bin/chfn
/usr/bin/chsh
/usr/bin/gpasswd
/usr/bin/newgrp
...
```

> ⚠️ **安全警告**：SUID 越多 = 攻击面越大。要审查！  
> 排查：`find / -perm -4000 -type f` 看有没有"陌生"的 SUID。

---

## §12 SGID：组继承的目录

### 12.1 问题：团队协作目录

```
场景：dev1 和 dev2 都在 devops 组，要共享 webapp/ 目录

朴素做法：每次新文件都手动 chgrp devops → 麻烦！

解决方案：给目录设 SGID → 新文件自动继承目录的组
```

### 12.2 SGID 设置

```bash
# 准备
[root@centos7 lab]# groupadd devops
[root@centos7 lab]# useradd -G devops dev1
[root@centos7 lab]# useradd -G devops dev2

[root@centos7 lab]# mkdir webapp
[root@centos7 lab]# chgrp devops webapp
[root@centos7 lab]# chmod g=rwx webapp

# 设 SGID（在属组 x 位变 s）
[root@centos7 lab]# chmod g+s webapp
[root@centos7 lab]# ls -ld webapp
drwxrws---. 2 root devops ... webapp
#         ↑ 这里 s = SGID
```

### 12.3 验证：dev1 创建文件自动继承 devops 组

```bash
# dev1 创建文件
[dev1@centos7 lab]$ touch webapp/dev-f1
[dev1@centos7 lab]$ ll webapp/dev-f1
-rw-rw-r--. 1 dev1 dev1 ... webapp/dev-f1          ← 没 SGID：组是 dev1

# 设 SGID 后
[root@centos7 lab]# chmod g+s webapp
[dev1@centos7 lab]$ touch webapp/dev-f2
[dev1@centos7 lab]$ ll webapp/dev-f2
-rw-rw-r--. 1 dev1 devops ... webapp/dev-f2         ← 有 SGID：组是 devops！

# dev2 现在能改这个文件了！
[dev2@centos7 lab]$ echo hello world >> webapp/dev-f2
[dev2@centos7 lab]$ cat webapp/dev-f2
hello world                                          ← 成功！
```

### 12.4 数字法：2xxx

```bash
chmod 2755 file    # 2 = SGID + 755
chmod 2775 dir     # 2 = SGID + 775（团队目录标准）
```

---

## §13 sticky：粘滞位（/tmp 的秘密）

### 13.1 问题：/tmp 谁都能删？

```bash
# /tmp 的权限很特殊
[root@centos7 lab]# ls -ld /tmp
drwxrwxrwt. 20 root root 4096 ... /tmp
#            ↑ t = sticky（粘滞位）
#            ↑ 1777 = sticky + 777
```

```
场景：xkw 在 /tmp 创了文件 storage.log
      alice 想删它？
        没 sticky → 任何人都能删！乱套！
        有 sticky → 只有 root + 文件主能删
```

### 13.2 演示

```bash
# 没 sticky 的演示
[xkw@centos7 ~]$ touch /tmp/xkw-f1
[xkw@centos7 ~]$ rm /tmp/storage.log
rm: cannot remove '/tmp/storage.log': Operation not permitted
#                            ↑ 因为 /tmp 有 sticky，alice 不是 owner 删不了

# 反例（自己有权限删自己）
[xkw@centos7 ~]$ rm /tmp/xkw-f1
# ✓ 删成功
```

### 13.3 设置 sticky

```bash
# 给目录加 sticky（其他人 x 位变 t）
chmod +t /shared/

# 数字法：1xxx
chmod 1777 /shared/    # 1 = sticky + 777

# 撤销
chmod -t /shared/
```

### 13.4 应用场景

| 场景            | 是否需要 sticky |
| ------------- | ----------- |
| `/tmp` 系统公共目录 | ✅ 必须        |
| 团队共享上传目录      | ✅ 推荐        |
| 私密目录          | ❌ 不需要       |
| 普通工作目录        | ❌ 不需要       |

### 13.5 三种特殊权限总览

| 特殊位 | 数字 | 字母位置 | 作用 | 适用 |
|---|---|---|---|---|
| **SUID** | **4** | u-x → u-s | 执行时临时变属主 | 可执行文件 |
| **SGID** | **2** | g-x → g-s | 执行时临时变属组 / 目录文件继承组 | 可执行文件 / 目录 |
| **sticky** | **1** | o-x → o-t | 目录里只能删自己的文件 | 公共目录 |

---

## §14 ACL 访问控制列表

### 14.1 为什么需要 ACL

```
UGO 权限的局限：只有 3 类（属主/属组/其他）
                如果要给"特定用户"额外授权？做不到！

ACL = 给文件加"额外名单"，绕开 UGO 限制
```

### 14.2 给用户加 ACL

```bash
# 准备
[root@centos7 lab]# cp /etc/passwd ./passwd
[root@centos7 lab]# chmod o=- passwd          # 其他完全没权限

# 给 xkw 加 rw 权限
[root@centos7 lab]# setfacl -m u:xkw:rw passwd

# 文件权限位 + （表示有 ACL）
[root@centos7 lab]# ls -l passwd
-rw-rw----+ 1 root root 2539 ... passwd
#                       ↑ + 标记

# 看 ACL
[root@centos7 lab]# getfacl passwd
# file: passwd
# owner: root
# group: root
user::rw-             # 属主 root
user:xkw:rw-        # ← ACL：xkw 有 rw
group::r--            # 属组 root
mask::rw-             # ← mask（最大权限）
other::---            # other 没权限
```

### 14.3 给组加 ACL

```bash
# 给 wheel 组加 rwx
[root@centos7 lab]# setfacl -m g:wheel:rwx passwd

# 同时给多个用户/组（逗号分隔）
[root@centos7 lab]# setfacl -m u:tom:rwx,u:xkw:r passwd
```

### 14.4 mask（有效权限掩码）

```
mask = 所有 ACL 条目的"上限"

[root@centos7 lab]# setfacl -m m:- passwd       # 把 mask 改为 ---
[root@centos7 lab]# getfacl passwd
user::rw-             # 属主没动
user:xkw:rw-        # effective:---  ← mask 限制后实际无权限！
group::r--            # effective:---
group:wheel:rwx       # effective:---
mask::---             # ← mask 设成全无
```

> ⚠️ mask 不能用普通方式"减"掉——它是 ACL 的"天花板"。

### 14.5 目录的 default ACL（继承）

```bash
# 给目录加 default ACL → 子文件/目录自动继承
[root@centos7 lab]# mkdir test
[root@centos7 lab]# setfacl -m d:u:xkw:rw test

# 看
[root@centos7 lab]# getfacl test/
default:user::rwx
default:user:xkw:rw-      ← xkw 在 test 里建的文件自动 rw
default:group::r-x
default:mask::rwx
default:other::r-x

# 测试：touch 新文件
[root@centos7 lab]# touch test/f2
[root@centos7 lab]# ls -l test/f2
-rw-rw-r--+ 1 root root 0 ... test/f2    ← 有 + 标记，自动继承 ACL
```

### 14.6 删除 ACL

```bash
# 删除某条
[root@centos7 lab]# setfacl -x u:xkw passwd

# 删除所有 ACL
[root@centos7 lab]# setfacl -b passwd
```

---

## §15 chattr：文件属性锁定

### 15.1 不可变位（+i）

```bash
# 给文件加 i 属性（不可修改、不可删除、不可重命名）
[root@centos7 ~]# chattr +i passwd
[root@centos7 ~]# echo 'lw:x:1000:...' >> passwd
-bash: passwd: Operation not permitted       ← 改不动

[root@centos7 ~]# rm -f passwd
rm: cannot remove 'passwd': Operation not permitted

# 撤销
[root@centos7 ~]# chattr -i passwd
```

### 15.2 应用场景

```bash
# 保护关键系统文件
chattr +i /etc/passwd
chattr +i /etc/shadow
chattr +i /etc/group
chattr +i /etc/gshadow
chattr +i /etc/fstab

# 排查：找有 i 属性的文件
[root@centos7 ~]# lsattr /etc/passwd
----i----------- /etc/passwd
```

---

## §16 提权基础：su vs su -

### 16.1 su 切换用户

```bash
# 语法：su [-] [username [arg ...]]

# 切换到 root（不切换环境变量）
[xkw@centos7 ~]$ su
Password: redhat
# 此时是 root，但家目录还是 /home/xkw，PATH 还是 xkw 的

# 验证
[root@centos7 xkw]# env | grep xkw
LOGNAME=xkw
MAIL=/var/spool/mail/xkw
PATH=/usr/local/bin:/usr/bin:...:/home/xkw/bin  ← 还是 xkw 的
PWD=/home/xkw
USER=xkw
```

```bash
# 切换到 root（加载 root 环境，= login shell）
[xkw@centos7 ~]$ su -
Password: redhat
Last login: Mon Nov 7 15:40:31 CST 2022 on pts/2
[root@centos7 ~]# set | grep xkw
# 空 ← 完全切换到 root 环境
```

### 16.2 三种 su 的区别

| 命令 | 是否登录 shell | 切换环境 | 适用 |
|---|---|---|---|
| `su` | ❌ nologin shell | 不切换（继承当前）| 想保留一些环境 |
| `su -` | ✅ login shell | 完整切换 | **推荐**，干净 |
| `su -l user` | ✅ login shell | 切到 user | 切到非 root 用户 |

### 16.3 su -c 执行单条命令

```bash
# 以 laowang 身份执行 id
[xkw@centos7 ~]$ su -l laowang -c 'id'
Password:
uid=1001(laowang) gid=1001(laowang) groups=1001(laowang)

# ⚠️ 引号陷阱：不带引号会执行两次
[xkw@centos7 ~]$ su -l laowang -c cat /etc/hosts
Password:
# 实际执行了 cat /etc/hosts 在 xkw 环境下 → 错的
# 必须用单引号包整个命令
```

### 16.4 su 失败：nologin shell

```bash
# 系统用户（nologin shell）不能 su 切换
[root@centos7 ~]# grep adm /etc/passwd
adm:x:3:4:adm:/var/adm:/sbin/nologin

[root@centos7 ~]# su -l adm -c id
This account is currently not available.

# 变通：用 -s 指定 shell
[root@centos7 ~]# su -l adm -s /bin/bash -c id
uid=3(adm) gid=4(adm) groups=4(adm)
```

### 16.5 su vs sudo 对比

| 维度 | su | sudo |
|---|---|---|
| 需要知道 root 密码 | ✅ 是 | ❌ 否 |
| 输入自己密码 | ❌ 否 | ✅ 是 |
| 审计日志 | ❌ 没详细记录 | ✅ `/var/log/secure` |
| 细粒度授权 | ❌ 整个 root | ✅ 可指定命令 |
| 安全性 | ⚠️ 低 | ✅ 高（推荐）|

---

## §17 提权核心：sudo 与 /etc/sudoers

### 17.1 为什么用 sudo

```
场景：要给运维同事临时授权

su → 必须给 root 密码 → 不安全
sudo → 只需给"特定命令"的权限 → 可审计、可撤销
```

### 17.2 快速授权

```bash
# 1) 编辑 sudoers（必须用 visudo！会自动检查语法）
[root@centos7 ~]# export EDITOR=vim
[root@centos7 ~]# visudo

# 2) 找到 wheel 行（CentOS-7 默认有）
%wheel  ALL=(ALL)  ALL
# ↑ % 开头 = 组
# ↑ 含义：wheel 组的所有用户都能 sudo 任何命令

# 3) 让 xkw 能 sudo
[root@centos7 ~]# usermod -aG wheel xkw

# 4) 验证
[xkw@centos7 ~]$ sudo id
[sudo] password for xkw:
uid=0(root) gid=0(root) groups=0(root)
```

### 17.3 三种授权写法

```bash
# 写法 1：允许 laowang sudo 任何命令，需要密码
[root@centos7 ~]# visudo
laowang ALL=(ALL)   ALL

# 写法 2：不需要密码
laowang ALL=(ALL)   NOPASSWD: ALL

# 写法 3：只允许特定命令
laowang ALL=(ALL)   /sbin/useradd, /sbin/usermod, /sbin/userdel

# 验证（写法 3）
[laowang@centos7 ~]$ sudo id
Sorry, user laowang is not allowed to execute '/bin/id' as root on centos7.
[laowang@centos7 ~]$ sudo useradd laozhang
# ✓ 创建成功
```

### 17.4 /etc/sudoers.d/ 子配置（推荐）

```bash
# 不要再改主文件！用独立文件
[root@centos7 ~]# echo 'laowang ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/laowang
[root@centos7 ~]# cat /etc/sudoers.d/laowang
laowang ALL=(ALL) NOPASSWD:ALL
```

### 17.5 别名（Alias）

```bash
# Cmd_Alias：定义命令组
Cmnd_Alias SOFTWARE = /bin/rpm, /usr/bin/up2date, /usr/bin/yum

# User_Alias：定义用户组
User_Alias SYSADMINS = alice, bob, charlie

# 综合：sys 组能用 NETWORKING/SOFTWARE/SERVICES 等命令
%sys ALL = NETWORKING, SOFTWARE, SERVICES, STORAGE, DELEGATING, PROCESSES, LOCATE, DRIVERS
```

### 17.6 sudo -i = 完整登录

```bash
# sudo -i 等于 su -：加载目标用户环境
[xkw@centos7 ~]$ sudo -i
[root@centos7 ~]#
# 完全切到 root
```

---

## §18 实战：白名单授权 + 审计

### 18.1 案例：让 xiaoniuma 只能 vim /etc/passwd

```bash
# 1) 建用户
[root@centos7 ~]# useradd xiaoniuma
[root@centos7 ~]# echo 123 | passwd --stdin xiaoniuma

# 2) 授权（只允许 sudo vim）
[root@centos7 ~]# echo 'xiaoniuma ALL=(ALL) /bin/vim' > /etc/sudoers.d/xiaoniuma

# 3) 测试：sudo vim 可以
[xiaoniuma@centos7 ~]$ sudo vim /etc/passwd
# 在 vim 里改 UID 0 → 提权为 root！

# 4) 修复：UID 改回原值
[xiaoniuma@centos7 ~]$ sudo vim /etc/passwd
xiaoniuma:x:1001:1001::/home/xiaoniuma:/bin/bash     ← 改回 1001

# 5) 清理
[root@centos7 ~]# userdel -r xiaoniuma
[root@centos7 ~]# rm -f /etc/sudoers.d/xiaoniuma
```

> ⚠️ **教训**：给 vim 这种"全功能工具"的 sudo 权限 = 给 root 权限！  
> 正确做法：给专用工具（如 `vipw`、`visudo -s`）。

### 18.2 案例：审计 sudo 行为

```bash
# 所有 sudo 行为都记到 /var/log/secure
[root@centos7 ~]# tail -f /var/log/secure
Nov 8 16:38:01 centos7 sudo: xkw : TTY=pts/0 ; PWD=/home/xkw ; USER=root ; COMMAND=/bin/id
                                                                                       ↑ 完整命令
```

### 18.3 案例：批量部署 sudo 白名单

```bash
#!/bin/bash
# deploy_sudo.sh - 给运维团队部署统一 sudo 权限

SUDO_DIR=/etc/sudoers.d
TEAM_ADMINS="alice bob charlie"

# 命令白名单
cat > $SUDO_DIR/team-admins << 'EOF'
Cmnd_Alias NETWORKING = /sbin/route, /sbin/ifconfig, /bin/ping, /sbin/dhclient
Cmnd_Alias SERVICES = /usr/bin/systemctl, /usr/bin/journalctl
Cmnd_Alias STORAGE = /sbin/fdisk, /sbin/mkfs, /sbin/mount, /sbin/umount
EOF

# 用户授权
for user in $TEAM_ADMINS; do
    cat > $SUDO_DIR/$user << EOF
$user ALL=(ALL) NOPASSWD: NETWORKING, SERVICES, STORAGE
EOF
    chmod 0440 $SUDO_DIR/$user
done
```

---

## §19 速查表

### 19.1 用户管理

```bash
useradd user01                    # 最简创建
useradd -u 8888 -g wheel user01   # 指定 UID 和主组
useradd -M user01                 # 不建家目录
usermod -aG wheel user01          # 加附加组
usermod -L user01                 # 锁定
userdel -r user01                 # 删用户 + 家目录
passwd --stdin user01 < pwd.txt   # 脚本改密
id user01                         # 看 UID/GID/组
```

### 19.2 组管理

```bash
groupadd admin                    # 建组
groupadd -g 2000 sysadmin         # 指定 GID
groupmod --new-name admins admin  # 改名
groupdel sysadmin                 # 删组
groupmems -g admins -a xkw      # 加成员
groupmems -g admins -l            # 列成员
```

### 19.3 文件权限

```bash
chmod 755 file                    # 数字法
chmod u+x file                    # 字符法
chmod -R 755 dir/                 # 递归
chown user file                   # 改属主
chown user:group file             # 改属主+属组
chown -R user:group dir/          # 递归
chgrp group file                  # 改属组
```

### 19.4 高级权限

```bash
chmod u+s /usr/bin/vim            # SUID（危险）
chmod g+s /shared/dir             # SGID（团队目录）
chmod +t /tmp                     # sticky（公共目录）
chmod 4755 file                   # SUID 数字法
chmod 2775 dir                    # SGID 数字法
chmod 1777 dir                    # sticky 数字法
```

### 19.5 ACL

```bash
setfacl -m u:alice:rw file        # 给用户加 ACL
setfacl -m g:wheel:rwx file       # 给组加 ACL
setfacl -m m:- file               # 改 mask
setfacl -m d:u:alice:rw dir       # 目录 default ACL
setfacl -x u:alice file           # 删一条 ACL
setfacl -b file                   # 清空所有 ACL
getfacl file                      # 查看 ACL
```

### 19.6 umask / chattr

```bash
umask                             # 看
umask 077                         # 设（仅自己）
chattr +i file                    # 不可变
chattr -i file                    # 撤销不可变
lsattr file                       # 看属性
```

### 19.7 提权

```bash
su -                              # 切 root（登录 shell）
su - user                         # 切指定用户
su -c 'cmd' user                  # 切用户执行命令
sudo id                           # 临时提权
sudo -i                           # sudo 登录 root
visudo                            # 编辑 sudoers
echo 'user ALL=(ALL) ALL' > /etc/sudoers.d/user  # 子配置
```

---

## §20 易错点 ×15

### 1. ❌ 用 useradd 后没设密码

```bash
useradd alice                     # ⚠️ 用户建好了，但密码是空的（！）
# 必须再 passwd alice
```

### 2. ❌ 删用户没 -r

```bash
userdel alice                     # ⚠️ /home/alice 还在！
# 用 userdel -r alice
```

### 3. ❌ usermod -G 忘了 -a

```bash
usermod -G docker alice            # ⚠️ 覆盖原附加组
usermod -aG docker alice           # ✓ -a 是 append
```

### 4. ❌ chmod 数字法位数不够

```bash
chmod 75 file                     # ⚠️ 实际是 075 → _rwxr-xr-x
chmod 075 file                    # ✓ 明确 3 位
```

### 5. ❌ 改属主前忘了 sudo

```bash
chown alice file                  # ⚠️ Permission denied（如果不是你的）
sudo chown alice file             # ✓
```

### 6. ❌ SUID 加错位置

```bash
chmod g+s /usr/bin/vim            # ⚠️ 加到组了，没效果
chmod u+s /usr/bin/vim            # ✓ 加到 user
```

### 7. ❌ SGID 用在文件上没效果

```bash
chmod g+s /tmp/file.txt           # ⚠️ 文件没"组继承"语义
chmod g+s /tmp/dir                # ✓ 目录才有继承
```

### 8. ❌ sticky 加在文件上

```bash
chmod +t /tmp/myfile              # ⚠️ 文件没意义
chmod +t /tmp                     # ✓ 公共目录才有意义
```

### 9. ❌ ACL 加错对象

```bash
setfacl -m alice:rw file          # ⚠️ 缺 u: / g:
setfacl -m u:alice:rw file        # ✓
```

### 10. ❌ ACL 后改属组不生效

```bash
setfacl -m g:wheel:rwx file       # 加 ACL
chown root:wheel file             # ⚠️ ACL 还在，但 mask 可能变
# 检查：getfacl file
```

### 11. ❌ umask 算错

```bash
umask 077
touch f                           # 实际权限 = 666 - 077 = 600 (-rw-------)
                                  # 文件永远是 666 基础（无 x）
mkdir d                           # 实际权限 = 777 - 077 = 700 (drwx------)
                                  # 目录永远是 777 基础
```

### 12. ❌ chattr +i 后忘了 -i

```bash
chattr +i /etc/passwd             # ⚠️ 后面想改需要 -i
# 系统升级前必须先 -i！
```

### 13. ❌ su 不带 -

```bash
su root                           # ⚠️ 继承当前环境
su - root                         # ✓ 干净切换
```

### 14. ❌ sudo 不带命令

```bash
sudo                              # ⚠️ 报错，需要命令
sudo id                           # ✓
```

### 15. ❌ 改 /etc/sudoers 直接用 vim

```bash
vim /etc/sudoers                  # ⚠️ 语法错就崩！
visudo                            # ✓ 自动检查语法
```

---

## §21 面试 8 大追问

### Q1：UID 0 / 1-999 / 1000+ 分别是什么？

**答**：
- **0**：root
- **1-999（CentOS-7）**：系统用户（服务），shell 是 `/sbin/nologin`
- **1000+**：普通用户，可登录

范围在 `/etc/login.defs` 配置。

### Q2：`/etc/passwd` 第二列是 `x` 不是密码，密码在哪？

**答**：在 `/etc/shadow`，第二行权限是 `----------`（root 才能读写）。

### Q3：644 和 755 区别？

**答**：
- **644 文件**：属主读写，其他人只读（普通文件）
- **755 文件/目录**：属主全权，其他人读+执行（脚本/目录）

### Q4：SUID / SGID / sticky 三种特殊权限区别？

**答**：

| 特殊位 | 数字 | 位置 | 作用 |
|---|---|---|---|
| **SUID** | 4 | u-x → u-s | 执行时临时变属主 |
| **SGID** | 2 | g-x → g-s | 目录内文件继承组 |
| **sticky** | 1 | o-x → o-t | 目录里只能删自己的 |

### Q5：`chmod u+s /usr/bin/vim` 危险在哪？

**答**：vim 是"全功能编辑器"，能改任何文件。给 SUID = 给 root 权限！  
任何用户执行 vim 都能改 `/etc/passwd`、`/etc/shadow`，**等于拿到 root**。

### Q6：su 和 sudo 区别？

**答**：
- **su**：需要 root 密码，无审计
- **sudo**：用自己的密码，有审计（`/var/log/secure`），可细粒度授权

**生产推荐 sudo**。

### Q7：`/etc/sudoers` 为什么必须用 visudo 编辑？

**答**：visudo 编辑后会**自动检查语法**，错了能恢复。直接 vim 改坏 = sudo 全挂。

### Q8：ACL 跟 UGO 什么关系？

**答**：
- ACL 是 UGO 的**扩展**（"额外名单"）
- 文件有 ACL 时，ls -l 末尾有 `+` 标记
- ACL 受 **mask** 限制（最大权限天花板）

---

## §22 链路

| 笔记 | 关系 |
|---|---|
| [[Linux目录/目录的权限]] | 已有 UGO/ACL/capability 强化版（精简）|
| [[LinuxShell/shell]] | shell 脚本里写用户管理脚本（useradd/usermod）|
| [[Linux文本处理/sed]] | 批量改 `/etc/passwd` 内容 |
| [[Linux文本处理/awk]] | 解析 passwd/group 文件 |
| [[Linux编辑器/vim]] | 用 vim 改配置 / visudo |
| [[LinuxShell/shell#§19 位置参数]] | $0/$@/$? 用法（脚本里写用户工具）|

### 完整 Linux 用户权限地图

```
                        ┌─ useradd/usermod/userdel
                        ├─ groupadd/groupmems
            用户和组 ───┤
                        ├─ /etc/passwd /etc/group
                        └─ /etc/login.defs /etc/skel

                        ┌─ chmod 字符法/数字法
                        ├─ chown/chgrp
            文件权限 ───┤
                        ├─ SUID/SGID/sticky
                        └─ ACL setfacl/getfacl

                        ┌─ su / su -
            提权 ───────┤
                        ├─ sudo / sudoers
                        └─ visudo / sudoers.d/

                        ┌─ umask（默认权限）
            其他 ───────┤
                        ├─ chattr（文件属性）
                        └─ id / who / w / users
```

**下一步**：进入 [[Linux包管理]]（PDF 06.1）或 [[Linux计划任务]]（PDF 06.2），继续第一波基础三件套。