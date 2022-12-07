---
title: vscode C++ 开发之使用 clangd、C/C++、clang-format
date: 2022-12-07 11:25:55
update: 2022-12-07 11:25:55
categories: C/C++
tags: [C++, vscode, clangd, clang-format]
---

最近比较忙，废话少说，vscode 开发 C/C++ 需要很繁琐的配置，之前也说过 launch 和 tasks 的配置。这篇文章主要结合自身使用经历讲讲 C++ 相关插件。

<!-- more -->

vscode 最常用的几个 C++ 插件（不包含 cmake）就是微软的 C/C++、LLVM 的 clangd，以前我也使用 C/C++，但是智能补全和提示、include 路径都太差劲了，转投 clangd 了，确实好用。所以不废话，直接推荐使用 clangd，不过 C/C++ 也在用，为了二者不冲突，需要配置如下：

``` json
"C_Cpp.autocomplete": "Disabled",
"C_Cpp.clang_format_fallbackStyle": "Visual Studio",
"C_Cpp.clang_format_sortIncludes": true,
"C_Cpp.clang_format_style": "file",
"C_Cpp.default.compilerPath": "/usr/bin/g++",
"C_Cpp.default.configurationProvider": "ms-vscode.cmake-tools",
"C_Cpp.default.cppStandard": "c++11",
"C_Cpp.default.cStandard": "c99",
"C_Cpp.default.intelliSenseMode": "gcc-x64",
"C_Cpp.errorSquiggles": "Disabled",
"C_Cpp.intelliSenseEngine": "Disabled",
"clangd.arguments": [
// 在后台自动分析文件（基于complie_commands)
"--background-index",
"--compile-commands-dir=${workspaceFolder}/build",
"-j=8",
// 支持 .clangd 配置
"--enable-config",
"--clang-tidy",
"--clang-tidy-checks=performance-*,bugprone-*",
"--log=verbose",
"--pretty",
// 全局补全（会自动补充头文件）
"--all-scopes-completion",
// 更详细的补全内容
"--completion-style=detailed",
// 补充头文件的形式
"--header-insertion=iwyu",
// pch优化的位置
"--pch-storage=memory",
"--function-arg-placeholders",
],
```

clangd 的 include 可以通过如下配置：

```json
"clangd.fallbackFlags": [
    "-std=c++11",
    "-I/usr/include/c++/9",
    "-I/usr/include/opencv4",
    "-I${workspaceFolder}/src/",
]
```

clangd 虽然很香，但是有个明显的缺点，就是它一定要使用自身的 clang-format 来格式化，而且无法配置使用 .clang-format 文件。为此，需要安装另一个插件 xaver clang-format。安装完成后配置格式化的程序：

```json
"[cpp]": {
// "editor.defaultFormatter": "llvm-vs-code-extensions.vscode-clangd"
"editor.defaultFormatter": "xaver.clang-format"
},
```

这个插件可以直接调用项目根目录下的 .clang-format 文件来格式化。

最后，有条件的推荐使用 clion 来开发和调试 C++。
