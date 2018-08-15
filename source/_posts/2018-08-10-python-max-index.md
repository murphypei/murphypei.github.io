---
title: Python找出矩阵中最大值的位置
date: 2018-08-10 09:19:44
update: 2018-08-10 09:19:44
categories: Python
tags: [python, numpy, max, argmax]
---

实际工程中发现，python做for循环非常缓慢，因此转换成numpy再找效率高很多。numpy中有两种方式可以找最大值（最小值同理）的位置。

<!--more-->

### 1. 通过np.max和np.where

通过np.max()找矩阵的最大值，再通过np.where获得最大值的位置，测试如下：

```python
a = np.random.randint(10, 100, size=9)
a = a.reshape((3,3))
print(a)
r, c = np.where(a == np.max(a))
print(r,c)
```

输出：

```python
[[77 54 16]
 [93 96 43]
 [92 78 88]]
(array([1]), array([1]))
```

注意，np.where输出的是两个array，需要从中取出坐标。

### 2. 通过np.argmax

np.argmax可以直接返回最大值的索引，不过索引值是一维的，需要做一下处理得到其在二维矩阵中的位置。

```python
a = np.random.randint(10, 100, size=9)
a = a.reshape((3,3))
print(a)

m = np.argmax(a)
r, c = divmod(m, a.shape[1])
print(r, c)
```

输出：

```python
[[42 86 40]
 [63 36 77]
 [38 60 98]]
(2, 2)
```

### 3.总结

综合来看，argmax快且方便，获得的结果直接就是一个tuple，好处理，推荐。