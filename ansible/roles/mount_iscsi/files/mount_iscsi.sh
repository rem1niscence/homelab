#!/bin/bash

set -e

if [ $# -ne 4 ]; then
  echo "Usage: $0 <IP_ADDRESS> <TARGET_NAME> <MOUNT_PATH> <FORMAT>"
  exit 1
fi

IP_ADDRESS="$1"
TARGET_NAME="$2"
MOUNT_PATH="$3"
FORMAT="$4"

if [ -z "$IP_ADDRESS" ] || [ -z "$TARGET_NAME" ] || [ -z "$MOUNT_PATH" ] || [ -z "$FORMAT" ]; then
    echo "Error: Not all values provided"
    exit 1
fi

service iscsid start

# Attempt to logout of any existing session for this target before (re)connecting
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --logout 2>/dev/null || true

DEVICES_BEFORE=$(lsblk -ndo NAME)

iscsiadm -m discovery -t sendtargets -p $IP_ADDRESS
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --login
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --op update -n node.startup -v automatic

sleep 5

DEVICES_AFTER=$(lsblk -ndo NAME)

DEVICE=$(comm -13 <(echo "$DEVICES_BEFORE" | sort) <(echo "$DEVICES_AFTER" | sort) | grep '^sd' | head -n1)

if [ -z "$DEVICE" ]; then
    echo "Error: Could not determine iSCSI device"
    exit 1
fi

umount /dev/$DEVICE || true

if [ "$FORMAT" == "true" ]; then
  parted -s /dev/$DEVICE mklabel msdos
  parted -s /dev/$DEVICE mkpart primary ext4 0% 100%
  sleep 5
  mkfs.ext4 /dev/${DEVICE}1
fi

mkdir -p $MOUNT_PATH
mount /dev/${DEVICE}1 $MOUNT_PATH

echo "iSCSI target is mounted at $MOUNT_PATH"
