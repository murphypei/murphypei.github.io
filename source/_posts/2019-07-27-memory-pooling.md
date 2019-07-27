---
title: C++ 简单内存池实现
date: 2019-07-27 13:54:03
update: 2019-07-27 13:54:03
categories: C++
tags: [C++, 内存池, memory pooling, malloc]
---

我之前记录过一个关于 Linux 的 `malloc` 堆管理的详细介绍：[Linux 堆内存管理深入分析](https://murphypei.github.io/blog/2019/01/linux-heap.html)，这篇文章是一个简易的 C++ 内存池的 demo。

<!-- more -->

### 为什么需要内存池？

和线程池类似，这种 xx 池一般都是处于一个共同的目的：减少资源的频繁申请和释放。如果读了之前那篇堆管理的文章我们就知道，实际内存管理是非常复杂的，并不是每次 `malloc` 和 `free` 都是简单的申请和释放，这涉及一个效率问题，特别是在频繁的小容量的内存申请的时候。

一般在初始化的时候申请可用资源，然后重复利用这些资源，最后在不需要的时候统一销毁。

这里要说明一下，现代编译器的 `malloc` 管理内存的方式本质就是内存池，`malloc` 从操作系统申请堆内存，然后将内存划分给应用程序，并进行内存的释放，合并等等管理。大多数情况下，可能你自己设计的内存池还不如 `malloc` 管理的好，毕竟这些库都是很多人测试很多次了。因此，**请谨慎判断是否需要内存池以及如何设计内存池**。本文仅仅作为一个简单的 demo 来说明内存池的工作原理而已。

### 内存池示例

下面主要以代码的方式进行说明。

#### 全局内存管理

首先看一下平时没有内存池的时候对象的生成和释放：

```c++
#define TEST_NUMBER 1000
#define ARRAY_SIZE 10000

class Rational
{
public:
    Rational(int a, int b = 1) : n(a), d(b) {}

private:
    int n;
    int d;
};

int main()
{
    Rational *arr[ARRAY_SIZE];
    for (int i = 0; i < TEST_NUMBER; i++)
    {
        for (int j = 0; j < ARRAY_SIZE; ++j)
        {
            arr[j] = new Rational(j);
        }
        for (int j = 0; j < ARRAY_SIZE; ++j)
        {
            delete arr[j];
        }
    }
}
```

这种默认的时候就是使用全局的内存管理器，`new` 操作符调用对象的默认 `operator new` 函数申请内存，`operator new` 函数内部调用 `malloc` 申请能够放下对象的内存（大于等于对象的大小）。然后 `new` 操作符调用类的构造函数堆这块内存进行初始化。 `delete` 操作符则相反，先调用类的析构函数，然后调用 `free` 释放内存（不一定会返回给操作系统）。

#### 类专用内存池

现在针对我们要用的这个类，使用一个专用的内存池：

```C++
#include <cstddef>
#include <cstdlib>

using namespace std;

#define TEST_NUMBER 1000

#define ARRAY_SIZE 10000

class NextOnFreeList
{
public:
    NextOnFreeList *next;
};

class Rational
{
public:
    Rational(int a = 0, int b = 1) : n(a), d(b) {}

    void *operator new(size_t size)
    {
        if (freeList == nullptr)
        {
            expandFreeList();
        }
        auto head = freeList;
        freeList = head->next;
        return head;
    }

    void operator delete(void *doomed)
    {
        NextOnFreeList *head = static_cast<NextOnFreeList *>(doomed);
        head->next = freeList;
        freeList = head;
    }

    static void newMemPool() { expandFreeList(); }
    static void deleteMemPool();

private:
    static NextOnFreeList *freeList;
    static void expandFreeList();
    static const size_t EXPANSION_SIZE;
    int n;
    int d;
};

void Rational::deleteMemPool()
{
    char *nextPtr = (char *)freeList;
    while (nextPtr != nullptr)
    {
        freeList = freeList->next;
        delete[] nextPtr;
        nextPtr = (char *)freeList;
    }
}

const size_t Rational::EXPANSION_SIZE = 64;
NextOnFreeList *Rational::freeList = nullptr;

void Rational::expandFreeList()
{
    // We must allocate an object large enough to contain the next pointer.  
    size_t size = (sizeof(Rational) > sizeof(NextOnFreeList *)) ? sizeof(Rational) : sizeof(NextOnFreeList *);
    NextOnFreeList *runner = (NextOnFreeList *)(new char[size]);
    freeList = runner;
    for (int i = 0; i < Rational::EXPANSION_SIZE; ++i)
    {
        runner->next = (NextOnFreeList *)(new char[size]);
        runner = runner->next;
    }
    runner->next = nullptr;
}

int main()
{
    Rational *array[ARRAY_SIZE];

    Rational::newMemPool();

    for (int j = 0; j < TEST_NUMBER; j++)
    {
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            array[i] = new Rational(i);
        }
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            delete array[i];
        }
    }

    Rational::deleteMemPool();
}
```

解释一下：

`Rational` 这个类维持一个自己类对象专用的内存池，通过 `NextOnFreeList` 表示的一个空白内存链表进行维护。当我们需要申请内存的时候，直接将 `operator new` 指向空白链表中第一个节点，因此不需要再调用 `malloc` 了，而当链表没有空间了，则通过 `expandFreeList` 进行批量（`EXPANSION_SIZE`）的扩充，一次申请多块内存。释放的过程则直接将对象所在的节点加入到空白链表的头部，因此也不需要释放内存，减少了内存碎片的管理消耗。

这个空白链表很有意思，在分配的时候，我们将其看作一个 `NextOnFreeList` 节点，其中包含一个指针，指向下一个空白的内存块。而在使用的时候将其看作一个 `Rational` 对象存放的内存，因此申请的内存大小是二者的最大值。

#### 类模板内存池

上述的内存池是 `Rational` 这个类专用的内存池，将上述代码改一改我们就能得到一个适用于不同类的内存池模板了。

```C++
#include <cstddef>
#include <cstdlib>

using namespace std;

#define TEST_NUMBER 1000

#define ARRAY_SIZE 10000

template <typename T>
class MemoryPool
{
public:
    MemoryPool(size_t size = EXPANSION_SIZE);
    ~MemoryPool();

    void *alloc(size_t size)
    {
        if (next != nullptr)
        {
            expandFreeList();
        }
        auto head = next;
        next = next->next;
        return head;
    }
    void free(void *doomed)
    {
        MemoryPool<T> *head = (MemoryPool<T> *)doomed;
        // merge head to freeList front
        head->next = next;
        next = head;
    }

private:
    MemoryPool<T> *next;
    void expandFreeList(size_t size = EXPANSION_SIZE);
    static const size_t EXPANSION_SIZE = 32;
};

template <typename T>
MemoryPool<T>::MemoryPool(size_t size)
{
    expandFreeList(size);
}

template <typename T>
MemoryPool<T>::~MemoryPool()
{
    char *nextPtr = (char *)next;
    while (nextPtr != nullptr)
    {
        next = next->next;
        delete[] nextPtr;
        nextPtr = (char *)next;
    }
}

template <typename T>
void MemoryPool<T>::expandFreeList(size_t size)
{
    size_t memSize = sizeof(T) > sizeof(MemoryPool<T> *) ? sizeof(T) : sizeof(MemoryPool<T> *);
    MemoryPool<T> *runner = (MemoryPool<T> *)new char[memSize];
    next = runner;
    for (size_t i = 0; i < size - 1; ++i)
    {
        runner->next = (MemoryPool<T> *)new char[memSize];
        runner = runner->next;
    }
}

class Rational
{
public:
    Rational(int a = 0, int b = 1) : n(a), d(b) {}

    void *operator new(size_t size)
    {
        return memPool->alloc(size);
    }
    void operator delete(void *doomed)
    {
        memPool->free(doomed);
    }

    static void newMemPool() { memPool = new MemoryPool<Rational>; }
    static void deleteMemPool() { delete memPool; }

private:
    int n; // Numerator
    int d; // Denominator

    static MemoryPool<Rational> *memPool;
};

MemoryPool<Rational> *Rational::memPool = 0;

int main()
{
    Rational *array[ARRAY_SIZE];
    Rational::newMemPool();

    for (int j = 0; j < TEST_NUMBER; j++)
    {
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            array[i] = new Rational(i);
        }
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            delete array[i];
        }
    }

    Rational::deleteMemPool();
}
```

`MemoryPool` 可以看作将类作为模板参数包装的内存池，其原理和上述基本一模一样。而类的 `operator new` 和 `operator delete` 则通过调用 `MemoryPool` 的接口实现了内存的管理。

#### 可变大小块内存池

上述的 `MemoryPool` 虽然适用于不同的类，但是其特化本质还是固定大小的，我们知道 `malloc` 可以申请任意大小的内存，我们的内存池往往也需要申请这种任意大小的内存块。

```C++
#include <cstddef>
#include <cstdlib>

using namespace std;

#define TEST_NUMBER 1000

#define ARRAY_SIZE 10000

class MemoryChunk
{
public:
    MemoryChunk(MemoryChunk *nextChunk, size_t chunkSize);
    ~MemoryChunk()
    {
        delete[](char *) mem;
    }

    void *alloc(size_t requestSize)
    {
        void *addr = static_cast<void *>((char *)mem + bytesAlreadyAllocated);
        bytesAlreadyAllocated += requestSize;
        return addr;
    }

    void free(void *doomed)
    {
        // TODO: merge free chunk
    }

    MemoryChunk *nextMemChunk()
    {
        return next;
    }

    size_t spaceAvailable()
    {
        return chunkSize - bytesAlreadyAllocated;
    }

    static const size_t DEFAULT_CHUNK_SIZE = 4096;

private:
    MemoryChunk *next;
    void *mem;
    size_t chunkSize;
    size_t bytesAlreadyAllocated;
};

MemoryChunk::MemoryChunk(MemoryChunk *nextChunk, size_t requestSize)
{
    chunkSize = (requestSize > DEFAULT_CHUNK_SIZE) ? requestSize : DEFAULT_CHUNK_SIZE;
    next = nextChunk;
    bytesAlreadyAllocated = 0;
    mem = new char[chunkSize];
}

class ByteMemoryPool
{
public:
    ByteMemoryPool(size_t initSize = MemoryChunk::DEFAULT_CHUNK_SIZE);
    ~ByteMemoryPool();

    void *alloc(size_t size);
    void free(void *doomed);

private:
    MemoryChunk *listOfMemoryChunks;
    void expandStorage(size_t requestSize);
};

ByteMemoryPool::ByteMemoryPool(size_t initSize) : listOfMemoryChunks(nullptr)
{
    expandStorage(initSize);
}

ByteMemoryPool::~ByteMemoryPool()
{
    MemoryChunk *memChunk = listOfMemoryChunks;
    while (memChunk)
    {
        listOfMemoryChunks = memChunk->nextMemChunk();
        delete memChunk;
        memChunk = listOfMemoryChunks;
    }
}

void *ByteMemoryPool::alloc(size_t requestSize)
{
    size_t space = listOfMemoryChunks->spaceAvailable();

    // if there is not enough empty size in current chunk,  expand an new chunk and add to chunk list.
    if (space < requestSize)
    {
        expandStorage(requestSize);
    }

    return listOfMemoryChunks->alloc(requestSize);
}

inline void ByteMemoryPool::free(void *doomed)
{
    listOfMemoryChunks->free(doomed);
}

void ByteMemoryPool::expandStorage(size_t requestSize)
{
    listOfMemoryChunks = new MemoryChunk(listOfMemoryChunks, requestSize);
}

class Rational
{
public:
    Rational(int a = 0, int b = 1) : n(a), d(b) {}

    void *operator new(size_t size)
    {
        return memPool->alloc(size);
    }

    void operator delete(void *doomed)
    {
        memPool->free(doomed);
    }

    static void newMemPool() { memPool = new ByteMemoryPool; }
    static void deleteMemPool() { delete memPool; }

private:
    int n; // Numerator
    int d; // Denominator

    static ByteMemoryPool *memPool;
};

ByteMemoryPool *Rational::memPool = nullptr;

int main()
{
    Rational *array[ARRAY_SIZE];

    Rational::newMemPool();

    for (int j = 0; j < TEST_NUMBER; j++)
    {
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            array[i] = new Rational(i);
        }
        for (int i = 0; i < ARRAY_SIZE; i++)
        {
            delete array[i];
        }
    }

    Rational::deleteMemPool();
}
```

* `MemoryChunk` 和 `malloc` 中的 `chunk` 很像，可以是任意大小的，不同的 `MemoryChunk` 以链表的方式连接在一起。每个 `MemoryChunk` 记录块的大小和已经使用的内存大小。
* `ByteMemoryPool` 就是维护的内存池，当我们需要 `alloc` 的时候，我们检查当前的 `MemoryChunk` 是否有足够的空间来分配使用，不够的话则需要扩充一个大块，然后将其加入到链表中。


最后再次强调，这个内存池 demo 非常的粗糙，远不及之前那篇堆内存管理介绍的那么复杂，仅仅是作为一个说明，说明内存池基本的工作原理。当然，内存池的管理还有多线程等等诸多复杂的问题需要考虑，因此才有开头我说的，一定要想想自己设计的需求以及性能。