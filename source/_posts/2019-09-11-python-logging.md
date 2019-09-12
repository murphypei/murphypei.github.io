---
title: Python 日志库 logging 总结
date: 2019-09-11 14:45:42
update: 2019-09-11 14:45:42
categories: Python 
tags: [python, logging, handler, logger]
---

标准日志库 logging 即使不是 Python 中最好的日志库，也是使用最多的日志库了，我个人非常喜欢。本文较为全面的总结了 logging 库的知识点。

<!--more-->

### logging 介绍

#### 日志级别

Python 标准库 logging 用作记录日志，默认分为六种日志级别（括号为级别对应的数值），NOTSET（0）、DEBUG（10）、INFO（20）、WARNING（30）、ERROR（40）、CRITICAL（50）。我们自定义日志级别时注意不要和默认的日志级别数值相同，logging 执行时输出大于等于设置的日志级别的日志信息，如设置日志级别是 INFO，则 INFO、WARNING、ERROR、CRITICAL 级别的日志都会输出。

#### 工作流程

官方的 logging 模块工作流程图如下：

![logging 工作流程](/images/posts/python/python-logging-flow.png)

从下图中我们可以看出看到这几种 Python 类型，Logger、LogRecord、Filter、Handler、Formatter。它们的作用分别为：

* Logger：日志，暴露函数给应用程序，基于日志记录器和过滤器级别决定哪些日志有效。
* LogRecord ：日志记录器，将日志传到相应的处理器处理。
* Handler ：处理器, 将(日志记录器产生的)日志记录发送至合适的目的地。
* Filter ：过滤器, 提供了更好的粒度控制,它可以决定输出哪些日志记录。
* Formatter：格式化器, 指明了最终输出中日志记录的布局。

logging 的整个工作流程：

1. 判断 Logger 对象对于设置的级别是否可用，如果可用，则往下执行，否则，流程结束。
2. 创建 LogRecord 对象，如果注册到 Logger 对象中的 Filter 对象过滤后返回 False，则不记录日志，流程结束，否则，则向下执行。
3. LogRecord 对象将 Handler 对象传入当前的 Logger 对象，（图中的子流程）如果 Handler 对象的日志级别大于设置的日志级别，再判断注册到 Handler 对象中的 Filter 对象过滤后是否返回 True 而放行输出日志信息，否则不放行，流程结束。
4. 如果传入的 Handler 大于 Logger 中设置的级别，也即 Handler 有效，则往下执行，否则，流程结束。
5. 判断这个 Logger 对象是否还有父 Logger 对象，如果没有（代表当前 Logger 对象是最顶层的 Logger 对象 root Logger），流程结束。否则将 Logger 对象设置为它的父 Logger 对象，重复上面的 3、4 两步，输出父类 Logger 对象中的日志输出，直到是 root Logger 为止。

#### 输出格式

日志输出格式可以自定义，默认的比较简单： 

```python
# 日志级别:日志记录名称:日志消息内容
WARNING:ROOT:MESSAGE
```

### loggging 使用

下面重点说说 logging 的使用，这也是大家最关心的。

#### 基本使用

首先是基本使用，我所认为的基本使用就是我这个 Python 文件临时要记录一下，就这么简单。示例如下：

```python
import logging

logging.basicConfig()
logging.debug('This is a debug message')
logging.info('This is an info message')
logging.warning('This is a warning message')
logging.error('This is an error message')
logging.critical('This is a critical message')
```

输出结果

```python
WARNING:root:This is a warning message
ERROR:root:This is an error message
CRITICAL:root:This is a critical message
```

可以看到，**默认打印的日志级别是 WARNING，不输出到文件，格式默认**。

当然，如果我们不懒，在 `basicConfig` 中传入一些参数就可以定制一下了：

