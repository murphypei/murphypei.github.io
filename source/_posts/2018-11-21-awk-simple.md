---
title: awk 简单使用教程
date: 2018-11-21 10:47:46
update: 2018-11-21 16:46:46
categories: Linux
tags: [Linux, awk, 文本处理, shell]
---

awk是Linux环境下重要的结构化文本处理工具，非常便捷好用。

<!--more-->

之前我一直使用 Python 来处理 Linux 的一些文本，但是对于一些大文本的简单处理，Python 麻烦而且慢，于是现在慢慢改用awk来处理，很多时候一行命令就能解决，因此非常方便。针对使用是过程的一些心得，写个小小的教程，awk太强大了，需要慢慢长时间的学习，我尽量保持更新这个教程吧。

## awk基本概念

awk是基于列的处理工具，它的工作方式是按行读取文本并视为一条记录，每条记录以字段分割成若干字段，然后输出各字段的值。awk认为文件都是结构化的，也就是说都是由单词和各种空白字符组成的，“空白字符”包括空格、tab、连续的空格和tab等，因此awk特别适合用于csv文件的处理。

### 域（字段）

* awk中每个非空白的部分叫做域（或者字段），从左到右依次是第一个域，第二个域。$1，$2表示第一域第二个域，$0表示全部域，也就是整行。
    * 打印第一个和第四个列：`awk '{print $1,$4}' awk.txt`
    * 打印全部内容：`awk '{print $0}' awk.txt`

* `$NF`表示最后一列，`$(NF-1)`倒数第二列，依次类推
    * 打印最后一列：`awk '{print $NF}' awk.txt`

### 分割符

作为csv文件处理工具，分隔符对于awk非常重要，根据输入和输出、域间和行间，共有4个分隔符变量：

| | 分割域 | 分割行 |
| :--: | :--: | :--: |
| 输入 | FS | RS |
| 输出 | OFS | ORS |

* RS和ORS默认是换行（'\n'）
* FS和OFS默认是空白符

> 这地方要注意，我们常用-F来制定输入的域分隔符，却忘记了制定输出的域分隔符，而导致经常是输入是TAB分割，保存后的文本变成了空白符分割。

通过为输入的分隔符变量制定相应分割方式，来更好的处理文本，而输出的分隔符变量则可以让我们在保存处理后的数据时更加灵活。
```s
awk -F "\t" '{OFS="\t"} {if ($4==3) $4=5}1' test.txt
```

上述命令指定输入分隔符为TAB，如果第4个字段为3，则将其替换为5，然后打印出来（{}后跟1表示打印），打印的域分隔符为TAB

## awk使用

### BEGIN和END

* BEGIN模块后紧跟着动作块，这个动作块在awk处理任何输入文件之前执行，所以它可以在没有任何输入的情况下进行测试，它通常用来做一些执行真正的文本处理之前的预处理工作，比如改变内建变量的值，如OFS,RS和FS等，以及打印标题。

* END不匹配任何的输入文件，但是执行动作块中的所有动作，它在整个输入文件处理完成后被执行，也就是后处理。

