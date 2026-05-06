resource "cloudflare_r2_bucket" "terraform-bucket" {
  account_id = var.account_id
  name       = "terraform-state"
  location   = "ENAM"
}
