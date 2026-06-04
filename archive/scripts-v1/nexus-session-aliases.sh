#!/bin/bash
# 🌀 NeXuS Session Management Aliases
# Quick commands for session save/restore

# 🔥 Fire-themed session aliases
alias nexus-save='~/scripts/nexus-session-manager.sh save'
alias nexus-restore='~/scripts/nexus-session-manager.sh restore'
alias nexus-list='~/scripts/nexus-session-manager.sh list'
alias nexus-sessions='~/scripts/nexus-session-manager.sh menu'

# 🚀 Quick session operations
alias save-session='~/scripts/nexus-session-manager.sh save "$(date +%H%M)"'
alias restore-last='~/scripts/nexus-session-manager.sh restore "$(ls -t ~/.nexus-sessions/ | head -1)"'
alias session-info='~/scripts/nexus-session-manager.sh info'

# 📋 tmux session management
alias nexus-attach='tmux attach-session -t nexus-work'
alias nexus-new='tmux new-session -s nexus-work'
alias nexus-tmux='tmux list-sessions | grep nexus'

# 🌀 Quick save with description
nexus-quick-save() {
    local desc="${1:-quick-save}"
    ~/scripts/nexus-session-manager.sh save "$(date +%H%M)-$desc"
}

# 🔥 Auto-save before reboot
nexus-reboot-save() {
    echo "🌀 Saving session before reboot..."
    ~/scripts/nexus-session-manager.sh save "pre-reboot-$(date +%Y%m%d_%H%M%S)"
    echo "🔥 Session saved! Use 'nexus-restore' after reboot to continue."
}

# 📊 Session status
nexus-status() {
    echo "🌀 NeXuS Session Status:"
    echo "   📁 Saved sessions: $(ls -1 ~/.nexus-sessions/ 2>/dev/null | wc -l)"
    echo "   🚀 tmux session: $(tmux has-session -t nexus-work 2>/dev/null && echo "ACTIVE" || echo "INACTIVE")"
    echo "   📍 Current dir: $(pwd)"
    echo "   🕐 Last save: $(ls -t ~/.nexus-sessions/ 2>/dev/null | head -1 || echo "None")"
}

echo "🔥 NeXuS Session Aliases Loaded!"
echo "   💾 nexus-save [name]     - Save current session"  
echo "   🚀 nexus-restore <name>  - Restore saved session"
echo "   📋 nexus-list           - List available sessions"
echo "   ⚡ save-session         - Quick save with timestamp"
echo "   🔥 nexus-reboot-save    - Save before reboot"
echo "   📊 nexus-status         - Show session status"