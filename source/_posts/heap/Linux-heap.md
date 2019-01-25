Linux堆内存管理深入分析

[Understanding glibc malloc](https://sploitfun.wordpress.com/2015/02/10/understanding-glibc-malloc/comment-page-1/) 深入浅出的介绍了Linux的堆内存分配情况，下面就是对原文的一些翻译和理解，表达其中的意思，并不是原本照搬，有兴趣建议阅读原文。

## 堆内存管理机制介绍

不同平台的堆内存管理机制不相同，下面是几个常见平台的堆内存管理机制：

| 平台 | 堆内存分配机制 |
| :--: | :--: |
| dlmalloc | General purpose allocator |
| ptmalloc2 | glibc |
| jemalloc |  FreeBSD and Firefox |
| tcmalloc |  Google |
| libumem  |  Solaris |

本文主要学习介绍在Linux的`glibc`使用的`ptmalloc2`实现原理。本来linux默认的是dlmalloc，但是由于其不支持多线程堆管理，所以后来被支持多线程的prmalloc2代替了。当然在linux平台*malloc本质上都是通过系统调用brk或者mmap实现的。原文作者的另一篇文章也介绍的很清楚[Syscalls used by malloc](https://sploitfun.wordpress.com/2015/02/11/syscalls-used-by-malloc/)。鉴于篇幅，本文就不加以详细说明了，只是为了方便后面对堆内存管理的理解，截取其中函数调用关系图：
![](/home/peic/Downloads/malloc-func-call.png)

再来一张进程的虚拟内存分布示意图：

![](/home/peic/Downloads/linuxFlexibleAddressSpaceLayout.png)

**注意：**
    * 这个图是32位系统的进程虚拟内存分布，所以最大是4G，内核默认占用1G
    * `0x08048000`这个地址也是针对32位系统而言，64位系统是`0x00400000`clang++ -std=c++11 test_malloc.cpp -lpthread

可以看到heap的内存大小与一个brk指针有关，这个就是heap内存的尾指针，而系统brk函数就是通过改变这个brk指针来进行内存的分配。

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

编译：
`clang++ -std=c++11 test_malloc.cpp -lpthread`

运行结果和分析如下：

1. Before malloc in main thread 

![](/home/peic/Pictures/heap-maps1.png)

可以看到，在本机上（Ubuntu16.04，x64），在主线程调用malloc之前，就已经给主线程分配了一块堆内存，这和原文作者在32位机上的实验结果是不同的。这块默认大小的内存是200KB。

heap是紧接着数据段的，说明这个系统是通过brk来进行内存分配的，和作者实验结果相同。

2. After malloc in main thread

![](/home/peic/Pictures/heap-maps2.png)

（不小心ctrl+c了，所以进程id不一样），在主线程中调用malloc之后，发现heap仍然是200K，我分析是因为默认分配的内存够用，因此malloc并没有引起heap的自增长。作者原文中有一种解释：

> 还可以看出虽然我们只申请了1000字节的数据，但是系统却分配了132KB大小的堆，这是为什么呢？原来这132KB的堆空间叫做arena，此时因为是主线程分配的，所以叫做main arena(每个arena中含有多个chunk，这些chunk以链表的形式加以组织)。由于132KB比1000字节大很多，所以主线程后续再声请堆空间的话，就会先从这132KB的剩余部分中申请，直到用完或不够用的时候，再通过增加program break location的方式来增加main arena的大小。同理，当main arena中有过多空闲内存的时候，也会通过减小program break location的方式来缩小main arena的大小。

3. After free in main thread

free之后，heap分布还是之前那样，没变（懒得截图了）。这里和原文实验结果也相同，原文也给出了解释：

> 在主线程调用free之后，从内存布局可以看出程序的堆空间并没有被释放掉，原来调用free函数释放已经分配了的空间并非直接“返还”给系统，而是由glibc 的malloc库函数加以管理。它会将释放的chunk添加到main arenas的bin(这是一种用于存储同类型free chunk的双链表数据结构，后问会加以详细介绍)中。在这里，记录空闲空间的freelist数据结构称之为bins。之后当用户再次调用malloc申请堆空间的时候，glibc malloc会先尝试从bins中找到一个满足要求的chunk，如果没有才会向操作系统申请新的堆空间。

4. Before malloc in thread 1

![](/home/peic/Pictures/heap-maps3.png)

请注意红色框这一部分地址，和下面的`/lib/x86_64-linux-gnu/libc-2.23.so`等动态库位于的`Memory Mapping Segment`区域的地址很接近，结合上图的内存分布图可以知道，就地址而言：stack > Memory Mapping Segment > heap。这里有一个知识：**Linux子线程是由mmap创建的，所以其栈是位于`Memory Mapping Segment`区域**[Where are the stacks for the other threads located in a process virtual address space?]（https://stackoverflow.com/questions/44858528/where-are-the-stacks-for-the-other-threads-located-in-a-process-virtual-address）。因此可以看出，在子线程malloc之前，已经创建了子线程的stack，其大小是8MB。

5. After malloc in thread 1

![](/home/peic/Pictures/heap-maps4.png)

继续关注红色区域的地址，在malloc之后，为子线程分配了堆，这个大小是132K，并且同样是位于`Memory Mapping Segment`区域，这部分区域就是thread1的堆空间，即thread1 arena。

同时还要注意，子线程分配的空间是`Memory Mapping Segment`向下增长的，也就是向堆区增长。

6. After free in thread 1

同 main thread。

## Arena 介绍

### Arena数量限制

前文提到main thread和thread1有自己独立的arena，那么是不是无论有多少个线程，每个线程都有自己独立的arena呢？答案是否定的。事实上，arena的个数是跟系统中处理器核心个数相关的，如下表所示：

| systems | number of arena |
| :--: | :--: |
| 32bits | 2 * number of cpu cores + 1 |
| 64bits | 8 * number of cpu cores + 1 |

### 多Arena的管理

假设有如下情境：一台只含有一个处理器核心的PC机安装有32位操作系统，其上运行了一个多线程应用程序，共含有4个线程——主线程和三个用户线程。显然线程个数大于系统能维护的最大arena个数（2*核心数 + 1= 3），那么此时glibc malloc就需要确保这4个线程能够正确地共享这3个arena，那么它是如何实现的呢？

当主线程首次调用malloc的时候，glibc malloc会直接为它分配一个main arena，而不需要任何附加条件。

当用户线程1和用户线程2首次调用malloc的时候，glibc malloc会分别为每个用户线程创建一个新的thread arena。此时，各个线程与arena是一一对应的。但是，当用户线程3调用malloc的时候，就出现问题了。因为此时glibc malloc能维护的arena个数已经达到上限，无法再为线程3分配新的arena了，那么就需要重复使用已经分配好的3个arena中的一个(main arena, arena 1或者arena 2)。那么该选择哪个arena进行重复利用呢？

1)首先，glibc malloc循环遍历所有可用的arenas，在遍历的过程中，它会尝试lock该arena。如果成功lock(该arena当前对应的线程并未使用堆内存则表示可lock)，比如将main arena成功lock住，那么就将main arena返回给用户，即表示该arena被线程3共享使用。

2)而如果没能找到可用的arena，那么就将线程3的malloc操作阻塞，直到有可用的arena为止。

