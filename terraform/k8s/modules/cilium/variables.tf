variable "chart_version" {
  description = "cilium Helm chart version"
  type        = string
  default     = "1.18.6"
}

variable "namespace" {
  description = "namespace to install cilium"
  type        = string
  default     = "kube-system"
}

variable "lan_lb_cidr" {
  description = "CIDR block for LAN LoadBalancer IPs"
  type        = string
}

variable "tailscale_lb_cidr" {
  description = "CIDR block for Tailscale LoadBalancer IPs"
  type        = string
}

variable "domain" {
  description = "Domain for Hubble UI"
  type        = string
}
