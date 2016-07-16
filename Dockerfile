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
FROM ubuntu:16.04
MAINTAINER Jeffery Bagirimvano <jeffery.rukundo@gmail.com>

RUN mkdir -p /setup_files
ADD setup_files /setup_files

ENV HOST_NAME kuali_db_mysql

# Install MySQL.
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server git && \
  ###
  echo $(head -1 /etc/hosts | cut -f1) ${HOST_NAME} >> /etc/hosts && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"localhost\" WITH GRANT OPTION;'" >> /tmp/config && \
  bash /tmp/config && \
  rm -f /tmp/config && \
  ### Set root password
	mysqladmin -u root password Chang3m3t0an0th3r && \
	mysqladmin -u root -pChang3m3t0an0th3r -h ${HOST_NAME} password Chang3m3t0an0th3r && \
  ###  For Kuali Coeus
  echo "transaction-isolation   = READ-COMMITTED" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "lower_case_table_names  = 1" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  ###
	mysql -u root -pChang3m3t0an0th3r < /setup_files/configure_mysql.sql && \
	service mysql restart && \
  ###
	cd /setup_files; ./install_kuali_db.sh && \
	rm -fr /setup_files && \
	echo "Done!!!"

# Expose ports.
EXPOSE 3306

# Define default command.
CMD /usr/bin/mysqld_safe
