# Linux VFS（虚拟文件系统）

> 本篇把前面所有"用户态命令"（`ls` / `cd` / `cat` / `find` / `cp` / `stat` ...）的**内核实现路径**打通。 重点：
> 
> 1. **4 大核心对象** 与 **4 大 operations 表** 之间的对应关系；
>     
> 2. **路径解析**的现代实现（RCU walk + seqlock + refcount）；
>     
> 3. **dcache / page cache** 让你"读文件快"的根本原因；
>     
> 4. **VFS 与前文命令的精确映射**——每条命令背后调用了哪些 inode_operations / file_operations。
>     
> 
> 备注：编写时网络访问受限，所有结论以 `Documentation/filesystems/` 与 `fs/` 源码语义为准。文末给出权威参考。

> **📔 专题深挖**：[[VFS-四个核心对象辨析]] | [[VFS-rm与inode引用计数]] | [[VFS-page-cache深度解析]]

---

## 0. 为什么要 VFS？

Linux 内核要同时支持 ext4 / xfs / btrfs / nfs / ntfs（读写） / fat / procfs / sysfs / tmpfs / overlayfs ... **20+ 种文件系统**。如果没有抽象层：

- 进程要"知道"自己操作的是哪种 FS（不可能）；
    
- 每个 FS 都要重新实现 `open` / `read` / `write` / `stat` / ... 的语义（巨量重复）；
    
- 文件系统切换 = 用户态命令重写。
    

**VFS = "文件"这个概念的统一抽象**。它向上提供**统一 API**（`syscall`），向下对接**具体 FS 的实现**。VFS 自己不存数据，**所有数据都在具体 FS 里**。

> 一句话：**VFS 是"通用文件模型"，是接口规范，不是一个文件系统。**

---

## 1. 四个核心对象（4 objects）

> 这是 VFS 的全部家底。背下来。常见混淆点见 [[VFS-四个核心对象辨析]]。

### 1.1 `super_block` —— 一个**已挂载的文件系统实例**

 struct super_block {  
     struct list_head    s_list;          // 链表  
     dev_t               s_dev;           // 设备号  
     unsigned long       s_blocksize;     // 块大小  
     loff_t              s_maxbytes;      // 最大文件大小  
     struct file_system_type *s_type;     // 指向 file_system_type  
     const struct super_operations *s_op; // ★ 操作表  
     struct dentry       *s_root;         // 根 dentry  
     struct list_head    s_inodes;        // 本 FS 的 inode 链表  
     struct list_head    s_mounts;        // 挂载相关  
     struct block_device *s_bdev;         // 关联的块设备（本地 FS）  
     void                *s_fs_info;      // 具体 FS 私有数据（ext4_sb_info 等）  
     // ...  
 };

> **关键点**：`super_block` = **一个挂载实例**。 同一块盘挂两次 → 2 个 `super_block`；不同盘同 FS → 2 个 `super_block`。

**生命周期**：注册 → mount → 使用 → umount → 销毁。

### 1.2 `inode` —— 文件的"**元数据**"

 struct inode {  
     umode_t             i_mode;          // 文件类型 + 权限（rwxrwxrwx）  
     unsigned int        i_nlink;         // 硬链接数  
     kuid_t              i_uid;           // 属主  
     kgid_t              i_gid;           // 属组  
     loff_t              i_size;          // 文件大小  
     struct timespec64   i_atime;         // 访问时间  
     struct timespec64   i_mtime;         // 修改时间  
     struct timespec64   i_ctime;         // 元数据变更时间  
     struct timespec64   i_btime;         // 创建时间（btime）  
     const struct inode_operations  *i_op;  // ★ inode 操作表  
     const struct file_operations   *i_fop; // 默认 file 操作  
     struct super_block  *i_sb;           // 所属 super_block  
     struct address_space *i_mapping;     // 页缓存  
     void                *i_private;      // 具体 FS 私有数据  
     // ...  
 };

> **关键点**：`inode` 不存文件名（文件名在 dentry 里），不存内容（内容在 page cache / 块设备）。 `inode` 唯一标识一个文件（在同一 FS 内）。`ls -i` 看到的就是 `inode` 编号。

**`inode.mode` 编码**：

| 高 4 位                | 含义       |
| -------------------- | -------- |
| `S_IFREG` (0100000)  | 普通文件 `-` |
| `S_IFDIR` (0040000)  | 目录 `d`   |
| `S_IFLNK` (0120000)  | 符号链接 `l` |
| `S_IFBLK` (0060000)  | 块设备 `b`  |
| `S_IFCHR` (0020000)  | 字符设备 `c` |
| `S_IFIFO` (0010000)  | 命名管道 `p` |
| `S_IFSOCK` (0140000) | 套接字 `s`  |

低 12 位是 `rwxrwxrwx` + sticky/setuid/setgid。

### 1.3 `dentry` —— "**一个目录项**"（名字 + inode 的绑定）

 struct dentry {  
     unsigned int        d_flags;  
     seqcount_spinlock_t d_seq;           // RCU walk 用  
     struct hlist_bl_node d_hash;         // 哈希链表（dcache）  
     struct dentry       *d_parent;        // 父 dentry  
     struct qstr         d_name;           // 文件名（hash + name）  
     struct inode        *d_inode;         // 关联的 inode  
     const struct dentry_operations *d_op; // ★ dentry 操作表  
     struct super_block  *d_sb;  
     void                *d_fsdata;  
     struct list_head    d_subdirs;        // 子目录  
     struct hlist_node   d_alias;         // 反向连到 inode  
     // LRU 链表  
     struct list_head    d_lru;  
     struct list_head    d_child;          // 父目录的子节点链表  
     // ...  
 };

