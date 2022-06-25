---
title: Golang 中 context 的使用方式
date: 2021-06-07 02:45:28
update: 2021-06-07 02:45:28
categories: Golang
tags: [golang, context, goroutine, goroutine]
---

context 是 go 中控制协程的一种比较方便的方式。

<!-- more -->

### Select + Chan

我们都知道一个 goroutine 启动后，我们是无法控制他的，大部分情况是等待它自己结束，那么如果这个 goroutine 是一个不会自己结束的后台 goroutine 呢？比如监控等，会一直运行的。

这种情况下比较笨的办法是全局变量，其他地方通过修改这个变量完成结束通知，然后后台 goroutine 不停的检查这个变量，如果发现被通知关闭了，就自我结束。这种方式首先我们要保证这个变量在多线程下的安全，基于此，有一种经典的处理方式：`chan` + `select` 。

```go
func main() {
	stop := make(chan bool)

	go func() {
		for {
			select {
			case <-stop:    // 收到了停滞信号
				fmt.Println("监控退出，停止了...")
				return
			default:
				fmt.Println("goroutine监控中...")
				time.Sleep(2 * time.Second)
			}
		}
	}()

	time.Sleep(10 * time.Second)
	fmt.Println("可以了，通知监控停止")
	stop<- true

	//为了检测监控过是否停止，如果没有监控输出，就表示停止了
	time.Sleep(5 * time.Second)
}
```

> 这里还有一个额外的知识，go 中通道的接收是有阻塞和非阻塞的（发送只有阻塞），这里 select 中的 case 语句接收通道数据其实是非阻塞的。非阻塞接收通道数据的 CPU 消耗较高，但是可以获取是否通道中有数据的状态。但是当 case 上读一个通道时，如果这个通道是 nil，则该 case 永远阻塞

例子中我们定义一个 stop 的 chan，通知他结束后台 goroutine。实现也非常简单，在后台 goroutine 中，使用 select 判断 stop 是否可以接收到值，如果可以接收到，就表示可以退出停止了；如果没有接收到，就会执行 default 里的监控逻辑，继续监控，只到收到 stop 的通知。

有了以上的逻辑，我们就可以在其他 goroutine 中，给 stop chan 发送值了，例子中是在 main goroutine 中发送的，控制让这个监控的 goroutine 结束。

发送了 `stop<-true` 结束的指令后，我这里使用 `time.Sleep(5 * time.Second)` 故意停顿5秒来检测我们结束监控 goroutine 是否成功。如果成功的话，不会再有 `goroutine监控中...` 的输出了；如果没有成功，监控 goroutine 就会继续打印 `goroutine监控中...` 输出。

这种 chan+select 的方式，是比较优雅的结束一个 goroutine 的方式，不过这种方式也有局限性，如果有很多 goroutine 都需要控制结束怎么办呢？如果这些 goroutine 又衍生了其他更多的 goroutine 怎么办呢？如果一层层的无穷尽的 goroutine 呢？这就非常复杂了，即使我们定义很多 chan 也很难解决这个问题，因为 goroutine 的关系链就导致了这种场景非常复杂。

### Context

上面说的这种场景是存在的，比如一个网络请求 Request，每个 Request 都需要开启一个 goroutine 做一些事情，这些 goroutine 又可能会开启其他的 goroutine。所以我们需要一种可以跟踪 goroutine 的方案，才可以达到控制他们的目的，这就是 Go 语言为我们提供的 Context，称之为上下文非常贴切，它就是 goroutine 的上下文。

