---
title: 单例模式(C++)
categories: C/C++
date: 2017-04-30
update: 2018-04-12
tags: [单例模式, C++, Singleton]
---

单例模式是设计模式中最简单也很常见的一种，单例模式的写法有很多种，本文对C++中各种单例的写法进行总结。

<!--more-->

## 原始版本的单例模式

```c++
class Singleton
{
public:
    static Singleton&  getInstance() 
    {
        return m_instance;
    }

private:
    Singleton();
    ~Singleton();
    Singleton(const Singleton& rhs);
    Singleton& operator=(const Singleton& rhs);

private:
    static Singleton m_instance;      // 静态成员变量, 程序开始的时候即完成了初始化
};
```

**特点：**

由于在main函数之前初始化，所以**没有线程安全的问题**，但是潜在问题在于no-local static对象（函数外的static对象）在不同编译单元（可理解为cpp文件和其包含的头文件）中的初始化顺序是未定义的。如果在初始化完成之前调用 getInstance()方法会返回一个未定义的实例。

**注意：**

这里getInstance()返回的实例的引用而不是指针，如果返回的是指针可能会有被外部调用者delete掉的隐患，所以这里返回引用会更加保险一些。

## 懒汉式的单例模式

```c++
class Singleton
{
public:
    static Singleton& getInstance()
    {
        if(m_ptrInstance == nullptr)
        {
            m_ptrInstance = new Singleton();
        }
        return *m_ptrInstance;  
    }

private:
    Singleton();
    ~Singleton();
    Singleton(const Singleton&);
    Singleton& operator=(const Singleton&);

private:
    static Singleton* m_ptrInstance;
};
```

**特点：**

* 先判断有没有现成的实例，如果有直接返回，如果没有则生成新实例并把实例的指针保存到私有的静态属性中。直到getInstance()被访问，才会生成实例，这种特性被称为延迟初始化（Lazy initialization），这在一些初始化时消耗较大的情况有很大优势。

* Lazy Singleton不是线程安全的，比如现在有线程A和线程B，m_ptrInstance == NULL的判断，那么线程A和B都会创建新实例。单例模式保证生成唯一实例的规则被打破了。

## 加锁的懒汉式单例模式

```c++
class Singleton
{
public:
    Singleton& getInstance()
    {
        if(m_ptrInstance == nullptr) // 只有在判断不存在实例的情况下才加锁，提升效率
        {
            mtx.lock();  //基于作用域的加锁，超出作用域，自动调用析构函数解锁
            if(m_ptrInstance == nullptr)    // 防止出现多个instance
            {
                m_ptrInstance = new Singleton();
            }
            mtx.unlock();
        }
        return *m_ptrInstance;
    }

private:
    Singleton();
    ~Singleton();
    Singleton(const Singleton&);
    Singleton& operator=(const Singleton&);

private:
    static Singleton* m_ptrInstance;
    static std::mutex mtx;
};
```

**特点：**

Lazy Singleton的一种线程安全改造是在Instance()中每次判断是否为NULL前加锁，但是加锁是很慢的。而实际上只有第一次实例创建的时候才需要加锁。双检测锁模式被提出来，只需要在第一次初始化的时候加锁，那么在这之前判断一下实例有没有被创建就可以了，所以多在加锁之前多加一层判断，需要判断两次所有叫Double-Checked。

**注意：**

> 此中方法接近完美，但是存在问题：指令重排和原子操作。`m_ptrInstance = new Singleton();`不是一个原子操作。这个操作可能存在CPU指令重排。

## 利用局部静态变量的单例模式（Meyers方法）

```c++
class Singleton
{
public:
    static Singleton& getInstance()
    {
        static Singleton instance;
        return instance;
    }

private:
    Singleton();
    ~Singleton();
    Singleton(const Singleton&);
    Singleton& operator=(const Singleton&);
};
```

**特点：**

static局部变量只在第一次函数调用时生成，很巧妙，而且是线程安全，最优实现。