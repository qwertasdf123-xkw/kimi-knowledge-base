# Linux 文件导航复习（一）：`pwd` 与 `cd`

> 本篇聚焦最基础、但最容易"知其然不知其所以然"的两条命令：`pwd` 与 `cd`。 重点讲清楚 **符号链接场景下** 的行为差异，以及 shell 内部状态（`$PWD` / `$OLDPWD`）和 **shell 内置** 概念。

---

## 1. `pwd` —— 打印当前工作目录

### 1.1 两种模式

`pwd` 看似只做一件事，但它有两种模式，差别在 **是否解析符号链接**：

|选项|名称|行为|
|---|---|---|
|`-L`（默认）|logical（逻辑路径）|显示 `$PWD` 环境变量的值，可能含未解析的符号链接|
|`-P`|physical（物理路径）|解析所有符号链接，输出真实路径|

 $ ln -s /var/log /tmp/log  
 $ cd /tmp/log  
 $ pwd          # /tmp/log         （逻辑，-L 默认）  
 $ pwd -L       # /tmp/log  
 $ pwd -P       # /var/log         （物理，解析了符号链接）  
 $ echo $PWD    # /tmp/log         （shell 缓存的逻辑路径）

### 1.2 `$PWD` 环境变量 vs `pwd -P`

> 关键区别：`$PWD` 是 **shell 维护的字符串**，未必反映真实物理路径。

- 每次 `cd` 成功后，shell 会更新 `$PWD`（逻辑路径）和 `$OLDPWD`（之前的值）。
    
- 想要"真实"路径，必须显式 `pwd -P`。
    
- 因此在脚本里**不要直接信任 `$PWD`**，尤其在符号链接被滥用的目录里。
    

 # 脚本里更稳的写法  
 real_dir=$(cd -- "$some_dir" && pwd -P)

### 1.3 退出码

|情况|退出码|
|---|---|
|正常输出|`0`|
|读取当前目录失败（例如权限被改、目录被删）|`1`|

> 当父目录权限被改（失去 `x` 位）时，`pwd` 会失败，因为内核无法遍历路径——这是上一节"目录权限"的直接体现。

---

## 2. `cd` —— 切换工作目录

### 2.1 为什么 `cd` 必须是 shell 内置

`cd` **不能** 作为外部命令实现：

> 进程的当前工作目录是 **进程级** 属性。子进程改变自己的 cwd 不会影响父进程。 因此 `cd` 必须是 shell 内部命令（builtin），由 shell 进程亲自修改自己的 cwd。

验证：

 $ type cd  
 cd is a shell builtin  
 $ type pwd        # 既有 builtin，也有 /bin/pwd  
 pwd is a shell builtin  
 pwd is /usr/bin/pwd

> 实战意义：在脚本里写 `cd /tmp` 后，下一行直接 `pwd` 看到的就是 `/tmp`，因为脚本在同一个 shell 进程里跑。**但子 shell 会重置**——这是后面"管道陷阱"的重点。

### 2.2 路径形式速查

|形式|含义|示例|
|---|---|---|
|绝对路径|从根 `/` 开始|`cd /etc/nginx`|
|相对路径|从当前目录开始|`cd ../logs`|
|`~`|当前用户的 `$HOME`|`cd ~`|
|`~user`|指定用户的家目录（需权限）|`cd ~root`（会报错）|
|`~+` / `~-`|bash 扩展：当前/上一个 dir（`dirs` 栈）|`cd ~+` 等价 `cd $PWD`|
|`-`|切换到 `$OLDPWD`|`cd -`|
|`..`|父目录|`cd ..`|
|`.`|当前目录（no-op）|`cd .`|
|（空参数）|切到 `$HOME`|`cd`|

### 2.3 经典快捷键

|命令|作用|
|---|---|
|`cd`|回 `$HOME`|
|`cd -`|在**当前目录**与**上一个目录**之间来回切|
|`cd ~`|同 `cd`|

 $ pwd  
 /var/log  
 $ cd /etc  
 $ cd -  
 /var/log  
 $ cd -  
 /etc

### 2.4 `CDPATH` —— `cd` 的"搜索路径"

`PATH` 是给**命令**用的，`CDPATH` 是给**目录**用的，作用类似：

 $ export CDPATH=.:~/projects:/srv  
 $ cd myapp         # 先在 . 找，再 ~/projects 找，再 /srv 找  
 $ pwd  
 /root/projects/myapp

