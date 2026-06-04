#!/bin/sh
# nexus-patch-fzfspeed-notes.sh
# Adds "nexus-notes" entry to fzf-speed popup menu.
# Run with: doas sh ~/scripts/nexus-patch-fwspeed-notes.sh

set -e

TARGET=/usr/bin/fzf-speed
TS=$(date +%Y%m%d_%H%M%S)
BDIR="/home/user/backups/fzf-speed-patch-${TS}"

mkdir -p "$BDIR"
cp "$TARGET" "$BDIR/fzf-speed.bak"
echo "[✓] Backup saved to $BDIR"

# ── 1. Add menu entry (before EOF of mylist) ──────────────────────────────────
if grep -q "nexus-notes" "$TARGET"; then
    echo "[i] nexus-notes entry already exists, skipping menu add"
else
    sed -i 's/^statusbar-hide-toggle!-- toggle statusbar hide\/show$/nexus-notes!-- open NeXuS notes (browse\/create\/quick)\nstatusbar-hide-toggle!-- toggle statusbar hide\/show/' "$TARGET"
    echo "[✓] Menu entry added"
fi

# ── 2. Add case handler (before final esac) ───────────────────────────────────
if grep -q "nexus-notes)" "$TARGET"; then
    echo "[i] nexus-notes case handler already exists, skipping"
else
    sed -i 's/^esac$/  nexus-notes)\n    tmux display-popup -E -h 85% -w 80% "bash \/home\/user\/scripts\/nexus-notes.sh"\n    ;;\nesac/' "$TARGET"
    echo "[✓] Case handler added"
fi

echo ""
echo "=== Done ==="
echo "Open your fzf-speed popup (prefix + \`) and type 'notes' to test."
