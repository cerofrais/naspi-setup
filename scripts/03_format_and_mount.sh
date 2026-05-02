#!/bin/bash
# Detects SATA drives, formats them with ext4, and mounts them at /mnt/disk1..N.
# DESTRUCTIVE if you choose to format — existing data will be wiped.
# Drives are added to /etc/fstab so they survive reboots.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/03_format_and_mount.sh"
    exit 1
fi

echo "=== [3/6] Format and Mount Drives ==="
echo ""

# Find all physical drives, excluding the SD card (mmcblk) and loop devices
DRIVES=()
while IFS= read -r dev; do
    DRIVES+=("$dev")
done < <(lsblk -dpno NAME,TYPE | awk '$2=="disk" && $1!~/mmcblk|loop|zram/ {print $1}')

if [[ ${#DRIVES[@]} -eq 0 ]]; then
    echo "ERROR: No SATA drives detected."
    echo ""
    echo "If you just rebooted after running script 01, wait a moment and retry."
    echo "Check drives with: lsblk -o NAME,SIZE,TYPE,VENDOR,MODEL"
    echo ""
    echo "If still empty, verify the Penta SATA HAT is seated correctly and"
    echo "check: cat /boot/firmware/config.txt | grep pciex1"
    exit 1
fi

echo "Detected drives:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,VENDOR,MODEL "${DRIVES[@]}"
echo ""

DISK_NUM=1
MOUNTED_DISKS=()

for DRIVE in "${DRIVES[@]}"; do
    SIZE=$(lsblk -dno SIZE "$DRIVE")
    FSTYPE=$(lsblk -dno FSTYPE "$DRIVE" 2>/dev/null || echo "")
    echo "----------------------------------------"
    echo "Drive: $DRIVE  Size: $SIZE  Current FS: ${FSTYPE:-none}"

    # Check for existing partitions with data
    PARTITIONS=$(lsblk -no NAME "$DRIVE" | tail -n +2)
    if [[ -n "$PARTITIONS" ]]; then
        echo "Existing partitions:"
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DRIVE"
    fi

    echo ""
    if [[ -n "$FSTYPE" ]] || [[ -n "$PARTITIONS" ]]; then
        echo "WARNING: This drive has existing data/filesystem!"
        read -rp "Format $DRIVE and WIPE ALL DATA? (yes/no): " CONFIRM
    else
        read -rp "Format $DRIVE as ext4? (yes/no): " CONFIRM
    fi

    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Skipping $DRIVE"
        echo ""
        # If it already has a usable filesystem, try to mount it anyway
        if [[ -n "$FSTYPE" ]]; then
            MOUNTPOINT="/mnt/disk${DISK_NUM}"
            UUID=$(blkid -s UUID -o value "$DRIVE" 2>/dev/null || echo "")
            if [[ -n "$UUID" ]]; then
                mkdir -p "$MOUNTPOINT"
                if ! grep -q "$UUID" /etc/fstab; then
                    echo "UUID=$UUID  $MOUNTPOINT  $FSTYPE  defaults,nofail  0  2" >> /etc/fstab
                    echo "Added existing $DRIVE ($FSTYPE) to fstab at $MOUNTPOINT"
                fi
                mount "$MOUNTPOINT" 2>/dev/null || mount "$DRIVE" "$MOUNTPOINT" 2>/dev/null || true
                MOUNTED_DISKS+=("$MOUNTPOINT")
                (( DISK_NUM++ ))
            fi
        fi
        continue
    fi

    LABEL="nas-disk${DISK_NUM}"
    MOUNTPOINT="/mnt/disk${DISK_NUM}"

    echo "Formatting $DRIVE with ext4 (label: $LABEL)..."
    # Wipe any existing partition table
    wipefs -af "$DRIVE"
    # Create a single partition spanning the whole drive
    parted -s "$DRIVE" mklabel gpt
    parted -s "$DRIVE" mkpart primary ext4 0% 100%
    sleep 1  # let kernel see the new partition
    PARTITION="${DRIVE}1"
    # Wait for partition to appear
    for i in $(seq 1 10); do
        [[ -b "$PARTITION" ]] && break
        sleep 1
    done
    mkfs.ext4 -L "$LABEL" "$PARTITION"

    UUID=$(blkid -s UUID -o value "$PARTITION")
    mkdir -p "$MOUNTPOINT"

    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID  $MOUNTPOINT  ext4  defaults,nofail  0  2" >> /etc/fstab
    fi

    mount "$MOUNTPOINT"
    echo "Mounted $PARTITION at $MOUNTPOINT"
    MOUNTED_DISKS+=("$MOUNTPOINT")
    (( DISK_NUM++ ))
    echo ""
done

echo "----------------------------------------"
echo ""
if [[ ${#MOUNTED_DISKS[@]} -eq 0 ]]; then
    echo "No drives were mounted. Check the output above."
    exit 1
fi

echo "Mounted disks:"
for MP in "${MOUNTED_DISKS[@]}"; do
    df -h "$MP" | tail -1
done

echo ""
echo "Drive setup complete."
echo "Next step: sudo bash scripts/04_setup_mergerfs.sh"
