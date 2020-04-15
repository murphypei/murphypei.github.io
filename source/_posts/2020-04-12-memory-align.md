---
title: 浅谈内存对齐
date: 2020-04-12 12:14:38
update: 2020-04-12 12:14:38
categories: C/C++
tags: [内存对齐, 内存寻址, C/C++, memory aligin]
---

C/C++ 编程中常见的一个概念是内存对齐，这里的对齐简单来讲就是分配的内存地址的起始位置是某个数字的倍数。

<!-- more -->


### 为什么要内存对齐

我们知道计算内存的最小存储单位是字节（byte），一般来讲我们调用 `malloc` 这类分配内存的函数也是以字节为单位分配的。理论上来讲我们分配的内存是由内核的堆管理器管理的，所以分配的内存首地址可能是任意的，也就是所谓的**没有对齐**。我们还知道，C 语言的 `struct` 中会有内存对齐，存在比如每个成员的起始地址必须是其大小的倍数，整个 `struct` 大小是最大成员的倍数等规则。这其中的原因是什么呢？

其实这和计算机体系结构或者说硬件设计有关。首先，**很多 CPU 只从对齐的地址开始加载数据**，CPU 这样做是为了更快一点。其次，**外部总线从内存一次获取的数据往往不是 1 byte，而是 4 bytes 或许 8 bytes 或者更多**，具体和数据总线带宽有关，32 位计算体系中数据总线一般就是 32 bits，也就是 4 bytes。

有了以上两个原因，我们容易理解为啥要数据对齐了。比如一个 int 数据类型，其分配的 4 bytes 没有对齐，比如分配在 3，4，5，6 这 4 个字节上。而 CPU 取值是对齐的，可能就需要取 0~3，4~7 这两块的数据才能获得这个 int 数据的大小。

### 向量指令

以上内存对齐的需求只是最基本，常见于 C 语言编程中，现代编译器一般会处理这类的内存对齐。另一种需要程序员处理的内存对齐就是向量指令集。我们以 x86 平台的向量化运算为例。

向量化运算就是用 SSE、AVX 等 SIMD（Single Instruction Multiple Data）指令集，实现一条指令对多个操作数的运算，从而提高代码的吞吐量，实现加速效果。SSE 是一个系列，包括从最初的 SSE 到最新的 SSE4.2，支持同时操作 16 bytes 的数据，即 4 个 float 或者 2 个 double。AVX 也是一个系列，它是 SSE 的升级版，支持同时操作 32 bytes 的数据，即 8 个 float 或者 4 个 double。

但**向量化运算是有前提的，那就是内存对齐**。SSE 的操作数，必须 16 bytes 对齐，而 AVX 的操作数，必须 32 bytes 对齐。也就是说，如果我们有 4 个 float 数，必须把它们放在连续的且首地址为 16 的倍数的内存空间中，才能调用 SSE 的指令进行运算。

### 栈上内存对齐

简单以 4 个浮点数相加为例：

```c++
#include <immintrin.h>
#include <iostream>

int main() {

  double input1[4] = {1, 1, 1, 1};
  double input2[4] = {1, 2, 3, 4};
  double result[4];

  std::cout << "address of input1: " << input1 << std::endl;
  std::cout << "address of input2: " << input2 << std::endl;

  __m256d a = _mm256_load_pd(input1);
  __m256d b = _mm256_load_pd(input2);
  __m256d c = _mm256_add_pd(a, b);

  _mm256_store_pd(result, c);

  std::cout << result[0] << " " << result[1] << " " << result[2] << " " << result[3] << std::endl;

  return 0;
}
```

`_mm256_*` 就是 AVX 向量指令的封装函数。`_mm256_load_pd` 指令用来加载操作数，`_mm256_add_pd` 指令进行向量化运算，最后， `_mm256_store_pd` 指令读取运算结果到 `result` 中。可惜的是，程序运行到第一个 `_mm256_load_pd` 处就崩溃了。崩溃的原因正是因为输入的变量没有内存对齐。那如何是我们的变量对齐呢？我们可以借助编译的一些特性来实现。比如 GCC 的语法为`__attribute__((aligned(32)))`，MSVC的语法为 `__declspec(align(32))`。以 GCC 语法为例，做少量修改，就可以得到正确的代码：

