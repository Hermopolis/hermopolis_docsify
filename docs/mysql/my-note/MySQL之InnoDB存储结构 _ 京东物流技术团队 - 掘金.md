1 InnoDB存储引擎
------------

InnoDB存储引擎最早由Innobase Oy公司开发（属第三方存储引擎）。从MySQL 5.5版本开始作为表的默认存储引擎。该存储引擎是第一个完整支持ACID事务的MySQL存储引擎，特点是行锁设计、支持MVCC、支持外键、提供一致性非锁定读，非常适合OLTP场景的应用使用。目前也是应用最广泛的存储引擎。

InnoDB存储引擎架构包含内存结构和磁盘结构两大部分，总体架构图如下：

8.0版本：

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7e82c63d8ed14fa88325dd42f8ec2c3d~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

5.5版本：

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/a29bf2ec1e9f49c3aa6ed7308c085ca8~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

2 InnoDB 存储结构
-------------

### 2.1 磁盘结构

#### 2.1.1 表空间 Tablespaces

InnoDB存储引擎的逻辑存储结构是将所有的数据都被逻辑地放在了一个空间中，这个空间中的文件就是实际存在的物理文件（.ibd文件），即表空间。默认情况下，一个数据库表占用一个表空间，表空间可以看做是InnoDB存储引擎逻辑结构的最高层，所以的数据都存放在表空间中，例如：表对应的数据、索引、insert buffer bitmap undo信息、insert buffer 索引页、double write buffer files 等都是放在共享表空间中的。

表空间分为系统表空间(ibdata1文件)(共享表空间)、临时表空间、常规表空间、Undo表空间和file-per-table表空间(独立表空间)。系统表空间又包括双写缓冲区(Doublewrite buffer)、Change Buffer等

1.系统表空间 System Tablespace

系统表空间可以对应文件系统上一个或多个实际的文件，默认情况下， InnoDB会在数据目录下创建一个名为.ibdata1，大小为 12M的文件，这个文件就是对应的系统表空间在文件系统上的表示。这个文件是可以自扩展的，当不够用的时候它会自己增加文件大小。需要注意的一点是，在一个MySQL服务器中，系统表空间只有一份。从MySQL5.5.7到MySQL5.6.6之间的各个版本中，我们表中的数据都会被默认存储到这个系统表空间。

```sql
show variables like '%innodb_data_file_path%'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/966ac15247154e1badd8eedbe5845b48~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

2.独立表空间

在MySQL5.6.6以及之后的版本中， InnoDB并不会默认的把各个表的数据存储到系统表空间中，而是为每一个表建立一个独立表空间，也就是说我们创建了多少个表，就有多少个独立表空间。使用独立表空间来存储表数据的话，会在该表所属数据库对应的子目录下创建一个表示该独立表空间的文件，文件名和表名相同，只不过添加了一个.ibd的扩展名而已。

```sql
show variables like '%innodb_file_per_table%'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/56b533cc9fcc4a0f9b334264054242d0~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

独立表空间只是存放数据、索引和插入缓冲Bitmap页，其他类的数据如回滚（undo）信息、插入缓冲索引页、系统事务信息、二次写缓冲等还是存放在原来的系统表空间。

3.其他类型的表空间

随着MySQL的发展，除了上述两种表空间之外，现在还新提出了一些不同类型的表空间，比如通用表空间 (general tablespace)、undo表空间(undo tablespace)、临时表空间(temporary tablespace)等

4.表空间结构

表空间又由段(segment)、区( extent)、页(page)组成，页是InnoDB磁盘管理的最小单位。在我们执行sql时，不论是查询还是修改，mysql 总会把数据从磁盘读取内内存中，而且在读取数据时，不会单独加在一条数据，而是直接加载数据所在的数据页到内存中。表空间本质上就是一个存放各种页的页面池。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/0d050fb9020e4a8db247cfdc8506fcf8~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

