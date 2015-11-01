#
# Kuali Coeus on MySQL Server Dockerfile
#
# https://github.com/jefferyb/docker-mysql-kuali-coeus
#
# To Build:
#    docker build -t jefferyb/kuali_db_mysql .
#
# To Run:
#    docker run -d --name kuali_db_mysql -h kuali_db_mysql -p 43306:3306 jefferyb/kuali_db_mysql
#

# Pull base image.
FROM ubuntu:14.04
MAINTAINER Jeffery Bagirimvano <jeffery.rukundo@gmail.com>

RUN mkdir -p /setup_files

ADD setup_files /setup_files

ENV HOST_NAME kuali_db_mysql
ENV SHELL /bin/bash

# Install MySQL.
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server git && \
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
	cp -f /setup_files/my.cnf /etc/mysql/my.cnf && \
	mysql -u root -pChang3m3t0an0th3r < /setup_files/configure_mysql.sql && \
	service mysql restart && \
	cd setup_files; ./install_kuali_db.sh && \
	rm -fr /setup_files && \
	echo "Done!!!"

# Expose ports.
EXPOSE 3306

# Define default command.
# CMD ["mysqld"]
CMD export TERM=vt100; /usr/bin/mysqld_safe
