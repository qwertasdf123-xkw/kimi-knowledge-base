# Linux vim 编辑器（CentOS-7 实操版）

> 本文是 **vim 编辑器的实操笔记**——按 CentOS-7 教学路径，专注**日常使用**所需的快捷键与命令。所有结论以本地 `man vim` / `vimtutor` 语义为准。
>
> **核心定位**：vim 是 Linux 运维的**默认编辑器**——SSH 远程登录、配置服务器、编辑脚本，几乎不可避免。掌握 vim = 掌握 Linux 的"读写能力"。
>
> **链路呼应**：
> - → [[Linux目录导航]]：vim 配置文件 ~/.vimrc
> - → [[目录的权限]]：vim 编辑文件需要写权限
> - → [[Linux vfs虚拟文件系统|VFS]]：vim 的交换文件 .swp 在 /var/tmp
> - → [[输入输出重定向]]：`vim -` 从 stdin 读
> - → [[grep]] / [[sed]]：vim 内嵌 `:!grep` / `:!sed` 调用外部命令
>
> 备注：编写时网络访问受限，所有结论以本地 `man vim` 语义为准。

---

## §0. 心智模型：vim = 双手钢琴

> vim 不只是"编辑器"——它是**有模式的设计**。理解 vim 的关键是：**不同模式对应不同的"键盘乐器"**。

| 比喻 | vim 对应 | 说明 |
|---|---|---|
| **钢琴键盘** | **键盘** | 同一个字母键在不同模式下功能完全不同 |
| **演奏姿态** | **模式（mode）** | "弹"哪个键取决于你用什么姿态 |
| **作曲家模式** | **Normal（普通模式）** | 思考 + 移动光标 + 小改动 |
| **书写模式** | **Insert（插入模式）** | 像 Word 一样打字 |
| **圈选模式** | **Visual（可视模式）** | 鼠标选中那样选文本 |
| **指挥模式** | **Command（命令行模式）** | `:w` `:q` `:!` 命令 |
| **替换模式** | **Replace（替换模式）** | 一个字符替换一个字符 |

> **核心口诀**：**"Normal 是家，Insert 是去 Insert 的路上"**——vim 90% 的时间你在 Normal 模式。

### 为什么 vim 是个值得学透的编辑器？

- **无处不在**：99% 的 Linux 发行版预装。
- **纯键盘**：学完不用鼠标，效率极高。
- **可编程**：宏、插件、脚本——你能想到的都能做。
- **SSH 友好**：远程编辑唯一靠谱的选择。
- **CentOS 教学**：是教学标准——学 Linux 必学 vim。

---

## §1. 启动与退出

### 1.1 启动 vim

```bash
vim                       # 打开空文件
vim file.txt              # 打开文件（不存在则新建）
vim +n file.txt           # 打开并跳到第 n 行
vim +/pattern file.txt    # 打开并跳到第一个匹配
vim file1 file2 file3     # 打开多个文件（:n 下一个，:N 上一个）
vim -O file1 file2        # 水平分屏
vim -o file1 file2        # 垂直分屏
vim -R file.txt           # 只读模式（view）
vim -d file1 file2        # diff 模式（vimdiff）
```

### 1.2 退出 vim（4 种）

```bash
:q          # 退出（未修改时）
:q!         # 强制退出（不保存）
:wq         # 保存并退出
:x          # 等价 :wq（无修改时不更新时间戳）
ZZ          # Normal 模式下：保存并退出（等价 :wq）
ZQ          # Normal 模式下：强制退出（等价 :q!）
```

> **救命三连**（顺序很重要）：
>
> 1. `Esc` —— 确保在 Normal 模式
> 2. `:q!` —— 强制退出
> 3. `Enter`

---

## §2. 三大模式（核心）

### 2.1 模式图

```
       i / a / o / O / I / A
      ┌──────────────────────►──┐
      │                         │
  [ Normal ]              [ Insert ]
      ▲                         │
      │       Esc                │
      └─────────────────────────┘

       v / V / Ctrl-v
      ┌──────────────────────►──┐
      │                         │
  [ Normal ]              [ Visual ]
      ▲                         │
      │       Esc                │
      └─────────────────────────┘

       :   /   ?   :!
      ┌──────────────────────►──┐
      │                         │
  [ Normal ]              [ Command-line ]
      ▲                         │
      │       Esc                │
      └─────────────────────────┘
```

