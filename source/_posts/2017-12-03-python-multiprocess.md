---
layout: post
title: python中的并发之多进程
date: 2017-12-03
update: 2018-04-12
categories: Python
tags: [python, 多进程, multiprocessing]
---

在python的并发变成中，由于GIL的限制（参考我的文章：CPython中的全局解释锁），多线程无法很好的应对计算密集型的并发情况，这时候就需要使用多进程的方法进行解决。

<!--more-->

python在 `os` 模块中，对Linux的fork函数进行了封装，可以很简单的就创建了一个子进程：

```python
import os

print 'Process (%s) start...' % os.getpid()
pid = os.fork()
if pid==0:
    print 'I am child process (%s) and my parent is %s.' % (os.getpid(), os.getppid())
else:
    print 'I (%s) just created a child process (%s).' % (os.getpid(), pid)
```

但windows上面没有fork函数，而且这种方法过于粗糙，所以一般使用跨平台版本的多进程模块 `multiprocessing` 来进行多进程编程。

## `multiprocessing` 使用

### 创建进程

利用 `multiprocessing` 模块创建一个进程非常简单：

```python
from multiprocessing import Process
import os

# 子进程要执行的代码
def run_proc(name):
    print 'Run child process %s (%s)...' % (name, os.getpid())

if __name__=='__main__':
    print 'Parent process %s.' % os.getpid()
    p = Process(target=run_proc, args=('test',))
    print 'Process will start.'
    p.start()
    p.join()
    print 'Process end.'
```

执行结果如下：

```
Parent process 5928.
Process will start.
Run child process test (5929)...
Process end.
```

### 进程池

如果需要大量的子进程，可以利用进程池的方法来批量创建子进程

```python
from multiprocessing import Pool
import os, time, random

def long_time_task(name):
    print 'Run task %s (%s)...' % (name, os.getpid())
    start = time.time()
    time.sleep(random.random() * 3)
    end = time.time()
    print 'Task %s runs %0.2f seconds.' % (name, (end - start))

if __name__=='__main__':
    print 'Parent process %s.' % os.getpid()
    p = Pool()
    for i in range(5):
        p.apply_async(long_time_task, args=(i,))
    print 'Waiting for all subprocesses done...'
    p.close()
    p.join()
    print 'All subprocesses done.'
```

执行结果如下：

```
Parent process 669.
Waiting for all subprocesses done...
Run task 0 (671)...
Run task 1 (672)...
Run task 2 (673)...
Run task 3 (674)...
Task 2 runs 0.14 seconds.
Run task 4 (673)...
Task 1 runs 0.27 seconds.
Task 3 runs 0.86 seconds.
Task 0 runs 1.41 seconds.
Task 4 runs 1.91 seconds.
All subprocesses done.
```

* `Pool` 函数创建一个进程池，可以传入子进程的数量，默认使用 `multiprocessing.cpu_count()` 方法来获取CPU的核心数目，并以此创建子进程的数量
    * 这么做的原因在于，理论上，CPU在某一时间能够同时运行的进程数目不会大于核心数目，更多的进程则需要等待
* `apply_async` 采用异步的方式提交一个子进程的任务，其对应的同步方法是 `apply`，如果使用同步的方法，则会父进程会阻塞，直到子进程返回结果。
* `close` 关闭进程池，不接受新的任务（当前任务不会被关闭）
    * 对应有个 `terminate`方法，会结束所有工作的子进程，不再处理未完成的任务。
* `join` 父进程等待子进程执行完毕

除了for循环以外，还可以利用map的方式来批量执行子进程

```python 
# -*- coding: utf-8 -*-
import multiprocessing as mp


def job(x):
    return x[0] + x[1]


if __name__ == '__main__':
    pool = mp.Pool(processes=3)  # 定义CPU核数量为3
    res = pool.map(job, zip(range(10), range(10)))
    print(res)
```

运行结果：

```
[0, 2, 4, 6, 8, 10, 12, 14, 16, 18]
```

* map的用法和python自带的map很像，而且能够直接获取函数的返回结果

### 获取子进程的结果

从通俗的意义上来讲，获取子进程的结果可以归纳为IPC，python对于这方面在 `multiprocessing` 模块中也进行了一些封装，这个需要开辟一个新的话题来讲。这里给出一些简单的获取子进程的结果的方法。

#### `map` 方式直接获取结果

如前面例子所示，利用map可以传入一系列的值，并直接获得这些值的执行结果

#### 获取`apply_async`的结果

`pool.apply_async`返回的是一个Process对象，这个对象会异步执行，我们可以在执行结束后，利用`get`方法获取结果，具体操作如下：

```python
import multiprocessing
import time

def func(msg):
    print "msg:", msg
    time.sleep(3)
    print "end"
    return "done" + msg

if __name__ == "__main__":
    pool = multiprocessing.Pool(processes=4)
    result = []
    for i in xrange(3):
        msg = "hello %d" %(i)
        result.append(pool.apply_async(func, (msg, )))
    pool.close()
    pool.join()
    for res in result:
        print ":::", res.get()
    print "Sub-process(es) done."
```

执行结果：

```
msg: hello 0
msg: hello 1
msg: hello 2
end
end
end
::: donehello 0
::: donehello 1
::: donehello 2
Sub-process(es) done.
```

一定要注意的是，不要在创建子进程之后立马调用get()，因为get()会阻塞，知道结果返回，所以一般在join之后才调用get()

## 遇到的一些问题

在我使用 `multiprocessing` 包的过程中能够，遇到过一个问题，有必要记录一下。

定义一个类，然后使用类的方法进行并发运算，大概如下：

```python

import multiprocessing as mp

class A():
    def run(i):
        return i * i

pool = mp.Pool(3)
results = []
for i in range(10):
    results.append(
        pool.apply_async(A().run, args=(i,)))

pool.close()
pool.join()
for r in results:
    print r.get()
```

**报错：Can’t pickle instancemethod …**，意思大概是类的方法进行打包的过程中出错。

查阅了资料，发现有人提到：

> python的multiprocessing pool进程池隐形的加入了一个任务队列，在你apply_async的时候，他会使用pickle序列化对象，但是python 2.x的pickle应该是不支持这种模式的序列化. 

所以就会出错，解决方法大概有：

* 不使用Pool，而是用Process函数来实例化子进程，这样不会产生队列
* 不使用类的方法来创建子进程
* 利用getattr对定义在类中的方法进行包装
* ...

具体可参考这篇 [博文](http://xiaorui.cc/2016/01/18/python-multiprocessing%E9%81%87%E5%88%B0cant-pickle-instancemethod%E9%97%AE%E9%A2%98/)

