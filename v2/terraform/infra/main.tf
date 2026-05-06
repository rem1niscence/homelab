# load SOPS encrypted file into the module
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

module "cloudflare" {
  source     = "./modules/cloudflare"
  account_id = data.sops_file.secrets.data["cloudflare.account_id"]
}
