---
title: 正则表达式速查（BRE / ERE / PCRE）
desc: 集中所有正则元字符、字符类、量词、锚点、反向引用。覆盖三剑客 grep/sed/awk 共用的正则语法。
type: 笔记
module: Linux文本处理
pdf: 01. Linux 正则表达式.pdf
pdf_size: 308 KB
scope: BRE（grep 默认）+ ERE（grep -E / egrep）+ PCRE（grep -P）三大流派
status: 完成
---

# 正则表达式速查（BRE / ERE / PCRE）

> **本笔记是 [[grep|grep]] / [[sed|sed]] / [[awk|awk]] 三剑客的"正则基础层"。三剑客笔记里涉及正则的细节都链接到本笔记。**
>
> **范围说明**：基于 `E:\云计算学习\09.shell编程实战\shell 三剑客\01. Linux 正则表达式.pdf` (308 KB) 整理。覆盖 BRE/ERE/PCRE 三大流派 + 元字符 + 字符类 + 量词 + 锚点 + 反向引用 + 实战 IPv4。

## 目录

- [[#§0 心智模型：正则 = 模式匹配 + 文本狩猎]]
- [[#§1 三大流派：BRE / ERE / PCRE]]
- [[#§2 普通字符与元字符]]
- [[#§3 字符类 [abc] [a-z] [^ab]]]
- [[#§4 预定义字符类 [[:digit:]] 等]]
- [[#§5 点号 . 与转义 \\]]
- [[#§6 量词 * + ? {n} {m,n}]]
- [[#§7 锚点 ^ $ \\b \\B \\< \\>]]
- [[#§8 分组 () 与反向引用 \\1]]
- [[#§9 交替 | 与分组捕获]]
- [[#§10 BRE vs ERE vs PCRE 速查表]]
- [[#§11 实战：IPv4 地址正则]]
- [[#§12 实战：重复单词检测]]
- [[#§13 速查表（一页纸）]]
- [[#§14 易错点 ×12]]
- [[#§15 面试 6 大追问]]
- [[#§16 与其他笔记的链路]]
- [[#§17 进一步阅读]]

---

## §0 心智模型：正则 = 模式匹配 + 文本狩猎

```
想象你是个猎人在森林里找兔子：
- 森林 = 一堆文本（文件）
- 你 = 正则引擎（grep/sed/awk）
- 猎枪上的"瞄准镜" = 模式（pattern）
- 兔子 = 匹配到的部分

普通字符：瞄准"c" → 只找 c
字符类：  瞄准"c[ab]t" → 找 cat 或 cbt
量词：    瞄准"do*g" → 找 dg / dog / doog / dooog...
锚点：    瞄准"^cat" → 只找行首的 cat
分组：    瞄准"(ab)+" → 找 ab / abab / ababab...
反向引用：瞄准"\\1" → 引用第 1 个分组匹配的内容
```

> 💡 **核心思想**：正则就是**用一串特殊符号描述"我想要的文字长什么样"**。

---

## §1 三大流派：BRE / ERE / PCRE

| 流派 | 全称 | 谁支持 | 关键差异 |
|---|---|---|---|
| **BRE** | Basic Regular Expression | grep、sed | 元字符需要 `\` 转义才特殊（`\|`、`\+`） |
| **ERE** | Extended Regular Expression | grep -E、egrep、awk | 元字符直接特殊（`|`、`+`），但 `(` `)` 需 `(` 起始 |
| **PCRE** | Perl-Compatible Regular Expression | grep -P、Perl、Python | 完整 Perl 正则（环视、命名分组、非贪婪等） |

```bash
# 演示：匹配 cat 或 dog

# BRE：必须 \|
grep 'cat\|dog' file
grep "cat\|dog" file

# ERE：直接 |
grep -E 'cat|dog' file            # 推荐
egrep 'cat|dog' file              # 等价

# PCRE：直接 | + 高级特性
grep -P 'cat|dog' file            # 额外支持 \d \s \w 等
```

> 💡 **黄金法则**：记不住就用 `grep -E`，覆盖 80% 场景。

---

## §2 普通字符与元字符

### 2.1 普通字符

```
普通字符 = 字母、数字、汉字、标点（除特殊元字符外）
它们在正则里 = 字面匹配

a       匹配 a
abc     匹配 abc
你好    匹配 你好
```

### 2.2 元字符（具有特殊含义）

```
. * + ? ^ $ \ | ( ) [ ] { }
```

> 这 12 个字符在正则里有"超能力"，需要字面匹配时**必须用 `\` 转义**。

```bash
# 演示：匹配字面点 .
echo 'c.t' | grep 'c.t'           # 匹配（. = 任意字符）
echo 'c.t' | grep 'c\.t'          # 匹配（\. = 字面点）
echo 'cat' | grep 'c\.t'          # 不匹配（cat ≠ c.t）
```

### 2.3 反斜杠 \ 的双重身份

```
在正则里 \ 是"转义符"，让特殊字符变普通
在 shell 里 \ 也是"转义符"
所以 "正则的 \ 实际是 \\"
```

```bash
# 在 shell 双引号里：每条 \ 实际是 \\
echo "c\.t"                       # 输出 c\.t
echo 'c\.t'                       # 输出 c\.t

# 真正传给 grep 的字符串
echo "c\\.t" | grep "c\\.t"       # 字面匹配 c.t
echo 'c\.t' | grep 'c\.t'         # 单引号更省事

# 推荐用单引号，避免 shell 和正则双重转义的混乱
```

> 💡 **最佳实践**：写正则用**单引号**包，避开 shell 的转义干扰。

---

## §3 字符类 [abc] [a-z] [^ab]

### 3.1 基础字符类

```bash
# 准备测试文件
cat > words << 'EOF'
cat
category
acat
concatenate
cbt
c1t
cCt
EOF

# [abc] = a 或 b 或 c
cat words | grep 'c[ab]t'        # cat, cbt
# 输出: cat, category, acat, concatenate, cbt
```

### 3.2 范围字符类

```bash
# [a-z] = 所有小写字母
cat words | grep 'c[a-z]t'       # cat, category, acat, concatenate, cbt

# [A-Z] = 所有大写字母
echo cCt >> words
cat words | grep 'c[A-Z]t'       # cCt

# [0-9] = 数字
echo c1t >> words
cat words | grep 'c[0-9]t'       # c1t

# 组合：[a-zA-Z0-9]
cat words | grep 'c[a-zA-Z0-9]t' # 几乎所有"c?t"形式
```

### 3.3 字符类里特殊字符的处理

```bash
# 在 [...] 里，- 开头或结尾才字面，其他位置是范围
echo c-t >> words
cat words | grep 'c[-a-zA-Z0-9]t'    # - 放最前面 = 字面
cat words | grep 'c[a-zA-Z0-9-]t'    # - 放最后面 = 字面
cat words | grep 'c[a-zA-Z\-0-9]t'   # - 用 \ 转义

# 字符类里 ^ 开头 = 取反
cat words | grep 'c[^ab]t'           # 不以 a/b 结尾的 c?t
# c1t, cCt, c-t, c.t 都在里面（因为中间不是 a 也不是 b）
```

### 3.4 取反字符类

```bash
# [^...] = 不在 ... 里的任意字符
cat words | grep 'c[^ab]t'           # c1t, cCt, c-t, c.t
# 注意：[^ab] = "不是 a 也不是 b"（不是"非 a 或非 b"）
```

### 3.5 字符类里转义 `^` 的字面含义

```bash
# ^ 不在开头 = 字面 ^ 字符
cat words | grep 'c[a^b]t'           # 找 c a/b/^ t
# 输出: cat, category, acat, concatenate
# 注意 c^t 不在 words 里，所以 c^t 不在结果里
```

### 3.6 实战：提取日志 IP 段

```bash
# 提取 access.log 第一个字段（IP）
awk '{print $1}' access.log | grep '^[0-9]\{1,3\}\.' | head
# 或
awk '{print $1}' access.log | grep -E '^[0-9]+\.' | head
```

---

## §4 预定义字符类 [[:digit:]] 等

> POSIX 标准字符类，用 `[[:name:]]` 语法。比 `[0-9]` 更可移植。

| 字符类 | 等价 | 含义 |
|---|---|---|
| `[[:digit:]]` | `[0-9]` | 数字 |
| `[[:xdigit:]]` | `[0-9A-Fa-f]` | 十六进制数字 |
| `[[:lower:]]` | `[a-z]` | 小写字母（C locale） |
| `[[:upper:]]` | `[A-Z]` | 大写字母（C locale） |
| `[[:alpha:]]` | `[A-Za-z]` | 字母 |
| `[[:alnum:]]` | `[0-9A-Za-z]` | 字母+数字 |
| `[[:blank:]]` | `[ \t]` | 空格 + Tab |
| `[[:space:]]` | `[ \f\n\r\t\v]` | 空白字符 |
| `[[:punct:]]` | `[!-/:-@\[-`{-~]` | 标点 |
| `[[:print:]]` | `[[:alnum:][:punct:]]` | 可打印字符 |
| `[[:graph:]]` | `[[:alnum:][:punct:]]` | 可视字符（不含空格） |
| `[[:cntrl:]]` | `[\x00-\x1F\x7F]` | 控制字符 |

```bash
# 演示：匹配数字
echo "abc 123 def" | grep '[[:digit:]]'
# 123

# 匹配"非数字"也行：把 digit 换成 ^digit
echo "abc 123 def" | grep '[^[:digit:]]'
# abc  def
```

### 4.1 PCRE 简化写法

PCRE 流派（`grep -P`、Perl、Python）有更简洁的写法：

| PCRE | 等价 POSIX | 含义 |
|---|---|---|
| `\d` | `[[:digit:]]` | 数字 |
| `\D` | `[^[:digit:]]` | 非数字 |
| `\s` | `[[:space:]]` | 空白 |
| `\S` | `[^[:space:]]` | 非空白 |
| `\w` | `[A-Za-z0-9_]` | 单词字符 |
| `\W` | `[^A-Za-z0-9_]` | 非单词字符 |
| `\t` | — | Tab (`\x09`) |
| `\n` | — | 换行 |
| `\r` | — | 回车 |
| `\f` | — | 换页 (`\x0C`) |
| `\v` | — | 垂直 Tab |

```bash
# grep -P 支持 PCRE
echo "abc 123" | grep -P '\d+'         # 匹配 123

# ⚠️ grep 默认（BRE/ERE）不支持 \d \s \w，要用 -P
echo "abc 123" | grep '\d+'            # 没匹配
echo "abc 123" | grep -E '[0-9]+'      # 用 [0-9] 替代
```

> ⚠️ **重要**：标准 grep 工具**默认不支持 `\d` `\s` `\w`**，必须 `grep -P`。

---

## §5 点号 . 与转义 \

### 5.1 点号 = 任意单字符

```bash
# 准备
cat > words << 'EOF'
cat
cbt
c1t
cCt
c-t
c.t
EOF

# . 匹配任意单字符
cat words | grep 'c.t'          # 几乎全匹配（cat cbt c1t cCt c-t c.t 全部）
```

> ⚠️ `.` **不匹配换行符**（默认情况下）。要跨行用 `grep -z` 或 PCRE 的 `s` 标志。

### 5.2 转义 \ 取消特殊含义

```bash
# 找字面点 .
cat words | grep 'c\.t'
# 输出: c.t

# 找字面反斜杠
echo "c\\t"                     # shell 里输出 c\t
echo 'c\\t' | grep 'c\\t'       # 找 c\t
# 复杂时用单引号简化
```

### 5.3 \ 加普通字符 = 特殊含义

```bash
# \n 换行（PCRE）
echo -e "line1\nline2" | grep -P '\n'
# 匹配换行符

# \t Tab
echo -e "a\tb" | grep -P '\t'
# 匹配 Tab
```

---

## §6 量词 * + ? {n} {m,n}

### 6.1 三个基本量词

| 量词 | 含义 | BRE 写法 | ERE 写法 |
|---|---|---|---|
| `*` | 0 或多个 | `*` | `*` |
| `+` | 1 或多个 | `\+` | `+` |
| `?` | 0 或 1 个 | `\?` | `?` |

```bash
# 准备
cat > words << 'EOF'
dg
dog
doog
doooog
EOF

# * = 0 或多个
cat words | grep 'do*g'         # dg, dog, doog, doooog

# + = 1 或多个（ERE）
cat words | grep -E 'do+g'      # dog, doog, doooog
cat words | grep 'do\+g'        # BRE 写法

# ? = 0 或 1 个（ERE）
cat words | grep -E 'do?g'      # dg, dog
cat words | grep 'do\?g'        # BRE 写法
```

### 6.2 {n} 精确 n 个

```bash
# 准备
echo doog >> words
echo dooog >> words
echo doooog >> words

# {2} = 恰好 2 个
cat words | grep -E 'do{2}g'    # doog
cat words | grep 'do\{2\}g'     # BRE 写法
```

### 6.3 {m,n} m 到 n 个

```bash
# {2,3} = 2 到 3 个
cat words | grep -E 'do{2,3}g'  # doog, dooog

# {2,} = 2 或更多
cat words | grep -E 'do{2,}g'   # doog, dooog, doooog

# {,3} = 0 到 3 个
cat words | grep -E 'do{,3}g'   # dg, dog, doog, dooog
                                  # ⚠️ doooog 不在里面（4 个 o 超过 3）
```

### 6.4 量词 + 字符类

```bash
# 找所有"数字开头 + 任意长度 + cat 结尾"的行
cat words | grep -E '^[0-9]+cat'

# 找所有"a 到 z 之间有 0 到 3 个字符"的行
cat words | grep -E '^a.{0,3}z$'
```

### 6.5 实战：手机号匹配

```bash
# 中国手机号：1 开头 + 3-9 + 9 个数字
echo "13800138000" | grep -E '^1[3-9][0-9]{9}$'

# 演示反例
echo "23800138000" | grep -E '^1[3-9][0-9]{9}$'  # 不匹配（第一位是 2）
```

### 6.6 实战：邮箱匹配（基础版）

```bash
# 用户名@域名.后缀
echo "user@example.com" | grep -E '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
echo "bad-email" | grep -E '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'  # 不匹配
```

---

## §7 锚点 ^ $ \b \B \< \>

### 7.1 行首 ^ 与行尾 $

```bash
# 准备
cat > words << 'EOF'
cat
category
acat
concatenate
EOF

# ^ 行首
cat words | grep '^cat'         # cat, category

# $ 行尾
cat words | grep 'cat$'         # cat, acat

# ^cat$ = 整行只有 cat
cat words | grep '^cat$'        # cat
```

### 7.2 单词边界 \b（grep -E / -P 支持）

```bash
# 准备
echo "hello cat" >> words

# \bcat = 单词边界的 cat（cat 前面是非单词字符或行首）
cat words | grep -E '\bcat'     # cat, category, hello cat
# 注意：acat 不匹配（前面是 a，是单词字符）

# cat\b = 单词边界的 cat（cat 后面是非单词字符或行尾）
cat words | grep -E 'cat\b'     # cat, acat, hello cat
# 注意：category 不匹配（后面是 e）

# \bcat\b = 完整单词 cat
cat words | grep -E '\bcat\b'   # cat, hello cat
```

### 7.3 非单词边界 \B

```bash
# \Bcat = 单词内部的 cat（cat 前面是单词字符）
cat words | grep -E '\Bcat'     # acat, concatenate, category
# 注意：cat、hello cat 不匹配（前面是非单词字符或行首）
```

### 7.4 \< \>（GNU 扩展，等价 \b）

```bash
# \< 单词开头，\> 单词结尾
cat words | grep -E '\<cat'     # = \bcat
cat words | grep -E 'cat\>'     # = cat\b
```

### 7.5 实战：^ $ \b 组合

```bash
# 找日志里 2025-07-09 开头的行
grep -E '^2025-07-09' app.log

# 找日志里 ERROR 结尾的行
grep -E 'ERROR$' app.log

# 找完整单词 "error"（不匹配 "errorId"）
grep -E '\berror\b' app.log

# 找"以 ERROR 开头的完整单词"
grep -E '^ERROR\b' app.log
```

---

## §8 分组 () 与反向引用 \1

### 8.1 分组捕获

```bash
# 准备
cat > words << 'EOF'
dogdog
dogdogdog
dogdogdogdog
EOF

# (dog)+ = 一个或多个 "dog"
cat words | grep -E '(dog)+'         # 全部 3 行
cat words | grep -E '(dog){2,3}'    # 前 2 行
cat words | grep -E '(dog){2,}'     # 全部 3 行
```

### 8.2 反向引用 \1

```bash
# 反向引用 = 引用第 1 个分组匹配的内容
echo 'xkw laoniu laohu xkw' | grep -E -o '(xkw) (laoniu).*\1'
# 输出: xkw laoniu laohu xkw
# 解释：匹配 "xkw laoniu...xkw"（最后 xkw 等于第一个 xkw）

# 实战：找文档里连续重复的单词
echo 'Is is the cost of of gasoline going up up?' | grep -E -o '\b([a-z]+) \1\b'
# 输出: of of, up up
```

### 8.3 反向引用 \N 语法差异

| 流派 | 写法 | 例子 |
|---|---|---|
| BRE | `\1`（不用转义额外的 \） | `grep '\(xkw\) \1' file` |
| ERE | `\1` | `grep -E '(xkw) \1' file` |
| PCRE | `\1` 或 `\g{1}` | `grep -P '(xkw) \1' file` |

> 💡 ERE 和 PCRE 写法一致：`\N`。

### 8.4 分组不捕获 (?:)

```bash
# PCRE 支持"非捕获分组"，性能略好
echo 'abcabc' | grep -P '(?:abc){2}'     # PCRE
# 不用 () 捕获

# BRE/ERE 不支持，所有 () 都捕获
```

---

## §9 交替 | 与分组捕获

### 9.1 交替 |

```bash
# 准备
echo cat >> words
echo dog >> words

# BRE 写法
cat words | grep 'cat\|dog'

# ERE 写法（推荐）
cat words | grep -E 'cat|dog'      # cat, dog

# 注意：| 的优先级低
echo 'cat' | grep -E 'cat|dog'             # 匹配 cat
echo 'catdog' | grep -E 'cat|dog'          # 也匹配（找 cat 部分）

# 想匹配"完整 cat 或完整 dog"：加 ()
echo 'catdog' | grep -E '^(cat|dog)$'      # 不匹配
echo 'cat' | grep -E '^(cat|dog)$'         # 匹配
```

### 9.2 分组捕获的数据

```bash
# ERE 中 () 自动捕获，sed/awk 可以用 \1 $1 取
# grep -E 用 -o 输出匹配段
echo 'date: 2025-07-09' | grep -E -o '[0-9]{4}-[0-9]{2}-[0-9]{2}'
# 输出: 2025-07-09
```

### 9.3 实战：多选一

```bash
# 找扩展名为 .txt .md .conf 的文件
ls | grep -E '\.(txt|md|conf)$'

# 找日期格式（多种）
echo "Today is 2025-07-09 or 2025/07/09" | grep -E -o '[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}'
# 2025-07-09, 2025/07/09
```

---

## §10 BRE vs ERE vs PCRE 速查表

| 特性 | BRE（默认 grep） | ERE（grep -E） | PCRE（grep -P） |
|---|---|---|---|
| `.` `*` | ✅ | ✅ | ✅ |
| `^` `$` | ✅ | ✅ | ✅ |
| `[...]` | ✅ | ✅ | ✅ |
| `+` | `\+` | `+` | `+` |
| `?` | `\?` | `?` | `?` |
| `{n,m}` | `\{n,m\}` | `{n,m}` | `{n,m}` |
| `|` | `\|` | `|` | `|` |
| `()` | `\(\)` | `()` | `()` |
| 反向引用 `\1` | ✅ | ✅ | ✅ |
| `\d \s \w` | ❌ | ❌ | ✅ |
| 非贪婪 `*?` `+?` | ❌ | ❌ | ✅ |
| 非捕获 `(?:)` | ❌ | ❌ | ✅ |
| 环视 `(?=)` | ❌ | ❌ | ✅ |
| 命名分组 | ❌ | ❌ | ✅ |

```bash
# 演示：找 1+ 个数字
echo "abc 123" | grep 'abc \+'      # BRE
echo "abc 123" | grep -E 'abc +'     # ERE
echo "abc 123" | grep -P 'abc \d+'   # PCRE
```

> 💡 **实战选择**：
> - 简单匹配 → BRE（默认）
> - 复杂表达式 → ERE（`grep -E`）
> - 需要 `\d` `\s` `\w` 或高级特性 → PCRE（`grep -P`）

---

## §11 实战：IPv4 地址正则

### 11.1 准备测试数据

```bash
cat > ips.txt << 'EOF'
0.0.0.0
1.1.1.1
11.11.11.111
111.111.111.111
999.9.9.9
01.1.1.1
10.0.0.0
0.1.1.1
266.1.1.1
248.1.1.1
256.1.1.1
EOF
```

### 11.2 完整 IPv4 正则

```bash
# ERE 写法（无 \d，纯 POSIX 字符类）
grep -E '\b(([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.)(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\b' ips.txt
# 输出合法 IPv4
```

### 11.3 拆解理解

```
一个 IP 段（0-255）的正则：

[0-9]              匹配 0-9
[1-9][0-9]         匹配 10-99
1[0-9]{2}          匹配 100-199
2[0-4][0-9]        匹配 200-249
25[0-5]            匹配 250-255

组合：( [0-9] | [1-9][0-9] | 1[0-9]{2} | 2[0-4][0-9] | 25[0-5] )

完整 IP：第 1 段 + . + 第 2-3 段（重复 2 次）+ . + 第 4 段
```

### 11.4 简化版（匹配所有含 . 的 4 段数字）

```bash
# 简化：只匹配"X.X.X.X" 形式，不管合法性
grep -E '\b[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\b' ips.txt
# 输出全部 11 行
```

### 11.5 极简版（PCRE）

```bash
# PCRE 用 \d 简化
grep -P '\b\d+\.\d+\.\d+\.\d+\b' ips.txt
```

### 11.6 实战：日志里提取合法 IP

```bash
# 从 access.log 提取合法 IPv4
awk '{print $1}' access.log | sort -u | \
  grep -E '\b(([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\b'
```

---

## §12 实战：重复单词检测

### 12.1 经典问题：找文档里"重复的词"

```bash
# 测试
echo 'Is is the cost of of gasoline going up up?' | \
  grep -E -o '\b([a-z]+) \1\b'
# 输出:
#   of of
#   up up
```

### 12.2 拆解

```
\b         单词边界
([a-z]+)   第 1 个分组：一个或多个小写字母
           （这一段会被"记住"）
[ ]        一个空格
\1         反向引用：与第 1 个分组匹配的内容相同
\b         单词边界
```

### 12.3 批量找文档里的"口误"

```bash
# 找 article.txt 里所有重复单词
grep -E -on '\b([a-zA-Z]+) \1\b' article.txt
# -o 只输出匹配段
# -n 显示行号
```

### 12.4 进阶：找连续 3 次重复

```bash
# "the the the" 这样的连续重复
echo 'the the the cat' | grep -E -o '\b([a-z]+)( \1){2,}\b'
# 输出: the the the
```

---

## §13 速查表（一页纸）

### 13.1 元字符

```
.       任意单字符（除换行）
*       0+ 个
+       1+ 个（ERE）
?       0 或 1 个（ERE）
{n}     恰好 n 个
{m,n}   m 到 n 个
{m,}    m+ 个
{,n}    0 到 n 个
^       行首
$       行尾
\b      单词边界
\B      非单词边界
|       交替（ERE）
()      分组
\1      反向引用第 1 组
\       转义
```

### 13.2 字符类

```
[abc]       a 或 b 或 c
[a-z]       a-z
[A-Z]       A-Z
[0-9]       0-9
[^ab]       不是 a 也不是 b
[[:digit:]] 数字（POSIX）
[[:alpha:]] 字母（POSIX）
[[:space:]] 空白（POSIX）
[[:alnum:]] 字母+数字（POSIX）
```

### 13.3 PCRE 简化

```
\d \D     数字/非数字
\s \S     空白/非空白
\w \W     单词/非单词字符
\b        单词边界
(?:...)   非捕获分组
*? +? ?   非贪婪
```

### 13.4 流派切换

```
grep 'pat'        # BRE
grep -E 'pat'     # ERE
grep -P 'pat'     # PCRE
```

---

## §14 易错点 ×12

### 1. ❌ 在 shell 双引号里忘了转义

```bash
echo "c\t" | grep "c\t"           # ⚠️ shell 解释 \t 为 Tab，正则收不到
echo "c\t" | grep 'c\t'           # ✓ 单引号保护反斜杠
```

> 💡 **永远用单引号**写正则。

### 2. ❌ BRE/ERE 混淆

```bash
grep -E 'do+g'                    # ERE 找 dog/doog/...
grep 'do+g'                       # ⚠️ BRE 把 + 当字面，找字面 do+g
```

> 💡 用 `-E` 后所有 `+ ? | ()` 都直接生效。

### 3. ❌ 点号 . 以为只匹配点

```bash
echo "c1t" | grep 'c.t'           # 匹配（. 匹配 1）
echo "c.t" | grep 'c.t'           # 也匹配
```

> 💡 `\.` 才匹配字面点。

### 4. ❌ 字符类里 - 放中间

```bash
grep 'c[a-zA-Z0-9-]t'             # 末尾 - 字面
grep 'c[-a-zA-Z0-9]t'             # 开头 - 字面
grep 'c[a-z-A-Z]t'                # ⚠️ 中间 - 是范围（z-A 非法，可能报错或行为不定义）
```

### 5. ❌ `[^ab]` 当成"非 a 或非 b"

```bash
grep 'c[^ab]t'                    # c?t 里 ? 不是 a 也不是 b
                                  # cct（第二个 c 不是 a/b）匹配
                                  # cat（第二个 a 是 a）不匹配
```

> 💡 `[^ab]` = "(不是 a) **且** (不是 b)"。

### 6. ❌ 锚点 ^ 放错位置

```bash
grep 'cat^'                       # ⚠️ 语法错
grep '^cat'                       # ✓ 锚点必须在字符前
```

### 7. ❌ $ 不带任何字符

```bash
grep '^$'                         # 找空行（正确）
grep 'cat$ dog'                   # ⚠️ 找 "cat$" 结尾 + 空格 + "dog"（无意义）
```

### 8. ❌ \b 在 BRE 里

```bash
grep '\bcat\b'                    # ⚠️ BRE 不支持 \b（可能报错）
grep -E '\bcat\b'                 # ✓ ERE 支持
```

### 9. ❌ 反向引用 \1 在不同流派

```bash
# BRE
grep '\(cat\) \1'                 # 需要转义括号

# ERE/PCRE
grep -E '(cat) \1'                # 直接 ()
```

### 10. ❌ 在 . 里用 | 没加分组

```bash
grep -E 'cat|dog'                 # 找 cat 或 dog
grep -E '^cat|dog$'               # ⚠️ 实际是 (^cat) | (dog$)
                                  # 找行首 cat 或行尾 dog
```

> 💡 想锚两边：`grep -E '^(cat|dog)$'`。

### 11. ❌ 数字匹配用 `*`

```bash
grep -E '1*'                      # 找任意个 1（包括 0 个 = 任意行）
                                  # 几乎每行都匹配
grep -E '1+'                      # 找 1+ 个 1（0 个不算）
```

### 12. ❌ 嵌套 \1 \2

```bash
# 反向引用编号按"左括号出现顺序"算
grep -E '((ab)(cd)) \1'           # \1 = abcd, \2 = ab, \3 = cd
```

> 💡 数左括号，从 1 开始。

---

## §15 面试 6 大追问

### Q1：BRE 和 ERE 区别？

**答**：
- **BRE（Basic）**：`+ ? | () {}` 需要 `\` 转义才生效
- **ERE（Extended）**：`+ ? | () {}` 直接生效
- **PCRE（Perl）**：完整 Perl 正则

```bash
# 同一表达式的三种写法
echo "abc" | grep 'a\+b'         # BRE
echo "abc" | grep -E 'a+b'       # ERE
echo "abc" | grep -P 'a+b'       # PCRE
```

### Q2：`grep -E` 和 `egrep` 等价吗？

**答**：✅ **完全等价**。`egrep` 是 `grep -E` 的旧式别名，新版系统已弃用 egrep。

### Q3：`\.` 和 `.` 区别？

**答**：
- `.` = **任意单字符**（除换行）
- `\.` = **字面点**（转义后无特殊含义）

```bash
echo "c.t" | grep 'c.t'          # 匹配（. 匹配 .）
echo "cat" | grep 'c.t'          # 也匹配（. 匹配 a）
echo "c.t" | grep 'c\.t'         # 匹配
echo "cat" | grep 'c\.t'         # ⚠️ 不匹配
```

### Q4：`.*` 和 `.+` 区别？

**答**：
- `.*` = **任意长度**（含 0 字符）
- `.+` = **至少 1 字符**

```bash
echo "abc" | grep -E '.*'        # 匹配（0 个字符也匹配 → 整行）
echo "abc" | grep -E '.+'        # 匹配（至少 1 字符）
echo ""    | grep -E '.*'        # 匹配（0 字符）
echo ""    | grep -E '.+'        # ⚠️ 不匹配（需要至少 1 字符）
```

### Q5：反向引用 `\1` 是什么？

**答**：引用**第 1 个分组**匹配的内容。

```bash
echo 'abab' | grep -E -o '(ab)\1'    # 匹配 abab
                                    # \1 等于 (ab) 匹配的内容
```

### Q6：什么是"非贪婪"？

**答**：量词默认**贪婪**（尽可能多匹配），加 `?` 变**非贪婪**（尽可能少）。

```bash
echo '<a>bc</a>' | grep -Po '<.+>'        # 贪婪: 匹配 <a>bc</a>（整段）
echo '<a>bc</a>' | grep -Po '<.+?>'       # 非贪婪: 匹配 <a>（最短）
```

> 💡 非贪婪只在 **PCRE** 里有意义（`grep -P`）。

---

## §16 与其他笔记的链路

| 笔记 | 关系 |
|---|---|
| [[Linux文本处理/grep]] | grep -E 用 ERE；grep -P 用 PCRE；正则基础 → [[regex]] |
| [[Linux文本处理/sed]] | sed 默认 BRE；`sed -E` 用 ERE；s/pattern/replacement/ |
| [[Linux文本处理/awk]] | awk 用 ERE；正则匹配：`$0 ~ /pattern/` |
| [[Linux文本处理/输入输出重定向]] | grep/sed/awk 通过管道串联 |
| [[Linux文本处理/辅助工具]] | `grep -E` vs `egrep` 等价；cut/sort/uniq 不支持正则 |
| [[LinuxShell/shell]] | bash 字符串 `[[ =~ ]]` 用 ERE；[[ =~ ]] 支持反向引用 |

### bash 中用正则

```bash
# bash 3+ 支持 [[ =~ ]] 用 ERE
if [[ "hello123" =~ ^[a-z]+[0-9]+$ ]]; then
    echo "匹配"
fi

# 捕获组用 BASH_REMATCH
if [[ "hello 123" =~ ^([a-z]+)\ ([0-9]+)$ ]]; then
    echo "字母: ${BASH_REMATCH[1]}"  # hello
    echo "数字: ${BASH_REMATCH[2]}"  # 123
fi
```

---

## §17 进一步阅读

| 资源 | 说明 |
|---|---|
| `man grep` | 查 `-E` `-P` `-o` 等选项 |
| `man 7 regex` | POSIX 正则手册 |
| [regex101.com](https://regex101.com/) | 在线调试（支持 PCRE/Python/JavaScript） |
| 《精通正则表达式》（Jeffrey Friedl） | "正则圣经" |
| 《Linux 命令行与 shell 脚本编程大全》第 4 章 | 实战练习 |
| `info grep` | 完整文档 |

### 推荐练习命令

```bash
# 在共享文件夹里做实验
cd /mnt/hgfs/Linux
mkdir -p regex_practice && cd regex_practice

# 创建测试数据
cat > words << 'EOF'
cat
category
acat
concatenate
cbt
c1t
cCt
c-t
c.t
dog
EOF

# 开始测试
grep 'c.t' words                # 任意字符
grep 'c\.t' words               # 字面点
grep -E '\bcat\b' words         # 完整单词
grep -E '(cat|dog)' words       # 交替
```

---

## 复习建议

- [ ] 能解释 BRE / ERE / PCRE 三大流派区别
- [ ] 能默写字符类 `[abc]` `[a-z]` `[^ab]` 含义
- [ ] 能默写量词 `*` `+` `?` `{n}` `{m,n}` 含义（ERE 语法）
- [ ] 能解释锚点 `^` `$` `\b` 区别
- [ ] 能用 `()` 分组 + `\1` 反向引用找重复单词
- [ ] 能解释 `grep -E` 和 `egrep` 等价
- [ ] 能写 IPv4 地址的正则（哪怕简化版）
- [ ] 能说出"贪婪 vs 非贪婪"的区别

**下一步**：进入 [[regex-practice|正则实战练习 12 道]]，在 VMware 共享文件夹里跑一遍。或者回 [[Linux文本处理/grep]] 复习更深的 grep 用法。
