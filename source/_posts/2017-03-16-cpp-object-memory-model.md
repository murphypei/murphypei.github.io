---
title: C++对象内存模型详解
date: 2017-03-16
update: 2018-04-12
categories: C++
tags: [C++, 虚函数, 内存模型, 虚继承]
---

本文总结了C++继承中的对象在内存中的布局，对于C++众多特性中不同对象的布局进行深入地详细记录。

<!--more-->

## 1. 前言

文章较长，而且内容相对来说比较枯燥，希望对C++对象的内存布局、虚表指针、虚基类指针等有深入了解的朋友可以慢慢看。
本文的结论都在VS2013上得到验证。不同的编译器在内存布局的细节上可能有所不同。
文章如果有解释不清、解释不通或疏漏的地方，恳请指出。

## 2. 何为C++对象模型？

引用《深度探索C++对象模型》这本书中的话：  
> 有两个概念可以解释C++对象模型：  
> * 语言中直接支持面向对象程序设计的部分。    
> * 对于各种支持的底层实现机制。

直接支持面向对象程序设计，包括了构造函数、析构函数、多态、虚函数等等，这些内容在很多书籍上都有讨论，也是C++最被人熟知的地方（特性）。而对象模型的底层实现机制却是很少有书籍讨论的。对象模型的底层实现机制并未标准化，不同的编译器有一定的自由来设计对象模型的实现细节。在我看来，对象模型研究的是对象在存储上的空间与时间上的更优，并对C++面向对象技术加以支持，如以虚指针、虚表机制支持多态特性。

## 3. 文章内容简介

这篇文章主要来讨论C++对象在内存中的布局，属于第二个概念的研究范畴。而C++直接支持面向对象程序设计部分则不多讲。文章主要内容如下：  

* **虚函数表解析**。含有虚函数或其父类含有虚函数的类，编译器都会为其添加一个虚函数表，vptr，先了解虚函数表的构成，有助对C++对象模型的理解。
* **虚基类表解析**。虚继承产生虚基类表(vbptr)，虚基类表的内容与虚函数表完全不同，我们将在讲解虚继承时介绍虚继承表。
* **C++对象模型概述**：介绍简单对象模型、表格驱动对象模型，以及非继承情况下的C++对象模型。
* 继承下的C++对象模型。分析C++类对象在下面情形中的内存布局：
    * 单继承：子类单一继承自父类，分析了子类重写父类虚函数、子类定义了新的虚函数情况下子类对象内存布局
    * 多继承：子类继承于多个父类，分析了子类重写父类虚函数、子类定义了新的虚函数情况下子类对象内存布局，同时分析了非虚继承下的菱形继承。
    * 虚继承：分析了单一继承下的虚继承、多重基层下的虚继承、重复继承下的虚继承。  
* 理解对象的内存布局之后，我们可以分析一些问题：
    * C++封装带来的布局成本是多大？
    * 由空类组成的继承层次中，每个类对象的大小是多大？    

至于其他与内存有关的知识，我假设大家都有一定的了解，如内存对齐，指针操作等。本文初看可能晦涩难懂，要求读者有一定的C++基础，对概念一有一定的掌握。


## 4. 理解虚函数表

### 4.1 多态和虚表

C++中虚函数的作用主要是为了实现多态机制。多态，简单来说，是指在继承层次中，父类的指针可以具有多种形态——当它指向某个子类对象时，通过它能够调用到子类的函数，而非父类的函数。

```C++
class Base {     
    virtual void print(void);    
}

class Drive1 :public Base{    
    virtual void print(void);    
}

class Drive2 :public Base{    
    virtual void print(void);    
}    

Base * ptr1 = new Base; 
Base * ptr2 = new Drive1;  
Base * ptr3 = new Drive2;

ptr1->print();  //调用Base::print()
prt2->print();  //调用Drive1::print()
prt3->print();  //调用Drive2::print()
```

![多态和虚表](/images/posts/cplusplus/virtual_derived.png)

这是一种运行期多态，即父类指针唯有在程序运行时才能知道所指的真正类型是什么。这种运行期决议，是通过虚函数表来实现的。

### 4.2 使用指针访问虚表

如果我们丰富我们的Base类,使其拥有多个virtual函数：  

```c++
class Base
{
public:
    
    Base(int i) :baseI(i){};

    virtual void print(void) { cout << "调用了虚函数Base::print()"; }

    virtual void setI() { cout << "调用了虚函数Base::setI()"; }

    virtual ~Base(){}
    
private:
    
    int baseI;
};
```

![使用指针访问虚表](/images/posts/cplusplus/base_class.png)

