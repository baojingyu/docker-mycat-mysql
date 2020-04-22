

## 补充Mysql主从复制知识点

### 主从复制原理

![image-20200421100525819](https://cdn.jsdelivr.net/gh/baojingyu/ImageHosting@master/uPic/2020042201335420200421100526image-20200421100525819.png)

一共由三个线程完成

1. 主服务将数据的更新记录保存到二进制日志--主服务器进程
2. 从服务将主服务的二进制日志复制到本地中继日志--从服务IO进程
3. 从服务读取中继日志，更新本地数据--从服务SQL进程

## mysql主从复制

### 配置Master和Slave

#### 创建数据同步用户

在Master数据库创建数据同步用户，授予用户 **gokuit** REPLICATION SLAVE权限，用于在主从库之间同步数据。

```
create user gokuit;
grant REPLICATION SLAVE on *.* to 'gokuit'@'%' IDENTIFIED by 'gokuit';
flush privileges;
```

#### 配置Master修改my.cnf

打开配置文件vi /etc/my.cnf

```
[mysqld]
## 同一局域网内注意要唯一
server-id=100  
## 开启二进制日志功能，可以随便取（关键）
log-bin=mysql-bin
```

#### 配置Slave修改my.cnf

打开配置文件vi /etc/my.cnf

```
[mysqld]
## 设置server_id,注意要唯一
server-id=101  
## 开启二进制日志功能，以备Slave作为其它Slave的Master时使用
log-bin=mysql-slave-bin   
```

#### Mysql主从复制,CHANGE MASTER TO语法详解

配置mysql主从复制时，在从机上需要进行CHANGE MASTER TO操作，以确定需要同步的主机IP，用户名，密码，binlog文件，binlog位置等信息。

##### 语法详解:

**master_host** ：Master的地址，指的是容器的独立ip,可以通过`docker inspect --format='{{.NetworkSettings.IPAddress}}' 容器名称|容器id`查询容器的ip

**master_port**：Master的端口号，指的是容器的端口号

**master_user**：用于数据同步的用户

**master_password**：用于同步的用户的密码

**master_log_file**：指定 Slave 从哪个日志文件开始复制数据，即上文中提到的 File 字段的值

**master_log_pos**：从哪个 Position 开始读，即上文中提到的 Position 字段的值

**master_connect_retry**：如果连接失败，重试的时间间隔，单位是秒，默认是60秒

##### 示例:

```mysql
change master to master_host='192.18.0.2', master_user='gokuit', master_password='gokuit', master_port=3306, master_log_file='mysql-bin.000003', master_log_pos= 154, master_connect_retry=30;
```


