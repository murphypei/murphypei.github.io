---
title: docker搭建本地/局域网仓库
date: 2018-04-15 12:04:03
update: 2018-04-15 12:04:03
categories: Docker
tags: [Docker, 本地仓库, 镜像, registry, insecure]
---

创建一个保存自己的docker开发环境镜像，这样在换电脑时，特别是windows系统的电脑，可以将镜像直接部署上去，环境随时切换。

<!--more-->

为了达到这个目的，有两个方法：

* 1. 一个是创建dockerfile，直接利用dockerfile来创建镜像。这个方法好处在于dockerfile只是一个文件，很小，随时能够直接从github上拉取下来；缺点时需要编写一个复杂的dockerfile，创建镜像是需要联网下载系统和软件。

* 2. 创建一个本地仓库，将镜像放于本地仓库中。其他电脑通过局域网连接，直接从本地仓库pull镜像。这种方法的好处是镜像文件完全是一样的，是你一直在用的，而且拉取不需要联外网，只要在局域网内就行。缺点时你需要将本地仓库加入局域网

一般团队写作而言，都会在局域网内维持一个基本环境镜像，因此使用2更方便。我本人目前没能搞定dockerfile的编写，另一方面更加喜欢本地镜像拉取的原汁原味的开发环境，所以在个人笔记本上创建了本地仓库，其余的电脑从笔记本上拉取即可。本文将介绍本地仓库的创建和基本使用。

## 创建本地仓库

首先在一台计算机上创建本地仓库，该计算机需要安装好了docker.

### 下载官方registry镜像

`docker pull registry`

`registry`镜像是docker官方提供的，用于作为仓库运行的镜像。如果直接运行上述命令比较慢，则需要挂载国内的docker仓库镜像地址，具体做法可以参考本文后续。


### 运行registry容器

`docker run -d -p 5000:5000 -v /home/docker_registry:/var/lib/registry registry`

这条命令表示在后台运行registry容器、将容器的5000端口映射到宿主机的5000端口，将宿主机的`/home/docker_registry`挂载共享到容器的`/var/lib/registry`文件夹

这样，这台计算机就运行了一个本地仓库。

## 使用本地仓库

### 上传镜像

现在，在局域网的计算机上，我们可以直接提交镜像了。首先将保存好的开发环境镜像重新打上标签：

`docker tag ubuntu <ip>:5000/ubuntu:latest`

ip地址就是仓库所在电脑的ip地址。

然后提交本地镜像

`docker push <ip>:5000/ubuntu:latest`

多半都会遇到的一个问题：

```
unable to ping registry endpoint https://172.18.3.22:5000/v0/
v2 ping attempt failed with error: Get https://172.18.3.22:5000/v2/: http: server gave HTTP response to HTTPS client
```

这是由于Registry为了安全性考虑，默认是需要https证书支持的.

但是我们可以通过一个简单的办法解决：

* Linux(Ubuntu):

    * 修改/etc/docker/daemon.json文件（下方的这个配置文件包含了修改国内镜像源）
    
    * vim /etc/docker/daemon.json
    ```
    {
        "registry-mirrors": ["https://registry.docker-cn.com"],
        "insecure-registries": ["<ip>:5000"] 
    }
    ```
* windows

    * 右键任务栏中的docker图标 -> settings -> Daemon -> 参照上述的方式，修改registry-mirrors和insecure-registries -> apply


### 查看镜像信息

在局域网的电脑上，可以查看本地仓库的镜像信息

`curl http://<ip>:5000/v2/_catalog`

### 拉取镜像

在其他电脑上，可以直接拉取镜像

`docker pull <ip>:5000/ubuntu:latest`

### 运行镜像

```
docker run -it <ip>:5000/ubuntu16.04:latest /bin/bash
```

如果对容器进行了修改，直接提交容器为一个新的镜像，然后打上标签，push就行了