**当一个类本身定义了虚函数，或其父类有虚函数时，为了支持多态机制，编译器将为该类添加一个虚函数表指针（vptr）。虚表指针一般都放在对象内存布局的第一个位置上，这是为了保证在多层继承或多重继承的情况下能以最高效率取到虚函数表。**

当vprt位于对象内存最前面时，**对象的地址即为虚函数表指针地址**。我们可以取得虚函数表指针的地址：  

```c++
Base b(1000);
int * vptrAdree = (int *)(&b);  
cout << "虚函数表指针（vprt）的地址是：\t" << vptrAdree << endl;
```

我们运行代码出结果：  

![](/images/posts/cplusplus/result1.jpg)  


我们强行把类对象的地址转换为 int* 类型，取得了虚表指针的地址。虚表指针指向虚函数表，虚函数表中存储的是一系列虚函数的地址，**虚函数地址出现的顺序与类中虚函数声明的顺序一致**。对虚函数表指针取地址值，可以得到虚函数表的地址，（添加注释：内存中这个地址存放的就是第一个虚函数的地址），也即是虚函数表第一个虚函数的地址:  

```c++
typedef void(*Fun)(void);
Fun vfunc = (Fun)*( (int *)*(int*)(&b));
cout << "第一个虚函数的地址是：" << (int *)*(int*)(&b) << endl;
cout << "通过地址，调用虚函数Base::print()：";
vfunc(); 
```
  
* 我们把虚表指针的值取出来： `*(int*)(&b)`，它是一个地址，虚函数表的地址
* 把虚函数表的地址强制转换成int指针： `int* : (int*) *(int*)( &b )`
* 再把它转化成我们Fun指针类型 ： `(Fun)*(int*)*(int*)(&b)`  
* 注意这里，int和指针的长度一般都是一样的，所以将地址指针转换为int指针

这样，我们就取得了类中的第一个虚函数，我们可以通过函数指针访问它。
运行结果：

![](/images/posts/cplusplus/result2.jpg)

同理,第二个虚函数setI()的地址为：

```c++
(int *)(*(int*)(&b)+1)
```

同样可以通过函数指针访问它。

到目前为止，我们知道了类中虚表指针vprt的由来，知道了虚函数表中的内容，以及如何通过指针访问虚函数表。下面的文章中将常使用指针访问对象内存来验证我们的C++对象模型，以及讨论在各种继承情况下虚表指针的变化，先把这部分的内容消化完再接着看下面的内容。

## 5. 对象模型概述

在C++中，有两种数据成员：static和nonstatic,以及三种类成员函数：static、nonstatic和virtual:  

![](/images/posts/cplusplus/class_members.png)

现在我们有一个类Base，它包含了上面这5中类型的数据或函数：  

```c++
class Base
{
public:
    
    Base(int i) :baseI(i){};
    
    int getI(){ return baseI; }
    
    static void countI(){};
    
    virtual void print(void){ cout << "Base::print()"; }

    virtual ~Base(){}
    
private:
    
    int baseI;
    
    static int baseS;
}; 
```

![](/images/posts/cplusplus/base_class1.jpg)

那么，这个类在内存中将被如何表示？5种数据都是连续存放的吗？如何布局才能支持C++多态？ 我们的C++标准与编译器将如何塑造出各种数据成员与成员函数呢？

### 5.1 简单对象模型

### 5.2 表格驱动模型

**注：因为这两种模型并没有应用于实际的C++编译器，所以不转载原文的描述，下同**

### 5.3 非继承下的C++对象模型

概述：在此模型下，nonstatic 数据成员被置于每一个对象中，而static数据成员被置于对象之外。static与nonstatic函数也都放在对象之外，而对于virtual 函数，则通过虚函数表+虚指针来支持，具体如下：

* 每个**类**生成一个表格，称为**虚表**（virtual table，简称vtbl）。虚表中存放着一堆指针，这些指针指向该类每一个虚函数。虚表中的函数地址将按**声明时**的顺序排列，不过当子类有多个重载函数时例外，后面会讨论。

* 每个**对象**都拥有一个**虚表指针**(vptr)，由编译器为其生成。虚表指针的设定与重置皆由类的复制控制（也即是构造函数、析构函数、赋值操作符）来完成。vptr的位置为编译器决定，传统上它被放在所有显示声明的成员之后，不过现在许多编译器把vptr放在一个类对象的最前端。关于数据成员布局的内容，在后面会详细分析。   

另外，虚函数表的前面设置了一个指向type_info的指针，用以支持RTTI（Run Time Type Identification，运行时类型识别）。RTTI是为多态而生成的信息，包括对象继承关系，对象本身的描述等，**只有具有虚函数的对象在会生成**。

在此模型下，Base的对象模型如图：  

![](/images/posts/cplusplus/object_model1.png)

先在VS上验证类对象的布局:

