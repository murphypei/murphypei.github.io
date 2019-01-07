---
title: jupyter远程配置的ip问题
date: 2018-12-23 09:19:44
update: 2018-12-23 09:19:44
categories: Python
tags: [Python, ipython, jupyter, notebook]
---

jupyter远程访问需要配置ip地址，配置ip地址过程中遇到了一个问题

<!--more-->

jupyter十分好用，如果想在服务器上运行jupyter，然后本地进行访问，需要进行一些配置，官方配置教程如下：[Running a public notebook server](https://jupyter-notebook.readthedocs.io/en/stable/public_server.html)

按照教程配置就好了，我大概翻译一下。

1. 首先需要安装jupyter

    `pip install jupyter`

    * 安装过程中如果遇到依赖，版本等问题，自己解决。

2. 生成jupyter配置文件

    `jupyter notebook --generat-config`

3. 生成一个访问密码

    `jupyter notebook password`

    * 自己输入密码，输入两次

4. 修改jupyter配置文件

    * 打开json配置文件，一般是`~/.jupyter/jupyter_notebook_config.json`，复制其中设置的密码的哈希密钥，从`sha1`开始复制
    * 打开py配置文件，一般是`~/.jupyter/jupyter_notebook_config.py`，修改其中的几项：

    ```
    c.NotebookApp.ip='*'
    c.NotebookApp.password = u'sha1:xxxxxx'
    c.NotebookApp.open_browser = False
    c.NotebookApp.port = 8888 
    ```

坑就出在这里，如果`ip='*'`，启动jupyter notebook就会报错，错误原因是ip地址错误，我看网上一堆教程，包括官网都是这么设置，我觉得原因是python执行不认这个配置吧。`ip='*'`的意思是允许任意的电脑访问这个notebook，当然了，需要密码。我尝试将其改为`ip='0.0.0.0'`，就可以了。果然，计算机编程原理都是类似的。





