#!/bin/bash

# Define variables
REGISTRY="registry.local"
IMAGE_NAME="canopy-backup"
IMAGE_TAG="latest"

podman build -t $REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
podman push --tls-verify=false  $REGISTRY/$IMAGE_NAME:$IMAGE_TAG
