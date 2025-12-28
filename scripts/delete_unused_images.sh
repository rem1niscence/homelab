#!/bin/bash

K3S_CTR="/var/lib/rancher/k3s/data/current/bin/ctr"
SOCKET_PATH="/run/k3s/containerd/containerd.sock"
NAMESPACE="k8s.io"

${K3S_CTR} -a ${SOCKET_PATH} -n ${NAMESPACE} image ls -q > all_images.txt

for container in $(${K3S_CTR} -a ${SOCKET_PATH} -n ${NAMESPACE} containers ls -q); do
    ${K3S_CTR} -a ${SOCKET_PATH} -n ${NAMESPACE} containers info ${container} | grep Image | awk '{print $2}' >> used_images.txt
done

# Sort and deduplicate
sort all_images.txt | uniq > all_sorted.txt
sort used_images.txt | uniq > used_sorted.txt

comm -23 all_sorted.txt used_sorted.txt > to_delete.txt
while read -r image; do
    echo "Removing $image"
    sudo ${K3S_CTR} -a ${SOCKET_PATH} -n ${NAMESPACE} image rm "$image"
done < to_delete.txt

rm all_images.txt used_images.txt all_sorted.txt used_sorted.txt to_delete.txt

echo "cleanup complete"
