---
title: OpenGL 渲染管线简介
date: 2021-02-20 11:25:17
update: 2021-02-20 11:25:17
categories: OpenGL
tags: [OpenGL, 渲染, render, shader]
---

最近在学习 OpenGL 渲染特效的东西，需要补充一些基础知识，遇到不错的介绍文章，整理摘录。

<!-- more -->

## 图形渲染管线

在 OpenGL 的世界里，任何事物是处于 3D 空间中的，而屏幕和窗口显示的却是 2D，所以 OpenGL 干的事情基本就是 **把3D坐标转变为适应屏幕的2D像素**。

3D 坐标转为 2D 坐标的处理过程是由 OpenGL 的**图形渲染管线**管理的，图形渲染管线可以被划分为两个主要部分：

> 图形渲染管线(Graphics Pipeline)，大多译为**管线**，实际上指的是一堆原始图形数据途经一个输送管道，期间经过各种变化处理最终出现在屏幕的过程。

1.  第一部分把你的 3D 坐标转换为 2D 坐标。
2.  第二部分是把 2D 坐标转变为实际的有颜色的像素。

> 另外，**2D 坐标**和**像素**也是不同的概念，2D 坐标精确表示一个点在 2D 空间中的**位置**，而 2D 像素是这个点的**近似值**，2D 像素受到你的屏幕/窗口分辨率的限制。
> 简单来说就是坐标是一个包含无限个数值的集合，像素则是极小的有限个区域。

现在我们就简单地讲讲图形渲染管线内，数据处理的过程：

-   管线接受一组 3D 坐标，然后把它们转变为你屏幕上的有色 2D 像素输出。
-   管线可以被划分为几个阶段，每个阶段将会把前一个阶段的输出作为输入。
-   所有这些阶段都是高度专门化的（它们都有一个特定的函数），并且**很容易并行执行**。
-   由于它们具有并行执行的特性，当今大多数显卡都有成千上万的小处理核心，它们在GPU上为每一个（渲染管线）阶段运行各自的小程序，从而在图形渲染管线中快速处理你的数据，这些小程序叫做**着色器(Shader)**。
    -   着色器有好几种，其中有些着色器允许开发者自己配置，以更细致地控制管线中的特定部分。
    -   着色器运行在GPU上。
    -   OpenGL 着色器是用 OpenGL 着色器语言 (OpenGL Shading Language 即 GLSL) 写成的。

关于着色器我们之后再讨论，回到管线，下面是一个图形渲染管线的每个阶段的抽象展示，其中蓝色的是我们可以注入自定义的着色器的部分。

![](/images/posts/opengl/render_pipeline/opengl-render.png)

如你所见，图形渲染管线包含很多部分，每个部分都将在转换顶点数据到最终像素这一过程中处理各自特定的阶段，我们下面会概括性地解释一下渲染管线的每个部分，从而对图形渲染管线的工作方式有个大概了解。

### 图元

我们需要先简单了解下图元。

为了让 OpenGL 知道我们的坐标和颜色值构成的到底是什么，你需要去指定这些数据所表示的渲染类型，比如说：传入坐标等数据后，你想让 OpenGL 把这些数据渲染成一系列的点？一系列的三角形？还是线？以上要给 OpenGL 的这些信息就叫**图元(Primitive)**，任何一个绘制指令的调用都将是**把图元传递给 OpenGL**。这是其中的几种：`GL_POINTS`、`GL_TRIANGLES`、`GL_LINE_STRIP`（点，三角形，线）。

> 这里我理解三角形就是代表面，因为如果我们想渲染一块区域，就应该使用三角形。

接下来正式进入渲染管线的介绍。这也是初学者比较头晕的部分，本文将分开一步步具体分析。

### 渲染管线流程

现在假设我们的目的就是画出一个三角形。下面我们对渲染管线中每个流程一一说明。

首先，我们要以数组的形式传递 3 个 3D 坐标作为图形渲染管线的输入，用来表示一个三角形，**一个 3D 坐标的数据的集合就是一个顶点(Vertex)**；这个数组就是一系列顶点的集合，我们叫他**顶点数据(Vertex Data)**（简单起见，我们先假定每个顶点只由一个3D位置和一些颜色值组成）。

> 这里再次强调，OpenGL 是 3D 的，因此内部表示的坐标都是 3D 坐标，哪怕我们想画的是 2D 图形。另外展示的都是屏幕像素，是 2D 的，因此渲染管线必须包含坐标处理。这里要切记。

![](/images/posts/opengl/render_pipeline/vertex-data.png)

顶点数据会进入**顶点着色器(Vertex Shader)**，它把一个单独的顶点作为输入，顶点着色器主要的目的是把输入的 3D 坐标转为另一种 3D 坐标（之后会解释），同时对顶点属性进行一些基本处理。

![](/images/posts/opengl/render_pipeline/vertex-shader.png)

顶点着色器输出的所有顶点会进入**图元装配(Primitive Assembly)**阶段，它将所有的点装配成**指定图元的形状**（这里的例子中是一个三角形，如果是 `GL_POINTS`，那么就是一个个的点）。

![](/images/posts/opengl/render_pipeline/shape-assembly.png)

图元装配阶段的输出会传递给**几何着色器(Geometry Shader)**，几何着色器把图元形式的一系列顶点的集合作为输入，它可以通过产生新顶点构造出新的（或是其它的）图元来生成其他形状，在这个例子里，它生成了另一个三角形。

![](/images/posts/opengl/render_pipeline/geometry-shader.png)

几何着色器的输出会被传入**光栅化阶段(Rasterization Stage)**，这里它会把图元映射为最终屏幕上相应的像素，生成供片段着色器(Fragment Shader)使用的片段(Fragment)（**OpenGL 的一个片段是 OpenGL 渲染一个像素所需的所有数据**）。但在片段着色器运行之前还会执行裁切(Clipping)，裁切会丢弃超出你的视图以外的所有像素，用来提升执行效率。

![](/images/posts/opengl/render_pipeline/rasterization.png)

输出的片段(Fragment)将会传入片段着色器(Fragment Shader)，它主要作用是计算一个像素的最终颜色，这也是所有 OpenGL 高级效果产生的地方，通常，片段着色器包含 3D 场景的数据（比如光照、阴影、光的颜色等等），这些数据可被用来计算最终像素的颜色。

![](/images/posts/opengl/render_pipeline/fragment-shader.png)

在所有对应颜色值确定以后，最终的对象将会被传到最后一个阶段，我们叫做 Alpha 测试和混合(Blending)阶段。这个阶段检测片段的对应的深度（和模板(Stencil)）值，用以判断这个像素是在前面还是后面，决定是否丢弃。这个阶段也会检查alpha 值（alpha值 定义了一个物体的透明度）并对物体进行混合(Blend)。所以，即使在片段着色器中计算出来了一个像素输出的颜色，在渲染多个三角形的时候最后的像素颜色也可能完全不同。

![](/images/posts/opengl/render_pipeline/test-blending.png)

可以看到，图形渲染管线非常复杂，它包含很多可配置的部分。**但其实对于大多数场合，我们只需要配置顶点和片段着色器就行了**（几何着色器是可选的，通常使用它默认的着色器就行了）。

在现代 OpenGL 中，我们也必须定义**至少一个顶点着色器和一个片段着色器**（GPU 中没有默认的顶点/片段着色器），因此刚开始学习的时候可能会非常困难，在你能够渲染自己的第一个三角形之前，已经需要了解一大堆知识了。

### 管线小结

我们再梳理一次渲染管线的流程：

![](/images/posts/opengl/render_pipeline/opengl-render.png)

1.  首先，我们以数组的形式传递 3 个 3D 坐标作为图形渲染管线的输入，这个数组叫做**顶点数据(Vertex Data)**，是**一系列顶点的集合**。
2.  **顶点着色器(Vertex Shader)** 把顶点的 3D 坐标转为另一种 3D 坐标，同时允许我们对顶点属性进行一些基本处理。
3.  **图元装配(Primitive Assembly)** 将所有的点装配成指定图元的形状。
4.  **几何着色器(Geometry Shader)** 它可以通过产生新顶点构造出新的（或是其它的）图元来生成其他形状，在我们这里，它生成了另一个三角形。
5.  **光栅化阶段(Rasterization Stage)** 会把图元映射为最终屏幕上相应的像素，生成片段(Fragment)，并执行裁切(Clipping)，丢弃超出你的视图以外的所有像素提升效率。
6.  **片段着色器(Fragment Shader)** 计算一个像素的最终颜色。
7.  **Alpha测试和混合(Blending)** 阶段检测片段的对应的深度（和模板(Stencil)）值，决定是否丢弃；这个阶段也会检查alpha值并对物体进行混合(Blend)。

