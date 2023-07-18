### Handy commands

Get all pods excluding ones from kube system
`kubectl get pods --all-namespaces --field-selector 'metadata.namespace!=kube-system' -o wide` 

Get cluster ip:
`kubectl get service/kubernetes -n default -o jsonpath='{.spec.clusterIP}'` 

install k3s:
`curl -sfL https://get.k3s.io | sh -s - --prefer-bundled-bin`

install k3s agent:
`curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.88:6443 K3S_TOKEN=K1035fab54c06df0791f574ca2338de942ec0d52b8d9040744289fe1127f5ce803a::server:09304e5c7e02353df6b840a43aafcfe8 sh -s -`

--prefer-bundled-bin breaks nfs-mounts

ephemeral service to curl for connection
`kubectl run -it --rm --restart=Never curl --image=curlimages/curl:latest -- sh`

To change the startup commands of k3s:
1. `sudo vim /etc/systemd/system/k3s.service `
2. `systemctl daemon-reload`
3. `systemctl restart k3s`

