---
title: 正则表达式实战练习 — 12 道
desc: 在 VMware /mnt/hgfs/Linux/ 共享文件夹里实操。覆盖 BRE/ERE/PCRE 三大流派 + 字符类 + 量词 + 锚点 + 分组 + 反向引用。
type: 练习
module: Linux文本处理
level: 简单 → 中等 → 进阶 → 综合
---

# 正则表达式实战练习 — 12 道

> **目标**：把 [[regex|正则表达式]] 17 节核心概念在 VMware 真实环境里跑一遍。
>
> **环境**：CentOS-7 / bash 4.2 + VMware 共享文件夹 `/mnt/hgfs/Linux/`（Windows 端是 `E:\Linux\`）。
>
> **建议节奏**：每天 3 道，4 天做完。每道题先**自己写一遍**再看答案。

## 使用说明

1. **新建练习目录**：`cd /mnt/hgfs/Linux && mkdir -p regex_practice && cd regex_practice`
2. **创建测试数据**：见每题的"准备"段
3. **每题 3 步**：
   - 自己写命令
   - 跑一遍验证
   - 对照答案
4. **建议**：用**单引号**包正则，避开 shell 转义干扰

---

## 第 1 题 ⭐ 字符类基础

**场景**：创建测试数据，用字符类筛选"c?t"形式（中间是字母或数字）。

**准备**：
```bash
cd /mnt/hgfs/Linux && mkdir -p regex_practice && cd regex_practice

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
```

**任务**：
1. 找中间是小写字母的 `c?t`：`grep 'c[??]t' words`
2. 找中间是数字的 `c?t`：`grep 'c[??]t' words`
3. 找中间是字母或数字的 `c?t`：`grep 'c[????]t' words`
4. 找中间**不是** a 或 b 的 `c?t`：`grep 'c[??]t' words`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 小写字母
grep 'c[a-z]t' words
# cat, category, acat, concatenate, cbt, c-t 之前的 5 行

# 2) 数字
grep 'c[0-9]t' words
# c1t

# 3) 字母或数字
grep 'c[a-zA-Z0-9]t' words
# 几乎所有（除了 c-t, c.t, dog）

# 4) 不是 a 也不是 b
grep 'c[^ab]t' words
# c1t, cCt, c-t, c.t
```

**核心点**：
- `[a-z]` 范围字符类
- `[^ab]` 取反字符类
</details>

---

## 第 2 题 ⭐ 预定义字符类

**任务**：
1. 用 `[[:digit:]]` 找 words 里的数字行
2. 用 `[[:alpha:]]` 找纯字母的行
3. 用 `[[:lower:]]` 找含小写字母的行
4. 对比 `[[:digit:]]` 和 `[0-9]` 的输出是否一致

<details>
<summary>💡 参考答案</summary>

```bash
# 1) POSIX 数字
grep '[[:digit:]]' words        # c1t
# 等价：grep '[0-9]' words

# 2) 纯字母
grep '^[[:alpha:]]\+$' words    # cat, category, acat, concatenate, cbt, cCt, dog
# 注：grep 用 ERE 才能直接 +

# 3) 含小写
grep '[[:lower:]]' words        # 含 a-z 的所有行

# 4) 对比
grep '[[:digit:]]' words        # c1t
grep '[0-9]' words              # c1t
# 一致
```

**核心点**：POSIX 字符类更可移植，但写起来长。
</details>

---

## 第 3 题 ⭐⭐ 量词对比

**场景**：在 words 基础上加 4 行测试量词。

**准备**：
```bash
cat >> words << 'EOF'
dg
doog
dooog
doooog
EOF
```

**任务**：
1. 用 `*`（0 或多个）找 `do*g`：应该 4 行都匹配（dg, dog, doog, doooog）
2. 用 `+`（1 或多个，ERE）找 `do+g`：dg 不匹配，其他匹配
3. 用 `?`（0 或 1，ERE）找 `do?g`：dg 和 dog 匹配
4. 用 `{2,}` 找 2+ 个 o：`do{2,}g`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 0 或多个
grep 'do*g' words
# dg, dog, doog, dooog, doooog

