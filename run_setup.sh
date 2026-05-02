#!/bin/bash
# Master setup script for Raspberry Pi 5 NAS
# Runs all setup phases in order, pausing where a reboot or manual step is needed.
#
# Stack: Samba + mergerfs + Tailscale + Cockpit (web UI)
# Target OS: Debian 13 Trixie (Raspberry Pi OS Lite 64-bit)
#
# Run order:
#   sudo bash run_setup.sh          <- detects phase automatically
#
# Or run individual scripts:
#   sudo bash scripts/01_enable_pcie_sata.sh
#   sudo reboot
#   sudo bash scripts/02_install_tailscale.sh
#   sudo tailscale up --hostname=nas-pi   (manual auth step)
#   sudo bash scripts/03_format_and_mount.sh
#   sudo bash scripts/04_setup_mergerfs.sh
#   sudo bash scripts/05_setup_samba.sh
#   sudo bash scripts/06_install_cockpit.sh

set -euo pipefail
cd "$(dirname "$0")"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash run_setup.sh"
    exit 1
fi

STATE_FILE="/var/lib/nas-setup-phase"

get_phase() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "1"
}

set_phase() {
    echo "$1" > "$STATE_FILE"
}

PHASE=$(get_phase)

print_header() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Pi 5 NAS Setup — Phase $PHASE              ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
}

print_header

case "$PHASE" in
1)
    echo "Phase 1: Enable PCIe SATA HAT"
    echo ""
    bash scripts/01_enable_pcie_sata.sh

    # Check if pciex1 was already active (drives present = skip reboot)
    DRIVES=$(lsblk -dpno NAME,TYPE | awk '$2=="disk" && $1!~/mmcblk|loop/ {print $1}')
    if [[ -n "$DRIVES" ]]; then
        echo ""
        echo "Drives already detected — skipping reboot, continuing to Phase 2."
        set_phase 2
        exec bash "$0"
    else
        set_phase 2
        echo ""
        echo "Please reboot now: sudo reboot"
        echo "Then run again:    sudo bash run_setup.sh"
    fi
    ;;

2)
    echo "Phase 2: Install Tailscale"
    echo ""
    bash scripts/02_install_tailscale.sh
    set_phase 3
    echo ""
    echo "─────────────────────────────────────────────"
    echo "PAUSE: Authenticate Tailscale before continuing."
    echo ""
    echo "  sudo tailscale up --hostname=nas-pi"
    echo ""
    echo "Open the URL shown in your browser, approve the device,"
    echo "then run: sudo bash run_setup.sh"
    echo "─────────────────────────────────────────────"
    ;;

3)
    # Verify Tailscale is authenticated
    if ! tailscale ip -4 &>/dev/null 2>&1; then
        echo "Tailscale not yet authenticated."
        echo "Run: sudo tailscale up --hostname=nas-pi"
        echo "Then: sudo bash run_setup.sh"
        exit 1
    fi
    echo "Phase 3: Format drives, pool with mergerfs, configure Samba, install Cockpit"
    echo ""
    bash scripts/03_format_and_mount.sh
    bash scripts/04_setup_mergerfs.sh
    bash scripts/05_setup_samba.sh
    bash scripts/06_install_cockpit.sh
    set_phase done
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                  SETUP COMPLETE                       ║"
    echo "╠══════════════════════════════════════════════════════╣"
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
    printf "║  NAS share:   smb://%-33s║\n" "${TAILSCALE_IP}/nas "
    printf "║  Time Machine: smb://%-32s║\n" "${TAILSCALE_IP}/timemachine "
    printf "║  Cockpit UI:  https://%-31s║\n" "${TAILSCALE_IP}:9090 "
    echo "╚══════════════════════════════════════════════════════╝"
    ;;

done)
    echo "Setup is already complete."
    echo ""
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<run: tailscale ip -4>")
    echo "  NAS share:    smb://${TAILSCALE_IP}/nas"
    echo "  Time Machine: smb://${TAILSCALE_IP}/timemachine"
    echo "  Cockpit:      https://${TAILSCALE_IP}:9090"
    echo ""
    echo "To re-run a specific step: sudo bash scripts/0N_<name>.sh"
    ;;

*)
    echo "Unknown phase '$PHASE'. Resetting to phase 1."
    set_phase 1
    exec bash "$0"
    ;;
esac
