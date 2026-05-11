variable "compartment_id" {
  description = "OCID of the compartment to deploy resources into"
  type        = string
}

variable "image_id" {
  description = "OCID of the amd64 image used by the x86 instance"
  type        = string
}

variable "arm_image_id" {
  description = "OCID of the aarch64 image used by the ARM instance"
  type        = string
}

variable "ssh_keys" {
  description = "Authorized SSH keys to add to the instance. Format: {key_name: public_key}"
  type        = map(string)
}

variable "display_name" {
  description = "Display name of the instance"
  type        = string
}

variable "user_data" {
  description = "Cloud-init user data script to run on server first boot"
  type        = string
  sensitive   = true
  default     = null
}