### 2.2 进入 Insert 模式的 6 个键

| 键   | 作用                 |
| --- | ------------------ |
| `i` | 在光标**前**插入（insert） |
| `I` | 在行**首**插入          |
| `a` | 在光标**后**追加（append） |
| `A` | 在行**尾**追加          |
| `o` | 在下方**新开一行**插入      |
| `O` | 在上方**新开一行**插入      |

### 2.3 模式切换的关键

- `Esc` —— 从任何模式**回到 Normal**
- Normal 模式下 `i/a/o` 进入 Insert
- Normal 模式下 `v/V/Ctrl-v` 进入 Visual
- Normal 模式下 `:` 进入 Command-line

> **面试考点**：vim 默认模式是 **Normal**，不是 Insert。这点和所有 GUI 编辑器相反——这是新手最不适应的地方。

---

## §3. 光标移动（Normal 模式）

### 3.1 基本移动（单字符 / 单行）

| 键 | 等价 | 作用 |
|---|---|---|
| `h` | `←` | 左 |
| `j` | `↓` | 下 |
| `k` | `↑` | 上 |
| `l` | `→` | 右 |

> **口诀**：**`h j k l` 在右手食指下，是 vim 的"基本音符"**。

### 3.2 单词移动（更高效）

| 键           | 作用                      |
| ----------- | ----------------------- |
| `w`         | 跳到**下一个单词**开头（word）     |
| `e`         | 跳到**当前/下一个单词**结尾（end）   |
| `b`         | 跳到**上一个单词**开头（back）     |
| `W` `E` `B` | 同上，但按"空白分隔的字符串"分词（无视标点） |

### 3.3 行内移动

| 键       | 作用                       |
| ------- | ------------------------ |
| `0`     | 行首（绝对）                   |
| `^`     | 行首（第一个非空字符）              |
| `$`     | 行尾                       |
| `f<字符>` | 跳到**当前行下一个** `<字符>`      |
| `F<字符>` | 跳到**当前行上一个** `<字符>`      |
| `t<字符>` | 跳到**当前行下一个** `<字符>`**前** |
| `T<字符>` | 跳到**当前行上一个** `<字符>`**后** |
| `;`     | 重复上一次 f/F/t/T            |
| `,`     | 反向重复                     |

### 3.4 文档级移动

| 键 | 作用 |
|---|---|
| `gg` | 跳到**第 1 行** |
| `G` | 跳到**最后一行** |
| `nG` 或 `:n` | 跳到**第 n 行**（如 `100G` = 第 100 行） |
| `Ctrl-d` | 下**半屏** |
| `Ctrl-u` | 上**半屏** |
| `Ctrl-f` | 下**一屏**（forward） |
| `Ctrl-b` | 上**一屏**（back） |
| `H` | 跳到屏幕**顶**（High） |
| `M` | 跳到屏幕**中**（Middle） |
| `L` | 跳到屏幕**底**（Low） |
| `%` | 跳到匹配的括号（`{} [] ()`） |

### 3.5 跳转列表（vim 的"返回键"）

```bash
Ctrl-o    # 跳到上一个跳转点
Ctrl-i    # 跳到下一个跳转点
# 这两个键让你像浏览器那样前进/后退
```

---

## §4. 编辑命令（Normal 模式）

### 4.1 删除 / 剪切（d = delete）

```bash
x           # 删除当前字符
dw          # 删除一个单词
d$  或 D    # 删除到行尾
d0          # 删除到行首
dd          # 删除当前行（剪贴）
ndd         # 删除 n 行（如 5dd）
dgg         # 删除到文件头
dG          # 删除到文件尾
```

### 4.2 复制（y = yank）

```bash
yw          # 复制一个单词
y$          # 复制到行尾
yy  或 Y    # 复制当前行
nyy         # 复制 n 行
yG          # 复制到文件尾
```

### 4.3 粘贴（p = paste）

```bash
p           # 在光标**后**粘贴
P           # 在光标**前**粘贴
```

### 4.4 撤销 / 重做

```bash
u           # 撤销（undo）
Ctrl-r      # 重做（redo）
U           # 撤销当前行的所有修改
```

