#!/bin/sh
# nexus-media.sh — NeXuS MEDIA/SOCIAL window launcher
# Creates or switches to MEDIA tmux window
# Layout:
#   [LEFT  60%] weechat IRC / social (top) + newsboat (bottom)
#   [RIGHT 40%] nexus-media-feeds.sh (top) + nexus-media-ticker.sh (strip)
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

WIN_NAME="MEDIA"
SCRIPTS="$HOME/scripts"

_in_tmux() { [ -n "$TMUX" ]; }

_window_exists() {
    tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"
}

_launch_window() {
    # Pane 0: weechat (left top 60%)
    tmux new-window -n "$WIN_NAME" "weechat 2>/dev/null || sh -c '
        printf \"\\033[38;5;51m\\033[1m  SOCIAL / IRC\\033[0m\\n\"
        printf \"\\033[38;5;240m  weechat not found — install: apk add weechat\\033[0m\\n\\n\"
        printf \"\\033[38;5;240m  While you wait, press [n] for newsboat or [q] to close.\\033[0m\\n\"
        old=\$(stty -g 2>/dev/null)
        stty -echo -icanon min 1 time 0 2>/dev/null
        while true; do
            k=\$(dd bs=1 count=1 2>/dev/null | tr -d \"\0\")
            case \"\$k\" in
                q|Q) break ;;
                n|N) newsboat; break ;;
            esac
        done
        stty \"\$old\" 2>/dev/null
    '"

    # Pane 1: newsboat (left bottom 40% of left column)
    tmux split-window -v -p 40 -t "${WIN_NAME}.0" \
        "newsboat 2>/dev/null || sh -c 'printf \"\\033[38;5;240m  newsboat not installed\\033[0m\\n\"; sleep 60'"

    # Pane 2: feeds (right column 40% width)
    tmux split-window -h -p 40 -t "${WIN_NAME}.0" \
        "$SCRIPTS/nexus-media-feeds.sh"

    # Pane 3: ticker strip (bottom of right column, ~3 lines)
    tmux split-window -v -p 15 -t "${WIN_NAME}.2" \
        "$SCRIPTS/nexus-media-ticker.sh"

    # Focus feeds pane
    tmux select-pane -t "${WIN_NAME}.2"
    tmux select-window -t "$WIN_NAME"
}

launch_publish() {
    tmux new-window -n "PUBLISH" "$SCRIPTS/nexus-media-write.sh"
}

if ! _in_tmux; then
    echo "Run inside tmux: tmux new-window nexus-media.sh"
    exit 1
fi

if _window_exists; then
    tmux select-window -t "$WIN_NAME"
else
    _launch_window
fi
