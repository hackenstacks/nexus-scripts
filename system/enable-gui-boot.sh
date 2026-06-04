#!/bin/bash
# Enable GUI boot (SDDM + X/Wayland)

echo "Enabling GUI boot mode..."

# Add SDDM to default runlevel
doas rc-update add sddm default

echo "✓ GUI boot enabled. Reboot to apply."
echo "Usage: doas reboot"