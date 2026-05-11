#!/bin/bash

# Documentation: https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy
# GH issue comment where this script was created:
# https://github.com/tailscale/tailscale/issues/1437#issuecomment-123456789
# also from this stack overflow response:
# https://stackoverflow.com/a/70424837

# This script generates a kubeconfig file for accessing a K3s cluster through the Tailscale operator
# in "noauth" mode. It creates the necessary ServiceAccount and RBAC permissions, extracts a JWT token,
# and outputs a complete kubeconfig that uses token-based authentication instead of client certificates.
# This solves the authentication issue when using Tailscale operator's API server proxy with K3s.
# Requires tailscale to be installed and configured on the system with
# `apiServerProxyConfig.mode="noauth"`

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the Tailscale server URL from command line argument
SERVER=$1

echo "Applying ServiceAccount and RBAC configuration..."
# Apply the ServiceAccount and ClusterRoleBinding manifests
kubectl apply -f "$SCRIPT_DIR/external_service_account.yml"

echo "Extracting service account token..."
# Extract the actual JWT token from the Kubernetes secret
TOKEN=$(kubectl get secret tailscale-cluster-admin-token -n tailscale -o jsonpath='{.data.token}' | base64 --decode)

echo "Generating kubeconfig..."
echo "--------"
# Substitute placeholders in config template with actual values and output the final kubeconfig
sed -e "s|{{SERVER_URL}}|$SERVER|g" -e "s|{{TOKEN}}|$TOKEN|g" "$SCRIPT_DIR/kube_config"
echo "--------"
echo ""
echo "Success! ✅ Copy the above kubeconfig content and paste it into your ~/.kube/config file"
echo "then run \"tailscale configure kubeconfig tailscale-operator\" to configure "
echo "the Tailscale Operator on your machine and you're ready to go!"
