---
title: MySQL事务知识点整理
date: 2018-04-12 10:33:43
update: 2018-04-12 10:33:43
categories: Database
tags: [MySQL, 数据库, 事务, ACID]
---

对MySQL数据库中的事务操作、存在的问题和相应的隔离级别等知识点进行整理，通过实例进行说明

<!--more-->

MySQL事务主要用于处理操作量大，复杂度高的数据。比如说，在银行管理系统中，账户A给账户B转账，既需要减少账户A的余额，又需要增加账户B的余额，二者缺一不可；再比如，在人员管理系统中，你删除一个人员，既需要删除人员的基本资料，也要删除和该人员相关的信息，如信箱，文章等等这样，这些数据库操作语句就构成一个事务！

MySQL事务具有一些基本特性：

* 在 MySQL 中只有使用了 Innodb 数据库引擎的数据库或表才支持事务。

* 事务处理可以用来维护数据库的完整性，保证成批的SQL语句要么全部执行，要么全部不执行。

* 事务用来管理insert,update,delete语句

## 事务的基本要素(ACID)

* 原子性（Atomicity）：事务开始操作后，要么全部做完，要么全部不做，不可能停滞在中间环节。事务执行过程中出错，会回滚到事务开始前的状态，所有的操作就像没有发生一样。也就是说事务是一个不可分割的整体，就像化学中学过的原子，是物质构成的基本单位。

* 一致性（Consistency）：事务开始前和结束后，数据库的完整性约束没有被破坏 。比如A向B转账，不可能A扣了钱，B却没收到。

* 隔离性（Isolation）：同一时间，只允许一个事务请求同一数据，不同的事务之间彼此没有任何干扰。比如A正在从一张银行卡中取钱，在A取钱的过程结束前，B不能向这张卡转账。

* 持久性（Durability）：事务完成后，事务对数据库的所有更新将被保存到数据库，不能回滚。

## 事务并发问题

事务的并发操作会带来编程中多线程操作类似的问题，具体有以下几点：

* 脏读：事务A读取了事务B更新的数据，然后B回滚操作，那么A读取到的数据是脏数据。

* 幻读：事务A正在修改数据库的数据，而与此同时，事务B**新增或者删除**了一些数据，等A改完发现，一些数据没有被修改，好像出现了幻觉，这就叫幻读。

* 不可重复读：事务A多次读取同一数据，事务B在事务A多次读取的过程中，对数据作了更新并提交，导致事务A多次读取同一数据时，结果不一致。

**注意：**不可重复读和幻读经常会混淆，我的理解是，不可重复读侧重于数据在两次读取之间被修改了，导致读取的结果不一样；而幻读侧重于新增或者删除了数据。更好的理解就是对于二者的解决办法是不一样的：不可重复读只需要锁住所需要读取的数据就行了，而幻读则需要锁住整个数据表。

## 事务隔离级别

不同事务的隔离级别带来的操作消耗是不一样的，体现着锁的范围。不同的隔离级别对于并发问题的敏感性也是不一样。

|         事务隔离级别         | 脏读  | 不可重复读 | 幻读  |
| :--------------------------: | :---: | :--------: | :---: |
| 未提交读（read-uncommitted） |  是   |     是     |  是   |
|   提交读（read-committed）   |  否   |     是     |  是   |
| 可重复读（repeatable-read）  |  否   |     否     |  是   |
|    串行读（serializable）    |  否   |     否     |  否   |

1. 未提交读：相当于完全没有隔离，一个事务可能会读到其他事务中未提交修改的数据，而别的事务可能还会对这个数据进行其他修改，甚至回滚操作，所以这种隔离级别下，上述并发问题均可能出现。

2. 提交读：只能读取到其他事务已经提交的数据，是Oracle等数据库默认的级别。

3. 可重复度：在同一个事务内的查询都是在事务开始时刻一致的，是MySQL的InnoDB引擎默认级别。在SQL标准中，该隔离级别消除了不可重复读，但是还存在幻读的可能。

4. 串行读：事务完全串行操作，每次读都需要获得表级共享锁，读写相互都会阻塞。

## 实例说明

### 创建数据库和数据表

```SQL
mysql> CREATE DATABASE IF NOT EXISTS examples DEFAULT CHARSET utf8;
Query OK, 1 row affected (0.00 sec)

mysql> use examples;
Database changed

mysql> CREATE TABLE IF NOT EXISTS `students` (
    -> `id` SMALLINT UNSIGNED AUTO_INCREMENT,
    -> `name` VARCHAR(10) NOT NULL,
    -> `scores` SMALLINT UNSIGNED NOT NULL,
    -> PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;
Query OK, 0 rows affected (0.28 sec)

mysql> INSERT INTO students (`name`, `scores`) VALUES ("xiaohua", 100);
Query OK, 1 row affected (0.09 sec)

mysql> INSERT INTO students (`name`, `scores`) VALUES ("zhangsan", 90);
Query OK, 1 row affected (0.02 sec)

mysql> INSERT INTO students (`name`, `scores`) VALUES ("lisi", 80);
Query OK, 1 row affected (0.03 sec)

mysql> SELECT * FROM students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |    100 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)

```

### 首先验证InnoDB的默认隔离级别

