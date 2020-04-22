# 基于Docker快速部署Mycat实现分表分库、读写分离、Mysql主从复制

[toc]



## 说明

- 使用一个t_test表做分片示意,分片规则使用mod-long
- 使用一个t_task_test表做分片示意,分片规则使用sharding-by-murmur-orgcode
- 采用mycat + mysql +docker+ docker-compose
- Mycat分表分库
- Mycat读写分离
- Mysql主从复制


- **Mysql**:

  ​	userName:root

  ​	password:password

- **Mycat**:

  - 读写帐户:

    ​		userName:root

    ​		password:password

  - 只读帐户:

    ​		userName:guest

    ​		password:guest

- **项目下载地址**:

  https://github.com/baojingyu/docker-mycat-mysql.git

---

## 引言

> 系统开发中，数据库是非常重要的一个点。除了程序的本身的优化，如：SQL语句优化、代码优化，数据库的处理本身优化也是非常重要的。主从、热备、分表分库等都是系统发展迟早会遇到的技术问题问题。Mycat是一个广受好评的数据库中间件，已经在很多产品上进行使用了。希望通过这篇文章的介绍，能学会Mycat的使用。

我们现在做一个主从、读写分离，简单分表的示例。结构如下图：

| 服务器 |     IP     | 说明                                    |
| :----: | :--------: | --------------------------------------- |
| Mycat  | 192.18.0.8 | mycat服务器，连接数据库时，连接此服务器 |
|   M1   | 192.18.0.2 | Mysql主 1，真正存储数据的数据库         |
|   S1   | 192.18.0.3 | Mysql主 1 的 Slave[从库]                |
|   S2   | 192.18.0.4 | Mysql主 1 的 Slave[从库]                |
|   M2   | 192.18.0.5 | Mysql主 2，真正存储数据的数据库         |
|   S3   | 192.18.0.6 | Mysql主 2 的 Slave[从库]                |
|   S4   | 192.18.0.7 | Mysql主 2的 Slave[从库]                 |

Mycat作为主数据库中间件，肯定是与代码弱关联的，所以代码是不用修改的，使用Mycat后，连接数据库是不变的，默认端口是8066。连接方式和普通数据库一样，如：jdbc:mysql://192.168.0.8:8066/



## 开始

### 拉取docker-mycat 工程

```git
git clone https://github.com/baojingyu/docker-mycat-mysql.git
```



###  修改Mycat的配置文件

Mycat的配置文件都在conf目录里面，这里介绍几个常用的文件：

/docker-mycat-mysql/mycat/conf/

| 文件       | 说明                                  |
| ---------- | ------------------------------------- |
| rule.xml   | Mycat分片（分库分表）规则             |
| schema.xml | Mycat对应的物理数据库和数据库表的配置 |
| server.xml | Mycat的配置文件，设置账号、参数等     |

**rule.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- - - Licensed under the Apache License, Version 2.0 (the "License"); 
	- you may not use this file except in compliance with the License. - You 
	may obtain a copy of the License at - - http://www.apache.org/licenses/LICENSE-2.0 
	- - Unless required by applicable law or agreed to in writing, software - 
	distributed under the License is distributed on an "AS IS" BASIS, - WITHOUT 
	WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. - See the 
	License for the specific language governing permissions and - limitations 
	under the License. -->
