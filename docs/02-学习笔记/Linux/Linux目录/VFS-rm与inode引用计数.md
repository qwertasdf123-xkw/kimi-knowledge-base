# VFS：rm 与 inode 引用计数

> 一个经典 VFS 坑：`rm` 删了文件，磁盘空间为什么不释放？答案全在 inode 的两个计数里。

---

## 1. rm 到底干了啥？

`rm` 在 VFS 里走的是 `unlink()` 系统调用，**核心动作就两件**：

1. 在父目录里，把目标 dentry（名字）从目录项里删掉
2. 把这个 dentry 的引用计数 -1

**就这两步，完事。** 没碰 inode，更没碰磁盘数据块。

所以你刚 `rm` 完，这个文件：
- **名字没了**（目录里查不到了）
- **数据块还在磁盘上**
- **inode 也还在**，在 inode cache 里挂着，直到内存紧张再被回收

---

## 2. inode 的两个引用计数，决定它死不死

inode 上有**两个**关键计数：

| 计数                            | 含义                  | 谁会动它                               |
| ----------------------------- | ------------------- | ---------------------------------- |
| **`i_links_count`（硬链接数/链接数）** | 这个 inode 还有多少个名字    | `link` +1，`unlink` -1              |
| **`i_count`（引用计数）**           | 这个 inode 还被多少内核对象指着 | open 的进程（file 里有指针）、dentry 挂着、内核引用 |

### rm 流程细化

```
1. 找到目标 inode，挂一个 inode_operations->unlink()
2. 父目录里把 dentry 摘掉  →  i_links_count -1
3. dentry 引用计数 -1
4. 调用 iput(inode)
   └─ i_count -1
      ├─ i_count != 0：inode 还在内存里，名字没了，但有人用着
      └─ i_count == 0 且 i_links_count == 0：触发真正删除逻辑
           └─ 走文件系统自己的 drop_inode / delete_inode
           └─ 释放磁盘数据块
           └─ 删除磁盘上的 inode
```

**真正删磁盘 inode 是后面的脏活儿**，由具体文件系统的 `delete_inode` 干——比如 ext4 就是把 inode 位图清掉、数据块位图清掉、对应 block group 标记为可写。

---

## 3. 一句话精准版

> **rm 不删 inode，只删"名字"。inode 真正死，两个条件都要满足：**
> 1. **链接数 = 0**（没人叫它了，所有路径都断了）
> 2. **引用计数 = 0**（所有 file、所有 dentry、所有 mmap 都放手了）
>
> **只要有一个 file 还 open 着，inode 就活着，数据块就 0 释放。空间占着不是因为 rm 没干活，是因为 rm 的定义本来就只是"摘名字"。**

---

## 4. 场景验证

| 场景 | 链接数 | 引用计数 | inode 死不死 | 空间回不回 |
|------|:------:|:--------:|:------------:|:----------:|
| `rm` 后没人 open | 0 | 0 | ✅ 真死 | ✅ 立刻回 |
| `rm` 后还有进程 open | 0 | >0 | ❌ 还活着 | ❌ 不回 |
| `rm` 一个硬链接（还有别的名字） | >0 | >0 | ❌ 还活着 | ❌ 不回 |
| `truncate`（截断到 0） | 不变 | 不变 | ❌ 还活着 | ✅ 数据块释放，但 inode 和名字都在 |

---

## 5. 常见怪现象的解释

### ① `rm` 之后磁盘空间没释放

经典场景：大日志被删了，进程还在追着 fd 写。

- `rm` 只解除了目录里那个 dentry
- 进程手里那个 file → inode 还在引用着，**file 没关，i_count 不归 0，inode 没法真删**
- 数据块也照样保留
- `df -h` 看磁盘还是满的

**排查方法**：

```bash
# 找到被删但还占空间的文件
lsof | grep deleted

# 示例输出：
# java  12345  user  3r  REG  253,1  10485760  1234567 /var/log/app.log (deleted)
```

→ 杀进程立刻释放，`du` 也对得上。

### ② 硬链接数量 > 1 时，rm 一个名字不影响数据

```bash
$ ls -li foo.txt bar.txt
123456 -rw-r--r-- 2 user ...  foo.txt   # 2 = 硬链接数
123456 -rw-r--r-- 2 user ...  bar.txt   # 两个名字，同一 inode

$ rm foo.txt
# → bar.txt 还在，inode 123456 还在，数据还在
# → i_links_count 减到 1，没归 0，inode 不死
```

### ③ 文件名带特殊字符、被进程占着，删不掉

只要 inode 还在被任何内核对象引用着，磁盘 inode 就在；磁盘 inode 在，你就能通过以下方式拿到它：

```bash
/proc/<pid>/fd/<fd>          # 拿到 fd
/proc/<pid>/map_files/       # 看到 mmap 映射
```

---

## 6. rm ≠ unlink ≠ truncate

| 操作 | VFS 调用 | 影响 |
|------|----------|------|
| `rm` | `unlink()` / `unlinkat()` | 删一个名字，链接数 -1 |
| `rmdir` | `rmdir()` / `unlinkat(AT_REMOVEDIR)` | 只能删空目录，走特殊逻辑 |
| `> file` | `O_TRUNC` + `open()` | 把文件截断到 0，**名字还在**，inode 改大小 |
| `truncate file` | `truncate()` | 改大小，名字还在 |

> ⚠️ `rm` 不会截断文件数据，只会删名字。`rm` 一个 100G 大文件但有人还 open 着它 → 磁盘上依旧实打实占着 100G，直到 open 关闭。

---

## 7. 内核调用链（简化）

```
sys_unlink()
  └─ do_path_lookup()                       // 路径解析：用 dcache + inode
  └─ vfs_unlink(nd, dentry, &inode)
      └─ inode->i_op->unlink(dir, dentry)   // 让具体文件系统删目录项
      └─ d_delete(dentry)                   // 把 dentry 从 dcache 里摘掉（或标记 negative）
      └─ dput(dentry)                       // dentry 引用计数 -1
  └─ iput(inode)                            // inode 引用计数 -1，可能触发删除
```

**`d_delete` 和 `dput` 的差别**：
- `d_delete`：把 dentry 从父目录的 hash 链里摘掉，但 dentry 本身不一定立刻释放
- `dput`：引用计数 -1，才决定这个 dentry 死不死

如果还有别的文件 open 着 → `i_count != 0` → `dput` 不会真杀 dentry → inode 也不会触发删除。

---

## 8. 什么情况下能立刻删除？

所有"指向这个 inode 的内核引用"全归零：

- 所有 file 关闭（fd 释放）→ file → inode 引用归零
- 所有 dentry 释放 → dentry → inode 引用归零
- 内核里的特殊引用（mmap、aio）归零

一旦 `i_count == 0` 且 `i_links_count == 0`：
- ext4 走 `ext4_drop_inode` → `generic_delete_inode` → 最终释放数据块 + 磁盘 inode

---

## 相关笔记

- [[Linux vfs虚拟文件系统]] —— 参考手册，§14 易错点中有相关条目
- [[VFS-四个核心对象辨析]] —— file:inode = N:1 的详细解释
- [[VFS-page-cache深度解析]] —— page cache 也参与 inode 生命周期