3)现在，如果线程3再次调用malloc的话，glibc malloc就会先尝试使用最近访问的arena(此时为main arena)。如果此时main arena可用的话，就直接使用，否则就将线程3阻塞，直到main arena再次可用为止。

这样线程3与主线程就共享main arena了。至于其他更复杂的情况，以此类推。


## 堆管理介绍

在glibc malloc中针对堆管理，主要涉及到以下3种数据结构：

**heap_info**

即Heap Header，因为一个thread arena（注意：不包含main thread）可以包含多个heaps，所以为了便于管理，就给每个heap分配一个heap header。

**那么在什么情况下一个thread arena会包含多个heaps呢？**在当前heap不够用的时候，malloc会通过系统调用mmap申请新的堆空间（这部分空间本来是位于`Memory Mapping Segment`区域），新的堆空间会被添加到当前thread arena中，便于管理。

```c++
typedef struct _heap_info
{
  mstate ar_ptr; /* Arena for this heap. */
  struct _heap_info *prev; /* Previous heap. */
  size_t size;   /* Current size in bytes. */
  size_t mprotect_size; /* Size in bytes that has been mprotected
                           PROT_READ|PROT_WRITE.  */
   /* Make sure the following data is properly aligned, particularly
      that sizeof (heap_info) + 2 * SIZE_SZ is a multiple of
      MALLOC_ALIGNMENT. */
  char pad[-6 * SIZE_SZ & MALLOC_ALIGN_MASK];
} heap_info;
```

