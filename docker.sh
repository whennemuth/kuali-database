#!/bin/bash

# Build a docker image from which can be started containers that are running a generic kuali-research mysql database.
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
  docker build -t kuali_db_mysql --build-arg KC_PROJECT_BRANCH=bu-master .

  docker stop secrets-server
  
  # Remove the sensitive github login
  rm -f repoUrl.txt
}

# Run a container that hosts the kuali-research mysql database.
# The container running the kuali-research application can connect to it over it's exposed port.
run() {
  docker rm -f kcdb 2> /dev/null

  docker run -d \
    --restart unless-stopped \
    --name kcdb \
    -h 127.0.0.1 \
    -p 3306:3306 \
    -e "MYSQL_ROOT_PASSWORD=password123" \
    -e "MYSQL_DATABASE=kualidb" \
    -e "MYSQL_USER=kcusername" \
    -e "MYSQL_PASSWORD=kcpassword" \
    -e "TZ=America/New_York" \
    kuali_db_mysql \
    mysqld
}

task="$1"
shift

case "$task" in
  build) build $@ ;;
  run) run $@ ;;
esac