都理解了之后，我们将尝试渲染一个三角形。

## 顶点输入

先记住以下三个概念：

-   顶点数组对象：Vertex Array Object，**VAO**
-   顶点缓冲对象：Vertex Buffer Object，**VBO**
-   索引缓冲对象：Element Buffer Object，**EBO** 或 Index Buffer Object，**IBO**

就如管线的流程，想要让 OpenGL 绘制图形，我们必须先给 OpenGL 喂一些顶点数据，**顶点输入**实际上步骤并不少，过程并不简单。

首先 OpenGL 是一个 3D 图形库，所以我们在 OpenGL 中指定的所有坐标都是 3D 坐标（x，y，z）。然后，OpenGL 不是简单地把所有的 3D 坐标变换为屏幕上的 2D 像素：仅当 3D 坐标在 3 个轴（x、y、z）上都为 **-1.0 到 1.0** 的范围内时才处理它，而所有在所谓的**标准化设备坐标(Normalized DeviceCoordinates)**范围内的坐标才会最终呈现在屏幕上。

#### 标准化设备坐标(Normalized Device Coordinates, NDC)

一旦你的顶点坐标已经在顶点着色器中处理过，它们就应该是标准化设备坐标了，标准化设备坐标是一个 x、y 和 z 值在 -1.0 到 1.0 的一小段空间，任何落在范围外的坐标都会被丢弃/裁剪，不会显示在你的屏幕上。

下面你会看到我们定义的在标准化设备坐标中的三角形(忽略z轴)：

![](/images/posts/opengl/render_pipeline/normalized-device-coordinates.png)

你的标准化设备坐标接着会变换为屏幕**空间坐标(Screen-spaceCoordinates)**，这是通过 `glViewport` 函数提供的数据，进行**视口变换(ViewportTransform)**完成的，所得的屏幕空间坐标又会被变换为片段输入到片段着色器中。

由于我们希望渲染一个三角形，我们一共要指定三个顶点，每个顶点都有一个 3D 位置，我们要将它们以标准化设备坐标的形式（OpenGL 的可见区域）输入，所以我们定义为一个 float 数组为**顶点数据(Vertex Data)**：

``` c++
float vertices[] = {
    -0.5f, -0.5f, 0.0f,//左
     0.5f, -0.5f, 0.0f,//右
     0.0f,  0.5f, 0.0f //上
};
```

由于 OpenGL 是在 3D 空间中工作的，而我们渲染的是一个 2D 三角形，我们将它顶点的 z 坐标设置为 0.0，这样子的话三角形每一点的 **深度 (Depth)**都是一样的，从而使它看上去像是 2D 的。深度可以理解为 z 坐标，它代表一个像素在空间中和你(屏幕)的距离，如果离你远就可能被别的像素遮挡，你就看不到它了，它会被丢弃，以节省资源。

创建之后，我们要考虑如何传输。顶点数据是要从 CPU 发往 GPU 上参与运算的，顶点数据通过 CPU 输入到 GPU 的**顶点着色器**之前，我们先要在 GPU 上创建内存（显存）空间，用于储存我们的顶点数据，还要配置 OpenGL 如何读懂这些数据，并且指定其如何发送给显卡，然后才轮到**顶点着色器**处理我们在内存中指定的顶点。

但是，**从 CPU 把数据发送到 GPU 是一个相对较慢的过程**，每个顶点发送一次耗费的时间将会非常大，所以我们要一次性发送尽可能多的数据，因此我们需要一个中介：**顶点缓冲对象(Vertex Buffer Objects, VBO)**，来管理这内存，它会在 GPU 内存（显存）中储存大量顶点，因此我们就能一批一批发送大量顶点数据到 GPU 内存（显存）了。而当数据储存到 GPU 的内存（显存）中后，顶点着色器几乎能立即访问顶点，这是个非常快的过程。

### 顶点缓冲对象 VBO

VBO 可以将输入的顶点数据**原封不动**的存起来。

和 OpenGL 中的其它对象一样，这个缓冲必须要有一个独一无二的 ID，所以我们需要一个整形变量，再使用 `glGenBuffers` 函数，他会生成缓冲并返回对应的 ID 存到第二个参数上。

```c++
unsigned int VBO;
glGenBuffers(1, &VBO); // glGenBuffers(缓冲区绑定对象目标数量，缓冲区对象名称(ID))
// glGenBuffers 可以产生多个 VBO，但是我们现在只要一个。如果你一次生成 10 个，第一个参数要改成 10，并且你就需要声明一个整形数组而不是一个整形变量。
```

OpenGL 有很多缓冲对象类型，**顶点缓冲对象**的缓冲类型是 `GL_ARRAY_BUFFER`，OpenGL 允许我们同时绑定多个缓冲，只要它们是不同的缓冲类型。我们可以使用 `glBindBuffer` 函数把新创建的缓冲**绑定**到 `GL_ARRAY_BUFFER` 目标上：

```c++
glBindBuffer(GL_ARRAY_BUFFER, VBO); // glBindBuffer(目标缓冲类型, 对象名称(ID))
```

要注意，`glGenBuffers` 只是生成缓冲，程序并不知道这个缓冲是什么类型。所以调用 `glBindBuffer` 并制定缓冲类型，我们才算真正创建了一个 VBO。

接下来我们要**把顶点数据存到 VBO 上**，调用 `glBufferData` 函数：

```c++
glBufferData(
    GL_ARRAY_BUFFER,  //目标缓冲类型
    sizeof(vertices), //传输数据的大小
    vertices,         //发送的实际数据
    GL_STATIC_DRAW    //管理给定的数据的方式
);
```

`glBufferData` 是一个专门用来**把用户定义的数据复制到当前绑定缓冲**的函数。

1.  第一个参数是目标缓冲的类型：顶点缓冲对象当前绑定到 `GL_ARRAY_BUFFER` 目标上。
2.  第二个参数指定传输数据的大小(以字节为单位)；用一个简单的 `sizeof` 计算出顶点数据大小就行。
3.  第三个参数是我们希望发送的实际数据。
4.  第四个参数指定了我们希望显卡如何管理给定的数据，它有三种形式：
    -   `GL_STATIC_DRAW` ：数据不会或几乎不会改变。
    -   `GL_DYNAMIC_DRAW`：数据会被改变很多。
    -   `GL_STREAM_DRAW` ：数据每次绘制时都会改变。

三角形的位置数据不会改变，每次渲染调用时都保持原样，所以它的使用类型最好是 `GL_STATIC_DRAW`。如果一个缓冲中的数据将频繁被改变，那么使用的类型就应该是 `GL_DYNAMIC_DRAW` 或 `GL_STREAM_DRAW`，这样就能确保显卡把数据放在能够高速写入的内存部分。

目前我们完成的是：

1.  建立一批顶点数据存在 vertices 数组里。
2.  在显存上创建了一个 VBO。
3.  将顶点数据存在了 VBO 中，GPU 可以通过 VBO 读取顶点数据。

之前也提到了，VBO 只是将输入的顶点数据**原封不动的保存在显存中供 GPU 使用**，接下来我们需要对这些数据加以解释，**输入数据的哪到哪是一个部分，每个部分对应什么**，让 GPU 读懂。

### 链接顶点属性

由于我们需要画三角形，传入的数据是三个顶点，所以我们希望 VBO 内的数据会被解析为下面这样子：

![](/images/posts/opengl/render_pipeline/vertex-property.png)

-   位置数据被储存为 32 位（4 字节）浮点值。
-   每个位置包含 3 个这样的值。
-   在这 3 个值之间没有空隙（或其他值），这几个值在数组中紧密排列。
-   数据中第一个值在缓冲开始的位置 0 。

