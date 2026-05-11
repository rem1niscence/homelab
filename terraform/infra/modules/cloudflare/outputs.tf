output "zones" {
  description = "cloudflare zones keyed by domain name"
  value = {
    for domain, zone in cloudflare_zone.main : domain => {
      id   = zone.id
      name = zone.name
    }
  }
}

output "buckets" {
  description = "cloudflare r2 buckets"
  value = {
    (cloudflare_r2_bucket.terraform-bucket.name) = {
      id       = cloudflare_r2_bucket.terraform-bucket.id
      location = cloudflare_r2_bucket.terraform-bucket.location
    }
  }
}
