#!/usr/bin/env bash
# nexus-wifi.sh - Switch WiFi networks via fzf
# Usage: nexus-wifi.sh [--scan] [--list] [--disconnect] [network-name]

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()  { echo -e "${CYAN}::${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
die()   { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

# Check deps
for cmd in nmcli fzf; do
    command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
done

show_status() {
    local dev state conn ssid
    dev=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | grep ':wifi:' | head -1)
    if [[ -z "$dev" ]]; then
        warn "No WiFi device found"
        return
    fi
    state=$(echo "$dev" | cut -d: -f3)
    conn=$(echo "$dev" | cut -d: -f4)
    device_name=$(echo "$dev" | cut -d: -f1)
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 || echo "")
    echo -e "${BOLD}Device:${RESET} $device_name  ${BOLD}State:${RESET} $state  ${BOLD}Connected:${RESET} ${ssid:-none}"
}

do_scan() {
    info "Scanning for networks..."
    nmcli device wifi rescan 2>/dev/null || true
    sleep 2
}

list_saved() {
    nmcli -t -f NAME,TYPE,STATE connection show \
        | grep ':802-11-wireless:' \
        | cut -d: -f1
}

list_available() {
    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
        | grep -v '^:' \
        | sort -t: -k2 -rn \
        | awk -F: '!seen[$1]++ { printf "%-35s sig:%-4s %s\n", $1, $2, $3 }'
}

connect_to() {
    local name="$1"

    # Try saved connection first (by connection name)
    if list_saved | grep -qxF "$name"; then
        info "Connecting to saved network: ${BOLD}$name${RESET}"
        nmcli connection up "$name" && ok "Connected to $name" && return 0
    fi

    # Try by SSID — use 'connection show <name>' per-profile to read the SSID
    # (802-11-wireless.ssid is not available as a list field, only per-profile)
    local saved_by_ssid
    saved_by_ssid=$(list_saved | while IFS= read -r profile; do
        profile_ssid=$(nmcli -t -f 802-11-wireless.ssid connection show "$profile" 2>/dev/null \
            | cut -d: -f2)
        [[ "$profile_ssid" == "$name" ]] && echo "$profile" && break
    done | head -1)
    if [[ -n "$saved_by_ssid" ]]; then
        info "Connecting via saved profile: ${BOLD}$saved_by_ssid${RESET}"
        nmcli connection up "$saved_by_ssid" && ok "Connected to $name" && return 0
    fi

    # New network - prompt for password
    warn "No saved profile for: $name"
    echo -n "Password (leave blank if open): "
    read -rs password
    echo

    if [[ -z "$password" ]]; then
        info "Connecting to open network: ${BOLD}$name${RESET}"
        nmcli device wifi connect "$name"
    else
        info "Connecting to: ${BOLD}$name${RESET}"
        nmcli device wifi connect "$name" password "$password"
    fi
    ok "Connected to $name"
}

interactive_pick() {
    local mode="${1:-saved}"

    if [[ "$mode" == "scan" ]]; then
        do_scan
        local selection
        selection=$(list_available \
            | fzf --prompt="WiFi> " \
                  --header="Available networks (signal strength shown)" \
                  --height=40% \
                  --reverse \
                  --ansi \
            | awk '{print $1}')
        [[ -z "$selection" ]] && { warn "No network selected"; exit 0; }
        connect_to "$selection"
    else
        # Merge saved + currently visible SSIDs for the fzf list
        local saved_list available_ssids combined
        saved_list=$(list_saved)
        available_ssids=$(nmcli -t -f SSID device wifi list 2>/dev/null | grep -v '^$' | sort -u)
        combined=$(printf '%s\n%s' "$saved_list" "$available_ssids" | sort -u | grep -v '^$')

        local selection
        selection=$(echo "$combined" \
            | fzf --prompt="WiFi> " \
                  --header="Saved + visible networks  [ctrl-r to rescan]" \
                  --height=40% \
                  --reverse \
                  --bind "ctrl-r:reload(nmcli device wifi rescan 2>/dev/null; nmcli -t -f SSID device wifi list 2>/dev/null | grep -v '^$' | sort -u)")
        [[ -z "$selection" ]] && { warn "No network selected"; exit 0; }
        connect_to "$selection"
    fi
}

# --- Main ---
show_status
echo

case "${1:-}" in
    --scan|-s)
        interactive_pick scan
        ;;
    --list|-l)
        echo -e "${BOLD}Saved connections:${RESET}"
        list_saved | sed 's/^/  /'
        echo
        echo -e "${BOLD}Visible networks:${RESET}"
        list_available | sed 's/^/  /'
        ;;
    --disconnect|-d)
        local wifi_dev
        wifi_dev=$(nmcli -t -f DEVICE,TYPE device status | grep ':wifi:' | cut -d: -f1 | head -1)
        [[ -z "$wifi_dev" ]] && die "No WiFi device found"
        nmcli device disconnect "$wifi_dev" \
            && ok "Disconnected $wifi_dev" \
            || die "Failed to disconnect $wifi_dev"
        ;;
    --help|-h)
        echo "Usage: nexus-wifi.sh [option] [network]"
        echo "  (no args)       Interactive pick from saved + visible networks"
        echo "  --scan / -s     Rescan then pick from all visible networks"
        echo "  --list / -l     List saved and visible networks"
        echo "  --disconnect/-d Disconnect current WiFi"
        echo "  <network-name>  Connect directly by name/SSID"
        ;;
    "")
        interactive_pick saved
        ;;
    *)
        connect_to "$1"
        ;;
esac
