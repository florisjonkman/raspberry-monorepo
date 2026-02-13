# Raspberry Pi Setup Guide

This guide covers flashing an SD card with Raspberry Pi OS and configuring it for headless operation with a static IP address.

## Prerequisites

### Hardware Required

- Raspberry Pi 4 Model B (4GB or 8GB RAM recommended)
- MicroSD card (32GB+ recommended, Class 10 or better)
- Ethernet cable
- Power supply (USB-C, 5V 3A)

### Software Required (macOS)

Install Raspberry Pi Imager:

```bash
brew install --cask raspberry-pi-imager
```

Or download from: https://www.raspberrypi.com/software/

## Step 1: Flash the SD Card

1. **Insert SD card** into your Mac (use an adapter if needed)

2. **Open Raspberry Pi Imager**

3. **Select OS**:
   - Click "CHOOSE OS"
   - Select "Raspberry Pi OS (other)"
   - Select **"Raspberry Pi OS Lite (64-bit)"**

   > We use the Lite version (no desktop) to minimize resource usage on the cluster.

4. **Select Storage**:
   - Click "CHOOSE STORAGE"
   - Select your SD card

   > Double-check you're selecting the correct drive!

5. **Configure Advanced Options** (click the gear icon):

   | Setting | Value |
   |---------|-------|
   | Set hostname | `raspberry` |
   | Enable SSH | Yes, Use password authentication (or public-key) |
   | Set username and password | `pi` / `<your-secure-password>` |
   | Set locale settings | Your timezone |
   | Skip WiFi configuration | Yes (we use Ethernet) |

   > If using SSH key authentication (recommended), paste your public key from `~/.ssh/id_rsa.pub`

6. **Click "Write"** and wait for completion

7. **Eject the SD card** when finished

## Step 2: First Boot

1. **Insert the SD card** into the Raspberry Pi
2. **Connect Ethernet cable** to your router/switch
3. **Connect power** to boot the Pi

The Pi will boot and connect to your network via DHCP.

## Step 3: Find the Pi's IP Address

### Option A: Check Your Router

1. Log into your router's admin panel (usually `192.168.1.1`)
2. Look for connected devices or DHCP clients
3. Find the device named `raspberry` or with manufacturer "Raspberry Pi"
4. Note the MAC address and current IP

### Option B: Use mDNS (if supported)

```bash
# Should resolve via mDNS
ping raspberry.local
```

### Option C: Network Scan

```bash
# Scan your local network
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"
```

## Step 4: Configure Static IP via DHCP Reservation

We configure the static IP on the **router** (not the Pi) using DHCP reservation. This approach:
- Survives Pi OS reinstalls
- Keeps network configuration centralized
- Requires no Pi-side configuration

### Steps

1. **Log into your router's admin panel**

2. **Navigate to DHCP settings** (often under LAN or Network settings)

3. **Create a DHCP reservation**:

   | Field | Value |
   |-------|-------|
   | MAC Address | `<Pi's MAC address from Step 3>` |
   | IP Address | `192.168.1.31` |
   | Description | `raspberry-pi-k3s` |

4. **Save the configuration**

5. **Reboot the Pi** to get the new IP:

   ```bash
   # SSH using current IP or hostname
   ssh pi@raspberry.local

   # On the Pi
   sudo reboot
   ```

6. **Verify the new IP**:

   ```bash
   ssh pi@192.168.1.31

   # Check IP on the Pi
   ip addr show eth0
   ```

## Step 5: Verify SSH Connection

Test the connection from your development machine:

```bash
# Using static IP
ssh pi@192.168.1.31

# Or using mDNS (backup)
ssh pi@raspberry.local
```

## Step 6: Run Ansible Setup

Once SSH is working, run the Ansible setup playbook:

```bash
# From the project root
task pi:ping    # Test connection
task pi:setup   # Run setup playbook
```

The setup playbook will:
- Update system packages
- Install required dependencies
- Configure cgroups for K3s
- Set up IP forwarding
- Configure hostname

## Network Configuration Reference

### Target Network Layout

| Device | IP Address | Purpose |
|--------|------------|---------|
| Router | 192.168.1.1 | Gateway |
| Raspberry Pi | 192.168.1.31 | K3s cluster |
| Reserved range | 192.168.1.31-199 | Infrastructure |

### Ports Used

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH | TCP |
| 80 | HTTP (Traefik) | TCP |
| 443 | HTTPS (Traefik) | TCP |
| 6443 | K3s API | TCP |

## Troubleshooting

### Can't Find Pi on Network

1. Check Ethernet cable is connected
2. Verify router DHCP is enabled
3. Check Pi power LED (solid red = powered)
4. Check Pi activity LED (flashing green = booting)

### SSH Connection Refused

1. Wait 1-2 minutes for boot to complete
2. Verify SSH was enabled in Imager settings
3. Check if hostname resolves: `ping raspberry.local`

### Wrong IP After Reboot

1. Verify DHCP reservation is configured correctly
2. Check MAC address matches the Pi
3. Clear ARP cache: `sudo arp -d 192.168.1.31`

### mDNS Not Working

If `.local` hostnames don't resolve:

1. **macOS**: Should work out of the box via Bonjour
2. **Linux**: Install `avahi-daemon`
3. **Fallback**: Use the static IP directly

## Next Steps

After completing this setup:

1. **Test locally first** - See [LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md)
2. **Install K3s** - Run `task k3s:install`
3. **Fetch kubeconfig** - Run `task k3s:kubeconfig`
4. **Install ArgoCD** - Run `task argocd:install`
