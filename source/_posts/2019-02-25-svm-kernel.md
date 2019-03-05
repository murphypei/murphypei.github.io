<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-MML-AM_CHTML"></script>


我之前写过一个关于SVM中核函数的理解，讲述了核函数的本质是利用高维映射来解决线性不可分的情况。但是具体怎么映射，以及核函数为什么写成两个向量内积的形式还存在一些疑问，这篇文章对这些知识点做一些总结。


## 感知机的对偶形式

《统计学习方法》(李航)在感知机的2.3.3小节中描述了感知机求解的对偶形式：

> 对偶形式的基本想法是，将\\(w\\)和\\(b\\)表示为实例$x_{i}$和标记