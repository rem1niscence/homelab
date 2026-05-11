resource "cloudflare_zone" "main" {
  for_each = var.domains

  account = {
    id = var.account_id
  }
  name = each.key
  type = "full"
}

resource "cloudflare_dns_record" "wildcard_record" {
  for_each = var.domains

  zone_id = cloudflare_zone.main[each.key].id
  name    = "*"
  type    = "A"
  content = each.value
  ttl     = 3600
}

resource "cloudflare_dns_record" "apex_record" {
  for_each = var.domains

  zone_id = cloudflare_zone.main[each.key].id
  name    = "@"
  type    = "A"
  content = each.value
  ttl     = 3600
}
