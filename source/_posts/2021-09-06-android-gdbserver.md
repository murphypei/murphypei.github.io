---
title: 使用 gdbserver 调试 Android Native 程序
date: 2021-09-06 17:40:10
update: 2021-09-06 17:40:10
categories: [C/C++]
tags: [C++, gdbserver, gdb remote, android, native]
---

使用 Android NDK 编译得到 Android native program，可以直接 push 到手机上运行，但是没办法直接用 gdb debug。

<!-- more -->

为此，我们需要使用 gdbserver，也就是 gdb 远程调试功能。原理就不讲了，我自己尝试的过程中发现网上写的教程都是相互转载的，乱七八糟，不知所云。本文写原理（谷歌可查），仅仅记录下我已经确认可行的调试过程。

1. 首先，把 `$NDK/prebuilt/android-arm64/gdbserver/gdbserver` 以及要调试的程序 push 到手机上（任意文件夹）。
2. 在手机上启动 gdbserver。`gdbserver :9090 <exec>`。其中 `:9090` 表示 gdbserver 监听手机的 9090 端口。会显示 `Listening on port 9090` 类似信息。如果有本地 lib，记得设置 `LD_LIBRARY_PATH` 环境变量。
3. 设置端口转发。`adb forward tcp:9090 tcp:9090`，表示将本地 9090 端口转发到手机的 9090 端口。
4. 本地启动 gdb。`$NDK/prebuilt/linux-x86_64/bin/gdb`。进入 gdb 调试页面。
5. 设置调试对象。`target remote :9090`。调试本地的 9090 端口，同时也是手机的 9090 端口，也就是 gdbserver，连接成功之后， gdbserver 那边会显示 `Remote debugging from host 127.0.0.1` 字样。

Android gdbserver 和 Linux gdb 有一些命令不太一样，但是很多还是相同的。启动程序不用 r，用 continue。

用 vscode 也可以，把上述流程弄到 vscode 的 task.json 中就行，只是觉得更麻烦了，所以没必要。