> **关键点**：
> 
> - `dentry` = "**文件名 + inode 指针**"的内存缓存项；
>     
> - **不一定落盘**——只在内存里；
>     
> - 同一文件多名字（硬链接）= 多个 dentry 指向同一 inode；
>     
> - 软链接的 dentry 是另一种：它的 `d_inode` 是个**伪 inode**（含链接路径）。
>     

**`dentry` 是 VFS 里最容易被忽视、但**最重要的对象**：

- `ls` 第一次要遍历目录项时，会查 dcache；
    
- dcache 命中 → 立即返回（不调底层 FS 的 `readdir`）；
    
- dcache miss → 调具体 FS 的 `iterate_dir` → 拿到 (name, inode) → **新建 dentry** → 放入 dcache。
    

### 1.4 `file` —— **进程**打开的一个文件

 struct file {  
     union {  
         struct llist_node   fu_llist;  
         struct rcu_head     fu_rcuhead;  
     } f_u;  
     struct path         f_path;          // 含 dentry + vfsmount  
     const struct file_operations *f_op;  // ★ file 操作表（可能与 i_fop 不同）  
     void                *private_data;   // open() 私有数据  
     loff_t              f_pos;           // ★ 当前文件偏移  
     atomic_long_t       f_count;         // 引用计数  
     unsigned int        f_flags;         // O_RDONLY / O_WRONLY / O_RDWR / O_CREAT ...  
     fmode_t             f_mode;          // FMODE_READ / FMODE_WRITE / FMODE_LSEEK ...  
     struct mutex        f_pos_lock;  
     // ...  
 };

> **关键点**：
> 
> - `struct file` 是**进程级的**（存在 `fdtable` 里）；
>     
> - 同一文件被两个进程打开 = 2 个 `struct file` + 1 个 `inode` + 1 个 `dentry`；
>     
> - 同一进程 `dup` 一个 fd = 2 个 `file`，可能共享 offset（除非用 `O_APPEND` 或 `pread`）；
>     
> - `f_pos` = 当前偏移，`lseek` / `read` / `write` 改它。
>     

### 1.5 4 大对象的"四元组"

|对象|作用范围|与谁关联|存储位置|
|---|---|---|---|
|`super_block`|挂载点|块设备 / 伪 FS|内存（可同步回设备元数据）|
|`inode`|文件|1 个 super_block|设备 + 内存（inode cache）|
|`dentry`|路径名|1 个 inode|**仅内存**（dcache）|
|`file`|进程级|1 个 dentry|**仅进程**（fdtable）|

> **数据流**：文件名 → dentry → inode → 块设备 / page cache。

---

## 2. 四个 Operations 表（4 ops tables）

> FS 的"能力"由 4 张表决定。每张表是**函数指针集合**。

### 2.1 `super_operations` —— 文件系统级

 struct super_operations {  
     struct inode *(*alloc_inode)(struct super_block *);  
     void (*destroy_inode)(struct inode *);  
     void (*dirty_inode)(struct inode *, int flags);  
     int (*write_inode)(struct inode *, struct writeback_control *);  
     int (*drop_inode)(struct inode *);  
     void (*evict_inode)(struct inode *);  
     void (*put_super)(struct super_block *);  
     int (*sync_fs)(struct super_block *, int);  
     int (*freeze_fs)(struct super_block *);  
     int (*unfreeze_fs)(struct super_block *);  
     int (*statfs)(struct dentry *, struct kstatfs *);  
     int (*remount_fs)(struct super_block *, int *, char *);  
     void (*umount_begin)(struct super_block *);  
     // ...  
 };

> "挂载时干什么"、"卸载时干什么"、"统计空间"、"写回"。

### 2.2 `inode_operations` —— **一个 inode**能做什么

 struct inode_operations {  
     struct dentry *(*lookup)(struct inode *, struct dentry *, unsigned int);  
     const char *(*get_link)(struct dentry *, struct inode *, struct delayed_call *);  
     int (*create)(struct inode *, struct dentry *, umode_t, bool);  
     int (*link)(struct dentry *, struct inode *, struct dentry *);  
     int (*unlink)(struct inode *, struct dentry *);  
     int (*symlink)(struct inode *, struct dentry *, const char *);  
     int (*mkdir)(struct inode *, struct dentry *, umode_t);  
     int (*rmdir)(struct inode *, struct dentry *);  
     int (*mknod)(struct inode *, struct dentry *, umode_t, dev_t);  
     int (*rename)(struct inode *, struct dentry *, struct inode *, struct dentry *, unsigned int);  
     int (*setattr)(struct dentry *, struct iattr *);  
     int (*permission)(struct inode *, int);  
     int (*getattr)(const struct path *, struct kstat *, u32, unsigned int);  
     // ...  
 };

> **关键**：`lookup` 是路径解析的"组件"——`/` 之后每段名字都调它。 `mkdir` / `rmdir` / `unlink` / `link` / `rename` 都是它。 `permission` 在每次打开/读/写时被 VFS 调用（决定是否放行）。

### 2.3 `dentry_operations` —— 极少数 FS 用

 struct dentry_operations {  
     int (*d_revalidate)(struct dentry *, unsigned int);  
     int (*d_weak_revalidate)(struct dentry *, unsigned int);  
     int (*d_hash)(const struct dentry *, struct qstr *);  
     int (*d_compare)(const struct dentry *, unsigned int, const char *, const struct qstr *);  
     int (*d_delete)(const struct dentry *);  
     void (*d_release)(struct dentry *);  
     void (*d_prune)(struct dentry *);  
     void (*d_iput)(struct dentry *, struct inode *);  
     char *(*d_dname)(struct dentry *, char *, int);  
     // ...  
 };