```python
import logging

logging.basicConfig(filename="test.log",
                    filemode="w",
                    format="%(asctime)s %(name)s:%(levelname)s:%(message)s",
                    datefmt="%d-%M-%Y %H:%M:%S",
                    level=logging.DEBUG)

logging.debug('This is a debug message')
logging.info('This is an info message')
logging.warning('This is a warning message')
logging.error('This is an error message')
logging.critical('This is a critical message')
```

运行完毕，我们就可以在 test.log 中看到如下内容了：

``` python
13-10-18 21:10:32 root:DEBUG:This is a debug message
13-10-18 21:10:32 root:INFO:This is an info message
13-10-18 21:10:32 root:WARNING:This is a warning message
13-10-18 21:10:32 root:ERROR:This is an error message
13-10-18 21:10:32 root:CRITICAL:This is a critical message
```

> 注意，此时输出到文件中，因此屏幕是不会打印任何内容的。

`basicConfig` 的参数如下：

| 参数名称 | 参数描述                                                     |
| :---: | :---: |
| filename | 日志输出到文件的文件名                                       |
| filemode | 文件模式，r[+]、w[+]、a[+]                                   |
| format   | 日志输出的格式                                               |
| datefat  | 日志附带日期时间的格式                                       |
| style    | 格式占位符，默认为 "%" 和 “{}”                               |
| level    | 设置日志输出级别                                             |
| stream   | 定义输出流，用来初始化 StreamHandler 对象，不能 filename 参数一起使用，否则会 ValueError 异常 |
| handles  | 定义处理器，用来创建 Handler 对象，不能和 filename 、stream 参数一起使用，否则也会抛出 ValueError 异常 |

这里有一个需要注意的地方，当发生异常时，直接使用无参数的 `debug()`、`info()`、`warning()`、`error()`、`critical()` 方法并不能记录异常信息，需要设置 `exc_info` 参数为 `True` 才可以，或者使用 `exception()` 方法，还可以使用 `log()` 方法，但还要设置日志级别和 `exc_info` 参数。示例如下：

```python
import logging

logging.basicConfig(filename="test.log",
                    filemode="w",
                    format="%(asctime)s %(name)s:%(levelname)s:%(message)s",
                    datefmt="%d-%M-%Y %H:%M:%S",
                    level=logging.DEBUG)
a = 5
b = 0
try:
    c = a / b
except Exception as e:
    # 下面三种方式三选一，推荐使用第一种
    logging.exception("Exception occurred")
    logging.error("Exception occurred", exc_info=True)
    logging.log(level=logging.DEBUG, msg="Exception occurred", exc_info=True)
```

#### 自定义 logger

以上的使用肯定不能满足大型项目的日志记录需求，因此就来到了喜闻乐见的自定义阶段了。。

首先需要明确一个比较重要的知识点：**一个系统只有一个 Logger 对象**，并且该对象不能被直接实例化，没错，这里用到了单例模式，获取 Logger 对象的方法为 `getLogger`。

> 这里的单例模式并不是说只有一个 Logger 对象，而是指**整个系统只有一个 root Logger 对象**，Logger 对象在执行 `info()`、`error()` 等方法时实际上调用都是 root Logger 对象对应的 `info()`、`error()` 等方法。

以上这句话需要深刻理解，因为在大型项目中，有很多文件，我们可以在每个文件中调用 `getLogger()` 来获取一个当前文件的 logger，存在以下情况：

* 假如 `getLogger()` 不传入任何参数，则不同文件获取的都是 root Logger，因此对这些 Logger 对象的操作都将影响其他文件的输入，比如我在 A 文件中对 logger 添加了一个 `logging.StreamHandler()`，同时在 B 文件中也添加了一个，则最后打印出来的每条日志都有两行一样的，因为处理了两次。
* 假如我们在不同文件中调用 `getLogger()` 传入不同的名字，比如当前文件的模块名字，那么得到的 Logger 对象也是不同的，因此不同的 Logger 对象可以添加不同的 hanlder 来控制当前文件中日志的输出。
* 以上两种方式实际输出都是由 root Logger 作为代理来调用的，因此实际输出操作是 root Logger，但是我们可以根据第二条来实现同一项目不同文件不同输出的控制，也可以根据第一条实现统一的输出控制。在打印出来的日志示例名称（默认的第二列）中可以看到 Logger 对象的名字（默认 root）。

