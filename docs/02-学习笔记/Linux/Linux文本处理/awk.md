# Linux awk 命令（面试强化版）

> 本文系统讲解 Linux **awk** —— 文本处理的"瑞士军刀之王"。awk 不仅是命令，更是 **完整的小型编程语言**，专为文本处理而生。
>
> **核心定位**：awk 是 **grep + sed 的"加工完成车间"**——grep 筛 → sed 改 → **awk 切、算、汇总、出报表**。90% 的日志统计、数据汇总、报表生成都能用一行 awk 搞定。
>
> **链路呼应**：
> - → [[regex|正则表达式]]：awk 用 ERE；`$0 ~ /pattern/` 是核心匹配
> - → [[输入输出重定向]]：awk 读 stdin、写 stdout；`-f file` 从脚本文件读
> - → [[grep]]：grep 找行 → awk 切字段（黄金组合）
> - → [[sed]]：sed 改行 → awk 切字段（黄金组合）
> - → [[linux文件查询]]：`find -exec awk` 批量处理
> - → [[Linux vfs虚拟文件系统|VFS]]：`/proc/$$/fd/` 也能 awk
> - → [[目录的权限]]：awk 解析 `/etc/passwd` 等权限相关文件
>
> 备注：编写时网络访问受限，所有结论以本地 `man awk` 语义为准。

---

## §0. 心智模型：awk = 流水线加工厂

> 想理解 awk，请先在脑子里装一座"工厂"。

| 比喻 | awk 对应 | 说明 |
|---|---|---|
| **原料传送带** | **输入流**（stdin 或文件） | 一行一行送进来 |
| **每件原料** | **一条记录 / 一行（record）** | 默认 = 一行 |
| **原料上的标签** | **字段（field）** | `$1, $2, $3...` |
| **工厂车间** | **awk 主程序** | 决定每件原料怎么处理 |
| **质检员** | **pattern**（正则） | 决定哪些行被处理 |
| **加工指令** | **{ action }** | 对匹配行做什么 |
| **开业仪式** | **BEGIN { }** | 处理第一行**之前**执行 |
| **关业收尾** | **END { }** | 处理完所有行**之后**执行 |
| **总账本** | **变量**（`NR, NF, FS`） | 跨行累积数据 |
| **出货区** | **stdout** | 处理后的结果 |

> **核心口诀**：**awk = "Aho, Weinberger, Kernighan"**——三位作者姓氏首字母。它是一个**完整的模式匹配 + 处理语言**，核心是 `pattern { action }`。

### 为什么 awk 是个值得理解透的命令/语言？

- **一行搞定 90% 数据处理**：日志分析、报表生成、字段提取、统计汇总。
- **自带编程能力**：变量、循环、条件、数组、函数——不需要写 Python。
- **shell 脚本的"主力打手"**：替代大量 Python 代码，性能更好（更快、更省内存）。
- **gawk（GNU awk）是事实标准**：本篇以 gawk 为准。

---

## §1. awk 基础语法

### 1.1 三种调用方式

```bash
# 方式 1：命令行（最常用）
awk [OPTIONS] 'program' [FILE...]

# 方式 2：从文件读程序
awk -f script.awk [FILE...]

# 方式 3：管道输入
cmd | awk 'program'

# 方式 4：变量赋值（在 program 之前）
awk -v name="Alice" 'BEGIN { print name }'
```

### 1.2 program 的结构：`pattern { action }`

```
awk 'pattern { action }' file
```

| 部分 | 作用 | 默认 |
|---|---|---|
| **pattern** | 决定哪些行被处理 | 全部 |
| **action** | 对匹配行做什么 | 打印整行（等价 `{ print }`） |

```bash
# 默认打印所有行
awk '1' file                    # "1" 永远为真（pattern）

# 只打印含 "error" 的行
awk '/error/' file              # pattern=正则, action 默认 print

# 只打印第 3 列
awk '{ print $3 }' file         # action 显式 print

# 组合：含 error 的行打印第 3 列
awk '/error/ { print $3 }' file
```

### 1.3 完整 program 结构

```
BEGIN { ... }          # 处理第一行之前
pattern1 { action1 }   # 对每行判断 pattern1
pattern2 { action2 }
...
END { ... }            # 处理完所有行之后
```

```bash
# 经典：统计行数
awk 'END { print NR }' file

# 经典：加表头 + 求和 + 平均
awk 'BEGIN { print "Name\tScore"; sum=0 }
     { sum += $2 }
     END { print "Total:", sum; print "Avg:", sum/NR }' scores.txt
```

### 1.4 常用选项

| 选项 | 作用 | 示例 |
|---|---|---|
| `-F FS` | 字段分隔符 | `awk -F: '{print $1}' /etc/passwd` |
| `-v VAR=VAL` | 传变量 | `awk -v name=alice 'BEGIN{print name}'` |
| `-f file` | 从文件读程序 | `awk -f script.awk data` |
| `-W interactive` | gawk 调试 | `awk -W interactive ...` |

---

## §2. 字段（$0, $1, $2...）与记录（NR, NF）

### 2.1 字段速查

