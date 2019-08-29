---
title: Go中使用jsonrpc进行远程调用
date: 2017-07-03
update: 2018-04-12
categories: Go
tags: [go, json, rpc]
---

利用json和RPC可以很方便的进行远程数据交换和程序调用，本文根据自身的经历对Go中使用jsonrpc库进行远程调用进行总结。

<!--more-->

## JSON-RPC

JSON-RPC就是使用JSON的数据格式来进行RPC的调用，远程连接可以使用TCP或者HTTP，简单易用。

**请求数据结构：**

```json
{
    "method": "getName",
    "params": ["1"],
    "id": 1
}
```

* method: 远端的方法名

* params: 远程方法接收的参数列表

* id: 本次请求的标识码，远程返回时数据的标识码应与本次请求的标识码相同

**返回数据结构：**

```json
{

    "result": {"id": 1, "name": "name1"},
    "error": null,
    "id": 1
}
```

* result: 远程方法返回值

* error: 错误信息

* id: 调用时所传来的id

## Go中的JSON-RPC使用

在Go中使用JSON-RPC非常简单，只需要几个常见的包就可以了：

* net/rpc

net/rpc包实现了最基本的rpc调用，它默认通过HTTP协议传输gob数据来实现远程调用。

服务端实现了一个HTTP server,接收客户端的请求，在收到调用请求后，会反序列化客户端传来的gob数据，获取要调用的方法名，并通过反射来调用我们自己实现的处理方法，这个处理方法传入固定的两个参数，并返回一个error对象，参数分别为客户端的请求内容以及要返回给客户端的数据体的指针。

* net/rpc/jsonrpc

net/rpc/jsonrpc包实现了JSON-RPC协议，即实现了net/rpc包的ClientCodec接口与ServerCodec，增加了对json数据的序列化与反序列化来取代gob格式的数据，使得调用更加具有通用性，可以使用Python等利用http请求，直接发送json字符串来调用服务器上的应用程序。

## Go中的JSON-RPC示例

### 1. 定义用于传输的数据结构

客户端与服务端双方传输数据，其中数据结构必须得让双方都能处理。首先定义rpc所传输的数据的结构，client端与server端都得用到。

```go
// 需要传输的对象
type RpcObj struct {
    Id   int `json:"id"` // struct标签， 如果指定，jsonrpc包会在序列化json时，将该聚合字段命名为指定的字符串
    Name string `json:"name"`
}

// 需要传输的对象
type ReplyObj struct {
    Ok  bool `json:"ok"`
    Id  int `json:"id"`
    Msg string `json:"msg"`
}
```

### 2. 定义服务端的处理器及其处理方法

```go
// 服务器RPC处理器
type ServerHandler struct{}

// 服务器RPC处理方法
func (sh *ServerHandler) GetName(id int, returnObj *RpcObj) error {
	log.Println("server\t-", "Receive GetName call, id:", id)
	returnObj.Id = id
	returnObj.Name = "peic"
	return nil
}

// 服务器RPC处理方法
func (sh *ServerHandler) SaveName(rpcObj RpcObj, returnObj *ReplyObj) error {
	log.Println("server\t-", "Receive SaveName call, RpcObj:", rpcObj)
	returnObj.Ok = true
	returnObj.Id = rpcObj.Id
	returnObj.Msg = "Save successfully"
	return nil
}
```

* ServerHandler结构可以不需要什么字段，只需要有符合net/rpcserver端处理器约定的方法即可。

* **符合约定的方法必须具备两个参数和一个error类型的返回值**

    * 第一个参数 为client端调用rpc时交给服务器的数据，可以是指针也可以是实体。net/rpc/jsonrpc的json处理器会将客户端传递的json数据解析为正确的struct对象。

    * 第二个参数 为server端返回给client端的数据,必须为指针类型。net/rpc/jsonrpc的json处理器会将这个对象正确序列化为json字符串，最终返回给client端。

* ServerHandler结构需要注册给net/rpc的HTTP处理器，HTTP处理器绑定后，会通过反射得到其暴露的方法，在处理请求时，根据JSON-RPC协议中的method字段动态的调用其指定的方法。

### 3. 设置开启服务器上的监听服务并处理相应调用请求

