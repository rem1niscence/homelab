#!/bin/bash

# need to run this on every node of the cluster
DOMAIN=$1 # This is the ClusterIP of the service registry
NAME=registry.local

# create folder if it doesn't exist
mkdir -p /etc/rancher/k3s

# register the registry in K3S
sudo tee /etc/rancher/k3s/registries.yaml << EOF
mirrors:
  "${NAME}":
    endpoint:
      - "http://${DOMAIN}"

configs:
  "$NAME":
    tls:
      insecure_skip_verify: true
EOF

# restart k3s or k3s-agent service
if systemctl is-active --quiet k3s; then
    sudo systemctl restart k3s
elif systemctl is-active --quiet k3s-agent; then
    sudo systemctl restart k3s-agent
fi

# create podman config folder
mkdir -p ~/.config/containers

# add the config to Podman
cat > ~/.config/containers/registries.conf << EOF
unqualified-search-registries = ["docker.io", "ghcr.io"]

[[registry]]
location = "$NAME"
insecure = true
EOF

echo "-----------------------"
echo "Configuration complete!"
echo ""
echo "Registry endpoints:"
echo "- Registry: http://$NAME"
echo ""

echo "Test with:"
echo "podman pull hello-world"
echo "podman tag hello-world $NAME/hello-world:latest"
echo "podman push $NAME/hello-world:latest"
echo "Note: Configuration may not work with docker as it uses an isolated network namespace"
