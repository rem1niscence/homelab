# load SOPS encrypted file into the module
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

# cilium replaces the default flannel CNI and handles all pod networking and network policies
module "cilium" {
  source    = "./modules/cilium"
  namespace = "kube-system"
  # pinned to 1.18.6 as 1.19.x has an issue in which pod-to-nodeIP connectivity in
  # VXLAN tunnel mode make pods unable to reach any host and ICMP to IPs also fails.
  # this breaks multiple components like metrics-server and prometheus node-exporter.
  # tracked in: https://github.com/cilium/cilium/issues/44430
  chart_version     = "1.18.6"
  lan_lb_cidr       = "192.168.0.200/24"
  tailscale_lb_cidr = "100.108.209.0/24"
}
