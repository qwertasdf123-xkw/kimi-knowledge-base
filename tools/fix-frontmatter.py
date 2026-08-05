# -*- coding: utf-8 -*-
"""给 E:\\Linux 的 17 篇笔记补齐 YAML frontmatter。
只向文件顶部新增 frontmatter，原正文一个字节不动。
"""
from pathlib import Path

VAULT = Path(r"E:\Linux")

# 每篇笔记的 frontmatter 字段。
# pdf / pdf_size：同模块无可对应参考（regex.md 的 PDF 仅覆盖正则表达式，
# Linux目录 / Linux编辑器 模块内无带 pdf 字段的笔记），按规则统一填 "未知"。
NOTES = {
    "CPU.md": {
        "desc": "psutil 系统监控（CPU/内存/磁盘/网络）、IP 地址处理与 paramiko SSH 的 Python 运维速查备忘。",
        "module": "根目录",
        "scope": "psutil / IP / paramiko 常用 API",
        "status": "进行中",
    },
    "Linux文本处理/awk.md": {
        "desc": "系统讲解 awk——文本处理的小型编程语言，覆盖字段切分、统计汇总与报表生成（面试强化版）。",
        "module": "Linux文本处理",
        "scope": "awk 语法 / 模式-动作 / 内置变量 / 统计报表",
        "status": "完成",
    },
    "Linux文本处理/grep.md": {
        "desc": "系统讲解 grep 逐行模式匹配，覆盖 BRE/ERE/PCRE 三大流派与管道筛选用法（面试强化版）。",
        "module": "Linux文本处理",
        "scope": "grep 选项 / 正则三流派 / 管道组合",
        "status": "完成",
    },
    "Linux文本处理/sed.md": {
        "desc": "系统讲解 sed 流编辑器的行级批量转换：替换、删除、插入、打印（面试强化版）。",
        "module": "Linux文本处理",
        "scope": "sed 脚本 / 地址定位 / 替换删除插入打印",
        "status": "完成",
    },
    "Linux文本处理/辅助工具.md": {
        "desc": "cut / tr / sort / uniq / wc / xargs 六个单功能文本处理命令的组合流水线速查。",
        "module": "Linux文本处理",
        "scope": "6 个管道小工具（切列/替换/排序/去重/统计/造参）",
        "status": "完成",
    },
    "Linux文本处理/输入输出重定向.md": {
        "desc": "系统讲解 I/O 重定向与管道——一切命令协作的底层粘合剂（面试强化版）。",
        "module": "Linux文本处理",
        "scope": "stdin/stdout/stderr / 重定向符号 / 管道",
        "status": "完成",
    },
    "Linux目录/Linux vfs虚拟文件系统.md": {
        "desc": "打通用户态命令的内核实现路径：VFS 四大核心对象、路径解析、dcache 与 page cache。",
        "module": "Linux目录",
        "scope": "super_block/inode/dentry/file + RCU walk + dcache/page cache",
        "status": "完成",
    },
    "Linux目录/linux文件查询.md": {
        "desc": "打包复习 ls / cat / less / head / tail / file / stat 七条查看类命令，强调三种时间戳与大文件处理。",
        "module": "Linux目录",
        "scope": "7 条文件查看命令 + 时间戳（atime/mtime/ctime/birth）",
        "status": "完成",
    },
    "Linux目录/Linux目录导航.md": {
        "desc": "聚焦 pwd 与 cd 的行为细节，讲清符号链接场景差异与 $PWD/$OLDPWD 的 shell 内部状态。",
        "module": "Linux目录",
        "scope": "pwd / cd / 符号链接 / shell 内置命令",
        "status": "完成",
    },
    "Linux目录/VFS-page-cache深度解析.md": {
        "desc": "从 read()/write() 精细流程出发，解析 page cache 与 VFS 四组件的关系及常见性能现象。",
        "module": "Linux目录",
        "scope": "read/write 流程 / page cache / 性能现象",
        "status": "完成",
    },
    "Linux目录/VFS-rm与inode引用计数.md": {
        "desc": "解释 rm 删除文件后磁盘空间不释放的经典问题——答案在 inode 的引用计数机制里。",
        "module": "Linux目录",
        "scope": "unlink() / dentry 与 inode 引用计数",
        "status": "完成",
    },
    "Linux目录/VFS-四个核心对象辨析.md": {
        "desc": "以纠错视角辨析 VFS 四个核心对象（super_block / inode / dentry / file）之间最易混淆的关系。",
        "module": "Linux目录",
        "scope": "VFS 四核心对象辨析（vfs虚拟文件系统 §1 补充）",
        "status": "完成",
    },
    "Linux目录/目录的使用.md": {
        "desc": "系统讲解 Linux 目录的使用方式：路径写法、特殊目录、隐藏文件规则与 FHS 标准及跨发行版差异。",
        "module": "Linux目录",
        "scope": "路径 / 特殊目录 / 隐藏文件 / FHS",
        "status": "完成",
    },
    "Linux目录/目录的操作/目录的操作.md": {
        "desc": "面试导向讲解目录的创建、复制、移动、链接与删除——从内核实现讲到命令用法。",
        "module": "Linux目录",
        "scope": "mkdir/cp/mv/ln/rm 的内核语义（面试导向版）",
        "status": "完成",
    },
    "Linux目录/目录的权限.md": {
        "desc": "按面试准备与类比理解双线梳理 Linux 目录权限模型（面试强化版）。",
        "module": "Linux目录",
        "scope": "目录 rwx 语义 / umask / 特殊权限位 / ACL",
        "status": "完成",
    },
    "Linux目录/目录类型.md": {
        "desc": "Linux 系统核心目录、用户与软件目录清单及隐藏文件规则速查。",
        "module": "Linux目录",
        "scope": "FHS 目录清单 / 特殊目录 / 隐藏文件",
        "status": "进行中",
    },
    "Linux编辑器/vim.md": {
        "desc": "vim 编辑器 CentOS-7 实操笔记，专注日常使用所需的快捷键与命令。",
        "module": "Linux编辑器",
        "scope": "vim 模式 / 快捷键 / 配置文件（CentOS-7 实操版）",
        "status": "完成",
    },
}

def build_frontmatter(title, meta):
    lines = [
        "---",
        f"title: {title}",
        f"desc: {meta['desc']}",
        "type: 笔记",
        f"module: {meta['module']}",
        "pdf: 未知",
        "pdf_size: 未知",
        f"scope: {meta['scope']}",
        f"status: {meta['status']}",
        "---",
        "",
    ]
    return "\n".join(lines).encode("utf-8")

def main():
    done, skipped = [], []
    for rel, meta in NOTES.items():
        path = VAULT / rel
        raw = path.read_bytes()
        if len(raw) == 0:
            skipped.append((rel, "0 字节占位文件，跳过"))
            continue
        if raw.startswith(b"---"):
            skipped.append((rel, "已有 frontmatter，跳过"))
            continue
        title = Path(rel).stem
        fm = build_frontmatter(title, meta)
        path.write_bytes(fm + raw)  # 原正文逐字节保留
        done.append(rel)
    print(f"已补齐 frontmatter: {len(done)} 篇")
    for r in done:
        print(f"  + {r}")
    for r, why in skipped:
        print(f"  - 跳过 {r}: {why}")

if __name__ == "__main__":
    main()