「页」是InnoDB管理存储空间的基本单位，也是内存和磁盘交互的基本单位。也就是说，哪怕你需要1字节的数据，InnoDB也会读取整个页的数据，InnoDB有很多类型的页，它们的用处也各不相同。比如：有存放undo日志的页、有存放INODE信息的页、有存放Change Buffer信息的页、存放用户记录数据的页（索引页）等等。

InnoDB默认的页大小是16KB，在初始化表空间之前可以在配置文件中进行配置，一旦数据库初始化完成就不可再变更了。

```sql
SHOW VARIABLES LIKE 'innodb_page_size'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/ac4c65aaf2b7457795f8d553f3a78774~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

#### 2.1.2 重写日志 redo log文件

redo log记录数据库的变更，数据库崩溃后，会从redo log获取事务信息，进行系统恢复。redo log在磁盘上表现为ib\_logfile0和ib\_logfile1两个文件。MySQL会在事务的提交前将redo日志刷新回磁盘。

在同一时间提交的事务，会采用组提交（group commit）的方式一次性刷新回磁盘。从而避免一个事务刷新一次磁盘，提高性能。

#### 2.1.3 Double Write Files 双写缓冲文件

double write 是保障 InnoDB 存储引擎操作数据页的可靠性。double write 分为两部分组成，一部分在内存中的 double write buffer, 大小为 2MB，另一部分是物理磁盘上共享表空间中连续的128个数据页，即2个区大小（同样是2MB）。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/900d6ae6ec3948c1b387fc2f5de04846~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

### 2.2 内存结构

InnoDB存储引擎是基于磁盘存储的，并将其中的记录按照页的方式进行管理，因此可将其视为基于磁盘的数据库系统（Disk-base Database）。在数据库中CPU速度与磁盘速度是有很大差距的，基于磁盘的数据库系统通常使用缓冲池技术来提高数据库的整体性能。结构如图所示：

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/266f011e1c4a48b3821cbe157f768fa6~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

#### 2.1.1 缓存池 Buffer Pool

Buffer Pool是InnoDB内存中的一块占比较大的区域，通过内存的速度来弥补磁盘速度慢对数据库性能的影响。在数据库中进行读取页的操作，首先将从磁盘读到的页放在缓冲池中，这个过程称为将页”FIX”在缓冲池中，下次再读到相同的页时，首先判断该页是否在缓冲池中，若在缓冲池中，直接读取该页，否则读取磁盘上的页。

对于数据库中的页的修改操作，首先修改在缓冲池中的页，然后再以一定频率刷新到磁盘上，这里需要注意的是，页从缓冲池刷新回磁盘的操作并不是在每次页发生更新时触发，而是通过一种称为Checkpoint的机制刷新回磁盘。

缓存区缓存的数据页类型有：索引页，数据页，undo页，插入缓冲（change buffer），自适应哈希索引（adaptive hash index），InnoDB存储锁信息（lock info），数据字典信息（data dictionary）。数据页和索引页占据了缓冲池很大部分。

InnoDB1.0.x版本开始，允许有多个缓冲池实例，每个页根据哈希值平均分配到不同缓冲池的实例中，这样可以减少数据库内部资源竞争，增加数据库的并发处理能力。

```sql
show variables like 'innodb_buffer_pool_instances'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/5bb6a58064ac4ada83a2f9cb2869bbcc~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

整个Buffer Pool的说明用一张图来概括如下：

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/cc5ed51f3f9e4f05b21b9c435d0fb40e~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

1.LRU List，Free List和Flush List——管理InnoDB内存区域

为了缓存管理的效率，缓冲池被实现为页链表，采用三个链表维护内存页，而内存页也因此对应 3 种状态： Free 尚未使用； Clean 已使用但未修改； Dirty（脏页）已修改；Free页只位于Free List，而Clean和Dirty页同时位于LRU List，Dirty页只存在于Flush List；

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fbea20e841664903b776922d3a496c17~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

1）LRU List：

数据库中的缓冲池是通过LRU（Latest Recent Used，最近最少使用）算法来进行管理的。即最频繁使用的页在LRU列表的前端，而最少使用的页在LRU列表的尾端。当缓冲池不能存放新读取到的页时，将首先释放LRU列表中尾端的页。

