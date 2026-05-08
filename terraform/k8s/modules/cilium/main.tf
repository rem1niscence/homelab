terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    file("${path.module}/values.yaml")
  ]

  wait = true
}

# cilium LB IP pool defines the address ranges cilium can assign to LoadBalancer services.
resource "kubectl_manifest" "cilium_lb_pool" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: default-pool
    spec:
      blocks:
        - cidr: "${var.lan_lb_cidr}"
        - cidr: "${var.tailscale_lb_cidr}"
  YAML

  depends_on = [helm_release.cilium]
}

# L2 announcement policy tells cilium which nodes and interfaces to use for ARP responses.
resource "kubectl_manifest" "cilium_l2_policy" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumL2AnnouncementPolicy
    metadata:
      name: local-l2
    spec:
      loadBalancerIPs: true
      interfaces:
        - ^(eth|eno|enp)
      nodeSelector:
        matchLabels: {}
  YAML

  depends_on = [helm_release.cilium]
}

# Cilium IngressRoute for Hubble UI
resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "hubble-ui"
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`hubble.${var.domain}`)"
          kind  = "Rule"
          services = [
            {
              name = "hubble-ui"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [helm_release.cilium]
}
