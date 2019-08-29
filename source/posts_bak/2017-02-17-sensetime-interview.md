---
title: SenseTime 实习生面试
date: 2017-02-17
update: 2018-04-12
categories: 求职
tags: [实习生面试，sensetime，虚函数，memcpy]
---

商汤面试记录和总结

<!--more-->

前几天在 SenseTime 面试了实习生职位，求职意向主要是算法模块以及工程业务，也就是偏码农一些。之所以不想做纯算法研究，我觉得我是根据自己的兴趣来制定的职业规划，也希望自己能够做相对喜欢的工作。

技术面试官总共有三个，不过时间都不长，侧重点也不太一样。

* 第一个面试官是部门的项目负责人，主要聊了一下求职的意向和个人的能力。会问以前实习的情况，会问项目以及擅长的领域。最后他了解到我想做工程业务，就直接拿了一套 `Linux/C++` 的题目来了。说一下题目：
    
    * 选择题有，关于虚函数的表述，`kill` 命令是通过什么实现的(信号、信号量、管道....）总之不难
    * Linux 下进程间通信的方式极其特征简述。（很重要，因为公司的业务关系吧）
    * 有一个填空题，不同基本类型，判断为 0 的方式（浮点型不是 0）
    * 代码题我觉得主要考察的 STL 的使用吧，vector 和 map 的元素操作（求和、插入、删除）。当然，能用 `<algorithm>` 和 `iterator` 的地方都要用吧。从面试官的话中，我感觉他可能也是想这样做。
    * 问了一个删除 `iterator` 后，此 `iterator` 是否还有效？我认为被回收进垃圾区了，无效。  

* 第二个面试官可能是主管工程业务的。根据描述来看，我如果入职，可能就是跟他。这部分工作主要打包算法给上层应用来使用，感觉像写中间件？接触的最多的是 TCP/IP（结果他没问我），问的问题主要还是个人简介、项目、经历等等。非项目技术问题有：进程和线程的区别（**分布式情况下只能使用进程来通信，另外进程相对线程稳定，一个线程挂了，线程所在进程都挂了**。这些点我答的不全，其余的区别基本说道了）、C++ 虚函数和多态的具体实现（虚表和虚指针的工作方式）、继承会不会覆盖虚函数等等。

* 第三个面试官可能时间比较急，和前面一样，自我介绍、项目、实习等等。然后就让我实现一下 memcpy 函数的功能，并写一个单元测试例子....我从没写过单元测试，我记录这篇文章也主要是想把这两个题记录一下。当然，实现参考网上的了。

**memcpy 函数实现**

重点就在于，地址重叠情况下，需要分清从前往后拷贝和从后往前拷贝两种情况

```c++
void* my_memcpy(void *dst, const void *src, size_t size) {
    char *psrc;
    char *pdst;
    if(NULL == dst || NULL == src) {
        return NULL;
    }
    
    if((src < dst) || ((char*)src + size > (char*)dst) {         // 从后向前拷贝
        psrc = (char*)src + size - 1;
        pdst = (char*)dst + size - 1;
        while(size--) {
            *pdst-- = *psrc--;
        }
    }
    else {
        psrc = (char*)src;
        pdst = (char*)dst;
        while(size--) {
            *pdst++ = *psrc++;
        }
    }
    
    return dst;
}
```

**测试用例**

```c++
void test() {
    char p1[256] = "hello world";
    char p2[256] = {0};
    char *ptr;
    
    printf("destination before memcpy: %s/n",dst);  
    
    ptr=(char*)memcpy(dst, src, sizeof(src)/sizeof(char));   // 内存不存在覆盖
    ptr=(char*)memcpy(dst+1,dst,2);                          // 内存存在覆盖 
    
    if (ptr){   
        printf("destination after memcpy: %s/n",ptr);   
    }   
    else{   
        printf("memcpy failed/n");   
    }   
    
    getch();   
    return 0;   
}
```
