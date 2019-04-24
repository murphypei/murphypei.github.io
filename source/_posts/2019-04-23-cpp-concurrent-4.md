---
title: C++11 并发编程系列(四)：异步操作(future)
date: 2019-04-23 09:37:04
update: 2019-04-23 09:37:04
categories: C++
tags: [C++, thread, 多线程, 同步, promise]
---

并发编程作为 C++11 系列的一个重大更新部分，值得我们去探究，并应用其提升程序的性能。本系列参考了其他一些文章，对 C++11 并发编程的一些要点进行了总结，并给出一些示例。

<!-- more -->

### future 介绍

我在初次了解异步操作这一块的时候，总是很纠结 `future` 究竟是一个什么东西。和 `mutex`，`condition_variable` 这类的实质性的对象不同，**`future` 封装的是一种访问异步操作的机制**。我们看看官方文档怎么说说：

> The class template std::future provides a mechanism to access the result of asynchronous operations: An asynchronous operation (created via std::async, std::packaged_task, or std::promise) can provide a std::future object to the creator of that asynchronous operation...

很明显，当在一个线程（creator）中创建（通过`std::async`，`std::packaged_task` 或者 `std::promise`）了一个异步操作（asynchronous operations，通常就是创建了一个新的线程，执行操作）的时候，这个异步操作会返回一个 `future` 对象给当前的线程，供其访问异步操作的状态，结果等等。

`future` 某种意义上表示的是一个异步操作，通过其成员函数我们能够获悉异步操作处于什么样的情况。可以通过 `get` 来等待异步操作结束并返回结果，是一个阻塞过程。`wait` 等待异步操作结束结束，也是一个阻塞过程。`wait_for` 是超时等待返回结果，`wait_util` 类似。

```c++
std::future_status status;
do 
{
    status = future.wait_for(std::chrono::seconds(1));
    if (status == std::future_status::deferred) 
    {
        std::cout << "deferred\n";
    } 
    else if (status == std::future_status::timeout) 
    {
        std::cout << "timeout\n";
    } 
    else if (status == std::future_status::ready) 
    {
        std::cout << "ready!\n";
    }
} 
while (status != std::future_status::ready);
```

`future` 作为线程间一种同步手段，还有一个知识就是其共享状态。所谓**共享状态就是这个 `future` 对象所表示的异步操作是否能够在其他线程中被访问**。一般来说，通过异步操作创建的 `future` 会被这些异步操作设置共享状态 。`future` 对象可以通过 `valid()` 函数查询其共享状态是否有效 ，一般来说，只有当 `valid()` 返回 `true`的时候才调用 `get()` 去获取结果，这也是 C++ 文档推荐的操作。

一个有效的 `std::future` 对象只能通过 `std::async()`, `std::promise::get_future` 或者 `std::packaged_task::get_future` 来初始化。另外由 `std::future` 默认构造函数创建的 `std::future` 对象是无效（invalid）的，当然通过 `std::future` 的 `move` 赋值后该 `std::future` 对象也可以变为 valid。

还有一点需要特别注意， **`get()` 调用会改变其共享状态，不再可用，也就是说 `get()` 只能被调用一次，多次调用会触发异常。如果想要在多个线程中多次获取产出值需要使用 `shared_future`。**

#### shared_future

`std::shared_future` 与 `std::future` 类似，但是 `std::shared_future` 可以拷贝、多个 `std::shared_future` 可以共享某个共享状态的最终结果(即共享状态的某个值或者异常)。**`shared_future` 可以通过某个 `std::future` 对象隐式转换（参见 `std::shared_future` 的构造函数），或者通过 `std::future::share()` 显示转换，无论哪种转换，被转换的那个 std::future 对象都会变为 not-valid**。`std::shared_future` 的成员函数和 `std::future` 大部分相同，这个地方就不一一展开了，需要的请查阅官方文档。

### promise 介绍

`promise` 非常有意思，最开始的时候我也很困惑，这个东西为啥叫 `promise`，当我真正理解其含义的时候就明白了。**`promise` 本质是一个类似我们打印输出中占位符的东西，你可以理解它就是一个等待数据装填的坑，它是一个“承诺”，承诺未来会有相应的数据（模板实现）**。因为这是一个“承诺”，所以创建的时候是没有东西的，所以我们需要知道这个异步操作什么时候能有东西，好实现“承诺”，所以 `promise` 可以通过调用 `get_future()` 返回一个 `future` 对象，让你去了解这个承诺是否完成了。因此，`promise` 是存放异步操作产出值的坑，而 `future` 是从其中获取异步操作结果，二者都是模板类型。

下面是一个异步操作的生产者-消费者模型的简单例子，看一下用法：

```C++
#include <thread>
#include <iostream>
#include <future>
#include <chrono>
 
struct MyData
{
	int value;
	float conf;
};
 
MyData data{0, 0.0f};
 
int main()
{
	std::promise<MyData> dataPromise;
	std::future<MyData> dataFuture = dataPromise.get_future();
 
	std::thread producer(
    [&] (std::promise<MyData> &data) -> void {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      data.set_value({2, 1.0f});
    }, 
    std::ref(dataPromise)
  );
 
	std::thread consumer(
    [&] (std::future<MyData> &data) -> void {
      auto a = data.valid();
      std::cout << a << std::endl;
      auto res = data.get();
      std::cout << res.value << "\t" << res.conf << std::endl;
      auto b = data.valid();
      std::cout << b << std::endl;
    }, 
    std::ref(dataFuture)
  );
 
  producer.join();
  consumer.join();
 
  return 0;
}
```

