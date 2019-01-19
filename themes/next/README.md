## Hexo-NexT

个人github主页使用的订制NexT主题，基于NexT v6.1添加和修改部分功能

### 相关框架版本信息

```
hexo-cli: 1.1.0
os: Windows_NT 6.1.7601 win32 x64
http_parser: 2.7.0
node: 8.4.0
v8: 6.0.286.52
uv: 1.13.1
zlib: 1.2.11
ares: 1.10.1-DEV
modules: 57
nghttp2: 1.22.0
openssl: 1.0.2l
icu: 59.1
unicode: 9.0
cldr: 31.0.1
tz: 2017b
```

### NexT订制

* 使用`hexo-generator-feed`实现RSS订阅

  * 在站点根目录下执行`npm install --save hexo-generator-feed`

* 添加live2D装饰

  * 在站根目录下执行`npm install hexo-helper-live2d --save`
  * 在站点配置文件中添加：
  
  ```
  live2d:
    position: left
    bottom: -30
    mobileShow: false  # 手机端不显示
  ```

* 添加百度和谷歌站点收录

  * 在站点根目录下执行：

  ```
  npm install hexo-generator-sitemap --save        
  npm install hexo-generator-baidu-sitemap --save  
  ```

  * 在站点配置文件中添加：
  
  ```
  sitemap:
    path: sitemap.xml
  baidusitemap:
    path: baidusitemap.xml
  ```
  
  * 打开next的配置文件中的百度和谷歌验证

* 为https站点添加百度分享：

  * https://www.hrwhisper.me/baidu-share-not-support-https-solution/


* 其余包括：替换标签图标、设置圆形旋转头像等等
