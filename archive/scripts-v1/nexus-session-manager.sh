#!/bin/bash
# 🌀 NeXuS Session Manager - Preserve and Restore Work Sessions
# Save and restore complete work contexts with fire aesthetics

set -e

# 🎨 NeXuS Visual Design System
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
ORANGE='\033[0;91m'
NC='\033[0m'

# 🔥 NeXuS Symbols
NEXUS_SYMBOL="🌀"
FIRE_SYMBOL="🔥"
SAVE_SYMBOL="💾"
RESTORE_SYMBOL="🚀"
SESSION_SYMBOL="📝"
BACKUP_SYMBOL="🛡️"
SUCCESS_SYMBOL="✅"
WARNING_SYMBOL="⚠️"
ERROR_SYMBOL="❌"
CLOCK_SYMBOL="⏰"

# 📁 Session Configuration
SESSIONS_DIR="/home/user/.nexus-sessions"
CURRENT_SESSION="$SESSIONS_DIR/current"
TMUX_SESSION_NAME="nexus-work"
SESSION_METADATA="$SESSIONS_DIR/session-metadata.json"

print_color() {
    echo -e "${1}${2}${NC}"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║        ${NEXUS_SYMBOL} NeXuS Session Manager ${SAVE_SYMBOL} ${RESTORE_SYMBOL}        ║"
    print_color $CYAN "║            ${FIRE_SYMBOL} Preserve Your Digital Fire ${FIRE_SYMBOL}            ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

# ⏰ 5-Second Cancellation Timer
show_cancel_timer() {
    local operation="$1"
    echo -e "${YELLOW}${CLOCK_SYMBOL} Starting: ${WHITE}$operation${NC}"
    echo -e "${CYAN}Press ${WHITE}CTRL+C${CYAN} to cancel in:${NC}"
    
    for i in 5 4 3 2 1; do
        echo -ne "\r${RED}[$i]${YELLOW} ▓▓▓▓▓▓▓▓▓▓ ${WHITE}$operation${NC}"
        sleep 1
    done
    echo -e "\n${GREEN}${FIRE_SYMBOL} Executing $operation...${NC}\n"
}

# 📊 Session Information Display
show_session_info() {
    print_color $BLUE "${SESSION_SYMBOL} Current Session Status:"
    echo
    
    # tmux session info
    if tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
        print_color $GREEN "${SUCCESS_SYMBOL} tmux session: ${WHITE}$TMUX_SESSION_NAME (ACTIVE)${NC}"
        tmux list-windows -t "$TMUX_SESSION_NAME" | head -5
    else
        print_color $YELLOW "${WARNING_SYMBOL} tmux session: ${WHITE}$TMUX_SESSION_NAME (NOT ACTIVE)${NC}"
    fi
    
    echo
    
    # Current working state
    print_color $CYAN "${FIRE_SYMBOL} Working Directory: ${WHITE}$(pwd)${NC}"
    print_color $CYAN "${SESSION_SYMBOL} Last Session: ${WHITE}$(ls -t $SESSIONS_DIR/ 2>/dev/null | head -1 || echo "None")${NC}"
    
    # Session count
    local session_count=$(ls -1 "$SESSIONS_DIR/" 2>/dev/null | wc -l)
    print_color $CYAN "${SAVE_SYMBOL} Saved Sessions: ${WHITE}$session_count${NC}"
    
    echo
}

# 💾 Save Current Session
save_session() {
    local session_name="${1:-session_$(date '+%Y%m%d_%H%M%S')}"
    local session_dir="$SESSIONS_DIR/$session_name"
    
    show_cancel_timer "Session Save: $session_name"
    
    # Create session directory
    mkdir -p "$session_dir"/{tmux,environment,workspace,logs}
    
    print_color $BLUE "${SAVE_SYMBOL} Saving NeXuS Session: ${WHITE}$session_name${NC}"
    
    # Save tmux session if exists
    if tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
        print_color $CYAN "${SUCCESS_SYMBOL} Saving tmux session layout..."
        
        # Save session layout
        tmux list-sessions > "$session_dir/tmux/sessions.txt"
        tmux list-windows -t "$TMUX_SESSION_NAME" > "$session_dir/tmux/windows.txt"
        tmux list-panes -t "$TMUX_SESSION_NAME" -F '#{window_index}.#{pane_index}: #{pane_current_path}' > "$session_dir/tmux/panes.txt"
        
        # Save working directories for each pane
        tmux list-panes -t "$TMUX_SESSION_NAME" -F '#{pane_id}:#{pane_current_path}' > "$session_dir/tmux/pane_dirs.txt"
        
        # Save tmux configuration
        cp ~/.tmux.conf "$session_dir/tmux/" 2>/dev/null || echo "# No tmux config found" > "$session_dir/tmux/tmux.conf"
    else
        print_color $YELLOW "${WARNING_SYMBOL} No tmux session to save"
    fi
    
    # Save environment state
    print_color $CYAN "${SUCCESS_SYMBOL} Saving environment state..."
    env > "$session_dir/environment/env_vars.txt"
    pwd > "$session_dir/environment/working_dir.txt"
    history > "$session_dir/environment/command_history.txt" 2>/dev/null || echo "# No history available" > "$session_dir/environment/command_history.txt"
    
    # Save workspace state
    print_color $CYAN "${SUCCESS_SYMBOL} Saving workspace state..."
    echo "$(pwd)" > "$session_dir/workspace/current_directory.txt"
    ls -la > "$session_dir/workspace/directory_listing.txt"
    
    # Copy recent work files
    cp /home/user/action_report.md "$session_dir/workspace/" 2>/dev/null || echo "No action report"
    cp /home/user/claude/CLAUDE.md "$session_dir/workspace/" 2>/dev/null || echo "No CLAUDE.md"
    cp /home/user/claude/NEXUS_COMPLETE_SYSTEM_MANUAL.md "$session_dir/workspace/" 2>/dev/null || echo "No manual"
    
    # Save session metadata
    cat > "$session_dir/session_info.json" << EOF
{
    "session_name": "$session_name",
    "save_time": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "working_directory": "$(pwd)",
    "tmux_session": "$TMUX_SESSION_NAME",
    "session_type": "nexus_work_session",
    "version": "1.0"
}
EOF
    
    # Update current session symlink
    ln -sf "$session_dir" "$CURRENT_SESSION"
    
    # Save to session metadata
    echo "$(date -Iseconds): Saved session '$session_name'" >> "$SESSION_METADATA"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Session saved successfully!"
    print_color $WHITE "   ${SAVE_SYMBOL} Location: ${session_dir}"
    print_color $WHITE "   ${CLOCK_SYMBOL} Time: $(date)"
    print_color $WHITE "   ${SESSION_SYMBOL} Name: $session_name"
    
    echo
    print_color $FIRE_SYMBOL "${FIRE_SYMBOL} Your digital fire has been preserved! ${FIRE_SYMBOL}"
}

# 🚀 Restore Session
restore_session() {
    local session_name="$1"
    
    if [ -z "$session_name" ]; then
        print_color $RED "${ERROR_SYMBOL} Please specify a session name to restore"
        list_sessions
        return 1
    fi
    
    local session_dir="$SESSIONS_DIR/$session_name"
    
    if [ ! -d "$session_dir" ]; then
        print_color $RED "${ERROR_SYMBOL} Session '$session_name' not found"
        list_sessions
        return 1
    fi
    
    show_cancel_timer "Session Restore: $session_name"
    
    print_color $BLUE "${RESTORE_SYMBOL} Restoring NeXuS Session: ${WHITE}$session_name${NC}"
    
    # Load session info
    if [ -f "$session_dir/session_info.json" ]; then
        print_color $CYAN "${SESSION_SYMBOL} Session Info:"
        grep -E '"(save_time|working_directory)"' "$session_dir/session_info.json" | sed 's/^/   /'
    fi
    
    # Restore working directory
    if [ -f "$session_dir/workspace/current_directory.txt" ]; then
        local saved_dir=$(cat "$session_dir/workspace/current_directory.txt")
        if [ -d "$saved_dir" ]; then
            print_color $CYAN "${SUCCESS_SYMBOL} Restoring working directory: $saved_dir"
            cd "$saved_dir"
        fi
    fi
    
    # Restore tmux session
    if [ -f "$session_dir/tmux/sessions.txt" ]; then
        print_color $CYAN "${RESTORE_SYMBOL} Restoring tmux session..."
        
        # Kill existing session if it exists
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null || true
        
        # Create new session
        tmux new-session -d -s "$TMUX_SESSION_NAME"
        
        # Restore pane directories
        if [ -f "$session_dir/tmux/pane_dirs.txt" ]; then
            while IFS=':' read -r pane_id dir; do
                if [ -d "$dir" ]; then
                    tmux send-keys -t "$TMUX_SESSION_NAME" "cd '$dir'" Enter 2>/dev/null || true
                fi
            done < "$session_dir/tmux/pane_dirs.txt"
        fi
        
        print_color $GREEN "${SUCCESS_SYMBOL} tmux session '$TMUX_SESSION_NAME' restored"
    fi
    
    # Update current session symlink
    ln -sf "$session_dir" "$CURRENT_SESSION"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Session restored successfully!"
    print_color $WHITE "   ${RESTORE_SYMBOL} Session: $session_name"
    print_color $WHITE "   ${CLOCK_SYMBOL} Restored: $(date)"
    print_color $WHITE "   ${SESSION_SYMBOL} tmux: $TMUX_SESSION_NAME"
    
    echo
    print_color $FIRE_SYMBOL "${FIRE_SYMBOL} Your digital fire has been rekindled! ${FIRE_SYMBOL}"
    
    # Show how to attach to tmux
    echo
    print_color $YELLOW "${NEXUS_SYMBOL} To attach to your restored session:"
    print_color $WHITE "   tmux attach-session -t $TMUX_SESSION_NAME"
}

# 📋 List Available Sessions
list_sessions() {
    print_color $BLUE "${SESSION_SYMBOL} Available NeXuS Sessions:"
    echo
    
    if [ ! -d "$SESSIONS_DIR" ] || [ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]; then
        print_color $YELLOW "${WARNING_SYMBOL} No saved sessions found"
        return
    fi
    
    local count=1
    for session in $(ls -t "$SESSIONS_DIR/"); do
        if [ -d "$SESSIONS_DIR/$session" ]; then
            local session_dir="$SESSIONS_DIR/$session"
            local save_time="Unknown"
            
            if [ -f "$session_dir/session_info.json" ]; then
                save_time=$(grep '"save_time"' "$session_dir/session_info.json" | cut -d'"' -f4)
            fi
            
            print_color $CYAN "   ${count}. ${WHITE}$session${NC}"
            print_color $WHITE "      ${CLOCK_SYMBOL} Saved: $save_time"
            
            # Show if this is current session
            if [ -L "$CURRENT_SESSION" ] && [ "$(readlink "$CURRENT_SESSION")" = "$session_dir" ]; then
                print_color $GREEN "      ${SUCCESS_SYMBOL} (Current Session)"
            fi
            
            count=$((count + 1))
        fi
    done
    
    echo
    print_color $YELLOW "${NEXUS_SYMBOL} Use: ${WHITE}./nexus-session-manager.sh restore <session_name>${NC}"
}

# 🗑️ Clean Old Sessions
cleanup_sessions() {
    local keep_count="${1:-10}"
    
    show_cancel_timer "Session Cleanup (keeping last $keep_count)"
    
    print_color $BLUE "${BACKUP_SYMBOL} Cleaning old sessions (keeping last $keep_count)..."
    
    local session_count=$(ls -1t "$SESSIONS_DIR/" 2>/dev/null | wc -l)
    
    if [ "$session_count" -le "$keep_count" ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} No cleanup needed ($session_count sessions)"
        return
    fi
    
    local sessions_to_delete=$(ls -1t "$SESSIONS_DIR/" | tail -n +$((keep_count + 1)))
    
    for session in $sessions_to_delete; do
        if [ -d "$SESSIONS_DIR/$session" ]; then
            print_color $YELLOW "${WARNING_SYMBOL} Removing old session: $session"
            rm -rf "$SESSIONS_DIR/$session"
        fi
    done
    
    print_color $GREEN "${SUCCESS_SYMBOL} Cleanup complete"
}

# 🔧 Initialize Session System
init_session_system() {
    print_color $BLUE "${NEXUS_SYMBOL} Initializing NeXuS Session Management System..."
    
    # Create directories
    mkdir -p "$SESSIONS_DIR"
    touch "$SESSION_METADATA"
    
    # Create tmux session if not exists
    if ! tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null; then
        print_color $CYAN "${RESTORE_SYMBOL} Creating tmux session: $TMUX_SESSION_NAME"
        tmux new-session -d -s "$TMUX_SESSION_NAME"
        tmux rename-window -t "$TMUX_SESSION_NAME" "nexus-main"
    fi
    
    print_color $GREEN "${SUCCESS_SYMBOL} Session system initialized"
    echo
    print_color $YELLOW "${NEXUS_SYMBOL} Quick commands:"
    print_color $WHITE "   Save current session:    ./nexus-session-manager.sh save"
    print_color $WHITE "   List sessions:          ./nexus-session-manager.sh list"
    print_color $WHITE "   Restore session:        ./nexus-session-manager.sh restore <name>"
    print_color $WHITE "   Attach to tmux:         tmux attach -t $TMUX_SESSION_NAME"
}

# 📋 Main Menu
show_main_menu() {
    while true; do
        show_banner
        show_session_info
        
        print_color $WHITE "Session Operations:"
        echo -e "${CYAN}[1]${NC} ${SAVE_SYMBOL} Save Current Session"
        echo -e "${CYAN}[2]${NC} ${RESTORE_SYMBOL} Restore Session"
        echo -e "${CYAN}[3]${NC} ${SESSION_SYMBOL} List Sessions"
        echo -e "${CYAN}[4]${NC} ${BACKUP_SYMBOL} Cleanup Old Sessions"
        echo -e "${CYAN}[5]${NC} ${NEXUS_SYMBOL} Initialize Session System"
        echo -e "${CYAN}[6]${NC} ${SESSION_SYMBOL} Show Session Info"
        echo -e "${CYAN}[0]${NC} Exit"
        echo
        echo -ne "${YELLOW}Select operation: ${NC}"
        
        read -r choice
        case $choice in
            1) 
                echo -ne "${YELLOW}Session name (or Enter for auto): ${NC}"
                read -r session_name
                save_session "$session_name"
                ;;
            2) 
                list_sessions
                echo -ne "${YELLOW}Session to restore: ${NC}"
                read -r session_name
                restore_session "$session_name"
                ;;
            3) list_sessions ;;
            4) 
                echo -ne "${YELLOW}Keep how many sessions (default 10): ${NC}"
                read -r keep_count
                cleanup_sessions "${keep_count:-10}"
                ;;
            5) init_session_system ;;
            6) show_session_info ;;
            0) 
                print_color $GREEN "${NEXUS_SYMBOL} NeXuS Session Manager standing by"
                exit 0 
                ;;
            *) print_color $RED "Invalid choice" ;;
        esac
        
        echo
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}

# 🚀 Main Execution
main() {
    # Initialize session directory
    mkdir -p "$SESSIONS_DIR"
    
    # Command line interface
    case "${1:-menu}" in
        "save")
            show_banner
            save_session "$2"
            ;;
        "restore")
            show_banner
            restore_session "$2"
            ;;
        "list")
            show_banner
            list_sessions
            ;;
        "cleanup")
            show_banner
            cleanup_sessions "$2"
            ;;
        "init")
            show_banner
            init_session_system
            ;;
        "info")
            show_banner
            show_session_info
            ;;
        "menu"|*)
            show_main_menu
            ;;
    esac
}

# Execute main function
main "$@"