![](/images/posts/cplusplus/result3.png)

可见对象b含有一个vfptr，即vprt。并且只有nonstatic数据成员被放置于对象内。我们展开vfprt：

![](/images/posts/cplusplus/result4.png)

vfptr中有两个指针类型的数据（地址），第一个指向了Base类的析构函数(**第一个虚函数地址总是指向析构函数**)，第二个指向了Base的虚函数print，**顺序与声明顺序相同**。  

这与上述的C++对象模型相符合。也可以通过代码来进行验证：  

```c++
void testBase( Base&p)
{
    cout << "对象的内存起始地址：" << &p << endl;
    cout << "type_info信息:" << endl;
    RTTICompleteObjectLocator str = *((RTTICompleteObjectLocator*)*((int*)*(int*)(&p) - 1));
    
    
    string classname(str.pTypeDescriptor->name);
    classname = classname.substr(4, classname.find("@@") - 4);
    cout <<  "根据type_info信息输出类名:"<< classname << endl;
    
    cout << "虚函数表地址:" << (int *)(&p) << endl;
    
    //验证虚表
    cout << "虚函数表第一个函数的地址：" << (int *)*((int*)(&p)) << endl;
    cout << "析构函数的地址:" << (int* )*(int *)*((int*)(&p)) << endl;
    cout << "虚函数表中，第二个虚函数即print（）的地址：" << ((int*)*(int*)(&p) + 1) << endl;
    
    //通过地址调用虚函数print（）
    typedef void(*Fun)(void);
    Fun IsPrint=(Fun)* ((int*)*(int*)(&p) + 1);
    cout << endl;
    cout<<"调用了虚函数"；
    IsPrint(); //若地址正确，则调用了Base类的虚函数print（）
    cout << endl;
    
    //输入static函数的地址
    p.countI();//先调用函数以产生一个实例
    cout << "static函数countI()的地址：" << p.countI << endl;
    
    //验证nonstatic数据成员
    cout << "推测nonstatic数据成员baseI的地址：" << (int *)(&p) + 1 << endl;
    cout << "根据推测出的地址，输出该地址的值：" << *((int *)(&p) + 1) << endl;
    cout << "Base::getI():" << p.getI() << endl;
}   

Base b(1000);
testBase(b);    
```

![](/images/posts/cplusplus/result5.png)

**结果分析：**

* 通过 (int *)(&p)取得虚函数表的地址
* type\_info信息的确存在于虚表的前一个位置。通过((int*)*(int*)(&p) - 1)取得type\_info信息的指针，并成功获得类的名称的Base
* 虚函数表的第一个函数是析构函数。
* 虚函数表的第二个函数是虚函数print()，取得地址后通过地址调用它（而非通过对象），验证正确
* 虚表指针的下一个位置为nonstatic数据成员baseI。
* 可以看到，static成员函数的地址段位与虚表指针、baseI的地址段位不同。  

好的，至此我们了解了非继承下类对象五种数据在内存上的布局，也知道了在每一个虚函数表前都有一个指针指向type_info，负责对RTTI的支持。而加入继承后类对象在内存中该如何表示呢？

## 6. 继承下的C++对象模型

### 6.1 单继承

如果我们定义了派生类  

```c++
class Derive : public Base
{
public:
    Derive(int d) :Base(1000),      DeriveI(d){};
    
    //overwrite父类虚函数
    virtual void print(void) { cout << "Drive::Drive_print()" ; }
    
    // Derive声明的新的虚函数
    virtual void Drive_print() { cout << "Drive::Drive_print()" ; }
    
    virtual ~Derive(){}
private:
    int DeriveI;
};   
```

继承类图为：  

![](/images/posts/cplusplus/base_class2.png)

一个派生类如何在机器层面上塑造其父类的实例呢？

在C++对象模型中，对于一般继承（这个一般是相对于虚继承而言），若子类重写（overwrite）了父类的虚函数，则子类虚函数将覆盖虚表中对应的父类虚函数(注意子类与父类拥有各自的一个虚函数表)；若子类并没有overwrite父类虚函数，而是声明了自己新的虚函数，则该虚函数地址将扩充到虚函数表最后（在vs中无法通过监视看到扩充的结果，不过我们通过取地址的方法可以做到，子类新的虚函数确实在虚函数表末端）。而对于虚继承，若子类overwrite父类虚函数，同样地将覆盖从父类继承过来的虚函数表中的对应位置，而若子类声明了自己新的虚函数，则**编译器将为子类增加一个新的虚表指针vptr，这与一般继承不同**，在后面再讨论。  

* 这地方最有趣的是虚析构函数，子类的虚函数表中，用自己的虚函数地址覆盖掉了父类的虚析构函数地址。