| 符号 | 含义 | 默认分隔 |
|---|---|---|
| `$0` | 整行 | 整个 record |
| `$1` | 第 1 个字段 | 空格/TAB |
| `$2` | 第 2 个字段 | 空格/TAB |
| `$NF` | 最后一个字段 | — |
| `$(NF-1)` | 倒数第 2 个字段 | — |
| `NF` | 当前行的字段数 | — |
| `NR` | 当前行号（从 1 开始） | — |
| `FNR` | 当前文件内行号（多文件） | — |
| `FS` | 输入字段分隔符 | 空格 |
| `OFS` | 输出字段分隔符 | 空格 |
| `RS` | 输入记录分隔符 | `\n` |
| `ORS` | 输出记录分隔符 | `\n` |
| `FILENAME` | 当前文件名 | — |
| `ARGC` / `ARGV` | 参数个数 / 参数数组 | — |

### 2.2 默认分隔符 vs 自定义

```bash
# 默认：空格或 TAB
echo "a b c" | awk '{print $1, $2, $3}'     # a b c

# 自定义分隔符：-F 指定
awk -F: '{print $1}' /etc/passwd            # 冒号分隔

# 多字符分隔符（gawk）
awk -F'[:,]' '{print $1, $2}' file          # 冒号或逗号

# 用 FS 变量动态设置
awk 'BEGIN{FS=":"} {print $1}' /etc/passwd
```

### 2.3 NF 与 $NF

```bash
# $NF = 最后一个字段
echo "a b c d" | awk '{print NF, $NF}'      # 4 d

# 倒数第 2 个
echo "a b c d" | awk '{print $(NF-1)}'       # c

# 没有第 0 个字段（$0 = 整行）
```

### 2.4 NR vs FNR（多文件）

```bash
# NR：跨文件总行号
# FNR：当前文件内行号

awk '{print NR, FNR, $0}' file1 file2
# 输出：
# 1 1 file1 line1
# 2 2 file1 line2
# 3 1 file2 line1
# 4 2 file2 line2
```

---

## §3. print 与 printf

### 3.1 `print` 简版

```bash
# print 自动加换行（ORS）
awk '{print $1}' file               # 打印第 1 列

# 多项用逗号分隔（OFS 拼接）
awk '{print $1, $2, $3}' file       # 空格分隔

# print 拼接字符串
awk '{print "User:", $1, "UID:", $3}' /etc/passwd

# print 重定向到文件（shell 重定向）
awk '{print $1 > "users.txt"}' /etc/passwd
```

### 3.2 `printf` 格式化（推荐）

```bash
# printf 不自动加换行
awk '{printf "%-10s %s\n", $1, $2}' file

# 常用格式符
# %s 字符串
# %d 整数
# %f 浮点
# %x 十六进制
# %o 八进制
# %c 单字符

# 宽度控制
awk '{printf "%5d %-15s\n", $1, $2}' file    # 右对齐5字符，左对齐15字符
```

### 3.3 实战 printf

```bash
# 表格化输出
awk 'BEGIN{printf "%-15s %5s %10s\n", "Name", "Age", "Score"}
     {printf "%-15s %5d %10.2f\n", $1, $2, $3}' data.txt

# 输出到文件
awk '{printf "%s\n", $1 > "out.txt"}' file

# 输出到管道
awk '{printf "%s\n", $1 | "sort -u"}' file
```

---

## §4. 模式（Pattern）详解

### 4.1 七种 pattern 类型

| 类型 | 语法 | 含义 | 示例 |
|---|---|---|---|
| **BEGIN** | `BEGIN` | 处理第一行之前 | `BEGIN { FS=":" }` |
| **END** | `END` | 处理所有行之后 | `END { print sum }` |
| **正则** | `/regex/` | 匹配的行 | `/error/` |
| **表达式** | `expr` | 真值（非零/非空） | `NR > 10` |
| **范围** | `pat1, pat2` | 从 pat1 到 pat2 | `/start/,/end/` |
| **空** | （无） | 所有行 | `{ print }` |
| **复合** | `p1 && p2` / `p1 \|\| p2` | 逻辑组合 | `NR>5 && /error/` |

### 4.2 BEGIN 和 END 的精髓

```bash
# BEGIN：初始化（只执行一次）
awk 'BEGIN { print "Start"; FS=":" } file

# END：汇总（只执行一次）
awk '{ sum += $1 } END { print "Total:", sum }' file

# 经典：含表头的报表
awk 'BEGIN { print "=== Report ===" }
     { print $1, $2 }
     END { print "=== End ===" }' data.txt
```

### 4.3 范围 pattern `pat1, pat2`

```bash
# 从含 "start" 到含 "end" 的所有行
awk '/start/,/end/' file

# 第 10 行到最后
awk 'NR==10, NR==20' file           # 同 NR>=10 && NR<=20

# 实战：提取日志中的 stack trace（从 ERROR 到空行）
awk '/ERROR/,/^$/' app.log
```

### 4.4 真值 pattern（条件判断）

```bash
# NR > 10 的行才打印
awk 'NR > 10' file

# 第 3 列 > 100 的行
awk '$3 > 100' file

# 多条件组合
awk '$3 > 100 && $4 == "OK"' file
awk '$1 == "alice" || $1 == "bob"' file
```

---

## §5. 变量与运算

### 5.1 变量类型

