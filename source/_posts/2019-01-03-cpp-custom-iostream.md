---
title: C++ 定制输入输出流
date: 2019-01-03 09:19:44
update: 2019-01-03 09:19:44
categories: C++
tags: [C++, stream, streambuf, ios]
---

C++中的输入输出流规范好用，有时候我们需要借鉴其形式定制自己的输入输出流

<!--more-->

## 前言

为了提供更灵活的输入输出控制，并让其支持更多的类型和格式，C++ 引入了输入输出流。C++ 的输入输出系统中提供了两个基类，分别是 `ios_base` 和 `ios`。基于这两个基类实现了我们常用的标准输入输出流 `istream` 和 `ostream`。同时，基于这两个流，C++ 提供了另外两种类型：文件输入输出流 `fstream` 以及字符串输入输出流 `stringstream`。这些类之间的继承关系可以用下图来说明：

![iostream](/images/posts/cplusplus/iostream.gif)

对于大多数 c++ 程序而言，使用系统提供的输入输出框架已经足够了。但是，对于想要根据需求改变流表现的使用者来说，了解如何定制流的过程至关重要。例如，你可能希望在你的项目中像标准输入输出一样来读取 tcp socket，或者希望像标准输入输出一样来封装一个对于 FILE* 的读取和写入，再或者你希望利用输入输出流的方式来操纵内存中的数据，这些都可以通过定制自己的流来实现。

## streambuf简介

我们都知道每一个输入输出流都会绑定相应的 `buffer`，也就是输入输出缓冲区。这个缓冲区就是基于上图中的 `streambuf` 类来定义的。可以看到，文件输入输出使用的是继承自 `streambuf` 的 `filebuf`，而字符串流则是使用的 `stringbuf`。事实上，`streambuf` 是输入输出系统中最关键的一部分，它负责提供缓冲功能，并提供“顺序读取设备”的抽象，也就是把数据刷新到外部设备中或者从外部设备中读取数据。而具体的流可以只负责进行格式化或者完成其他类型地工作。

现在假设我们有这样一个需求：用标准输入输出的方式来封装一个 TCP socket，也就是定义一个 BasicTcpStream，使其可以进行如下地操作：

```c++
std::string inputStr;
BasicTcpStream tcpInOut1(socket1);
BasicTcpStream tcpInOut2(socket2);

// 1. 从标准输入中接受字符串，然后写入到socket中
while(cin >> inputStr) {
    tcpInOut1 << inputStr << endl;
}

// 2. 从一个socket中接收数据写入到另一个socket中
while(tcpInOut1 >> inputStr) {
    tcpInOut2 << inputStr << endl;
}
```

注意这并不是一个无意义的需求，事实上 phxrpc 就实现了这个功能。为了达到目的，那么我们需要完成两步的工作：

    1. 按照需求自定义一个 `buffer` 类，该 `buffer` 一般需要继承自 `streambuf`，并且覆盖类中的部分虚函数实现。
    2. 定义一个相应的 `stream` 来使用该 `buffer` 类，也就是利用 `buffer` 类来同外部设备打交道，读取或者写入 socket。

## 自定义streambuf

`streambuf` 是一个 `traits class`，由 `basic_streambuf` 所定义（具体什么是 `traits class` 以及为什么要这么定义 `streambuf`，以后再说）。

```c++
template< 
    class CharT, 
    class Traits = std::char_traits<CharT>
> class basic_streambuf;
 
typedef   basic_streambuf<char> streambuf; 
typedef   basic_streambuf<wchar_t> wstreambuf;
```

其中 `streambuf` 基于标准字符类型 `char`，而 `wstreambuf` 基于宽字符类型 `wchar_t`，这里我们的实例均基于 `streambuf` 所实现。`streambuf` 既定义了输出的操作也定义了输入操作，我们将分别介绍如何实现对于输入输出的定制。

### 用于输出的streambuf

用于输出的`streambuf`可以类比标准输出`std::cout`，用于`<<`操作符存放数据，将输出数据放置到缓冲区中。`streambuf` 使用三个指针来管理相应的输出缓冲区（缓冲区需要自行设置），分别由接口 `pbase`，`pptr`和 `epptr` 返回。其中 `pbase` 是缓冲区的基指针，指向缓冲区的第一个字节，`epptr` 是缓冲区的尾指针，指向其最后一个字节的下一个字节（类似于 iter.end() 的作用），而 `pptr` 指向缓冲区当前可用的位置，也就是 `pptr` 之前都已经被数据所填充，如下图：

![](/images/posts/cplusplus/stream-out.png)

