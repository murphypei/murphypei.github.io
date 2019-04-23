---
layout: post
title: 分布式爬虫：Scrapy-Redis使用
date: 2017-06-21
update: 2018-04-12
categories: Python
tags: [Python, scrapy, redis, 分布式, 爬虫]
---

个人整理的关于srapy-redis的使用教程。

<!--more-->

## 前言

Python中Scrapy可以算是很基本的爬虫框架了，我自己也用过。感觉很方便，只需要写好几个组件，配置好环境就能运行。关于Scrapy我就不介绍了，可以看文档（有中文的）。

为了提升爬虫效率主要有两种实现办法：
 
* 开启多线程来爬取
* 分布式多台机器爬取

后者从直观上看，肯定要更加高效，但是也涉及机器的利用率吧。我使用Scrapy-Redis体验了一下分布式爬虫，进行简要介绍。

## Scrapy介绍

[Scrapy中文文档](http://scrapy-chs.readthedocs.io/zh_CN/1.0/)

安装好相关Python库之后，直接可以执行`scrapy startproject tutorial`来创建一个scrapy工程，会自动在当前目录下创建一个文件夹，结构如下：

```
tutorial/
    scrapy.cfg

    tutorial/
        __init__.py

        items.py

        pipelines.py

        settings.py

        spiders/
            __init__.py
            ...
```
* `scrapy.cfg` 是爬虫的信息，主要是爬虫的配置文件位置和项目名称。

* `items.py` 是要爬取的信息的结构。比如我要爬一张图片，需要知道图片的地址、图片名称等等，这些结构。利用Field来创建相应的数据结构类。一般还包括一个ItemLoader类，用于将网页上的数据装载到你创建的数据结构类中，生成一个实例对象。

* `pipelines.py` 是对所爬数据的实例对象进行处理操作。比如对于一个图片item，我可以利用其数据结构中的图片地址，将其下载下来，我也可以将图片地址、图片名称、大小什么的组成关系型数据结构，存放在数据库中。

* `settings.py` 是整个爬虫工程的配置文件，包括爬虫的中间件、定时、调度器等等，这个需要结合自身需求，慢慢摸索。

* `spiders` 目录中存在实际的爬虫程序，主要是对页面的解析操作。

Scrapy中有连个基本的爬虫类，Spider和CrawlerSpider，前者利用parse函数定义对于页面的解析操作，一般需要在其中包含提取url并进行下一步的操作等等。后者适用于全站爬取，通过ruler定义自动提取页面链接的规则，并设置对于包含所要提取数据的页面的操作。CrawlerSpider中自动写好了parse函数，因此不能覆盖掉这个函数。


## Scrapy-Redis介绍

Scrapy-Redis是一个基于Redis的Scrapy分布式组件。它利用Redis对用于爬取的请求(Requests)进行存储和调度(Schedule)，并对爬取产生的项目(items)存储以供后续处理使用。scrapy-redi重写了scrapy一些比较关键的代码，将scrapy变成一个可以在多个主机上同时运行的分布式爬虫。

官方的github地址如下：[scrapy-redis](https://github.com/rmax/scrapy-redis)。下面是我结合网上的一些博客，对于源码和原理上的一些总结。

* `connect.py` 进行Redis数据库连接和操作
    
    在这个文件中引入了redis模块，这个是redis-Python库的接口，用于通过Python访问redis数据库，可见，这个文件主要是实现连接redis数据库的功能（返回的是redis库的Redis对象或者StrictRedis对象，这俩都是可以直接用来进行数据操作的对象）。这些连接接口在其他文件中经常被用到。其中，我们可以看到，要想连接到redis数据库，和其他数据库差不多，需要一个ip地址、端口号、用户名密码（可选）和一个整形的数据库编号，同时我们还可以在scrapy工程的setting文件中配置套接字的超时时间、等待时间等。

* `dupefilters.py` 进行request的判重功能

    这个文件看起来比较复杂，重写了scrapy本身已经实现的request判重功能。因为本身scrapy单机跑的话，只需要读取内存中的request队列或者持久化的request队列（scrapy默认的持久化似乎是json格式的文件，不是数据库）就能判断这次要发出的request url是否已经请求过或者正在调度（本地读就行了）。而分布式跑的话，就需要各个主机上的scheduler都连接同一个数据库的同一个request池来判断这次的请求是否是重复的了。 

    在这个文件中，通过继承BaseDupeFilter重写他的方法，实现了基于redis的判重。根据源代码来看，scrapy-redis使用了scrapy本身的一个fingerprint接request_fingerprint，这个接口很有趣，根据scrapy文档所说，他通过hash来判断两个url是否相同（相同的url会生成相同的hash结果），但是当两个url的地址相同，get型参数相同但是顺序不同时，也会生成相同的hash结果（这个真的比较神奇。。。）所以scrapy-redis依旧使用url的fingerprint来判断request请求是否已经出现过。这个类通过连接redis，使用一个key来向redis的一个set中插入fingerprint（这个key对于同一种spider是相同的，redis是一个key-value的数据库，如果key是相同的，访问到的值就是相同的，这里使用spider名字+DupeFilter的key就是为了在不同主机上的不同爬虫实例，只要属于同一种spider，就会访问到同一个set，而这个set就是他们的url判重池），如果返回值为0，说明该set中该fingerprint已经存在（因为集合是没有重复值的），则返回False，如果返回值为1，说明添加了一个fingerprint到set中，则说明这个request没有重复，于是返回True，还顺便把新fingerprint加入到数据库中了。

    DupeFilter判重会在scheduler类中用到，每一个request在进入调度之前都要进行判重，如果重复就不需要参加调度，直接舍弃就好了，不然就是白白浪费资源。

* `picklecompat.py` 进行序列化操作

    这里实现了loads和dumps两个函数，其实就是实现了一个serializer，因为redis数据库不能存储复杂对象（value部分只能是字符串，字符串列表，字符串集合和hash，key部分只能是字符串），所以我们存啥都要先串行化成文本才行。这里使用的就是Python的pickle模块，一个兼容py2和py3的串行化工具。这个serializer主要用于一会的scheduler存reuqest对象，至于为什么不实用json格式，我也不是很懂，item pipeline的串行化默认用的就是json。

* `pipeline.py` 对所爬取的item进行Redis操作

    pipeline文件实现了一个item pipieline类，和scrapy的item pipeline是同一个对象，通过从settings中拿到我们配置的REDIS_ITEMS_KEY作为key，把item串行化之后存入redis数据库对应的value中（这个value可以看出出是个list，我们的每个item是这个list中的一个结点），这个pipeline把提取出的item存起来，主要是为了方便我们延后处理数据。

* `queue.py`
    
    该文件实现了几个容器类，可以看这些容器和redis交互频繁，同时使用了我们上边picklecompat中定义的serializer。这个文件实现的几个容器大体相同，只不过一个是队列，一个是栈，一个是优先级队列，这三个容器到时候会被scheduler对象实例化，来实现request的调度。比如我们使用SpiderQueue最为调度队列的类型，到时候request的调度方法就是先进先出，而实用SpiderStack就是先进后出了。 

    我们可以仔细看看SpiderQueue的实现，他的push函数就和其他容器的一样，只不过push进去的request请求先被scrapy的接口request_to_dict变成了一个dict对象（因为request对象实在是比较复杂，有方法有属性不好串行化），之后使用picklecompat中的serializer串行化为字符串，然后使用一个特定的key存入redis中（该key在同一种spider中是相同的）。而调用pop时，其实就是从redis用那个特定的key去读其值（一个list），从list中读取最早进去的那个，于是就先进先出了。 
    
    这些容器类都会作为scheduler调度request的容器，scheduler在每个主机上都会实例化一个，并且和spider一一对应，所以分布式运行时会有一个spider的多个实例和一个scheduler的多个实例存在于不同的主机上，但是，因为scheduler都是用相同的容器，而这些容器都连接同一个redis服务器，又都使用spider名加queue来作为key读写数据，所以不同主机上的不同爬虫实例公用一个request调度池，实现了分布式爬虫之间的统一调度。

* `scheduler.py`

    这个文件重写了scheduler类，用来代替scrapy.core.scheduler的原有调度器。其实对原有调度器的逻辑没有很大的改变，主要是使用了redis作为数据存储的媒介，以达到各个爬虫之间的统一调度。 
    
    scheduler负责调度各个spider的request请求，scheduler初始化时，通过settings文件读取queue和dupefilters的类型（一般就用上边默认的），配置queue和dupefilters使用的key（一般就是spider name加上queue或者dupefilters，这样对于同一种spider的不同实例，就会使用相同的数据块了）。每当一个request要被调度时，enqueue_request被调用，scheduler使用dupefilters来判断这个url是否重复，如果不重复，就添加到queue的容器中（先进先出，先进后出和优先级都可以，可以在settings中配置）。当调度完成时，next_request被调用，scheduler就通过queue容器的接口，取出一个request，把他发送给相应的spider，让spider进行爬取工作。

* `spider.py`

    spider的改动也不是很大，主要是通过connect接口，给spider绑定了spider_idle信号，spider初始化时，通过setup_redis函数初始化好和redis的连接，之后通过next_requests函数从redis中取出strat url，使用的key是settings中REDIS_START_URLS_AS_SET定义的（注意了这里的初始化url池和我们上边的queue的url池不是一个东西，queue的池是用于调度的，初始化url池是存放入口url的，他们都存在redis中，但是使用不同的key来区分，就当成是不同的表吧），spider使用少量的start url，可以发展出很多新的url，这些url会进入scheduler进行判重和调度。直到spider跑到调度池内没有url的时候，会触发spider_idle信号，从而触发spider的next_requests函数，再次从redis的start url池中读取一些url。

最后总结一下scrapy-redis的总体思路：这个工程通过重写scheduler和spider类，实现了调度、spider启动和redis的交互。实现新的dupefilter和queue类，达到了判重和调度容器和redis的交互，因为每个主机上的爬虫进程都访问同一个redis数据库，所以调度和判重都统一进行统一管理，达到了分布式爬虫的目的。 

当spider被初始化时，同时会初始化一个对应的scheduler对象，这个调度器对象通过读取settings，配置好自己的调度容器queue和判重工具dupefilter。每当一个spider产出一个request的时候，scrapy内核会把这个reuqest递交给这个spider对应的scheduler对象进行调度，scheduler对象通过访问redis对request进行判重，如果不重复就把他添加进redis中的调度池。当调度条件满足时，scheduler对象就从redis的调度池中取出一个request发送给spider，让他爬取。当spider爬取的所有暂时可用url之后，scheduler发现这个spider对应的redis的调度池空了，于是触发信号spider_idle，spider收到这个信号之后，直接连接redis读取strart url池，拿去新的一批url入口，然后再次重复上边的工作。

## Scrapy-Redis使用

这个地方，我强烈建议，不要找网上的教程看了，**就看作者给的三个[例子](https://github.com/rmax/scrapy-redis/tree/master/example-project/example)**，对于中文的博客，实在写的不怎么样，误导性很强。结合前面对源码和原理的分析，搞清楚作者给的例子，就能明白基本的爬虫原理了。

对于布置分布式爬虫，也很简单。不要一上来就分什么主从服务器什么的，就记住一点，需要有一台机器装有Redis数据库，并且所有其余的机器都要能够访问这个数据库。然后在你想跑爬虫程序的机器上，都拷贝一份代码，包括装有Redis数据库的也可以，然后运行就完事了。对于主从服务器什么的而言，一般是为了性能上的考虑。

**我的参考项目**： https://github.com/ChaoPei/meizitu_distribute_crawler

### 参考

* [Redis命令参考](http://doc.redisfans.com/)
* [xpath语法](http://www.w3school.com.cn/xpath/xpath_syntax.asp)
* [使用scrapy-redis构建简单的分布式爬虫](http://blog.csdn.net/howtogetout/article/details/51633814)
* [scrapy-redis分布式爬虫原理分析](http://www.codexiu.cn/Python/blog/24719/)