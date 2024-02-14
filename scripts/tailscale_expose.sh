#!/bin/bash

# Get all services in all namespaces
services=$(kubectl get svc --all-namespaces -o json)

# Loop through each service to check for the presence of 'tailscale.com/expose'
echo "$services" | jq -r '.items[] | select(.metadata.annotations."tailscale.com/expose" != null) | .metadata.name + " in namespace " + .metadata.namespace' | while read -r service; do
  echo "Service with 'tailscale.com/expose': $service"
done
