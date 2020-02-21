---
title: C++11 thread_local 用法
date: 2020-02-21 13:34:19
update: 2020-02-21 13:34:19
categories: C++
tags: [C++, thread, thread_local, static]
---

thread_local 是 C++11 为线程安全引进的变量声明符。

<!-- more -->

### thread_local 简介

thread_local 是一个[存储器指定符](https://zh.cppreference.com/w/cpp/language/storage_duration)。

> 所谓存储器指定符，其作用类似命名空间，指定了变量名的存储期以及链接方式。同类型的关键字还有：
>
> * auto：自动存储期；
> * register：自动存储期，提示编译器将此变量置于寄存器中；
> * static：静态或线程存储期，同时提示是内部链接；
> * extern：静态或线程存储期，同时提示是外部链接；
> * thread_local：线程存储期；
> * mutable：不影响存储期或链接。

对于 thread_local，官方解释是：

> *thread_local* 关键词只对声明于命名空间作用域的对象、声明于块作用域的对象及静态数据成员允许。它指示对象拥有线程存储期。它能与 static 或 extern 结合，以分别指定内部或外部链接（除了静态数据成员始终拥有外部链接），但**附加的 static 不影响存储期**。
>
> **线程存储期**: 对象的存储在线程开始时分配，而在线程结束时解分配。每个线程拥有其自身的对象实例。唯有声明为 thread_local 的对象拥有此存储期。 thread_local 能与 static 或 extern 一同出现，以调整链接。

这里有一个很重要的信息，就是 **`static thread_local` 和 `thread_local` 声明是等价的**，都是指定变量的周期是在线程内部，并且是静态的。这是什么意思呢？举个代码的例子。

下面是一个线程安全的均匀分布随机数生成，例子来源于 [stackoverflow](https://stackoverflow.com/questions/21237905/how-do-i-generate-thread-safe-uniform-random-numbers)：

```C++
inline void random_uniform_float(float *const dst, const int len, const int min = 0, const int max = 1)
{
    // generator is only created once in per thread, but distribution can be regenerated.
    static thread_local std::default_random_engine generator;     // heavy
    std::uniform_real_distribution<float> distribution(min, max); // light
    for (int i = 0; i < len; ++i)
    {
        dst[i] = distribution(generator);
    }
}
```

`generator` 是一个函数的静态变量，理论上这个静态变量在函数的所有调用期间都是同一个的（静态存储期），相反 `distribution` 是每次调用生成的函数内临时变量。现在 `generator` 被 thread_local 修饰，表示其存储周期从整个函数调用变为了线程存储期，也就是在同一个线程内，这个变量表现的就和函数静态变量一样，但是不同线程中是不同的。可以理解为 thread_local 缩小了变量的存储周期。关于 thread_local 变量自动 static，C++ 标准中也有说明：

> When thread_local is applied to a variable of block scope the storage-class-specifier static **is implied** if it does not appear explicitly

关于 thread_local 的定义我也不想过多着墨，还是看代码例子说明吧。

### thread_local 使用示例

#### 全局变量

```c++
#include <iostream>
#include <thread>
#include <mutex>
std::mutex cout_mutex;    //方便多线程打印

thread_local int x = 1;

void thread_func(const std::string& thread_name) {
    for (int i = 0; i < 3; ++i) {
        x++;
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "thread[" << thread_name << "]: x = " << x << std::endl;
    }
    return;
}

int main() {
    std::thread t1(thread_func, "t1");
    std::thread t2(thread_func, "t2");
    t1.join();
    t2.join();
    return 0;
}
```

输出：

```
thread[t2]: x = 2
thread[t2]: x = 3
thread[t2]: x = 4
thread[t1]: x = 2
thread[t1]: x = 3
thread[t1]: x = 4
```

**可以看出全局的 thread_local 变量在每个线程里是分别自加互不干扰的。**

#### 局部变量

```C++
#include <iostream>
#include <thread>
#include <mutex>
std::mutex cout_mutex;    //方便多线程打印

void thread_func(const std::string& thread_name) {
    for (int i = 0; i < 3; ++i) {
        thread_local int x = 1;
        x++;
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "thread[" << thread_name << "]: x = " << x << std::endl;
    }
    return;
}

int main() {
    std::thread t1(thread_func, "t1");
    std::thread t2(thread_func, "t2");
    t1.join();
    t2.join();
    return 0;
}
```

输出：

```
thread[t2]: x = 2
thread[t2]: x = 3
thread[t2]: x = 4
thread[t1]: x = 2
thread[t1]: x = 3
thread[t1]: x = 4
```

可以看到虽然是局部变量，但是在每个线程的每次 for 循环中，使用的都是线程中的同一个变量，也侧面印证了 **thread_local 变量会自动 static**。

如果我们不加 thread_local，输出如下：

```C++
thread[t2]: x = 2
thread[t2]: x = 2
thread[t2]: x = 2
thread[t1]: x = 2
thread[t1]: x = 2
thread[t1]: x = 2
```

体现了局部变量的特征。

这里还有一个要注意的地方，就是 **thread_local 虽然改变了变量的存储周期，但是并没有改变变量的使用周期或者说作用域**，比如上述的局部变量，其使用范围不能超过 for 循环外部，否则编译出错。

```c++
void thread_func(const std::string& thread_name) {
    for (int i = 0; i < 3; ++i) {
        thread_local int x = 1;
        x++;
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "thread[" << thread_name << "]: x = " << x << std::endl;
    }
    x++;    //编译会出错：error: ‘x’ was not declared in this scope
    return;
}
```

#### 类对象

```C++
#include <iostream>
#include <thread>
#include <mutex>
std::mutex cout_mutex;

//定义类
class A {
public:
    A() {
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "create A" << std::endl;
    }

    ~A() {
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "destroy A" << std::endl;
    }

    int counter = 0;
    int get_value() {
        return counter++;
    }
};

void thread_func(const std::string& thread_name) {
    for (int i = 0; i < 3; ++i) {
        thread_local A* a = new A();
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "thread[" << thread_name << "]: a.counter:" << a->get_value() << std::endl;
    }
    return;
}

int main() {
    std::thread t1(thread_func, "t1");
    std::thread t2(thread_func, "t2");
    t1.join();
    t2.join();
    return 0;
}
```

输出：

```c++
create A
thread[t1]: a.counter:0
thread[t1]: a.counter:1
thread[t1]: a.counter:2
create A
thread[t2]: a.counter:0
thread[t2]: a.counter:1
thread[t2]: a.counter:2

```

可以看出类对象的使用和创建和内部类型类似，都不会创建多个。这种情况在函数间或通过函数返回实例也是一样的：

```c++
A* creatA() {
    return new A();
}

void loopin_func(const std::string& thread_name) {
    thread_local A* a = creatA();
    std::lock_guard<std::mutex> lock(cout_mutex);
    std::cout << "thread[" << thread_name << "]: a.counter:" << a->get_value() << std::endl;
    return;
}

void thread_func(const std::string& thread_name) {
    for (int i = 0; i < 3; ++i) {    
        loopin_func(thread_name);
    }
    return;
}

```

输出：

```
create A
thread[t1]: a.counter:0
thread[t1]: a.counter:1
thread[t1]: a.counter:2
create A
thread[t2]: a.counter:0
thread[t2]: a.counter:1
thread[t2]: a.counter:2

```

虽然 `createA()` 看上去被调用了多次，实际上只被调用了一次，因为 thread_local 变量只会在每个**线程最开始被调用的时候进行初始化，并且只会被初始化一次**。

举一反三，如果不是初始化，而是赋值，则情况就不同了：

```
void loopin_func(const std::string& thread_name) {
    thread_local A* a;
    a = creatA();
    std::lock_guard<std::mutex> lock(cout_mutex);
    std::cout << "thread[" << thread_name << "]: a.counter:" << a->get_value() << std::endl;
    return;
}

```

输出：

```c++
create A
thread[t1]: a.counter:0
thread[t1]: a.counter:1
thread[t1]: a.counter:2
create A
thread[t2]: a.counter:0
thread[t2]: a.counter:1
thread[t2]: a.counter:2

```

很明显，虽然只初始化一次，但却可以被多次赋值，因此 C++ 变量初始化是十分重要的（手动狗头）。

#### 类成员变量

规定：**thread_local 作为类成员变量时必须是 static 的**。

```c++
class B {
public:
    B() {
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "create B" << std::endl;
    }
    ~B() {}
    thread_local static int b_key;
    //thread_local int b_key;
    int b_value = 24;
    static int b_static;
};

thread_local int B::b_key = 12;
int B::b_static = 36;

void thread_func(const std::string& thread_name) {
    B b;
    for (int i = 0; i < 3; ++i) {
        b.b_key--;
        b.b_value--;
        b.b_static--;   // not thread safe
        std::lock_guard<std::mutex> lock(cout_mutex);
        std::cout << "thread[" << thread_name << "]: b_key:" << b.b_key << ", b_value:" << b.b_value << ", b_static:" << b.b_static << std::endl;
        std::cout << "thread[" << thread_name << "]: B::key:" << B::b_key << ", b_value:" << b.b_value << ", b_static: " << B::b_static << std::endl;
    return;
}

```

输出：

```
create B
thread[t2]: b_key:11, b_value:23, b_static:35
thread[t2]: B::key:11, b_value:23, b_static: 35
thread[t2]: b_key:10, b_value:22, b_static:34
thread[t2]: B::key:10, b_value:22, b_static: 34
thread[t2]: b_key:9, b_value:21, b_static:33
thread[t2]: B::key:9, b_value:21, b_static: 33
create B
thread[t1]: b_key:11, b_value:23, b_static:32
thread[t1]: B::key:11, b_value:23, b_static: 32
thread[t1]: b_key:10, b_value:22, b_static:31
thread[t1]: B::key:10, b_value:22, b_static: 31
thread[t1]: b_key:9, b_value:21, b_static:30
thread[t1]: B::key:9, b_value:21, b_static: 30

```

`b_key` 是 thread_local，虽然其也是 static 的，但是每个线程中有一个，每次线程中的所有调用共享这个变量。`b_static` 是真正的 static，全局只有一个，所有线程共享这个变量。

#### 参考资料

* https://zh.cppreference.com/w/cpp/language/storage_duration
* https://stackoverflow.com/questions/21237905/how-do-i-generate-thread-safe-uniform-random-numbers
* http://cifangyiquan.net/programming/thread_local/