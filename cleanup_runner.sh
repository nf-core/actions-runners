#!/bin/bash
#This script runs after each job to automatically remove temporary files in order to keep the runner clean and nice
find /home/ubuntu/actions-runner/work_runner/ -mindepth 1 -delete
docker rm -f $(docker ps -aq)
docker system prune --volumes --force
