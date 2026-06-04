#!/bin/bash
# NeXuS Quick Access - Shortcuts to frequently used scripts and commands

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Beautiful symbols
FIRE_SYMBOL="🔥"
ROCKET_SYMBOL="🚀"
GEAR_SYMBOL="⚙️"
LIGHTNING_SYMBOL="⚡"
FOLDER_SYMBOL="📁"
STAR_SYMBOL="⭐"
DIAMOND_SYMBOL="💎"
CROWN_SYMBOL="👑"
MAGIC_SYMBOL="✨"
HEART_SYMBOL="💖"

SCRIPT_DIR="/home/user/scripts"
RECENT_FILE="/home/user/.config/nexus/recent_commands"

# Ensure recent file exists
mkdir -p "$(dirname "$RECENT_FILE")"
touch "$RECENT_FILE"

print_color() {
    echo -e "${1}${2}${NC}"
}

# Add command to recent list
add_to_recent() {
    local command="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Add to top of file, keep only last 10
    {
        echo "$timestamp | $command"
        head -9 "$RECENT_FILE" 2>/dev/null
    } > "${RECENT_FILE}.tmp"
    
    mv "${RECENT_FILE}.tmp" "$RECENT_FILE"
}

# Get recent commands
get_recent_commands() {
    if [ -f "$RECENT_FILE" ]; then
        head -5 "$RECENT_FILE" 2>/dev/null
    fi
}

# Quick script shortcuts with categories
declare -A QUICK_SCRIPTS=(
    # Fire & System Management
    ["F1"]="fire_login.sh:${FIRE_SYMBOL} Fire Login"
    ["F2"]="secure_notify_manager.sh:🔔 Notifications"
    ["F3"]="attention.sh:🚨 Attention Alert"
    
    # Configuration & Settings
    ["C1"]="kmscon-tui-config.sh:🖥️ Terminal Config"
    ["C2"]="tmux-tui-config.sh:📱 TMUX Config"
    ["C3"]="qt-platform-launcher.sh:🎯 Qt Platform"
    
    # Boot & System Control
    ["B1"]="cli_login_manager.sh:⚡ Login Manager"
    ["B2"]="enable-terminal-boot.sh:🔧 Terminal Boot"
    ["B3"]="remove_sddm.sh:🗑️ Remove SDDM"
    
    # Utilities & Tools
    ["U1"]="launch_app.sh:🚀 App Launcher"
    ["U2"]="volume_control.sh:🔊 Volume Control"
    ["U3"]="cli_clipboard.sh:📋 Clipboard"
)

# Direct command shortcuts
declare -A QUICK_COMMANDS=(
    ["htop"]="htop:📊 Process Monitor"
    ["ranger"]="ranger:📁 File Manager"
    ["vim"]="vim:✏️ Text Editor"
    ["w3m"]="w3m:🌐 Web Browser"
    ["glances"]="glances:💻 System Monitor"
)

# System actions
execute_system_action() {
    local action="$1"
    
    case "$action" in
        "reboot")
            print_color $RED "🔄 System Reboot Requested"
            echo "Are you sure? (y/N): "
            read -n 1 confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                doas reboot
            fi
            ;;
        "shutdown")
            print_color $RED "🔌 System Shutdown Requested"
            echo "Are you sure? (y/N): "
            read -n 1 confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                doas poweroff
            fi
            ;;
        "restart-tmux")
            print_color $YELLOW "🔄 Restarting TMUX..."
            tmux source-file ~/.tmux.conf
            print_color $GREEN "✅ TMUX configuration reloaded"
            ;;
        "fire-login")
            print_color $FIRE_SYMBOL "🔥 Activating Fire Login..."
            if [ -x "/home/user/fire_login.sh" ]; then
                /home/user/fire_login.sh
            fi
            ;;
    esac
}

