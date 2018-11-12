---
title: CMake库打包以及支持find_package
date: 2018-11-04 16:46:46
update: 2018-11-04 16:46:46
categories: CMake
tags: [CMake, C++, 编译, 链接, 打包, find_package]
---

本文对CMake中库的打包，安装，导出以及支持find_package，使其能够很简单的应用到其他的项目中进行详细的总结。

<!--more-->

## CMake打包库

假设我们的库的结构如下：
```
- include/
  - my_library/
    - header-a.hpp
	- header-b.hpp
	- config.hpp
	- ...
- src/
  - source-a.cpp
  - source-b.cpp
  - config.hpp.in
  - ...
  - CMakeLists.txt
- example/
  - example-a.cpp
  - ...
  - CMakeLists.txt
- tool/
  - tool.cpp
  - CMakeLists.txt
- test/
  - test.cpp
  - CMakeLists.txt
- CMakeLists.txt
- ...
```

在这个库中包含了不同的头文件和源文件，还包含一些例子，工具和单元测试模块。对于库、示例和单元测试，每个模块分别拥有自己的`CMakeLists.txt`，在其中定义了编译的目标并且在子目录中包含了相关的代码。而项目的根目录的`CMakeLists.txt`则定义了配置选项，并将这些子模块的加入编译中去。

库的相关配置在`config.hpp.in`中被定义，然后这个文件会被CMake预处理为`config_impl.hpp`，然后被`config.hpp`包含到项目中去（`#include "config_impl.hpp"`）。

> 这种方法非常重要，能够让我们对不同的CMake配置文件进行分离，比如一些不相干的配置的宏等等

**项目根目录的`CMakeLists.txt`文件：**

```
cmake_minimum_required(VERSION 3.0)
project(MY_LIBRARY)

# define library version (update: apparently you can also do it in project()!)
set(MY_LIBRARY_VERSION_MAJOR 1 CACHE STRING "major version" FORCE)
set(MY_LIBRARY_VERSION_MINOR 0 CACHE STRING "minor version" FORCE)
set(MY_LIBRARY_VERSION ${MY_LIBRARY_VERSION_MAJOR}.${MY_LIBRARY_VERSION_MINOR} CACHE STRING "version" FORCE)

# some options
option(MY_LIBRARY_USE_FANCY_NEW_CLASS "whether or not to use fancy new class" ON)
option(MY_LIBRARY_DEBUG_MODE "whether or not debug mode is activated" OFF)

# add subdiretories
add_subdirectory(src)
add_subdirectory(example)
add_subdirectory(tool)
add_subdirectory(test)
```

这个文件中有一些`option`操作，这些配置选项能够讲相关配置写入到`config.hpp.in`中，我们需要在`config.hpp.in`定义这些选项，类似这种形式：`#cmakedefine01`

> 注意，库的版本号我们使用了`force`，这个就阻止了用户在`CMakeCache.txt`中更改这个版本号

**库模块的`src/CMakeLists.txt`文件：**

```
# set headers
set(header_path "${MY_LIBRARY_SOURCE_DIR}/include/my_library")
set(header ${header_path}/header-a.hpp
		   ${header_path}/header-b.hpp
		   ${header_path}/config.hpp
		   ...)

# set source files
set(src source-a.cpp
		source-b.cpp
		...)
		
# configure config.hpp.in
configure_file("config.hpp.in" "${CMAKE_CURRENT_BINARY_DIR}/config_impl.hpp")

# define library target
add_library(my_library ${header} ${src})
target_include_directories(my_library PUBLIC ${MY_LIBRARY_SOURCE_DIR}/include
											 ${CMAKE_CURRENT_BINARY_DIR})
```

首先，我们定义了头文件和源文件的列表，方便后续使用。

> 注意头文件的路径变量`header_path`，这个变量在不同的CMake子文件中是不同的，而源文件因为在同一目录中，则可以直接定义。

这个CMake文件同样能够生成`config_impl.hpp`，并保存在当前定义的库生成的二进制目录中（`${CMAKE_CURRENT_BINARY_DIR}`），然后被包含在`config.hpp`中，最终在库被使用能够被找到。

`target_include_directories`指定了这个库要用到的头文件，`PUBLIC`制定的包含目录包括了`include/`的子目录和当前`CMake`的二进制目录（为了包含`config_impl.hpp`）。