* 其实这个图可以表明继承关系中是如何产生类的对象中，我们知道，**C++继承时，先调用父类构造函数生成一个父类对象，如图Base类实例，然后调用子类的构造函数生成一个子类的对象，其实这个对象在父类的对象上进行扩充**。  

* 另一方面，子类继承了父类全部的成员，包括private，只是子类没有访问权限。所以不是没有，是不能访问。

![](/images/posts/cplusplus/object_model2.png)  

我们使用代码来验证以上模型  

```c++
typedef void(*Fun)(void);
    
int main()
{
    Derive d(2000);
    //[0]
    cout << "[0]Base::vptr";
    cout << "\t地址：" << (int *)(&d) << endl;
    //vprt[0]
    cout << "  [0]";
    Fun fun1 = (Fun)*((int *)*((int *)(&d)));
    fun1();
    cout << "\t地址:\t" << *((int *)*((int *)(&d))) << endl;

    //vprt[1]析构函数无法通过地址调用，故手动输出
    cout << "  [1]" << "Derive::~Derive" << endl;

    //vprt[2]
    cout << "  [2]";
    Fun fun2 = (Fun)*((int *)*((int *)(&d)) + 2);
    fun2();
    cout << "\t地址:\t" << *((int *)*((int *)(&d)) + 2) << endl;
    //[1]
    cout << "[2]Base::baseI=" << *(int*)((int *)(&d) + 1);
    cout << "\t地址：" << (int *)(&d) + 1;
    cout << endl;
    //[2]
    cout << "[2]Derive::DeriveI=" << *(int*)((int *)(&d) + 2);
    cout << "\t地址：" << (int *)(&d) + 2;
    cout << endl;
    getchar();
}
```  

运行结果：  

![](/images/posts/cplusplus/result6.png)

这个结果与我们的对象模型符合。  

### 继承导致重载函数的隐藏

* 首先要说明的是，**重载只能发生在同一个类中**，子类和父类之间的同名函数（参数列表），无法构成重载。

* **子类的同名函数（无论参数列表是否相同），会覆盖所有父类（多继承情况下）的所有同名函数（包括虚函数）**。

* 因为这种特性，也就导致了子类的同名函数会隐藏父类的重载函数。如果想用父类的重载函数，可以通过`using Base::foo`来声明继承所有的重载函数，然后重写特定参数列表的函数。如果不需要重写，则也可以通过使用父类作用域来显式地调用父类的重载函数。

### 6.2 多继承

#### 6.2.1 一般的多重继承  

单继承中（一般继承），子类会扩展父类的虚函数表。在多继承中，子类含有多个父类的子对象，该往哪个父类的虚函数表扩展呢？当子类overwrite了父类的函数，需要覆盖多个父类的虚函数表吗？  

* **子类的虚函数被放在声明的第一个基类的虚函数表中**。

* overwrite时，所有基类的同名函数都被子类的同名函数覆盖。

* 内存布局中，父类按照其声明顺序排列。  

其中第二点保证了父类指针指向子类对象时，总是能够调用到真正的函数。

为了方便查看，我们把代码都粘贴过来  

```c++
class Base
{
public:
    
    Base(int i) :baseI(i){};
    virtual ~Base(){}
    
    int getI(){ return baseI; }
    
    static void countI(){};
    
    virtual void print(void){ cout << "Base::print()"; }
    
private:
    
    int baseI;
    
    static int baseS;
};
class Base_2
{
public:
    Base_2(int i) :base2I(i){};

    virtual ~Base_2(){}

    int getI(){ return base2I; }

    static void countI(){};

    virtual void print(void){ cout << "Base_2::print()"; }
    
private:
    
    int base2I;
    
    static int base2S;
};
    
class Drive_multyBase :public Base, public Base_2
{
public:

    Drive_multyBase(int d) :Base(1000), Base_2(2000) ,Drive_multyBaseI(d){};
    
    virtual void print(void){ cout << "Drive_multyBase::print" ; }
    
    virtual void Drive_print(){ cout << "Drive_multyBase::Drive_print" ; }
    
private:
    int Drive_multyBaseI;
};  
```

继承类图为：  

![](/images/posts/cplusplus/class1.png)  

此时Drive_multyBase 的对象模型是这样的：  

![](/images/posts/cplusplus/object_model3.png)

我们使用代码验证：  

