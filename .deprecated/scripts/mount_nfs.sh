#!/bin/bash

# Check if the user is root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <IP_ADDRESS> <NFS_PATH> <MOUNT_POINT>"
  exit 1
fi

IP_ADDRESS="$1"
NFS_PATH="$2"
MOUNT_POINT="$3"

# Create the mount point if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Add the entry to /etc/fstab
echo "$IP_ADDRESS:$NFS_PATH $MOUNT_POINT nfs4 soft,timeo=30,retrans=2 0 0" >> /etc/fstab

# Mount all filesystems according to fstab
mount -a

# Check if the mount was successful
if mountpoint -q "$MOUNT_POINT"; then
  echo "The NFS mount was successful."
else
  echo "The NFS mount failed. Please check your settings."
  exit 1
fi
