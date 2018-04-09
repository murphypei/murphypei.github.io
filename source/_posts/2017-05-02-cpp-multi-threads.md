---
title: C++11多线程编程介绍
categories: C++
description: "C++11中的多线程编程"
tags: [并发编程, 多线程, C++11, thread, tmux]
---

### 1. 与 C++11 多线程相关的头文件

C++11 新标准中引入了四个头文件来支持多线程编程，他们分别是

```
<atomic>, <thread>, <mutex>, <condition_variable>, <future>
```

* ```<atomic>```：该头文主要声明了两个类, **std::atomic** 和 **std::atomic_flag**，另外还声明了一套 C 风格的原子类型和与 C 兼容的原子操作的函数。

* ```<thread>```：该头文件主要声明了 **std::thread** 类，另外 **std::this_thread 命名空间**也在该头文件中。

* ```<mutex>```：该头文件主要声明了与**互斥量(mutex)相关的类**，包括 **std::mutex** 系列类，**std::lock_guard, std::unique_lock**, 以及其他的类型和函数。

* ```<condition_variable>```：该头文件主要声明了与条件变量相关的类，包括 **std::condition_variable** 和 **std::condition_variable_any**。

* ```<future>```：该头文件主要声明了 **std::promise, std::package_task** 两个 Provider 类，以及 **std::future** 和 **std::shared_future** 两个 Future 类，另外还有一些与之相关的类型和函数，**std::async()** 函数就声明在此头文件中。


### 2. std::thread "Hello world"

下面是一个最简单的使用 std::thread 类的例子：

```
#include <stdio.h>
#include <stdlib.h>

#include <iostream> // std::cout
#include <thread>   // std::thread

void thread_task() {
    std::cout << "hello thread" << std::endl;
}


int main(int argc, const char *argv[])
{
    std::thread t(thread_task);
    t.join();

    return EXIT_SUCCESS;
}  /* ----------  end of function main  ---------- */
```


Makefile：（需要连接pthread， GCC4.6）

```
all:Thread

CC=g++
CPPFLAGS=-Wall -std=c++11 -ggdb
LDFLAGS=-pthread			

Thread:Thread.o
    $(CC) $(LDFLAGS) -o $@ $^

Thread.o:Thread.cc
    $(CC) $(CPPFLAGS) -o $@ -c $^


.PHONY:
    clean

clean:
    rm Thread.o Thread
```



### 3. std::thread详解

std::thread在头文件```<thread>```中声明，因此使用 std::thread 时需要包含 ```<thread> ```头文件。

| default(1) | thread() noexcept; |
| :---: | :---: |
| initialization (2) | ```template <class Fn, class... Args>```, explicit thread (Fn&& fn, Args&&... args); |
| copy [deleted] (3) | thread (const thread&) = delete; |
| move (4) | thread (thread&& x) noexcept; |



* (1). 默认构造函数，创建一个空的 thread 执行对象。

* (2). 初始化构造函数，创建一个 thread对象，该 thread对象可被 **joinable**，**新产生的线程会调用 fn 函数，该函数的参数由 args 给出**。

* (3). **拷贝构造函数(被禁用)**，意味着 **thread 不可被拷贝构造**。

* (4). move 构造函数，move 构造函数，调用成功之后 x 不代表任何 thread 执行对象。

注意：可被 joinable 的 thread 对象必须在他们销毁之前被主线程 join 或者将其设置为 detached.

> 主线程中执行joinable对象的join()，相当于在主线程中添加这些thread，也就是在这些添加的thread执行完毕之后才会继续执行主线程，类似嵌入代码 

> join进入主线程的thread并不是从头执行，而是继续执行到完毕，或者说主线程等待其执行到完毕。相当于异步执行变为了同步执行。



####  **move操作**

```move: thread& operator= (thread&& rhs) noexcept;```

* thread类中的operator=是move操作，不是copy操作

* 将rhs这个thread对象的状态赋值到*this中
> thread object whose state is moved to *this.

* move 赋值操作，如果当前对象不可 joinable，需要传递一个右值引用(rhs)给 move 赋值操作；

* 如果当前对象可被 joinable，则 terminate() 被调用。

例子如下：

