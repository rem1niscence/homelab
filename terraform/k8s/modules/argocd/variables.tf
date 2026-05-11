variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD"
  type        = string
  default     = "argocd"
}

variable "admin_password" {
  description = "Admin password for ArgoCD UI"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain for ArgoCD UI"
  type        = string
}

variable "sealed_secrets_crt" {
  description = "TLS certificate for Sealed Secrets"
  type        = string
  sensitive   = true
}

variable "sealed_secrets_key" {
  description = "TLS private key for Sealed Secrets"
  type        = string
  sensitive   = true
}

variable "repo_url" {
  description = "SSH URL of the infra repo (e.g. git@github.com:you/infra.git)"
  type        = string
}

variable "repo_deploy_key" {
  description = "SSH private key for ArgoCD to pull from the private repo"
  type        = string
  sensitive   = true
}

variable "target_revision" {
  description = "Git branch, tag, or commit to deploy"
  type        = string
  default     = "main"
}

variable "apps_path" {
  description = "Path to the ArgoCD Application manifests in the repo"
  type        = string
  default     = "k8s/apps"
}
