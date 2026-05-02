#!/bin/bash
# Installs Cockpit — a browser-based web UI for monitoring the Pi,
# managing storage (disks, filesystems, RAID), services, and logs.
# Access it at http://<tailscale-ip>:9090
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/06_install_cockpit.sh"
    exit 1
fi

echo "=== [6/6] Install Cockpit Web UI ==="
echo ""

echo "[1/3] Installing Cockpit and storage plugin..."
apt-get install -y cockpit cockpit-storaged

echo "[2/3] Enabling Cockpit..."
systemctl enable --now cockpit.socket

# Allow Cockpit through if ufw is active
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    ufw allow 9090/tcp comment "Cockpit web UI"
    echo "Opened port 9090 in ufw."
fi

echo "[3/3] Cockpit is ready."
echo ""

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo "========================================================"
echo " Cockpit Web UI"
echo ""
echo "  Via Tailscale: https://${TAILSCALE_IP}:9090"
echo "  Local network: https://${LOCAL_IP}:9090"
echo ""
echo " Log in with your Pi OS user credentials (naspi or root)."
echo " Ignore the self-signed TLS certificate warning."
echo ""
echo " Features available:"
echo "   Storage  → manage disks, filesystems, RAID"
echo "   Services → start/stop/monitor services"
echo "   Logs     → system journal"
echo "   Terminal → browser-based SSH"
echo "========================================================"
