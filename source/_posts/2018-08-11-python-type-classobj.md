---
title: Python中的type和classobj
date: 2018-08-10 09:19:44
update: 2018-08-10 09:19:44
categories: Python
tags: [Python, type, classobj, super]
---

根据实际使用过程中的报错问题引出的python的type和classobj的总结。

<!--more-->

最近在调用super的过程中，报了一个很错误：

```python
TypeError: must be type, not classobj
```

对这个错误有点诧异，因为在python2和python3上运行结果不同，3就不会报错，一查才知道python2中的类的定义分为两种，经典类（也就是报错中提到的classobj）和新式类，而python中super只能应用于新式类，而不能应用于经典类。

**经典类**

所谓经典类就是什么都不用继承的类，例如最初的A类就是经典类，下面是一个经典类的例子:

```python
class A():
  ...
```

**新式类**

所谓新式类就是必须要有继承的类，如果什么都不想继承，就继承到object类。下面是一个新类的例子：

```python
class B(object):
  ...
```

由于python2中新式类的定义必须显式继承object，否则会被认为是经典类，所以报错。而在python3中，所有类都默认继承自object，也就是说**python3中全部都是新式类，没有经典类**，所以也就不会报错。

进一步的思考，为啥报错中提到must be type？难道不是应该是object类型吗，object和type又是什么关系？先放结论：

> object是所有类的超类。而type是什么呢？它是object的类型（也就是说object是type的实例），同时，object又是type的超类。总之来说，object和type是鸡生蛋，蛋生鸡，谁先生谁，无法说。

上面这段结论必须要围绕python中一切皆是对象的理念来思考。对于所有类的超类object，它是被定义的类，但这个类也是对象，它的类型就是type，如果了解python中元类编程大概就能明白这句话的意思了。python元类基本概念可以参考[这篇文章](https://www.liaoxuefeng.com/wiki/0014316089557264a6b348958f449949df42a6d3a2e542c000/0014319106919344c4ef8b1e04c48778bb45796e0335839000)，这里我简单说一下大概：因为python是动态语言，所以类的创建也是在程序运行过程中创建的，创建类的方式就是通过type函数（还有一种方式就是元类），type函数既可以返回实例的类型，也可以用于创建一个类，被创建的类的类型就是type。

定义一个类Hello

```python
class Hello(object):
  def hello(self, name='world'):
    print('Hello, %s.' % name)
```

测试如下：

```python
>>> from hello import Hello
>>> h = Hello()
>>> h.hello()
Hello, world.
>>> print(type(Hello))
<class 'type'>
>>> print(type(h))
<class 'hello.Hello'>
```

type可以直接用于创建一个类：

```python
>>> def fn(self, name='world'): # 先定义函数
...     print('Hello, %s.' % name)
...
>>> Hello = type('Hello', (object,), dict(hello=fn)) # 创建Hello class
>>> h = Hello()
>>> h.hello()
Hello, world.
>>> print(type(Hello))
<class 'type'>
>>> print(type(h))
<class '__main__.Hello'>
```

所以现在我们明白了，**在python2中显式继承自object的类，都是由type创建的，都是type类型，至于object，它是python中所有类的超类。type和object是python中两个源对象，二者的关系没有严格的父子关系，互相依赖对方来定义，所以它们不能分开而论**。type和object的测试如下：

```
>>> object            #===>(1)
<class 'object'>
>>> type              #===>(2)
<class 'type'>
>>> type(object)      #===>(3)
<class 'type'>
>>> object.__class__  #===>(4)
<class 'type'>
>>> object.__bases__  #===>(5)
()
>>> type.__class__    #===>(6)
<class 'type'>
>>> type.__bases__    #===>(7)
(<class 'object'>,)
```

结论如下：

* (1)，(2)：python中的两个源对象的名字。我们先前说过type()是用来获对象的类型的。事实上，它既是一个对象，也是获取其它对象的类型的方法。
* (3)，(4)：查看object的类型。看到object是type的实例，我们另外也用.__class__来核实它和type()的输出是一样的。
* (5)：object没有超类，因为它本身就是所有对象的超类。
* (6)，(7)：分别输出type的类型和超类。即，object是type的超类。type的类型是它自己
