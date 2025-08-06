#!/bin/bash
#
BINARY_PATH=$1

# Define variables
REGISTRY="registry.local"
IMAGE_NAME="canopy-backup"
IMAGE_TAG="latest"
PLATFORM="linux/amd64"

podman build --platform $PLATFORM --build-arg BINARY_PATH=$BINARY_PATH -t $REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
podman push --tls-verify=false  $REGISTRY/$IMAGE_NAME:$IMAGE_TAG