### 4.5 替换（r = replace）

```bash
r<char>     # 替换当前字符为 <char>（不进入 Insert）
R           # 进入 Replace 模式（持续替换）
~           # 大小写反转当前字符
```

### 4.6 组合公式：**动词 + 名词**

vim 的命令遵循一个公式：**`[次数] 动词 名词`**

| 动词 | 含义 | 名词 | 含义 |
|---|---|---|---|
| `d` | delete | `w` | word |
| `y` | yank (copy) | `$` | 行尾 |
| `c` | change | `0` | 行首 |
| `v` | visual | `gg` | 文件头 |
| `>` | indent | `G` | 文件尾 |
| `<` | unindent | `i"` | 双引号内 |
| | | `it` | tag 内（HTML） |

```bash
d3w          # 删除 3 个单词
y2j          # 复制向下 2 行
c$           # 删除到行尾 + 进入 Insert（change = delete + insert）
>4j          # 缩进 4 行
di"          # 删除双引号内内容（"hello" → ""）
```

> **口诀**：**"动词定动作，名词定范围"**——记住这个组合公式，vim 命令就不用死记。

---

## §5. 查找与替换

### 5.1 查找

```bash
/pattern         # 向下查找
?pattern         # 向上查找
n                # 重复上一次查找（向下）
N                # 反向重复
*                # 查找当前光标所在的"单词"（向下）
#                # 查找当前光标所在的"单词"（向上）
:set hlsearch    # 高亮匹配（默认就开）
:set nohlsearch  # 关闭高亮
:nohlsearch      # 临时关闭（一次性）
```

### 5.2 替换（substitute）

```bash
:s/old/new           # 当前行第一个匹配替换
:s/old/new/g         # 当前行所有匹配替换（g = global）
:n,m s/old/new/g     # 第 n-m 行替换
:%s/old/new/g        # 整个文件替换
:%s/old/new/gc       # 整个文件替换，每个询问（c = confirm）
:%s/old/new/gi       # 加 i = 忽略大小写
```

### 5.3 实战替换

```bash
# 把所有 foo 改成 bar
:%s/foo/bar/g

# 在第 10-20 行替换
:10,20s/foo/bar/g

# 替换时确认（推荐第一次用）
:%s/foo/bar/gc
# 提示：y 替换 / n 不替换 / a 全部 / q 退出

# 删除所有空行
:g/^$/d

# 只在含 "TODO" 的行替换
:g/TODO/s/foo/bar/g
```

---

## §6. 可视模式（Visual）

### 6.1 三种进入方式

```bash
v           # 字符可视（按字符选）
V           # 行可视（按行选）
Ctrl-v      # 块可视（按矩形选，最强大）
```

### 6.2 实战用法

```bash
# 字符可视：选中一段文本（移动光标）
v3w          # 选 3 个单词
v$           # 选到行尾

# 行可视：选中多行
V5j          # 选 5 行

# 块可视：选矩形（多行同列）
Ctrl-v j j   # 选 2 行同列
# 可以做"多行同时编辑"：
# 1) Ctrl-v 选中多行第一列
# 2) I 进入 Insert
# 3) 输入字符
# 4) Esc —— 所有选中行都加上！

# 操作选中内容（和 d/y/>/< 组合）
d           # 删除选中
y           # 复制选中
>           # 缩进选中
<           # 反缩进选中
```

### 6.3 多行注释（块可视最常用）

```bash
# 给多行加 # 注释
1. Ctrl-v 进入块可视
2. 选多行（光标下移）
3. I 输入 #
4. Esc
# 所有选中行首都有 #

# 取消多行注释（块可视 + 删除）
1. Ctrl-v 进入块可视
2. 选多行第一列
3. x 删除
```

---

## §7. 命令行模式（Command-line，`:` 开头）

### 7.1 文件操作

```bash
:w              # 保存
:w file.txt     # 另存为
:w!             # 强制保存（只读时）
:q              # 退出
:q!             # 强制退出
:wq             # 保存退出
:e file.txt     # 打开另一文件
:bn             # 下一个 buffer（文件）
:bp             # 上一个 buffer
:bd             # 关闭当前 buffer
:ls             # 列出所有 buffer
```

### 7.2 查找 / 替换

