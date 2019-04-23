---
title: 在 virtualenv 中安装 dmlc-tensorboard 的坑
date: 2019-03-28 11:17:56
update: 2019-03-28 11:17:56
categories: [Linux]
tags: [dmlc, tensorboard, Python, virtualenv]
mathjax: false
---

在 virtualenv 中安装 dmlc-tensorboard 的体验十分不友好，安装过程坑太多了，总结一下。

<!-- more -->

## 清除安装环境

这一步是**非常必要的**，因为 dmlc-tensorboard 的安装过程中涉及 bazel 以及 tensorflow 的安装，因此保证一个干净的环境是非常必要的，具体需要清除的是：

* `pip uninstall dmlc-tensorboard`
    * 这一步是删除现有的可能已经安装了的 dmlc-tensorboard
* `rm -rf ~/.cache/bazel`
    * 删除 bazel 的缓存，也许你的 bazel 缓存不在这个地方，那就删除 bazel 缓存的文件夹所在位置
* `rm -rf ~/.bazel ~/bin/bazel`
    * 是的，你没看错，为了万无一失，连 bazel 也删除了，如果你的 bazel 不是用户安装，也就是不在这个位置，那就去相应的位置删除
* `rm -rf dmlc-tensorboard`
    * 为了防止以前编译的 tensorflow 有问题，你最好连下载的 dmlc-tensorboard 都删除了
    * 如果实在不想删除源码，建议至少清除恢复，特别是不同版本 Python 编译的时候，更是必须的
        * `git reset --hard HEAD && git clean -fd`

## 安装准备

* 安装 bazel
    * `chmod +x bazel-0.6.1-installer-linux-x86_64.sh && ./bazel-0.6.1-installer-linux-x86_64.sh --user`
    * 建议 0.6.1 这个版本，我实测没问题，直接下载 bazel-0.6.1-installer-linux-x86_64.sh 这个文件，执行上述命令即可，使用用户安装
* 安装 Python 依赖
    * `sudo apt install python2-dev && sudo apt install python3-dev`
    * 这一步在很多 ubuntu 系统是必须的，特别是 Python3 环境，因为没有安装 Python3-dev，因此编译 tensorflow 的时候会报 `python.h` 找不到的错误，网上解释了一堆，其实都是因为这个开发包没安装而已。
* 设置环境变量
    * `export PYTHON_BIN_PATH=~/.virtualenv/py3/bin/python`
    * `export PYTHON_LIB_PATH=~/.virtualenvs/py3/lib/python3.5/site-packages/`
    * 根据你自己的虚拟环境位置设置
* 下载 dmlc-tensorboard
    * `git clone --recursive https://github.com/dmlc/tensorboard`
* 安装 protobuf3
    * 自行安装，然后 `protoc --version` 检查版本没问题就行

## 安装

* `cd tensorboard && sh installer.sh`
    * **所有选项全部选 `N`，最后一个默认**

### 注意事项

* Python2 和 Python3 的 tensorboard 需要分开（最好这样），或者每次都要清除 tensorboard 文件夹，因为编译出来的安装文件不一样
* virtualenv 有一个 bug，安装完之后需要修改 tensorboard 的可执行文件 `~/.virtualenvs/py3/bin/tensorboard` 中的 `FindModuleSpace` 函数

```Python
 # Find the runfiles tree
 def FindModuleSpace():
   # Follow symlinks, looking for my module space
   stub_filename = os.path.abspath(sys.argv[0])
   while True:
     # Found it?
     module_space = stub_filename + '.runfiles'
     if os.path.isdir(module_space):
       break
     #package_path = site.getsitepackages()
     # In case this instance is a string
     #if not isinstance(package_path, list):
     #  package_path= [package_path]
     #user_path = site.getusersitepackages()
     #if not isinstance(user_path, list):
     #  user_path = [user_path]
     #package_path.extend(user_path)
     if hasattr(site, 'getsitepackages'):
       sitepackages = site.getsitepackages()
     else:
       from distutils.sysconfig import get_python_lib
       sitepackages = [get_python_lib()]
     for mod in sitepackages:
       module_space = mod + '/tensorboard/tensorboard' + '.runfiles'
       if os.path.isdir(module_space):
         return module_space
 
     runfiles_pattern = "(.*\.runfiles)/.*"
     if IsWindows():
       runfiles_pattern = "(.*\.runfiles)\\.*"
     matchobj = re.match(runfiles_pattern, os.path.abspath(sys.argv[0]))
     if matchobj:
       module_space = matchobj.group(1)
       break
 
     raise AssertionError('Cannot find .runfiles directory for %s' %
                          sys.argv[0])
   return module_space
```