有了这些信息我们就可以使用 `glVertexAttribPointer()` 函数告诉 OpenGL 该如何解析顶点数据了：

```c++
glVertexAttribPointer(
    0,                  //指定要配置的Location
    3,                  //指定顶点属性的大小
    GL_FLOAT,           //指定数据的类型
    GL_FALSE,           //是否希望数据被标准化
    3 * sizeof(float),  //连续的顶点属性组之间的间隔
    (void*)0            //偏移量
);
glEnableVertexAttribArray(0);
```

`glVertexAttribPointer` 函数的参数非常多，这里逐一介绍它们：

1.  第一个参数**指定我们要配置的顶点属性**，我们之后需要在顶点着色器中使用 `layout(location = 0)` 定义 position 顶点属性的位置值(Location)。把顶点属性的位置值同样设置为 0 。
2.  第二个参数**指定顶点属性的大小**，顶点属性是一个 `vec3`，它由 3个 值组成，所以大小是 3 。
3.  第三个参数**指定数据的类型**，这里是 `GL_FLOAT` (GLSL 中 `vec*` 都是由浮点数值组成的)。
4.  第四个参数定义我们**是否希望数据被标准化**(Normalize)，如果我们置为 `GL_TRUE`，所有数据都会被映射到 0 到 1 之间（对于有符号型signed数据是-1），我们把它置为 `GL_FALSE`。
5.  第五个参数叫做步长(Stride)，它告诉我们在**连续的顶点属性组之间的间隔**，由于下个组位置数据在 3 个 float 之后，我们把步长设置为 `3 * sizeof(float)`，要注意的是由于我们知道这个数组是紧密排列的（在两个顶点属性之间没有空隙）我们也可以**设置为 0 来让 OpenGL 决定**具体步长是多少（只有当数值是紧密排列时才可用），一旦我们有更多的顶点属性，我们就必须更小心地定义每个顶点属性之间的间隔。
6.  最后一个参数的类型是 `void*`，所以需要我们进行这个奇怪的强制类型转换，它表示位置数据在缓冲中起始位置的**偏移量(Offset)**，由于位置数据在数组的开头，所以这里是 0，我们会在后面详细解释这个参数。

如果程序中可以有多个 VBO，OpenGL怎么判断从哪个 VBO 获取呢？绑定是 OpenGL 中很重要的一个概念，还记得我们之前调用 `glVertexAttribPointer()` 时将 VBO 绑定到 `GL_ARRAY_BUFFER` 吗？**在调用 `glVertexAttribPointer()` 之前绑定的是哪个 VBO，链接的就是它**。

> 换句话说，调用 `glVertexAttribPointer()` 时使用的 VBO 是当前被绑定到 `GL_ARRAY_BUFFER` 上的缓冲区。

我们已经告诉了 OpenGL 该如何解释顶点数据，目前的进度是：

1.  建立了一批顶点数据存在 vertices 数组里。
2.  在显存上创建了一个 VBO。
3.  将顶点数据存在了 VBO 中，GPU 可以通过 VBO 读取顶点数据。
4.  告诉了 OpenGL 如何把顶点数据链接到顶点着色器的顶点属性上。

在 OpenGL 中绘制一个物体的准备工作流程大致如下代码：

```c++
// 0. 复制顶点数组到VBO缓冲中供OpenGL使用
glBindBuffer(GL_ARRAY_BUFFER, VBO);
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

// 1. 设置顶点属性指针
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);

//...

// 绘制代码(渲染循环中)
while (!glfwWindowShouldClose(window))
{
    // 2. 渲染一个物体时要使用着色器程序
    glUseProgram(shaderProgram);
    // 3. 绘制物体
    someOpenGLFunctionThatDrawsOurTriangle();
}
```

每当我们绘制一个物体的时候都必须重复这一过程，看起来可能不多，但是如果有超过 5 个顶点属性，上百个不同物体时，绑定正确的缓冲对象，为每个物体配置所有顶点属性就会非常麻烦。有没有一些方法可以使我们**把所有这些状态配置储存在另一个对象中**，并且可以通过绑定这个对象来恢复状态呢？顶点数组对象 VAO 可以完成这项功能。

### 顶点数组对象 VAO

**顶点数组对象(Vertex Array Object, VAO)** 可以记录我们对 VBO 内顶点数据的配置，当配置顶点属性指针时，你只需要将之前那些调用执行一次，之后再绘制物体的时候只需要**绑定相应的 VAO** 就行了，这使在不同顶点数据和属性配置之间切换变得非常简单，只需要绑定不同的 VAO 就行了，刚刚设置的所有状态都将存储在 VAO 中。

OpenGL 的核心模式**要求**我们使用 VAO，所以它知道该如何处理我们的顶点输入，如果我们绑定 VAO 失败，OpenGL会拒绝绘制任何东西。

一个顶点数组对象会储存以下这些内容：

-   `glEnableVertexAttribArray()` 和 `glDisableVertexAttribArray()` 的调用。
-   通过 `glVertexAttribPointer()` 设置的顶点属性配置。
-   通过 `glVertexAttribPointer()` 调用与顶点属性关联的顶点缓冲对象。

VBO 和 VAO 的关系如下图：

![](/images/posts/opengl/render_pipeline/vao-vbo.png)

所以通常我们是**一个绘制的物体对应一个 VAO**。创建一个VAO和创建一个VBO很类似：

```c++
unsigned int VAO;
glGenVertexArrays(1, &VAO);
```

要想使用 VAO，只需调用 `glBindVertexArray()` 绑定VAO。

从绑定之后起，我们应该绑定和配置对应的 VBO 和属性指针，之后解绑 VAO 供之后使用，当我们打算绘制一个物体的时候，我们只要在绘制物体前简单地把 VAO 绑定到希望使用的设定上就行了。

这段代码应该看起来像这样：

```c++
// 初始化代码,只运行一次 (除非你的物体频繁改变)
// 1. 绑定 VAO
glBindVertexArray(VAO);
// 2. 把顶点数组复制到缓冲中供 OpenGL 使用
glBindBuffer(GL_ARRAY_BUFFER, VBO);
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
// 3. 设置顶点属性指针
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);
//...
// 绘制代码(渲染循环中)
while (!glfwWindowShouldClose(window))
{
    // 4. 绘制物体
    glUseProgram(shaderProgram);
    glBindVertexArray(VAO); //绑定 VAO
    someOpenGLFunctionThatDrawsOurTriangle();
}
```

如果我们打算绘制多个物体，就先要配置每种物体的 VBO 和 VAO ，储存它们供后面使用，绘制物体的时候就拿出相应的 VAO，绑定它，绘制完后再解绑 VAO。

比如我们需要两种不同的三角形时，首先需要两个三角形的顶点数据：

```c++
float firstTriangle[] = {
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
};
float secondTriangle[] = {
    0.0f, -0.5f, 0.0f,  // left
    0.9f, -0.5f, 0.0f,  // right
    0.45f, 0.5f, 0.0f   // top 
};
```

然后创建两个 VAO ，两个 VBO（是不是可以只用一个VBO呢？）。

```c++
unsigned int VBOs[2], VAOs[2];
glGenVertexArrays(2, VAOs);
glGenBuffers(2, VBOs);
```

分别设置：

```c++
glBindVertexArray(VAOs[0]);
glBindBuffer(GL_ARRAY_BUFFER, VBOs[0]);
glBufferData(GL_ARRAY_BUFFER, sizeof(firstTriangle), firstTriangle, GL_STATIC_DRAW);
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);

glBindVertexArray(VAOs[1]);
glBindBuffer(GL_ARRAY_BUFFER, VBOs[1]);
glBufferData(GL_ARRAY_BUFFER, sizeof(secondTriangle), secondTriangle, GL_STATIC_DRAW);
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);
```

渲染：

```c++
glUseProgram(shaderProgram);
glBindVertexArray(VAOs[0]);
glDrawArrays(GL_TRIANGLES, 0, 3);
glBindVertexArray(VAOs[1]);
glDrawArrays(GL_TRIANGLES, 0, 3);
glBindVertexArray(0);
```

释放资源：

```c++
glfwTerminate();
glDeleteVertexArrays(2, VAOs);
glDeleteBuffers(2, VBOs);
```

