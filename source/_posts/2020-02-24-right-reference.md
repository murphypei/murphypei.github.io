---
title: C++ 右值引用使用总结
date: 2020-02-24 19:38:13
update: 2020-02-24 19:38:13
categories: C/C++
tags: [C++11, 移动, 完美转发, 右值引用]
---

一篇关于 C++11 右值引用的一篇总结，觉得其中对于常见误用的总结很不错，想起来了当年自己走过的一些坑，转载做个记录。

<!-- more -->

### 写在前面

> 如果你还不知道 C++ 11 引入的右值引用是什么，可以读读这篇文章，看看有什么 **启发**；如果你已经对右值引用了如指掌，也可以读读这篇文章，看看有什么 **补充**。欢迎交流~ 

尽管 C++ 17 标准已经发布了，很多人还不熟悉 C++ 11 的 **右值引用/移动语义/拷贝省略/通用引用/完美转发** 等概念，甚至对一些细节 **有所误解**（包括我）。

本文将以最短的篇幅，一步步解释 关于右值引用的 **为什么/是什么/怎么做**。先分享几个我曾经犯过的错误。

#### 误解1：返回前，移动局部变量

> [ES.56: Write `std::move()` only when you need to explicitly move an object to another scope](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Res-move)

```cpp
std::string base_url = tag->GetBaseUrl();
if (!base_url.empty()) {
  UpdateQueryUrl(std::move(base_url) + "&q=" + word_);
}
LOG(INFO) << base_url;  // |base_url| may be moved-from
```

