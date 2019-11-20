create user gokuit;
grant REPLICATION SLAVE on *.* to 'gokuit'@'192.18.0.%' IDENTIFIED by 'gokuit';
flush privileges;