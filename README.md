## Hexo-blog

使用 Hexo 模板和 NexT 主题搭建的个人博客主页。

### 安装

`git clone --recursive https://github.com/murphypei/hexo-blog` 

* 安装 Nodejs
    * 下载(Nodejs)[https://nodejs.org/en/download/]库包并解压缩
    * 然后添加`${node-path}/bin`到`$PATH`中
* 配置 npm 淘宝库
    * `npm config set registry https://registry.npm.taobao.org`
    * 验证: `npm config get registry`
* 安装插件
    * `npm install`

### 运行

* `hexo clean && hexo g && hexo s`

### 部署

* `hexo d`

### 常见错误记录

hexo g

* `SyntaxError: ${project_dir}/node_modules/live2d-widget-model-haru/01/package.json: Unexpected end of JSON input`。
    * 使用 live2d-widget-model-haru，安装完毕后，需要将 `node_modules/live2d-widget-model-haru/package.json` 复制进 01, 02 两个子文件夹中。
* `WARN  No layout: about/index.html`
    * 子模块 NexT 主题没有拉下来，需要更新子模块：`git submodule update --init --recursive`。
