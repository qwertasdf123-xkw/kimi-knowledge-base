---
title: Shell 变量篇实战练习 — 12 道
desc: 在 VMware /mnt/hgfs/Linux/ 共享文件夹里实操。覆盖 var/${}/export/PATH/PS1/HISTTIMEFORMAT/profile/命令替换/算术/引号。
type: 练习
module: LinuxShell
level: 简单 → 中等 → 进阶 → 综合
---

# Shell 变量篇实战练习 — 12 道

> **目标**：把 [[shell#§0 心智模型|变量篇]] 13 节核心概念在 VMware 真实环境里跑一遍。
>
> **环境**：CentOS-7 / bash 4.2 + VMware 共享文件夹 `/mnt/hgfs/Linux/`（Windows 端是 `E:\Linux\`）。
>
> **建议节奏**：每天 3 道，4 天做完。每道题先**自己写一遍**再看答案。

## 使用说明

1. **新建练习目录**：`cd /mnt/hgfs/Linux && mkdir -p shell_practice && cd shell_practice`
2. **每题 3 步**：
   - 自己写命令
   - 跑一遍验证
   - 对照答案
3. **可选**：把每题的脚本保存到 `shell_practice/`，形成可复用的"小工具库"

---

## 第 1 题 ⭐ 变量三连（基础）

**场景**：在共享文件夹里建一个测试文件，给路径赋给变量，最后清掉。

**任务**：
1. 创建一个文件 `/mnt/hgfs/Linux/shell_practice/secret.txt`
2. 把完整路径赋给变量 `filepath`
3. `echo` 显示 `filepath` 的值
4. 用 `set | grep filepath` 查看
5. `unset filepath` 删除
6. 再 `echo $filepath` 验证（应该是空行）

**预期输出**（步骤 3）：
```
/mnt/hgfs/Linux/shell_practice/secret.txt
```

<details>
<summary>💡 参考答案</summary>

```bash
cd /mnt/hgfs/Linux && mkdir -p shell_practice && cd shell_practice

# 1) 建文件
touch secret.txt

# 2) 赋值
filepath=/mnt/hgfs/Linux/shell_practice/secret.txt

# 3) 显示
echo $filepath

# 4) 查 set
set | grep filepath

# 5) 删除
unset filepath

# 6) 验证
echo "filepath 现在是: '$filepath'"
# 输出: filepath 现在是: ''（空字符串）
```
</details>

---

## 第 2 题 ⭐ 变量拼接的歧义陷阱

**场景**：演示 `${}` 框定变量名的重要性。

**任务**：
1. 设置 `lang=bash` 和 `version=5`
2. 不用 `${}` 拼接：尝试 `echo $lang$version` 和 `echo $lang_$version`，**记录两次输出**
3. 用 `${}` 修正：实现 `bash_5` 这样的输出

**预期输出**：
```bash
$ echo $lang_$version
5              # ⚠️ 只输出了 version
$ echo ${lang}_${version}
bash_5         # ✓ 正确
```

<details>
<summary>💡 参考答案</summary>

```bash
lang=bash
version=5

# 错误示范
echo $lang$version        # bash5（碰巧对，因为后面跟的是 $version）
echo $lang_$version       # 5（找 lang_ 不存在，输出空，只剩 $version）

# 正确示范
echo ${lang}_${version}   # bash_5
```

**核心点**：`_` 既是合法变量名字符，也是"连接符"——不加 `${}` 时 Shell 优先把它当成变量名的一部分。
</details>

---

## 第 3 题 ⭐⭐ 本地变量 vs 环境变量

**场景**：理解为什么子 Shell 看不到父 Shell 的本地变量。

**任务**：
1. 在当前 Shell 设 `localvar=parent_value`（不 export）
2. `bash` 进入子 Shell
3. `echo $localvar` 看子 Shell 能不能看到
4. `exit` 退到父 Shell
5. 这次先 `export envvar=parent_value` 再 `bash` 进入
6. 验证子 Shell 能看到

**预期输出**：
```bash
# 步骤 3：空（子 Shell 看不到）
# 步骤 6：parent_value
```

<details>
<summary>💡 参考答案</summary>

```bash
# 演示本地变量不继承
localvar=parent_value
bash                                  # 进子 Shell
echo "子 Shell 看到的 localvar: $localvar"  # 空！
exit                                  # 退回父 Shell

# 演示 export 后的继承
export envvar=parent_value
bash
echo "子 Shell 看到的 envvar: $envvar"   # parent_value
exit
```

**核心点**：`export` 把本地变量"提升"为环境变量，子进程才能继承。
</details>

---

## 第 4 题 ⭐⭐ PATH 改坏的 3 种救法

**场景**：故意改坏 PATH，然后分别用 3 种方法救回来。

**任务**：
1. 把 `/usr/bin/ls` 移到当前目录（`./ls`）
2. 直接输 `ls` 看会怎样（应报 `command not found`）
3. 救法 1：用相对路径 `./ls`
4. 救法 2：临时加 PATH `export PATH=$PATH:$(pwd)`，再 `ls`
5. 救法 3：用绝对路径 `/bin/cp ./ls /usr/bin/ls` 还原
6. 验证 `ls` 恢复正常

**预期输出**：
```bash
# 步骤 2：
bash: ls: command not found...

# 步骤 4（加 PATH 后）：
anaconda-ks.cfg initial-setup-ks.cfg ls secret.txt   # 当前目录文件

# 步骤 6：
(恢复正常)
```

<details>
<summary>💡 参考答案</summary>

```bash
# 警告：以下命令在生产环境不要做！这里是练习

# 1) 搬走 ls
sudo cp /usr/bin/ls ./ls              # 备份到当前目录（先 cp 防止真丢）
sudo mv /usr/bin/ls /usr/bin/ls.bak   # 改名模拟"丢失"

# 2) 直接 ls 失败
ls
# bash: ls: command not found...

# 3) 救法 1：相对路径
./ls -l

# 4) 救法 2：加 PATH
export PATH=$PATH:$(pwd)              # 把当前目录加到 PATH 末尾
ls

# 5) 救法 3：绝对路径还原
sudo /bin/cp $(pwd)/ls /usr/bin/ls

# 6) 验证
ls

# 清理
sudo rm /usr/bin/ls.bak
```

**核心点**：
- 救法 1（相对路径）：最干净
- 救法 2（改 PATH）：临时救急用，记得退出 Shell 失效
- 救法 3（绝对路径）：最稳，连 PATH 坏了都能用
</details>

---

## 第 5 题 ⭐⭐ 命令替换生成带时间戳的文件

**场景**：运维里常见"日志归档"，需要带日期的文件名。

**任务**：
1. 用 `$(date +%Y%m%d)` 生成 `app-20250709.log` 这样的文件名
2. 创建该文件
3. `ls` 查看
4. 加时间戳：`backup-20250709_143022.tar.gz`
5. 用反引号 `` `date +%Y%m%d` `` 写一遍，看输出是否一样

**预期输出**：
```bash
$ ls
app-20250709.log  backup-20250709_143022.tar.gz
```

<details>
<summary>💡 参考答案</summary>

```bash
# 1-3) 日期 + 创建
today=$(date +%Y%m%d)
filename=app-${today}.log
touch "$filename"
ls

# 4) 加时间
now=$(date +%Y%m%d_%H%M%S)
backup=backup-${now}.tar.gz
touch "$backup"
ls

# 5) 反引号
oldstyle=app-`date +%Y%m%d`.log
echo $oldstyle
# 输出: app-20250709.log
```

**核心点**：`$(cmd)` 和 `` `cmd` `` 结果一样，但 `$()` 可嵌套、可读性高。
</details>

---

## 第 6 题 ⭐⭐⭐ 自定义彩色 PS1

**场景**：把默认 PS1 改成带时间 + 颜色的提示符。

**任务**：
1. 查看当前 `PS1` 值：`echo $PS1`
2. 改成：`[\u@\h \W \t]\$ `（加时间）
3. 验证：在提示符里能看到 `13:52:08`
4. 加颜色：`\[\e[92;1m\]\u\[\e[0m\]@\[\e[91m\]\h\[\e[0m\]:\[\e[94m\]\W\[\e[0m\]\$ `
5. 永久生效：写入 `~/.bashrc` 末尾

**预期输出**：
```bash
# 步骤 3：
[xkw@centos7 ~ 13:52:08]$

# 步骤 4（用户绿粗、@红、:蓝、目录蓝）：
xkw@centos7:~$                ← 有颜色，但终端无法显示
```

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 看默认
echo $PS1
# [\u@\h \W]\$

# 2) 加时间
PS1='[\u@\h \W \t]\$ '

# 3) 验证
# 提示符立刻变成 [xkw@centos7 ~ 13:52:08]$

# 4) 加颜色
PS1='\[\e[92;1m\]\u\[\e[0m\]@\[\e[91m\]\h\[\e[0m\]:\[\e[94m\]\W\[\e[0m\]\$ '

# 5) 永久
echo "PS1='\[\e[92;1m\]\u\[\e[0m\]@\[\e[91m\]\h\[\e[0m\]:\[\e[94m\]\W\[\e[0m\]\$ '" >> ~/.bashrc
source ~/.bashrc
```

**核心点**：
- 颜色必须 `\[\e[...m\]` 包裹，否则命令行长度算错
- `source ~/.bashrc` 让修改立即生效（否则要重开 Shell）
- 改坏恢复：`export PS1='[\u@\h \W]\$ '`
</details>

---

## 第 7 题 ⭐⭐⭐ HISTTIMEFORMAT + 永久化

**场景**：让 `history` 显示时间戳，并保存为永久配置。

**任务**：
1. `history | head -5` 看默认（无时间）
2. `export HISTTIMEFORMAT="%F %T "`
3. 再次 `history | head -5` 看到时间戳
4. 尝试格式 `%m-%d %H:%M`（短时间）
5. 永久化：写入 `~/.bashrc` 并 `source`

**预期输出**：
```bash
# 步骤 3：
   12  2025-07-09 13:50:23 ls
   13  2025-07-09 13:50:30 cd /tmp
   ...

# 步骤 4：
   12  07-09 13:50 ls
```

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 默认
history | head -5
# 12  ls
# 13  cd /tmp

# 2) 启用
export HISTTIMEFORMAT="%F %T "

# 3) 验证
history | head -5
# 12  2025-07-09 13:50:23 ls

# 4) 短格式
export HISTTIMEFORMAT="%m-%d %H:%M "
history | head -5
# 12  07-09 13:50 ls

# 5) 永久
echo 'export HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
source ~/.bashrc

# 验证：重开一个新 Shell
bash
history | head -3
# 应该依然有时间戳
```

**核心点**：临时 `export` 关闭 Shell 就丢，必须 `echo ... >> ~/.bashrc`。
</details>

---

## 第 8 题 ⭐⭐⭐ profile 加载顺序验证

**场景**：用 `echo` 写到不同文件，看新开 Shell 时哪个被加载。

**任务**：
1. 在 `~/.bashrc` 末尾加：`echo "我来自 ~/.bashrc" >> /tmp/load_log`
2. 在 `/etc/bashrc` 末尾加（需要 sudo）：`echo "我来自 /etc/bashrc" >> /tmp/load_log`
3. 清空 `/tmp/load_log`
4. `bash` 进入新 Shell，然后 `exit`
5. `cat /tmp/load_log` 看加载顺序

**预期输出**：
```bash
# 步骤 5：
我来自 ~/.bashrc
我来自 /etc/bashrc
```

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 用户级
echo 'echo "我来自 ~/.bashrc" >> /tmp/load_log' >> ~/.bashrc

# 2) 系统级
sudo bash -c 'echo "我来自 /etc/bashrc" >> /tmp/load_log' >> /etc/bashrc

# 3) 清空
> /tmp/load_log

# 4) 测试 nologin shell
bash
exit

# 5) 看结果
cat /tmp/load_log
# 我来自 ~/.bashrc
# 我来自 /etc/bashrc
```

**核心点**：
- `nologin shell`（`bash` 命令进入）只读 `~/.bashrc` → `/etc/bashrc`
- `login shell`（SSH 登录）读 `/etc/profile` → `~/.bash_profile` → `~/.bashrc` → `/etc/bashrc`
- 验证完记得**清理**（删 `~/.bashrc` 和 `/etc/bashrc` 末尾的两行），不然每次开 Shell 都刷一条
</details>

---

## 第 9 题 ⭐⭐⭐ 多行 echo + 重定向

**场景**：把多行配置写到一个新文件。

**任务**：
1. 用 `echo "..."` 一次写一个 3 行的 `info.txt`：
   ```
   === System Info ===
   Hostname: $(hostname)
   Date: $(date)
   ```
2. `cat info.txt` 验证
3. 加上 `>>`（追加），再加一段：
   ```
   === User ===
   Current: $(whoami)
   ```
4. 验证最终文件

**预期输出**（步骤 4）：
```
=== System Info ===
Hostname: centos7
Date: 2025年 07月 09日 星期三 14:30:22 CST
=== User ===
Current: root
```

<details>
<summary>💡 参考答案</summary>

```bash
cd /mnt/hgfs/Linux/shell_practice

# 1) 写入多行（注意双引号包住）
echo "=== System Info ===
Hostname: $(hostname)
Date: $(date)" > info.txt

# 2) 验证
cat info.txt

# 3) 追加
echo "=== User ===
Current: $(whoami)" >> info.txt

# 4) 完整
cat info.txt
```

**核心点**：
- `>` 覆盖（危险！），`>>` 追加（安全）
- 多行靠**双引号**包住，按回车不结束
- 危险：生产配置别用 `echo >`，用 `>>` 或 `cat << EOF`（见编程篇 §18）
</details>

---

## 第 10 题 ⭐⭐⭐ 算术 + 命令替换组合

**场景**：算 1+2+...+100 = 5050，并嵌入到消息里。

**任务**：
1. 用 `$(( $(echo {1..100} | tr ' ' '+') ))` 求 1+2+...+100
2. 嵌入到消息：`"1+2+...+100 = 5050"`
3. 算一个表达式：`(123 + 456) * 2 / 3`（浮点保留 2 位，用 awk）
4. 把第 3 步的结果写进文件 `math.txt`

**预期输出**：
```bash
# 步骤 1：
5050

# 步骤 3：
393.00
```

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 求和
echo $(( $(echo {1..100} | tr ' ' '+') ))
# 5050

# 2) 嵌入消息
result=$(( $(echo {1..100} | tr ' ' '+') ))
echo "1+2+...+100 = $result"

# 3) 浮点（用 awk）
awk_result=$(awk 'BEGIN{printf "%.2f", (123+456)*2/3}')
echo "结果: $awk_result"
# 结果: 393.00

# 4) 写文件
echo "1+2+...+100 = $result" > math.txt
echo "(123+456)*2/3 = $awk_result" >> math.txt
cat math.txt
```

**核心点**：
- 整数用 `$(( ))`，浮点必须用 `awk` 或 `bc`
- `printf "%.2f"` 控制小数位
- `tr ' ' '+'` 把空格替换成 + 号，配合 `$(( ))` 求和
</details>

---

## 第 11 题 ⭐⭐⭐⭐ 引号三连（弱/强/无）

**场景**：在同一个表达式里演示 `"` `'` 和裸字符串的区别。

**任务**：
1. 设 `name="Alice"`
2. 三种 `echo`：
   - `echo Hello $name, today is $(date +%A)`
   - `echo "Hello $name, today is $(date +%A)"`
   - `echo 'Hello $name, today is $(date +%A)'`
3. 记录三个输出
4. 加 `\` 转义：演示 `echo "Price: \$5"` 输出 `Price: $5`

**预期输出**（步骤 2 的三个）：
```bash
Hello Alice, today is 星期三
Hello Alice, today is 星期三
Hello $name, today is $(date +%A)         # ⚠️ 单引号原样
```

<details>
<summary>💡 参考答案</summary>

```bash
name="Alice"

# 1) 裸字符串
echo Hello $name, today is $(date +%A)

# 2) 双引号（弱引用，变量和命令替换展开）
echo "Hello $name, today is $(date +%A)"

# 3) 单引号（强引用，全部原样）
echo 'Hello $name, today is $(date +%A)'

# 4) 转义
echo "Price: \$5"
# Price: $5
```

**核心点**：
- 裸 vs `"..."` 一般一样（除非变量值含空格/通配符）
- `'...'` 内的 `$` `(` `\` 全失效
- `"..."` 里 `\$` 才能让 `$` 字面输出
</details>

---

## 第 12 题 ⭐⭐⭐⭐⭐ 综合：环境变量改造 PATH

**场景**：把一个"工具目录"加入 PATH，让里面的脚本能直接调用。

**任务**：
1. 在 `/mnt/hgfs/Linux/shell_practice/myscripts/` 建一个 `greet.sh`：
   ```bash
   #!/bin/bash
   echo "Hello, $USER! Today is $(date +%F)."
   ```
2. `chmod +x greet.sh`
3. 临时把目录加到 PATH：`export PATH=$PATH:/mnt/hgfs/Linux/shell_practice/myscripts`
4. 直接输 `greet.sh` 看能不能跑（应该能）
5. 验证 `which greet.sh` 显示完整路径
6. 写一个聚合脚本 `setup.sh` 自动做 2-4 步
7. 永久化：写入 `~/.bashrc`

**预期输出**：
```bash
# 步骤 4：
Hello, root! Today is 2025-07-09.
```

<details>
<summary>💡 参考答案</summary>

```bash
cd /mnt/hgfs/Linux/shell_practice
mkdir -p myscripts
cd myscripts

# 1) 写脚本
cat > greet.sh << 'EOF'
#!/bin/bash
echo "Hello, $USER! Today is $(date +%F)."
EOF

# 2) 加权限
chmod +x greet.sh

# 3) 加 PATH
export PATH=$PATH:/mnt/hgfs/Linux/shell_practice/myscripts

# 4) 直接调用（不带路径！）
greet.sh
# 输出：Hello, root! Today is 2025-07-09.

# 5) which 验证
which greet.sh
# /mnt/hgfs/Linux/shell_practice/myscripts/greet.sh

# 6) 写 setup.sh
cd /mnt/hgfs/Linux/shell_practice
cat > setup.sh << 'EOF'
#!/bin/bash
SCRIPTS_DIR="/mnt/hgfs/Linux/shell_practice/myscripts"
if [[ ":$PATH:" != *":$SCRIPTS_DIR:"* ]]; then
    export PATH=$PATH:$SCRIPTS_DIR
    echo "✓ 已添加 $SCRIPTS_DIR 到 PATH"
else
    echo "✓ $SCRIPTS_DIR 已在 PATH 中"
fi
EOF
chmod +x setup.sh
./setup.sh

# 7) 永久化
echo "export PATH=\$PATH:/mnt/hgfs/Linux/shell_practice/myscripts" >> ~/.bashrc
source ~/.bashrc
```

**核心点**：
- `:`$PATH:` 加首尾冒号才能用 `*:$DIR:*` 检查
- `source setup.sh` 在当前 Shell 生效（区别于 `bash setup.sh`）
- 生产路径别用 `/tmp` 或当前目录（安全风险）
</details>

---

## 进阶挑战（可选）

### 挑战 1 ⭐⭐⭐⭐⭐ PATH 安全性

**任务**：演示为什么不能把 `.` 加到 PATH。

```bash
export PATH=.:$PATH
# 假设黑客在 /tmp 放个 ls，你 cd /tmp 后输 ls：
# 跑的是 /tmp/ls，不是 /bin/ls

# 验证：
cd /tmp
echo '#!/bin/bash' > ls
echo 'echo "我是假 ls, 我能干啥都行"' >> ls
chmod +x ls
ls
# 输出: 我是假 ls...

# 清理
cd / && rm /tmp/ls
```

### 挑战 2 ⭐⭐⭐⭐⭐ PS1 颜色错位

**任务**：故意写错 PS1（颜色不加 `\[\]`），看命令行怎么乱。

```bash
# 错的：
PS1='\e[32m$ \e[0m'                # 没 \[\] 包裹
# 现象：输入长命令后，按退格删除，光标位置错乱

# 对的：
PS1='\[\e[32m\]$ \[\e[0m\]'
```

### 挑战 3 ⭐⭐⭐⭐⭐ 多变量联动

**任务**：写一个 `~/.bashrc` 自定义配置，让：
- `LL='ls -lah'` 别名
- `GREP='grep --color=auto'` 别名
- 时间戳 history
- 简洁的彩色 PS1

```bash
cat >> ~/.bashrc << 'EOF'

# === my custom config ===
alias LL='ls -lah'
alias GREP='grep --color=auto'
alias ll='ls -l --color=auto'
export HISTTIMEFORMAT="%F %T "
export PS1='[\[\e[92;1m\]\u\[\e[0m\]@\[\e[91m\]\h\[\e[0m\] \[\e[94m\]\W\[\e[0m\] \t]\$ '
EOF

source ~/.bashrc
```

---

## 完成情况自查

| # | 主题 | 难度 | 做了吗 |
|---|---|---|---|
| 1 | 变量三连 | ⭐ | ☐ |
| 2 | ${} 拼接 | ⭐ | ☐ |
| 3 | 本地 vs 环境 | ⭐⭐ | ☐ |
| 4 | PATH 改坏 | ⭐⭐ | ☐ |
| 5 | 时间戳文件 | ⭐⭐ | ☐ |
| 6 | 彩色 PS1 | ⭐⭐⭐ | ☐ |
| 7 | HISTTIMEFORMAT | ⭐⭐⭐ | ☐ |
| 8 | profile 加载 | ⭐⭐⭐ | ☐ |
| 9 | 多行 echo | ⭐⭐⭐ | ☐ |
| 10 | 算术 + 替换 | ⭐⭐⭐ | ☐ |
| 11 | 引号三连 | ⭐⭐⭐⭐ | ☐ |
| 12 | PATH 改造 | ⭐⭐⭐⭐⭐ | ☐ |

**做完后回到 [[shell]] 复习，或进入 [[shell#编程篇（基于 09.shell编程实战 系列 PDF）|编程篇]] 开始写真正的 Shell 脚本。**
