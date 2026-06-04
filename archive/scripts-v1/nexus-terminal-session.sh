#!/bin/sh
# nexus-terminal-session.sh — NeXuS CLI-First Session Launcher
# Sane • Simple • Secure
#
# Runs under cage (single-app Wayland compositor)
# cage -- nexus-terminal-session.sh
#
# Inside: foot terminal → tmux 'nexus' session
# Launcher: yofi (works in cage, fuzzel does not)
# GUI apps: launched from within tmux via yofi

# Make yofi available as a tmux keybind or shell alias
export NEXUS_LAUNCHER="yofi"

# Launch foot with tmux — attach to existing 'nexus' session or create new
exec foot \
    --config ~/.config/foot/foot.ini \
    -e tmux new-session -A -s nexus