**其余模块的的`CMakeLists.txt`类似**

到这一步，其余的用户就能够通过`add_subdirtectory()`来添加库的目录，然后调用`target_link_libraries(my_target PUBLIC my_library)`来链接库，并且需要设置`include_directories`来包含相关的头文件，从而能够调用我们的库。

## CMake安装库

我们需要安装的东西包括：头文件，可执行的工具以及已经编译好的库。这些都能够直接使用`install()`命令来直接安装。当我们使用`cmake install（make install）`这类命令时，会拷贝这些文件到`${CMAKE_INSTALL_PREFIX}`中（Linux下默认是`/usr/local`）。

首先，我们在项目的**根`CMakeLists.txt`中**定义相关的位置和变量：
`set(tool_dest "bin")`
`set(include_dest "include/my_library-"${MY_LIBRARY_VERSION}")`
`set(main_lib_dest "lib/my_library-"${MY_LIBRARY_VERSION}")`

然后我们配置`install()`命令：
```
# in tool/CMakeLists.txt
install(TARGETS my_library_tool DESTINATION "${tool_dest}")

# in src/CMakeLists.txt
install(TARGETS my_library DESTINATION "${main_lib_dest}")
install(FILES ${header} DESTINATION "${include_dest}")
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/config_impl.hpp DESTINATION "${include_dest}")
```

这会将可执行工具安装到`${CMAKE_INSTALL_PREFIX}/bin`上，头文件安装到`${CMAKE_INSTALL_PREFIX}/include/my_library-1.0`，库安装到`${CMAKE_INSTALL_PREFIX}/lib/my_library-1.0`。现在就已经满足了我们的一个目标了：不同版本的库不会产生冲突，因为版本号成为了安装路径的一部分。

> 对于工具`tool`，我们假设其能够具有很好的兼容性，并且将其直接放到`bin/`文件夹中，这样其能够直接在终端运行，如果你有需求，你应该对这部分做一些自定义的调整。

但是目前仍然没有解决一个问题：**每个编译出来的库可以拥有不同的配置**。因为现在只有一个配置文件。我们当然也能通过配置不同的识别名称来区别不同的配置，就像利用不同的版本号一样，但是这对于大多数文件是不需要，因此我们不必采用这种方案。

再次忽略掉`tool`，那么就只剩下两个文件需要依赖不同的配置：编译得到的库和生成的`config_impl.hpp`文件。因为其中包含了对于库的一些宏的操作，因此我们需要根据配置的不同，将这两个文件放在不同的位置。

但是我们怎么去区分呢？

可以使用编译类型`${CMAKE_BUILD_TYPE}`这个变量。通过指示`Debug`，`Release`，`MinSizeRel`以及`RelWithDebInfo`，来指示不同的配置选项。

> 我们也可以定义自己的编译类型以及相对应的一些编译选项操作。

现在我们可以在项目的根`CmakeLists.txt`中添加一个新的变量了`lib_dest`：

`set(lib_dest ${main_lib_dest}/${CMAKE_BUILD_TYPE}")`

并且需要更改`config_impl.hpp`和库目标的路径，将其安装到`lib_dest`中，这样对于不同的编译类型（也就是不同的配置），我们就会得到不同的`config_impl.hpp`和库文件。

现在，经过这些配置，我们已经能够区别不同版本和不同配置的库，将其安装到不同的目标路径中，比如`${CMAKE_INSTALL_PREFIX}/lib/my_library-1.0/Debug`。

## CMake导出库

经过上述步骤，我们已经安装了我们库的所有东西，现在其他用户可以通过`include_directories`和`add_libraries`以及制定链接的目标等相应操作来使用我们的库，但是我们希望能够像OpenCV一样，让我们的库的CMake整合到别人的项目中去。

为此，CMake提供了目标导出的功能。导出一个目标能够让我们重复利用一个CMake工程，比如一些变量等等，就像用户自己定义的一样，最常见的就是OpenCV和NDK这类的工程。

为了使用导出功能，需要创建一个`my_library.cmake`文件，其中包含了所有编译和安装目标的引用，用户只需要包含这个文件就可以使用前面编译和安装的库。为了能够导出`my_library`库，我们需要做两件事：

