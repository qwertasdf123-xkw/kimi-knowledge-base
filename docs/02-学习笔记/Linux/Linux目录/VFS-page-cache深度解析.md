# VFS：Page Cache 深度解析

> Page Cache 是文件 I/O 性能的根基。本文从 `read()`/`write()` 的精细流程出发，把 page cache 与 VFS 四组件的关系串起来，并解释生产中最常见的几个性能现象。

---

## 1. 概念全景图

```
                        你（应用层）
   ↓ read(fd, buf, 4096)
   ─────────────────────────────────
   ↑ VFS 层
   │ file->f_op->read(file, buf, count)
   │    │
   │    └─ 调用 file->f_mapping->a_ops->readpage / readahead
   │       │
   │       ▼
   │     page cache（struct page 数组，在 RAM 里）
   │       │
   │       ▼
   │     地址空间 address_space（每个 inode 一个）
   │       │
   │       ▼
   │     块设备层 / 文件系统日志层 / IO 调度层
   │       │
   │       ▼
   │     磁盘
   ─────────────────────────────────
```

> **一句话：page cache 是磁盘内容在内存里的缓存，由 `address_space` 索引着，挂在 inode 上。**

---

## 2. 三个核心概念

### ① `address_space` —— 一个 inode 的"地址空间"

每个 inode 都有一个 `address_space`（在 inode 结构体里）。它把**文件里的偏移 0、4K、8K、12K...** 映射到真实的内存页（`struct page`）。

本质上是一棵 **radix tree**（基数树，按 offset 索引），作用类似 dcache 哈希：**用偏移 O(1) 找到对应的 page**。

所以 VFS 实际上是**五个**核心组件：
- super_block / inode / dentry / file
- **+ `address_space`**（绑在 inode 上，专管"文件内容在内存里的映射"）

### ② `struct page` —— 4K 的内存页（缓存最小单位）

page cache 就是一堆 page。读到内存的、还没写回磁盘的，**全是 4K 的 page**。每个 page 知道：

| 属性 | 含义 |
|------|------|
| `mapping` | 我属于哪个 address_space → 反向查 inode |
| `index` | 我在文件里的偏移 |
| `PG_dirty` | 脏不脏（是否需要写回磁盘） |
| LRU 链表位置 | 冷热状态（要被回收时从这里拉出去） |

### ③ LRU 链表 —— 冷热页管理

所有"非活跃"的 page 串成 LRU list，内存紧 → `kswapd` → 按 LRU 淘汰。这就是为什么内存不够时，冷了文件可能被回收。

---

## 3. 一次 `read()` 的精细流程

```
1. 进程 read(fd, buf, 4096)
   │
2.  sys_read → vfs_read
   │
3.  file->f_op->read(file, buf, count)
   │  （具体文件系统可能是 generic_file_read / ext4_file_read / shmem_file_read...）
   │
4.  filemap_get_pages() / find_get_page() / find_or_create_page()
   │
5.  在 file->f_mapping（就是 inode 的 address_space）的 radix 树里找 page
   ├─ 命中（page cache 里已有）
   │   └─ get page，复制到用户 buf，返回
   │
   └─ 未命中（cache miss）
      ├─ 调用 a_ops->readpage 或 readahead 触发磁盘 IO
      ├─ 走块设备层：submit_bio / bio → IO 调度 → 磁盘驱动 → 磁盘
      ├─ 磁盘数据先读到 page cache（mark_page_accessed，不脏）
      ├─ 然后从 page 复制到用户 buffer（copy_to_user！）
      └─ page LRU 入队，等待被淘汰
```

**关键收获**：
1. 磁盘 IO 和 user 拷贝**是分开的**——磁盘 IO 异步，user 拷贝同步。这里有 `mmap` 的优化空间。
2. 第二次 `read` 同位置 → 直接命中 page cache，**磁盘一动不动**。热门配置/库文件反复读都不会打磁盘。

---

## 4. 一次 `write()` 的精细流程（写比读复杂）

```
1. 进程 write(fd, buf, 4096)
   │
2.  sys_write → vfs_write
   │
3.  page = grab_cache_page_write_begin()
   │   从 address_space 里找/创建一个 page
   │
4.  调用 file->f_op->write(file, buf, count, &pos)
   │   这一步：a_ops->write_begin → copy_from_user → 写到 page
   │
5.  标记 page 脏（SetPageDirty(page)）→ 挂在 inode 的脏链表上
   │
6.  write_end
   │
7.  返回用户写完了
```

