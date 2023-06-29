#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo docker network create --driver bridge pi-network
sudo usermod -aG docker $USER
sudo reboot

# Useful commands
# If you want a quick ephemeral image:
# docker run --rm -it --entrypoint bash ubuntu
# Restart all stopped containers
# docker restart $(docker ps -a -q --filter "status=exited")