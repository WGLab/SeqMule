#!/bin/bash
set -ex
# build image and push
docker login
version=$(git describe | sed 's/^v//')
branch=$(git rev-parse --abbrev-ref HEAD)
docker build --target --no-cache --build-arg branch_of_interest=${branch} -f Dockerfile -t whaleuuu/seqmule:${version} .
docker tag whaleuuu/seqmule:${version} whaleuuu/seqmule:latest
docker push whaleuuu/seqmule:${version}
docker push whaleuuu/seqmule:latest
# on AWS (Amazon Linux 2), how to set up docker
# sudo yum update -y && sudo yum install -y docker && sudo service docker start && sudo usermod -aG docker $USER && sudo chmod 666 /var/run/docker.sock && docker info
# recommend at least 32GB memory and 100GB storage for building 
