---
title: Ubuntu 启动过程中各配置脚本执行顺序
date: 2020-02-10 10:58:25
update: 2020-02-10 10:58:25
categories: Linux
tags: [Ubuntu， Linux， bashrc， profile， bash_profile]
---

登录 Linux 时，会有 `/etc/profile`、`~/.bash_profile`、`~/.bashrc`等相关配置文件依次启动，本文以 Ubuntu 为例说明。

<!-- more -->

对于 Ubuntu 而言，系统登录时会读取 `/etc/profile` 的内容。

在 `/etc/profile` 文件中会启动 `/etc/bash.bashrc`，然后遍历 `/etc/profile.d` 文件夹，启动里面的每一个 sh 文件。

然后执行 `~/.bash_profile` 或者 `~/.bash_login` 或者 `~/.profile` 中的一个，他们的执行优先级为 bash_profile>bash_login>profile。

当我们在终端打开一个 shell（包括打开一个新终端和在终端上输入bash），都会重新读取和 `~/.bashrc` 文件里面的内容。

使用 login 和 non login 术语来说，就是使用 login 方式是会读取 `/etc/profile` 和 `~/.profile` 文件。使用 non login 方式的话，会读取 `/etc/bash.bashrc` 和 `~/.bashrc` 文件的内容。也就是说 `/etc/profile` 和 `~/.profile` 文件是在 login 时才会读取。所以，在不使用 su 命令的情况下，只有在 Linux 启动登录的时候才会被读取（这也就导致了有些软件安装后，要重启才能生效）。

> login 模式是指用户通过 /bin/login 登录进系统然后启动 shell，而 non login 模式是指由某些程序启动的 shell，比如 /bin/bash。

在退出登录时会执行 `~/.bash_logout`。

因此各脚本执行顺序为：`/etc/profile` -> (`~/.bash_profile` | `~/.bash_login` | `~/.profile`) -> `~/.bashrc` -> `~/.bash_logout`。

关于各个文件的作用域，在网上找到了以下说明：

* `/etc/profile`： 此文件为系统的每个用户设置环境信息，当用户第一次登录时，该文件被执行，**该文件仅仅执行一次**。并从 `/etc/profile.d` 目录的配置文件中搜集 shell 的设置。
* `/etc/bash.bashrc`：为每一个运行 bash shell 的用户执行此文件.当 bash shell 被打开时，该文件被读取。
* `~/.bash_profile`：每个用户都可使用该文件输入专用于自己使用的 shell 信息，当用户登录时，**该文件仅仅执行一次**。默认情况下，他设置一些环境变量，执行用户的 .bashrc 文件。
* `~/.bashrc`：该文件包含专用于你的 bash shell 的 bash 信息，当登录时以及每次打开新的 shell 时，该该文件被读取。
* `~/.bash_logout`：当每次退出系统(退出bash shell)时，执行该文件。
