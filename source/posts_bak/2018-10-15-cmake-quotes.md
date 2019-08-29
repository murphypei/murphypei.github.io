---
title: CMake中引号用法总结
date: 2018-10-15 16:46:46
update: 2018-10-15 16:46:46
categories: CMake
tags: [CMake, C++, 编译, 链接, 引号]
---

关于CMake中引号用法的小结

<!--more-->

## CMake中引号的用法

在CMake中定义和使用变量时，可以使用引号也可以不使用引号，并且它们会产生不同的结果。

### 定义变量时使用引号

例1：

```cmake
set(TITLE learn cmake quotes!)
message(${TITLE})

输出：
learncmakequotes!
```

可以看到字符串中间的空格没了，实际上，当我们不用引号定义变量的时候，相当于我们定义了一个包含多个成员的字符串数组，对于例1是：learn, cmake和quotes!。于是，当我们使用message输出的时候，其实是挨着输出了这5个元素，结果就是learncmakequotes!了。我们也可以用foreach验证下这个结果：

```cmake
foreach(e ${TITLE})
    message(${e})
endforeach()
```

### 使用变量时使用引号

对于例1中`${TITLE}`变量，如果使用引号，也会有不同的结果

例2：

```cmake
message("${TITLE")

输出：
learn;cmake;quotes!
```

因为此时${TITLE}还是一个数组，我们用`"${TITLE}"`这种形式的时候，表示要让CMake把这个数组的所有值当成一个整体，而不是分散的个体。于是，为了保持数组的含义，又提供一个整体的表达方式，CMake就会用;把这数组的多个值连接起来。无论是在CMake还是Shell里，用分号分割的字符串，形式上是一个字符串，但把它当成命令执行，就会被解析成多个用分号分割的部分。

对于单一的字符串变量(不包含特殊字符)，用不用引号，结果都是一样的。

### 定义变量时使用引号，使用的时候不用

**当使用引号时，这个值就是普通的字符层，不再是数组了。**

例3：

```cmake
set(TITLE "learn cmake quotes!")
message(${TITLE})
message("${TITLE}")

输出：
learn cmake quotes!
learn cmake quotes!
```

### 总结

* 引号对于CMake中变量的定义，其功能主要是当有空格的时候，区别变量时一个数组还是纯粹的字符串；
* 在使用的时候，对于普通字符串，加不加引号没什么区别，而对于数组，加引号会将数组以分号间隔输出，而不加引号则是直接拼接数组。
