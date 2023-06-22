#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo docker network create --driver bridge pi-network
sudo usermod -aG docker $USER
sudo reboot

# If you want a quick ephemeral image:
# docker run --rm -it --entrypoint bash ubuntu