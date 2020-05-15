#!/bin/bash

build() {
  local repoUrl="$1"
  if [ -z "$repoUrl" ] ; then
    printf "\nWhat is the kuali github repo url?"
    printf "\nExample: https://your_username:your_password@github.com/bu-ist/kuali-research.git"
    printf "\nEnter here: "
    read repoUrl
  fi
  echo "$repoUrl" > repoUrl.txt

  # Make sure there are no containers running from previous activity.
  docker rm -f secrets-server 2> /dev/null
  docker rm -f kcdb 2> /dev/null

  # Run a container that will make sensitive information available to the docker build over the network.
  docker run \
    -d \
    --name=secrets-server \
    --rm \
    --volume $PWD:/files \
    -p 8000:8000 \
    busybox httpd -f -p 8000 -h /files

  # Build the image.
  docker build -t jefferyb/kuali_db_mysql .

  docker stop secrets-server
  
  # Remove the sensitive github login
  rm -f repoUrl.txt
}

run() {
  docker rm -f kcdb 2> /dev/null

  docker run -d \
    --restart unless-stopped \
    --name kcdb \
    -h 127.0.0.1 \
    -p 3306:3306 \
    -e "MYSQL_ROOT_PASSWORD=password123" \
    -e "MYSQL_DATABASE=kualicoeusdb" \
    -e "MYSQL_USER=kcusername" \
    -e "MYSQL_PASSWORD=kcpassword" \
    -e "TZ=America/New_York" \
    jefferyb/kuali_db_mysql \
    mysqld
}

task=$1
shift

case "$task" in
  build) build $@ ;;
  run) run $@ ;;
esac