```s
awk 'BEGIN{FS=":"; OFS="\t"; ORS="\n\n"} {print $1,$2,$3} END{print "${FILENAME} processing done" }' test。
```
上面这条语句在打印之前，更改了FS，OFS，ORS等变量，然后处理完毕打印文本名字（${FILENAME）processing done。

### 字符匹配

作为文本处理工具，字符匹配自然是少不了的，awk支持正则表达式，条件和范围等匹配方式，能够根据匹配结果进行操作。

下面展示一些不同的匹配的写法：

* 打印域匹配的行
```
awk -F: '{if($3==0) print}' /etc/passwd
```

* 匹配大于7列的行，打印列数和整行
```
awk -F: 'NF>7 {print NF,$0}' /etc/passwd
```

* 打印数字开头的行
```
awk '/^[0-9]/{print $0}' group.txt
```

* 匹配包含root或net或ucp的任意行
```
awk '/(root|net|ucp)/'{print $0} /etc/passwd
```

### 内置函数

awk中有一些非常实用的内置函数，我们可以直接实用

| | |
| :---: | :---: |
| gsub(r,s) | 在整个$0中s替换r |
| gsub(r,s,t) | 在整个t中s替换r |
| index(s,t) | 返回s中字符串t的第一位置 |
| length(s) | 返回s长度 |
| match(s,r) | 测试s中是否包含匹配r的字符串 |
| split(s,a,fs) | 在fs上将s分成序列a |
| sub(s,) | 用$0中最左边也是最长的字符串替代 |
| subtr(s,p) | 返回字符串s中从p开始的后缀部分 |
| substr(s,p,n) | 返回字符串s中从p开始长度为n的后缀部分 |

使用示例：

* gsub
```
awk 'gsub(/^root/,"netseek") {print}' /etc/passwd # 将以root开头的字符串替换为netseek并打印
awk 'gsub(/0/,2){print}' /etc/passwd
awk '{print gsub(/0/,2) $0}' /etc/fstab
```

* index
```
awk 'BEGIN{print index("root","o")}'  # 查询o在root字符串中出现的第一位置
awk -F : '$1=="root" {print index($1,"o")" " $1}' /etc/passwd
awk -F : '{print index($1,"o") $1}' /etc/passwd
```

* length
```
awk -F : '{print length($1)}' /etc/passwd
awk -F : '$1=="root"{print length($1)"\t" $0}' /etc/passwd
```

* match
```
awk 'BEGIN{print match("ANCD","C")}'    # 在 ANCD 中查找 C 的位置
```

* split 
```
awk 'BEGIN{print split("123#456#789",array,"#")}'   # 返回字符串数组元素个数
```

* sub 
```
awk 'sub(/0/,2){print }' /etc/fstab     # 只能替换指定域的第一个 0
```

* substr 
```
awk 'BEGIN{print substr("www.baidu.com",5,9)}' #第五个子夫开始,取9个字符
awk 'BEGIN{print substr("www.baidu.com",5)}' #第五个位置开始,一直到最后
```

### 格式化打印

awk printf 格式

| | |
| :--: | :--: |
|%c|ASCII 字符|
|%d|整数|
|%e|科学计数法|
|%f|浮点数|
|%g|awk 决定使用哪种浮点数转换,e 或者 f|
|%o|八进制数|
|%s|字符串|
|%x|十六进制|

使用示例：
```s
echo "65" | awk '{printf "%c\n", $0}'
awk 'BEGIN{printf "%c\n" ,65}'
awk 'BEGIN{printf "%f\n",999}'
awk -F : '{printf "%-15s %s\n",$1,$3}' /etc/passwd
awk -F : 'BEGIN{printf "USER\t\tUID\n"}{printf "%-15s %s\n",$1,$3}' /etc/passwd
who | awk '{if ($1==user) print $1 " you are connected :" $2}' user=$LOGNAME
```

### awk 脚本

对于复杂的awk命令，我们可以写成一个awk 脚本文件(在文件名字后面加后缀.awk 翻遍区分)

awk脚本文件开头一般都是这样的：#!/bin/awk -f，使用的时候直接后跟文件路径即可。

示例：
```
#!/bin/awk -f
BEGIN{
    FS=":"
    print "User\t\tUID"
    print "----------------"
}

{printf "%-15s %s\n",$1,$3}

END{
    print "end"
}
```

## 总结

综上所述，我们可以将awk的使用总结如下：

```s
awk BEGIN{ comands } pattern { commands } END { commands } file
```

1) 执行`BEGIN { comands }`语句块中的语句
2) 从文件或stdin中读取一行，然后执行`pattern { commands }`。重复这个过程，知道文件全部被读取完毕。每读取一行时，它就会检查该行和提供的样式是否匹配。样式本身可以是正则表达式、条件以及行匹配范围等。如果当前行匹配该样式，则执行{ }中的语句
3) 当读至输入流末尾时，执行`END { commands }`语句块

## 实用例子（持续更新）

在这里会记录一下我日常实用的觉得比较实用的例子，持续更新。

* awk 配合拷贝：标注信息最后一列是文件位置，将其取出，拷贝到新的位置，需要利用管道将组合的拷贝命令发送给bash
    * `awk 'BEGIN{FS="\t"} {print "cp "$NF" ./tmp"}' val.lst | sh`

* awk 配合批量resize图片
    * `for im in $(ls -l source/*.jpg | awk '{print $9}'); do convert -resize 128X256 $im dest/$(basename $im); done`
    * 利用awk和ls配合获得原始图片，然后利用convert命令（需要安装imagemagick）resize并存入目标文件夹

* awk 批量移动部分文件到新文件夹
    * `ls -l src_dir | head -n 200001 | awk '{if(NR>1) system("mv ./src_dir/"$9" ./dest_dir")}'`
    * 随机挑选要移动的部分文件
        * `ls -l src_dir | awk 'BEGIN{srand();}{idx=int(rand()*10000000); if(NR>1) print idx $0}' | sort | head -n 11 | awk '{print $9}'`

* 读取 classes-list，内容是按行排列的单词，将其用双引号包裹，打印成一行（也就是 Python 字符串 list 的形式）
    * `awk 'BEGIN{RS="\n";ORS=" ";}  {print "\""$0"\","} END{print "\n"}' /path/to/classes-list`

* 读取 md5 文件，其中第一列是 md5 值，第二列是绝对路径，将第二列的绝对路径改为只有文件的名
    * `cat test.txt | awk '{"basename "$2 |& getline $2; print $1" "$2}`
    * `"basename "$2`：构建获取文件名的命令
    * `|& geline $2`：将构建的命令执行，获取结果
