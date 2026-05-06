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
  }
}

provider "hcloud" {
  token = data.sops_file.secrets.data["hetzner.cloud_token"]
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare.api_token"]
}
