---
title: C++11并发编程系列（一）：thread初探
date: 2019-04-16 16:57:19
update: 2019-04-16 16:57:19
categories: C++
tags: [C++, thread, 多线程]
---

并发编程作为C++11系列的一个重大更新部分，值得我们去探究，并应用其提升程序的性能。本系列参考了其他一些文章，对C++11并发编程的一些要点进行了总结，并给出一些示例。

<!-- more -->

## 引言

C++的多线程一直为之诟病，作为Linux程序员，但有了C++11的`std::thread`以后，你可以在语言层面编写多线程程序了，直接的好处就是多线程程序的可移植性得到了很大的提高，所以作为一名 C++ 程序员，熟悉 C++11 的多线程编程方式还是很有益处的。

### 并发和并行

首先介绍一下并发的概念，很多时候容易和并行混淆。看一下定义：

> 如果某个系统支持两个或者多个动作（Action）同时存在，那么这个系统就是一个并发系统。如果某个系统支持两个或者多个动作同时执行，那么这个系统就是一个并行系统。并行”概念是“并发”概念的一个子集。也就是说，你可以编写一个拥有多个线程或者进程的并发程序，但如果没有多核处理器来执行这个程序，那么就不能以并行方式来运行代码。

总结来说就是，并发是程序编写的过程中是否有多个动作存在，而并行是实际执行过程中是否有多个动作执行。

### 与C++11多线程相关的头文件

首先熟悉一下C++11的多线程模块的头文件吧。C++11新标准中引入了四个头文件来支持多线程编程，他们分别是`<atomic>`，`<thread>`，`<mutex>`，`<condition_variable>`和`<future>`。

* `<atomic>`：该头文件用于原子操作，主要声明了两个类，`std::atomic`和`std::atomic_flag`，另外还声明了一套C风格的原子类型和与C兼容的原子操作的函数。
* `<thread>`：该头文件用于线程操作，主要声明了`std::thread`类，另外`std::this_thread`命名空间也在该头文件中，包含一些线程的操作函数。
* `<mutex>`：该头文件用于互斥量操作，主要声明了与互斥量(mutex)相关的类，包括`std::mutex`系列类，`std::lock_guard`，`std::unique_lock`，以及其他的类型和函数。
* `<condition_variable>`：该头文件用于条件变量操作，主要声明了与条件变量相关的类，包括`std::condition_variable`和`std::condition_variable_any`。
* `<future>`：该头文件用于异步调用操作，主要声明了`std::promise`，`std::package_task`两个`Provider`类，以及`std::future`和`std::shared_future`两个`Future`类，另外还有一些与之相关的类型和函数，`std::async()`函数就声明在此头文件中。

### C++11多线程的Hello World

Talk is cheap.

```c++
#include <iostream>
#include <string>
#include <thread>

void foo(std::string &str)
{
    std::cout << "print in new thread: " << str << std::endl;
    str = "Changed";
}

int main()
{
    std::string str{"Hello World!"};
    std::thread t(foo, std::ref(str));
    t.join();
    std::cout << "print in main thread: " << str << std::endl;
    return 0;
}
```

输出：
```
print in new thread: Hello World!
print in main thread: Changed
```

可以看到，我们创建了一个线程，然后传入一个`std::string`的引用，因为函数声明的参数是一个引用，所以在这里，我们必须通过`std::ref`将引用传进去，具体可以参考[C++11的std::ref用法](https://chaopei.github.io/blog/2019/04/cpp-std-ref.html)。在子线程中我们改变了这个字符串，然后调用`join()`等待子线程完成，在主线程中打印可以看到字符串已经被改变。这就是线程的基本用法。

### thread详解

首先看一下`std::thread`的构造方式：

| | |
| :--: | :--: |
| default (1) | thread() noexcept; |
| initialization (2) | template <class Fn, class... Args> explicit thread (Fn&& fn, Args&&... args); |
| copy [deleted] (3) | thread (const thread&) = delete; |
| move (4) | thread (thread&& x) noexcept; |

* 默认构造函数，创建一个空的thread执行对象。
* 初始化构造函数，创建一个thread对象，该thread对象可被joinable，新产生的线程会调用`fn`函数，该函数的参数由`args`给出。
* 拷贝构造函数(被禁用)，意味着thread不可被拷贝构造。
* move构造函数，move构造函数，调用成功之后`x`不代表任何thread执行对象。

**线程对象可以被move，但是不能被拷贝**。而对于move赋值操作，如果当前对象不可joinable，需要传递一个右值引用给move赋值操作；如果当前对象可被joinable，则terminate()报错。关于线程是否joinable，可以通过调用`joinable()`来获得，更多关于joinable的资料，可以参考[std::thread::joinable](http://www.cplusplus.com/reference/thread/thread/joinable/)

注意：可被joinable的thread对象必须在他们销毁之前被主线程`join`或者将其设置为`detached`。

用法示例：

```c++
#include <iostream>
#include <utility>
#include <thread>
#include <chrono>
#include <functional>
#include <atomic>

void f1(int n)
{
    for (int i = 0; i < 5; ++i) {
        std::cout << "Thread " << n << " executing\n";
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

void f2(int& n)
{
    for (int i = 0; i < 5; ++i) {
        std::cout << "Thread 2 executing\n";
        ++n;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

int main()
{
    int n = 0;
    std::thread t1; // t1 is not a thread
    std::thread t2(f1, n + 1); // pass by value
    std::thread t3(f2, std::ref(n)); // pass by reference
    std::thread t4(std::move(t3)); // t4 is now running f2(). t3 is no longer a thread
    t2.join();
    t4.join();
    std::cout << "Final value of n is " << n << '\n';
}
```

输出：
```
Thread 2 executing
Thread 1 executing
Thread 2 executing
Thread 1 executing
Thread 2 executing
Thread 1 executing
Thread 2 executing
Thread 1 executing
Thread 2 executing
Thread 1 executing
Final value of n is 5
```

除了`join`，`detach`，`joinable`之外，`std::thread`头文件还在`std::this_thread`命名空间下提供了一些辅助函数：

* `get_id`: 返回当前线程的 id
* `yield`: 告知调度器运行其他线程，可用于当前处于繁忙的等待状态
* `sleep_for`：给定时长，阻塞当前线程
* `sleep_until`：阻塞当前线程至给定时间点