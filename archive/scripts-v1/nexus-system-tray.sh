#!/bin/bash
# NeXuS System Tray - Clock, Date, Volume, Network Status

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

# Beautiful Unicode symbols
CLOCK_SYMBOL="🕐"
CALENDAR_SYMBOL="📅"
VOLUME_SYMBOL="🔊"
VOLUME_MUTE="🔇"
NETWORK_SYMBOL="🌐"
WIFI_SYMBOL="📶"
BATTERY_SYMBOL="🔋"
NOTIFICATION_SYMBOL="🔔"
FIRE_SYMBOL="🔥"
STAR_SYMBOL="⭐"

print_color() {
    echo -e "${1}${2}${NC}"
}

# Get current time with fancy formatting
get_current_time() {
    date '+%H:%M:%S'
}

# Get current date with fancy formatting
get_current_date() {
    date '+%A, %B %d, %Y'
}

# Get volume level
get_volume_level() {
    if command -v amixer >/dev/null 2>&1; then
        local volume=$(amixer get Master | grep -o '[0-9]*%' | head -1)
        local muted=$(amixer get Master | grep '\[off\]')
        
        if [ -n "$muted" ]; then
            echo "MUTED"
        else
            echo "${volume:-0%}"
        fi
    else
        echo "N/A"
    fi
}

# Get network status
get_network_status() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$interface" ]; then
        local ip=$(ip addr show "$interface" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        echo "CONNECTED ($ip)"
    else
        echo "DISCONNECTED"
    fi
}

# Get battery status (if available)
get_battery_status() {
    local battery_dir="/sys/class/power_supply"
    if [ -d "$battery_dir" ]; then
        local bat_file=$(find "$battery_dir" -name "BAT*" | head -1)
        if [ -n "$bat_file" ]; then
            local capacity=$(cat "$bat_file/capacity" 2>/dev/null)
            local status=$(cat "$bat_file/status" 2>/dev/null)
            echo "${capacity:-?}% ($status)"
        else
            echo "AC POWER"
        fi
    else
        echo "AC POWER"
    fi
}

# Get notification count (from secure_notify_manager if available)
get_notification_count() {
    # Check if notification manager is running
    if pgrep -f "secure_notify_manager" >/dev/null; then
        echo "ACTIVE"
    else
        echo "READY"
    fi
}

# Create a beautiful mini calendar
get_mini_calendar() {
    cal | head -8 | tail -7
}

# Draw beautiful system tray
draw_tray() {
    clear
    
    # Get current data
    local current_time=$(get_current_time)
    local current_date=$(get_current_date)
    local volume_level=$(get_volume_level)
    local network_status=$(get_network_status)
    local battery_status=$(get_battery_status)
    local notification_status=$(get_notification_count)
    
    # Header
    print_color $CYAN "╔══════════════════════════════════════╗"
    print_color $CYAN "║        🔥 NeXuS System Tray 🔥      ║"
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # Time Display - Big and Bold
    local time_display="$current_time"
    printf "${CYAN}║${NC}              ${BOLD}${WHITE}${CLOCK_SYMBOL} %s${NC}               ${CYAN}║${NC}\n" "$time_display"
    
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # Date Display
    printf "${CYAN}║${NC} ${CALENDAR_SYMBOL} ${BOLD}Date:${NC}                              ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${BLUE}%-32s${NC}   ${CYAN}║${NC}\n" "$current_date"
    
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # Volume Control
    local volume_color=$GREEN
    local volume_icon=$VOLUME_SYMBOL
    if [ "$volume_level" = "MUTED" ]; then
        volume_color=$RED
        volume_icon=$VOLUME_MUTE
    fi
    
    printf "${CYAN}║${NC} ${volume_icon} ${BOLD}Volume:${NC} ${volume_color}%-20s${NC}   ${CYAN}║${NC}\n" "$volume_level"
    
    # Network Status
    local network_color=$GREEN
    if [[ "$network_status" == "DISCONNECTED" ]]; then
        network_color=$RED
    fi
    
    printf "${CYAN}║${NC} ${NETWORK_SYMBOL} ${BOLD}Network:${NC}                         ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${network_color}%-32s${NC}   ${CYAN}║${NC}\n" "$network_status"
    
    # Battery Status
    printf "${CYAN}║${NC} ${BATTERY_SYMBOL} ${BOLD}Power:${NC} ${GREEN}%-20s${NC}     ${CYAN}║${NC}\n" "$battery_status"
    
    # Notifications
    local notif_color=$BLUE
    if [ "$notification_status" = "ACTIVE" ]; then
        notif_color=$GREEN
    fi
    
    printf "${CYAN}║${NC} ${NOTIFICATION_SYMBOL} ${BOLD}Notifications:${NC} ${notif_color}%-12s${NC}     ${CYAN}║${NC}\n" "$notification_status"
    
    print_color $CYAN "╠══════════════════════════════════════╣"
    print_color $CYAN "║              📅 CALENDAR              ║"
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # Mini calendar
    get_mini_calendar | while read cal_line; do
        printf "${CYAN}║${NC} ${YELLOW}%-34s${NC}   ${CYAN}║${NC}\n" "$cal_line"
    done
    
    print_color $CYAN "╠══════════════════════════════════════╣"
    print_color $CYAN "║            🎛️ QUICK CONTROLS          ║"
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # Quick controls
    echo -e "${CYAN}║${NC} ${GREEN}[+]${NC} Vol Up   ${GREEN}[-]${NC} Vol Down      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}[m]${NC} Mute     ${GREEN}[n]${NC} Network Info  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}[c]${NC} Calendar ${GREEN}[t]${NC} Time Settings ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}[s]${NC} Scripts  ${GREEN}[q]${NC} Quit          ${CYAN}║${NC}"
    
    print_color $CYAN "╠══════════════════════════════════════╣"
    
    # System load indicator
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_stars=""
    local load_num=$(echo "$load_avg" | cut -d'.' -f1)
    
    # Create star rating based on load
    for ((i=1; i<=5; i++)); do
        if [ "$i" -le "$load_num" ]; then
            load_stars+="${STAR_SYMBOL}"
        else
            load_stars+="☆"
        fi
    done
    
    printf "${CYAN}║${NC} ${FIRE_SYMBOL} ${BOLD}System Load:${NC} %s ${YELLOW}%.2f${NC}     ${CYAN}║${NC}\n" "$load_stars" "$load_avg"
    
    print_color $CYAN "╚══════════════════════════════════════╝"
    
    # Status line
    echo -e "${BLUE}Auto-refresh every 5 seconds${NC} | ${YELLOW}Press key for quick action...${NC}"
}

