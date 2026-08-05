# Linux sed 命令（面试强化版）

> 本文系统讲解 Linux **sed**（stream editor）—— 非交互式流编辑器。sed 是 **grep 之后的"加工车间"**：grep 筛出来，sed 改内容。
>
> **核心定位**：sed 做的是 **行级别的批量转换**——替换、删除、插入、打印、改行号……所有"不改写整文件、但要改行内容"的活都是它。
>
> **链路呼应**：
> - → [[regex|正则表达式]]：sed 默认 BRE，`-E` 用 ERE；`s/pattern/replacement/` 是核心
> - → [[输入输出重定向]]：sed 默认输出到 stdout（不修改文件），`-i` 才真正修改
> - → [[grep]]：grep 找行 → sed 改行（黄金组合）
> - → [[linux文件查询]]：`find -exec sed -i` 批量改文件名/内容
> - → [[Linux目录导航]]：用 sed 改 .bashrc / .profile 等配置
> - → [[Linux vfs虚拟文件系统|VFS]]：`/proc/$$/fd/` 里也有 sed 可改的虚拟文件
> - → [[目录的权限]]：`-i` 改文件需要写权限
>
> 备注：编写时网络访问受限，所有结论以本地 `man sed` 语义为准。

---

## §0. 心智模型：sed = 自动盖章机

> 想理解 sed，请先在脑子里装一台"流水线盖章机"。

| 比喻 | sed 对应 | 说明 |
|---|---|---|
| **传送带** | **输入流**（stdin 或文件） | 一行一行送进来 |
| **盖章/划掉/重写区** | **脚本（pattern + command）** | 决定每一行怎么变 |
| **盖章机** | **sed 进程** | 逐行处理 |
| **传送带末端** | **stdout**（默认输出） | 处理后的结果输出 |
| **`-n` 开关** | **静音模式** | 不输出未处理的行（只输出 p 命令指定的） |
| **`-i` 开关** | **原地盖章** | 不输出，直接把盖章结果写回原文件 |
| **`-e 'cmd1' -e 'cmd2'`** | **多道工序** | 一行经过多个盖章机 |
| **`-f script.sed`** | **外部工序卡** | 从文件读 sed 脚本 |
| **`s/old/new/`** | **替换印章** | 把每行的 old 换成 new |
| **`/pattern/d`** | **划掉操作** | 匹配的行删除（不出传送带） |

> **核心口诀**：**sed = "stream editor"**——"流编辑器"。它**逐行**处理，**默认不修改原文件**（输出到 stdout），要原地改用 `-i`。

### 为什么 sed 是个值得理解透的命令？

- 批量修改配置、代码、日志的**首选工具**——比 `vim` 改 100 个文件快一万倍。
- 流水线中的"加工厂"角色——`grep` 找 → `sed` 改 → `awk` 切。
- 正则表达式的"真正舞台"——grep 只用它**匹配**，sed 用它**匹配 + 替换**。
- 写脚本的基础设施——shell 脚本里 80% 的文本处理都靠 sed。

---

## §1. sed 基础语法

### 1.1 调用方式

```bash
# 方式 1：行内脚本（最常用）
sed [OPTIONS] 'script' [FILE...]

# 方式 2：从文件读脚本
sed [OPTIONS] -f script.sed [FILE...]

# 方式 3：管道输入
cmd | sed [OPTIONS] 'script'

# 方式 4：多脚本
sed [OPTIONS] -e 'script1' -e 'script2' file
```

### 1.2 脚本结构：`地址 + 命令`

sed 的每个指令 = **地址（address）** + **命令（command）**：

```
[ADDR]CMD
```

| 部分 | 作用 | 可选？ |
|---|---|---|
| **地址** | 决定哪些行被处理 | ✅（默认 = 所有行） |
| **命令** | 对匹配行做什么 | ❌（必填） |

```bash
sed 's/old/new/' file           # 所有行的 old → new（无地址 = 全部）
sed '5s/old/new/' file          # 只第 5 行
sed '/error/d' file             # 含 "error" 的行删除
sed '5,10d' file                # 第 5-10 行删除
```

