---
layout: post
title: CPython中的全局解释锁(GIL)
date: 2017-05-27
update: 2018-04-12
categories: Python
tags: [Python, GIL, CPython, 全局解释锁]
---

全局解释锁（GIL）是Python解释器中实现的一个全局锁，控制Python程序的执行。

<!--more-->

首先看一下全局解释锁的定义：

`static PyThread_type_lock interpreter_lock = 0; /* This is the GIL */`

上面这一行代码摘自 ceval.c —— CPython 2.7 解释器的源代码，Guido van Rossum 的注释”This is the GIL“ 添加于2003 年，但这个锁本身可以追溯到1997年他的第一个多线程 Python 解释器。在 Unix系统中，PyThread_type_lock 是标准 C  mutex_t 锁的别名。当 Python 解释器启动时它初始化：

```c
void
PyEval_InitThreads(void)
{
    interpreter_lock = PyThread_allocate_lock();
    PyThread_acquire_lock(interpreter_lock);
}
```

**解释器中的所有 C 代码在执行 Python 时必须保持这个锁**。

* Guido 最初加这个锁是因为它使用起来简单。而且每次从 CPython 中去除 GIL 的尝试会耗费单线程程序太多性能，尽管去除 GIL 会带来多线程程序性能的提升，但仍是不值得的。（前者是Guido最为关切的, 也是不去除 GIL 最重要的原因, 一个简单的尝试是在1999年, 最终的结果是导致单线程的程序速度下降了几乎2倍.）

* GIL 对程序中线程的影响足够简单，记住这个原则：“**一个线程运行 Python ，而其他 N 个睡眠或者等待 I/O.**”（即保证同一时刻只有一个线程对共享资源进行存取）  Python 线程也可以等待threading.Lock或者线程模块中的其他同步对象；线程处于这种状态也称之为”睡眠“。

线程何时切换？一个线程无论何时开始睡眠或等待网络 I/O，其他线程总有机会获取 GIL 执行 Python 代码。这是协同式多任务处理。CPython 也还有抢占式多任务处理。如果一个线程不间断地在 Python 2 中运行 1000 字节码指令，或者不间断地在 Python 3 运行15 毫秒，那么它便会放弃 GIL，而其他线程可以运行。把这想象成旧日有多个线程但只有一个 CPU 时的时间片。我将具体讨论这两种多任务处理。

## 协同式多任务处理

当一项任务比如网络 I/O启动，而在长的或不确定的时间，没有运行任何 Python 代码的需要，一个线程便会让出GIL，从而其他线程可以获取 GIL 而运行 Python。这种礼貌行为称为协同式多任务处理，它允许并发；多个线程同时等待不同事件。

两个线程各自分别连接一个套接字：

```Python
def do_connect():
    s = socket.socket()
    s.connect(('Python.org', 80))  # drop the GIL
 
for i in range(2):
    t = threading.Thread(target=do_connect)
    t.start()
```

两个线程在同一时刻只能有一个执行 Python ，**但一旦线程开始连接，它就会放弃 GIL ，这样其他线程就可以运行**。这意味着两个线程可以并发等待套接字连接，这是一件好事。在同样的时间内它们可以做更多的工作。

这也就是常见的 I/O 密集型多线程

让我们看看一个线程在连接建立时实际是如何放弃 GIL 的，在 socketmodule.c 中:

```c
/* s.connect((host, port)) method */
static PyObject *
sock_connect(PySocketSockObject *s, PyObject *addro)
{
    sock_addr_t addrbuf;
    int addrlen;
    int res;
 
    /* convert (host, port) tuple to C address */
    getsockaddrarg(s, addro, SAS2SA(&addrbuf), &addrlen);
 
    Py_BEGIN_ALLOW_THREADS
    res = connect(s->sock_fd, addr, addrlen);
    Py_END_ALLOW_THREADS
 
    /* error handling and so on .... */
}
```

