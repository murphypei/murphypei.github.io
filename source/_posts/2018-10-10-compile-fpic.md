---
title: fPIC编译简介
date: 2018-10-10 16:46:46
update: 2018-10-10 16:46:46
categories: C++
tags: [Linux, C++, 编译, 链接]
---

fPIC是C++编译中使用较多的编译选项，而且CMake甚至在一些场景中默认强制使用这个编译选项，本文对Linux编程的fPIC编译参数进行汇总备忘。

<!--more-->

### fPIC的使用

在Linux系统中，动态链接文件称为动态共享对象（DSO，Dynamic Shared Objects），简称共享对象，一般是以.so为扩展名的文件。在Windows系统中，则称为动态链接库（Dynamic Linking Library），很多以.dll为扩展名。这里只备忘Linux的共享对象。

在实现一共享对象时，最一般的编译链接命令行为：
```sh 
 g++ -fPIC -shared test.cc -o lib.so
```

或者是：
```sh
g++ -fPIC test.cpp -c -o test.o
ld -shared test.o -o lib.so
```

上面的命令行中-shared表明产生共享库，而-fPIC则表明使用地址无关代码。PIC：Position Independent Code，作用于编译阶段，告诉编译器产生与位置无关代码。

**Linux下编译共享库时，必须加上-fPIC参数，否则在链接时会有错误提示**（有资料说AMD64的机器才会出现这种错误，但我在Inter的机器上也出现了）：
```
/usr/bin/ld: test.o: relocation R_X86_64_32 against `a local symbol' can not be used when making a shared object; recompile with -fPIC
test.o: could not read symbols: Bad value
collect2: ld returned 1 exit status
```

在Linux系统中如何确认一个共享对象是PIC呢？使用下述命令
```sh
readelf -d foo.so | grep TEXTREL
```

如果上边的shell有任何输出，则说明这foo.so不是PIC。TEXTREL表示代码段重定位表地址，PIC的共享对象不会包含任何代码段重定位表。

### fPIC的作用

fPIC的目的是什么？我们知道，共享对象可能会被不同的进程加载到不同的位置上，如果共享对象中的指令使用了绝对地址、外部模块地址，那么在共享对象被加载时就必须根据相关模块的加载位置对这个地址做调整，也就是修改这些地址，让它在对应进程中能正确访问，而被修改到的段就不能实现多进程共享一份物理内存，它们在每个进程中都必须有一份物理内存的拷贝。**fPIC指令就是为了让使用到同一个共享对象的多个进程能尽可能多的共享物理内存，它背后把那些涉及到绝对地址、外部模块地址访问的地方都抽离出来，保证代码段的内容可以多进程相同，实现共享。**

抽离出这部分特殊的指令、地址之后，放到了一个叫做**GOT（Global Offset Table）的地方，它放在数据段中，每一个进程都有独立的一份，里面的内容可能是变量的地址、函数的地址，不同进程它的内容很可能是不同的**，这部分就是被隔离开的“地址相关”内容。模块被加载的时候，会把GOT表的内容填充好（在没有延迟绑定的情况下）。代码段要访问到GOT时，通过类似于window的call/pop/sub指令得到GOT对应项的地址。

对于模块中全局变量的访问，为了解决可执行文件跟模块可能拥有同一个全局变量的问题（此时，模块内的全局变量会被覆盖为可执行文件中的全局变量），对模块中的全局变量访问也通过GOT间接访问。

这样子，每一次访问全局变量、外部函数都需要去计算在GOT中的位置，然后再通过对应项的值访问变量、调用函数。**从运行性能上来说，比装载时重定位要差点。装载时重定位就是不使用fPIC参数，代码段需要一个重定位表，在装载时修正所有特殊地址，以后运行时不需要再有GOT位置计算和间接访问。**（但是，在有些测试中，编译链接共享库时，没法不使用fPIC参数，可能多数系统都要求必须有fPIC）。

### 延迟绑定

如果在装载时就去计算GOT的内容，那么会影响加载速度，于是就有了延迟绑定（Lazy Binding），直到用时才去填充GOT。它使用到了PLT（Procedure Linkage Table）：每一项都是一小段代码，对应于本运行模块要引用的函数。函数调用时，先到这里，然后再到GOT。在函数第一次被调用时，进入PLT跳到加载器，加载器计算函数的真正地址，然后将地址写入GOT对应项，以后的调用就直接从PLT跳到GOT记录的函数位置。这样也减少了运行时多次调用多次计算GOT位置。

PIC的共享对象也会有重定位表，数据段中的GOT、数据的绝对地址引用，这些都是需要重定位的。
```
readelf -r Lib.so
```

可以看到共享对象的重定位表，.rel.dyn是对数据引用的修正，.rel.plt是对函数引用的修正。