<!DOCTYPE mycat:rule SYSTEM "rule.dtd">
<mycat:rule xmlns:mycat="http://io.mycat/">
	<tableRule name="rule1">
		<rule>
			<columns>id</columns>
			<algorithm>func1</algorithm>
		</rule>
	</tableRule>

	<tableRule name="rule2">
		<rule>
			<columns>user_id</columns>
			<algorithm>func1</algorithm>
		</rule>
	</tableRule>

	<tableRule name="sharding-by-intfile">
		<rule>
			<columns>sharding_id</columns>
			<algorithm>hash-int</algorithm>
		</rule>
	</tableRule>
	<tableRule name="auto-sharding-long">
		<rule>
			<columns>id</columns>
			<algorithm>rang-long</algorithm>
		</rule>
	</tableRule>
	<tableRule name="mod-long">
		<rule>
			<columns>id</columns>
			<algorithm>mod-long</algorithm>
		</rule>
	</tableRule>
	<tableRule name="sharding-by-murmur">
		<rule>
			<columns>id</columns>
			<algorithm>murmur</algorithm>
		</rule>
	</tableRule>
	<tableRule name="crc32slot">
		<rule>
			<columns>id</columns>
			<algorithm>crc32slot</algorithm>
		</rule>
	</tableRule>
	<tableRule name="sharding-by-month">
		<rule>
			<columns>create_time</columns>
			<algorithm>partbymonth</algorithm>
		</rule>
	</tableRule>
	<tableRule name="latest-month-calldate">
		<rule>
			<columns>calldate</columns>
			<algorithm>latestMonth</algorithm>
		</rule>
	</tableRule>
	
	<tableRule name="auto-sharding-rang-mod">
		<rule>
			<columns>id</columns>
			<algorithm>rang-mod</algorithm>
		</rule>
	</tableRule>
	
	<tableRule name="jch">
		<rule>
			<columns>id</columns>
			<algorithm>jump-consistent-hash</algorithm>
		</rule>
	</tableRule>
	<!--根据列orgCode进行一致性hash规则分片-->
	<tableRule name="sharding-by-murmur-orgcode">
		<rule>
			<columns>org_code</columns>
			<algorithm>murmur</algorithm>
		</rule>
	</tableRule>

	<function name="murmur"
		class="io.mycat.route.function.PartitionByMurmurHash">
		<property name="seed">0</property><!-- 默认是0 -->
		<property name="count">2</property><!-- 要分片的数据库节点数量，必须指定，否则没法分片 -->
		<property name="virtualBucketTimes">160</property><!-- 一个实际的数据库节点被映射为这么多虚拟节点，默认是160倍，也就是虚拟节点数是物理节点数的160倍 -->
		<!-- <property name="weightMapFile">weightMapFile</property> 节点的权重，没有指定权重的节点默认是1。以properties文件的格式填写，以从0开始到count-1的整数值也就是节点索引为key，以节点权重值为值。所有权重值必须是正整数，否则以1代替 -->
		<!-- <property name="bucketMapPath">/etc/mycat/bucketMapPath</property> 
			用于测试时观察各物理节点与虚拟节点的分布情况，如果指定了这个属性，会把虚拟节点的murmur hash值与物理节点的映射按行输出到这个文件，没有默认值，如果不指定，就不会输出任何东西 -->
	</function>

	<function name="crc32slot"
			  class="io.mycat.route.function.PartitionByCRC32PreSlot">
		<property name="count">2</property><!-- 要分片的数据库节点数量，必须指定，否则没法分片 -->
	</function>
	<function name="hash-int"
		class="io.mycat.route.function.PartitionByFileMap">
		<property name="mapFile">partition-hash-int.txt</property>
	</function>
	<function name="rang-long"
		class="io.mycat.route.function.AutoPartitionByLong">
		<property name="mapFile">autopartition-long.txt</property>
	</function>
	<function name="mod-long" class="io.mycat.route.function.PartitionByMod">
		<!-- how many data nodes -->
		<property name="count">2</property><!--count值为数据库的节点数-->
	</function>

	<function name="func1" class="io.mycat.route.function.PartitionByLong">
		<property name="partitionCount">8</property>
		<property name="partitionLength">128</property>
	</function>
	<function name="latestMonth"
		class="io.mycat.route.function.LatestMonthPartion">
		<property name="splitOneDay">24</property>
	</function>
	<function name="partbymonth"
		class="io.mycat.route.function.PartitionByMonth">
		<property name="dateFormat">yyyy-MM-dd</property>
		<property name="sBeginDate">2015-01-01</property>
	</function>
	
	<function name="rang-mod" class="io.mycat.route.function.PartitionByRangeMod">
        	<property name="mapFile">partition-range-mod.txt</property>
	</function>
	
	<function name="jump-consistent-hash" class="io.mycat.route.function.PartitionByJumpConsistentHash">
		<property name="totalBuckets">3</property>
	</function>
</mycat:rule>