在InnoDB存储引擎中，缓冲池中页的大小默认为16KB，同样使用LRU算法对缓冲池进行管理。稍有不同的是InnoDB存储引擎对传统的LRU算法做了一些优化。在InnoDB的存储引擎中，LRU列表中还加入了midpoint位置。新读取到的页，虽然是最新访问的页，但并不是直接放入到LRU列表的首部，而是放入到LRU列表的midpoint位置。这个算法在InnoDB存储引擎下称为midpoint insertion strategy。在默认配置下，该位置在LRU列表长度的5/8处。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/5c06cafed1cc4621bf097667c05e305b~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

```sql
SHOW VARIABLES LIKE'innodb_old_blocks_pct'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fc257fb754824b8fa45159d0bf24df27~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

参数innodb\_old\_blocks_pct默认值为37，表示新读取的页插入到LRU列表尾端的37%的位置（差不多3/8的位置）。在InnoDB存储引擎中，把midpoint之后的列表称为old列表，之前的列表称为new列表。可以简单地理解为new列表中的页都是最为活跃的热点数据

*   那为什么不采用朴素的LRU算法，直接将读取的页放入到LRU列表的首部呢？

这是因为若直接将读取到的页放入到LRU的首部，那么某些SQL操作可能会使缓冲池中的页被刷新出，从而影响缓冲池的效率。常见的这类操作为索引或数据的扫描操作。这类操作需要访问表中的许多页，甚至是全部的页，而这些页通常来说又仅在这次查询操作中需要，并不是活跃的热点数据。如果页被放入LRU列表的首部，那么非常可能将所需要的热点数据页从LRU列表中移除，而在下一次需要读取该页时，InnoDB存储引擎需要再次访问磁盘。

*   解决热点数据被移除LRU列表

InnoDB存储引擎引入了另一个参数来进一步管理LRU列表，这个参数是innodb\_old\_blocks_time，用于表示页读取到mid位置后需要等待多久才会被加入到LRU列表的热端，通过这个方法尽可能使LRU列表中热点数据不被刷出。

```sql
SHOW VARIABLES LIKE'innodb_old_blocks_time'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/015578dcdbcb42e9b345b5aaee798cd5~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

当有新的数据从磁盘查询到内存时，会写入到 old sub list 的头部，当此数据再次被查询的时候，即在 old sublist 中命中之后，才会放入 new sublist 的头部。当页从LRU列表的old部分加入到new部分时，称此时发生的操作为page made young；如果因为innodb\_old\_blocks_time的设置导致页没有从old部分移动到new部分的操作，称为page not made young。  
通过命令SHOW ENGINE INNODB STATUS可以观察到如下内容：