```SQL
mysql> SELECT @@tx_isolation;
+-----------------+
| @@tx_isolation  |
+-----------------+
| REPEATABLE-READ |
+-----------------+
1 row in set (0.00 sec)
```

可以看到默认是可重复读

### 未提交读

先将客户端A的事务隔离级别改为未提交读

```SQL
mysql> set session transaction isolation level read uncommitted;
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT @@tx_isolation;
+------------------+
| @@tx_isolation   |
+------------------+
| READ-UNCOMMITTED |
+------------------+
1 row in set (0.00 sec)
```
**这种隔离级别的改变只对输入该命令的客户端生效，而且不是永久的，在客户端断开连接之后，将恢复为默认的级别。**

然后在客户端A中开始一个查询事务，且不提交：

```SQL
mysql> start transaction;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |    100 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

在客户端B中开启一个事务，更改表的数据，**但不提交**：

```SQL
mysql> start transaction;
Query OK, 0 rows affected (0.00 sec)

mysql> update students set scores=60 where id=1;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     60 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

而客户端A中已经能够看到更改的数据了：

```SQL
mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     60 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

如果此时客户端B因为其他原因进行`rollback`，那么A此时读的数据就是脏数据。

### 提交读

先将客户端A的级别改为提交读，并且数据都回滚了。

```SQL
mysql> set session transaction isolation level read committed;
Query OK, 0 rows affected (0.01 sec)

mysql> start transaction;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |    100 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)

```

在客户端B中开启一个事务修改数据，但不提交。

```SQL
mysql> begin;
Query OK, 0 rows affected (0.03 sec)

mysql> update students set scores=50 where id=1;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

此时在客户端A中查询，发现数据是没有变化的，已经读不到未提交的数据了。

```SQL
mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |    100 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

在客户端B中利用`commit`命令提交之后，在A中就能够查到修改后的数据了。

```SQL
mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |    100 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)


mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

但是我们可以看出，客户端A**在一个事务中两次相同命令查询的结果不同**，这也就是不可重复读的现象。

另外还有一点，在`commit`命令生效后，由于持久化的特性，`rollback`是无法回滚回去的。

```SQL
mysql> commit;
Query OK, 0 rows affected (0.04 sec)

mysql> rollback;
Query OK, 0 rows affected (0.01 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

### 可重复读

将客户端A改为可重复读，查询数据。

```SQL
mysql> set session transaction isolation level repeatable read;
Query OK, 0 rows affected (0.00 sec)

mysql> select @@tx_isolation;
+-----------------+
| @@tx_isolation  |
+-----------------+
| REPEATABLE-READ |
+-----------------+
1 row in set (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

在客户端B中修改数据并提交。

```SQL
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> update students set scores=30 where id=1;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> commit;
Query OK, 0 rows affected (0.05 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     30 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.01 sec)
```

此时在客户端A中继续查询数据，**数据是没有变化的，没有出现不可重复读的问题**

```SQL
mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

这地方有个小问题：**在事务中输入命令不要使用上键来偷懒，每一条命令都要自己输，否则容易出现事务自动提交的bug**

**但是这个地方如果执行数据修改，其会按照客户端B中已提交的数据进行修改**

```SQL
mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     50 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)

mysql> update students set scores=scores-10 where id=1;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     20 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

这种结果我觉得其实就是幻读的一种....但是好像不是这种叫法。另外，这种做法能够很好的保持数据的一致性。

### 串行化

将客户端A设置为串行化，查询数据。

```SQL
mysql> set session transaction isolation level serializable;
Query OK, 0 rows affected (0.00 sec)

mysql> select @@tx_isolation;
+----------------+
| @@tx_isolation |
+----------------+
| SERIALIZABLE   |
+----------------+
1 row in set (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from students;
+----+----------+--------+
| id | name     | scores |
+----+----------+--------+
|  1 | xiaohua  |     20 |
|  2 | zhangsan |     90 |
|  3 | lisi     |     80 |
+----+----------+--------+
3 rows in set (0.00 sec)
```

**将客户端B设置为串行化**，然后插入数据。

```SQL
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into students values(4, 'wangwu', 10);
ERROR 1205 (HY000): Lock wait timeout exceeded; try restarting transaction

```
一开始并没有报错，命令执行被阻塞，但是隔了一会，会报错，执行失败，因为客户端A的事务一直没有提交。

## 总结

* mysql中默认事务隔离级别是可重复读，但并不会锁住读取到的行，两个事务都可以修改，且修改的结果会叠加，但是一个事务中读取的结果一致。

* 事务隔离级别为读提交时，写数据只会锁住相应的行。

* 事务隔离级别为可重复读时，如果有索引（包括主键索引）的时候，以索引列为条件更新数据，会存在间隙锁间隙锁、行锁、下一键锁的问题，从而锁住一些行；如果没有索引，更新数据时会锁住整张表。

* 事务隔离级别为串行化时，读写数据都会锁住整张表。

* 隔离级别越高，越能保证数据的完整性和一致性，但是对并发性能的影响也越大，鱼和熊掌不可兼得啊。对于多数应用程序，可以优先考虑把数据库系统的隔离级别设为Read Committed，它能够避免脏读取，而且具有较好的并发性能。尽管它会导致不可重复读、幻读这些并发问题，在可能出现这类问题的个别场合，可以由应用程序采用悲观锁或乐观锁来控制。