# 2) 1 或多个（ERE）
grep -E 'do+g' words
# dog, doog, dooog, doooog（dg 没了）

# 3) 0 或 1（ERE）
grep -E 'do?g' words
# dg, dog

# 4) 2+ 个
grep -E 'do{2,}g' words
# doog, dooog, doooog

# BRE 写法（要转义）
grep 'do\+g' words               # 1 或多个
grep 'do\?g' words               # 0 或 1
grep 'do\{2,\}g' words           # 2+ 个
```

**核心点**：
- `*` 默认 0+
- ERE 写法直观，BRE 要 `\` 转义
</details>

---

## 第 4 题 ⭐⭐ 锚点 ^ $ \b

**任务**：
1. 找 words 里以 `cat` 开头的行：`grep '^cat' words`
2. 找 words 里以 `cat` 结尾的行：`grep 'cat$' words`
3. 找 words 里**完整单词** `cat`：`grep -E '\bcat\b' words`
4. 找 words 里以 `cat` 开头的**完整单词**：`grep -E '^cat\b' words`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 行首
grep '^cat' words
# cat, category

# 2) 行尾
grep 'cat$' words
# cat, acat

# 3) 完整单词（用 ERE 支持 \b）
grep -E '\bcat\b' words
# cat, hello cat
# 注意：acat 不在（前后是字母）
# 注意：category 不在（cat 后面是 e）

# 4) 单词开头的 cat
grep -E '\bcat' words
# cat, category, hello cat
# acat 不在（前面是 a）
```

**核心点**：
- `^` `$` 是行级锚点
- `\b` 是单词级锚点（ERE/PCRE）
</details>

---

## 第 5 题 ⭐⭐ 字符类与转义

**任务**：在 words 基础上加 2 行特殊数据，演示转义。

**准备**：
```bash
echo 'c*t' >> words
echo 'c*t.c' >> words
```

**任务**：
1. 用 `.` 找 `c.t`：`grep 'c.t' words` —— 看 c*t 在不在结果
2. 用 `\.` 找字面点：`grep 'c\.t' words` —— 同样
3. 用 `\*` 找字面星号：`grep 'c\*t' words` —— 看 c*t 在不在
4. 用 `\\` 找字面反斜杠（先 echo 'c\\t'）：`echo 'c\\t' >> words && grep 'c\\t' words`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) . 匹配任意单字符
grep 'c.t' words
# cat, cbt, c1t, cCt, c-t, c*t（c*t 里的 * 匹配"任意字符"！）
# c.t 也在（点匹配点）

# 2) \. 字面点
grep 'c\.t' words
# 只有 c.t（精确）

# 3) \* 字面星号
grep 'c\*t' words
# 只有 c*t

# 4) \\ 字面反斜杠
echo 'c\\t' >> words              # shell 里 \\ → 实际写入 c\t
grep 'c\\t' words                 # 正则 \\ → 实际匹配 c\t
# 输出: c\t（你看 words 里的字面 c\t）
```

**核心点**：
- 元字符必须 `\` 转义才能字面匹配
- 永远是**单引号**包正则
</details>

---

## 第 6 题 ⭐⭐⭐ 分组捕获

**任务**：找 `dogdog`、`dogdogdog` 等重复模式。

**准备**：
```bash
echo dogdog >> words
echo dogdogdog >> words
echo dogdogdogdog >> words
echo dog >> words
echo dogd >> words
```

**任务**：
1. 用 `(dog)+` 找 1+ 个完整 dog：`grep -E '(dog)+' words`
2. 用 `(dog){2,3}` 找 2-3 个连续 dog：`grep -E '(dog){2,3}' words`
3. 用 `(dog){2,}` 找 2+ 个连续 dog：`grep -E '(dog){2,}' words`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 1+ 个
grep -E '(dog)+' words
# dog, dogdog, dogdogdog, dogdogdogdog
# dogd 不在（d 后是 d，不是完整 dog）

# 2) 2-3 个
grep -E '(dog){2,3}' words
# dogdog, dogdogdog
# dogdogdogdog 不在（4 个超过 3）

# 3) 2+ 个
grep -E '(dog){2,}' words
# dogdog, dogdogdog, dogdogdogdog
```

