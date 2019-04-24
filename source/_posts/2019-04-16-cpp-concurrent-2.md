---
title: C++11 并发编程系列(二)：互斥量(mutex)
date: 2019-04-16 16:57:19
update: 2019-04-16 16:57:19
categories: C++
tags: [C++, thread, 多线程, mutex]
---

并发编程作为 C++11 系列的一个重大更新部分，值得我们去探究，并应用其提升程序的性能。本系列参考了其他一些文章，对 C++11 并发编程的一些要点进行了总结，并给出一些示例。

<!-- more -->

mutex 又称互斥量，C++11 中与 mutex 相关的类（包括锁类型）和函数都声明在 `<mutex>` 头文件中，所以如果你需要使用 `std::mutex`，就必须包含 `<mutex>` 头文件。

### mutex 头文件介绍

`<mutex>`中包含了 mutex 相关的定义和操作，主要包含的内容包括：

#### mutex系列类(四种)

* `std::mutex`：基本的 mutex 类。
* `std::recursive_mutex`：递归 mutex 类。
* `std::time_mutex`：定时 mutex 类。
* `std::recursive_timed_mutex`：定时递归 mutex 类。

#### lock类（两种）

* `std::lock_guard`：与 mutex RAII 相关，方便线程对互斥量上锁。
* `std::unique_lock`：与 mutex RAII 相关，方便线程对互斥量上锁，但提供了更好的上锁和解锁控制。

#### 其他类型

* `std::once_flag`
* `std::adopt_lock_t`
* `std::defer_lock_t`
* `std::try_to_lock_t`

#### 函数

* `std::try_lock`：尝试同时对多个互斥量上锁。
* `std::lock`：可以同时对多个互斥量上锁。
* `std::call_once`：如果多个线程需要同时调用某个函数，`call_once` 可以保证多个线程对该函数只调用一次。

### mutex 介绍

基本的 `std::mutex` 是 C++11 中最基本的互斥量，`std::mutex` 对象提供了独占所有权的特性——即不支持递归地对 `std::mutex` 对象上锁。而 `std::recursive_lock` 则可以递归地对互斥量对象上锁。

`std::mutex` 的成员函数：

* 构造函数：`std::mutex` 不允许拷贝构造，也不允许 move 拷贝，**最初产生的 mutex 对象是处于 unlocked 状态的**。
* `lock()`：调用线程将锁住该互斥量。线程调用该函数会发生下面3种情况：
    * 如果该互斥量当前没有被锁住，则调用线程将该互斥量锁住，直到调用 `unlock` 之前，该线程一直拥有该锁；
    * 如果当前互斥量被其他线程锁住，则当前的调用线程被阻塞住，直到 mutex 被释放；
    * 如果当前互斥量被当前调用线程锁住，则会产生死锁（deadlock）。
* `unlock()`：释放对互斥量的所有权。
* `try_lock()`：尝试锁住互斥量，如果互斥量被其他线程占有，则**当前线程也不会被阻塞**。线程调用该函数也会出现下面3种情况：
    * 如果当前互斥量没有被其他线程占有，则该线程锁住互斥量，直到该线程调用 `unlock` 释放互斥量。
    * 如果当前互斥量被其他线程锁住，则当前调用线程返回 `false`，而并不会被阻塞掉。
    * 如果当前互斥量被当前调用线程锁住，则会产生死锁（deadlock）。

mutex示例：

```c++
#include <iostream>
#include <thread>
#include <mutex>
#include <chrono>

volatile int counter(0);        // non-atomic counter
std::mutex mtx;                 // locks access to counter

void attempt_10k_increases() 
{
    for (int i=0; i<100; ++i) 
    {
        if (mtx.try_lock()) 
        {   // only increase if currently not locked:
            ++counter;
            std::this_thread::sleep_for(std::chrono::microseconds(50));
            mtx.unlock();
        }
        else
        {
            std::cout << std::this_thread::get_id() << " failed" << std::endl;
        }
    }
}

int main (int argc, const char* argv[]) 
{
    std::thread threads[10];
    for (int i=0; i<10; ++i)
    {
        threads[i] = std::thread(attempt_10k_increases);
    }

    for (auto& th : threads) 
    {
        th.join();
    }
    
    std::cout << counter << " successful increases of the counter.\n";

    return 0;
}
```