| 类型 | 说明 | 示例 |
|---|---|---|
| **标量** | 单值 | `x = 5`, `name = "alice"` |
| **数组** | 关联数组（hash） | `count["alice"] = 3` |
| **数字** | 自动转换 | `"10" + 5 = 15` |
| **字符串** | 默认 | `"abc" + "" = "abc"` |

### 5.2 运算符速查

| 类别 | 运算符 |
|---|---|
| **算术** | `+ - * / % ^`（^ 是幂） |
| **赋值** | `= += -= *= /= %= ^= **` |
| **比较** | `< > <= >= == !=` |
| **逻辑** | `&& \|\| !` |
| **正则匹配** | `~ !~`（匹配/不匹配） |
| **字符串** | `（拼接）`（紧挨着） |
| **三元** | `cond ? a : b` |
| **自增** | `++ --` |

### 5.3 实战运算

```bash
# 求和
awk '{ sum += $1 } END { print sum }' numbers.txt

# 求平均
awk '{ sum += $1; n++ } END { print sum/n }' numbers.txt

# 求最大
awk 'NR==1 { max=$1 } $1>max { max=$1 } END { print max }' numbers.txt
# 简化（gawk）：awk 'BEGIN{getline; max=$1} $1>max{max=$1} END{print max}'

# 字符串拼接
awk '{ print $1 "-" $2 }' file               # 用 - 拼接
awk '{ print $1 $2 }' file                   # 无分隔拼接

# 三元运算
awk '{ print ($1 > 50 ? "high" : "low") }' file
```

---

## §6. 控制流（if / while / for）

### 6.1 if / else

```bash
awk '{ if ($1 > 100) print "high"; else print "low" }' file

# 多行写法
awk '{
    if ($1 > 100)
        print "high"
    else if ($1 > 50)
        print "medium"
    else
        print "low"
}' file
```

### 6.2 while

```bash
# 累加每行的字段
awk '{
    i = 1
    sum = 0
    while (i <= NF) {
        sum += $i
        i++
    }
    print "Row sum:", sum
}' file
```

### 6.3 for

```bash
# 经典 for（数字循环）
awk '{
    for (i = 1; i <= NF; i++) print $i
}' file

# 数组遍历（for-in）
awk '{
    for (key in arr) print key, arr[key]
}' file
```

### 6.4 实战：数据清洗

```bash
# 过滤异常行 + 转换 + 输出
awk '{
    if (NF < 3) {
        print "Skip line", NR, ":", $0 > "/dev/stderr"
        next
    }
    name = $1
    age = $2 + 0                    # 强制转数字
    score = $3 + 0
    if (age > 0 && score > 0)
        print name "\t" age "\t" score
}' data.txt
```

---

## §7. 数组（关联数组）

### 7.1 数组的本质

awk 的数组是 **关联数组（associative array / hash）**——key 是字符串。

```bash
# 用字符串作 key
awk '{ count[$1]++ } END { for (k in count) print k, count[k] }' file

# 用数字作 key
awk '{ sum[NR] = $1 } END { for (i=1; i<=NR; i++) print i, sum[i] }' file
```

### 7.2 经典案例：统计频率

```bash
# 统计每行第 1 列的出现次数
awk '{ count[$1]++ } END { for (k in count) print count[k], k }' file \
    | sort -rn | head

# 统计访问日志中每个 IP 的请求数
awk '{ ip[$1]++ } END { for (k in ip) print ip[k], k }' access.log \
    | sort -rn | head
```

### 7.3 经典案例：分组求和

```bash
# 按第 1 列分组，对第 3 列求和
awk '{ sum[$1] += $3 } END { for (k in sum) print k, sum[k] }' file

# 按第 1 列分组，求平均
awk '{ sum[$1] += $3; n[$1]++ } END {
    for (k in sum) print k, sum[k]/n[k]
}' file
```

### 7.4 多维数组

awk **原生不支持**多维数组，但可以用**字符串 key 模拟**：

```bash
# 用 SUBSEP（默认 \034）分隔
awk '{
    key = $1 SUBSEP $2
    arr[key] += $3
}
END {
    for (k in arr) {
        split(k, parts, SUBSEP)
        print parts[1], parts[2], arr[k]
    }
}' file
```

### 7.5 数组遍历顺序

> **关键陷阱**：awk 的数组遍历顺序是**未定义的**！要排序必须用 `sort` 或自己排。

```bash
# 错的：直接遍历，顺序随机
awk '{a[$1]++} END { for (k in a) print a[k], k }' file

# 对的：sort 排序
awk '{a[$1]++} END { for (k in a) print a[k], k }' file | sort -rn

# 对的：awk 内排序（gawk）
awk '{a[$1]++} END {
    n = asorti(a, sorted)         # gawk 扩展：返回长度，sorted 是排序后的索引
    for (i=1; i<=n; i++) print a[sorted[i]], sorted[i]
}' file
```

---

## §8. 函数

### 8.1 内置函数速查

**字符串函数**：

