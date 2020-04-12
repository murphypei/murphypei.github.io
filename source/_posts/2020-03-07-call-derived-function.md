---
title: 父类成员函数调用子类成员函数
date: 2020-03-07 19:38:13
update: 2020-03-07 19:38:13
categories: C/C++
tags: [C++11, 函数指针, 模板]
---

最近遇到一个很有意思的问题，如果在父类成员函数中调用子类成员函数。这个应用场景不是很常见，但是有一些方法可以实现。

<!-- more -->

#### 通过函数指针

```c++
#include <iostream>

// 声明子类型
class Derived;

class Base
{
public:
    // 声明子类对象指针
    Derived *d;
    // 声明子类型的函数指针
    void (Derived::*f)(int);
    
    // 通过子类型对象和函数指针调用子类型函数
    void f1() 
    { 
        (d->*f)(123); 	// 注意调用的写法
    }
};

class Derived : public Base
{
public:
    void f2(int i) 
    { 
        std::cout << "Derived f2: " << i << std::endl; 
    }
	
    // 为继承得到的父类型的成员变量赋值
    void f3()
    {
        d = this;
        f = &Derived::f2;	// 注意这里 & 后面不能加括号
    }
};

int main()
{
    Derived d;
    d.f3();
    d.f1();
    return 0;
}
```

输出：

```
Derived f2: 123
```

思路是这样的，在父类中声明子类成员变量指针和函数指针，并在父类成员方法中通过函数指针去调用。然后在子类中给继承得到的这些成员变量赋值，这样子类调用父类的方法的时候就能实现调用子类方法。

这里说两个关于类成员函数指针的知识点：

> 1. 函数指针赋值要使用 **&**
> 2. 使用 **.\*** (实例对象)或者 **->\***（实例对象指针）调用类成员函数指针所指向的函数


#### 通过模板类

其实这个问题本来是让我用模板类实现。

```c++
#include <iostream>

template <typename T>
class Base
{
public:
    T *t;
    void f1() 
    { 
        std::cout << "Base f1: "<< t->val << std::endl;
        // 模板类型即使看不到声明也可以调用
        t->f2();
    }
};

class Derived : public Base<Derived>
{
public:
    int val;
    void f2() 
    { 
        std::cout << "Derived f2: " << val << std::endl; 
    }

    void f3()
    {
        val = 123;
        t = this;
    }
};

int main()
{
    Derived d;
    d.f3();
    d.f1();
    return 0;
}
```

输出：

```
Base f1: 123
Derived f2: 123
```

其实思路类似，就是在父类中需要有一个占位符能表示子类。在前面函数指针实现中，我们用子类指针和函数指针作为声明（需要前置声明子类）占位符。而利用模板，我们不需要函数指针，模板类型本身就可以作为一种占位符。我们将模板类型当作子类类型，直接在父类成员中调用子类函数。另外，我们在子类定义时，继承的父类是利用子类模板实例化的一个类，然后在子类中给模板类型赋值为当前对象指针，这样就实现了调用。

其实这里我们主要是利用 t 是模板类型 T 的指针，这样即使不知道 t 的具体定义，也可以访问到其成员，可以调用到其方法，若非通过模板，就不能这样。