**核心点**：
- `()` 分组是基本单位
- `{n,m}` 量词跟分组配合
</details>

---

## 第 7 题 ⭐⭐⭐ 反向引用 \1

**场景**：找文本里"重复的单词"。

**任务**：
1. 找 "of of" 这样的重复：`echo 'Is is the cost of of gasoline going up up?' | grep -E -o '\b([a-z]+) \1\b'`
2. 改一下数据，找 "the the"：`echo 'the the cat' | grep -E -o '\b([a-z]+) \1\b'`
3. 找连续 3 次重复：`echo 'the the the cat' | grep -E -o '\b([a-z]+)( \1){2,}\b'`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 重复单词
echo 'Is is the cost of of gasoline going up up?' | \
    grep -E -o '\b([a-z]+) \1\b'
# 输出: of of, up up

# 2) 改数据
echo 'the the cat' | \
    grep -E -o '\b([a-z]+) \1\b'
# 输出: the the

# 3) 连续 3 次
echo 'the the the cat' | \
    grep -E -o '\b([a-z]+)( \1){2,}\b'
# 输出: the the the
```

**核心点**：
- `\b` 单词边界
- `()` 捕获
- `\1` 反向引用
- `{2,}` 跟分组配合
</details>

---

## 第 8 题 ⭐⭐⭐ PCRE \d \s \w

**任务**：
1. 准备：`echo "abc 123" >> words`
2. 用 `\d+` 找连续数字（PCRE）：`grep -P '\d+' words`
3. 不用 -P 直接用 `\d+` 看看会怎样：`grep '\d+' words` —— 应该匹配不到
4. 用 ERE 等价：把 `\d+` 改成 `[0-9]+` 试试：`grep -E '[0-9]+' words`

<details>
<summary>💡 参考答案</summary>

```bash
# 准备
echo "abc 123" >> words

# 1) PCRE
grep -P '\d+' words
# 输出: abc 123（找数字段 123）

# 2) 不带 -P
grep '\d+' words
# ⚠️ 无输出（BRE 把 \d 当字面，找字面 \d）

# 3) ERE 等价
grep -E '[0-9]+' words
# 输出: abc 123, c1t

# 对比 PCRE 简洁写法
grep -P '\w+@\w+' email.txt       # 匹配邮箱
grep -E '[a-zA-Z0-9_]+@[a-zA-Z0-9_]+' email.txt  # ERE 等价（长）
```

**核心点**：
- `grep -P` 才有 `\d \s \w`
- 不带 -P 就用 `[0-9] [a-zA-Z0-9_] [ \t]` 等价
</details>

---

## 第 9 题 ⭐⭐⭐ 提取日志数据

**场景**：从 access.log 提取 IP 段（简化版）。

**准备**：
```bash
cat > access.log << 'EOF'
192.168.1.1 - - [10/Oct/2025:13:55:36] "GET /index.html HTTP/1.1" 200 1234
10.0.0.1 - - [10/Oct/2025:13:55:37] "POST /api HTTP/1.1" 201 567
invalid 1.2 - - [10/Oct/2025:13:55:38] "GET / HTTP/1.1" 404 0
256.1.1.1 - - [10/Oct/2025:13:55:39] "GET / HTTP/1.1" 200 100
EOF
```

**任务**：
1. 提取每行第一个字段（IP）：`awk '{print $1}' access.log`
2. 找合法 IPv4（简化版）：`awk '{print $1}' access.log | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'`
3. 找**只含数字和点**的 IP 段：`grep -E '^[0-9.]+$'`
4. 找请求方法（GET/POST）：`grep -oE '"[A-Z]+ ' access.log`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 取 IP
awk '{print $1}' access.log
# 192.168.1.1
# 10.0.0.1
# invalid
# 256.1.1.1