每个 Logger 对象都可以设置一个名字，如果想区别不同文件的 logger，可以设置 `logger = logging.getLogger(__name__)`，`__name__` 是 Python 中的一个特殊内置变量，他代表当前模块的名称（默认为 `__main__`）。Logger 对象的 `name` 为建议使用使用以点号作为分隔符的命名空间等级制度。

Logger 对象可以设置多个 Handler 对象和 Filter 对象，Handler 对象又可以设置 Formatter 对象。Formatter 对象用来设置具体的输出格式，常用变量格式如下表所示，所有可以参数见官方文档：

|    变量     |      格式       |                           变量描述                           |
| :---------: | :-------------: | :----------------------------------------------------------: |
|   asctime   |   %(asctime)s   | 将日志的时间构造成可读的形式，默认情况下是精确到毫秒，如 2018-10-13 23:24:57,832，可以额外指定 datefmt 参数来指定该变量的格式 |
|    name     |     %(name)     |                        日志对象的名称                        |
|  filename   |  %(filename)s   |                      不包含路径的文件名                      |
|  pathname   |  %(pathname)s   |                       包含路径的文件名                       |
|  funcName   |  %(funcName)s   |                     日志记录所在的函数名                     |
|  levelname  |  %(levelname)s  |                        日志的级别名称                        |
|   message   |   %(message)s   |                        具体的日志信息                        |
|   lineno    |   %(lineno)d    |                      日志记录所在的行号                      |
|  pathname   |  %(pathname)s   |                           完整路径                           |
|   process   |   %(process)d   |                          当前进程ID                          |
| processName | %(processName)s |                         当前进程名称                         |
|   thread    |   %(thread)d    |                          当前线程ID                          |
| threadName  |  %threadName)s  |                         当前线程名称                         |

Logger 对象和 Handler 对象都可以设置级别，而默认 Logger 对象级别为 30，也即 WARNING，默认 Handler 对象级别为 0，也即 NOTSET。logging 模块这样设计是为了更好的灵活性，比如有时候我们既想在控制台中输出 DEBUG 级别的日志，又想在文件中输出WARNING 级别的日志。

> 日志最后的输出级别是 Logger 和 Handler 中级别最高的，因此如果我们想输出低级别的，比如 INFO，不仅仅要设置 Handler 的级别，还需要修改 Logger 的级别。


可以只设置一个最低级别的 Logger 对象，两个不同级别的 Handler 对象，示例代码如下：

```python
import logging
import logging.handlers

logger = logging.getLogger("logger")

handler1 = logging.StreamHandler()
handler2 = logging.FileHandler(filename="test.log")

logger.setLevel(logging.DEBUG)
handler1.setLevel(logging.WARNING)
handler2.setLevel(logging.DEBUG)

formatter = logging.Formatter("%(asctime)s %(name)s %(levelname)s %(message)s")
handler1.setFormatter(formatter)
handler2.setFormatter(formatter)

logger.addHandler(handler1)
logger.addHandler(handler2)

# 分别为 10、30、30
# print(handler1.level)
# print(handler2.level)
# print(logger.level)

logger.debug('This is a customer debug message')
logger.info('This is an customer info message')
logger.warning('This is a customer warning message')
logger.error('This is an customer error message')
logger.critical('This is a customer critical message')
```

控制台输出结果为：

```python
2018-10-13 23:24:57,832 logger WARNING This is a customer warning message
2018-10-13 23:24:57,832 logger ERROR This is an customer error message
2018-10-13 23:24:57,832 logger CRITICAL This is a customer critical message
```