```go
// 开启RPC服务器
func startServer() {
	// 新建Server
	server := rpc.NewServer()

	// 监听端口
	listener, err := net.Listen("tcp", ":6666")     // 使用tcp连接
	if err != nil {
		log.Fatal("server\t-", "Listen error:", err.Error())
	}
	defer listener.Close()

	log.Println("server\t-", "Start listen on port 6666")

	// 新建RPC处理器
	serverHandler := new(ServerHandler)
	server.Register(serverHandler)

	// 等待连接并处理
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Fatal("server\t-", "Accept error:", err.Error())
		}

		// 在goroutine中处理请求
        // 绑定rpc的编码器，使用http connection新建一个jsonrpc编码器，并将该编码器绑定给http处理器
		go server.ServeCodec(jsonrpc.NewServerCodec(conn))
	}
}
```

### 4. 客户端调用请求

客户端可以采用同步或者异步的方法来进行RPC的调用请求，一般步骤都是建立连接，调用请求，处理结果。

**同步调用：**

```go
// 客户端同步请求
func callRpcBySynchronous() {

	// 连接服务器, Timeout设置为10s
	client, err := net.DialTimeout("tcp", "localhost:6666", 1000*1000*1000*10)
	if err != nil {
		log.Fatal("client\t-", err.Error())
	}
	defer client.Close()

	// 建立RPC通道
	rpcClient := jsonrpc.NewClient(client)

	// 测试1
	// 服务器返回对象
	var response1 RpcObj
	request1 := 1
	log.Println("client\t-", "Call GetName method")
	// 请求数据，rpcObj对象会被填充
	rpcClient.Call("ServerHandler.GetName", request1, &response1) // 此处必须传入指针
	log.Println("client\t-", "Receive remote return:", response1)

	// 测试2
	// 服务器返回对象
	var response2 ReplyObj
	request2 := RpcObj{2, "Synchronous"}
	log.Println("client\t-", "Call Save method")
	rpcClient.Call("ServerHandler.SaveName", request2, &response2) // 此处必须传入指针
	log.Println("client\t-", "Receive remote return:", response2)
}
```

**异步调用：**

```go
// 客户端异步请求
func callRpcByAsynchronous() {
	client, err := net.DialTimeout("tcp", "localhost:6666", 1000*1000*1000*10)
	if err != nil {
		log.Fatal("client\t-", err.Error())
	}
	defer client.Close()

	rpcClient := jsonrpc.NewClient(client)

	// 请求次数
	requestNum := 150
	// 用于阻塞主goroutine
	endChan := make(chan int, requestNum)

	for i := 1; i <= requestNum; i++ {
		request := RpcObj{i, "Asynchronous"}
		log.Println("client\t-", "Call SaveName method")

		// 进行异步请求
		divCall := rpcClient.Go("ServerHandler.SaveName", request, &ReplyObj{}, nil)    

		// 在一个新的gorontinue中异步获取远程返回的数据
		go func(num int) {
            // 注意如何取出调用结果
			reply := divCall.Done
			tmp := <-reply
			log.Println("client\t-", "Receive remote return by Asychronous", tmp.Reply)
			endChan <- num
		}(i)
	}

	// 等待所有请求的结果全部返回，则可以退出
	for i := 1; i <= requestNum; i++ {
		_ = <-endChan
	}

	log.Println("Exit...")
}
```

### 综合示例：

将上述代码放置在go文件中，运行即可

```go
package main

import (
	"log"
	"net"
	"net/rpc"
	"net/rpc/jsonrpc"
)

// 上述代码
.......

func main() {
	go startServer()
	// callRpcBySynchronous()
	callRpcByAsynchronous()
}
```

异步调用的结果如下：

```
2017/07/03 11:55:00 server	- Start listen on port 6666
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 client	- Call SaveName method
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {1 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {6 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {4 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {5 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {10 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {8 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {7 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {9 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {2 Asynchronous}
2017/07/03 11:55:00 server	- Receive SaveName call, RpcObj: {3 Asynchronous}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 1 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 4 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 10 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 5 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 2 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 8 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 7 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 3 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 9 Save successfully}
2017/07/03 11:55:00 client	- Receive remote return by Asychronous &{true 6 Save successfully}
2017/07/03 11:55:00 Exit...
```

### Go中JSON-RPC的Server和Client处理示意图

* **Server示意图**

![Server示意图](/images/posts/go/o_golang_jsonrpc_server.png)

* **Client示意图**

![Client示意图](/images/posts/go/o_golang_jsonrpc_client.png)