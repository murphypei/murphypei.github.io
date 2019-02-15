---
title: Linux堆内存管理深入分析
date: 2019-01-26 09:19:44
update: 2019-01-26 09:19:44
categories: C++
tags: [C++, heap, chunk, 堆内存管理]
---

最近看了一篇堆内存管理的分析文章，觉得非常棒，结合一些其他博文的参考，整理记录。

<!--more-->

[Understanding glibc的malloc](https://sploitfun.wordpress.com/2015/02/10/understanding-glibc-malloc/comment-page-1/)是一篇非常优秀的文章，深入浅出的介绍了Linux的堆内存分配情况，下面就是对原文的一些翻译和理解，表达其中的意思，并不是原本照搬，有兴趣建议阅读原文。

## 堆内存管理机制介绍

不同平台的堆内存管理机制不相同，下面是几个常见平台的堆内存管理机制：

| 平台 | 堆内存分配机制 |
| :--: | :--: |
| dlmalloc | General purpose allocator |
| ptmalloc2 | glibc |
| jemalloc |  free BSD and Firefox |
| tcmalloc |  Google |
| libumem  |  Solaris |

本文主要学习介绍在Linux的`glibc`使用的`ptmalloc2`实现原理。本来linux默认的是`dlmalloc`，但是由于其不支持多线程堆管理，所以后来被支持多线程的`prmalloc2`代替了。当然在linux平台`malloc`本质上都是通过系统调用`brk`或者`mmap`实现的。原文作者的另一篇文章也介绍的很清楚[Syscalls used by malloc](https://sploitfun.wordpress.com/2015/02/11/syscalls-used-by-malloc/)。鉴于篇幅，本文就不加以详细说明了，只是为了方便后面对堆内存管理的理解，截取其中函数调用关系图：

![](/images/posts/cplusplus/heap/malloc-func-call.png)

再来一张进程的虚拟内存分布示意图：

![](/images/posts/cplusplus/heap/linuxFlexibleAddressSpaceLayout.png)

**注意：**

* 这个图是**32位系统的进程虚拟内存分布，所以最大是4G(2^32)**，内核默认占用1G
* `0x08048000`这个地址也是针对32位系统而言，64位系统是`0x00400000`clang++ -std=c++11 test_malloc.cpp -lpthread

请仔细记住这张图中，不同内存区域的位置,可以看到heap的内存大小与一个**brk指针**有关，这个就是heap内存的尾指针，而系统`brk`函数就是通过改变这个brk指针来进行内存的分配。

## 堆内存分配实验

实验代码：

```c++
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>

void* threadFunc(void *arg)
{
    printf("Before malloc in thread 1\n");
    getchar();
    char* addr = (char*)malloc(1000);
    printf("After malloc and before free in thread 1\n");
    getchar();
    free(addr);
    printf("After free in thread 1\n");
    getchar();
}

int main()
{
    pthread_t t1;
    void *s;
    int ret;
    char* addr;

    printf("Welcome to per thread arena example: %d\n", getpid());
    printf("Before malloc in main thread\n");
    getchar();
    addr = (char*) malloc(1000);
    printf("After malloc and before free in main thread\n");
    getchar();
    free(addr);
    printf("After free in main thread\n");
    getchar();
    ret = pthread_create(&t1, NULL, threadFunc, NULL);
    if (ret)
    {
        printf("Thread creation error\n");
        return -1;
    }
    ret = pthread_join(t1, &s);
    if (ret)
    {
        printf("THread join error\n");
        return -1;
    }
    return 0;
}
```

编译：`clang++ -std=c++11 test_malloc.cpp -lpthread`

运行结果和分析如下：

#### 1. Before malloc in main thread 

![](/images/posts/cplusplus/heap/heap-maps1.png)

可以看到，在本机上（Ubuntu16.04，x64），在主线程调用`malloc`之前，就已经给主线程分配了一块堆内存，这和原文作者在32位机上的实验结果是不同的。这块**默认大小的内存是200KB**。

heap是紧接着数据段的，说明这个系统是通过`brk`来进行内存分配的，和作者实验结果相同。

#### 2. After malloc in main thread

![](/images/posts/cplusplus/heap/heap-maps2.png)

（不小心ctrl+c了，所以进程id不一样），在主线程中调用`malloc`之后，发现**heap仍然是200K**，我分析是因为默认分配的内存够用，因此`malloc`并没有引起heap的自增长。作者原文中有一种解释：

> 还可以看出虽然我们只申请了1000字节的数据，但是系统却分配了132KB大小的堆，这是为什么呢？原来这132KB的堆空间叫做`arena`，此时因为是主线程分配的，所以叫做`main arena`(每个`arena`中含有多个`chunk`，这些`chunk`以链表的形式加以组织)。由于132KB比1000字节大很多，所以主线程后续再申请堆空间的话，就会先从这132KB的剩余部分中申请，直到用完或不够用的时候，再通过增加**program break location**的方式来增加`main arena`的大小。同理，当`main arena`中有过多空闲内存的时候，也会通过减小**program break location**的方式来缩小`main arena`的大小。

#### 3. After free in main thread

`free`之后，heap分布还是之前那样，没变（懒得截图了）。这里和原文实验结果也相同，原文也给出了解释：

> 在主线程调用`free`之后，从内存布局可以看出程序的堆空间并没有被释放掉，原来调用`free`函数释放已经分配了的空间并非直接“返还”给系统，而是由`glibc`的`malloc`库函数加以管理。它会将释放的`chunk`添加到`main arena`的`bin`(这是一种用于存储同类型`free chunk`的双链表数据结构，后问会加以详细介绍，请记住)中。在这里，记录空闲空间的`free list`数据结构称之为`bins`。之后当用户再次调用`malloc`申请堆空间的时候，`glibc`的`malloc`会先尝试从`bins`中找到一个满足要求的`chunk`，如果没有才会向操作系统申请新的堆空间。

#### 4. Before malloc in thread1

![](/images/posts/cplusplus/heap/heap-maps3.png)

请注意红色框这一部分地址，和下面的`/lib/x86_64-linux-gnu/libc-2.23.so`等动态库位于的`Memory Mapping Segment`区域的地址很接近，结合上图的内存分布图可以知道，**就地址而言：stack > Memory Mapping Segment > heap**。这里有一个知识：**Linux子线程是由mmap创建的，所以其栈是位于`Memory Mapping Segment`区域**（可参见：[Where are the stacks for the other threads located in a process virtual address space?](https://stackoverflow.com/questions/44858528/where-are-the-stacks-for-the-other-threads-located-in-a-process-virtual-address)）。因此可以看出，**在子线程`malloc`之前，已经创建了子线程的stack，其大小是8MB**。

#### 5. After malloc in thread1

![](/images/posts/cplusplus/heap/heap-maps4.png)

继续关注红色区域的地址，**在malloc之后，为子线程分配了堆**，这个大小是132K（这个大小倒是和原文的一致），并且同样是位于`Memory Mapping Segment`区域，这部分区域就是thread1的堆空间，即thread1 的`arena`。

同时还要注意，子线程分配的空间是`Memory Mapping Segment`向下增长的，也就是向堆区增长。

所以可以确定的是，子线程的堆栈都是分配在`Memory Mapping Segment`和`Heap`之间的区域。虚拟内存的分布图中我们可以看到，在3GB的用户进程空间中，地址最高处的栈所占用的比较少（主线程的栈一般是16MB或者8MB），然后`Memory Mapping Segment`也不大，而初始化的`Heap`区域也很小。所以`Memory Mapping Segment`和`Heap`之间的区域是非常大的。（注意，图中颜色区域只是示意，并不代表实际大小）。

#### 6. After `free` in thread1

同 main thread。

## arena介绍

### arena数量限制

前文提到`main thread`和`thread1`有自己独立的`arena`，那么是不是无论有多少个线程，每个线程都有自己独立的`arena`呢？答案是否定的。事实上，`arena`的个数是跟系统中处理器核心个数相关的，如下表所示：

| systems | number of arena |
| :--: | :--: |
| 32bits | 2 x number of cpu cores + 1 |
| 64bits | 8 x number of cpu cores + 1 |

### 多arena的管理

假设有如下情境：一台只含有一个处理器核心的PC机安装有32位操作系统，其上运行了一个多线程应用程序，共含有4个线程——主线程和三个用户线程。显然线程个数大于系统能维护的最大`arena`个数（2x核心数 + 1= 3），那么此时`glibc`的`malloc`就需要确保这4个线程能够正确地共享这3个`arena`，那么它是如何实现的呢？

当主线程首次调用`malloc`的时候，`glibc`的`malloc`会直接为它分配一个`main arena`，而不需要任何附加条件。

当用户线程1和用户线程2首次调用`malloc`的时候，`glibc`的`malloc`会分别为每个用户线程创建一个新的`thread arena`。此时，各个线程与`arena`是一一对应的。但是，当用户线程3调用`malloc`的时候，就出现问题了。因为此时`glibc`的`malloc`能维护的`arena`个数已经达到上限，无法再为线程3分配新的`arena`了，那么就需要重复使用已经分配好的3个`arena`中的一个(`main arena`, `arena1`或者`arena2`)。那么该选择哪个`arena`进行重复利用呢？

(1) 首先，`glibc`的`malloc`循环遍历所有可用的`arena`，在遍历的过程中，它会尝试lock该`arena`。如果成功lock(该`arena`当前对应的线程并未使用堆内存则表示可lock)，比如将`main arena`成功lock住，那么就将`main arena`返回给用户，即表示该`arena`被线程3共享使用。

(2) 而如果没能找到可用的`arena`，那么就将线程3的`malloc`操作阻塞，直到有可用的`arena`为止。

(3) 现在，如果线程3再次调用`malloc`的话，`glibc`的`malloc`就会先尝试使用最近访问的`arena`(此时为`main arena`)。如果此时`main arena`可用的话，就直接使用，否则就将线程3阻塞，直到`main arena`再次可用为止。

这样线程3与主线程就共享`main arena`了。至于其他更复杂的情况，以此类推。

## 堆管理详情介绍

在`glibc`的`malloc`中针对堆管理，主要涉及到以下3种数据结构：

#### 1. heap_info

即`heap header`，因为一个`thread arena`（注意：不包含`main thread`）可以包含多个heaps，所以为了便于管理，就给每个heap分配一个`heap header`。

那么在什么情况下一个`thread arena`会包含多个heaps呢？**在当前heap不够用的时候，`malloc`会通过系统调用`mmap`申请新的堆空间（这部分空间本来是位于`Memory Mapping Segment`区域），新的堆空间会被添加到当前`thread arena`中，便于管理。**

```c++
typedef struct _heap_info
{
  mstate ar_ptr;                /* arena for this heap. */
  struct _heap_info *prev;      /* Previous heap. */
  size_t size;                  /* Current size in bytes. */
  size_t mprotect_size;         /* Size in bytes that has been mprotected
                                   PROT_READ|PROT_WRITE.  */
   /* Make sure the following data is properly aligned, particularly
      that sizeof (heap_info) + 2 * SIZE_SZ is a multiple of
      MALLOC_ALIGNMENT. */
  char pad[-6 * SIZE_SZ & MALLOC_ALIGN_MASK];
} heap_info;
```

#### 2. malloc_state

即`arena header`，每个thread只含有一个`arena header`。`arena header`包含`bins`的信息、`top chunk`以及最后一个`remainder chunk`等(这些概念会在后文详细介绍):

```c++
struct malloc_state
{
  /* Serialize access.  */
  mutex_t mutex;
  
  /* Flags (formerly in max_fast).  */
  int flags;

  /* Fastbins */
  mfastbinptr fastbinsY[NFASTBINS];

  /* Base of the topmost chunk -- not otherwise kept in a bin */
  mchunkptr top;

  /* The remainder from the most recent split of a small request */
  mchunkptr last_remainder;

  /* Normal bins packed as described above */
  mchunkptr bins[NBINS * 2 - 2];

  /* Bitmap of bins */
  unsigned int binmap[BINMAPSIZE];

  /* Linked list */
  struct malloc_state *next;

  /* Linked list for free arenas.  */
  struct malloc_state *next_free;

  /* Memory allocated from the system in this arena.  */
  INTERNAL_SIZE_T system_mem;
  INTERNAL_SIZE_T max_system_mem;
};
```

#### 3. malloc_chunk(chunk header)

一个heap被分为多个`chunk`，至于每个`chunk`的大小，这是根据用户的请求决定的，也就是说用户调用`malloc(size)`传递的size参数“就是”`chunk`的大小(这里给“就是“加上引号，说明这种表示并不准确，但是为了方便理解就暂时这么描述了，详细说明见后文)。每个`chunk`都由一个结构体`malloc_chunk`表示。

```c++
struct malloc_chunk {
  /* #define INTERNAL_SIZE_T size_t */
  INTERNAL_SIZE_T      prev_size;  /* Size of previous chunk (if free).  */
  INTERNAL_SIZE_T      size;       /* Size in bytes, including overhead. */
  struct malloc_chunk* fd;         /* double links -- used only if free. 这两个指针只在free chunk中存在*/
  struct malloc_chunk* bk;

  /* Only used for large blocks: pointer to next larger size.  */
  struct malloc_chunk* fd_nextsize; /* double links -- used only if free. */
  struct malloc_chunk* bk_nextsize;
};
```

**注意：**

> 1. Main thread不含有多个heaps所以也就不含有`heap_info`结构体。当需要更多堆空间的时候，就通过扩展`sbrk`的`heap segment`来获取更多的空间，直到它碰到内存`mapping`区域为止。
> 2. 不同于`thread arena`，`main arena`的`arena header`并不是`sbrk`的`heap segment`的一部分，而是一个全局变量！因此它属于`libc.so`的data segment。

### heap segment与arena关系

首先，通过内存分布图理清`malloc_state`与`heap_info`之间的组织关系。下图是只有一个`heap segment`的`main arena`和`thread arena`的内存分布图：

![](/images/posts/cplusplus/heap/arena-single-segment.png)

下图是一个`thread arena`中含有多个heap segments的情况：

![](/images/posts/cplusplus/heap/arena-multi-segments.png)

从上图可以看出，`thread arena`只含有一个`malloc_state`(即`arena header`)，却有两个`heap_info`(即`heap header`)。由于两个`heap segments`是通过`mmap`分配的内存，两者在内存布局上并不相邻而是分属于不同的内存区间，所以为了便于管理，`glibc`的`malloc`将第二个`heap_info`结构体的`prev`成员指向了第一个`heap_info`结构体的起始位置（即`ar_ptr`成员），而第一个`heap_info`结构体的`ar_ptr`成员指向了`malloc_state`，这样就构成了一个单链表，方便后续管理。

## chunk介绍

在`glibc`的`malloc`中将整个堆内存空间分成了连续的、大小不一的`chunk`，即对于堆内存管理而言`chunk`就是最小操作单位。`chunk`总共分为4类：

* `allocated chunk`
* `free chunk`
* `top chunk`
* `last remainder chunk`

从本质上来说，所有类型的`chunk`都是内存中一块连续的区域，只是通过该区域中特定位置的某些标识符加以区分。为了简便，我们先将这4类`chunk`简化为2类：`allocated chunk`以及`free chunk`，前者表示已经分配给用户使用的`chunk`，后者表示未使用的`chunk`。

众所周知，无论是何种堆内存管理器，其完成的核心目的都是能够高效地分配和回收内存块(`chunk`)。因此，它需要设计好相关算法以及相应的数据结构，而数据结构往往是根据算法的需要加以改变的。既然是算法，那么算法肯定有一个优化改进的过程，所以本文将根据堆内存管理器的演变历程，逐步介绍在`glibc`的`malloc`中`chunk`这种数据结构是如何设计出来的，以及这样设计的优缺点。

任何堆内存管理器都是以`chunk`为单位进行堆内存管理的，而这就需要一些数据结构来标志各个块的边界，以及区分已分配块和空闲块。大多数堆内存管理器都将这些边界信息作为`chunk`的一部分嵌入到`chunk`内部。**堆内存中要求每个`chunk`的大小必须为8的整数倍**，因此`chunk size`的后3位是无效的，为了充分利用内存，堆管理器将这3个比特位用作`chunk`的标志位，典型的就是将第0比特位用于标记该`chunk`是否已经被分配。这样的设计很巧妙，因为我们只要获取了一个指向`chunk size`的指针，就能知道该`chunk`的大小，即确定了此`chunk`的边界，且利用`chunk size`的第0比特位还能知道该`chunk`是否已经分配，这样就成功地将各个`chunk`区分开来。注意在`allocated chunk`中，如果一个`chunk`的大小不是8的整数倍，需要填充部分`padding`数据进行对齐。

#### 1. allocated chunk

![](/images/posts/cplusplus/heap/allocated-chunk.png)

顾名思义，是已经被分配使用的`chunk`，区域内容表示如下：

* `prev_size`: 如果前一个`chunk`是`free`的，则这个内容保存的是前一个`chunk`的大小. 如果前一个`chunk`已经被使用了，则这个区域保存的是前一个`chunk`的用户数据（一部分而已，主要是为了能够充分利用这块内存空间）。
* `size`: 保存的是当前这个`chunk`的大小。总共是32bits，并且最后的3位作为标志位。

三个标志位的意义：

* `PREV_INUSE (P)`: 表示前一个`chunk`是否为allocated.（当前`chunk`是不是allocated可以通过查询下一个`chunk`的这个标志位来得知）
* `IS_MMAPPED (M)`: 表示当前`chunk`是否是通过`mmap`系统调用产生的。（`mmap`或者`brk`）
* `NON_MAIN_arena (N)`: 表示当前`chunk`是否是main thread `arena`。（也就是非主线程的`arena`，用于支持多线程）

**`chunk`设计意义：**

* 每个`chunk`的大小怎么确定？
    * 调用malloc时传入的大小就是当前分配的`chunk`大小
* 我们为什么要知道前一个`chunk`的大小？
    * 为了方便合并不同的`chunk`，减少内存的碎片化。如果不这么做，`chunk`的合并只能向下合并，必须从头遍历整个堆，然后加以合并，这就意味着每次进行`chunk`释放操作消耗的时间与堆的大小成线性关系。
* `chunk`的链表是如何构成的
    * `chunk`在堆内存上是连续的，并不是直接由指针构成的链表，而是通过`prev_size`和`size`块构成了隐式的链表。在进行分配操作的时候，堆内存管理器可以通过遍历整个堆内存的`chunk`，分析每个`chunk`的`size`字段，进而找到合适的`chunk`。

#### 2. free chunk

![](/images/posts/cplusplus/heap/free-chunk.png)

* `prev_size`: 为了防止碎片化，堆中不存在两个相邻的`free chunk`（如果存在，则被堆管理器合并了）。因此对于一个`free chunk`，这个prev_size区域中一定包含的上一个`chunk`的部分有效数据或者为了地址对齐所做的padding。
* `size`: 同`allocated chunk`，表示当前`chunk`的大小
* `N`, `M`, `P`: 同`allocated chunk`
* `fd`: 前向指针——指向当前`chunk`在同一个bin（一种用于加快内存分配和释放效率的显示链表）的下一个`chunk`
* `bk`: 后向指针——指向当前`chunk`在同一个bin的上一个`chunk`

#### 3. top chunk

当一个`chunk`处于一个`arena`的最顶部(即最高内存地址处)的时候，就称之为`top chunk`。该`chunk`并不属于任何`bin`，而是在系统当前的所有`free chunk`(无论那种bin)都无法满足用户请求的内存大小的时候，将此`chunk`当做一个应急消防员，分配给用户使用。如果`top chunk`的大小比用户请求的大小要大的话，就将该`top chunk`分作两部分：1）用户请求的`chunk`；2）剩余的部分成为新的`top chunk`。否则，就需要扩展heap或分配新的heap了——在`main arena`中通过sbrk扩展heap，而在`thread arena`中通过`mmap`分配新的heap。

#### 4. last remainder chunk

要想理解此`chunk`就必须先理解`glibc`的`malloc`中的`bin`机制，所以等介绍完`bin`再介绍这种类型的`chunk`

这一部分建议你先看本文后面的**bin机制介绍**，然后下面的原理就很好理解了。对于`last remainder chunk`，我们主要有两个问题：1)它是怎么产生的；2)它的作用是什么？

先回答第一个问题。根据第二部分文章中对`small bin`的`malloc`机制的介绍么？当用户请求的是一个`small chunk`，且该请求无法被`small bin`、`unsorted bin`满足的时候，就通过`binmaps`遍历`bin`查找最合适的`chunk`，如果该`chunk`有剩余部分的话，就将该剩余部分变成一个新的`chunk`加入到`unsorted bin`中，另外，再将该新的`chunk`变成新的`last remainder chunk`。

然后回答第二个问题。此类型的`chunk`用于提高连续`malloc`(`small chunk`)的效率，主要是提高内存分配的局部性。那么具体是怎么提高局部性的呢？举例说明。当用户请求一个`small chunk`，且该请求无法被`small bin`满足，那么就转而交由`unsorted bin`处理。同时，假设当前`unsorted bin`中只有一个`chunk`的话——就是`last remainder chunk`，那么就将该`chunk`分成两部分：前者分配给用户，剩下的部分放到`unsorted bin`中，并成为新的`last remainder chunk`。这样就保证了连续`malloc`(`small chunk`)中，各个`small chunk`在内存分布中是相邻的，即提高了内存分配的局部性。

## bin机制介绍

通过前面的介绍，我们知道使用隐式链表来管理内存`chunk`总会涉及到内存的遍历，效率极低。对此`glibc`的`malloc`引入了显示链表技术来提高堆内存分配和释放的效率。

所谓的显示链表就是我们在数据结构中常用的链表，而链表本质上就是将一些属性相同的“结点”串联起来，方便管理。在`glibc`的`malloc`中这些链表统称为`bin`，链表中的“结点”就是各个`chunk`，**结点的共同属性就是**：

* 均为free chunk
* 同一个链表中各个chunk的大小相等(有一个特例，详情见后文)。

`bin`作为一种记录`free chunk`的链表数据结构。系统针对不同大小的`free chunk`，将`bin`分为了4类：

* `fast bin`
* `unsorted bin`
* `small bin`
* `large bin`

同时，在`glibc`中用于记录`bin`的数据结构有两种，分别为：

* `fastbinsY`: 这是一个数组，用于记录所有的`fast bin`
* `bins`数组: 这也是一个数组，用于记录除`fast bin`之外的所有`bins`。事实上这个数组共有126个元素，分别是：
    * [1]为`unsorted bin`
    * [2~63]为`small bin`
    * [64~126]为`large bin`

那么处于`bins`中个各个`free chunk`是如何链接在一起的呢？回顾`malloc_chunk`的数据结构：其中的`fd`和`bk指`针就是指向当前chunk所属的链表中`forward chunk`或者`backward chunk`。

#### 1. fast bin

`fast bin`是指`fast chunk`的链表，而`fast chunk`是指那些**16到80字节的chunk**。为了便于后文描述，这里对chunk大小做如下约定：

* 只要说到`chunk size`，那么就表示该`malloc_chunk`的实际整体大小；

* 而说到`chunk unused size`，就表示该`malloc_chunk`中刨除诸如`prev_size`, `size`, `fd`和`bk`这类辅助成员之后的实际可用的大小。因此，对`free chunk`而言，其实际可用大小总是比实际整体大小少16字节。

![](/images/posts/cplusplus/heap/fast-bin.png)

**在内存分配和释放过程中，`fast bin`是所有bin中操作速度最快的**。下面详细介绍`fast bin`的一些特性：

* `fast bin`的个数

    `fast bin`总共有10个

* 每个`fast bin`都是一个单链表(只使用`fd`指针)。

    为什么这么设计呢？

    > 为什么使用单链表呢？因为在`fast bin`中无论是添加还是移除`fast chunk`，都是对“链表尾”进行操作，而不会对某个中间的`fast chunk`进行操作。更具体点就是`LIFO`(后入先出)算法：添加操作(free内存)就是将新的`fast chunk`加入链表尾，删除操作(malloc内存)就是将链表尾部的`fast chunk`删除。需要注意的是，为了实现`LIFO`算法，`fastbinsY`数组中每个`fastbin`元素均指向了该链表的`rear end`（尾结点），而尾结点通过其`fd`指针指向前一个结点，依次类推，如图所示。

* `fast bin`中的`chunk`

    `fast bin`中的`chunk size`是有限定范围的：10个`fast bin`中所包含的`fast chunk size`是按照步进8字节排列的。即第一个`fast bin`中所有`fast chunk size`均为16字节，第二个`fast bin`中为24字节，依次类推。在进行`malloc`初始化的时候，最大的`fast chunk size`被设置为80字节(`chunk unused size`为64字节)，因此默认情况下大小为16到80字节的`chunk`被分类到`fast chunk`。详情如上图所示。

* `fast bin`不进行`free chunk`的合并

    `fast bin`不会对`free chunk`进行合并操作。鉴于设计`fast bin`的初衷就是进行快速的小内存分配和释放，因此系统将属于`fast bin`的`chunk`的`P`(未使用标志位)总是设置为**1**，这样即使当`fast bin`中有某个`chunk`同一个`free chunk`相邻的时候，系统也不会进行自动合并操作，而是保留两者。虽然这样做可能会造成额外的碎片化问题，但瑕不掩瑜。

* malloc操作

    当用户通过`malloc`请求的大小属于`fast chunk`的大小范围(注意：用户请求size加上16字节就是实际内存`chunk size`)。在初始化的时候`fast bin`支持的最大内存大小以及所有`fast bin`链表都是空的，所以当最开始使用`malloc`申请内存的时候，即使申请的内存大小属于`fast chunk`的内存大小(即16到80字节)，它也不会交由`fast bin`来处理，而是向下传递交由`small bin`来处理，如果`small bin`也为空的话就交给`unsorted bin`处理：

```c++
/* Maximum size of memory handled in fastbins.  */
static INTERNAL_SIZE_T global_max_fast;

/* offset 2 to use otherwise unindexable first 2 bins */

/*这里SIZE_SZ就是sizeof(size_t)，在32位系统为4，64位为8，fastbin_index就是根据要malloc的size来快速计算该size应该属于哪一个fast bin，即该fast bin的索引。因为fast bin中chunk是从16字节开始的，所有这里以8字节为单位(32位系统为例)有减2*8 = 16的操作！*/
#define fastbin_index(sz) \
    ((((unsigned int) (sz)) >> (SIZE_SZ == 8 ? 4 : 3)) - 2)

/* The maximum fastbin request size we support */
#define MAX_FAST_SIZE     (80 * SIZE_SZ / 4)

#define NFASTBINS  (fastbin_index (request2size (MAX_FAST_SIZE)) + 1)
```

**那么`fast bin` 是在哪？怎么进行初始化的呢？**

当我们第一次调用`malloc(fast chunk size)`的时候，系统执行`_int_malloc`函数，该函数首先会发现当前`fast bin`为空，就转交给`small bin`处理，进而又发现`small bin`也为空，就调用`malloc_consolidate`函数对`malloc_state`结构体进行初始化，`malloc_consolidate`函数主要完成以下几个功能：

* 首先判断当前`malloc_state`结构体中的`fast bin`是否为空，如果为空就说明整个`malloc_state`都没有完成初始化，需要对`malloc_state`进行初始化。
* `malloc_state`的初始化操作由函数`malloc_init_state(av)`完成，该函数先初始化除`fast bin`之外的所有的`bins`(构建双链表，详情见后文`small bins`介绍)，再初始化`fast bins`。

然后当再次执行`malloc(fast chunk size)`函数的时候，此时`fast bin`相关数据不为空了，就开始使用`fast bin`(见下面代码中的※1部分)：

```c++
static void *
_int_malloc (mstate av, size_t bytes)
{
  // …
  /*
     If the size qualifies as a fastbin, first check corresponding bin.
     This code is safe to execute even if av is not yet initialized, so we
     can try it without checking, which saves some time on this fast path.
   */

   //第一次执行malloc(fast chunk)时这里判断为false，因为此时get_max_fast ()为0

   if ((unsigned long) (nb) <= (unsigned long) (get_max_fast ()))
    {
      // ※1 
      idx = fastbin_index (nb);     
      mfastbinptr *fb = &fastbin (av, idx);
      mchunkptr pp = *fb;
      do
        {
          victim = pp;
          if (victim == NULL)
            break;
        }

      // ※2    
      while ((pp = catomic_compare_and_exchange_val_acq (fb, victim->fd, victim))!= victim);
      if (victim != 0)
        {
          if (__builtin_expect (fastbin_index (chunksize (victim)) != idx, 0))
            {
              errstr = "malloc(): memory corruption (fast)";
            errout:
              malloc_printerr (check_action, errstr, chunk2mem (victim));
              return NULL;
            }
          check_remalloced_chunk (av, victim, nb);
          void *p = chunk2mem (victim);
          alloc_perturb (p, bytes);
          return p;
        }
    }
```

得到第一个来自于`fast bin`的`chunk`之后，系统就将该`chunk`从对应的`fast bin`中移除，并将其地址返回给用户，见上面代码※2处。

* free操作

    `free(fast chunk)`这个操作很简单，主要分为两步：先通过`chunksize`函数根据传入的地址指针获取该指针对应的`chunk`的大小；然后根据这个`chunk`大小获取该`chunk`所属的`fast bin`，然后再将此`chunk`添加到该`fast bin`的链尾即可。整个操作都是在`_int_free`函数中完成。

    在`main arena`中`fast bins`(即数组`fastbinsY`)的整体操作示意图如上图所示。

#### 2. unsorted bin

当释放较小或较大的`chunk`的时候，**如果系统没有将它们添加到对应的`bins`中(为什么，在什么情况下会发生这种事情呢？详情见后文)，系统就将这些`chunk`添加到`unsorted bin`中**。为什么要这么做呢？这主要是为了让`glibc`的`malloc`能够有第二次机会重新利用最近释放的`chunk`(第一次机会就是`fast bin`机制)。利用`unsorted bin`，可以加快内存的分配和释放操作，因为整个操作都不再需要花费额外的时间去查找合适的`bin`了。

`unsorted bin`的特性如下：

* `unsorted bin`的个数

    1个。unsorted bin是一个由free chunks组成的循环双链表。

* chunk size

    不同于其他的`bin`（包括`fast bin`），在`unsorted bin`中，对`chunk`的大小并没有限制，任何大小的`chunk`都可以归属到`unsorted bin`中。这就是前言说的特例了，不过特例并非仅仅这一个，后文会介绍。

总结而言，`unsorted bin`就像一个非`fast bin`的其他`chunk`的快速缓存机制。

#### 3. small bin

**小于512字节的`chunk`称之为`small chunk`，`small bin`就是用于管理`small chunk`的**。就内存的分配和释放速度而言，`small bin`比`larger bin`快，但比`fast bin`慢。

`small bin`的特性如下：

* small bin个数

    `small bin`共有62个。每个`small bin`也是一个由对应`free chunk`组成的循环双链表。同时`small bin`采用`FIFO`(先入先出)算法：内存释放操作就将新释放的`chunk`添加到链表的`front end`(前端)，分配操作就从链表的`rear end`(尾端)中获取`chunk`。

* chunk size

    同一个`small bin`中所有`chunk`大小是一样的，且第一个`small bin`中`chunk`大小为16字节，后续每个`small bin`中chunk的大小依次增加8字节，即最后一个`small bin`的`chunk`为16 + 62 * 8 = 512字节。

* 合并操作

    相邻的`free chunk`需要进行合并操作，即合并成一个大的`free chunk`。具体操作见下文`free(small chunk)`介绍。

* malloc操作

    类似于`fast bin`，最初所有的`small bin`都是空的，因此在对这些`small bin`完成初始化之前，即使用户请求的内存大小属于`small chunk`也不会交由`small bin`进行处理，而是交由`unsorted bin`处理，如果`unsorted bin`也不能处理的话，`glibc`的`malloc`就依次遍历后续的所有`bins`，找出第一个满足要求的`bin`，如果所有的`bin`都不满足的话，就转而使用`top chunk`，如果`top chunk`大小不够，那么就扩充`top chunk`，这样就一定能满足需求了(还记得在`top chunk`中留下的问题么？答案就在这里)。注意遍历后续`bins`以及之后的操作同样被`large bin`所使用，因此，将这部分内容放到`large bin`的`malloc`操作中加以介绍。

那么`glibc`的`malloc`是如何初始化这些`bins`的呢？因为这些`bin`属于`malloc_state`结构体，所以在初始化`malloc_state`的时候就会对这些`bin`进行初始化，代码如下：

```c++
malloc_init_state (mstate av)
{
  int i;
  mbinptr bin;

  /* Establish circular links for normal bins */
  for (i = 1; i < NBINS; ++i)
  {
    bin = bin_at (av, i);
    bin->fd = bin->bk = bin;
  }

  // .....
}
```

注意在`malloc`源码中，将`bins`数组中的第一个成员索引值设置为了1，而不是我们常用的0(在`bin_at`宏中，自动将i进行了减1处理…)。从上面代码可以看出在初始化的时候`glibc`的`malloc`将所有`bin`的指针都指向了自己——这就代表这些`bin`都是空的。

过后，当再次调用`malloc(small chunk)`的时候，如果该`chunk size`对应的`small bin`不为空，就从该`small bin`链表中取得`small chunk`，否则就需要交给`unsorted bin`及之后的逻辑来处理了。

* free操作

    当释放`small chunk`的时候，先检查该`chunk`相邻的`chunk`是否为`free`，如果是的话就进行合并操作：将这些`chunks`合并成新的`chunk`，然后将它们从`small bin`中移除，最后将新的`chunk`添加到`unsorted bin`中。

#### 4. large bin

**大于512字节的`chunk`称之为`large chunk`，`large bin`就是用于管理这些`large chunk`的。**

`large bin`的特性如下：

* `large bin`的数量

    63个。`large bin`类似于`small bin`，只是需要注意两点：一是同一个`large bin`中每个chunk的大小可以不一样，但必须处于某个给定的范围(特例2) ；二是`large chunk`可以添加、删除在`large bin`的任何一个位置。

    在这63个`large bin`中，前32个`large bin`依次以64字节步长为间隔，即第一个`large bin`中`chunk size`为512~575字节，第二个`large bin`中`chunk size`为576 ~ 639字节。紧随其后的16个`large bin`依次以512字节步长为间隔；之后的8个`bin`以步长4096为间隔；再之后的4个`bin`以32768字节为间隔；之后的2个`bin`以262144字节为间隔；剩下的`chunk`就放在最后一个`large bin`中。

    鉴于同一个`large bin`中每个`chunk`的大小不一定相同，因此为了加快内存分配和释放的速度，就将同一个`large bin`中的所有`chunk`按照`chunk size`进行从大到小的排列：最大的`chunk`放在链表的`front end`，最小的`chunk`放在`rear end`。

* 合并操作

    类似于`small bin`。

* malloc操作

初始化完成之前的操作类似于`small bin`，这里主要讨论`large bin`初始化完成之后的操作。首先确定用户请求的大小属于哪一个`large bin`，然后判断该`large bin`中最大的`chunk`的size是否大于用户请求的size(只需要对比链表中front和end的size即可)。如果大于，就从`rear end`开始遍历该`large bin`，找到第一个size相等或接近的`chunk`，分配给用户：

* 如果该`chunk`大于用户请求的size的话，就将该`chunk`拆分为两个`chunk`：前者返回给用户，且size等同于用户请求的size；剩余的部分做为一个新的`chunk`添加到`unsorted bin`中。

* 如果该`large bin`中最大的`chunk`的size小于用户请求的size的话，那么就依次查看后续的`large bin`中是否有满足需求的`chunk`，不过需要注意的是鉴于`bin`的个数较多(不同`bin`中的`chunk`极有可能在不同的内存页中)，如果按照上一段中介绍的方法进行遍历的话(即遍历每个`bin`中的`chunk`)，就可能会发生多次内存页中断操作，进而严重影响检索速度，所以`glibc`的`malloc`设计了`binmap`结构体来帮助提高bin-by-bin检索的速度。`binmap`记录了各个`bin`中是否为空，通过`bitmap`（不是`binmap`）可以避免检索一些空的`bin`。如果通过`binmap`找到了下一个非空的`large bin`的话，就按照上一段中的方法分配`chunk`，否则就使用`top chunk`来分配合适的内存。

* free操作

类似于`small chunk`。

下面附上各类上述三类`bin`的逻辑：

![](/images/posts/cplusplus/heap/unsorted-small-large-bin.jpg)

#### last remainder chunk补充

了解了`bin`机制，那么`last remainder chunk`的原理就很好理解了。对于`last remainder chunk`，我们主要有两个问题：它是怎么产生的以及它的作用是什么？

先回答第一个问题。当用户请求的是一个`small chunk`，且该请求无法被`small bin`、`unsorted bin`满足的时候，就通过`binmap`遍历`bin`查找最合适的`chunk`，如果该`chunk`有剩余部分的话，就将该剩余部分变成一个新的`chunk`加入到`unsorted bin`中，另外，再将该新的`chunk`变成新的`last remainder chunk`。

然后回答第二个问题。此类型的`chunk`用于提高连续`malloc(small chunk`)的效率，主要是提高内存分配的局部性。那么具体是怎么提高局部性的呢？举例说明。当用户请求一个`small chunk`，且该请求无法被`small bin`满足，那么就转而交由`unsorted bin`处理。同时，假设当前`unsorted bin`中只有一个`chunk`的话——就是`last remainder chunk`，那么就将该`chunk`分成两部分：前者分配给用户，剩下的部分放到`unsorted bin`中，并成为新的`last remainder chunk`。这样就保证了连续`malloc(small chunk`)中，各个`small chunk`在内存分布中是相邻的，即提高了内存分配的局部性。


**本文参考链接：**

* [Understanding glibc的malloc](https://sploitfun.wordpress.com/2015/02/10/understanding-glibc-malloc/comment-page-1/)
* [Syscalls used by malloc](https://sploitfun.wordpress.com/2015/02/11/syscalls-used-by-malloc/)
* [Linux堆内存管理深入分析(上半部)](https://blog.csdn.net/AliMobileSecurity/article/details/51384912)
* [Linux堆内存管理深入分析(下半部)](https://blog.csdn.net/AliMobileSecurity/article/details/51481718)
