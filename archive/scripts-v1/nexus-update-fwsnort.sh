#!/bin/sh
# nexus-update-fwsnort.sh
# Drop-in replacement for /usr/bin/update-fwsnort that includes the
# iptables-nft port negation fix after rule generation.
#
# Run with: doas sh ~/scripts/nexus-update-fwsnort.sh
# Or replace /usr/bin/update-fwsnort: doas cp this /usr/bin/update-fwsnort

set -e

echo "=== NeXuS: Updating fwsnort rules ==="

# Step 1: Update snort rules from upstream
/usr/sbin/fwsnort --update-rules

# Step 2: Regenerate iptables ruleset from updated snort rules
/usr/sbin/fwsnort

# Step 3: Fix iptables-nft incompatible port negation syntax (8 bad lines)
sh /home/user/scripts/nexus-fix-fwsnort-nftables.sh

# Step 4: Update PSAD signatures and reload
if pgrep -x psad > /dev/null 2>&1; then
    psad --sig-update
    psad -H
    echo "[✓] PSAD signatures updated and reloaded"
fi

echo "=== fwsnort update complete ==="
