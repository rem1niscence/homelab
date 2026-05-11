resource "hcloud_ssh_key" "keys" {
  for_each   = var.ssh_keys
  name       = each.key
  public_key = each.value
}

resource "hcloud_server" "server" {
  server_type = "cax21"
  image       = "ubuntu-24.04"
  location    = "fsn1"
  name        = "hetzner-fsn1-1"
  ssh_keys    = values(hcloud_ssh_key.keys)[*].id
  user_data   = var.user_data
  labels = {
    managed-by = "terraform"
    role       = "worker"
  }
}
