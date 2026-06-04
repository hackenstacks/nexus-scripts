#!/bin/sh
# nexus-witness.sh — NeXuS Automated Proof Loop
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful
#
# <!-- NXS-FORGE-META
# id:           NXS-SCRIPT-WITNESS-0001
# type:         SCRIPT
# principles:   Sane Simple Secure
# status:       ACTIVE
# -->

# Configuration
SCRIPTS_DIR="/home/user/claude/scripts"
KEYS_DIR="/home/user/claude/ai-nexus-bridge/keys"
TEST_KEY="${KEYS_DIR}/test_bridge_private.pem"
BRIDGE="${SCRIPTS_DIR}/nexus-bridge.sh"
STYX="${SCRIPTS_DIR}/styx-gen.sh"

_error() {
    echo "❌ Error: $1" >&2
    exit 1
}

# 1. Ensure Test Key exists
if [ ! -f "$TEST_KEY" ]; then
    echo "🔑 Generating Test Key for Witness Loop..."
    openssl genrsa -out "$TEST_KEY" 2048 >/dev/null 2>&1
fi

# 2. Setup Environment
export NODE_SECRET=$(cat "$TEST_KEY")
[ -z "$NODE_SECRET" ] && _error "Failed to load NODE_SECRET"

# 3. Main Loop
echo "🌀 NeXuS Witness Loop Active (Ctrl+C to stop)"
echo "📡 Watching DivaChain for tasks..."

while true; do
    # Check if Diva is reachable
    $BRIDGE status >/dev/null 2>&1 || { echo "⚠️ DivaChain unreachable. Retrying in 10s..."; sleep 10; continue; }

    # Simulation/Polling logic
    # In 'watch' mode, the bridge prints current state. 
    # For dev, we simulate a task trigger.
    
    TASK_ID="nexus:task:$(date +%Y%m%d%H%M)"
    SEQ="1"
    
    echo "🎯 New Task Detected: $TASK_ID (Seq: $SEQ)"
    
    # 4. Generate the Prime Truth
    echo "⚙️ Calculating Styx Prime Token..."
    TRUTH=$($STYX "$TASK_ID" "$SEQ")
    
    if [ -n "$TRUTH" ]; then
        echo "🟢 Truth Derived: ${TRUTH}"
        
        # 5. Submit to DivaChain
        # We use a sub-namespace for this node's proofs
        NS="nexus:proof:testnode"
        echo "📤 Submitting Proof to namespace: $NS"
        
        $BRIDGE put "$NS" "$TRUTH"
        
        echo "✅ Cycle Complete. Resting for 60s..."
    else
        echo "❌ Calculation failed."
    fi

    sleep 60
done
