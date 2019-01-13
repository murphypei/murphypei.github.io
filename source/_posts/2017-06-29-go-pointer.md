---
title: Go在函数中进行指针传递遇到的小问题
date: 2017-06-29
update: 2018-04-12
categories: Go
tags: [go, 指针, 参数传递]
---

刚开始学Go，所以还不太熟悉。但是遇到了一个指针的问题，我觉得和C/C++中的很相似，所以记录一下。

<!--more-->

代码如下

```go
func (x *Json) GetName(args Json, result *Json) error {
	if args.Name == "di" {
		log.Println("args: ", args)
		// result = &Json{Name: "peic", Age: 24}           // (1)
        *result = Json{Name: "peic", Age: 24}        // (2)
		log.Println("result: ", result)
		return nil
	}
	return errors.New("Input Name Error")
}
```

上述(1)、(2)两行代码，有指针经验的人可能就能看出毛病了。

首先需要知道的一点是，Go中只有值传递，没有引用传递

* 在(1)中，result是Json的指针，传递到函数中。通过(1)这个语句**将result赋值给了一个匿名Json对象**，这不符合我们的意愿，我们的函数是为了将结果保存在result指向的对象或者是内存中

* 在(2)中，我们修改了result指向的对象的内容， 符合指针真正的调用方法，也能得到正确的结果。

总结来看，使用指针传递，还是需要注意啊！