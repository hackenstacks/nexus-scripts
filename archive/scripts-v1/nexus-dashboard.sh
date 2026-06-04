#!/bin/bash

# NeXuS Dashboard Launcher - Properly configured wtfutil

# Set proper terminal environment
export TERM=${TERM:-xterm-256color}
export COLORTERM=truecolor

# Ensure we have a proper TTY
if [ ! -t 0 ]; then
    echo "Error: No TTY available. Run from a terminal."
    exit 1
fi

# Check if wtfutil config exists
if [ ! -f ~/.config/wtf/config.yml ]; then
    echo "🔥 NeXuS Dashboard: Creating initial config..."
    mkdir -p ~/.config/wtf
fi

# Clear screen and show startup message
clear
echo "🚀 Starting NeXuS Dashboard..."
echo "Press 'q' to quit, 'h' for help"
sleep 1

# Launch wtfutil with proper environment
exec /usr/bin/wtfutil -c ~/.config/wtf/config.yml