### 1.3 默认行为 vs `-n`

```bash
# 默认：输出每一行（不管改没改）
echo -e "hello\nworld" | sed 's/h/H/'
# 输出：
# Hello
# world

# -n 静默：不自动输出，只输出 p 命令指定的
echo -e "hello\nworld" | sed -n 's/h/H/p'
# 输出：
# Hello
# （world 不输出，因为它没匹配 p）
```

**关键洞察**：`-n` + `p` 是经典组合——只输出"匹配 + 修改"的行。

---

## §2. 地址（Address）详解

### 2.1 地址的五种形式

| 形式 | 语法 | 含义 | 示例 |
|---|---|---|---|
| **无地址** | `CMD` | 所有行 | `sed 's/a/b/' file` |
| **行号** | `N` | 第 N 行 | `sed '5d' file` |
| **行号范围** | `N,M` | 第 N 到 M 行 | `sed '5,10d' file` |
| **正则地址** | `/pat/` | 匹配 pat 的行 | `sed '/error/d' file` |
| **正则范围** | `/pat1/,/pat2/` | 从匹配 pat1 开始到 pat2 结束 | `sed '/start/,/end/d' file` |

### 2.2 特殊行号

| 符号 | 含义 |
|---|---|
| `$` | 最后一行 |
| `0` | 文档开头（一般写 `1`） |
| `first~step` | 从 first 开始每隔 step 行（如 `1~2` = 奇数行） |

```bash
sed '$d' file               # 删最后一行
sed '1~2d' file             # 删奇数行
sed '0~2d' file             # 删偶数行（同 1~2 但从第 0 行开始）
sed '2~3d' file             # 删 2, 5, 8, 11... 行
```

### 2.3 实战：地址组合

```bash
# 删除所有空行和注释行
sed '/^$/d; /^#/d' file

# 删除第 1-3 行和最后一行
sed '1,3d; $d' file

# 在含 "ERROR" 的行**前面**插入一行
sed '/ERROR/i\# ERROR FOUND' file

# 在含 "ERROR" 的行**后面**插入一行
sed '/ERROR/a\# see above' file

# 把所有含 "TODO" 的行整行替换为 "DONE"
sed '/TODO/c\DONE' file
```

### 2.4 反向地址 `!`

```bash
# 所有不含 "error" 的行替换
sed '/error/!s/foo/bar/' file

# 第 5 行以外都替换
sed '5!s/foo/bar/' file
```

---

## §3. 核心命令速查

### 3.1 必背 12 个命令

| 命令 | 全称 | 作用 | 示例 |
|---|---|---|---|
| `s/regex/repl/flags` | substitute | 替换 | `s/old/new/g` |
| `d` | delete | 删除（不输出） | `/^$/d` |
| `p` | print | 打印（重复输出） | `/error/p` |
| `i\text` | insert | 在匹配行**前**插入 | `i\inserted line` |
| `a\text` | append | 在匹配行**后**追加 | `a\appended line` |
| `c\text` | change | 整行替换 | `c\replaced line` |
| `y/src/dst/` | transliterate | 字符一一映射 | `y/abc/xyz/` |
| `q` | quit | 退出（不读剩余行） | `/error/q` |
| `n` | next | 读下一行（跳过当前） | `n; p` |
| `N` | Next | 读下一行追加到模式空间 | 多行处理 |
| `=` | line number | 打印行号 | `sed '=' file` |
| `l` | list | 显式不可见字符 | `l` |

### 3.2 `s`（替换）的 6 个 flag

| Flag | 含义 | 默认行为 | 加 flag 后 |
|---|---|---|---|
| `g` | global（行内所有匹配） | 只换第一个 | 换所有 |
| `N` | 第 N 个匹配（1-based） | — | 只换第 N 个 |
| `p` | print（输出被改的行） | 不输出 | 输出修改行 |
| `i` | ignore case（GNU 扩展） | 区分大小写 | 不区分 |
| `e` | execute（执行替换结果） | 不执行 | 把匹配当作命令执行 |
| `w file` | write（写入文件） | 不写 | 把修改的行写 file |

