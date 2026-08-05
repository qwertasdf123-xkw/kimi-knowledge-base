---
title: 华为 VRP — 网络设备的命令行操作系统
desc: 基于 04.网络技术基础-入门版.pdf PDF 02 网络初体验-华为 VRP 系统（约 30 页）整理。覆盖 VRP 介绍/eNSP 安装/Console 登录/命令行视图/4 级用户权限/命令格式（命令字-关键字-参数）/文件操作 12 命令/基础配置（sysname/接口/save/reboot）。
type: 笔记
module: 华为VRP
pdfs:
  - 04.网络技术基础-入门版.pdf（108 页，14.3 MB）
pdf_size: PDF 02 ≈ 30 页
scope: 华为 VRP 平台（路由器/交换机通用）
status: 完成
---

# 华为 VRP — 网络设备的命令行操作系统

> **范围**：基于《网络技术基础-入门版》PDF 第 02 章 整理（30 页）：
> - **VRP 介绍** — Versatile Routing Platform 是什么
> - **VRP 安装** — eNSP + WinPcap + Wireshark + VirtualBox
> - **VRP 配置方式** — Console + VTY + Web
> - **VRP 命令行** — 用户等级 + 命令格式 + 视图 + 功能键
> - **文件操作** — 12 个文件系统命令
> - **配置命令** — 基本配置 + 保存与启动
>
> **协议理论** 见：[[../网络基础原理/网络基础原理]]
> **路由与 VLAN** 见：[[../路由与VLAN/路由与VLAN]]
>
> **前置**：无（VRP 是华为设备的"最底层"，先学完这个再学路由/VLAN）

## 目录

