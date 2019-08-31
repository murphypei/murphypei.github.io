---
title: Linux IO 模式及 select、poll、epoll 详解
date: 2017-03-19
update: 2018-04-12
categories: Linux
tags: [Linux, IO复用, select, epoll]
---

Linux IO 模式总结并对 select、poll、epoll 的使用做介绍。

<!--more-->

## 概念说明

在进行解释之前，首先要说明几个概念：

* 用户空间和内核空间
* 进程切换
* 进程的阻塞
* 文件描述符
* 缓存 I/O

### 用户空间与内核空间

现在操作系统都是采用虚拟存储器，那么对 32 位操作系统而言，它的寻址空间（虚拟存储空间）为 4G（2 的 32 次方）。操作系统的核心是内核，独立于普通的应用程序，可以访问受保护的内存空间，也有访问底层硬件设备的所有权限。为了保证用户进程不能直接操作内核（kernel），保证内核的安全，操心系统将虚拟空间划分为两部分，一部分为内核空间，一部分为用户空间。针对 Linux 操作系统而言，将最高的 1G 字节（从虚拟地址 0xC0000000 到 0xFFFFFFFF），供内核使用，称为内核空间，而将较低的 3G 字节（从虚拟地址 0x00000000 到 0xBFFFFFFF），供各个进程使用，称为用户空间。

### 进程切换

为了控制进程的执行，内核必须有能力挂起正在 CPU 上运行的进程，并恢复以前挂起的某个进程的执行。这种行为被称为进程切换。因此可以说，任何进程都是在操作系统内核的支持下运行的，是与内核紧密相关的。从一个进程的运行转到另一个进程上运行，这个过程中经过下面这些变化：

* 保存处理机上下文，包括程序计数器和其他寄存器中的数据。
* 更新 PCB 信息。
* 把进程的 PCB 移入相应的队列，如就绪、在某事件阻塞等队列。
* 选择另一个进程执行，并更新其 PCB。
* 更新内存管理的数据结构。

可以看出，进程的切换很耗资源

### 进程阻塞

正在执行的进程，由于期待的某些事件未发生，如请求系统资源失败、等待某种操作的完成、新数据尚未到达或无新工作做等，则由系统自动执行阻塞原语(Block)，使自己由运行状态变为阻塞状态。可见，**进程的阻塞是进程自身的一种主动行为**，也因此只有处于运行态的进程（获得 CPU），才可能将其转为阻塞状态。**当进程进入阻塞状态，是不占用 CPU 资源的。**

### 文件描述符 fd

文件描述符（file descriptor）是计算机科学中的一个术语，是一个用于表述指向文件的引用的抽象化概念。

文件描述符在形式上是一个非负整数。实际上，它是一个索引值，指向内核为每一个进程所维护的该进程打开文件的记录表。当程序打开一个现有文件或者创建一个新文件时，内核向进程返回一个文件描述符。在程序设计中，一些涉及底层的程序编写往往会围绕着文件描述符展开。但是文件描述符这一概念往往只适用于 UNIX、Linux 这样的操作系统。

### 缓存 I/O

缓存 I/O 又被称作标准 I/O，大多数文件系统的默认 I/O 操作都是缓存 I/O。在 Linux 的缓存 I/O 机制中，操作系统会将 I/O 的数据缓存在文件系统的页缓存（ page cache ）中，也就是说，**数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的地址空间。** 这也导致**数据在传输过程中需要在应用程序地址空间和内核进行多次数据拷贝操作，这些数据拷贝操作所带来的 CPU 以及内存开销是非常大的。**

## IO 模式

刚才说了，对于一次 IO 访问（以 read 举例），数据会先被拷贝到操作系统内核的缓冲区中，然后才会从操作系统内核的缓冲区拷贝到应用程序的地址空间。所以说，当一个 read 操作发生时，它会经历两个阶段：

1. 等待数据准备（Waiting for the data to be ready）
2. 将数据从内核拷贝到进程中（Copying the data from the kernel to the process）

因为这两个阶段，Linux 系统产生了下面五种网络模式的方案。

