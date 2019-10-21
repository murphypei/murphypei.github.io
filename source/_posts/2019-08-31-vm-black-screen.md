---
title: win10 虚拟机黑屏卡死
date: 2019-08-31 15:07:38
update: 2019-08-31 15:07:38
categories: Windows
tags: [Windows, vm, vmware, virtualbox]
---

在 windows10 上面装好 virtualbox 虚拟机之后卡死黑屏，开不了机。

<!-- more -->

我以为是系统不兼容问题，搞了很多试验，换不同的虚拟机系统，不同版本的 virtualbox，检查 bios 中的 VT/X，都解决不了问题，**还没有任何提示**。最后我安装了 vmware pro，加载系统盘的时候提示：**VMware Workstation 与 Device/Credential Guard 不兼容**，一查原来是不知道什么时候开启了 win10 的内核保护隔离，虚拟机运行需要关闭。

官方给的方法比较麻烦，知乎上面有一个比较简单的方法：

* 关闭

`bcdedit /set hypervisorlaunchtype off`

* 开启

`bcdedit /set hypervisorlaunchtype auto`

亲测有效解决。