# Draw the beautiful quick access menu
draw_quick_access() {
    clear
    
    print_color $CYAN "╔════════════════════════════════════════════════╗"
    print_color $CYAN "║         ${ROCKET_SYMBOL}${MAGIC_SYMBOL} NeXuS Quick Access ${MAGIC_SYMBOL}${ROCKET_SYMBOL}          ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    
    # Fire & System Section
    print_color $CYAN "║              ${FIRE_SYMBOL} FIRE & SYSTEM ${FIRE_SYMBOL}               ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${RED}F1${NC} ${FIRE_SYMBOL} Fire Login      ${RED}F2${NC} 🔔 Notifications ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}F3${NC} 🚨 Attention       ${RED}F4${NC} ${FIRE_SYMBOL} Fire Setup    ${CYAN}║${NC}"
    
    # Configuration Section
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    print_color $CYAN "║              ${GEAR_SYMBOL} CONFIGURATION ${GEAR_SYMBOL}               ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${BLUE}C1${NC} 🖥️ Terminal Config ${BLUE}C2${NC} 📱 TMUX Config   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}C3${NC} 🎯 Qt Platform     ${BLUE}C4${NC} ⚙️ System Settings${CYAN}║${NC}"
    
    # Boot & Control Section
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    print_color $CYAN "║            ${LIGHTNING_SYMBOL} BOOT & CONTROL ${LIGHTNING_SYMBOL}             ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${YELLOW}B1${NC} ⚡ Login Manager   ${YELLOW}B2${NC} 🔧 Terminal Boot ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}B3${NC} 🗑️ Remove SDDM     ${YELLOW}B4${NC} 🔄 Restart TMUX  ${CYAN}║${NC}"
    
    # Applications Section
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    print_color $CYAN "║              ${STAR_SYMBOL} APPLICATIONS ${STAR_SYMBOL}               ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${GREEN}A1${NC} 📊 htop          ${GREEN}A2${NC} 📁 ranger       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}A3${NC} ✏️ vim            ${GREEN}A4${NC} 🌐 w3m          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}A5${NC} 💻 glances       ${GREEN}A6${NC} 🚀 Launch App   ${CYAN}║${NC}"
    
    # Recent Commands Section
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    print_color $CYAN "║              ${DIAMOND_SYMBOL} RECENT COMMANDS ${DIAMOND_SYMBOL}             ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    
    local recent_count=0
    get_recent_commands | while read recent_line && [ $recent_count -lt 3 ]; do
        if [ -n "$recent_line" ]; then
            local cmd_part="${recent_line##*| }"
            local time_part="${recent_line%% |*}"
            local short_time="${time_part##* }"
            printf "${CYAN}║${NC} ${MAGENTA}R$((recent_count+1))${NC} %-20s %s      ${CYAN}║${NC}\n" "${cmd_part:0:15}" "$short_time"
            ((recent_count++))
        fi
    done 2>/dev/null
    
    # Fill empty recent slots
    while [ $recent_count -lt 3 ]; do
        printf "${CYAN}║${NC} ${MAGENTA}R$((recent_count+1))${NC} %-35s      ${CYAN}║${NC}\n" "(empty)"
        ((recent_count++))
    done
    
    # System Actions
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    print_color $CYAN "║              ${CROWN_SYMBOL} SYSTEM ACTIONS ${CROWN_SYMBOL}              ║"
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${RED}S1${NC} 🔄 Reboot System   ${RED}S2${NC} 🔌 Shutdown      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}S3${NC} 🔄 Restart TMUX    ${RED}S4${NC} ${FIRE_SYMBOL} Fire Mode     ${CYAN}║${NC}"
    
    # Controls
    print_color $CYAN "╠════════════════════════════════════════════════╣"
    echo -e "${CYAN}║${NC} ${GREEN}[Enter code]${NC} Execute  ${GREEN}[r]${NC} Refresh  ${GREEN}[q]${NC} Quit ${CYAN}║${NC}"
    print_color $CYAN "╚════════════════════════════════════════════════╝"
    
    # Status
    local current_time=$(date '+%H:%M:%S')
    echo -e "${BLUE}Quick Access Dashboard${NC} | ${YELLOW}Time: $current_time${NC} | ${GREEN}Ready for input...${NC}"
}

