resource "ansible_host" "vm" {
  name   = var.hetzner_ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = var.hetzner_vm.username
    ansible_become_password = var.hetzner_vm.password
    ts_extra_args           = "--accept-routes"
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=vm",
      "--node-label platform.io/vm-storage=true",
      "--node-ip=${var.hetzner_vm.ts_ip}"
    ])
  }
}

resource "ansible_host" "amd" {
  name   = var.server_amd.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = var.server_amd.username
    ansible_become_password = var.server_amd.password
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
  name   = var.server_pi_2.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = var.server_pi_2.username
    ansible_become_password = var.server_pi_2.password
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=pi",
      "--node-label platform.io/pi=pi-2",
    ])
  }
}

resource "ansible_host" "pi-3" {
  name   = var.server_pi_3.ip
  groups = ["agent", "tailscale"]

  variables = {
    ansible_user            = var.server_pi_3.username
    ansible_become_password = var.server_pi_3.password
    extra_agent_args = join(" ", [
      "--node-label platform.io/type=pi",
      "--node-label platform.io/pi=pi-3",
    ])
  }
}

resource "ansible_host" "nuc" {
  name   = var.server_nuc.ip
  groups = ["server", "tailscale"]

  variables = {
    ansible_user            = var.server_nuc.username
    ansible_become_password = var.server_nuc.password
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
  name   = var.server_pi_1.ip
  groups = ["tailscale"]

  variables = {
    ansible_user            = var.server_pi_1.username
    ansible_become_password = var.server_pi_1.password
    ts_routes               = join(",", var.server_pi_1.ts_routes)
  }
}

resource "ansible_host" "oracle_vm" {
  name   = var.oracle_ip
  groups = ["tunnel"]

  variables = {
    ansible_user             = var.oracle_vm.username
    ansible_become_password  = var.oracle_vm.password
    frp_token                = var.frp_token
    frp_dashboard_username   = var.frp_dashboard_username
    frp_dashboard_password   = var.frp_dashboard_password
    frp_dashboard_secret_key = var.frp_dashboard_secret_key
    frp_extra_ports          = var.frp_extra_ports
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
    api_endpoint    = var.server_nuc.ip
    token           = var.k3s_token
    cluster_context = "homelab-k3s"
    k3s_version     = "v1.35.4+k3s1"
    helm_version    = "v3.20.2"
    user_kubectl    = true
  }
}

resource "ansible_group" "tailscale" {
  name = "tailscale"

  variables = {
    tailscale_auth_key = var.tailscale_auth_key
  }
}

resource "ansible_group" "tunnel" {
  name = "tunnel"
}
