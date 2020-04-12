---
title: STL 中的二分查找
date: 2019-11-29 11:27:44
update: 2019-11-29 11:27:44
categories: C/C++
tags: [C++, binary, lower_bound, upper_bound]
---

STL 中的算法都很精妙，有很多实现值得我们细究和学习。

<!-- more -->

STL 容器中有两个有趣的方法：

```c++
// 返回一个非递减序列[first, last)中的第一个大于等于值val的位置。
ForwardIter lower_bound(ForwardIter first, ForwardIter last,const _Tp& val)

// 返回一个非递减序列[first, last)中第一个大于val的位置。
ForwardIter upper_bound(ForwardIter first, ForwardIter last, const _Tp& val)
```

这两个方法一般是用于确定 `val` 的上下边界，因为作用是一个**非递减序列**，因此用二分查找最好不过了。下面就是 STL 中这两个方法的实现。

```c++
// 这个算法中，first是最终要返回的位置
int lower_bound(int *array, int size, int key)
{
    int first = 0, middle;
    int half, len;
    len = size;

    while(len > 0)
    {
        half = len >> 1;    // half 表示待查找序列的一半长度
        middle = first + half;  // 确定待查找序列的中间位置
        // 根据比较结果，更新待查找序列
        if(array[middle] < key)
        {
            first = middle + 1;
            len = len-half-1;       //在右边子序列中查找
        }
        else
        {
            len = half;            //在左边子序列（包含middle）中查找
        }
    }
    return first;
}
```

```c++
int upper_bound(int *array, int size, int key)
{
    int first = 0, len = size-1;
    int half, middle;

    while(len > 0)
    {
        half = len >> 1;
        middle = first + half;
        if(array[middle] > key)     //中位数大于key,在包含last的左半边序列中查找。
        {
            len = half;
        }
        else
        {
            first = middle + 1;    //中位数小于等于key,在右半边序列中查找。
            len = len - half - 1;
        }
    }
    return first;
}
```

回想一下，我们日常见到的二分查找都是使用两个位置变量标记一段待查找序列，STL中使用一个起始位置和长度来标记一段待查找序列，都是通过缩小待查找范围来更新，原理并没有什么不同，实现的复杂度也是类似的。

这里附一个我自己平时用的二分查找的模板：

```c++
int binarySearch(int *data, int size, int target)
{
    int left = 0, right = size - 1;
    while(left <= right)
    {
        int mid =  left + ((right - left) >> 1);
        if (data[mid] == target)
        {
            return mid;
        }
        else if (data[mid] > target)
        {
            right = mid - 1;
        }
        else
        {
            left = mid + 1;
        }
    }
    return -1;
}
```

**这里要特别注意，`>>` 和 `+` 运算符有优先级，所以必须使用 `()`**。