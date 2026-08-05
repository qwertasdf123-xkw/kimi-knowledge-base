# VFS 四个核心对象辨析

> 本文是对 [[Linux vfs虚拟文件系统]] §1 的补充——从"你以为...但其实..."的纠错角度，把 4 大对象之间最容易混淆的关系讲清楚。

---

## 1. 逻辑链串讲

1. **VFS 是一套"插头国标"**，核心是一组约定 + 三张 `*_op` 函数指针表。
2. **`super_block` 是 VFS 和具体文件系统"握手"的地方**。文件系统注册进来，内核为它分配一个 `super_block`，从此接入 VFS 世界。
3. 用户进 VFS 世界，靠 **dentry 缓存的树形路径** 来定位文件：从根 dentry 出发，一级级哈希查找，命中缓存就很快，没命中就走 inode 操作表查真实文件系统。
4. 找到目标 **inode** 后，权限检查、锁、属性这些都问 inode。
5. `open` 后内核 **new 一个 file 对象**，把 inode 的 `i_fop` 拷过来当 `f_op`，从此用户读写都通过 file → inode 走到具体实现。

---

## 2. 六个最容易混淆的点

### ① `super_block` 不只是"描述"，它是"活的"

除了元数据，挂载时的 `fs_info`、journal、quota、统计都在 `sb` 里。它是整个文件系统在内核里的**控制中枢**，不是一个静态描述符。

### ② inode 不存文件名

文件名存在 dentry 里。inode 只存"我是谁、我多大、我数据在哪"。

**硬链接的存在就是因为 dentry 和 inode 是 N:1**——同一个 inode，多个 dentry 多个名字，删一个名字文件不消失（rm 走的是 dentry → inode 引用计数，到 0 才真删）。

### ③ file 和 inode 不是 1:1，是 N:1

多个进程 `open` 同一个文件 → 多个 file → 共享同一个 inode。但每个 file 有自己的 `f_pos`（偏移）和 `f_flags`（打开标志）。

`fork` 时父子进程默认共享同一个 file 对象（**共享偏移**），所以 `lseek` 会互相影响——这是常见面试点。

```c
// 同一个文件，不同进程、不同打开方式
int fd1 = open("foo.txt", O_RDONLY);   // 进程 A 的 file1
int fd2 = open("foo.txt", O_RDONLY);   // 进程 B 的 file2
int fd3 = dup(fd1);                     // 进程 A 的 file3（又一个 file）

// 这会儿 foo.txt 的 inode 上挂了：file1 + file2 + file3 = 3 个 file
// i_count 现在 = 3（严格说是 dentry 引用 + 3 个 file）
```

> **关键**：只要还有任何一个 file 指过来，`i_count` 就 > 0，inode 就不会死，数据就不释放。

### ④ `i_op` 和 `i_fop` 是两张不同的表，别合并

| 表 | 全称 | 用途 | 何时用 |
|----|------|------|--------|
| `i_op` | `inode_operations` | **目录树操作**：lookup、create、mkdir、rename、unlink… | `open` 之前（路径解析、改文件系统结构） |
| `i_fop` | `file_operations` | **打开后**的字节读写操作：read、write、mmap、poll、fsync… | `open` 之后 |

`open` 之前只用 `i_op`（lookup）；`open` 之后才用 `i_fop`。这是 VFS 设计上很优雅的拆分。

### ⑤ dentry 不是逻辑必需，是性能优化

没有 dcache 也能跑 VFS，每步查 inode 就行——但慢到不可用。dentry 还在另一个抽象层上救场：它把"路径"这件事从 inode 里拽出来，inode 只关心"文件本身"，目录结构交给 dentry。

### ⑥ 四组件的引用计数都管回收

| 组件 | 释放条件 |
|------|----------|
| `super_block` | 没人挂载了才释放 |
| `inode` | 没人用 + 内存压力大才丢回 inode cache（磁盘删不删看 link count 是否到 0） |
| `dentry` | 引用计数到 0 才从 dcache 赶走 |
| `file` | fd 关闭或进程退出才释放 |

> 详见 [[VFS-rm与inode引用计数]]

---

## 3. 一句总结

> **`super_block` 让文件系统"接入"VFS，dentry 把"路径"高效解析到 inode，inode 描述"文件本身"并通过两套 `*_op` 表提供能力，file 把这套能力封装成进程能用的句柄。**

---

## 相关笔记

- [[Linux vfs虚拟文件系统]] —— 参考手册，含完整结构体定义和命令映射
- [[VFS-rm与inode引用计数]] —— inode 引用计数的经典案例：rm 为什么不删 inode
- [[VFS-page-cache深度解析]] —— page cache 与四组件如何配合
