### Handy commands

Get cluster ip:
`kubectl get service/kubernetes -n default -o jsonpath='{.spec.clusterIP}'` 

install k3s:
`curl -sfL https://get.k3s.io | sh -s - --prefer-bundled-bin`

--prefer-bundled-bin breaks nfs-mounts on rpi

ephemeral service to curl for connection
`kubectl run -it --rm --restart=Never curl --image=curlimages/curl:latest -- sh`

To change the startup commands of k3s:
1. `sudo vim /etc/systemd/system/k3s.service `
2. `systemctl daemon-reload`
3. `systemctl restart k3s`

### TrueNAS Commands
Set max zfs cache
`echo 217633266688 >> /sys/module/zfs/parameters/zfs_arc_max`

required libraries in nodes for nfs support: 
* nfs-common
* libnfs-utils


fixes many ipv6 issues
`sudo modprobe ip6table_filter`
