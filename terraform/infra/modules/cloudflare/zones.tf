resource "cloudflare_zone" "main" {
  for_each = toset(var.domains)
  account = {
    id = var.account_id
  }
  name = each.value
  type = "full"
}
