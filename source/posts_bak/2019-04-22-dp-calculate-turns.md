---
title: 动态规划：计算路径数目(有限拐点)
date: 2019-04-22 15:07:15
update: 2019-04-22 15:07:15
categories: 算法
tags: [动态规划, C++]
---

一道有趣的动态规划题目

<!-- more -->

### 问题描述

给定一个 m x n 大小的矩阵，计算从左上角到右下角的路径数量（只允许向下或者向右移动），要求路径所经历的拐点数目**不大于 k**。

什么是拐点？如果我们本来沿着行移动，但是现在沿着列移动，则认为路径经过了一个拐点；或者本来沿着列移动，现在沿着行移动。拐点可能发生时有两种可能的情况：

在点 (i, j)：

* 向右转： (i-1, j) -> (i, j) -> (i, j + 1)
* 向下转： (i, j-1) -> (i, j) -> (i + 1, j)

对于下图：

![](/images/posts/algorithm/pathswithkturns.png)

```
输入：m = 3，n = 3，k = 2
输出：4

输入：m = 3，n = 3，k = 1
输出：2
```

### 求解分析

这是一道典型的动态规划题目，可以列出转移方程的形式。

首先定义计算路径的函数：

* `countPaths(i，j，k)`：从 (0, 0) 到达 (i, j) 的路径的数量
* `countPathsDir(i，j，k，0)`：沿着行方向到达 (i, j) 的路径数量。
* `countPathsDir(i，j，k，1)`：沿着列方向到达 (i, j) 的路径数量。

`countPathsDir` 中的第四个参数表示方向。因此：`countPaths(i，j，k) = countPathsDir(i，j，k，0) + countPathsDir(i，j，k，1)`

`countPathsDir` 的值可以递归地定义为：

```C++
// 如果当前方向是沿着行
if (d == 0)
{
  // 计算两种情况的路径
  // 1）我们通过前一行到达这里。
  // 2）我们通过前一列到达此处，因此数量为将 k 减少 1。
  
  countPathsDir(i, j, k, d) = countPathsUtil(i, j-1, k, d) + countPathsUtil(i-1, j, k-1, ！d);
}

// 如果当前方向是沿列
else
{
  //与上面类似

  countPathsDir(i, j, k, d) = countPathsUtil(i-1, j, k, d) + countPathsUtil(i, j-1, k-1，！d);
}
```

### 编程实现

我们可以使用动态编程在多项式时间中解决这个问题。想法是使用 4 维表 `dp[m][n][k][d]` 其中 m 是行数，n 是列数，k 是剩余的拐点数目，d 是方向。

下面是基于动态编程的 C++ 实现。

```C++
#include <iostream>
#include <bits/stdc++.h>

using namespace std;

#define MAX 100

int dp[MAX][MAX][MAX][2];

// Returns count of paths to reach (i, j) from (0, 0) using at-most k turns. 
// d is current direction d = 0 indicates along row, d = 1 indicates along column. 

int countPathUtil(int i, int j, int k, int d)
{
  if (i < 0 || j < 0)
  {
    return 0;
  }

  // 动态规划的边界条件：1 x 1 矩阵的情况
  if (i == 0 && j == 0)
  {
    return 1;
  }

  // 动态规划的边界条件：拐点数目已经达到极限
  if (k == 0)
  {
    // 只有当前方向是along row，并且重点行坐标 i == 0 才可能到达。
    // 否则，必然还需要最少一个拐点。
    if (d == 0 && i == 0)
    {
      return 1;
    }
    // 同理
    if (d == 1 && i == 1)
    {
      return 1;
    }

    return 0;
  }
  
  // 如果这个问题已经被求解了，直接返回结果
  if (dp[i][j][k][d] != -1)
  {
    return dp[i][j][k][d];
  }

  // 递归求解
  if (d == 0)
  {
    return dp[i][j][k][d] = countPathUtil(i, j-1, k, d) + countPathUtil(i-1, j, k-1, 1-d);
  }
  else
  {
    return dp[i][j][k][d] = countPathUtil(i-1, j, k, d) + countPathUtil(i, j-1, k-1, 1-d);
  }
}

int countPath(int i, int j, int k)
{
  if (i == 0 && j == 0)
  {
    return 1;
  }
  memset(dp, -1, sizeof(dp));

  // 沿着行方向移动和沿着列方向移动，到达 (i, j) 的两种方式
  return countPathUtil(i-1, j, k, 1) + countPathUtil(i, j-1, k, 0);
}

int main()
{
  int m = 3, n = 3, k = 2;
  
  cout << "Number of paths is " << countPath(m-1, n-1, k) << endl;
  
  return 0;
}
```
