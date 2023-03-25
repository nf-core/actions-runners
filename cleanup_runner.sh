#!/bin/bash
#This script runs after each job to automatically remove temporary files in order to keep the runner clean and nice
find /home/runner/work/ -mindepth 1 -delete
docker system prune --volumes --force
docker image prune -a