```bash
# 默认：每行只换第一个
echo "aaa" | sed 's/a/X/'
# 输出：Xaa

# 加 g：每行换所有
echo "aaa" | sed 's/a/X/g'
# 输出：XXX

# 加 2：换第 2 个
echo "aaa" | sed 's/a/X/2'
# 输出：aXa

# 加 p + -n：只输出被改的行（greplike）
sed -n 's/error/ERROR/p' file

# 加 i：忽略大小写（GNU）
sed 's/error/ERROR/gi' file

# 加 e：把匹配当命令执行
echo "ls" | sed 's/ls/ls -l/e'
# 实际执行 ls -l
```

### 3.3 实战命令组合

```bash
# 替换 + 打印 + 删除 三连
sed -n 's/old/new/gp' file             # 只输出改过的行
sed '/^#/d; /^$/d' file                # 去注释和空行
sed '5,10!d' file                      # 只保留 5-10 行

# 多次替换
sed -e 's/a/A/' -e 's/b/B/' file       # a→A，b→B

# 等价写法
sed 's/a/A/; s/b/B/' file              # 用 ; 分隔

# 用花括号分组
sed '/start/,/end/{ s/^/|/; s/$/|/ }' file
```

---

## §4. 替换（s）的精髓

### 4.1 分隔符：可以用任何字符

```bash
# 默认用 / —— 但路径里也含 / 时会冲突
sed 's|/usr/bin|/usr/local/bin|' file      # 用 | 作分隔符

# 用 @ 作分隔符
sed 's@/usr/bin@/usr/local/bin@' file

# 用 # 作分隔符（脚本里常用）
sed 's#/usr/bin#/usr/local/bin#' file
```

### 4.2 `&` = 整个匹配

```bash
# 给匹配项加引号
sed 's/word/"&"/' file
# hello word → hello "word"

# 包裹匹配项为 HTML <b>
sed 's/error/<b>&<\/b>/' file
```

### 4.3 反向引用 `\1 \2 ...`

```bash
# 交换两个字段
echo "hello world" | sed 's/\(\w*\) \(\w*\)/\2 \1/'
# 输出：world hello

# 把 firstname lastname → lastname, firstname
sed -E 's/(\w+) (\w+)/\2, \1/' file

# 在 ERE 模式下分组不需要转义括号
sed -E 's/(\w+) (\w+)/\2 \1/' file
```

### 4.4 实战正则替换

```bash
# 匹配 IP 地址并加方括号
sed -E 's/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/[\1]/' file

# 删行首数字编号
sed 's/^[0-9]*\. //' file
# "1. apple" → "apple"

# 删 HTML 标签
sed -E 's/<[^>]+>//g' file
# "<b>hello</b>" → "hello"

# 转换日期格式 YYYY-MM-DD → DD/MM/YYYY
sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/' file

# 把 TAB 替换为逗号
sed 's/\t/,/g' file
```

---

## §5. 模式空间 & 保持空间（进阶）

### 5.1 概念

| 空间 | 作用 | 类比 |
|---|---|---|
| **模式空间（pattern space）** | sed 当前正在处理的"工作台" | 桌面上正在看的文件 |
| **保持空间（hold space）** | 暂存区，可以"夹在腋下" | 抽屉里临时放的东西 |

### 5.2 空间操作命令

| 命令 | 作用 |
|---|---|
| `h` | 模式空间 → 保持空间（覆盖） |
| `H` | 模式空间 → 保持空间（追加） |
| `g` | 保持空间 → 模式空间（覆盖） |
| `G` | 保持空间 → 模式空间（追加） |
| `x` | 交换两个空间 |

### 5.3 经典案例：合并两行为一行

```bash
# 把每两行合并为一行（用 ; 分隔）
sed 'N; s/\n/; /' file

# 把每两行合并为一行（用 TAB）
sed 'N; s/\n/\t/' file
```

### 5.4 经典案例：打印最后一行前插入空行

