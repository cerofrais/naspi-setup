#!/bin/bash
# Installs and configures Samba with macOS/iOS optimizations.
# Creates a NAS user, a general share, and a Time Machine share.
# Shares are accessible at smb://<tailscale-ip>/nas (and /timemachine)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/05_setup_samba.sh"
    exit 1
fi

POOL_DIR="/srv/nas"

echo "=== [5/6] Setup Samba File Sharing ==="
echo ""

if [[ ! -d "$POOL_DIR" ]]; then
    echo "ERROR: $POOL_DIR not found. Run script 04 first."
    exit 1
fi

echo "[1/5] Installing Samba..."
apt-get install -y samba samba-common-bin avahi-daemon

# ── Create system group and user ──────────────────────────────────────────────
echo ""
echo "[2/5] Create NAS user"
echo ""
read -rp "Enter username for NAS access: " NAS_USER
if [[ -z "$NAS_USER" ]]; then
    echo "Username cannot be empty."
    exit 1
fi

if ! getent group nasusers &>/dev/null; then
    groupadd nasusers
fi

if ! id "$NAS_USER" &>/dev/null; then
    useradd -m -G nasusers -s /bin/bash "$NAS_USER"
    echo "System user '$NAS_USER' created."
else
    usermod -aG nasusers "$NAS_USER"
    echo "Added existing user '$NAS_USER' to nasusers group."
fi

echo ""
echo "Set Samba password for $NAS_USER (can differ from system password):"
smbpasswd -a "$NAS_USER"

# ── Fix share directory permissions ──────────────────────────────────────────
echo ""
echo "[3/5] Setting share permissions..."
chown -R root:nasusers "$POOL_DIR"
chmod -R 2775 "$POOL_DIR"   # setgid so new files inherit nasusers group

# ── Write smb.conf ────────────────────────────────────────────────────────────
echo "[4/5] Writing /etc/samba/smb.conf..."

# Back up original
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true

cat > /etc/samba/smb.conf << SMBCONF
[global]
    workgroup = WORKGROUP
    server string = NAS Pi 5
    server role = standalone server

    # Logging
    log file = /var/log/samba/log.%m
    max log size = 50
    logging = file

    # Security
    security = user
    passdb backend = tdbsam
    map to guest = never

    # macOS / iOS compatibility via vfs_fruit
    # Handles Mac metadata, resource forks, extended attributes correctly
    vfs objects = catia fruit streams_xattr
    fruit:metadata = stream
    fruit:model = MacSamba
    fruit:posix_rename = yes
    fruit:veto_appledouble = no
    fruit:wipe_intentionally_left_blank_rfork = yes
    fruit:delete_empty_adfiles = yes

    # Hide macOS noise files from other clients
    veto files = /.DS_Store/._.*/
    delete veto files = yes

    # Performance
    socket options = TCP_NODELAY IPTOS_LOWDELAY
    read raw = yes
    write raw = yes
    use sendfile = yes
    aio read size = 16384
    aio write size = 16384

    # Encoding
    unix charset = UTF-8

    # Disable printing
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes

# ── Main NAS share ────────────────────────────────────────────────────────────
[nas]
    comment = NAS Storage
    path = ${POOL_DIR}
    browseable = yes
    read only = no
    valid users = @nasusers
    create mask = 0664
    directory mask = 0775
    force group = nasusers

# ── Time Machine backup share ─────────────────────────────────────────────────
[timemachine]
    comment = Time Machine Backups
    path = ${POOL_DIR}/timemachine
    browseable = yes
    read only = no
    valid users = @nasusers
    create mask = 0660
    directory mask = 0770
    force group = nasusers
    # Enable Time Machine protocol support
    fruit:time machine = yes
    # Set a quota (bytes). 0 = unlimited. Example: 500GB = 536870912000
    fruit:time machine max size = 0
SMBCONF

# ── Enable Avahi (mDNS) for auto-discovery on macOS ──────────────────────────
# This makes the NAS appear in Finder sidebar automatically
cat > /etc/avahi/services/samba.service << 'AVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=RackMac</txt-record>
  </service>
  <service>
    <type>_adisk._tcp</type>
    <port>9</port>
    <txt-record>dk0=adVF=0x83,adVN=timemachine</txt-record>
    <txt-record>sys=waMa=0,adVF=0x100</txt-record>
  </service>
</service-group>
AVAHI

echo "[5/5] Enabling and starting services..."
systemctl enable --now smbd nmbd avahi-daemon
systemctl restart smbd nmbd avahi-daemon

echo ""
echo "Testing Samba config..."
testparm -s 2>&1 | tail -5

echo ""
echo "========================================================"
echo " Samba is running."
echo ""
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo " Connect from macOS (Finder > Go > Connect to Server):"
echo "   smb://${TAILSCALE_IP}/nas"
echo "   smb://${LOCAL_IP}/nas        (local network only)"
echo ""
echo " Time Machine:"
echo "   System Settings > General > Time Machine > Add Backup Disk"
echo "   Select 'timemachine' share on this server"
echo ""
echo " iPhone (Files app > ... > Connect to Server):"
echo "   smb://${TAILSCALE_IP}/nas"
echo ""
echo " Username: ${NAS_USER}"
echo " Password: (the Samba password you just set)"
echo "========================================================"
echo ""
echo "Next step: sudo bash scripts/06_install_cockpit.sh"
