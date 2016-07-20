# Kuali Coeus Database Image [ MySQL version ] - Dockerfile

This repository contains the **Dockerfile** of an [ automated build of a Kuali Database image ](https://registry.hub.docker.com/u/jefferyb/kuali_db_mysql/) published to the public [Docker Hub Registry](https://registry.hub.docker.com/).

# How to Use the Kuali Database Images

## Start a Kuali Database Instance

Start a Kuali Database instance as follows:

    docker run  -d --name kuali-coeus-database -p 3306:3306 jefferyb/kuali_db_mysql

## Build a Kuali Database Image yourself

You can build an image from the docker-compose.yml file:

    docker-compose build

Alternatively, you can build an image from the Dockerfile:

    docker build  -t jefferyb/kuali_db_mysql https://github.com/jefferyb/docker-mysql-kuali-coeus.git

## Connect to Kuali Database from an Application in Another Docker Container

This image exposes the standard MySQL port (3306), so container linking makes the MySQL instance available to other application containers. For example, to start your application container, like jefferyb/kuali_tomcat, link it to the Kuali Database container like so:

    docker run  -d \
                --name kuali-coeus-application \
                --link kuali-coeus-database \
                -e "KUALI_APP_URL=EXAMPLE.COM" \
                -e "KUALI_APP_URL_PORT=8080" \
                -e "MYSQL_HOSTNAME=kuali-coeus-database" \
                -p 8080:8080 \
                jefferyb/kuali_tomcat


## Container Shell Access

The `docker exec` command allows you to run commands inside a Docker container. The following command line will give you a bash shell inside your Kuali Database container:

    docker exec -it kuali-coeus-database bash
