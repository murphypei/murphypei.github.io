---
title: 阿里实习生编程测试题
categories: 求职
description: "记录阿里实习生编程测试"
tags: [C++, 阿里巴巴, 实习生, 编程测试]
---


### 题目要求：
小明在工作中需要为一种编码格式编写解码程序。这种编码格式会将整数0到1114111编码成1-4个字节

| 数值范围（十进制） | 编码（二进制） |
| :---: | :---: |
| 0-127 | 0xxxxxxx |
| 128-2047 | 110xxxxx 10xxxxxx |
| 2048 - 65535 | 1110xxxx 10xxxxxx 10xxxxxx|
| 65536-1114111 | 1110xxx 10xxxxxxx 10xxxxxx 10xxxxxx|

这个题目的意思是：

* 0~127可以用7位二进制来表示，然后前面加个0
* 128~2047可以用11位二进制表示（11位二进制最大表示2047），然后将前5位前面加上110，后6位前面加上10，再将二者组合成一个字符串。
* 依次类推....

代码的思路还是比较简单的，将输入的字符串表示的数字用二进制表示出来，然后加上相应的标识就行了。

```C++
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
using namespace std;


/** 请完成下面这个函数，实现题目要求的功能 **/
/** 当然，你也可以不按照这个模板来作答，完全按照自己的想法来 ^-^  **/
string Decode(string in)
{
	// 将输入字符串转换为数字，检查输入是否有效
	int num = 0;
	try
	{
		num = stoi(in);
	}
	catch (invalid_argument)
	{
		cerr << "Invalid_argument !" << endl;
		return "-1";
	}

	if (num > 1114111 || num < 0)
	{
		cerr << "The number is not in range !" << endl;
	}
	
	bitset<32> t = num;
	string bs = t.to_string();

	string result = "";
	if (num <= 127)
	{
		string t = bs.substr(bs.length() - 7, 7);
		result = "0" + t;
	}
	else if (num <= 2047)
	{
		string t1 = bs.substr(bs.length() - 11, 5);
		string t2 = bs.substr(bs.length() - 6, 6);
		result = "110" + t1 + "10" + t2;
	}
	else if (a <= 65535)
	{
		string t1 = bs.substr(bs.length() - 16, 4);
		string t2 = bs.substr(bs.length() - 12, 6);
		string t3 = bs.substr(bs.length() - 6, 6);
		result = "1110" + t1 + "10" + t2 + "10" + t3;
	}
	else
	{
		string t1 = bs.substr(bs.length() - 21, 3);
		string t2 = bs.substr(bs.length() - 18, 6);
		string t3 = bs.substr(bs.length() - 12, 6);
		string t4 = bs.substr(bs.length() - 6, 6);
		result = "11110" + t1 + "10" + t2 + "10" + t3 + "10" + t4;
	}

	return result;
}

int main()
{

	string res;

	string _in;
	getline(cin, _in);

	res = Decode(_in);
	cout << res << endl;

	getchar();
	return 0;
}
```
