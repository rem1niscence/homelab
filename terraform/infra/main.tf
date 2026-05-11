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

# --- Ansible inventory ---

resource "ansible_host" "vm" {
  name   = values(module.hetzner.server)[0].ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = local.server_vm.username
    ansible_become_password = local.server_vm.password
    ts_extra_args           = "--accept-routes"
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=vm",
      "--node-label platform.io/remote-storage=true",
      "--node-ip=${local.server_vm.ts_ip}"
    ])
  }
}

resource "ansible_host" "amd" {
  name   = local.server_amd.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = local.server_amd.username
    ansible_become_password = local.server_amd.password
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=secondary",
      "--node-label platform.io/local-storage=true",
      "--node-label platform.io/remote-storage=true"
    ])
    iscsi_mounts = [
      {
        name       = "local"
        ip         = "192.168.0.95"
        target     = "iscsi-main-drive:longhorn.ssd-2tb"
        mount_path = "/var/lib/longhorn-local"
        format     = "false"
      },
      {
        name       = "remote"
        ip         = "192.168.0.95"
        target     = "iscsi-main-drive:longhorn-remote.ssd-2tb"
        mount_path = "/var/lib/longhorn-remote"
        format     = "false"
      }
    ]
  }
}

resource "ansible_host" "pi-2" {
  name   = local.server_pi_2.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = local.server_pi_2.username
    ansible_become_password = local.server_pi_2.password
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=pi",
      "--node-label platform.io/pi=pi-2",
    ])
  }
}

resource "ansible_host" "pi-3" {
  name   = local.server_pi_3.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = local.server_pi_3.username
    ansible_become_password = local.server_pi_3.password
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=pi",
      "--node-label platform.io/pi=pi-3",
    ])
  }
}

resource "ansible_host" "nuc" {
  name   = local.server_nuc.ip
  groups = ["server", "tailscale"]

  variables = {
    ansible_user            = local.server_nuc.username
    ansible_become_password = local.server_nuc.password
    extra_server_args = join(" ", [
      "--node-label platform.io/local-storage=true",
      "--flannel-backend=none",
      "--disable-network-policy",
      "--disable servicelb",
      "--disable-kube-proxy",
      "--secrets-encryption",
      "--node-label platform.io/type=main",
      "--cluster-cidr=10.42.0.0/16",
      "--service-cidr=10.43.0.0/16"
    ])
    iscsi_mounts = [
      {
        name       = "local"
        ip         = "192.168.0.95"
        target     = "iscsi-main-drive:longhorn.main-drive"
        mount_path = "/var/lib/longhorn-local"
        format     = "false"
      },
    ]
  }
}

resource "ansible_host" "pi-1" {
  name   = local.server_pi_1.ip
  groups = ["tailscale"]

  variables = {
    ansible_user            = local.server_pi_1.username
    ansible_become_password = local.server_pi_1.password
    ts_routes               = join(",", local.server_pi_1.ts_routes)
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
  children = ["server", "agent"]

  variables = {
    api_endpoint    = local.server_nuc.ip
    token           = data.sops_file.secrets.data["ansible.k3s_token"]
    cluster_context = "homelab-k3s"
    k3s_version     = "v1.35.4+k3s1"
    helm_version    = "v3.20.2"
    user_kubectl    = true
  }
}

resource "ansible_group" "tailscale" {
  name = "tailscale"

  variables = {
    tailscale_auth_key = data.sops_file.secrets.data["ansible.tailscale.auth_key"]
  }
}
