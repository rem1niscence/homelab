output "hetzner_instance" {
  value = module.hetzner.server
}

output "cloudflare_zone" {
  value = module.cloudflare.zone
}

output "cloudflare_buckets" {
  value = module.cloudflare.buckets
}

output "oracle_instance" {
  value = module.oracle.instance
}
