#!/usr/bin/env bash
set -euo pipefail

### CONFIGURATION (set these before running)
# NODE_ROLE: "server" (master), "lan-agent", or "remote-agent"
# MASTER_LAN_IP: LAN IP of the control-plane server (required for agents)
# MASTER_TAILSCALE_IP: Tailscale IP of the control-plane server (required for remote agents)
# LAN_IP: Node's LAN IP (empty for remote agents)
# TAILSCALE_IP: Node's Tailscale IP (required)
# K3S_TOKEN: K3s cluster join token (required for agents)

### Example:
# NODE_ROLE=server MASTER_LAN_IP=192.168.1.10 MASTER_TAILSCALE_IP=100.x.x.x LAN_IP=192.168.1.10 TAILSCALE_IP=100.x.x.x ./install_k3s.sh

if [[ -z "${NODE_ROLE:-}" || -z "${TAILSCALE_IP:-}" ]]; then
    echo "ERROR: NODE_ROLE and TAILSCALE_IP must be set."
    exit 1
fi

if [[ "$NODE_ROLE" != "server" && -z "${K3S_TOKEN:-}" ]]; then
    echo "ERROR: K3S_TOKEN must be set for agents."
    exit 1
fi

# using flannel-backend=host-gw as
# local traffic does not need to be encrypted
# and remote traffic is already encrypted by Tailscale
if [[ "$NODE_ROLE" == "server" ]]; then
    echo "[INFO] Installing K3s Server (control-plane)"
    curl -sfL https://get.k3s.io | sh -s - server \
        --secrets-encryption \
        --node-ip="${LAN_IP:-$TAILSCALE_IP}" \
        --node-external-ip="$TAILSCALE_IP" \
        --flannel-backend=host-gw
        # --flannel-backend=wireguard-native

elif [[ "$NODE_ROLE" == "lan-agent" ]]; then
    if [[ -z "${MASTER_LAN_IP:-}" ]]; then
        echo "ERROR: MASTER_LAN_IP must be set for LAN agents."
        exit 1
    fi
    echo "[INFO] Installing K3s LAN Agent"
    curl -sfL https://get.k3s.io | \
        K3S_URL="https://${MASTER_LAN_IP}:6443" \
        K3S_TOKEN="$K3S_TOKEN" \
        sh -s - agent \
        --node-ip="$LAN_IP" \
        --node-external-ip="$TAILSCALE_IP"
elif [[ "$NODE_ROLE" == "remote-agent" ]]; then
    if [[ -z "${MASTER_TAILSCALE_IP:-}" ]]; then
        echo "ERROR: MASTER_TAILSCALE_IP must be set for remote agents."
        exit 1
    fi
    echo "[INFO] Installing K3s Remote Agent"
    curl -sfL https://get.k3s.io | \
        K3S_URL="https://${MASTER_TAILSCALE_IP}:6443" \
        K3S_TOKEN="$K3S_TOKEN" \
        sh -s - agent \
        --node-external-ip="$TAILSCALE_IP"
else
    echo "ERROR: NODE_ROLE must be one of: server, lan-agent, remote-agent"
    exit 1
fi

echo "[INFO] K3s installation complete for $NODE_ROLE."
