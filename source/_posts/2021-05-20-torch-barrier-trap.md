---
title: Pytorch distributed barrier 引发的陷阱
date: 2021-05-20 15:17:19
update: 2021-05-20 15:17:19
categories: [Pytorch]
tags: [pytorch, distribute, barrier, DDP]
---

Pytorch 中 `torch.distributed.barrier` 函数通常用于分布式进程同步，但是使用也存在一个陷阱。

<!-- more -->

记录一个最近使用 Pytorch 分布式遇到的一个问题。

熟悉 Pytorch 的同学一定知道 `torch.distributed.barrier` 是用于不同进程间的同步，其原理很简单，就是**每个进程进入这个函数后都会被阻塞，当所有进程都进入这个函数后，阻塞解除**，继续向下执行。废话不多说，直接说重点：**所有进程都执行到这一步**。也就是说如果有些代码是某个进程单独执行，并且不小心包含了这条语句，那么这个进程陷入无限等待。

直接看我的**错误例子**：

```python
train_dataloader = create_dataloader(rank, ...)

if rank in [-1, 0]:
    val_dataloader = create_dataloader(rank, ...)
```

`create_dataloader` 内部：
```python
def create_dataloader(rank, ...):
    with torch_distributed_zero_first(rank):
        dataset = Dataset(...)
    
    dataloader = foo(dataset)
    return dataloader
```

`torch_distributed_zero_first(rank)` 是一个 contextmanager，其用法就是用 `@contextmanager` 语法糖修饰一个生成器，使其能够按照 `with ...` 形式执行。
```python
@contextmanager
def torch_distributed_zero_first(rank):
    if rank not in [-1, 0]:
        torch.distributed.barrier()
    yield
    if rank == 0:
        torch.distributed.barrier()
```
contextmanager，其用法就是用执行顺序是：
1. 首先`with` 语句先执行生成器内部代码，遇到 `yield` 之后返回（如果有返回值则就是 `with ... as ...` 中 as 的值）。
2. 继续执行 `with` 嵌套的语句（如上就是创建 Dataset），执行完毕回到生成器。
3. 执行 `yield` 后面的语句。

首先说明一下，使用 `torch_distributed_zero_first` 的目的是执行创建 dataloader 的时候，期望主进程能够先执行，这样可以创建一些缓存之类的文件，让后续进程直接读取缓存，加快顺序，这是出发点。我们看一下运行原理：首先 `create_dataloader` 中 `with torch_distributed_zero_first(rank):` 调用会让除了主进程以外的其他进程进入阻塞，只有主进程会继续在 `yield` 执行的时候返回，执行嵌套语句，创建 Dataset，然后再次进入生成器，调用 barrier。这时候所有进程进入了 barrier 函数，因此所有一起被唤醒，继续向下执行。因此这样确保所有进程中主进程最先执行了嵌套语句。

弄明白了上述的工作原理，再看 `val_dataloader` 的创建过程，其问题出在**只有主进程执行了这个调用**。因此按照上述分析，主进程创建完 Dataset 之后，被阻塞，此时其他进程并未被阻塞，因此主进程陷入无限阻塞（后续如果恰好其他进程执行到 barrier 或许可以解除）。因此这里应该传入 `rank=-1`，跳过 if 后面的 barrier。