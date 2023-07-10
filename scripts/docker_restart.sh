#!/bin/bash

# place this file in /usr/local/bin

# Sleep for a minute
sleep 60

# Restart all exited Docker containers
docker restart $(docker ps -a -q --filter "status=exited")