---
title: C++ 链接一个不需要的库(--no-as-needed)
date: 2022-04-18 17:16:49
update: 2022-04-18 17:16:49
categories: C/C++
tags: [C++, link, no-as-needed, undef]
---

使用 libtorch 的 C++ 动态链接库遇到了一个非常诡异的问题...

<!-- more -->

我使用 libtorch 的库编译了一个语音识别程序，使用 CPU 推理，能够完美运行，然后在 go 中对这个程序封装了一层 GRPC，也都 OK。

但是当我想用 GPU 推理的时候，我直接下载了 libtorch 的 [GPU 库](https://download.pytorch.org/libtorch/cu113/libtorch-cxx11-abi-shared-with-deps-1.11.0%2Bcu113.zip)，然后直接编译语音程序（需要修改 `torch::Device`），可以直接跑在 GPU 上了，很开心。

但是我用第二次编译出来的库放到 go 程序中，则出现了诡异的错误，运行加载模型的时候，`model->to_device`，而且 `device_count` 为 0，很明显，程序没找到 GPU。

利用 ldd 查看 go 编译出来的可执行文件，发现没有链接到 `torch_cuda_*` 这些库，怎么会这么奇怪呢？我明明把这些库放到编译的 flags 中了。为此我反复调整了链接的 flag，包括库的顺序，库的路径等等，但是都无济于事。

几经辗转，终于找到一个和我类似的错误了。https://github.com/pytorch/pytorch/issues/72396

```
Could not run 'aten::empty_strided' with arguments from the 'CUDA' backend. This could be because the operator doesn't exist for this backend, or was omitted during the selective/custom build process (if using custom build). If you are a Facebook employee using PyTorch on mobile, please visit https://fburl.com/ptmfixes for possible resolutions. 'aten::empty_strided' is only available for these backends: [CPU, Meta, BackendSelect, Python, Named, Conjugate, Negative, ADInplaceOrView, AutogradOther, AutogradCPU, AutogradCUDA, AutogradXLA, AutogradLazy, AutogradXPU, AutogradMLC, AutogradHPU, AutogradNestedTensor, AutogradPrivateUse1, AutogradPrivateUse2, AutogradPrivateUse3, Tracer, UNKNOWN_TENSOR_TYPE_ID, Autocast, Batched, VmapMode].

CPU: registered at aten\src\ATen\RegisterCPU.cpp:18433 [kernel]
Meta: registered at aten\src\ATen\RegisterMeta.cpp:12703 [kernel]
BackendSelect: registered at aten\src\ATen\RegisterBackendSelect.cpp:665 [kernel]
Python: registered at ..\..\aten\src\ATen\core\PythonFallbackKernel.cpp:47 [backend fallback]
Named: registered at ..\..\aten\src\ATen\core\NamedRegistrations.cpp:7 [backend fallback]
Conjugate: fallthrough registered at ..\..\aten\src\ATen\ConjugateFallback.cpp:22 [kernel]
Negative: fallthrough registered at ..\..\aten\src\ATen\native\NegateFallback.cpp:22 [kernel]
ADInplaceOrView: fallthrough registered at ..\..\aten\src\ATen\core\VariableFallbackKernel.cpp:64 [backend fallback]
AutogradOther: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradCPU: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradCUDA: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradXLA: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradLazy: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradXPU: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradMLC: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradHPU: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradNestedTensor: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradPrivateUse1: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradPrivateUse2: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
AutogradPrivateUse3: registered at ..\..\torch\csrc\autograd\generated\VariableType_2.cpp:10483 [autograd kernel]
Tracer: registered at ..\..\torch\csrc\autograd\generated\TraceType_2.cpp:11423 [kernel]
UNKNOWN_TENSOR_TYPE_ID: fallthrough registered at ..\..\aten\src\ATen\autocast_mode.cpp:466 [backend fallback]
Autocast: fallthrough registered at ..\..\aten\src\ATen\autocast_mode.cpp:305 [backend fallback]
Batched: registered at ..\..\aten\src\ATen\BatchingRegistrations.cpp:1016 [backend fallback]
VmapMode: fallthrough registered at ..\..\aten\src\ATen\VmapModeRegistrations.cpp:33 [backend fallback]

Exception raised from reportError at ..\..\aten\src\ATen\core\dispatch\OperatorEntry.cpp:431 (most recent call first):
00007FFEE7CAA29200007FFEE7CAA230 c10.dll!c10::Error::Error [<unknown file> @ <unknown line number>]
00007FFEE7C843C500007FFEE7C84350 c10.dll!c10::NotImplementedError::NotImplementedError [<unknown file> @ <unknown line number>]
00007FFD5F015C7100007FFD5F015AA0 torch_cpu.dll!c10::impl::OperatorEntry::reportError [<unknown file> @ <unknown line number>]
00007FFD5F6C6AF000007FFD5F66DBB0 torch_cpu.dll!at::_ops::xlogy_Tensor::redispatch [<unknown file> @ <unknown line number>]
00007FFD5F8E73F100007FFD5F8CF610 torch_cpu.dll!at::_ops::zeros_out::redispatch [<unknown file> @ <unknown line number>]
00007FFD5F8E3F7400007FFD5F8CF610 torch_cpu.dll!at::_ops::zeros_out::redispatch [<unknown file> @ <unknown line number>]
00007FFD5F6EB6E800007FFD5F6EB520 torch_cpu.dll!at::_ops::empty_strided::call [<unknown file> @ <unknown line number>]
00007FFD5EF259CB00007FFD5EF258D0 torch_cpu.dll!at::empty_strided [<unknown file> @ <unknown line number>]
00007FFD5F2C24D100007FFD5F2C2130 torch_cpu.dll!at::native::_to_copy [<unknown file> @ <unknown line number>]
00007FFD5FA7C3D600007FFD5FA7BF10 torch_cpu.dll!at::compositeexplicitautograd::xlogy_ [<unknown file> @ <unknown line number>]
00007FFD5FA5A8FB00007FFD5FA3F310 torch_cpu.dll!at::compositeexplicitautograd::bitwise_xor_outf [<unknown file> @ <unknown line number>]
00007FFD5F4EB5AD00007FFD5F45B290 torch_cpu.dll!at::TensorMaker::make_tensor [<unknown file> @ <unknown line number>]
00007FFD5F8DED7700007FFD5F8CF610 torch_cpu.dll!at::_ops::zeros_out::redispatch [<unknown file> @ <unknown line number>]
00007FFD5F8E36EB00007FFD5F8CF610 torch_cpu.dll!at::_ops::zeros_out::redispatch [<unknown file> @ <unknown line number>]
00007FFD5F4EB5AD00007FFD5F45B290 torch_cpu.dll!at::TensorMaker::make_tensor [<unknown file> @ <unknown line number>]
00007FFD5F56326800007FFD5F563190 torch_cpu.dll!at::_ops::_to_copy::redispatch [<unknown file> @ <unknown line number>]
00007FFD60A27F0000007FFD60A27A30 torch_cpu.dll!at::redispatch::_thnn_fused_lstm_cell_backward [<unknown file> @ <unknown line number>]
00007FFD60A4031D00007FFD60A34930 torch_cpu.dll!torch::jit::Node::c_ [<unknown file> @ <unknown line number>]
00007FFD5F50C12B00007FFD5F50BF70 torch_cpu.dll!at::_ops::_to_copy::call [<unknown file> @ <unknown line number>]
00007FFD5F2C2E7900007FFD5F2C2BD0 torch_cpu.dll!at::native::to_dense_backward [<unknown file> @ <unknown line number>]
00007FFD5F2C2B0C00007FFD5F2C29E0 torch_cpu.dll!at::native::to [<unknown file> @ <unknown line number>]
00007FFD5FB6A66800007FFD5FB63F10 torch_cpu.dll!at::compositeimplicitautograd::where [<unknown file> @ <unknown line number>]
00007FFD5FB4DB5D00007FFD5FB1BE50 torch_cpu.dll!at::compositeimplicitautograd::broadcast_to [<unknown file> @ <unknown line number>]
00007FFD5F7E6F4600007FFD5F7E6D70 torch_cpu.dll!at::_ops::to_dtype_layout::call [<unknown file> @ <unknown line number>]
00007FFD5EF4AA8800007FFD5EF4A970 torch_cpu.dll!at::Tensor::to [<unknown file> @ <unknown line number>]
00007FFD5EF9EAE900007FFD5EF9E9F0 torch_cpu.dll!at::tensor [<unknown file> @ <unknown line number>]
00007FF7714295A200007FF7714294B0 SplinterlandsSimulator.exe!main [C:\Users\xargo\source\repos\SplinterlandsSimulator\SplinterlandsSimulator\SplinterlandsSimulator.cpp @ 390]
00007FF77144164C00007FF771441540 SplinterlandsSimulator.exe!__scrt_common_main_seh [d:\a01\_work\20\s\src\vctools\crt\vcstartup\src\startup\exe_common.inl @ 288]
00007FFF47C554E000007FFF47C554D0 KERNEL32.DLL!BaseThreadInitThunk [<unknown file> @ <unknown line number>]
00007FFF48DA485B00007FFF48DA4830 ntdll.dll!RtlUserThreadStart [<unknown file> @ <unknown line number>]
```

上述报错跟我的很像，而且从下面的回复来看，也是没能链接到 cuda 相应的库。下面的回复给我了启发：**如果我的 go 程序没用到 libtorch 的 cuda 接口，是不是不会主动链接到 libtorch 相应的 cuda 的库**？

前面说了，ldd 查看的确实没有，那怎么让编译器强制链接到 libtorch 的 cuda 相应的库呢？显然是的，编译器默认使用了 `--as-needed` 编译参数，这也是合理的，我们没必要链接所有的动态库，动态库本来就是按需链接，但是在我们的这个使用场景中，会遇到这种特殊情况，使用 `--no-as-needed` 强制链接到 libtorch cuda 的相应库，结果就没有问题了。

```
--as-needed
--no-as-needed
This option affects ELF DT_NEEDED tags for dynamic libraries mentioned on the command line after the --as-needed option. Normally the linker will add a DT_NEEDED tag for each dynamic library mentioned on the command line, regardless of whether the library is actually needed or not. --as-needed causes a DT_NEEDED tag to only be emitted for a library that satisfies an undefined symbol reference from a regular object file or, if the library is not found in the DT_NEEDED lists of other libraries linked up to that point, an undefined symbol reference from another dynamic library. --no-as-needed restores the default behaviour.
```