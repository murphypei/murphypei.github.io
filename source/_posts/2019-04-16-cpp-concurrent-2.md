---
title: C++11并发编程系列（二）：mutex 一窥
date: 2019-04-16 16:57:19
update: 2019-04-16 16:57:19
categories: C++
tags: [C++, thread, 多线程, mutex]
---

并发编程作为C++11系列的一个重大更新部分，值得我们去探究，并应用其提升程序的性能。本系列参考了其他一些文章，对C++11并发编程的一些要点进行了总结，并给出一些示例。

<!-- more -->

mutex又称互斥量，C++11中与mutex相关的类（包括锁类型）和函数都声明在`<mutex>`头文件中，所以如果你需要使用`std::mutex`，就必须包含`<mutex>`头文件。

### <mutex>头文件介绍

`<mutex>`中包含了mutex相关的定义和操作，主要包含的内容包括：

#### mutex系列类(四种)

* `std::mutex`：基本的mutex类。
* `std::recursive_mutex`：递归mutex类。
* `std::time_mutex`：定时mutex类。
* `std::recursive_timed_mutex`：定时递归mutex类。

#### lock 类（两种）

* `std::lock_guard`：与mutex RAII相关，方便线程对互斥量上锁。
* `std::unique_lock`：与mutexRAII相关，方便线程对互斥量上锁，但提供了更好的上锁和解锁控制。

#### 其他类型

* `std::once_flag`
* `std::adopt_lock_t`
* `std::defer_lock_t`
* `std::try_to_lock_t`

#### 函数

* `std::try_lock`：尝试同时对多个互斥量上锁。
* `std::lock`：可以同时对多个互斥量上锁。
* `std::call_once`：如果多个线程需要同时调用某个函数，`call_once`可以保证多个线程对该函数只调用一次。

### mutex介绍

基本的`std::mutex`是C++11 中最基本的互斥量，`std::mutex`对象提供了独占所有权的特性——即不支持递归地对`std::mutex`对象上锁。而`std::recursive_lock`则可以递归地对互斥量对象上锁。

`std::mutex`的成员函数：

* 构造函数：`std::mutex`不允许拷贝构造，也不允许move拷贝，**最初产生的mutex对象是处于unlocked状态的**。
* `lock()`：调用线程将锁住该互斥量。线程调用该函数会发生下面3种情况：
    * 如果该互斥量当前没有被锁住，则调用线程将该互斥量锁住，直到调用`unlock`之前，该线程一直拥有该锁；
    * 如果当前互斥量被其他线程锁住，则当前的调用线程被阻塞住，直到mutex被释放；
    * 如果当前互斥量被当前调用线程锁住，则会产生死锁(deadlock)。
* `unlock()`：释放对互斥量的所有权。
* `try_lock()`：尝试锁住互斥量，如果互斥量被其他线程占有，则**当前线程也不会被阻塞**。线程调用该函数也会出现下面3种情况：
    * 如果当前互斥量没有被其他线程占有，则该线程锁住互斥量，直到该线程调用`unlock`释放互斥量。
    * 如果当前互斥量被其他线程锁住，则当前调用线程返回 false，而并不会被阻塞掉。
    * 如果当前互斥量被当前调用线程锁住，则会产生死锁(deadlock)。

