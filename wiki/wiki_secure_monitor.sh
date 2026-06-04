#!/bin/bash
# Secure wrapper for wiki auto-import with resource monitoring

set -e

# Load configuration
CONFIG_FILE="/home/user/scripts/wiki_auto_import.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Default security values if config missing
MAX_MEMORY_KB=${MAX_MEMORY_KB:-51200}
MAX_PROCESSES=${MAX_PROCESSES:-64}
MAX_FILE_HANDLES=${MAX_FILE_HANDLES:-1024}
NICE_LEVEL=${NICE_LEVEL:-19}

# Set resource limits
ulimit -v $((MAX_MEMORY_KB * 1024))  # Virtual memory
ulimit -u "$MAX_PROCESSES"           # Process count
ulimit -n "$MAX_FILE_HANDLES"        # File handles
ulimit -f 102400                     # File size (100MB)

# Set process priority
renice "$NICE_LEVEL" $$ >/dev/null 2>&1 || true

# Set I/O priority if ionice available
if command -v ionice >/dev/null 2>&1; then
    ionice -c 3 -p $$ >/dev/null 2>&1 || true
fi

# Monitor resource usage
monitor_resources() {
    while true; do
        sleep 30
        
        # Check memory usage
        local mem_kb=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
        if [[ "$mem_kb" -gt "$MAX_MEMORY_KB" ]]; then
            echo "[SECURITY] Memory limit exceeded: ${mem_kb}KB > ${MAX_MEMORY_KB}KB" >&2
            kill -TERM $$
            exit 1
        fi
        
        # Check CPU usage (5 minute average)
        local cpu_percent=$(ps -o %cpu= -p $$ 2>/dev/null | cut -d. -f1 || echo "0")
        if [[ "$cpu_percent" -gt "50" ]]; then
            echo "[WARNING] High CPU usage: ${cpu_percent}%" >&2
            # Increase nice level for lower priority
            renice +5 $$ >/dev/null 2>&1 || true
        fi
    done
}

# Start resource monitor in background
monitor_resources &
MONITOR_PID=$!

# Cleanup function
cleanup() {
    kill $MONITOR_PID 2>/dev/null || true
    exit
}

trap cleanup TERM INT EXIT

# Run the actual wiki auto-import with security wrapper
exec /home/user/scripts/wiki_auto_import.sh "$@"
