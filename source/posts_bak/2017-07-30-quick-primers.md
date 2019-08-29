---
layout: post
title: 快速求素数序列方法
date: 2017-07-30
update: 2018-04-12
categories: 算法
tags: [算法, 素数序列, primer]
---

快速求素数序列方法

<!--more-->

**定理：如果n不是素数，则n有一个素数因子d，并且满足： 1 < d <= sqrt(n)**

证明：如果n不是素数, 则由定义，n有一个因子d满足： 1 < d < n，如果d大于sqrt(n), 则n/d是满足1<n/d<=sqrt(n)的一个因子，根据因式分解，如果d不是素数，则d可以分解，最终得到一个n的素数因子

这样的话就可以直接定义一个素数序列来判断了，而不用逐一或者逐二（跳过偶数）来寻找因子

```c++
#include "cstdio"  
  
#define N 50  
  
int main()  
{  
    int primes[N];  
    int pc, m, k;  
  
    //clrscr();  
    printf("\n The first %d prime number are: \n", N);  
    // 构造素数序列  
    primes[0] = 2;  
    // 计数器  
    pc = 1;  
    // 从3开始寻找  
    m = 3;  
    while(pc < N)  
    {  
        k = 0;  
        // m若不为素数，必有一个素数因子小于m，则这个因子一定在primes数组序列中  
        while(primes[k] * primes[k] <= m)  
        {  
            // 找到一个素数，则m加2，跳过偶数  
            if(m % primes[k] == 0)  
            {  
                m += 2;  
                k = 1;  
            }  
            else  
                k++;  
        }  
        // 找不到素数因子，则说明m是素数，添加入素数序列，然后m加2，继续寻找  
        primes[pc++] = m;  
        m += 2;  
    }  
      
    for(k = 0; k < pc; k++)  
        printf("%4d", primes[k]);  
    printf("\n\n Press any key to quit...\n ");  
    getchar();  
}
```