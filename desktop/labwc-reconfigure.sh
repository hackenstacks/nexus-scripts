#!/bin/sh
# labwc-reconfigure.sh — Safe SIGUSR1 wrapper for matugen post_hook
# Waits until labwc has been running >10s before sending reconfigure signal.
# Prevents crash when matugen runs during compositor startup.

WAIT_SECS=10
LABWC_PID=$(pgrep -n labwc)

if [ -z "$LABWC_PID" ]; then
    exit 0  # labwc not running, nothing to do
fi

# Check how long labwc has been running (in seconds)
UPTIME=$(ps -o etimes= -p "$LABWC_PID" 2>/dev/null | tr -d ' ')

if [ -z "$UPTIME" ]; then
    exit 0
fi

if [ "$UPTIME" -lt "$WAIT_SECS" ]; then
    SLEEP_FOR=$(( WAIT_SECS - UPTIME ))
    sleep "$SLEEP_FOR"
fi

pkill -SIGUSR1 labwc
