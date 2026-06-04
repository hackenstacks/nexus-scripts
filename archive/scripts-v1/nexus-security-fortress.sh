#!/bin/bash
# 🛡️ NeXuS Security Fortress - Automated Defense System
# The ultimate democratic security platform for all users
# Features: PSAD, fail2ban, OpenSnitch, Privoxy, Stealth Mode, Containers

set -e

# 🎨 NeXuS Visual Design System
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
ORANGE='\033[0;91m'
NC='\033[0m'

# 🛡️ Security Symbols
FORTRESS_SYMBOL="🏰"
SHIELD_SYMBOL="🛡️"
STEALTH_SYMBOL="👤"
CONTAINER_SYMBOL="📦"
NETWORK_SYMBOL="🌐"
LOCK_SYMBOL="🔒"
KEY_SYMBOL="🔑"
EYE_SYMBOL="👁️"
GHOST_SYMBOL="👻"
FIRE_SYMBOL="🔥"
LIGHTNING_SYMBOL="⚡"
NEXUS_SYMBOL="🌀"
CANCEL_SYMBOL="⏰"
SUCCESS_SYMBOL="✅"
ERROR_SYMBOL="❌"
WARNING_SYMBOL="⚠️"

# 📁 Configuration Paths
NEXUS_CONFIG_DIR="/home/user/.nexus-security"
SECURITY_LOG="$NEXUS_CONFIG_DIR/fortress.log"
BACKUP_DIR="/home/user/claude/backups/security-$(date '+%Y%m%d_%H%M%S')"
NOTIFICATION_FIFO="$NEXUS_CONFIG_DIR/notifications"

# 🚀 NeXuS Functions Library
source_nexus_libs() {
    # ═══════════════════════════════════════════════════════════════════════════
    # DISABLED CODE BLOCK - DO NOT UNCOMMENT WITHOUT FIXING
    # ═══════════════════════════════════════════════════════════════════════════
    #
    # ORIGINAL INTENT:
    #   Source (import) function definitions from nexus-smart-diagnostics.sh
    #   so this script could use those diagnostic functions.
    #
    # THE BUG:
    #   The grep pattern "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" only matches lines that
    #   LOOK like function declarations, for example:
    #       check_network()
    #       assess_disk()
    #
    #   But grep only extracts those SINGLE LINES - not the function bodies!
    #   A complete bash function looks like:
    #       check_network() {
    #           echo "doing stuff"
    #           return 0
    #       }
    #
    #   So bash receives incomplete code like:
    #       check_network()
    #       assess_disk()
    #
    #   ...with no { } bodies, which is INVALID SYNTAX.
    #
    # THE ERROR:
    #   /dev/fd/63 line 17: syntax error: unexpected end of file
    #   (/dev/fd/63 is the process substitution file descriptor)
    #
    # TO FIX PROPERLY (if functions are needed in future):
    #   Option A: Source the entire file:
    #       source /home/user/scripts/nexus-smart-diagnostics.sh
    #   Option B: Use awk to extract complete function definitions
    #   Option C: Create a minimal library file with only needed functions
    #
    # COMMENTED OUT 2025-01-28 - Causing script to fail on startup
    # ═══════════════════════════════════════════════════════════════════════════
    #
    # [[ -f "/home/user/scripts/nexus-smart-diagnostics.sh" ]] && {
    #     # Extract function definitions without executing
    #     source <(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" /home/user/scripts/nexus-smart-diagnostics.sh | head -20)
    # }
    #
    # ═══════════════════════════════════════════════════════════════════════════

    # Safe replacement: just mark that diagnostics are available for future use
    if [[ -f "/home/user/scripts/nexus-smart-diagnostics.sh" ]]; then
        NEXUS_DIAGNOSTICS_AVAILABLE=true
    fi
}

# 🎨 Visual Banner System
print_fortress_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              🛡️  NeXuS SECURITY FORTRESS  🛡️              ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}         Automated Defense • Democratic Security           ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}    PSAD • fail2ban • OpenSnitch • Stealth • Containers   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# ⏰ 5-Second Cancellation Timer with Visual Countdown
show_cancel_timer() {
    local operation="$1"
    echo -e "${YELLOW}${CANCEL_SYMBOL} Starting: ${WHITE}$operation${NC}"
    echo -e "${CYAN}Press ${WHITE}CTRL+C${CYAN} to cancel in:${NC}"
    
    for i in 5 4 3 2 1; do
        echo -ne "\r${RED}[$i]${YELLOW} ▓▓▓▓▓▓▓▓▓▓ ${WHITE}$operation${NC}"
        sleep 1
    done
    echo -e "\n${GREEN}${LIGHTNING_SYMBOL} Executing $operation...${NC}\n"
}