* 阻塞 I/O（blocking IO）
* 非阻塞 I/O（nonblocking IO）
* I/O 多路复用（IO multiplexing）
* 信号驱动 I/O（signal driven IO）
* 异步 I/O（asynchronous IO）

注：由于 signal driven IO 在实际中并不常用，所以我这只提及剩下的四种 IO Model。

### 阻塞 IO

在 Linux 中，默认情况下所有的 socket 都是 blocking，一个典型的读操作流程大概是这样：

![阻塞型IO模型](/images/posts/linux/block_io.png)

当用户进程调用了 `recvfrom` 这个系统调用，kernel 就开始了 IO 的第一个阶段：准备数据（对于网络 IO 来说，很多时候数据在一开始还没有到达。比如，还没有收到一个完整的 UDP 包。这个时候 kernel 就要等待足够的数据到来）。这个过程需要等待，也就是说数据被拷贝到操作系统内核的缓冲区中是需要一个过程的。而**在用户进程这边，整个进程会被阻塞（当然，是进程自己选择的阻塞）**。当 kernel 一直等到数据准备好了，然后 kernel 返回结果，用户进程才解除 block 的状态，重新运行起来，也就是开始第二个阶段，将数据从 kernel 中拷贝到用户内存。

所以，**blocking IO 的特点就是在 IO 执行的两个阶段都被 block 了**。

### 非阻塞 I/O（nonblocking IO）

Linux 下，可以通过设置 socket 标志位使其变为 non-blocking。当对一个 non-blocking socket 执行读操作时，流程是这个样子：

![非阻塞型IO模型](/images/posts/linux/non_block_io.png)

当用户进程发出 `read` 操作时，如果 kernel 中的数据还没有准备好，那么它并不会 block 用户进程，而是立刻返回一个 error。**从用户进程角度讲 ，它发起一个 `read` 操作后，并不需要等待，而是马上就得到了一个结果**。用户进程判断结果是一个 error 时，它就知道数据还没有准备好，于是它可以选择通过轮询的方式查看数据是否准备好，一旦kernel中的数据准备好了，并且用户进程发送了 `read` 操作，kernel 再次收到了用户进程的 `system call`，那么它马上就将数据拷贝到了用户内存，然后返回。

所以，**non-blocking IO 的特点是用户进程需要不断的主动询问 kernel 数据好了没有（轮询）**。

**上述两种 IO 方式都是同步的。注意，同步是针对内核从内核拷贝数据到用户进程空间**， 而阻塞和非阻塞是针对用户进程是否等待一次 IO 操作请求的成功返回。

### I/O 多路复用（IO multiplexing）

IO multiplexing 就是我们说的 `select`，`poll`，`epoll`，有些地方也称这种 IO 方式为事件驱动型（event driven）IO。使用 IO 复用的好处就在于单个 process 就可以同时处理多个网络连接的 IO。**它的基本原理就是 `select`，`poll`，`epoll` 这个function 会不断的轮询所负责的所有 socket，当某个 socket 有数据到达了，就通知用户进程**。

![IO多路复用模型](/images/posts/linux/io_multiplexing.png)

**当用户进程调用了 `select`，那么整个进程（`select` 进程）会被block，而同时，kernel 会监视所有 `select` 负责的 socket，当任何一个 socket 中的数据准备好了，`select` 就会返回。这个时候用户进程再调用 `read` 操作，将数据从 kernel 拷贝到用户进程。**

所以，I/O 多路复用的特点是通过一种机制**一个进程能同时等待多个文件描述符**，而这些文件描述符（套接字描述符）其中的任意一个进入读（写）就绪状态，`select` 函数就可以返回。

上述这个图和 blocking IO 的图其实并没有太大的不同，事实上，还更差一些。因为这里需要使用两个 system call（`select` 和 `recvfrom`），而 blocking IO 只调用了一个 system call（`recvfrom`）。但是，**用 `select` 的优势在于它可以同时处理多个 connection**。

所以，如果处理的连接数不是很高的话，使用 `select` 或者 `epoll` 的 web server 不一定比使用 multi-threading + blocking IO 的 web server 性能更好，可能延迟还更大。`select` 和 `epoll` 的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接。

