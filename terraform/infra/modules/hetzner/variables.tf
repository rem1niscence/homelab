variable "ssh_keys" {
  description = "Authorized SSH keys to add to the servers. Format: {key_name: public_key}"
  type        = map(string)
}

variable "user_data" {
  description = "Cloud-init user data script to run on server first boot"
  type        = string
  sensitive   = true
  default     = null
}