## 着色器

如果我们打算做渲染的话，现代 OpenGL 需要我们至少设置一个顶点和一个片段着色器，接下来我们先简单介绍一下着色器，然后配置两个非常简单的着色器：**顶点着色器(Vertex Shader)**和**片段着色器(Fragment Shader)**，用来来绘制我们第一个三角形。

> 在图形编程中我们经常会使用向量这个数学概念，因为它简明地表达了任意空间中的位置和方向，并且它有非常有用的数学属性。在 GLSL 中一个向量有最多 4 个分量，每个分量值都代表空间中的一个坐标，它们可以通过 `vec.x`、`vec.y`、`vec.z` 和 `vec.w` 来获取，注意 `vec.w` 分量不是用作表达空间中的位置的（我们处理的是3D不是4D），而是用在所谓的透视除法(Perspective Division)上。

### 顶点着色器

还记得上面说的吗？顶点着色器是我们图形渲染管线的第一个部分，**顶点着色器(Vertex Shader)**，它把一个单独的顶点作为输入，顶点着色器主要的目的是把 3D 坐标转为另一种 3D 坐标，同时顶点着色器允许我们对顶点属性进行一些基本处理。

我们需要做的第一件事是学习使用**着色器语言 GLSL(OpenGL Shading Language)**编写顶点着色器，然后编译这个着色器，这样我们就可以在程序中使用它了。和学初级语言时写的 HelloWorld 一样，下面我们先看一段非常简单的顶点着色器的源代码：

```c++
// 顶点着色器
#version 330 core
layout (location = 0) in vec3 aPos;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
```

不难看出 GLSL 看起来很像 C 语言，接下来我们一句句看。

```c++
#version 330 core
```

首先，每个着色器都起始于一个版本声明，OpenGL 3.3 以及和更高版本中，GLSL 版本号和 OpenGL 的版本是匹配的（比如说 GLSL420 版本对应于 OpenGL4.2），我们这里声明使用 3.30 版本，并且使用核心模式。

```c++
layout (location = 0) in vec3 aPos; //声明输入顶点属性
```

下一步，使用 `in` 关键字，在顶点着色器中声明所有的**输入顶点属性(Input Vertex Attribute)** 。之前我们用 `glVertexAttribPointer()` 的第一个参数指定了输入的 location 为 0 ，所以需要通过 `layout (location = 0)` 设定输入变量的位置值(Location)为 0。现在我们只关心位置(Position)数据，所以我们只需要一个顶点属性。由于每个顶点都有一个 3D 坐标，我们就创建一个 `vec3 `输入变量 aPos。

```c++
gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
// gl_Position的值即为输出
```

为了设置顶点着色器的输出，我们必须把位置数据赋值给预定义的 `gl_Position` 变量（`vec4`类型）。在 `main` 函数里，`gl_Position` 最后的值就是该顶点着色器的**输出**。

由于我们的输入是一个 3 分量的向量，我们必须把它转换为 `gl_Position` 所对应的 4 分量的向量。我们可以把 `vec3` 的数据作为 `vec4` 构造器的参数，同时把 `w` 分量设置为 1.0f（后面解释为什么）。

很简单，就这样写完了，再看一次我们这个顶点着色器的代码：

```c++
// 顶点着色器
#version 330 core
layout (location = 0) in vec3 aPos;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
```

当前这个顶点着色器可能是我们能想到的最简单的顶点着色器了，因为我们对输入数据什么都没有处理就把它传到着色器的输出了（在真实的程序里输入数据通常都不是标准化设备坐标，所以我们首先必须先把它们转换至 OpenGL 的可视区域内，但是现在我们可以先不考虑）。

#### 编译顶点着色器

我们已经写了一个顶点着色器源码，但是为了能够让 OpenGL 使用它，我们必须在**运行时动态编译它的源码**，我们写的顶点着色器源码将储存在一个 C 的字符串中：

```c++
const char *vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
```
(很恶心，但我们之后会通过文件读写解决这个问题的，不用着急)

我们首先要做的是创建一个着色器对象，注意还是用 ID 来引用的，所以我们储存这个顶点着色器的 ID 为 `unsigned int`，然后用 `glCreateShader` 创建这个着色器，我们把需要创建的着色器类型以参数形式提供给
`glCreateShader`，由于我们正在创建一个顶点着色器，传递的参数是 `GL_VERTEX_SHADER`。

```c++
unsigned int vertexShader;
vertexShader = glCreateShader(GL_VERTEX_SHADER);
```

下一步我们把这个着色器源码附加到着色器对象上，然后编译它：

```c++
glShaderSource(
    vertexShader,        //要编译的着色器对象
    1,                   //传递的源码字符串数量
    &vertexShaderSource, //顶点着色器源码
    NULL
);
glCompileShader(vertexShader);
```

`glShaderSource()` 函数的参数：

1.  第一个参数是要编译的着色器对象。
2.  第二参数指定了传递的源码字符串数量，这里只有一个。
3.  第三个参数是顶点着色器源码。
4.  第四个参数我们先设置为 `NULL`。

同时，我们希望检测在调用 `glCompileShader` 后编译是否成功了，如果没成功的话，也希望知道错误是什么，这样才能方便修复它们，检测编译时错误输出可以通过以下代码来实现：

```c++
int success;        //是否成功编译
char infoLog[512];  //储存错误消息
glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);   //检查是否编译成功
if(!success)
{
    glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
    std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
}
else {
    std::cout << "vertexShader complie SUCCESS" << std::endl;
}
```

首先我们定义一个整型变量 `success` 来表示是否成功编译，还定义了一个储存错误消息（出错了才会有）的容器 `infoLog[]` ，这是个 char 类型的数组，然后我们用 `glGetShaderiv` 函数检查是否编译成功，如果编译失败，我们会用 `glGetShaderInfoLog()` 获取错误消息，然后打印它。如果编译的时候没有检测到任何错误，顶点着色器就被编译成功了。

### 片段着色器

我们刚才通过顶点着色器的 `gl_Position` 变量设置了三角形三个点的位置，现在我们要在片段着色器里设置他们的颜色。

**片段着色器(Fragment Shader)**的主要目的是计算一个像素的最终颜色，这也是所有 OpenGL 高级效果产生的地方，通常，片段着色器包含 3D 场景的数据（比如光照、阴影、光的颜色等等），这些数据可被用来计算最终像素的颜色。

在计算机图形中颜色被表示为有 4 个元素的数组：**红色、绿色、蓝色和alpha(透明度)分量**，通常缩写为 RGBA。当在 OpenGL 中定义一个颜色的时候，我们把颜色每个分量的强度设置在 0.0 到 1.0 之间。比如说我们设置红为 1.0f，绿为 1.0f，我们会得到两个颜色的混合色，即黄色。这三种颜色分量的不同调配可以生成超过1600万种不同的颜色。

现在看到我们的片段着色器代码：

```c++
#version 330 core
out vec4 FragColor;//只需要一个输出变量

void main()
{
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
} 
```

片段着色器只需要一个输出变量，这个变量是一个 4 分量向量，它表示的是最终的输出颜色，我们可以用 out 关键字声明输出变量，这里我们命名为 `FragColor`。我们将一个 alpha 值为 1.0（代表完全不透明）的橘黄色的 vec4 赋值给颜色输出 `FragColor`。

#### 编译片段着色器

编译片段着色器的过程与顶点着色器类似，不过我们使用 `GL_FRAGMENT_SHADER` 常量作为着色器类型：

```c++
unsigned int fragmentShader;
fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
glCompileShader(fragmentShader);
```

我们同样用刚才的方法检测编译是否出错：

```c++
int success;//是否成功编译
char infoLog[512];//储存错误消息
glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
if (!success) {
    glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
    std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
}
else {
    std::cout << "fragmentShader complie SUCCESS" << std::endl;
}
```

没有检测到任何错误，片段着色器也被编译成功了。好了，现在两个着色器现在都编译了，总的代码如下：

```c++
const char *vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
const char *fragmentShaderSource = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";

int main()
    ...
    //build and compile 着色器程序（main内）
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
        //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    unsigned int fragmentShader;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
        //检查片段着色器是否编译错误
    glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShader complie SUCCESS" << std::endl;
    }
    ...
}
```

