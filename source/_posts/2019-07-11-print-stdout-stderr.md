---
title: Bash 中同时输出常规信息和错误到文件中
date: 2019-07-11 15:58:43
update: 2019-07-11 15:58:43
categories: Linux
tags: [Linux, stdout, stderr, 管道]
---

我们在 Linux 中运行脚本的时候经常有一个需求是将日志信息保存到文件中，方便查看。

<!-- more -->

我们知道， Linux 的 stdout 和 stderr 都是标准输出，只是 stream 不同。stdout 就是正常的终端打印输出，而 stderr 是错误信息。 从终端上看，二者并无直观分别，都是打印在屏幕上。 但是，由于 stream 不同，在进行组合操作时，会有较大差异。

作为 Unix 标准的一部分，这哥俩一开始是从 C 语言出来的。 其它更早的语言，虽然也有区分正常打印与错误信息的，比如 Fortran。 但是，stdout 和 stderr 这两个词，直接出自 C 语言的 `stdio.h`。

```C
#include<stdio.h>

int main(void)
{
    printf("stdout\n");
    fprintf(stdout, "stdout\n");
    fprintf(stderr, "stderr\n");
    return 0;
}
```

以上 C 语言代码编译后运行，会在终端显示三行。 两行 stdout 会打印到 stdout，一行 stderr 会打印到 stderr，因为大部分**默认情况** stdout 和 stderr 都是屏幕，所以看上去没区别。

### stdout 与 stderr 的相互重定向

默认情况下，输出到 stdout，比如：

`echo "hello"`

如果需要打印到 stderr，则要麻烦一些：

`echo "hello" 1>&2`

其中，末尾的 `1` 可以省略，可以写作 `>&2` ，但是 `>&2` 不能有空格。这里，`1` 就代表 stdout，`2` 就代表 stderr，`>` 是重定向。 含义就是把 stdout 的输出内容，重定向（redirect to）到 stderr 中去。

同理，`2>&1` 就是把 stderr 里的内容，重定向到 stdout 中。 这个更常用一些。这种表达式，不仅对 `echo` 生效，而是对任何 Bash 调用都生效，包括自定义脚本与程序。`2` 不能省略

再次强调：`2>&1`这类表达式中间不能有空格。

### 从stdout与stderr里重定向到文件

这就是本文开头提到的需求了，了解了上面的重定向就比较好办了。首先来看直接把 stdout 重定向到文件：

`make > build.log`

这个太普遍了，只不过如果仅仅这样，就会造成错误信息打印在屏幕上，常规信息保存在文件中。我们需要的是同时将它们保存在文件中，应该是这样：

`make > build.log 2>&1`

这种方法，不仅逻辑上麻烦，而且很容易出错。 例如，有时会写成 `make 2>&1 > build.log`，这是无效的，与 `make > build.log` 等价。**`2>&1` 必须要放到一个完整 Bash 表达式的最后才能生效**。 这一点，非常容易出错。

第二种方法，直接把 stdout 和 stderr 都重定向到文件。 不仅形式简单，而且不会出错。

`make &> build.log`

把 `&>` 替换成 `>&`，也是等价的。 另外要注意，这种用法仅在 Bash 中有效，在标准的 sh 无效，其它 shell 则没试过。 而 `1>`、`2>`、`2>&1`即使在标准的sh中，也是有效的。

### 打印并保存在文件中

有时，既需要打印，又需要重定向。 还是以 make 举例，俺们通常既需要看到编译的过程，又需要分析 build.log。 这时，`tee` 就可以满足需求。

`make | tee build.log`

这一句的意思是，把 make 的 stdout 输出，传给 tee； 而 **tee 则会打印到 stdout 的同时，重定向到 build.log 中**。 所以结果是，stdout 和 stderr 都会被打印，而只有 stdout 才会被重定向到 build.log中。结合前面的需求，如果都需要保存在文件中：

`make 2>&1 | tee build.log`

这一句就满足了保存完整 log 的需求。

咦？等等！ 那个 `2>&1` 的位置，似乎有些奇怪？这是因为，管道 `|` 分割了 Bash 表达式，这一句实际上是两个表达式。 所以，`2>&1` 确实是在表达式的末尾，没错。如果换成 `make | tee build.log 2>&1`，反而无法生效。 因为，管道 `|` 只会传递 stdout 的输出，不会传递 stderr 的输出。

### 丢弃信息

有时候我们既不想把错误信息保存在文件中，也不想打印在屏幕上，而因为 stdout 和 stderr 默认就是屏幕，所以我们需要把它们重定向到下水道里：

`make 2> /dev/null`

这就是把 stderr 重定向到下水道里。