```c++

typedef void(*Fun)(void);
    
int main()
{
    Drive_multyBase d(3000);
    
    //[0]
    cout << "[0]Base::vptr";
    cout << "\t地址：" << (int *)(&d) << endl;
    
    //vprt[0]析构函数无法通过地址调用，故手动输出
    cout << "  [0]" << "Derive::~Derive" << endl;

    //vprt[1]
    cout << "  [1]";
    Fun fun1 = (Fun)*((int *)*((int *)(&d))+1);
    fun1();
    cout << "\t地址:\t" << *((int *)*((int *)(&d))+1) << endl;


    //vprt[2]
    cout << "  [2]";
    Fun fun2 = (Fun)*((int *)*((int *)(&d)) + 2);
    fun2();
    cout << "\t地址:\t" << *((int *)*((int *)(&d)) + 2) << endl;
    
    
    //[1]
    cout << "[1]Base::baseI=" << *(int*)((int *)(&d) + 1);
    cout << "\t地址：" << (int *)(&d) + 1;
    cout << endl;
    
    
    //[2]
    cout << "[2]Base_::vptr";
    cout << "\t地址：" << (int *)(&d)+2 << endl;
    
    //vprt[0]析构函数无法通过地址调用，故手动输出
    cout << "  [0]" << "Drive_multyBase::~Derive" << endl;

    //vprt[1]
    cout << "  [1]";
    Fun fun4 = (Fun)*((int *)*((int *)(&d))+1);
    fun4();
    cout << "\t地址:\t" << *((int *)*((int *)(&d))+1) << endl;
    
    //[3]
    cout << "[3]Base_2::base2I=" << *(int*)((int *)(&d) + 3);
    cout << "\t地址：" << (int *)(&d) + 3;
    cout << endl;
    
    //[4]
    cout << "[4]Drive_multyBase::Drive_multyBaseI=" << *(int*)((int *)(&d) + 4);
    cout << "\t地址：" << (int *)(&d) + 4;
    cout << endl;
    
    getchar();
}  

运行结果： 
 
![](/images/posts/cplusplus/result7.png)  

##### 6.2.2 菱形继承

菱形继承也称为钻石型继承或重复继承，它指的是基类被某个派生类简单重复继承了多次。这样，派生类对象中拥有多份基类实例（这会带来一些问题）。为了方便叙述，我们不使用上面的代码了，而重新写一个重复继承的继承层次：  

![](/images/posts/cplusplus/class2.png)

```c++
class B
{
    
public:
    
    int ib;
    
public:
    
    B(int i=1) :ib(i){}
    
    virtual void f() { cout << "B::f()" << endl; }
    
    virtual void Bf() { cout << "B::Bf()" << endl; }
    
};
    
class B1 : public B
{
    
public:
    
    int ib1;
    
public:
    
    B1(int i = 100 ) :ib1(i) {}
    
    virtual void f() { cout << "B1::f()" << endl; }
    
    virtual void f1() { cout << "B1::f1()" << endl; }
    
    virtual void Bf1() { cout << "B1::Bf1()" << endl; }
    
    
    
};
    
class B2 : public B
{
    
public:

    int ib2;
    
public:
    
    B2(int i = 1000) :ib2(i) {}
    
    virtual void f() { cout << "B2::f()" << endl; }
    
    virtual void f2() { cout << "B2::f2()" << endl; }
    
    virtual void Bf2() { cout << "B2::Bf2()" << endl; }
    
};
    
    
class D : public B1, public B2
{
    
public:

    int id;
    
public:
    
    D(int i= 10000) :id(i){}
    
    virtual void f() { cout << "D::f()" << endl; }
    
    virtual void f1() { cout << "D::f1()" << endl; }
    
    virtual void f2() { cout << "D::f2()" << endl; }
    
