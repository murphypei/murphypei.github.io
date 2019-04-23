---
layout: post
title: Python虚拟环境和包管理总结
date: 2018-03-30
update: 2018-04-12
categories: Python
tags: [Python, 虚拟环境, 包管理, pip, virtual, conda]
---

Python由于2.x和3.x版本不兼容的问题，出现了虚拟环境管理的方式，这也算是日常比较常见的Python环境配置的一种方式。此外，由于Python丰富的库依赖，对于库的管理又出现了不同。本文将总结日常使用virtualenv、pip、anaconda等Python配置的经验。

<!--more-->

## 库管理

说到Python的库管理，首先想到的就是pip了。这是Python官方自带的管理依赖库的软件，对于不同版本的Python，pip 也是不一样的，或者简单的可以理解为，你安装了一个Python，就安装了一个pip，二者绑定。比如我的电脑上就有两个Python和pip。

```shell
peic@peic-ubuntu:~$ ll /usr/local/bin/pip*
lrwxrwxrwx 1 root root  19  1月  3 18:03 /usr/local/bin/pip -> /usr/local/bin/pip2*
-rwxr-xr-x 1 root root 204  2月 13  2017 /usr/local/bin/pip2*
-rwxr-xr-x 1 root root 204  2月 13  2017 /usr/local/bin/pip2.7*
-rwxr-xr-x 1 root root 206 12月 20 19:04 /usr/local/bin/pip3*
-rwxr-xr-x 1 root root 206 12月 20 19:04 /usr/local/bin/pip3.5*
```

对于使用不同版本的Python，应该使用不同pip来管理相应的依赖库。

pip使用[PyPI](https://pypi.Python.org/pypi)的源来管理依赖库，如果国内连不上或者速度慢，可以更换为国内源。

很多人喜欢用anaconda来一次安装很丰富的库，很方便。anaconda也分为2.x和3.x，和Python一样，并且一样有不同版本的pip。

anaconda最重要的是自带了conda命令，也可以install，因此就会有疑惑，anaconda的pip install和conda install有什么不同？其实本质上都是从一个源获取目标并安装，只是源不同，conda使用了anaconda自己的源，因此很多时候pip安装不了的库，conda却可以，这就是因为这个库没有放到PyPI上，提交到anaconda了。需要注意的是，conda使用了一个新的包格式，你不能交替使用pip 和conda。因为pip不能安装和解析conda的包格式。你可以使用两个工具 但是他们是不能交互的。

我推荐使用anaconda的同时使用conda来进行包的管理，这样能够统一，而且和后面要讲的虚拟环境也保持一致。

## 虚拟环境管理

虚拟环境是为了创建一个指定版本和独立的库的Python运行环境，具体可bing一下。Python常用的管理虚拟环境的主要是virtualenv和anaconda自带的conda，具体用法可bing，此处不在赘述，网上资料很多。

我个人对于不同组合选用的原则很简单：

* 如果没有装anaconda，就用virtualenv，然后用pip管理依赖库；

* 如果使用anaconda，就用conda命令来管理依赖库和虚拟环境，保持统一。

我推荐使用pip+virtualenv的组合，anaconda慢不说，而且conda的源也不如pip原生的源丰富。