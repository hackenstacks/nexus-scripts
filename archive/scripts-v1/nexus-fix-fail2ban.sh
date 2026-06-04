#!/bin/sh
# nexus-fix-fail2ban.sh
# Fix fail2ban watching empty /var/log/sshd_log instead of /var/log/messages.
# Also creates paths-overrides.local so all future jails default correctly.
#
# Run with: doas sh ~/scripts/nexus-fix-fail2ban.sh

set -e

echo "=== NeXuS: Fixing fail2ban log path ==="
echo ""

TS=$(date +%Y%m%d_%H%M%S)
BDIR="/home/user/backups/fail2ban-fix-${TS}"
mkdir -p "$BDIR"

# ── Backup ────────────────────────────────────────────────────────────────────
cp /etc/fail2ban/jail.d/alpine-ssh.conf "$BDIR/alpine-ssh.conf.bak"
echo "[✓] Backup saved to $BDIR"

# ── Fix alpine-ssh.conf — swap commented/active logpath lines ─────────────────
# Wrong: logpath = /var/log/sshd_log   (empty, SSH never writes here)
# Right: logpath = /var/log/messages   (busybox syslogd routes auth.* here)

cat > /etc/fail2ban/jail.d/alpine-ssh.conf << 'EOF'
[sshd]
enabled  = true
filter   = alpine-sshd
port     = ssh
logpath  = /var/log/messages
maxretry = 5
bantime  = 600

[sshd-ddos]
enabled  = true
filter   = alpine-sshd-ddos
port     = ssh
logpath  = /var/log/messages
maxretry = 5
bantime  = 600
EOF

echo "[✓] alpine-ssh.conf: logpath fixed to /var/log/messages"
echo "[✓] maxretry lowered from 10 to 5"

# ── Create paths-overrides.local — fix default sshd_log path for Alpine ───────
# paths-common.conf defaults sshd_log to /var/log/auth.log which doesn't
# exist on Alpine with busybox syslogd. Override it globally here.

if [ ! -f /etc/fail2ban/paths-overrides.local ]; then
    cat > /etc/fail2ban/paths-overrides.local << 'EOF'
# NeXuS Alpine override — busybox syslogd routes auth.* to /var/log/messages
# not /var/log/auth.log (which doesn't exist on this system)
[DEFAULT]
sshd_log = /var/log/messages
syslog_authpriv = /var/log/messages
EOF
    echo "[✓] paths-overrides.local created"
else
    echo "[i] paths-overrides.local already exists, skipping"
fi

# ── Restart fail2ban ──────────────────────────────────────────────────────────
rc-service fail2ban restart
echo "[✓] fail2ban restarted"

echo ""
echo "=== Verify with: ==="
echo "  doas fail2ban-client status"
echo "  doas fail2ban-client status sshd"
echo "  doas fail2ban-client status sshd-ddos"
