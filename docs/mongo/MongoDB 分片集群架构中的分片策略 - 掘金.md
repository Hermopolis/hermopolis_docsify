1-1、分片简介
--------

`分片（shard）是指在将数据进行水平切分之后，将其存储到多个不同的服务器节点上的一种扩展方式`。分片在概念上非常类似于应用开发中的“水平分表”。不同的点在于，MongoDB本身就自带了分片管理的能力，对于开发者来说可以做到开箱即用。

### 1-1-1、为什么要使用分片？

`MongoDB复制集实现了数据的多副本复制及高可用，但是一个复制集能承载的容量和负载是有限的`。在你遇到下面的场景时，就需要考虑使用分片了：

*   存储容量需求超出单机的磁盘容量。
*   活跃的数据集超出单机内存容量，导致很多请求都要从磁盘读取数据，影响性能。
*   写IOPS超出单个MongoDB节点的写服务能力。

> 垂直扩容（Scale Up） VS 水平扩容（Scale Out）：
> 
> 垂直扩容 ： 用更好的服务器，提高 CPU 处理核数、内存数、带宽等
> 
> 水平扩容 ： 将任务分配到多台计算机上

### 1-1-2、MongoDB 分片集群架构

MongoDB 分片集群（Sharded Cluster）是对数据进行水平扩展的一种方式。`MongoDB 使用 分片集群来支持大数据集和高吞吐量的业务场景`。在分片模式下，存储不同的切片数据的节点被称为分片节点，一个分片集群内包含了多个分片节点。当然，除了分片节点，集群中还需要一些配置节点、路由节点，以保证分片机制的正常运作。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7efdf85d61124d719ee46e80298abb90~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

### 1-1-3、核心概念

*   **数据分片**：分片用于存储真正的数据，并提供最终的数据读写访问。分片仅仅是一个逻辑的概念，它可以是一个单独的mongod实例，也可以是一个复制集。图中的Shard1、Shard2都是一个复制集分片。在`生产环境中也一般会使用复制集的方式，这是为了防止数据节点出现单点故障。`
*   **配置服务器（Config Server）**：配置服务器包含多个节点，并组成一个复制集结构，对应于图中的ConfigReplSet。`配置复制集中保存了整个分片集群中的元数据，其中包含各个集合的分片策略，以及分片的路由表等。`
*   **查询路由（mongos）**：`mongos是分片集群的访问入口，其本身并不持久化数据`。mongos启动后，会从配置服务器中加载元数据。之后mongos开始提供访问服务，并将用户的请求正确路由到对应的分片。在分片集群中可以部署多个mongos以分担客户端请求的压力。

1-2、分片策略使用分片集群
--------------

