---
title: C++ struct 位域
date: 2019-06-11 15:58:43
update: 2019-06-11 15:58:43
categories: C++
tags: [C++, struct, bit fields, 位域]
---

位域(Bit field)为一种数据结构，可以把数据以位的形式紧凑的储存，并允许程序员对此结构的位进行操作。这种数据结构的一个好处是它可以使数据单元节省储存空间，当程序需要成千上万个数据单元时，这种方法就显得尤为重要。

<!-- more -->

## 位域的声明

位域使用以下的结构声明 , 该结构声明为每个位域成员设置名称，并决定其宽度。

```C++
struct bit_field_name
{
    type member_name : width;
};
```

例如声明如下一个位域:

```C++
struct _PRCODE
{
	unsigned int code1: 2;
	unsigned int cdde2: 2;
	unsigned int code3: 8;
};
struct _PRCODE prcode;
```

该定义使 `prcode` 包含 2 个 2 Bits 位域和 1 个 8 Bits 位域，我们可以使用结构体的成员运算符对其进行赋值：

```C++
prcode.code1 = 0;
prcode.code2 = 3;
procde.code3 = 102;
```

当然，赋值时要注意值的大小不能超过位域成员的容量，例如 `prcode.code3` 为 8 Bits 的位域成员，其容量为 2^8 = 256，即赋值范围应为 [0, 255]。

我第一次见到这种写法的时候很奇怪，查询了才知道了位域的用法。一般来说位域都是为了更好的使用内存，实际成员占据的内存大小就是位域声明的大小，比如我们使用 int，但是实际数的范围很小，没必要用很多位，所以才会这样做，移动端特别注重。注意，冒号后面的数字表示这个成员变量占用多少 bit，但是这个大小不能超过这个数据类型应该的大小。比如下述的声明就无效，编译不通过。

```C++
struct bits_B {
    int a:64;
};
```

## 位域的大小和对齐

### 位域的大小

```c++
struct box 
{
    unsigned int a: 1;
    unsigned int  : 3;
    unsigned int b: 4;
};
```

该位域结构体中间有一个未命名的位域，占据 3 Bits，**仅起填充作用，并无实际意义**。 填充使得该结构总共使用了 8 Bits。但 C 语言使用 unsigned int 作为位域的基本单位，即使一个结构的唯一成员为 1 Bit 的位域，该结构大小也和一个 unsigned int 大小相同（满足struct 大小是最大的成员变量大小的整数倍规则）。 有些系统中，unsigned int 为 16 Bits，在 x86 系统中为 32 Bits。文章以下均默认 unsigned int 为 32 Bits。

### 位域的对齐

**位域同样受 struct 的数据成员排列的规则限制（`sizeof` 的计算规则）**，也会产生一些填充和对齐。

比如上述说的，一个位域成员不允许跨越两个 unsigned int 的边界，如果成员声明的总位数超过了一个 unsigned int 的大小， 那么编辑器会自动移位位域成员，使其按照 unsigned int 的边界对齐。例如：

```c++
struct stuff 
{
	unsigned int field1: 30;
	unsigned int field2: 4;
	unsigned int field3: 3;
};
```

`field1` + `field2` = 34 Bits，超出 32 Bits, 编译器会将 `field2` 移位至下一个 unsigned int 单元存放， `stuff.field1` 和 `stuff.field2` 之间会留下一个 2 Bits 的空隙， `stuff.field3` 紧跟在 `stuff.field2` 之后，该结构现在大小为 2 * 32 = 64 Bits。

这个空洞可以用之前提到的未命名的位域成员填充，我们也可以**使用一个宽度为 0 的未命名位域成员令下一位域成员与下一个整数对齐**，这个用法很常用，也就是将前后两个位域成员分开存在不同的基本类型内存中。例如:

```c++
struct stuff 
{
	unsigned int field1: 30;
	unsigned int       : 2;
	unsigned int field2: 4;
	unsigned int       : 0;
	unsigned int field3: 3; 
};
```

这里 `stuff.field1` 与 `stuff.field2` 之间有一个 2 Bits 的空隙，`stuff.field3` 则存储在下一个 unsigned int 中，该结构现在大小为 3 * 32 = 96 Bits。

## 位域的初始化和位的重映射

### 位域的初始化

位域的初始化与普通结构体初始化的方法相同，这里列举两种，如下:

```C++
struct stuff s1= {20,8,6};

struct stuff s2;
s2.field1 = 20;
s2.field2 = 8;
s2.field3 = 4;
```

### 位域的重映射 (Re-mapping)

```C++
struct box {
	unsigned int ready:     2;
	unsigned int error:     2;
	unsigned int command:   4;
	unsigned int sector_no: 24;
}b1;
```

利用重映射将位域归零

```C++
int* p = (int *) &b1;  // 将 "位域结构体的地址" 映射至 "整形（int*) 的地址" 
*p = 0;                // 清除 s1，将各成员归零
```

### 利用联合 (union) 将 32 Bits 位域 重映射至 unsigned int 型

先简单介绍一下联合

> union 是一种特殊的类，也是一种构造类型的数据结构。在一个 union 内可以定义多种不同的数据类型， 一个被说明为该 union 类型的变量中，允许装入该 union 所定义的任何一种数据，这些数据共享同一段内存，以达到节省空间的目的。

> union 与 struct 有一些相似之处。但两者有本质上的不同。在结构中各成员有各自的内存空间， 一个结构变量的总长度是各成员长度之和（空结构除外，同时不考虑边界调整）。而在 union 中，各成员共享一段内存空间， 一个联合变量的长度等于各成员中最长的长度。应该说明的是，这里所谓的共享不是指把多个成员同时装入一个联合变量内， 而是指该联合变量可被赋予任一成员值，但每次只能赋一种值，**赋入新值则冲去旧值**。

```C++
union u_box {
  struct box st_box;     
  unsigned int ui_box;
};
```

x86 系统中 unsigned int 和 box 都为 32 Bits, 通过该联合使 st_box 和 ui_box 共享一块内存。具体位域中哪一位与 unsigned int 哪一位相对应，取决于编译器和硬件。利用联合将位域归零，代码如下：

```C++
union u_box u;
u.ui_box = 0;
```