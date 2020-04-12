---
title: C++11的右值引用和转移语义
date: 2018-08-19 12:02:41
update: 2018-08-19 12:02:41
categories: C/C++
tags: [C++, 右值引用, C++11, 引用]
---

C++11中的右值引用是非常重要的特性，带来了语言层面的性能优化，其使用方法简洁方便，利于掌握。

<!--more-->

## 1.右值引用特性的目的

右值引用 (Rvalue Referene) 是 C++ 新标准 (C++11, 11 代表 2011 年 ) 中引入的新特性 , 它实现了转移语义 (Move Sementics) 和精确传递 (Perfect Forwarding)。它的主要目的有两个方面：

* 消除两个对象交互时不必要的对象拷贝，节省运算存储资源，提高效率。
* 能够更简洁明确地定义泛型函数。

## 2.左值和右值

### 2.1 定义

网上一堆关于左值和右值定义的博客，我觉得有的根本就是错误的，建议直接看primer的定义：**一个左值表达式表示的是对象的身份，而右值表达式表示的是对象的值**，我个人的理解很简单：**左值对应变量的存储位置，而右值对应变量的值本身**。因此右值引用同样也是实际内存对象的一个名字，而左值要求一个明确的对象（不然哪来的身份），右值则为常见的立即数、临时对象，这些只要在内存中有明确的值存在的对象上。

C++( 包括 C) 中所有的表达式和变量要么是左值，要么是右值。通俗的左值的定义就是非临时对象，那些可以在多条语句中使用的对象。所有的变量都满足这个定义，在多条代码中都可以使用，都是左值。右值是指临时的对象，它们只在当前的语句中有效。请看下列示例 :

简单的赋值语句

```cpp
int i = 0;
```

在这条语句中，i 是左值，0 是临时值，就是右值。在下面的代码中，i 可以被引用，0 就不可以了。立即数都是右值。

右值也可以出现在赋值表达式的左边，但是不能作为赋值的对象，因为右值只在当前语句有效，赋值没有意义。

```cpp
((i>0) ? i : j) = 1;
```

在这个例子中，0 作为右值出现在了 = 的左边。但是赋值对象是 i 或者 j，都是左值。

在 C++11 之前，右值是不能被引用的，最大限度就是用常量引用绑定一个右值，如 :

```cpp
const int &a = 1;
```

在这种情况下，右值不能被修改的。但是实际上右值是可以被修改的，如 :

```cpp
T().set().get();
```

T 是一个类，set 是一个函数为 T 中的一个变量赋值，get 用来取出这个变量的值。在这句中，T() 生成一个临时对象，就是右值，set() 修改了变量的值，也就修改了这个右值。

既然右值可以被修改，那么就可以实现右值引用。右值引用能够方便地解决实际工程中的问题，实现非常有吸引力的解决方案。

### 2.2 语法符号

左值的声明符号为`&`， 为了和左值区分，右值的声明符号为`&&`。

示例1：
```cpp
void process_value(int& i) { 
 std::cout << "LValue processed: " << i << std::endl; 
} 
 
void process_value(int&& i) { 
 std::cout << "RValue processed: " << i << std::endl; 
} 
 
int main() { 
 int a = 0; 
 process_value(a); 
 process_value(1); 
}
```

运行结果：
```cpp
LValue processed: 0 
RValue processed: 1
```

Process_value 函数被重载，分别接受左值和右值。由输出结果可以看出，临时对象是作为右值处理的。

**但是如果临时对象通过一个接受右值的函数传递给另一个函数时，就会变成左值，因为这个临时对象在传递过程中，变成了命名对象。**

示例2：
```cpp
void process_value(int& i) { 
 std::cout << "LValue processed: " << i << std::endl; 
} 
 
void process_value(int&& i) { 
 std::cout << "RValue processed: " << i << std::endl; 
} 
 
void forward_value(int&& i) { 
 process_value(i); 
} 
 
int main() { 
 int a = 0; 
 process_value(a); 
 process_value(1); 
 forward_value(2); 
}
```

运行结果：
```cpp
LValue processed: 0 
RValue processed: 1 
LValue processed: 2
```

虽然 2 这个立即数在函数 forward_value 接收时是右值，但到了 process_value 接收时，变成了左值。

## 3.转移语义

### 3.1 定义

右值引用是用来支持转移语义的。**转移语义**可以将资源 ( 堆，系统对象等 ) 从一个对象转移到另一个对象，这样能够减少不必要的临时对象的创建、拷贝以及销毁，能够大幅度提高 C++ 应用程序的性能。临时对象的维护 ( 创建和销毁 ) 对性能有严重影响。

