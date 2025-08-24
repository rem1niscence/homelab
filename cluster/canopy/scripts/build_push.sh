#!/bin/bash

BINARY_PATH=$1
IMAGE_NAME=$2

if [ -z "$BINARY_PATH" ]; then
    echo "Error: BINARY_PATH is required as the first argument"
    echo "Usage: $0 <BINARY_PATH> <IMAGE_NAME>"
    exit 1
fi

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: IMAGE_NAME is required as the second argument"
    echo "Usage: $0 <BINARY_PATH> <IMAGE_NAME>"
    exit 1
fi

REGISTRY="registry.local"
IMAGE_TAG="latest"
PLATFORM="linux/amd64"
DOCKERFILE="Dockerfile.backup"

podman build --platform $PLATFORM --build-arg BINARY_PATH=$BINARY_PATH -t $REGISTRY/$IMAGE_NAME:$IMAGE_TAG -f $DOCKERFILE .
podman push --tls-verify=false  $REGISTRY/$IMAGE_NAME:$IMAGE_TAG

# podman build --platform linux/amd64 -t registry.local/canopy:latest -f .docker/Dockerfile .
# podman push --tls-verify=false registry.local/canopy:latest
