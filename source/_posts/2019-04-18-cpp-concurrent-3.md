---
title: C++11 并发编程系列(三)：条件变量(condition_variable)
date: 2019-04-18 17:58:56
update: 2019-04-18 17:58:56
categories: C/C++
tags: [C++, thread, 多线程, condition_variable]
---

并发编程作为 C++11 系列的一个重大更新部分，值得我们去探究，并应用其提升程序的性能。本系列参考了其他一些文章，对 C++11 并发编程的一些要点进行了总结，并给出一些示例。

<!-- more -->

### condition_variable 类介绍

`std::condition_variable` 是 C++11 多线程编程中的条件变量。

当 `std::condition_variable` 对象的某个 `wait` 类函数被调用的时候，它使用 `std::unique_lock`（通过 `std::mutex`）来锁住当前的线程，当前的线程会一直被阻塞（进入睡眠等待状态），直到有**其他的线程在同一个 `std::condition_variable` 对象上调用 `notify` 类函数来唤醒它。

`std::condition_variable` 对象通常使用 `std::unique_lock<std::mutex>` 来等待，如果需要使用另外的 lockable 类型，可以使用 `std::condition_variable_any` 类，本文后面会讲到 `std::condition_variable_any` 的用法。

首先来看一个简单的例子：

```C++
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;   // 全局标志位

void printId(int id)
{
  std::unique_lock<std::mutex> lck(mtx);
  // 如果标志位不为true，则等待
  while(!ready)
  {
    // 线程被阻塞，直到标志位变为true
    cv.wait(lck);
  }
  std::cout << "thread: " << std::this_thread::get_id() << " id: " << id << "\n";
}

void go()
{
  std::unique_lock<std::mutex> lck(mtx);
  // 改变全局标志位
  ready = true;
  // 唤醒所有线程
  cv.notify_all();
}

int main()
{
  std::thread threads[10];

  for (int i = 0; i < 10; ++i)
  {
    threads[i] = std::thread(printId, i);
  }
  std::cout << "create done.\n" ;

  go();

  for (auto &t : threads)
  {
    t.join();
  }
  std::cout << "process done.\n" ;
  return 0;
```

输出：

```
create done.
thread: 140496261539584 id: 0
thread: 140496253146880 id: 1
thread: 140496244754176 id: 2
thread: 140496227968768 id: 4
thread: 140496211183360 id: 6
thread: 140496194397952 id: 8
thread: 140496202790656 id: 7
thread: 140496186005248 id: 9
thread: 140496219576064 id: 5
thread: 140496236361472 id: 3
process done.
```

在上面的例子中，10 个线程被同时唤醒，因此打印的时候是乱序的。值得注意的是 `while(!ready)`，实际上，正常情况下，`cv.wait` 只会被调用一次，然后等待唤醒，因为线程在调用 `wait()` 之后就被阻塞了。但是通过一个 `while` 循环来判断全局标志位是否正确，这样可以防止被**误唤醒**，这也是条件变量中的常见写法。

#### 构造函数

`std::condition_variable` 的拷贝构造函数被禁用，只提供了默认构造函数。

#### wait 操作

`std::condition_variable` 提供了两种 `wait()` 函数。

* 无条件等待

```
void wait (unique_lock<mutex>& lck);
```

当前线程调用 `wait()` 后将被阻塞（此时当前线程应该获得了锁（mutex），不妨设获得锁 `lck`），直到另外某个线程调用 `notify_*` 唤醒了当前线程。在线程被阻塞时（也就是调用 `wait()` 的时候），该函数会自动调用 `lck.unlock()` 释放锁，使得其他被阻塞在锁竞争上的线程得以继续执行。另外，一旦当前线程获得通知（notified，通常是另外某个线程调用 `notify_*` 唤醒了当前线程），`wait()` 函数也是自动调用 `lck.lock()`，使得 `lck` 的状态和 `wait` 函数被调用时相同。

* 有条件等待

