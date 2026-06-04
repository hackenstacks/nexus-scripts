#!/bin/sh
# nexus-fix-psad-logging.sh
# Fix the broken UFW → klogd → syslogd → PSAD logging chain
# Run with: doas sh ~/scripts/nexus-fix-psad-logging.sh
#
# What this fixes:
#   1. klogd not running  → iptables LOG entries stuck in kernel ring buffer
#   2. before.rules       → LOG rules missing prefix, PSAD can't identify them
#   3. psad.conf          → wrong SYSLOG_DAEMON, missing IPT_PREFIX
#   4. metalog.conf       → broken fail2ban section syntax error

set -e

echo "=== NeXuS: Fixing UFW + klogd + PSAD logging chain ==="
echo ""

# ── Backups ──────────────────────────────────────────────────────────────────
TS=$(date +%Y%m%d_%H%M%S)
BDIR="/home/user/backups/psad-logging-fix-${TS}"
mkdir -p "$BDIR"

cp /etc/ufw/before.rules        "$BDIR/before.rules.bak"
cp /etc/psad/psad.conf          "$BDIR/psad.conf.bak"
cp /etc/metalog.conf            "$BDIR/metalog.conf.bak"
cp /etc/conf.d/klogd            "$BDIR/klogd.conf.bak"

echo "[✓] Backups saved to $BDIR"

# ── Fix 1: before.rules — add log prefix to LOG rules ────────────────────────
# Old: -A INPUT -j LOG  (logs ALL traffic, no prefix, PSAD can't identify it)
# New: -A ufw-before-input -j LOG --log-prefix "[UFW BLOCK] " --log-level 4
#      (logs only traffic that reaches UFW's before-input chain, with prefix)

sed -i \
  's|^-A INPUT -j LOG$|-A ufw-before-input -j LOG --log-prefix "[UFW BLOCK] " --log-level 4|' \
  /etc/ufw/before.rules

sed -i \
  's|^-A FORWARD -j LOG$|-A ufw-before-forward -j LOG --log-prefix "[UFW BLOCK] " --log-level 4|' \
  /etc/ufw/before.rules

echo "[✓] before.rules: LOG rules updated with [UFW BLOCK] prefix"

# ── Fix 2: psad.conf — correct SYSLOG_DAEMON and add IPT_PREFIX ──────────────
# syslogd is busybox, not metalog. IPT_PREFIX tells PSAD which log entries
# are firewall entries (matches the prefix we set above).

sed -i \
  's|^SYSLOG_DAEMON\s*metalog;|SYSLOG_DAEMON           syslogd;|' \
  /etc/psad/psad.conf

# Add IPT_PREFIX if not present
if ! grep -q "^IPT_PREFIX " /etc/psad/psad.conf; then
  sed -i \
    '/^IPT_SYSLOG_FILE/a IPT_PREFIX                  [UFW BLOCK];' \
    /etc/psad/psad.conf
fi

echo "[✓] psad.conf: SYSLOG_DAEMON set to syslogd, IPT_PREFIX added"

# ── Fix 3: metalog.conf — fix broken fail2ban section (missing closing quote) ─
# Line: logdir    = "/var/log/    ← missing closing quote and path
sed -i \
  's|logdir    = "/var/log/$|logdir    = "/var/log/fail2ban"|' \
  /etc/metalog.conf

echo "[✓] metalog.conf: fail2ban section syntax error fixed"

# ── Fix 4: klogd — add to boot runlevel and start ────────────────────────────
# klogd reads /proc/kmsg (kernel messages) and forwards to syslogd.
# Without it, iptables LOG entries never leave the kernel ring buffer.

rc-update add klogd boot 2>/dev/null && echo "[✓] klogd: added to boot runlevel" \
  || echo "[!] klogd: already in runlevel or rc-update failed"

rc-service klogd start 2>/dev/null && echo "[✓] klogd: started" \
  || echo "[!] klogd: failed to start (check rc-service klogd status)"

# ── Fix 5: Reload UFW and restart PSAD ───────────────────────────────────────
rc-service ufw restart 2>/dev/null && echo "[✓] UFW: reloaded with new LOG rules" \
  || echo "[!] UFW: restart failed"

rc-service psad restart 2>/dev/null && echo "[✓] PSAD: restarted" \
  || echo "[!] PSAD: restart failed"

echo ""
echo "=== Done. Verify with: ==="
echo "  grep 'UFW BLOCK' /var/log/messages   # should appear after traffic hits firewall"
echo "  psad --Status                         # should show packets after some traffic"
echo ""
echo "Note: trigger a test scan from another machine or run:"
echo "  nmap -sS localhost  # to generate firewall log entries"