```bash
:/{pattern}     # 向下查找
:?{pattern}     # 向上查找
:nohlsearch     # 取消高亮
:%s/old/new/g   # 全文替换
```

### 7.3 设置（set 命令）

```bash
:set number        # 显示行号（简写 :set nu）
:set nonumber      # 关闭行号（简写 :set nonu）
:set relativenumber   # 相对行号（vim 7.3+）
:set ignorecase    # 查找忽略大小写（:set ic）
:set smartcase     # 大写敏感 + 小写忽略（:set scs）
:set tabstop=4     # tab 显示宽度（:set ts=4）
:set shiftwidth=4  # 缩进宽度（:set sw=4）
:set expandtab     # tab 转空格（:set et）
:set autoindent    # 自动缩进（:set ai）
:set hlsearch      # 高亮查找（:set hls）
:set wrap          # 自动换行（:set nowrap 关闭）
:set showcmd       # 显示命令（:set sc）
```

### 7.4 调用外部命令（!）

```bash
:!ls             # 临时执行 ls，看完回 vim
:!date           # 看时间
:r !date         # 把 date 输出**插入**到当前光标
:r !ls           # 把 ls 输出插入
:w !sudo tee %   # 强制保存只读文件（vim 经典）
```

### 7.5 多文件 / 多窗口

```bash
:sp file.txt     # 水平分屏（split）
:vsp file.txt    # 垂直分屏（vsplit）
Ctrl-w w         # 切换窗口
Ctrl-w j/k/h/l  # 移动到下/上/左/右窗口
Ctrl-w q         # 关闭窗口
:tabnew file     # 新建标签页
gt / gT          # 下一个/上一个标签
:tabclose        # 关闭标签
```

---

## §8. 配置文件（.vimrc）

### 8.1 配置文件位置

```bash
~/.vimrc         # 用户级 vim 配置
/etc/vimrc       # 系统级 vim 配置（CentOS）
# 编辑 ~/.vimrc 后让配置生效：
:source ~/.vimrc
# 或重新打开 vim
```

### 8.2 推荐的 CentOS 7 入门配置

```vim
" ~/.vimrc 基础配置（CentOS-7 风格）

" 显示设置
set number                    " 显示行号
set cursorline                " 高亮当前行
set showcmd                   " 显示未完成命令
set wildmenu                  " 命令补全菜单

" 缩进
set tabstop=4                 " tab 显示宽度
set shiftwidth=4              " 缩进宽度
set expandtab                 " tab 转空格
set autoindent                " 自动缩进

" 查找
set hlsearch                  " 高亮匹配
set incsearch                 " 边输入边查找
set ignorecase                " 忽略大小写
set smartcase                 " 大写敏感

" 编辑体验
set syntax on                 " 语法高亮
set encoding=utf-8            " 编码
set backspace=indent,eol,start " backspace 跨模式删除

" 友好行为
set mouse=a                   " 启用鼠标
set clipboard=unnamed        " 共享系统剪贴板
```

### 8.3 实用补充配置

```vim
" 自动保存
autocmd BufWritePre * :silent! let &backup = &backup " 关闭备份文件

" 保存时去掉行尾空格
autocmd BufWritePre *.py :%s/\s\+$//e

" 快速切换行
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==

" 用 jk 代替 Esc（很多 vim 用户的习惯）
inoremap jk <Esc>
```

---

## §9. 实战场景

### 场景 1：编辑配置文件

```bash
vim /etc/ssh/sshd_config
# 修改 Port 22 为 Port 2222
# :%s/^Port 22/Port 2222/g
# :wq
sudo systemctl restart sshd
```

### 场景 2：批量修改多行

```bash
# 给所有以 "function" 开头的行加 //
:g/^function/normal I//
```

### 场景 3：在 vim 里执行 grep

```bash
# 跳到第一个匹配
:grep "ERROR" *.log
# vim 会打开 quickfix 窗口（:cnext 下一个，:cprev 上一个）

# 用 vimgrep（vim 内置，不需要 grep 命令）
:vimgrep /TODO/ **
:copen       # 打开 quickfix 窗口
```

### 场景 4：列编辑（块可视模式）