最后我们要把两个着色器对象链接到一个用来渲染的着色器程序(Shader Program)中。

### 着色器程序

着色器程序对象(Shader Program Object)是多个着色器合并之后并最终链接完成的版本，如果要使用刚才编译的着色器我们必须把它们链接(Link)为一个着色器程序对象，然后在渲染对象的时候激活这个着色器程序。已激活着色器程序的着色器将在我们发送渲染调用的时候被使用。

当链接着色器至一个程序的时候，它会把每个着色器的输出链接到下个着色器的输入，如果输出和输入不匹配，就会得到一个连接错误。

创建一个程序对象很简单，像刚才一样：

```c++
unsigned int shaderProgram;
shaderProgram = glCreateProgram();
```

`glCreateProgram()` 函数创建一个程序，并返回新创建程序对象的 ID 引用。

现在我们需要把之前编译的着色器附加到程序对象上，然后用 `glLinkProgram()` 链接它们：

```c++
glAttachShader(shaderProgram, vertexShader);
glAttachShader(shaderProgram, fragmentShader);
glLinkProgram(shaderProgram);
```

代码应该很清楚，我们把着色器附加到了程序上，然后用 `glLinkProgram()` 链接。

就像着色器的编译一样，我们也可以检测链接着色器程序是否失败，并获取相应的日志

与上面不同，我们尝试不调用 `glGetShaderiv()` 和 `glGetShaderInfoLog() `，而是使用 `glGetProgramiv()` 和 `glGetProgramInfoLog()` ：

```c++
glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
if(!success) {
    glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
    ...
}
else {
    std::cout << "shaderProgram complie SUCCESS" << std::endl;
}
```

如果着色器程序没有报错，我们通过 `glLinkProgram()` 得到的就是一个程序对象，我们可以调用 `glUseProgram()` 函数，用刚创建的程序对象作为它的参数，以激活这个程序对象：

```c++
glUseProgram(shaderProgram);    //写进渲染循环
```

在 `glUseProgram()` 函数调用之后，每个着色器调用和渲染调用都会使用这个程序对象（也就是之前写的着色器）了。

对了，**在把着色器对象链接到程序对象以后，记得删除着色器对象**，我们不再需要它们了：

```c++
glDeleteShader(vertexShader);
glDeleteShader(fragmentShader);
```

## 画出三角形

庆贺吧，终于来到了这一刻。

要想绘制我们想要的物体，OpenGL 给我们提供了 `glDrawArrays()` 函数，它使用当前激活的着色器，之前定义的顶点属性配置，和 VBO 的顶点数据（通过 VAO 间接绑定）来绘制图元：

```c++
glUseProgram(shaderProgram);
glBindVertexArray(VAO);
glDrawArrays(
    GL_TRIANGLES,   //图元的类型
    0,              //顶点数组的起始索引
    3               //绘制多少个顶点
);
```

`glDrawArrays()` 函数：

1. 第一个参数是我们打算绘制的 OpenGL 图元的类型，由于我们在一开始时说过，我们希望绘制的是一个三角形，这里传递 GL_TRIANGLES 给它。
2. 第二个参数指定了顶点数组的起始索引，我们这里填 0 。
3. 最后一个参数指定我们打算绘制多少个顶点，这里是 3（我们只从我们的数据中渲染一个三角形，它只有3个顶点长）。

现在尝试编译代码，如果编译通过了，你应该看到下面的结果：

![](/images/posts/opengl/render_pipeline/result.png)

这时候我们的代码是这样的：

```c++
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void processInput(GLFWwindow* window);

// settings
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

const char* vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
const char* fragmentShaderSource = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";

int main()
{
    // 实例化GLFW窗口
    glfwInit();//glfw初始化
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);//主版本号
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);//次版本号
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    //（宽，高，窗口名）返回一个GLFWwindow类的实例：window
    if (window == NULL)
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    // 告诉GLFW我们希望每当窗口调整大小的时候调用改变窗口大小的函数
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad管理opengl函数指针，初始化glad
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    //build and compile 着色器程序
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
    //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    unsigned int fragmentShader;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    //检查片段着色器是否编译错误
    glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShader complie SUCCESS" << std::endl;
    }
    //连接着色器
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    //检查片段着色器是否编译错误
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgram complie SUCCESS" << std::endl;
    }
    //连接后删除
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    //顶点数据
    float vertices[] = {
    -0.5f, -0.5f, 0.0f,
     0.5f, -0.5f, 0.0f,
     0.0f,  0.5f, 0.0f
    };

    unsigned int VBO;
    glGenBuffers(1, &VBO);
    unsigned int VAO;
    glGenVertexArrays(1, &VAO);

    // 初始化代码
    // 1. 绑定VAO
    glBindVertexArray(VAO);
    // 2. 把顶点数组复制到缓冲中供OpenGL使用
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    // 3. 设置顶点属性指针
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);



    // 渲染循环
    while (!glfwWindowShouldClose(window))
    {
        // 输入
        processInput(window);

        // 渲染指令
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        // 检查并调用事件，交换缓冲
        glfwSwapBuffers(window);

        // 检查触发什么事件，更新窗口状态
        glfwPollEvents();
    }

    // 释放之前的分配的所有资源
    glfwTerminate();
    
    return 0;
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // 每当窗口改变大小，GLFW会调用这个函数并填充相应的参数供你处理
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    // 返回这个按键是否正在被按下
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)//是否按下了返回键
        glfwSetWindowShouldClose(window, true);
}
```

## 索引缓冲对象

在渲染顶点这一话题上我们还有最后一个需要讨论的东西——**索引缓冲对象**(Element Buffer Object，**EBO**，也叫Index Buffer Object，IBO)

假设我们不再绘制一个三角形而是绘制一个矩形，我们可以**绘制两个三角形来组成一个矩形**（OpenGL 主要处理三角形）这会生成下面的顶点的集合：

```c++
float vertices[] = {
    // 第一个三角形
    0.5f, 0.5f, 0.0f,   // 右上角
    0.5f, -0.5f, 0.0f,  // 右下角
    -0.5f, 0.5f, 0.0f,  // 左上角
    // 第二个三角形
    0.5f, -0.5f, 0.0f,  // 右下角
    -0.5f, -0.5f, 0.0f, // 左下角
    -0.5f, 0.5f, 0.0f   // 左上角
};
```

可以看到，有几个顶点叠加了：我们指定了右下角和左上角两次，一个矩形只有4个而不是6个顶点，这样就产生50%的额外开销。更好的解决方案是只储存不同的顶点，并**设定绘制这些顶点的顺序**，这样子我们只要储存 4 个顶点就能绘制矩形了，之后只要指定绘制的顺序就行了。

**索引缓冲对象 EBO** 就是干这个的，和顶点缓冲对象一样，EBO 也是一个缓冲，它**专门储存索引**，OpenGL 调用这些顶点的索引来决定该绘制哪个顶点。

首先，我们先要定义（不重复的）顶点，和绘制出矩形所需的索引：

```c++
float vertices[] = {
    0.5f, 0.5f, 0.0f,   // 0号点
    0.5f, -0.5f, 0.0f,  // 1号点
    -0.5f, -0.5f, 0.0f, // 2号点
    -0.5f, 0.5f, 0.0f   // 3号点
};
unsigned int indices[] = { // 注意索引从0开始!
    0, 1, 3, // 第一个三角形
    1, 2, 3  // 第二个三角形
};
```

你可以看到，当时用索引的时候，我们只定义了 4 个顶点，下一步我们需要创建索引缓冲对象，与 VBO 类似，我们先绑定 EBO 然后用 `glBufferData()` 把索引复制到缓冲里。

```c++
unsigned int EBO;
glGenBuffers(1, &EBO);
```

同样，和 VBO 类似，我们会把这些函数调用放在绑定和解绑函数调用之间，只不过这次我们把缓冲的类型定义为 `GL_ELEMENT_ARRAY_BUFFER`。

```c++
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
```

要注意的是，我们传递了 `GL_ELEMENT_ARRAY_BUFFER` 当作缓冲目标。

