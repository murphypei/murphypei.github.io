---
title: Python拷贝虚拟环境的方法
date: 2019-02-01 09:19:44
update: 2018-12-23 09:19:44
categories: Python
tags: [Python, virtualenv, 虚拟环境拷贝]
---

Python 虚拟环境拷贝并不是仅仅的复制目录，本文用于记录自己实践的拷贝 Python 虚拟环境的方法。

<!-- more -->

Python 虚拟环境非常好用，有时候需要我们拷贝一个已经配置好的虚拟环境，网上找了一下发现全是 `pip freeze > requirements.txt`，然后 `pip install -r requirements.txt`。这种操作很常见，但是对于一些不用pip安装的包，就没办法处理了，而且安装时间也是一个问题。

### 同一个机器之间拷贝

直接使用虚拟环境 `virtualenv` 自带的工具 `virtualenv-clone` 或者 `virtualenvwrapper` 包装的工具 `cpvirtualenv`，用法很简单：

`cpvirtualenv src dest`

或者

`virtualenv-clone source target`

### 不同机器之间的拷贝

这个才是重点，因为服务器的虚拟环境安装了一些自己编译的包，需要拷贝过来用（ `pip freeze` 处理不了）。下面是步骤：

#### 直接拷贝源的 `.virtualenvs` 目录到目标机器

这一步一般是从一个 home 目录到另一个 home 目录，假设源机器是 `/src/.virtualenvs`，目标机器是 `/dest/.virtualenvs`。

这一步拷贝之后，如果你的两个 `.virtualenvs` 的路径是一样的，恭喜你，你已经完成了，如果不一样，下面就需要做一些操作。

#### 查看一下虚拟环境中的可执行文件的路径

比如有一个名为 venv 的环境，查看其可执行文件中配置的路径：`grep "/src/.virtualenvs" /path/to/venv/bin -R`。结果如下：

```
/dest/.virtualenvs/py2/bin/jupyter-notebook:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/pip2.7:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/coverage2:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-serverextension:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-kernel:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/chardetect:#!/src/.virtualenvs/py2/bin/python
/dest/.virtualenvs/py2/bin/jupyter-qtconsole:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/cythonize:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-kernelspec:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/easy_install-2.7:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/cython:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/range-detector:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/ipython:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/tqdm:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/activate.csh:setenv VIRTUAL_ENV "/src/.virtualenvs/py2"
/dest/.virtualenvs/py2/bin/jupyter-bundlerextension:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/wheel:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jsonschema:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/iptest:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/pip2:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/pbr:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/f2py:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/python-config:#!/src/.virtualenvs/py2/bin/python
/dest/.virtualenvs/py2/bin/activate:VIRTUAL_ENV="/src/.virtualenvs/py2"
/dest/.virtualenvs/py2/bin/coverage-2.7:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/ipdb:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-nbconvert:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/easy_install:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/cygdb:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-console:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-trust:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-troubleshoot:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-migrate:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/ipython2:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/pip:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/iptest2:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-run:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/coverage:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/pygmentize:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/jupyter-nbextension:#!/src/.virtualenvs/py2/bin/python2
/dest/.virtualenvs/py2/bin/activate.fish:set -gx VIRTUAL_ENV "/src/.virtualenvs/py2"
```

可以看出问题了吧？就是我们直接拷贝过来的，这些路径是没有改变的，如果 `/src/` 和 `/dest/` 一样则完全没问题，如果不一样，则我们需要把 `/src/` 调整为 `/dest/`，可以配合 `sed` 工具。

```
sed -i s/dest/src/g `grep -rl "/src/.virtualenvs" /path/to/venv/bin`
```

再用前面的命令查看就名为问题了。至此就完成了，直接可以愉快的使用了，又快又好用。