输出：

```
1
2	1
0
```

可以看到，我们不用互斥量和条件变量也可以写出生产者消费者模型，生产者将结果放到 `promise` 中，而消费者通过 `promise` 这个异步操作相关联的 `future` 对象获取结果。另外可以看出，对于一个 `future` 对象，可以通过执行 `valid()` 检查其结果是否是共享的（但是不一定准备好了），然后调用 `get()` 获取结果，并且 `get()` 会改变其共享状态。这里需要注意的一点是，`future` 的 `get()` 方法是阻塞的，所以在与其成对的 `promise` 还未产出值，也就是未调用 `set_value()` 方法之前，调用 `get()` 的线程将会一直阻塞在 `get()` 处直到其他任何人调用了 `set_value()` 方法（虽然 `valid()` 一直是 `true`）。

### packaged_task

`packaged_task` 是对一个任务的抽象，我们可以给其传递一个函数来完成其构造。相较于 `promise`，它应该算是更高层次的一个抽象了吧，同样地，我们可以将任务投递给任何线程去完成，然后通过 `packaged_task::get_future()` 方法获取的 `future` 对象来获取任务完成后的产出值。总结来说，**`packaged_task` 是连数据操作创建都封装进去了的 `promise`**。`packaged_task` 也是一个类模板，模板参数为函数签名，也就是传递函数的类型。

```C++
#include <thread>
#include <iostream>
#include <future>
#include <chrono>
 
struct MyData
{
	int value;
	float conf;
};
 
MyData data{0, 0.0f};
 
int main()
{
	std::packaged_task<MyData()> produceTask(
        [&] () -> MyData {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            return MyData{2, 1};
        }
    );

    auto dataFuture = produceTask.get_future();
 
	std::thread producer(
        [&] (std::packaged_task<MyData()> &task) -> void {
            task();
    }, 
    std::ref(produceTask)
  );
 
	std::thread consumer(
        [&] (std::future<MyData> &data) -> void {
            auto res = data.get();
            std::cout << res.value << "\t" << res.conf << std::endl;
    },
    std::ref(dataFuture)
  );
 
  producer.join();
  consumer.join();
 
  return 0;
}
```

`packaged_task::valid()` 可以帮忙检查当前 `packaged_task` 是否处于一个有效的共享状态，对于由默认构造函数生成的 `packaged_task` 对象，该函数返回 `false`，除非中间进行了 `move()` 赋值操作或者 `swap()` 操作。另外我们也可以通过 `reset()` 来重置其共享状态。对于我们上面创建的 `producerTask` 其创建之后就拥有有效的共享状态。

### async 介绍

介绍了这么多异步操作，终于看到 `async` 这个词了。

`std::async` 大概的工作过程：先将异步操作用 `std::packaged_task` 包装起来，然后将异步操作的结果放到 `std::promise` 中，这个过程就是创造未来的过程。外面再通过 `future.get/wait` 来获取这个未来的结果。可以说，`std::async` 帮我们将 `std::future`、`std::promise` 和 `std::packaged_task` 三者结合了起来。还是直接看那个例子吧。

```C++
#include <thread>
#include <iostream>
#include <future>
#include <chrono>
 
struct MyData
{
	int value;
	float conf;
};
 
MyData data{0, 0.0f};
 
int main()
{
    auto start = std::chrono::steady_clock::now();
    std::future<MyData> dataFuture = std::async(std::launch::async, [] () -> MyData {
        std::this_thread::sleep_for(std::chrono::seconds(2));
        return MyData{2, 1};
    });

    std::this_thread::sleep_for(std::chrono::seconds(1));
    auto res = dataFuture.get();
    std::cout << res.value << "\t" << res.conf << std::endl;

    auto end = std::chrono::steady_clock::now();
    std::cout << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count() << std::endl;

    return 0;
}
```

`async` 返回一个与函数返回值相对应类型的 `future`，通过它我们可以在其他任何地方获取异步结果。由于我们给 `async` 提供了 `std::launch::async` 策略，所以生产过程将被异步执行，具体执行的时间取决于各种因素，最终输出的时间为 2000ms < t < 3000ms ，可见生产过程和主线程是并发执行的。除了 `std::launch::async`，还有一个 `std::launch::deferred` 策略，它会延迟线程地创造，也就是说**只有当我们调用 `future.get()` 时子线程才会被创建以执行任务**，这样输出时间应该是 t > 3000 ms 的。

### 总结

至此，我们基本了解 C++异步操作的常见用法和接口，也通过生产者和消费者例子看见了异步操作在代码编写和性能上的优越性，由于篇幅有限，很多细节并没有展示过多，在使用的过程中，还需要配合官方文档资料进行查阅。
