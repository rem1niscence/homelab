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

set -o allexport
if [ -f "./$app/.env" ]; then
    source "./$app/.env"
fi
set +o allexport

if [ -f "./$app/secrets.yml" ]; then
    envsubst < "./$app/secrets.yml" > "./$app/secrets-processed.yml"
    rm "./$app/secrets.yml"
    mv "./$app/secrets-processed.yml" "./$app/secrets.yml" 
fi

if [ -f "./$app/ingress-routes.yml" ]; then
    sed -e "s;{{DOMAIN}};$domain;g" "./$app/ingress-routes.yml" | kubectl apply -f -
fi

kubectl apply -f ./$app

echo "done ✅"