| 函数 | 作用 | 示例 |
|---|---|---|
| `length(s)` | 字符串长度 | `length("abc") = 3` |
| `substr(s, i, n)` | 子串 | `substr("hello", 2, 3) = "ell"` |
| `index(s, t)` | t 在 s 中的位置 | `index("hello", "ll") = 3` |
| `split(s, arr, sep)` | 分割字符串到数组 | `split("a,b,c", arr, ",")` |
| `gsub(r, s, t)` | 全局替换 | `gsub(/o/, "0", $1)` |
| `sub(r, s, t)` | 单次替换 | `sub(/o/, "0", $1)` |
| `match(s, r)` | 正则匹配位置 | `match("abc123", /[0-9]+/)` |
| `tolower(s)` / `toupper(s)` | 大小写转换 | `tolower("ABC") = "abc"` |
| `sprintf(fmt, ...)` | 格式化字符串 | `sprintf("%05d", 7) = "00007"` |

**数学函数**：

| 函数 | 作用 |
|---|---|
| `int(x)` | 截断 |
| `sqrt(x)` | 平方根 |
| `exp(x)` | e^x |
| `log(x)` | 自然对数 |
| `sin/cos/atan2` | 三角 |
| `rand()` | 0-1 随机数 |
| `srand(x)` | 设随机种子 |

### 8.2 自定义函数

```bash
awk '
function max(a, b) {
    return a > b ? a : b
}

{ print max($1, $2) }
' file

# 实战：定义一个"百分比"函数
awk '
function pct(part, total) {
    if (total == 0) return 0
    return (part / total) * 100
}

{ print pct($1, $2) "%" }
' file
```

### 8.3 实战：常用模式

```bash
# 替换字段内容
awk '{ gsub(/[0-9]+/, "NUM", $1); print }' file

# 提取字段到数组
awk '{ split($1, a, "-"); print a[1], a[2] }' file

# 字符串转数字
awk '{ x = $1 + 0; print x * 2 }' file        # 自动转换

# 数字转字符串（自动）
awk '{ x = 42 "abc"; print x }' file          # "42abc"
```

---

## §9. 实战场景（10 大经典）

### 场景 1：日志 IP 统计 TOP N

```bash
# 经典：统计 access.log 中请求最多的 IP
awk '{ ip[$1]++ } END {
    for (k in ip) print ip[k], k
}' access.log | sort -rn | head -20
```

### 场景 2：计算每行总和 / 平均

```bash
# 每行字段求和
awk '{ sum=0; for (i=1; i<=NF; i++) sum+=$i; print sum }' numbers.txt

# 文件所有数字求和
awk '{ for (i=1; i<=NF; i++) sum+=$i } END { print sum }' numbers.txt

# 含表头的平均值
awk 'NR>1 { sum+=$3; n++ } END { print "Avg:", sum/n }' data.csv
```

### 场景 3：解析 /etc/passwd

```bash
# 列出所有用户名
awk -F: '{ print $1 }' /etc/passwd

# 列出 UID >= 1000 的用户（普通用户）
awk -F: '$3 >= 1000 { print $1, $3 }' /etc/passwd

# 列出所有 shell 是 /bin/bash 的用户
awk -F: '$7 == "/bin/bash" { print $1 }' /etc/passwd

# 统计每种 shell 的用户数
awk -F: '{ n[$7]++ } END { for (k in n) print n[k], k }' /etc/passwd \
    | sort -rn
```

### 场景 4：CSV / TSV 处理

```bash
# CSV：按逗号分隔，输出第 1、3 列
awk -F, '{ print $1, $3 }' data.csv

# TSV：TAB 分隔
awk -F'\t' '{ print $1, $3 }' data.tsv

# 跳过 CSV 标题行
awk 'NR>1' data.csv

# 转换 CSV 为 TSV
awk 'BEGIN{FS=","; OFS="\t"} {$1=$1; print}' data.csv
```

### 场景 5：多文件合并 + 标记来源

```bash
# 合并多个文件，加文件名
awk '{ print FILENAME, $0 }' file1 file2

# 分别统计每个文件的行数
awk '{ count[FILENAME]++ } END { for (f in count) print f, count[f] }' file*

# 跨文件行号 + 当前文件行号
awk '{ print FILENAME, FNR, $0 }' file1 file2
```

### 场景 6：数据校验 / 过滤

```bash
# 过滤第 3 列 > 100 的行
awk '$3 > 100' data.txt

# 过滤异常行（字段数不对）
awk 'NF != 3 { print "Bad line:", NR, $0; next } { print $1 }' data.txt

# 校验 IP 格式（简化）
awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print "OK:", $1 }' file
```

### 场景 7：报表生成

```bash
# 含表头 + 汇总的报表
awk 'BEGIN {
    print "Name\tAge\tScore\tGrade"
}
{
    grade = $3 >= 90 ? "A" : $3 >= 80 ? "B" : $3 >= 70 ? "C" : "F"
    total += $3
    print $1 "\t" $2 "\t" $3 "\t" grade
}
END {
    printf "Total students: %d\nAverage score: %.2f\n", NR, total/NR
}' scores.txt
```

### 场景 8：JSON-like 数据提取（无 jq 时）

```bash
# 提取 JSON 中的 value（粗暴版）
awk -F'"' '/"name"/ { print $4 }' data.json

# 提取 key: value
awk -F': *|"' '/"name"/ { print $4 }' data.json

# 实战：比 jq 快（无需安装）
awk -F'"' '/^[[:space:]]*"/ { print }' data.json
```

### 场景 9：与 grep / sed 配合

