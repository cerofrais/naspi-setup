#!/bin/bash
# Installs mergerfs and creates a unified /srv/nas pool from all /mnt/disk* mounts.
# mergerfs presents multiple physical drives as one seamless directory —
# files are written to whichever disk has the most free space.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/04_setup_mergerfs.sh"
    exit 1
fi

echo "=== [4/6] Setup mergerfs Drive Pool ==="
echo ""

# Find all /mnt/disk* mountpoints that are actually mounted
DISKS=()
while IFS= read -r mp; do
    DISKS+=("$mp")
done < <(findmnt -rno TARGET | grep -E '^/mnt/disk[0-9]+$' | sort)

if [[ ${#DISKS[@]} -eq 0 ]]; then
    echo "ERROR: No /mnt/disk* mountpoints found."
    echo "Run script 03 first to format and mount drives."
    exit 1
fi

echo "Drives to pool:"
for D in "${DISKS[@]}"; do
    df -h "$D" | awk 'NR==2 {printf "  %s  %s total, %s used, %s free\n", $6, $2, $3, $4}'
done
echo ""

echo "[1/3] Installing mergerfs..."
apt-get install -y mergerfs

POOL_DIR="/srv/nas"
echo "[2/3] Creating pool directory at $POOL_DIR..."
mkdir -p "$POOL_DIR"

# Build the colon-separated source list for mergerfs
SOURCES=$(IFS=:; echo "${DISKS[*]}")

# mergerfs fstab entry:
#   mfs = most free space (fill disks evenly)
#   cache.files=partial = safe caching for reads
#   dropcacheonclose=true = reduce memory pressure
#   category.create=mfs = new files go to disk with most free space
FSTAB_LINE="${SOURCES}  ${POOL_DIR}  fuse.mergerfs  defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,minfreespace=5G,fsname=mergerfs  0  0"

echo "[3/3] Adding mergerfs to /etc/fstab..."
if grep -q "fuse.mergerfs" /etc/fstab; then
    # Update existing entry
    sed -i '/fuse\.mergerfs/d' /etc/fstab
    echo "Removed old mergerfs fstab entry."
fi
echo "$FSTAB_LINE" >> /etc/fstab
echo "Added mergerfs fstab entry."

# Mount now
if mountpoint -q "$POOL_DIR"; then
    umount "$POOL_DIR" 2>/dev/null || true
fi
mount "$POOL_DIR"

echo ""
echo "Pool mounted at $POOL_DIR:"
df -h "$POOL_DIR"
echo ""

# Create standard subdirectories
mkdir -p "$POOL_DIR/media"
mkdir -p "$POOL_DIR/documents"
mkdir -p "$POOL_DIR/backups"
mkdir -p "$POOL_DIR/timemachine"
chmod 775 "$POOL_DIR" "$POOL_DIR"/*

echo "Created directories: media, documents, backups, timemachine"
echo ""
echo "mergerfs pool ready at $POOL_DIR"
echo "Next step: sudo bash scripts/05_setup_samba.sh"
