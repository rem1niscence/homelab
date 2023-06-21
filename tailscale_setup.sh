#!/bin/bash

curl -fsSL https://tailscale.com/install.sh | sh

# start tailscale using the configured DNS on the admin panel
sudo tailscale up --accept-dns=false

