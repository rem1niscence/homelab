output "hetzner_instance" {
  value = module.hetzner.server
}

output "cloudflare_zones" {
  value = module.cloudflare.zones
}

output "cloudflare_buckets" {
  value = module.cloudflare.buckets
}

output "oracle_instance" {
  value = module.oracle.instance
}
