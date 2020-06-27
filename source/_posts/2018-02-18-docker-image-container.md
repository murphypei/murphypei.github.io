---
layout: post
title: Docker容器和镜像、命令操作详解
date: 2018-02-18
update: 2018-04-12
categories: Docker
tags: [Docker, Batch Normalization]
---

docker中的容器和镜像是docker这门工具核心概念，我在初学docker的时候也是一知半解，看到了[这篇文章](http://dockone.io/article/783)，觉得从命令入手，引入统一文件系统（the union file system）的知识，讲解的比较透彻，整理转载，感谢原文作者。

<!--more-->

## 镜像

镜像（Image）就是一堆只读层（read-only layer）的统一视角，也许这个定义有些难以理解，下面的这张图能够帮助读者理解镜像的定义。

![](/images/posts/docker/image_container/d8384db1332e83c4.png)

从左边我们看到了多个只读层，它们重叠在一起。除了最下面一层，其它层都会有一个指针指向下一层。这些层是Docker内部的实现细节，并且能够在主机（运行Docker的机器）的文件系统上访问到。**统一文件系统（union file system）技术能够将不同的层整合成一个文件系统，为这些层提供了一个统一的视角，这样就隐藏了多层的存在，在用户的角度看来，只存在一个文件系统。**我们可以在图片的右边看到这个视角的形式。

如果不关心多层的结构，最简单的理解：**镜像就是打包好的只读文件**

你可以在你的主机文件系统上找到有关这些层的文件。需要注意的是，在一个运行中的容器内部，这些层是不可见的。它们存在于/var/lib/docker/aufs目录下。

```shell
sudo tree -L 1 /var/lib/docker/
/var/lib/docker/
├── aufs
├── containers
├── graph
├── init
├── linkgraph.db
├── repositories-aufs
├── tmp
├── trust
└── volumes
7 directories, 2 files
```

## 容器

容器（container）的定义和镜像（image）几乎一模一样，也是一堆层的统一视角，**唯一区别在于容器的最上面那一层是可读可写的。**

![](/images/posts/docker/image_container/34b9fc3aa5addc15.png)

容器的这个定义并不关心容器是否运行，事实上，我的理解是，容器因为有了上面一层读写层，是一种可修改的运行环境，依据Linux一切皆文件的理念，这个环境也是由只读文件（镜像）和可修改文件组成。

## 运行态的容器

一个运行态容器（running container）被定义为**一个可读写的统一文件系统加上隔离的进程空间和包含其中的进程**。下面这张图片展示了一个运行中的容器。

![](/images/posts/docker/image_container/4f793e62b594a6e1.png)

正是文件系统隔离技术使得Docker成为了一个前途无量的技术。一个容器中的进程可能会对文件进行修改、删除、创建，这些改变都将作用于可读写层（read-write layer）。下面这张图展示了这个行为。

![](/images/posts/docker/image_container/e98eaceee62588d0.png)

我们可以通过运行以下命令来验证我们上面所说的：

`dcoker run ubuntu touch happiness.txt`

即便是这个ubuntu容器不再运行，我们依旧能够在主机的文件系统上找到这个新文件。

```shell
find / -name happiness.txt
/var/lib/docker/aufs/diff/860a7b...889/happiness.txt
```

## 镜像层

为了将零星的数据整合起来，我们提出了镜像层（image layer）这个概念。下面的这张图描述了一个镜像层，通过图片我们能够发现一个层并不仅仅包含文件系统的改变，它还能包含了其他重要信息。

![](/images/posts/docker/image_container/cf3aa0f878e929d8.png)

元数据（metadata）就是关于这个层的额外信息，它不仅能够让Docker获取运行和构建时的信息，还包括父层的层次信息。需要注意，只读层和读写层都包含元数据。

![](/images/posts/docker/image_container/3617d8aeb0df8bc2.png)

除此之外，每一层都包括了一个指向父层的指针。如果一个层没有这个指针，说明它处于最底层。

![](/images/posts/docker/image_container/8129b164de4aa120.png)

在我自己的主机上，镜像层（image layer）的元数据被保存在名为”json”的文件中，比如说：

`/var/lib/docker/graph/e809f156dc985.../json`

e809f156dc985...就是这层的id

一个容器的元数据好像是被分成了很多文件，但或多或少能够在`/var/lib/docker/containers/<id>`目录下找到，<id>就是一个可读层的id。这个目录下的文件大多是运行时的数据，比如说网络，日志等等。

## 结合命令理解

### `docker create <image-id>`

![](/images/posts/docker/image_container/734938abfb7c68f3.jpg)

`docker create` 命令为指定的镜像（image）添加了一个可读写层，构成了一个新的容器。**这个容器并没有运行。**

![](/images/posts/docker/image_container/97eebd78315a7e3a.png)

### `docker start <container-id>`

![](/images/posts/docker/image_container/deed3c22dad8c373.jpg)

`docker start` 命令为容器文件系统创建了一个进程隔离空间。注意，每一个容器只能够有一个进程隔离空间。

### `docker run <image-id>`

![](/images/posts/docker/image_container/a25b426d4d852878.jpg)

docker start 和 docker run命令有什么区别？

![](/images/posts/docker/image_container/47fd20c0fa6b248f.png)

从图片可以看出，docker run 命令先是利用镜像创建了一个容器，然后运行这个容器。这个命令非常的方便，并且隐藏了两个命令的细节，但从另一方面来看，这容易让用户产生误解。

其实docker run命令类似于git pull命令。git pull命令就是git fetch 和 git merge两个命令的组合，同样的，docker run就是docker create和docker start两个命令的组合。

### `docker ps`

![](/images/posts/docker/image_container/867d9146479850b6.jpg)

docker ps 命令会列出所有运行中的容器。这隐藏了非运行态容器的存在.

### `docker ps -a`

![](/images/posts/docker/image_container/4287e2cc738ec23d.jpg)

docker ps –a命令会列出所有的容器，不管是运行的，还是停止的。

### `docker images`

![](/images/posts/docker/image_container/5e239b2d5cf42f96.jpg)

docker images命令会列出了所有顶层（top-level）镜像。实际上，在这里**我们没有办法区分一个镜像和一个只读层**，所以我们提出了top-level镜像。**只有创建容器时使用的镜像或者是直接pull下来的镜像能被称为顶层（top-level）镜像**，并且每一个顶层镜像下面都隐藏了多个镜像层。

### `docker images –a`

![](/images/posts/docker/image_container/566aa876217eeaa9.jpg)

docker images –a命令列出了所有的镜像，也可以说是列出了所有的可读层。如果你想要查看某一个image-id下的所有层，可以使用docker history来查看。

### `docker rm <container-id>`

docker rm命令会移除构成容器的可读写层。注意，这个命令只能对非运行态容器执行。

虽然容器是镜像生成的，但是容器和镜像并不是硬链接关系，所以移除容器，并不会影响只读文件的镜像

### `docker rmi <image-id>`

docker rmi 命令会移除构成镜像的一个只读层。你只能够使用docker rmi来移除最顶层（top level layer）（也可以说是镜像），你也可以使用-f参数来强制删除中间的只读层。 

### `docker commit <container-id>`

![](/images/posts/docker/image_container/579de73bc5368456.jpg)

![](/images/posts/docker/image_container/1515de1ff3fa6197.png)

docker commit命令将容器的可读写层转换为一个只读层，这样就把一个容器转换成了不可变的镜像。

### `docker build`

![](/images/posts/docker/image_container/359d48c0595e851b.jpg)

docker build命令非常有趣，它会反复的执行多个命令。

![](/images/posts/docker/image_container/a43df8ecf698c0a2.png)


### `docker exec <running-container-id>`

![](/images/posts/docker/image_container/6a8e71845dcc28ad.jpg)

docker exec 命令会在运行中的容器执行一个新进程。

### `docker inspect <container-id> or <image-id>`

![](/images/posts/docker/image_container/31a4f848515234d7.jpg)

docker inspect命令会提取出容器或者镜像最顶层的元数据。

### `docker export <container-id>`

![](/images/posts/docker/image_container/9929bc83f8d79af6.jpg)

docker export命令创建一个tar文件，并且**移除了元数据和不必要的层，将多个层整合成了一个层，只保存了当前统一视角看到的内容**（expoxt后的容器再import到Docker中，通过docker images –tree命令只能看到一个镜像；而save后的镜像则不同，它能够看到这个镜像的历史镜像）。

### `docker save <image-id>`

![](/images/posts/docker/image_container/3c8816e666fdba5c.jpg)

docker save命令会创建一个镜像的压缩文件，这个文件能够在另外一个主机的Docker上使用。和export命令不同，这个命令为每一个层都保存了它们的元数据。这个命令只能对镜像生效。

### `docker history <image-id>`

![](/images/posts/docker/image_container/24d1badf8f886be9.jpg)

docker history命令递归地输出指定镜像的历史镜像。

## 结论

本文从镜像和容器的构成入手，详解了镜像和容器的区别，并对一些常见的docker命令的操作过程进行了解剖。当然还有很多命令本文并未涉及，仍需要进一步的深入学习。