转移语义是和**拷贝语义**相对的，可以类比文件的剪切与拷贝，当我们将文件从一个目录拷贝到另一个目录时，速度比剪切慢很多。

通过转移语义，临时对象中的资源能够转移其它的对象里。

在现有的 C++ 机制中，我们可以定义拷贝构造函数和赋值函数。要实现转移语义，需要定义转移构造函数，还可以定义转移赋值操作符。对于右值的拷贝和赋值会调用转移构造函数和转移赋值操作符。如果转移构造函数和转移拷贝操作符没有定义，那么就遵循现有的机制，拷贝构造函数和赋值操作符会被调用。

普通的函数和操作符也可以利用右值引用操作符实现转移语义。

### 3.2 转移构造函数和转移赋值函数

对于拷贝语义，C++中一些类必须显示定义拷贝构造函数和拷贝赋值函数，同样的，对于转移语义，一个类同样需要定义转移构造函数和转移赋值函数。

以一个简单的 string 类为示例，实现拷贝构造函数和拷贝赋值操作符。

示例类：

```c++
class MyString {

private:
    char* _data;
    size_t _len;
    void _init_data(const char *s) {
        _data = new char[_len+1];
        memcpy(_data, s, _len);
        _data[_len] = '\0';
    }

public:
    // 默认构造函数
    MyString() {
        _data = nullptr;
        _len = 0;
    }

    // 构造函数
    MyString(const char* p) {
        _len = strlen(p);
        _init_data(p);
    }

    // 拷贝构造函数
    MyString(const MyString& str) {
        _len = str._len;
        _init_data = (str._data);
        std::cout << "Copy Constructor is called! source: " << str._data << std::endl; 
    }

    // 拷贝赋值函数
    MyString& operator=(const MyString& str) {
        if (this != &str) { 
            _len = str._len; 
            _init_data(str._data); 
        } 
        std::cout << "Copy Assignment is called! source: " << str._data << std::endl; 
        return *this;
    }

    // 析构函数
    virtual ~MyString() {
        if (_data) 
            free(_data)
    }
};


int main() { 
 MyString a; 
 a = MyString("Hello"); 
 std::vector<MyString> vec; 
 vec.push_back(MyString("World")); 
}
```

运行结果：

```cpp
Copy Assignment is called! source: Hello 
Copy Constructor is called! source: World
```

这个 string 类已经基本满足我们演示的需要。在 main 函数中，实现了调用拷贝构造函数的操作和拷贝赋值操作符的操作。MyString(“Hello”) 和 MyString(“World”) 都是临时对象，也就是右值。虽然它们是临时的，但程序仍然调用了拷贝构造和拷贝赋值，造成了没有意义的资源申请和释放的操作。如果能够直接使用临时对象已经申请的资源，既能节省资源，有能节省资源申请和释放的时间。这正是定义转移语义的目的。

我们先定义转移构造函数：

```c++
MyString(MyString&& str) { 
   std::cout << "Move Constructor is called! source: " << str._data << std::endl; 
   _len = str._len; 
   _data = str._data; 
   
   // 修改资源链接和标记
   str._len = 0; 
   str._data = NULL; 
}
```

转移构造函数定义和拷贝构造函数类似，有几点需要注意：

* **参数（右值）的符号必须是右值引用符号，即`&&`。**
* **参数（右值）不可以是常量，因为我们需要修改右值。**
* **参数（右值）的资源链接和标记必须修改。否则，右值的析构函数就会释放资源。转移到新对象的资源也就无效了。**

现在我们定义转移赋值操作符：

```cpp
MyString& operator=(MyString&& str) { 
   std::cout << "Move Assignment is called! source: " << str._data << std::endl; 
   if (this != &str) { 
     _len = str._len; 
     _data = str._data; 
     str._len = 0; 
     str._data = NULL; 
   } 
   return *this; 
}
```

这里需要注意的问题和转移构造函数是一样的。

增加了转移构造函数和转移复制操作符后，我们的程序运行结果为 :

```cpp
Move Assignment is called! source: Hello 
Move Constructor is called! source: World
```

由此看出，编译器区分了左值和右值，**对右值调用了转移构造函数和转移赋值操作符。节省了资源，提高了程序运行的效率**。