```bash
# 反向：用 x 翻转 + G 追加
sed -n '1!G; h; $p' file
# 这段代码把每行倒序累积
```

---

## §6. 实战场景（10 大经典）

### 场景 1：批量替换文件内容

```bash
# 改单个文件
sed -i 's/old/new/g' file.txt

# 改多个文件
sed -i 's/old/new/g' *.txt

# 递归改（find + sed）
find . -name "*.py" -exec sed -i 's/version = "1.0"/version = "2.0"/g' {} +
```

### 场景 2：删除文件中的空行/注释

```bash
# 去空行
sed '/^$/d' file

# 去注释行（# 开头）
sed '/^#/d' file

# 同时去空行和注释
sed '/^$/d; /^#/d' file

# 保留注释但删空行
sed '/^$/d' config
```

### 场景 3：行首/行尾添加内容

```bash
# 每行行首加 "> "
sed 's/^/> /' file

# 每行行尾加 " <<"
sed 's/$/ <</' file

# 给每行加行号
sed '=' file | sed 'N; s/\n/: /'
# 输出：
# 1: line1
# 2: line2
```

### 场景 4：提取特定行

```bash
# 提取第 5-10 行
sed -n '5,10p' file

# 提取含 "ERROR" 的行
sed -n '/ERROR/p' file

# 提取最后一行
sed -n '$p' file

# 提取每 3 行（1, 4, 7...）
sed -n '1~3p' file
```

### 场景 5：CSV / 配置文件的字段处理

```bash
# 改 CSV 的第 3 列为大写
sed -E 's/^([^,]+),([^,]+),(.*)/\1,\2,\U\3/' file
# 注意：\U 是 GNU 扩展

# 把 key=value 格式的 value 加引号
sed -E 's/^(.*)=(.*)$/\1="\2"/' file
# "name=value" → "name=\"value\""

# 把每行倒序
sed -n '1!G; h; $p' file
```

### 场景 6：替换文件中的路径

```bash
# 把所有 /old/path 改成 /new/path
sed -i 's|/old/path|/new/path|g' *.conf

# 把所有相对路径改成绝对
sed -i 's|./config|/etc/myapp/config|g' app.conf
```

### 场景 7：和 grep 联动

```bash
# 先 grep 找行，再 sed 改
grep "ERROR" app.log | sed 's/.*ERROR/ERROR/'

# 等价：sed 自己就能做（更高效）
sed -n '/ERROR/{ s/.*ERROR/ERROR/; p }' app.log

# 只改含 ERROR 的行
sed '/ERROR/s/old/new/g' file
```

### 场景 8：改文件名（不是内容）

```bash
# 把所有 .txt 改成 .md（rename 命令）
ls *.txt | sed 's/\(.*\)\.txt/mv & \1.md/' | sh

# 等价直接用 rename
rename 's/\.txt$/.md/' *.txt
```

### 场景 9：日志清理

```bash
# 删除前 N 行（如前 100 行头注释）
sed '1,100d' app.log

# 只保留前 N 行
sed '101,$d' app.log

# 删除含特定关键字的行
sed '/DEBUG/d' app.log

# 保留含 ERROR 或 WARN 的行
sed -n '/ERROR\|WARN/p' app.log
```

### 场景 10：配置 / 代码批量重构

```bash
# 把所有 print("...") 改成 logger.info("...")
find . -name "*.py" -exec sed -i 's/print(/logger.info(/g' {} +

# 加 license header 到所有 .py
sed -i '1i\# Copyright 2026' *.py

# 把所有函数改名（rename in all files）
sed -i 's/\boldFunc\b/newFunc/g' *.c
# \b 是词边界，避免误改 oldFunc2
```

---

## §7. sed 与 grep / awk 的分工

### 7.1 三大文本工具的"角色"

| 工具 | 角色 | 输入 | 输出 | 是否修改文件 |
|---|---|---|---|---|
| **`grep`** | 筛选器 | 多行/文件 | 匹配的行 | ❌ |
| **`sed`** | 转换器 | 多行 | 修改后的行 | ❌（默认），✅（-i） |
| **`awk`** | 切片器 | 多行 | 按字段重组 | ❌ |

