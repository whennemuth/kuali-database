#
# Kuali Coeus on MySQL Server Dockerfile
#
# https://github.com/jefferyb/docker-mysql-kuali-coeus
#
# To Build:
#    docker build -t jefferyb/kuali_db_mysql .
#
# To Run:
#    docker run -d --name kuali_database -h kuali_database -p 3306:3306 jefferyb/kuali_db_mysql
#
# NOTE: A number of issues were encountered with the forked repo:
# 1) The above docker run command won't work. The kuali_database host does nothing, and the CMD instruction from
#    the Dockerfile /usr/bin/mysqld_safe leads to the mysqld process getting dropped for some unknown reason and
#    this instruction must be overridden in the docker run command with just "mysqld":
#       docker run -d --name kc -h 127.0.0.1 -p 3306:3306 jefferyb/kuali_db_mysql mysqld
#    test the container with the following:
#       
# 2) Due to problems with mysqld rejecting logins from users, skip-grant-tables is set in mysqld.cnf
#    This is obviously not secure, but is ok for local development.
# 3) Attempts made to edit the /etc/hosts file could never have worked. The hosts file is created at docker 
#    container runtime and cannot be edited in a Dockerfile RUN instruction.
#       mysql -u root -h 127.0.0.1 kualidb -e "show tables;"
# NOTE: If you are running this container on a remote host and would like to connect mysql workbench from your
#       laptop to it, tunnel into the host over port 3306 as in the following example:
#          ssh -i ~/.ssh/buaws-kuali-rsa-warren -N -v -L 3306:10.57.237.89:3306 ec2-user@10.57.237.89

FROM ubuntu:16.04

RUN mkdir -p /setup_files

ENV MYSQL_ROOT_PASSWORD="password123"
ENV MYSQL_DATABASE="kualidb"
ENV MYSQL_USER="kcusername"
ENV MYSQL_PASSWORD="kcpassword"
ENV TZ=America/New_York

ARG KC_PROJECT_BRANCH="master"

# Install MySQL.
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server git curl && \
  echo "The repoUrl is: " && \
  rm -rf /var/lib/apt/lists/* && \
  # Root is getting access denied when trying access mysql. Add skip-grant-tables and then flush privileges when connected.
  echo "skip-grant-tables" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'flush privileges; GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"localhost\" WITH GRANT OPTION;'" >> /tmp/config && \
  mkdir -p /var/run/mysqld && \
  chown mysql:mysql /var/run/mysqld && \
  bash /tmp/config && \
  rm -f /tmp/config && \
  ### Set root password ()
  mysqladmin -u root password ${MYSQL_ROOT_PASSWORD} && \
  ###  For Kuali Coeus
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "transaction-isolation   = READ-COMMITTED" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "lower_case_table_names  = 1" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
  # sed -i 's/skip-grant-tables//' /etc/mysql/mysql.conf.d/mysqld.cnf && \
  ### Create user & database
  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e " \
    CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE CHARACTER SET utf8 COLLATE utf8_bin; \
    GRANT ALL ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, CREATE VIEW, CREATE ROUTINE, ALTER ROUTINE ON * . * TO  '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ; \
    "; \
  service mysql restart

ADD setup_files /setup_files

# Run the sql scripts
RUN \
  service mysql start && \
  mkdir -p /var/run/mysqld 2> /dev/null && \
  chown mysql:mysql /var/run/mysqld && \
  cd /setup_files && \
  ./install_kuali_db.sh \
    "KC_REPO_URL=$(curl --silent http://172.17.0.1:8000/repoUrl.txt)" \
    "KC_PROJECT_BRANCH=$KC_PROJECT_BRANCH" && \
  # rm -fr /setup_files && \
  echo "Done!!!"

# Expose ports.
EXPOSE 3306

# Define default command.
CMD /usr/bin/mysqld_safe
