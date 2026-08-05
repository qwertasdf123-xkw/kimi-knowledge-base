---
title: CPU
desc: psutil 系统监控（CPU/内存/磁盘/网络）、IP 地址处理与 paramiko SSH 的 Python 运维速查备忘。
type: 笔记
module: 根目录
pdf: 未知
pdf_size: 未知
scope: psutil / IP / paramiko 常用 API
status: 进行中
---
cpu-times
cpu-count
注意：logical=false是真正的物理核心数
mem
Virtual-memory
交换分区：Swap-memory
disk-partitions返回一个列表
disk-usages磁盘用量
disk_io_counters（perdisk=True）查看单网卡
网络同理net_io_counters
杂项：
boot_time
datetime.datetime.fromtimestamp(%Y-%m-%d,%H:%M:%s)
IP:长度：IP.len()
反向解析地址：IP.reserveNames()
类型ip.iptype()
格式转换
ip().int()
ip().StrBin()
ip().StrHex()
如果是网段和网络范围，那么可以使用make_net
三种方法
IP('192.168.1.0').make_net('255.255.255.0')
IP('192.168.2.0/255.255.255.0'),make_net=True
IP('fanwei+ziwangyanma'),make_net=True
查看一个网段是否包含在另一个网段里
使用 in
看两个网段的IP是否重叠
使用overlaps
paramiko
首先是我们的连接
connect()
字段：
hostname （IP地址）
port：（端口）
username：（用户名）
password：（密码）
pkey：（私钥）
