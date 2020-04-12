---
title: C++ 实现图的 DFS 和 BFS
date: 2019-04-15 16:53:17
update: 2019-04-15 16:53:17
categories: C/C++
tags: [C++, 图, DFS, BFS, 递归]
---

图的 DFS 和 BFS 的思想在实际编程中也非常常见，本文对其实现思路进行了一个小小的记录。

<!-- more -->

### 图的创建

将图存储在二维矩阵中，矩阵中的元素可以表示两个节点间的距离。

```c++
std::vector<std::list<int>> graph;
```

### 图的 BFS

#### 非递归实现，借助队列

```c++
// 以v开始做广度优先搜索
void bfs(int v)
{
    std::list<int>::iterator it;
    visited[v] = true;

    // process node
    std::cout << v << " ";

    queue<int> tempQueue;
    tempQueue.push(v);
    while(!tempQueue.empty())
    {
        v = tempQueue.front();
        tempQueue.pop();
        for (it = graph[v].begin(); it != graph[v].end(); ++it)
        {
            if (!visited[*it])
            {
                // process node
                std::cout << *it << " ";
                tempQueue.push(*it);
                visited[*it] = true;
            }
        }
    }
    std::cout << std::endl;
}
```

### 图的 DFS

#### 非递归实现，借助栈

```c++
// 以v开始做深度优先搜索
void dfs(int v)
{
    std::list<int>::iterator it;
    visited[v] = true;

    // process node
    std::cout << v << " ";

    std::stack<int> tempStack;
    tempStack.push(v);

    while(!tempStack.empty())
    {
        v = tempStack.top();
        tempStack.pop();
        if (!visited[v])
        {
            // process node
            std::cout << v << " ";
            visited[v] = true;
        }

        for (it = graph[v].begin(); it != graph[v].end(); it++)
        {
            if (!visited[*it])
            {
                tempStack.push(*it);
            }
        }
    }
    std::cout << std::endl;
}
```

#### 递归实现

```c++
// 以v开始做深度优先搜索
void dfs(int v)
{
    std::list<int>::iterator it;
    visited[v] = true;

    // process node
    std::cout << v << " ";

    // 对当前节点所联通的每一个节点，递归进行DFS
    for (it = graph[v].begin(); it != graph[v].end(); it++)
    {
        if (!visited[*it])
            dfs(*it);
    }
}
```