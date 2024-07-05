#!/bin/bash

hostname=$1

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=${hostname} \
  --set replicas=3