> 网络 FS（NFS / CIFS）大量用 `d_revalidate`（验证远端条目是否仍然有效）。 大多数本地 FS 留空——用通用实现。

### 2.4 `file_operations` —— 一个**已打开的文件**能做什么

 struct file_operations {  
     loff_t (*llseek)(struct file *, loff_t, int);  
     ssize_t (*read)(struct file *, char __user *, size_t, loff_t *);  
     ssize_t (*write)(struct file *, const char __user *, size_t, loff_t *);  
     ssize_t (*read_iter)(struct kiocb *, struct iov_iter *);  
     ssize_t (*write_iter)(struct kiocb *, struct iov_iter *);  
     int (*mmap)(struct file *, struct vm_area_struct *);  
     unsigned long mmap_supported_flags;  
     int (*open)(struct inode *, struct file *);  
     int (*release)(struct inode *, struct file *);  
     int (*fsync)(struct file *, loff_t, loff_t, int);  
     int (*flush)(struct file *, fl_owner_t id);  
     int (*lock)(struct file *, int, struct file_lock *);  
     // poll / ioctl / splice / sendpage ...  
     long (*unlocked_ioctl)(struct file *, unsigned int, unsigned long);  
     int (*iterate)(struct file *, struct dir_context *);  
     int (*iterate_shared)(struct file *, struct dir_context *); // readdir  
     // ...  
 };

> 几乎所有进程能对文件做的操作都在这里。 `iterate_shared` = `readdir`（`ls` 的实现路径）。

### 2.5 四张表的"调用方"

| 表                   | 谁来填                  | 谁来调                             |
| ------------------- | -------------------- | ------------------------------- |
| `super_operations`  | 具体 FS 在 `mount` 时填   | VFS 主动调（mount/umount/writeback） |
| `inode_operations`  | FS 在 `read_inode` 时填 | VFS 调（路径解析/创建/删除）               |
| `dentry_operations` | 可选（多数 FS 不填）         | VFS 调（验证/比较名字）                  |
| `file_operations`   | FS 在 `open` 时填       | VFS 调（read/write/llseek/...）    |

---

## 3. 文件描述符与 `fdtable`

// 每个进程  
struct files_struct {  
    atomic_t         count;          // 引用计数  
    struct fdtable   *fdt;  
    struct fdtable   fdtab;          // 内嵌的默认 fdtable  
    spinlock_t       file_lock;  
    // ...  
};  
  
struct fdtable {  
    unsigned int     max_fds;        // 当前大小  
    struct file     **fd;            // fd 数组  
    unsigned long   *close_on_exec;  // 位图：CLOEXEC 标记  
    unsigned long   *open_fds;       // 位图：已使用 fd  
    struct rcu_head rcu;  
};

> **fd 本质**：`fd` 是一个**数组下标**。 `fd=0/1/2` 默认分配给 stdin/stdout/stderr。 `dup()`、`dup2()`、`fcntl(F_DUPFD)` 都复制 fd → 多个 fd 指向同一 `struct file`。

---

## 4. 路径解析：从字符串到 inode

> 进程给 VFS 一条路径（如 `/home/alice/file.txt`），VFS 怎么一步步找到对应的 `inode`？

### 4.1 现代 Linux 路径解析的两阶段

Linux 4.0+ 的路径解析拆成**两阶段**（`fs/namei.c`）：

1. **RCU walk（无锁快路径）**：在 `rcu_read_lock` 下用 RCU 走 dcache，**不允许睡眠**。
    
2. **REF walk（慢路径 / 引用 walk）**：拿 dentry 的 refcount，慢但能睡眠、能改 dcache。
    

|阶段|锁|允许睡眠|性能|何时退回|
|---|---|---|---|---|
|RCU walk|RCU|❌|极快|遇 `d_revalidate` / 不可解析链接 / .need_revalidate|
|REF walk|refcount + seqlock|✅|慢|——|

> 关键函数：`link_path_walk()` → `walk_component()` → `inode->i_op->lookup()`。

### 4.2 完整流程

sys_open("/a/b/c", O_RDONLY)  
└── do_sys_open()  
    └── do_filp_open()  
        └── path_openat()  
            ├── path_init()        // 起点：当前 cwd 或 AT_FDCWD  
            ├── link_path_walk()   // ★ 走完所有中间目录  
            │   └── walk_component()  
            │       ├── 查 dcache（rcu）  
            │       ├── miss → inode->i_op->lookup()  
            │       ├── 处理 ".", "..", 符号链接  
            │       └── 退回 REF walk（如需要）  
            ├── lookup_last()      // 走最后一段  
            └── do_last()          // open/create/symlink/etc.  
                ├── may_lookup()    // 权限检查  
                └── vfs_open()     // 创建 struct file，填 f_op

### 4.3 关键 LOOKUP_* 标志

LOOKUP_FOLLOW       // 跟随最后一段的符号链接  
LOOKUP_DIRECTORY    // 最后一段必须是目录  
LOOKUP_OPEN         // 用于 open()  
LOOKUP_CREATE       // 不存在则创建  
LOOKUP_EXCL         // 排他创建（O_EXCL）  
LOOKUP_RCU          // RCU walk 模式  
LOOKUP_REVAL        // 重新验证 dcache  
LOOKUP_JUMPED       // 中间有绝对路径跳转

### 4.4 路径解析的边界

- **`MAXSYMLINKS = 8`**：超过报 `ELOOP`（`cd loop/loop/...` 死循环时）。
    
