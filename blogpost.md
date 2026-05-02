# Building a Home NAS with a Raspberry Pi 5 and Penta SATA HAT

I wanted a home NAS — a network-attached storage box for backups, media, and general file access from my Mac and iPhone. Rather than buy a pre-built unit, I built one using a Raspberry Pi 5. Here is what I chose, what I ran into, and how I set it up.

---

## Hardware

- **Raspberry Pi 5 (8 GB)** — fast enough to handle Samba, a VPN, and a web UI without breaking a sweat.
- **Penta SATA HAT** — a HAT that connects up to five SATA drives to the Pi 5 via its external PCIe FFC connector. No USB adapters, no hubs — real SATA throughput.
- **Hard drives** — standard 3.5" HDDs for bulk storage.
- **Power supply** — the official Pi 5 27W USB-C PSU. The HAT has its own barrel-jack power input for the drives.

The Penta HAT uses the Pi 5's PCIe lane. By default the port runs at Gen 2. Adding one line to `/boot/firmware/config.txt` bumps it to Gen 3 for full speed:

```
dtparam=pciex1_gen=3
```

Without this line, the drives do not appear at all. This is the first thing the setup does and it requires a reboot.

---

## Why Not OpenMediaVault

The obvious choice for a Pi NAS is **OpenMediaVault (OMV)** — a polished, Debian-based NAS OS with a full web UI. I planned to use it.

The problem: I was running **Debian 13 (Trixie)**, and OMV 7 requires **Debian 12 (Bookworm)**. There is no Trixie-compatible release of OMV yet. Installing it on Trixie partially works but breaks silently in ways that are hard to debug. Rather than downgrade the OS or fight an unsupported install, I decided to build the same capabilities from individual packages that all run fine on Trixie.

---

## Software Stack

| Tool | Role |
|---|---|
| **Samba** | SMB file sharing — natively supported on macOS, iOS, Windows |
| **mergerfs** | Combines multiple physical drives into a single `/srv/nas` mount |
| **Tailscale** | WireGuard-based VPN — access the NAS from anywhere, no port forwarding |
| **Cockpit** | Browser-based web UI (port 9090) for disk management, services, and logs |

This stack covers everything OMV would have given us: shared folders, pooled storage, remote access, and a monitoring dashboard.

### Samba
Samba is configured with macOS optimizations (`vfs_fruit`, `mdnsresponder-publish = yes`) so the NAS shows up in Finder's sidebar. There are two shares: a general `nas` share and a `timemachine` share for macOS backups.

### mergerfs
mergerfs presents all mounted drives (`/mnt/disk1`, `/mnt/disk2`, …) as a single `/srv/nas` directory. New files are written to whichever disk has the most free space. Adding a new drive is as simple as mounting it and updating the mergerfs fstab entry. No RAID, no parity — just pooling.

### Tailscale
Tailscale handles VPN with zero configuration on the router. Once installed, `tailscale up` authenticates the device and assigns it a stable private IP. The Mac and iPhone are also on the same Tailscale network, so `smb://100.x.x.x/nas` always works from anywhere.

### Cockpit
Cockpit is a lightweight web UI that runs on the Pi itself at `http://<tailscale-ip>:9090`. It provides disk usage, service status, log viewing, and basic storage management — the core things you would reach for OMV to do.

---

## Setup Scripts

The setup is automated across six scripts, run in order. A master script (`run_setup.sh`) chains them together and pauses at steps that need a reboot or manual action.

### `01_enable_pcie_sata.sh`
Adds `dtparam=pciex1_gen=3` to `/boot/firmware/config.txt` and prompts for a reboot. Nothing else works until this is done and the Pi has rebooted.

### `02_install_tailscale.sh`
Installs Tailscale and enables IP forwarding. After the script finishes, run `tailscale up` to authenticate. The script prints the URL.

### `03_format_and_mount.sh`
Detects SATA drives, shows them to you, and asks for confirmation before formatting. Each drive is formatted with ext4 and mounted at `/mnt/disk1`, `/mnt/disk2`, etc. Entries are added to `/etc/fstab` so mounts survive reboots.

> **Warning:** this script will wipe drives you choose to format. It prompts before doing anything destructive.

### `04_setup_mergerfs.sh`
Installs mergerfs and creates the `/srv/nas` pool from all `/mnt/disk*` mounts. Adds the mergerfs entry to `/etc/fstab`.

### `05_setup_samba.sh`
Installs Samba, creates a `nasuser` system account, writes a Samba config optimized for macOS and Time Machine, and enables the Samba service. Prompts you to set a Samba password for the user.

### `06_install_cockpit.sh`
Installs Cockpit and enables it on boot. Access the UI at `http://<tailscale-ip>:9090` with your system credentials.

---

## Running the Setup

Clone the repo and run the master script as root:

```bash
git clone https://github.com/yourusername/nas-setup.git
cd nas-setup
sudo bash run_setup.sh
```

The script walks you through each phase and tells you when a reboot or manual step is needed.

---

## Result

A quiet, low-power NAS that:
- Shows up in macOS Finder over Tailscale
- Accepts Time Machine backups
- Pools multiple drives transparently with mergerfs
- Has a web dashboard at port 9090
- Is fully manageable over SSH or Cockpit from anywhere

Total cost is lower than most commercial NAS units of equivalent spec, and it runs a standard Debian system you can maintain and extend like any Linux box.