**malloc_state**

即Arena Header，每个thread只含有一个Arena Header。Arena Header包含bins的信息、top chunk以及最后一个remainder chunk等(这些概念会在后文详细介绍):

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

**malloc_chunk**

即Chunk Header，一个heap被分为多个chunk，至于每个chunk的大小，这是根据用户的请求决定的，也就是说用户调用malloc(size)传递的size参数“就是”chunk的大小(这里给“就是”加上引号，说明这种表示并不准确，但是为了方便理解就暂时这么描述了，详细说明见后文)。每个chunk都由一个结构体malloc_chunk表示。

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

> 1. Main thread不含有多个heaps所以也就不含有heap_info结构体。当需要更多堆空间的时候，就通过扩展sbrk的heap segment来获取更多的空间，直到它碰到内存mapping区域为止。
> 2. 不同于thread arena，main arena的arena header并不是sbrk heap segment的一部分，而是一个全局变量！因此它属于libc.so的data segment。

### heap segment与arena关系

首先，通过内存分布图理清malloc_state与heap_info之间的组织关系。下图是只有一个heap segment的main arena和thread arena的内存分布图：

![](single-thread-arena.png)

下图是一个thread arena中含有多个heap segments的情况：

![](multi-thread-arena.png)

从上图可以看出，thread arena只含有一个malloc_state(即arena header)，却有两个heap_info(即heap header)。由于两个heap segments是通过mmap分配的内存，两者在内存布局上并不相邻而是分属于不同的内存区间，所以为了便于管理，glibc malloc将第二个heap_info结构体的prev成员指向了第一个heap_info结构体的起始位置（即ar_ptr成员），而第一个heap_info结构体的ar_ptr成员指向了malloc_state，这样就构成了一个单链表，方便后续管理。

## chunk 介绍

在glibc malloc中将整个堆内存空间分成了连续的、大小不一的chunk，即对于堆内存管理而言chunk就是最小操作单位。Chunk总共分为4类：1)allocated chunk; 2)free chunk; 3)top chunk; 4)Last remainder chunk。从本质上来说，所有类型的chunk都是内存中一块连续的区域，只是通过该区域中特定位置的某些标识符加以区分。为了简便，我们先将这4类chunk简化为2类：allocated chunk以及free chunk，前者表示已经分配给用户使用的chunk，后者表示未使用的chunk。

众所周知，无论是何种堆内存管理器，其完成的核心目的都是能够高效地分配和回收内存块(chunk)。因此，它需要设计好相关算法以及相应的数据结构，而数据结构往往是根据算法的需要加以改变的。既然是算法，那么算法肯定有一个优化改进的过程，所以本文将根据堆内存管理器的演变历程，逐步介绍在glibc malloc中chunk这种数据结构是如何设计出来的，以及这样设计的优缺点。

任何堆内存管理器都是以chunk为单位进行堆内存管理的，而这就需要一些数据结构来标志各个块的边界，以及区分已分配块和空闲块。大多数堆内存管理器都将这些边界信息作为chunk的一部分嵌入到chunk内部。堆内存中要求每个chunk的大小必须为8的整数倍，因此chunk size的后3位是无效的，为了充分利用内存，堆管理器将这3个比特位用作chunk的标志位，典型的就是将第0比特位用于标记该chunk是否已经被分配。这样的设计很巧妙，因为我们只要获取了一个指向chunk size的指针，就能知道该chunk的大小，即确定了此chunk的边界，且利用chunk size的第0比特位还能知道该chunk是否已经分配，这样就成功地将各个chunk区分开来。注意在allocated chunk中，如果一个chunk的大小不是8的整数倍，需要填充部分padding数据进行对齐。

**Allocated chunk**

![](allocated-chunk.png)