- **`NAME_MAX = 255`**：单段名最长 255 字节。
    
- **`PATH_MAX = 4096`**：整条路径最长（部分 FS 支持更大，如 btrfs）。
    
- **绝对 vs 相对**：`/a/b` 是绝对；`a/b` 是相对 `$PWD`；`./a` 是相对（**同 `.` 略过**）。
    

### 4.5 符号链接解析

软链接是**路径解析的扩展**：

- `lookup` 时遇到 `inode.mode == S_IFLNK` → 读链接内容（`i_op->get_link`）→ **递归解析**。
    
- 解析深度超过 `MAXSYMLINKS` → 报 `ELOOP`。
    
- `O_NOFOLLOW`：最后一段是软链 → **不跟随**（`open` / `lstat` 行为）。
    
- `O_PATH`：只解析路径，不真正打开。
    

---

## 5. dcache（Dentry Cache）——"ls 这么快"的真相

### 5.1 数据结构

dcache = 哈希表 + LRU 链表。

struct dentry_stat_t {  
    int     nr_dentry;     // 总 dentry 数  
    int     nr_unused;     // 未被引用的  
    int     age_limit;     // LRU 老化时间  
    int     want_pages;    // dentry want pages  
    int     dummy[2];  
};

### 5.2 关键 LRU 链表

|链表|含义|
|---|---|
|`d_lru`（全局 LRU）|所有未引用的 dentry，回收时按此扫|
|`inode->i_dentry`|单 inode 关联的多个 dentry（用于 unlink 时遍历）|

### 5.3 `ls` 怎么跑得快

$ ls /usr/include  
# 看似遍历整个目录 → 实际：  
# 1) VFS 拿到 /usr/include 的 inode  
# 2) 调 readdir → 文件系统返回 (name, ino) 列表  
# 3) VFS 对每条 (name, ino) 在 dcache 中查找  
#    - 命中：直接返回 dentry  
#    - miss：新建 dentry、加入 dcache  
# 4) 遍历完目录，输出文件名  
# 5) 后续 ls 同一目录：dcache 全命中 → 几乎不需要 FS 操作

> **关键实验**：
> 
> $ time ls /usr  # 第一次  
> real    0m0.012s  
> $ time ls /usr  # 第二次  
> real    0m0.003s  
> # 第二次几乎都是 dcache 命中

### 5.4 negative dentry

> "**确认不存在的文件名**" 也是一种 dentry，叫 **negative dentry**。

- 减少 `lookup` 调用（再次 `stat notexist.txt` 时直接返回 -ENOENT）。
    
- 内存压力时优先回收。
    
- `find` 在大目录上快，部分依赖此机制。
    

### 5.5 dcache 工具

# 看当前 dcache 统计  
cat /proc/sys/fs/dentry-state  
# 14523  1234   45   0   0   0  
# nr_dentry nr_unused age_limit ...  
  
# 强制回收  
echo 2 > /proc/sys/vm/drop_caches   # 慎用  
# 0: 不释放；1: page cache；2: dcache + page cache；3: 全部（含 slab）

---

## 6. Page Cache & Buffer Cache

> 深度解析见 [[VFS-page-cache深度解析]]（read/write 全链路、cp 先快后慢、mmap 零拷贝）。

### 6.1 关键结构

struct address_space {  
    struct inode        *host;          // 所属 inode  
    struct radix_tree_root i_pages;     // 页树（page cache）  
    atomic_t            i_mmap_writable; // 可写的 mmap 数  
    struct rb_root_cached   i_mmap;     // mmap 链表  
    const struct address_space_operations *a_ops; // ★ 同步回写  
    unsigned long       nrpages;        // 已缓存的页数  
    // ...  
};  
  
struct address_space_operations {  
    int (*readpage)(struct file *, struct page *);  
    int (*writepage)(struct page *, struct writeback_control *);  
    int (*readpages)(struct file *, struct address_space *, struct list_head *, unsigned);  
    int (*writepages)(struct address_space *, struct writeback_control *);  
    int (*set_page_dirty)(struct page *);  
    int (*readpage)(struct file *, struct page *);  
    int (*write_begin)(struct file *, struct address_space *, loff_t, unsigned, unsigned, struct page **, void **);  
    int (*write_end)(struct file *, struct address_space *, loff_t, unsigned, unsigned, unsigned, struct page *, void *);  
    sector_t (*bmap)(struct address_space *, sector_t);  
    void (*invalidatepage)(struct page *, unsigned int, unsigned int);  
    int (*releasepage)(struct page *, gfp_t);  
    void (*freepage)(struct page *);  
    // ...  
};

### 6.2 数据流（读文件）

进程 read()  
└── vfs_read()  
    └── file->f_op->read_iter()  // 一般是 generic_file_read_iter  
        └── filemap_read() / do_read_fault()  
            ├── 检查 page cache 是否有这页  
            │   - 命中：直接拷贝到用户缓冲区  
            │   - miss：提交 I/O  
            │       ├── file->f_mapping->a_ops->readpage()  
            │       ├── 块设备 I/O  
            │       └── 放入 page cache  
            └── 返回数据

### 6.3 数据流（写文件）

进程 write()  
└── vfs_write()  
    └── file->f_op->write_iter()  // generic_file_write_iter  
        └── do_writepages() 或 buffered write  
            ├── 数据先写到 page cache（页变 dirty）  
            ├── 设置 PG_dirty  
            ├── 标记 inode 脏  
            └── 后续由 writeback 线程异步刷回