### 7.2 黄金管道

```bash
# 经典三件套：找 → 改 → 切
grep "ERROR" app.log | sed 's/.*ERROR //' | awk '{print $1}'

# 拆分：
# 1) grep 找出所有 ERROR 行
# 2) sed 把 "ERROR xxx" 改成 "xxx"
# 3) awk 切第一列
```

### 7.3 何时用 sed vs awk

| 场景 | 用 sed | 用 awk |
|---|---|---|
| 简单替换 | ✅ | 杀鸡用牛刀 |
| 按字段处理 | 复杂 | ✅ 简单 |
| 数学计算 | 难 | ✅ 内置数学 |
| 简单行过滤 | ✅ | ✅ |
| 状态机/累加 | 复杂 | ✅ |
| 改文件本身 | ✅（-i） | 复杂 |

---

## §8. 高级用法

### 8.1 `sed -i` 的备份选项

```bash
# 直接改文件（不备份）
sed -i 's/old/new/g' file

# 改文件 + 备份原文件（推荐）
sed -i.bak 's/old/new/g' file         # 备份到 file.bak

# 自定义备份后缀
sed -i'.bak' 's/old/new/g' file       # 同上
sed -i'_orig' 's/old/new/g' file      # 备份到 file_orig
```

> **BSD sed vs GNU sed**：macOS 的 `sed -i` 必须指定备份后缀（不能空），GNU 随意。

### 8.2 sed 脚本文件

```bash
# 把脚本写到文件
cat > script.sed << 'EOF'
# 这是一个 sed 脚本
/^$/d
s/old/new/g
/pattern/i\
# inserted line
EOF

# 调用
sed -f script.sed file
```

### 8.3 多行处理（N 命令）

```bash
# 把连续多行合并成一行
sed ':a; N; $!ba; s/\n//g' file       # 经典模式

# 解释：
# :a - 标签
# N - 读下一行追加到模式空间
# $!ba - 不是最后一行就跳回 :a
# s/\n//g - 把所有换行去掉
```

### 8.4 分支与条件（b / t）

```bash
# 替换后跳转到标签
sed 's/old/new/; t end; s/missed/X/; :end' file

# 实战：只在替换成功的行做后续处理
sed 's/foo/bar/; t skip; d; :skip' file
# 如果 foo 替换成功就跳 :skip，否则删除
```

### 8.5 行号与 `=` `F`

```bash
# 打印行号
sed '=' file                          # 行号独立成行

# 打印文件名（F 命令）
sed 'F' file                          # 每行前加文件名

# 配合 -n 只输出文件名
sed -n 'F' file
```

---

## §9. 易错点 ×15

