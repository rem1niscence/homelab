# K3S Private (and insecure) Container Registry Setup Guide

## Example Environment:

- **Cluster node**: 192.168.0.91
- **Local subnet**: 192.168.0.0/24
- **Storage**: Longhorn
- **Local Registry domain**: registry.local
- **Networking**: Tailscale VPN for inter-node connectivity

## 1. Manifest at [cluster/registry/manifest.yml](/cluster/registry/manifest.yml)

### Deploy the Registry

```bash
make app AP=registry DOMAIN={{DOMAIN}}
kubectl get pods -n registry
```

## 2. DNS Configuration

### For External Access (Host Machines)
```bash
# Add to /etc/hosts on all machines that need access
echo "192.168.0.91 registry.local" | sudo tee -a /etc/hosts
```

## 3. k3s Registry Configuration

### Get Registry Service ClusterIP
```bash
# Find the ClusterIP of your registry service
kubectl get svc registry -n registry
# Example output: registry ClusterIP 10.43.105.26
```

### Configure registries.yaml on ALL k3s Nodes
```bash
# Run this on ALL nodes: nuc, amd, pi-2, pi-3, ubuntu-4gb-fsn1-1
sudo mkdir -p /etc/rancher/k3s

# Replace 10.43.105.26 with the service actual ClusterIP
sudo tee /etc/rancher/k3s/registries.yaml << 'EOF'
mirrors:
  "registry.local":
    endpoint:
      - "http://10.43.105.26"

configs:
  "registry.local":
    tls:
      insecure_skip_verify: true
EOF

# Restart k3s services
sudo systemctl restart k3s         # on server nodes
sudo systemctl restart k3s-agent   # on agent nodes
```

## 4. Image Push/Pull with Podman

### Install and Configure Podman
```bash
# Install podman (Ubuntu/Debian)
sudo apt install podman

# Configure podman for insecure registry
mkdir -p ~/.config/containers
cat > ~/.config/containers/registries.conf << 'EOF'
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "registry.local"
insecure = true
EOF
```

### Push Images to Registry
```bash
# Pull, tag, and push images
podman pull hello-world
podman tag hello-world registry.local/hello-world:test
podman push registry.local/hello-world:test

# Verify push succeeded
curl http://registry.local/v2/_catalog
curl http://registry.local/v2/hello-world/tags/list
```

## 5. Test k3s Deployment

### Create Test Deployment
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: registry-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world-test
  namespace: registry-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world-test
  template:
    metadata:
      labels:
        app: hello-world-test
    spec:
      containers:
      - name: hello-world
        image: registry.local/hello-world:test  # Note: registry.local format
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "50m"
```

### Deploy and Verify
```bash
kubectl apply -f test-deployment.yaml
kubectl get pods -n registry-test

# Check events to confirm successful image pull
kubectl describe pod -n registry-test -l app=hello-world-test
# Should show: "Container image registry.local/hello-world:test already present on machine"
```

## 6. Usage in Deployments

### For Deployments in Any Namespace
```yaml
spec:
  containers:
  - name: my-app
    image: registry.local/my-app:v1.0.0  # Use registry.local format
```

### Push New Images
```bash
# Build or pull your image
podman build -t my-app:v1.0.0 .

# Tag for your registry
podman tag my-app:v1.0.0 registry.local/my-app:v1.0.0

# Push to registry
podman push registry.local/my-app:v1.0.0
```

## Key Success Factors

1. **Used IngressRoute instead of Ingress** - Direct Traefik integration
2. **Used Podman instead of Docker** - Avoided Docker networking/DNS issues
3. **Used ClusterIP directly in registries.yaml** - Bypassed DNS resolution problems
4. **Used registry.local format** - Avoided Docker Hub name conflicts
5. **Configured both external and in-cluster DNS** - Full accessibility

## Troubleshooting

### Verify Registry is Working
```bash
# Test registry API
curl http://registry.local/v2/

# List repositories
curl http://registry.local/v2/_catalog

# Test DNS from within cluster
kubectl run dns-test --image=busybox -it --rm -- nslookup registry.registry.svc.cluster.local
```

### Common Issues
- **ImagePullBackOff**: Check registries.yaml configuration and restart k3s services
- **DNS resolution failures**: Verify /etc/hosts entries and Rancher registry configuration
- **Docker networking issues**: Use Podman instead for easier DNS resolution
- **Podman cannot send images**: Modify /etc/hosts on the podman vm (`podman machine ssh`) to make sure it resolves `registry.local` correctly.
