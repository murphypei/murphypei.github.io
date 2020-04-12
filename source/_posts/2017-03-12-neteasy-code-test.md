---
title: 网易游戏暑期实习招聘编程实例
date: 2017-03-12
update: 2018-04-12
categories: 随笔
tags: [C++, 网易, 实习生, 笔试]
---

记录网易游戏暑期实习招聘笔试

<!--more-->

### 题目描述如下：

![neteasy_1](/images/posts/cplusplus/neteasy_shixi_1.jpg)
![neteasy_2](/images/posts/cplusplus/neteasy_shixi_2.jpg)
![neteasy_3](/images/posts/cplusplus/neteasy_shixi_3.jpg)

### 思路分析：

首先想到的就是遍历求解，通过递归的方法。

* 首先从最低位开始，每一位逐一分解整个数值（string表示）。
* 于每一位，总共有三个输入，add1，add2 和 sum，其中 sum 是已知的，add1 和 add2 要分情况讨论：
    * 两个都未知
    * 一个未知，一个确定
    * 两个确定（用来验证输入是否正确）
*  而对于 add1 和 add2 相加为 sum，每一位有两种情况：
    * 需要进位
    * 不需要进位
* 其他需要注意的：
    * 两个加数以及 sum 的可能长度不同，需要分情况讨论

**可以通过验证的代码** 

```c++
#include <iostream>
#include <vector>
#include <map>
#include <set>
#include <string>
#include <queue>
#include <stack>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <bitset>  
#include<sstream> 

using namespace std;

/**
 * @brief: 两个数不确定情况下，有无进位分别对应的可能结果
 * @param: num, sum对应位的数值
 * @param: isCarry, 有无进位
 */
int getnum(int num, bool isCarry)
{
    if (isCarry)
    {
        return 9 - num;
    }
    else
        return num - 1 >= 0 ? num - 1 : 0;
}

/*
* @brief: 主处理函数，输入两个加数和和，输出对应可能结果
* @param: s1, 加数1, 位数较长
* @param: s2, 加数2, 位数较短
* @param: sum, 和
 */
int fuc(string s1, string s2, string sum)
{
    if (s1.size() < s2.size())
    {
        return fuc(s2, s1, sum);
    }

    // s1和s3比较
    if (s2.size() == 0)
    {
        if (sum != "0" && s1.size() != sum.size())    // 错误
            return 0;
        else
        {
            bool flag = true;
            for (int i = 0; i < s1.size(); i++)        // 遍历s1和s3，判断可能存在的情况
            {
                if (s1[i] == 'x')                    // 能够匹配
                    continue;
                if (s1[i] != sum[i])                // 错误情况
                    flag = false;
            }
            if (flag)
                return 1;                            // 只能是对应位相等
            else
            {
                return 0;
            }
        }
    }

    // 取出三个数的最后一位（最低位）
    string s1Last = s1.substr(s1.size() - 1, 1);
    string s2Last = s2.substr(s2.size() - 1, 1);
    int intSumLast = atoi(sum.substr(sum.size() - 1, 1).c_str());

    // sum的剩余高位（-1表示有进位的情况下，相当于最低位+10）
    stringstream ss;
    ss << (atoi(sum.substr(0, sum.size() - 1).c_str()) - 1);
    string minuSum = ss.str();


    // 如果两个加数在最低位都是不确定的
    if (s1Last == "x" && s2Last == "x")
    {
        // 对于两个加数位均不确定的情况下，和所在位的值可以是不带进位和带进位的两种情况（举例，sum位值为3，那么两个加数对应位可以是相加为3或者13两种情况）
        return getnum(intSumLast, true)*fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), minuSum)
            + getnum(intSumLast, false)*fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), sum.substr(0, sum.size() - 1));

    }
    // 如果两个加数在最低位有一个是不确定的
    else if (s1Last == "x" || s2Last == "x")
    {
        // 取出已知的加数位的数值
        string nx = s1Last == "x" ? s2Last : s1Last;
        int intnxlast = atoi(nx.c_str());

        // 已知加数位的数值和sum的数值相等
        if (intnxlast == intSumLast) 
        {
            return 0;
        }
        // 已知位的数值小于sum的数值（不需要进位）
        else if (intnxlast < intSumLast)
        {
            return fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), sum.substr(0, sum.size() - 1));
        }
        // 已知位的数值大于sum的数值（需要进位）
        else
        {
            return fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), minuSum);
        }

    }
    // 当前位没有x，判断是否有进位
    else
    {
        int ints1last = atoi(s1Last.c_str());
        int ints2last = atoi(s2Last.c_str());
        // 输入有误，返回0
        if ((ints1last + ints2last) % 10 != intSumLast)
            return 0;
        
        // 分情况，同上
        if (ints1last + ints2last < 10)
        {
            return fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), sum.substr(0, sum.size() - 1));
        }
        else
        {
            return fuc(s1.substr(0, s1.size() - 1), s2.substr(0, s2.size() - 1), minuSum);
        }
    }
}

int main()
{
    int n;
    cin >> n;
    vector<int> results;
    for (int i = 0; i < n; i++)
    {
        string s1;
        string s2;
        string s3;
        cin >> s1;
        cin >> s2;
        cin >> s3;

        results.push_back(fuc(s1, s2, s3));
    }
    for (auto &i : results)
    {
        cout << i << endl;
    }
    getchar();

    return 0;
}
```