在 IO multiplexing Model 中，实际中，对于每一个 socket，一般都设置成为 non-blocking，但是，如上图所示，整个用户进程其实是一直被 block 的。**只不过进程阻塞在 `select` 这个函数处，而不是被 socket IO 处。**

### 异步 I/O（asynchronous IO）

Linux 下的 asynchronous IO 其实用得很少。先看一下它的流程：

![异步IO模型](/images/posts/linux/asynchronous_io.png)

用户进程发起 `read` 操作之后，立刻就可以开始去做其它的事。而另一方面，从 kernel 的角度，当它收到一个 `asynchronous read` 调用之后，首先它会立刻返回，所以不会对用户进程产生任何 block。然后，kernel 会等待数据准备完成，然后将数据拷贝到用户内存，当这一切都完成之后，kernel 会给用户进程发送一个 signal，告诉它 read 操作完成了。

总结来说，**异步 IO 就是在内核拷贝数据回用户进程的这一操作中，用户进程不会阻塞在 copy 的过程中，而对于同步IO来说，copy 的过程中，用户进程是阻塞的（等待 IO 数据准备可阻塞可不阻塞）。**

### 总结

**阻塞和非阻塞的区别**

调用 blocking IO 会一直 block 住对应的进程直到操作完成，而 non-blocking IO 在 kernel 数据还没准备好的情况下会立刻返回。

**同步和异步的区别**

在说明 synchronous（同步） IO 和 asynchronous（异步） IO 的区别之前，需要先给出两者的定义。POSIX 的定义是这样子的：

* A synchronous I/O operation causes the requesting process to be blocked until that I/O operation completes;
* An asynchronous I/O operation does not cause the requesting process to be blocked;
* 同步 IO 做 IO operation 的时候会将进程阻塞。按照这个定义，之前所述的 blocking IO，non-blocking IO，都属于同步 IO。

有人会说，non-blocking IO 并没有被 block 啊。这里有个非常“狡猾”的地方，定义中所指的”IO operation”是指真实的 IO 操作，就是例子中的 `recvfrom` 这个 system call。non-blocking IO 在执行 `recvfrom` 这个 system call的时候，如果 kernel 的数据没有准备好，这时候不会 block 进程。但是，当 kernel 中数据准备好的时候，`recvfrom` 会将数据从 kernel 拷贝到用户内存中，这个时候进程是被 block 了，在这段时间内，进程是被 block 的。

异步 IO 则不一样，当进程发起 IO 操作之后，就直接返回再也不理睬了，直到 kernel 发送一个信号，告诉进程说 IO 完成。在这整个过程中，进程完全没有被 block。

各个 IO Model 的比较如图所示：

![IO模型比较](/images/posts/linux/io_model_compare.png)

通过上面的图片，可以发现 non-blocking IO 和 asynchronous IO 的区别还是很明显的。在 non-blocking IO 中，虽然进程大部分时间都不会被 block，但是它仍然要求进程去主动的 check，并且当数据准备完成以后，也需要进程主动的再次调用 `recvfrom` 来将数据拷贝到用户内存。而 asynchronous IO 则完全不同。它就像是用户进程将整个 IO 操作交给了他人（kernel）完成，然后他人做完后发信号通知。在此期间，用户进程不需要去检查 IO 操作的状态，也不需要主动的去拷贝数据。

## IO 多路复用之 select、poll、epoll 详解

`select`，`poll`，`epoll` 都是 IO 多路复用的机制。IO 多路复用就是通过一种机制，一个进程可以监视多个描述符，一旦某个描述符就绪（一般是读就绪或者写就绪），能够通知程序进行相应的读写操作。但 `select`，`poll`，`epoll` 本质上都是同步 IO，因为他们都需要在读写事件就绪后自己负责进行读写，也就是说这个读写过程是阻塞的，而异步 IO 则无需自己负责进行读写，异步 IO 的实现会负责把数据从内核拷贝到用户空间。

### select

```c++
int select (int n, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
```

