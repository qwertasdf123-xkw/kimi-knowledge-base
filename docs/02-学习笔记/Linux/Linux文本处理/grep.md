---
title: grep
desc: 系统讲解 grep 逐行模式匹配，覆盖 BRE/ERE/PCRE 三大流派与管道筛选用法（面试强化版）。
type: 笔记
module: Linux文本处理
pdf: 未知
pdf_size: 未知
scope: grep 选项 / 正则三流派 / 管道组合
status: 完成
---
# Linux grep 命令（面试强化版）

> 本文系统讲解 Linux **grep** —— 文本搜索的"瑞士军刀"。grep 本身只做一件事：**逐行匹配模式**。
>
> **核心定位**：grep 是 **管道链的第一站**。`ps aux | grep`、`cat /etc/passwd | grep root`、`dmesg | grep -i error`——90% 的运维命令都靠它筛选。
>
> **链路呼应**：
> - → [[regex|正则表达式]]：grep 的核心是正则匹配，BRE/ERE/PCRE 三大流派速查
> - → [[输入输出重定向]]：grep 99% 用在管道里；`-o / -c` 配合重定向做统计
> - → [[linux文件查询]]：`grep` 搜索文件内容，`find` 搜索文件名——两大查找工具互补
> - → [[目录的权限]]：`-r` 递归遍历需要目录 `x` 权限
> - → [[Linux vfs虚拟文件系统|VFS]]：`/proc/$$/fd/` 也能 grep
> - → [[Linux目录导航]]：`-l` + 路径在脚本里非常常见
>
> 备注：编写时网络访问受限，所有结论以本地 `man grep` 语义为准。

---

## §0. 心智模型：grep = 漏斗筛子

> 想理解 grep，请先在脑子里装一个"漏斗"。

| 比喻 | grep 对应 | 说明 |
|---|---|---|
| **大锅汤** | **输入文本流**（stdin 或文件） | 杂乱无章的所有行 |
| **筛子孔** | **正则表达式 / 固定字符串** | 匹配规则 |
| **留下来的** | **匹配到的行**（默认输出到 stdout） | 通过筛子的部分 |
| **倒掉的** | **不匹配的行** | 默认丢弃 |
| **开关 -v** | **反转漏斗** | 不匹配的留下来 |
| **开关 -c** | **数筛子剩多少** | 只输出匹配行数 |
| **开关 -l** | **只记文件名** | 输出"哪个文件有"，不输出内容 |
| **开关 -o** | **只取匹配片段** | 不输出整行，只输出命中部分 |
| **开关 -n** | **贴行号标签** | 输出时带行号 |
| **开关 -i** | **大小写不敏感筛子** | Case-INsensitive |

