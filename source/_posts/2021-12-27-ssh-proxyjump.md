---
title: SSH 穿越多个跳板机的连接方法
date: 2021-12-27 10:40:42
update: 2021-12-27 10:40:42
categories: Linux
tags: [linux, ssh, proxy, proxyjump, jump]
---

鉴于安全原因，工作需要使用跳板机登录；鉴于服务器环境老旧，我需要在服务器上使用 docker 来搞个开发环境，所以需要有一种方法穿越层层阻隔，让我的 vscode 直接连过去。

<!-- more -->

## SSH 公钥和私钥

* 首先搞清楚一些基本关系，一般使用密钥登录，`ssh-keygen -t rsa` 运行此命令产生公钥私钥（id\_rsa 和 id\_rsa.pub），一路回车可以不设置保护密码，假设要登录的机器是 server，登录的终端是 client，那么将公钥 id\_rsa.pub 的内容记录在 server 的 authorized_keys 中，然后 client 使用私钥 id\_rsa 登录。
* 每一个被登录的机器都开启的 ssh 服务，并配置了 ssh 密钥登录功能。对于我的需求来说，公司的跳板机和服务器一定是已经配置的，否则无法登录服务器，因此我还需要在 docker 中配置 ssh 密钥登录服务。
* client 设置登录的层层专跳（这是重点）

> ssh 相关的文件如果没有特殊说明，都是在 `~/.ssh` 文件夹中，ssh 服务的配置文件在 `/etc/ssh/sshd_config` 中。

## openssh 的 ProxyJump

在 openssh7.5 之后（ubuntu18.04），支持 ProxyJump 语句，非常方便。windows 不支持。

假设我们登录路径是这样的：

client->jump_server->server->dev_docker

那么 client 的 `~/.ssh/config` 文件应该如下：

```
Host jump
    HostName <jump_server ip>
    Port <jump_server port>
    User <jump_server username>
    IdentityFile <jump_server id_rsa>


Host server
    HostName <server ip>
    Port <server port>
    User <server username>
    IdentityFile <server id_rsa>
    ProxyJump jump

Host dev_docker
    HostName <dev_docker ip>
    Port <dev_docker port>
    User <dev_docker username>
    IdentityFile <dev_docker id_rsa>
    ProxyJump server
```

然后在 client 中，直接使用 `ssh dev_docker` 命令，ssh 就会一步步登录过去。使用 `-v` 可以看到每一步的登录过程。

vscode 会自动读取 config 文件，就可以直接打开 docker 中的文件夹了。真的很方便。

还有两个比较实用的配置，同样是配置在客户端：

* `ServerAliveInterval 60`：每隔 60s 服务器发送一个包看客户端是否有响应。
* `ServerAliveCountMax 600`：服务器发出请求后客户端没有响应的次数达到一定值，就自动断开，正常情况下，客户端不会不响应。

这两个配置组合就可以保持 ssh 的长连接了，不用一直手动连接。