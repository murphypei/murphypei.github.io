---
title: 使用wireshark抓取本地包
date: 2017-06-30
update: 2018-04-12
categories: ComputerNetwork
tags: [wireshark, localhost, 抓包]
---

记录使用wireshark抓取本地包的过程。

<!--more-->

使用本机进行服务器/客户端开发测试的时候，通常把服务器和客户端都设置为本机，也就是127.0.0.1。在对TCP和HTTP抓包的过程中发现，无法抓取这种本机回环的数据包，原因是wireshark监听的是网卡的数据，而回环数据包不经过网卡。

网上有设置增加一条回环包发送给网卡的路由规则，亲试貌似不管用。最终找到了一种方法，使用Npcap代替wireshark默认的WinPcap，亲测有效，而且方便好用。

1. 如果装好了wireshark，先卸载WinPcap（不是卸载wireshark）。如果没有安装wireshark，则安装的过程中不要装WinPcap。

2. 安装Npcap

    Npcap下载地址：[摸我](https://nmap.org/npcap/)

    安装的过程一切随意，选项根据自己的需求来选择， api-compat mode必须勾选上

3. 打开wireshark，选择Npcap Loopback Adapter模式，即可监听本地回环数据。可以利用tcp.port==***进行端口过滤。