* 首先，对于每个目标，需要指明其是否导出。这个可以通过在`install(TARGET)`命令中添加`EXPORT my_library`选项，像下面这样：

    * `install(TARGETS my_library EXPORT my_library DESTINATION "${lib_dest}")`

* 其次，导出的目标也需要安装，这个可以通过在根目录下的`CMakeLists.txt`中的`install(EXPORT)`命令完成。因为我们的编译类型和`config_impl.hpp`的位置以及库的目标位置有关，二者会被安装到`${lib_dest}`，因此，安装命令如下：

    * `install(EXPORT my_library DESTINATION '${lib_dest}')`

现在还有一个小问题：我们的目标库设定了`target_include_directories()`，这个设置会将我们要构建的目标（`add_library`或者`add_executable`所指定的生成目标）所使用的头文件目录传递给目标，并且安装时也是依据这个来安装目标对象的头文件，这就导致构建和安装的时候，必须使用同一个include目录。而且这个目录是不能随意更改的，否则在构建的时候会出现问题。

> 这里有个额外的知识，我们知道`target_include_directories()`指定了对象的include目录，当这个target T 被其他的target通过`target_link_libraries()`链接的时候，T中通过`target_include_directories()`指定的`PUBLIC`和`INTERFACE`目录，会被自动导入到其他的target的include_directories中。这也是`target_include_directories()`在项目的多模块引用时的一个用法。

CMake有一个特性可以支持修复上述的问题，就是生成器表达式，这个特性可以允许设定目标对象在构建和安装时，使用不同的include目录，我们需要将`target_include_directories()`调用改为如下的格式：
```
target_include_directories(my_library PUBLIC
        $<BUILD_INTERFACE:${MY_LIBRARY_SOURCE_DIR}/include> # for headers when building
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}> # for config_impl.hpp when building
        $<INSTALL_INTERFACE:${include_dest}> # for client in install mode
        $<INSTALL_INTERFACE:${lib_dest}> # for config_impl.hpp in install mode)
```

这样我们就有了一个`my_library.cmake`，当需要用到`my_library`库的时候，只需要通过`include(/path/to/installation/my_library-1.0/Debug/my_library.cmake)`来直接引用，而不比再搞一大堆类似lib的路径，include的路径等等操作了。

但是现在还不是最终形式，我们前面说了，要搞成类似OpenCV那种支持自动find的形式，接着就是最后的支持包搜索了。

## 支持find_package

CMake支持`find_package()`，相信大家在Linux上面用OpenCV，很多都是直接用这条命令。

当我们用`find_package(my_library ...)`这条命令时，它去`${CMAKE_INSTALL_PREFIX}/lib`目录下一个名为`my_library*`的文件夹中自动去寻找一个类似`my_library-config.cmake`的文件，而我们的安装命名就是符合这个规则的，`lib/my_library-[major].[minor] - ${main_lib_dest}`。所以现在我们只需要提供`my_library-config.cmake`文件。

这个文件的内容是能够被`find_package()`直接调用的脚本，通常包含了定义目标的代码，而这些代码我们已经通过`install(EXPORT)`命令生成在`my_library.cmake`文件中了，因此我们只需要在`my_library-config.cmake`文件中`include()`这个文件。包含的时候也要匹配相应的版本号和编译类型
```
# my_library-config.cmake - package configuration file

get_filename_component(SELF_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include(${SELF_DIR}/${CMAKE_BUILD_TYPE}/my_library.cmake)
```

这个文件同样能够存储在我们的库中，必须记住在安装的时候顺便将其安装了：
```
install(FILES my_library-config.cmake DESTINATION ${main_lib_dest})
install(EXPORT ...)
```

现在，用户只需要在自己的CMake项目中调用`find_package(my_library REQUIRED)`，这个库就会被自动搜索和找到（如果该库的${CMAKE_BUILD_TYPE}类型已经被安装了），并且导出所有的对象，然后方便用户直接链接：`target_link_libraries(client_target PUBLIC my_library)`，能够直接链接到正确的版本和构建类型。

> `REQUIRED`并非必须，但是在引用目标的时候就必须附加相应的变量。

### 版本控制

`find_package()`同样支持版本控制，你可以传入版本号作为第二个参数。

