---
layout: post
title: windows7 x64环境使用GLOG日志库
date: 2017-06-01
update: 2018-04-12
categories: C/C++
tags: [windows7, qt5, VS2013, glog]
---

C++中使用GLOG库来进行日志的记录是非常方便的，但是对于其在windows上的配置和使用，还有一些坑。

<!--more-->

想在工程中使用glog来进行日志的记录，无奈google的东西对windows真是不友好，想想还是记录一下吧。

* **需求：**
    
    * 记录日志

* **环境：**
    * windows7 x64
    * Qt5.6.0
    * 编译器: MSVC2012(VS2013)
    * glog: 0.3.4

想法很简单，用VS2013打开glog的源码，build一下即可。但是因为我是64位的Qt程序，所以必须用x64平台来编译。对于glog0.3.3及更早，是不支持x64的，在VS2013等编译环境中还有各种错误，错误包括但不限于：
 
* min函数找不到
* _asm语句在x64环境中无法编译通过
* va_copy重定义警告
* ....

这些错误也不算严重，网上有解决方案。不过我看github中放出的0.3.4版本，这些错误基本都消除了，建议直接下载0.3.4的来编译。

glog中并没有提供x64的配置方案，直接在VS2013中利用win32的配置副本，新建一个x64的配置方案，然后编译。好戏来了：

**编译的动态库libglog没有.lib文件！**

对于我这种白痴来说，一脸懵逼......只有dll文件，没有lib，而且编译libglog的单元测试用例，因为没有lib，也无法通过。

我在网上找了很多，google group中也有人反映这种情况，但是没人给出确切的解决办法。

而我最后的解决办法就是放弃了动态库，使用静态库：`libglog_static.lib`，**使用静态库必须包含两个宏定义**，静态库使用方法如下：

```c++
// 防止和windows的日志库冲突
#define GLOG_NO_ABBREVIATED_SEVERITIES
#define GOOGLE_GLOG_DLL_DECL
#pragma comment(lib, "libglog_static.lib")
```

一些glog使用的定义：

```c++
FLAGS_log_dir = "./logs";                       // 设置日志的保存目录
google::InitGoogleLogging(argv[0]);             // 设置日志的文件名(程序名)
FLAGS_colorlogtostderr = true;                  // 设置输出到屏幕的日志显示相应颜色
FLAGS_max_log_size = 100;                       // 最大日志大小为 100MB
FLAGS_logbufsecs = 3;                           //设置可以缓冲日志的最大秒数，0指实时输出
google::SetStderrLogging(google::GLOG_INFO);    // 在输出中打印所有的日志信息
google::SetLogDestination(google::GLOG_INFO, "./logs/ALL_LOG_INFO_");       // 记录所有的日志信息
google::SetLogDestination(google::GLOG_ERROR, "./logs/ERROR_");             // 记录错误信息，便于方便定位程序出错
```