1. **`sed 's/old/new/'` 默认只换第一个匹配** —— 要换所有必须加 `g`：`sed 's/old/new/g'`。
2. **`sed` 默认输出所有行** —— 想只输出改过的加 `-n` + `p`：`sed -n 's/x/y/p'`。
3. **`sed -i` 在 macOS/BSD 必须带备份后缀** —— `sed -i '' 's/x/y/' file`（空字符串表示不备份）。
4. **`/pattern/` 是正则** —— `sed '/./d'` 删所有非空行（. 匹配任意字符）。
5. **正则里的 `|` 要转义** —— `sed '/a\|b/d'`（BRE），`sed -E '/a|b/d'`（ERE）。
6. **替换分隔符冲突** —— 内容含 `/` 时换分隔符：`sed 's|/a/b|/x/y|'`。
7. **`s/old/new/` 里的 `&` 是匹配本身** —— 加 `\1 \2` 才能反向引用。
8. **`a\` `i\` `c\` 后必须有反斜杠**（GNU 允许不带） —— `sed 'a\text'` 才正确。
9. **`N` 命令** —— 不是 `n`，大写 N = Next（合并下一行），小写 n = next（跳过当前）。
10. **`y/` 命令不支持正则** —— `y/abc/xyz/` 是字符一一映射，不是字符串。
11. **`sed '5d'`** 删的是**第 5 行**，不是"含 5 的行"。后者是 `sed '/5/d'`。
12. **`!` 反转地址** —— `5!d` 是"第 5 行以外都删"，不是"删第 5 行"。
13. **地址范围 `5,10`** —— 含 5 和 10，**包含两端**。
14. **`q` 命令让 sed 立即退出** —— 之后的行不会被读，适合"找到第一个就停"。
15. **GNU sed 的 `\d \w` 不被识别** —— 用 `[[:digit:]]` `[[:alnum:]]` 替代。

---

## §10. 面试 10 大追问

### Q1：`sed` 默认修改文件吗？

**答案**：**不修改**。sed 默认输出到 stdout，原文件不变。
- `sed 's/old/new/' file` → stdout 输出修改后内容，file 不变
- `sed -i 's/old/new/' file` → **原地修改** file

**加分话术**：
> "面试陷阱：很多新手以为 `sed 's/old/new/' file` 改了文件，其实没有——要看不到修改还以为 sed '不工作'。要原地改必须 `-i`。生产环境强烈建议 `-i.bak` 先备份。"

### Q2：`sed 's/old/new/g'` 和 `sed 's/old/new/'` 区别？

**答案**：
- `s/old/new/`：每行**只换第一个**匹配
- `s/old/new/g`：每行**换所有**匹配

**加分话术**：
> "面试常考：'把每行的所有 foo 改成 bar'——答案是加 `g`。还有 `s/old/new/2` 是换第 2 个，`s/old/new/2g` 是从第 2 个开始全换。"

### Q3：`sed -i` 在 macOS 和 Linux 上行为一样吗？

**答案**：**不一样**。
- GNU sed（Linux）：`-i` 直接修改，不备份
- BSD sed（macOS）：`-i` 必须带参数，`-i ''` 表示不备份

```bash
# Linux
sed -i 's/old/new/' file

# macOS（必须带空字符串）
sed -i '' 's/old/new/' file

# 跨平台写法
sed -i.bak 's/old/new/' file       # 都兼容
```

**加分话术**：
> "写跨平台 shell 脚本时**永远用 `-i.bak`**，最稳。注意 `.bak` 是参数的一部分，不是文件后缀拼接——备份文件名是 `file.bak`。"

### Q4：`sed` 怎么实现"多行替换"？

**答案**：用 `N` 命令把多行合并到模式空间，再处理。

```bash
# 经典：合并连续行为一行
sed ':a; N; $!ba; s/\n//g' file

# 解释：
# :a - 标签
# N - 读下一行，追加到模式空间（中间用 \n 分隔）
# $!ba - 不是最后一行就跳回 :a
# s/\n//g - 把所有换行去掉
```

**加分话术**：
> "sed 默认是行处理——一次处理一行。多行要靠 `N` 命令（Next 大写）把多行粘到模式空间。`n` 小写是 skip 当前行，区别很大。"

### Q5：`sed` 的 `s/old/new/` 里的 `&` 和 `\1` 区别？

**答案**：
- `&`：**整个匹配**的字符串
- `\1 \2 ...`：**第 1 个、第 2 个分组**（用 `()` 包围的）

```bash
echo "hello world" | sed 's/\w+/[&]/'
# 输出：[hello] [world]
# & 是 "hello"、"world" 各自

echo "hello world" | sed -E 's/(\w+) (\w+)/\2 \1/'
# 输出：world hello
# \1 = "hello"，\2 = "world"
```

**加分话术**：
> "`&` 在所有 sed 版本都支持；`\1` 在 BRE 里要 `\( \)`，ERE 里 `()` 直接写。日常用 `sed -E` 加 `()` 不用反斜杠。"

### Q6：`grep` 和 `sed` 在管道里怎么配合？

**答案**：

```bash
# 先 grep 筛选，再 sed 处理
grep "ERROR" app.log | sed 's/.*ERROR //; s/:.*//'

# 等价（sed 自带地址过滤，更高效）
sed -n '/ERROR/s/.*ERROR //p' app.log

