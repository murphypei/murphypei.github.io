---
title: C++11 的随机数
date: 2019-10-30 17:46:32
update: 2019-10-30 17:46:32
categories: C/C++
tags: [C++, C++11, random, engine]
---

C++11 带来了丰富便捷的随机数生成方法。

<!-- more -->

C++11 的随机数分为三个层次，下面分别叙述。

### 产生随机数

标准库提供了一个**非确定性随机数**生成设备。在 Linux 的实现中，是读取 `/dev/urandom` 设备；Windows 的实现是用`rand_s`，在这里强烈谴责一下。`random_device` 提供 `()` 操作符，用来返回一个 `min()` 到 `max()` 之间的一个数字。因此 Linux（包括类 Unix）下调用 `random_device()` 获取的是一个真随机数，Windows 是伪随机数。

```c++
#include <iostream>
#include <random>
int main()
{
  std::random_device rd;
  for(int n=0; n<20000; ++n)
    std::cout << rd() << std::endl;
  return 0; 
}
```

### 随机数引擎

C++ 中的均匀随机位生成器 (URBG) ，也就是随机数引擎是伪随机数生成器。这种随机数生成器传入一个种子，根据种子生成随机数，这也是我们最常见的一种随机数生成器。这种随机数引擎本质是一种算数算法，因此**相同的种子多次调用产生的随机数是完全相同的**。

标准提供三种常用的引擎：linear_congruential_engine，mersenne_twister_engine 和 subtract_with_carry_engine。第一种是线性同余算法，第二种是梅森旋转算法，第三种带进位的线性同余算法。第一种是最常用的，而且速度也是非常快的；第二种号称是最好的伪随机数生成器；第三种目前还不太清楚。

随机数引擎接受一个整形参数当作种子，不提供的话，会使用默认值。如果想多次运行产生相同的随机数，可以使用一个确定的数作为种子。如果是想每次运行生成不一样的随机数，Linux 推荐使用 `random_device` 来产生一个随机数当作种子，windows 产生一个伪随机数作为种子吧。

```c++
#include <iostream>
#include <random>

int main()
{
  std::random_device rd;
  std::mt19937 mt(rd());	// 梅森旋转算法
  for(int n = 0; n < 10; n++)
    std::cout << mt() << std::endl;
  return 0;
}
```

### 随机分布

STL 标准库还提供各种各样的随机分布，不过我们经常用的比较少，比如平均分布，正太分布...使用也很简单。随机分布是利用一定的算法处理 URBG 的输出，以使得输出结果按照定义的统计概率密度函数分布。

```c++
//平均分布
#include <random>
#include <iostream>
int main()
{
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1, 6);
    for(int n=0; n<10; ++n)
        std::cout << dis(gen) << ' ';
    std::cout << '\n';
}
```

```c++
//正太分布
#include <iostream>
#include <iomanip>
#include <string>
#include <map>
#include <random>
#include <cmath>
int main()
{
    std::random_device rd;
    std::mt19937 gen(rd());
 
    // values near the mean are the most likely
    // standard deviation affects the dispersion of generated values from the mean
    std::normal_distribution<> d(5,2);
 
    std::map<int, int> hist;
    for(int n=0; n<10000; ++n) {
        ++hist[std::round(d(gen))];
    }
    for(auto p : hist) {
        std::cout << std::fixed << std::setprecision(1) << std::setw(2)
                  << p.first << ' ' << std::string(p.second/200, '*') << '\n';
    }
}
```