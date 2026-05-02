#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash fix_mergerfs_pool.sh"
    exit 1
fi

echo "=== Fix mergerfs pool ==="
echo ""

# Remove the bogus swap entry for /mnt/disk1
if grep -q "fef07e1d-4fbc-4f02-8d71-d43ba032f77d" /etc/fstab; then
    sed -i '/fef07e1d-4fbc-4f02-8d71-d43ba032f77d/d' /etc/fstab
    echo "Removed bogus swap entry from /etc/fstab"
else
    echo "Bogus swap entry already gone, skipping"
fi

# Fix mergerfs line to include both disk1 and disk2
if grep -q "^/mnt/disk2  /srv/nas" /etc/fstab; then
    sed -i 's|^/mnt/disk2  /srv/nas|/mnt/disk1:/mnt/disk2  /srv/nas|' /etc/fstab
    echo "Updated mergerfs fstab entry to include /mnt/disk1"
elif grep -q "/mnt/disk1:/mnt/disk2" /etc/fstab; then
    echo "mergerfs entry already correct, skipping"
else
    echo "ERROR: Could not find mergerfs line in /etc/fstab — check manually"
    exit 1
fi

# Mount disk1
mkdir -p /mnt/disk1
if mountpoint -q /mnt/disk1; then
    echo "/mnt/disk1 already mounted"
else
    mount /mnt/disk1
    echo "Mounted /mnt/disk1"
fi

# Remount the mergerfs pool
if mountpoint -q /srv/nas; then
    umount /srv/nas
fi
mount /srv/nas
echo "Mounted /srv/nas"

echo ""
echo "Result:"
df -h /mnt/disk1 /mnt/disk2 /srv/nas
