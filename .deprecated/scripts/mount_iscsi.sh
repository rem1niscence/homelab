#!/bin/bash

set -e  # Exit on any command failure

# Check if the correct number of parameters are provided
if [ $# -ne 4 ]; then
  echo "Usage: $0 <IP_ADDRESS> <TARGET_NAME> <MOUNT_PATH> <FORMAT>"
  exit 1
fi

# Obtain the values from parameters
IP_ADDRESS="$1"
TARGET_NAME="$2"
MOUNT_PATH="$3"
FORMAT="$4"

# Check if any variable is empty
if [ -z "$IP_ADDRESS" ] || [ -z "$TARGET_NAME" ] || [ -z "$MOUNT_PATH" ] || [ -z "$FORMAT" ]; then
    echo "Error: Not all values provided"
    exit 1
fi

# start service in case it hasn't already
service iscsid start

# Capture devices before login
DEVICES_BEFORE=$(lsblk -ndo NAME)

# Discover the target
iscsiadm -m discovery -t sendtargets -p $IP_ADDRESS

# Log in to the target
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --login

# Automatic reconnect
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --op update -n node.startup -v automatic

# Wait for the device to be available
sleep 5

# Capture devices after login
DEVICES_AFTER=$(lsblk -ndo NAME)

# Find the new device
DEVICE=$(comm -13 <(echo "$DEVICES_BEFORE" | sort) <(echo "$DEVICES_AFTER" | sort) | grep '^sd' | head -n1)

if [ -z "$DEVICE" ]; then
    echo "Error: Could not determine iSCSI device"
    exit 1
fi

# Unmount the device if it's mounted
umount /dev/$DEVICE || true  # We use "|| true" to prevent the script from exiting if the device is not mounted.

if [ "$FORMAT" == "true" ]; then
  # Use parted to create a partition table and partition
  parted -s /dev/$DEVICE mklabel msdos
  parted -s /dev/$DEVICE mkpart primary ext4 0% 100%

  # Wait for the kernel to recognize the new partition
  sleep 5

  # Format the partition with ext4
  mkfs.ext4 /dev/${DEVICE}1
fi

# Create the mount point
mkdir -p $MOUNT_PATH

# Mount the filesystem
mount /dev/${DEVICE}1 $MOUNT_PATH

# Add to /etc/fstab for persistence across reboots
# But currently doesn't work for me, gotta fix.
# echo "/dev/${DEVICE}1 $MOUNT_PATH ext4 defaults,_netdev 0 0" >> /etc/fstab

echo "iSCSI target is mounted at $MOUNT_PATH"

# logout of all sessions
# sudo iscsiadm --mode node --logoutall=all

# Place this on
# /usr/bin
# Remember to set this as root owner:
# sudo chown root:root mount_iscsi
