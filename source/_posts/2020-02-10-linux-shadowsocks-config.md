---
title: Linux下shadowsocks使用配置
date: 2020-02-10 11:43:08
update: 2020-02-10 11:43:08
categories: Linux
tags: [Linux, shadowsocks]
---

记录 Linux 使用 shadowsocks 的方法。

<!-- more -->

#### 安装

```bash
pip install shadowsocks
```

#### 配置

创建配置文件： `/etc/shadowsocks.json`

内容如下：

```json
{
    "server":"1.2.3.4", // 服务器IP
    "server_port":8888, // 对外提供服务的端口
    "local_port":1080,
    "password":"your password",
    "timeout":600,
    "method":"aes-256-cfb",
    "fast-open": true
}
```

#### 作为服务器

前台启动

```
ssserver -c /etc/shadowsocks.json
```

后台运行

```
ssserver -c /etc/shadowsocks.json -d start # 启动
ssserver -c /etc/shadowsocks.json -d stop # 停止
```

#### 作为客户端

前台启动

```
sslocal -c /etc/shadowsocks.json
```

后台运行

```
sslocal -c /etc/shadowsocks.json -d start # 启动
sslocal -c /etc/shadowsocks.json -d stop # 停止
```