#!/bin/bash

for container in $(sudo ctr container ls -q); do
    task=$(sudo ctr task ls | grep $container)
    if [ -z "$task" ]; then
        echo "deleting $container"
        sudo ctr container rm $container
    fi
done