`select` 函数监视的文件描述符分 3 类，分别是 `writefds`、`readfds` 和 `exceptfds`。调用后 `select` 函数会阻塞，直到有描述副就绪（有数据 可读、可写、或者有 `except`），或者超时（`timeout` 指定等待时间，如果立即返回设为 null 即可），函数返回。当 `select` 函数返回后，可以通过遍历 `fdset`，来找到就绪的描述符。

`select` 目前几乎在所有的平台上支持，其良好跨平台支持也是它的一个优点。`select` 的一个缺点在于**单个进程能够监视的文件描述符的数量存在最大限制，在 Linux 上一般为 1024，可以通过修改宏定义甚至重新编译内核的方式提升这一限制，但是这样也会造成效率的降低**。

### poll

```c++
int poll (struct pollfd *fds, unsigned int nfds, int timeout);
```

不同与 `select` 使用三个位图来表示三种 `fdset` 的方式，`poll` 使用一个 `pollfd` 的指针实现。

```c++
struct pollfd {
    int fd;         /* file descriptor */
    short events;   /* requested events to watch */
    short revents;  /* returned events witnessed */
};
```

`pollfd` 结构包含了要监视的 event 和发生的 event，不再使用 select 那样“参数-值”传递的方式。同时，`pollfd` 并没有最大数量限制（但是数量过大后性能也是会下降）。 和 `select` 函数一样，`poll` 返回后，需要轮询 `pollfd` 来获取就绪的描述符。

从上面看，**`select` 和 `poll` 都需要在返回后，将所有监控的描述符拷贝到内核空间，通过遍历文件描述符来获取已经就绪的 fd**。事实上，同时连接的大量客户端在一时刻可能只有很少的处于就绪状态，因此随着监视的描述符数量的增长，其效率也会线性下降。

### epoll

`epoll` 操作过程需要三个接口，分别如下：

```c++
int epoll_create(int size)；//创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```

#### epoll_create

创建一个 `epoll` 的句柄，`size` 用来告诉内核这个监听的数目一共有多大，这个参数不同于 `select` 中的第一个参数（给出最大监听的 fd+1 的值），参数 `size` 并不是限制了 `epoll` 所能监听的描述符最大个数，只是对内核初始分配内部数据结构的一个建议。当创建好 `epoll` 句柄后，它就会占用一个 fd 值，在 Linux 下如果查看 `/proc/进程id/fd/`，是能够看到这个 fd 的，所以在使用完 `epoll` 后，必须调用 `close()` 关闭，否则可能导致 fd 被耗尽。

#### epoll_ctl

函数是对指定描述符 fd 执行 op 操作。

* `epfd`：是 `epoll_create()` 的返回值。
* `op`：表示 op 操作，用三个宏来表示：添加 `EPOLL_CTL_ADD`，删除 `EPOLL_CTL_DEL`，修改 `EPOLL_CTL_MOD`。分别添加、删除和修改对fd的监听事件。
* `fd`：是需要监听的 fd（文件描述符）。
* `epoll_event`：是告诉内核需要监听什么事，`struct epoll_event` 结构如下：

```c++
struct epoll_event {
  __uint32_t events;  /* Epoll events */
  epoll_data_t data;  /* User data variable */
};

// events可以是以下几个宏的集合
// EPOLLIN ：表示对应的文件描述符可以读（包括对端SOCKET正常关闭）；
// EPOLLOUT：表示对应的文件描述符可以写；
// EPOLLPRI：表示对应的文件描述符有紧急的数据可读（这里应该表示有带外数据到来）；
// EPOLLERR：表示对应的文件描述符发生错误；
// EPOLLHUP：表示对应的文件描述符被挂断；
// EPOLLET： 将EPOLL设为边缘触发(Edge Triggered)模式，这是相对于水平触发(Level Triggered)来说的。
// EPOLLONESHOT：只监听一次事件，当监听完这次事件之后，如果还需要继续监听这个socket的话，需要再次把这个socket加入到EPOLL队列里
```

`epoll()` 的事件注册函数，它不同与 `select()` 是在监听事件时告诉内核要监听什么类型的事件，而是在这里先注册要监听的事件类型。当事件发生时，会触发回调，返回给用户进程。

#### epoll_wait

