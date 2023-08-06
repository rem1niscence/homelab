#!/bin/bash

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

# Discover the target
iscsiadm -m discovery -t sendtargets -p $IP_ADDRESS

# Log in to the target
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --login


# Wait for the device to be available
sleep 5

# Find the device name
DEVICE=$(ls /sys/class/block | grep -E '^sd[a-z]$' | tail -n1)

# Unmount the device if it's mounted
umount /dev/$DEVICE

if [ "$FORMAT" == "true" ]; then
  # Create a new partition and format it
  (
    echo o
    echo n
    echo p
    echo 1
    echo
    echo
    echo w
  ) | fdisk /dev/$DEVICE

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
# cho "/dev/${DEVICE}1 $MOUNT_PATH ext4 defaults,_netdev 0 0" >> /etc/fstab

echo "iSCSI target is mounted at $MOUNT_PATH"

# logout of all sessions
# sudo iscsiadm --mode node --logoutall=all

# Place this on
# /usr/bin
# Remember to set this as root owner