```bash
# 三件套黄金管道
grep "ERROR" app.log | sed 's/.*ERROR //' | awk '{ print $1 }'

# awk 单独使用（含过滤）
awk '/ERROR/ { print $1 }' app.log

# 提取并格式化
awk -F: '$3 >= 1000 { printf "%-15s UID=%d\n", $1, $3 }' /etc/passwd
```

### 场景 10：进程 / 系统监控

```bash
# 统计每个进程的 CPU 使用率总和（top 风格）
top -b -n 1 | awk 'NR>7 { sum += $9 } END { print "Total CPU:", sum "%" }'

# 统计每个用户打开了多少文件
lsof 2>/dev/null | awk '{ n[$3]++ } END { for (u in n) print n[u], u }' \
    | sort -rn | head

# 看磁盘使用率最高的挂载点
df -h | awk 'NR>1 { gsub("%",""); print $5, $6 }' | sort -rn | head
```

---

## §10. awk 与 grep / sed 的对比

### 10.1 三大工具的"角色"

| 工具 | 角色 | 何时用 |
|---|---|---|
| **`grep`** | 筛选器 | 找含特定模式的行 |
| **`sed`** | 转换器 | 替换、删除、插入行 |
| **`awk`** | 切片器 + 处理器 | 按字段处理、做统计 |

### 10.2 何时用 awk vs sed

| 场景 | 用 awk | 用 sed |
|---|---|---|
| 按字段处理 | ✅ | 难 |
| 求和/求平均 | ✅ | 难 |
| 多条件分支 | ✅ | 难 |
| 简单替换 | 杀鸡用牛刀 | ✅ |
| 改文件本身 | 复杂 | ✅ `-i` |
| 关联数组 | ✅ 内置 | ❌ |

### 10.3 gawk vs mawk vs BWK awk

| 特性 | gawk（GNU） | mawk（轻量） | BWK awk（原版） |
|---|---|---|---|
| 关联数组 | ✅ | ✅ | ✅ |
| 字符串函数 | 完整 | 较少 | 基本 |
| 网络/时间函数 | ✅（gawk 扩展） | ❌ | ❌ |
| `asort / asorti` | ✅ | ❌ | ❌ |
| 速度 | 较慢 | **最快** | 中等 |
| 默认（Linux） | ✅ | 部分（Debian） | macOS |

> **实战**：Linux 默认 `awk` 是 gawk（Ubuntu 以前用 mawk，后来换了）。日常够用。

---

## §11. 高级用法

### 11.1 awk + shell 变量

```bash
# 在 BEGIN 外用 shell 变量（要在 -v 里传）
name="alice"
awk -v n="$name" 'BEGIN { print "Hello,", n }'

# 多变量
awk -v a=1 -v b=2 'BEGIN { print a+b }'

# 数组变量（复杂）
awk -v arr="a:1,b:2" 'BEGIN {
    split(arr, parts, ",")
    for (i in parts) {
        split(parts[i], kv, ":")
        print kv[1], kv[2]
    }
}'
```

### 11.2 awk 调用 shell 命令

```bash
# 在 awk 里执行 shell 命令（system 函数）
awk '{ system("echo Processing " $1) }' file

# 把字段当命令执行（慎用）
awk '$1 == "calc" { system($2) }' file

# 用 getline 读另一个文件
awk 'BEGIN {
    while ((getline line < "users.txt") > 0)
        print "user:", line
}' file
```

### 11.3 getline 进阶

```bash
# 从文件读一行
awk 'BEGIN { getline first_line < "data.txt"; print first_line }'

# 从管道读
awk 'BEGIN { "date" | getline today; print today }'

# 在主循环里读
awk '{
    if ($1 == "INCLUDE") {
        while ((getline line < $2) > 0)
            print line
    } else {
        print
    }
}' file
```

### 11.4 自定义函数库

```bash
# 写到文件
cat > lib.awk << 'EOF'
function pct(part, total) {
    return total == 0 ? 0 : (part/total)*100
}

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}
EOF

# 调用
awk -f lib.awk '{ print trim($1), pct($2, $3) }' data.txt
```

### 11.5 调试技巧

```bash
# 打印 NR 和 $0（看每行）
awk '{ print "DEBUG:", NR, $0 > "/dev/stderr"; print }' file

# 用 strace 看 syscall
strace -f -e trace=open,read,write awk '...' file

# gawk 调试器
gawk -D -f script.awk file        # 启动调试
```

---

## §12. 易错点 ×15

