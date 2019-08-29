---
layout: post
title: windows7搭建Qt和opencv环境（借助VS2015编译器）
date: 2017-05-16
update: 2018-04-12
categories: C++
tags: [qt5, opencv, VS2015, MSVC2015]
---

记录Qt配置opencv环境遇到的问题，折腾了好几天弄这个环境，不得不说QT自带的creator真是让人醉了，只提示程序crashed，没有任何原因。所以记录一下，防止以后再被坑。

<!--more-->

### 基本环境

* Windows7 64bit（盗版已激活）
* 安装了Visual Studio 2015 64bit（盗版已激活）

### Qt安装
因为已经安装了VS2015，所以直接去官网下载Qt，下载地址：

[摸我](https://www.qt.io/download-open-source/#section-2)

出于保守观念，我下载了较老的**5.6版本**：

`Qt 5.6.2 for Windows 64-bit (VS 2015, 839 MB)    (info)`

然后就是一路安装....

装完之后，这个就是可以运行Qt Creator的，在Creator这个IDE中测试，通过。

### VS安装Qt插件

这个主要是为了在VS中编辑Qt的工程，至于原因，当然是以为VS这个宇宙最强IDE更好用。

需要安装Qt插件，Qt官网就有vs-add-in这个VS插件，直接下载点击安装就行了，下载地址：

[摸我](http://download.qt.io/development_releases/vsaddin/)

然后就可以在VS中配置Qt项目选项了，这也没啥问题。网上教程一堆。


### Qt和opencv

Qt和opencv网上教程也是一堆。我天真的以为，这也很顺风顺水....

我首先下载了opencv2.4.13（windows版本），然后解压，然后开始疯狂添加路径。

> 题外话：opencv的windows版本解压就可以得到已经编译了的文件（build文件夹）

因为Qt程序一直crashed，而且我肯定是opencv出问题了，所以我决定在VS2015中测试opencv。大家都知道，2.4.13中有vc11和vc12两个文件夹。在VS2015中，使用vc12。配置了属性表之后，完美通过。

我仔细思考了一下，觉得还是编译器的问题。stackoverflow中首先肯定了，这种情况的crashed是dll文件没找到，而我在Qt中添加的opencv库路径是解压得到vc12。**问题的关键在于：** Qt自动检测的编译器是VS2015的编译器，而Qt要求dll文件和代码文件必须使用同一个编译器。我天真的以为VS2015中能使用vc12的编译结果，Qt中也可以，事实证明是不行的！！！

**解决办法：**

使用VS2015的编译器MSVC2015手动编译一下opencv的源码，然后在Qt中引用这个编译得到的库文件。

### Qt版本问题

这个版本主要是指编译器，在windows中，Qt可以使用两种版本的编译器，Mingw和MSVC，至于我为什么不用前者，因为我下载不了。

根据我浏览的解答来看，无论是使用哪个版本，除非和opencv中的自带的编译一样（比如VS2012），**都需要手动编译opencv然后再使用库文件**。至于网上一堆只添加路径就跑起来的教程，我只想说，NB！

[使用VS2015编译opencv的Qt教程](http://blog.csdn.net/waterbinbin/article/details/52238519)

[使用Mingw编译opencv的Qt教程](http://blog.csdn.net/u014695839/article/details/53130424)

