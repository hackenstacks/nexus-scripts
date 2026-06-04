#!/bin/bash
# NeXuS App Launcher - CLI Application Menu

SCRIPT_DIR="/home/user/scripts"
APPS_DIR="/home/user/apps"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

# Script categories from your collection
declare -A SCRIPT_CATEGORIES=(
    ["System Management"]="cli_login_manager.sh remove_sddm.sh fire_login_setup.sh"
    ["Configuration"]="kmscon-tui-config.sh tmux-tui-config.sh"
    ["Boot Management"]="enable-terminal-boot.sh enable-gui-boot.sh boot-mode-selector.sh"
    ["Qt Applications"]="qt-platform-launcher.sh qt-app-examples.sh"
    ["Notifications"]="secure_notify_manager.sh notification-service.sh attention.sh"
    ["Audio/Media"]="volume_control.sh"
    ["Network"]="remote_notify.sh send_remote_notification.sh"
    ["Development"]="character-generator AI-projects universal-ai-proxy"
    ["Utilities"]="launch_app.sh cli_clipboard.sh"
)

# Available CLI applications
declare -A CLI_APPS=(
    ["System Monitor"]="htop btop glances"
    ["File Managers"]="ranger nnn mc pcmanfm-qt"
    ["Text Editors"]="vim nvim nano micro kwrite"
    ["Terminal Apps"]="tmux screen fish zsh"
    ["Network Tools"]="curl wget w3m lynx"
    ["Media Players"]="mpv vlc cmus"
    ["System Tools"]="doas ps kill df du"
)

# Draw the main menu
draw_menu() {
    clear
    print_color $CYAN "┌─────────────────────────────────────────────────┐"
    print_color $CYAN "│               🚀 NeXuS App Launcher             │"
    print_color $CYAN "├─────────────────────────────────────────────────┤"
    print_color $CYAN "│                                                 │"
    
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🔧 System Scripts & Management          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} ⚙️  Configuration Tools                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🖥️  CLI Applications                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 🎯 Qt Applications (Platform Select)    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 📊 System Monitoring Tools             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 📁 File Managers                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}7.${NC} ✏️  Text Editors                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 🌐 Network Tools                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}9.${NC} 🎵 Media Players                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}S.${NC} 🔍 Search All Scripts                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}F.${NC} 🚀 Fuzzy Launch (fzf)                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}R.${NC} 🔄 Refresh Menu                        ${CYAN}│${NC}"
    
    print_color $CYAN "│                                                 │"
    print_color $CYAN "└─────────────────────────────────────────────────┘"
    echo
    print_color $YELLOW "Select option [1-9, S, F, R, q to quit]: "
}

# Launch system scripts
launch_system_scripts() {
    clear
    print_color $CYAN "🔧 System Scripts & Management"
    echo "================================"
    echo
    
    local scripts=(
        "cli_login_manager.sh:CLI Login Management"
        "remove_sddm.sh:Remove SDDM Display Manager"
        "fire_login_setup.sh:Fire Aesthetics Setup"
        "enable-terminal-boot.sh:Enable Terminal Boot"
        "enable-gui-boot.sh:Enable GUI Boot"
        "secure_notify_manager.sh:Notification Manager"
    )
    
    for i in "${!scripts[@]}"; do
        local script_info="${scripts[i]}"
        local script_name="${script_info%%:*}"
        local description="${script_info##*:}"
        
        if [ -f "$SCRIPT_DIR/$script_name" ]; then
            echo -e "${GREEN}$((i+1)).${NC} ${BLUE}$script_name${NC} - $description"
        fi
    done
    
    echo
    read -p "Select script number (or Enter to return): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#scripts[@]}" ]; then
        local selected_script="${scripts[$((choice-1))]}"
        local script_name="${selected_script%%:*}"
        
        if [ -f "$SCRIPT_DIR/$script_name" ]; then
            echo
            print_color $YELLOW "Launching: $script_name"
            echo "Press Ctrl+C to return to menu..."
            sleep 2
            "$SCRIPT_DIR/$script_name"
        fi
    fi
}

# Launch configuration tools
launch_config_tools() {
    clear
    print_color $CYAN "⚙️ Configuration Tools"
    echo "======================="
    echo
    
    local tools=(
        "kmscon-tui-config.sh:KMSCON Terminal Configuration"
        "tmux-tui-config.sh:TMUX Configuration Manager"
        "qt-platform-launcher.sh:Qt Platform Configuration"
    )
    
    for i in "${!tools[@]}"; do
        local tool_info="${tools[i]}"
        local tool_name="${tool_info%%:*}"
        local description="${tool_info##*:}"
        
        if [ -f "$SCRIPT_DIR/$tool_name" ]; then
            echo -e "${GREEN}$((i+1)).${NC} ${BLUE}$tool_name${NC} - $description"
        fi
    done
    
    echo
    read -p "Select tool number (or Enter to return): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#tools[@]}" ]; then
        local selected_tool="${tools[$((choice-1))]}"
        local tool_name="${selected_tool%%:*}"
        
        if [ -f "$SCRIPT_DIR/$tool_name" ]; then
            echo
            print_color $YELLOW "Launching: $tool_name"
            echo "Press Ctrl+C to return to menu..."
            sleep 2
            doas "$SCRIPT_DIR/$tool_name"
        fi
    fi
}

