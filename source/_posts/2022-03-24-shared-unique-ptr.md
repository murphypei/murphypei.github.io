---
title: shared_ptr 和 unique_ptr 深入探秘
date: 2022-03-24 10:52:47
update: 2022-03-24 10:52:47
categories: C/C++
tags: [c++, shared_ptr, unique_ptr, delete, template]
---

C++ 中 `shared_ptr` 和 `unique_ptr` 是 C++11 之后被广泛使用的两个智能指针，但是其实他们在使用上还是有一些“秘密”的，我根据平时遇到的两个问题，总结记录一些知识。

<!-- more -->

### 为什么 unique_ptr 需要明确知道类型的析构函数

这个问题是我写 `unique_ptr` 调试接口的时候才注意到的，之前确实不知道。为什么会这样呢？首先我们必须要知道 `unique_ptr` 到底封装了什么？通常 `unique_ptr` 就是简单的对裸指针封装，并且禁用拷贝和赋值：

```c++
template<
    class T,
    class Deleter = std::default_delete<T>
> class unique_ptr;
```

可以看到，`Deleter` 的类型是 `unique_ptr` 类型的一部分。在 `unique_ptr` 内部会保存类型为 `T*` 和 `Deleter` 的成员 ，分别表示保存的裸指针和删除器。假设内部是这么实现的 (一般会运用空基类优化把 `Deleter` 的空间优化掉，`libstdc++` 里把他们放进了一个 tuple。这里是简化了)：

```c++
private:
    T* p;
    Deleter del;
```

然后析构的时候就会这样：

```c++
~unique_ptr()
{
    del(p);
}
```


当 `Deleter` 是默认的 `std::default_delete` 时，`del(p)` 就会 `delete p`，`delete` 会调用析构函数。而 `delete` 一个不完整类型的指针是 ub(undefined behavior)。在典型的实现中都会在 `delete` 前通过 `static_assert(sizeof(T) > 0)` 做检查。 `sizeof` 对 incomplete type 求值会直接编译出错。

> incomplete type 是指当定义一个变量的时候，不知道应该分配多少内存。C++ 声明和定义最大的区别就是是否发生内存分配，当发生内存分配的时候，必须知道要分配多少内存，通常一个未定义的 struct，未指定长度的数组类型，都会引发 incomplete type 的问题。参考：https://docs.microsoft.com/en-us/cpp/c-language/incomplete-types?view=msvc-170

```c++
struct student;
std::cout << sizeof(student) << std::endl;
```

上述代码执行会报错

```
prog.cc:17:18: error: invalid application of 'sizeof' to an incomplete type 'student'
    std::cout << sizeof(student) << std::endl;
```

只声明了结构体 `student`，但是并没有定义，所以是一个 incomplete type，所以 `sizeof` 无法执行。

回到 `unique_ptr`，现在我们知道 `unique_ptr` 的报错链路是 `unique_ptr`->`delete`->`sizoef`，也就是 `sizeof` 才是罪魁祸首。所以当 `Deleter` 非默认时，就不一定需要知道类型的析构函数。比如下面这样：

```c++
// A is incomplete type
class A;
auto Del = [] (A*) { };
std::unique_ptr<A, decltype(Del)> ptr;
```

因此可以对这个问题做定性：**并不是 `unique_ptr` 需要知道析构函数，而是 `unique_ptr` 的默认删除器 `Deleter` 需要明确知道类型的析构函数**。

继续深挖一下，这个问题会出现在 `shared_ptr` 吗？答案是**不会**。这又引入了另一个问题，shared_ptr 和 unique_ptr 的封装有什么不同？

### shared_ptr 的封装

按理说 `shared_ptr.reset` 的时候需要 `delete` ptr 就需要 ptr 的类型（错了请指正），而 `shared_ptr` 的 template type 可以是 incomplete type（错误请指正）。cppreference 是这么描述的：
> `std::shared_ptr` may be used with an incomplete typeT. However, the constructor from a raw pointer (template<class Y> shared_ptr(Y*)) and the template<class Y>void reset(Y*) member function may only be called with a pointer to a complete type (note that std::unique_ptr may be constructed from a raw pointer to an incomplete type).

`reset` 的时候需要类型完整。默认构造的时候允许是不完整类型。为什么会这样呢？`shared_ptr` 怎么处理 `Deleter` 呢？(还记得吧， Deleter 就是智能指针析构时候的删除操作)

在常见编译器的实现里，`shared_ptr` 把 `Deleter`（包括默认情况下的 operator delete）放进一个叫做 **control block** 的结构里，相当于做了一次 type erasure，把 `Deleter` 的类型从 `shared_ptr` 类型本身里面擦下去。`Deleter` 的类型在 control block 的具体类型上，`shared_ptr` 本身只**持有一个 `control block` 基类的指针**，通过虚函数来调用 `Deleter`。而因为 `shared_ptr` 构造的时候要求必须是 complete type，control block已经知道怎么析构了，`shared_ptr` 析构的时候就调用个虚函数，具体事情它不管的。

这下我们明白了，`unique_ptr` 的封装太简单了，没有 control block，`Deleter`（包括默认的std::default_delete）直接做在 `unique_ptr` 一起了，这就导致 `unique_ptr` 的析构函数需要亲手析构被管理的类型，因此析构函数必须看到 complete type。然而反过来，因为**构建的时候只需要保存下指针，所以 `unique_ptr` 构造的时候不需要看到 complete type**。这俩正好是反的。C++ 标准并没有规定这些实现细节，但是规定函数签名和特性的时候，是考虑着比较合理的实现方式来写标准的，到最后标准落下来之后也差不多只能这么实现了。

### 总结

* `unique_ptr` 只保存了类型指针 ptr 和这个指针的析构方法，调用 delete ptr，就需要ptr的完整类型，为了防止这个问题出现，直接通过 assert sizeof 排除掉了这种风险。**`unique_ptr` 相当于在编译时绑定了删除器**。
* `shared_ptr` 保存的是一个控制块的指针。控制块包含的就是一个引用计数和一个原来对象的裸指针。控制块中初始化的指针是 `nullptr`，在运行时为其赋值，也可以通过 `reset` 修改。类似于虚函数，**`shared_ptr` 相当于在运行时绑定了删除器**。

虽然只是一个小小的知识点，但是也帮助我深入理解了 `shared_ptr` 和 `unique_ptr` 在设计上的区别，对于不同使用场景下选择不同智能指针的体会也更加深刻。