    virtual void Df() { cout << "D::Df()" << endl; }
    
};  
```


这时，根据单继承，我们可以分析出B1，B2类继承于B类时的内存布局。又根据一般多继承，我们可以分析出D类的内存布局。我们可以得出D类子对象的内存布局如下图：  

![](/images/posts/cplusplus/object_model4.png)

D类对象内存布局中，图中青色表示b1类子对象实例，黄色表示b2类子对象实例，灰色表示D类子对象实例。从图中可以看到，由于D类间接继承了B类两次，导致D类对象中含有两个B类的数据成员ib，一个属于来源B1类，一个来源B2类。这样不仅增大了空间，更重要的是引起了程序歧义：  


    D d;
     
    d.ib =1 ;               //二义性错误,调用的是B1的ib还是B2的ib？
     
    d.B1::ib = 1;           //正确
     
    d.B2::ib = 1;           //正确

尽管我们可以通过明确指明调用路径以消除二义性，但二义性的潜在性还没有消除，我们可以通过虚继承来使D类只拥有一个ib实体。

## 7. 虚继承

虚继承解决了菱形继承中最派生类拥有多个间接父类实例的情况。虚继承的派生类的内存布局与普通继承很多不同，主要体现在：

* 虚继承的子类，如果本身定义了新的虚函数，则编译器为其生成一个虚函数表指针（vptr）以及一张虚函数表。该vptr位于对象内存最前面。

    * 非虚继承：直接扩展父类虚函数表。

* 虚继承的子类也单独保留了父类的vptr与虚函数表。这部分内容接与子类内容以一个四字节的0来分界。

* 虚继承的子类对象中，含有四字节的虚基类表指针偏移值。

为了分析最后的菱形继承，我们还是先从单虚继承继承开始。

### 7.1 虚基类表解析

在C++对象模型中，虚继承而来的子类会**生成一个隐藏的虚基类指针（vbptr）**，在Microsoft Visual C++中，虚基类表指针总是在虚函数表指针之后，因而，对某个类实例来说，如果它有虚基类指针，那么虚基类指针可能在实例的0字节偏移处（该类没有vptr时，vbptr就处于类实例内存布局的最前面，否则vptr处于类实例内存布局的最前面），也可能在类实例的4字节偏移处。

**虚基类表**

* 一个类的虚基类指针指向的虚基类表

* 与虚函数表一样，虚基类表也由多个条目组成，条目中存放的是偏移值。**第一个条目存放虚基类表指针（vbptr）所在地址到该类内存首地址的偏移值**，由第一段的分析我们知道，这个偏移值为0（类没有vptr）或者-4（类有虚函数，此时有vptr）。

* 虚基类表的第二、第三...个条目依次为**该类的最左虚继承父类、次左虚继承父类...的内存地址相对于虚基类表指针的偏移值。**

我们通过一张图来更好地理解。  

![](/images/posts/cplusplus/vptr_in_class.png)


### 7.2 简单虚继承

如果我们的B1类虚继承于B类：

```c++
//类的内容与前面相同
class B{...}
class B1 : virtual public B
```

![](/images/posts/cplusplus/class3.png)

根据我们前面对虚继承的派生类的内存布局的分析，B1类的对象模型应该是这样的：

![](/images/posts/cplusplus/object_model5.png)

> ***注意上图，子类对象中有两个虚表指针，分别是子类的虚表指针和父类的虚表指针。如果子类重写父类的虚函数，则将父类的虚表中的虚函数地址替换为子类的虚函数地址***


我们通过指针访问B1类对象的内存，以验证上面的C++对象模型：

```c++
int main()
{
B1 a;
    cout <<"B1对象内存大小为："<< sizeof(a) << endl;
    
    //取得B1的虚函数表
    cout << "[0]B1::vptr";
    cout << "\t地址：" << (int *)(&a)<< endl;
    
    //输出虚表B1::vptr中的函数
    for (int i = 0; i<2;++ i)
    {
        cout << "  [" << i << "]";
        Fun fun1 = (Fun)*((int *)*(int *)(&a) + i);
        fun1();
        cout << "\t地址：\t" << *((int *)*(int *)(&a) + i) << endl;
    }
    
    //[1]
    cout << "[1]vbptr "  ;
    cout<<"\t地址：" << (int *)(&a) + 1<<endl;  //虚表指针的地址
    //输出虚基类指针条目所指的内容
    for (int i = 0; i < 2; i++)
    {
        cout << "  [" << i << "]";
    
        cout << *(int *)((int *)*((int *)(&a) + 1) + i);
    
        cout << endl;
    }
    
    
    //[2]
    cout << "[2]B1::ib1=" << *(int*)((int *)(&a) + 2);
    cout << "\t地址：" << (int *)(&a) + 2;
    cout << endl;
    
    //[3]
    cout << "[3]值=" << *(int*)((int *)(&a) + 3);
    cout << "\t\t地址：" << (int *)(&a) + 3;
    cout << endl;
    
    //[4]
    cout << "[4]B::vptr";
    cout << "\t地址：" << (int *)(&a) +3<< endl;
    
    //输出B::vptr中的虚函数
    for (int i = 0; i<2; ++i)
    {
        cout << "  [" << i << "]";
        Fun fun1 = (Fun)*((int *)*((int *)(&a) + 4) + i);
        fun1();
        cout << "\t地址:\t" << *((int *)*((int *)(&a) + 4) + i) << endl;
    }
    
    //[5]
    cout << "[5]B::ib=" << *(int*)((int *)(&a) + 5);
    cout << "\t地址: " << (int *)(&a) + 5;
    cout << endl;
}
```

**运行结果**：

![](/images/posts/cplusplus/result8.png)


这个结果与我们的C++对象模型图完全符合。这时我们可以来分析一下虚表指针的第二个条目值12的具体来源了，回忆上文讲到的：

> 第二、第三...个条目依次为该类的最左虚继承父类、次左虚继承父类...的内存地址相对于虚基类表指针的偏移值。

在我们的例子中，也就是B类实例内存地址相对于vbptr的偏移值，也即是：[4]-[1]的偏移值，结果即为12，从地址上也可以计算出来：007CFDFC-007CFDF4结果的十进制数正是12。现在，我们对虚基类表的构成应该有了一个更好的理解。

### 7.3 虚拟菱形继承

如果我们有如下继承层次：

```c++
class B{...}
class B1: virtual public  B{...}
class B2: virtual public  B{...}
class D : public B1,public B2{...}
```

类图如下所示：

![](/images/posts/cplusplus/class4.png)

菱形虚拟继承下，最派生类D类的对象模型又有不同的构成了。在D类对象的内存构成上，有以下几点：

* 在D类对象内存中，基类出现的顺序是：先是B1（最左父类），然后是B2（次左父类），最后是B（虚祖父类）

* D类对象的数据成员id放在B类前面，两部分数据依旧以0来分隔。

* **编译器没有为D类生成一个它自己的vptr，而是覆盖并扩展了最左父类的虚基类表，与简单继承的对象模型相同**。

* 超类B的内容放到了D类对象内存布局的最后。

菱形虚拟继承下的C++对象模型为：


![](/images/posts/cplusplus/object_model6.png)

下面使用代码加以验证：

```c++
int main()
{
    D d;
    cout << "D对象内存大小为：" << sizeof(d) << endl;
    
    //取得B1的虚函数表
    cout << "[0]B1::vptr";
    cout << "\t地址：" << (int *)(&d) << endl;
    
    //输出虚表B1::vptr中的函数
    for (int i = 0; i<3; ++i)
    {
        cout << "  [" << i << "]";
        Fun fun1 = (Fun)*((int *)*(int *)(&d) + i);
        fun1();
        cout << "\t地址：\t" << *((int *)*(int *)(&d) + i) << endl;
    }
    
    //[1]
    cout << "[1]B1::vbptr ";
    cout << "\t地址：" << (int *)(&d) + 1 << endl;  //虚表指针的地址
    //输出虚基类指针条目所指的内容
    for (int i = 0; i < 2; i++)
    {
        cout << "  [" << i << "]";
    
        cout << *(int *)((int *)*((int *)(&d) + 1) + i);
    
        cout << endl;
    }
    
    
    //[2]
    cout << "[2]B1::ib1=" << *(int*)((int *)(&d) + 2);
    cout << "\t地址：" << (int *)(&d) + 2;
    cout << endl;
    
    //[3]
    cout << "[3]B2::vptr";
    cout << "\t地址：" << (int *)(&d) + 3 << endl;
    
    //输出B2::vptr中的虚函数
    for (int i = 0; i<2; ++i)
    {
        cout << "  [" << i << "]";
        Fun fun1 = (Fun)*((int *)*((int *)(&d) + 3) + i);
        fun1();
        cout << "\t地址:\t" << *((int *)*((int *)(&d) + 3) + i) << endl;
    }
    
    //[4]
    cout << "[4]B2::vbptr ";
    cout << "\t地址：" << (int *)(&d) + 4 << endl;  //虚表指针的地址
    //输出虚基类指针条目所指的内容
    for (int i = 0; i < 2; i++)
    {
        cout << "  [" << i << "]";
    
        cout << *(int *)((int *)*((int *)(&d) + 4) + i);
    
        cout << endl;
    }
    
    //[5]
    cout << "[5]B2::ib2=" << *(int*)((int *)(&d) + 5);
    cout << "\t地址: " << (int *)(&d) + 5;
    cout << endl;
    
    //[6]
    cout << "[6]D::id=" << *(int*)((int *)(&d) + 6);
    cout << "\t地址: " << (int *)(&d) + 6;
    cout << endl;
    
    //[7]
    cout << "[7]值=" << *(int*)((int *)(&d) + 7);
    cout << "\t\t地址：" << (int *)(&d) + 7;
    cout << endl;
    
    //间接父类
    //[8]
    cout << "[8]B::vptr";
    cout << "\t地址：" << (int *)(&d) + 8 << endl;
    
    //输出B::vptr中的虚函数
    for (int i = 0; i<2; ++i)
    {
        cout << "  [" << i << "]";
        Fun fun1 = (Fun)*((int *)*((int *)(&d) + 8) + i);
        fun1();
        cout << "\t地址:\t" << *((int *)*((int *)(&d) + 8) + i) << endl;
    }
    
    //[9]
    cout << "[9]B::id=" << *(int*)((int *)(&d) + 9);
    cout << "\t地址: " << (int *)(&d) +9;
    cout << endl;
    
    getchar();
}
```    

查看运行的结果：

![](/images/posts/cplusplus/result10.png)

### 8. 一些问题解答

#### 8.1 C++封装带来的布局成本是多大？

在C语言中，“数据”和“处理数据的操作（函数）”是分开来声明的，也就是说，语言本身并没有支持“数据和函数”之间的关联性。
在C++中，我们通过类来将属性与操作绑定在一起，称为ADT，抽象数据结构。

C语言中使用struct（结构体）来封装数据，使用函数来处理数据。举个例子，如果我们定义了一个struct Point3如下：

```c++
typedef struct Point3
{
    float x;
    float y;
    float z;
} Point3;
```

为了打印这个Point3d，我们可以定义一个函数：

```c++
void Point3d_print(const Point3d *pd)
{
    printf("(%f,%f,%f)",pd->x,pd->y,pd_z);
}
```

而在C++中，我们更倾向于定义一个Point3d类，以ADT来实现上面的操作:

```c++
class Point3d
{
    public:
        point3d (float x = 0.0,float y = 0.0,float z = 0.0)
            : _x(x), _y(y), _z(z){}

