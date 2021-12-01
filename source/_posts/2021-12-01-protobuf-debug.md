---
title: C++ 使用 protobuf 踩坑的一次记录
date: 2021-12-01 10:40:42
update: 2021-12-01 10:40:42
categories: C/C++
tags: [protobuf, 共享库, registry, protoc]
---

之前用 protobuf 都比较随意，直到用 protobuf 发布 SDK，遇到了一个坑，恰好遇到了手机的一些问题，导致连环坑。

<!-- more -->

## 坑1：

这个坑很常见，不仅仅对于我，大概情况如下：

```sh
[libprotobuf ERROR /home/murphy/code/github/protobuf/src/google/protobuf/descriptor_database.cc:58] File already exists in database: speech_ai.capt.proto[libprotobuf FATAL /home/murphy/code/github/protobuf/src/google/protobuf/descriptor.cc:1358] CHECK failed: GeneratedDatabase()->Add(encoded_file_descriptor, size): terminating with uncaught exception of type google::protobuf::FatalException: CHECK failed: GeneratedDatabase()->Add(encoded_file_descriptor, size)
```

这个错误原因是因为在两个编译目标（共享库或者可执行文件）中都引入了相同的 `*.pb.cc` 文件。举个例子：
* 我们有个 `example.proto`，生成了 `example.pb.h` 和 `example.pb.cc` 两个文件。
* 首先编译一个共享库 `A.so`，编译的时候需要加入 `example.pb.cc` 文件，因为其中包含了函数定义。
* 编译一个可执行文件 `B.out`，用来测试 `A.so` 的接口是否合适，因为 `B.out` 中也用到了 `example.pb.cc` 中的函数定义，所以按照常规的想法，也需要加入到其中编译（不然会报 undefined reference 错误），并且 `B.out` 需要链接 `A.so`。

如果这种常规做法，就会报上面类似的错误，我查询的原因可以总结如下（也怪我学艺不精，不太了解 protobuf 的内部机制）：**protobuf 本身有一个 global 的 registry。每个 message type 都需要去那里注册一下，而且不能重复注册**。上述的 `Add` 错误就是因为注册失败，原因就是因为 `A.so` 和 `B.out` 中重复注册了（两份 `pb.cc` 实现）。
* 据说换成 protobuf-lite 就能避免这个问题，但是 Google 官方并没有对此表态。

最常规的解决办法就是把所有 `pb.cc` 文件编译成一个共享库 `p.so`，然后 `A.so` 和 `B.out` 都去链接这个共享库。这里需要注意，编译的时候需要设置 `visibility=default`，把符号都打开（一般 SDK 都会隐藏符号）。

## 坑2：

这个坑很奇怪，大概如下：我使用 ndk 和 protobuf v3.6.1 编译了 android 的 `libprotobuf.so`，然后用这个共享库编译 android native 测序程序，运行遇到 Version verification failed，大概如下：

```sh
[libprotobuf FATAL /home/murphy/code/github/protobuf/src/google/protobuf/stubs/common.cc:79] This program was compiled against version 3.0.0 of the Protocol Buffer runtime library, which is not compatible with the installed version (3.6.1).  Contact the program author for an update.  If you compiled the program yourself, make sure that your headers are from the same version of Protocol Buffers as your link-time library.  (Version verification failed in "external/protobuf/src/google/protobuf/any.pb.cc".)terminating with uncaught exception of type google::protobuf::FatalException: This program was compiled against version 3.0.0 of the Protocol Buffer runtime library, which is not compatible with the installed version (3.6.1).  Contact the program author for an update.  If you compiled the program yourself, make sure that your headers are from the same version of Protocol Buffers as your link-time library.  (Version verification failed in "external/protobuf/src/google/protobuf/any.pb.cc".)
```

在 android 使用 gdbserver 调试发现（[教程](https://murphypei.github.io/blog/2021/09/android-gdbserver.html)），`/system/lib64/` 下面有个 `protobuf.so`，这个 so 的版本是 v3.0.0，但是我们编译的程序理论上是用 v3.6.1 编译的。看上去这里运行的时候，链接的是 v3.6.1，但是 v3.6.1 的符号没有覆盖默认的 v3.0.0 的符号，导致 `GOOGLE_PROTOBUF_VERSION` 这个符号变成了 `3000000` 而不是 `3006001`，所以就会失败。

这个问题没有找到解决方案，我换了一个测试手机，没有复现这个问题，所以猜测可能是之前的测试手机有一些问题，如果遇到这个问题，建议换个测试手机试试。