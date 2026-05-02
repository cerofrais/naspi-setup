#!/bin/bash
# Enables the Pi 5's external PCIe port so the Penta SATA HAT drives appear.
# Must be run before any other script. Requires a reboot to take effect.
set -euo pipefail

CONFIG=/boot/firmware/config.txt

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash scripts/01_enable_pcie_sata.sh"
    exit 1
fi

echo "=== [1/6] Enable PCIe for Penta SATA HAT ==="
echo ""

# Check for any pciex1 variant (pciex1, pciex1_gen=2, pciex1_gen=3)
if grep -qE "dtparam=pciex1" "$CONFIG"; then
    echo "PCIe already enabled in $CONFIG:"
    grep "pciex1" "$CONFIG"
else
    # Append under the [all] section at end of file
    cat >> "$CONFIG" << 'EOF'

# External PCIe port - required for Penta SATA HAT
dtparam=pciex1
dtparam=pciex1_gen=3
EOF
    echo "Added PCIe config to $CONFIG"
fi

echo ""
echo "Current drives (before reboot - expect none from SATA HAT):"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null

echo ""
echo "====================================================="
echo " REBOOT REQUIRED"
echo " Run: sudo reboot"
echo " After reboot, continue with:"
echo "   sudo bash scripts/02_install_tailscale.sh"
echo "====================================================="