```bash
# 给每行末尾加分号：
Ctrl-v 选多行（按 $ 到行尾）$  A;  Esc
# 或者更简单：
:%s/$/;/g
```

### 场景 5：写代码时的实用技巧

```bash
# 跳转函数定义（ctags）
:tag function_name
Ctrl-]   # 跳转到定义
Ctrl-t   # 跳回

# 自动补全（在 Insert 模式）
Ctrl-n   # 下一个候选
Ctrl-p   # 上一个候选

# 折叠代码
zf      # 创建折叠
zo      # 打开折叠
zc      # 关闭折叠
zd      # 删除折叠
```

### 场景 6：保存只读文件（无权限时）

```bash
:w !sudo tee %
# 经典 vim 救命命令
# :w 保存 → !sudo 用 sudo → tee % 把 stdin 写到当前文件
```

---

## §10. 速查表（cheat sheet）

### 10.1 一页纸速记

```bash
# === 进入 / 退出 ===
vim file.txt              # 打开
:i / :a / :o              # 进入 Insert
Esc                       # 回 Normal
:wq / :x / ZZ             # 保存退出
:q! / ZQ                  # 强制退出

# === 光标移动（Normal） ===
h j k l                   # 左 下 上 右
0 $                       # 行首 行尾
gg G                      # 文件头 文件尾
w e b                     # 单词前进 单词尾 后退
/pattern ?pattern         # 向下 向上查找
n N                       # 下一个 上一个匹配

# === 编辑（Normal） ===
x                         # 删字符
dd                        # 删行
yy                        # 复制行
p P                       # 粘贴（后/前）
u Ctrl-r                  # 撤销 重做

# === Insert 模式 ===
i a o O                   # 光标前 后 行下 行上
Esc                       # 回 Normal

# === 可视模式 ===
v V Ctrl-v                # 字符 行 块可视
d y > <                   # 在可视模式下：删 复制 缩进 反缩进

# === 替换 ===
:%s/old/new/g             # 全文替换
:%s/old/new/gc            # 加确认

# === 文件 ===
:w :q :wq :x :q!         # 保存 退出 保存退出 保存退出(无改) 强制退出
:e file.txt               # 打开文件
:sp :vsp                  # 水平 垂直分屏
```

### 10.2 必须背的 10 个命令

| 命令 | 作用 |
|---|---|
| `i` `Esc` | 进入/退出 Insert |
| `h` `j` `k` `l` | 移动光标 |
| `:w` `:q` | 保存 / 退出 |
| `dd` `yy` `p` | 删行 / 复制行 / 粘贴 |
| `/pattern` `n` | 查找 + 重复 |
| `:%s/old/new/g` | 全文替换 |
| `u` `Ctrl-r` | 撤销 / 重做 |
| `v` `V` `Ctrl-v` | 进入可视模式 |
| `gg` `G` | 文件头 / 文件尾 |
| `:!cmd` | 执行 shell 命令 |

---

## §11. 易错点 ×15

1. **"我不能退出 vim！"** —— 按 `Esc` → `:q!` → `Enter`。
2. **"我的修改被覆盖了"** —— 没按 `u` 撤销！vim 默认有撤销历史。
3. **`dd` 是删行不是复制** —— 想复制用 `yy`。
4. **`p` 粘贴在光标后** —— 想前粘贴用 `P`。
5. **`/` 查找后默认停在第一个** —— 用 `n` 继续下一个。
6. **:%s 默认不全局** —— `:%s/foo/bar/` 只换每行第一个。要全换加 `g`。
7. **删除大文件会卡** —— vim 是把整个文件读进内存的。GB 级文件用 less / sed。
8. **`:wq` 没权限保存** —— 看是不是文件没写权限。用 `:w !sudo tee %`。
9. **`.swp` 残留文件** —— 编辑时会产生 .swp 文件，正常 vim 退出后自动删除。崩溃后可能残留，删除前确认。
10. **`Ctrl-S` 锁屏** —— 终端误按 Ctrl-S 会"死机"。按 `Ctrl-Q` 解锁。
11. **块可视模式选不连续** —— Ctrl-v 是矩形，要"阶梯形"选区用普通可视 + `o` 切换端点。
12. **`gf` 跳转到文件** —— 当光标在路径上时，按 `gf` 打开该文件（要先在 :set path 加路径）。
13. **`Ctrl-z` 把 vim 挂后台** —— 这不是退出，是挂起。`fg` 回来。
14. **`Esc` 在 Insert 模式不总是立刻生效** —— 某些终端要按两次。也可以用 `Ctrl-c`（功能相同但不等价 Esc）。
15. **新机器没 .vimrc** —— 默认配置很素。CentOS-7 默认在 `/etc/vimrc`，但建议自己写 `~/.vimrc`。