# 2) 简化合法 IP（只看形式）
awk '{print $1}' access.log | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
# 192.168.1.1
# 10.0.0.1
# 256.1.1.1（这是"形式"合法但实际越界）

# 3) 只含数字和点
grep -E '^[0-9.]+$' <(awk '{print $1}' access.log)
# 192.168.1.1
# 10.0.0.1
# 256.1.1.1

# 4) 提取方法
grep -oE '"[A-Z]+ ' access.log
# "GET
# "POST
# "GET
# "GET
```

**核心点**：
- 实际生产用 [[regex#§11 实战：IPv4 地址正则|完整 IPv4 正则]]
- `grep -o` 只输出匹配段（不是整行）
</details>

---

## 第 10 题 ⭐⭐⭐⭐ 文件名批量匹配

**任务**：
1. 在 regex_practice 下建一些测试文件：`touch a.txt b.md c.conf d.log e.txt`
2. 找所有 `.txt` 文件：`ls | grep -E '\.txt$'`
3. 找所有扩展名是 .txt .md .conf 的：`ls | grep -E '\.(txt|md|conf)$'`
4. 找文件名是字母+数字的（不含特殊字符）：`ls | grep -E '^[a-zA-Z0-9.]+$'`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 建文件
cd /mnt/hgfs/Linux/regex_practice
touch a.txt b.md c.conf d.log e.txt
ls
# a.txt  b.md  c.conf  d.log  e.txt

# 2) 找 .txt
ls | grep -E '\.txt$'
# a.txt
# e.txt

# 3) 多扩展名
ls | grep -E '\.(txt|md|conf)$'
# a.txt  b.md  c.conf  e.txt

# 4) 干净文件名
ls | grep -E '^[a-zA-Z0-9.]+$'
# 全部（都符合）
```

**核心点**：
- `.` 在正则里要转义成 `\.`
- `$` 锚定行尾（=文件名结尾）
</details>

---

## 第 11 题 ⭐⭐⭐⭐ 综合：清理文本

**场景**：把一段带噪声的文本清理成"只有数字和换行"。

**准备**：
```bash
cat > messy.txt << 'EOF'
Order #12345 placed at 2025-07-09 by user alice
Order #67890 placed at 2025-07-09 by user bob
Total: $54321
Phone: 138-0013-8000
Email: alice@example.com
EOF
```

**任务**：
1. 提取所有订单号（#后跟 5+ 数字）：`grep -oE '#[0-9]+' messy.txt`
2. 提取所有日期：`grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' messy.txt`
3. 提取所有价格（$后跟数字）：`grep -oE '\$[0-9]+' messy.txt`
4. 提取所有电话号码：`grep -oE '[0-9]{3}-[0-9]{4}-[0-9]{4}' messy.txt`
5. 提取所有邮箱：`grep -oE '[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+' messy.txt`

<details>
<summary>💡 参考答案</summary>

```bash
# 1) 订单号
grep -oE '#[0-9]+' messy.txt
# #12345
# #67890

# 2) 日期
grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' messy.txt
# 2025-07-09
# 2025-07-09

# 3) 价格
grep -oE '\$[0-9]+' messy.txt
# $54321

# 4) 电话
grep -oE '[0-9]{3}-[0-9]{4}-[0-9]{4}' messy.txt
# 138-0013-8000

# 5) 邮箱（基础版）
grep -oE '[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+' messy.txt
# alice@example.com
```

**核心点**：
- `grep -o` 是提取匹配段的关键
- 综合：字符类 + 量词 + 字符类反义 + 锚点
</details>

