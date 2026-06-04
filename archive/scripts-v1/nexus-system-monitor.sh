#!/bin/bash
# NeXuS System Monitor - Real-time system monitoring dashboard

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

# Unicode symbols for pretty display
CPU_SYMBOL="🔥"
MEM_SYMBOL="💾"
DISK_SYMBOL="💿"
NET_SYMBOL="🌐"
TEMP_SYMBOL="🌡️"
LOAD_SYMBOL="⚡"
PROC_SYMBOL="⚙️"
UP_ARROW="▲"
DOWN_ARROW="▼"
CIRCLE="●"
SQUARE="■"

print_color() {
    echo -e "${1}${2}${NC}"
}

# Function to create progress bars
create_progress_bar() {
    local percentage=$1
    local width=${2:-20}
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    # Color based on percentage
    if [ "$percentage" -lt 50 ]; then
        echo -e "${GREEN}${bar}${NC} ${percentage}%"
    elif [ "$percentage" -lt 80 ]; then
        echo -e "${YELLOW}${bar}${NC} ${percentage}%"
    else
        echo -e "${RED}${bar}${NC} ${percentage}%"
    fi
}

# Get CPU usage
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "CPU:" | awk '{print $2}' | sed 's/%us,//')
    echo "${cpu_usage:-0}"
}

# Get memory usage
get_memory_usage() {
    local mem_info=$(free | grep Mem:)
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    local percentage=$((used * 100 / total))
    echo "$percentage"
}

# Get disk usage for root
get_disk_usage() {
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "${disk_usage:-0}"
}

# Get system temperature
get_temperature() {
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    if [ -f "$temp_file" ]; then
        local temp_raw=$(cat "$temp_file" 2>/dev/null)
        local temp_celsius=$((temp_raw / 1000))
        echo "${temp_celsius}°C"
    else
        echo "N/A"
    fi
}

# Get load averages
get_load_averages() {
    local load=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    echo "$load"
}

# Get top processes
get_top_processes() {
    ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
        local user=$(echo $line | awk '{print $1}')
        local pid=$(echo $line | awk '{print $2}')
        local cpu=$(echo $line | awk '{print $3}')
        local mem=$(echo $line | awk '{print $4}')
        local command=$(echo $line | awk '{print $11}' | cut -c1-15)
        
        printf "%-8s %6s %5s%% %5s%% %-15s\n" "$user" "$pid" "$cpu" "$mem" "$command"
    done
}

# Get network info
get_network_info() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$interface" ]; then
        local ip=$(ip addr show "$interface" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        echo "$interface: $ip"
    else
        echo "No network"
    fi
}