---

## §12. 面试 8 大追问

### Q1：vim 的三大模式是什么？

**答案**：**Normal（普通）、Insert（插入）、Visual（可视）**。外加命令行模式（`:` 开头）和 Replace 模式（`R`）。

```bash
Esc              # 回 Normal
i / a / o        # Normal → Insert
v / V / Ctrl-v   # Normal → Visual
:                # Normal → Command-line
```

**加分话术**：
> "vim 是'有模式'编辑器，和 Word 的'无模式'设计相反。理解这点就能理解为什么 vim 这么高效——同一个键在不同模式下功能不同。90% 时间在 Normal 模式，做'指挥'。"

### Q2：vim 和 emacs 区别？

**答案**：

| 维度 | vim | emacs |
|---|---|---|
| 设计哲学 | 模式化（modal） | 无模式（modeless） |
| 学习曲线 | 陡（要记模式） | 缓（所见即所得） |
| 速度 | 极快（手不离键盘） | 慢（多用 Ctrl 组合） |
| 扩展性 | 脚本 + 插件 | 完整编程环境 |
| 远程友好 | ✅ SSH 极轻 | 较重 |
| 配置语言 | vimscript | elisp |

**加分话术**：
> "两个都是'编辑器之神'。运维场景 vim 更合适（轻、远程友好）；开发场景 emacs 也可以。CentOS-7 教学默认 vim——学 Linux 必学。"

### Q3：`dd` 和 `dw` 区别？

**答案**：
- `dd` —— **删除整行**（包括换行符）
- `dw` —— **删除一个单词**（不删换行符；停在下一个单词开头）

```bash
"hello world"
光标在 h 上：
dw → " world"（删 hello + 空格）
dd → ""（整行没了，包括换行）
```

**加分话术**：
> "vim 的命令都是'动词 + 名词'。d = delete（动词），w = word / d = line（名词）。记住这个公式就能猜命令。"

### Q4：`:%s/old/new/g` 和 `:%s/old/new/gc` 区别？

**答案**：
- `g` —— global（行内所有匹配都换）
- `c` —— confirm（每个匹配询问 y/n）

```bash
:%s/foo/bar/g     # 直接换所有（无确认）
:%s/foo/bar/gc    # 每个匹配询问
# 提示：y 替换 / n 不换 / a 全部 / q 退出 / l 只换这个然后退出
```

**加分话术**：
> "生产脚本批量替换前先 `-gc` 确认——尤其是配置文件，错一个就可能重启失败。我自己的习惯：批量替换前先 `:%s/old/new/gc`，确认无误再 `:%s/old/new/g`。"

### Q5：如何让 vim 显示行号？

**答案**：

```bash
:set number           # 开启（缩写 :set nu）
:set nonumber         # 关闭（缩写 :set nonu）

# 持久化（写入 ~/.vimrc）：
echo "set number" >> ~/.vimrc
```

**加分话术**：
> "运维调试配置文件、查日志必开行号——vim 默认是关的，新手经常踩坑。我个人还开 `set cursorline`（高亮当前行）和 `set relativenumber`（相对行号，配合 `5j` 跳行更直观）。"

### Q6：vim 怎么执行 shell 命令？

**答案**：

```bash
:!ls             # 临时执行 ls（看结果后回 vim）
:r !date         # 把 date 输出插入到当前光标位置
:w !sudo tee %   # 用 sudo 强制保存只读文件
:shell           # 临时开 shell（exit 回来）
```

**加分话术**：
> "vim 是'编辑器壳'——可以在 vim 里调用 shell。这是 vim 比 GUI 编辑器强的地方。`:r !cmd` 把输出读进文件，`:!cmd` 临时执行，`:w !cmd` 把当前 buffer 当 stdin。"

### Q7：vim 在 SSH 远程卡顿怎么办？