顾名思义，是已经被分配使用的chunk，

* prev_size: 如果前一个chunk是free的，则这个内容保存的是前一个chunk的大小. 如果前一个chunk已经被使用了，则这个区域保存的是前一个chunk的用户数据（一部分而已，主要是为了能够充分利用这块内存空间）。
* size: 保存的是当前这个chunk的大小。总共是32bits，并且最后的3位作为标志位。

三个标志位的意义：

* PREV_INUSE (P): 表示前一个chunk是否为allocated.（当前chunk是不是allocated可以通过查询下一个chunk的这个标志位来得知）
* IS_MMAPPED (M): 表示当前chunk是否是通过mmap系统调用产生的。（mmap或者brk）
* NON_MAIN_ARENA (N): – 表示当前chunk是否是thread arena。（也就是非主线程的arena，用于支持多线程）

**chunk相关问题：**

* 每个chunk的大小怎么确定？
    * 调用malloc时传入的大小就是当前分配的chunk大小
* 我们为什么要知道前一个chunk的大小？
    * 为了方便合并不同的chunk，减少内存的碎片化。如果不这么做，chunk的合并只能向下合并，必须从头遍历整个堆，然后加以合并，这就意味着每次进行chunk释放操作消耗的时间与堆的大小成线性关系。
* chunk的链表是如何构成的
    *chunk在堆内存上是连续的，并不是直接由指针构成的链表，而是通过prev_size和size块构成了隐式的链表。在进行分配操作的时候，堆内存管理器可以通过遍历整个堆内存的chunk，分析每个chunk的size字段，进而找到合适的chunk。

**Free chunk**

![](free-chunk.png)

* prev_size: 为了防止碎片化，堆中不存在两个相邻的chunk（如果存在，则被堆管理器合并了）。因此对于一个free chunk，这个prev_size区域中一定包含的上一个chunk的部分有效数据或者为了地址对齐所做的padding。
* size: 同allocated chunk，表示当前chunk的大小
* N,M,P: 同allocated chunk
* fd: 前向指针——指向当前chunk在同一个bin（一种用于加快内存分配和释放效率的显示链表）的下一个chunk
* bk: 后向指针——指向当前chunk在同一个bin的上一个chunk

**Top chunk**

当一个chunk处于一个arena的最顶部(即最高内存地址处)的时候，就称之为top chunk。该chunk并不属于任何bin，而是在系统当前的所有free chunk(无论那种bin)都无法满足用户请求的内存大小的时候，将此chunk当做一个应急消防员，分配给用户使用。如果top chunk的大小比用户请求的大小要大的话，就将该top chunk分作两部分：1）用户请求的chunk；2）剩余的部分成为新的top chunk。否则，就需要扩展heap或分配新的heap了——在main arena中通过sbrk扩展heap，而在thread arena中通过mmap分配新的heap。

**Last Remainder Chunk**


要想理解此chunk就必须先理解glibc malloc中的bin机制。如果你已经看了第二部分文章，那么下面的原理就很好理解了，否则建议你先阅读第二部分文章。对于Last remainder chunk，我们主要有两个问题：1)它是怎么产生的；2)它的作用是什么？



先回答第一个问题。还记得第二部分文章中对small bin的malloc机制的介绍么？当用户请求的是一个small chunk，且该请求无法被small bin、unsorted bin满足的时候，就通过binmaps遍历bin查找最合适的chunk，如果该chunk有剩余部分的话，就将该剩余部分变成一个新的chunk加入到unsorted bin中，另外，再将该新的chunk变成新的last remainder chunk。



然后回答第二个问题。此类型的chunk用于提高连续malloc(small chunk)的效率，主要是提高内存分配的局部性。那么具体是怎么提高局部性的呢？举例说明。当用户请求一个small chunk，且该请求无法被small bin满足，那么就转而交由unsorted bin处理。同时，假设当前unsorted bin中只有一个chunk的话——就是last remainder chunk，那么就将该chunk分成两部分：前者分配给用户，剩下的部分放到unsorted bin中，并成为新的last remainder chunk。这样就保证了连续malloc(small chunk)中，各个small chunk在内存分布中是相邻的，即提高了内存分配的局部性。
