---
title: TensorFlow 序列化数据格式
date: 2020-04-15 12:14:38
update: 2020-04-15 12:14:38
categories: DeepLearning
tags: [TensorFlow, 序列化, protobuf, pbtxt]
---

TensorFlow 保存模型结构和参数的方法有几种，日常都会遇到这些不同格式的数据，做记录总结。

<!-- more -->

一般来讲，TensorFlow 有三种文件格式：

- checkpoint：一种独有的文件格式，包含四个文件。保存了计算图和权重，无法直接打开阅读。多用于训练时。
- pb：protobuf 格式的二进制文件，可以只保存计算图（很小），也同时保存了权重和计算图（很大），无法直接打开阅读。
  - 包含权重的文件中所有的 variable 都已经变成了 tf.constant 和 graph 一起 frozen 到一个文件。
- pbtxt：pb 文件的可读文本，如果同时保存权重，文件会很大，一般用的比较少，可用于调试查看网络结构。

下面是我写的一个关于 TensorFlow 存储和加载不同格式的例子，配合注释就知道每种格式怎么读写了：

```python
import tensorflow as tf
import numpy as np
import os
from tensorflow.python.framework.graph_util import convert_variables_to_constants


class TestCase(object):

    def __init__(self, batch_size, feature_size, hidden_size, output_size):
        np.random.seed(123)

        self.batch_size = batch_size
        self.feature_size = feature_size
        self.hidden_size = hidden_size
        self.output_size = output_size

        self.input_file = "./tf_test_input.txt"
        self.output_file = "./tf_test_output.txt"
        self.ckpt_prefix = "./ckpt/model"
        self.pb_file = "./pb/tf_test_model.pb"
        if not os.path.exists(os.path.dirname(self.ckpt_prefix)):
            os.makedirs(os.path.dirname(self.ckpt_prefix))
        if not os.path.exists(os.path.dirname(self.pb_file)):
            os.makedirs(os.path.dirname(self.pb_file))

        self.input_name = 'input'
        self.output_name = 'output'

        self.prepare_data()

    def prepare_data(self):
        self.x_data = np.random.random((self.batch_size, self.feature_size)) * 2.0
        self.y_data = np.random.random((self.batch_size, self.output_size)) * 2.0
        with open(self.input_file, 'w') as f:
            f.write('\n'.join([str(i) for i in self.x_data.flatten()]))
            print("save input data to file: " + self.input_file)
        with open(self.output_file, 'w') as f:
            f.write('\n'.join([str(i) for i in self.y_data.flatten()]))
            print("save output data to file: " + self.input_file)

    def add_fc_layer(self, inputs, in_size, out_size, activation_function=None):
        # add one more layer and return the output of this layerb
        w = tf.Variable(tf.random_normal([in_size, out_size]))
        b = tf.Variable(tf.zeros([1, out_size]) + 0.1)
        y = tf.matmul(inputs, w) + b
        if activation_function is None:
            outputs = y
        else:
            outputs = activation_function(y)
        return outputs

    def train_network(self):
        with tf.Session(graph=tf.Graph()) as sess:
            x_train_data = tf.placeholder(tf.float32, shape=(self.batch_size, self.feature_size), name=self.input_name)
            y_train_data = tf.placeholder(tf.float32, shape=(self.batch_size, self.output_size), name='label')
            l1 = self.add_fc_layer(x_train_data, self.feature_size, self.hidden_size, tf.nn.relu)
            prediction = self.add_fc_layer(l1, self.hidden_size, self.output_size, None)
            output = tf.identity(prediction, self.output_name)

            loss = tf.reduce_mean(tf.reduce_sum(tf.square(y_train_data - output), reduction_indices=[1]))
            train_step = tf.train.GradientDescentOptimizer(0.1).minimize(loss)

            # 设置 checkpoint saver，用于保存 checkpoint 格式的数据。
            saver = tf.train.Saver()
            # 初始化所有参数
            sess.run(tf.global_variables_initializer())

            for i in range(1001):
                sess.run(train_step, feed_dict={x_train_data: self.x_data, y_train_data: self.y_data})
                # snapchat
                if i % 50 == 0:
                    # to see the step improvement
                    # print(sess.run([loss, output], feed_dict={x_train_data: self.x_data, y_train_data: self.y_data}))
                    print(sess.run(loss, feed_dict={x_train_data: self.x_data, y_train_data: self.y_data}))
                    # 每迭代 50 次，保存一次模型。这里由于没有修改名字，因为会覆盖掉前面的 checkpoint。
                    saver.save(sess, self.ckpt_prefix)

            # 保存 pbtxt 格式的计算图，只有图结构，没有权重。
            tf.train.write_graph(tf.get_default_graph(), ".", self.pb_file + "txt", as_text=True)

    def restore_from_ckpt(self):
        with tf.Session() as sess:
            saver = tf.train.import_meta_graph(self.ckpt_prefix + '.meta')
            saver.restore(sess, tf.train.latest_checkpoint(os.path.dirname(self.ckpt_prefix)))

            # 这里不能重新初始化，否则参数被覆盖了
            # sess.run(tf.global_variables_initializer())

            # 打印所有 tensor
            # print([[n.name for n in tf.get_default_graph().as_graph_def().node]])

            input_tensor = tf.get_default_graph().get_tensor_by_name('{}:0'.format(self.input_name))
            output_tensor = tf.get_default_graph().get_tensor_by_name('{}:0'.format(self.output_name))

            print(sess.run(output_tensor, feed_dict={input_tensor: self.x_data}))

    # save graph as pb file
    def convert_to_pb(self):
        with tf.Session() as sess:
            # 从 checkpoint 中恢复模型。
            saver = tf.train.import_meta_graph(self.ckpt_prefix + '.meta')
            saver.restore(sess, tf.train.latest_checkpoint(os.path.dirname(self.ckpt_prefix)))
            graph = tf.get_default_graph()

            # 转存为 pb 文件，同时保留计算图和 variable 的值。将 variable 转为 constant。
            output_graph_def = convert_variables_to_constants(
                sess, sess.graph_def, output_node_names=[self.output_name])
            with tf.gfile.FastGFile(self.pb_file, mode='wb') as f:
                f.write(output_graph_def.SerializeToString())

    def restore_from_pb(self):
        # 直接从 pb 中恢复计算图和 variable 的值
        with tf.gfile.GFile(self.pb_file, "rb") as f:
            graph_def = tf.GraphDef()
            graph_def.ParseFromString(f.read())

        with tf.Session(graph=tf.get_default_graph()) as sess:
            tf.import_graph_def(graph_def, name='')

            # 打印所有 tensor
            # print([[n.name for n in tf.get_default_graph().as_graph_def().node]])

            input_tensor = tf.get_default_graph().get_tensor_by_name('{}:0'.format(self.input_name))
            output_tensor = tf.get_default_graph().get_tensor_by_name('{}:0'.format(self.output_name))
            print(sess.run(output_tensor, feed_dict={input_tensor: self.x_data}))


if __name__ == "__main__":
    tc = TestCase(batch_size=128, feature_size=1024, hidden_size=2048, output_size=64)
    tc.train_network()
    # tc.restore_from_ckpt()
    # tc.restore_from_pb()

```

