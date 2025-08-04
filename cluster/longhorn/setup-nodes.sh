#!/bin/bash

# Disable pi-1 and pi-3 to take storage tasks
kubectl patch nodes.longhorn.io pi-1 -n longhorn --type merge -p '{"spec":{"allowScheduling":false}}'
kubectl patch nodes.longhorn.io pi-3 -n longhorn --type merge -p '{"spec":{"allowScheduling":false}}'


# Tag nodes based on their characteristics
# Tags: fast, slow, storage
kubectl patch nodes.longhorn.io pi-2 -n longhorn --type='json' -p='[{"op": "add", "path": "/spec/tags", "value": ["slow", "storage"]}]'

kubectl patch nodes.longhorn.io pi-3 -n longhorn --type='json' -p='[{"op": "add", "path": "/spec/tags", "value": ["slow"]}]'

kubectl patch nodes.longhorn.io nuc -n longhorn --type='json' -p='[{"op": "add", "path": "/spec/tags", "value": ["fast", "storage"]}]'

kubectl patch nodes.longhorn.io truenas-vm -n longhorn --type='json' -p='[{"op": "add", "path": "/spec/tags", "value": ["fast", "storage"]}]'
