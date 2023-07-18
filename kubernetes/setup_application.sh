#!/bin/bash

path=$1
domain=$2
volume=$3

echo "setting up $path"

set -o allexport
source "./$path/.env"
set +o allexport

envsubst < "./$path/secrets.yml" > "./$path/secrets-processed.yml"

kubectl apply -f "./$path/secrets-processed.yml"

if [ "$volume" = "true" ]; then
    kubectl apply -f "./$path/pv.yml"
    kubectl apply -f "./$path/pvc.yml"
fi

kubectl apply -f "./$path/deployment.yml"
kubectl apply -f "./$path/service.yml"
sed -e "s;{{DOMAIN}};$domain;g" "./$path/ingress-routes.yml" | kubectl apply -f -

echo "done ✅"
