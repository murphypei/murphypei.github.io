---
title: 使用 pyenv 搭建任意 python 环境
date: 2022-01-13 10:47:20
update: 2022-01-13 10:47:20
categories: [Python]
tags: [python, pyenv, virtualenv, activate]
---

开发和部署的过程中，常常遇到 python 版本和环境导致的冲突不兼容问题，pyenv 能够完美解决。

<!-- more -->

virtualenv 可以搭建虚拟且独立的 python 环境，可以使每个项目环境与其他项目独立开来，保持环境的干净，解决包冲突问题。但是这个依赖于已安装的 python 版本，相当于**同一版本的不同环境**。

pyenv 可以帮助你在一台开发机上建立多个版本的 python 环境，并提供方便的切换方法，可以搭配 virtualenv，完美解决 python 环境冲突，自由搭建任意版本的 python 环境。

### pyenv 安装

**安装 pyenv 之前建议卸载本机的 virtualenv 和 virtualenvwrapper 等相关虚拟环境**，因为我从没用过 conda， 所以不清楚 conda 是否需要卸载。

* 下载最新 pyenv 
```shell
git clone https://github.com/yyuu/pyenv.git ~/.pyenv
```

* 配置环境变量

```shell
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
```

> 用 zsh 的改为 ~/.zshrc，下同

* 添加 pyenv 初始化到你的 shell

```shell
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
```

* 重新启动你的 shell 使更改生效

```shell
exec $SHELL
source ~/.bashrc
```

### 安装某个版本的 python

首先我们可以查看一下有哪些版本的 python 可以安装

```shell
pyenv install --list
```

一般情况下，几乎所有的 python 版本都可以安装，这也是 pyenv 强大之处。

* 安装指定版本：

```shell
pyenv install -v 3.9.9
```

* 安装完成后可以查看安装情况：

```shell
pyenv versions 
```

一般输出如下：

```shell
* system (set by ~/.pyenv/version)
3.9.9
```

system 代表当前系统的 python 版本, 3.9.9 是我们用pyenv安装的, *表示当前的 python 版本， 可以看到，我们还在使用的是默认的 system 自带的 python 版本。

* 切换 python 版本

```shell
pyenv global 3.9.9
# pyenv local 3.9.9
# pyenv shell 3.9.9
```

上面三条命令都可以切换 python 版本，区别简单解释如下：

* `pyenv global` 读写 `~/.python-version` 文件，基本来说你在当前 shell 和今后打开的 shell 中，默认都是用这个版本的 python。
* `pyenv local` 读写**当前目录**的 `.python-version` 文件，相当于覆盖了 `~/.python-version` 的版本。
* `pyenv shell` 指定当前 shell 使用的 python 版本，相当于覆盖了前面两个。

此外设置 `PYENV_VERSION` 变量也可以修改 python 版本，看上去很杂很乱，但是多用几次就明白了。详细命令文档看这里：[pyenv commands](https://github.com/pyenv/pyenv/blob/master/COMMANDS.md)

* 卸载 python 版本

```shell
pyenv uninstall 3.9.9
```

### pyenv 中使用 virtualenv

pyenv virtualenv 是 pyenv 的插件，为 UNIX 系统提供 pyenv virtualenv 命令。

* 安装 pyenv-virtualenv

```shell
git clone https://github.com/yyuu/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
source ~/.bashrc
```

* 创建虚拟环境

```shell
pyenv virtualenv 3.9.9 env399
```

> 创建虚拟环境的 python 版本需要提前装好

* 激活环境

```shell
pyenv activate env399
```

切换后查看一下 python 版本：

```shell
  system
  3.9.9
  3.9.9/envs/env399
* env399 (set by PYENV_VERSION environment variable)
```

* 退出虚拟环境

```shell
pyenv deactivate
```

* 删除虚拟环境

```shell
rm -rf ~/.pyenv/versions/env399
```

### 可能遇到的问题

* 安装依赖

自己谷歌查依赖的安装，我测试没遇到过。

* activate 激活不生效

简单来说就是激活后 `pyenv versions` 显示生效了，`python version` 还是系统版本，暂时没找到具体原因，手动指定激活可以解决 `source ~/.pyenv/version/env399/bin/activate`。



