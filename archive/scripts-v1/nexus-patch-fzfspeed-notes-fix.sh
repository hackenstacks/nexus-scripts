#!/bin/sh
# Fix notes handler - run directly in existing popup instead of nesting
# Run with: doas sh ~/scripts/nexus-patch-fzfspeed-notes-fix.sh

sed -i 's|tmux display-popup -E -h 85% -w 80% "bash /home/user/scripts/nexus-notes.sh"|exec bash /home/user/scripts/nexus-notes.sh|' /usr/bin/fzf-speed
echo "[✓] Fixed — notes now runs inside the existing popup"
