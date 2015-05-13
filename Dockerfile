#
# Kuali Coeus on MySQL Server Dockerfile
#
# https://github.com/jefferyb/docker-mysql-kuali-coeus
#
# To Build:
#    docker build -t kuali_db_mysql:1504.3 .
#
# To Run:
#    docker run -d --name kuali_db_mysql -h kuali_db_mysql -p 43306:3306 kuali_db_mysql:1504.3
#

# Pull base image.
FROM ubuntu:14.04.2
MAINTAINER Jeffery Bagirimvano <jeffery.rukundo@gmail.com>

RUN mkdir -p /SetupMySQL

ADD db_scripts /SetupMySQL

ENV HOST_NAME kuali_db_mysql
ENV SHELL /bin/bash

# Install MySQL.
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server && \
  echo $(head -1 /etc/hosts | cut -f1) ${HOST_NAME} >> /etc/hosts && \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  sed -i 's/^\(log_error\s.*\)/# \1/' /etc/mysql/my.cnf && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;'" >> /tmp/config && \
  bash /tmp/config && \
  rm -f /tmp/config && \
	mysqladmin -u root password Chang3m3t0an0th3r && \
	mysqladmin -u root -h ${HOST_NAME} password Chang3m3t0an0th3r && \
	cp -f /SetupMySQL/mysql_files/my.cnf /etc/mysql/my.cnf && \
	mysql -u root -pChang3m3t0an0th3r < /SetupMySQL/mysql_files/configure_mysql.sql && \
	service mysql restart; cd /SetupMySQL/main; ./J_KC_Install.sh && \
	mkdir -p /SetupMySQL/ver_1504.3/mysql/LOGS && \
	cd /SetupMySQL/ver_1504.3/mysql && \
	mysql -ukcusername -pkcpassword kualicoeusdb < 601_mysql_kc_rice_server_upgrade.sql > /SetupMySQL/ver_1504.3/mysql/LOGS/601_MYSQL_KC_RICE_SERVER_UPGRADE.log 2>&1 && \
	mysql -ukcusername -pkcpassword kualicoeusdb < 601_mysql_kc_upgrade.sql > /SetupMySQL/ver_1504.3/mysql/LOGS/601_MYSQL_KC_UPGRADE.log 2>&1 && \
	mysql -ukcusername -pkcpassword kualicoeusdb < 1504_mysql_kc_rice_server_upgrade.sql > /SetupMySQL/ver_1504.3/mysql/LOGS/1504_MYSQL_KC_RICE_SERVER_UPGRADE.log 2>&1 && \
	mysql -ukcusername -pkcpassword kualicoeusdb < 1504_mysql_kc_upgrade.sql > /SetupMySQL/ver_1504.3/mysql/LOGS/1504_MYSQL_KC_UPGRADE.log 2>&1 && \
	rm -fr /SetupMySQL && \
	echo "Done!!!"

# Expose ports.
EXPOSE 3306

# Define default command.
# CMD ["mysqld"]
CMD export TERM=vt100; /usr/bin/mysqld_safe
