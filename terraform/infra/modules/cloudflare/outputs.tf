output "zone" {
  description = "cloudflare zone"
  value = {
    id   = cloudflare_zone.main.id
    name = cloudflare_zone.main.name
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
