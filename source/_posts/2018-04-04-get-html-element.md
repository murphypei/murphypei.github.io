---
layout: post
title: Python简单方法获取网页页面元素内容
date: 2018-04-04
update: 2018-04-12
categories: Python
tags: [Python, urllib, request, beautifulsoup]
---

使用 Python 的 `urllib` 和 `BeautifulSoup` 库进行简单的页面元素提取测试

<!--more-->

```Python
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