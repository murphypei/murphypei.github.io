---
title: MXNet框架学习（1）：MXNet安装和NDArray
date: 2018-08-21 12:02:41
update: 2018-08-21 12:02:41
categories: MxNet
tags: [深度学习, MXNet, Python]
---

最近开始学习MXNet框架的使用，看到一篇较好的入门[英文博客](https://becominghuman.ai/an-introduction-to-the-mxnet-api-part-1-848febdcf8ab)，讲解的很实用，推荐看原文，基本读完可以上手试试模型了，因此觉得非常不错，就想翻译一遍做个记录，也方便其他新手。

<!--more-->

翻译并不是原文照搬，表达最主要的意思和内容，摒弃一些废话。这篇文章是给像我一样，有深度学习基础，熟悉相关知识，只是为了了解MXNet的人群，不会过多介绍太基础的东西。

## 1.MXNet安装

### 1.1 安装cuda和cuDNN

关于这个网上一堆教程，在我看来都是非常错误的，一堆驱动错误什么的，乱七八糟。这里推荐我的方法，在ubuntu18.04上试验通过：

1. 官网下载cuda8.0或者9.0的**deb(local)**，注意一定要下载deb版本的，而不是run文件，因为deb文件包含了驱动程序

2. `dpkg -i` 安装deb文件，然后`apt install cuda-8.0`就可以自动安装了，安装的过程会自动下载相应的NVIDIA的驱动程序

  * 安装要求gcc和g++的版本如何相应的要求，比如cuda8.0需要gcc5。具体就是安装相应的版本，然后修改软连接
```sh
sudo apt install gcc-5 g++-5
sudo rm /usr/local/cuda/bin/gcc
sudo rm /usr/local/cuda/bin/g++
sudo ln -s /usr/bin/gcc-5 /usr/local/cuda/bin/gcc
sudo ln -s /usr/bin/g++-5 /usr/local/cuda/bin/g++
```

3. 下载cuDNN的Linux压缩包，解压，拷贝，拷贝使用`cp -P`来拷贝软连接。

```sh
sudo cp -P cuda/include/cudnn.h /usr/local/cuda/include
sudo cp -P cuda/lib64/libcudnn* /usr/local/cuda/lib64/
sudo chmod a+r /usr/local/cuda/lib64/libcudnn*
```

4. 安装完添加路径
```sh
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

**再次强调，个人经验，多看官网的那个安装指南的PDF文件，而不是去网上找乱七八糟的教程！！！**

### 1.2 安装MXNet-Python

这里只推荐一种方法，virtualenv和pip，具体怎么操作看MXNet官网，说的很明白了。注意，`pip install`需要制定cuda的版本，比如`pip install mxnet-cu80`这种。
```sh
pip install --upgrade pip
pip install mxnet-cu80
sudo apt-get install graphviz
pip install graphviz
```

装完测试一下：
```py
import mxnet as mx
a = mx.nd.ones((2, 3), mx.gpu())
b = a * 2 + 1
b.asnumpy()
```

能打印除b就没问题了。

## 2. NDArray模块

这是这篇的重点了，安装完MXNet就可以看看MXNet最重要的数据结构NDArray。NDArray是一种n维阵列，其中可包含类型与大小完全一致的项（32位浮点、32位整数等）。一句话，这种数据结构就是为了批量处理多通道的图像，比如MXNet中layer的一次输入最常见的结构就是(batch_size, channel, height, width)。

### 2.1 NDArray API

一句话：NDArrays与Numpy的Array极为类似，熟悉Numpy，用NDArray就很简单了。
```py
>>> a = mx.nd.array([[1,2,3], [4,5,6]])
>>> a.size
6
>>> a.shape
(2L, 3L)
>>> a.dtype
<type 'numpy.float32'>
```

默认情况下，一个NDArray可以保存32位浮点，不过这个大小可以调整。
```py
>>> import numpy as np
>>> b = mx.nd.array([[1,2,3], [2,3,4]], dtype=np.int32)
>>> b.dtype
```

NDArray的打印很简单，这样：
```py
>>> b.asnumpy()
array([[1, 2, 3],
       [2, 3, 4]], dtype=int32)
```

NDArray支持所有需要的数学运算，例如可以试试看进行一个面向元素的矩阵乘法：
```py
>>> a = mx.nd.array([[1,2,3], [4,5,6]])
>>> b = a*a
>>> b.asnumpy()
array([[  1.,   4.,   9.],
       [ 16.,  25.,  36.]], dtype=float32)
```

再来个严格意义上的矩阵乘法（又叫“点积”）怎么样？
```py
>>> a = mx.nd.array([[1,2,3], [4,5,6]])
>>> a.shape
(2L, 3L)
>>> a.asnumpy()
array([[ 1.,  2.,  3.],
       [ 4.,  5.,  6.]], dtype=float32)
>>> b = a.T
>>> b.shape
(3L, 2L)
>>> b.asnumpy()
array([[ 1.,  4.],
       [ 2.,  5.],
       [ 3.,  6.]], dtype=float32)
>>> c = mx.nd.dot(a,b)
>>> c.shape
(2L, 2L)
>>> c.asnumpy()
array([[ 14.,  32.],
       [ 32.,  77.]], dtype=float32)
```
接着再来试试一些更复杂的运算：

初始化一个均匀分布的1000x1000矩阵并存储在GPU#0（此处使用了一个g2实例）。
初始化另一个正态分布的1000x1000矩阵（均值为1，标准差为2），也存储在GPU#0。
```py
>>> c = mx.nd.uniform(low=0, high=1, shape=(1000,1000), ctx="gpu(0)")
>>> d = mx.nd.normal(loc=1, scale=2, shape=(1000,1000), ctx="gpu(0)")
>>> e = mx.nd.dot(c,d)
```

别忘了，MXNet可以在CPU和GPU上实现一致的运行结果。这就是个很棒的例子：只要将上述代码中的“gpu(0)”替换为“cpu(0)”，就可以通过CPU运行这个点积。

差不多NDArray就介绍这些了，因为和Numpy实在太像了，没啥可过多介绍的。
