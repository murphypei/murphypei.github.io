---
title: git 不同平台下软链接问题
date: 2021-03-03 15:05:06
update: 2021-03-03 15:05:06
categories: Git
tags: [git, symlink, linux, windows]
---

早就听说不同平台软链接兼容问题很大，最近遇上了，记录一下这个问题。

<!-- more -->

### 问题场景

问题场景很常见也很简单。有一个 C++ 项目，在 Linux 下开发，引用了一些第三方库，比如 opencv，其中的 lib 有些是软链接的形式。在 windows 下拉取仓库之后，发现软链接失效了（不影响 windows 平台本身的运行）。我使用 clion 将 windows 的代码同步到远程开发机，则编译无法进行，文件格式错误。原因在于不同操作系统使用的文件系统不同，因此软链接失效了。不同文件系统软链接不兼容的问题，网上自己找找一大堆，实现不同，没啥说的。

### 解决方案

现在的 git 都支持了软链接的兼容处理，安装的时候有个 symlink 选项，勾上即可。另外需要在 clone 的时候处理：

* 首先，使用**以管理员方式**打开 git bash，因为 windows 创建软链接需要管理员权限。
* clone 的时候必须**明确指定**兼容软链接。`git clone -c core.symlinks=true ...`。在 亲测 `.gitconfig` 中设置无效。

这样 clone 下来的仓库里，之前的软链接就变成了 windows 系统中的快捷方式。但是这种快捷方式通过 clion 同步到 Linux 中就是自动的软链接，非常 nice。

### 总结

* windows 下的 git bash 可以通过创造快捷方式的办法兼容 Linux 下的软链接，并且同步到 Linux 中还能保持软链接。
* clion 的远程开发落后 vscode 一个段位，本质就是 rsync 文件同步和 ssh 执行一些命令，因此当遇到这种 windows 和 Linux 中不兼容的文件，这种简单的同步方式必然 GG。

为了解决这个问题顺便测试了最新的 vscode 的 C/C++ 和 cmake 插件，已经解决之前的 includePath 和跳转提示问题，加上强大的 remote 和 git，我觉得 vscode 取代 clion 已经是近在咫尺了。



