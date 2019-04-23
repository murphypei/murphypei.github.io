---
title: MXNet框架学习（4）：模型加载和使用
date: 2018-08-24 12:02:41
update: 2018-08-24 12:02:41
categories: 深度学习
tags: [深度学习, MXNet, Python, pretrained]
---

在[MXNet框架学习（3）]((https://chaopei.github.io/blog/2018/08/mxnet-module.html))中，我们构建并训练了第一个神经网络，这篇文章我们学习如何加载和使用一个已有模型。

<!--more-->

表现优秀的深度学习模型都非常复杂，它们拥有上百个网络层，需要花费数天甚至数周的时间在庞大的数据集上进行训练，设计和调整这些模型需要大量的专业知识。

幸运的是，使用这些模型则简单的多，一般只需要几行代码。在这篇文章中，我们将使用一个预训练的Inception V3模型来进行图像分类工作。

### 1. Inception V3

Inception V3发布于2015年12月，是GoogleNet模型（获得2014年ImageNet挑战赛冠军）的进化版。我们并不对科研论文进行解读，但是总结一句，Inception V3比当时最好的模型精确度提高了15-25%，同时计算量减少了6倍，参数量最少降低了5倍。这么牛逼的东西，我们怎么用呢？

### 2. MXNet model zoo

MXNet模型库收集了许多预先训练好的模型，你可以获得这些模型的结构定义和模型已经训练好的参数（也就是神经网络的权重），有些还有使用说明。

我们首先下载模型的定义文件和参数文件，修改一下文件名（方便后续传参）：

```shell
$ wget http://data.dmlc.ml/models/imagenet/inception-bn/Inception-BN-symbol.json
$ wget http://data.dmlc.ml/models/imagenet/inception-bn/Inception-BN-0126.params
$ mv Inception-BN-0126.params Inception-BN-0000.params
```

你可以打开第一个json文件，你可以看到所有层的定义，第二个文件是一个二进制文件。

虽然这个模型已经在ImageNet数据集上训练好了，我们仍然需要下载相应的图片分类的信息列表（总共有1000类）。

```
$ wget http://data.dmlc.ml/models/imagenet/synset.txt
$ wc -l synset.txt
    1000 synset.txt
$ head -5 synset.txt
n01440764 tench, Tinca tinca
n01443537 goldfish, Carassius auratus
n01484850 great white shark, white shark, man-eater, man-eating shark, Carcharodon carcharias
n01491361 tiger shark, Galeocerdo cuvieri
n01494475 hammerhead, hammerhead shark
```

搞定，我们可以开始工作了。

### 3. 加载模型

我们需要做的：

* 加载模型的保存状态：MXNet称为checkpoint。返回结果是，模型的symbol和模型的参数

```Python
import mxnet as mx

sym, arg_params, aux_params = mx.model.load_checkpoint('Inception-BN', 0) # 这个0就是修改参数文件的原因，也可以传入未修改的数值。
```

* 利用得到的symbol创建一个新的module，我们也可以设置一个context参数用来决定在哪里运行这个模型：默认参数是cpu(0),但是我们可以使用gpu(0)来让模型运行在GPU上。

```Python
mod = mx.mod.Module(symbol=sym, context=gpu(0))
```

* 将输入数据绑定到输入的symbol上，输入数据命名为data，这是根据网络的输入层（可从json文件查看）来决定的。

* 定义data的数据维度为1x3x224x224：224x224是图像的分辨率，3是图像的RGB三通道，1是batch size（我们一次只预测一张图片）

```Python
mod.bind(for_training=False, data_shapes=[('data', (1,3,224,224))])
```

* 设置模型的参数

```py
mod.set_params(arg_params, aux_params)
```

一切准备妥当，只需要4行代码，现在把数据放进去看看会发生什么。

### 4. 准备数据

模型需要的是4维的NDArray数据，包括RGB三通道和224x224的图像大小，我们使用OpenCV库从输入的图像来来构造NDArray。如果你没有安装OpenCV，运行`pip install opencv-Python`应该就行了（大多数情况下）。

步骤如下：

* 读取图片：返回一个numpy array，大小是图片的高度、宽度、3，通道是BGR，应该转为RGB

```py
img = cv2.imread(filename)
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
```

* 图片缩放到224x224

```py
img = cv2.resize(img, (224, 224))
```

* 更改数据结构，从（h, w, 3)改为（3，h，w）

```py
img = np.swapaxes(img, 0, 2)
img = np.swapaxes(img, 1, 2)
```

* 增加第4维数据

```py
img = img[np.newaxis, :]
array = mx.nd.array(img)      # array.shape: (1L, 3L, 224L, 224L)
```

如果batch size不设置为1，array的第一维也就随之变化。

现在可以开始预测了。

### 5. 预测

你应该还记得第3部分我们说过，一个module对象必须批量的输入数据给一个model：一个通用的方法就是使用data iterator（我们当时用的是其子类NDArrayIter对象）

现在我们只要预测一张图像，当然我们也可以使用data iterator，但是杀鸡焉用牛刀。我们可以创建一个命名tuple，称为Batch，作为一个虚拟的iterator，当其data属性被引用的时候，直接返回我们输入的NDArray。

```py
from collections import namedtuple
Batch = namedtuple('Batch', ['data'])
```

现在我们可以将数据输入到模型，预测其结果

```py
mod.forward(Batch([array])
```

模型会输出一个1000维的NDArray，保存了1000个类别的概率。因为只有一张图片，所以只有一行（1000列）。我们对其进行一些压缩（去掉多余维度）

```py
prob = mod.get_outputs()[0].asnumpy() # prob.shape: (1, 1000)
prob = np.squeeze(prob) # prob.shape: (1000, )
```

现在我们可以获取概率最大的索引值了，以及其对应的分类概论

```py
sortedprob = np.argsort(prob)[::-1]
p = prob[sortedprob[0]]
```

现在可以根据分类信息和ImageNet的标注文件获得类别了

```py
synsetfile = open('synset.txt', 'r')
categorylist = []
for line in synsetfile:
  categorylist.append(line.rstrip())

c_name = categorylist[sortedprob[0]]
```

结束。
