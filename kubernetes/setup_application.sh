#!/bin/bash

app=$1
domain=$2

kubectl create namespace $app

echo "setting up $app"

if [ -f "./$app/volumes.yml" ]; then
    kubectl apply -f "./$app/volumes.yml"
    # wait for volumes to mount
    echo "waiting for volumes to be mounted..."
    sleep 10
fi

set -o allexport
if [ -f "./$app/.env" ]; then
    source "./$app/.env"
fi
set +o allexport

if [ -f "./$app/secrets.yml" ]; then
    envsubst < "./$app/secrets.yml" > "./$app/secrets-processed.yml"
    kubectl apply -f "./$app/secrets-processed.yml"
fi

if [ -f "./$app/service.yml" ]; then
    kubectl apply -f "./$app/service.yml"
fi

if [ -f "./$app/ingress-routes.yml" ]; then
    sed -e "s;{{DOMAIN}};$domain;g" "./$app/ingress-routes.yml" | kubectl apply -f -
fi

if [ -f "./$app/manifest.yml" ]; then
    kubectl apply -f "./$app/manifest.yml"
fi

if [ -f "./$app/deployment.yml" ]; then
    kubectl apply -f "./$app/deployment.yml"
fi

if [ -f "./$app/daemonset.yml" ]; then
    kubectl apply -f "./$app/daemonset.yml"
fi

echo "done ✅"
