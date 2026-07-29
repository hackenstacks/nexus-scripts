#!/bin/sh
# nexus-home.sh — NeXuS HOME window launcher
# Creates a dedicated tmux window named HOME with:
#   Left pane:   status, security score, warnings, services
#   Right pane:  RSS feed (optional)
#   Bottom pane: AI chat with TTS
#
# Usage:
#   nexus-home.sh          — open HOME in current tmux session
#   nexus-home.sh attach   — attach or create session with HOME
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

SCRIPTS="$HOME/scripts"
WIN_NAME="HOME"

_in_tmux() { [ -n "$TMUX" ]; }

_window_exists() {
    tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"
}

_launch() {
    # Create HOME window
    tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-home-status.sh"

    # Split right: services/RSS pane (30% width)
    tmux split-window -h -p 30 -t "$WIN_NAME" "$SCRIPTS/nexus-home-rss.sh"

    # Split bottom: AI chat (40% height, spanning full width)
    tmux split-window -v -p 40 -t "${WIN_NAME}.0" "$SCRIPTS/nexus-home-chat.sh"

    # Focus the chat pane
    tmux select-pane -t "${WIN_NAME}.2"

    # Key bindings active only in HOME window
    # (these are bound in tmux.conf — see nexus-home.help.md)
    tmux select-window -t "$WIN_NAME"
}

_bind_keys() {
    # Bind launch keys inside HOME window context
    # These create new windows for each function
    tmux bind-key -n d run-shell "tmux new-window -n DARKNET '$HOME/claude/nexus-darknet-go/nexus-darknet tui'"
    tmux bind-key -n g run-shell "tmux new-window -n GATE 'cd $HOME/claude/nexus-orchestrator && python nexus.py'"
    tmux bind-key -n o run-shell "tmux new-window -n ORCH 'cd $HOME/claude/nexus-orchestrator && python nexus.py'"
    tmux bind-key -n l run-shell "tmux new-window -n LOGS 'tail -f $HOME/.nexus/audit.log'"
    tmux bind-key -n m run-shell "tmux new-window -n MON 'htop'"
}

if ! _in_tmux; then
    if [ "$1" = "attach" ]; then
        # Create or attach a nexus session
        tmux has-session -t nexus 2>/dev/null || tmux new-session -d -s nexus -n "$WIN_NAME" "$SCRIPTS/nexus-home-status.sh"
        tmux attach -t nexus
    else
        echo "Not in tmux. Run: tmux new-session '$SCRIPTS/nexus-home.sh'"
        echo "Or: nexus-home.sh attach"
    fi
    exit 0
fi

# Inside tmux — create or jump to HOME
if _window_exists; then
    tmux select-window -t "$WIN_NAME"
else
    _launch
fi