`streambuf` 定义的输出相关的函数主要有 `sputc` 和 `sputn`，前者输出一个字符到缓冲区，并且将指针 `pptr` 向后移动一个字符，后者调用函数 `xsputn` 连续输出多个字符，`xsputn` 默认的实现就是多次调用 `sputc`。由于缓冲区有限，当 `pptr` 指针向后移动满足 `pptr() == epptr` 时，说明缓冲区满了，这时将会调用函数 `overflow` 将数据写入到外部设备并清空缓冲区；清空缓冲区的方式则是调用 `pbump` 函数将指针 `pptr` 重置。我们可以通过如下的类来实现自定义的输出 buffer：

```c++
#include <iostream>

class TcpStreamBuf : public std::streambuf {
 public:
     TcpStreamBuf(int socket, size_t buf_size);
     ~TcpStreamBuf();

     int overflow(int c);  // 字符 c 是调用 overflow 时当前的字符
     int sync();           // 将buffer中的内容刷新到外部设备，不管缓冲区是否满

 private:
     const size_t buf_size_;
     int socket_;
     char* pbuf_;  // 输出缓冲区
 };
 ```

我们在初始化时来申请 buffer 内存，并且通过 `setp` 函数来指定初始 `pbase` 以及 `epptr` 指针的位置：

```c++
TcpStreamBuf::TcpStreamBuf(int socket, size_t buf_size) :
    buf_size_(buf_size), socket_(socket) {
    assert(buf_size_ > 0);
    pbuf_ = new char[buf_size_];

    setp(pbuf_, pbuf_ + buf_size_); // set the pointers for output buf
}

// flush the data to the socket
int TcpStreamBuf::sync() {
    int sent = 0;
    int total = pptr() - pbase();  // data that can be flushed
    while (sent < total) {
        int ret = send(socket_, pbase()+sent, total-sent, 0);
        if (ret > 0) sent += ret;
        else {
            return -1;
        }
    }
    setp(pbase(), pbase() + buf_size_);  // reset the buffer
    pbump(0);  // reset pptr to buffer head

    return 0;
}
```

上面的构造函数和 `sync` 函数都比较容易理解。构造函数申请一块堆内存 `pbuf` 作为输出缓冲区，然后调用 `setp` 函数来设置 buffer 的头指针 `pbase` 和尾指针 `epptr`。`sync` 函数强制将已经缓存的数据调用 `send` 发送出去，也就是刷新到外部设备。

接下来我们看如何定义函数 `overflow`。注意，**`overflow`是缓冲区满了的时候自动调用的**，由于调用 `overflow` 时当前的缓冲区已经满了，因此 `overflow` 的参数 `c`，也就是传入的字符，必须在缓冲区中的数据刷新到外部设备之后才能够放入到 `buffer` 中，否则 `overflow` 应该返回 `eof`。

```c++
int TcpStreamBuf::overflow(int c) {
    if (-1 == sync()) {
        return traits_type::eof();
    }
    else {
        // put c into buffer after successful sync
        if (!traits_type::eq_int_type(c, traits_type::eof())) {
            sputc(traits_type::to_char_type(c));
        }

        // return eq_int_type(c, eof()) ? eof():c;
        return traits_type::not_eof(c);
    }
}
```

完成了上述这些步骤，我们基本上已经定义了一个可以用于输出的缓冲区 `TcpStreamBuf`，接下来我们同样介绍一下，如何为该缓冲区类增加输入的功能。

### 用于输入的streambuf

前面的需求中，希望 `TcpStream` 能够支持类似于 `cin` 的操作，也就是直接从 `socket` 中读取数据。这就要求我们定义的底层 `TcpStreamBuf` 需要支持输入操作。同管理输出缓冲区一样，`streambuf` 也使用三个指针，`eback()`，`gptr()` 以及 `egptr()` 来指示输入缓冲区的开始字节，当前可用字节以及缓冲区尾的下一字节，如下图所示：

![](/images/posts/cplusplus/stream-out.png)

`streambuf` 类同样定义了如下几个函数来支持对于输入缓冲区的读取和管理：

* `sgetc`: 从输入缓冲区中读取一个字符；
* `sbumpc`: 从输入缓冲区中读取一个字符，并将 gptr() 指针向后移动一个位置；
* `sgetn`: 从输入缓冲区中读取 n 个字符；
* `sungetc`: 将缓冲区的 gptr() 指针向前移动一个位置；
* `sputbackc`: 将一个读取到的字符重新放回到输入缓冲区中；

