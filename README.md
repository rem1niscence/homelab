# Homelab Cluster

My homelab K3s cluster configuration

## 💻 Hardware

| Device               | Count | RAM    | Disks                                                   | OS             | Arch  |
|----------------------|-------|--------|---------------------------------------------------------|----------------|-------|
| Intel NUC I7 10th Gen| 1     | 64GB   | SSD 4TB (X2) <br> SSD 2TB (X2) <br> Micro SD 1TB (X2) <br> USB 512GB | TrueNAS SCALE  | amd64 |
| Intel NUC I7 10th Gen      | 1     | 32GB | SSD 256GB                                                 | Ubuntu 22.10        | amd64 |
| Raspberry Pi 4       | 2     | 8 GB   | SD 32GB                                                 | Raspberry PI OS         | armv7 |

## 💾 Virtual Machines

| Name           | Count | RAM  | Disks | OS          | Arch  |
|----------------|-------|------|-------|-------------|-------|
| K3s Worker VM  | 1     | 22GB | 128GB | Ubuntu 22.10| amd64 |
| Pihole         | 1     | 2GB  | 20GB  | DietPI      | amd64 |

## 📁 Repository structure

```sh
📁 cluster      # Kubernetes cluster defined as code
├─📁 scripts    # scripts directly related to cluster management
└─📁 {apps}...  # Apps deployed into the cluster grouped by namespace
📁 pi-2/shared  # Apps not yet migrated to the cluster
📁 provision    # Infrastructure setup defined as code (Not yet implemented)
📁 docker       # Services running outside the cluster
📁 scripts      # miscelaneus scripts mainly intented for the cluster nodes
```

## Credits to:

- [k3s](https://k3s.io) by [Rancher](https://rancher.com/)
- [tailscale](https://github.com/tailscale/tailscale) by [Tailscale](https://tailscale.com/)
