#!/bin/bash

app=$1
domain=$2

kubectl create namespace $app

# Use the app's custom setup
if [ -f "./$app/setup.sh" ]; then
    chmod +x "./$app/setup.sh"
    "./$app/setup.sh" $app $domain
    exit 0
fi

echo "setting up $app"

if [ -f "./$app/volumes.yml" ]; then
    kubectl apply -f "./$app/volumes.yml"
    # wait for volumes to mount
    echo "waiting for volumes to be mounted..."
    sleep 6
fi

set -o allexport
if [ -f "./$app/.env" ]; then
    source "./$app/.env"
fi
set +o allexport

if [ -f "./$app/secrets.yml" ]; then
    envsubst < "./$app/secrets.yml" > "./$app/secrets-processed.yml"
    rm "./$app/secrets.yml"
    mv "./$app/secrets-processed.yml" "./$app/secrets.yml" 
    kubectl apply -f "./$app/secrets.yml"
fi

if [ -f "./$app/manifest.yml" ]; then
    kubectl apply -f "./$app/manifest.yml"
fi

if [ -f "./$app/deployment.yml" ]; then
    kubectl apply -f "./$app/deployment.yml"
    # Need to wait for deployment to come up otherwise DNS resolution will break
    # because the service.yml will target the UDP port to a non functional service
    if [ "$app" == "pihole" ]; then
        echo "pihole detected. Need to sleep for 60 seconds so container starts"
        sleep 60
        echo "If DNS resolion dies after this, delete the service and retry."
    fi
fi

if [ -f "./$app/service.yml" ]; then
    kubectl apply -f "./$app/service.yml"
fi

if [ -f "./$app/ingress-routes.yml" ]; then
    sed -e "s;{{DOMAIN}};$domain;g" "./$app/ingress-routes.yml" | kubectl apply -f -
fi

if [ -f "./$app/daemonset.yml" ]; then
    kubectl apply -f "./$app/daemonset.yml"
fi

if [ -f "./$app/cronjob.yml" ]; then
    kubectl apply -f "./$app/cronjob.yml"
fi

echo "done ✅"
