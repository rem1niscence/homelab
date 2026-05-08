output "hetzner_server" {
  value = module.hetzner.server
}

output "cloudflare_zone" {
  value = module.cloudflare.zone
}

output "cloudflare_buckets" {
  value = module.cloudflare.buckets
}
