FROM mysql:5.7
MAINTAINER <gokuit.cn>
ENV MYSQL_USER user
ENV MYSQL_ROOT_PASSWORD password
ENV MYSQL_PASSWORD password
EXPOSE 3306
RUN echo "nameserver 8.8.8.8" >/etc/resolv.conf
# 在主服务器新建一个用户赋予“REPLICATION SLAVE”的权限。你不需要再赋予其它的权限。
ADD ./schema.sql /docker-entrypoint-initdb.d
CMD ["mysqld"]