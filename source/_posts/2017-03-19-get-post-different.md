---
title: GET 和 POST 的区分
date: 2017-03-19
update: 2018-04-12
categories: 网络编程
tags: [GET, POST, web]
---

HTTP 中最常见的两种请求方式 GET 和 POST 区别很大，但是本质上的区别并不是用法上的那么简单。

<!--more-->

根据搜集到的资料来看，区别可以分为两种，实际应用的区别和本质上的区别。

### 实际应用的区别（平常所说的区别）

| 方法 | GET | POST |
| :---: | :--: | :--: |
|后退按钮/刷新|无害|数据会被重新提交（浏览器应该告知用户数据会被重新提交）。|
|书签|可收藏为书签| 不可收藏为书签|
|缓存|能被缓存|不能缓存|
|编码类型|  application/x-www-form-urlencoded|application/x-www-form-urlencoded 或 multipart/form-data。为二进制数据使用多重编码。|
|历史|  参数保留在浏览器历史中|参数不会保存在浏览器历史中|
|对数据长度的限制|是的。当发送数据时，GET 方法向 URL 添加数据；URL 的长度是受限制的（URL 的最大长度是 2048 个字符）。|无限制|
|对数据类型的限制|只允许 ASCII 字符| 没有限制。也允许二进制数据|
|安全性|与 POST 相比，GET 的安全性较差，因为所发送的数据是 URL 的一部分。在发送密码或其他敏感信息时绝不要使用 GET ！|POST 比 GET 更安全，因为参数不会被保存在浏览器历史或 web 服务器日志中。|
|可见性|数据在 URL 中对所有人都是可见的|数据不会显示在 URL 中|

### 真正的区别来源于 RFC 中的定义

> *The GET method requests transfer of a current selected representation for the target resource. GET is the primary mechanism of information retrieval and the focus of almost all performance optimizations. Hence, when people speak of retrieving some identifiable information via HTTP, they are generally referring to making a GET request.
> A payload within a GET request message has no defined **semantics**; sending a payload body on a GET request might cause some existing implementations to reject the request. The POST method requests that the target resource process the representation enclosed in the request according to the resource’s own specific semantics.*

需要注意的是：

> The request method token is the primary source of request semantics; it indicates the purpose for which the client has made this request and what is expected by the client as a successful result.

这里牵涉到一个很重要的词语：**semantic（语义）**

#### 语法和语义的区别

一种语言是合法句子的集合。什么样的句子是合法的呢？可以从两方面来判断：语法和语义。语法是和文法结构有关，然而语义是和按照这个结构所组合的单词符号的意义有关。合理的语法结构并不表明语义是合法的。例如我们常说：我上大学，这个句子是符合语法规则的，也符合语义规则。但是大学上我，虽然符合语法规则，但没有什么意义，所以说是**不符合语义**的。

#### HTTP中的语法和语义

对于 HTTP 请求来说，语法是指请求响应的格式，比如请求第一行必须是 方法名 URI 协议/版本 这样的格式。语义则定义了这一类型的请求具有什么样的性质。比如 GET 的语义就是获取资源，POST 的语义是处理资源，那么在具体实现这两个方法时，就必须考虑其语义，做出符合其语义的行为。

### 简单总结

1. GET 和 POST 在用法和实现上是可以没有语法上的区别的（可以，但具体到实现是有区别的），但是语义不同，也就是应用的场景不同
2. 在符合语法的前提下实现违背语义的行为也是可以做到的，比如使用 GET 方法修改用户信息，POST 获取资源列表，这样就只能说这个请求是合法的，但是**不符合语义**的。 
3. 如果说本质的区别，那就是语义上的区别，即：
    * GET 的语义是请求获取指定的资源。GET 方法是安全、幂等、可缓存的（除非有 Cache-Control Header 的约束），GET 方法的报文主体没有任何语义。
    * POST 的语义是根据请求负荷（报文主体）对指定的资源做出处理，具体的处理方式视资源类型而不同。POST 不安全，不幂等，（大部分实现）不可缓存。
    * 具体到在微博这个场景里，GET 的语义会被用在看看我的 Timeline 上最新的 20 条微博这样的场景，而 POST 的语义会被用在发微博、评论、点赞这样的场景中。