```
#include <stdio.h>
#include <stdlib.h>

#include <chrono>    // std::chrono::seconds
#include <iostream>  // std::cout
#include <thread>    // std::thread, std::this_thread::sleep_for

// thread运行函数
void thread_task(int n) {
    std::this_thread::sleep_for(std::chrono::seconds(n));
    std::cout << "hello thread "
        << std::this_thread::get_id()
        << " paused " << n << " seconds" << std::endl;
}


int main(int argc, const char *argv[])
{
    std::thread threads[5];
    std::cout << "Spawning 5 threads...\n";
    
    // 创建5个线程
    for (int i = 0; i < 5; i++) {
	    // move-assign threads
        threads[i] = std::thread(thread_task, i + 1);
    }
    
    std::cout << "Done spawning threads! Now wait for them to join\n";
	
	// 5个线程依次join()
    for (auto& t: threads) {
        t.join();
    }
    
    std::cout << "All threads joined.\n";

    return 0;
} 
```

还有一些其余的常规函数，可以查阅手册
[std::thread](http://www.cplusplus.com/reference/thread/thread/?kw=thread)




### 4. std::mutex 详解

Mutex 又称互斥量，C++ 11中与 Mutex 相关的类（包括锁类型）和函数都声明在 ```<mutex>``` 头文件中，所以如果你需要使用 std::mutex，就必须包含 ```<mutex>```头文件。

> pthread下有pthread_mutex


#### **```<mutex>``` 头文件介绍**

**Mutex 系列类(四种)**

* std::mutex，最基本的 Mutex 类。
* std::recursive_mutex，递归 Mutex 类。
* std::time_mutex，定时 Mutex 类。
* std::recursive_timed_mutex，定时递归 Mutex 类。

**Lock 类（两种）**

* std::lock_guard，与 Mutex RAII 相关，方便线程对互斥量上锁。
* std::unique_lock，与 Mutex RAII 相关，方便线程对互斥量上锁，但提供了更好的上锁和解锁控制。

**其他类型**

* std::once_flag
* std::adopt_lock_t
* std::defer_lock_t
* std::try_to_lock_t

**函数**

* std::try_lock，尝试同时对多个互斥量上锁。
* std::lock，可以同时对多个互斥量上锁。
* std::call_once，如果多个线程需要同时调用某个函数，call_once 可以保证多个线程对该函数只调用一次。



#### **std::mutex 介绍**

下面以 std::mutex 为例介绍 C++11 中的互斥量用法。

std::mutex 是C++11 中最基本的互斥量，std::mutex 对象提供了独占所有权的特性——即不支持递归地对 std::mutex 对象上锁，而 std::recursive_lock 则可以递归地对互斥量对象上锁。

**std::mutex 的成员函数**

* 构造函数，std::mutex**不允许拷贝构造，也不允许 move 拷贝**，最初产生的 mutex 对象是处于 unlocked 状态的。

* lock()，**调用线程将锁住该互斥量**。线程调用该函数会发生下面 3 种情况：
	* (1). 如果该互斥量当前没有被锁住，则调用线程将该互斥量锁住，直到调用 unlock之前，该线程一直拥有该锁。
	* (2). 如果当前互斥量被其他线程锁住，则当前的调用线程被阻塞住。
	* (3). 如果当前互斥量被当前调用线程锁住，则会产生死锁(deadlock)。

* unlock()， 解锁，释放对互斥量的所有权。

* try_lock()，尝试锁住互斥量，如果互斥量被其他线程占有，则**当前线程也不会被阻塞**。线程调用该函数也会出现下面 3 种情况，
	* (1). 如果当前互斥量没有被其他线程占有，则该线程锁住互斥量，直到该线程调用 unlock 释放互斥量。
	* (2). 如果当前互斥量被其他线程锁住，则当前调用线程返回 false，而并不会被阻塞掉。
	* (3). 如果当前互斥量被当前调用线程锁住，则会产生死锁(deadlock)。

**mutex例子如下：**

```
#include <iostream>       // std::cout
#include <thread>         // std::thread
#include <mutex>          // std::mutex

volatile int counter(0);  // non-atomic counter
std::mutex mtx;           // locks access to counter

void attempt_10k_increases() {
    for (int i=0; i<10000; ++i) {
        if (mtx.try_lock()) {   // only increase if currently not locked:
            ++counter;
            mtx.unlock();
        }
    }
}

int main (int argc, const char* argv[]) {
    std::thread threads[10];
    for (int i=0; i<10; ++i)
        threads[i] = std::thread(attempt_10k_increases);

    for (auto& th : threads) th.join();
    std::cout << counter << " successful increases of the counter.\n";

    return 0;
}
```

**std::recursive_mutex 介绍**

* std::recursive_mutex 与 std::mutex 一样，也是一种可以被上锁的对象，但是和 std::mutex 不同的是，**std::recursive_mutex 允许同一个线程对互斥量多次上锁（即递归上锁），来获得对互斥量对象的多层所有权**，

* std::recursive_mutex 释放互斥量时需要**调用与该锁层次深度相同次数的 unlock()，可理解为 lock() 次数和 unlock() 次数相同**，除此之外，std::recursive_mutex 的特性和 std::mutex 大致相同。

**std::time_mutex 介绍**

* std::time_mutex 比 std::mutex 多了两个成员函数，try_lock_for()，try_lock_until()。

* **try_lock_for** 函数接受一个时间范围，表示**在这一段时间范围之内线程如果没有获得锁则被阻塞住**（与 std::mutex 的 try_lock() 不同，try_lock 如果被调用时没有获得锁则直接返回 false），如果在此期间其他线程释放了锁，则该线程可以获得对互斥量的锁，如果超时（即在指定时间内还是没有获得锁），则返回 false。
	* 在指定时间内阻塞，知道获得锁。超时返回false

* **try_lock_until** 函数则接受一个**时间点作为参数**，在指定时间点未到来之前线程如果没有获得锁则被阻塞住，如果在此期间其他线程释放了锁，则该线程可以获得对互斥量的锁，如果超时（即在指定时间内还是没有获得锁），则返回 false。

**time_mutext举例如下：**

```
#include <iostream>       // std::cout
#include <chrono>         // std::chrono::milliseconds
#include <thread>         // std::thread
#include <mutex>          // std::timed_mutex

std::timed_mutex mtx;

void fireworks() {
  // waiting to get a lock: each thread prints "-" every 200ms:
  while (!mtx.try_lock_for(std::chrono::milliseconds(200))) {
    std::cout << "-";
  }
  // got a lock! - wait for 1s, then this thread prints "*"
  std::this_thread::sleep_for(std::chrono::milliseconds(1000));
  std::cout << "*\n";
  mtx.unlock();
}

int main ()
{
  std::thread threads[10];
  // spawn 10 threads:
  for (int i=0; i<10; ++i)
    threads[i] = std::thread(fireworks);

  for (auto& th : threads) th.join();

  return 0;
}
```

**std::recursive_timed_mutex 介绍**

* 和 std:recursive_mutex 与 std::mutex 的关系一样，std::recursive_timed_mutex 的特性也可以从 std::timed_mutex 推导出来

#### **std::lock_guard 介绍**

与 Mutex RAII 相关，方便线程对互斥量上锁。

```
#include <iostream>       // std::cout
#include <thread>         // std::thread
#include <mutex>          // std::mutex, std::lock_guard
#include <stdexcept>      // std::logic_error

std::mutex mtx;

void print_even (int x) {
    if (x%2==0) std::cout << x << " is even\n";
    else throw (std::logic_error("not even"));
}

void print_thread_id (int id) {
    try {
        // using a local lock_guard to lock mtx guarantees unlocking on destruction / exception:
        std::lock_guard<std::mutex> lck (mtx);
        print_even(id);
    }
    catch (std::logic_error&) {
        std::cout << "[exception caught]\n";
    }
}

int main ()
{
    std::thread threads[10];
    // spawn 10 threads:
    for (int i=0; i<10; ++i)
        threads[i] = std::thread(print_thread_id,i+1);

    for (auto& th : threads) th.join();

    return 0;
}
```

<br/>

#### **std::unique_lock 介绍**

与 Mutex RAII 相关，方便线程对互斥量上锁，但提供了更好的上锁和解锁控制。

```
#include <iostream>       // std::cout
#include <thread>         // std::thread
#include <mutex>          // std::mutex, std::unique_lock

std::mutex mtx;           // mutex for critical section

void print_block (int n, char c) {
    // critical section (exclusive access to std::cout signaled by lifetime of lck):
    std::unique_lock<std::mutex> lck (mtx);
    for (int i=0; i<n; ++i) {
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