```
template <class Predicate>
void wait (unique_lock<mutex>& lck, Predicate pred);
```

第二种情况设置了 `Predicate`，只有当 `pred` 条件为 `false` 时调用 `wait()` 才会阻塞当前线程，并且在收到其他线程的通知后只有当 `pred` 为 `true` 时才会被解除阻塞。因此第二种情况类似以下代码：

```
while (!pred()) 
{
    wait(lck);
}
```

和 `mutex` 的 `lock` 类似，`std::condition_variable` 也提供了相应的两种（带 `Predicate` 和不带 `Predicate`） `wait_for()` 函数，与 `std::condition_variable::wait()` 类似，不过 `wait_for` 可以指定一个时间段，**在当前线程收到通知或者指定的时间超时之前，该线程都会处于阻塞状态。而一旦超时或者收到了其他线程的通知，`wait_for` 返回**，剩下的处理步骤和 `wait()` 类似。还有 `wait_util()`，用法也类似。

#### notify 操作

* `std::condition_variable::notify_one()`

唤醒某个等待（wait）线程。如果当前没有等待线程，则该函数什么也不做，如果同时存在多个等待线程，则唤醒某个线程是不确定的（unspecified）。

* `std::condition_variable::notify_all()`

唤醒所有的等待（wait）线程。如果当前没有等待线程，则该函数什么也不做。

### condition_variable_any 介绍

与 `std::condition_variable` 类似，只不过 **`std::condition_variable_any` 的 `wait` 函数可以接受任何 `lockable` 参数，而 `std::condition_variable` 只能接受 `std::unique_lock<std::mutex>` 类型的参数，除此以外，和 `std::condition_variable` 几乎完全一样**。

### cv_status 介绍

* `cv_status::no_timeout`

`wait_for` 或者 `wait_until` 没有超时，即在规定的时间段内线程收到了通知。

* `cv_status::timeout`

`wait_for` 或者 `wait_until` 超时。

### notify_all_at_thread_exit

```c++
void std::notify_all_at_thread_exit (condition_variable& cond, unique_lock<mutex> lck);
```

当调用该函数的线程退出时，所有在 `cond` 条件变量上等待的线程都会收到通知。**一般为了防止误唤醒，我们和之前一样，通过一个全局标志位进行判断操作。

### 生产中消费者模型

一般来说，生产者消费者模型可以通过 `queue`， `mutex` 和 `condition_variable` 来实现。下面是一个简单实现：

```c++
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <chrono>
#include <atomic>

int main()
{
  std::queue<int> production;
  std::mutex mtx;
  std::condition_variable cv;
  bool ready = false;  // 是否有产品可供消费
  bool done = false;   // 生产结束

  std::thread producer(
    [&] () -> void {
      for (int i = 1; i < 10; ++i)
      {
        // 模拟实际生产过程
        std::this_thread ::sleep_for(std::chrono::milliseconds(10));
        std::cout << "producing " << i << std::endl;

        std::unique_lock<std::mutex> lock(mtx);
        production.push(i);

        // 有产品可以消费了
        ready = true;
        cv.notify_one();
      }
      // 生产结束了
      done = true;
    }
  );

  std::thread consumer(
    [&] () -> void {
      std::unique_lock<std::mutex> lock(mtx);
      // 如果生成没有结束或者队列中还有产品没有消费，则继续消费，否则结束消费
      while(!done || !production.empty())
      {
        // 防止误唤醒
        while(!ready)
        {
          cv.wait(lock);
        }

        while(!production.empty())
        {
          // 模拟消费过程
          std::cout << "consuming " << production.front() << std::endl;
          production.pop();
        }

        // 没有产品了
        ready = false;
      }
    }
  );

  producer.join();
  consumer.join();

  return 0;
}
```

上述的实现是一个非常简单的单生产者-单消费者模型，是为了展示条件变量和互斥量的配合使用，至于一些标志的原子性以及多生产者-多消费者模型，也可以在这个基础进行扩展。
