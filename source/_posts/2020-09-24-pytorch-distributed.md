---
title: PyTorch 多进程分布式训练实战
date: 2020-09-24 16:02:34
update: 2020-09-24 16:02:34
categories: PyTorch
tags: [PyTorch, distributed, multiprocessing]
---

PyTorch 可以通过 `torch.nn.DataParallel` 直接切分数据并行在单机多卡上，实践证明这个接口并行力度并不尽如人意，主要问题在于数据在 master 上处理然后下发到其他 slaver 上训练，而且由于 [GIL](https://murphypei.github.io/blog/2017/05/python-GIL) 的存在只有计算是并行的。`torch.distributed` 提供了更好的接口和并行方式，搭配多进程接口 `torch.multiprocessing` 可以提供更加高效的并行训练。

<!-- more -->

### 多进程

我们都知道由于 GIL 的存在， python 要想真正的并行必须使用多进程，IO 频繁可以勉强使用多线程。`torch.nn.DataParallel` 全局只有一个进程，受到了 GIL 的限制，所以肯定会拖累并行的力度。

python 自带的 `multiprocessing` 是多进程常用的实现，但是有一个巨大的问题，**不支持 CUDA**，所以我们使用 GPU 训练的时候不能用这个包，需要使用 PyTorch 提供的 `torch.multiprocessing`。它提供了和 `multiprocessing` 几乎一样的接口，所以用起来也比较方便。

这里额外插一句，`torch.distributed` 可以通过 `torch.distributed.launch` 启动多卡训练，但是我个人的原则是能交由自己代码控制的都不会交给工具，所以使用 `torch.multiprocessing` 手动提交多进程并行。所以本文不会对 `torch.distributed.launch` 以及多级多卡这类我没测试使用过的东西做说明。

### 分布式训练

`torch.distributed` 提供了和通用分布式系统常见的类似概念。

* **group**：进程组。默认情况下，只有一个组，一个 `job` 即为一个组，也即一个 `world`，当我们使用多进程的时候，一个 `group` 就有了多个 `world`。当需要进行更加精细的通信时，可以通过 `new_group` 接口，使用 word 的子集，创建新组，用于集体通信等。
* **world**：全局进程个数。
* **rank**：表示进程序号，用于进程间通信，可以用于表示进程的优先级。我们一般设置 `rank=0` 的主机为 master 节点。
* **local_rank**：进程内 GPU 编号，非显式参数，由 `torch.distributed.launch` 内部指定。比方说， `rank=3`，`local_rank=0` 表示第 3 个进程内的第 1 块 GPU。

### PyTorch 多进程分布式训练实战

##### 启动多进程任务：

```python
ngpus_per_node = torch.cuda.device_count()

def main():
    if not torch.cuda.is_available():
        print("\033[1;33m{}\033[0m".format("gpu is not available, cpu will be very slow!"))
    else:
        print("Let's use {} GPUs!".format(torch.cuda.device_count()))

    if args.seed is not None:
        random.seed(args.seed)
        torch.manual_seed(args.seed)
        cudnn.deterministic = True
        print("\033[1;33m{}\033[0m".format(
            ("You have chosen to seed training. This will turn on the CUDNN deterministic setting, which can slow down "
             "your training considerably! You may see unexpected behavior when restarting from checkpoints.")))

    if args.dist_url == "env://" and args.world_size == -1:
        args.world_size = int(os.environ["WORLD_SIZE"])

    args.distributed = args.world_size > 1 or args.multiprocessing_distributed

    if args.multiprocessing_distributed:
        # Since we have ngpus_per_node processes per node, the total world_size needs to be adjusted accordingly
        args.world_size = ngpus_per_node * args.world_size
        # Use torch.multiprocessing.spawn to launch distributed processes: the main_worker process function
        mp.spawn(main_worker, nprocs=ngpus_per_node, args=(args,))
    else:
        main_worker(args.gpu, args)
```

以上代码很简单，就是提交多进程任务。我们设置 `args.multiprocessing_distributed` 为 `True` 即可启动多进程分布式训练。`ngpus_per_node` 是单机上卡的数量，我们以此为标准，设置 `world_size` 也就是要启动的进程数量。然后通过 `torch.multiprocessing.spawn` 直接提交每个进程的任务。

`args.dist_url` 是通信方式，`env://` 以及 `os.environ["WORLD_SIZE"]` 都表示通过环境变量设置任务参数，这个不需要去纠结，不这样用就行了，通过命令行参数传入方便简单而且灵活，等你真的有大规模集群的时候再考虑通过环境配置这些参数。

##### 初始化分布式训练

```python
def main_worker(gpu, args):
    args.gpu = gpu
    if args.gpu is not None:
        print("Use GPU: {}".format(args.gpu))
    global best_result

    if args.distributed:
        if args.dist_url == "env://" and args.rank == -1:
            args.rank = int(os.environ["RANK"])
        if args.multiprocessing_distributed:
            # For multiprocessing distributed training, rank needs to be the global rank among all the processes.
            args.rank = args.rank * ngpus_per_node + args.gpu
        torch.distributed.init_process_group(backend=args.dist_backend,
                                             init_method=args.dist_url,
                                             world_size=args.world_size,
                                             rank=args.rank)
```

`main_worker` 就是每个进程实际执行的任务了，也比较好理解。这里有一个需要注意的地方：`torch.multiprocessing.spawn()` 要求提交的任务函数第一个参数是 gpu\_id，并且启动多进程传参的时候不传入这个参数，是默认传入的。

这里首先设置了当前进程的 `rank`，也是通过传入的 gpu\_id 设置的，也就是 GPU\_0 就是 `rank=0` 了。然后最重要的就是分布式初始化了：`init_process_group()`。

`backend` 参数可以参考 [PyTorch Distributed Backends](https://pytorch.org/docs/master/distributed.html?highlight=distributed#backends)，也就是分布式训练的底层实现，GPU 用 `nccl`，CPU 用 `gloo`，不用选了。

> 这里需要注意，选择了 GPU 或者 CPU 之后，多进程通信的操作就只限于 GPU 数据和 CPU 数据了，比如 `nccl` 就不支持 CPU 数据的一些操作。

`init_method` 参数就是多进程通信的方式，前文说了通过命令行 `args.dist_url` 传入即可，单机多卡直接无脑 TCP 就行，又快又稳，比如：`tcp://127.0.0.1:8009`，随便选一个没有被占用的端口即可。

`world_size` 和 `rank` 前文已经说过了。

注意，`main_worker` 函数里的每一行代码都会在每个进程上单独执行，这里可以看到，不同的进程仅仅是使用了不同的 `rank`，后续也是通过这个参数去区分不同的进程。我一般是会选择一个 master，也就是 `rank=0` 用于我的一些打印信息和其他操作。

```python
def main_worker(gpu, args):
    
    # code...

    if not args.multiprocessing_distributed or (args.multiprocessing_distributed and args.rank % ngpus_per_node == 0):
        args.master = True
    else:
        args.master = False
```

#### 训练数据处理

`torch.nn.DataParallel` 接口之所以说简单是因为数据是在全局进程中处理，所以不需要对 DataLoader 做特别的处理。PyTorch 分布式训练的原理是把数据直接切分成 `world_size` 份，然后在每个进程内独立处理数据、前向和反向传播，所以快。因此也必须要对 DataLoader 做一些处理，其实也是非常简单的。

```python

if torch.distributed.is_initialized():
    train_sampler = torch.utils.data.distributed.DistributedSampler(train_dataset, shuffle=Tru)
else:
    train_sampler = None

train_loader = torch.utils.data.DataLoader(train_dataset,
                                            batch_size=batch_size,
                                            shuffle=(train_sampler is None),
                                            num_workers=workers,
                                            worker_init_fn=_worker_init_fn,
                                            pin_memory=True,
                                            sampler=train_sampler,
                                            collate_fn=fast_collate)
```

通过 `torch.distributed.is_initialized()` 我们就可以检查每个进程是否被分布式初始化了，然后直接调用 `torch.utils.data.distributed.DistributedSampler()` 实例化一个数据分发的对象，通过这个 sampler 把数据发到各个进程中。这里要特别注意一点，首先，然后使用了 `DistributedSampler`，那么 DataLoader 中的 `shuffle` 参数是无效的，这是必然的，因为数据是在最开始就直接被切分了的，每个卡在整个训练期间的时候只能看到自己的那块数据，当然，你可以设置 sampler 内部 shuffle，而且也有一个办法避免；其次，**切分和 rank 无关，而且不保证连续**，这是我多次实验的结论，也就是说每个卡的得到哪些数据我们完全不可控，这就是说如果你想用多卡推理，然后把推理结果和原数据顺序对应起来基本不可能，非常无语。

数据处理还有一个提示，PyTorch 文档中写的：

> In distributed mode, calling the `set_epoch()` method at the beginning of each epoch before creating the `DataLoader` iterator is necessary to make shuffling work properly across multiple epochs. Otherwise, the same ordering will be always used.

什么意思呢？就是如果你想每个 epoch 每个卡的数据都充分 shuffle 而不是像我上面说的那样每张卡整个训练过程中只能看到自己的那部分数据，你就需要在每次迭代的过程中调用 `DistributedSampler.set_epoch()` 方法。这个就是前面提到避免每张卡只看到一部分数据的方法。我自己觉得用不用都可。

#### 多进程数据操作

多进程有一些麻烦事，比如打印这些，最好设置在 master 中进程，可能代码中比较多的 `if master` 了，另外一个就是我个人需求，我希望每个 epoch 能够对整个测试数据做评测，而不是 master 那自己的一部分，这个就涉及多进程间数据合并和通信了。代码为例：

```python
logits = torch.cat(logits_list, dim=0)
targets = torch.cat(targets_list, dim=0)

# For distributed parallel, collect all data and then run metrics.
if torch.distributed.is_initialized():
    logits_gather_list = [torch.zeros_like(logits) for _ in range(ngpus_per_node)]
    torch.distributed.all_gather(logits_gather_list, logits)
    logits = torch.cat(logits_gather_list, dim=0)

    targets_gather_list = [torch.zeros_like(targets) for _ in range(ngpus_per_node)]
    torch.distributed.all_gather(targets_gather_list, targets)
    targets = torch.cat(targets_gather_list, dim=0)

accuracy, recall, precision, auc = classification_metrics(logits, targets)
```

`logits` 和 `targets` 是常见的分类网络的输出和标签了，如果分布式训练，则通过 `torch.distributed.all_gather()` 这个操作，将各个进程的数据都搜集到一块，然后再处理。这里的搜集方式看代码结合[官方文档](https://pytorch.org/docs/master/distributed.html?highlight=all_gather#torch.distributed.all_gather)就明白了，很简单。


### 总结

以上就是我自己使用 PyTorch 多进程分布式训练的经验了，没有太多原理讲解，想看其实现原理直接网上搜就行，具体怎么用看我给的代码就会了。根据我的经验，直接将这些流程嵌入到已有代码中即可，对于一些处理、打印、TensorBoard 等等都交给 master，缺点就是只能反映部分，不能反映整体，算是目前的一些不足吧。我的训练环境主要是单机多卡，写这篇文章也是结合我自己的使用经验，所以肯定有很多地方没照顾到，但是以实践为主看完这篇文章就可以上手了。