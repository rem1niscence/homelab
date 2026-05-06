# load SOPS encrypted file into the module
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

locals {
  ssh_keys = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["keys"])

  user_data_cloud_init = templatefile("${path.module}/templates/cloud-init.tpl", {
    admin_username      = data.sops_file.secrets.data["ssh.vm_username"]
    admin_password_hash = data.sops_file.secrets.data["ssh.vm_password_hash"]
    ssh_authorized_keys = values(nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["keys"]))
  })

  local_agents        = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["local_agents"])
  local_control_plane = nonsensitive(yamldecode(data.sops_file.secrets.raw)["ssh"]["local_control_plane"])
}

module "cloudflare" {
  source     = "./modules/cloudflare"
  account_id = data.sops_file.secrets.data["cloudflare.account_id"]
}

module "hetzner" {
  source    = "./modules/hetzner"
  ssh_keys  = local.ssh_keys
  user_data = local.user_data_cloud_init
}

# --- Ansible inventory ---

resource "ansible_host" "vm" {
  name   = values(module.hetzner.server)[0].ip
  groups = ["agent"]

  variables = {
    ansible_user            = data.sops_file.secrets.data["ssh.vm_username"]
    ansible_become_password = data.sops_file.secrets.data["ssh.vm_password"]
  }
}

resource "ansible_host" "local-agents" {
  for_each = local.local_agents
  name     = each.value.ip
  groups   = ["agent"]

  variables = {
    ansible_user            = each.value.username
    ansible_become_password = each.value.password
  }
}

resource "ansible_host" "control-plane" {
  for_each = local.local_control_plane
  name     = each.value.ip
  groups   = ["server"]

  variables = {
    ansible_user            = each.value.username
    ansible_become_password = each.value.password
    extra_server_args = [
      "--flannel-backend=none",
      "--disable-network-policy",
      "--secrets-encryption",
    ]
  }
}

resource "ansible_group" "server" {
  name = "server"
}

resource "ansible_group" "agent" {
  name = "agent"
}

resource "ansible_group" "k3s_cluster" {
  name     = "k3s_cluster"
  children = ["agent"]

  variables = {
    api_endpoint    = values(local.local_control_plane)[0].ip
    token           = data.sops_file.secrets.data["ansible.k3s_token"]
    cluster_context = "homelab-k3s"
    k3s_version     = "v1.35.3+k3s1"
    helm_version    = "v3.20.2"
    user_kubectl    = true
  }
}
