---
title: golang select 机制和超时
date: 2022-06-25 14:24:59
update: 2022-06-25 14:24:59
categories: Golang
tags: [golang, select, case, timeout, after, chan]
---

golang 中的协程使用非常方便，但是协程什么时候结束是一个控制问题，可以用 select 配合使用。

<!-- more -->

首先声明，golang 使用并不熟悉，本文仅仅是记录使用过程中遇到的一些坑。

子协程和父协程的通信通常用 context 或者 chan。我遇到一个通常的使用场景，在子协程中尝试多次处理，父协程等待一段时间超时，我选择用 chan 实现。我以为 select 和 C++ 中 switch 类似，所以最开始代码类似如下：

```golang
for {
    select {
        case <-ctx.Done():
            // process ctx done
        case <-time.After(time.Second * 3):
            // process after
        default:
            // process code
    }
}
```

测试发现无法实现 timeout，又仔细查看文档，才发现 golang 中 select 另有玄机。废话少说，直接总结要点：

* select 中的 case 必须是进行 chan 的手法操作，也就是只能在 case 中操作 chan，并且是**非阻塞接收**。
* select 中的 case 是同时监听的，多个 case 同时操作，并未 switch 中一个个顺序判断。如果多个 case 满足要求，随机执行一个，如果一个没有则阻塞当前的协程（没有 default 情况下）。**很类似 Linux 文件符操作的 select 语义**。
* 上面说的阻塞是没有 default 的情况下，如果有 default，则执行 default，然后退出 select，也就是不会阻塞当前协程。

回到上述代码，我这个 select 会一直不断的执行 default，`time.After` 生成的 chan 并不会被阻塞判断，所以根本无法完成我想要的效果。理解了之后重新修改代码：

```golang
done := make(char int)
go func(c chan int) {
    for {
        // process code
        if {
            c <- 1
            return
        }
    }
    c <- 0
}(done)

select {
    case <-ctx.Done():
        // process ctx done
    case <-time.After(time.Second * 3):
        // process after
    case <-done:
        // process code
}
```

开一个新的协程去不断尝试，在外的三个 case 有一个满足，则会执行。但是这里有一个问题非常需要注意：**子协程什么时候退出？**。

因为 gorountine 不能被强制 kill，所以在上述超时的情况下，select 语句执行 `case time.After` 之后退出，`done` 这个 chan 已经没有接受方了，因此既没有接受者，又没有缓冲区，结合 chan 的特性，则子协程会一直阻塞无法退出，所以本质上这个实现会导致子协程累积下去，也就是**协程泄露**，可能会使资源耗尽。

如何避免上述问题呢？一个很简单的想法就是提供缓冲区，`done := make(char int, 1)`，这样即使没有接收方，子协程也能完成发送，不会被阻塞。

还要一种办法，上面说了，select 操作 chan，并且可以指定 default，那是不是有思路了呢？

```golang
if {
    select {
        case done <- 1:
        default:
            return
    }
}
```

我们尝试往 chan 中发送，如果发不出去，则就退出，也实现了目的。


最后总结一下，goroutine 泄露的防范条例：
* 创建 goroutine 时就要想好该 goroutine 该如何结束。
* 使用 chan 时，要考虑到 chan 阻塞时协程可能的行为。
* 实现循环语句时注意循环的退出条件，避免死循环。
