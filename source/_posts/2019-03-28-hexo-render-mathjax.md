---
title: 解决hexo-next主题和mathjax下划线冲突问题
date: 2019-03-28 15:47:30
update: 2019-03-28 15:47:30
categories: [Hexo]
tags: [hexo, next, mathjax, kramed, 下划线]
---

mathjax中下划线是下标符号，而markdown中是斜体符号，所以会出现冲突。

<!-- more -->

解决办法就是首先替换公式渲染引擎：

```
npm uninstall hexo-renderer-marked --save
npm install hexo-renderer-kramed --save
```

之所以不用`pandoc`是为了习惯吧，但是`hexo-renderer-kramed`只能够解决单行的渲染问题，行内的仍然会出问题，需要手工矫正一下：

修改`node_modules\kramed\lib\rules\inline.js`：

修改第11行
```
// escape: /^\\([\\`*{}\[\]()#$+\-.!_>])/,
escape: /^\\([`*\[\]()#$+\-.!_>])/,
```

修改第20行：
```
// em: /^\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)/,
em: /^\*((?:\*\*|[\s\S])+?)\*(?!\*)/,
```

重启hexo
```
hexo clean 
hexo g
```

本文参考：

* http://xiaofeima1990.github.io/2018/05/18/solve-mathjax-display%20in%20next/
