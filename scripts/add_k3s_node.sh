#!/bin/bash

if [[ -z "${IP}" ]] || [[ -z "${TOKEN}" ]]; then
    echo "Environment variables IP and TOKEN must be set"
    exit 1
else
    curl -sfL https://get.k3s.io | K3S_URL=https://$(IP):6443 K3S_TOKEN=$(TOKEN) sh -s -
fi