下面我们就使用 Go Context 重写上面的示例。

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	go func(ctx context.Context) {
		for {
			select {
			case <-ctx.Done():
				fmt.Println("监控退出，停止了...")
				return
			default:
				fmt.Println("goroutine监控中...")
				time.Sleep(2 * time.Second)
			}
		}
	}(ctx)

	time.Sleep(10 * time.Second)
	fmt.Println("可以了，通知监控停止")
	cancel()
	//为了检测监控过是否停止，如果没有监控输出，就表示停止了
	time.Sleep(5 * time.Second)
}
```

重写也很简单，把之前使用 select+chan 控制的协程改为 Context 控制即可：

`context.Background()` 返回一个空的 Context，这个空的 Context 一般用于整个 Context 树的根节点。然后我们使用 `context.WithCancel(parent)` 函数，创建一个可取消的子 Context，然后当作参数传给 goroutine 使用，这样就可以使用这个子 Context 跟踪这个 goroutine。

在 goroutine 中，使用 select 调用 `<-ctx.Done()` 判断是否要结束，如果接受到值的话，就可以返回结束 goroutine 了；如果接收不到，就会继续进行监控。

那么 Context 是如何发送结束指令的呢？这就是示例中的 `cancel` 函数啦，它是我们调用 `context.WithCancel(parent)` 函数生成子 Context 的时候返回的，第二个返回值就是这个取消函数，它是 `CancelFunc` 类型的。我们调用它就可以发出取消指令，然后我们的监控 goroutine 就会收到信号，就会返回结束。

### Context 控制多个 goroutine

使用 Context 控制一个 goroutine 的例子如上，非常简单，下面我们看看控制多个 goroutine 的例子，其实也比较简单。

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	go watch(ctx,"【监控1】")
	go watch(ctx,"【监控2】")
	go watch(ctx,"【监控3】")

	time.Sleep(10 * time.Second)
	fmt.Println("可以了，通知监控停止")
	cancel()
	//为了检测监控过是否停止，如果没有监控输出，就表示停止了
	time.Sleep(5 * time.Second)
}

func watch(ctx context.Context, name string) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println(name,"监控退出，停止了...")
			return
		default:
			fmt.Println(name,"goroutine监控中...")
			time.Sleep(2 * time.Second)
		}
	}
}
```

示例中启动了 3 个监控 goroutine 进行不断的监控，每一个都使用了 Context 进行跟踪，**当我们使用 cancel 函数通知取消时，这 3 个 goroutine 都会被结束**。这就是 Context 的控制能力，它就像一个控制器一样，按下开关后，**所有基于这个 Context 或者衍生的子 Context 都会收到通知**，这时就可以进行清理操作了，最终释放 goroutine，这就优雅的解决了 goroutine 启动后不可控的问题。

### Context 接口

Context 的接口定义的比较简洁，我们看下这个接口的方法。

```go
type Context interface {
	Deadline() (deadline time.Time, ok bool)

	Done() <-chan struct{}

	Err() error

	Value(key interface{}) interface{}
}
```

这个接口共有 4 个方法，了解这些方法的意思非常重要，这样我们才可以更好的使用他们。

`Deadline` 方法是获取设置的截止时间的意思，第一个返回式是截止时间，到了这个时间点，Context 会自动发起取消请求；第二个返回值 `ok` 表示是否设置截止时间，如果没有设置时间，当需要取消的时候，需要调用取消函数进行取消。

`Done` 方法返回一个只读的 chan，类型为 struct{}，我们在 goroutine 中，如果该方法返回的 chan 可以读取，则意味着 parent context 已经发起了取消请求，我们通过 Done 方法收到这个信号后，就应该做清理操作，然后退出 goroutine，释放资源。

`Err` 方法返回取消的错误原因，因为什么 Context 被取消。

`Value` 方法获取该 Context 上绑定的值，是一个键值对，所以要通过一个 Key 才可以获取对应的值，这个值一般是线程安全的。

以上四个方法中常用的就是 `Done` 了，如果 Context 取消的时候，我们就可以得到一个关闭的 chan，关闭的 chan 是可以读取的，所以**只要 `ctx.Done()` 可以读取的时候，就意味着收到 Context 取消的信号了**，以下是这个方法的经典用法。

```go
func Stream(ctx context.Context, out chan<- Value) error {
	for {
		v, err := DoSomething(ctx)
		if err != nil {
			return err
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case out <- v:
		}
	}
}
```

Context 接口并不需要我们实现，Go 内置已经帮我们实现了 2 个，我们代码中最开始都是以这两个内置的作为最顶层的 partent context，衍生出更多的子 Context。

```go
var (
	background = new(emptyCtx)
	todo       = new(emptyCtx)
)

func Background() Context {
	return background
}

func TODO() Context {
	return todo
}
```

一个是 `Background`，主要用于 main 函数、初始化以及测试代码中，作为 Context 这个树结构的最顶层的 Context，也就是根 Context。