1. **字段分隔符**：`awk '{print $1}'` 默认按**空格或 TAB**，连续多个空格算 1 个。要其他分隔符用 `-F`。
2. **`$0` 是整行**：`$0 = $1 FS $2 FS ... FS $NF`（FS 是字段分隔符），不能直接 `$0 = "new"` 替换（要用 `$0 = "new"` 也可以）。
3. **修改字段要重建整行**：直接 `$1 = "new"` 后必须 `$1 = $1` 才能让 `$0` 重建。
4. **`NR` vs `FNR`**：多文件时 `NR` 跨文件累加，`FNR` 单文件内。`END { print NR }` 输出总行数。
5. **数组遍历顺序随机**：awk 不保证数组遍历顺序！要排序必须 `sort` 或 `asorti`（gawk）。
6. **`++` 是数字操作**：`count[$1]++` 默认初值为 0（awk 自动初始化），但**字符串拼接要用 `count[$1] = count[$1] "x"`**。
7. **`sub` vs `gsub`**：`sub` 只换第一个，`gsub` 换所有。**默认 awk 的 `sub` 只换第一个**——坑多。
8. **`print` 加换行**：`print` 自动加 ORS（默认 `\n`）；`printf` 不加，必须自己 `\n`。
9. **`getline` 错误返回**：成功 > 0，EOF = 0，错误 < 0。**必须检查返回值**。
10. **`split` 第一个参数是字符串**：要修改的字段是 `i`，不是 `$i`：`split($i, parts, ",")`。
11. **`if` 后的 action 必须用 `{}`**：`awk 'if($1>10) print' file` 是错的，应该是 `awk '{if($1>10) print}' file`。
12. **`%` 格式符要用引号**：`printf %d 5` 不行（shell 会展开 %d）。要 `printf "%d", 5`。
13. **数字 + 字符串 = 数字转换**：`"10" + 5 = 15`，`"10abc" + 5 = 15`（截断到第一个非数字）。但 `"abc" + 5 = 5`（视为 0）。
14. **`mawk` vs `gawk` 差异**：`asort`、`asorti`、`gensub` 等是 gawk 扩展，mawk/BWK 没有。
15. **awk 不支持 `else if`** —— 实际上是支持的（gawk），但要写成 `else if` 紧跟，不是另起行。

---

## §13. 面试 10 大追问

### Q1：`awk`、`nawk`、`gawk` 的关系？

**答案**：
- **awk**：原版 awk（Aho, Weinberger, Kernighan 1977）
- **nawk**：new awk（1985 增强版），是 POSIX awk 的基础
- **gawk**：GNU awk，是 Linux 上最常用的实现，功能最完整

```bash
# 看你的 awk 是什么
ls -l $(which awk)
# /usr/bin/awk -> /etc/alternatives/awk -> /usr/bin/gawk  (Debian/Ubuntu)
# /usr/bin/awk -> /usr/bin/mawk                         (部分发行版)
```

**加分话术**：
> "Linux 上 `awk` 实际上是 `gawk` 的软链。`mawk` 在 Debian 之前是默认，因为它快 5-10 倍但功能少。现在 Debian 也默认 gawk。macOS 用 BWK awk（nawk 子集）。写脚本要兼容就用 gawk 的通用子集。"

### Q2：`awk 'NR==1'` 和 `awk 'NR==1,NR==3'` 区别？

**答案**：
- `NR==1`：只匹配第 1 行
- `NR==1,NR==3`：匹配 1-3 行（**范围 pattern**）

```bash
# 范围 pattern：从 pat1 第一次匹配到 pat2 第一次匹配
awk '/start/,/end/' file

# 注意：pat2 第一次匹配后，下一个 pat1 才会再开始范围
```

**加分话术**：
> "范围 pattern 是 awk 的'杀手特性'——grep 没有。可以用它提取日志的 stack trace（从 ERROR 到空行）。要记住的是：范围只在 pat1 匹配后才开始，到 pat2 匹配后结束；pat2 之后再遇到 pat1，会重新开始新范围。"

### Q3：`awk` 怎么读取 shell 变量？

**答案**：

```bash
# 1) -v 传变量（最常用）
var="hello"
awk -v v="$var" '{ print v, $1 }' file

# 2) 拼到 program 里（不安全，慎用）
awk -v v="$var" 'BEGIN { print "'"$var"'" }'   # 双层引号麻烦

# 3) ENVIRON 数组（gawk 扩展）
awk 'BEGIN { print ENVIRON["HOME"] }' file
```

**加分话术**：
> "面试陷阱：`awk "..." file` 在 program 里直接写 `$var` 拿不到 shell 变量——必须用 `-v`。原因：awk 的 program 是它自己解析的，不经 shell 展开。我日常都是 `-v var="$shell_var"`。"

### Q4：`awk` 的 `print` 和 `printf` 区别？

**答案**：
- `print`：自动加 ORS（默认 `\n`），简单
- `printf`：格式化输出（C 风格），不自动加换行

```bash
# print：输出自动带换行
awk '{print $1}' file

# printf：要自己加 \n
awk '{printf "%-10s %d\n", $1, $2}' file
```

**加分话术**：
> "报表生成必用 `printf`——能精确控制列宽、对齐、补零。`%-10s` = 左对齐 10 字符宽度，`%05d` = 补零到 5 位。这俩是格式化最常用的。"

### Q5：`awk` 怎么实现 SQL 风格的 `GROUP BY`？

**答案**：用**关联数组** + END 遍历。

```bash
# 等价 SELECT category, COUNT(*) FROM t GROUP BY category
awk '{ count[$3]++ } END { for (k in count) print k, count[k] }' data.txt

# 等价 SELECT category, SUM(price) FROM t GROUP BY category
awk '{ sum[$3] += $2 } END { for (k in sum) print k, sum[k] }' data.txt

# 等价 SELECT category, AVG(price) FROM t GROUP BY category
awk '{ sum[$3]+=$2; n[$3]++ } END { for (k in sum) print k, sum[k]/n[k] }' data.txt
```