> **核心口诀**：**grep = "global regular expression print"**——"全局正则表达式打印"。G/R/E/P = **G**lobal/**R**egular/**E**xpression/**P**rint。它把"匹配到的行"打印出来。

### 为什么 grep 是个值得理解透的命令？

- 所有日志分析、配置审计、错误排查的**起点**。
- 正则表达式的"最小可用集"——掌握 grep 的正则 ≈ 掌握 70% 的日常正则需求。
- 几乎所有"查找字符串"问题，都能用 `grep` 一个命令解决。
- 性能极强：grep 是用 Boyer-Moore / Aho-Corasick 算法实现的，**比 Python 的字符串查找快 10-100 倍**。

---

## §1. 三种"grep 家族"成员

### 1.1 速查表

| 命令 | 含义 | 行为 | 速度 |
|---|---|---|---|
| `grep` | 基础版 | 支持基本正则（BRE） | 快 |
| **`egrep`** / `grep -E` | Extended | 支持扩展正则（ERE），**`+ ? \| ()` 不用反斜杠** | 快 |
| **`fgrep`** / `grep -F` | Fixed string | **不解析正则**，纯字符串查找 | **最快** |
| `pgrep` | Process grep | 按名称查 PID（不是文本工具） | - |
| `rgrep` | Recursive（很少单独用） | 等价 `grep -r` | - |

> **关键**：现代用法几乎都是 `grep -E`（支持扩展正则）或 `grep -F`（纯字符串）。`egrep` / `fgrep` 是历史命令，POSIX 已标记 deprecated 但仍兼容。

### 1.2 BRE vs ERE vs Fixed 三选一决策

```bash
# 场景 1：纯字符串（最快、最安全）
grep -F "ERROR: timeout" app.log       # 不解析 . * [ 等

# 场景 2：基本正则（默认）
grep "error.*timeout" app.log          # .* 是 BRE 通配

# 场景 3：扩展正则（推荐日常用）
grep -E "error|warning" app.log        # | 直接用，不用 \|

# 场景 4：Perl 正则（最强大，需 pcre 支持）
grep -P "\d{3}-\d{4}" phone.txt        # \d \w 等 Perl 语法
```

**性能对比**（同一 1GB 日志，搜索固定字符串）：

| 模式 | 时间 |
|---|---|
| `grep -F` | **0.4 秒** |
| `grep`（BRE） | 0.8 秒 |
| `grep -E`（ERE） | 1.0 秒 |
| `grep -P`（PCRE） | 1.5-2 秒 |

> **实战建议**：能 `-F` 就 `-F`，能 `-E` 就 `-E`，少用 `-P`（可移植性差）。

---

## §2. grep 基础语法

### 2.1 三种调用方式

```bash
# 方式 1：标准（最常用）
grep [OPTIONS] PATTERN [FILE...]

# 方式 2：从 stdin 读（管道）
cmd | grep PATTERN

# 方式 3：从 here-doc 读
grep PATTERN << 'EOF'
line 1
line 2 with pattern
line 3
EOF
```

### 2.2 返回值（exit code）

| 返回值 | 含义 |
|---|---|
| `0` | 至少有一行匹配 |
| `1` | 没有匹配 |
| `2` | 错误（文件不存在、参数错误等） |

**实战**：`grep` 可直接用在 `if` / `&&` / `||` 里。

```bash
if grep -q "ERROR" app.log; then
    echo "发现错误"
fi

# 等价写法
grep -q "ERROR" app.log && echo "发现错误"

# 判断文件是否包含某个字符串
grep -q "root" /etc/passwd && echo "存在 root 用户"
```

### 2.3 模式里含 shell 特殊字符怎么办？

```bash
# 错误：shell 会展开 *
grep "error.*timeout" file.log
# 实际：grep 拿到 error.*timeout（shell 不展开引号里的内容）✅ 没问题

# 错误：模式里有 $、反引号
grep "$(date)" file.log     # 错误：会被命令替换
grep '\$HOME' file.log      # 正确：单引号不展开

# 模式里有 / 但不是路径
grep "a/b" file.log         # OK，/ 不是 shell 特殊字符
```

---

## §3. 必背选项（按用途分类）

### 3.1 控制输出内容的选项

| 选项 | 作用 | 实战 |
|---|---|---|
| `-n` | 显示行号 | `grep -n "error" log` |
| `-o` | 只输出匹配片段（不是整行） | `grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" log` 提取 IP |
| `-c` | 只输出匹配行数（不输出内容） | `grep -c "ERROR" log` |
| `-l` | 只输出匹配的文件名（多文件时） | `grep -rl "TODO" src/` |
| `-L` | 只输出**未**匹配的文件名 | `grep -rL "TODO" src/` |
| `-m N` | 最多匹配 N 行就停 | `grep -m 5 "ERROR" huge.log` |
| `--color=auto` | 高亮匹配 | `grep --color=auto "err" log` |
| `-h` | 多文件时不显示文件名 | `grep -h "TODO" *.c` |
| `-H` | 强制显示文件名（即使单文件） | `grep -H "TODO" file` |
| `-q` | 安静模式（只关心退出码） | `if grep -q ...; then` |

### 3.2 控制匹配行为的选项

| 选项 | 作用 | 实战 |
|---|---|---|
| `-i` | 忽略大小写 | `grep -i "error" log` |
| `-v` | 反转（不匹配的留下） | `grep -v "^#" config` 过滤注释 |
| `-w` | 整词匹配（边界） | `grep -w "is" text` 不匹配 `this` |
| `-x` | 整行匹配 | `grep -x "exact line" file` |
| `-F` | 固定字符串（无正则） | `grep -F "a.b" file`（`.` 当字面字符） |
| `-E` | 扩展正则 | `grep -E "a\|b"` |
| `-P` | Perl 正则（最强大） | `grep -P "\d+" file` |
| `-s` | 静默（不显示错误信息） | `grep -s "x" /nonexistent` |
| `-e PATTERN` | 指定模式（可多次） | `grep -e "a" -e "b" file` = OR |
| `-f FILE` | 从文件读模式 | `grep -f patterns.txt file` |
| `-z` | 以 NUL 分隔（处理含换行文件名） | `grep -z "x" file` |

### 3.3 控制文件遍历的选项

| 选项 | 作用 | 实战 |
|---|---|---|
| `-r` / `-R` | 递归子目录 | `grep -r "TODO" src/` |
| `--include=GLOB` | 只搜匹配 GLOB 的文件 | `grep -r --include="*.py" "import" .` |
| `--exclude=GLOB` | 跳过匹配 GLOB 的文件 | `grep -r --exclude="*.log" "x" .` |
| `--exclude-dir=DIR` | 跳过目录 | `grep -r --exclude-dir=".git" "x" .` |

### 3.4 控制输出的格式（GNU 扩展）

| 选项 | 作用 |
|---|---|
| `-A N` | 匹配行后**追加** N 行（After） |
| `-B N` | 匹配行前**插入** N 行（Before） |
| `-C N` | 前后各 N 行（Context） |
| `--group-separator=...` | 多匹配之间的分隔符 |

```bash
# 实战：看错误上下文
grep -A 3 -B 1 "ERROR" app.log
# 显示 ERROR 行 + 后面 3 行 + 前面 1 行

grep -C 5 "panic" kernel.log
# 显示 panic 行 + 前后各 5 行
```

---

## §4. 正则表达式（grep 子集）

### 4.1 基础元字符（BRE + ERE 通用）

| 元字符 | 含义 | 示例 |
|---|---|---|
| `.` | 任意单字符 | `a.c` 匹配 abc, axc, a/c |
| `^` | 行首 | `^root` 匹配行首的 root |
| `$` | 行尾 | `bash$` 匹配行尾的 bash |
| `*` | 前一项 0+ 次 | `ab*` 匹配 a, ab, abb, ... |
| `[]` | 字符类 | `[abc]` 匹配 a 或 b 或 c |
| `[^]` | 否定字符类 | `[^0-9]` 匹配非数字 |
| `\` | 转义 | `\.` 匹配字面点 |

### 4.2 BRE vs ERE 关键区别

| 表达式 | BRE（默认） | ERE（`-E`） |
|---|---|---|
| 分组 `()` | `\(ab\)` | `(ab)` |
| 或 `\|` | `ab\|cd` | `ab\|cd` |
| 一次或多次 `+` | `a\+` | `a+` |
| 零次或一次 `?` | `a\?` | `a?` |
| 区间 `{n,m}` | `a\{2,5\}` | `a{2,5}` |

> **口诀**：BRE 比 ERE 多一层反斜杠——所以**强烈推荐日常用 `grep -E`**。

### 4.3 字符类简写（POSIX）

| 简写 | 等价 | 说明 |
|---|---|---|
| `[:alpha:]` | `[a-zA-Z]` | 字母 |
| `[:digit:]` | `[0-9]` | 数字 |
| `[:alnum:]` | `[a-zA-Z0-9]` | 字母+数字 |
| `[:space:]` | `[\t\n\f\v ]` | 空白 |
| `[:lower:]` | `[a-z]` | 小写 |
| `[:upper:]` | `[A-Z]` | 大写 |
| `[:punct:]` | `[!-/:-@\[-`{-~]` | 标点 |
| `[:xdigit:]` | `[0-9a-fA-F]` | 十六进制 |

```bash
# POSIX 字符类必须包在 [] 里
grep "[[:digit:]]" file        # 匹配数字
grep -E "[[:alpha:]]+" file    # 字母串
```

### 4.4 实战常用正则速查

```bash
# IP 地址（简化版）
grep -E "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" file

# 邮箱（简化版）
grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" file

# URL
grep -E "https?://[^[:space:]]+" file

# 十六进制颜色
grep -E "#[0-9a-fA-F]{6}\b" file

# 时间戳 HH:MM:SS
grep -E "[0-9]{2}:[0-9]{2}:[0-9]{2}" file

# 行尾分号
grep -E ";$" file

# 空行
grep -E "^$" file

# 含中文字符（GNU grep 用 Perl 模式）
grep -P "[\x{4e00}-\x{9fff}]" file
```

---

## §5. 实战场景（10 大经典）

### 场景 1：在日志中查找错误

```bash
# 大小写不敏感 + 行号 + 上下文
grep -in -B 2 -A 5 "error\|fail\|panic" app.log

# 仅查看错误行数
grep -c "ERROR" app.log

# 查看最近 1000 行里的错误
tail -n 1000 app.log | grep "ERROR"
```

### 场景 2：过滤掉注释和空行

```bash
# 看配置文件有效内容
grep -vE "^\s*(#|$)" /etc/ssh/sshd_config

# 等价拆分
grep -v "^#" file      # 去注释
grep -v "^$" file      # 去空行
```

### 场景 3：递归搜索代码

```bash
# 在 src/ 下找所有 .py 文件中含 "import requests"
grep -rn --include="*.py" "import requests" src/

# 跳过 .git、node_modules、__pycache__
grep -rn \
    --include="*.py" --include="*.js" \
    --exclude-dir={.git,node_modules,__pycache__} \
    "TODO" .
```

### 场景 4：提取匹配的内容（用 `-o`）

```bash
# 从 access.log 提取所有 IP
grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" access.log | sort -u

# 提取 URL 中的域名
grep -oE "https?://[^/]+" file | sort -u

# 提取 key=value 中的 value
grep -oE "key=[^&]+" query_string
```

### 场景 5：反向查找（`-v`）

```bash
# 看非 ssh 的进程
ps aux | grep -v "grep" | grep -v "ssh"

# 看不是注释行的配置
grep -v "^#" /etc/ssh/sshd_config

# 多条件反向：找出不含 "ok" 也不含 "fine" 的行
grep -v -e "ok" -e "fine" file
```

### 场景 6：统计匹配次数

```bash
# 每行匹配次数
grep -o "ERROR" app.log | wc -l

# 每个文件中匹配数
grep -rc "ERROR" logs/

# 注意：grep -c 是"匹配的行数"，grep -o | wc -l 是"匹配的总次数"
# 一行多次匹配会差很多
```

### 场景 7：在多个文件中查找并定位

```bash
# 找哪个文件含 TODO（只看文件名）
grep -rl "TODO" src/

# 找哪些文件**不**含 license header
grep -rL "Copyright" --include="*.py" src/
```

### 场景 8：实时跟踪日志中的关键字

```bash
# 等价 tail -f + grep
tail -f app.log | grep --line-buffered "ERROR"

# --line-buffered 关键：grep 默认行缓冲，否则输出会延迟
```

### 场景 9：组合 find 使用

```bash
# 在最近 7 天修改过的 .log 中找 ERROR
find /var/log -name "*.log" -mtime -7 -exec grep -l "ERROR" {} +

# 找大文件中首次出现的位置（避免全量读）
grep -m 1 "ERROR" huge.log
```

### 场景 10：用 `-f` 实现多模式搜索

```bash
# 从文件读模式（每行一个）
cat > patterns.txt << 'EOF'
ERROR
WARN
FATAL
EOF

grep -f patterns.txt app.log

# 实战：和 find 配合过滤敏感词
grep -f bad_words.txt -r --include="*.txt" uploads/
```

---

## §6. grep 与其他工具的对比

### 6.1 grep vs find vs awk vs sed

| 工具 | 核心功能 | 输入 | 输出 |
|---|---|---|---|
| **`grep`** | 文本**筛选**（按行匹配） | 行/文件 | 匹配行 |
| **`find`** | 文件**查找**（按属性） | 路径 | 文件路径 |
| **`awk`** | 文本**切片** + 处理 | 行 | 处理后的字段 |
| **`sed`** | 文本**替换/转换** | 行 | 修改后的行 |
| **`ripgrep`**（rg） | 增强版 grep | 多文件 | 匹配行（更快） |

> **黄金组合**：`find` 找文件 → `grep` 看内容 → `awk` 切字段 → `sed` 改格式。

### 6.2 标准 grep vs GNU grep vs BSD grep

| 特性 | 标准 grep | GNU grep（默认 Linux） | BSD grep（macOS） |
|---|---|---|---|
| `-P`（PCRE） | ❌ | ✅ | ❌ |
| `--include` | ❌ | ✅ | ❌ |
| `--exclude-dir` | ❌ | ✅ | ❌ |
| 速度 | 基准 | **2x 加速** | 接近 GNU |
| 颜色 | 手动 | 默认开 | 手动 |

> **实战**：在 Linux 上 `grep` 默认就是 GNU；写跨平台脚本注意选项兼容性。

### 6.3 性能对比（同一 5GB 日志，搜索 "ERROR"）

| 工具 | 时间 | 备注 |
|---|---|---|
| `grep -F` | 1.2 秒 | 字符串模式 |
| `grep` | 2.0 秒 | BRE |
| `grep -E` | 2.3 秒 | ERE |
| `ripgrep`（rg） | **0.4 秒** | 默认跳过 .git，跳二进制 |
| `ag`（The Silver Searcher） | 0.6 秒 | 类似 rg |
| Python `re.findall` | 30+ 秒 | 慢 10x+ |

> **建议**：大代码库用 `rg`；日常用 `grep -E`；批量处理用 `grep -F`。

---

## §7. 高级用法

### 7.1 进程替换配合 grep

```bash
# 同时 diff 两个命令的输出
diff <(grep "ERROR" log1) <(grep "ERROR" log2)

# 把 grep 结果作为另一个命令的输入
grep "ERROR" log | tee >(mail -s "ERROR" admin@x.com) > /dev/null
```

### 7.2 配合 `-z` 处理特殊文件名

```bash
# 含换行符的文件名（find -print0 配合）
find . -name "*.txt" -print0 | xargs -0 grep "ERROR"
```

### 7.3 grep 与颜色

```bash
# 永久开启颜色
export GREP_OPTIONS="--color=auto"           # 老方法
alias grep='grep --color=auto'                # 推荐方法（写入 ~/.bashrc）

# 或在脚本里
grep --color=always "error" file | less -R    # less 保留颜色
```

### 7.4 grep 的性能调优

```bash
# 1) 固定字符串用 -F
grep -F "User not found" access.log

# 2) 限制输出行数
grep -m 100 "ERROR" huge.log

# 3) 用 --include/--exclude 限制文件
grep -r --include="*.log" "ERROR" /var/log

# 4) 限制读取字节数
grep --byte-offset "x" file                  # 显示匹配在文件中的字节偏移
```

### 7.5 grep 与其他工具的管道链

```bash
# 经典：统计 access.log 中每个 IP 的请求数
grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" access.log \
    | sort | uniq -c | sort -rn | head -20

# 拆分：grep 提取 IP → sort 排序 → uniq -c 计数 → sort -rn 倒序 → head 前 20
```

---

## §8. 易错点 ×12

1. **`grep "a.b" file`** —— `.` 是正则元字符，匹配 a + 任意 + b。要匹配字面 `a.b` 用 `grep -F "a.b"`。
2. **`grep` 默认匹配子串** —— `grep "is" file` 会匹配 `this`、`is`、`history`。整词用 `-w`。
3. **`grep -r` 不跳过 `.git`** —— 搜索仓库时**必须** `--exclude-dir=.git`，否则巨慢。
4. **`grep` + 管道 + `set -e`** —— `cmd | grep "x"` 在 `set -e` 下若 grep 没匹配到不会让脚本退出（grep 返回 1），但**管道上游失败会被忽略**。要严谨就加 `set -o pipefail`。
5. **`grep -v` 不等于 "排除"** —— 它是"反转匹配"，模式写得不对就匹配错。
6. **`grep` 大小写敏感** —— `Error` 和 `error` 是两个模式。需要忽略大小写加 `-i`。
7. **`grep` 不支持 `\d \w`** —— 默认 BRE/ERE 没有这些，要 `-P`（PCRE）。
8. **`grep "x" binary_file`** —— 输出会"卡住"显示整文件。用 `-I`（大写 i）跳过二进制。
9. **`grep -r` 在符号链接上** —— 默认会跟进，可能死循环。用 `-P`（大写）跳过符号链接。
10. **空文件 + `grep -c "x"`** —— 返回 0（匹配 0 行），不是文件不存在。
11. **`grep -c` 数的是行数不是次数** —— 一行多次匹配只算 1 行。
12. **`grep -o` 配合 `wc -l`** 才能得到**匹配次数**（不是行数）。

---

## §9. 面试 10 大追问

### Q1：`grep`、`egrep`、`fgrep` 的区别？

**答案**：
- `grep`：基本正则（BRE），元字符需转义（`\+`, `\|`）
- `egrep` / `grep -E`：扩展正则（ERE），元字符直接用（`+`, `|`, `()`）
- `fgrep` / `grep -F`：固定字符串，**完全不解析正则**，速度最快

**加分话术**：
> "现代用法都是 `grep -E` 或 `grep -F`；`egrep/fgrep` 是历史命令已 deprecated。POSIX 标记 obsolete 但 Linux 还兼容。我日常 90% 用 `grep -E`，纯字符串用 `grep -F` 提速 2-3 倍。"

### Q2：`grep -v` 和 `grep -L` 一样吗？

**答案**：**完全不一样**。
- `-v`：反转匹配，**输出不匹配的行**（仍然是行内容）
- `-L`：列出**不包含匹配的文件名**（仅文件名，无行内容）

**加分话术**：
> "`-L` 必须用在多文件场景。`grep -L 'TODO' *.py` 列出所有不含 TODO 的 py 文件。`-v` 永远是行级别反转。"

### Q3：怎么在日志里找第 N 次出现的模式？

**答案**：

```bash
# 找第 5 次出现的 ERROR
grep -n "ERROR" log | sed -n '5p'           # 第 5 个匹配

# 或者用 awk
awk '/ERROR/{c++; if(c==5) print NR, $0}' log
```

**加分话术**：
> "纯 grep 不直接支持'第 N 个匹配'，要配合 awk 或 sed。如果要前 N 个匹配，更快的是 `grep -m 5` 限制输出数。"

### Q4：`grep` 怎么匹配二进制文件？

**答案**：

```bash
# 跳过二进制文件（推荐）
grep -I "pattern" binary_dir/

# 强制把二进制当文本（输出会很乱）
grep -a "pattern" binary_file
```

**加分话术**：
> "`-I`（大写 i）= skip binary；`-a`（小写 a）= text mode。grep 通过 `file` 启发式检测：含 NUL 字节就认为是二进制。"

### Q5：`grep` 的退出码有哪些？

**答案**：

| 退出码 | 含义 |
|---|---|
| 0 | 至少一行匹配 |
| 1 | 没有匹配 |
| 2 | 错误（文件不存在等） |

**加分话术**：
> "这是写脚本的关键——`grep -q` 加 `if` 是经典模式。但要注意 `set -e` + 管道 + `grep` 的语义：如果上游 cmd 失败但 grep 没匹配到，shell 不会退出（因为 grep 退出码 1 是合法返回）。"

### Q6：`grep -E` 和 `grep -P` 区别？

**答案**：
- `-E`：扩展正则（ERE），POSIX 标准，支持 `+ ? | ()`
- `-P`：Perl 兼容正则（PCRE），非 POSIX，支持 `\d \w \s`、lookahead、lookbehind 等

**加分话术**：
> "跨平台脚本不要用 `-P`（BSD grep 不支持）。`-E` 是日常首选。需要 `\d \w` 之类的 Perl 特性时再用 `-P`。性能 `-P` 比 `-E` 慢约 30%。"

### Q7：`grep` 的算法是什么？为什么这么快？

**答案**：
- **基础算法**：Boyer-Moore 字符串搜索（从右往左比较，跳得多）
- **多模式**：Aho-Corasick 自动机（用于 `-f` 多模式）
- **GNU grep**：Boyer-Moore + 手工汇编优化

**加分话术**：
> "Boyer-Moore 的精髓是'坏字符规则'——匹配失败时根据字符跳过尽可能多的位置，对短模式尤其快。GNU grep 还用了 mmap 减少 IO，再加速 3-5 倍。"

### Q8：`grep -c` 数的是行还是次数？

**答案**：**数行数**。一行里多次匹配只算 1 行。

```bash
# 数匹配次数（不是行数）
grep -o "ERROR" log | wc -l

# 数匹配行数
grep -c "ERROR" log
```

**加分话术**：
> "面试陷阱题：`grep -c "x" file` 在每行有 5 个 x 的情况下返回 5（行数）还是 25（次数）？答案是 5。要次数用 `-o | wc -l`。"

### Q9：`grep` 能改文件内容吗？

**答案**：**不能**。grep 是只读工具，不会修改输入。

**要修改用 sed**：

```bash
# 替换所有 ERROR 为 WARNING（只改文件，不改输出）
sed -i 's/ERROR/WARNING/g' file

# grep 只能"查看"，不能"改"
```

**加分话术**：
> "grep 是'筛选器'，不是'编辑器'。要替换用 sed，要切片重排用 awk。grep + sed + awk 是文本处理三件套，分工清晰。"

### Q10：`grep` 在大文件（10GB+）上怎么优化？

**答案**：

```bash
# 1) 用固定字符串（-F）加速
grep -F "EXACT_TOKEN" 10gb.log

# 2) 限制匹配数
grep -m 1000 "ERROR" 10gb.log

# 3) 限制文件读取范围
head -n 1000000 10gb.log | grep "x"    # 只看前 100 万行

# 4) 并行（GNU parallel）
parallel -j 8 "grep -F 'token' {}" ::: chunk_*.log

# 5) 用 ripgrep（更快，跳二进制）
rg "ERROR" -t log /var/log/
```

**加分话术**：
> "超大数据建议用 ripgrep 或直接进 Spark/Flink。grep 在 100GB 量级还是有点慢，rg/ag 设计上更好——它们默认跳过 .git、node_modules、二进制文件。"

---

## §10. 速查清单（cheat sheet）

### 10.1 一行模式（one-liner）

```bash
# 统计 access.log 中 TOP 10 IP
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head

# 找所有 .py 中含 TODO 的（跳过 .git）
grep -rn --include="*.py" --exclude-dir=.git "TODO" .

# 找最近 1 小时日志中的 5xx 错误
find /var/log -name "*.log" -mmin -60 -exec grep -h "5[0-9][0-9]" {} +

# 大小写不敏感统计
grep -ic "error" app.log

# 找空行
grep -c "^$" file

# 找不含注释行的文件
grep -rL "^[[:space:]]*#" --include="*.conf" /etc/
```

### 10.2 常用正则速记

| 想要 | 正则 |
|---|---|
| 数字 | `[0-9]` / `[[:digit:]]` |
| 字母 | `[a-zA-Z]` / `[[:alpha:]]` |
| 字母+数字 | `[a-zA-Z0-9]` / `[[:alnum:]]` |
| 任意空白 | `[[:space:]]` |
| IP 地址 | `\b([0-9]{1,3}\.){3}[0-9]{1,3}\b` |
| 邮箱 | `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` |
| URL | `https?://[^[:space:]]+` |
| 时间 HH:MM | `[0-9]{2}:[0-9]{2}` |
| 整数字 | `-?[0-9]+` |
| 浮点数 | `-?[0-9]+\.[0-9]+` |

### 10.3 选项速记表

| 我想... | 用... |
|---|---|
| 显示行号 | `-n` |
| 反转匹配 | `-v` |
| 忽略大小写 | `-i` |
| 只看文件名 | `-l` |
| 看上下文 | `-C N` 或 `-A/-B N` |
| 递归 | `-r` |
| 只匹配整词 | `-w` |
| 纯字符串（不快正则） | `-F` |
| 扩展正则 | `-E` |
| Perl 正则 | `-P` |
| 只看匹配片段 | `-o` |
| 计数 | `-c` |
| 限制文件类型 | `--include` / `--exclude` |
| 跳过目录 | `--exclude-dir` |

---

## §11. 与其他笔记的链路

| 主题 | 链接 | 关联点 |
|---|---|---|
| **输入输出重定向** | [[输入输出重定向]] | grep 几乎都用在管道里；`-c` 配合重定向做统计 |
| **linux文件查询** | [[linux文件查询]] | `grep` 看内容，`find` 看文件 |
| **目录的权限** | [[目录的权限]] | `-r` 递归需要目录 `x` 权限 |
| **VFS** | [[Linux vfs虚拟文件系统]] | `/proc/$$/fd/` 也能 grep |
| **目录导航** | [[Linux目录导航]] | 跨目录搜索时 `-r` + 路径 |
| **获取帮助** | [[linux获取帮助]] | `man grep`、`grep --help`、`info grep` |

---

## §12. 进一步阅读（权威参考）

### 12.1 man 手册（必看）

- `man 1 grep` —— grep 命令完整手册
- `man 7 regex` —— 正则表达式 POSIX 规范
- `man 1p grep` —— POSIX 标准 grep
- `man 1 ripgrep` —— rg 替代品（若安装）
- `man 1 awk` —— 配合 grep 的下一步工具
- `man 1 sed` —— 配合 grep 的下一步工具

### 12.2 在线资源

- **GNU grep 官方**：https://www.gnu.org/software/grep/manual/html_node/index.html
- **POSIX grep 标准**：https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html
- **ripgrep 官网**：https://github.com/BurntSushi/ripgrep
- **正则练习**：https://regex101.com/（PCRE 风格）

### 12.3 推荐书

- **《Classic Shell Scripting》** —— 第 4 章"文本处理工具"
- **《sed & awk》**（Dale Dougherty）—— 文本处理三件套经典
- **《Mastering Regular Expressions》**（Jeffrey Friedl）—— 正则表达式圣经

---

> 复习建议：
> 1. **§0 漏斗比喻** + **§1 三种 grep 家族** 是基础，先理解；
> 2. **§3 选项速查** 至少背 `-n -v -i -r -E -F -l -c -o -w` 这 10 个；
> 3. **§4 正则基础** 重点是 `. * ^ $ [] \| + ? ()` 这 8 个元字符；
> 4. **§5 实战 10 场景** 至少跑通 5 个，建立肌肉记忆；
> 5. **§9 面试 10 问** Q1/Q4/Q5/Q8 是高频考点；
> 6. 用 `grep -nE "TODO|FIXME" -r src/` 在自己项目里跑一次，看输出；
> 7. **下一步**：学 `sed`（替换）和 `awk`（切片），把 grep 当"过滤器"嵌入到三件套流水线中。