> **写回时机**：
> 
> - `pdflush` / `kworker` 异步写回（5 秒 + dirty ratio 触发）。
>     
> - `fsync(fd)` 强制刷回（`O_SYNC` 标志 → 每 write 都同步）。
>     
> - `sync()` 全系统刷回。
>     
> - `drop_caches=1` 不动 page cache，`=2` 清 page cache + dcache。
>     

### 6.4 buffer cache vs page cache

|维度|老 buffer cache|新 page cache|
|---|---|---|
|粒度|块（512B~4KB）|页（4KB，可包含多块）|
|抽象层|buffer_head 包裹|纯 page + 映射|
|现今|**已被 page cache 吸收**|是主流|

> 现代 Linux **只有一个 page cache**。`buffer_head` 只是"页到块"的描述符，不另起缓存。

### 6.5 O_DIRECT 绕过 page cache

open("/path", O_DIRECT);  
// 数据不进入 page cache，直接 DMA 到用户缓冲区  
// 需要对齐：buffer、offset、length 都需 512 字节对齐（多数 FS 4KB）

- **优点**：不污染 cache、避免双份内存。
    
- **缺点**：性能反而可能更差（失去 read-ahead / write-behind）。
    
- **典型用户**：数据库（PostgreSQL、MySQL InnoDB、Oracle）。
    

### 6.6 mmap

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);

- 把文件**直接映射**到进程虚拟地址空间。
    
- 缺页时通过 `file->f_op->mmap` 调底层 FS 拉取页（走 page cache）。
    
- 写时仍标记 dirty，由 writeback 刷回。
    
- 经典用途：可执行文件、动态库、大型数据文件。
    

---

## 7. 文件系统注册与挂载

### 7.1 `file_system_type`

struct file_system_type {  
    const char          *name;     // "ext4" / "xfs" / "btrfs" / "proc" / "sysfs"  
    int                 fs_flags;  // FS_REQUIRES_DEV / FS_USERNS_MOUNT ...  
    struct file_system_type *next; // 全局链表  
    struct super_block  *(*get_sb)(struct file_system_type *, int, const char *, void *); // 旧 API  
    struct dentry       *(*mount)(struct file_system_type *, int, const char *, void *); // 新 API（fs_context）  
    void                (*kill_sb)(struct super_block *);  
    struct module       *owner;  
    struct file_system_type *next;  
    // ...  
};

> 大多数 FS 在 `init` 时 `register_filesystem(&my_fs_type)`，卸载模块时 `unregister_filesystem`。

### 7.2 mount 流程

sys_mount(dev, dir, type, flags, data)  
└── do_mount()  
    └── do_new_mount()  // 或 do_change_typeflags()  
        └── vfs_get_tree()  
            └── fc->ops->get_tree()  // 走 fs_context  
                └── 具体 FS 的 fill_super / get_tree  
                    ├── sb = sget()        // 找/建 super_block  
                    ├── sb->s_op->...      // 填 super_operations  
                    ├── root = ...          // 建根 inode + 根 dentry  
                    └── 挂载点 install 到 mount 树

### 7.3 `/proc/filesystems` / `/proc/mounts`

# 系统支持哪些 FS（已加载的）  
$ cat /proc/filesystems  
nodev   sysfs  
nodev   tmpfs  
nodev   bdev  
nodev   proc  
        ext4  
        vfat  
        xfs  
        btrfs  
  
# 当前挂载情况  
$ cat /proc/mounts   # /proc/self/mounts 软链  
/dev/sda1 / ext4 rw,relatime 0 0  
tmpfs /run tmpfs rw,nosuid,nodev,size=... 0 0

### 7.4 挂载标志

|标志|含义|
|---|---|
|`MS_RDONLY`|只读|
|`MS_NOSUID`|忽略 SUID/SGID|
|`MS_NODEV`|禁止访问设备文件|
|`MS_NOEXEC`|禁止执行|
|`MS_SYNCHRONOUS`|同步写（无 page cache）|
|`MS_REMOUNT`|改已挂载 FS 的标志|
|`MS_BIND`|bind mount（目录到目录）|
|`MS_PRIVATE` / `MS_SLAVE` / `MS_SHARED`|mount namespace 传播|
|`MS_NOATIME`|不更新 atime|
|`MS_RELATIME`|atime 相对更新|
|`MS_LAZYTIME`|mtime/ctime 也延迟更新|

### 7.5 `mount` 数据结构

struct vfsmount {  
    struct dentry       *mnt_root;     // 此挂载的根 dentry  
    struct super_block  *mnt_sb;       // 所属 super_block  
    int                 mnt_flags;     // 挂载标志  
    struct hlist_node   mnt_hash;      // mount 哈希  
    struct list_head    mnt_mounts;    // 子挂载  
    struct list_head    mnt_child;     // 父挂载的子节点  
    struct vfsmount     *mnt_parent;   // 父挂载  
    struct rcu_head     mnt_rcu;  
    // ...  
};

> 一个 `super_block` 可能有**多个** `vfsmount`（bind mount / 多次挂载）。

---

## 8. VFS 与"前面命令"的精确映射

> 这是最实用的部分——把前文复习过的每条命令落到 VFS 内部。

### 8.1 `cd` / `pwd`（文件系统导航）

|用户态|syscall|VFS 路径|
|---|---|---|
|`pwd`|`getcwd`|读 `current->fs->root` + `pwd`|
|`cd /a/b`|`chdir` (`sys_chdir`)|`path_lookup` → 找 `b` 的 inode → 检查 S_IFDIR 与 execute 权限 → `set_fs_pwd()` 更新 `current->fs`|
|`cd ..`|同上|走 `..`，查 dcache 父 dentry|
|`readlink`|`readlinkat`|调 `i_op->get_link` 读软链内容|

