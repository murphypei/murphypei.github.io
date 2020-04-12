---
title: C++ 接口和实现分离初步简介
date: 2018-12-12 10:47:46
update: 2018-12-12 16:46:46
categories: C/C++
tags: [C++, interface, 接口, 实现, pImpl]
---

C++虽然不太常提到设计模式，但是对外接口和实现细节的分离仍然是必须的。

<!--more-->

今天在提交代码的时候遇到一个问题，给出的.h文件中定义了一个类，虽然类中只有一些对外暴露的接口的成员函数，但是类中包含了一些private的成员变量。虽然不影响使用，但是从规范上讲是不合理的。因此需要将接口和实现的细节进行分离。也就是常说的信息隐藏。下面通过一个常用的头文件格式进行说明。考虑我们对外Release的一个头文件，`a.h`：
```c++
class A
{
public:
  X getX();
  Y getY();
  Z getZ();
 
private:
  X god;
  Y damn;
  Z it;
};
```

## private成员变量

这种方式的头文件形式如下：
```
#include "X.h"
#include "Y.h"
#include "Z.h"
 
class A
{
public:
  X getX();
  Y getY();
  Z getZ();

private:
  X god;
  Y damn;
  Z it;
};
```
其中我们如果直接使用private的方式进行信息隐藏，面临多个问题：

* 别人能看到我们private成员变量的信息；
* 必须同时给出我们依赖的`X.h`，`Y.h`和`Z.h`；
* 依赖的头文件和类本身的任何改动都将引发重新编译，即使这个改动本质上是不影响外部调用的。

这种方式本质上是一种**紧耦合**，只是简单的面向对象的封装，隐藏实现细节。

## 使用依赖类的声明而非定义

这种方式的头文件形式如下：
```
class X;
class Y;
class Z;
 
class A
{
public:
  X getX();
  Y getY();
  Z getZ();

private:
  X god;
  Y damn;
  Z it;
};
```

可以看到，我们不用再包含`X.h`，`Y.h`和`Z.h`，当他们发生变化时，A的调用者不必重新编译，阻止了**级联依赖的发生**，但是别人仍然能看到我们的私有成员信息，这也不是我们预想的。


## pImpl模式

使用Impl的代理模式，即A本身只是一个负责对外提供接口的类，真正的实现使用一个AImpl类来代理，接口的实现通过调用Impl类的对应函数来实现，从而实现真正意义上的**接口和实现分离**
```c++
// AImpl.h
struct AImpl
{
public:
  X getX();
  Y getY();
  Z getZ();

private:
  X x;
  Y y;
  Z z;
};
 
// A.h
class X;
class Y;
class Z;
struct AImpl;
 
class A
{
public:
  // 可能的实现： X getX() { return pImpl->getX(); }
  X getX()
  Y getY()
  Z getZ();

private:
  std::tr1::unique_ptr<AImpl> pImpl;
};
```

来看看这种实现的好处。首先，任何实现的细节都封装在AImpl类中，所以对于调用端来说是完全不可见的，包括可能用到的成员。其次，只要A的接口没有变化，调用端都不需要重新编译。

但是这种实现也有一个问题，就是多了一个类需要维护，并且每次对A的调用都将是对AImpl的间接调用，效率肯定有所降低。

这种实现方式有一些问题需要注意：

* **Impl的声明最好设置为struct**，原因我也不清楚，因为我用class声明的AImpl（不包含private成员），在Linux上能过，在windows过不去，一直报`LINK ERROR`的错误。我怀疑windows上看不到类的定义时，直接引用类成员函数会有问题。

* 一般使用`unique_ptr`来包装Impl类，但是使用`unique_ptr`的时候，接口类的析构函数不能直接定义在类的声明中。因为在类的声明中直接定义析构函数（或者使用=default）的时候，看不到Impl类的实现，也就是看不到Impl类的析构函数，而接口类的析构函数，必须要看`unique_ptr`成员函数Impl类的析构函数，否则会报`can't delete an incomplete type`错误。

  * 这个错误其实是一类错误，主要是类的声明不知道类的大小，无论是构造还是析构，都不知道需要为类的对象分配或者回收的内存大小，因此是`incomplete type`。

  * 同时这中前向声明的方式，通常也用于解决循环引用的问题，但是forward declaration方式，被声明的类只能被用于指针，因为作为类的成员变量，必须知道其大小，而声明的Impl类没看到定义，不知道大小，但是指针的大小是固定的。

更多相关知识，可以参考： [How to implement the pimpl idiom by using unique_ptr](https://www.fluentcpp.com/2017/09/22/make-pimpl-using-unique_ptr/)

## Interface类

一个能够同时满足两个需求的方法是使用接口类，也就是不包含私有数据的抽象类。调用端首先获得一个AConcrete对象的指针，然后通过接口指针A*来进行操作。
```c++
// A.h
class A
{
public:
  virtual ~A();
  virtual X getX() = 0;
  virtual Y getY() = 0;
  virtual Z getZ() = 0;
  ..
};
 
class AConcrete: public A
{ ... };
```

这种方法也比较常用，好处类似使用Impl模式，代价是可能会多一个VPTR，指向虚表。