# Handle user input for quick controls
handle_tray_input() {
    local choice
    read -t 5 -n 1 choice
    
    case "$choice" in
        +|=)
            if [ -x "/home/user/scripts/volume_control.sh" ]; then
                /home/user/scripts/volume_control.sh up
                print_color $GREEN "Volume increased"
                sleep 1
            fi
            ;;
        -|_)
            if [ -x "/home/user/scripts/volume_control.sh" ]; then
                /home/user/scripts/volume_control.sh down
                print_color $GREEN "Volume decreased"
                sleep 1
            fi
            ;;
        m|M)
            if [ -x "/home/user/scripts/volume_control.sh" ]; then
                /home/user/scripts/volume_control.sh mute
                print_color $YELLOW "Volume toggled"
                sleep 1
            fi
            ;;
        n|N)
            clear
            print_color $CYAN "🌐 Network Information:"
            print_color $CYAN "========================"
            ip addr show
            echo
            print_color $YELLOW "Press any key to return..."
            read -n 1
            ;;
        c|C)
            clear
            print_color $CYAN "📅 Full Calendar:"
            print_color $CYAN "=================="
            cal
            echo
            print_color $YELLOW "Press any key to return..."
            read -n 1
            ;;
        t|T)
            clear
            print_color $CYAN "⏰ Time & Date Information:"
            print_color $CYAN "============================"
            date
            echo
            print_color $BLUE "Timezone: $(date +%Z)"
            print_color $BLUE "Unix timestamp: $(date +%s)"
            echo
            print_color $YELLOW "Press any key to return..."
            read -n 1
            ;;
        s|S)
            clear
            print_color $CYAN "🔧 Available Scripts:"
            print_color $CYAN "====================="
            ls -1 /home/user/scripts/*.sh 2>/dev/null | head -10 | while read script; do
                local basename_script=$(basename "$script" .sh)
                echo -e "${GREEN}•${NC} ${BLUE}$basename_script${NC}"
            done
            echo
            print_color $YELLOW "Press any key to return..."
            read -n 1
            ;;
        q|Q)
            print_color $GREEN "Exiting NeXuS System Tray..."
            exit 0
            ;;
    esac
}

# Main tray loop
main_tray_loop() {
    # Trap Ctrl+C to exit gracefully
    trap 'print_color $GREEN "System Tray closed!"; exit 0' INT
    
    while true; do
        draw_tray
        handle_tray_input
    done
}

# Start the system tray
main_tray_loop