# Launch CLI applications
launch_cli_apps() {
    local category="$1"
    clear
    print_color $CYAN "🖥️ CLI Applications - $category"
    echo "======================================="
    echo
    
    case "$category" in
        "monitor")
            local apps=("htop" "btop" "glances" "top" "iotop" "nethogs")
            ;;
        "filemanager")
            local apps=("ranger" "nnn" "mc" "pcmanfm-qt")
            ;;
        "editor")
            local apps=("vim" "nvim" "nano" "micro" "emacs")
            ;;
        "network")
            local apps=("curl" "wget" "w3m" "lynx" "nmap" "netstat")
            ;;
        "media")
            local apps=("mpv" "vlc" "cmus" "mocp" "alsamixer")
            ;;
        *)
            local apps=("htop" "ranger" "vim" "w3m" "mpv")
            ;;
    esac
    
    for i in "${!apps[@]}"; do
        local app="${apps[i]}"
        if command -v "$app" >/dev/null 2>&1; then
            echo -e "${GREEN}$((i+1)).${NC} ${BLUE}$app${NC} - $(which $app)"
        else
            echo -e "${RED}$((i+1)).${NC} ${YELLOW}$app${NC} - Not installed"
        fi
    done
    
    echo
    read -p "Select application number (or Enter to return): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#apps[@]}" ]; then
        local selected_app="${apps[$((choice-1))]}"
        
        if command -v "$selected_app" >/dev/null 2>&1; then
            echo
            print_color $YELLOW "Launching: $selected_app"
            echo "Press Ctrl+C to return to menu..."
            sleep 2
            "$selected_app"
        else
            print_color $RED "Application not installed: $selected_app"
            sleep 2
        fi
    fi
}

# Fuzzy launcher using fzf
fuzzy_launch() {
    clear
    print_color $CYAN "🚀 Fuzzy Launcher (fzf)"
    echo
    
    if ! command -v fzf >/dev/null 2>&1; then
        print_color $RED "fzf not installed. Install with: doas apk add fzf"
        sleep 3
        return
    fi
    
    # Combine all available options
    local options=(
        # System scripts
        $(find "$SCRIPT_DIR" -name "*.sh" -executable | xargs basename -s .sh)
        # CLI applications  
        $(compgen -c | sort | uniq)
    )
    
    local selected=$(printf '%s\n' "${options[@]}" | fzf --prompt="Launch: " --height=20 --reverse)
    
    if [ -n "$selected" ]; then
        echo
        print_color $YELLOW "Launching: $selected"
        
        # Check if it's a script first
        if [ -f "$SCRIPT_DIR/$selected.sh" ]; then
            "$SCRIPT_DIR/$selected.sh"
        elif command -v "$selected" >/dev/null 2>&1; then
            "$selected"
        else
            print_color $RED "Command not found: $selected"
            sleep 2
        fi
    fi
}

# Search all scripts
search_scripts() {
    clear
    print_color $CYAN "🔍 Search All Scripts"
    echo "===================="
    echo
    
    read -p "Enter search term: " search_term
    
    if [ -n "$search_term" ]; then
        echo
        print_color $YELLOW "Searching for: $search_term"
        echo
        
        # Search script names and descriptions
        find "$SCRIPT_DIR" -name "*.sh" -exec grep -l "$search_term" {} \; 2>/dev/null | while read script; do
            local basename_script=$(basename "$script")
            echo -e "${GREEN}●${NC} ${BLUE}$basename_script${NC} - $(dirname $script)"
        done
        
        echo
        read -p "Press Enter to continue..."
    fi
}

# Main menu loop
main_loop() {
    while true; do
        draw_menu
        read -r choice
        
        case "$choice" in
            1) launch_system_scripts ;;
            2) launch_config_tools ;;
            3) launch_cli_apps "general" ;;
            4) 
                echo
                print_color $YELLOW "Qt Platform Launcher"
                "$SCRIPT_DIR/qt-platform-launcher.sh"
                ;;
            5) launch_cli_apps "monitor" ;;
            6) launch_cli_apps "filemanager" ;;
            7) launch_cli_apps "editor" ;;
            8) launch_cli_apps "network" ;;
            9) launch_cli_apps "media" ;;
            [Ss]) search_scripts ;;
            [Ff]) fuzzy_launch ;;
            [Rr]) continue ;;
            [Qq]|"") 
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "Invalid option: $choice"
                sleep 1
                ;;
        esac
    done
}

# Start the application launcher
main_loop