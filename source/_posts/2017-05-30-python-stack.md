---
layout: post
title: Python算法实践：栈
date: 2017-05-30
update: 2018-04-12
categories: Python
tags: [python, stack, 栈, 算法]
---

python没有内置栈的数据结构，但是可以通过list来实现一个栈

<!--more-->

## python中的栈

python中的数据结构list可以实现栈的操作，无需单独实现一个栈

| list接口 | 对应栈操作描述 |
| :---: | :---: |
| s = [] | 创建一个栈 |
| s.append(x) | 相当于push，向栈内添加一个元素 |
| s.pop() | 弹出(删除)栈顶元素 |
| not s | 判断栈是否为空 | 
| len(s) | 判断栈的长度 | 
| s(-1) | 相当于top，获取栈顶元素 | 
  

## 算法实例

### 1. 括号匹配

假如表达式中允许包含三中括号()、[]、{}，其嵌套顺序是任意的，例如：

正确的格式：

`{()[()]},[{({})}]`

错误的格式：

`[(]),[()),(()}`

编写一个函数，判断一个表达式字符串，括号匹配是否正确

**思路：**

1. 创建一个空栈，用来存储尚未找到匹配的左括号
2. 遍历字符串，遇到一个左括号则入栈，遇到一个右括号，则弹出栈顶元素，比较是否匹配
3. 在第二步骤过程中，如果空栈情况下遇到右括号，说明缺少左括号，不匹配
4. 在第二步骤遍历结束时，栈不为空，说明缺少右括号，不匹配

**算法代码：**

```python
#!/usr/bin/env python
# -*- coding:utf-8 -*-

LEFT = {'(', '[', '{'}
RIGHT = {']', ')', '}'}

def match(expr):
    '''
    @param expr: 传入的字符串
    @return: 返回结果是否正确
    '''
    stack = []
    for bracket in expr:
        if bracket in LEFT:
            stack.append(bracket)
        elif bracket in RIGHT:
            if not stack or not 1 <= ord(bracket) - ord(stack[-1]) <= 2:  # ord返回对应的ASCII码或者Unicode码
                # 如果当前栈为空
                # 如果右括号减去左括号的值不是小于等于2大于等于1（判断左右括号是否匹配）
                return False
            
             # 如果栈不为空，且匹配，则弹出左括号
            stack.pop()
        else:
            return False   #其他字符则返回false
    return not stack

result = match('[(){()}]')
print(result)
```

### 2. 迷宫问题

**题目：**

用一个二维数组表示一个简单的迷宫，用0表示通路，用1表示阻断，老鼠在每个点上可以移动相邻的东南西北四个点，设计一个算法，模拟老鼠走迷宫，找到从入口到出口的一条路径。

迷宫如图所示，出去的正确线路如图中的红线所示:

![迷宫](/images/posts/python/migong.png)

**思路：**

1. 用一个栈来记录老鼠从入口到出口的路径
2. 走到某点后，将该点左边压栈，并把该点值置为1，表示走过了；
3. 从临近的四个点中可到达的点中任意选取一个，走到该点；
4. 如果在到达某点后临近的4个点都不走，说明已经走入死胡同，此时退栈，退回一步尝试其他点；
5. 反复执行第二、三、四步骤直到找到出口；

**算法代码：**

```python
#!/usr/bin/env python
# -*-coding:utf-8-*-

def initMaze():
    '''
    初始化迷宫
    '''
    maze = [[0] * 7 for _ in range(5 + 2)] # 用列表解析创建一个7*7的二维数组，为了确保迷宫四周都是墙
    walls = [
        (1, 3),
        (2, 1), (2, 5),
        (3, 3), (3, 4),
        (4, 2),  # (4, 3),  # 如果把(4, 3)点也设置为墙，那么整个迷宫是走不出去的，所以会返回一个空列表
        (5, 4)
    ]
    # 设置四周的墙
    for i in range(7):
        maze[i][0] = maze[i][-1] = 1
        maze[0][i] = maze[-1][i] = 1
    for i,j in walls:
        maze[i][j] = 1
    return maze

"""
[1, 1, 1, 1, 1, 1, 1]
[1, 0, 0, 1, 0, 0, 1]
[1, 1, 0, 0, 0, 1, 1]
[1, 0, 0, 1, 1, 0, 1]
[1, 0, 1, 0, 0, 0, 1]
[1, 0, 0, 0, 1, 0, 1]
[1, 1, 1, 1, 1, 1, 1]
"""

def path(maze, start, end):
    '''
    @param maze: 迷宫
    @param start: 起点
    @param end: 终点
    @return: 路径上的点
    '''
    i, j = start
    ei, ej = end
    stack = [(i,j)] # 创建一个栈，并让老鼠站到起始点的位置    
    while stack:
        i,j = stack[-1]
        # 如果找到出口
        if(i,j) == (ei,ej):
            break
        # 在上下左右四个相邻的位置寻找路径
        for di, dj in [(0,-1), (0,1), (1,0), (-1,0)]:
            # 找到一个可走的路径就入栈，继续寻找
            if maze[i+di][j+dj] == 0:
                maze[i+di][j+dj] = 1
                stack.append((i+di, j+dj))
                break   
            else:
                stack.pop()
    return stack

Maze = initMaze()
result = path(maze=Maze, start=(1,1), end=(5,5))
print(result)
```


### 3. 后缀表达式

**题目：**

计算一个表达式时，编译器通常使用后缀表达式。编写程序实现后缀表达式求值函数。

**思路：**

1. 建立一个栈来存储待计算的操作数；
2. 遍历字符串，遇到操作数则压入栈中，遇到操作符号则出栈操作数(n次)，进行相应的计算，计算结果是新的操作数压回栈中，等待计算
3. 按上述过程，遍历完整个表达式，栈中只剩下最终结果；

**算法代码：**

```python
#!/usr/bin/env python
# -*- coding:utf-8 -*-

operators = {
    '+': lambda a, b : a + b, 
    '-': lambda a, b : a - b,
    '/': lambda a, b : a / b,
    '*': lambda a, b : a * b
}

def evalPostfix(e):
    '''
    @param e: 算术表达式
    @return: 计算结果
    '''
    tokens = e.split()
    stack = []
    for token in tokens:  # 迭代列表中的元素
        if token.isdigit():  # 如果当前元素是数字
            stack.append(int(token))  # 就追加到栈里边
        elif token in operators.keys():  # 如果当前元素是操作符
            f = operators[token]  # 获取运算符操作表中对应的lambda表达式
            op2 = stack.pop()  # 根据先进后出的原则，先让第二个元素出栈
            op1 = stack.pop()  # 在让第一个元素出栈
            stack.append(f(op1, op2))  # 把计算的结果在放入到栈内
    return stack.pop()  # 返回栈内的第一个元素
result = evalPostfix('2 3 4 * +')
print(result)
```

