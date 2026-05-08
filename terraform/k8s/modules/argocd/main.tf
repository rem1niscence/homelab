terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "sealed-secrets" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_secret_v1" "sealed-secrets-key" {
  metadata {
    name      = "sealed-secrets-key"
    namespace = "sealed-secrets"
  }
  data = {
    "tls.crt" = var.sealed_secrets_crt
    "tls.key" = var.sealed_secrets_key
  }
  depends_on = [kubernetes_namespace_v1.sealed-secrets]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = var.argocd_namespace
  create_namespace = true
  wait             = true

  values = [yamlencode({
    # global = {
    #   nodeSelector = {
    #     "node-role.kubernetes.io/control-plane" = "true"
    #   }
    # }

    configs = {
      secret = {
        argocdServerAdminPassword = var.admin_password
      }
      params = {
        # Traefik handles TLS termination
        "server.insecure" = true
      }
    }

    # ServiceMonitor for VictoriaMetrics (Prometheus) monitoring
    server = {
      extraArgs = ["--insecure"]
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    }
    controller = {
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    }
    repoServer = {
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    }
    applicationSet = {
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    }
    notifications = {
      enabled = false
      metrics = {
        enabled = false
        serviceMonitor = {
          enabled = false
        }
      }
    }
    redis = {
      metrics = {
        enabled = false
        serviceMonitor = {
          enabled = false
        }
      }
    }
    dex = {
      enabled = false
      metrics = {
        enabled = false
        serviceMonitor = {
          enabled = false
        }
      }
    }
  })]
  depends_on = [kubernetes_secret_v1.sealed-secrets-key]
}

# Traefik IngressRoute for ArgoCD UI
resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "argocd-server"
      namespace = var.argocd_namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`argocd.${var.domain}`)"
          kind  = "Rule"
          services = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "repo_credentials" {
  metadata {
    name      = "infra-repo"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    "type"          = "git"
    "url"           = var.repo_url
    "sshPrivateKey" = var.repo_deploy_key
  }

  depends_on = [helm_release.argocd]
}

# ------------------------------------------------------------------------------
# App of Apps
#
# Points at k8s/apps/ in the repo. ArgoCD discovers all Application manifests
# in that directory and deploys them.
# ------------------------------------------------------------------------------
resource "kubectl_manifest" "app_of_apps" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = var.apps_path
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.repo_credentials,
  ]
}