# 区别：
# 前者：grep 先读全部，再传 sed
# 后者：sed 自己读，只处理匹配的行（少一次 pipe）
```

**加分话术**：
> "性能上 `sed -n '/pat/p'` ≈ `grep pat`，但 `sed` 多一步可以做修改。如果 grep + sed 链用得对，'sed 自带过滤'在内存上更省。但现代管道都很快，可读性更重要。"

### Q7：`sed` 的 `q` 命令有什么用？

**答案**：让 sed **立即退出**，不读剩余行。常用于"找到第一个就停"。

```bash
# 找到第一个 ERROR 就退出
sed '/ERROR/{ s/.*/!!! ERROR FOUND !!!/; p; q }' app.log

# 提取前 10 行后退出
sed '10q' file
# 等价 head -n 10
```

**加分话术**：
> "`q` 性能优化神器——大文件查第一个匹配用它能快 1000 倍。`grep -m 1` 类似。两者原理都是读到第一个匹配就退出循环。"

### Q8：`sed` 的模式空间和保持空间？

**答案**：
- **模式空间（pattern space）**：sed 当前正在处理的"工作台"，一行进来在这里加工
- **保持空间（hold space）**：暂存区，可以"夹在腋下"跨行传递

| 命令 | 作用 |
|---|---|
| `h` | 模式 → 保持（覆盖） |
| `H` | 模式 → 保持（追加） |
| `g` | 保持 → 模式（覆盖） |
| `G` | 保持 → 模式（追加） |
| `x` | 交换两个空间 |

**加分话术**：
> "这两个空间是 sed '有状态'处理的基础——但日常 90% 用不到。需要多行/反转/分组聚合时才上 hold space。面试不会深挖，但能说出来是加分项。"

### Q9：`sed` 怎么替换换行符 / 多行字符串？

**答案**：

```bash
# 1) 在替换字符串里插入换行（用 \n，GNU）
sed 's/abc/xyz\n&/' file

# 2) 删换行符（多行合并）
sed ':a; N; $!ba; s/\n//g' file

# 3) 把换行符替换成其他字符
sed ':a; N; $!ba; s/\n/; /g' file

# 4) 在每个换行后插入一行
sed 's/$/\nINSERTED/g' file
```

**加分话术**：
> "GNU sed 的 `\n` 在替换部分有效（BSD 不行）。要严格跨平台用 `:a; N; $!ba; s/\n/X/g` 这种循环结构。"

### Q10：`sed` 在大文件（10GB+）上怎么优化？

**答案**：

```bash
# 1) 找到就退出（不读完）
sed '/ERROR/q' 10gb.log

# 2) 限制处理行数
sed '1000000q' 10gb.log              # 只处理前 100 万行

# 3) 用 sed 自带的流式特性（不需要全读入内存）
#    sed 本身就是流式处理，不会 OOM

# 4) 并行（GNU parallel）
parallel -j 8 "sed 's/old/new/g' {}" ::: chunk_*.log

# 5) 直接 awk / Python（更复杂的场景）
```

**加分话术**：
> "sed 是流式处理——理论上 O(1) 内存，无论文件多大都不会 OOM。所以大文件用 sed 反而比 Python 安全（Python 习惯 readlines 会爆内存）。"

---

## §11. 速查清单（cheat sheet）

### 11.1 一行模式（one-liner）

```bash
# 替换文件内容
sed -i 's/old/new/g' file

# 批量替换（递归）
find . -name "*.py" -exec sed -i 's/version = "1"/version = "2"/g' {} +

# 删除空行和注释
sed '/^$/d; /^#/d' file

# 加行号
sed '=' file | sed 'N; s/\n/: /'

# 每行加前缀
sed 's/^/[INFO] /' file

# 删除前 N 行
sed '1,100d' file

# 提取含 pattern 的行（grep 等价）
sed -n '/pattern/p' file

# 倒序每行字符
sed 's/\(.\)/\1 /g' file | rev | sed 's/ //g'

