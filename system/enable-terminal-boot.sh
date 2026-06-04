#!/bin/bash
# Enable terminal-only boot (no X/Wayland)

echo "Enabling terminal-only boot mode..."

# Remove SDDM from default runlevel
doas rc-update del sddm default

# Stop SDDM if running
doas rc-service sddm stop

echo "✓ Terminal-only boot enabled. Reboot to apply."
echo "Usage: doas reboot"
echo ""
echo "To start GUI manually later:"
echo "  doas rc-service sddm start"
echo "  # or"  
echo "  startx"
echo "  # or"
echo "  sway"