```

**schema.xml**分表分库、读写分离配置

```xml
<?xml version="1.0"?>
<!DOCTYPE mycat:schema SYSTEM "schema.dtd">
<mycat:schema xmlns:mycat="http://io.mycat/">

    <!-- 定义MyCat的逻辑库 -->
    <!-- 设置表的存储方式. schema name="test_db" 与 server.xml中的test_db 设置一致 -->
    <!-- schema数据库配置
    name,逻辑数据库名，与server.xml中的schema对应。
    checkSQLschema,数据库前缀相关设置，建议看文档，这里暂时设为folse。
    sqlMaxLimit,select 时默认的limit，避免查询全表。-->
    <schema name="test_db" checkSQLschema="false" sqlMaxLimit="100">
        <!--t_test表根据 id 进行十进制求模运算-->
        <table name="t_test" primaryKey="id" autoIncrement="true" dataNode="dn1,dn2" rule="mod-long"></table>
        <!--t_task_test表根据org_code列,进行一致性hash规则分片-->
        <table name="t_task_test" dataNode="dn1,dn2" rule="sharding-by-murmur-orgcode"></table>
    </schema>

    <!-- 定义MyCat的数据节点(分片) -->
    <!-- 设置dataNode 对应的数据库,及 mycat 连接的地址dataHost -->
    <dataNode name="dn1" dataHost="dh1" database="test_db"/>
    <dataNode name="dn2" dataHost="dh2" database="test_db"/>


    <!-- mycat 逻辑主机dataHost对应的物理主机.其中也设置对应的mysql登陆信息 -->
    <!-- 定义数据主机dtHost，连接到MySQL读写分离集群 ,schema中的每一个dataHost中的host属性值必须唯一-->
    <!-- dataHost实际上配置就是后台的数据库集群，一个datahost代表一个数据库集群
    name唯一标识 dataHost 标签，供dataNode标签使用。
    maxCon指定每个读写实例连接池的最大连接。也就是说，标签内嵌套的 writeHost、readHost 标签都会使用这个属性的值来实例化出连接池的最大连接数。
    minCon指定每个读写实例连接池的最小连接，初始化连接池的大小。 -->

    <!--读取负载均衡类型
    balance="0", 不开启读写分离机制，所有读操作都发送到当前可用的 writeHost 上。
    balance="1",全部的 readHost 与 stand by writeHost 参与 select 语句的负载均衡，简单的说，当双主双从模式(M1->S1，M2->S2，并且 M1 与 M2 互为主备)，正常情况下，M2,S1,S2 都参与 select 语句的负载均衡。
    balance="2",所有读操作都随机的在 writeHost、readhost 上分发。
    balance="3",所有读请求随机的分发到 wiriterHost 对应的 readhost 执行，writerHost 不负担读压力-->

    <!--写入负载均衡类型
    writeType="0",所有写操作发送到配置的第一个writeHost，这里就是我们的hostmaster，第一个挂了切到还生存的第二个writeHost
    writeType="1",所有写操作都随机的发送到配置的 writeHost
    writeType="2",没实现。-->

    <!--switchType 属性
    switchType="-1",表示不自动切换。
    switchType="1",默认值，自动切换。
    switchType="2",基于MySQL 主从同步的状态决定是否切换。-->

    <dataHost name="dh1" maxCon="1000" minCon="10" balance="1"
              writeType="0" dbType="mysql" dbDriver="native" switchType="1" slaveThreshold="100">
        <!--心跳检测 -->
        <heartbeat>select user()</heartbeat>
        <!--配置后台数据库的IP地址和端口号，还有账号密码 -->
        <writeHost host="m1" url="192.18.0.2:3306" user="root" password="password">
            <readHost host="s1" url="192.18.0.3:3306" user="root" password="password" />
            <readHost host="s2" url="192.18.0.4:3306" user="root" password="password" />
        </writeHost>
    </dataHost>

    <dataHost name="dh2" maxCon="1000" minCon="10" balance="1"
              writeType="0" dbType="mysql" dbDriver="native" switchType="1" slaveThreshold="100">
        <heartbeat>select user()</heartbeat>
        <writeHost host="m2" url="192.18.0.5:3306" user="root" password="password">
            <readHost host="s3" url="192.18.0.6:3306" user="root" password="password" />
            <readHost host="s4" url="192.18.0.7:3306" user="root" password="password" />
        </writeHost>
    </dataHost>

</mycat:schema>
```

**server.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- - - Licensed under the Apache License, Version 2.0 (the "License");
    - you may not use this file except in compliance with the License. - You
    may obtain a copy of the License at - - http://www.apache.org/licenses/LICENSE-2.0
    - - Unless required by applicable law or agreed to in writing, software -
    distributed under the License is distributed on an "AS IS" BASIS, - WITHOUT
    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. - See the
    License for the specific language governing permissions and - limitations
    under the License. -->
<!DOCTYPE mycat:server SYSTEM "server.dtd">
<mycat:server xmlns:mycat="http://io.mycat/">
    <system>
    <property name="useSqlStat">0</property>  <!-- 1为开启实时统计、0为关闭 -->
    <property name="useGlobleTableCheck">0</property>  <!-- 1为开启全加班一致性检测、0为关闭 -->

        <property name="sequnceHandlerType">2</property>
      <!--  <property name="useCompression">1</property>--> <!--1为开启mysql压缩协议-->
        <!--  <property name="fakeMySQLVersion">5.6.20</property>--> <!--设置模拟的MySQL版本号-->
    <!-- <property name="processorBufferChunk">40960</property> -->
    <!--
    <property name="processors">1</property>
    <property name="processorExecutor">32</property>
     -->
        <!--默认为type 0: DirectByteBufferPool | type 1 ByteBufferArena-->
        <property name="processorBufferPoolType">0</property>
        <!--默认是65535 64K 用于sql解析时最大文本长度 -->
        <!--<property name="maxStringLiteralLength">65535</property>-->
        <!--<property name="sequnceHandlerType">0</property>-->
        <!--<property name="backSocketNoDelay">1</property>-->
        <!--<property name="frontSocketNoDelay">1</property>-->
        <!--<property name="processorExecutor">16</property>-->
        <!--
            <property name="serverPort">8066</property> <property name="managerPort">9066</property>
            <property name="idleTimeout">300000</property> <property name="bindIp">0.0.0.0</property>
            <property name="frontWriteQueueSize">4096</property> <property name="processors">32</property> -->
        <!--分布式事务开关，0为不过滤分布式事务，1为过滤分布式事务（如果分布式事务内只涉及全局表，则不过滤），2为不过滤分布式事务,但是记录分布式事务日志-->
        <property name="handleDistributedTransactions">0</property>

            <!--
            off heap for merge/order/group/limit      1开启   0关闭
        -->
        <property name="useOffHeapForMerge">1</property>

        <!--
            单位为m
        -->
        <property name="memoryPageSize">1m</property>

        <!--
            单位为k
        -->
        <property name="spillsFileBufferSize">1k</property>

        <property name="useStreamOutput">0</property>

        <!--
            单位为m
        -->
        <property name="systemReserveMemorySize">384m</property>


        <!--是否采用zookeeper协调切换  -->
        <property name="useZKSwitch">true</property>


    </system>

    <!-- 全局SQL防火墙设置
    <firewall>
       <whitehost>
          <host host="192.18.0.2" user="root"/>
          <host host="192.18.0.3" user="root"/>
          <host host="192.18.0.4" user="root"/>
       </whitehost>
       <blacklist check="false">
       </blacklist>
    </firewall>-->

    <user name="root">
        <property name="password">password</property>
        <property name="schemas">test_db</property>

        <!-- 表级 DML 权限设置 -->
        <!--
        <privileges check="false">
            <schema name="TESTDB" dml="0110" >
                <table name="tb01" dml="0000"></table>
                <table name="tb02" dml="1111"></table>
            </schema>
        </privileges>
         -->
    </user>
    <!--只读帐户-->
    <user name="guest">
        <property name="password">guest</property>
        <property name="schemas">test_db</property>
        <property name="readOnly">true</property>
    </user>

</mycat:server>
```



