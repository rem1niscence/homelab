output "hetzner_server" {
  value = module.hetzner.server
}

output "cloudflare_zones" {
  value = module.cloudflare.zones
}

output "cloudflare_buckets" {
  value = module.cloudflare.buckets
}