> ⚠️ **磁盘 IO 还没发起！** page 在内存里、标记脏了，**磁盘上其实还没写**。

### 磁盘什么时候写？

| 触发时机 | 机制 |
|----------|------|
| 脏页积累到阈值 | pdflush / writeback 线程，由 `vm/dirty_ratio` 等阈值触发 |
| 内存不够要回收 | pageout → writeback |
| `fsync` / `fdatasync` / `sync` | 同步阻塞写 |
| 30 秒超时 | 脏页超过 30s 主动回写（`dirty_expire_centisecs`） |

> 这就是为什么突然断电 / kernel panic 可能丢数据——脏页还没刷回磁盘。也是为什么需要 `fsync`、WAL、写日志。

---

## 5. 生产中的经典现象

### ① `cp` 大文件：先快后慢

```
cp src dst
  1. 读 src → cache miss → 磁盘 IO
  2. 写 dst → 写到 page cache，标记脏，返回（快！）
  3. 继续读...

问题：写入积攒了大量脏页，超过 dirty_ratio 时：
  → writeback 被同步阻塞，pause！
  → cp 速度从 GB/s 掉到 MB/s 量级
```

可以调 `dirty_ratio`、`dirty_background_ratio`、`dirty_bytes`，但风险是掉电丢更多。

### ② `echo 3 > /proc/sys/vm/drop_caches`

```bash
echo 1 > /proc/sys/vm/drop_caches   # 释放 page cache
echo 2 > /proc/sys/vm/drop_caches   # 释放 dentries + inodes
echo 3 > /proc/sys/vm/drop_caches   # 都释放
```

**它是清内存，不是清磁盘内容。** 清了之后第一次读会重新去磁盘拉，慢了。但**不会损坏任何文件**。

> ⚠️ **绝对不要在生产定时清**——你用 page cache 是为了让业务快，清了等于在自杀。

### ③ `mmap`：为什么比 `read/write` 快？

核心：**少了"内核页 → 用户页"那次拷贝**。

```
read/write 走法：
  磁盘 → page cache page → copy_to_user → 用户 buf
       2 次数据移动，多一次 CPU 拷贝

mmap 走法：
  磁盘 → page cache page → 用户进程直接 map 同一页（同一份 VMAs）
       1 次数据移动，0 次 CPU 拷贝
```

代价：**mmap 的 page 改了就必须脏**——所有 mmap 的改动一定走 page cache，不可能有"绕过 cache 直写磁盘"的旁路。

---

## 6. page cache 与 VFS 四组件的关系

| 组件 | 与 page cache 的关系 |
|------|---------------------|
| **super_block** | 容纳所有东西，全局视野 |
| **inode** | **拥有 address_space**，radix 树挂在这里；本 inode 的脏页链表也挂着这里 |
| **dentry** | 帮忙定位 inode，从而定位 address_space |
| **file** | 每次 read/write 实际通过 file 操作 `file->f_mapping`（即 inode 的 address_space） |

page cache 不是 VFS 的独立第五件，更像是 **inode 的一个属性**——是 inode 描述"我的内容在内存里怎么组织"的能力。

---

## 7. 一句话总结

> **page cache 是以 inode 为粒度的磁盘内容缓存，由 `address_space` 索引，缓存在 4K 的 `struct page` 里。读路径 = 磁盘 IO + 一次拷贝到用户；写路径 = 只到 page + 标记脏，由内核在阈值/超时/`fsync` 触发下回写磁盘。性能优化的所有空间都来自这里：减少 IO（命中 cache）、减少拷贝（mmap / sendfile / splice / O_DIRECT）、控制脏页（fsync / dirty_ratio）。**

---

## 相关笔记

- [[Linux vfs虚拟文件系统]] —— 参考手册，§6 有 page cache 基础结构和 buffer cache 对比
- [[VFS-四个核心对象辨析]] —— inode 和 file 的详细关系
- [[VFS-rm与inode引用计数]] —— inode 生命周期与 page cache 的关联