最后一件要做的事是用 `glDrawElements()` 来替换 `glDrawArrays()` 函数，来指明我们从索引缓冲渲染。使用 `glDrawElements()` 时，我们会使用当前绑定的索引缓冲对象中的索引进行绘制：

```c++
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);

//glDrawArrays(GL_TRIANGLES, 0, 6);
glDrawElements(
    GL_TRIANGLES,      //绘制的模式
    6,                 //绘制顶点的个数
    GL_UNSIGNED_INT,   //索引的类型
    0                  //偏移量
);
```

`glDrawElements` 的参数：

1. 第一个参数指定了我们绘制的模式，这个和 `glDrawArrays()` 的一样。
2. 第二个参数是我们打算绘制顶点的个数，这里填 6，也就是说我们一共需要绘制 6 个顶点。
3. 第三个参数是索引的类型，这里是 `GL_UNSIGNED_INT`。
4. 最后一个参数里我们可以指定 EBO 中的偏移量（或者传递一个索引数组，但是这是当你不在使用索引缓冲对象的时候），但是我们会在这里填写 0 。

`glDrawElements()` 函数从当前绑定到 `GL_ELEMENT_ARRAY_BUFFER` 目标的 EBO 中获取索引，这意味着我们必须在每次要用索引渲染一个物体时绑定相应的 EBO，还是有点麻烦。不过顶点数组对象同样可以保存索引缓冲对象的绑定状态，VAO 绑定时正在绑定的索引缓冲对象会被保存为 VAO 的元素缓冲对象，**绑定 VAO 的同时也会自动绑定 EBO**。

![](/images/posts/opengl/render_pipeline/vao-ebo.png)

当目标是 `GL_ELEMENT_ARRAY_BUFFER` 的时候，VAO 会储存 `glBindBuffer()` 的函数调用，这也意味着它也会储存解绑调用，所以确保你没有在解绑 VAO 之前解绑索引数组缓冲，否则它就没有这个 EBO 配置了最后的初始化和绘制代码现在看起来像这样：

```c++
// 初始化代码
// 1. 绑定顶点数组对象
glBindVertexArray(VAO);
// 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
glBindBuffer(GL_ARRAY_BUFFER, VBO);
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
// 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
// 4. 设定顶点属性指针
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);

//...

// .绘制代码（渲染循环中）
glUseProgram(shaderProgram);
glBindVertexArray(VAO);
glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0)；
glBindVertexArray(0);
```

运行结果如下：

![](/images/posts/opengl/render_pipeline/result2.png)

## 扩展知识

### 线框模式(Wireframe Mode) 

要想用线框模式绘制你的三角形，你可以通过 `glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)` 函数配置 OpenGL 如何绘制图元。

1. 第一个参数表示我们打算将其应用到所有的三角形的正面和背面。
2. 第二个参数告诉我们用线来绘制。

**设定之后的绘制调用会一直以线框模式绘制三角形**，直到我们用 `glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)` 将其设置回默认模式。

![](/images/posts/opengl/render_pipeline/result3.png)

可以看到这个矩形的确是由两个三角形组成的，完整代码如下：

```c++
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void processInput(GLFWwindow* window);

// settings
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

const char* vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
const char* fragmentShaderSource = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";

int main()
{
    // 实例化GLFW窗口
    glfwInit();//glfw初始化
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);//主版本号
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);//次版本号
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    //（宽，高，窗口名）返回一个GLFWwindow类的实例：window
    if (window == NULL)
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    // 告诉GLFW我们希望每当窗口调整大小的时候调用改变窗口大小的函数
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad管理opengl函数指针，初始化glad
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    //build and compile 着色器程序
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
    //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    unsigned int fragmentShader;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    //检查片段着色器是否编译错误
    glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShader complie SUCCESS" << std::endl;
    }
    //连接着色器
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    //检查片段着色器是否编译错误
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgram complie SUCCESS" << std::endl;
    }
    //连接后删除
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    //顶点数据
    float vertices[] = {
        0.5f, 0.5f, 0.0f,   // 0号点
        0.5f, -0.5f, 0.0f,  // 1号点
        -0.5f, -0.5f, 0.0f, // 2号点
        -0.5f, 0.5f, 0.0f   // 3号点
    };
    unsigned int indices[] = { // 注意索引从0开始!
        0, 1, 3, // 第一个三角形
        1, 2, 3  // 第二个三角形
    };

    unsigned int VBO;
    glGenBuffers(1, &VBO);
    unsigned int VAO;
    glGenVertexArrays(1, &VAO);
    unsigned int EBO;
    glGenBuffers(1, &EBO);

    // 初始化代码
    // 1. 绑定顶点数组对象
    glBindVertexArray(VAO);
    // 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    // 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    // 4. 设定顶点属性指针
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    //线框模式wireframe
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    // 渲染循环
    while (!glfwWindowShouldClose(window))
    {
        // 输入
        processInput(window);

        // 渲染指令
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        // 检查并调用事件，交换缓冲
        glfwSwapBuffers(window);

        // 检查触发什么事件，更新窗口状态
        glfwPollEvents();
    }

    // 释放之前的分配的所有资源
    glfwTerminate();
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    
    return 0;
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // 每当窗口改变大小，GLFW会调用这个函数并填充相应的参数供你处理
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    // 返回这个按键是否正在被按下
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)//是否按下了返回键
        glfwSetWindowShouldClose(window, true);
}
```

### 两个彼此相连的三角形

我们可以尝试添加更多顶点到数据中，使用 `glDrawArrays()`，绘制两个彼此相连的三角形。我们只需要更改顶点数组：

```c++
float vertices[] = {
    //第一个三角形
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
    //第二个三角形
    0.0f, -0.5f, 0.0f,  // left
    0.9f, -0.5f, 0.0f,  // right
    0.45f, 0.5f, 0.0f   // top 
};
```

然后更改 EBO 设置（直接注了）

```c++
// glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
// glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
```

更改渲染指令：

```c++
glDrawArrays(GL_TRIANGLES, 0, 6);
// glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
```

结果如下：

![](/images/posts/opengl/render_pipeline/result4.png)

代码如下：

```c++
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void processInput(GLFWwindow* window);

// settings
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

const char* vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
const char* fragmentShaderSource = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";

int main()
{
    // 实例化GLFW窗口
    glfwInit();//glfw初始化
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);//主版本号
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);//次版本号
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    //（宽，高，窗口名）返回一个GLFWwindow类的实例：window
    if (window == NULL)
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    // 告诉GLFW我们希望每当窗口调整大小的时候调用改变窗口大小的函数
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad管理opengl函数指针，初始化glad
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    //build and compile 着色器程序
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
    //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    unsigned int fragmentShader;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    //检查片段着色器是否编译错误
    glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShader complie SUCCESS" << std::endl;
    }
    //连接着色器
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    //检查片段着色器是否编译错误
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgram complie SUCCESS" << std::endl;
    }
    //连接后删除
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    //顶点数据
    //float vertices[] = {
    //    0.5f, 0.5f, 0.0f,   // 0号点
    //    0.5f, -0.5f, 0.0f,  // 1号点
    //    -0.5f, -0.5f, 0.0f, // 2号点
    //    -0.5f, 0.5f, 0.0f   // 3号点
    //};
    //unsigned int indices[] = { // 注意索引从0开始!
    //    0, 1, 3, // 第一个三角形
    //    1, 2, 3  // 第二个三角形
    //};

    float vertices[] = {
        //第一个三角形
        -0.9f, -0.5f, 0.0f,  // left 
        -0.0f, -0.5f, 0.0f,  // right
        -0.45f, 0.5f, 0.0f,  // top 
        //第二个三角形
        0.0f, -0.5f, 0.0f,  // left
        0.9f, -0.5f, 0.0f,  // right
        0.45f, 0.5f, 0.0f   // top 
    };

    unsigned int VBO;
    glGenBuffers(1, &VBO);
    unsigned int VAO;
    glGenVertexArrays(1, &VAO);
    unsigned int EBO;
    glGenBuffers(1, &EBO);

    // 初始化代码
    // 1. 绑定顶点数组对象
    glBindVertexArray(VAO);
    // 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    // 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
    //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    //glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    // 4. 设定顶点属性指针
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    ////线框模式wireframe
    //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    // 渲染循环
    while (!glfwWindowShouldClose(window))
    {
        // 输入
        processInput(window);

        // 渲染指令
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        // glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        // 检查并调用事件，交换缓冲
        glfwSwapBuffers(window);

        // 检查触发什么事件，更新窗口状态
        glfwPollEvents();
    }

    // 释放之前的分配的所有资源
    glfwTerminate();
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    //glDeleteBuffers(1, &EBO);
    
    return 0;
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // 每当窗口改变大小，GLFW会调用这个函数并填充相应的参数供你处理
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    // 返回这个按键是否正在被按下
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)//是否按下了返回键
        glfwSetWindowShouldClose(window, true);
}
```