与输出缓冲区不同的是，输入缓冲区需要额外提供 `putback` 操作，也就是将字符放回到输入缓冲区内。我们的 `TcpStream` 暂时不需要支持该功能，如果想了解如何添加 `putback` 功能可以参考一下[phxrpc](http://wizmann.tk/phxrpc-1.html)。

当输入缓冲区满足 `gptr() == egptr()` 时，表明缓冲区已经没有数据可以读取，函数 `sget`c 将会调用 `underflow` 函数来从外部设备中拉取数据。不同于 `sgetc`，`sbumpc` 在这种情况下则会调用 `uflow` 来实现拉取数据，并移动缓冲区读取指针的目的。默认情况下，`uflow` 会调用 `underflow`，我们也无需额外实现 `uflow`，但在特殊情况下（例如没有定义缓冲空间），则需要覆盖实现两个函数。

知道这些之后，我们就可以为 `TcpStreamBuf` 增加输入的功能。首先我们需要在构造时，为 `TcpStreamBuf` 申请一块空间用于输出缓冲区，并调用 `setg` 来设置相应的三个指针:

```c++
gbuf_ = new char[buf_size_];
setg(gbuf_, gbuf_, gbuf_);
```

需要注意的是，`setg` 比 `setp` 多一个参数，需要同时设置三个指针的指向位置。接下来我们需要定义当缓冲区已经没有数据时需要进行的操作，也就是 `underflow` 函数：

```c++
int TcpStreamBuf::underflow() {
    int ret = recv(socket_, eback(), buf_size_, 0);
    if (ret > 0) {
        setg(eback(), eback(), eback() + ret);
        return traits_type::to_int_type(*gptr());
    } else {
        return traits_type::eof();
    }
}
```

当缓冲区没有数据时，函数 `underflow` 将直接从 `socket` 中读取数据到 `gbuf_` 中，然后设置尾指针为 `eback() + ret`，设置 `gptr` 为指向数据的第一个字节 `eback`。同时返回当前可以读取的位置上的数据 `*gptr()`。

上述的函实现已经基本满足一个可以用于读取写入 `TCP socket` 的 `streambuf`，接下来我们介绍第二步，也就是定义一个 `stream` 来使用 `TcpStreamBuf`。

## 自定义stream

自定义的类 `BasicTcpStream` 需要继承于类 `iostream`，并且将 `TcpStreamBuf` 作为底层的缓冲区使用：

```c++
class BasicTcpStream : public std::iostream {
public:
    BasicTcpStream(int socket, size_t buf_size): 
        iostream(new TcpStreamBuf(socket, buf_size), 
        socket_(socket), buf_size_(buf_size) {
    }
    ~BasicTcpStream();

private:
    int socket_;
    const size_t buf_size_;
};
```

下面不再为这个类增加更多的内容，仅仅将其作为一个简单的包装类来测试一下 `TcpStreamBuf` 的使用。我们首先需要编写一个简单的 `client` 和 `server` 来建立起 tcp 链接，然后通过类似于标准输入输出的方式来实现对于 `socket` 的写入和读取。

`server.c` 的写入代码如下：

```c++
for (;;) {
    int clientfd = -1;
    struct sockaddr_in addr;
    socklen_t socklen = sizeof(addr);

    clientfd = accept(sockfd, (struct sockaddr*) &addr, &socklen);

    if (clientfd >= 0) {
        tcpstream::BasicTcpStream tcpInOut(clientfd, BUF_SIZE);
        tcpInOut << "Hello World" << std::endl;

        for(char c = 'j'; c <= 'q'; c++) {
            tcpInOut << c << std::endl;
        }

        int rc;
        while(tcpInOut >> rc) {
            std::cout << char(rc) << std::endl;
        }
    }
}
```

对于每一个接入的客户端，首先写回一个 HelloWorld，然后从字母 j 到字母 q 逐个写入，之后接受从客户端发过来的字符。

客户端的代码如下：

```c++
tcpstream::BasicTcpStream tcpInOut(sockfd, BUF_SIZE);
char line[64] = { 0 };

if(tcpInOut.getline(line, 64).good()) {
    std::cout << line << std::endl;
}
else {
    std::cout << "receive error: " << line << std::endl;
}

char c;
while(tcpInOut >> c) {
    std::cout << c << std::endl;
    tcpInOut << std::toupper(c) << std::endl; 
    if(c == 'q') {
        close(sockfd);
        break;
    }
}
```

也就是将服务端发送过来的字母全部转为大写并发送回去。

本文参考：http://kaiyuan.me/2017/06/22/custom-streambuf/