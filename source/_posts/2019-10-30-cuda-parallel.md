---
title: CUDA 多线程并行
date: 2019-10-30 17:47:03
update: 2019-10-30 17:47:03
categories: 
tags:
---

cuda 中核函数执行使用多线程并行（SIMD）的方式，同时计算多个数据，因此核函数的线程管理以及相应的任务分配就显得尤为重要。

<!-- more -->

首先说明一点，cuda 中使用 `dim3` 作为三维数据的表示方式，其表示的意义如下：

```c++
dim3 blocks1D( 5       ); 	// 5*1*1
dim3 blocks2D( 5, 5    );	// 5*5*1
dim3 blocks3D( 5, 5, 5 );	// 5*5*5
```

再来看看 cuda 中 kernel 函数的典型调用形式：

```c++
kernel<<<Dg, Db, Ns, S>>>(params);
```

- 参数 `Dg` 是一个 `dim3` 类型，用于定义整个 grid 的维度，也就是一个 grid 中有多少个 block。`dim3 Dg(Dg.x, Dg.y, 1)` 表示 grid 中每行有 `Dg.x` 个block，每列有 `Dg.y` 个block，第三维恒为 1。整个 grid 中共有 `Dg.x*Dg.y` 个 block，其中 `Dg.x` 和 `Dg.y` 最大值为 65535。
  - 对于一个 grid，其中包含了多个 block，使用 `unit3` 类型的 `blockIdx` 来表示，通过 `blockIdx.x`，`blockIdx.y`，`blockIdx.z` 三个坐标可以定位 grid 中的一个 block。
  - 注意：`dim3` 是手工定义的，主机端可见。`uint3` 是设备端在执行的时候可见的，不可以在核函数运行时修改，初始化完成后 `uint3` 值就不变了。他们是有区别的，这一点必须要注意。
- 参数 `Db` 是一个 `dim3` 类型，用于定义一个 block 的维度，即一个 block 有多少个 thread。`Dim3 Db(Db.x, Db.y, Db.z)` 表示整个 block 中每行有 `Db.x` 个thread，每列有 `Db.y` 个thread，高度为 `Db.z`。`Db.x` 和 `Db.y `最大值为 512，`Db.z` 最大值为 62。 一个 block中 共有 `Db.x*Db.y*Db.z` 个 thread。不同计算能力这个乘积的最大值不一样。
  - 和在 grid 中定位一个 block 类似，在一个 block 中定位一个 thread 也是用一个 `unit3` 类型的 `threadIdx` 的三个坐标来表示的。
- 参数 `Ns` 是一个可选参数，用于设置每个 block 除了静态分配的 shared memory 以外，最多能动态分配的 shared memory 大小，单位为 byte。不需要动态分配时该值为0或省略不写。
- 参数 `S` 是一个 `cudaStream_t` 类型的可选参数，初始值为零，表示该核函数处在哪个流之中。

kernel 可以通过 grid 和 block 的设置实现了多线程并行计算，下面是 cuda 官方的一个向量相加的例子，其中的 kernel 函数就是实际计算程序：

```c++
#include "../common/book.h"

#define N   (33 * 1024)

__global__ void add( int *a, int *b, int *c ) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    while (tid < N) {
        c[tid] = a[tid] + b[tid];
        tid += blockDim.x * gridDim.x;
    }
}

int main( void ) {
    int *a, *b, *c;
    int *dev_a, *dev_b, *dev_c;

    // allocate the memory on the CPU
    a = (int*)malloc( N * sizeof(int) );
    b = (int*)malloc( N * sizeof(int) );
    c = (int*)malloc( N * sizeof(int) );

    // allocate the memory on the GPU
    HANDLE_ERROR( cudaMalloc( (void**)&dev_a, N * sizeof(int) ) );
    HANDLE_ERROR( cudaMalloc( (void**)&dev_b, N * sizeof(int) ) );
    HANDLE_ERROR( cudaMalloc( (void**)&dev_c, N * sizeof(int) ) );

    // fill the arrays 'a' and 'b' on the CPU
    for (int i=0; i<N; i++) {
        a[i] = i;
        b[i] = 2 * i;
    }

    // copy the arrays 'a' and 'b' to the GPU
    HANDLE_ERROR( cudaMemcpy( dev_a, a, N * sizeof(int),
                              cudaMemcpyHostToDevice ) );
    HANDLE_ERROR( cudaMemcpy( dev_b, b, N * sizeof(int),
                              cudaMemcpyHostToDevice ) );

    add<<<128,128>>>( dev_a, dev_b, dev_c );

    // copy the array 'c' back from the GPU to the CPU
    HANDLE_ERROR( cudaMemcpy( c, dev_c, N * sizeof(int),
                              cudaMemcpyDeviceToHost ) );

    // verify that the GPU did the work we requested
    bool success = true;
    for (int i=0; i<N; i++) {
        if ((a[i] + b[i]) != c[i]) {
            printf( "Error:  %d + %d != %d\n", a[i], b[i], c[i] );
            success = false;
        }
    }
    if (success)    
        printf( "We did it!\n" );

    // free the memory we allocated on the GPU
    HANDLE_ERROR( cudaFree( dev_a ) );
    HANDLE_ERROR( cudaFree( dev_b ) );
    HANDLE_ERROR( cudaFree( dev_c ) );

    // free the memory we allocated on the CPU
    free( a );
    free( b );
    free( c );

    return 0;
}
```

上面的代码中可以通过 `threadIdx.x + blockIdx.x * blockDim.x` 定位当前执行线程的 index。但是我们实际操作的数据长度(33\*1024) 大于设置的线程数量 (128\*128)。因此一个线程可能会处理多个数据，因此使用 `tid += blockDim.x * gridDim.x` 来执行多个数据的处理。当然，需要判断 `tid` 是否越界。

因为我们都是通过多线程并行来实现 kernel 的高效执行，因此也可以说编写核函数的精髓就是如何利用线程的序号（索引值）来分配计算任务。这里有一个题外话，据说之所以在硬件上将线程抽象成三维数组来表示，就是为了方便图像处理里，利用三维的线程索引来对应图像数据索引，并行加速，其实对于底层硬件，不存在三维线程的概念。

至于对于一个任务应该分配多少线程，grid 和 block 应该设置为多大，这根据需求和硬件素质。通常选取 2 的倍数作为线程总数，合理地平均分配任务到各个线程。