**答案**：

```bash
# 1) 关闭语法高亮（最有效）
:syntax off

# 2) 关闭搜索高亮
:set nohlsearch

# 3) 用轻量模式
vim -u NONE file.txt       # 不加载任何配置

# 4) 不要在远程用大文件（用 less / sed / head）
#    vim 把整个文件读进内存，1GB 文件会卡死
```

**加分话术**：
> "远程 vim 卡顿通常是 3 个原因：① 网络延迟（建议 ssh -C 压缩）② 语法高亮（关掉）③ 文件太大（用 less 替代）。我远程编辑大文件都是 less + 局部 sed。"

### Q8：`.swp` 文件是什么？怎么处理？

**答案**：

```bash
# .swp 是 vim 的"交换文件"——崩溃恢复用
# 正常退出 vim 自动删除
# 崩溃后可能残留

# 看残留的 .swp
ls -la .*.swp

# 处理：
rm .file.txt.swp          # 确认不需要恢复后删除
# 或用 vim 打开原文件，会提示"Recover or delete?"
# R 恢复，D 删除，Q 退出
```

**加分话术**：
> "vim 的 .swp 文件是'崩溃保险'——编辑时 vim 把当前 buffer 写入 .swp，突然断电重启能恢复。生产环境的 .swp 残留 = 之前的 vim 没正常退出。git commit 前注意清理（vim 的 .gitignore 里加 `*.swp`）。"

---

## §13. 与其他笔记的链路

| 主题 | 链接 | 关联点 |
|---|---|---|
| **目录导航** | [[Linux目录导航]] | vim 配置文件 ~/.vimrc |
| **目录的权限** | [[目录的权限]] | vim 编辑文件需要写权限 |
| **VFS** | [[Linux vfs虚拟文件系统]] | .swp 交换文件 |
| **输入输出重定向** | [[输入输出重定向]] | `vim -` 从 stdin 读 |
| **grep** | [[grep]] | vim 内嵌 `:!grep` 调用 |
| **sed** | [[sed]] | vim 内嵌 `:!sed` 调用 |
| **awk** | [[awk]] | vim 内嵌 `:!awk` 调用 |
| **文件查询** | [[linux文件查询]] | 编辑前用 `cat / less` 先看 |

---

## §14. 进一步阅读（权威参考）

### 14.1 必看资源

- **`vimtutor`** —— vim 自带教程（终端输入 `vimtutor`），30 分钟速成
- `man vim` —— 完整手册（很长，耐心看）
- `man vimrc` —— 配置文件说明
- `:help` —— vim 内置帮助（按主题搜索）
- `:help quickref` —— 速查表

### 14.2 在线资源

- **vim 官方文档**：https://www.vim.org/docs.php
- **Vim Adventures**：https://vim-adventures.com/（游戏化学习）
- **Open vim**：https://openvim.com/（交互式教程）

### 14.3 推荐书

- **《Vim 实用技巧》**（Drew Neil）—— 进阶必备
- **《Learning the vi and Vim Editors》**（Arnold Robbins）—— 经典
- **《Practical Vim》**（Drew Neil）—— 实战派

### 14.4 CentOS-7 教学配套

- `vimtutor zh_CN` —— 中文版教程
- `/usr/share/vim/vim74/tutor/` —— vim 自带教学文件

---

> 复习建议：
> 1. **§0 双手钢琴比喻** + **§2 三大模式** 是入门必懂；
> 2. **§3 光标移动** + **§4 编辑命令** 是核心（动词+名词公式背熟）；
> 3. **§5 查找替换** 是日常最常用（背 `/` 和 `:%s`）；
> 4. **§6 块可视模式** 多行注释必备；
> 5. **§8 .vimrc** 配置 —— 拷贝一份基础版到 `~/.vimrc`；
> 6. **§11 易错点 15 条** 第 1 条（救命三连）和第 7 条（不要 vim GB 文件）是关键；
> 7. **§12 面试 8 问** Q1/Q3/Q5 是高频；
> 8. **最重要**：跑一次 `vimtutor`（30 分钟，把 vim 从"敌人"变"朋友"）；
> 9. **下一步**：学 Shell 基础（基于 `8. Shell 基础.pdf`），形成"编辑 → 执行"的完整闭环。