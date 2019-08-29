---
title: Git分支命名导致Push失败
date: 2018-09-30 16:46:46
update: 2018-09-30 16:46:46
categories: Git
tags: [Git, push, delete, branch, 分支]
---

Git中的分支命名遵循一定的规则

<!--more-->

之前一直我的Git分支命名用类似`/dev/myname`形式，然后今天往一个别人建立的repo中push的时候，直接报错了
```
remote: error: cannot lock ref 'refs/heads/dev/chaop': 'refs/heads/dev' exists; cannot create 'refs/heads/dev/myname'
To *********************
 ! [remote rejected] dev/myname -> dev/myname (failed to update ref)
error: failed to push some refs to ' *********************'
```
（***是git的repo地址）

然后查了一下，发现原来是远程repo中有一个`dev`分支，导致冲突了，原因如下：

在Git中，每个分支都会被创建一个文件，这些分支的文件在`.git/logs/refs/heads/`文件夹中。因为远程仓库中有了一个`dev`分支，所以就存在一个`.git/logs/refs/heads/dev`文件。这个时候，我的分支命是`dev/myname`，根据这个分支命名，需要在`.git/logs/refs/heads/`文件夹中创建一个名为`dev`的文件夹，并在这个文件夹中创建一个`myname`文件。这就是冲突所在了：不能同事存在一个`dev`文件和文件夹！

根据上面的问题，Git的分支命名还是有讲究的，特别是合作的时候，不然就会出现类似的冲突。