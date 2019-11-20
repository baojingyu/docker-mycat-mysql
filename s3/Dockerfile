FROM mysql:5.7
MAINTAINER <gokuit.cn>
ENV MYSQL_USER user
ENV MYSQL_ROOT_PASSWORD password
ENV MYSQL_PASSWORD password
EXPOSE 3306
RUN echo "nameserver 8.8.8.8" >/etc/resolv.conf \
CMD ["mysqld"]