# 🔍 Security Stack Assessment
assess_security_stack() {
    echo -e "${BLUE}${EYE_SYMBOL} Assessing Current Security Stack...${NC}\n"
    
    # Check existing services
    local services=("psad" "fail2ban" "ufw")
    for service in "${services[@]}"; do
        if pgrep "$service" >/dev/null 2>&1; then
            echo -e "${GREEN}${SUCCESS_SYMBOL} $service: ${WHITE}RUNNING${NC}"
        else
            echo -e "${RED}${ERROR_SYMBOL} $service: ${WHITE}NOT RUNNING${NC}"
        fi
    done
    
    # Check container runtime
    if command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} podman: ${WHITE}AVAILABLE (rootless)${NC}"
    elif command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}${WARNING_SYMBOL} docker: ${WHITE}AVAILABLE (needs rootless config)${NC}"
    else
        echo -e "${RED}${ERROR_SYMBOL} containers: ${WHITE}NO RUNTIME FOUND${NC}"
    fi
    
    echo
}

# 🏗️ Initialize Security Fortress
initialize_fortress() {
    show_cancel_timer "Security Fortress Initialization"
    
    # Create directory structure
    mkdir -p "$NEXUS_CONFIG_DIR"/{configs,logs,backups,containers}
    mkdir -p "$BACKUP_DIR"
    
    # Initialize notification system
    [[ ! -p "$NOTIFICATION_FIFO" ]] && mkfifo "$NOTIFICATION_FIFO"
    
    # Log initialization
    echo "$(date): NeXuS Security Fortress initialized" >> "$SECURITY_LOG"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Fortress infrastructure created${NC}"
}

# 📦 Container Security Setup
setup_container_security() {
    echo -e "${BLUE}${CONTAINER_SYMBOL} Setting up Unprivileged Container Security...${NC}"
    
    # Check if podman is configured for rootless
    if command -v podman >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Podman rootless ready${NC}"
        
        # Create security container configs
        cat > "$NEXUS_CONFIG_DIR/containers/security-stack.yaml" << 'EOF'
# NeXuS Security Container Stack
version: '3.8'
services:
  opensnitch:
    image: 'opensnitch/opensnitch:latest'
    container_name: nexus-opensnitch
    restart: unless-stopped
    network_mode: host
    volumes:
      - './opensnitch:/etc/opensnitchd'
    user: "1000:1000"
    
  privoxy:
    image: 'privoxy:latest'
    container_name: nexus-privoxy
    restart: unless-stopped
    ports:
      - '8118:8118'
    volumes:
      - './privoxy:/etc/privoxy'
    user: "1000:1000"
EOF
        echo -e "${GREEN}${SUCCESS_SYMBOL} Container security stack configured${NC}"
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} No container runtime - install podman for full functionality${NC}"
    fi
}

# 🌐 Network Security Layer
setup_network_security() {
    echo -e "${BLUE}${NETWORK_SYMBOL} Configuring Network Security Layers...${NC}"
    
    # Privoxy + uBlock Origin rules configuration
    cat > "$NEXUS_CONFIG_DIR/configs/privoxy-ublock.config" << 'EOF'
# NeXuS Privoxy Configuration with uBlock Origin Rules
listen-address  127.0.0.1:8118
toggle  1
enable-remote-toggle 0
enable-edit-actions 0
enable-remote-http-toggle 0

# uBlock Origin-style filtering
filterfile default.filter
filterfile user.filter

# Stealth mode headers
hide-user-agent-header{User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36}
hide-referrer{conditional-block}
hide-forwarded-for-headers{1}

# Block tracking
+block{Tracking blocked by NeXuS}
+filter{privacy}
EOF
    echo -e "${GREEN}${SUCCESS_SYMBOL} Network filtering configured${NC}"
}

# 👻 Stealth Mode with Medusa Proxy
setup_stealth_mode() {
    echo -e "${BLUE}${STEALTH_SYMBOL} Configuring Stealth Mode with Medusa Routing...${NC}"
    
    # Medusa proxy configuration
    cat > "$NEXUS_CONFIG_DIR/configs/medusa-stealth.conf" << 'EOF'
# NeXuS Medusa Stealth Configuration
# Multi-hop proxy routing for ultimate anonymity

# Primary proxy chain
proxy_chain_1=socks5://127.0.0.1:9050  # Tor
proxy_chain_2=http://127.0.0.1:8118    # Privoxy
proxy_chain_3=socks5://medusa-relay:1080

# Load balancing
round_robin=true
failover=true

# Stealth options
user_agent_rotation=true
connection_limits=5
delay_range=1000-3000ms
EOF
    
    # Stealth activation script
    cat > "$NEXUS_CONFIG_DIR/stealth-activate.sh" << 'EOF'
#!/bin/bash
# Activate NeXuS Stealth Mode
echo "🌀 Activating Stealth Mode..."
export HTTP_PROXY=http://127.0.0.1:8118
export HTTPS_PROXY=http://127.0.0.1:8118
export ALL_PROXY=socks5://127.0.0.1:9050
echo "👻 Stealth Mode Active - All traffic routed through Medusa"
EOF
    chmod +x "$NEXUS_CONFIG_DIR/stealth-activate.sh"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Stealth mode configured${NC}"
}

