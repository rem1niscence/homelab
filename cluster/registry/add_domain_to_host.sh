#!/bin/bash

# Set your variables
REGISTRY_IP="$1"
REGISTRY_DOMAIN="$2"

# add to /etc/hosts on each node
echo "${REGISTRY_IP} ${REGISTRY_DOMAIN}" | sudo tee -a /etc/hosts
