---
title: Python 操作字节流以及 struct 模块简易教程
date: 2017-02-25
update: 2018-04-12
categories: Python
tags: [Python, 字节, mnist, struct]
---

在编程中，对于数据操作最常见的就是字符流和字节流操作，本文以解析 MNIST 数据集为例，对 Python 中如何操作字节流进行总结。

<!--more-->

利用 Caffe 训练 MNIST 数据集，发现数据集是 IDX 文件格式，需要进行二进制的读取操作。网上查了一些利用 Python 进行字节流操作的教程，整理了 struct 模块的简易教程。

> 一般认为：二进制流 == 字节流 == 二进制数组 == 字节数组

### struct 模块简介

struct 模块中最重要的三个函数是 `pack()`, `unpack()`, `calcsize()`

```py
# 按照给定的格式化字符串，把数据封装成字符串(实际上是类似于c结构体的字节流)
string = struct.pack(fmt, v1, v2, ...)

# 按照给定的格式(fmt)解析字节流string，返回解析出来的tuple
tuple = unpack(fmt, string)

# 计算给定的格式(fmt)占用多少字节的内存
offset = calcsize(fmt)
```

**struct 中支持的格式如下表：**

| Format | C Type | Python | 字节数 |
| :------: | :-----:  | :----: | :----: |
| x | pad byte | no value | 1 |
| c	| char |	string of length 1|	1 |
| b	| signed char |	integer | 1 |
| B	| unsigned char | integer |	1 |
|?|_Bool|	bool|	1
|h|	short|	integer	|2
|H|	unsigned short|	integer|	2
|i|	int|	integer	|4
|I|	unsigned int|	integer or lon	|4
|l|	long	|integer |4
|L|	unsigned long|	long|	4
|q|	long |long	long	|8
|Q|	unsigned long|long	long|	8
|f|	float|	float|	4
|d|	double|	float|	8
|s|	char[]|	string|	1
|p|	char[]|	string|	1
|P|	void *|	long|	

**需要注意的一些问题：**

* q 和 Q 只在机器支持 64 位操作时有意义
* 每个格式前可以有一个数字，表示个数
* s 格式表示一定长度的字符串，4s 表示长度为 4 的字符串，但是 p 表示的是 pascal 字符串
* P 用来转换一个指针，其长度和机器字长相关
* 最后一个可以用来表示指针类型的，占 4 个字节

为了同 C 中的结构体交换数据，还要考虑有的 C/C++ 编译器使用了字节对齐，通常是以 4 个字节为单位的 32 位系统，故而 struct 根据本地机器字节顺序转换。可以用格式中的第一个字符来改变对齐方式。定义如下：

|Character|	Byte order|	Size and alignment|
| :---: | :---: | :---: |
|@|	native	native| 凑够4个字节
|=|	native	standard| 按原字节数
|<|	little-endian	standard |按原字节
|>|	big-endian	standard |按原字节数
|!|	network (= big-endian)	standard| 按原字节数

**使用方法是放在 fmt 的第一个位置，就像 `@5s6sif`**

### 利用 struct 解析 MNIST 数据集

MNIST 数据集从官网下载解压，得到四个 IDX 数据文件

```
t10k-images.idx3-ubyte
t10k-labels-idx1-ubyte
train-images.idx3-ubyte
train-labels.idx1-ubyte
```

**解析并保存数据：**

