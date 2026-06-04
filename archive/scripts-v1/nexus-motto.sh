#!/bin/bash
# 🌀 NeXuS Motto Display Script
# System identification and philosophy banner
#
# 🔥 Sane! Simple! Secure! NeXuS
#    Because working together everyone achieves MORE
# 🌀 NeXuS NetWoRk - The Path to Individual Freedom

# NeXuS Colors (for terminal output)
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'

# Display modes
show_full_banner() {
    echo -e "${YELLOW}🔥━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━🔥${RESET}"
    echo -e "${RED}                                                                                    ${RESET}"
    echo -e "${RED}    🔥 ${YELLOW}Sane! Simple! Secure! NeXuS${RED} 🔥                                          ${RESET}"
    echo -e "${RED}       ${CYAN}Because working together everyone achieves MORE${RED}                       ${RESET}"
    echo -e "${RED}                                                                                    ${RESET}"
    echo -e "${BLUE}    🌀 ${GREEN}NeXuS NetWoRk - The Path to Individual Freedom${BLUE} 🌀                     ${RESET}"
    echo -e "${RED}                                                                                    ${RESET}"
    echo -e "${YELLOW}🔥━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━🔥${RESET}"
}

show_compact_banner() {
    echo -e "${RED}🔥 ${YELLOW}Sane! Simple! Secure! NeXuS${RED} 🔥 ${CYAN}Working together → MORE${RESET}"
    echo -e "${BLUE}🌀 ${GREEN}NeXuS NetWoRk - The Path to Individual Freedom${BLUE} 🌀${RESET}"
}

show_mini_banner() {
    echo -e "${RED}🔥${YELLOW}NeXuS${RED}🔥 ${BLUE}🌀${GREEN}The Path to Individual Freedom${BLUE}🌀${RESET}"
}

show_motto_only() {
    echo "🔥 Sane! Simple! Secure! NeXuS"
    echo "   Because working together everyone achieves MORE"
}

show_network_only() {
    echo "🌀 NeXuS NetWoRk - The Path to Individual Freedom"
}

show_ascii_art() {
    echo -e "${YELLOW}"
    cat << 'EOF'
    ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗
    ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝
    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗
    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║
    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║
    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
EOF
    echo -e "${RESET}"
    echo -e "${RED}    🔥 Sane! Simple! Secure! 🔥${RESET}"
    echo -e "${BLUE}🌀 The Path to Individual Freedom 🌀${RESET}"
}

show_system_info() {
    echo -e "${CYAN}🌀 NeXuS System Information:${RESET}"
    echo -e "   ${GREEN}Node ID:${RESET} $(hostname)"
    echo -e "   ${GREEN}Kernel:${RESET} $(uname -r)"
    echo -e "   ${GREEN}Uptime:${RESET} $(uptime -p 2>/dev/null || echo "Unknown")"
    echo -e "   ${GREEN}Philosophy:${RESET} Sane! Simple! Secure!"
    echo -e "   ${GREEN}Mission:${RESET} The Path to Individual Freedom"
    echo -e "   ${GREEN}Method:${RESET} Working together → MORE"
}

show_usage() {
    cat << 'EOF'
🌀 NeXuS Motto Display Script

Usage:
  nexus-motto.sh [command]

Commands:
  full      - Full decorative banner
  compact   - Compact two-line version  
  mini      - Single line minimal
  motto     - Just the motto
  network   - Just the network tagline
  ascii     - ASCII art version
  info      - System information with motto
  random    - Random display style

Examples:
  nexus-motto.sh full     # Login banner
  nexus-motto.sh compact  # Terminal prompt
  nexus-motto.sh mini     # Status bar
  nexus-motto.sh info     # System summary

Integration:
  # Add to shell startup:
  ~/scripts/nexus-motto.sh compact
  
  # In tmux status:
  #(~/scripts/nexus-motto.sh mini)
  
  # SSH login banner:
  ~/scripts/nexus-motto.sh full
EOF
}

# Random display mode
show_random() {
    modes=("full" "compact" "mini" "ascii")
    mode=${modes[$RANDOM % ${#modes[@]}]}
    case $mode in
        full) show_full_banner ;;
        compact) show_compact_banner ;;
        mini) show_mini_banner ;;
        ascii) show_ascii_art ;;
    esac
}

# Main execution
case "$1" in
    full|banner)
        show_full_banner
        ;;
    compact)
        show_compact_banner
        ;;
    mini|small)
        show_mini_banner
        ;;
    motto)
        show_motto_only
        ;;
    network)
        show_network_only
        ;;
    ascii|art)
        show_ascii_art
        ;;
    info|system)
        show_system_info
        ;;
    random|rand)
        show_random
        ;;
    *)
        show_usage
        ;;
esac