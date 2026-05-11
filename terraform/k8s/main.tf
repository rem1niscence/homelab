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
  domain            = data.sops_file.secrets.data["domain"]
}

# argocd watches the infrastructure repo and reconciles cluster state from it
module "argocd" {
  source             = "./modules/argocd"
  domain             = data.sops_file.secrets.data["domain"]
  argocd_version     = "9.5.12"
  repo_url           = "git@github.com:rem1niscence/homelab.git"
  repo_deploy_key    = data.sops_file.secrets.data["argocd.deploy_key"]
  sealed_secrets_crt = data.sops_file.secrets.data["sealed_secrets.tls_crt"]
  sealed_secrets_key = data.sops_file.secrets.data["sealed_secrets.tls_key"]
  admin_password     = data.sops_file.secrets.data["argocd.admin_password_hash"]
  target_revision    = "deploy"
  depends_on         = [module.cilium]
}

# --- Kubernetes bootstrap configuration ---

# annotate the Traefik service to be exposed via Tailscale
resource "kubernetes_annotations" "traefik_tailscale" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "traefik"
    namespace = "kube-system"
  }
  annotations = {
    "tailscale.com/hostname" = "traefik"
    "tailscale.com/expose"   = "true"
  }
  depends_on = [module.argocd]
}

data "kubernetes_nodes" "all" {}

# Endpoints are excluded from ArgoCD's resource tracking by default
resource "kubernetes_endpoints_v1" "truenas" {
  metadata {
    name      = "truenas"
    namespace = "truenas"
  }
  subset {
    address {
      ip = "192.168.0.95"
    }
    port {
      port     = 80
      name     = "http"
      protocol = "TCP"
    }
  }
  depends_on = [module.argocd]
}

resource "kubernetes_endpoints_v1" "router" {
  metadata {
    name      = "router"
    namespace = "truenas"
  }
  subset {
    address {
      ip = "192.168.0.1"
    }
    port {
      port     = 80
      name     = "http"
      protocol = "TCP"
    }
  }
  depends_on = [module.argocd]
}

# annotate nodes with Longhorn tags based on their storage labels so that
# Longhorn can schedule volumes to the correct nodes
resource "kubernetes_annotations" "longhorn_node_tags" {
  for_each = {
    for n in data.kubernetes_nodes.all.nodes : n.metadata[0].name => n
    if(
      lookup(n.metadata[0].labels, "platform.io/local-storage", null) == "true" ||
      lookup(n.metadata[0].labels, "platform.io/remote-storage", null) == "true" ||
      lookup(n.metadata[0].labels, "platform.io/vm-storage", null) == "true"
    )
  }

  api_version = "v1"
  kind        = "Node"
  metadata { name = each.key }
  annotations = {
    "node.longhorn.io/default-node-tags" = jsonencode(compact([
      lookup(each.value.metadata[0].labels,
      "platform.io/local-storage", null) == "true" ? "local" : "",
      lookup(each.value.metadata[0].labels,
      "platform.io/remote-storage", null) == "true" ? "remote" : "",
      lookup(each.value.metadata[0].labels,
      "platform.io/vm-storage", null) == "true" ? "vm" : "",
    ]))
  }
  depends_on = [module.argocd]
}