一个是 `TODO`，它目前还不知道具体的使用场景，如果我们不知道该使用什么 Context 的时候，可以使用这个。

他们两个本质上都是 emptyCtx 结构体类型，是一个不可取消，没有设置截止时间，没有携带任何值的 Context。

```go
type emptyCtx int

func (*emptyCtx) Deadline() (deadline time.Time, ok bool) {
	return
}

func (*emptyCtx) Done() <-chan struct{} {
	return nil
}

func (*emptyCtx) Err() error {
	return nil
}

func (*emptyCtx) Value(key interface{}) interface{} {
	return nil
}
```

### Context 的继承衍生

有了如上的根 Context，那么是如何衍生更多的子 Context 的呢？这就要靠 context 包为我们提供的 With 系列的函数了。

```go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc)
func WithDeadline(parent Context, deadline time.Time) (Context, CancelFunc)
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)
func WithValue(parent Context, key, val interface{}) Context
```

这四个 With 函数，接收的都有一个 `partent` 参数，就是父 Context，我们要基于这个父 Context 创建出子 Context 的意思，这种方式可以理解为子 Context 对父 Context 的继承，也可以理解为基于父 Context 的衍生。

通过这些函数，就创建了一颗 Context 树，树的每个节点都可以有任意多个子节点，节点层级可以有任意多个。每个父节点可以控制自己所有的子节点。

* `WithCancel` 函数，传递一个父 Context 作为参数，返回子 Context，以及一个取消函数用来取消 Context。 
* `WithDeadline` 函数，和 `WithCancel` 差不多，它会多传递一个截止时间参数，意味着到了这个时间点，会自动取消 Context，当然我们也可以不等到这个时候，可以提前通过取消函数进行取消。
* `WithTimeout` 和 `WithDeadline` 基本上一样，这个表示是超时自动取消，是多少时间后自动取消 Context 的意思。
* `WithValue` 函数和取消 Context 无关，它是为了生成一个绑定了一个键值对数据的 Context，这个绑定的数据可以通过 Context.Value方法访问到，后面我们会专门讲。

大家可能留意到，前三个函数都返回一个取消函数 CancelFunc，这是一个函数类型，它的定义非常简单。

```go
type CancelFunc func()
```

这就是取消函数的类型，该函数可以取消一个 Context，以及这个节点 Context 下所有的所有的 Context，不管有多少层级。

### WithValue 传递元数据

通过 Context 我们也可以传递一些必须的元数据，这些数据会附加在 Context 上以供使用。

```go
var key string="name"

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	//附加值
	valueCtx:=context.WithValue(ctx,key,"【监控1】")
	go watch(valueCtx)
	time.Sleep(10 * time.Second)
	fmt.Println("可以了，通知监控停止")
	cancel()
	//为了检测监控过是否停止，如果没有监控输出，就表示停止了
	time.Sleep(5 * time.Second)
}

func watch(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			//取出值
			fmt.Println(ctx.Value(key),"监控退出，停止了...")
			return
		default:
			//取出值
			fmt.Println(ctx.Value(key),"goroutine监控中...")
			time.Sleep(2 * time.Second)
		}
	}
}
```

在前面的例子，我们通过传递参数的方式，把 `name` 的值传递给监控函数。在这个例子里，我们实现一样的效果，但是通过的是 Context 的 Value 的方式。

我们可以使用 `context.WithValue` 方法附加一对 K-V 的键值对，这里 Key 必须是等价性的，也就是具有可比性；Value 值要是线程安全的。

这样我们就生成了一个新的 Context，这个新的 Context 带有这个键值对，在使用的时候，可以通过 Value 方法读取 `ctx.Value(key)`。

记住，使用 WithValue 传值，一般是必须的值，不要什么值都传递。

### Context 使用原则

* 不要把 Context 放在结构体中，要以参数的方式传递。
* 以 Context 作为参数的函数方法，应该把 Context 作为第一个参数，放在第一位。
* 给一个函数方法传递 Context 的时候，不要传递 nil，如果不知道传递什么，就使用 `context.TODO`。
* Context 的 Value 相关方法应该传递必须的数据，不要什么数据都使用这个传递。
* Context 是线程安全的，可以放心的在多个 goroutine 中传递。