---

## 第 12 题 ⭐⭐⭐⭐⭐ 综合：IP 提取 + 排序

**场景**：从 access.log 提取所有 IP，统计次数，找出 TOP 3。

**任务**：
1. 提取每行第一个字段：`awk '{print $1}' access.log`
2. 过滤出"形式合法"的 IP：`awk '{print $1}' access.log | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'`
3. 排序去重统计：`... | sort | uniq -c | sort -rn`
4. 取前 3：`... | head -3`

<details>
<summary>💡 参考答案</summary>

```bash
# 1-4 完整管道
awk '{print $1}' access.log | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort | uniq -c | sort -rn | head -3

# 假设 access.log 里 192.168.1.1 出现 2 次，10.0.0.1 出现 1 次，256.1.1.1 出现 1 次
# 输出:
#      2 192.168.1.1
#      1 256.1.1.1
#      1 10.0.0.1
```

**核心点**：
- 这是正则 + [[Linux文本处理/辅助工具|cut/sort/uniq]] + [[输入输出重定向|重定向]] 黄金组合
- 真实工作流：grep 提 → sort 排 → uniq 数 → sort -rn 反序 → head 取前 N
</details>

---

## 进阶挑战（可选）

### 挑战 1 ⭐⭐⭐⭐⭐ IPv4 完整版

**任务**：用 [[regex#§11 实战：IPv4 地址正则|完整 IPv4 正则]]，从 access.log 提取"实际合法"的 IP（0-255 范围）。

```bash
awk '{print $1}' access.log | sort -u | \
  grep -E '\b(([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\b'
# 256.1.1.1 应该被过滤掉
```

### 挑战 2 ⭐⭐⭐⭐⭐ URL 解析

**任务**：从日志里提取所有 URL（路径部分）。

```bash
# 准备
cat > urls.log << 'EOF'
"GET /index.html HTTP/1.1"
"POST /api/login HTTP/1.1"
"GET /static/style.css HTTP/1.1"
EOF

# 提取（双引号之间 + GET/POST + 空格 + 路径 + 空格 + HTTP）
grep -oE '"[A-Z]+ /[^ ]+ HTTP' urls.log | grep -oE '/[^ ]+'
# /index.html
# /api/login
# /static/style.css
```

### 挑战 3 ⭐⭐⭐⭐⭐ 反向引用实战：检测重复行

**任务**：找文件中**完全相同的两行**。

```bash
# 准备
cat > dup.txt << 'EOF'
line A
line B
line A
line C
line B
EOF

# 提示：用 awk 维护哈希表
awk '{if ($0 in seen) print "重复: " $0; seen[$0]=1}' dup.txt
# 重复: line A
# 重复: line B
```

---

## 完成情况自查

| # | 主题 | 难度 | 做了吗 |
|---|---|---|---|
| 1 | 字符类基础 | ⭐ | ☐ |
| 2 | 预定义字符类 | ⭐ | ☐ |
| 3 | 量词对比 | ⭐⭐ | ☐ |
| 4 | 锚点 ^ $ \b | ⭐⭐ | ☐ |
| 5 | 字符类与转义 | ⭐⭐ | ☐ |
| 6 | 分组捕获 | ⭐⭐⭐ | ☐ |
| 7 | 反向引用 \1 | ⭐⭐⭐ | ☐ |
| 8 | PCRE \d \s \w | ⭐⭐⭐ | ☐ |
| 9 | 提取日志数据 | ⭐⭐⭐ | ☐ |
| 10 | 文件名批量匹配 | ⭐⭐⭐⭐ | ☐ |
| 11 | 清理文本综合 | ⭐⭐⭐⭐ | ☐ |
| 12 | IP 提取 + 排序 | ⭐⭐⭐⭐⭐ | ☐ |

**做完后回到 [[regex]] 复习，或进入 [[Linux文本处理/grep]] 看 grep 高级用法。**
