resource "cloudflare_zone" "main" {
  account = {
    id = var.account_id
  }
  name = var.domain
  type = "full"
}

resource "cloudflare_dns_record" "wildcard_record" {
  zone_id = cloudflare_zone.main.id
  name    = "*"
  type    = "A"
  content = var.server_ip
  ttl     = 3600
}

resource "cloudflare_dns_record" "apex_record" {
  zone_id = cloudflare_zone.main.id
  name    = "@"
  type    = "A"
  content = var.server_ip
  ttl     = 3600
}
