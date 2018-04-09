---
layout: post
title: 排列组合算法(C++)
categories: 算法
description: "C++实现的排列组合算法"
tags: [C++, 排列组合, permucation, 算法]
---


排列和组合是两种不同的算法，排列所求的k个数，数的排序不同则为一种不同情况，总共有k!中可能情况

求全排列最常用的算法就是按照字典式排序(STL)，字典式排序从第一位开始找最小的数，然后依次找每一位能够存在的最小的数（和已存在的排列不重复），主要步骤如下（以123456为例）：

1. 第一个数是每一位能取到的最小的数，也就是123456
2. 从第二个数开始就按照以下算法来寻找：
	* 在上一个排列中， 找到最后一个连续两个数组成的**正序 **，比如123456，从后向前，56是正序，45，34，23，12都是正序，**最后一个正序是56**
	* 在正序组成的两个数中较小的数，也就是前面的数a（5）的后面找一个比它大的最后一个数b（6）
	* 交换这两个数a、b
	* 将b后面（原先a的位置）的序列反序（从小到大排序）。
	* 得到新的排列，也就是字典式排列的下一个排列。

对上述的算法进行分析（因为123456比较单一，以263541这个排列为例）：

* 算法第一步找最后一个正序（35），因为这是最后一个正序，所以在3后面的数中，必然是从大到小的排序方式（541）。
* 第二步从后向前找第一个比3大的数。结合上一步，从后向前找，也就是从小到大找，所以找到的数必然是比3大的数中最小的数。前面说了，字典式排序找每一位能够取到的最小的数，如果我们要替换3这个位置的数，必然是取比3大的数中最小的数，所以按照这一步，能够取到这个数。
* 第三步，交换这两个数。这很明白，就是替换掉
* 第四步，将替换掉的数后面的数反序。这也很明白，每一位取能够取到的最小的数。

综上，可以分析出，这个算法能够有规律的找出所有的排列。
	 
STL提供了用来计算下一个排列关系的算法，分别是next_permucation以及求上一个排列的prev_permucation

下面给出我自己的求全排列的搜索实现。

```
#include <cstdlib>
#include <vector>
#include <iostream>

using namespace std;
class Solution {
    
public:
    vector< vector<int> > result;

    vector<vector<int>> permute(vector<int>& nums) {
        
        vector<int> tmp;
        
        if(nums.size() <= 1)
        {
            result.push_back(nums);
            return result;
        }
        
        dfs(0, nums);
        return result;
    
    }
    
    void dfs(int index, vector<int> nums)
    {
        if(index == nums.size())
        {
            cout << "---" <<endl;
            vector<int> tmp;
            for(int i = 0; i < nums.size(); ++i)
            {
				tmp.push_back(nums[i]);
            }
            result.push_back(tmp);
            return;
        }
        
        // 将nums[index] 与后面的每个数交换，然后递归遍历交换之后的序列
        for(int j = index; j < nums.size(); ++j)
        {
            cout << "***" <<endl;
            swap(nums[j], nums[index]);
            cout << index + 1 << endl;
            dfs(index+1, nums);  
            //swap(nums[j], nums[index]);
        }
    }
    
    void swap(int &a, int &b)
    {
        int tmp = a;
        a = b;
        b = tmp;
    }
};

int main(int args, char* argv[])
{

    int i, j;
    int numbers[] = {1,2,3,4};
	vector<int> nums(numbers, numbers + sizeof(numbers) / sizeof(numbers[0]));
	Solution s;
	vector< vector<int> > result = s.permute(nums);

	cout << result.size() << endl;
    for (i = 0; i<result.size(); i++)
    {
        for (j = 0; j<result[i].size(); j++)
        {
            cout << result[i][j] << "  ";
        }
        cout << endl;
    }

	system("pause");
	return 0;
}
```