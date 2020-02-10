## Hexo-blog

使用 Hexo 模板和 NexT 主题搭建的个人博客主页。

`git clone --recursive https://github.com/murphypei/hexo-blog` && `npm install`

### 常见错误记录

hexo g

* `SyntaxError: ***/hexo-blog/node_modules/live2d-widget-model-haru/01/package.json: Unexpected end of JSON input`。
    * 使用 live2d-widget-model-haru，安装完毕后，需要将 `node_modules/live2d-widget-model-haru/package.json` 复制进 01, 02 两个子文件夹中。
* `WARN  No layout: about/index.html`
    * 子模块 NexT 主题没有拉下来，需要更新子模块：`git submodule update --init --recursive`。
