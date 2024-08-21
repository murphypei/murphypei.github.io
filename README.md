## Hexo-blog

使用 Hexo 模板和 NexT 主题搭建的个人博客主页。

### 安装

本仓库使用的nodejs、hexo、next主题的版本都比较老，不能直接使用最新的版本部署，因此推荐使用docker。

* 编译dockerfile（注意，在当前目录下编译）。
* 运行docker，进入容器内，运行hexo命令。

> 发现docker中使用npm安装了依赖之后，运行会有问题，所以在dockerfile中注释了，可以挂载本地目录或者拷贝文件，然后进入docker容器内，手动运行`npm install .`安装依赖。

**hexo运行测试**

* `hexo clean && hexo g && hexo s`

**hexo部署**

* `hexo d`

### 常见错误记录

#### 生成错误

* `SyntaxError: ${project_dir}/node_modules/live2d-widget-model-haru/01/package.json: Unexpected end of JSON input`。
    * 使用 live2d-widget-model-haru，安装完毕后，需要将 `node_modules/live2d-widget-model-haru/package.json` 复制进 01, 02 两个子文件夹中。
* `WARN  No layout: about/index.html`
    * 子模块 NexT 主题没有拉下来，需要更新子模块：`git submodule update --init --recursive`。

#### 数学公式和 Markdown 渲染问题

* https://murphypei.github.io/blog/2019/03/hexo-render-mathjax.html
