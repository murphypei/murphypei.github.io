---
title: C++中条件编译
date: 2018-08-17 09:19:44
update: 2018-08-17 09:19:44
categories: C++
tags: [C++, if, ifdef, t条件编译]
---

C++中常用常用`#ifdef`，`#if`和`#endif`来控制头文件的编译变量检查，控制编译的代码区域。

<!--more-->

在C++中常用`#ifdef`，`#ifndef`和`#endif`来控制头文件的编译变量检查，另一方面，也可以方便控制代码的插入。

在实际应用中，除了`#ifdef`，`#ifndef`和`#endif`，还有一种更为强大的控制语句：`#if`和`#if defined()`。后者除了能够判断变量是否定义，还能将对变量的值进行检查并且**实现逻辑控制**

示例1：如果需要判断是否同时定义`MACRO_A`和`MACRO_B`

```cpp
#ifdef (MACRO_A)  
    #ifndef (MACRO_B)  
        ...;  
    #endif  
#end
```

```cpp
#if defined(MACRO_A) && !defined(MACRO_B)  
  ...;
#endif 
```

显然，后者更加方便，书写和阅读都更舒服。

除了更加方便，`#ifdef`、`#if defined()`和`#if`在使用上还有区别：

* 对于`#if`后面需要是一个表达式，如果表达式为1则调用#if下面的代码。

* 对于`#ifdef`后面需要的只是这个值有没有用#define定义，并不关心define的这个值是0还是1。

* `#if defined`和`#ifdef`用法一样，只不过多了逻辑表达式组合。

条件编译的指令总结如下：

* `#define`：定义一个预处理宏
* `#undef`：取消宏的定义
* `#if`：编译预处理中的条件命令，相当于C语法中的if语句
* `#ifdef`：判断某个宏是否被定义，若已定义，执行随后的语句
* `#ifndef`：与#ifdef相反，判断某个宏是否未被定义
* `#elif`：若#if, #ifdef, #ifndef或前面的#elif条件不满足，则执行#elif之后的语句，相当于C语法中的else-if
* `#else`：与#if, #ifdef, #ifndef对应, 若这些条件不满足，则执行#else之后的语句，相当于C语法中的else
* `#endif`：#if, #ifdef, #ifndef这些条件命令的结束标志.
* `defined`：与#if, #elif配合使用，判断某个宏是否被定义