### 构建并启动容器

```shell
[root@localhost docker-mycat-mysql]# docker-compose up -d
Creating network "mysql_mycat_mysql" with driver "bridge"
Creating m1 ... done
Creating m2 ... done
Creating s1 ... done
Creating s2 ... done
Creating s3 ... done
Creating s4 ... done
Creating mycat ... done
```

### 显示所有容器

```shell
[root@localhost docker-mycat-mysql]# docker-compose ps
Name              Command             State                       Ports                     
--------------------------------------------------------------------------------------------
m1      docker-entrypoint.sh mysqld   Up      0.0.0.0:3307->3306/tcp, 33060/tcp             
m2      docker-entrypoint.sh mysqld   Up      0.0.0.0:3310->3306/tcp, 33060/tcp             
mycat   ./mycat console               Up      0.0.0.0:8066->8066/tcp, 0.0.0.0:9066->9066/tcp
s1      docker-entrypoint.sh mysqld   Up      0.0.0.0:3308->3306/tcp, 33060/tcp             
s2      docker-entrypoint.sh mysqld   Up      0.0.0.0:3309->3306/tcp, 33060/tcp             
s3      docker-entrypoint.sh mysqld   Up      0.0.0.0:3311->3306/tcp, 33060/tcp             
s4      docker-entrypoint.sh mysqld   Up      0.0.0.0:3312->3306/tcp, 33060/tcp             
```

### Mysql 主从复制设置

#### 配置 M1、M2 为 Master 主

通过`docker exec -it m1 /bin/bash`命令进入。

修改 my.cnf 文件。

- **m1**

  ```
  [mysqld]
  ## 同一局域网内注意要唯一
  server-id=1
  sync_binlog=1
  ## 开启二进制日志功能，可以随便取（关键）
  log-bin=mysql-bin
  ```

- **m2**

  ```
  [mysqld]
  ## 同一局域网内注意要唯一
  server-id=4
  sync_binlog=1
  ## 开启二进制日志功能，可以随便取（关键）
  log-bin=mysql-bin
  ```

配置完成之后，需要重启mysql服务使配置生效。使用`service mysql restart`完成重启。

下一步在Master数据库,`m1、m2`创建数据同步用户，授予用户 `gokuit` REPLICATION SLAVE权限和REPLICATION CLIENT权限，用于在主从库之间同步数据。

> create user gokuit;
> grant REPLICATION SLAVE on *.* to 'gokuit'@'192.18.0.%' IDENTIFIED by 'gokuit';
> flush privileges;

#### 配置 S1、S2 、S3、S4为 Slave从

和配置Master(主)一样，在Slave配置文件my.cnf中添加如下配置：

- **S1**

  ```
  [mysqld]
  ## 设置server_id,注意要唯一
  server-id=2
  log-bin=mysql-bin
  ```

- **S2**

  ```
  [mysqld]
  ## 设置server_id,注意要唯一
  server-id=3
  log-bin=mysql-bin
  ```

- **S3**

  ```
  [mysqld]
  ## 设置server_id,注意要唯一
  server-id=5
  log-bin=mysql-bin
  
  ```

- **S4**

  ```
  [mysqld]
  ## 设置server_id,注意要唯一
  server-id=6
  log-bin=mysql-bin
  ```

配置完成之后，需要重启mysql服务使配置生效。使用`service mysql restart`完成重启。



#### 链接Master(主)和Slave(从)

- **m1**进入 Mysql，执行`show master status;`

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec m1 bash
  root@169ab7da713e:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 3
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> show master status;
  +------------------+----------+--------------+------------------+-------------------+
  | File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
  +------------------+----------+--------------+------------------+-------------------+
  | mysql-bin.000010 |      154 |              |                  |                   |
  +------------------+----------+--------------+------------------+-------------------+
  1 row in set (0.00 sec)
  
  mysql> exit
  ```

  

- **m2**进入 Mysql，执行`show master status;`

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec m2 bash
  root@3eb2efc9df37:/# mysql -u root -p 
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 11
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> show master status;
  +------------------+----------+--------------+------------------+-------------------+
  | File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
  +------------------+----------+--------------+------------------+-------------------+
  | mysql-bin.000003 |      154 |              |                  |                   |
  +------------------+----------+--------------+------------------+-------------------+
  1 row in set (0.00 sec)
  
  mysql> exit
  ```

