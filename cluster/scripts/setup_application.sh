#!/bin/bash

app=$1
domain=$2

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
    rm .env
fi
set +o allexport

if [ -f "./$app/secrets.yml" ]; then
    envsubst < "./$app/secrets.yml" > "./$app/secrets-processed.yml"
    rm "./$app/secrets.yml"
    mv "./$app/secrets-processed.yml" "./$app/secrets.yml"
fi

kubectl apply -f ./$app

if [ -f "./$app/secrets.yml" ]; then
  rm ./$app/secrets.yml; echo "File ./$app/secrets.yml deleted."
  rm ./$app/.env; echo "File ./$app/.env deleted."
fi

echo "done ✅"
