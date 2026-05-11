# load SOPS encrypted file into the module
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

locals {
  ssh_keys = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["keys"])

  user_data_cloud_init = templatefile("${path.module}/templates/cloud-init.tpl", {
    admin_username      = data.sops_file.secrets.data["ssh.vm.username"]
    admin_password_hash = data.sops_file.secrets.data["ssh.vm.password_hash"]
    ssh_authorized_keys = values(nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["keys"]))
  })

  # servers
  server_vm   = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["vm"])
  oracle_vm   = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["oracle"])
  server_nuc  = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["nuc"])
  server_amd  = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["amd"])
  server_pi_1 = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["pi-1"])
  server_pi_2 = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["pi-2"])
  server_pi_3 = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["pi-3"])
}

module "cloudflare" {
  source     = "./modules/cloudflare"
  account_id = data.sops_file.secrets.data["cloudflare.account_id"]
  domain     = nonsensitive(data.sops_file.secrets.data["server.domain"])
  server_ip  = nonsensitive(data.sops_file.secrets.data["server.ip"])
}

module "hetzner" {
  source    = "./modules/hetzner"
  ssh_keys  = local.ssh_keys
  user_data = local.user_data_cloud_init
}

module "oracle" {
  source         = "./modules/oracle-cloud"
  compartment_id = data.sops_file.secrets.data["oracle.compartment_id"]
  ssh_keys       = local.ssh_keys
  display_name   = "oracle-vm"
  user_data      = local.user_data_cloud_init
  # Ubuntu 24.04
  image_id     = "ocid1.image.oc1.iad.aaaaaaaadixs2qfdqjmauecmzcnlvvnhlw2jmxulgrmmf3e2emc56xqarj7q"
  arm_image_id = "ocid1.image.oc1.iad.aaaaaaaaccnswiekwi4w3pkmygjvfk24epduwj7uvq2smjmznu4kq6dcs27a"
}

module "ansible" {
  source = "./modules/ansible"

  hetzner_ip         = values(module.hetzner.server)[0].ip
  oracle_ip          = values(module.oracle.instance)[0].ip
  hetzner_vm         = local.server_vm
  oracle_vm          = local.oracle_vm
  server_nuc         = local.server_nuc
  server_amd         = local.server_amd
  server_pi_1        = local.server_pi_1
  server_pi_2        = local.server_pi_2
  server_pi_3        = local.server_pi_3
  k3s_token          = data.sops_file.secrets.data["ansible.k3s_token"]
  tailscale_auth_key = data.sops_file.secrets.data["ansible.tailscale.auth_key"]

  # Tunnel configuration
  frp_token                = data.sops_file.secrets.data["tunnel.frp.token"]
  frp_dashboard_username   = data.sops_file.secrets.data["tunnel.frp.dashboard_username"]
  frp_dashboard_password   = data.sops_file.secrets.data["tunnel.frp.dashboard_password"]
  frp_dashboard_secret_key = data.sops_file.secrets.data["tunnel.frp.dashboard_secret_key"]
  frp_extra_ports          = []
}
