---
title: jupyter设置多个虚拟环境的kernel
date: 2019-01-11 09:19:44
update: 2019-01-11 09:19:44
categories: Python
tags: [Python, ipython, jupyter, notebook]
---

jupyter中可以切换通过切换kernel来方便的控制python的运行环境。

<!--more-->

jupyter中可以方便的切换python的运行环境，由于我平时的python都是用virtualenvs，我以为在每个虚拟环境中直接安装jupyter就可以了，但是实际上发现jupyter只找到了系统自带的python环境....

查阅资料发现原来是需要手动注册一下虚拟环境到ipykernel中。下面就是在jupyter中配置virtualenvs的全部过程。

1. 安装虚拟环境env

    省略

2. 安装jupyter

    `sudo pip install -U jupyter`

    注意这个jupyter是安装在系统的python环境中的

2. 在虚拟环境中安装ipykernel

    切换到虚拟环境中，安装ipykernel：

    `pip install ipykernel`

3. 注册虚拟环境

    在虚拟环境中执行注册：

    `python -m ipykernel install --user --name=env`

大功告成，重启jupyter notebook就可以看到不同的kernel了。
