#!/bin/bash
# nexus-dms-fire.sh — Dead Man Switch Default Action
# Fired when nexus-time.sh DMS deadline is exceeded without checkin.
#
# CUSTOMIZE THIS FILE — what should happen if you go dark?
# Examples: wipe keys, send alert, lock system, notify contact
#
# Current default: log the event loudly, send wall message
# Replace or extend with your actual action.

set -euo pipefail

LOG="/tmp/nexus-dms-fire.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] NEXUS DMS FIRED" >> "$LOG"
echo "[$TIMESTAMP] Host: $(hostname)" >> "$LOG"
echo "[$TIMESTAMP] Uptime: $(uptime)" >> "$LOG"

# ── Alert all logged-in users ─────────────────────────────────────────────
wall "
========================================
  NEXUS DEAD MAN SWITCH FIRED
  Time: $TIMESTAMP
  No checkin received — action triggered
  Host: $(hostname)
========================================
" 2>/dev/null || true

# ── Add your custom actions below ─────────────────────────────────────────

# Example: wipe sensitive key material
# shred -uz ~/.ssh/id_ed25519 ~/.gnupg/private-keys-v1.d/*.key 2>/dev/null || true

# Example: send alert (requires curl + endpoint)
# curl -sf -X POST "https://your-alert-endpoint/dms" \
#   -d "host=$(hostname)&time=$TIMESTAMP" 2>/dev/null || true

# Example: lock the screen
# loginctl lock-sessions 2>/dev/null || true

# Example: shut down
# doas /sbin/poweroff

# ── Log completion ─────────────────────────────────────────────────────────
echo "[$TIMESTAMP] DMS fire action complete" >> "$LOG"
