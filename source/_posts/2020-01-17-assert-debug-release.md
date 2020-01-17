---
title: Assert 在 Debug 和 Release 引起的问题
date: 2020-01-17 16:56:49
update: 2020-01-17 16:56:49
categories: C++
tags: [C++, assert, 断言, debug, 宏]
---

在一次代码调试过程中，发现 Debug 和 Release 的结果不一致，由此引发的问题追溯...

<!-- more -->

因为 Debug 和 Release 不同，程序并没有报错，所以很容易想到是不是编译器做了什么操作导致编译的代码产生区别。

说实话，这次调试的过程是非常痛苦的，完全找不到头绪，最后通过一步步代码回退发现是 assert 的调用导致了问题。大概原理如下：

假设在一个循环中重复调用函数 `do_something`。这个函数在成功的情况下返回 0，失败则返回非 0 值。但是你完全不期望它在程序中
出现失败的情况。你可能会想这样写：

```C++
for (i = 0; i < 100; ++i)
  assert (do_something () == 0);
```

不过，你可能发现这个运行时检查引入了不可承受的性能损失，并因此决定稍候指定 NDEBUG 以禁用运行时检测（Release 编译就等同于此）。这样做的结果是整个对 assert 的调用会被完全删除，也就是说，assert 宏的条件表达式将永远不会被执行，`do_something` 一次也不会被调用。因此，**这样写才是正确的**：

```C++
for (i = 0; i < 100; ++i) {
  int status = do_something ();
  assert (status == 0);
}
```

进一步查询发现，在 `<cassert>` 头文件中，assert 的定义为：

```c++
#ifdef NDEBUG
#define assert(condition) ((void)0)
#else
#define assert(condition) /*implementation defined*/
#endif
```

也就是说 `assert` 语句在 Release 模式下是失效的...虽然程序继续运行了，但是结果不对。

这个问题弄了好久，但是说到底还是学艺不精，吃一堑长一智吧，记住 assert 的调用正确的写法，不过也可以牺牲部分性能定义一个检查的宏来代替 assert 的检查。
