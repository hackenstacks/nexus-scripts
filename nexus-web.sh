#!/bin/sh
# nexus-web.sh — NeXuS Web Window launcher
# GUI → hub strip + w3m + amfora (Gemini) + sacc (Gopher)
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

WIN_NAME="WEB"
SCRIPTS="$HOME/scripts"

_in_tmux()       { [ -n "$TMUX" ]; }
_in_gui()        { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_window_exists() { tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"; }

_launch_window() {
    # Pane 0 (top strip ~12): hub — search, launch, clipper
    tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-web-hub.sh"

    # Pane 1 (bottom-left 55%): w3m text browser
    tmux split-window -v -p 80 -t "${WIN_NAME}.0" \
        "w3m -o confirm_qq=0 -o http_proxy='' \
              'https://lite.duckduckgo.com/lite/' 2>/dev/null || \
         w3m 'about:' 2>/dev/null"

    # Pane 2 (bottom-right top): amfora — Gemini
    tmux split-window -h -p 45 -t "${WIN_NAME}.1" \
        "amfora 'gemini://geminispace.info/' 2>/dev/null || \
         sh -c 'printf \"\\033[38;5;51m  amfora not found\\033[0m\\n  apk add amfora\\n\"; sleep 9999'"

    # Pane 3 (bottom-right bottom): sacc — Gopher
    tmux split-window -v -p 45 -t "${WIN_NAME}.2" \
        "sacc 'gopher://gopher.floodgap.com/' 2>/dev/null || \
         bombadillo 'gopher://gopher.floodgap.com/' 2>/dev/null || \
         sh -c 'printf \"\\033[38;5;51m  sacc/bombadillo — Gopher\\033[0m\\n  apk add sacc\\n\"; sleep 9999'"

    tmux select-pane -t "${WIN_NAME}.1"
    tmux select-window -t "$WIN_NAME"
}

! _in_tmux && echo "Run inside tmux" && exit 1

if _window_exists; then
    tmux select-window -t "$WIN_NAME"
else
    _launch_window
fi
