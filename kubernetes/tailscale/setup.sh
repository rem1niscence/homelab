#!/bin/bash

set -e
function handleError {
  echo "error: ${1}"
  exit 1
}

trap 'handleError $?' ERR

echo "performing variable substitution for secrets 🥷"
# Load environment variables from .env file
set -o allexport
source .env
set +o allexport
envsubst < secrets.yml > secrets-processed.yml
echo "variable substitution done ✅"

echo "applying secrets  🔒"
sudo kubectl apply -f secrets-processed.yml
echo "applying secrets done ✅"

echo "applying roles 👩‍⚖️"
sudo kubectl apply -f rbac.yml
echo "applying roles done ✅"

echo "applying deployment 🚀"
sudo kubectl apply -f deployment.yml
echo "applying deployment done ✅"
