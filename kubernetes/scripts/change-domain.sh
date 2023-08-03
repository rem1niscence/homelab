#!/bin/bash

app_path=$1
domain=$2

if [ -f "./$app_path/ingress-routes.yml" ]; then
  sed -e "s;{{DOMAIN}};$domain;g" "./$app_path/ingress-routes.yml" | kubectl apply -f -
elif [ -f "./$app_path/manifest.yml" ]; then
  sed -e "s;{{DOMAIN}};$domain;g" "./$app_path/manifest.yml" | kubectl apply -f -
else
  echo "Error: Neither ingress-routes.yml nor manifest.yml were found." >&2
  exit 1
fi
