#!/bin/bash
# 🌀 NeXuS Tmux Session Manager
# Save and restore tmux sessions with beautiful interface

set -e

# 🎨 NeXuS Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 🌀 NeXuS symbols
NEXUS_SYMBOL="🌀"
SAVE_SYMBOL="💾"
ATTACH_SYMBOL="🔗"
SESSION_SYMBOL="📋"
WINDOW_SYMBOL="🪟"
SUCCESS_SYMBOL="✅"
ERROR_SYMBOL="❌"
FIRE_SYMBOL="🔥"

print_color() {
    echo -e "${1}${2}${NC}"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║              ${NEXUS_SYMBOL} NeXuS Tmux Session Manager ${NEXUS_SYMBOL}             ║"
    print_color $CYAN "║                ${FIRE_SYMBOL} Save & Restore Sessions ${FIRE_SYMBOL}                ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

save_session() {
    show_banner
    print_color $YELLOW "${SAVE_SYMBOL} Save Current Tmux Session"
    echo
    
    # Check if in tmux session
    if [ -z "$TMUX" ]; then
        print_color $RED "${ERROR_SYMBOL} Not currently in a tmux session!"
        print_color $WHITE "Please run this script from within a tmux session to save it."
        exit 1
    fi
    
    # Get current session name
    current_session=$(tmux display-message -p '#S')
    print_color $BLUE "Current session: ${WHITE}$current_session"
    echo
    
    # Ask for save name
    print_color $CYAN "Enter a descriptive name for this session save:"
    print_color $WHITE "(e.g., 'nexus-gateway-work', 'ai-development', 'security-audit')"
    echo -n "Save name: "
    read -r save_name
    
    if [ -z "$save_name" ]; then
        print_color $RED "${ERROR_SYMBOL} Save name cannot be empty!"
        exit 1
    fi
    
    # Create saves directory
    saves_dir="/home/user/.nexus-tmux-saves"
    mkdir -p "$saves_dir"
    
    # Generate save filename with timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    save_file="${saves_dir}/${save_name}_${timestamp}.save"
    
    print_color $YELLOW "${SAVE_SYMBOL} Saving session state..."
    echo
    
    # Create comprehensive save file
    cat > "$save_file" << EOF
# NeXuS Tmux Session Save
# Save Name: $save_name
# Original Session: $current_session
# Save Date: $(date)
# Save File: $save_file

ORIGINAL_SESSION="$current_session"
SAVE_NAME="$save_name"
SAVE_DATE="$(date)"

# Session windows and layout
WINDOWS_INFO="$(tmux list-windows -t "$current_session" -F "#{window_index}:#{window_name}:#{window_layout}:#{pane_current_path}")"

# Current working directories for each pane
PANE_PATHS="$(tmux list-panes -t "$current_session" -a -F "#{session_name}:#{window_index}:#{pane_index}:#{pane_current_path}")"

# Window titles and commands
WINDOW_DETAILS="$(tmux list-windows -t "$current_session" -F "#{window_index}:#{window_name}:#{window_active}:#{window_layout}")"
EOF
    
    # Save session layout using tmux-resurrect if available
    if command -v tmux-resurrect >/dev/null 2>&1; then
        print_color $BLUE "Using tmux-resurrect for enhanced save..."
        # Trigger manual save
        tmux run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh'
    fi
    
    # Create restoration script
    restore_script="${saves_dir}/${save_name}_${timestamp}.restore.sh"
    cat > "$restore_script" << EOF
#!/bin/bash
# NeXuS Tmux Session Restoration Script
# Restore session: $save_name

source "$save_file"

echo "🌀 Restoring NeXuS Tmux Session: \$SAVE_NAME"
echo "📅 Original save date: \$SAVE_DATE"
echo

# Create new session with original name or modified name
session_name="\${ORIGINAL_SESSION}_restored_\$(date +%H%M%S)"

tmux new-session -d -s "\$session_name"

echo "✅ Session '\$session_name' created and ready!"
echo "🔗 Attach with: tmux attach-session -t \$session_name"
EOF
    chmod +x "$restore_script"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Session saved successfully!"
    print_color $WHITE "Save file: ${CYAN}$save_file"
    print_color $WHITE "Restore script: ${CYAN}$restore_script"
    echo
    print_color $YELLOW "💡 To restore this session later:"
    print_color $WHITE "$0 attach"
    echo
}

list_sessions() {
    print_color $CYAN "${SESSION_SYMBOL} Available Tmux Sessions:"
    echo
    
    # List running sessions
    if tmux list-sessions >/dev/null 2>&1; then
        print_color $YELLOW "🔥 Running Sessions:"
        tmux list-sessions -F "  ${GREEN}#{session_name}${NC} - #{session_windows} windows (#{?session_attached,attached,detached})" 2>/dev/null | sort
        echo
    else
        print_color $WHITE "  No running sessions found"
        echo
    fi
    
    # List saved sessions
    saves_dir="/home/user/.nexus-tmux-saves"
    if [ -d "$saves_dir" ] && [ "$(ls -A "$saves_dir"/*.save 2>/dev/null | wc -l)" -gt 0 ]; then
        print_color $YELLOW "💾 Saved Sessions:"
        local count=1
        for save_file in "$saves_dir"/*.save; do
            if [ -f "$save_file" ]; then
                local save_name=$(basename "$save_file" | sed 's/_[0-9]*_[0-9]*.save$//')
                local save_date=$(grep "Save Date:" "$save_file" | cut -d: -f2- | xargs)
                print_color $WHITE "  [$count] ${CYAN}$save_name${NC} - saved: $save_date"
                count=$((count + 1))
            fi
        done
        echo
    else
        print_color $WHITE "  No saved sessions found"
        echo
    fi
}

attach_session() {
    show_banner
    list_sessions
    
    print_color $YELLOW "${ATTACH_SYMBOL} Attach to Session"
    echo
    print_color $CYAN "Choose an option:"
    print_color $WHITE "[1] Attach to running session"
    print_color $WHITE "[2] Restore from saved session"
    print_color $WHITE "[3] List session windows (for running sessions)"
    print_color $WHITE "[q] Quit"
    echo
    echo -n "Choice: "
    read -r choice
    
    case $choice in
        1)
            attach_running_session
            ;;
        2)
            restore_saved_session
            ;;
        3)
            list_session_windows
            ;;
        q|Q)
            print_color $YELLOW "Goodbye! 🌀"
            exit 0
            ;;
        *)
            print_color $RED "${ERROR_SYMBOL} Invalid choice!"
            sleep 2
            attach_session
            ;;
    esac
}

attach_running_session() {
    echo
    print_color $YELLOW "🔗 Running Sessions:"
    
    if ! tmux list-sessions >/dev/null 2>&1; then
        print_color $RED "${ERROR_SYMBOL} No running tmux sessions found!"
        return
    fi
    
    # Create numbered list of sessions
    sessions=($(tmux list-sessions -F "#{session_name}" 2>/dev/null | sort))
    
    if [ ${#sessions[@]} -eq 0 ]; then
        print_color $RED "${ERROR_SYMBOL} No running sessions available!"
        return
    fi
    
    local count=1
    for session in "${sessions[@]}"; do
        local windows=$(tmux list-sessions -F "#{session_name}:#{session_windows}" | grep "^$session:" | cut -d: -f2)
        local status=$(tmux list-sessions -F "#{session_name}:#{?session_attached,attached,detached}" | grep "^$session:" | cut -d: -f2)
        print_color $WHITE "  [$count] ${CYAN}$session${NC} - $windows windows ($status)"
        count=$((count + 1))
    done
    
    echo
    echo -n "Select session number (or 'q' to quit): "
    read -r session_choice
    
    if [ "$session_choice" = "q" ] || [ "$session_choice" = "Q" ]; then
        return
    fi
    
    if ! [[ "$session_choice" =~ ^[0-9]+$ ]] || [ "$session_choice" -lt 1 ] || [ "$session_choice" -gt ${#sessions[@]} ]; then
        print_color $RED "${ERROR_SYMBOL} Invalid session number!"
        sleep 2
        return
    fi
    
    selected_session="${sessions[$((session_choice - 1))]}"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Attaching to session: ${CYAN}$selected_session"
    sleep 1
    
    # Check if already in tmux
    if [ -n "$TMUX" ]; then
        print_color $YELLOW "Switching to session $selected_session..."
        tmux switch-client -t "$selected_session"
    else
        print_color $YELLOW "Attaching to session $selected_session..."
        exec tmux attach-session -t "$selected_session"
    fi
}

restore_saved_session() {
    saves_dir="/home/user/.nexus-tmux-saves"
    
    if [ ! -d "$saves_dir" ] || [ "$(ls -A "$saves_dir"/*.save 2>/dev/null | wc -l)" -eq 0 ]; then
        print_color $RED "${ERROR_SYMBOL} No saved sessions found!"
        return
    fi
    
    echo
    print_color $YELLOW "💾 Saved Sessions:"
    
    # Create numbered list of saved sessions
    saves=($(ls "$saves_dir"/*.save 2>/dev/null | sort -r))
    
    local count=1
    for save_file in "${saves[@]}"; do
        local save_name=$(basename "$save_file" | sed 's/_[0-9]*_[0-9]*.save$//')
        local save_date=$(grep "Save Date:" "$save_file" | cut -d: -f2- | xargs)
        print_color $WHITE "  [$count] ${CYAN}$save_name${NC} - $save_date"
        count=$((count + 1))
    done
    
    echo
    echo -n "Select save number to restore (or 'q' to quit): "
    read -r save_choice
    
    if [ "$save_choice" = "q" ] || [ "$save_choice" = "Q" ]; then
        return
    fi
    
    if ! [[ "$save_choice" =~ ^[0-9]+$ ]] || [ "$save_choice" -lt 1 ] || [ "$save_choice" -gt ${#saves[@]} ]; then
        print_color $RED "${ERROR_SYMBOL} Invalid save number!"
        sleep 2
        return
    fi
    
    selected_save="${saves[$((save_choice - 1))]}"
    restore_script="${selected_save%.save}.restore.sh"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Restoring session from: ${CYAN}$(basename "$selected_save")"
    
    if [ -f "$restore_script" ]; then
        bash "$restore_script"
    else
        print_color $YELLOW "⚠️ Restore script not found, using basic restoration..."
        # Basic restoration
        source "$selected_save"
        session_name="${ORIGINAL_SESSION}_restored_$(date +%H%M%S)"
        tmux new-session -d -s "$session_name"
        print_color $GREEN "${SUCCESS_SYMBOL} Session '$session_name' created!"
        print_color $WHITE "Attach with: ${CYAN}tmux attach-session -t $session_name"
    fi
}

list_session_windows() {
    echo
    print_color $YELLOW "${WINDOW_SYMBOL} Session Windows"
    echo
    
    if ! tmux list-sessions >/dev/null 2>&1; then
        print_color $RED "${ERROR_SYMBOL} No running tmux sessions found!"
        return
    fi
    
    sessions=($(tmux list-sessions -F "#{session_name}" 2>/dev/null | sort))
    
    if [ ${#sessions[@]} -eq 0 ]; then
        print_color $RED "${ERROR_SYMBOL} No running sessions available!"
        return
    fi
    
    # If only one session, show its windows directly
    if [ ${#sessions[@]} -eq 1 ]; then
        show_windows_for_session "${sessions[0]}"
        return
    fi
    
    # Multiple sessions - let user choose
    local count=1
    print_color $CYAN "Select session to view windows:"
    for session in "${sessions[@]}"; do
        print_color $WHITE "  [$count] ${CYAN}$session"
        count=$((count + 1))
    done
    
    echo
    echo -n "Select session number: "
    read -r session_choice
    
    if ! [[ "$session_choice" =~ ^[0-9]+$ ]] || [ "$session_choice" -lt 1 ] || [ "$session_choice" -gt ${#sessions[@]} ]; then
        print_color $RED "${ERROR_SYMBOL} Invalid session number!"
        return
    fi
    
    selected_session="${sessions[$((session_choice - 1))]}"
    show_windows_for_session "$selected_session"
}

show_windows_for_session() {
    local session="$1"
    
    echo
    print_color $CYAN "🪟 Windows in session: ${WHITE}$session"
    echo
    
    # Get window information
    tmux list-windows -t "$session" -F "#{window_index}:#{window_name}:#{window_active}:#{pane_current_path}" | while IFS=: read -r index name active path; do
        if [ "$active" = "1" ]; then
            print_color $GREEN "  [$index] ${WHITE}$name ${YELLOW}(active) ${CYAN}$path"
        else
            print_color $WHITE "  [$index] $name ${CYAN}$path"
        fi
    done
    
    echo
    print_color $YELLOW "💡 To switch to a window: ${WHITE}tmux select-window -t $session:INDEX"
    print_color $YELLOW "💡 To attach to session: ${WHITE}tmux attach-session -t $session"
    echo
}

# 5-second cancel timer
cancel_timer() {
    local action="$1"
    print_color $YELLOW "🔥 Starting: $action"
    print_color $CYAN "🌀 Press CTRL+C to cancel in:"
    
    for i in 5 4 3 2 1; do
        print_color $WHITE "[$i] ▓▓▓▓▓▓▓▓▓▓ $action"
        sleep 1
    done
    
    print_color $GREEN "⚡ Executing $action..."
    echo
}

main() {
    # Check for tmux installation
    if ! command -v tmux >/dev/null 2>&1; then
        print_color $RED "${ERROR_SYMBOL} tmux is not installed!"
        print_color $WHITE "Install with: ${CYAN}doas apk add tmux"
        exit 1
    fi
    
    show_banner
    
    print_color $CYAN "🌀 NeXuS Tmux Session Manager"
    echo
    print_color $YELLOW "Select an action:"
    print_color $WHITE "[1] ${SAVE_SYMBOL} Save current session"
    print_color $WHITE "[2] ${ATTACH_SYMBOL} Attach to session"
    print_color $WHITE "[3] ${SESSION_SYMBOL} List all sessions"
    print_color $WHITE "[q] Quit"
    echo
    echo -n "Choice: "
    read -r choice
    
    case $choice in
        1)
            cancel_timer "Session Save"
            save_session
            ;;
        2)
            attach_session
            ;;
        3)
            show_banner
            list_sessions
            echo
            print_color $YELLOW "Press Enter to return to menu..."
            read -r
            main
            ;;
        q|Q)
            print_color $YELLOW "Goodbye! 🌀"
            exit 0
            ;;
        *)
            print_color $RED "${ERROR_SYMBOL} Invalid choice!"
            sleep 2
            main
            ;;
    esac
}

# Handle command line arguments
case "${1:-menu}" in
    "save")
        save_session
        ;;
    "attach")
        attach_session
        ;;
    "list")
        show_banner
        list_sessions
        ;;
    "windows")
        list_session_windows
        ;;
    "help"|"--help")
        show_banner
        print_color $CYAN "NeXuS Tmux Session Manager Usage:"
        echo
        print_color $WHITE "Interactive mode:"
        print_color $CYAN "  $0                 ${NC}# Interactive menu"
        echo
        print_color $WHITE "Direct commands:"
        print_color $CYAN "  $0 save           ${NC}# Save current session"
        print_color $CYAN "  $0 attach         ${NC}# Attach to session menu"
        print_color $CYAN "  $0 list           ${NC}# List all sessions"
        print_color $CYAN "  $0 windows        ${NC}# Show session windows"
        echo
        ;;
    *)
        main
        ;;
esac