**加分话术**：
> "awk 的关联数组 = SQL 的 GROUP BY。`count[$3]++` 是 `COUNT(*)`，`sum[$3]+=$2` 是 `SUM(price)`。这就是为什么 awk 在日志分析里几乎是 SQL 替代品——一行实现分组聚合。"

### Q6：`awk` 的 `next` 有什么用？

**答案**：跳过当前行剩余的 action，进入下一行。

```bash
# 跳过空行
awk 'NF == 0 { next } { print $1 }' file

# 多模式：满足一个就跳过其他
awk '
/DEBUG/ { next }
{ print }
' file

# 数据清洗
awk '{
    if (NF < 3) next           # 异常行跳过
    if ($1 == "") next          # 空字段跳过
    print $1, $2, $3
}' file
```

**加分话术**：
> "`next` 是 awk 的流程控制基础——比 `if/else` 干净。多模式 program 里，`next` 让条件复杂的处理变得线性、可读。我日常 80% 的 awk 脚本开头都是一堆 `next` 过滤异常。"

### Q7：`awk` 的 `getline` 怎么用？

**答案**：

| 形式 | 含义 |
|---|---|
| `getline` | 从主输入读下一行到 $0 |
| `getline var` | 从主输入读下一行到 var |
| `getline < "file"` | 从文件读一行 |
| `"cmd" \| getline` | 从管道读 |
| `getline var < "file"` | 从文件读一行到 var |

```bash
# 从另一个文件读
awk 'BEGIN {
    getline first < "data.txt"
    print "Header:", first
}' main.txt

# 从命令读（时间戳）
awk 'BEGIN {
    "date" | getline today
    print "Today:", today
}' file
```

**加分话术**：
> "`getline` 是 awk 的'I/O 扩展点'——能读任意文件/管道/命令。性能上 `getline < file` 比在 BEGIN 里 cat 文件好。生产脚本里常用它读配置文件。"

### Q8：`awk` 怎么写多行 program？

**答案**：

```bash
# 方法 1：用 -f 从文件读
cat > script.awk << 'EOF'
BEGIN {
    print "Start"
    FS = ":"
}

/root/ {
    print "Root found:", $0
}

END {
    print "End"
}
EOF

awk -f script.awk /etc/passwd

# 方法 2：命令行多行（用分号或 ;）
awk 'BEGIN{print "Start"} /root/{print $0} END{print "End"}' /etc/passwd

# 方法 3：把 awk 脚本写到 shell 函数
process() {
    awk '
    BEGIN { ... }
    { ... }
    END { ... }
    ' "$1"
}
```

**加分话术**：
> "生产环境一律 `-f script.awk`——命令行挤 50 行 program 既难看又难调试。养成'复杂 awk 写文件'的习惯。我自己有个 `~/awk-lib/` 目录存常用函数库。"

### Q9：`awk` 在大文件（10GB+）上怎么优化？

**答案**：

```bash
# 1) 早退：找到第一个就停
awk '/ERROR/ { print; exit }' 10gb.log

# 2) 减少字段拆分：直接用 $0
# 慢：awk '{print $1}' file
# 快：awk '/pattern/ {sub(/ .*/, ""); print}' file  （避免 split）

# 3) 用 mawk 替代 gawk（如果不需要 gawk 扩展）
# mawk 比 gawk 快 5-10 倍

# 4) 并行（GNU parallel）
parallel -j 8 "awk '{sum+=\$1} END{print sum}' {}" ::: chunk_*.txt

# 5) 用 awk 的'流式'特性：不需要全读入内存
#    awk 默认逐行处理，内存 O(1)
```

**加分话术**：
> "awk 是流式处理——内存 O(1)，不会 OOM。比 Python 强得多（Python 习惯 readlines 就爆内存）。大文件用 awk 反而最稳。mawk 比 gawk 快 5-10 倍——如果用不到 gawk 扩展（asort、gensub、time 函数），换 mawk 立竿见影。"

### Q10：`awk` 和 Python 怎么处理选型？

**答案**：

| 场景 | 用 awk | 用 Python |
|---|---|---|
| 字段提取 | ✅ | 杀鸡用牛刀 |
| 求和/统计 | ✅ | OK |
| 简单数据清洗 | ✅ | OK |
| JSON/XML 解析 | 难 | ✅ |
| 网络请求 | ❌ | ✅ |
| 数据库 | ❌ | ✅ |
| 复杂逻辑 | 难 | ✅ |
| 性能优先 | ✅（mawk） | 较慢 |
| 安装便捷 | ✅（默认） | 一般有 |

**加分话术**：
> "我的经验法则：一行能搞定用 awk，两行以上考虑 Python。awk 适合'行级别处理'，Python 适合'复杂逻辑+多数据源'。生产 shell 脚本里 80% 是 awk + sed + grep——Python 是后备力量。"

---

## §14. 速查清单（cheat sheet）

### 14.1 一行模式（one-liner）

