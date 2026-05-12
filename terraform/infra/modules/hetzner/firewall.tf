resource "hcloud_firewall" "k8s_firewall" {
  name = "k8s_firewall"

  rule {
    # SSH access
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # HTTP
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # HTTPS
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # ICMP for cluster ping, health checks, and diagnostics
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # K3s supervisor and Kubernetes API Server
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # Kubelet metrics and API
    direction  = "in"
    protocol   = "tcp"
    port       = "10250"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # K3S HA with Embedded etcd
    direction  = "in"
    protocol   = "tcp"
    port       = "2379-2380"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # Cilium VXLAN tunnel traffic
    direction  = "in"
    protocol   = "udp"
    port       = "8472"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # Node Exporter metrics
    direction  = "in"
    protocol   = "tcp"
    port       = "9100"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # validator P2P
    direction  = "in"
    protocol   = "tcp"
    port       = "9001"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    # validator P2P
    direction  = "in"
    protocol   = "tcp"
    port       = "9001-9002"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