> 写法：冒号分隔，多个根目录。`cd` 会在这些目录中**依次**查找第一个匹配项。
> 
> 陷阱：`CDPATH=.` 是必须的，否则在当前目录找不到时会失败。 调试方法：`cd` 不工作时，先 `echo $CDPATH`。

### 2.5 路径含空格 / 中文 / 元字符

 cd "My Documents"            # 引号  
 cd 'Program Files'           # 单引号更安全  
 cd /tmp/中文目录              # 取决于 locale，建议终端用 UTF-8  
 cd /tmp/file\ with\ space    # 反斜杠转义

> 建议：路径里出现奇怪字符（空格、`$`、`&`），**永远加引号**。 实用技巧：用 `cd "$dir"` 而不是 `cd $dir`——前者对所有怪字符免疫。

### 2.6 退出码

|情况|退出码|
|---|---|
|成功|`0`|
|目录不存在 / 无权限|`1`|
|参数个数 >1|`bash` 等大多数 shell 也会返回 1（POSIX 不强制）|

---

## 3. 符号链接场景：`cd` 的 `-L` vs `-P`

### 3.1 行为差异

 # 准备  
 mkdir -p /tmp/real/dir  
 ln -s /tmp/real/dir /tmp/link  
 ​  
 cd /tmp/link  
 pwd       # /tmp/link  
 pwd -P    # /tmp/real/dir

`cd` 也有 `-L` 和 `-P`：

| 选项   | 默认  | 行为              |
| ---- | --- | --------------- |
| `-L` | 默认  | 保留逻辑路径（沿用符号链接）  |
| `-P` | —   | 切换到物理路径（解析符号链接） |

 cd -L /tmp/link        # pwd 仍显示 /tmp/link  
 cd -P /tmp/link        # pwd 显示 /tmp/real/dir

### 3.2 用 `set` 控制默认行为

set -P     # 改默认值：cd 默认走物理路径（pwd 也跟着显示物理路径）  
set +P     # 恢复默认（保留逻辑路径）

> 实战建议：日常用默认（逻辑路径），**只在脚本**里为了"绝对正确"切到 `set -P`。

### 3.3 综合案例：路径穿越

# 假设当前 PWD=/home/alice，alice 的家目录里有一个指向 /var/www 的符号链接 web  
$ cd ~/web  
$ pwd          # /home/alice/web        （逻辑）  
$ pwd -P       # /var/www              （物理）  
$ cd ..        # 关键差异！  
$ pwd          # /home/alice            （基于逻辑 PWD）  
$ pwd -P       # /var                  （基于物理 PWD）

> 这就是 `..` 在两种模式下走不同路径的根源。

---

## 4. `$OLDPWD` 与 `cd -`

`cd -` 不是语法糖，而是 POSIX 标准行为：

$ echo $OLDPWD  
/home/alice  
$ cd /etc  
$ echo $OLDPWD  
/home/alice        # cd 后 OLDPWD 自动更新为"切换前"的 PWD  
$ cd -  
/home/alice  
$ cd -  
/etc

实现原理：`cd -` 实际等价于 `cd "$OLDPWD" && OLDPWD=$PWD`（POSIX 描述）。 `dirs` 栈也参与工作（见下节）。

---

## 5. 扩展工具：`pushd` / `popd` / `dirs`

`cd` 只能记**上一个**目录。`pushd` / `popd` 用栈记一串。

|命令|作用|
|---|---|
|`pushd /a/b`|把当前目录压栈，切到 `/a/b`|
|`pushd`|栈顶两个目录对调|
|`popd`|弹栈，回到上一个|
|`dirs`|显示栈内容（默认一行）|
|`dirs -v`|每行带编号（推荐）|
|`dirs -c`|清空栈|

$ pushd /etc  
/etc ~  
$ pushd /var  
/var /etc ~  
$ dirs -v  
0  /var  
1  /etc  
2  ~  
$ pushd +1      # 切到栈里第 1 个（从 0 起）  
/etc /var ~  
$ popd  
/var ~

> bash 还支持 `pushd +N` / `popd +N` 按编号操作；zsh 还支持 `cd -<NUM>` 按编号回退。

---

## 6. bash 的几个"省事"扩展

