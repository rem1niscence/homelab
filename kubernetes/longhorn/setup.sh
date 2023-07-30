#!/bin/bash

# Yes I know about flux/ArgoCD but I'm learning and one thing at a time, will 
# set that up eventually

helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace -f ./values.yml