当然你也可以用上 EBO，更简单，我们需要这样改下顶点数组：

```c++
float vertices[] = {
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
    0.9f, -0.5f, 0.0f,  // right
    0.45f, 0.5f, 0.0f   // top 
};
unsigned int indices[] = { // 注意索引从0开始!
    0, 1, 2, // 第一个三角形
    1, 3, 4  // 第二个三角形
};
```

EBO设置和上文相同，结果是一样的。

### 使用不同的 VAO 和 VBO

效果和之前是相同的，但是我们分别创建了两个不同的 VAO 和两个不同的 VBO，所以顶点数据也要分成两个数组：

```c++
float firstTriangle[] = {
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
};
float secondTriangle[] = {
    0.0f, -0.5f, 0.0f,  // left
    0.9f, -0.5f, 0.0f,  // right
    0.45f, 0.5f, 0.0f   // top 
};
```

VAO，VBO 代码如下：

```c++
//unsigned int VBO;
//glGenBuffers(1, &VBO);
//unsigned int VAO;
//glGenVertexArrays(1, &VAO);
//unsigned int EBO;
//glGenBuffers(1, &EBO);
unsigned int VBOs[2], VAOs[2];
glGenVertexArrays(2, VAOs);
glGenBuffers(2, VBOs);

//// 初始化代码
//// 1. 绑定顶点数组对象
//glBindVertexArray(VAO);
//// 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
//glBindBuffer(GL_ARRAY_BUFFER, VBO);
//glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
//// 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
//glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
//glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
//// 4. 设定顶点属性指针
//glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
//glEnableVertexAttribArray(0);

glBindVertexArray(VAOs[0]);
glBindBuffer(GL_ARRAY_BUFFER, VBOs[0]);
glBufferData(GL_ARRAY_BUFFER, sizeof(firstTriangle), firstTriangle, GL_STATIC_DRAW);
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);

glBindVertexArray(VAOs[1]);
glBindBuffer(GL_ARRAY_BUFFER, VBOs[1]);
glBufferData(GL_ARRAY_BUFFER, sizeof(secondTriangle), secondTriangle, GL_STATIC_DRAW);
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);
```

渲染指令：

```c++
glUseProgram(shaderProgram);
//glBindVertexArray(VAO);
//glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
glBindVertexArray(VAOs[0]);
glDrawArrays(GL_TRIANGLES, 0, 3);
glBindVertexArray(VAOs[1]);
glDrawArrays(GL_TRIANGLES, 0, 3);
glBindVertexArray(0);
```

释放资源：

```c++
// 释放之前的分配的所有资源
glfwTerminate();
//glDeleteVertexArrays(1, &VAO);
//glDeleteBuffers(1, &VBO);
//glDeleteBuffers(1, &EBO);
glDeleteVertexArrays(2, VAOs);
glDeleteBuffers(2, VBOs);
```

全部源码：

```c++
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void processInput(GLFWwindow* window);

// settings
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

const char* vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
const char* fragmentShaderSource = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";

int main()
{
    // 实例化GLFW窗口
    glfwInit();//glfw初始化
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);//主版本号
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);//次版本号
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    //（宽，高，窗口名）返回一个GLFWwindow类的实例：window
    if (window == NULL)
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    // 告诉GLFW我们希望每当窗口调整大小的时候调用改变窗口大小的函数
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad管理opengl函数指针，初始化glad
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    //build and compile 着色器程序
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
    //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    unsigned int fragmentShader;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    //检查片段着色器是否编译错误
    glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShader complie SUCCESS" << std::endl;
    }
    //连接着色器
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    //检查片段着色器是否编译错误
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgram complie SUCCESS" << std::endl;
    }
    //连接后删除
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    //顶点数据
    //float vertices[] = {
    //    0.5f, 0.5f, 0.0f,   // 0号点
    //    0.5f, -0.5f, 0.0f,  // 1号点
    //    -0.5f, -0.5f, 0.0f, // 2号点
    //    -0.5f, 0.5f, 0.0f   // 3号点
    //};
    //unsigned int indices[] = { // 注意索引从0开始!
    //    0, 1, 3, // 第一个三角形
    //    1, 2, 3  // 第二个三角形
    //};

    //float vertices[] = {
    //    -0.9f, -0.5f, 0.0f,  // left 
    //    -0.0f, -0.5f, 0.0f,  // right
    //    -0.45f, 0.5f, 0.0f,  // top 
    //    0.9f, -0.5f, 0.0f,  // right
    //    0.45f, 0.5f, 0.0f   // top 
    //};
    //unsigned int indices[] = { // 注意索引从0开始!
    //    0, 1, 2, // 第一个三角形
    //    1, 3, 4  // 第二个三角形
    //};

    float firstTriangle[] = {
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
    };
    float secondTriangle[] = {
        0.0f, -0.5f, 0.0f,  // left
        0.9f, -0.5f, 0.0f,  // right
        0.45f, 0.5f, 0.0f   // top 
    };

    //unsigned int VBO;
    //glGenBuffers(1, &VBO);
    //unsigned int VAO;
    //glGenVertexArrays(1, &VAO);
    //unsigned int EBO;
    //glGenBuffers(1, &EBO);
    unsigned int VBOs[2], VAOs[2];
    glGenVertexArrays(2, VAOs);
    glGenBuffers(2, VBOs);

    //// 初始化代码
    //// 1. 绑定顶点数组对象
    //glBindVertexArray(VAO);
    //// 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
    //glBindBuffer(GL_ARRAY_BUFFER, VBO);
    //glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    //// 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
    //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    //glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    //// 4. 设定顶点属性指针
    //glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    //glEnableVertexAttribArray(0);

    glBindVertexArray(VAOs[0]);
    glBindBuffer(GL_ARRAY_BUFFER, VBOs[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(firstTriangle), firstTriangle, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glBindVertexArray(VAOs[1]);
    glBindBuffer(GL_ARRAY_BUFFER, VBOs[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(secondTriangle), secondTriangle, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    ////线框模式wireframe
    //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    // 渲染循环
    while (!glfwWindowShouldClose(window))
    {
        // 输入
        processInput(window);

        // 渲染指令
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);
        //glBindVertexArray(VAO);
        //glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(VAOs[0]);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glBindVertexArray(VAOs[1]);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glBindVertexArray(0);

        // 检查并调用事件，交换缓冲
        glfwSwapBuffers(window);

        // 检查触发什么事件，更新窗口状态
        glfwPollEvents();
    }

    // 释放之前的分配的所有资源
    glfwTerminate();
    //glDeleteVertexArrays(1, &VAO);
    //glDeleteBuffers(1, &VBO);
    //glDeleteBuffers(1, &EBO);
    glDeleteVertexArrays(2, VAOs);
    glDeleteBuffers(2, VBOs);

    return 0;
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // 每当窗口改变大小，GLFW会调用这个函数并填充相应的参数供你处理
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    // 返回这个按键是否正在被按下
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)//是否按下了返回键
        glfwSetWindowShouldClose(window, true);
}
```

### 创建两个着色器程序

第二个程序使用一个不同的片段着色器(顶点着色器无需改动)，再次绘制这两个三角形，让其中一个输出为黄色。结果如下：

![](/images/posts/opengl/render_pipeline/result5.png)

修改着色器程序

```c++
const char *vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
//const char *fragmentShaderSource = "#version 330 core\n"
//"out vec4 FragColor;\n"
//"void main()\n"
//"{\n"
//"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
//"}\n\0";
const char *fragmentShader1Source = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";
const char *fragmentShader2Source = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 1.0f, 0.0f, 1.0f);\n"
"}\n\0";
```