|特性|启用 / 控制|效果|
|---|---|---|
|`shopt -s autocd`|bash 4+|输入目录名直接 `cd` 进去（不用 `cd` 命令）|
|`shopt -s cdspell`|bash|纠正拼写错误（`cd /ect` → `cd /etc`）|
|`set -P` / `set +P`|切换物理/逻辑默认|见 3.2|
|`CDPATH`|环境变量|见 2.4|
|`PROMPT_COMMAND='pwd'`|提示符|让提示符始终显示绝对路径|
|`dirs -v`|内部|栈式回退|

shopt -s autocd cdspell       # 推荐在交互 shell 启用

---

## 7. 常见陷阱与排错

### 7.1 管道 / 子 shell 里 `cd` 不生效

$ pwd  
/home/alice  
$ cd /tmp | pwd  
/home/alice    # 管道右侧是新进程，cd 在子 shell 里执行，没改父 shell

> 解法：用 `{ cd /tmp && pwd; }` 或 `( cd /tmp && pwd )` 显式子 shell，或直接用 `cd /tmp && pwd`。

### 7.2 `cd` 失败却没察觉

`cd` 失败时**不会改变当前目录**，但 bash 默认**不会报错**。在脚本里这是大坑：

cd /wrong/path || exit 1     # 显式检查  
# 或者  
set -e                        # 任何命令失败立即退出脚本（bash 特性）

### 7.3 `cd` 成功但路径已被删

$ pwd  
/tmp/foo  
$ cd ..  
$ rm -rf /tmp/foo  
$ cd /tmp/foo  
$ pwd  
pwd: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory  
# 解决办法：cd 到已知有效目录  
$ cd /tmp; pwd  
/tmp

> `PWD` 指向已删除目录时，shell 提示符会卡住，必须先 `cd` 到一个有效目录。

### 7.4 `cd` 与脚本里的 `set -e`

set -e  
cd /nonexistent             # 这条失败 → 脚本退出  
echo "never run"

但 `cd foo || true` 不会触发 `-e` 退出。

### 7.5 软链环（symlink loop）

$ ln -s loop loop  
$ cd loop  
# bash 探测到环：cd: error: too many levels of symbolic links

---

## 8. 速查表

|场景|命令|
|---|---|
|回主目录|`cd` / `cd ~`|
|切到上一个目录|`cd -`|
|看真实物理路径|`pwd -P`|
|看当前 shell 缓存路径|`echo $PWD`|
|启用 autocd + cdspell|`shopt -s autocd cdspell`|
|跨目录搜索|`export CDPATH=.:~/projects`|
|栈式导航|`pushd / popd / dirs -v`|
|永远加引号|`cd "$dir"`|
|失败立即退出|`cd /path \\|\\| exit 1`|
|脚本里求真实路径|`real_dir=$(cd -- "$d" && pwd -P)`|

---

## 9. 易错点（小结）

1. **`$PWD` 不等于物理路径**——脚本里要用 `cd ... && pwd -P`。
    
2. **`cd` 是 builtin**——子 shell 里的 `cd` 不影响父 shell。
    
3. **`cd -` 走 `$OLDPWD`**——也是 builtin 行为。
    
4. **管道右侧看不到 `cd` 效果**——管道会开子 shell。
    
5. **目录被删后 `pwd` 会失败**——必须先 `cd` 到有效目录。
    
6. **没启用 autocd 时，敲目录名不会切**——很多人误以为命令"不工作"。
    
7. **`CDPATH` 必须含 `.`**——否则当前目录下的目录都进不去。
    
8. **路径里有空格 / 中文**——永远加引号。
    
9. **`cd` 失败默认不报错**——脚本里要 `set -e` 或显式 `|| exit 1`。
    
10. **`cd /a && cd -` 的结果**——`-` 切回到 `/a` 之前的目录（不是 `/a`）。
    

---

## 10. 进一步阅读

- `man 1 pwd` —— 注意区分 bash builtin 和 `/bin/pwd`
    
- `man 1 bash` 内 `CD`、`PWD`、`OLDPWD`、`CDPATH` 章节
    
- `help cd` / `help pwd`（bash 内部帮助）
    
- `info bash` "Directory Stack Builtins" 一节
    
- `man 1 pushd`（多数系统其实是 `man bash` 里的部分）
    

---

> 复习建议：
> 
> 1. 在自己机器上构造一个符号链接，亲自跑一遍 `cd` + `pwd` + `pwd -P`；
>     
> 2. 写一个 5 行的 bash 脚本，故意漏掉 `cd ... || exit`，观察 `set -e` 前后的差异；
>     
> 3. 用 `dirs -v` 体验一下"目录栈"在多项目切换时的便利。
>