---
title: docker加入用户组，省去sudo
date: 2018-12-08 12:04:03
update: 2018-12-08 12:04:03
categories: Docker
tags: [Docker, sudo, 用户组, root]
---

ubuntu16安装了docker以后，每次使用docker命令均需要sudo，十分麻烦，发现了一种可以省去的方法。

<!--more-->

## 为什么docker命令要使用sudo？

Docker守候进程绑定的是一个unix socket，而不是TCP端口。这个套接字默认的属主是root，其他是用户可以使用sudo命令来访问这个套接字文件。因为这个原因，docker服务进程都是以root帐号的身份运行的。

## 怎么避免sudo？

为了避免每次运行docker命令的时候都需要输入sudo，可以创建一个docker用户组，并把相应的用户添加到这个分组里面。当docker进程启动的时候，会设置该套接字可以被docker这个分组的用户读写。这样只要是在docker这个组里面的用户就可以直接执行docker命令了，这就是大概的原理。实测在ubuntu16中安装了最新的docker是会自动创建一个docker用户组的。

1. 首先查看是否已经存在docker分组

    `sudo cat /etc/group | grep docker`

2. 如果没有docker分组，创建docker分组

    `sudo groupadd -g 999 docker`
        * `-g 999`为组ID，也可以不指定

3. 将用户添加到docker分组

    `sudo usermod -aG docker <username>`

4. 修改守护进程绑定的套接字的权限，能够被docker分组访问

    `sudo chmod a+rw /var/run/docker.sock`

5. 退出当前用户登陆状态，然后重新登录，以便让权限生效，或重启docker-daemon

    `sudo systemctl restart docker`

6. 确认你可以直接运行docker命令，执行docker命令

    `docker  info`

**注意**：该docker分组等同于root帐号，具体的详情可以参考这篇文章：Docker Daemon Attack Surface.