# Execute quick action
execute_quick_action() {
    local code="$1"
    
    case "$code" in
        # Fire & System
        F1|f1)
            add_to_recent "Fire Login"
            print_color $FIRE_SYMBOL "🔥 Starting Fire Login..."
            if [ -x "/home/user/fire_login.sh" ]; then
                /home/user/fire_login.sh
            fi
            ;;
        F2|f2)
            add_to_recent "Notifications"
            print_color $YELLOW "🔔 Opening Notification Manager..."
            if [ -x "$SCRIPT_DIR/secure_notify_manager.sh" ]; then
                "$SCRIPT_DIR/secure_notify_manager.sh"
            fi
            ;;
        F3|f3)
            add_to_recent "Attention Alert"
            print_color $RED "🚨 Sending Attention Alert..."
            if [ -x "/home/user/attention.sh" ]; then
                /home/user/attention.sh
            fi
            ;;
        F4|f4)
            add_to_recent "Fire Setup"
            print_color $FIRE_SYMBOL "🔥 Fire Aesthetics Setup..."
            if [ -x "/home/user/fire_login_setup.sh" ]; then
                /home/user/fire_login_setup.sh
            fi
            ;;
            
        # Configuration
        C1|c1)
            add_to_recent "Terminal Config"
            print_color $BLUE "🖥️ Opening Terminal Configuration..."
            if [ -x "$SCRIPT_DIR/kmscon-tui-config.sh" ]; then
                doas "$SCRIPT_DIR/kmscon-tui-config.sh"
            fi
            ;;
        C2|c2)
            add_to_recent "TMUX Config"
            print_color $BLUE "📱 Opening TMUX Configuration..."
            if [ -x "$SCRIPT_DIR/tmux-tui-config.sh" ]; then
                "$SCRIPT_DIR/tmux-tui-config.sh"
            fi
            ;;
        C3|c3)
            add_to_recent "Qt Platform"
            print_color $BLUE "🎯 Opening Qt Platform Launcher..."
            if [ -x "$SCRIPT_DIR/qt-platform-launcher.sh" ]; then
                "$SCRIPT_DIR/qt-platform-launcher.sh"
            fi
            ;;
            
        # Boot & Control
        B1|b1)
            add_to_recent "Login Manager"
            print_color $YELLOW "⚡ Opening Login Manager..."
            if [ -x "/home/user/cli_login_manager.sh" ]; then
                /home/user/cli_login_manager.sh
            fi
            ;;
        B2|b2)
            add_to_recent "Terminal Boot"
            print_color $YELLOW "🔧 Enabling Terminal Boot..."
            if [ -x "$SCRIPT_DIR/enable-terminal-boot.sh" ]; then
                "$SCRIPT_DIR/enable-terminal-boot.sh"
            fi
            ;;
        B3|b3)
            add_to_recent "Remove SDDM"
            print_color $YELLOW "🗑️ SDDM Removal Tool..."
            if [ -x "/home/user/remove_sddm.sh" ]; then
                /home/user/remove_sddm.sh
            fi
            ;;
        B4|b4)
            add_to_recent "Restart TMUX"
            execute_system_action "restart-tmux"
            ;;
            
        # Applications
        A1|a1)
            add_to_recent "htop"
            print_color $GREEN "📊 Starting htop..."
            htop
            ;;
        A2|a2)
            add_to_recent "ranger"
            print_color $GREEN "📁 Starting ranger..."
            if command -v ranger >/dev/null 2>&1; then
                ranger
            else
                print_color $RED "ranger not installed"
            fi
            ;;
        A3|a3)
            add_to_recent "vim"
            print_color $GREEN "✏️ Starting vim..."
            vim
            ;;
        A4|a4)
            add_to_recent "w3m"
            print_color $GREEN "🌐 Starting w3m..."
            if command -v w3m >/dev/null 2>&1; then
                w3m
            else
                print_color $RED "w3m not installed"
            fi
            ;;
        A5|a5)
            add_to_recent "glances"
            print_color $GREEN "💻 Starting glances..."
            if command -v glances >/dev/null 2>&1; then
                glances
            else
                print_color $RED "glances not installed"
            fi
            ;;
        A6|a6)
            add_to_recent "Launch App"
            print_color $GREEN "🚀 Opening App Launcher..."
            if [ -x "$SCRIPT_DIR/launch_app.sh" ]; then
                "$SCRIPT_DIR/launch_app.sh"
            fi
            ;;
            
        # System Actions
        S1|s1)
            execute_system_action "reboot"
            ;;
        S2|s2)
            execute_system_action "shutdown"
            ;;
        S3|s3)
            execute_system_action "restart-tmux"
            ;;
        S4|s4)
            execute_system_action "fire-login"
            ;;
            
        # Recent commands
        R1|r1|R2|r2|R3|r3)
            local recent_num="${code:1:1}"
            local recent_cmd=$(get_recent_commands | sed -n "${recent_num}p" | cut -d'|' -f2- | sed 's/^ *//')
            if [ -n "$recent_cmd" ]; then
                print_color $MAGENTA "🔄 Repeating: $recent_cmd"
                # Try to execute the recent command
                execute_quick_action "$recent_cmd"
            fi
            ;;
            
        *)
            print_color $RED "❌ Unknown code: $code"
            sleep 1
            ;;
    esac
}

# Main quick access loop
main_quick_loop() {
    trap 'print_color $GREEN "Quick Access closed!"; exit 0' INT
    
    while true; do
        draw_quick_access
        echo -n "Enter code: "
        read -r user_input
        
        case "$user_input" in
            q|Q|quit|exit)
                print_color $GREEN "👋 Goodbye from Quick Access!"
                exit 0
                ;;
            r|R|refresh)
                continue
                ;;
            "")
                continue
                ;;
            *)
                execute_quick_action "$user_input"
                echo
                print_color $CYAN "Press Enter to continue..."
                read
                ;;
        esac
    done
}

# Start quick access
main_quick_loop