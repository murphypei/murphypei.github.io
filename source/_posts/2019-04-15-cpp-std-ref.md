---
title: C++11的std::ref用法
date: 2019-04-15 15:43:50
update: 2019-04-15 15:43:50
categories: C++
tags: [C++, STL, ref, bind, thread]
---

C++11中引入`std::ref`用于取某个变量的引用，这个引入是为了解决一些传参问题。

<!-- more -->

我们知道C++中本来就有引用的存在，为何C++11中还要引入一个`std::ref`了？主要是考虑函数式编程（如std::bind）在使用时，是对参数直接拷贝，而不是引用。下面通过例子说明

示例1：
```C++
#include <functional>
#include <iostream>

void f(int& n1, int& n2, const int& n3)
{
    std::cout << "In function: " << n1 << ' ' << n2 << ' ' << n3 << '\n';
    ++n1; // increments the copy of n1 stored in the function object
    ++n2; // increments the main()'s n2
    // ++n3; // compile error
}

int main()
{
    int n1 = 1, n2 = 2, n3 = 3;
    std::function<void()> bound_f = std::bind(f, n1, std::ref(n2), std::cref(n3));
    n1 = 10;
    n2 = 11;
    n3 = 12;
    std::cout << "Before function: " << n1 << ' ' << n2 << ' ' << n3 << '\n';
    bound_f();
    std::cout << "After function: " << n1 << ' ' << n2 << ' ' << n3 << '\n';
}
```

输出：
```
Before function: 10 11 12
In function: 1 11 12
After function: 10 12 12
```

上述代码在执行`std::bind`后，在函数f()中n1的值仍然是1，n2和n3改成了修改的值，**说明`std::bind`使用的是参数的拷贝而不是引用，因此必须显示利用`std::ref`来进行引用绑定**。具体为什么std::bind不使用引用，可能确实有一些需求，使得C++11的设计者认为默认应该采用拷贝，如果使用者有需求，加上std::ref即可。

示例2：

```C++
#include<thread>
#include<iostream>
#include<string>

void threadFunc(std::string &str, int a)
{
    str = "change by threadFunc";
    a = 13;
}

int main()
{
    std::string str("main");
    int a = 9;
    std::thread th(threadFunc, std::ref(str), a);

    th.join();

    std::cout<<"str = " << str << std::endl;
    std::cout<<"a = " << a << std::endl;

    return 0;
}
```

输出：
```
str = change by threadFunc
a = 9
```

可以看到，和`std::bind`类似，多线程的`std::thread`也是必须显式通过`std::ref`来绑定引用进行传参，否则，形参的引用声明是无效的。
