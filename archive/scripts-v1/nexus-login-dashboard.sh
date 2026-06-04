#!/bin/bash

# NeXuS Login Dashboard - Shows on first login

# Colors for welcome message
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_welcome() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${RED}🔥${YELLOW}💻${GREEN} Welcome to NeXuS System ${GREEN}💻${RED}🔥${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Quick Start Options:${NC}"
    echo -e "${YELLOW}1.${NC} ${BLUE}nexus-dashboard.sh${NC}     - Launch main dashboard"
    echo -e "${YELLOW}2.${NC} ${BLUE}tmux${NC}                   - Start terminal multiplexer"
    echo -e "${YELLOW}3.${NC} ${BLUE}nexus-app-launcher.sh${NC}  - Application menu"
    echo -e "${YELLOW}4.${NC} ${BLUE}ranger${NC}                 - File manager"
    echo ""
    echo -e "${CYAN}🚀 Press F12 for quick launcher | Ctrl+Z to suspend${NC}"
    echo -e "${CYAN}📚 Type: ${YELLOW}cat ~/NEXUS_CHEAT_SHEET.md${CYAN} for full help${NC}"
    echo ""
}

# Check if this is first login of the day
LAST_WELCOME_FILE=~/.nexus_last_welcome
TODAY=$(date +%Y-%m-%d)

if [ ! -f "$LAST_WELCOME_FILE" ] || [ "$(cat $LAST_WELCOME_FILE 2>/dev/null)" != "$TODAY" ]; then
    show_welcome
    echo "$TODAY" > "$LAST_WELCOME_FILE"
    
    # Give user time to read
    echo -n "Press Enter to continue or 'd' for dashboard: "
    read -t 10 choice
    
    case "$choice" in
        d|D) exec /home/user/scripts/nexus-dashboard.sh ;;
        *) ;;
    esac
fi