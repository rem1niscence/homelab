#!/bin/bash

helm repo add keel https://charts.keel.sh 
helm repo update
helm upgrade --install keel --namespace=kube-system keel/keel -f values.yml