        float x() const {return _x;}
        float y() const {return _y;}
        float z() const {return _z;}
    
    private:
        float _x;
        float _y;
        float _z;
};

inline ostream&
operator<<(ostream &os, const Point3d &pt)
{
    os<<"("<<pr.x()<<","
        <<pt.y()<<","<<pt.z()<<")";
}
```

看到这段代码，很多人第一个疑问可能是：加上了封装，布局成本增加了多少？答案是class Point3d并没有增加成本。学过了C++对象模型，我们知道，**Point3d类对象的内存中，只有三个数据成员**。

上面的类声明中，三个数据成员直接内含在每一个Point3d对象中，而成员函数虽然在类中声明，却不出现在类对象（object）之中，这些函数(non-inline)属于类而不属于类对象，只会为类产生唯一的函数实例。

所以，Point3d的封装并没有带来任何空间或执行期的效率影响。而在下面这种情况下，C++的封装额外成本才会显示出来：

* 虚函数机制（virtual function） , 用以支持执行期绑定，实现多态。
* 虚基类 （virtual base class） ，虚继承关系产生虚基类，用于在多重继承下保证基类在子类中拥有唯一实例。

不仅如此，Point3d类数据成员的内存布局与c语言的结构体Point3d成员内存布局是相同的。C++中处在同一个访问标识符（指public、private、protected）下的声明的数据成员，在内存中必定保证以其声明顺序出现。而处于不同访问标识符声明下的成员则无此规定。对于Point3类来说，它的三个数据成员都处于private下，在内存中一起声明顺序出现。我们可以做下实验：

```c++
void TestPoint3Member(const Point3d& p)
{
    
    cout << "推测_x的地址是：" << (float *) (&p) << endl;
    cout << "推测_y的地址是：" << (float *) (&p) + 1 << endl;
    cout << "推测_z的地址是：" << (float *) (&p) + 2 << endl;
    
    cout << "根据推测出的地址输出_x的值：" << *((float *)(&p)) << endl;
    cout << "根据推测出的地址输出_y的值：" << *((float *)(&p)+1) << endl;
    cout << "根据推测出的地址输出_z的值：" << *((float *)(&p)+2) << endl;
    
}