输出：
```
140680347330304 failed
...
140680406079232 failed
...
140680406079232 failed
229 successful increases of the counter.
```

可以看到，一部分线程在 increase 的过程中，`try_lock()` 获取互斥量执行失败了，而且不会阻塞，直接返回。

### recursive_mutex 介绍

`std::recursive_mutex` 与 `std::mutex` 一样，也是一种可以被上锁的对象，但是和 `std::mutex` 不同的是，`std::recursive_mutex` 允许同一个线程对互斥量多次上锁（即递归上锁），来获得对互斥量对象的多层所有权，**`std::recursive_mutex` 释放互斥量时需要调用与该锁层次深度相同次数的 `unlock()`**，可理解为 `lock()` 次数和 `unlock()` 次数相同，除此之外，`std::recursive_mutex` 的特性和 `std::mutex` 大致相同。

### time_mutex 介绍

`std::time_mutex` 比 `std::mutex` 多了两个成员函数，`try_lock_for()`，`try_lock_until()`。

* `try_lock_for`：函数接受一个时间范围，表示在这一段时间范围之内线程如果没有获得锁则被阻塞住（与 `std::mutex` 的 `try_lock()` 不同，`try_lock()` 如果被调用时没有获得锁则直接返回 `false`），如果在此期间其他线程释放了锁，则该线程可以获得对斥量的锁，如果超时（即在指定时间内还是没有获得锁），则返回 `false`。
* `try_lock_until`：函数则接受一个时间点作为参数，在指定时间点未到来之前线程如果没有获得锁则被阻塞住，如果在此期间其他线程释放了锁，则该线程可以获得对互斥量的锁，如果超时（即在指定时间内还是没有获得锁），则返回 `false`。

### recursive_timed_mutex 介绍

和 `std:recursive_mutex` 与 `std::mutex` 的关系一样，`std::recursive_timed_mutex` 的特性也可以从 `std::timed_mutex` 推导出来，感兴趣的同鞋可以自行查阅。

### lock_guard 介绍

mutex的RAII相关实现，方便线程的互斥量的使用。

```c++
#include <iostream>       // std::cout
#include <thread>         // std::thread
#include <mutex>          // std::mutex
#include <chrono>

volatile int counter(0);    // non-atomic counter
std::mutex mtx;             // locks access to counter

void attempt_10k_increases()
{
    for (int i=0; i<100; ++i)
    {
        try
        {
            // RAII方式使用mutex
            std::lock_guard<std::mutex> lck(mtx);
            counter++;
            std::this_thread::sleep_for(std::chrono::microseconds(10));
        }
        catch (std::logic_error&)
        {
            std::cout << "[exception caught]\n";
        }
    }
}

int main (int argc, const char* argv[])
{
    std::thread threads[10];
    for (int i=0; i<10; ++i)
    {
        threads[i] = std::thread(attempt_10k_increases);
    }

    for (auto& th : threads)
    {
        th.join();
    }

    std::cout << counter << " successful increases of the counter.\n";

    return 0;
}
```

`lock_guard` 在构造函数中上锁（等待），然后在析构函数中释放锁。

### unique_lock 介绍

与 RAII 相关，方便线程对互斥量上锁，但提供了更好的上锁和解锁控制。

```c++
#include <iostream>       // std::cout
#include <thread>         // std::thread
#include <mutex>          // std::mutex, std::unique_lock

std::mutex mtx;           // mutex for critical section

void print_block (int n, char c) 
{
    std::unique_lock<std::mutex> lck (mtx);
    for (int i=0; i<n; ++i) 
    {
        std::cout << c;
    }
    std::cout << '\n';
}

int main ()
{
    std::thread th1 (print_block,50,'*');
    std::thread th2 (print_block,50,'$');

    th1.join();
    th2.join();

    return 0;
}
```

可以看到，`unique_lock` 和 `lock_guard` 用法很相似，但是实际上 `unique_lock` 更加灵活，**可以在任意的时候加锁或者解锁**，因此其资源消耗也更大，通常是在有需要的时候（比如和条件变量配合使用，我们将在介绍条件变量的时候介绍这个用法）才会使用，否则用 `lock_guard`。