- [[#§0 心智模型：VRP = 华为设备的 Windows]]
- [[#§1 VRP 介绍：通用路由平台]]
- [[#§2 VRP 安装环境：eNSP 仿真套件]]
- [[#§3 VRP 配置方式：Console / VTY / Web]]
- [[#§4 用户等级：4 级权限划分]]
- [[#§5 命令格式：命令字 + 关键字 + 参数]]
- [[#§6 命令行视图：用户 / 系统 / 接口 / 协议]]
- [[#§7 功能键：Tab / ?/ undo]]
- [[#§8 文件操作 12 命令]]
- [[#§9 基本配置命令]]
- [[#§10 配置保存与启动]]
- [[#§11 易错点 ×10]]
- [[#§12 速查表]]
- [[#§13 面试 6 大追问]]

---

## §0 心智模型：VRP = 华为设备的 Windows

把 VRP 想象成 **华为路由器/交换机的"操作系统"**：

| VRP 概念 | Windows 类比 | 实际 |
|---|---|---|
| VRP 平台 | Windows 操作系统 | 华为设备的操作系统层 |
| `system-view` | 进控制面板 | 进系统全局配置 |
| `interface GigabitEthernet 0/0/1` | 进"网络适配器属性" | 进某个接口配置 |
| `display this` | `ipconfig /all` | 看当前视图的配置 |
| `save` | "确认修改" | 保存配置到 flash |
| `reboot` | `restart` | 重启设备 |

### 核心洞察

> **"VRP 不是某个命令，而是一整套命令体系——所有华为路由器/交换机都用它"** —— VRP 是 §1-§10 的全部语境。

### VRP 设备全景

```
┌──────────────────────────────┐
│         华为 VRP 平台        │
│   (路由器 + 交换机 + 防火墙)  │
├──────────────────────────────┤
│  配置管理  |  路由管理        │
│  接口管理  |  安全管理        │
│  文件管理  |  系统管理        │
│  ......                     │
├──────────────────────────────┤
│           硬件层            │
└──────────────────────────────┘
```

---

## §1 VRP 介绍：通用路由平台（PDF 02）

### 1.1 VRP 是什么

> **"通用路由平台 VRP (Versatile Routing Platform) 是华为公司数据通信产品的通用操作系统平台。"**

**核心特点**：
- **统一**：所有华为数据通信产品用**同一个**操作系统
- **IP 业务为核心**：专注 IP 网络
- **组件化**：模块按需加载
- **可裁剪**：功能可少不可多（不同设备版本不同）
- **可扩展**：第三方能加新功能

### 1.2 VRP 提供 4 大功能

| 功能 | 含义 |
|---|---|
| **统一用户界面和管理界面** | 同一套命令管所有设备 |
| **控制平面功能 + 转发平面接口规范** | 软件控制 + 硬件转发的桥梁 |
| **产品转发平面与 VRP 控制平面的交互** | 不同设备有不同硬件，统一控制 |
| **屏蔽链路层差异** | 不同介质（以太网、光纤、串口）同一个管理方式 |

### 1.3 VRP 与 Cisco IOS 对照

| 厂商 | 平台 | 设备示例 |
|---|---|---|
| **华为** | VRP | NE / AR / S 系列（路由器交换机） |
| **思科** | IOS / IOS-XE / NX-OS | ISR / Catalyst 系列 |
| **华三** | Comware | H3C / HCL |
| **Juniper** | Junos | MX / EX 系列 |

> **命令风格**：华为像"日语"，Cisco 像"法语"，结构类似但表达不同。

### 1.4 VRP 设备典型型号

| 型号 | 用途 |
|---|---|
| **AR 系列路由器**（AR2240 等） | 企业级路由器 |
| **S 系列交换机**（S5700 / S6700） | 园区接入 / 汇聚 |
| **CE 系列** | 数据中心 |
| **NE 系列** | 运营商级骨干 |
| **USG 系列防火墙** | 安全网关 |

---

## §2 VRP 安装环境：eNSP 仿真套件（PDF 02）

### 2.1 eNSP 是什么

**eNSP（Enterprise Network Simulation Platform）** = 华为提供的**免费网络仿真软件**，可在 PC 上虚拟化整个企业网络。

### 2.2 eNSP 软件包清单

> **"按顺序安装软件包，不要升级软件。所有软件安装在默认位置。"**

| # | 软件 | 用途 |
|---|---|---|
| 1 | **Wireshark-win64-3.4.8.exe** | 抓包工具 |
| 2 | **WinPcap_4_1_3.exe** | 网络抓包驱动（Wireshark 依赖） |
| 3 | **VirtualBox-5.2.44** | 虚拟机引擎（eNSP 内部跑 AR / S 设备用） |
| 4 | **eNSP_Setup.exe** | 主程序 |

### 2.3 安装准备 3 步骤

1. **关闭第三方安全软件**（如火绒、360）：可能误杀 eNSP 进程
2. **关闭 Windows 防火墙**：阻止 eNSP 内部网络包
3. **关内核隔离**：4 个选项全关 + 内存完整性关闭 + 重启

### 2.4 安装后验证

```bash
# 在 VirtualBox 中应该能看到虚拟网卡
# 在 eNSP 中新建拓扑 → 加 2 个设备
#   ├─ AR2240（路由器）
#   └─ S5700（交换机）
# 启动设备 → 灯变亮蓝色 = 正常运行
```

### 2.5 常见安装问题

| 问题 | 解决方案 |
|---|---|
| WinPcap 安装提示"A newer version is installed" | 卸掉新版 WinPcap，装 4.1.3 |
| VirtualBox 报错（系统版本太新） | 关内核隔离 + 内存完整性 + 重启 |
| 注册表权限错误（CredentialGuard） | 改 `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard\Enabled` = 0 |

### 2.6 eNSP 设备类型

| 设备 | 用途 |
|---|---|
| AR2240 | 路由器 |
| S5700 / S6700 | 接入/汇聚交换机 |
| S12700 | 核心交换机 |
| AC | 无线控制器 |
| AP | 无线接入点 |
| PC | 终端 |
| Client | 模拟客户端 |

---

## §3 VRP 配置方式：Console / VTY / Web（PDF 02）

### 3.1 三大登录方式

| 方式 | 协议 | 用途 |
|---|---|---|
| **Console** | 串口 | 本地首次配置（必须从这开始） |
| **VTY**（Virtual Type Terminal） | Telnet / STelnet (SSH) | 远程登录 |
| **Web 网管** | HTTP / HTTPS | 图形化界面 |

### 3.2 Console 口配置

**流程**：
```
PC 串口（COM） ←→ 设备 Console 口  ←→  配置设备
                  ↑
                  串口线（华为一般配）
```

**PuTTY 设置**：
- 连接类型：**Serial**
- COM 端口：根据实际
- 速率：**9600**（固定）

### 3.3 VTY 配置（远程登录）

**VTY 用户界面**用来管理通过 VTY 方式登录的用户。

```
Telnet 客户端 ←→ Telnet 连接 ←→ 设备 VTY 通道 ←→ 配置
                       ↑
                  虚拟的
```

**配置 VTY 登录密码**：
```bash
[Huawei] user-interface vty 0 4        # 进入 VTY 0-4 共 5 个用户界面
[Huawei-ui-vty0-4] authentication-mode password
[Huawei-ui-vty0-4] set authentication password cipher Huawei@123
```

### 3.4 Web 网管

- HTTP：明文（不安全）
- HTTPS：加密（生产用）

> **实际**：Web 网管功能**有限**，大多数时候还是用命令行。

### 3.5 三种方式对比

| 维度 | Console | VTY (Telnet/SSH) | Web |
|---|---|---|---|
| **物理距离** | 必本地 | 远程 | 远程 |
| **协议** | 串口 | TCP/IP | TCP/IP |
| **安全** | 物理隔离 | SSH 加密 / Telnet 明文 | HTTPS / HTTP |
| **首次配置** | ✅ 唯一 | ❌ | ❌ |
| **批量化** | ❌ | ✅ | ❌ |

### 3.6 配置流程

```
首次配置设备流程：

1. 用串口线连 PC ↔ 设备 Console 口
   ↓
2. PuTTY 设 Serial / COM / 9600
   ↓
3. 进 Console → 默认用户视图 <Huawei>
   ↓
4. system-view → 配置 VTY/SSH
   ↓
5. 配 IP 地址到接口
   ↓
6. 从 PC SSH/Telnet 连 IP
   ↓
7. 远程配置所有后续
```

---

## §4 用户等级：4 级权限划分（PDF 02）

### 4.1 VRP 4 级权限

> **"VRP 提供基本的权限控制，可以实现不同级别的用户能够执行不同级别的命令"**

| 用户等级 | 命令等级 | 名称 | 能干啥 |
|---|---|---|---|
| **0** | 0 | **参观级** | 网络诊断工具（ping/tracert）+ 外部访问命令（telnet 客户端）+ 部分 display |
| **1** | 0 and 1 | **监控级** | 系统维护（更多 display） |
| **2** | 0,1,2 | **配置级** | 业务配置命令（路由、各层命令） |
| **3-15** | 0,1,2,3 | **管理级** | 业务**支撑**命令（文件系统/FTP/debug） |

### 4.2 默认用户等级映射

| 用户类型 | 默认级别 |
|---|---|
| 访客用户 | 0 |
| 监控用户 | 1 |
| 普通管理员 | 2 |
| 超级管理员 | 3+ |

### 4.3 切换用户

```bash
# 查看用户等级
[Huawei] display users

# 切换用户
<Huawei> super 3           # 临时升到 3 级（需密码）
<Huawei> super 2
```

### 4.4 4 个等级的关键差异

```
参观级（0）：ping 别人、从自己 ping 出
       ↓
监控级（1）：display 查看一切配置
       ↓
配置级（2）：能改配置（路由 / 接口 / VLAN）
       ↓
管理级（3+）：能改系统（文件系统 / 升级 / debug）
```

### 4.5 生产建议

| 角色 | 推荐等级 |
|---|---|
| 普通运维 | 1（监控） |
| 网络工程师 | 2（配置） |
| 高级工程师 | 3（管理） |
| 安全审计 | 1（只读） |

---

## §5 命令格式：命令字 + 关键字 + 参数（PDF 02）

### 5.1 命令的 3 大要素

> **"华为提供的命令按照一定的格式设计"**

| 要素 | 作用 | 示例 |
|---|---|---|
| **命令字** | 规定系统做什么 | `display`（查）/ `reboot`（重启） |
| **关键字** | 进一步约束命令 / 逻辑补充 | `ip` / `route-static` |
| **参数** | 进一步约束命令执行 | `192.168.1.0` / `255.255.255.0` |

### 5.2 命令格式示例

**示例 1**：`display ip interface GE0/0/0`
```
display       ← 命令字
   ip         ← 关键字
       interface   ← 参数名
              GE0/0/0   ← 参数值
```

**示例 2**：`reboot`（最简单）
```
reboot    ← 命令字（无关键字，无参数）
```

### 5.3 命令补全（4 个规则）

```
按 Tab：
  1. 匹配唯一 → 自动补全
  2. 匹配多个 → 循环显示所有匹配
  3. 不匹配   → 提示音 / 不变
  4. 错命令 + Tab → 提示"Error: Ambiguous"
```

### 5.4 ? 在线帮助

**完全帮助**：输入 `?` 显示当前位置所有可能命令。
**部分帮助**：输入 `d?` 显示所有 d 开头的命令。

```bash
<Huawei> d?
  debugging  <Group> debugging command group
  delete     Delete a file
  dialer     Dialer
  dir        List files on a filesystem
  display    Display information
```

### 5.5 关键快捷键

| 快捷键 | 作用 |
|---|---|
| `Backspace` | 删除光标前一个字符 |
| `←` / `Ctrl+B` | 光标左移一个字符 |
| `→` / `Ctrl+F` | 光标右移一个字符 |
| `↑` | 上一条历史命令 |
| `↓` | 下一条历史命令 |
| `Tab` | 补全命令 |
| `Ctrl+C` | 中断当前操作 |
| `Ctrl+Z` | 直接返回用户视图 |

### 5.6 undo 命令

**`undo` 在命令前** = 反向操作（恢复默认 / 禁用 / 删除）。

```bash
# 恢复默认值
[Huawei] undo sysname
[Huawei]                                    ← 主机名恢复 Huawei

# 禁用功能
[Huawei] undo ftp server

# 删除某项设置
[Huawei-GigabitEthernet0/0/1] undo ip address
# 等同删除该 IP
```

### 易错点

- ❌ `display ip route` 中 `route` 是关键字 → 实际是参数
- ❌ `undo` + 命令总能撤销 → 有些命令无 undo（如 reboot）
- ❌ Tab 永远补全 → **不匹配时**不变，会让人迷惑

---

## §6 命令行视图（PDF 02）

### 6.1 视图概念

> **"设备提供了多样的配置和查询命令，为便于用户使用这些命令，VRP 系统按功能分类将命令分别注册在不同的命令行视图下。"**

### 6.2 主要视图

| 视图 | 提示符 | 能干啥 |
|---|---|---|
| **用户视图** | `<Huawei>` | 查看运行状态、统计信息 |
| **系统视图** | `[Huawei]` | 配置系统参数 + 进入其他视图 |
| **接口视图** | `[Huawei-GigabitEthernet0/0/1]` | 配置接口参数 |
| **协议视图** | `[Huawei-ospf-1]` | 配置路由协议 |
| **区域视图** | `[Huawei-ospf-1-area-0.0.0.0]` | 配置 OSPF 区域 |

### 6.3 视图切换命令

| 操作 | 命令 |
|---|---|
| 用户 → 系统 | `system-view` (或 `sys`) |
| 系统 → 接口 | `interface GigabitEthernet 0/0/1` |
| 系统 → 协议 | `ospf 1` |
| 协议 → 区域 | `area 0` |
| 任意 → 用户 | `return`（一步）或 `quit`（逐级） |
| 任意 → 系统 | `quit` |

### 6.4 完整视图切换示例

```bash
<Huawei>
<Huawei> system-view                                    # 用户 → 系统
[Huawei]
[Huawei] interface GigabitEthernet 0/0/1                # 系统 → 接口
[Huawei-GigabitEthernet0/0/1]
[Huawei-GigabitEthernet0/0/1] ip address 192.168.1.1 24  # 配置 IP
[Huawei-GigabitEthernet0/0/1] quit                       # 接口 → 系统
[Huawei]
[Huawei] ospf 1                                          # 系统 → 协议
[Huawei-ospf-1]
[Huawei-ospf-1] area 0                                   # 协议 → 区域
[Huawei-ospf-1-area-0.0.0.0]
[Huawei-ospf-1-area-0.0.0.0] return                      # 直接回用户视图
<Huawei>
```

### 6.5 视图的层级关系

```
用户视图 <Huawei>
   ↑ return
   │ quit
区域视图 [Huawei-ospf-1-area-0.0.0.0]
   ↑
协议视图 [Huawei-ospf-1]
   ↑
接口视图 [Huawei-GigabitEthernet0/0/1]  （or 其他功能视图）
   ↑
系统视图 [Huawei]
```

### 6.6 视图与命令的关系

| 视图 | 有效命令示例 |
|---|---|
| 用户 | `display current-configuration` / `system-view` / `ping` / `reboot` |
| 系统 | `interface ...` / `ospf ...` / `sysname` / `display ip ...` |
| 接口 | `ip address` / `description` / `shutdown` / `undo shutdown` |
| 协议 | `area` / `network` / `default-route-advertise` |

> **经验**：在哪个视图就执行哪个视图的命令 —— 错视图看不见要执行的命令。

### 易错点

- ❌ `ip address` 在系统视图能配 → **不能**，要在接口视图
- ❌ `return` 和 `quit` 一样 → 不一样：`return` 直接回用户，`quit` 逐级回
- ❌ 视图切换会丢失配置 → 命令**会保留**，视图切换只是改"提示符"

---

## §7 功能键：Tab / ?/ undo（PDF 02）

### 7.1 三件套回顾

| 功能 | 作用 |
|---|---|
| **Tab** | 自动补全命令 |
| **?** | 在线帮助（完整或部分） |
| **undo 命令** | 反向操作 |

### 7.2 Tab 用法 4 规则

```
示例：info-center 命令
[Huawei] info-         ← 输入 info-，按 Tab
[Huawei] info-center   ← 自动补全（唯一匹配）

[Huawei] info-center log
   按 Tab → info-center logbuffer   ← 匹配多个，循环 1
   再 Tab → info-center logfile     ← 循环 2
   再 Tab → info-center loghost     ← 循环 3

[Huawei] info-center loglog    ← 错命令 + Tab，不变
```

### 7.3 ? 用法

```bash
<Huawei> ?
User view commands:
  arp-ping       ARP-ping
  autosave       <Group> autosave command group
  backup         Backup information
  cd             Change current directory
  clear          Clear
  clock          Specify the system clock
  ...

<Huawei> d?
  debugging  <Group> debugging command group
  delete     Delete a file
  dialer     Dialer
  dir        List files on a filesystem
  display    Display information
```

### 7.4 undo 的 4 种典型用法

```bash
# 1. 恢复默认值
[Huawei] sysname Server
[Server] undo sysname            # 恢复成 Huawei

# 2. 禁用某个功能
[Huawei] ftp server enable       # 启用
[Huawei] undo ftp server         # 禁用

# 3. 删除某项配置
[Huawei-GigabitEthernet0/0/1] ip address 192.168.1.1 24
[Huawei-GigabitEthernet0/0/1] undo ip address       # 删除该 IP

# 4. 批量恢复默认（系统视图）
[Huawei] undo info-center enable     # 关掉所有系统通知
```

### 7.5 undo 不能做的

| 命令 | 能否 undo |
|---|---|
| `reboot`（重启） | ❌ |
| `save`（保存） | ❌ |
| `reset saved-configuration`（清配置） | ❌ |
| `delete`（删文件） | ❌（但 undelete 可恢复，**除非** 清空了回收站） |
| `format`（格式化） | ❌ |
| `display`（查） | ❌（它是查询） |

---

## §8 文件操作 12 命令（PDF 02）

### 8.1 文件操作全景

| # | 命令 | 作用 |
|---|---|---|
| 1 | `pwd` | **查看当前位置**（print working directory） |
| 2 | `dir` | **显示当前目录的文件**清单 |
| 3 | `more` | **看文本文件内容** |
| 4 | `cd` | **切换目录** |
| 5 | `mkdir` | **创建新目录** |
| 6 | `rmdir` | **删除空目录** |
| 7 | `copy` | **复制文件** |
| 8 | `move` | **移动文件** |
| 9 | `rename` | **重命名文件** |
| 10 | `delete` | **删除文件**（进回收站） |
| 11 | `undelete` | **恢复删除**的文件 |
| 12 | `reset recycle-bin` | **彻底清空回收站** |

### 8.2 文件系统结构

```
flash:                                 ← 根目录（默认）
├── src/                               ← 目录（drw-）
├── pmdata/
├── dhcp/
│   └── dhcp-duid.txt                  ← 文件（-rw-）
├── private-data.txt
└── mplstpoam/
```

**属性含义**：
- `drw-` = directory readable/writable
- `-rw-` = file readable/writable

### 8.3 dir 输出详解

```bash
<Huawei> dir
Directory of flash:/
  Idx  Attr     Size(Byte)  Date       Time       FileName
    0  drw-              -  Aug 07 2015 13:51:14   src
    1  drw-              -  Jun 21 2024 14:41:16   pmdata
    2  drw-              -  Jun 21 2024 14:41:22   dhcp
    3  -rw-             28  Jun 21 2024 14:41:23   private-data.txt
    4  drw-              -  Jun 21 2024 14:56:28   mplstpoam
32,004 KB total (31,994 KB free)
```

| 字段 | 含义 |
|---|---|
| Idx | 索引 |
| Attr | 属性（d 目录，r 读，w 写） |
| Size | 大小（目录 - 文件 字节） |
| Date/Time | 修改时间 |
| FileName | 文件名 |
| `total / free` | 总容量 / 剩余容量 |

### 8.4 文件操作实战（华为命令）

```bash
<Huawei> pwd                                              # 看位置
flash:                                                    # 默在 flash:/

<Huawei> mkdir test                                        # 创建目录
Info: Create directory flash:/test......Done.

<Huawei> rmdir test                                       # 删空目录
Remove directory flash:/test?[Y/N]:Y

<Huawei> copy private-data.txt huawei.txt                  # 复制
Copy flash:/private-data.txt to flash:/huawei.txt?[Y/N]:Y

<Huawei> rename huawei.txt save.zip                        # 改名
Rename flash:/huawei.txt to flash:/save.zip ?[Y/N]:Y

<Huawei> copy private-data.txt flash:/dhcp/file.txt        # 复制到子目录
Copy flash:/private-data.txt to flash:/dhcp/file.txt?[Y/N]:Y

<Huawei> cd dhcp                                          # 进 dhcp 目录
<Huawei> dir                                              # 看当前目录

<Huawei> delete file.txt                                  # 删除（进回收站）
Delete flash:/dhcp/file.txt?[Y/N]:Y

<Huawei> undelete file.txt                                # 恢复
Undelete flash:/dhcp/file.txt?[Y/N]:Y

<Huawei> reset recycle-bin                                # 清空回收站
```

### 8.5 重要的坑：delete 是"软删除"

```
delete 文件：
  文件 → 回收站

reset recycle-bin：
  清空回收站 → 不可恢复
```

> **PDF 原话**："删除文件"（进回收站）和"彻底删除"（清空回收站）是 2 个步骤。

### 8.6 文件操作命令速查

```bash
# 查看类
pwd                      # 看当前位置
dir [/all]               # 看文件清单
more <file>              # 看文本内容
display saved-configuration    # 看已保存配置（VRP 专有）

# 操作类
mkdir <dir>              # 创建目录
rmdir <dir>              # 删目录（必须空）
cd <dir>                 # 切换目录
copy <src> <dst>         # 复制
move <src> <dst>         # 移动
rename <src> <new>       # 改名
delete <file>            # 删文件（进回收站）
undelete <file>          # 恢复
reset recycle-bin        # 清回收站
```

---

## §9 基本配置命令（PDF 02）

### 9.1 配置设备名称

```bash
<Huawei> system-view
[Huawei] sysname Datacom-Router                # 改名为 Datacom-Router
[Datacom-Router]
[Datacom-Router] undo sysname                  # 还原为 Huawei
[Huawei]
```

### 9.2 关闭信息中心通知（避免刷屏）

```bash
[Datacom-Router] undo info-center enable
# 关闭系统通知消息（防止调试中一直刷屏）
```

### 9.3 设置 Console 口超时

```bash
[Datacom-Router] user-interface console 0
[Datacom-Router-ui-console0] idle-timeout 60    # 60 分钟无操作自动登出
[Datacom-Router-ui-console0] quit
```

> **为什么改超时**：默认 10 分钟，调成 60 分钟适合调试。

### 9.4 接口配置 IP

```bash
[Datacom-Router] interface GigabitEthernet 0/0/1
[Datacom-Router-GigabitEthernet0/0/1] ip address 192.168.1.1 24
[Datacom-Router-GigabitEthernet0/0/1] quit
```

### 9.5 查看当前视图配置

```bash
[Datacom-Router-GigabitEthernet0/0/1] display this
#
interface GigabitEthernet0/0/1
 ip address 192.168.1.1 255.255.255.0
#
return
```

### 9.6 取消接口配置

```bash
[Datacom-Router] interface GigabitEthernet 0/0/1
[Datacom-Router-GigabitEthernet0/0/1] undo ip address    # 删 IP
[Datacom-Router-GigabitEthernet0/0/1] quit
```

### 9.7 查看设备当前配置

```bash
[Datacom-Router] display current-configuration
# 输出整个设备的当前运行配置
```

### 9.8 Console 口登录密码 3 种认证方式

> **"通过 Console 口登录路由器时，认证方式主要有以下 3 种"** —— PDF 原话

| 认证方式 | 安全性 | 用法 |
|---|---|---|
| **无认证**（None） | ❌ 低 | 仅测试环境 |
| **密码认证**（Password） | ⚠️ 中 | 只需密码 |
| **AAA 认证** | ✅ 高 | 需用户名 + 密码，生产环境 |

### 9.9 配置 Console 密码认证

```bash
<Huawei> system-view
[Huawei] user-interface console 0
[Huawei-ui-console0] authentication-mode password
[Huawei-ui-console0] set authentication password cipher Huawei@123
[Huawei-ui-console0] quit
```

> **`cipher` 关键词**：密文显示（更安全）；如果用 `simple` 是明文（能看到密码）。

### 9.10 实用命令一览

| 命令 | 作用 |
|---|---|
| `sysname 名称` | 改设备名 |
| `undo info-center enable` | 关闭系统通知 |
| `user-interface console 0` | 进 Console 配置视图 |
| `idle-timeout 分钟` | 设置超时 |
| `authentication-mode password` | 密码认证模式 |
| `set authentication password cipher 密码` | 设密文密码 |
| `interface 接口` | 进接口视图 |
| `ip address IP 掩码` | 配 IP |
| `shutdown` / `undo shutdown` | 关/开接口 |
| `description 描述` | 给接口加描述 |
| `display this` | 看当前视图配置 |
| `display current-configuration` | 看全部当前配置 |

---

## §10 配置保存与启动（PDF 02）

### 10.1 配置的"两态"

| 状态 | 含义 |
|---|---|
| **当前配置**（current-configuration） | 内存里正在运行的配置 |
| **下次启动配置**（saved-configuration / startup） | flash 里保存的下次启动用的配置 |

**核心原则**：改完配置要 `save`，否则重启会丢失！

### 10.2 save 命令

```bash
<Huawei> save
  The current configuration will be written to the device.
  Are you sure to continue? (y/n)[n]: y
  It will take several minutes to save configuration file, please wait.......
  Configuration file had been saved successfully
  Note: The configuration file will take effect after being activated
<Huawei>
```

**保存到哪里**：默认到 `flash:/vrpcfg.zip`（华为的加密配置文件）。

### 10.3 配置相关 13 个命令

| # | 命令 | 作用 |
|---|---|---|
| 1 | `display current-configuration` | 查看当前配置 |
| 2 | `display saved-configuration` | 查看保存的配置 |
| 3 | `display this` | 看当前视图的配置 |
| 4 | `compare configuration` | 比较当前与启动配置 |
| 5 | `save` | 保存配置 |
| 6 | `reset saved-configuration` | 清除已保存的配置 |
| 7 | `display startup` | 看启动配置参数 |
| 8 | `startup saved-configuration configuration-file` | 设置下次启动用的配置 |
| 9 | `reboot` | 重启设备 |

### 10.4 9 个常用命令完整版（PDF 汇总）

| # | 命令 | 作用 |
|---|---|---|
| 1 | `display saved-configuration` | 查看保存配置 |
| 2 | `reset saved-configuration` | 清除保存配置 |
| 3 | `display startup` | 查看启动参数 |
| 4 | `startup saved-configuration configuration-file X` | 设置启动配置 |
| 5 | `reboot` | 重启 |

### 10.5 比对当前与启动配置

```bash
<Huawei> compare configuration
 The current configuration is the same as the next startup configuration file.
<Huawei>

# 输出 "is different as" 时说明还没 save
```

### 10.6 完整的基本配置示例（PDF 原版）

```bash
# 1. 进系统视图
<Huawei> system-view
Enter system view, return user view with Ctrl+Z.

# 2. 改设备名
[Huawei] sysname Datacom-Router

# 3. 关闭系统通知
[Datacom-Router] undo info-center enable

# 4. 设置 Console 口超时 60 分钟
[Datacom-Router] user-interface console 0
[Datacom-Router-ui-console0] idle-timeout 60
[Datacom-Router-ui-console0] quit

# 5. 配接口 IP
[Datacom-Router] interface GigabitEthernet 0/0/1
[Datacom-Router-GigabitEthernet0/0/1] ip address 192.168.1.1 24

# 6. 看当前视图
[Datacom-Router-GigabitEthernet0/0/1] display this
#
interface GigabitEthernet0/0/1
 ip address 192.168.1.1 255.255.255.0
#
return

# 7. 取消接口配置
[Datacom-Router-GigabitEthernet0/0/1] undo ip address
[Datacom-Router-GigabitEthernet0/0/1] quit

# 8. 重配 G0/0/2
[Datacom-Router] interface GigabitEthernet 0/0/2
[Datacom-Router-GigabitEthernet0/0/2] ip address 192.168.1.1 24
[Datacom-Router-GigabitEthernet0/0/2] quit

# 9. 看全部当前配置
[Datacom-Router] display current-configuration

# 10. 返回用户视图
[Datacom-Router] quit

# 11. 保存配置
<Datacom-Router> save
  The current configuration will be written to the device.
  Are you sure to continue? (y/n)[n]: y
  ...
  Configuration file had been saved successfully

# 12. 比对当前与启动
<Datacom-Router> compare configuration
 The current configuration is the same as the next startup configuration file.
```

### 10.7 ⚠️ 重要：修改配置后必须 save

| 场景 | 是否自动生效 | 是否需要 save |
|---|---|---|
| 修改 IP | **立即生效** | ✅ 建议 save |
| 配置路由 | **立即生效** | ✅ 建议 save |
| 改 sysname | **立即生效** | ✅ 建议 save |
| `shutdown` 接口 | **立即生效**（接口 down） | ✅ 建议 save |
| **重启设备** | 走 saved 配置 | **必须** save |

### 10.8 排查流程：配置改完不通

```
改了配置，不通？
  ↓
save 了没？ → 没：save 后再测
  ↓
重启了没？ → 没：可能未完全生效，reboot
  ↓
display this 看当前视图配置
  ↓
display current-configuration 看全部
  ↓
compare configuration 比对当前 vs 启动
  ↓
找差异 → 改对 → save → reboot
```

---

## §11 易错点 ×10

1. **忘记 `save` 导致重启丢配置** → 改动**只在内存**，重启恢复
2. **`undo` 跟配置命令后所有内容** → 比如 `undo ip address 192.168.1.1 24` 会报错，应只 `undo ip address`
3. **Tab 总是补全** → 不匹配时**不变**，可能掩盖错命令
4. **`dir` 把文件显示多少就多少** → 实际可能含 `.bak` 等隐藏
5. **`delete` 是真删** → **不是**真删，进回收站（undelete 可恢复）
6. **VRP 用户等级 0 是最高** → **0 是最低**
7. **`quit` 和 `return` 一样** → 不一样（quit 逐级，return 直接回用户）
8. **`display this` 在任何视图能用** → 是的，无论用户/系统/接口/协议
9. **Console 改密码不需要重启** → 真的不需要
10. **保存失败没报错** → 看 VRP 提示，可能 flash 满或文件保护

---

## §12 速查表

### VRP 视图速查

| 视图 | 提示符 | 进入命令 |
|---|---|---|
| 用户视图 | `<Huawei>` | 默认 |
| 系统视图 | `[Huawei]` | `system-view` |
| 接口视图 | `[Huawei-GigabitEthernet0/0/1]` | `interface 接口` |
| 协议视图 | `[Huawei-ospf-1]` | `ospf 1` |
| 区域视图 | `[Huawei-ospf-1-area-0.0.0.0]` | `area 0` |

### 命令三要素

| 要素 | 作用 |
|---|---|
| 命令字 | 规定动作（display/reboot） |
| 关键字 | 进一步约束（ip/route） |
| 参数 | 具体值（IP/掩码） |

### 用户等级速查

| 等级 | 名称 | 能干啥 |
|---|---|---|
| 0 | 参观 | ping/tracert + display |
| 1 | 监控 | 全部 display |
| 2 | 配置 | 业务配置命令 |
| 3-15 | 管理 | 文件/FTP/debug |

### 12 个文件命令速查

| 命令 | 作用 |
|---|---|
| `pwd` | 看当前位置 |
| `dir` | 看文件清单 |
| `more file` | 看文件内容 |
| `cd dir` | 切目录 |
| `mkdir` / `rmdir` | 建/删目录 |
| `copy` / `move` | 复制/移动 |
| `rename` | 改名 |
| `delete` / `undelete` | 删/恢复 |
| `reset recycle-bin` | 清回收站 |

### 配置保存速查

| 命令 | 作用 |
|---|---|
| `save` | 保存到 flash |
| `display saved-configuration` | 看保存配置 |
| `display current-configuration` | 看当前配置 |
| `reset saved-configuration` | 清保存配置 |
| `display startup` | 看启动参数 |
| `startup saved-configuration X` | 设置启动配置 |
| `reboot` | 重启 |
| `compare configuration` | 对比当前 vs 启动 |

### Console 登录速查

```bash
user-interface console 0
authentication-mode password
set authentication password cipher 密码
idle-timeout 60
```

### undo 命令速查

```bash
undo sysname            # 还原默认名
undo info-center enable # 关闭通知
undo ftp server         # 关闭 FTP
undo ip address         # 删 IP（接口视图下）
undo shutdown           # 启用接口
```

### VTY 远程登录速查

```bash
[Huawei] user-interface vty 0 4
[Huawei-ui-vty0-4] authentication-mode password
[Huawei-ui-vty0-4] set authentication password cipher 密码
[Huawei-ui-vty0-4] protocol inbound ssh    # 限制 SSH
```

---

## §13 面试 6 大追问

> 学完后能回答这 6 个问题，说明 VRP 命令行掌握扎实。

1. **VRP 是什么？和 Cisco IOS 是什么关系？**
   - **VRP = Versatile Routing Platform**，是华为的通用路由平台
   - Cisco **IOS** 是思科的等价物
   - 都是命令行操作系统，**语法相近但不通用**

2. **VRP 4 级用户权限对应什么？**
   - **0 参观**（ping/tracert + display）
   - **1 监控**（全部 display）
   - **2 配置**（业务命令）
   - **3-15 管理**（系统/FTP/debug）

3. **VRP 命令格式是什么？3 大要素？**
   - **命令字**（action）+ **关键字**（进一步约束）+ **参数**（具体值）
   - 例：`display ip interface GE0/0/0`

4. **`quit` vs `return` 区别？**
   - `quit` **逐级退回**（接口 → 系统 → 用户）
   - `return` **直接回用户视图**（任意视图 → 用户）

5. **`delete` 和 `reset recycle-bin` 的关系？**
   - `delete` 把文件**移到回收站**（可恢复）
   - `reset recycle-bin` **彻底清空回收站**（不可恢复）

6. **改了配置后，重启前一定要做什么？**
   - **save**！否则重启会丢配置
   - `save` 把"当前配置"写到 flash 的"启动配置"
   - `compare configuration` 可验证

---

## 📎 跨模块链接

- **[[../网络基础原理/网络基础原理]]** — OSI/TCP-IP/MAC/IP 协议理论
- **[[../路由与VLAN/路由与VLAN]]** — 用 VRP 配置路由 + VLAN + 三层交换
- **[[../Linux网络/Linux网络]]** — Linux 单机命令实操

## 📦 镜像

- `E:\notes\华为VRP.md`（同步备份）