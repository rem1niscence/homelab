#!/bin/bash

helm repo add tailscale https://pkgs.tailscale.com/helmcharts

helm repo update

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId=$OAUTH_CLIENT_ID \
  --set-string oauth.clientSecret=$OAUTH_CLIENT_SECRET \
  --set-string apiServerProxyConfig.mode="noauth" \
  --wait