```py
# -*- coding=utf-8 -*-

"""
解析MNIST数据集的IDX格式文件
"""
import scipy.misc
import numpy as np
import struct
import matplotlib.pyplot as plt
import os

# 数据集存放目录
dataset_path = "/home/ryancrj/data/mnist-dataset/"

# 训练数据集文件
train_image_idx_ubyte_file = 'train-images.idx3-ubyte'
train_labels_idx_ubyte_file = 'train-labels.idx1-ubyte'

save_train_images_path = "train_images"
save_train_labels_file= "train_labels.txt"

# 测试数据集文件
test_image_idx_ubyte_file = 't10k-images.idx3-ubyte'
test_labels_idx_ubyte_file = 't10k-labels.idx1-ubyte'

save_test_images_path = "test_images"
save_test_labels_file = "test_labels.txt"


def decode_idx3_ubyte(idx3_ubyte_file, save_path):
    '''
    解析idx3文件
    :param idx3_ubyte_file: idx3文件路径
    :return: 解析得到的数据集
    '''

    # 读取二进制数据
    bin_data = open(idx3_ubyte_file, 'rb').read()

    # 解析文件头信息：魔术数，图片数量，图片高，宽
    offset = 0 
    fmt_header = '>iiii'    # 大端读取，4个整数类型
    magic_number, num_images, num_rows, num_cols = struct.unpack_from(
        fmt_header, bin_data, offset)
    print '魔术数: {}，图片数量: {}，图片大小: {} * {}'.format(
        magic_number, num_images, num_rows, num_cols)

    # 解析数据集
    image_size = num_rows * num_cols
    offset += struct.calcsize(fmt_header)
    fmt_image = '>' + str(image_size) + 'B'     # 从大端开始读取图像尺寸大小的无符号字节流
    images = np.empty((num_images, num_rows, num_cols))
    for i in range(num_images):
        if (i + 1) % 10000 == 0:
            print "已经解析 %d" %(i+1) + " 张"
        images[i] = np.array(struct.unpack_from(fmt_image, bin_data, offset)
                            ).reshape((num_rows, num_cols))
        offset += struct.calcsize(fmt_image)      # 计算给定格式所占用空间大小
        # 保存图片
        scipy.misc.imsave(os.path.join(save_path, '{}.jpg'.format(i+1)), images[i])  
    return images


def decode_idx1_ubyte(idx1_ubyte_file, save_file):
    '''
    解析idx1文件
    :param idx1_ubyte_file: idx1文件路径
    :return: 解析得到的数据集
    '''

    # 读取二进制数据
    bin_data = open(idx1_ubyte_file, 'rb').read()

    # 解析文件头信息：魔术数，标签数量
    offset = 0 
    fmt_header = '>ii'   
    magic_number, num_labels = struct.unpack_from(fmt_header, bin_data, offset)
    print '魔术数: {}，标签数量: {}'.format(magic_number, num_labels)

    # 解析数据集
    offset += struct.calcsize(fmt_header)
    fmt_label = '>B'    
    labels = np.empty(num_labels)
    fout = open(save_file, 'w')
    for i in range(num_labels):
        if (i + 1) % 10000 == 0:
            print "已经解析 %d" %(i+1) + " 个"
        labels[i] = np.array(struct.unpack_from(fmt_label, bin_data, offset))[0]
        offset += struct.calcsize(fmt_label)      # 计算给定格式所占用空间大小
        fout.write(str(int(labels[i]))+'\n')      # 将label写入文件
    return labels


def load_train_images():
    save_image_path = os.path.join(dataset_path, save_train_images_path)
    if not os.path.exists(save_image_path):
        os.mkdir(save_image_path)

    return decode_idx3_ubyte(os.path.join(
        dataset_path, train_image_idx_ubyte_file), save_image_path)

def load_train_labels():
    save_file = os.path.join(dataset_path, save_train_labels_file)
    return decode_idx1_ubyte(os.path.join(
        dataset_path, train_labels_idx_ubyte_file), save_file)

def load_test_images():
    save_image_path = os.path.join(dataset_path, save_test_images_path)
    if not os.path.exists(save_image_path):
        os.mkdir(save_image_path)
    return decode_idx3_ubyte(os.path.join(
        dataset_path, test_image_idx_ubyte_file), save_image_path)

def load_test_labels():
    save_file = os.path.join(dataset_path, save_test_labels_file)
    return decode_idx1_ubyte(os.path.join(
        dataset_path, test_labels_idx_ubyte_file), save_file)


def test():
    #train_images = load_train_images()
    #train_labels = load_train_labels()

    test_images = load_test_images()
    test_labels = load_test_labels()

    # 查看前10个标签
    for i in range(10):
        print test_labels[i]
        plt.imshow(test_images[i], cmap='gray')
        plt.show()
    print 'done'


def parse_data():
    train_images = load_train_images()
    train_labels = load_train_labels()
    test_images = load_test_images()
    test_labels = load_test_labels()


if __name__ == '__main__':
    parse_data()
```