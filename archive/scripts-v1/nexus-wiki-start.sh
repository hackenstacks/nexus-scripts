#!/bin/bash
# NeXuS Wiki Services - idempotent startup
# Starts nb server and auto-import daemon if not already running

LOG_DIR="/tmp"

# Start nb wiki server via socat (nb browse --serve has a startup bug)
if ! pgrep -f "socat.*6789" > /dev/null 2>&1; then
    nohup socat tcp-listen:6789,reuseaddr,fork \
        "system:{ $(which nb) browse --respond; }" \
        >> "$LOG_DIR/nb_server.log" 2>&1 &
fi

# Start auto-import daemon
if ! pgrep -f "wiki_auto_import" > /dev/null 2>&1; then
    nohup bash /home/user/scripts/wiki_auto_import.sh start >> "$LOG_DIR/wiki_auto_import.log" 2>&1 &
fi
