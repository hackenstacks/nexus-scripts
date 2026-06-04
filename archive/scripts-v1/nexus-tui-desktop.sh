#!/bin/bash
# NeXuS TUI Desktop Environment
# Complete tmux-based desktop environment with app launcher, system monitor, and quick access

NEXUS_SESSION="nexus-desktop"
NEXUS_DIR="/home/user/scripts"
NEXUS_CONFIG="/home/user/.config/nexus"

# Create config directory
mkdir -p "$NEXUS_CONFIG"

# Colors for TUI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

# Check if we're already in a tmux session
check_tmux() {
    if [ -z "$TMUX" ]; then
        echo "Starting NeXuS Desktop Environment..."
        exec tmux new-session -d -s "$NEXUS_SESSION" "$0" main \; attach-session -t "$NEXUS_SESSION"
    fi
}

# Create the main desktop layout
create_desktop_layout() {
    # Main window with 4 panes:
    # ┌─────────────────────┬─────────────────┐
    # │                     │                 │
    # │    APP LAUNCHER     │  SYSTEM TRAY    │
    # │                     │                 │
    # ├─────────────────────┼─────────────────┤
    # │                     │                 │
    # │  SYSTEM MONITOR     │   QUICK ACCESS  │
    # │                     │                 │
    # └─────────────────────┴─────────────────┘
    
    # Rename window
    tmux rename-window "NeXuS-Desktop"
    
    # Create layout
    tmux split-window -h -p 30    # Split right 30%
    tmux split-window -v -p 50    # Split bottom right 50%
    tmux select-pane -t 0
    tmux split-window -v -p 50    # Split bottom left 50%
    
    # Label panes
    tmux select-pane -t 0 -T "App Launcher"
    tmux select-pane -t 1 -T "System Monitor" 
    tmux select-pane -t 2 -T "System Tray"
    tmux select-pane -t 3 -T "Quick Access"
    
    # Start components in each pane
    tmux send-keys -t 0 "$NEXUS_DIR/nexus-app-launcher.sh" Enter
    tmux send-keys -t 1 "$NEXUS_DIR/nexus-system-monitor.sh" Enter
    tmux send-keys -t 2 "$NEXUS_DIR/nexus-system-tray.sh" Enter  
    tmux send-keys -t 3 "$NEXUS_DIR/nexus-quick-access.sh" Enter
    
    # Select app launcher by default
    tmux select-pane -t 0
}

# Initialize desktop environment
init_desktop() {
    print_color $CYAN "🚀 Initializing NeXuS TUI Desktop Environment..."
    
    # Kill existing session if it exists
    tmux kill-session -t "$NEXUS_SESSION" 2>/dev/null
    
    # Create new session
    tmux new-session -d -s "$NEXUS_SESSION"
    
    # Create desktop layout
    create_desktop_layout
    
    # Create additional windows for applications
    tmux new-window -n "Terminal"
    tmux new-window -n "Apps"
    tmux new-window -n "Config"
    
    # Return to desktop window
    tmux select-window -t "NeXuS-Desktop"
    
    print_color $GREEN "✅ NeXuS Desktop Environment ready!"
}

# Main script logic
case "${1:-help}" in
    main)
        # This runs inside tmux
        create_desktop_layout
        # Keep running
        while true; do
            sleep 10
        done
        ;;
    start)
        check_tmux
        ;;
    init)
        init_desktop
        ;;
    attach)
        if tmux has-session -t "$NEXUS_SESSION" 2>/dev/null; then
            tmux attach-session -t "$NEXUS_SESSION"
        else
            print_color $YELLOW "No NeXuS session found. Starting new session..."
            $0 start
        fi
        ;;
    kill)
        tmux kill-session -t "$NEXUS_SESSION" 2>/dev/null
        print_color $GREEN "NeXuS Desktop Environment stopped."
        ;;
    help|*)
        cat << 'EOF'
🔥 NeXuS TUI Desktop Environment 🔥

USAGE:
  nexus-tui-desktop.sh <command>

COMMANDS:
  start     - Start new NeXuS desktop session
  attach    - Attach to existing session  
  init      - Initialize desktop layout
  kill      - Stop NeXuS desktop session

LAYOUT:
  ┌─────────────────────┬─────────────────┐
  │    APP LAUNCHER     │  SYSTEM TRAY    │
  │   - Applications    │  - Clock/Date   │
  │   - Scripts         │  - Volume       │
  │   - Settings        │  - Network      │
  │   - Qt Apps         │  - Notifications│
  ├─────────────────────┼─────────────────┤
  │  SYSTEM MONITOR     │   QUICK ACCESS  │
  │   - CPU/Memory      │  - Scripts      │
  │   - Processes       │  - Configs      │
  │   - Disk Usage      │  - Shortcuts    │
  │   - Network         │  - Recent       │
  └─────────────────────┴─────────────────┘

WINDOWS:
  - NeXuS-Desktop: Main dashboard
  - Terminal: Full terminal access
  - Apps: Running applications
  - Config: System configuration

NAVIGATION:
  - Ctrl+z + arrow keys: Switch panes
  - Ctrl+z + number: Switch windows
  - Ctrl+z + [: Copy mode / scrollback

FEATURES:
  ✅ CLI-only (no X/Wayland required)
  ✅ Complete script integration
  ✅ System monitoring dashboard
  ✅ Application launcher
  ✅ Quick access system tray
  ✅ tmux session management
EOF
        ;;
esac