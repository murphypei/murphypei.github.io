---
title: numpy meshgrid和reval用法
date: 2018-07-21 09:19:44
update: 2018-07-21 09:19:44
categories: Python
tags: [Python, numpy, meshgrid, reval]
---

numpy中有一些强大的函数可以很方便的实现日常的数值处理计算。在机器学习的特征处理中，meshgrid使用的很多，我之前对于meshgrid的用法一直是有点茫然记不住，后来看到一个stackoverflow的帖子恍然大悟，所以记录分享一下，有兴趣可以看原帖。

<!--more-->

[原帖](https://stackoverflow.com/questions/36013063/what-is-purpose-of-meshgrid-in-python-numpy)

meshgrid主要是用来很方便的生成坐标对，坐标由给定的x, y两个数组来提供，具体的操作示意图，看下面的图片就一目了然了。

![](/images/posts/python/meshgrid.png)

将x和y分别在另一个数组的维度方向上进行扩展，然后就生成了坐标pair，返回的结果就是坐标的x集合和y集合。

```python
>>> nx, ny = (3, 2)
>>> x = np.linspace(0, 1, nx) # x = array([0, 0.5, 1])
>>> y = np.linspace(0, 1, ny) # y = array([0, 1])
>>> xv, yv = np.meshgrid(x, y)
>>> xv
array([[ 0. ,  0.5,  1. ],
       [ 0. ,  0.5,  1. ]])
>>> yv
array([[ 0.,  0.,  0.],
       [ 1.,  1.,  1.]])
```

一个与meshgrid经常一起用的函数是reval，通常用于将meshgrid返回的的坐标集合矩阵拉伸，用于后续处理

```python
>>> x = np.array([[1, 2, 3], [4, 5, 6]])
>>> print(np.ravel(x))
[1 2 3 4 5 6]
```