# Draw the beautiful monitor dashboard
draw_monitor() {
    clear
    
    # Header with fire emojis and styling
    print_color $CYAN "╔════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║          🔥💻 NeXuS System Monitor Dashboard 💻🔥              ║"
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    
    # System overview section
    print_color $CYAN "║                    📊 SYSTEM OVERVIEW                         ║"
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    
    # Get system data
    local cpu_usage=$(get_cpu_usage)
    local mem_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local temperature=$(get_temperature)
    local load_avg=$(get_load_averages)
    local network=$(get_network_info)
    local uptime_info=$(uptime -p)
    
    # CPU Section
    echo -e "${CYAN}║${NC} ${CPU_SYMBOL} ${BOLD}CPU Usage:${NC}     $(create_progress_bar ${cpu_usage} 25)         ${CYAN}║${NC}"
    
    # Memory Section  
    echo -e "${CYAN}║${NC} ${MEM_SYMBOL} ${BOLD}Memory Usage:${NC}  $(create_progress_bar ${mem_usage} 25)         ${CYAN}║${NC}"
    
    # Disk Section
    echo -e "${CYAN}║${NC} ${DISK_SYMBOL} ${BOLD}Disk Usage:${NC}    $(create_progress_bar ${disk_usage} 25)         ${CYAN}║${NC}"
    
    # Temperature and Load
    printf "${CYAN}║${NC} ${TEMP_SYMBOL} ${BOLD}Temperature:${NC}   %-20s ${LOAD_SYMBOL} ${BOLD}Load:${NC} %-15s ${CYAN}║${NC}\n" "$temperature" "$load_avg"
    
    # Network and Uptime
    printf "${CYAN}║${NC} ${NET_SYMBOL} ${BOLD}Network:${NC}       %-35s              ${CYAN}║${NC}\n" "$network"
    printf "${CYAN}║${NC} ⏰ ${BOLD}Uptime:${NC}        %-35s              ${CYAN}║${NC}\n" "$uptime_info"
    
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    print_color $CYAN "║                   ${PROC_SYMBOL} TOP PROCESSES                              ║"
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    
    # Header for processes
    printf "${CYAN}║${NC} ${BOLD}%-8s %6s %5s %5s %-15s${NC}                    ${CYAN}║${NC}\n" "USER" "PID" "CPU%" "MEM%" "COMMAND"
    print_color $CYAN "║────────────────────────────────────────────────────────────────║"
    
    # Top processes
    get_top_processes | while read proc_line; do
        printf "${CYAN}║${NC} ${WHITE}%-50s${NC}              ${CYAN}║${NC}\n" "$proc_line"
    done
    
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    print_color $CYAN "║                    💡 QUICK ACTIONS                           ║"
    print_color $CYAN "╠════════════════════════════════════════════════════════════════╣"
    
    # Quick actions
    echo -e "${CYAN}║${NC} ${GREEN}h${NC} - Full htop    ${GREEN}b${NC} - btop    ${GREEN}g${NC} - glances    ${GREEN}r${NC} - refresh   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}n${NC} - Network      ${GREEN}d${NC} - Disk    ${GREEN}m${NC} - Memory     ${GREEN}q${NC} - quit      ${CYAN}║${NC}"
    
    print_color $CYAN "╚════════════════════════════════════════════════════════════════╝"
    
    # Status line
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}Last updated: ${timestamp}${NC} | ${YELLOW}Press key for action or wait for auto-refresh...${NC}"
}

# Handle user input for quick actions
handle_input() {
    local choice
    read -t 3 -n 1 choice
    
    case "$choice" in
        h|H)
            clear
            print_color $YELLOW "Launching htop..."
            htop
            ;;
        b|B)
            if command -v btop >/dev/null 2>&1; then
                clear
                print_color $YELLOW "Launching btop..."
                btop
            else
                print_color $RED "btop not installed"
                sleep 2
            fi
            ;;
        g|G)
            if command -v glances >/dev/null 2>&1; then
                clear
                print_color $YELLOW "Launching glances..."
                glances
            else
                print_color $RED "glances not installed"
                sleep 2
            fi
            ;;
        n|N)
            clear
            print_color $YELLOW "Network Information:"
            ip addr show
            echo
            print_color $CYAN "Press any key to continue..."
            read -n 1
            ;;
        d|D)
            clear
            print_color $YELLOW "Disk Information:"
            df -h
            echo
            print_color $CYAN "Press any key to continue..."
            read -n 1
            ;;
        m|M)
            clear
            print_color $YELLOW "Memory Information:"
            free -h
            echo
            print_color $CYAN "Press any key to continue..."
            read -n 1
            ;;
        q|Q)
            print_color $GREEN "Exiting NeXuS System Monitor..."
            exit 0
            ;;
        r|R)
            # Just refresh - do nothing special
            ;;
    esac
}

# Main monitoring loop
main_loop() {
    # Trap Ctrl+C to exit gracefully
    trap 'print_color $GREEN "Goodbye!"; exit 0' INT
    
    while true; do
        draw_monitor
        handle_input
        sleep 1  # Brief pause before refresh
    done
}

# Start the system monitor
main_loop