线程正是在 `Py_BEGIN_ALLOW_THREADS` 宏处放弃 GIL；它被简单定义为：

`PyThread_release_lock(interpreter_lock);`

当然 `Py_END_ALLOW_THREADS` 重新获取锁。一个线程可能会在这个位置堵塞，等待另一个线程释放锁；一旦这种情况发生，等待的线程会抢夺回锁，并恢复执行你的Python代码。简而言之：当N个线程在网络 I/O 堵塞，或等待重新获取GIL，而一个线程运行Python。

下面来看一个使用协同式多任务处理快速抓取许多 URL 的完整例子。但在此之前，先对比下协同式多任务处理和其他形式的多任务处理。

## 抢占式多任务处理

Python线程可以主动释放 GIL，也可以先发制人抓取 GIL 。

让我们回顾下 Python 是如何运行的。你的程序分两个阶段运行。首先，Python文本被编译成一个名为字节码的简单二进制格式。第二，Python解释器的主回路，一个名叫 `pyeval_evalframeex()` 的函数，流畅地读取字节码，逐个执行其中的指令。

当解释器通过字节码时，它会定期放弃GIL，而不需要经过正在执行代码的线程允许，这样其他线程便能运行：

```c
for (;;) {
    if (--ticker < 0) {
        ticker = check_interval;
 
        /* Give another thread a chance */
        PyThread_release_lock(interpreter_lock);
 
        /* Other threads may run now */
 
        PyThread_acquire_lock(interpreter_lock, 1);
    }
 
    bytecode = *next_instr++;
    switch (bytecode) {
        /* execute the next instruction ... */
    }
}
```

默认情况下，**检测间隔是1000 字节码。所有线程都运行相同的代码，并以相同的方式定期从他们的锁中抽出。在 Python 3 GIL 的实施更加复杂，检测间隔不是一个固定数目的字节码，而是15 毫秒。**然而，对于你的代码，这些差异并不显著。

## Python中的线程安全

如果一个线程可以随时失去 GIL，你必须使让代码线程安全。 然而 Python 程序员对线程安全的看法大不同于 C 或者 Java 程序员，因为许多 **Python 操作是原子的**。

在列表中调用 sort()，就是原子操作的例子。线程不能在排序期间被打断，其他线程从来看不到列表排序的部分，也不会在列表排序之前看到过期的数据。原子操作简化了我们的生活，但也有意外。例如，+= 似乎比 sort() 函数简单，但 += 不是原子操作。你怎么知道哪些操作是原子的，哪些不是？

看看这个代码：

```Python
n = 0
def foo():
    global n
    n += 1
```

我们可以看到这个函数用 Python 的标准 dis 模块编译的字节码：

```Python
>>> import dis
>>> dis.dis(foo)
LOAD_GLOBAL              0 (n)
LOAD_CONST               1 (1)
INPLACE_ADD
STORE_GLOBAL             0 (n)
```

代码的一行中， n += 1，被编译成 4 个字节码，进行 4 个基本操作：

将 n 值加载到堆栈上
将常数 1 加载到堆栈上
将堆栈顶部的两个值相加
将总和存储回 n

记住，一个线程每运行 1000 字节码，就会被解释器打断夺走 GIL 。如果运气不好，这（打断）可能发生在线程加载 n 值到堆栈期间，以及把它存储回 n 期间。很容易可以看到这个过程会如何导致更新丢失：

```Python
threads = []
for i in range(100):
    t = threading.Thread(target=foo)
    threads.append(t)
for t in threads:
    t.start()
for t in threads:
    t.join()
print(n)
```

通常这个代码输出 100，因为 100 个线程每个都递增 n 。但有时你会看到 99 或 98 ，如果一个线程的更新被另一个覆盖。

所以，尽管有 GIL，你仍然需要加锁来保护共享的可变状态：

```Python
n = 0
lock = threading.Lock()
def foo():
    global n
    with lock:
        n += 1
```

