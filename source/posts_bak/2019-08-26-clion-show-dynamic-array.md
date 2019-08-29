---
title: clion 显示动态数组内容
date: 2019-08-26 10:23:40
update: 2019-08-26 10:23:40
categories: C++
tags: [C++, IDE, clion]
---

如果要想在 clion 中显示动态数组，直接显示是不行的，需要强制转换为数组格式。

<!-- more -->

比如如下动态数组指针：

```C++
float *input = new float[202];
// fill array input
```

在调试窗口中右键动态数组的指针，选择 Evaluate Expression，然后做一步转换：`(float (*)[202])input` ，这时候就会显示数组的内容了。