---
title: TensorFlow 显示运行中间结果方法
date: 2019-08-26 11:22:25
update: 2019-08-26 11:22:25
categories: DeepLearning
tags: [TensorFlow, 静态图, ckpt, meta]
---

TensorFlow 以静态图运行，因此想查看中间结果比较麻烦。本文以强化学习的 ppo 网络为例，结合代码注释提供一个思路。

<!-- more -->

首先是训练过程中模型的保存：

```python
import tensorflow as tf

# graph.pbtxt
tf.train.write_graph(sess.graph_def, path, filename, as_text)

# ckpt
saver = tf.train.Saver({var for var in tf.global_variables()}, max_to_keep=5)
saver.restore(sess, ckpt.model_checkpoint_path)
saver.save(sess, checkpoint_path)
```

保存的模型应该有三个文件：`*.ckpt.index`，`*.ckpt.meta`，`*.ckpt.data-*`。之所以保存 `*.pbtxt`，是因为我们查看模型中间层的时候需要名字，`pbtxt` 是可以直接查看的模型结构文件，方便我们查看。然后如下调用进行 inference 和显示结果。

```python
#! -*-coding: utf-8 -*-

import tensorflow as tf
import numpy as np

with tf.Session() as sess:
    modelpath = r'../ppo/2/'    # 存放模型的地方
    # 加载模型和权重
    saver = tf.train.import_meta_graph(modelpath + 'model.ckpt.meta')
    saver.restore(sess, tf.train.latest_checkpoint(modelpath))

    # 创建图
    graph = tf.get_default_graph()
    print('Successfully load the pre-trained model!')
    
    # 加载测试数据
    observation_data = np.array(np.load('../ppo/2/observation.npy'))
    observation_data = observation.reshape((1,197,1))
    print(observation_data.shape) 
    
    # 设置输入 tensor
    in_observation = graph.get_tensor_by_name("ppo/observation:0") # :0 表示 batch 中的第一个，如果 batch 是 1 就是全部结果了
    print(in_observation.shape)
    
    # 设置输出 tensor
    out_neglogps = graph.get_tensor_by_name("ppo/neglogps:0")   # :0 同输入
    out_actions = graph.get_tensor_by_name("ppo/actions:0")
    out_values = graph.get_tensor_by_name("ppo/values:0")
    out_fetches = [out_neglogps, out_actions, out_values]
    
    # 需要输出的层，其实和输出 tensor 是一类的
    mlp_fc0 = graph.get_tensor_by_name("ppo/model/vf/add:0")
    mid_fetches = [mlp_fc0]
    
    # 要显示的 tensor
    fetches = out_fetches + mid_fetches
    
    # 运行图
    output = sess.run(fetches, feed_dict={in_observation: observation_data})

    # 打印结果
    for out in output:
        print("out: ", out)
```