`File`和`Position`字段的值后面将会用到，在后面的操作完成之前，需要保证Master库不能做任何操作，否则将会引起状态变化，File和Position字段的值变化。



#### 链接Slave(从)

S1、s2、S3、S4 分别执行主从同步命令

> change master to master_host='192.18.0.2', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;

**命令说明：**

**master_host** ：Master的地址，指的是容器的独立ip,可以通过`docker inspect --format='{{.NetworkSettings.IPAddress}}' 容器名称|容器id`查询容器的ip

**master_port**：Master的端口号，指的是容器的端口号

**master_user**：用于数据同步的用户

**master_password**：用于同步的用户的密码

**master_log_file**：指定 Slave 从哪个日志文件开始复制数据，即上文中提到的 File 字段的值

**master_log_pos**：从哪个 Position 开始读，即上文中提到的 Position 字段的值

**master_connect_retry**：如果连接失败，重试的时间间隔，单位是秒，默认是60秒



![image-20200422001058103](https://cdn.jsdelivr.net/gh/baojingyu/ImageHosting@master/uPic/20200422001058image-20200422001058103.png)

SlaveIORunning 和 SlaveSQLRunning 都是Yes，说明主从复制已经开启。此时可以测试数据同步是否成功。



- **s1**进入 Mysql ，执行主从同步命令

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec s1 bash
  root@3882671bea53:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 27
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> change master to master_host='192.18.0.2', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;
  Query OK, 0 rows affected, 2 warnings (0.01 sec)
  
  mysql> show slave status \G;
  *************************** 1. row ***************************
                 Slave_IO_State: 
                    Master_Host: 192.18.0.2
                    Master_User: gokuit
                    Master_Port: 3306
                  Connect_Retry: 30
                Master_Log_File: mysql-bin.000003
            Read_Master_Log_Pos: 154
                 Relay_Log_File: 3882671bea53-relay-bin.000001
                  Relay_Log_Pos: 4
          Relay_Master_Log_File: mysql-bin.000003
               Slave_IO_Running: No
              Slave_SQL_Running: No
                Replicate_Do_DB: 
            Replicate_Ignore_DB: 
             Replicate_Do_Table: 
         Replicate_Ignore_Table: 
        Replicate_Wild_Do_Table: 
    Replicate_Wild_Ignore_Table: 
                     Last_Errno: 0
                     Last_Error: 
                   Skip_Counter: 0
            Exec_Master_Log_Pos: 154
                Relay_Log_Space: 154
                Until_Condition: None
                 Until_Log_File: 
                  Until_Log_Pos: 0
             Master_SSL_Allowed: No
             Master_SSL_CA_File: 
             Master_SSL_CA_Path: 
                Master_SSL_Cert: 
              Master_SSL_Cipher: 
                 Master_SSL_Key: 
          Seconds_Behind_Master: NULL
  Master_SSL_Verify_Server_Cert: No
                  Last_IO_Errno: 0
                  Last_IO_Error: 
                 Last_SQL_Errno: 0
                 Last_SQL_Error: 
    Replicate_Ignore_Server_Ids: 
               Master_Server_Id: 0
                    Master_UUID: 
               Master_Info_File: /var/lib/mysql/master.info
                      SQL_Delay: 0
            SQL_Remaining_Delay: NULL
        Slave_SQL_Running_State: 
             Master_Retry_Count: 86400
                    Master_Bind: 
        Last_IO_Error_Timestamp: 
       Last_SQL_Error_Timestamp: 
                 Master_SSL_Crl: 
             Master_SSL_Crlpath: 
             Retrieved_Gtid_Set: 
              Executed_Gtid_Set: 
                  Auto_Position: 0
           Replicate_Rewrite_DB: 
                   Channel_Name: 
             Master_TLS_Version: 
  1 row in set (0.00 sec)
  
  ERROR: 
  No query specified
  
  mysql> start slave;
  Query OK, 0 rows affected (0.00 sec)
  
  mysql> show slave status \G;
  *************************** 1. row ***************************
                 Slave_IO_State: Waiting for master to send event
                    Master_Host: 192.18.0.2
                    Master_User: gokuit
                    Master_Port: 3306
                  Connect_Retry: 30
                Master_Log_File: mysql-bin.000003
            Read_Master_Log_Pos: 154
                 Relay_Log_File: 3882671bea53-relay-bin.000002
                  Relay_Log_Pos: 320
          Relay_Master_Log_File: mysql-bin.000003
               Slave_IO_Running: Yes
              Slave_SQL_Running: Yes
                Replicate_Do_DB: 
            Replicate_Ignore_DB: 
             Replicate_Do_Table: 
         Replicate_Ignore_Table: 
        Replicate_Wild_Do_Table: 
    Replicate_Wild_Ignore_Table: 
                     Last_Errno: 0
                     Last_Error: 
                   Skip_Counter: 0
            Exec_Master_Log_Pos: 154
                Relay_Log_Space: 534
                Until_Condition: None
                 Until_Log_File: 
                  Until_Log_Pos: 0
             Master_SSL_Allowed: No
             Master_SSL_CA_File: 
             Master_SSL_CA_Path: 
                Master_SSL_Cert: 
              Master_SSL_Cipher: 
                 Master_SSL_Key: 
          Seconds_Behind_Master: 0
  Master_SSL_Verify_Server_Cert: No
                  Last_IO_Errno: 0
                  Last_IO_Error: 
                 Last_SQL_Errno: 0
                 Last_SQL_Error: 
    Replicate_Ignore_Server_Ids: 
               Master_Server_Id: 1
                    Master_UUID: 4a5ef558-0b9f-11ea-a7e8-0242c0120002
               Master_Info_File: /var/lib/mysql/master.info
                      SQL_Delay: 0
            SQL_Remaining_Delay: NULL
        Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
             Master_Retry_Count: 86400
                    Master_Bind: 
        Last_IO_Error_Timestamp: 
       Last_SQL_Error_Timestamp: 
                 Master_SSL_Crl: 
             Master_SSL_Crlpath: 
             Retrieved_Gtid_Set: 
              Executed_Gtid_Set: 
                  Auto_Position: 0
           Replicate_Rewrite_DB: 
                   Channel_Name: 
             Master_TLS_Version: 
  1 row in set (0.00 sec)
  
  ERROR: 
  No query specified
  
  mysql> exit
  Bye
  root@3882671bea53:/# exit
  ```

  

- **s2**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec s2 bash
  root@91cb062e6ca2:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 35
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> change master to master_host='192.18.0.2', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;
  Query OK, 0 rows affected, 2 warnings (0.01 sec)
  
  mysql> start slave;
  Query OK, 0 rows affected (0.00 sec)
  
  mysql> show slave status \G;
  *************************** 1. row ***************************
                 Slave_IO_State: Waiting for master to send event
                    Master_Host: 192.18.0.2
                    Master_User: gokuit
                    Master_Port: 3306
                  Connect_Retry: 30
                Master_Log_File: mysql-bin.000003
            Read_Master_Log_Pos: 154
                 Relay_Log_File: 91cb062e6ca2-relay-bin.000002
                  Relay_Log_Pos: 320
          Relay_Master_Log_File: mysql-bin.000003
               Slave_IO_Running: Yes
              Slave_SQL_Running: Yes
                Replicate_Do_DB: 
            Replicate_Ignore_DB: 
             Replicate_Do_Table: 
         Replicate_Ignore_Table: 
        Replicate_Wild_Do_Table: 
    Replicate_Wild_Ignore_Table: 
                     Last_Errno: 0
                     Last_Error: 
                   Skip_Counter: 0
            Exec_Master_Log_Pos: 154
                Relay_Log_Space: 534
                Until_Condition: None
                 Until_Log_File: 
                  Until_Log_Pos: 0
             Master_SSL_Allowed: No
             Master_SSL_CA_File: 
             Master_SSL_CA_Path: 
                Master_SSL_Cert: 
              Master_SSL_Cipher: 
                 Master_SSL_Key: 
          Seconds_Behind_Master: 0
  Master_SSL_Verify_Server_Cert: No
                  Last_IO_Errno: 0
                  Last_IO_Error: 
                 Last_SQL_Errno: 0
                 Last_SQL_Error: 
    Replicate_Ignore_Server_Ids: 
               Master_Server_Id: 1
                    Master_UUID: 4a5ef558-0b9f-11ea-a7e8-0242c0120002
               Master_Info_File: /var/lib/mysql/master.info
                      SQL_Delay: 0
            SQL_Remaining_Delay: NULL
        Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
             Master_Retry_Count: 86400
                    Master_Bind: 
        Last_IO_Error_Timestamp: 
       Last_SQL_Error_Timestamp: 
                 Master_SSL_Crl: 
             Master_SSL_Crlpath: 
             Retrieved_Gtid_Set: 
              Executed_Gtid_Set: 
                  Auto_Position: 0
           Replicate_Rewrite_DB: 
                   Channel_Name: 
             Master_TLS_Version: 
  1 row in set (0.00 sec)
  
  ERROR: 
  No query specified
  
  mysql> exit
  Bye
  root@91cb062e6ca2:/# exit
  ```

  

- **s3**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec s3 bash
  root@2de6d8063972:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 40
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> change master to master_host='192.18.0.5', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;
  Query OK, 0 rows affected, 2 warnings (0.01 sec)
  
  mysql> start slave;
  Query OK, 0 rows affected (0.00 sec)
  
  mysql> show slave status \G;
  *************************** 1. row ***************************
                 Slave_IO_State: Waiting for master to send event
                    Master_Host: 192.18.0.5
                    Master_User: gokuit
                    Master_Port: 3306
                  Connect_Retry: 30
                Master_Log_File: mysql-bin.000003
            Read_Master_Log_Pos: 154
                 Relay_Log_File: 2de6d8063972-relay-bin.000002
                  Relay_Log_Pos: 320
          Relay_Master_Log_File: mysql-bin.000003
               Slave_IO_Running: Yes
              Slave_SQL_Running: Yes
                Replicate_Do_DB: 
            Replicate_Ignore_DB: 
             Replicate_Do_Table: 
         Replicate_Ignore_Table: 
        Replicate_Wild_Do_Table: 
    Replicate_Wild_Ignore_Table: 
                     Last_Errno: 0
                     Last_Error: 
                   Skip_Counter: 0
            Exec_Master_Log_Pos: 154
                Relay_Log_Space: 534
                Until_Condition: None
                 Until_Log_File: 
                  Until_Log_Pos: 0
             Master_SSL_Allowed: No
             Master_SSL_CA_File: 
             Master_SSL_CA_Path: 
                Master_SSL_Cert: 
              Master_SSL_Cipher: 
                 Master_SSL_Key: 
          Seconds_Behind_Master: 0
  Master_SSL_Verify_Server_Cert: No
                  Last_IO_Errno: 0
                  Last_IO_Error: 
                 Last_SQL_Errno: 0
                 Last_SQL_Error: 
    Replicate_Ignore_Server_Ids: 
               Master_Server_Id: 4
                    Master_UUID: 4acb3ee7-0b9f-11ea-895b-0242c0120005
               Master_Info_File: /var/lib/mysql/master.info
                      SQL_Delay: 0
            SQL_Remaining_Delay: NULL
        Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
             Master_Retry_Count: 86400
                    Master_Bind: 
        Last_IO_Error_Timestamp: 
       Last_SQL_Error_Timestamp: 
                 Master_SSL_Crl: 
             Master_SSL_Crlpath: 
             Retrieved_Gtid_Set: 
              Executed_Gtid_Set: 
                  Auto_Position: 0
           Replicate_Rewrite_DB: 
                   Channel_Name: 
             Master_TLS_Version: 
  1 row in set (0.00 sec)
  
  ERROR: 
  No query specified
  
  mysql> exit
  Bye
  root@2de6d8063972:/# exit
  ```

  

- **s4**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec s4 bash
  root@b2fa7bf4adcd:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 44
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> change master to master_host='192.18.0.5', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;
  Query OK, 0 rows affected, 2 warnings (0.01 sec)
  
  mysql> start slave;
  Query OK, 0 rows affected (0.00 sec)
  
  mysql> 
  mysql> show slave status \G;
  *************************** 1. row ***************************
                 Slave_IO_State: Waiting for master to send event
                    Master_Host: 192.18.0.5
                    Master_User: gokuit
                    Master_Port: 3306
                  Connect_Retry: 30
                Master_Log_File: mysql-bin.000003
            Read_Master_Log_Pos: 154
                 Relay_Log_File: b2fa7bf4adcd-relay-bin.000002
                  Relay_Log_Pos: 320
          Relay_Master_Log_File: mysql-bin.000003
               Slave_IO_Running: Yes
              Slave_SQL_Running: Yes
                Replicate_Do_DB: 
            Replicate_Ignore_DB: 
             Replicate_Do_Table: 
         Replicate_Ignore_Table: 
        Replicate_Wild_Do_Table: 
    Replicate_Wild_Ignore_Table: 
                     Last_Errno: 0
                     Last_Error: 
                   Skip_Counter: 0
            Exec_Master_Log_Pos: 154
                Relay_Log_Space: 534
                Until_Condition: None
                 Until_Log_File: 
                  Until_Log_Pos: 0
             Master_SSL_Allowed: No
             Master_SSL_CA_File: 
             Master_SSL_CA_Path: 
                Master_SSL_Cert: 
              Master_SSL_Cipher: 
                 Master_SSL_Key: 
          Seconds_Behind_Master: 0
  Master_SSL_Verify_Server_Cert: No
                  Last_IO_Errno: 0
                  Last_IO_Error: 
                 Last_SQL_Errno: 0
                 Last_SQL_Error: 
    Replicate_Ignore_Server_Ids: 
               Master_Server_Id: 4
                    Master_UUID: 4acb3ee7-0b9f-11ea-895b-0242c0120005
               Master_Info_File: /var/lib/mysql/master.info
                      SQL_Delay: 0
            SQL_Remaining_Delay: NULL
        Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
             Master_Retry_Count: 86400
                    Master_Bind: 
        Last_IO_Error_Timestamp: 
       Last_SQL_Error_Timestamp: 
                 Master_SSL_Crl: 
             Master_SSL_Crlpath: 
             Retrieved_Gtid_Set: 
              Executed_Gtid_Set: 
                  Auto_Position: 0
           Replicate_Rewrite_DB: 
                   Channel_Name: 
             Master_TLS_Version: 
  1 row in set (0.00 sec)
  
  ERROR: 
  No query specified
  
  mysql> exit
  Bye
  root@b2fa7bf4adcd:/# exit
  ```



### 测试主从复制

####  Master 创建test_db库

- **M1创建test_db库**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec m1 bash
  root@169ab7da713e:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 53
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> CREATE DATABASE IF NOT EXISTS test_db;
  Query OK, 1 row affected (0.00 sec)
  
  mysql> show databases;
  +--------------------+
  | Database           |
  +--------------------+
  | information_schema |
  | mysql              |
  | performance_schema |
  | sys                |
  | test_db            |
  +--------------------+
  5 rows in set (0.01 sec)
  
  mysql> exit
  Bye
  root@169ab7da713e:/# exit
  ```

  

- **M2创建test_db库**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec m2 bash
  root@3eb2efc9df37:/# mysql -u root -p
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 60
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> CREATE DATABASE IF NOT EXISTS test_db;
  Query OK, 1 row affected (0.00 sec)
  
  mysql> show databases;
  +--------------------+
  | Database           |
  +--------------------+
  | information_schema |
  | mysql              |
  | performance_schema |
  | sys                |
  | test_db            |
  +--------------------+
  5 rows in set (0.00 sec)
  
  mysql> exit
  Bye
  root@3eb2efc9df37:/# exit
  ```

  

#### 检查 Slave 是否存在此数据库

- **分别检查S1、S2、S3、S4 是否存在test_db库**

  ```
  [root@localhost docker-mycat-mysql]# docker-compose exec s1 bash
  root@3882671bea53:/# mysql -u root -p 
  Enter password: 
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 55
  Server version: 5.7.28-log MySQL Community Server (GPL)
  
  Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.
  
  Oracle is a registered trademark of Oracle Corporation and/or its
  affiliates. Other names may be trademarks of their respective
  owners.
  
  Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
  
  mysql> show databases;
  +--------------------+
  | Database           |
  +--------------------+
  | information_schema |
  | mysql              |
  | performance_schema |
  | sys                |
  | test_db            |
  +--------------------+
  5 rows in set (0.00 sec)
  ```

  

### 重启容器

```shell
[root@localhost docker-mycat-mysql]# docker-compose restart
Restarting mycat ... done
Restarting s4    ... done
Restarting s3    ... done
Restarting s2    ... done
Restarting s1    ... done
Restarting m2    ... done
Restarting m1    ... done
```

### Navicat连接Mycat

![image-20200422003828806](https://cdn.jsdelivr.net/gh/baojingyu/ImageHosting@master/uPic/20200422003828image-20200422003828806.png)

```sql
-- 连接mycat成功,在test_db库执行以下SQL语句
CREATE TABLE IF NOT EXISTS t_test (
  id BIGINT(20) NOT NULL,
  title VARCHAR(100) NOT NULL ,
  PRIMARY KEY (id)
) ENGINE=INNODB DEFAULT CHARSET=utf8 ;


INSERT INTO t_test (id,title) VALUES ('1','test0001');
INSERT INTO t_test (id,title) VALUES ('2','test0002');
INSERT INTO t_test (id,title) VALUES ('3','test0003');
INSERT INTO t_test (id,title) VALUES ('4','test0004');
INSERT INTO t_test (id,title) VALUES ('5','test0005');
INSERT INTO t_test (id,title) VALUES ('6','test0006');
SELECT * FROM t_test;


CREATE TABLE IF NOT EXISTS t_task_test (
  id BIGINT(20) NOT NULL,
  org_code VARCHAR(100) NOT NULL ,
  title VARCHAR(100) NOT NULL ,
  PRIMARY KEY (id)
) ENGINE=INNODB DEFAULT CHARSET=utf8 ;

INSERT INTO t_task_test (id,org_code,title) VALUES ('1','W12340001','test0001');
INSERT INTO t_task_test (id,org_code,title) VALUES ('2','W12340002','test0002');
INSERT INTO t_task_test (id,org_code,title) VALUES ('3','W12340003','test0003');
INSERT INTO t_task_test (id,org_code,title) VALUES ('4','W12340004','test0004');
INSERT INTO t_task_test (id,org_code,title) VALUES ('5','W12340005','test0005');
INSERT INTO t_task_test (id,org_code,title) VALUES ('6','W12340006','test0006');
SELECT * FROM t_task_test;
```

## 命令

```shell
#构建,后台启动并运行所有的容器
docker-compose up -d

#显示所有容器
docker-compose ps

#进入某某容器
docker-compose exec xx容器名称 bash

#登入mysql
mysql -u root -p

#显示Master状态
show master status;

#显示Slave状态
show slave status \G;

#S1,S2执行Master主从复制,读取Master的binlog文件和位置信息
change master to master_host='192.18.0.2', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;

#S3,S4执行Master主从复制,读取Master的binlog文件和位置信息
change master to master_host='192.18.0.5', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;

#同时启动I/O 线程和SQL线程;I/O线程从主库读取bin log，并存储到relay log中继日志文件中。SQL线程读取中继日志，解析后，在从库重放。
start slave;

#创建test_db数据库
CREATE DATABASE IF NOT EXISTS test_db;

#显示所有数据库
show databases;

#重启所有容器
docker-compose restart

```



