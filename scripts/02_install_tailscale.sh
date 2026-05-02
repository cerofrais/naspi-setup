#!/bin/bash
# Installs Tailscale and configures IP forwarding.
# You will need to authenticate via a browser URL shown at the end.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/02_install_tailscale.sh"
    exit 1
fi

echo "=== [2/6] Install Tailscale ==="
echo ""

if command -v tailscale &>/dev/null; then
    echo "Tailscale already installed: $(tailscale version | head -1)"
    echo ""
    tailscale status 2>/dev/null || true
    echo ""
    echo "To re-authenticate: sudo tailscale up --hostname=nas-pi"
    exit 0
fi

echo "[1/3] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "[2/3] Enabling IP forwarding..."
cat > /etc/sysctl.d/99-tailscale.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf

echo "[3/3] Starting Tailscale service..."
systemctl enable --now tailscaled

echo ""
echo "====================================================="
echo " MANUAL STEP: Authenticate Tailscale"
echo ""
echo " Run this command, then open the URL in your browser:"
echo "   sudo tailscale up --hostname=nas-pi"
echo ""
echo " After auth, your Tailscale IP will be shown with:"
echo "   tailscale ip -4"
echo ""
echo " Make sure your Mac and iPhone also have Tailscale"
echo " installed and are in the same Tailscale network."
echo "====================================================="
echo ""
echo "Next step after auth: sudo bash scripts/03_format_and_mount.sh"
