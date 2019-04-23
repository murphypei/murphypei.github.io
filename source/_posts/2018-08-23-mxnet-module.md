---
title: MXNet框架学习（3）：数据处理和Module
date: 2018-08-23 12:02:41
update: 2018-08-23 12:02:41
categories: 深度学习
tags: [深度学习, MXNet, Python, module]
---

在[MXNet框架学习（2）](https://chaopei.github.io/blog/2018/08/mxnet-symbol.html)中，我们介绍了如何使用Symbols定义计算中使用的Graph，并处理存储在NDArray（在第一篇文章中有介绍）中的数据。本文将介绍如何使用Symbol和NDArray准备所需数据并构建神经网络。随后将使用Module API训练该网络并预测结果。

<!--more-->

## 1. 数据处理

### 1.1 定义数据集

我们（设想中的）数据集包含1000个数据样本：

* 每个样本有100个特征
* 每个特征体现为一个介于0和1之间的浮点值
* 样本被分为10个类别，我们将使用神经网络预测特定样本的恰当类别
* 我们将使用800个样本进行训练，使用200个样本进行验证
* 训练和验证过程的批大小为10

```py
import mxnet as mx
import numpy as np
import logging
logging.basicConfig(level=logging.INFO)
sample_count = 1000
train_count = 800
valid_count = sample_count - train_count
feature_count = 100
category_count = 10
batch=10
```

### 1.2 生成数据集

我们将通过均匀分布的方式生成这1000个样本，将其存储在一个名为“X”的NDArray中：1000行，100列。
```py
X = mx.nd.uniform(low=0, high=1, shape=(sample_count,feature_count))
>>> X.shape
(1000L, 100L)
>>> X.asnumpy()
array([[ 0.70029777,  0.28444085,  0.46263582, ...,  0.73365158,
         0.99670047,  0.5961988 ],
       [ 0.34659418,  0.82824177,  0.72929877, ...,  0.56012964,
         0.32261589,  0.35627609],
       [ 0.10939316,  0.02995235,  0.97597599, ...,  0.20194994,
         0.9266268 ,  0.25102937],
       ...,
       [ 0.69691515,  0.52568913,  0.21130568, ...,  0.42498392,
         0.80869114,  0.23635457],
       [ 0.3562004 ,  0.5794751 ,  0.38135922, ...,  0.6336484 ,
         0.26392782,  0.30010447],
       [ 0.40369365,  0.89351988,  0.88817406, ...,  0.13799617,
         0.40905532,  0.05180593]], dtype=float32)
```

这1000个样本的类别用介于0-9的整数来代表，类别是随机生成的，存储在一个名为“Y”的NDArray中。
```py
Y = mx.nd.empty((sample_count,))
for i in range(0,sample_count-1):
  Y[i] = np.random.randint(0,category_count)
>>> Y.shape
(1000L,)
>>> Y[0:10].asnumpy()
array([ 3.,  3.,  1.,  9.,  4.,  7.,  3.,  5.,  2.,  2.], dtype=float32)
```

### 1.3 拆分数据集

随后我们将针对训练和验证两个用途对数据集进行80/20拆分。为此需要使用NDArray.crop函数。在这里，数据集是完全随机的，因此可以使用前80%的数据进行训练，用后20%的数据进行验证。实际运用中，我们可能需要首先搅乱数据集，这样才能避免按顺序生成的数据可能造成的偏差。

```py
X_train = mx.nd.crop(X, begin=(0,0), end=(train_count,feature_count-1))
X_valid = mx.nd.crop(X, begin=(train_count,0), end=(sample_count,feature_count-1))
Y_train = Y[0:train_count]
Y_valid = Y[train_count:sample_count]
```

至此数据已经准备完毕！

## 2. Module模块

### 2.1 构建网络

这个网络其实很简单，一起看看其中的每一层：

输入层是由一个名为“Data”的Symbol代表的，随后会绑定至实际的输入数据。

`data = mx.sym.Variable('data')`

fc1是第一个隐藏层，通过64个相互连接的神经元构建而来，输入层的每个特征都会连接至所有的64个神经元。如你所见，我们使用了高级的Symbol.FullyConnected函数，相比手工建立每个连接，这种做法更方便一些！

`fc1 = mx.sym.FullyConnected(data, name='fc1', num_hidden=64)`

fc1的每个输出会进入到一个激活函数(Activation function)。在这里我们将使用一个线性整流单元(Rectified linear unit)，即“Relu”。之前承诺过尽量少讲理论知识，因此可以这样理解：激活函数将用于决定是否要“启动”某个神经元，例如其输入是否由足够有意义，可以预测出正确的结果。

`relu1 = mx.sym.Activation(fc1, name='relu1', act_type="relu")`

fc2是第二个隐藏层，由10个相互连接的神经元构建而来，可映射至我们的10个分类。每个神经元可输出一个任意标度(Arbitrary scale)的浮点值。10个值中最大的那个代表了数据样本最有可能的类别。

`fc2 = mx.sym.FullyConnected(relu1, name='fc2', num_hidden=category_count)`

输出层会将Softmax函数应用给来自fc2层的10个值：这些值会被转换为10个介于0和1之间的值，所有值的总和为1。每个值代表预测出的每个类别的可能性，其中最大的值代表最有可能的类别。

`out = mx.sym.SoftmaxOutput(fc2, name='softmax')`

`mod = mx.mod.Module(out)`

### 2.2 构建数据迭代器

在第一篇文章中，我们了解到神经网络并不会一次只训练一个样本，因为这样做从性能的角度来看效率太低。因此我们会使用批，即一批固定数量的样本。

为了给神经网络提供这样的“批”，我们需要使用NDArrayIter函数构建一个迭代器。其参数包括训练数据、分类（MXNet将其称之为标签(Label)），以及批大小。

如你所见，我们可以对整个数据集进行迭代，同时对10个样本和10个标签执行该操作。随后即可调用reset()函数将迭代器恢复为初始状态。
```py
train_iter = mx.io.NDArrayIter(data=X_train,label=Y_train,batch_size=batch)
>>> for batch in train_iter:
...   print batch.data
...   print batch.label
...
[<NDArray 10x99 @cpu(0)>]
[<NDArray 10 @cpu(0)>]
[<NDArray 10x99 @cpu(0)>]
[<NDArray 10 @cpu(0)>]
[<NDArray 10x99 @cpu(0)>]
[<NDArray 10 @cpu(0)>]
<edited for brevity>
>>> train_iter.reset()
```

网络已经准备完成，开始训练吧！

### 2.3 训练模型

首先将输入Symbol**绑定**至实际的数据集（样本和标签），这时候就会用到迭代器。

`mod.bind(data_shapes=train_iter.provide_data, label_shapes=train_iter.provide_label)`

随后对网络中的神经元权重进行初始化。这个步骤非常重要：使用“恰当”的技术对齐进行初始化可以帮助网络更快速地学习。此时可用的技术很多，Xavier初始化器（名称源自该技术的发明人Xavier Glorot）就是其中之一。

```py
# Allowed, but not efficient
mod.init_params()
# Much better
mod.init_params(initializer=mx.init.Xavier(magnitude=2.))
```

接着需要定义优化参数：

我们将使用随机坡降法(Stochastic Gradient Descent)算法（又名SGD），该算法在机器学习和深度学习领域有着广泛的应用。
我们会将学习速率设置为0.1，这是SGD算法一个非常普遍的设置。

`mod.init_optimizer(optimizer='sgd', optimizer_params=(('learning_rate', 0.1), ))`

最后，终于可以开始训练网络了！我们会执行50个回合(Epoch)的训练，也就是说，整个数据集需要在这个网络中（以10个样本为一批）运行50次。

```py
mod.fit(train_iter, num_epoch=50)
INFO:root:Epoch[0] Train-accuracy=0.097500
INFO:root:Epoch[0] Time cost=0.085
INFO:root:Epoch[1] Train-accuracy=0.122500
INFO:root:Epoch[1] Time cost=0.074
INFO:root:Epoch[2] Train-accuracy=0.153750
INFO:root:Epoch[2] Time cost=0.087
INFO:root:Epoch[3] Train-accuracy=0.162500
INFO:root:Epoch[3] Time cost=0.082
INFO:root:Epoch[4] Train-accuracy=0.192500
INFO:root:Epoch[4] Time cost=0.094
INFO:root:Epoch[5] Train-accuracy=0.210000
INFO:root:Epoch[5] Time cost=0.108
INFO:root:Epoch[6] Train-accuracy=0.222500
INFO:root:Epoch[6] Time cost=0.104
INFO:root:Epoch[7] Train-accuracy=0.243750
INFO:root:Epoch[7] Time cost=0.110
INFO:root:Epoch[8] Train-accuracy=0.263750
INFO:root:Epoch[8] Time cost=0.101
INFO:root:Epoch[9] Train-accuracy=0.286250
INFO:root:Epoch[9] Time cost=0.097
INFO:root:Epoch[10] Train-accuracy=0.306250
INFO:root:Epoch[10] Time cost=0.100
...
INFO:root:Epoch[20] Train-accuracy=0.507500
...
INFO:root:Epoch[30] Train-accuracy=0.718750
...
INFO:root:Epoch[40] Train-accuracy=0.923750
...
INFO:root:Epoch[50] Train-accuracy=0.998750
INFO:root:Epoch[50] Time cost=0.077
```

如你所见，训练的准确度有了飞速提升，50个回合后已经接近99%以上。似乎我们的网络已经从训练数据集中学成了。非常惊人！

但针对验证数据集执行的效果如何呢？

### 2.4 验证模型

随后将新的数据样本放入网络，例如剩下的那20%尚未在训练中使用过的数据。

首先构建一个迭代器，这一次将使用验证样本和标签。

`pred_iter = mx.io.NDArrayIter(data=X_valid,label=Y_valid, batch_size=batch)`

随后要使用Module.iter_predict()函数，借此让样本在网络中运行。这样做的同时，还需要对预测的标签和实际标签进行对比。我们需要追踪比分并显示验证准确度，即，网络针对验证数据集的执行效果到底如何。

```py
pred_count = valid_count
correct_preds = total_correct_preds = 0
for preds, i_batch, batch in mod.iter_predict(pred_iter):
    label = batch.label[0].asnumpy().astype(int)
    pred_label = preds[0].asnumpy().argmax(axis=1)
    correct_preds = np.sum(pred_label==label)
    total_correct_preds = total_correct_preds + correct_preds
print('Validation accuracy: %2.2f' % (1.0*total_correct_preds/pred_count))
```

iter_predict()返回了：

* i_batch：批编号。
* batch：一个NDArray数组。这里它其实保存了一个NDArray，其中存储了当前批的内容。我们将用它找出当前批中10个数据样本的标签，随后将其存储在名为Label的Numpy array中（10个元素）。
* preds：也是一个NDArray数组。这里它保存了一个NDArray，其中存储了当前批预测出的标签：对于每个样本，我们提供了所有10个分类预测出的可能性（10x10矩阵）。因此我们将使用argmax()找出最高值的指数，即最可能的分类。所以* pred_label实际上是一个10元素数组，其中保存了当前批中每个数据样本预测出的分类。

随后我们需要使用Numpy.sum()将label和pred_label中相等值的数量进行对比。

最后计算并显示验证准确度。验证准确度：0.09，充分说明我们的数据真是随即的....训练的精度只不过是过拟合而以。
