---
title: OpenBLAS 中矩阵运算函数学习
date: 2019-09-25 14:20:11
update: 2019-09-25 14:20:11
categories: C++
tags: [OpenBLAS, cblas_sgemm, cblas_sgemv, gemm]
---

GEMM 是矩阵乘法最成熟的优化计算方式，也有很多现成的优化好的库可以调用。

<!-- more -->

## OpenBLAS 矩阵计算

OpenBLAS 库实现成熟优化的矩阵与矩阵乘法的函数 `cblas_sgemm` 和矩阵与向量乘法函数 `cblas_sgemv`，二者使用方法基本相同，参数较多，所以对参数的使用做个记录。

#### 矩阵与矩阵乘法

`cblas_sgemm` 计算的矩阵公式：`C=alpha*A*B+beta*C `，其中 `A`、`B`、`C` 都是矩阵，`C` 初始中存放的可以是偏置值。

`cblas_sgemm` 函数定义：

`cblas_sgemm(layout, transA, transB, M, N, K, alpha, A, LDA, B, LDB, beta, C, LDC);`

- `layout`：存储格式，有行主序（`CblasRowMajor`）和列主序（`CblasRowMajor`），C/C++ 一般是行主序。
- `transA`：`A` 矩阵是否需要转置。
- `transB`：`B` 矩阵是否需要转置。
- `M`，`N`，`K`：`A` 矩阵经过 `transA` 之后的维度是 `M*K` ，`B` 矩阵经过 `transB` 之后的维度是 `K*N` ，`C` 矩阵的维度是 `M*N`。
- `LDA`，`LDB`，`LDC`：**矩阵在 `trans` （如果需要转置）之前**，在主维度方向的维度（如果是行主序，那这个参数就是列数）。

示例代码：

```c++
#include <stdio.h>
#include <cblas.h>

int main() {
  int i, j;
  float a[6]={1,3,5,2,7,8};
  float b[6]={5,3,7,2,4,2};
  float c[6]={0,0,0,0,0,0};
  cblas_sgemm(CblasRowMajor, CblasTrans, CblasTrans, 3, 3, 2, 1.0, a, 3, b, 2, 0.0, c, 3);
  for(i = 0; i < 3; ++i){
    for(j = 0; j < 3; ++j){
      printf("%f ", c[i*3+j]);
    }
    printf("\n");
  }
  return 1;
}
```

#### 矩阵与向量乘法

矩阵与向量乘法本质也是矩阵与矩阵，只不过 `gemv` 比 `gemm` 要快一些，所以有时候也需要用 `gemv`。计算式：`C=alpha*A*b+beta*C `

`cblas_sgemv` 函数定义：

`cblas_sgemv(layout, trans, M, N, alpha, A, LDA, b, 1, beta, C, 1)`

参数的定义基本和 `gemm` 相同，`M` 和 `N` 是 `A` 的行数和列数，`b` 和 `C` 的列数都是 1。

