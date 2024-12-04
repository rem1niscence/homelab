#!/bin/bash

# This script restarts the qBittorrent process running inside a pod in a Kubernetes cluster.
# The reason for it is that qbittorrent has an issue with gluetin reloading the vpn configuration
# and the only way to reload it is to restart qbittorrent while keeping the vpn container running
# So this script sends a SIGHUP signal to the qbittorrent process to reload the vpn configuration.

# Define the namespace
NAMESPACE="qbittorrent"
CONTAINER="qbittorrent"

# Get the name of the only pod in the namespace
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')

# Check if a pod name was found
if [ -z "$POD_NAME" ]; then
    echo "Error: No pod found in namespace $NAMESPACE"
    exit 1
fi

echo "Pod Name: $POD_NAME"

# Command of the process to restart
PROCESS_NAME="/app/qbittorrent-nox --profile=/app --webui-port=8080"

PROCESS_PID=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -c $CONTAINER -- sh -c "pgrep -f '$PROCESS_NAME'")

# # Check if the process was found
if [ -z "$PROCESS_PID" ]; then
    echo "Error: No process named '$PROCESS_NAME' found in pod $POD_NAME"
    exit 1
fi

echo "Process PID: $PROCESS_PID"

# Send SIGHUP to the process inside the pod
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c $CONTAINER -- sh -c "kill -HUP $PROCESS_PID"

if [ $? -eq 0 ]; then
    echo "SIGHUP signal sent to process '$PROCESS_NAME' (PID: $PROCESS_PID) in pod $POD_NAME"
else
    echo "Failed to send SIGHUP signal to process '$PROCESS_NAME' in pod $POD_NAME"
fi