```c++
#include <immintrin.h>
#include <iostream>

int main() {

  __attribute__ ((aligned (32))) double input1[4] = {1, 1, 1, 1};
  __attribute__ ((aligned (32))) double input2[4] = {1, 2, 3, 4};
  __attribute__ ((aligned (32))) double result[4];

  std::cout << "address of input1: " << input1 << std::endl;
  std::cout << "address of input2: " << input2 << std::endl;

  __m256d a = _mm256_load_pd(input1);
  __m256d b = _mm256_load_pd(input2);
  __m256d c = _mm256_add_pd(a, b);

  _mm256_store_pd(result, c);

  std::cout << result[0] << " " << result[1] << " " << result[2] << " " << result[3] << std::endl;

  return 0;
}
```

当然上面只是示例代码，可以通过类型定义等方法优化代码的写法等等。

### 堆上内存对齐

以上通过编译器的修饰语法来解决内存对齐，貌似很简单，但是还是存在一个问题。以上的两个数组变量都是局部变量，也就是分配在**栈上，内存地址由编译器在编译时确定**，因此预编译指令会生效。但用new 和 malloc 动态创建的对象则存储在堆中，其地址在运行时确定。C++ 的运行时库并不会关心预编译指令声明的对齐方式，我们需要更强有力的手段来确保内存对齐。

废话不多说，我这里以 MNN 中的内存对齐代码为例：

```c++
static inline void **alignPointer(void **ptr, size_t alignment) {
    return (void **)((intptr_t)((unsigned char *)ptr + alignment - 1) & -alignment);
}

extern "C" void *MNNMemoryAllocAlign(size_t size, size_t alignment) {
    MNN_ASSERT(size > 0);

#ifdef MNN_DEBUG_MEMORY
    return malloc(size);
#else
    void **origin = (void **)malloc(size + sizeof(void *) + alignment);
    MNN_ASSERT(origin != NULL);
    if (!origin) {
        return NULL;
    }

    void **aligned = alignPointer(origin + 1, alignment);
    aligned[-1]    = origin;
    return aligned;
#endif

extern "C" void MNNMemoryFreeAlign(void *aligned) {
#ifdef MNN_DEBUG_MEMORY
    free(aligned);
#else
    if (aligned) {
        void *origin = ((void **)aligned)[-1];
        free(origin);
    }
#endif
}
}
```

我们分析一下以上代码。首先，为了保证内存对齐，我们可以在 `malloc` 分配时分配比所要求的内存大的内存容量，这样我们可以向下寻找一个保证是对齐大小的整倍数的内存地址。

```c++
(void **)malloc(size + sizeof(void *) + alignment)
```

然后我们向下寻找满足对齐需求的首地址，代码就是：

```c++
(void **)((intptr_t)((unsigned char *)ptr + alignment - 1) & -alignment)
```

`&` 符号是按位与，`-alignment` 的补码表示就是 `aliginment` 符号位不变，其余位按位取反并加 1。我们以 AVX 所需要的 32 bytes 对齐为例，`alignment` 就是 256，二进制就是 `0...00000100000000`，`-alignment` 在计算中的表示就是 `1...11111100000000`，也就是后 8 位为 0，其余位为均为 1， 因此任何数与 `-alignment` 按位与的后 8 为都为 0，所以结果肯定是 32 bytes 对齐的。`((unsigned char *)ptr + alignment - 1) & -alignment` 就相当于把 `ptr + alignment - 1` 的后 8 位置为 0，这个数比 `ptr + alignment - 1` 小，而且一定是对齐的。最后将**真正的地址放在对齐后的地址前面，释放的时候取原始的地址及其前面的信息释放内存**。

通过以上代码，我们可以获取一块在堆上新创建的并且地址对齐的内存。