### 8.2 `ls`（目录读取）

|用户态|syscall|VFS 路径|
|---|---|---|
|`ls -l`|`getdents64`（先 readdir） + `newfstatat`（每条目）|`iterate_shared` 调底层 FS → 返回 (name, ino) → VFS 查/建 dentry → 用户态用 `stat` 拿属性|
|`ls -la`|同上 + `getdents`|"**先 readdir 再 stat**"——所以 `ls` 涉及 **2×N 个 syscall**|

> **为什么 `ls -l` 比 `ls` 慢**：多 N 个 `stat` 调用。

### 8.3 `cat` / `less` / `head` / `tail`

|用户态|syscall|VFS 路径|
|---|---|---|
|`cat file`|`open` → `read` → `close`|`do_filp_open` → `vfs_read` → `file->f_op->read_iter` → `filemap_read` → page cache|
|`tail -f`|`inotify` 或循环 `read` + `lseek`|多数实现是循环 `read`，但新版用 `inotify`（节省 CPU）|
|`less`|同 cat + `lseek` + `ioctl(TIOCGWINSZ)`|翻页 = 多次 `read` + `lseek`|

### 8.4 `file`（猜文件类型）

|用户态|syscall|VFS 路径|
|---|---|---|
|`file x`|`open` + `read` 前 N 字节|`magic` 数据库（用户态） + 看 `inode.mode` 的高位|
|`file -L`|跟符号链接|`readlink` + 重新 open|

### 8.5 `stat` / `find` / `tree`

|用户态|syscall|VFS 路径|
|---|---|---|
|`stat`|`newfstatat(AT_FDCWD, path, ..., 0)`|`path_lookup` → 找 inode → `inode->i_op->getattr()` → 填 `kstat`|
|`lstat`|`newfstatat(..., AT_SYMLINK_NOFOLLOW)`|同上但**不跟软链**|
|`find`|`open` + `getdents` + `newfstatat` (循环)|递归 `iterate_shared` + `path_lookup`|
|`tree`|同 `find`|——|

### 8.6 文件操作（mkdir/rm/cp/mv/ln/touch）

|用户态|syscall|VFS 路径|
|---|---|---|
|`mkdir`|`mkdir` / `mkdirat`|`path_lookup(父)` → `may_create` → `inode->i_op->mkdir()`|
|`rmdir`|`rmdir` / `unlinkat(AT_REMOVEDIR)`|`path_lookup(父)` → `inode->i_op->rmdir()`|
|`rm file`|`unlink` / `unlinkat`|`path_lookup(父)` → `inode->i_op->unlink()`|
|`cp src dst`|`open(src, O_RDONLY)` + `open(dst, O_WRONLY\|O_CREAT)` + 循环 `read`/`write`|见 cat + mkdir|
|`mv src dst`|`rename` / `renameat2`|`path_lookup(src父)` + `path_lookup(dst父)` → `inode->i_op->rename()`|
|`ln -s`|`symlink` / `symlinkat`|`path_lookup(父)` → `inode->i_op->symlink()`|
|`ln`（硬）|`link` / `linkat`|`path_lookup(src)` + `path_lookup(新名父)` → `inode->i_op->link()`|
|`touch`|`open(O_CREAT)` + `utimensat`|`i_op->create` + `i_op->setattr`（设 atime/mtime）|

### 8.7 权限检查（呼应第一篇）

|用户态|syscall|VFS 路径|
|---|---|---|
|`open`|`do_sys_open`|`path_lookup` → `inode_permission()` → `generic_permission()` → 检查 `inode->i_mode`|
|读|`sys_read`|`file->f_op->read` → `security_file_permission`|
|写|`sys_write`|同上|
|`chmod`|`sys_fchmodat`|`inode_operations::setattr` → 改 `inode->i_mode` + `mark_inode_dirty`|
|`chown`|`sys_fchownat`|同上，改 uid/gid|
|`access`|`sys_faccessat`|`path_lookup` → `inode_permission`（**用真实 uid/gid，不考虑 setuid 位**）|

> **核心权限流程**（每次都跑）：
> 
> inode_permission()  
> └── generic_permission()  
>  ├── do_inode_has_perm()    // 检查 inode.mode  
>  ├── ACL 检查  
>  └── LSM hook (SELinux/AppArmor)

### 8.8 链接到前文

- **目录权限复习 (linux-directory-permissions.md)** → 本篇 § 8.7 完整机制
    
- **cd/pwd 复习 (linux-cd-pwd.md)** → 本篇 § 4 路径解析 + § 5 dcache
    
- **文件查看复习 (linux-file-viewing.md)** → 本篇 § 6 page cache + § 8.2 / 8.3
    
- **搜索/查找复习 (linux-search-find.md)** → 本篇 § 8.5 (stat/find)
    
- **操作类复习 (linux-file-operations.md)** → 本篇 § 8.6（逐条对应 inode_operations）
    

---

## 9. 特殊文件系统（pseudo-FS）

> VFS 框架让内核对象"伪装成文件"——所有这些都"借用"了 VFS。

### 9.1 `procfs`（`/proc`）

- 把进程 / 系统信息"伪装成文件"读。
    
- 例子：`/proc/cpuinfo` / `/proc/meminfo` / `/proc/self/status` / `/proc/<pid>/fd/*`。
    
- 实现：`proc_fs_context` + `proc_ops`。
    

### 9.2 `sysfs`（`/sys`）

- 把内核对象（kobject）树暴露成文件系统。
    
- 例子：`/sys/class/net/eth0/` / `/sys/devices/...`。
    
- 设备驱动的"标准接口"。
    

