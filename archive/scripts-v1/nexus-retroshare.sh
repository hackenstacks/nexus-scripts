#!/bin/sh
# nexus-retroshare.sh — NeXuS RetroShare Window
# GUI session  → launches Flatpak GUI + text companion panes
# CLI session  → cert management + log view
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

WIN_NAME="RETROSHARE"
SCRIPTS="$HOME/scripts"
RS_FLATPAK="cc.retroshare.retroshare-gui"
RS_API="http://127.0.0.1:9090"
RS_CERT_DIR="$HOME/.nexus/rs-certs"
RS_CERT_SITE="$HOME/.nexus/forge/store/nexus-friend-cert"
RS_LOG="$HOME/.retroshare"
mkdir -p "$RS_CERT_DIR"

_in_tmux()  { [ -n "$TMUX" ]; }
_in_gui()   { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_rs_running() { pgrep -f "retroshare\|RetroShare" >/dev/null 2>&1; }
_api_up()   { curl -s --max-time 2 "$RS_API/api/v2/peers" >/dev/null 2>&1; }

_window_exists() {
    tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"
}

_launch_window() {
    if _in_gui; then
        # GUI mode — 3 panes:
        # Top-left: hub/management  Top-right: text chat companion
        # Bottom strip: status/log
        tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-retroshare-hub.sh"
        tmux split-window -h -p 55 -t "${WIN_NAME}.0" \
            "$SCRIPTS/nexus-retroshare-chat.sh"
        tmux split-window -v -p 20 -t "${WIN_NAME}.0" \
            "tail -F $RS_LOG/*/debug.log 2>/dev/null || \
             sh -c 'while true; do $SCRIPTS/nexus-retroshare-hub.sh status_line; sleep 5; done'"
        tmux select-pane -t "${WIN_NAME}.0"
    else
        # CLI — hub only with log
        tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-retroshare-hub.sh"
        tmux split-window -v -p 30 -t "${WIN_NAME}.0" \
            "tail -F $RS_LOG/*/debug.log 2>/dev/null || sleep 9999"
        tmux select-pane -t "${WIN_NAME}.0"
    fi
    tmux select-window -t "$WIN_NAME"
}

! _in_tmux && echo "Run inside tmux" && exit 1

if _window_exists; then
    tmux select-window -t "$WIN_NAME"
else
    _launch_window
fi
