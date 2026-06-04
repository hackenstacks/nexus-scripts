#!/bin/sh
# nexus-ai.sh — NeXuS AI Window Hub
# Dedicated tmux window: AI
# Sections: Chat • Think • Images • Search • Docs • Forge • Vault
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'; BLU='\033[38;5;33m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

WIN_NAME="AI"
SCRIPTS="$HOME/scripts"
AICHAT="$HOME/.cargo/bin/aichat"

# Project paths
CLI_CHAR_GEN="$HOME/Projects/adv-cli-char-gen"
CLI_CHAR_SCRIPT="$CLI_CHAR_GEN/incomplete-char-gen-enhanced-5k-v2.py"
GUI_CHAR_GEN="$HOME/Projects/advanced-ai-character-generator-terminal-access"
AI_FORGE="$HOME/Projects/ai-forge"
VAULT_CHARS="$CLI_CHAR_GEN/characters"
VAULT_IMAGES="$CLI_CHAR_GEN/generated_images"
VAULT_AVATARS="$CLI_CHAR_GEN/avatars"
SHADOW_VAULT="$CLI_CHAR_GEN/shadowvault.json"

_in_tmux() { [ -n "$TMUX" ]; }

_window_exists() {
    tmux list-windows -F '#W' 2>/dev/null | grep -q "^${WIN_NAME}$"
}

_launch_window() {
    # Create AI window with status hub + chat pane
    tmux new-window -n "$WIN_NAME" "$SCRIPTS/nexus-ai-hub.sh"
    # Bottom pane: quick chat (40% height)
    tmux split-window -v -p 35 -t "${WIN_NAME}" "$SCRIPTS/nexus-home-chat.sh"
    tmux select-pane -t "${WIN_NAME}.0"
    tmux select-window -t "$WIN_NAME"
}

# If called as launcher, create/switch to window
if ! _in_tmux; then
    echo "Run inside tmux"
    exit 1
fi

if _window_exists; then
    tmux select-window -t "$WIN_NAME"
else
    _launch_window
fi
