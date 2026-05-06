output "zones" {
  description = "cloudflare zones"
  value = {
    for k, z in cloudflare_zone.main : k => {
      id   = z.id
      name = z.name
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
