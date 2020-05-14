#!/bin/bash

build() {
  local repoUrl="$1"
  if [ -z "$repoUrl" ] ; then
    printf "\nWhat is the kuali github repo url?"
    printf "\nExample: https://your_username:your_password@github.com/bu-ist/kuali-research.git"
    printf "\nEnter here: "
    read repoUrl
    echo $repoUrl
  fi

  # Make sensitive github login url available to docker over the network.
  echo "$repoUrl" > repoUrl.txt
  docker run \
    -d \
    --name=secrets-server \
    --rm \
    --volume $PWD:/files \
    busybox httpd -f -p 8000 -h /files

  # Build the image.
  docker-compose build

  docker stop secrets-server
  
  # Remove the sensitive github login
  rm -f repoUrl.txt
}

build