### 9.3 `devtmpfs`（`/dev`）

- 内核动态管理的设备文件树。
    
- 配合 udev。
    

### 9.4 `tmpfs`（`/run` / `/dev/shm` / `/tmp`）

- 纯内存文件系统。
    
- 读写 = 走 page cache，不落盘（可 swap）。
    

### 9.5 `cgroup` / `cgroup2`（`/sys/fs/cgroup`）

- 进程分组 + 资源限制。
    
- 是 FS 形式的原因：可以**用统一 syscall**（`open` / `write`）配置。
    

### 9.6 `bpf`（`/sys/fs/bpf`）

- 挂载 BPF 程序 / map。
    

### 9.7 `overlayfs`（容器根目录）

- 联合挂载：把多个目录"叠"成一个。
    
- Docker / Podman 默认使用。
    

### 9.8 特殊 FS 的"操作表"特点

|FS|特点|
|---|---|
|procfs|`proc_ops`（基于 `file_operations`）几乎所有方法都是"读回调"|
|sysfs|每个文件对应一个 kobj_attribute|
|tmpfs|"真" FS 行为，但 page cache 即可当"块设备"|
|devtmpfs|设备文件由内核直接建|
|overlayfs|自己是 FS，但用**另一个 FS** 当底层（redirect）|

---

## 10. VFS 锁机制简史

> VFS 是 Linux 内核锁演化的"主战场"。

|时期|主要锁|备注|
|---|---|---|
|Linux 1.x|BKL（Big Kernel Lock）|早期一切入口都拿 BKL，性能极差|
|Linux 2.4|inode_lock, dcache_lock|颗粒度更细；rename_lock 专给 `rename`|
|Linux 2.6|per-inode mutex, RCU for dcache|引入 dcache RCU，路径解析可以无锁|
|Linux 3.x|seqlock 替代 dcache_lock|rename_lock 改用 seqlock|
|Linux 4.x|RCU walk + REF walk 两阶段|路径解析进一步细分|
|Linux 5.x+|per-CPU 优化、更多无锁|持续优化|

> **核心思想**：从"一把大锁" → "每对象一锁" → "RCU / seqlock" → "per-CPU"。

---

## 11. 关键 VFS 源文件索引

|路径|作用|
|---|---|
|`fs/namei.c`|路径解析（`path_lookup`, `link_path_walk`）|
|`fs/open.c`|`open` / `close` / `llseek` / `fcntl`|
|`fs/read_write.c`|`read` / `write` / `pread` / `pwrite`|
|`fs/stat.c`|`stat` / `lstat` / `fstat` / `newfstatat`|
|`fs/inode.c`|inode cache / alloc / writeback|
|`fs/dcache.c`|dcache（哈希 + LRU）|
|`fs/super.c`|super_block 管理 / `get_super`|
|`fs/mount.c`|mount / umount / mount namespace|
|`fs/namespace.c`|VFS mount tree|
|`fs/file.c`|fdtable / `dup` / `close`|
|`fs/select.c`|`poll` / `select` / `epoll`|
|`fs/eventfd.c` / `fs/signalfd.c` / `fs/timerfd.c`|通知类 fd|
|`fs/io_uring.c`|io_uring（5.x+）|
|`include/linux/fs.h`|主要结构定义|
|`include/linux/dcache.h`|dentry 定义|
|`include/linux/namei.h`|nameidata / LOOKUP_*|
|`Documentation/filesystems/`|VFS 与各 FS 文档|

---

## 12. 综合实验

### 实验 1：观察 dcache 命中

# 第一次：冷  
$ time ls /usr/include > /dev/null  
real    0m0.014s  
# 第二次：热  
$ time ls /usr/include > /dev/null  
real    0m0.002s  
# 释放  
$ sudo sh -c 'echo 2 > /proc/sys/vm/drop_caches'  
# 再来一次  
$ time ls /usr/include > /dev/null  
real    0m0.012s     # 又慢了

### 实验 2：用 `strace` 看 VFS 调用

$ strace -e trace=open,openat,read,write,getdents64,newfstatat ls  
# 把 ls 展开成 syscall 序列  
# 看到：open "." → getdents64 → 多次 newfstatat

### 实验 3：观察 page cache 命中

# 第一遍：冷  
$ dd if=/var/log/syslog of=/dev/null bs=1M  
# 第二遍：热（应有 GB/s 速度）  
$ dd if=/var/log/syslog of=/dev/null bs=1M  
# 用 cachestat 看  
$ sudo cachestats /var/log/syslog

### 实验 4：观察 dentry 数量

$ cat /proc/sys/fs/dentry-state  
# 1000000+ 是常态  
  
# 某进程打开的 dentry  
$ cat /proc/$(pidof nginx)/fd | wc -l

### 实验 5：触底路径解析

# 看内核怎么走路径  
$ strace -e trace=openat cat /a/b/c  
# 0 openat(AT_FDCWD, "/a/b/c", O_RDONLY) = 3  
# 一行 syscall = 一次 path_lookup

### 实验 6：观察 inode 与硬链接

$ ln /etc/passwd /tmp/pwdlink  
$ ls -li /etc/passwd /tmp/pwdlink  
# 两个文件 inode 一样  
# 硬链接数变 2  
$ stat -c '%i %h %n' /etc/passwd /tmp/pwdlink

### 实验 7：看 page cache 占用

$ cat /proc/meminfo | head  
Cached:   1234567 kB  
Buffers:  234567 kB  
  
# 谁占着？  
$ sudo slabtop  
# 或  
$ cat /proc/slabinfo | head

### 实验 8：用 inotify 看 VFS 事件

