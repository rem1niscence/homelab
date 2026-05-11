output "server" {
  description = "hetzner k3s server"
  value = {
    (hcloud_server.server.name) = {
      ip       = hcloud_server.server.ipv4_address
      user     = "root"
      location = hcloud_server.server.location
      id       = hcloud_server.server.id
      provider = "hetzner"
    }
  }
}