`find_package()`的版本控制是通过一个类似名为`my_library-config-version.cmake`文件完成的，和`my_library-config.cmake`类似，你需要在库中提供并安装它。

这个版本控制文件接受`${PACKAGE_FIND_VERSION_MAJOR/MINOR}`格式的版本号，并设置相应的合适版本号变量`${PACKAGE_FIND_VERSION_EXACT/COMPATIBLE/UNSUITABLE}`，以及完整的版本号`${PACKAGE_VERSION}`。但是仅仅设置版本号相关的变量还没有解决一个问题：到底哪个版本的库将会被安装。为此，我们需要在安装之前通过引用根目录的`CMakeLists.txt`中的版本号相关的变量来进行安装的配置。

这里有一个简单的脚本，需要一个指定的大版本号以及必须大于等于的小版本号：
```
# my_library-config-version.cmake - checks version: major must match, minor must be less than or equal

set(PACKAGE_VERSION @MY_LIBRARY_VERSION@)

if("${PACKAGE_FIND_VERSION_MAJOR}" EQUAL "@MY_LIBRARY_VERSION_MAJOR@")
    if ("${PACKAGE_FIND_VERSION_MINOR}" EQUAL "@MY_LIBRARY_VERSION_MINOR@")
        set(PACKAGE_VERSION_EXACT TRUE)
    elseif("${PACKAGE_FIND_VERSION_MINOR}" LESS "@MY_LIBRARY_VERSION_MINOR@")
        set(PACKAGE_VERSION_COMPATIBLE TRUE)
    else()
        set(PACKAGE_VERSION_UNSUITABLE TRUE)
    endif()
else()
    set(PACKAGE_VERSION_UNSUITABLE TRUE)
endif()
```

可以在根目录的`CMakeLists.txt`中配置相应的版本（通过替换@中的版本变量为相应的正确版本号）和完成安装。
```
configure_file(my_library-config-version.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/my_library-config-version.cmake @ONLY)

install(FILES my_library-config.cmake ${CMAKE_CURRENT_BINARY_DIR}/my_library-config-version.cmake DESTINATION ${main_lib_dest})
install(EXPORT ...)
```

> 这里`@NOLY`主要是为了不符合CMake的变量命名方式。

现在调用`find_package(my_library 1.0 REQUIRED)`这种形式，可以寻找1.0或者相兼容版本（如果你设置了兼容的版本号）的库。

## 总结

总结来看，为了在CMake中支持库的安装和`find_package()`，我们需要：

* 改变库目标的`target_include_directories()`，使用`$<BUILD_INTERFACE:>`和`$<INSTALL_INTERFACE:>`生成器表达式来设置正确的include目录。在安装模式下，就是把库的头文件将会被安装的位置。（看下一条）

* 通过`install(FILES)`安装头文件到`include/my_library-[major].[minor]`中。

* 通过`install(FILES)`安装相应的配置头文件（或者其他依赖于构建类型（build type）的头文件）到`lib/my_library-[major].[minor]/${CMAKE_BUILD_TYPE}/`中。

* 通过`install(TARGET target EXPORT my_library ...)`安装库文件到`lib/my_library-[major].[minor]/${CMAKE_BUILD_TYPE}/`中，这条命令也将目标加入导出集合中。

* 定义一个命名为`my_library-config.cmake`的文件，其中包含了相应的`my_library.cmake`文件。还需要定义一个`my_library-config-version.cmake.in`配置文件，和上述一样，用于版本兼容性检查和控制。

* 通过`configure_file(...)`来配置正确的版本安装的文件，然后通过`install(FILES)`安装相应版本控制文件和`my_library-config.cmake`文件到`lib/my_library-[major].[minor]/`中。

* 通过`install(EXPORT)`安装导出集合中的的库文件到`lib/my_library-[major].[minor]/${CMAKE_BUILD_TYPE}/`。

现在，用户只需要通过如下方式来调用：
```
find_package(my_library 1.0 REQUIRED)
target_link_libraries(client_target PUBLIC my_library)
```

这样就能够自动地寻找合适版本的库进行链接。

本文翻译自： https://foonathan.net/blog/2016/03/03/cmake-install.html

项目的源码地址： https://github.com/foonathan/memory