//测试代码
Point3d a(1,2,3);
TestPoint3Member(a);
```

运行结果：

![](/images/posts/cplusplus/result11.png)

从结果可以看到，_x,_y,_z三个数据成员在内存中紧挨着。

总结一下：  

**不考虑虚函数与虚继承，当数据都在同一个访问标识符下，C++的类与C语言的结构体在对象大小和内存布局上是一致的，C++的封装并没有带来空间时间上的影响**。


#### 8.2 下面这个空类构成的继承层次中，每个类的大小是多少？

```c++
class B{};
class B1 :public virtual  B{};
class B2 :public virtual  B{};
class D : public B1, public B2{};

int main()
{
    B b;
    B1 b1;
    B2 b2;
    D d;
    cout << "sizeof(b)=" << sizeof(b)<<endl;
    cout << "sizeof(b1)=" << sizeof(b1) << endl;
    cout << "sizeof(b2)=" << sizeof(b2) << endl;
    cout << "sizeof(d)=" << sizeof(d) << endl;
    getchar();
}  
```

输出结果：

![](/images/posts/cplusplus/result12.png)

解析：  

- 编译器为空类安插1字节的char，以使该类对象在内存得以配置一个地址。
- b1虚继承于b，编译器为其安插一个4字节的**虚基类表指针（32为机器）**，此时b1已不为空，编译器不再为其安插1字节的char（优化）。
- d含有来自b1与b2两个父类的两个虚基类表指针。大小为8字节。


本文转自：http://www.cnblogs.com/QG-whz/p/4909359.html