参考源码：

```c++
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void processInput(GLFWwindow* window);

// settings
const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;

const char* vertexShaderSource = "#version 330 core\n"
"layout (location = 0) in vec3 aPos;\n"
"void main()\n"
"{\n"
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n"
"}\0";
//const char *fragmentShaderSource = "#version 330 core\n"
//"out vec4 FragColor;\n"
//"void main()\n"
//"{\n"
//"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
//"}\n\0";
const char* fragmentShader1Source = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
"}\n\0";
const char* fragmentShader2Source = "#version 330 core\n"
"out vec4 FragColor;\n"
"void main()\n"
"{\n"
"   FragColor = vec4(1.0f, 1.0f, 0.0f, 1.0f);\n"
"}\n\0";

int main()
{
    // 实例化GLFW窗口
    glfwInit();//glfw初始化
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);//主版本号
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);//次版本号
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    //（宽，高，窗口名）返回一个GLFWwindow类的实例：window
    if (window == NULL)
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    // 告诉GLFW我们希望每当窗口调整大小的时候调用改变窗口大小的函数
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad管理opengl函数指针，初始化glad
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        // 生成错误则输出错误信息
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    //build and compile 着色器程序
    //顶点着色器
    unsigned int vertexShader;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);
    //检查顶点着色器是否编译错误
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "vertexShader complie SUCCESS" << std::endl;
    }
    //片段着色器
    //unsigned int fragmentShader;
    //fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    //glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    //glCompileShader(fragmentShader);
    unsigned int fragmentShaderOrange;
    fragmentShaderOrange = glCreateShader(GL_FRAGMENT_SHADER);
    unsigned int fragmentShaderYellow;
    fragmentShaderYellow = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShaderOrange, 1, &fragmentShader1Source, NULL);
    glCompileShader(fragmentShaderOrange);
    glShaderSource(fragmentShaderYellow, 1, &fragmentShader2Source, NULL);
    glCompileShader(fragmentShaderYellow);

    //检查片段着色器是否编译错误
    //glGetShaderiv(fragmentShader, GL_LINK_STATUS, &success);
    //if (!success) {
    //    glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
    //    std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    //}
    //else {
    //    std::cout << "fragmentShader complie SUCCESS" << std::endl;
    //}
    glGetShaderiv(fragmentShaderOrange, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShaderOrange, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShaderOrange complie SUCCESS" << std::endl;
    }
    glGetShaderiv(fragmentShaderYellow, GL_LINK_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragmentShaderYellow, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "fragmentShaderYellow complie SUCCESS" << std::endl;
    }

    //连接着色器
    //unsigned int shaderProgram;
    //shaderProgram = glCreateProgram();
    //glAttachShader(shaderProgram, vertexShader);
    //glAttachShader(shaderProgram, fragmentShader);
    //glLinkProgram(shaderProgram);
    unsigned int shaderProgramOrange;
    shaderProgramOrange = glCreateProgram();
    unsigned int shaderProgramYellow;
    shaderProgramYellow = glCreateProgram();
    glAttachShader(shaderProgramOrange, vertexShader);
    glAttachShader(shaderProgramOrange, fragmentShaderOrange);
    glLinkProgram(shaderProgramOrange);
    glAttachShader(shaderProgramYellow, vertexShader);
    glAttachShader(shaderProgramYellow, fragmentShaderYellow);
    glLinkProgram(shaderProgramYellow);


    //检查片段着色器是否编译错误
    //glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    //if (!success) {
    //    glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
    //    std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    //}
    //else {
    //    std::cout << "shaderProgram complie SUCCESS" << std::endl;
    //}
    glGetProgramiv(shaderProgramOrange, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgramOrange, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgramOrange complie SUCCESS" << std::endl;
    }
    glGetProgramiv(shaderProgramYellow, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgramYellow, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    else {
        std::cout << "shaderProgramYellow complie SUCCESS" << std::endl;
    }

    //连接后删除
    glDeleteShader(vertexShader);
    //glDeleteShader(fragmentShader);
    glDeleteShader(fragmentShaderOrange);
    glDeleteShader(fragmentShaderYellow);

    //顶点数据
    //float vertices[] = {
    //    0.5f, 0.5f, 0.0f,   // 0号点
    //    0.5f, -0.5f, 0.0f,  // 1号点
    //    -0.5f, -0.5f, 0.0f, // 2号点
    //    -0.5f, 0.5f, 0.0f   // 3号点
    //};
    //unsigned int indices[] = { // 注意索引从0开始!
    //    0, 1, 3, // 第一个三角形
    //    1, 2, 3  // 第二个三角形
    //};

    //float vertices[] = {
    //    -0.9f, -0.5f, 0.0f,  // left 
    //    -0.0f, -0.5f, 0.0f,  // right
    //    -0.45f, 0.5f, 0.0f,  // top 
    //    0.9f, -0.5f, 0.0f,  // right
    //    0.45f, 0.5f, 0.0f   // top 
    //};
    //unsigned int indices[] = { // 注意索引从0开始!
    //    0, 1, 2, // 第一个三角形
    //    1, 3, 4  // 第二个三角形
    //};

    float firstTriangle[] = {
    -0.9f, -0.5f, 0.0f,  // left 
    -0.0f, -0.5f, 0.0f,  // right
    -0.45f, 0.5f, 0.0f,  // top 
    };
    float secondTriangle[] = {
        0.0f, -0.5f, 0.0f,  // left
        0.9f, -0.5f, 0.0f,  // right
        0.45f, 0.5f, 0.0f   // top 
    };

    //unsigned int VBO;
    //glGenBuffers(1, &VBO);
    //unsigned int VAO;
    //glGenVertexArrays(1, &VAO);
    //unsigned int EBO;
    //glGenBuffers(1, &EBO);
    unsigned int VBOs[2], VAOs[2];
    glGenVertexArrays(2, VAOs);
    glGenBuffers(2, VBOs);

    //// 初始化代码
    //// 1. 绑定顶点数组对象
    //glBindVertexArray(VAO);
    //// 2. 把我们的顶点数组复制到一个顶点缓冲中，供OpenGL使用
    //glBindBuffer(GL_ARRAY_BUFFER, VBO);
    //glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    //// 3. 复制我们的索引数组到一个索引缓冲中，供OpenGL使用
    //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    //glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    //// 4. 设定顶点属性指针
    //glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    //glEnableVertexAttribArray(0);

    glBindVertexArray(VAOs[0]);
    glBindBuffer(GL_ARRAY_BUFFER, VBOs[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(firstTriangle), firstTriangle, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glBindVertexArray(VAOs[1]);
    glBindBuffer(GL_ARRAY_BUFFER, VBOs[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(secondTriangle), secondTriangle, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    ////线框模式wireframe
    //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    // 渲染循环
    while (!glfwWindowShouldClose(window))
    {
        // 输入
        processInput(window);

        // 渲染指令
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        //glUseProgram(shaderProgram);
        //glBindVertexArray(VAO);
        //glDrawArrays(GL_TRIANGLES, 0, 6);

        glUseProgram(shaderProgramOrange);
        glBindVertexArray(VAOs[0]);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glUseProgram(shaderProgramYellow);
        glBindVertexArray(VAOs[1]);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        
        glBindVertexArray(0);

        // 检查并调用事件，交换缓冲
        glfwSwapBuffers(window);

        // 检查触发什么事件，更新窗口状态
        glfwPollEvents();
    }

    // 释放之前的分配的所有资源
    glfwTerminate();
    //glDeleteVertexArrays(1, &VAO);
    //glDeleteBuffers(1, &VBO);
    //glDeleteBuffers(1, &EBO);
    glDeleteVertexArrays(2, VAOs);
    glDeleteBuffers(2, VBOs);

    return 0;
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // 每当窗口改变大小，GLFW会调用这个函数并填充相应的参数供你处理
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    // 返回这个按键是否正在被按下
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)//是否按下了返回键
        glfwSetWindowShouldClose(window, true);
}
```


#### 参考资料

* https://learnopengl-cn.readthedocs.io/zh/latest/