如果我们使用一个原子操作比如 sort() 函数会如何呢？：

```Python
lst = [4, 1, 3, 2]
def foo():
    lst.sort()
```

这个函数的字节码显示 sort() 函数不能被中断，因为它是原子的：

```Python
>>> dis.dis(foo)
LOAD_GLOBAL              0 (lst)
LOAD_ATTR                1 (sort)
CALL_FUNCTION            0
```

一行被编译成 3 个字节码：

将 lst 值加载到堆栈上
将其排序方法加载到堆栈上
调用排序方法

即使这一行  lst.sort() 分几个步骤，调用 sort 自身是单个字节码，因此线程没有机会在调用期间抓取 GIL 。我们可以总结为在 sort() 不需要加锁。或者，**为了避免担心哪个操作是原子的，遵循一个简单的原则：始终围绕共享可变状态的读取和写入加锁**。毕竟，在 Python 中获取一个 threading.Lock 是廉价的。

尽管 GIL 不能免除我们加锁的需要，但它确实意味着没有加细粒度的锁的需要（所谓细粒度是指程序员需要自行加、解锁来保证线程安全，典型代表是 Java , 而 CPython 中是粗粒度的锁，即语言层面本身维护着一个全局的锁机制,用来保证线程安全）。在线程自由的语言比如 Java，程序员努力在尽可能短的时间内加锁存取共享数据，减轻线程争夺，实现最大并行。然而因为在 Python 中线程无法并行运行，细粒度锁没有任何优势。只要没有线程保持这个锁，比如在睡眠，等待I/O, 或者一些其他失去 GIL 操作，你应该使用尽可能粗粒度的，简单的锁。其他线程无论如何无法并行运行。

## 并发可以完成更快

我敢打赌你真正为的是通过多线程来优化你的程序。通过同时等待许多网络操作，你的任务将更快完成，那么多线程会起到帮助，即使在同一时间只有一个线程可以执行 Python 。这就是并发，线程在这种情况下工作良好。

线程中代码运行更快

```Python
import threading
import requests
urls = [...]
def worker():
    while True:
        try:
            url = urls.pop()
        except IndexError:
            break  # Done.
        requests.get(url)
for _ in range(10):
    t = threading.Thread(target=worker)
    t.start()
```

正如我们所看到的，在 HTTP上面获取一个URL中，这些线程在等待每个套接字操作时放弃 GIL，所以他们比一个线程更快完成工作。

## Parallelism 并行

如果想只通过同时运行 Python 代码，而使任务完成更快怎么办？这种方式称为并行，这种情况 GIL 是禁止的。你必须使用多个进程，这种情况比线程更复杂，需要更多的内存，但它可以更好利用多个 CPU。

这个例子 fork 出 10 个进程，比只有 1 个进程要完成更快，因为进程在多核中并行运行。但是 10 个线程与 1 个线程相比，并不会完成更快，因为在一个时间点只有 1 个线程可以执行 Python：

```Python
import os
import sys
nums =[1 for _ in range(1000000)]
chunk_size = len(nums) // 10
readers = []
while nums:
    chunk, nums = nums[:chunk_size], nums[chunk_size:]
    reader, writer = os.pipe()
    if os.fork():
        readers.append(reader)  # Parent.
    else:
        subtotal = 0
        for i in chunk: # Intentionally slow code.
            subtotal += i
        print('subtotal %d' % subtotal)
        os.write(writer, str(subtotal).encode())
        sys.exit(0)
# Parent.
total = 0
for reader in readers:
    subtotal = int(os.read(reader, 1000).decode())
    total += subtotal
print("Total: %d" % total)
```

因为每个 fork 的进程有一个单独的 GIL，这个程序可以把工作分派出去，并一次运行多个计算。

（Jython 和 IronPython 提供单进程的并行，但它们远没有充分实现 CPython 的兼容性。有软件事务内存的 PyPy 有朝一日可以运行更快。如果你对此好奇，试试这些解释器。）