有了右值引用和转移语义，我们在设计和实现类时，对于需要动态申请大量资源的类，应该设计转移构造函数和转移赋值函数，以提高应用程序的效率。**这个非常重要，对于一些类对象的函数传值，返回等等操作，都会因为右值引用而大大提高效率，更重要的是，这种操作是编译器自动优化的，我们只需要定义好转移语义的函数，编译器会自动调用转移语义的函数来提高效率**。

### 3.2 std::move

既然**编译器只对右值引用才能调用转移构造函数和转移赋值函数**，而**所有命名对象都只能是左值引用**，如果已知一个命名对象不再被使用而想对它调用转移构造函数和转移赋值函数，也就是**把一个左值引用当做右值引用来使用**，怎么做呢？标准库提供了函数 std::move，这个函数以非常简单的方式将左值引用转换为右值引用。

示例程序：

```cpp
void ProcessValue(int& i) { 
 std::cout << "LValue processed: " << i << std::endl; 
} 
 
void ProcessValue(int&& i) { 
 std::cout << "RValue processed: " << i << std::endl; 
} 
 
int main() { 
 int a = 0; 
 ProcessValue(a); 
 ProcessValue(std::move(a)); 
}
```

运行结果：

```cpp
LValue processed: 0 
RValue processed: 0
```

std::move在提高 swap 函数的的性能上非常有帮助，一般来说，swap函数的通用定义如下：

```cpp
template <class T> swap(T& a, T& b)  { 
       T tmp(a);   // copy a to tmp 
       a = b;      // copy b to a 
       b = tmp;    // copy tmp to b 
}
```

有了 std::move，swap 函数的定义变为 :

```cpp
template <class T> swap(T& a, T& b) { 
       T tmp(std::move(a)); // move a to tmp 
       a = std::move(b);    // move b to a 
       b = std::move(tmp);  // move tmp to b 
}
```

通过 std::move，一个简单的 swap 函数就避免了 3 次不必要的拷贝操作。

## 4 完美转发(Perfect Forwarding)



回忆一下，前文一个例子里，右值引用传递到函数内部就变成左值了，这就是**引用塌缩**，因为一个引用本身是命名对象，所以是左值。在传统 C++ 中，我们不能够对一个引用类型继续进行引用，但 C++ 由于右值引用的出现而放宽了这一做法，从而产生了引用坍缩规则，允许我们对引用进行引用，既能左引用，又能右引用。但是却遵循如下规则：


|函数形参类型|传入实参类型|推导后的实际函数参数类型|
| :--: | :--: | :--: |
|T&|左引用|T&|
|T&|右引用|T&|
|T&&|左引用|T&|
|T&&|右引用|T&&|

完美转发就是基于上述规律产生的。所谓完美转发，就是为了让我们在传递参数的时候，保持原来的参数类型（左引用保持左引用，右引用保持右引用）。为了解决这个问题，我们应该使用 std::forward 来进行参数的转发（传递）：

```cpp
#include <iostream>
#include <utility>
void reference(int& v) {
    std::cout << "左值引用" << std::endl;
}
void reference(int&& v) {
    std::cout << "右值引用" << std::endl;
}
template <typename T>
void pass(T&& v) {
    std::cout << "普通传参:";
    reference(v);
    std::cout << "std::move 传参:";
    reference(std::move(v));
    std::cout << "std::forward 传参:";
    reference(std::forward<T>(v));

}
int main() {
    std::cout << "传递右值:" << std::endl;
    pass(1);

    std::cout << "传递左值:" << std::endl;
    int v = 1;
    pass(v);

    return 0;
}
```

```cpp
传递右值:
普通传参:左值引用
std::move 传参:右值引用
std::forward 传参:右值引用
传递左值:
普通传参:左值引用
std::move 传参:右值引用
std::forward 传参:左值引用
```

无论传递参数为左值还是右值，普通传参都会将参数作为左值进行转发，所以 std::move 总会接受到一个左值，从而转发调用了reference(int&&) 输出右值引用。

唯独 std::forward 即没有造成任何多余的拷贝，同时完美转发(传递)了函数的实参给了内部调用的其他函数。

实际上， **std::forward 和 std::move 一样，没有做任何事情，std::move 单纯的将左值转化为右值，std::forward 也只是单纯的将参数做了一个类型的转换，从是实现来看，std::forward<T>(v) 和 static_cast<T&&>(v) 是完全一样的。**

## 5.总结

右值引用带来的一系列特性是C++11最重要的特性之一，熟悉这些特性的性能优化和原理实现，可以很方便的帮助我们更好的控制C++的内存资源和对象。