上述代码的问题在于：使用 `std::move()` 移动局部变量 `base_url`，会导致后续代码不能使用该变量；如果使用，会出现 **未定义行为** *(undefined behavior)*（参考：[`std::basic_string(basic_string&&)`](https://en.cppreference.com/w/cpp/string/basic_string/basic_string)）。

如何检查 **移动后使用** *(use after move)*：

* 运行时，在 移动构造/移动赋值 函数中，将被移动的值设置为无效状态，并在每次使用前检查有效性
* 编译时，使用 Clang 标记对移动语义进行静态检查（参考：[Consumed Annotation Checking | Attributes in Clang](https://clang.llvm.org/docs/AttributeReference.html#consumed-annotation-checking)）

#### 误解2：被移动的值不能再使用

> [C.64: A move operation should move and leave its source in a valid state](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-move-semantic)

很多人认为：被移动的值会进入一个 **非法状态** *(invalid state)*，对应的 **内存不能再访问**。

其实，C++ 标准要求对象 遵守 [§ 3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动语义) **移动语义** —— 被移动的对象进入一个 **合法但未指定状态** *(valid but unspecified state)*，调用该对象的方法（包括析构函数）不会出现异常，甚至在重新赋值后可以继续使用：

```cpp
auto p = std::make_unique<int>(1);
auto q = std::move(p);

assert(p == nullptr);  // OK: reset to default
p.reset(new int{2});   // or p = std::make_unique<int>(2);
assert(*p == 2);       // OK: reset to int*(2)
```

另外，基本类型（例如 `int/double`）的移动语义 和拷贝相同：

```cpp
int i = 1;
int j = std::move(i);

assert(i == j);
```

#### 误解3：移动非引用返回值

> [F.48: Don’t `return std::move(local)`](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rf-return-move-local)

```cpp
std::unique_ptr<int> foo() {
  auto ret = std::make_unique<int>(1);
  //...
  return std::move(ret);  // -> return ret;
}
```

上述代码的问题在于：没必要使用 `std::move()` 移动非引用返回值。

C++ 会把即将离开作用域的 **非引用类型的** 返回值当成 **右值**（参考 [§ 2.1](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#值类别-vs-变量类型)），对返回的对象进行 [§ 3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动语义) 移动构造（语言标准）；如果编译器允许 [§ 4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#拷贝省略) 拷贝省略，还可以省略这一步的构造，直接把 `ret` 存放到返回值的内存里（编译器优化）。

> Never apply `std::move()` or `std::forward()` to local objects if they would otherwise be eligible for the return value optimization. —— Scott Meyers, *Effective Modern C++*

另外，误用 `std::move()` 会 **阻止** 编译器的拷贝省略 **优化**。不过聪明的 Clang 会提示 [`-Wpessimizing-move`/`-Wredundant-move`](https://developers.redhat.com/blog/2019/04/12/understanding-when-not-to-stdmove-in-c/) 警告。

#### 误解4：不移动右值引用参数

> [F.18: For “will-move-from” parameters, pass by `X&&` and `std::move()` the parameter](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rf-consume)

```cpp
std::unique_ptr<int> bar(std::unique_ptr<int>&& val) {
  //...
  return val;    // not compile
                 // -> return std::move/forward(val);
}
```

上述代码的问题在于：没有对返回值使用 `std::move()`（编译器提示 `std::unique_ptr(const std::unique_ptr&) = delete` 错误）。

> [If-it-has-a-name Rule](http://thbecker.net/articles/rvalue_references/section_05.html#no_name):
>
> * Named rvalue references are lvalues.
> * Unnamed rvalue references are rvalues.

因为不论 **左值引用** 还是 **右值引用** 的变量（或参数）在初始化后，都是左值（参考 [§ 2.1](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#值类别-vs-变量类型)）：

* **命名的右值引用** *(named rvalue reference)* **变量** 是 **左值**，但变量类型却是 **右值引用**。
* 在作用域内，**左值变量** 可以通过 **变量名** *(variable name)* **被取地址、被赋值**。

所以，返回右值引用变量时，需要使用 `std::move()`/`std::forward()` 显式的 [§ 5.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动转发) **移动转发** 或 [§ 5.3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#完美转发) **完美转发**，将变量 “还原” 为右值（右值引用类型）。

> 这里补充一下，这里说的是右值引用的变量，常见于函数的参数，函数参数传递会导致外面的右值引用进入函数内部作为参数变成了左值变量。

#### 误解5：手写错误的移动构造函数

> [C.20: If you can avoid defining default operations, do](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-zero)
>
> [C.21: If you define or `=delete` any default operation, define or `=delete` them all](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-five)
>
> [C.80: Use `=default` if you have to be explicit about using the default semantics](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-eqdefault)
>
> [C.66: Make move operations `noexcept`](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-move-noexcept)

实际上，多数情况下：

* 如果 **没有定义** 拷贝构造/拷贝赋值/移动构造/移动赋值/析构 函数的任何一个，编译器会 **自动生成** 移动构造/移动赋值 函数（[rule of zero](https://en.cppreference.com/w/cpp/language/rule_of_three#Rule_of_zero)）
* 如果 **需要定义** 拷贝构造/拷贝赋值/移动构造/移动赋值/析构 函数的任何一个，不要忘了 移动构造/移动赋值 函数，否则对象会 **不可移动**（[rule of five](https://en.cppreference.com/w/cpp/language/rule_of_three#Rule_of_five)）
* **尽量使用** `=default` 让编译器生成 移动构造/移动赋值 函数，否则 **容易写错**
* 如果 **需要自定义** 移动构造/移动赋值 函数，尽量定义为 `noexcept` 不抛出异常（编译器生成的版本会自动添加），否则 **不能高效** 使用标准库和语言工具

例如，标准库容器 `std::vector` 在扩容时，会通过 [`std::vector::reserve()`](https://en.cppreference.com/w/cpp/container/vector/reserve#Exceptions) 重新分配空间，并转移已有元素。如果扩容失败，`std::vector` 满足 [**强异常保证** *(strong exception guarantee)*](https://en.cppreference.com/w/cpp/language/exceptions#Exception_safety)，可以回滚到失败前的状态。

为此，`std::vector` 使用 [`std::move_if_noexcept()`](https://en.cppreference.com/w/cpp/utility/move_if_noexcept) 进行元素的转移操作：

* 优先 使用 `noexcept` 移动构造函数（高效；不抛出异常）
* 其次 使用 拷贝构造函数（低效；如果异常，可以回滚）
* 再次 使用 非 `noexcept` 移动构造函数（高效；如果异常，**无法回滚**）
* 最后 如果 不可拷贝、不可移动，**编译失败**

如果 没有定义移动构造函数或自定义的移动构造函数没有 `noexcept`，会导致 `std::vector` 扩容时执行无用的拷贝，**不易发现**。

### 基础知识

之所以会出现上边的误解，往往是因为 C++ 语言的复杂性和使用者对基础知识的掌握程度不匹配。

#### 值类别 vs 变量类型

**划重点** —— **值** *(value)* 和 **变量** *(variable)* 是两个独立的概念：

* 值只有 **类别** *(category)* 的划分，变量 只有 **类型** *(type)* 的划分 😵
* 值不一定拥有 **身份** *(identity)*，也不一定拥有 变量名（例如 表达式中间结果 `i + j + k`）

[**值类别** *(value category)*](https://en.cppreference.com/w/cpp/language/value_category) 可以分为两种：

* **左值** *(lvalue, left value)* 是能被取地址、不能被移动的值
* **右值** *(rvalue, right value)* 是表达式中间结果/函数返回值（可能拥有变量名，也可能没有）

> C++ 17 细化了 `prvalue/xvalue/lvalue` 和 `rvalue/glvalue` 类别，本文不详细讨论。

[**引用类型** *(reference type)*](https://en.cppreference.com/w/cpp/language/reference) 属于一种 [**变量类型** *(variable type)*](https://en.cppreference.com/w/cpp/language/type)，将在 [§ 2.2](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#左值引用-vs-右值引用-vs-常引用) 详细讨论。

在变量 [**初始化** *(initialization)*](https://en.cppreference.com/w/cpp/language/initialization) 时，需要将 **初始值** *(initial value)* 绑定到变量上；但 [**引用类型变量** 的初始化](https://en.cppreference.com/w/cpp/language/reference_initialization) 和其他的值类型（非引用类型）变量不同：

* 创建时，**必须显式初始化**（和指针不同，不允许 **空引用** *(null reference)*；但可能存在 **悬垂引用** *(dangling reference)*）
* 相当于是 其引用的值 的一个 **别名** *(alias)*（例如，对引用变量的 **赋值运算** *(assignment operation)* 会赋值到 其引用的值 上）
* 一旦绑定了初始值，就 **不能重新绑定** 到其他值上了（和指针不同，赋值运算不能修改引用的指向；而对于 Java/JavaScript 等语言，对引用变量赋值 可以重新绑定）

#### 左值引用 vs 右值引用 vs 常引用

引用类型 可以分为两种：

* **左值引用** *(l-ref, lvalue reference)* 用 `&` 符号引用 左值（但不能引用右值）
* **右值引用** *(r-ref, rvalue reference)* 用 `&&` 符号引用 右值（也可以移动左值）

```cpp
void f(Data&  data);  // 1, data is l-ref
void f(Data&& data);  // 2, data is r-ref
Data   data;

Data&  data1 = data;             // OK
Data&  data1 = Data{};           // not compile: invalid binding
Data&& data2 = Data{};           // OK
Data&& data2 = data;             // not compile: invalid binding
Data&& data2 = std::move(data);  // OK

f(data);    // 1, data is lvalue
f(Data{});  // 2, data is rvalue
f(data1);   // 1, data1 is l-ref type and lvalue
f(data2);   // 1, data2 is r-ref type but lvalue
```

* 左值引用变量 `data1` 在初始化时，不能绑定右值 `Data{}`
* 右值引用变量 `data2` 在初始化时，不能绑定左值 `data`，但可以通过 `std::move()` 将左值 **转为右值引用**（参考 [§ 5.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动转发)）
* **右值引用** 变量 `data2` 被初始化后，在作用域内是 **左值**（参考 [§ 1.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-不移动右值引用参数)），所以匹配 `f()` 的 **重载 2**

另外，C++ 还支持了 **常引用** *(c-ref, const reference)*，**同时接受** 左值/右值 进行初始化：

```cpp
void g(const Data& data);  // data is c-ref

g(data);    // ok, data is lvalue
g(Data{});  // ok, data is rvalue
```

常引用和右值引用 都能接受右值的绑定，有什么区别呢？

* 通过 右值引用/常引用 初始化的右值，都可以将 [**生命周期扩展** *(lifetime extension)*](https://en.cppreference.com/w/cpp/language/reference_initialization#Lifetime_of_a_temporary) 到 绑定该右值的 引用的生命周期
* 初始化时 绑定了右值后，右值引用 **可以修改** 引用的右值，而 常引用 不能修改

```cpp
const Data& data1 = Data{};   // OK: extend lifetime
data1.modify();               // not compile: const

Data&& data2 = Data{};        // OK: extend lifetime
data2.modify();               // OK: non-const
```

#### 引用参数重载优先级

如果函数重载同时接受 右值引用/常引用 参数，编译器 **优先重载** 右值引用参数 —— 是 [§ 3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动语义) 移动语义 的实现基础：

```cpp
void f(const Data& data);  // 1, data is c-ref
void f(Data&& data);       // 2, data is r-ref

f(Data{});  // 2, prefer 2 over 1 for rvalue
```

针对不同左右值 **实参** *(argument)* 重载 引用类型 **形参** *(parameter)* 的优先级如下：

|  实参/形参   |  T&  | const T& | T&&  | const T&& |
| :----------: | :--: | :------: | :--: | :-------: |
|    lvalue    |  1   |    2     |      |           |
| const lvalue |      |    1     |      |           |
|    rvalue    |      |    3     |  1   |     2     |
| const rvalue |      |    2     |      |     1     |

* 数值越小，优先级越高；如果不存在，则重载失败
* 如果同时存在 **传值** *(by value)* 重载（接受值类型参数 `T`），会和上述 **传引用** *(by reference)* 重载产生歧义，编译失败
* **常右值引用** *(const rvalue reference)* `const T&&` 一般不直接使用（[参考](https://codesynthesis.com/~boris/blog/2012/07/24/const-rvalue-references/)）

#### 引用折叠

[**引用折叠** *(reference collapsing)*](https://en.cppreference.com/w/cpp/language/reference#Reference_collapsing) 是 [§ 5.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动转发) `std::move()` 和 [§ 5.3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#完美转发) `std::forward()` 的实现基础：

```cpp
using Lref = Data&;
using Rref = Data&&;
Data data;

Lref&  r1 = data;    // r1 is Data&
Lref&& r2 = data;    // r2 is Data&
Rref&  r3 = data;    // r3 is Data&
Rref&& r4 = Data{};  // r4 is Data&&
```

### 移动语义

在 C++ 11 强化了左右值概念后，提出了 **移动语义** *(move semantic)* 优化：由于右值对象一般是临时对象，在移动时，对象包含的资源 **不需要先拷贝再删除**，只需要直接 **从旧对象移动到新对象**。

同时，要求 **被移动的对象** 处于 **合法但未指定状态**（参考 [§ 1.2](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-被移动的值不能再使用)）：

* （基本要求）能正确析构（不会重复释放已经被移动了的资源，例如 `std::unique_ptr::~unique_ptr()` 检查指针是否需要 `delete`）
* （一般要求）重新赋值后，和新的对象没有差别（C++ 标准库基于这个假设）
* （更高要求）恢复为默认值（例如 `std::unique_ptr` 恢复为 `nullptr`）

由于**基本类型不包含资源，其移动和拷贝相同：被移动后，保持为原有值**。

#### 避免先拷贝再释放资源

一般通过 **重载构造/赋值函数** 实现移动语义。例如，`std::vector` 有：

* 以常引用作为参数的 **拷贝构造函数** *(copy constructor)*
* 以右值引用作为参数的 **移动构造函数** *(move constructor)*

```cpp
template<typename T>
class vector {
 public:
  vector(const vector& rhs);      // copy data
  vector(vector&& rhs) noexcept;  // move data
  ~vector();                      // dtor
 private:
  T* data_ = nullptr;
  size_t size_ = 0;
};

vector::vector(const vector& rhs) : data_(new T[rhs.size_]) {
  auto &lhs = *this;
  lhs.size_ = rhs.size_;
  std::copy_n(rhs.data_, rhs.size_, lhs.data_);  // copy data
}

vector::vector(vector&& rhs) noexcept {
  auto &lhs = *this;
  lhs.size_ = rhs.size_;
  lhs.data_ = rhs.data_;  // move data
  rhs.size_ = 0;
  rhs.data_ = nullptr;    // set data of rhs to null
}

vector::~vector() {
  if (data_)              // release only if owned
    delete[] data_;
}
```

上述代码中，构造函数 `vector::vector()` 根据实参判断（重载优先级参考 [§ 2.3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#引用参数重载优先级)）：

* 实参为左值时，拷贝构造，使用 `new[]`/`std::copy_n` 拷贝原对象的所有元素（本方案有一次冗余的默认构造，仅用于演示）。
* 实参为右值时，移动构造，把指向原对象内存的指针 `data_`、内存大小 `size_` 拷贝到新对象，并把原对象这两个成员置 `0`。

析构函数 `vector::~vector()` 检查 data_ 是否有效，决定是否需要释放资源。

> 此处省略 拷贝赋值/移动赋值 函数，但建议加上。（参考 [§ 1.5](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-手写错误的移动构造函数)）

此外，**类的成员函数** 还可以通过 [**引用限定符** *(reference qualifier)*](https://en.cppreference.com/w/cpp/language/member_functions#const-.2C_volatile-.2C_and_ref-qualified_member_functions)，针对当前对象本身的左右值状态（以及 const-volatile）重载：

```cpp
class Foo {
 public:
  Data data() && { return std::move(data_); }  // rvalue, move-out
  Data data() const& { return data_; }         // otherwise, copy
};

auto ret1 = foo.data();    // foo   is lvalue, copy
auto ret2 = Foo{}.data();  // Foo{} is rvalue, move
```

#### 转移不可拷贝的资源

> 在之前写的 [资源管理小记](https://bot-man-jl.github.io/articles/?post=2018/Resource-Management#资源和对象的映射关系) 提到：如果资源是 **不可拷贝** *(non-copyable)* 的，那么装载资源的对象也应该是不可拷贝的。

如果资源对象不可拷贝，一般需要定义 移动构造/移动赋值 函数，并禁用 拷贝构造/拷贝赋值 函数。例如，智能指针 `std::unique_ptr` **只能移动** *(move only)*：

```cpp
template<typename T>
class unique_ptr {
 public:
  unique_ptr(const unique_ptr& rhs) = delete;
  unique_ptr(unique_ptr&& rhs) noexcept;  // move only
 private:
  T* data_ = nullptr;
};

unique_ptr::unique_ptr(unique_ptr&& rhs) noexcept {
  auto &lhs = *this;
  lhs.data_ = rhs.data_;
  rhs.data_ = nullptr;
}
```

上述代码中，`unique_ptr` 的移动构造过程和 `vector` 类似：

* 把指向原对象内存的指针 `data_` 拷贝到新对象
* 把原对象的指针 `data_` 置为空

#### 反例：不遵守移动语义

移动语义只是语言上的一个 **概念**，具体是否移动对象的资源、如何移动对象的资源，都需要通过编写代码 **实现**。而移动语义常常被 **误认为**，编译器 **自动生成** 移动对象本身的代码（[§ 4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#拷贝省略) 拷贝省略）。

为了证明这一点，我们可以实现不遵守移动语义的 `bad_vec::bad_vec(bad_vec&& rhs)`，执行拷贝语义：

```cpp
bad_vec::bad_vec(bad_vec&& rhs) : data_(new T[rhs.size_]) {
  auto &lhs = *this;
  lhs.size_ = rhs.size_;
  std::copy_n(rhs.data_, rhs.size_, lhs.data_);  // copy data
}
```

那么，一个 `bad_vec` 对象在被 `move` 移动后仍然可用：

```cpp
bad_vec<int> v_old { 0, 1, 2, 3 };
auto v_new = std::move(v_old);

v_old[0] = v_new[3];           // ok, but odd :-)
assert(v_old[0] != v_new[0]);
assert(v_old[0] == v_new[3]);
```

虽然代码可以那么写，但是在语义上有问题：进行了拷贝操作，违背了移动语义的初衷。

### 拷贝省略

尽管 C++ 引入了移动语义，移动的过程 仍有优化的空间 —— 与其调用一次 没有意义的移动构造函数，不如让编译器 直接跳过这个过程 —— 于是就有了 [拷贝省略 *(copy elision)*](https://en.cppreference.com/w/cpp/language/copy_elision)。

然而，很多人会把移动语义和拷贝省略 **混淆**：

* 移动语义是 **语言标准** 提出的概念，通过编写遵守移动语义的 移动构造函数、右值限定成员函数，**逻辑上** 优化 **对象内资源** 的转移流程
* 拷贝省略是（C++ 17 前）非标准的 **编译器优化**，跳过移动/拷贝构造函数，让编译器直接在 **移动后的对象** 内存上，构造 **被移动的对象**（例如 [§ 1.3](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-移动非引用返回值) 的代码，直接在 函数返回值对象 的内存上，构造 函数局部对象 `ret` —— 在 **不同作用域** 里，共享 **同一块内存**）

C++ 17 要求编译器对 **纯右值** *(prvalue, pure rvalue)* 进行拷贝省略优化。（[参考](https://jonasdevlieghere.com/guaranteed-copy-elision/)）

```cpp
Data f() {
  Data val;
  // ...
  throw val;
  // ...
  return val;

  // NRVO from lvalue to ret (not guaranteed)
  // if NRVO is disabled, move ctor is called
}

void g(Date arg);

Data v = f();     // copy elision from prvalue (C++ 17)
g(f());           // copy elision from prvalue (C++ 17)
```

初始化 局部变量、函数参数时，传入的纯右值可以确保被优化 —— Return Value Optimization *(RVO)*；而返回的 **将亡值** *(xvalue, eXpiring value)* 不保证被优化 —— Named Return Value Optimization *(NRVO)*。

### 通用引用和完美转发

> 揭示 `std::move()`/`std::forward()` 的原理，需要读者有一定的 **模板编程基础**。

#### 为什么需要通用引用

C++ 11 引入了变长模板的概念，允许向模板参数里传入不同类型的不定长引用参数。由于每个类型可能是左值引用或右值引用，针对所有可能的左右值引用组合，**特化所有模板** 是 **不现实的**。

**假设没有** 通用引用的概念，模板 [`std::make_unique<>`](https://en.cppreference.com/w/cpp/memory/unique_ptr/make_unique) 至少需要两个重载：

```cpp
template<typename T, typename... Args>
unique_ptr<T> make_unique(const Args&... args) {
  return unique_ptr<T> {
    new T { args... }
  };
}

template<typename T, typename... Args>
unique_ptr<T> make_unique(Args&&... args) {
  return unique_ptr<T> {
    new T { std::move<Args>(args)... }
  };
}
```

* 对于传入的左值引用 `const Args&... args`，只要展开 `args...` 就可以转发这一组左值引用
* 对于传入的右值引用 `Args&&... args`，需要通过 [§ 5.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动转发) `std::move()` 转发出去，即 `std::move(args)...`（为什么要转发：参考 [§ 1.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-不移动右值引用参数)）

上述代码的问题在于：如果传入的 `args` **既有** 左值引用 **又有** 右值引用，那么这两个模板都 **无法匹配**。

#### 通用引用

> Item 24: Distinguish universal references from rvalue references. —— Scott Meyers, *Effective Modern C++*

[Scott Meyers 指出](https://isocpp.org/blog/2012/11/universal-references-in-c11-scott-meyers)：有时候符号 `&&` 并不一定代表右值引用，它也可能是左值引用 —— 如果一个引用符号需要通过 左右值类型推导（模板参数类型 或 `auto` 推导），那么这个符号可能是左值引用或右值引用 —— 这叫做 **通用引用** *(universal reference)*。

```cpp
// rvalue ref: no type deduction
void f1(Widget&& param1);
Widget&& var1 = Widget();
template<typename T> void f2(vector<T>&& param2);

// universal ref: type deduction
auto&& var2 = var1;
template<typename T> void f3(T&& param);
```

上述代码中，前三个 `&&` 符号不涉及引用符号的左右值类型推导，都是右值引用；而后两个 `&&` 符号会 **根据初始值推导左右值类型**：

* 对于 `var2`，因为 `var1` 是左值，所以 `var2` 也是左值引用
  * 推导不会参考 `var1` 的变量类型
* 对于 `T&&`：
  * 如果 `param` 传入左值，`T&&` 是左值引用 `std::remove_reference_t&`
  * 如果 `param` 传入右值，`T&&` 是右值引用 `std::remove_reference_t&&`

基于通用引用，[§ 5.1](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#为什么需要通用引用) 的模板 `std::make_unique<>` 只需要一个重载：

```cpp
template<typename T, typename... Args>
unique_ptr<T> make_unique(Args&&... args) {
  return unique_ptr<T> {
    new T { std::forward<Args>(args)... }
  };
}
```

其中，`std::forward()` 实现了 **针对不同左右值参数的转发** —— 完美转发。

> 这里就是完美转发真正的意义所在，会将形参的引用类型转发出去。

#### 完美转发

什么是 **完美转发** *(perfect forwarding)*：

* 如果参数是 **左值引用**，直接以 **左值引用** 的形式，转发给下一个函数
* 如果参数是 **右值引用**，要先 “还原” 为 **右值引用** 的形式，再转发给下一个函数

因此，[`std::forward()`](https://en.cppreference.com/w/cpp/utility/forward) 定义两个 **不涉及** 左右值类型 **推导** 的模板（不能使用 通用引用参数）：

```cpp
template <typename T>
T&& forward(std::remove_reference_t<T>& val) noexcept {  // #1
  // forward lvalue as either lvalue or rvalue
  return static_cast<T&&>(val);
}

template <typename T>
T&& forward(std::remove_reference_t<T>&& val) noexcept {  // #2
  // forward rvalue as rvalue (not lvalue)
  static_assert(!std::is_lvalue_reference_v<T>,
                "Cannot forward rvalue as lvalue.");
  return static_cast<T&&>(val);
}
```

| 实参/返回值 | 重载 | l-ref 返回值 | r-ref 返回值 |
| :---------: | :--: | :----------: | :----------: |
| l-ref 实参  |  #1  |   完美转发   | **移动转发** |
| r-ref 实参  |  #2  | **语义错误** |   完美转发   |

* 尽管初始化后的变量都是 **左值**（参考 [§ 1.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#误解-不移动右值引用参数)），但原始的 **变量类型** 仍会保留
* 因此，可以根据 **实参类型** 选择重载，**和模板参数 `T` 的类型无关**
* **返回值类型** `static_cast(val)` 经过模板参数 `T&&` [§ 2.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#引用折叠) 引用折叠 实现 完美转发/移动转发，**和实参类型无关**
* “将 l-ref 实参 转发为 r-ref 返回值” 等价于 [§ 5.4](https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference#移动转发) `std::move()` 移动转发

#### 移动转发

类似的，[`std::move()`](https://en.cppreference.com/w/cpp/utility/move) 只转发为右值引用类型：

```cpp
template <typename T>
std::remove_reference_t<T>&& move(T&& val) noexcept {
  // forward either lvalue or rvalue as rvalue
  return static_cast<std::remove_reference_t<T>&&>(val);
}
```

| 实参/返回值 |     r-ref 返回值     |
| :---------: | :------------------: |
| l-ref 实参  |       移动转发       |
| r-ref 实参  | 移动转发（完美转发） |

* 接受 通用引用模板参数 `T&&`（无需两个模板，使用时不区分 `T` 的引用类型）
* 返回值 `static_cast&&>(val)` 将实参 **转为将亡值**（右值引用类型）
* 所以 `std::move()` 等价于 `std::forward&&>()`

最后，`std::move()`/`std::forward()` 只是编译时的变量类型转换，不会产生目标代码。

### 参考资料

* 原文链接：https://bot-man-jl.github.io/articles/?post=2018/Cpp-Rvalue-Reference