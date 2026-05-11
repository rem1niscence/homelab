variable "account_id" {
  description = "Account ID for the Cloudflare account where the R2 bucket will be created"
  type        = string
  sensitive   = true
}

variable "domains" {
  description = "Map of domains to their IP addresses"
  type        = map(string)
}
