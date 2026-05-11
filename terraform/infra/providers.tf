terraform {
  required_version = ">= 1.9"

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.7"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }

    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }

    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

provider "hcloud" {
  token = data.sops_file.secrets.data["hetzner.cloud_token"]
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api_token"]
}

provider "oci" {
  tenancy_ocid = data.sops_file.secrets.data["oracle.tenancy_ocid"]
  user_ocid    = data.sops_file.secrets.data["oracle.user_ocid"]
  fingerprint  = data.sops_file.secrets.data["oracle.fingerprint"]
  private_key  = data.sops_file.secrets.data["oracle.private_key"]
  region       = data.sops_file.secrets.data["oracle.region"]
}