等待 `epfd` 上的 IO 事件，最多返回 `maxevents` 个事件。
参数 `events` 用来从内核得到事件的集合，`maxevents` 告之内核这个 `events` 有多大，这个 `maxevents` 的值不能大于创建 `epoll_create()` 时的 size，参数 `timeout` 是超时时间（毫秒，0 会立即返回，-1 将不确定，也有说法说是永久阻塞）。该函数返回需要处理的事件数目，如返回 0 表示已超时。

#### epoll 工作模式

`epoll` 对文件描述符的操作有两种模式：LT（level trigger）和 ET（edge trigger）。LT 模式是默认模式，LT 模式与 ET 模式的区别如下：

* LT 模式：当 `epoll_wait()` 检测到描述符事件发生并将此事件通知应用程序，**应用程序可以不立即处理该事件。下次调用 `epoll_wait()` 时，会再次响应应用程序并通知此事件**。
    * LT(level triggered) 是缺省的工作方式，并且同时支持 block 和 no-block socket.在这种做法中，内核告诉你一个文件描述符是否就绪了，然后你可以对这个就绪的 fd 进行 IO 操作。如果你不作任何操作，内核还是会继续通知你的。

* ET 模式：当 `epoll_wait()` 检测到描述符事件发生并将此事件通知应用程序，**应用程序必须立即处理该事件。如果不处理，下次调用 `epoll_wait()` 时，不会再次响应应用程序并通知此事件**。
    * ET(edge-triggered) 是高速工作方式，只支持 no-block socket。在这种模式下，当描述符从未就绪变为就绪时，内核通过 `epoll` 告诉你。然后它会假设你知道文件描述符已经就绪，并且不会再为那个文件描述符发送更多的就绪通知，直到你做了某些操作导致那个文件描述符不再为就绪状态了（比如，你在发送，接收或者接收请求，或者发送接收的数据少于一定量时导致了一个 EWOULDBLOCK 错误）。但是请注意，如果一直不对这个 fd 作 IO 操作（从而导致它再次变成未就绪），内核不会发送更多的通知（only once）
    * ET 模式在很大程度上减少了 `epoll` 事件被重复触发的次数，因此效率要比 LT 模式高。`epoll` 工作在 ET 模式的时候，必须使用非阻塞套接口，以避免由于一个文件句柄的阻塞读/阻塞写操作把处理多个文件描述符的任务饿死。

#### epoll 机制

在 `select`/`poll` 中，进程只有在调用一定的方法后，内核才对所有监视的文件描述符进行扫描，而 `epoll` 事先通过 `epoll_ctl()` 来注册一个文件描述符，**一旦基于某个文件描述符就绪时，内核会采用类似 callback 的回调机制，迅速激活这个文件描述符，当进程调用 `epoll_wait()` 时便得到通知。(此处去掉了遍历文件描述符，而是通过监听回调的的机制。这正是 `epoll` 的魅力所在)**。

`epoll` 的优点主要是一下几个方面：

* 监视的描述符数量不受限制，它所支持的 fd 上限是最大可以打开文件的数目，这个数字一般远大于 2048，举个例子，在 1GB 内存的机器上大约是 10 万左右，具体数目可以 `cat /proc/sys/fs/file-max` 察看,一般来说这个数目和系统内存关系很大。`select` 的最大缺点就是进程打开的 fd 是有数量限制的。这对于连接数量比较大的服务器来说根本不能满足。虽然也可以选择多进程的解决方案（Apache 就是这样实现的），不过虽然 Linux 上面创建进程的代价比较小，但仍旧是不可忽视的，加上进程间数据同步远比不上线程间同步的高效，所以也不是一种完美的方案。
* IO 的效率不会随着监视 fd 的数量的增长而下降。`epoll` 不同于 `select` 和 `poll` 轮询的方式，而是通过每个 fd 定义的回调函数来实现的。只有就绪的 fd 才会执行回调函数。
* 如果没有大量的 `idle-connection` 或者 `dead-connection`，`epoll` 的效率并不会比 `select/poll` 高很多，但是当遇到大量的 `idle-connection`，就会发现 `epoll` 的效率大大高于 `select`/`poll`。