$ inotifywait -m /tmp  
Setting up watches.  
Watching /tmp.  
# 触发  
$ touch /tmp/hello  
/tmp/ CREATE hello  
/tmp/ OPEN hello  
/tmp/ ATTRIB hello  
/tmp/ CLOSE_WRITE,CLOSE hello

### 实验 9：mount 标志对比

mount -o remount,noatime /        # 减少 atime 写入  
mount -o remount,ro /            # 切只读  
mount -t tmpfs tmpfs /run/user/0 # 临时挂载内存 FS  
mount --bind /srv/data /mnt/data # bind mount

### 实验 10：观察 mount tree

$ findmnt  
# 或  
$ cat /proc/self/mountinfo  
# 字段：mount ID parent fsroot options

---

## 13. 速查表

|想了解|看哪里|
|---|---|
|一个文件被打开的完整路径|`fs/namei.c` 的 `do_filp_open`|
|读文件走了哪些页|`fs/read_write.c` + `mm/filemap.c`|
|dcache 是否太满|`/proc/sys/fs/dentry-state` + `/proc/slabinfo`|
|某个目录有多大|`findmnt` / `/proc/self/mountinfo`|
|内核支持哪些 FS|`/proc/filesystems`|
|释放 page cache|`echo 1 > /proc/sys/vm/drop_caches`|
|释放 dcache|`echo 2 > /proc/sys/vm/drop_caches`|
|跟踪 VFS 调用|`strace -e trace=open,read,write,stat,getdents64`|
|看文件系统被 I/O 抖动|`iostat -x`, `bpftrace`|
|文件路径是否在 dcache|`dcache-state`（需 debugfs）|

---

## 14. 易错点（重点记忆）

> 关于 rm / 引用计数 / 空间不释放的深入讨论见 [[VFS-rm与inode引用计数]]。

1. **`inode` 不存文件名**——文件名在 `dentry.d_name`。
    
2. **`dentry` 不一定落盘**——只在内存里，是 dcache 的项。
    
3. **`struct file` 是进程级**——多个进程打开同一文件 = 多个 `file`，共享 1 个 `inode`。
    
4. **`super_block` = 一个挂载实例**——同盘挂两次 = 2 个 `super_block`。
    
5. **路径解析是递归的"逐段 lookup"**——每段都查 dcache，miss 才调 FS 的 `inode_operations::lookup`。
    
6. **VFS 不存数据**——数据全在具体 FS 里。
    
7. **rcu walk 不能睡眠**——一遇 `d_revalidate` 就退回 ref walk。
    
8. **`O_NOFOLLOW`** 阻止**最后一段**软链跟随；中间段必须跟。
    
9. **`O_DIRECT` 绕过 page cache**——数据库常用，但要做对齐。
    
10. **`MAXSYMLINKS = 8`** 超过报 `ELOOP`。
    
11. **`access()` 不用 setuid 提权**——`open()` 才会。
    
12. **特殊 FS 仍然走 VFS**——procfs/sysfs/tmpfs 都是"按 VFS 框架实现的 FS"。
    
13. **`rename` 在同一 FS 是原子**——跨 FS 不是（拆成 cp+rm）。
    
14. **`umount` 失败常常是 "device busy"**——有进程在该 mount 上的文件 → 用 `fuser -m` / `lsof` 找。
    
15. **`chmod` 改 mode，ACL 改 named entry**——ACL 不在 `inode.mode` 里。
    

---

## 15. 进一步阅读

### 书籍

- **《Understanding the Linux Kernel》** (Bovet & Cesati) —— 第 12 章 "The Virtual Filesystem" 经典必读
    
- **《Linux Kernel Development》** (Robert Love) —— 第 13 章 "The Virtual File System" 简洁精炼
    
- **《Linux Device Drivers》** (Corbet et al.) —— 第 15 章 "内存映射" + 第 9 章 "Linux 内核中的同步"
    
- **《Linux Kernel Internals》**（Tiger Li）—— 进阶推荐
    

### 源码

- `Documentation/filesystems/vfs.rst` —— VFS 官方文档
    
- `fs/Makefile` / `fs/*.c` —— VFS 实现
    
- `include/linux/fs.h` —— 核心结构
    
- `Documentation/filesystems/porting` —— 迁移指南（看每个版本变化）
    

### 工具

- `strace` —— 看 syscall
    
- `perf trace` —— 高级追踪
    
- `bpftrace` / `bcc` —— 跟踪内核事件（如 `biolatency`、`vfsstat`）
    
- `debugfs` —— 挂 `/sys/kernel/debug` 后看 dcache
    

### 进阶论文

- "Linux VFS 的设计"（早期论文）
    
- 各种 FS 的论文（ext4、btrfs、xfs）
    

---

> 复习建议：
> 
> 1. **先把 §1 / §2 背熟**——4 对象 + 4 ops 表是 VFS 的全部家底；
>     
> 2. 用 `strace` 把 `ls -l /usr` / `cat /etc/passwd` / `mkdir /tmp/x` 都跑一遍，看 syscall 序列（§8 是答案）；
>     
> 3. 在 dcache 上动手：跑 `ls`、看 `/proc/sys/fs/dentry-state`、`drop_caches` 后再看；
>     
> 4. 找一段 `fs/namei.c` 的 `link_path_walk`，看它怎么走 dcache，怎么调 `lookup`；
>     
> 5. 写一个最小内核模块，挂个简单 `proc` 文件，理解 "VFS 让一切变成文件" 的含义（§9）；
>     
> 6. 读一遍 `Documentation/filesystems/vfs.rst`（约 200 行），看官方怎么描述自己。
>