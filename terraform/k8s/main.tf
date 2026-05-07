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

# argocd watches the infrastructure repo and reconciles cluster state from it
module "argocd" {
  source             = "./modules/argocd"
  domain             = "argocd.${data.sops_file.secrets.data["argocd.domain"]}"
  argocd_version     = "9.5.12"
  repo_url           = "git@github.com:rem1niscence/homelab.git"
  repo_deploy_key    = data.sops_file.secrets.data["argocd.deploy_key"]
  sealed_secrets_crt = data.sops_file.secrets.data["sealed_secrets.tls_crt"]
  sealed_secrets_key = data.sops_file.secrets.data["sealed_secrets.tls_key"]
  admin_password     = data.sops_file.secrets.data["argocd.admin_password_hash"]
  target_revision    = "v2"
  depends_on         = [module.cilium]
}
