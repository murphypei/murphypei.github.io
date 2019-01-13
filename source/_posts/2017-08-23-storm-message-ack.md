---
layout: post
title: Storm中消息确认机制
date: 2017-08-23
update: 2018-04-12
categories: Java
tags: [java, storm, kafka, acker]
---

storm为了维持对于数据处理的完整性，使用消息确认机制，本文记录我解决一个问题中查阅的关于 storm 的消息确认机制的相关知识。

<!--more-->

## 问题来源

在 kafka-storm 的使用中，发现一个消息被处理后，spout 延迟很久也没 emit 下一个消息，并且还伴随着消息的重复发送，非常不正常。

## kafka-storm 并行

我是 storm 的新手，首先想到的原因是 bolt 处理的太慢了？虽然这个不大可能，但我还是查阅了一些资料，了解到在 kafka-storm 中，spout 在初始化的时候可以设置线程数，但是这个线程数受限，必须小于等于 topic 的 partition 数目，其实也不难理解，一次并行最多能从当前消息主题的每个分区中同时读取消息。

但我设置了发现，这只能解决一次处理的问题，并行之后，前述问题依然存在。

## 消息确认机制

我查看处理后的消息发现，这些消息在很早的时候就被处理，而 spout 却陷入等待。我猜想，是不是 spout 不知道消息已经处理好了？于是我查阅了一些资料。

### tuple 的 fully processed

storm 的 bolt 收到的都是 tuple，而且会产生 tuple 发送给下面的 bolt 。因为 tuple 被 emit 出去后, 可能会被多级bolt处理, 并且 bolt 也有可能由该 tuple 生成多组 tuples，最终由一个 tuple trigger(触发)的所有 tuples 会形成一个树或 DAG(有向无环图)。

> 只有当 tuple tree 上的所有节点都被成功处理的时候，storm 才认为该 tuple 被 fully processed。如果 tuple tree 上任一节点失败或者超时，都被看作该 tuple fail， 失败的 tuple 会被重发。

### ack实现机制

首先，所有 tuple 都有一个唯一标识 msgId，当 tuple 被 emit 的时候确定。

```java
_collector.emit(new Values("field1", "field2", 3) , msgId);
```

而对于 spout 接口，除了获取 tuple 的 nextTuple 还有 ack 和 fail，当 Storm detect 到 tuple 被fully processed，会调用 ack， 如果超时或 detect fail，则调用 fail。

```java
public interface ISpout extends Serializable {
    void open(Map conf, TopologyContext context, SpoutOutputCollector collector);
    void close();
    void nextTuple();
    void ack(Object msgId);
    void fail(Object msgId);
}
```
而对于 Spout 中的 tuple queue， 每次发射一个 tuple，然后将这个 tuple 状态改为 pending，防止该tuple被多次发送。一直等到该 tuple 被 ack，才真正的 pop 该 tuple，当然该 tuple 如果 fail，就重新把状态改回初始状态，也就可以重发这个 tuple。这也解释， 为什么 tuple 只能在被 emit 的 spout 被 ack 或 fail，因为只有这个 spout 的 queue 里面有该 tuple。

当分析到这一步，大概也就明白了？难道是消息没得到及时的确认，从而导致 spout 一直等待直到超时重发，那么 storm 中，spout 是如何知道 tuple 是否成功被 fully processed？

要解决这个问题, 可以分为两个问题,    

1. 如何知道tuple tree的结构?    

2. 如何知道tuple tree上每个节点的运行情况, success或fail?



答案很简单，**显式声明**。

* tuple tree 的结构

对于 tuple tree 的结构，需要知道每个 tuple 由哪些 tuple 产生，即 tree 节点间的 link tree 节点间的 link 称为 anchoring，当每次 emi t新 tuple 的时候，必须显式的通过 API 建立 anchoring

```java
_collector.emit(tuple, new Values(word)); 
```

当一个 bolt 依赖多个输入的时候：

```java
List<Tuple> anchors = new ArrayList<Tuple>();
anchors.add(tuple1);
anchors.add(tuple2);
_collector.emit(anchors, new Values(1, 2, 3));
```

当然，如果我们对于可靠性的要求并不高，也可以调用 unanchoring 的版本来 emit，可以提高效率

```java
_collector.emit(new Values(word));
```

* tuple 在每个节点的确认

对于 tuple tree 上每个节点的运行情况, 你需要在每个 bolt 的逻辑处理完后, 显式的调用 OutputCollector 的 ack 和 fail 来汇报 

而对我项目的检查发现，我错误的认为，确实是由最后一个 bolt 来完成，只在最后一个 bolt 中进行了输入 tuple 的确认，所以引发了超时重传（默认设置的是30s）

### 相关API

对于 `IRichBolt` 接口和 `BaseRichBolt` 基类，必须显示书写 `ack(tuple)`，这汇总机制会给程序员造成额外的工作, 尤其对于很多简单的 case， 比如 filter， 每次都要去显式的建立 anchoring 和 ack。

所以 storm 提供简单的版本 `BaseBasicBolt `, 会自动的建立 anchoring，并在 bolt 执行完自动调用 ack。只需要重写 execute 和 declareOutputFields 就行了。

## 更深入的Acker

前面说了，storm 的 spout 是通过 ack 机制来控制一个消息是否被 fully processed 或者重发，而且也知道是根据每个节点进行处理的确认来跟踪，那么在整个处理流程中，spout 如何追踪一个 message 的 ack 呢？这就涉及到 Acker 了。

strom 是通过 Acker（一种特殊的 Blot Task）来监控 tuple 树，最终它通过调用 Spout 中的 ack 或者 fail 方法来告诉 Spout 消息的最终情况。对于 spout 产生的 tuple，所有的 tuple 都会有一个随机的 64bit 的 id 用于被 track，tuple 之间通过 emit 时的 anchor 形成 tuple tree，并且每个 tuple 都知道产生它的 spout tuple 的 id (通过不断的 copy 传递)，当任何 tuple 在 bolt 中被 ack 的时候, 都会 send message 到相应的 acker。这样 spout 也就能追踪到一个初始的 tuple 是否被 fully processed。