```bash
# 统计列和
awk '{sum += $1} END {print sum}' numbers.txt

# 求平均
awk '{sum+=$1; n++} END {print sum/n}' numbers.txt

# 求最大
awk 'NR==1{max=$1} $1>max{max=$1} END{print max}' numbers.txt

# 统计第 1 列频次 TOP 10
awk '{count[$1]++} END {for (k in count) print count[k], k}' file | sort -rn | head

# 跳过空行
awk 'NF > 0' file

# 加行号
awk '{print NR": "$0}' file

# 替换字段
awk '{gsub(/old/, "new", $1); print}' file

# 多文件合并 + 来源标记
awk '{print FILENAME, $0}' file1 file2

# 按列排序（按第 3 列）
awk '{print $0}' file | sort -k3

# 表头 + 汇总
awk 'BEGIN{print "==Start=="} {print} END{print "==End=="}' file
```

### 14.2 变量速记

| 变量 | 含义 |
|---|---|
| `$0` | 整行 |
| `$1...$NF` | 字段 |
| `NF` | 当前行字段数 |
| `NR` | 行号（跨文件累加） |
| `FNR` | 当前文件行号 |
| `FS` | 输入字段分隔符（默认空格） |
| `OFS` | 输出字段分隔符 |
| `RS` | 输入记录分隔符 |
| `ORS` | 输出记录分隔符 |
| `FILENAME` | 当前文件名 |
| `ARGC` | 参数个数 |
| `ARGV` | 参数数组 |
| `ENVIRON` | 环境变量数组 |
| `SUBSEP` | 多维数组分隔符（默认 \034） |

### 14.3 函数速记

| 函数 | 类别 | 作用 |
|---|---|---|
| `length(s)` | 字符串 | 长度 |
| `substr(s, i, n)` | 字符串 | 子串 |
| `split(s, a, sep)` | 字符串 | 分割 |
| `gsub(r, s, t)` | 字符串 | 全局替换 |
| `sub(r, s, t)` | 字符串 | 单次替换 |
| `match(s, r)` | 字符串 | 匹配位置 |
| `tolower/toupper` | 字符串 | 大小写 |
| `sprintf(fmt, ...)` | 字符串 | 格式化 |
| `int(x)` | 数学 | 截断 |
| `sqrt(x)` | 数学 | 平方根 |
| `rand()` | 数学 | 随机数 |
| `system(cmd)` | I/O | 执行命令 |
| `getline` | I/O | 读一行 |

### 14.4 模式速记

| 模式 | 含义 |
|---|---|
| `BEGIN` | 处理第一行前 |
| `END` | 处理所有行后 |
| `/regex/` | 正则匹配 |
| `expr` | 真值（非零/非空） |
| `pat1, pat2` | 范围 |
| `p1 && p2` | 逻辑与 |
| `p1 \|\| p2` | 逻辑或 |
| `!p` | 逻辑非 |
| `$1 ~ /x/` | 字段匹配 |
| `$1 !~ /x/` | 字段不匹配 |

---

## §15. 与其他笔记的链路

| 主题 | 链接 | 关联点 |
|---|---|---|
| **输入输出重定向** | [[输入输出重定向]] | awk 读 stdin、写 stdout；`system("cmd")` 写命令输出 |
| **grep** | [[grep]] | grep 找行 → awk 切字段（黄金组合） |
| **sed** | [[sed]] | sed 改行 → awk 切字段（黄金组合） |
| **linux文件查询** | [[linux文件查询]] | `find -exec awk` 批量处理 |
| **VFS** | [[Linux vfs虚拟文件系统]] | `/proc/$$/fd/` 也能 awk 统计 |
| **目录的权限** | [[目录的权限]] | awk 解析 `/etc/passwd` |
| **获取帮助** | [[linux获取帮助]] | `man awk`、`info gawk` |

---

## §16. 进一步阅读（权威参考）

### 16.1 man 手册（必看）

- `man 1 awk` —— POSIX awk 接口
- `man 1 gawk` —— GNU awk 完整手册
- `man 3 regex` —— 正则规范
- `man 1p awk` —— POSIX awk 标准
- `man 1 grep` / `man 1 sed` —— 三件套兄弟

### 16.2 在线资源

- **GNU awk 官方**：https://www.gnu.org/software/gawk/manual/gawk.html
- **POSIX awk 标准**：https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html
- **gawk 教程**：https://www.grymoire.com/Unix/Awk.html（最经典）
- **awk one-liners**：https://github.com/adambard/learnxinyminutes-docs

### 16.3 推荐书

- **《sed & awk》**（Dale Dougherty, Arnold Robbins）—— 三件套圣经
- **《Effective awk Programming》**（Arnold Robbins）—— gawk 专著
- **《Classic Shell Scripting》** —— 第 6 章"awk"

---

> 复习建议：
> 1. **§0 加工厂比喻** + **§1 `pattern { action }` 结构** 是基础；
> 2. **§2 字段变量（$0, $1, NF, NR）** 是核心，必须背熟；
> 3. **§7 关联数组** 是 awk 的杀手特性（GROUP BY 等价）；
> 4. **§9 实战 10 场景** 至少跑通 5 个（IP 统计、CSV 处理是高频）；
> 5. **§13 面试 10 问** Q1/Q3/Q5/Q9 是高频考点；
> 6. 在大日志文件上跑一次 `awk '{ip[$1]++} END{for(k in ip) print ip[k], k}' access.log | sort -rn | head`，体验 awk 的"SQL 替代"威力；
> 7. **三件套毕业**——grep（筛）→ sed（改）→ awk（算）已学完，可以开始组合实战项目。