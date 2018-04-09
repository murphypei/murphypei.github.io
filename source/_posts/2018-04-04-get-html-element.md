---
layout: post
title: python简单方法获取网页页面元素内容
categories: Python
description: ""
tags: [python, urllib, request, beautifulsoup]
---

使用`urllib`和`BeautifulSoup`的组合进行简单的页面元素获取

```python
import urllib.request
from bs4 import BeautifulSoup


response = urllib.request.urlopen('http://www.mmjpg.com/')
if response:
    # 获取页面内容
    html_content = response.read().decode('utf-8')
    # 将获取到的内容转换成BeautifulSoup格式，并将html.parser作为解析器
    soup = BeautifulSoup(html_content, 'html.parser')
    # 格式化打印输出html
    print(soup.prettify())
    # 获取元素节点
    tag_elements = soup.find('div', attrs={"class": "subnav"}).find_all('a')
    # 获取连接
    hrefs = [e.get('href') for e in tag_elements]
    # 获取文本内容
    tags = [e.string for e in tag_elements]
    print(hrefs)
    print(tags)
```