#!/bin/sh
# debug-labwc.sh — Capture labwc crash info when matugen sends SIGUSR1
# Run this from a TTY or nested Wayland session (NOT from inside labwc)
# Output goes to /tmp/labwc-debug.log

LOG=/tmp/labwc-debug.log
MATUGEN_LOG=/tmp/matugen-debug.log

echo "=== NeXuS labwc crash debugger ===" | tee "$LOG"
echo "Started: $(date)" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# Check we're not already inside labwc
if [ "$XDG_CURRENT_DESKTOP" = "labwc" ]; then
    echo "ERROR: Already inside labwc. Run from niri or a TTY." | tee -a "$LOG"
    exit 1
fi

# Pick an unused Wayland socket
export WAYLAND_DISPLAY=wayland-debug
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

echo "Starting labwc on $WAYLAND_DISPLAY with full debug output..." | tee -a "$LOG"
echo "---LABWC OUTPUT---" >> "$LOG"

# Start labwc in foreground capturing all output
# WAYLAND_DEBUG=1 gives protocol-level detail if needed
labwc 2>&1 | tee -a "$LOG" &
LABWC_PID=$!

echo "labwc PID: $LABWC_PID" | tee -a "$LOG"

# Give labwc time to fully initialize
echo "Waiting 3s for labwc to initialize..." | tee -a "$LOG"
sleep 3

# Check labwc is still running
if ! kill -0 "$LABWC_PID" 2>/dev/null; then
    echo "FAIL: labwc died before we could test it!" | tee -a "$LOG"
    echo "Check $LOG for output." | tee -a "$LOG"
    exit 1
fi

echo "labwc is up. Running matugen now..." | tee -a "$LOG"
echo "---MATUGEN OUTPUT---" >> "$MATUGEN_LOG"

# Run matugen the same way dms does — with current wallpaper
WALLPAPER=$(cat ~/.config/labwc/current-wallpaper 2>/dev/null)
if [ -z "$WALLPAPER" ]; then
    echo "No wallpaper set, using a solid color test..." | tee -a "$LOG"
    # Just test the SIGUSR1 directly
    echo "Sending SIGUSR1 directly to labwc ($LABWC_PID)..." | tee -a "$LOG"
    kill -SIGUSR1 "$LABWC_PID"
else
    echo "Wallpaper: $WALLPAPER" | tee -a "$LOG"
    matugen image "$WALLPAPER" 2>&1 | tee -a "$MATUGEN_LOG"
fi

# Wait briefly then check if labwc survived
sleep 2

if kill -0 "$LABWC_PID" 2>/dev/null; then
    echo "SUCCESS: labwc survived the SIGUSR1!" | tee -a "$LOG"
    echo "The crash may be timing-related (SIGUSR1 too soon after startup)." | tee -a "$LOG"
    kill "$LABWC_PID"
else
    echo "CONFIRMED CRASH: labwc died after matugen/SIGUSR1" | tee -a "$LOG"
    echo "" | tee -a "$LOG"
    echo "Check full log: $LOG" | tee -a "$LOG"
    echo "Matugen log:    $MATUGEN_LOG" | tee -a "$LOG"
    echo "themerc-override written:" | tee -a "$LOG"
    cat ~/.config/labwc/themerc-override | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "Done: $(date)" | tee -a "$LOG"
echo "Full log: $LOG"
