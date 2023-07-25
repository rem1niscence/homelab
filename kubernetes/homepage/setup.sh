#!/bin/bash

path=$1
domain=$2

kubectl apply -f ./$path/cluster-role.yml

kubectl apply -f ./$path/service-account.yml

sed -e "s;{{DOMAIN}};$domain;g" "./$path/config-map.yml" | kubectl apply -f -

set -o allexport
if [ -f "./$path/.env" ]; then
    source "./$path/.env"
fi
set +o allexport
envsubst < "./$path/secrets.yml" > "./$path/secrets-processed.yml"
rm "./$path/secrets.yml"
mv "./$path/secrets-processed.yml" "./$path/secrets.yml" 
kubectl apply -f "./$path/secrets.yml"

kubectl apply -f ./$path/deployment.yml

kubectl apply -f ./$path/service.yml

sed -e "s;{{DOMAIN}};$domain;g" "./$path/ingress-routes.yml" | kubectl apply -f -