文件中输出内容为：

```python
2018-10-13 23:44:59,817 logger DEBUG This is a customer debug message
2018-10-13 23:44:59,817 logger INFO This is an customer info message
2018-10-13 23:44:59,817 logger WARNING This is a customer warning message
2018-10-13 23:44:59,817 logger ERROR This is an customer error message
2018-10-13 23:44:59,817 logger CRITICAL This is a customer critical message
```

创建了自定义的 Logger 对象，就不要在用 logging 中的日志输出方法了，这些方法使用的是默认配置的 Logger 对象，否则会输出的日志信息会重复。

```python
import logging
import logging.handlers

logger = logging.getLogger("logger")
handler = logging.StreamHandler()
handler.setLevel(logging.DEBUG)
formatter = logging.Formatter("%(asctime)s %(name)s %(levelname)s %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.debug('This is a customer debug message')
logging.info('This is an customer info message')
logger.warning('This is a customer warning message')
logger.error('This is an customer error message')
logger.critical('This is a customer critical message')`
```

输出结果如下（可以看到日志信息被输出了两遍）：

```python
2018-10-13 22:21:35,873 logger WARNING This is a customer warning message
WARNING:logger:This is a customer warning message
2018-10-13 22:21:35,873 logger ERROR This is an customer error message
ERROR:logger:This is an customer error message
2018-10-13 22:21:35,873 logger CRITICAL This is a customer critical message
CRITICAL:logger:This is a customer critical message
```

> 在引入有日志输出的 Python 文件时，如 import test.py，在满足大于当前设置的日志级别后就会输出导入文件中的日志，在大型项目中尤其要注意。

#### logger 配置

通过上面的例子，我们知道创建一个 Logger 对象所需的配置了，上面直接硬编码在程序中配置对象，配置还可以从字典类型的对象和配置文件获取。打开 logging.config Python 文件，可以看到其中的配置解析转换函数。

```python
import logging.config

config = {
    'version': 1,
    'formatters': {
        'simple': {
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        },
        # 其他的 formatter
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'DEBUG',
            'formatter': 'simple'
        },
        'file': {
            'class': 'logging.FileHandler',
            'filename': 'logging.log',
            'level': 'DEBUG',
            'formatter': 'simple'
        },
        # 其他的 handler
    },
    'loggers':{
        'StreamLogger': {
            'handlers': ['console'],
            'level': 'DEBUG',
        },
        'FileLogger': {
            # 既有 console Handler，还有 file Handler
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
        },
        # 其他的 Logger
    }
}

logging.config.dictConfig(config)
StreamLogger = logging.getLogger("StreamLogger")
FileLogger = logging.getLogger("FileLogger")
# 省略日志输出
```

因此我们也可以从配置文件中获取配置信息。常见的配置文件有 ini 格式、yaml 格式、JSON 格式，或者从网络中获取都是可以的，只要有相应的文件解析器解析配置即可，下面只展示了 ini 格式和 yaml 格式的配置。

```ini
[loggers]
keys=root,sampleLogger

[handlers]
keys=consoleHandler

[formatters]
keys=sampleFormatter

[logger_root]
level=DEBUG
handlers=consoleHandler

[logger_sampleLogger]
level=DEBUG
handlers=consoleHandler
qualname=sampleLogger
propagate=0

[handler_consoleHandler]
class=StreamHandler
level=DEBUG
formatter=sampleFormatter
args=(sys.stdout,)

[formatter_sampleFormatter]
format=%(asctime)s - %(name)s - %(levelname)s - %(message)s
```

因为默认有 ini 的解析器，所以我们不需要额外操作就可以直接解析上述 test.ini 文件的配置信息来初始化 logger：

```python
import logging.config

logging.config.fileConfig(fname='test.ini', disable_existing_loggers=False)
logger = logging.getLogger("sampleLogger")
```

也可以使用 yaml 文件作为配置文件格式：

```yaml
version: 1
formatters:
  simple:
    format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    level: DEBUG
    formatter: simple
  
