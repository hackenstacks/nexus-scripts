#!/bin/bash
# nexus-time-setup.sh — NeXuS Time Stack Interactive Setup
# Sane • Simple • Secure
# Installs and configures chrony NTS, dead man switch, and nexus-time.sh

set -euo pipefail

GRN="\033[0;32m"; YEL="\033[1;33m"; RED="\033[0;31m"; CYN="\033[0;36m"
DIM="\033[2m"; BOLD="\033[1m"; NC="\033[0m"

ok()     { echo -e "${GRN}[  ok ]${NC} $*"; }
info()   { echo -e "${CYN}[setup]${NC} $*"; }
warn()   { echo -e "${YEL}[ warn]${NC} $*"; }
err()    { echo -e "${RED}[error]${NC} $*"; exit 1; }
header() { echo -e "\n${BOLD}${CYN}── $* ${NC}$(printf '─%.0s' $(seq 1 $((48 - ${#1}))))\n"; }
prompt() { echo -en "${YEL}  →${NC} $* "; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHRONY_CONF_SRC="$SCRIPT_DIR/chrony.conf"
CHRONY_CONF_DST="/etc/chrony/chrony.conf"
TIME_SCRIPT="$SCRIPT_DIR/nexus-time.sh"
DMS_SCRIPT="$SCRIPT_DIR/nexus-dms-fire.sh"
DMS_STATE="/tmp/nexus-dms.state"
DMS_PID="/tmp/nexus-dms.pid"

# ── Helpers ───────────────────────────────────────────────────────────────────

dms_armed() { [ -f "$DMS_STATE" ]; }

dms_watcher_running() {
    [ -f "$DMS_PID" ] && kill -0 "$(cat "$DMS_PID" 2>/dev/null)" 2>/dev/null
}

dms_status_line() {
    if dms_armed; then
        local deadline now remaining hrs mins
        deadline=$(cat "$DMS_STATE")
        now=$(date +%s)
        remaining=$(( deadline - now ))
        if [ "$remaining" -lt 0 ]; then
            echo -e "${RED}OVERDUE${NC}"
        else
            hrs=$(( remaining / 3600 ))
            mins=$(( (remaining % 3600) / 60 ))
            echo -e "${YEL}ARMED${NC} — ${hrs}h ${mins}m remaining"
        fi
    else
        echo -e "${GRN}DISARMED${NC}"
    fi
}

chrony_ok() { doas chronyc tracking &>/dev/null; }

pause() {
    echo ""
    prompt "Press Enter to continue..."
    read -r
}

# ── Menu ──────────────────────────────────────────────────────────────────────

show_menu() {
    clear
    echo -e "\n  ${BOLD}${CYN}NeXuS Time Stack${NC}"
    echo -e "  ${DIM}Sane • Simple • Secure${NC}\n"

    # Live status indicators
    if chrony_ok 2>/dev/null; then
        local ref
        ref=$(doas chronyc tracking 2>/dev/null | grep "Reference ID" | awk '{print $4}' | tr -d '()')
        echo -e "  ${DIM}chrony:${NC}  ${GRN}●${NC} running  ${DIM}ref: ${ref:-syncing...}${NC}"
    else
        echo -e "  ${DIM}chrony:${NC}  ${RED}●${NC} not responding"
    fi
    echo -e "  ${DIM}DMS:   ${NC}  $(dms_status_line)"
    echo ""

    echo -e "  ${BOLD}${CYN}── Time / Chrony ───────────────────────────────${NC}"
    echo -e "  ${BOLD}1)${NC} Full install         — chrony + NTS config + scripts"
    echo -e "  ${BOLD}2)${NC} Deploy config        — copy chrony.conf → /etc/chrony/"
    echo -e "  ${BOLD}3)${NC} Restart chronyd      — restart + verify"
    echo -e "  ${BOLD}4)${NC} Test chronyc          — check daemon connectivity"
    echo -e "  ${BOLD}5)${NC} NTS status            — tracking + sources"
    echo -e "  ${BOLD}6)${NC} Force time sync       — chronyc makestep"
    echo -e "  ${BOLD}7)${NC} Show deployed config  — cat /etc/chrony/chrony.conf"
    echo ""
    echo -e "  ${BOLD}${CYN}── Startup / Services ──────────────────────────${NC}"
    echo -e "  ${BOLD}8)${NC} View startup services — rc-status all runlevels"
    echo -e "  ${BOLD}9)${NC} Add chrony to boot    — rc-update add chronyd default"
    echo -e "  ${BOLD}10)${NC} Remove chrony from boot — rc-update del chronyd default"
    echo -e "  ${BOLD}11)${NC} Stop chronyd now      — rc-service chronyd stop"
    echo -e "  ${BOLD}12)${NC} Fix script permissions — chmod +x nexus-time.sh etc"
    echo ""
    echo -e "  ${BOLD}${CYN}── Dead Man Switch ─────────────────────────────${NC}"
    echo -e "  ${BOLD}13)${NC} DMS status            — current state + log"
    echo -e "  ${BOLD}14)${NC} Arm DMS               — start countdown"
    echo -e "  ${BOLD}15)${NC} Check in              — reset timer"
    echo -e "  ${BOLD}16)${NC} Disarm DMS            — stop + clear"
    echo -e "  ${BOLD}17)${NC} Edit fire action      — open nexus-dms-fire.sh"
    echo ""
    echo -e "  ${BOLD}q)${NC} Quit\n"
    prompt "Choice:"
    read -r choice
    handle_choice "$choice"
}

# ── Time / Chrony Actions ─────────────────────────────────────────────────────

do_install() {
    header "Full Install"

    if ! command -v chronyc &>/dev/null; then
        info "chrony not found — installing..."
        doas apk add chrony || err "Install failed"
        ok "chrony installed"
    else
        ok "chrony already installed ($(chronyc --version 2>&1 | head -1))"
    fi

    if ! command -v at &>/dev/null; then
        info "Installing 'at' for scheduled events..."
        doas apk add at 2>/dev/null && ok "at installed" || warn "at install failed — --event won't work"
    else
        ok "at already installed"
    fi

    do_deploy_config
    do_fix_permissions
    _add_boot
    do_restart

    echo ""
    ok "Install complete"
    pause
}

do_deploy_config() {
    header "Deploy Config"

    if [ ! -f "$CHRONY_CONF_SRC" ]; then
        err "Config not found: $CHRONY_CONF_SRC"
    fi

    if [ -f "$CHRONY_CONF_DST" ]; then
        local bak="${CHRONY_CONF_DST}.bak.$(date +%Y%m%d-%H%M%S)"
        doas cp "$CHRONY_CONF_DST" "$bak" && ok "Backed up → $bak"
    fi

    doas cp "$CHRONY_CONF_SRC" "$CHRONY_CONF_DST" && ok "Config deployed → $CHRONY_CONF_DST"
    pause
}

do_restart() {
    header "Restart chronyd"
    doas rc-service chronyd restart && ok "chronyd restarted"
    sleep 2
    do_test
}

do_test() {
    header "Test chronyc"
    if chrony_ok; then
        ok "chronyc can talk to daemon"
        doas chronyc tracking
    else
        warn "chronyc cannot talk to daemon"
        info "Service status:"
        rc-service chronyd status || true
        info "Config cmdport/bindcmd lines:"
        grep -n "cmdport\|bindcmd" "$CHRONY_CONF_DST" 2>/dev/null || echo "  (none)"
    fi
    pause
}

do_status() {
    header "NTS Status"
    if ! chrony_ok; then
        warn "Cannot talk to daemon — restart first (option 3)"
    else
        info "── Tracking ────────────────────────────────────"
        doas chronyc tracking
        echo ""
        info "── NTS Sources ─────────────────────────────────"
        doas chronyc ntssources 2>/dev/null || doas chronyc sources -v
        echo ""
        info "── System Time ─────────────────────────────────"
        date
    fi
    pause
}

do_force_sync() {
    header "Force Time Sync"
    if ! chrony_ok; then
        err "Cannot talk to daemon — restart first (option 3)"
    fi
    doas chronyc makestep && ok "Clock stepped"
    info "Waiting for sync..."
    doas chronyc waitsync 10 0.1 0.0 10 && ok "Synced: $(date)" \
        || warn "Sync timeout — NTS handshake may still be in progress"
    pause
}

do_show_config() {
    header "Deployed Config"
    [ -f "$CHRONY_CONF_DST" ] && cat -n "$CHRONY_CONF_DST" || warn "No config at $CHRONY_CONF_DST"
    pause
}

# ── Startup / Services Actions ────────────────────────────────────────────────

do_view_startup() {
    header "Startup Services"
    info "── All runlevels ────────────────────────────────"
    rc-status --all 2>/dev/null || rc-update show 2>/dev/null
    echo ""
    info "── chronyd specifically ─────────────────────────"
    rc-update show | grep chrony || echo "  chronyd not in any runlevel"
    pause
}

_add_boot() {
    doas rc-update add chronyd default 2>/dev/null \
        && ok "chronyd added to default runlevel" \
        || warn "Already in default runlevel (or failed)"
}

do_add_boot() {
    header "Add to Boot"
    _add_boot
    pause
}

do_remove_boot() {
    header "Remove from Boot"
    prompt "Remove chronyd from boot runlevel? (y/N):"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        doas rc-update del chronyd default 2>/dev/null \
            && ok "chronyd removed from default runlevel" \
            || warn "Not in default runlevel (or failed)"
    else
        info "Cancelled"
    fi
    pause
}

do_stop_service() {
    header "Stop chronyd"
    prompt "Stop chronyd now? (y/N):"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        doas rc-service chronyd stop && ok "chronyd stopped"
    else
        info "Cancelled"
    fi
    pause
}

do_fix_permissions() {
    header "Fix Permissions"
    for s in "$TIME_SCRIPT" "$DMS_SCRIPT" "$SCRIPT_DIR/nexus-time-setup.sh"; do
        if [ -f "$s" ]; then
            chmod +x "$s" && ok "chmod +x $(basename "$s")"
        else
            warn "Not found: $s"
        fi
    done
    pause
}

# ── Dead Man Switch Actions ───────────────────────────────────────────────────

do_dms_status() {
    header "Dead Man Switch Status"
    if [ ! -f "$TIME_SCRIPT" ]; then
        warn "nexus-time.sh not found at $TIME_SCRIPT"
        pause; return
    fi
    "$TIME_SCRIPT" --dms-status
    pause
}

do_dms_arm() {
    header "Arm Dead Man Switch"
    if dms_armed; then
        warn "DMS is already armed — disarm first (option 16) or check in (option 15)"
        pause; return
    fi
    prompt "Hours until DMS fires if no checkin (default 24):"
    read -r hrs
    hrs="${hrs:-24}"
    if ! [[ "$hrs" =~ ^[0-9]+$ ]]; then
        warn "Invalid — must be a number"
        pause; return
    fi
    "$TIME_SCRIPT" --dms-start "$hrs"
    pause
}

do_dms_checkin() {
    header "Dead Man Switch Check-In"
    if ! dms_armed; then
        warn "DMS is not armed"
        pause; return
    fi
    "$TIME_SCRIPT" --checkin
    pause
}

do_dms_disarm() {
    header "Disarm Dead Man Switch"
    if ! dms_armed && ! dms_watcher_running; then
        info "DMS is already disarmed"
        pause; return
    fi
    prompt "Disarm DMS? (y/N):"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        "$TIME_SCRIPT" --dms-stop
    else
        info "Cancelled"
    fi
    pause
}

do_dms_edit_action() {
    header "Edit DMS Fire Action"
    if [ ! -f "$DMS_SCRIPT" ]; then
        warn "Not found: $DMS_SCRIPT"
        pause; return
    fi
    info "Opening $DMS_SCRIPT"
    info "This script runs when the DMS fires — customise your action here"
    echo ""
    # Use micro if available, fall back to vi
    if command -v micro &>/dev/null; then
        micro "$DMS_SCRIPT"
    elif command -v nano &>/dev/null; then
        nano "$DMS_SCRIPT"
    else
        vi "$DMS_SCRIPT"
    fi
    chmod +x "$DMS_SCRIPT"
    ok "Saved"
    pause
}

# ── Router ────────────────────────────────────────────────────────────────────

handle_choice() {
    case "$1" in
        1)  do_install ;;
        2)  do_deploy_config ;;
        3)  do_restart ;;
        4)  do_test ;;
        5)  do_status ;;
        6)  do_force_sync ;;
        7)  do_show_config ;;
        8)  do_view_startup ;;
        9)  do_add_boot ;;
        10) do_remove_boot ;;
        11) do_stop_service ;;
        12) do_fix_permissions ;;
        13) do_dms_status ;;
        14) do_dms_arm ;;
        15) do_dms_checkin ;;
        16) do_dms_disarm ;;
        17) do_dms_edit_action ;;
        q|Q) echo ""; exit 0 ;;
        *) warn "Unknown option: $1" ;;
    esac
    show_menu
}

# ── Entry ─────────────────────────────────────────────────────────────────────
if [ "${1:-}" != "" ]; then
    handle_choice "$1"
else
    show_menu
fi
