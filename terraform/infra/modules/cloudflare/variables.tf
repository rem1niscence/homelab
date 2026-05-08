variable "account_id" {
  description = "Account ID for the Cloudflare account where the R2 bucket will be created"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain to be used over the cluster"
  type        = string
}

variable "server_ip" {
  description = "IP address for the wildcard DNS record"
  type        = string
}
