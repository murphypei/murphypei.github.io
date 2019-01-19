---
title: pip升级之后出现的问题
date: 2018-11-19 10:47:46
update: 2018-11-19 16:46:46
categories: Python
tags: [Python, pip]
---

pip升级之后出现的错误

<!--more-->

今天在pip升级之后，出现了一个问题，执行pip命令报错：
```
/usr/bin/pip: No such file or directory
```

于是直接看看pip装到哪了：
```
$ which pip
/usr/local/bin/pip
```

这就很奇怪了，明明pip命令指向的是`/usr/local/bin/pip`的可执行文件，报错的却是`/usr/bin/pip`，这时候就需要对命令进行深究了。

### type用法

Linux type命令被用于判断另外一个命令是否是内置命令以及显示其执行路径。（当然还有更多用法）
```
$ type pip
pip is hashed (/usr/bin/pip)
```

可以看到，pip执行命令的缓存路径是`/usr/bin/pip`，而`which`表明实际安装的路径是`/usr/local/bin/pip`，因此就报错了。解决这个问题也很简单，使用hash命令。

### hash用法

hash命令的作用是在环境变量PATH中搜索命令name的完整路径并记住它，这样以后再次执行相同的命令时，就不必搜索其完整路径了，而且shell每次执行环境变量PATH中的一个命令时，hash都会记住它。我们执行pip出错就是因为缓存的pip路径不是当前安装的路径。因此清空当前的hash列表就行了。
```
$ hash -r
```

问题解决。