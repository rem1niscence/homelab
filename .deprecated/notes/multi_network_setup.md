# K3s + Tailscale Multi-Cloud Networking Setup

## Overview

This document summarizes the configuration and operational notes for running a K3s cluster across LAN and remote nodes connected via Tailscale, using Flannel as the CNI with WireGuard-based backends.

---

## Configuration Summary

### K3s Installation Script Parameters

- `NODE_ROLE`: Defines the node role, one of:
  - `server` (control-plane/master)
  - `lan-agent` (LAN node joining via local LAN IP)
  - `remote-agent` (Remote node joining via Tailscale IP)

- `MASTER_LAN_IP`: LAN IP of the control-plane server (required for `lan-agent`)
- `MASTER_TAILSCALE_IP`: Tailscale IP of the control-plane server (required for `remote-agent`)
- `LAN_IP`: Node's LAN IP (empty for remote nodes)
- `TAILSCALE_IP`: Node's Tailscale IP (required)
- `K3S_TOKEN`: K3s cluster join token (required for agents)

---

### Flannel Backend Selection

- Initially used `--flannel-backend=wireguard-native` on the master node.
- Observed high CPU usage in Tailscale caused by pod-to-pod traffic routed through Tailscale.
- Switched master node to `--flannel-backend=host-gw` to route pod traffic over the local network.
- After this change, pod-to-pod traffic between LAN nodes flows over the LAN interface, reducing Tailscale CPU load.

---

## Tailscale Subnet Routing

- Each node runs Tailscale in Docker.
- Each node advertises its **pod CIDR** subnet to Tailscale (e.g., `10.42.0.0/24` for `nuc`, `10.42.1.0/24` for `amd`, etc.).
- These advertised routes are approved on the Tailscale admin console.
- Each node's Tailscale client is configured with `--accept-routes=true` to accept advertised pod CIDRs.

### Important Gotchas:

- Enabling `--accept-routes=true` can cause connection loss if subnet routes conflict with existing subnet exit nodes or network settings.
- To avoid connectivity loss, temporarily disable conflicting subnet exit nodes in Tailscale or adjust route advertisements accordingly.
- Approve only the relevant advertised routes for each node in the Tailscale admin console.
- Routes advertised by multiple nodes must be unique per node; no overlapping advertised routes.
- On each node docker config, you should advertise the pod k3s CIDR subnet to Tailscale.

---

## Routing Behavior

- With pod CIDRs advertised via Tailscale and proper routing setup:
  - Pod-to-pod traffic between LAN nodes is routed locally over the LAN (not via Tailscale).
  - Pod-to-pod traffic involving remote nodes flows over Tailscale via advertised pod CIDRs.
- This setup ensures efficient local network usage and seamless remote connectivity.

---

## Summary

Use host-gw flannel backend on the master node to minimize Tailscale CPU overhead and ensure local pod traffic stays on LAN.
* Advertise pod CIDRs via Tailscale on each node, approve routes in the admin console.
* Enable --accept-routes=true carefully, ensuring no conflicts with subnet exit nodes.
* Confirm pod-to-pod traffic uses local LAN when possible and Tailscale only for remote pods.
* Use manual route additions if finer control over routing is necessary.
