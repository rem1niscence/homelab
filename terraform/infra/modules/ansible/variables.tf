variable "hetzner_ip" {
  description = "IP address of the Hetzner VM"
  type        = string
}

variable "oracle_ip" {
  description = "IP address of the Oracle VM"
  type        = string
}

variable "hetzner_vm" {
  description = "Hetzner VM server SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "oracle_vm" {
  description = "Oracle VM server SSH credentials and config"
  type        = any
  sensitive   = true
}


variable "server_nuc" {
  description = "NUC server SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "server_amd" {
  description = "AMD server SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "server_pi_1" {
  description = "Pi-1 SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "server_pi_2" {
  description = "Pi-2 SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "server_pi_3" {
  description = "Pi-3 SSH credentials and config"
  type        = any
  sensitive   = true
}

variable "k3s_token" {
  description = "k3s cluster join token"
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# Tunnel

variable "frp_token" {
  description = "FRP token for token auth"
  type        = string
  sensitive   = true
}

variable "frp_dashboard_username" {
  description = "FRP dashboard username"
  type        = string
}

variable "frp_dashboard_password" {
  description = "FRP dashboard password"
  type        = string
  sensitive   = true
}

variable "frp_dashboard_secret_key" {
  description = "FRP dashboard secret key"
  type        = string
  sensitive   = true
}

variable "frp_extra_ports" {
  description = "List of extra ports to expose via FRP. Docker port expose format"
  type        = list(string)
  default     = []
}

variable "frp_caddy_enabled" {
  description = "Enable cappy for FRP"
  type        = bool
  default     = false
}

variable "frp_caddy_routes" {
  description = "List of Caddy routes to configure for FRP"
  type = list(object({
    domain       = string,
    backend_port = number
  }))
  default = []
}