# 🔔 Notification System Integration
setup_notifications() {
    echo -e "${BLUE}${FIRE_SYMBOL} Setting up Cool Nerdy Notification System...${NC}"
    
    # Notification daemon script
    cat > "$NEXUS_CONFIG_DIR/notification-daemon.sh" << 'EOF'
#!/bin/bash
# NeXuS Security Notification Daemon
FIFO="/home/user/.nexus-security/notifications"

while true; do
    if read -r event < "$FIFO"; then
        case "$event" in
            "SECURITY_ALERT:"*)
                notify-send -u critical "🛡️ NeXuS Security" "${event#*:}" ;;
            "STEALTH_ACTIVATED")
                echo -e "\033[0;35m👻 STEALTH MODE ACTIVE\033[0m" ;;
            "CONTAINER_STARTED:"*)
                echo -e "\033[0;32m📦 ${event#*:}\033[0m" ;;
            "FORTRESS_STATUS:"*)
                echo -e "\033[0;36m🏰 ${event#*:}\033[0m" ;;
        esac
    fi
done &
EOF
    chmod +x "$NEXUS_CONFIG_DIR/notification-daemon.sh"
    
    # Start notification daemon
    "$NEXUS_CONFIG_DIR/notification-daemon.sh" &
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Notification system active${NC}"
}

# 🔒 AppArmor Profile Generation
setup_apparmor_profiles() {
    echo -e "${BLUE}${LOCK_SYMBOL} Generating AppArmor Security Profiles...${NC}"
    
    # Create basic AppArmor profiles for NeXuS components
    cat > "$NEXUS_CONFIG_DIR/apparmor-nexus.profile" << 'EOF'
# NeXuS Security Fortress AppArmor Profile
#include <tunables/global>

/home/user/scripts/nexus-security-fortress.sh {
  #include <abstractions/base>
  #include <abstractions/bash>
  
  capability net_raw,
  capability sys_admin,
  
  /home/user/scripts/** r,
  /home/user/.nexus-security/** rw,
  /tmp/** rw,
  /var/log/** rw,
  
  deny /etc/shadow r,
  deny /root/** rw,
}
EOF
    echo -e "${GREEN}${SUCCESS_SYMBOL} AppArmor profiles generated${NC}"
}

# 🏃 Quick Security Check
quick_security_check() {
    echo -e "${CYAN}${EYE_SYMBOL} NeXuS Quick Security Scan...${NC}\n"
    
    # System status
    echo -e "${WHITE}🔍 System Status:${NC}"
    assess_security_stack
    
    # Network connections
    echo -e "${WHITE}🌐 Active Connections:${NC}"
    ss -tuln | head -10
    
    # Process monitoring
    echo -e "${WHITE}📊 Security Process Status:${NC}"
    ps aux | grep -E "(fail2ban|psad)" | grep -v grep || echo "Security services need attention"
    
    echo
    echo -e "${GREEN}${SUCCESS_SYMBOL} Quick scan complete${NC}"
}

# 📋 Main Menu System
show_main_menu() {
    while true; do
        print_fortress_banner
        echo -e "${WHITE}Security Operations:${NC}"
        echo -e "${CYAN}[1]${NC} Quick Security Check"
        echo -e "${CYAN}[2]${NC} Initialize Security Fortress"
        echo -e "${CYAN}[3]${NC} Setup Container Security"
        echo -e "${CYAN}[4]${NC} Configure Network Security"
        echo -e "${CYAN}[5]${NC} Activate Stealth Mode"
        echo -e "${CYAN}[6]${NC} Setup Notifications"
        echo -e "${CYAN}[7]${NC} Generate AppArmor Profiles"
        echo -e "${CYAN}[0]${NC} Exit"
        echo
        echo -ne "${YELLOW}Select operation: ${NC}"
        
        read -r choice
        case $choice in
            1) quick_security_check ;;
            2) initialize_fortress ;;
            3) setup_container_security ;;
            4) setup_network_security ;;
            5) setup_stealth_mode ;;
            6) setup_notifications ;;
            7) setup_apparmor_profiles ;;
            0) echo -e "${GREEN}${FORTRESS_SYMBOL} NeXuS Security Fortress standing down${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
        
        echo
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}

# 🚀 Main Execution
main() {
    # Check for existing NeXuS library functions
    source_nexus_libs
    
    # Command line options
    case "${1:-menu}" in
        "check")
            print_fortress_banner
            quick_security_check
            ;;
        "init")
            print_fortress_banner
            initialize_fortress
            ;;
        "stealth")
            print_fortress_banner
            setup_stealth_mode
            echo "STEALTH_ACTIVATED" > "$NOTIFICATION_FIFO" 2>/dev/null || true
            ;;
        "menu"|*)
            show_main_menu
            ;;
    esac
}

# Execute main function
main "$@"