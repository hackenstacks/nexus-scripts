#!/bin/sh
# Direct fix using line number — replaces the bad display-popup with exec
# Run with: doas sh ~/scripts/nexus-patch-notes-fix2.sh

cp /usr/bin/fzf-speed /home/user/backups/fzf-speed-fix2-$(date +%Y%m%d_%H%M%S).bak

# Replace line 1064 directly
sed -i '1064s/.*/    exec bash \/home\/user\/scripts\/nexus-notes.sh/' /usr/bin/fzf-speed

echo "Applied. Verifying:"
sed -n '1062,1067p' /usr/bin/fzf-speed
