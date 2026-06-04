#!/bin/bash
# nexus-time.sh — NeXuS Time Management + Dead Man Switch
# Sane • Simple • Secure
# Requires: chrony, at (for scheduled events)
#
# Usage:
#   nexus-time.sh --sync              Force NTS time sync
#   nexus-time.sh --status            Show time sync status
#   nexus-time.sh --checkin           Reset dead man switch timer
#   nexus-time.sh --dms-start <hrs>   Start dead man switch (e.g. 24)
#   nexus-time.sh --dms-stop          Disarm dead man switch
#   nexus-time.sh --dms-status        Show dead man switch status
#   nexus-time.sh --event <time> <cmd> Schedule an event (e.g. "14:00" "backup.sh")
#   nexus-time.sh --events            List scheduled events

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────
DMS_STATE="/tmp/nexus-dms.state"
DMS_PID="/tmp/nexus-dms.pid"
DMS_LOG="/tmp/nexus-dms.log"
DMS_ACTION="${NEXUS_DMS_ACTION:-/home/user/scripts/nexus-dms-fire.sh}"
CHRONY_CONF="/etc/chrony/chrony.conf"

# ── Colors ──────────────────────────────────────────────────────────────────
GRN="\033[0;32m"; YEL="\033[1;33m"; RED="\033[0;31m"; CYN="\033[0;36m"; NC="\033[0m"
ok()   { echo -e "${GRN}[  ok ]${NC} $*"; }
info() { echo -e "${CYN}[time ]${NC} $*"; }
warn() { echo -e "${YEL}[ warn]${NC} $*"; }
err()  { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ── Time Sync ───────────────────────────────────────────────────────────────
cmd_sync() {
    info "Forcing NTS time sync via chrony..."
    if ! command -v chronyc &>/dev/null; then
        err "chrony not installed. Run: doas apk add chrony"
    fi
    doas chronyc makestep
    doas chronyc waitsync 10 0.1 0.0 10
    ok "Time synced: $(date)"
}

cmd_status() {
    if ! command -v chronyc &>/dev/null; then
        err "chrony not installed"
    fi
    echo ""
    info "── Chrony NTS Status ──────────────────────────────"
    chronyc tracking
    echo ""
    info "── NTS Sources ────────────────────────────────────"
    chronyc ntssources 2>/dev/null || chronyc sources -v
    echo ""
    info "── System Time ────────────────────────────────────"
    date
    echo ""
}

# ── Dead Man Switch ─────────────────────────────────────────────────────────
# The DMS works by writing a deadline timestamp to state file.
# A background watcher checks every minute — if deadline passes without
# a checkin, the action fires.
#
# Use cases:
#   - Security: if you don't check in, keys get wiped / alerts sent
#   - Server monitoring: if node goes silent, fire alert
#   - Privacy: capture/detention protection

dms_watcher() {
    # Run in background — checks deadline every 60s
    local deadline="$1"
    echo "$$" > "$DMS_PID"
    echo "ARMED $(date) DEADLINE $(date -d @$deadline 2>/dev/null || date -r $deadline)" >> "$DMS_LOG"

    while true; do
        sleep 60
        if [ ! -f "$DMS_STATE" ]; then
            echo "STATE FILE GONE — disarmed $(date)" >> "$DMS_LOG"
            exit 0
        fi
        local current_deadline
        current_deadline=$(cat "$DMS_STATE" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)

        if [ "$now" -gt "$current_deadline" ]; then
            echo "FIRED $(date) — deadline exceeded" >> "$DMS_LOG"
            # Fire the action
            if [ -x "$DMS_ACTION" ]; then
                "$DMS_ACTION" &
            else
                # Default action — log and alert
                echo "NEXUS DMS FIRED — $(date)" >> "$DMS_LOG"
                wall "⚠ NEXUS DEAD MAN SWITCH FIRED — $(date)" 2>/dev/null || true
            fi
            rm -f "$DMS_STATE" "$DMS_PID"
            exit 0
        fi
    done
}

cmd_dms_start() {
    local hours="${1:-24}"
    local seconds=$(( hours * 3600 ))
    local deadline=$(( $(date +%s) + seconds ))

    if [ -f "$DMS_PID" ] && kill -0 "$(cat "$DMS_PID" 2>/dev/null)" 2>/dev/null; then
        warn "Dead man switch already armed. Use --dms-stop first or --checkin to reset."
        return
    fi

    echo "$deadline" > "$DMS_STATE"
    dms_watcher "$deadline" &
    disown

    ok "Dead man switch ARMED"
    info "Deadline: $(date -d @$deadline 2>/dev/null || date -r $deadline 2>/dev/null || echo "+${hours}hrs")"
    info "Check in with: nexus-time.sh --checkin"
    info "Action on fire: $DMS_ACTION"
    warn "If you do not check in within ${hours} hours the action WILL fire"
}

cmd_checkin() {
    if [ ! -f "$DMS_STATE" ]; then
        warn "Dead man switch is not armed"
        return
    fi
    # Read current deadline to get the original interval
    local old_deadline
    old_deadline=$(cat "$DMS_STATE")
    local now
    now=$(date +%s)

    # Reset by same interval as original (store interval separately)
    if [ -f "${DMS_STATE}.interval" ]; then
        local interval
        interval=$(cat "${DMS_STATE}.interval")
        local new_deadline=$(( now + interval ))
        echo "$new_deadline" > "$DMS_STATE"
        ok "Dead man switch reset — new deadline: $(date -d @$new_deadline 2>/dev/null || echo "+${interval}s")"
    else
        # Fallback — extend by 24hrs
        local new_deadline=$(( now + 86400 ))
        echo "$new_deadline" > "$DMS_STATE"
        ok "Dead man switch reset — extended 24hrs"
    fi
    echo "CHECKIN $(date)" >> "$DMS_LOG"
}

cmd_dms_stop() {
    if [ -f "$DMS_PID" ]; then
        local pid
        pid=$(cat "$DMS_PID" 2>/dev/null)
        kill "$pid" 2>/dev/null && ok "Dead man switch watcher stopped (PID $pid)" || true
        rm -f "$DMS_PID"
    fi
    rm -f "$DMS_STATE" "${DMS_STATE}.interval"
    ok "Dead man switch DISARMED"
}

cmd_dms_status() {
    echo ""
    info "── Dead Man Switch Status ─────────────────────────"
    if [ ! -f "$DMS_STATE" ]; then
        echo -e "  Status:   ${GRN}DISARMED${NC}"
    else
        local deadline
        deadline=$(cat "$DMS_STATE")
        local now
        now=$(date +%s)
        local remaining=$(( deadline - now ))
        if [ "$remaining" -lt 0 ]; then
            echo -e "  Status:   ${RED}OVERDUE — should have fired${NC}"
        else
            local hrs=$(( remaining / 3600 ))
            local mins=$(( (remaining % 3600) / 60 ))
            echo -e "  Status:   ${YEL}ARMED${NC}"
            echo    "  Deadline: $(date -d @$deadline 2>/dev/null || echo "unix:$deadline")"
            echo    "  Remaining: ${hrs}h ${mins}m"
        fi
    fi
    if [ -f "$DMS_PID" ] && kill -0 "$(cat "$DMS_PID" 2>/dev/null)" 2>/dev/null; then
        echo    "  Watcher:  running (PID $(cat "$DMS_PID"))"
    else
        echo    "  Watcher:  not running"
    fi
    if [ -f "$DMS_LOG" ]; then
        echo ""
        info "── Last 5 DMS Events ──────────────────────────────"
        tail -5 "$DMS_LOG"
    fi
    echo ""
}

# ── Scheduled Events ────────────────────────────────────────────────────────
cmd_event() {
    local time="${1:-}"
    local cmd="${2:-}"
    if [ -z "$time" ] || [ -z "$cmd" ]; then
        err "Usage: nexus-time.sh --event <time> <command>\n  Examples:\n    --event '14:00' '/home/user/scripts/backup.sh'\n    --event '23:59' 'nexus-time.sh --checkin'\n    --event 'now + 1 hour' 'echo fired'"
    fi
    if ! command -v at &>/dev/null; then
        err "'at' not installed. Run: doas apk add at"
    fi
    echo "$cmd" | at "$time" 2>&1
    ok "Event scheduled: '$cmd' at $time"
}

cmd_events() {
    if ! command -v at &>/dev/null; then
        warn "'at' not installed. Run: doas apk add at"
        return
    fi
    info "── Scheduled Events (atq) ─────────────────────────"
    atq 2>/dev/null || echo "  No scheduled events"
    echo ""
}

# ── Main ────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --sync)        cmd_sync ;;
    --status)      cmd_status ;;
    --checkin)     cmd_checkin ;;
    --dms-start)   cmd_dms_start "${2:-24}" ;;
    --dms-stop)    cmd_dms_stop ;;
    --dms-status)  cmd_dms_status ;;
    --event)       cmd_event "${2:-}" "${3:-}" ;;
    --events)      cmd_events ;;
    *)
        echo ""
        echo -e "  ${CYN}NeXuS Time Management + Dead Man Switch${NC}"
        echo ""
        echo "  Usage:"
        echo "    nexus-time.sh --sync              Force NTS time sync"
        echo "    nexus-time.sh --status            Show chrony NTS status"
        echo "    nexus-time.sh --checkin           Reset dead man switch"
        echo "    nexus-time.sh --dms-start <hrs>   Arm DMS (default 24hrs)"
        echo "    nexus-time.sh --dms-stop          Disarm DMS"
        echo "    nexus-time.sh --dms-status        DMS status + log"
        echo "    nexus-time.sh --event <t> <cmd>   Schedule event"
        echo "    nexus-time.sh --events            List scheduled events"
        echo ""
        echo "  Dead Man Switch action: $DMS_ACTION"
        echo "  (create this script to define what fires)"
        echo ""
        ;;
esac