之前的文章有讲述分片集群搭建过程，[\# MongoDB分片集群的两种搭建方式及使用](https://juejin.cn/post/7160298673182605343 "https://juejin.cn/post/7160298673182605343")

通过分片功能，可以将一个非常大的集合分散存储到不同的分片上，如图：

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/d5f0ebec482840689802e1c218155b46~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

假设这个集合大小是1TB，那么拆分到4个分片上之后，每个分片存储256GB的数据。这个当然是最理想化的场景，实质上很难做到如此绝对的平衡。一个集合在拆分后如何存储、读写，与该集合的分片策略设定是息息相关的。

### 1-2-1、使用分片集群

*   首先连接mongos

```null
mongo mongo03.com:27017

```

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/e1512f09def24beabe4012663d445504~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

*   为了使集合支持分片，需要先开启database的分片功能(下面给集合`shop`开启分片功能)--**`必须要开启`**

```arduino
sh.enableSharding("shop")

```

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/ec07b33e1f724b0d8bfc965d2a289280~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

*   执行shardCollection命令，对集合执行分片初始化()

```php
sh.shardCollection("shop.product",{productId:"hashed"},false,{numInitialChunks:4})

```

`shop.product集合将productId作为分片键，并采用了哈希分片策略`，除此以外，“numInitialChunks：4”表示将初始化4个chunk。 `numInitialChunks必须和哈希分片策略配合使用`。而且，这个选项只能用于空的集合，如果已经存在数据则会返回错误。这个值可以为后面数据平衡迁移做计算，（我之前搭建分片集群有两个分片，这样就是每个分片有两个chunk）

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/64743ec0b6dd4e108a48095c10951769~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

*   向分片集合写入数据(向shop.product集合写入一批数据)

```css
db = db.getSiblingDB("shop");
var count = 0;
for (var i = 0; i < 1000; i++) {
    var p = [];
    for (var j = 0; j < 100; j++) {
        p.push({
            "productId": "P-" + i + "-" + j,
            name: "羊毛衫",
            tags: [{
                tagKey: "size",
                tagValue: ["L", "XL", "XXL"]
            },
            {
                tagKey: "color",
                tagValue: ["蓝色", "杏色"]
            },
            {
                tagKey: "style",
                tagValue: "韩风"
            }]
        });
    }
    count += p.length;
    db.product.insertMany(p);
    print("insert ", count)
}

```

*   查询数据的分布

```scss
db.product.getShardDistribution()

```

可以看到product集合数据存储于shard1和shard2两个分片，同时也可以看到每个分片存储的数据大小、数量以及chunks数量。最后在总统计中可以看到总数据量，以及每个分片数据的占比

![](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/b96c74d9d622441f8d39bd5b32b96600~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

### 1-2-2、什么是chunk

chunk的意思是数据块，一个chunk代表了集合中的“一段数据”，例如，用户集合（db.users）在切分成多个chunk之后如图所示：

![](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/92a34d4073f04d01b88c5fa2a28f0321~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

chunk所描述的是范围区间，例如，db.users使用了userId作为分片键，那么chunk就是userId的各个值（或哈希值）的连续区间。`集群在操作分片集合时，会根据分片键找到对应的chunk，并向该chunk所在的分片发起操作请求`，而chunk的分布在一定程度上会影响数据的读写路径，这由以下两点决定：

*   chunk的切分方式，决定如何找到数据所在的chunk
*   chunk的分布状态，决定如何找到chunk所在的分片

### 1-2-3、分片算法

`chunk切分是根据分片策略进行实施的，分片策略的内容包括分片键和分片算法`。当前，MongoDB支持两种分片算法：

#### 1-2-3-1、范围分片（range sharding）

假设集合根据x字段来分片，x的完整取值范围为\[minKey, maxKey\]（x为整数，这里的minKey、maxKey为整型的最小值和最大值），其将整个取值范围划分为多个chunk，例如：

*   chunk1包含x的取值在\[minKey，-75）的所有文档。
    
*   chunk2包含x取值在\[-75，25）之间的所有文档，依此类推。
    

![](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/b6693172ed0540a9b56c08293a0c9c8b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

`范围分片能很好地满足范围查询的需求`，比如想查询x的值在\[-30，10\]之间的所有文档，这时mongos直接将请求定位到chunk2所在的分片服务器，就能查询出所有符合条件的文档。`范围分片的缺点在于，如果Shard Key有明显递增（或者递减）趋势，则新插入的文档会分布到同一个chunk，此时写压力会集中到一个节点，从而导致单点的性能瓶颈`。一些常见的导致递增的Key如下：

*   时间值。
*   ObjectId，自动生成的_id由时间、计数器组成。
*   UUID，包含系统时间、时钟序列。
*   自增整数序列。

#### 1-2-3-2、哈希分片（hash sharding）

`哈希分片会先事先根据分片键计算出一个新的哈希值（64位整数），再根据哈希值按照范围分片的策略进行chunk的切分`。适用于日志，物联网等高并发场景。

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7b845d474fee4ac6a02513a49978ccf4~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

哈希分片与范围分片是互补的，`由于哈希算法保证了随机性，所以文档可以更加离散地分布到多个chunk上，这避免了集中写问题`。然而，`在执行一些范围查询时，哈希分片并不是高效的`。因为所有的范围查询都必然导致对所有chunk进行检索，如果集群有10个分片，那么mongos将需要对10个分片分发查询请求。哈希分片与范围分片的另一个区别是，`哈希分片只能选择单个字段，而范围分片允许采用组合式的多字段作为分片键。`

哈希分片仅支持单个字段的哈希分片：

```css
{ x : "hashed" } 
{x : 1 , y : "hashed"} // 4.4 new

```

4.4 以后的版本，可以将单个字段的哈希分片和一个到多个的范围分片键字段来进行组合，比如指定 x:1,y 是哈希的方式。

#### 1-2-3-3、分片标签

`MongoDB允许通过为分片添加标签（tag）的方式来控制数据分发`。一个标签可以关联到多个分片区间（TagRange）。均衡器会优先考虑chunk是否正处于某个分片区间上（被完全包含），如果是则会将chunk迁移到分片区间所关联的分片，否则按一般情况处理。

分片标签适用于一些特定的场景。例如，集群中可能同时存在OLTP和OLAP处理，一些系统日志的重要性相对较低，而且主要以少量的统计分析为主。为了便于单独扩展，我们可能希望将日志与实时类的业务数据分开，此时就可以使用标签。

##### 1-2-3-3-1、给分片添加标签

为了让分片拥有指定的标签，需执行addShardTag命令,通过如下指令就可以给shard1设置tag

```arduino
sh.addShardTag("shard1","oltp")

```

执行指令前使用`sh.status()`查看状态信息

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/593a1be7dc9147afa6b4454aee873b4b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

执行给分片添加标签之后，shard1分片就多了tag属性，如下：

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9c6bc08331b949168c6a1e241494d82d~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

##### 1-2-3-3-2、给集合设置分片标签

*   首先创建一个集合，并且给集合设置分片的能力

```css
use main
sh.enableSharding("main")

```

*   给集合设置分片hash的key

```css
sh.shardCollection("main.devices",{i:'hashed'})

```

*   设置集合属于oltp属性，声明TagRange

```css
# shardKey为分片键（后面进行详细说明）
# sh.addTagRange("main.devices",{shardKey:MinKey},{shardKey:MaxKey},"oltp")

sh.addTagRange("main.devices",{i:MinKey},{i:MaxKey},"oltp")

```

*   插入数据

```css
for (var i = 0; i < 10000; i++) { 
  db.devices.insert({i: i}); 
}

```

*   最后在查询数据存储分片结果

```scss
db.devices.getShardDistribution()

```

执行结果，可以看到数据都落到shard1上面了，我们就可以通过这种方式来设置让数据只落到某个分片上

![](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/b598f845128049cd9da313b041883ec5~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

#### 1-2-3-4、分片键（ShardKey）的选择

在选择分片键时，需要根据业务的需求及范围分片、哈希分片的不同特点进行权衡。一般来说，在设计分片键时需要考虑的因素包括：

*   `分片键的基数（cardinality），取值基数越大越有利于扩展。`
    *   以性别作为分片键 ：数据最多被拆分为 2 份
    *   以月份作为分片键 ：数据最多被拆分为 12 份
*   分片键的取值分布应该尽可能均匀。
*   `业务读写模式，尽可能分散写压力，而读操作尽可能来自一个或少量的分片。`
*   分片键应该能适应大部分的业务操作。

`分片键如果基数较小，这样会导致chunk的数据量过大的情况发生`；每个chunk存储到64MB,就会向下再拆分，拆分为两个32MB的chunk,当这两个32MB的chunk存储到64MB的时候就无法再进行拆分，只能当前chunk进行自己存储。 这样在写入或者后面迁移的时候就有受到影响。

#### 1-2-3-5、分片键（ShardKey）的约束

ShardKey 必须是一个索引。非空集合须在 ShardCollection 前创建索引；空集合 ShardCollection 自动创建索引

上面给`main.devices`中的`i`作为分片键（ShardKey）的时候，就会自动在devices中创建一个索引，如下：

![](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/2ba7e8fe7f5943e3a6e972c5f20a5434~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp?)

4.4 版本之前：

*   ShardKey 大小不能超过 512 Bytes；
*   仅支持单字段的哈希分片键；
*   Document 中必须包含 ShardKey；
*   ShardKey 包含的 Field 不可以修改。

4.4 版本之后:

*   ShardKey 大小无限制；
*   支持复合哈希分片键；
*   Document 中可以不包含 ShardKey，插入时被当 做 Null 处理；
*   为 ShardKey 添加后缀 refineCollectionShardKey 命令，可以修改 ShardKey 包含的 Field；

而在 4.2 版本之前，ShardKey 对应的值不可以修改；4.2 版本之后，如果 ShardKey 为非_ID 字段， 那么可以修改 ShardKey 对应的值。