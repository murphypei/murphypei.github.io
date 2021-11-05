---
title: 使用 vscode 调试 C++ 程序
date: 2021-11-04 11:00:28
update: 2021-11-04 11:00:28
categories: C/C++
tags: [vscode, c++, tasks, launch, c_cpp_properties]
---

vscode 远程比 clion 好用太多了，就是 C++ 调试功能不如 clion，不过简单配置一下，也可以实现单步调试，比简陋的 GDB 还是好用多了。

<!-- more -->


下面的配置是我的某个项目的配置，仅仅作为参考和自己的记录，因为国内大部分的教程都只写单独的文件，没啥参考价值。

### c_cpp_properties.json 

这个文件主要是配置一些头文件路径，不过现在 vscode 对于头文件的支持还是不太行，配置了还有很多波浪线，头疼。

```json
{
    "configurations": [
        {
            "name": "Linux",
            "includePath": [
                "${workspaceFolder}/**",
                "${workspaceFolder}/build"
            ],
            "defines": [],
            "configurationProvider": "ms-vscode.cmake-tools"
        }
    ],
    "version": 4
}
```

### tasks.json

这个文件是执行真正的任务，主要是编译任务。以前我以为只支持 g++ 命令（坑爹的国内教程），后来想通了，这个文件其实就是执行 linux 命令，你可以放 cmake、make 甚至编译脚本的命令，我通常喜欢写一个编译脚本来编译。

下面的例子，cmake 和 make 执行编译，build 通过脚本编译。make 任务可以不需要 cmake 重新生成（关闭 dependsOn），方便快速增量编译。

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "cmake",
            "type": "shell",
            "options": {
                "cwd": "${workspaceFolder}/build"
            },
            "command": "cmake -DCMAKE_BUILD_TYPE=Debug -DBUILD_ANDROID=OFF -DBUILD_UNIT_TESTS=ON -DBUILD_SHARED_LIBS=ON -DCUDA_ENABLE=OFF .. "
        },
        {
            "label": "make",
            "type": "shell",
            "options": {
                "cwd": "${workspaceFolder}/build"
            },
            "command": "make -j8",
            // "dependsOn": [
            //     "cmake"
            // ],
        },
        {
            "label": "build",
            "type": "shell",
            "command": "source ${workspaceFolder}/linux.sh"
        }
    ]
}
```

### launch.json

用 GDB 执行可执行文件，没啥说的，注意 preLaunchTask 根据需要选择（tasks.json 中配置的 build 彻底重新编译，make 只编译改动的头文件）。

```json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "capt_test",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/capt_test",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            // "preLaunchTask": "make"
            "preLaunchTask": "build"
        },
    ]
}
```
