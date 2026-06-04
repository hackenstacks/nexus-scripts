#!/bin/bash
# nexus-vm.sh - Boot any ISO in a KVM VM
# Sane - Simple - Secure
#
# Usage: nexus-vm.sh <path-to-iso> [ram_mb] [cpus]
# Example: nexus-vm.sh ~/Downloads/iso/kodachi.iso 3072 2

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ISO="${1:-}"
RAM="${2:-3072}"
CPUS="${3:-2}"
VNC_DISPLAY=2
VNC_PORT=$((5900 + VNC_DISPLAY))
SSH_PORT=2222
MONITOR_SOCK="/tmp/nexus-vm.sock"
PIDFILE="/tmp/nexus-vm.pid"

usage() {
    echo -e "${CYAN}nexus-vm.sh${NC} - Boot any ISO in KVM"
    echo ""
    echo "Usage: nexus-vm.sh <iso-path> [ram_mb] [cpus]"
    echo "       nexus-vm.sh stop"
    echo "       nexus-vm.sh status"
    echo ""
    echo "Defaults: 3072MB RAM, 2 CPUs"
    echo "Access:   VNC localhost:${VNC_PORT}  |  SSH -p ${SSH_PORT} user@localhost"
}

stop_vm() {
    if [[ -f "$PIDFILE" ]]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Stopping VM (PID $pid)...${NC}"
            # Try graceful first
            if [[ -S "$MONITOR_SOCK" ]]; then
                echo "system_powerdown" | socat - UNIX-CONNECT:"$MONITOR_SOCK" 2>/dev/null || true
                sleep 3
            fi
            # Force if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                sleep 1
            fi
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
            fi
            echo -e "${GREEN}VM stopped.${NC}"
        else
            echo "VM not running (stale PID)."
        fi
        rm -f "$PIDFILE"
    else
        # Check for any qemu
        local pid
        pid=$(pgrep -f "qemu.*nexus-vm" 2>/dev/null || true)
        if [[ -n "$pid" ]]; then
            echo -e "${YELLOW}Stopping VM (PID $pid)...${NC}"
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}VM stopped.${NC}"
        else
            echo "No VM running."
        fi
    fi
    rm -f "$MONITOR_SOCK"
}

status_vm() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        local pid
        pid=$(cat "$PIDFILE")
        echo -e "${GREEN}VM running${NC} (PID $pid)"
        echo -e "  VNC:  localhost:${VNC_PORT}"
        echo -e "  SSH:  ssh -p ${SSH_PORT} user@localhost"
        echo -e "  Stop: nexus-vm.sh stop"
    else
        echo "No VM running."
    fi
}

case "${ISO}" in
    stop)   stop_vm; exit 0 ;;
    status) status_vm; exit 0 ;;
    -h|--help|"") usage; exit 0 ;;
esac

# Validate ISO
if [[ ! -f "$ISO" ]]; then
    echo -e "${RED}ISO not found:${NC} $ISO"
    exit 1
fi

# Stop any existing VM first
stop_vm 2>/dev/null

# Check KVM
if [[ ! -e /dev/kvm ]]; then
    echo -e "${RED}KVM not available.${NC} Check kernel modules."
    exit 1
fi

ISO_NAME=$(basename "$ISO")

echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        nexus-vm - ISO Launcher         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ISO:   ${GREEN}${ISO_NAME}${NC}"
echo -e "  RAM:   ${RAM}MB"
echo -e "  CPUs:  ${CPUS}"
echo -e "  VNC:   ${GREEN}localhost:${VNC_PORT}${NC}"
echo -e "  SSH:   ${GREEN}ssh -p ${SSH_PORT} user@localhost${NC}"
echo ""

qemu-system-x86_64 \
    -enable-kvm \
    -m "$RAM" \
    -smp "$CPUS" \
    -cdrom "$ISO" \
    -boot d \
    -nic user,model=virtio,hostfwd=tcp::${SSH_PORT}-:22 \
    -display none \
    -vnc ":${VNC_DISPLAY}" \
    -usb -device usb-tablet \
    -monitor unix:"$MONITOR_SOCK",server,nowait \
    -name "nexus-vm-${ISO_NAME}" \
    -daemonize \
    -pidfile "$PIDFILE" \
    2>&1

if [[ -f "$PIDFILE" ]]; then
    echo -e "${GREEN}VM started!${NC} (PID $(cat "$PIDFILE"))"
    echo ""
    echo -e "  Connect:  ${CYAN}wlvncc 127.0.0.1 ${VNC_PORT}${NC}"
    echo -e "  Stop:     ${CYAN}nexus-vm.sh stop${NC}"
    echo -e "  Status:   ${CYAN}nexus-vm.sh status${NC}"
else
    echo -e "${RED}Failed to start VM.${NC}"
    exit 1
fi
