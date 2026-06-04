#!/bin/sh
# nexus-media-av.sh — NeXuS Audio/Video Window
# mpv · vlc · ncmpcpp · yt-dlp · Strawberry
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

WIN_NAME="AV"
SCRIPTS="$HOME/scripts"

_in_tmux()       { [ -n "$TMUX" ]; }
_in_gui()        { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_window_exists() { tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"; }

_launch_window() {
    # Pane 0 (left ~45%): nexus-av-hub — launcher + queue + download
    tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-av-hub.sh"

    # Pane 1 (right top ~55%): ncmpcpp — music player (MPD)
    tmux split-window -h -p 55 -t "${WIN_NAME}.0" \
        "ncmpcpp 2>/dev/null || sh -c 'printf \"\\033[38;5;51m  ncmpcpp (MPD)\\033[0m\\n  Start MPD: mpd\\n  Install: apk add ncmpcpp\\n\"; sleep 9999'"

    # Pane 2 (right bottom ~35% of right): mpv log / now playing
    tmux split-window -v -p 35 -t "${WIN_NAME}.1" \
        "tail -f /tmp/nexus-mpv.log 2>/dev/null || \
         sh -c 'printf \"\\033[38;5;240m  mpv output · yt-dlp log\\033[0m\\n\"; sleep 9999'"

    tmux select-pane -t "${WIN_NAME}.0"
    tmux select-window -t "$WIN_NAME"
}

! _in_tmux && echo "Run inside tmux" && exit 1
_window_exists && tmux select-window -t "$WIN_NAME" || _launch_window
