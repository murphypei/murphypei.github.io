---
title: C++内部类（嵌套类）与外部类和友元
date: 2017-02-17
update: 2018-04-12
categories: C/C++
tags: [C++, 内部类, 外部类, 友元]
---

在阅读 SimpleHttpServe 源码时，ServeBase 类中大量内部类的定义，本文对 C++ 的内部类（嵌套类）与外部类极其与友元的关系进行了总结。

<!--more-->

### 内部类的概念

如果一个类定义在另一个类的内部，这个内部类就叫做内部类。此时这个内部类是一个独立的类，它不属于外部类，更不能通过外部类的对象去调用内部类。外部类对内部类没有任何优越的访问权限。即说：

* **内部类就是外部类的友元类**（不需要特意在外部类中声明）。注意友元类的定义，内部类可以通过外部类的对象参数来访问外部类中的所有成员。但是**外部类不是内部类的友元**。
* 总结来看，外部类与内部类其实联系并不大，外部类无非仅仅限定了内部类类名的作用域范围。

内部类可以定义在外部类的 public、protected、private 都是可以的。

* 如果内部类定义在 public，则可通过 外部类名::内部类名 来定义内部类的对象。
* 如果定义在 private，则外部不可定义内部类的对象，这可实现“实现一个不能被继承的类”问题。

### 内部类的使用

定义一个内部类：

```c++
#include <iostream>

using namespace std;

class Outer {
public:
    Outer() {m_outerInt = 0;}
    void displayOut() { cout << m_outerInt << endl; }
private:
    int m_outerInt;

// 定义内部类
public:
    class Inner {
    public:
        Inner(){m_innerInt = 1;}
    private:
        int m_innerInt;
    public:
        void displayIn() { cout << m_innerInt << endl; }
    };
// End内部类
};



int main() {
    Outer out;
    Outer::Inner in;    // 内部类对象
    out.displayOut();
    in.displayIn();
    
    getchar();
    return 0;
}
```

内部类自动声明为外部类的友元，如果想在内部类的实例对象中中访问外部类的实例对象的数据成员，必须通过传入外部类的指针来解决，直接看代码吧：

```c++
#include <iostream>
#include <cstddef>

using namespace std;

#define METHOD_PROLOGUE(theClass, localClass)  \
    theClass* pThis = ((theClass*)((char*)(this) - offsetof(theClass, m_x##localClass)));   // offsetof求数据成员偏移
                                                                                            // ## 宏定义分隔连接符
    
using namespace std;

class Outer {
public:
    Outer() { m_outerInt = 0; }
    void displayOut() { cout << m_outerInt << endl; }
private:
    int m_outerInt;
public:
    class Inner {
    public:
        Inner() { m_innerInt = 1; }
        void displayIn() { cout << m_innerInt << endl; }
        void setOut() {
            METHOD_PROLOGUE(Outer, Inner);
            pThis->m_outerInt = 10;
        } m_xInner;     // 在Outer类中声明一个Inner实例对象
    private:
        int m_innerInt;
    }
};

int main() {
    Outer out;
    out.displayOut();   // 0
    out.m_xInner.setOut();
    out.displayOut();   // 10
    
    getchar();
    return 0;
}
```

可以看出，外部类对象中必须包含一个内部类对象。然后内部类对象通过寻找外部类数据成员在外部类中的地址来操作其数据成员。

**`main` 函数解析：**

* 程序执行完 `main` 函数第一句后，内存中便有了一个数据块，它存储着 `out` 的数据，而 `m_xInner` 也在数据块中；
* 当然，`&out` 和 `this` 指针（外部类）都指向该内存块的起始位置，而内部类代码中的 `this` 指针当然就指向 `m_xInner` 的起始内存了，`offsetof(theClass, m_x##localClass)` 获得的便是 `m_xInner` 在该内存块中与该内存块起始地址（这正是 `out` 的地址）的距离（偏移），即内部类 this - 外部类 this 的差值（以字节为单位）这样，用内部类 this 减去其自身的偏移，便可得到 `pThis`。
* 有了 `out` 的地址，基本上可以对其为所欲为了，至于为何要有 `char*` 强转，可以 go to definition of offset，可以看到其实现中有个关于 char 的转换。

此外，由于友元的关系，**内部类可以直接访问外部类中的 static、枚举成员，不需要外部类的对象/类名**。再次强调，如果外部类中不包含内部类的对象，外部类和内部类没有特别的关系，最直接的解释就是 `sizeof` 求外部的大小等于外部类的数据成员大小，内部类只不过是一个定义在外部类的定义域中的普通类。
