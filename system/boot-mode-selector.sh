#!/bin/bash
# Boot Mode Selector - Choose terminal or GUI at startup
# Place in /etc/local.d/ and make executable

CHOICE_FILE="/tmp/boot_choice"
TIMEOUT=10

# Create choice prompt
echo "Boot Mode Selection (${TIMEOUT}s timeout):"
echo "1) Terminal Only (CLI)"  
echo "2) GUI Desktop (SDDM + X/Wayland)"
echo "3) kmscon Terminal (Enhanced)"
echo
echo -n "Choice [1-3, default=1]: "

# Read choice with timeout
if read -t $TIMEOUT choice; then
    echo "$choice" > "$CHOICE_FILE"
else
    echo "1" > "$CHOICE_FILE"  # Default to terminal
    echo -e "\nTimeout reached. Defaulting to terminal mode."
fi

choice=$(cat "$CHOICE_FILE")

case "$choice" in
    2)
        echo "Starting GUI desktop..."
        rc-service sddm start
        ;;
    3)
        echo "Starting enhanced kmscon terminal..."
        killall kmscon 2>/dev/null
        kmscon --no-drm --hwacc --font-name "DejaVu Sans Mono" --font-size 14 &
        ;;
    *)
        echo "Starting terminal-only mode..."
        # Ensure no GUI services start
        rc-service sddm stop 2>/dev/null
        ;;
esac