loggers:
  simpleExample:
    level: DEBUG
    handlers: [console]
    propagate: no
root:
  level: DEBUG
  handlers: [console]
```

因为默认不是 yaml 解析器，因此需要安装额外的 yaml 解析器，将文件解析为字典传入：

```python
import logging.config
# 需要安装 pyymal 库
import yaml

with open('test.yaml', 'r') as f:
    config = yaml.safe_load(f.read())
    logging.config.dictConfig(config)

logger = logging.getLogger("sampleLogger")
# 省略日志输出
```

### 实战问题

#### 中文乱码

上面的例子中日志输出都是英文内容，发现不了将日志输出到文件中会有中文乱码的问题，如何解决到这个问题呢？FileHandler 创建对象时可以设置文件编码，如果将文件编码设置为 “utf-8”（utf-8 和 utf8 等价），就可以解决中文乱码问题啦。一种方法是自定义 Logger 对象，需要写很多配置，另一种方法是使用默认配置方法 basicConfig()，传入 handlers 处理器列表对象，在其中的 handler 设置文件的编码。网上很多都是无效的方法，关键参考代码如下：

```python
# 自定义 Logger 配置
handler = logging.FileHandler(filename="test.log", encoding="utf-8")

# 使用默认的 Logger 配置
logging.basicConfig(handlers=[logging.FileHandler("test.log", encoding="utf-8")], level=logging.DEBUG)
```

#### 临时禁用日志输出

有时候我们又不想让日志输出，但在这后又想输出日志。如果我们打印信息用的是 `print()` 方法，那么就需要把所有的 `print()` 方法都注释掉，而使用了 logging 后，我们就有了一键开关闭日志的 "魔法"。一种方法是在使用默认配置时，给 `logging.disabled()` 方法传入禁用的日志级别，就可以禁止设置级别以下的日志输出了，另一种方法时在自定义 Logger 时，Logger 对象的 `disable` 属性设为 `True`（默认值是 `False`，也即不禁用）。

```python
logging.disable(logging.INFO)

logger.disabled = True
```

#### 日志文件按照时间划分或者按照大小划分

如果将日志保存在一个文件中，那么时间一长，或者日志一多，单个日志文件就会很大，既不利于备份，也不利于查看。我们会想到能不能按照时间或者大小对日志文件进行划分呢？答案肯定是可以的，并且还很简单，logging 考虑到了我们这个需求。logging.handlers 文件中提供了 `TimedRotatingFileHandler` 和 `RotatingFileHandler` 类分别可以实现按时间和大小划分。打开这个 handles 文件，可以看到还有其他功能的 Handler 类，它们都继承自基类 `BaseRotatingHandler`。

```python
# TimedRotatingFileHandler 类构造函数
def __init__(self, filename, when='h', interval=1, backupCount=0, encoding=None, delay=False, utc=False, atTime=None):

# RotatingFileHandler 类的构造函数
def __init__(self, filename, mode='a', maxBytes=0, backupCount=0, encoding=None, delay=False)
```

使用示例：

```python
# 每隔 1000 Byte 划分一个日志文件，备份文件为 3 个
file_handler = logging.handlers.RotatingFileHandler("test.log", mode="w", maxBytes=1000, backupCount=3, encoding="utf-8")

# 每隔 1小时 划分一个日志文件，interval 是时间间隔，备份文件为 10 个
handler2 = logging.handlers.TimedRotatingFileHandler("test.log", when="H", interval=1, backupCount=10)
```

### 总结

logging 作为 Python 标准日志库，灵活并且强大，但是实际使用中也需要注意一些配置，对此我觉得需要深入理解 logging 的整个流程，才能达到随心所欲的掌握这个强大的工具。

#### 参考资料

* https://cloud.tencent.com/developer/article/1354396