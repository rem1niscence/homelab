# Use make tf-init to initialize the Terraform backend configuration
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "terraform.tfstate"
    region = "auto"

    secret_key = ""
    access_key = ""
    endpoints = {
      s3 = ""
    }

    // R2 specific settings as it does not support all S3 features
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
