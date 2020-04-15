---
title: TensorRT 实战教程
date: 2019-09-09 15:39:03
update: 2019-09-09 15:39:03
categories: TensorRT
tags: [TensorRT, c++, trt, cuda, tensorflow, caffe]
---

TensorRT(TRT) 作为一种能显著加快深度学习模型 inference 的工具，如果能够较好的利用，可以显著提高我们的 GPU 使用效率和模型运行速度。

<!--more-->

TensorRT(TRT) 作为一种快速的 GPU 推理框架，其常规流程就是利用现有的模型文件编译一个 engine，在编译 engine 的过程中，会为每一层的计算操作找寻最优的算子方法，这样编译好的 engine 执行起来就非常高效。很类似 C++ 编译过程。

关于 TRT 的相关资料，我觉得还是以 NV 官方的为准。对于 TRT 而言，其在推理上的速度优势肯定是不言而喻的，它有多好，有多快，适不适合你的业务场景，这个需要大家自行判断。而其大概流程和一些基本优化，NV 官方的资料也做出了说明，可以参考这票文章 [deploying-deep-learning-nvidia-tensorrt](https://devblogs.nvidia.com/deploying-deep-learning-nvidia-tensorrt/) 。想快速了解 TRT 以及安装过程，也可以参考 [TensorRT-介绍-使用-安装](https://arleyzhang.github.io/articles/7f4b25ce/)

本文根据自身实际使用过程中的记录而来，使用了 TRT 的 C++ 接口，更加注重编码的流程，配合讲解 TRT 的一些知识点，作为使用的总结。

### 构建模型 和 engine

TRT 将模型结构和参数以及相应 kernel 计算方法都编译成一个二进制 engine，因此在部署之后大大加快了推理速度。为了能够使用 TRT 进行推理，需要创建一个 eninge。TRT 中 engine 的创建有两种方式：

- 通过网络模型结构和参数文件编译得到，很慢。
- 读取一个已有的 engine（gie 文件），因为跳过了模型解析等过程，速度更快。

第一种方式很慢，但是在第一次部署某个模型，或者修改模型的精度、输入数据类型、网络结构等等，只要修改了模型，就必须重新编译（其实 TRT 还有一种可以重新加载参数的方式，不是本文所涉及的）。

现在假设我们是第一次用 TRT，所以就只能选择第一种方式来创建一个 engine。为了创建一个 engine，我们需要有模型结构和模型参数两个文件，同时需要能够解析这两个文件的方法。在 TRT 中，编译 engine 是通过 `IBuilder` 对象进行的，因此我们首先需要新键一个 `IBuilder` 对象：

```c++
nvinfer1::IBuilder *builder = createInferBuilder(gLogger);
```

> `gLogger` 是 TRT 中的日志接口 `ILogger` ，继承这个接口并创建自己的 logger 对象传入即可。

为了编译一个 engine，`builder` 首先需要创建一个 `INetworkDefinition` 作为模型的容器：

```c++
nvinfer1::INetworkDefinition *network = builder->createNetwork();
```

注意，**此时 `network` 是空的**，我们需要填充模型结构和参数，也就是解析我们自己的模型结构和参数文件，获取数据放到其中。

TRT 官方给了三种主流框架模型格式的解析器（parser），分别是：

- ONNX：`IOnnxParser parser = nvonnxparser::createParser(*network, gLogger);`
- Caffe：`ICaffeParser parser = nvcaffeparser1::createCaffeParser();`
- UFF：`IUffParser parser = nvuffparser::createUffParser();`

其中 UFF 是用于 TensorFlow 的格式。调用这三种解析器就可以解析相应的文件。以 `ICaffeParser` 为例，调用其 `parse` 方法来填充 `network`。

```c++
virtual const IBlobNameToTensor* nvcaffeparser1::ICaffeParser::parse(
    const char* deploy, 
    const char * model, 
	nvinfer1::INetworkDefinition &network, 
	nvinfer1::DataType weightType)

//Parameters
//deploy	    The plain text, prototxt file used to define the network configuration.
//model	        The binaryproto Caffe model that contains the weights associated with the network.
//network	    Network in which the CaffeParser will fill the layers.
//weightType    The type to which the weights will transformed.
```

这样就能得到一个填充好的 `network` ，就可以编译 engine 了，似乎一切都很美妙呢...

然而实际 TRT 并不完善，比如 TensorFlow 的很多操作并不支持，因此你传入的文件往往是根本就解析不了（深度学习框架最常见的困境之一）。因此我们需要自己去做填充 `network` 这件事，这就需要调用 TRT 中低级别的接口来创建模型结构，类似于你在 Caffe 或者 TensorFlow 中做的那样。

TRT 提供了较为丰富的接口让你可以直接通过这些接口创建自己的网络，比如添加一个卷积层：

```c++
virtual IConvolutionLayer* nvinfer1::INetworkDefinition::addConvolution(ITensor &input, 
                                                                        int nbOutputMaps,
                                                                        DimsHW kernelSize,
                                                                        Weights kernelWeights,
                                                                        Weights biasWeights)		

// Parameters
// input	The input tensor to the convolution.
// nbOutputMaps	The number of output feature maps for the convolution.
// kernelSize	The HW-dimensions of the convolution kernel.
// kernelWeights	The kernel weights for the convolution.
// biasWeights	The optional bias weights for the convolution.
```

这里的参数基本上就是和其他深度学习框架类似的意思，没有什么好讲的。就是把数据封装成 TRT 中的数据结构即可。可能和平时构建训练网络不同的地方就是需要填充好模型的参数，因为 TRT 是推理框架，参数是已知确定的。这个过程一般是读取已经训练好的模型，构造 TRT 的数据结构类型放到其中，也就是需要你自己去解析模型参数文件。

之所以说 TRT 的网络构造接口是**较为丰富**，是因为即使使用这些低级接口这样，很多操作还是没办法完成，也就是没有相应的 `add*` 方法，更何况现实业务可能还会涉及很多自定义的功能层，因此 TRT 又有了 plugin 接口，允许你自己定义一个 `add*` 的操作。其流程就是继承 `nvinfer1::IPluginV2` 接口，利用 cuda 编写一个自定义层的功能，然后继承 `nvinfer1::IPluginCreator` 编写其创建类，需要重写其虚方法 `createPlugin`。最后调用 `REGISTER_TENSORRT_PLUGIN` 宏来注册这个 plugin 就可以用了。plugin 接口的成员函数介绍。

```c++
// 获得该自定义层的输出个数，比如 leaky relu 层的输出个数为1
virtual int getNbOutputs() const = 0;

// 得到输出 Tensor 的维数
virtual Dims getOutputDimensions(int index, const Dims* inputs, int nbInputDims) = 0;

// 配置该层的参数。该函数在 initialize() 函数之前被构造器调用。它为该层提供了一个机会，可以根据其权重、尺寸和最大批量大小来做出算法选择。
virtual void configure(const Dims* inputDims, int nbInputs, const Dims* outputDims, int nbOutputs, int maxBatchSize) = 0;

// 对该层进行初始化，在 engine 创建时被调用。
virtual int initialize() = 0;

// 该函数在 engine 被摧毁时被调用
virtual void terminate() = 0;

// 获得该层所需的临时显存大小。
virtual size_t getWorkspaceSize(int maxBatchSize) const = 0;

// 执行该层
virtual int enqueue(int batchSize, const void*const * inputs, void** outputs, void* workspace, cudaStream_t stream) = 0;

// 获得该层进行 serialization 操作所需要的内存大小
virtual size_t getSerializationSize() = 0;

// 序列化该层，根据序列化大小 getSerializationSize()，将该类的参数和额外内存空间全都写入到系列化buffer中。
virtual void serialize(void* buffer) = 0;
```



我们需要根据自己层的功能，重写这里全部或者部分函数的实现，这里有很多细节，没办法一一展开，需要自定义的时候还是需要看官方 API。

构建好了网络模型，就可以执行 engine 的编译了，还需要对 engine 进行一些设置。比如计算精度，支持的 batch size 等等，因为这些设置不同，编译出来的 engine 也不同。

TRT 支持 FP16 计算，也是官方推荐的计算精度，其设置也比简单，直接调用：

```c++
builder->setFp16Mode(true);
```

另外在设置精度的时候，还有一个设置 strict 策略的接口：

```c++
builder->setStrictTypeConstraints(true);
```

这个接口就是是否严格按照设置的精度进行类型转换，如果不设置 strict 策略，则 TRT 在某些计算中可能会选择更高精度（不影响性能）的计算类型。 

除了精度，还需要设置好运行的 batch size 和 workspace size：

```c++
builder->setMaxBatchSize(batch_size);
builder->setMaxWorkspaceSize(workspace_size);
```

这里的 batch size 是运行时最大能够支持的 batch size，运行时可以选择比这个值小的 batch size，workspace 也是相对于这个最大 batch size 设置的。

设置好上述参数，就可以编译 engine 了。

```c++
nvinfer1::ICudaEngine *engine = builder->buildCudaEngine(*network);

```

编译需要花较长时间，耐心等待。

### Engine 序列化和反序列化

编译 engine 需要较长时间，在模型和计算精度、batch size 等均保持不变的情况下，我们可以选择保存 engine 到本地，供下次运行使用，也就是 engine 序列化。TRT 提供了很方便的序列化方法：

```c++
nvinfer1::IHostMemory *modelStream = engine->serialize();

```

通过这个调用，得到的是一个二进制流，将这个流写入到一个文件中即可保存下来。

如果需要再次部署，可以直接反序列化保存好的文件，略过编译环节。

```c++
IRuntime* runtime = createInferRuntime(gLogger);
ICudaEngine* engine = runtime->deserializeCudaEngine(modelData, modelSize, nullptr);

```

### 使用 engine 进行预测

有了 engine 之后就可以使用它进行 inference 了。

首先创建一个 inference 的 context。这个 context 类似命名空间，用于保存一个 inference 任务的变量。

```c++
IExecutionContext *context = engine->createExecutionContext();

```

**一个 engine 可以有多个 context**，也就是说一个 engine 可以同时进行多个预测任务。

然后就是绑定输入和输出的 index。这一步的原因在于 TRT 在 build engine 的过程中，将输入和输出映射为索引编号序列，因此我们只能通过索引编号来获取输入和输出层的信息。虽然 TRT 提供了通过名字获取索引编号的接口，但是本地保存可以方便后续操作。

我们可以先获取索引编号的数量：

```c++
int index_number = engine->getNbBindings();

```

我们可以判断这个编号数量是不是和我们网络的输入输出之和相同，比如你有一个输入和一个输出，那么编号的数量就是2。如果不是，则说明这个 engine 是有问题的；如果没问题，我们就可以通过名字获取输入输出对应的序号：

```c++
int input_index = engine->getBindingIndex(input_layer_name);
int output_index = engine->getBindingIndex(output_layer_name);

```

对于常见的一个输入和输出的网络，输入的索引编号就是 0，输出的索引编号就是 1，所以这一步也不是必须的。

接下来就需要为输入和输出层分配显存空间了。为了分配显存空间，我们需要知道输入输出的维度信息和存放的数据类型，TRT 中维度信息和数据类型的表示如下：

```c++
class Dims
{
public:
    static const int MAX_DIMS = 8; //!< The maximum number of dimensions supported for a tensor.
    int nbDims;                    //!< The number of dimensions.
    int d[MAX_DIMS];               //!< The extent of each dimension.
    DimensionType type[MAX_DIMS];  //!< The type of each dimension.
};

enum class DataType : int
{
    kFLOAT = 0, //!< FP32 format.
    kHALF = 1,  //!< FP16 format.
    kINT8 = 2,  //!< quantized INT8 format.
    kINT32 = 3  //!< INT32 format.
};

```

我们通过索引编号获取输入和输出的数据维度（dims）和数据类型（dtype），然后为每个输出层开辟显存空间，存放输出结果：

```c++
for (int i = 0; i < index_number; ++i)
{
	nvinfer1::Dims dims = engine->getBindingDimensions(i);
	nvinfer1::DataType dtype = engine->getBindingDataType(i);
    // 获取数据长度
    auto buff_len = std::accumulate(dims.d, dims.d + dims.nbDims, 1, std::multiplies<int64_t>());
    // ...
    // 获取数据类型大小
    dtype_size = getTypeSize(dtype);	// 自定义函数
}

// 为 output 分配显存空间
for (auto &output_i : outputs)
{
    cudaMalloc(buffer_len_i * dtype_size_i * batch_size);
}

```

> 本文给出的是伪代码，仅表示逻辑，因此会涉及一些简单的自定义函数。

至此，我们已经做好了准备工作，现在就可以把数据塞进模型进行推理了。

#### 前向预测

TRT 的前向预测执行是异步的，context 通过一个 enqueue 调用来提交任务：

```c++
cudaStream_t stream;
cudaStreamCreate(&stream);
context->enqueue(batch_size, buffers, stream, nullptr);
cudaStreamSynchronize(stream);

```

enqueue 是 TRT 的实际执行任务的函数，我们在写 plugin 的时候也需要实现这个函数接口。其中：

- `batch_size`：engine 在 build 过程中传入的 `max_batch_size`。

- `buffers`：是一个指针数组，其下标对应的就是输入输出层的索引编号，存放的就是输入的数据指针以及输出的数据存放地址（也就是开辟的显存地址）。

- `stream`：stream 是 cuda 一系列顺序操作的概念。对于我们的模型来说就是将所有的模型操作按照（网络结构）指定的顺序在指定的设备上执行。

  > cuda stream 是指一堆异步的 cuda 操作，他们按照 host 代码调用的顺序执行在 device 上。stream 维护了这些操作的顺序，并在所有预处理完成后允许这些操作进入工作队列，同时也可以对这些操作进行一些查询操作。这些操作包括 host 到 device 的数据传输，launch kernel 以及其他的 host 发起由 device 执行的动作。这些操作的执行总是异步的，cuda runtime 会决定这些操作合适的执行时机。我们则可以使用相应的cuda api 来保证所取得结果是在所有操作完成后获得的。**同一个 stream 里的操作有严格的执行顺序**，不同的 stream 则没有此限制。

这里需要注意，输入数据和输出数据在 buffers 数组中都是在 GPU 上的，可以通过 `cudaMemcpy` 拷贝 CPU 上的输入数据到 GPU 中（需要提前开辟一块显存来存放）。同理，输出数据也需要从 GPU 中拷贝到 CPU 中。

前两句创建了一个 cuda stream，最后一句则是等待这个异步 stream 执行完毕，然后从显存中将数据拷贝出来即可。

至此，我们就完成了 TRT 一个基本的预测流程。

### 总结

本文仅仅是针对 TRT 的预测流程和一些常见调用进行了说明，并不涉及具体网络和具体实现，也没有太多编码的细节。不同网络不同操作需要一些扩展 plugin 的编写，而对于编码，包括内存和显存的开辟管理，TRT 的析构清理工作等等都不在本文叙述范围之内。

#### 参考资料：

- https://docs.nvidia.com/deeplearning/sdk/tensorrt-developer-guide/index.html#c_topics
- https://docs.nvidia.com/deeplearning/sdk/tensorrt-api/c_api/index.html
- https://www.cnblogs.com/1024incn/p/5891051.html