# JSON 缩进（用 sed 实现简单版）
sed -E 's/^( *)"(.*)":/\1\2:/' file
```

### 11.2 命令速记

| 我想... | 用... |
|---|---|
| 替换文本 | `s/old/new/flags` |
| 删行 | `d` |
| 打印（多次输出） | `p` |
| 行前插入 | `i\text` |
| 行后追加 | `a\text` |
| 整行替换 | `c\text` |
| 字符一一映射 | `y/src/dst/` |
| 退出 | `q` |
| 跳过当前读下 N 行 | `n`（小写） |
| 追加下一行到模式空间 | `N`（大写） |
| 打印行号 | `=` |
| 显式不可见字符 | `l` |

### 11.3 地址速记

| 我想处理... | 用... |
|---|---|
| 所有行 | （不写地址） |
| 第 N 行 | `N` |
| 第 N 到 M 行 | `N,M` |
| 含 pattern 的行 | `/pattern/` |
| 从 pat1 到 pat2 | `/pat1/,/pat2/` |
| 最后一行 | `$` |
| 奇数行 | `1~2` |
| 偶数行 | `2~2` |
| 不含 pattern 的行 | `/pattern/!` 或 `!` |
| 第 N 行以外 | `N!` |

### 11.4 替换 flag 速记

| flag | 含义 |
|---|---|
| `g` | 全局（行内所有） |
| `N` | 第 N 个匹配 |
| `p` | 输出被改的行 |
| `i` | 忽略大小写（GNU） |
| `e` | 执行替换结果（GNU） |
| `w file` | 写入文件 |

---

## §12. 与其他笔记的链路

| 主题 | 链接 | 关联点 |
|---|---|---|
| **输入输出重定向** | [[输入输出重定向]] | sed 默认输出到 stdout（不修改文件） |
| **grep** | [[grep]] | grep 找行 → sed 改行（黄金组合） |
| **linux文件查询** | [[linux文件查询]] | `find -exec sed -i` 批量改 |
| **目录的权限** | [[目录的权限]] | `-i` 改文件需要写权限 |
| **VFS** | [[Linux vfs虚拟文件系统]] | `/proc/` 下的虚拟文件可 sed |
| **目录导航** | [[Linux目录导航]] | 改 .bashrc / .profile 等配置 |
| **获取帮助** | [[linux获取帮助]] | `man sed`、`info sed` |

---

## §13. 进一步阅读（权威参考）

### 13.1 man 手册（必看）

- `man 1 sed` —— sed 命令完整手册
- `man 1p sed` —— POSIX 标准 sed
- `man 7 regex` —— 正则规范
- `man 1 awk` —— 配合 sed 的下一步工具
- `man 1 grep` —— 上一步过滤器

### 13.2 在线资源

- **GNU sed 官方**：https://www.gnu.org/software/sed/manual/sed.html
- **POSIX sed 标准**：https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sed.html
- **sed 教程**：https://www.grymoire.com/Unix/sed.html（最经典）
- **sed one-liners**：https://github.com/adambard/learnxinyminutes-docs

### 13.3 推荐书

- **《sed & awk》**（Dale Dougherty, Arnold Robbins）—— sed + awk 圣经
- **《Classic Shell Scripting》** —— 第 5 章"文本处理"
- **《Mastering Regular Expressions》**（Jeffrey Friedl）—— 正则在 sed 里的应用

---

> 复习建议：
> 1. **§0 盖章机比喻** + **§1 脚本结构（地址+命令）** 是基础；
> 2. **§3 必背 12 命令** + **§4 替换精髓** 是核心，背熟；
> 3. **§6 实战 10 场景** 至少跑通 5 个（批量替换最常用）；
> 4. **§9 易错点 15 条** 重点是 `-i` 在 macOS 行为不同、`g` 默认不加只换第一个；
> 5. **§10 面试 10 问** Q1/Q2/Q3/Q9 是高频考点；
> 6. 在大代码库跑一次 `find . -name "*.py" -exec sed -i 's/foo/bar/g' {} +`，体验"批处理"的威力；
> 7. **下一步**：学 `awk`（字段切片）—— 完成"过滤器 → 编辑器 → 切片器"三件套。