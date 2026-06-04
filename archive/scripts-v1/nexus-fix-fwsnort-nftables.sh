#!/bin/sh
# nexus-fix-fwsnort-nftables.sh
# Fix fwsnort iptables-nft incompatibility: invalid port negation inside
# multiport lists (e.g. "--dports 25,!445,!1500") which iptables-nft rejects.
#
# Root cause: fwsnort incorrectly translates some Snort port negations into
# multiport lists with ! inside the list (invalid syntax). Only 8 rules
# affected out of ~29,680. This script strips those lines and re-applies.
#
# Run with: doas sh ~/scripts/nexus-fix-fwsnort-nftables.sh
# Also installed as post-step in update-fwsnort wrapper.

set -e

CMDS=/var/lib/fwsnort/fwsnort_iptcmds.sh
SAVE=/var/lib/fwsnort/fwsnort.save
TS=$(date +%Y%m%d_%H%M%S)
BDIR="/home/user/backups/fwsnort-nft-fix-${TS}"

echo "=== NeXuS: Fixing fwsnort iptables-nft port negation syntax ==="
echo ""

mkdir -p "$BDIR"

# ── Backup ────────────────────────────────────────────────────────────────────
if [ -f "$CMDS" ]; then
    cp "$CMDS" "$BDIR/fwsnort_iptcmds.sh.bak"
    echo "[✓] Backed up fwsnort_iptcmds.sh"
fi
if [ -f "$SAVE" ]; then
    cp "$SAVE" "$BDIR/fwsnort.save.bak"
    echo "[✓] Backed up fwsnort.save"
fi

# ── Count bad lines before fix ────────────────────────────────────────────────
BAD=$(grep -c "dports.*,![0-9]\|sports.*,![0-9]" "$CMDS" 2>/dev/null || echo 0)
echo "[i] Bad lines found: $BAD"

# ── Strip bad lines from fwsnort_iptcmds.sh ───────────────────────────────────
# These are rules where iptables ! port negation appears inside a multiport
# comma-separated list, which iptables-nft does not support.
# Removing them is safe: they represent 8/29680 rules for very specific
# signatures that fwsnort cannot correctly translate for nftables anyway.
sed -i '/dports.*,![0-9]/d; /sports.*,![0-9]/d' "$CMDS"

REMAINING=$(grep -c "dports.*,![0-9]\|sports.*,![0-9]" "$CMDS" 2>/dev/null || echo 0)
echo "[✓] Bad lines removed. Remaining: $REMAINING"

# ── Apply the cleaned rules ───────────────────────────────────────────────────
echo "[i] Applying fwsnort rules via fwsnort_iptcmds.sh..."
IPTABLES=iptables sh "$CMDS" 2>/tmp/fwsnort-apply.log && \
    echo "[✓] fwsnort rules applied successfully" || \
    { echo "[!] Some rules failed — check /tmp/fwsnort-apply.log"; cat /tmp/fwsnort-apply.log | head -20; }

# ── Signal PSAD to reload ─────────────────────────────────────────────────────
if pgrep -x psad > /dev/null 2>&1; then
    psad -H 2>/dev/null && echo "[✓] PSAD reloaded" || echo "[!] PSAD HUP failed"
fi

echo ""
echo "=== Done ==="
echo "Rules applied: $(grep -c '^\$IPTABLES' $CMDS 2>/dev/null || echo unknown)"
echo "Backup at: $BDIR"
