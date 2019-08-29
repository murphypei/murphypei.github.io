---
title: jupyter 设置多个虚拟环境的 kernel
date: 2019-01-11 09:19:44
update: 2019-01-11 09:19:44
categories: Python
tags: [Python, iPython, jupyter, notebook]
---

jupyter 中可以切换通过切换 kernel 来方便的控制 Python 的运行环境。

<!--more-->

jupyter 中可以方便的切换 Python 的运行环境，由于我平时的 Python 都是用 virtualenvs，我以为在每个虚拟环境中直接安装 jupyter 就可以了，但是实际上发现 jupyter 只找到了系统自带的 Python 环境....

查阅资料发现原来是需要手动注册一下虚拟环境到 ipykernel 中。下面就是在 jupyter 中配置 virtualenvs 的全部过程。

1. 安装虚拟环境 env

    省略

2. 安装 jupyter

    `sudo pip install -U jupyter`

    注意这个 jupyter 是安装在系统的 Python 环境中的

2. 在虚拟环境中安装 ipykernel

    切换到虚拟环境中，安装 ipykernel：

    `pip install ipykernel`

3. 注册虚拟环境

    在虚拟环境中执行注册：

    `python -m ipykernel install --user --name=env`

大功告成，重启 jupyter notebook 就可以看到不同的 kernel 了。
