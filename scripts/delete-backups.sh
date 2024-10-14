#!/bin/bash

# Default dry-run to true
dry_run=true

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) dry_run="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Get all backups that are not in the "Completed" state and process them
kubectl get backup -o json | jq '.items[] | select(.status.state != "Completed") | .metadata.name' | sed 's/"//g' | \
while read name; do
  echo "Found backup: $name"
  
  if [ "$dry_run" == "false" ]; then
    echo "Deleting backup: $name"
    kubectl delete backup $name
  else
    echo "Dry run enabled. Not deleting backup: $name"
  fi
done
