# 基于Docker的Mycat分片及读写分离&Mysql两主四从搭建

## 说明

- 使用一个t_test表做分片示意,分片规则使用mod-long
- 使用一个t_task_test表做分片示意,分片规则使用sharding-by-murmur-orgcode
- 采用mycat + mysql + docker-compose
- 采用2分片（2主4从）
- Mycat读写分离

---

#### 命令

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

---

## 开始

### 构建并启动容器

```shell
[root@localhost mysql_mycat]# docker-compose up -d
Creating network "mysql_mycat_mysql" with driver "bridge"
Creating m1 ... done
Creating m2 ... done
Creating s1 ... done
Creating s2 ... done
Creating s3 ... done
Creating s4 ... done
Creating mycat ... done
```

#### 显示所有容器

```shell
[root@localhost mysql_mycat]# docker-compose ps
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

#### 链接Master(主)

**m1**

```shell
[root@localhost mysql_mycat]# docker-compose exec m1 bash
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
| mysql-bin.000003 |      154 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)

mysql> exit
```

**m2**

```
[root@localhost mysql_mycat]# docker-compose exec m2 bash
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

File和Position字段的值后面将会用到，在后面的操作完成之前，需要保证Master库不能做任何操作，否则将会引起状态变化，File和Position字段的值变化。

#### 链接Slave(从)

```shell
[root@localhost mysql_mycat]# docker-compose exec s1 bash
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

**s2**

```shell
[root@localhost mysql_mycat]# docker-compose exec s2 bash
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

**s3**

```shell
[root@localhost mysql_mycat]# docker-compose exec s3 bash
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

**s4**

```shell
[root@localhost mysql_mycat]# docker-compose exec s4 bash
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

### 创建test_db库

#### M1创建test_db库

```shell
[root@localhost mysql_mycat]# docker-compose exec m1 bash
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

#### M2创建test_db库

```shell
[root@localhost mysql_mycat]# docker-compose exec m2 bash
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

#### 测试主从复制

```shell
[root@localhost mysql_mycat]# docker-compose exec s1 bash
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
[root@localhost mysql_mycat]# docker-compose restart
Restarting mycat ... done
Restarting s4    ... done
Restarting s3    ... done
Restarting s2    ... done
Restarting s1    ... done
Restarting m2    ... done
Restarting m1    ... done
```

### Navicat连接Mycat

![image-20191120231042166](/Users/baojingyu/Library/Application%20Support/typora-user-images/image-20191120231042166.png)

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



## 补充主从复制知识点

### 配置Master和Slave

#### 创建数据同步用户

在Master数据库创建数据同步用户，授予用户 gokuit REPLICATION SLAVE权限，用于在主从库之间同步数据。

```
create user gokuit;
grant REPLICATION SLAVE on *.* to 'gokuit'@'%' IDENTIFIED by 'gokuit';
flush privileges;
```

#### 配置Master修改my.cnf

```
[mysqld]
## 同一局域网内注意要唯一
server-id=100  
## 开启二进制日志功能，可以随便取（关键）
log-bin=mysql-bin
```

#### 配置Slave修改my.cnf

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