```arduino
SHOW ENGINE INNODB STATUS

----------------------
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 137428992
Dictionary memory allocated 10620037
Buffer pool size   8191  
Free buffers       1025  
Database pages     6985  
Old database pages 2558  
Modified db pages  0     
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 4656751, not young 61021911  
0.00 youngs/s, 0.00 non-youngs/s   
Pages read 1036977, created 686192, written 21243071
0.00 reads/s, 0.00 creates/s, 0.28 writes/s

Buffer pool hit rate 1000 / 1000, young-making rate 0 / 1000 not 0 / 1000 
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 6985, unzip_LRU len: 0
I/O sum[17]:cur[0], unzip sum[0]:cur[0]

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/40d55cd96a2048bda2f08c1d0b1a40a6~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

*   页压缩功能

InnoDB存储引擎从1.0.x版本开始支持压缩页的功能，即将原本16KB的页压缩为1KB、2KB、4KB和8KB。而由于页的大小发生了变化，LRU列表也有了些许的改变。对于非16KB的页，是通过unzip\_LRU列表进行管理的，LRU中的页包含了unzip\_LRU列表中的页。

对于压缩页的表，每个表的压缩比率可能各不相同。可能存在有的表页大小为8KB，有的表页大小为2KB的情况。unzip_LRU是怎样从缓冲池中分配内存的呢？

首先，在unzip_LRU列表中对不同压缩页大小的页进行分别管理。其次，通过伙伴算法进行内存的分配。例如对需要从缓冲池中申请页为4KB的大小，其过程如下：

*   检查4KB的unzip_LRU列表，检查是否有可用的空闲页；
*   若有，则直接使用；
*   否则，检查8KB的unzip_LRU列表；
*   若能够得到空闲页，将页分成2个4KB页，存放到4KB的unzip_LRU列表；
*   若不能得到空闲页，从LRU列表中申请一个16KB的页，将页分为1个8KB的页、2个4KB的页，分别存放到对应的unzip_LRU列表中。

2）Free List：

free list 定义是当前没有被使用的内存页，也就是空闲的内存页，当执行查询操作时，如果页已经在 buffer pool 中了，则查询到直接返回，如果没有在 buffer pool，并且 free list 不为空，则会从磁盘中查询对应的数据，放入 free list 的某一页中，并且把这页从 free list 中移除，放入 LRU 队列中。Flush List中的脏页在执行了刷盘操作后会将空间还给Free List，通过这种方式可以解决空间碎片化

LRU列表用来管理已经读取的页，但当数据库刚启动时，LRU列表是空的，即没有任何的页。这时页都存放在Free列表中。当需要从缓冲池中分页时，首先从Free列表中查找是否有可用的空闲页，若有则将该页从Free列表中删除，放入到LRU列表中。否则，根据LRU算法，淘汰LRU列表末尾的页，将该内存空间分配给新的页。

从上面可以看出 【SHOW ENGINE INNODB STATUS】 :

*   Free buffers表示当前Free列表中页的数量，Database pages表示LRU列表中页的数量。可能的情况是Free buffers与Database pages的数量之和不等于Buffer pool size。因为缓冲池中的页还可能会被分配给自适应哈希索引、Lock信息、Change Buffer等页，而这部分页不需要LRU算法进行维护，因此不存在于LRU列表中。
*   pages made young显示了LRU列表中页移动到前端的次数，youngs/s、non-youngs/s表示每秒这两类操作的次数。
*   这里还有一个重要的观察变量——Buffer pool hit rate，表示缓冲池的命中率，通常该值不应该小于95%。若发生Buffer pool hit rate的值小于95%这种情况，用户需要观察是否是由于全表扫描引起的LRU列表被污染的问题。

3）Flush List：

在LRU列表中的页被修改后，称该页为脏页（dirty page），即缓冲池中的页和磁盘上的页的数据产生了不一致。这时数据库会通过CHECKPOINT机制将脏页刷新回磁盘，而Flush列表中的页即为脏页列表。需要注意的是，脏页既存在于LRU列表中，也存在于Flush列表中。LRU列表用来管理缓冲池中页的可用性，Flush列表用来管理将页刷新回磁盘，二者互不影响。

Flush List中的脏页在执行了刷盘操作后会将空间还给Free List。

同LRU列表一样，Flush列表也可以通过命令SHOW ENGINE INNODB STATUS来查看，前面例子中Modified db pages 就显示了脏页的数量。

2.Checkpoint技术

数据库在发生增删查改操作的时候，都是先在buffer pool中完成的，为了提高事物操作的效率，buffer pool中修改之后的数据，并没有立即写入到磁盘，这有可能会导致内存中数据与磁盘中的数据产生不一致的情况。

倘若每次一个页的变化，就将新页的版本刷新到磁盘，那么这个开销是非常大的，若热点数据集中在某几个页中，那么数据库的性能就会变得非常差。同时，如果在从缓冲池将页的的新版本刷新到磁盘时发生了宕机，那么数据就不能恢复了，为了避免这种情况，当前事务数据库系统普遍都采用了Write Ahead Log策略，即当事务提交时，先写重做日志，再修改页，当由于发生宕机而导致数据丢失时，可以通过重做日志来完成数据的恢复。这也是事务ACID中D（Durability持久性）的要求。

checkpoint的作用：

*   缩短数据库的恢复时间
*   缓冲池不够用时，将脏页刷新到磁盘
*   重做日志不可用时，刷新脏页  
    checkpoint的分类
*   sharp checkpoint：在关闭数据库的时候，将buffer pool中的脏页全部刷新到磁盘中。
*   fuzzy checkpoint：数据库正常运行时，在不同的时机，将部分脏页写入磁盘，进刷新部分脏页到磁盘，也是为了避免一次刷新全部的脏页造成的性能问题。

#### 2.2.2 写缓冲 Change Buffer

在MySQL5.5之前，叫插入缓冲（Insert Buffer），只针对INSERT做了优化；现在对DELETE和UPDATE也有效，叫做写缓冲（Change Buffer）。它是一种应用在非唯一普通索引页（non-unique secondary index page）不在缓冲池中，对页进行了写操作，并不会立刻将磁盘页加载到缓冲池，而仅仅记录缓冲变更（Buffer Changes），等未来数据被读取时，再将数据合并（Merge）恢复到缓冲池中的技术。写缓冲的目的是降低写操作的磁盘IO，提升数据库性能。

数据的修改分为两个情况：

1.当修改的数据页在缓冲池时

上文讲过，通过LRU、Flush List的管理，数据库不是直接写入磁盘中，是先将redo log写入到磁盘，再通过checkpoint机制，将这些“脏数据页”同步地写入磁盘，等于是将这期间发生的n次的落盘合并成了一次落盘。因为有redo log是落盘的，所以即使数据库崩溃，缓存中的数据页全部丢失，也可以通过redo log将这些数据页找回来。

redo log是数据库用来在崩溃的时候进行数据恢复的日志，redo log的写入策略可以通过参数控制，并不一定是每一次写操作之后立即落盘redo log，在部分参数下，redo log可能是每秒集中写入一次，也有可能采取其他落盘策略，但是无论采用什么方式，redo log的量都是不会减少的，与数据写入的覆盖性不同，后一条redo log是不会覆盖前一条的，而是增量形式的，因此写redo log的操作，等同于是对磁盘某一小块区域的顺序I/O，而不像数据落盘一样的随机IO在磁盘里写入，需要磁盘在多个地方移动磁头。所以redo log的落盘是IO操作当中消耗较少的一种，比数据直接刷回磁盘要优很多。

2.当修改的数据页不在缓冲池时，不用写缓冲至少需要下面的三步：

*   先把需要的索引页，从磁盘加载到缓冲池，一次磁盘随机读操作；
*   修改缓冲池中的页，一次内存操作；
*   写入 redo log ，一次磁盘顺序写操作；

在没有命中缓冲池的时候，至少多产生一次磁盘IO，对于写多读少的业务场景，性能损耗是很高的

加入写缓冲优化后，流程优化为：

*   在写缓冲中记录这个操作，一次内存操作；
*   写入redo log，一次磁盘顺序写操作；

其性能与这个索引页在缓冲池中，相近。

3.如何保证数据的一致性？

*   数据库异常奔溃，能够从redo log中恢复数据；
*   写缓冲不只是一个内存结构，它也会被定期刷盘到写缓冲系统表空间；
*   数据读取时，有另外的流程，将数据合并到缓冲池；

下一次读到该索引页：

*   载入索引页，缓冲池未命中，这次磁盘IO不可避免；
*   从写缓冲读取相关信息；
*   恢复索引页，放到缓冲池LRU和Flush里；（在真正被读取时，才会被加载到缓冲池中）

4.为什么写缓冲优化，仅适用于非唯一普通索引页呢？

InnoDB里有聚集索引（Clustered Index）)和普通索引(Secondary Index)两种。如果索引设置了唯一（Unique）属性，在 进行修改操作 时， InnoDB必须进行唯一性检查 。也就是说， 索引页即使不在缓冲池，磁盘上的页读取无法避免（否则怎么校验是否唯一！？）

此时就应该直接把相应的页放入缓冲池再进行修改。

5.除了数据页被访问，还有哪些场景会触发刷写缓冲中的数据呢？

*   有一个后台线程，会认为数据库空闲时；
*   数据库缓冲池不够用时；
*   数据库正常关闭时；
*   redo log写满时；（几乎不会出现redo log写满，此时整个数据库处于无法写入的不可用状态）

6.什么业务场景，适合开启InnoDB的写缓冲机制？

*   数据库大部分是非唯一索引；
*   业务是写多读少，或者不是写后立刻读取；

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/44ba2c2195d147ceb29adf8da0372b3a~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

```sql
SHOW VARIABLES LIKE 'innodb_change_buffer_max_size'

