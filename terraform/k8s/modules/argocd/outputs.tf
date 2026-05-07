output "namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.argocd_namespace
}

output "url" {
  description = "ArgoCD UI URL"
  value       = "https://${var.domain}"
}
