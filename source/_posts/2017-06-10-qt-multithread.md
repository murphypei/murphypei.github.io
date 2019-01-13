---
layout: post
title: Qt中使用多线程的同时更新UI
date: 2017-06-10
update: 2018-04-12
categories: C++
tags: [qt, C++, 多线程]
---

在Qt中使用多线程来解决UI界面在处理数据过程中的阻塞导致未响应等问题。

<!--more-->

## 问题一：多线程非阻塞更新UI

问题的起源来源于需要在Qt中调用图像处理函数，该处理十分耗时，实际运行时发现，经常UI界面出现**未响应**等不友好的信息，甚至CPU占用大的时候直接有假死的现象。

很明显能想到利用多线程来将运算放在子线程中进行。Qt支持QThread，通过继承QThread（重写run方法）来实现多线程（很像java），当然还有其他的方法。不过我对Qt真的不熟悉，还是利用C++11的thread库来写。

写的时候发现一个问题，主线程必须等待子线程的运算结果，而Qt规定**只能在主线程中更新UI**，所以我不能一句join就解决了。想到的方法就是在主线程中循环刷新页面，通过一个原子变量开关控制，当子线程中得到计算结果，主线程再继续运行下去。

主要代码分段：

```c++
atomic_bool subThreadStopped;   // 原子变量，翻拍检测子线程是否完成，完成则停止
```

```c++
// 启动子线程来调用翻拍检测
std::thread recoThread(std::bind(&CameraWidget::detectForRecapture, this));
// 主线程中更新UI
while(!subThreadStopped)
{
    qApp->processEvents();
    this->show();
}
// 等待子线程完成
recoThread.join();
```


上述的`subThreadStopped`变量初始化为false，当子线程运行完毕，赋值为true。

**注意：** 主线程的join必须要有，不然程序会abort，我的理解是由于子线程赋值之后，子线程并没有完全的结束，所以主线程应该等待一下，不过这个等待是可以接受的，时间很短。

网上有说解决方案是弹出一个提醒窗口或者进度条的我也是醉了，治标不治本....


## 问题二：类成员函数来初始化线程

在初始化线程时，调用这样一句

```c++
std::thread recoThread(std::bind(&CameraWidget::detectForRecapture, this));
```

为什么要这样写呢，因为detectForRecapture是一个类成员函数。我们知道，std::thread第一个参数是函数指针，也就是函数的位置，而类成员函数的指针在标准C++中是无法获得普通类成员函数的指针的（这是一个知识点，因为普通类成员函数的第一个隐含参数是this指针）。

解决方案有两种，第一种是将该成员函数设置为static，这样以来该函数的指针就和类绑定了，和对象成员无关，可以获取得到。但是随之而来的问题是static成员函数无法访问普通类成员变量....

第二种就是上述这种写法，**利用C++11新标准的std::bind函数将成员函数和对象指针this绑定**，这样detectForRecapture第一个隐含参数就相当于传入了，也就可以获取到其指针了。

