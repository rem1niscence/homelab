#!/bin/bash

# logout of all sessions
# sudo iscsiadm --mode node --logoutall=all

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

# attempt to logout of any existing session for this target before (re)connecting
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --logout 2>/dev/null || true

iscsiadm -m discovery -t sendtargets -p $IP_ADDRESS
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --login
iscsiadm -m node -T $TARGET_NAME -p $IP_ADDRESS:3260 --op update -n node.startup -v automatic

# resolve the device using the stable by-path symlink to avoid misidentification
# when discovery triggers reconnection of other targets simultaneously
BY_PATH="/dev/disk/by-path/ip-${IP_ADDRESS}:3260-iscsi-${TARGET_NAME}-lun-0"
for i in $(seq 1 10); do
    if [ -L "$BY_PATH" ]; then
        break
    fi
    echo "waiting for by-path symlink: $BY_PATH (attempt $i)"
    sleep 2
done

if [ ! -L "$BY_PATH" ]; then
    echo "Error: by-path symlink not found: $BY_PATH"
    exit 1
fi

DEVICE=$(basename "$(readlink -f "$BY_PATH")")

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
