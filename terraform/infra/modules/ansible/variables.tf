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