```

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/92a07ad81d62444aa84fcbd498191702~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

#### 2.2.3 自适应散列索引 Adaptive Hash Index

自适应哈希索引用于优化对BP数据的查询。InnoDB存储引擎会监控对二级索引数据的查找，如果观察到建立哈希索引可以带来速度的提升(最近连续被访问三次的数据)，则建立哈希索引，自适应哈希索引通过缓冲池的B+树构造而来，因此建立的速度很快。InnoDB存储引擎会自动根据访问的频率和模式来为某些页建立哈希索引。（在高负载系统下AHI容易产生资源的争用，进而引起一些bug导致系统受影响甚至崩溃，故建议关闭该功能）

#### 2.2.4 重做日志缓冲区 rodo Log Buffer

重做日志缓冲区，当在MySQL中对InnoDB表进行数据更改时，这些更改首先存储在InnoDB日志缓冲区的内存中，然后再写入重做日志（redo logs）的InnoDB日志磁盘文件中。他让MySQL在崩溃的时候具有了恢复数据的能力，即在数据库发生意外的时候，可以进行数据恢复；

日志缓冲区log buffer是内存存储区域，用于保存要写入磁盘上的日志文件的数据。日志缓冲区大小由innodb\_log\_buffer_size 变量定义，默认大小为16MB。

日志缓冲区的内容定期刷新到磁盘。较大的日志缓冲区可以运行大型事务，而无需在事务提交之前将重做日志数据写入磁盘。因此，如果有更新，插入或删除许多行的事务，则增加日志缓冲区的大小可以节省磁盘I/O。

这里还涉及到一个参数 innodb\_flush\_log\_at\_trx_commit ：控制如何将日志缓冲区的内容写入并刷新到磁盘,默认为1，不建议修改

1.  参数为0时，表示事务commit不立即把 redo log buffer 里的数据刷入磁盘文件的，而是依靠 InnoDB 的主线程每秒（此时间由参数innodb\_flush\_log\_at\_timeout控制，默认1s）执行一次刷新到磁盘。此时可能你提交事务了，结果 mysql 宕机了，然后此时内存里的数据全部丢失。
2.  参数为1时，表示事务commit后立即把 redo log buffer 里的数据写入到os buffer中，并立即执行fsync()操作
3.  参数为2时，表示事务commit后立即把 redo log buffer 里的数据写入到os buffer中，但不立即fsync()SQL执行过程

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/59c61d02947a43c493ce29f6024a456a~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

**什么是binlog**

binlog是一个二进制格式的文件，用于记录用户对数据库更新的SQL语句信息，默认情况下，binlog是二进制格式的，不能使用文本工具的命令进行查看，而是使用mysqlbinlog解析查看。

**binlog的功能**

当数据写入到数据库的时候，会同时把更新的SQL语句写入到相应的binlog文件里面，同时在使用mysqldump进行备份的时候，只是对一段时间的数据进行了全局备份，但是如果备份后发现数据库服务器产生故障，这个时候就要用到binlog日志了。

**binlog和redolog的区别：** 

1.  redo log是在InnoDB存储引擎层产生，而binlog是mysql数据库的上层产生，而且binlog是二进制格式的日志，不仅仅针对InnoDB存储引擎。
2.  两种日志记录的内容形式不同，MySQL的binlog是逻辑日志，而InnoDB存储引擎层面的重做日志是物理日志。
3.  两种日志与记录写入磁盘的时间点不同，二进制日志只在事物提交完成后进行一次写入，而redo log的重做日志在事物的进行过程中不断地被写入。
4.  binlog不是循环使用，在写满或者重启之后，会生成新的binlog文件，但是redo log是循环使用的。

3 InnoDB 存储特性
-------------

1.  写缓冲 Change Buffer
2.  两次写 Double Write

InnoDB在把Dirty 脏页写回到表空间之前，在内存中会线拷贝到连续的内存空间double write buffer缓冲区，然后再把它们写到一个叫doublewrite buffer file的连续磁盘存储区域内，在写doublewrite buffer file完成后，InnoDB才会把Dirty pages写到data file的适当的位置。如果在写page的过程中发生意外崩溃，InnoDB在稍后的恢复过程中在doublewrite buffer file中找到完好的page副本用于恢复。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/bf24a1e2aa2f49fe981fc90e1ca849d6~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

**为什么需要双写？**

InnoDB 的Page Size一般是16KB，其数据校验也是针对这16KB来计算的，将数据写入到磁盘是以Page为单位进行操作的。而计算机硬件和操作系统，写文件是以4KB（512字节）作为单位的，不能保证MySQL数据页面16KB的一次性原子写。试想，在某个Dirty Page flush的过程中，发生了系统断电（或者OS崩溃），16K的数据只有部分被写到磁盘上，只有一部分写是成功的，这种现象被称为partial page writes。在出现磁盘崩溃的时候，InnoDB 引擎会从共享表空间中的doublewrite找到该页的一个副本，将其复制到表空间文件，再应用重做日志，保障 InnoDB 存储引擎操作数据页的可靠性。

**为什么不能使用redo log 解决partial page writes？**

一旦partial page writes发生，那么在InnoDB恢复时就很尴尬：redo log的页大小一般设计为512个字节，因此redo log page本身不会发生break page。用redo log来解决partial write 理论上是可行的，不过innodb的redo log是物理逻辑日志，并不是纯物理日志，因此发生partial write后崩溃恢复过程中不能直接应用redo log ，innodb发现break page后实际上会报错。物理逻辑日志不是完全幂等的，这取决于重做日志类型，对于INSERT产生的日志其不是幂等的。  
**  
两次写的工作流程**

double write由两部分组成，一部分是InnoDB内存中的double write buffer，大小为2MB，另一部分是物理磁盘上的ibdata，系统表空间中大小为2MB，共128个连续的Page（2*1024/16KB=128），即两个分区（extend）一个段（segment）。其中120个页用于批量刷新脏页（如LRU LIST刷新与FLUSH LIST刷新这两种刷新策略），另外8个页用于单页刷新（Single Page Flush）。做区分的原因是批量刷脏是后台线程做的，不影响前台线程。而单页刷新是用户线程发起的，需要尽快的刷脏页并替换出一个空闲页出来。

InnoDB刷新（写出）缓冲区中的数据页时采用的是一次写多个页的方式：

*   多个页就可以先顺序写入到double write buffer，并调用fsync()保证这些数据被刷新到double write磁盘（ibdata）。
*   然后数据页调用fsync()被刷新到实际存储位置；
*   故障恢复时InnoDB检查double write Buffer与数据页原存储位置的内容，若double write页处于页断裂状态，则简单的丢弃；若数据页不一致，则从double write页还原。

![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6b963a7219cd431dad86a484cd064bd1~tplv-k3u1fbpfcp-zoom-in-crop-mark:1512:0:0:0.awebp)
[](https://link.juejin.cn/?target=)

由于double write页落盘与数据页落盘在不同的时间点，不会出现double write页和数据页同时发生断裂的情况，因此doublewrite技术可以解决页断裂问题，进而保证了重做日志能顺利进行，数据库能恢复到一致的状态。

**3.自适应哈希索引 Adaptive Hash Index**

4 参考资料
------

掘金小册《MySQL 是怎样运行的：从根儿上理解 MySQL》学习笔记[www.jianshu.com/p/3394321c1…](https://link.juejin.cn/?target=https%3A%2F%2Fwww.jianshu.com%2Fp%2F3394321c11bf "https://www.jianshu.com/p/3394321c11bf")

> 作者：京东物流 邓钧蔚
> 
> 来源：京东云开发者社区 自猿其说Tech