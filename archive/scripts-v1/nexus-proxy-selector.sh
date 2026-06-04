#!/bin/bash

# NeXuS Proxy Setup Selector
# Choose between Basic (no admin) or Enhanced (admin required) proxy setup
# Sane • Simple • Secure - User decides the level

set -e

# Fire aesthetics for NeXuS
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_fire() {
    echo -e "${RED}🔥${YELLOW}🔥${WHITE}🔥${CYAN} $1 ${PURPLE}🔥${YELLOW}🔥${RED}🔥${NC}"
}

print_status() {
    echo -e "${BLUE}📊 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️ $1${NC}"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}            🌐 NeXuS PROXY SETUP SELECTOR 🌐           ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}      Choose Your Anonymous Proxy Configuration Level     ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}              Sane • Simple • Secure Options              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

show_basic_option() {
    echo -e "${GREEN}🌟 OPTION 1: BASIC ANONYMOUS PROXY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}What it includes:${NC}"
    echo -e "${GREEN}✅ User-level Tor proxy (no admin needed)${NC}"
    echo -e "${GREEN}✅ Web-proxy torrent streaming${NC}"
    echo -e "${GREEN}✅ Gateway VM with user networking${NC}"
    echo -e "${GREEN}✅ Anonymous browsing and torrenting${NC}"
    echo -e "${GREEN}✅ SOCKS5 proxy on port 9060${NC}"
    echo
    echo -e "${WHITE}Perfect for:${NC}"
    echo -e "${CYAN}• Personal anonymous torrenting${NC}"
    echo -e "${CYAN}• Quick setup without complications${NC}"
    echo -e "${CYAN}• Users without admin access${NC}"
    echo -e "${CYAN}• Learning proxy concepts${NC}"
    echo
    echo -e "${YELLOW}⚠️ Limitations:${NC}"
    echo -e "${YELLOW}• VM uses user networking (port forwards only)${NC}"
    echo -e "${YELLOW}• Manual proxy configuration for some apps${NC}"
    echo -e "${YELLOW}• Single machine setup${NC}"
    echo
}

show_enhanced_option() {
    echo -e "${PURPLE}🚀 OPTION 2: ENHANCED PROXY INFRASTRUCTURE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${WHITE}What it includes:${NC}"
    echo -e "${GREEN}✅ Everything from Basic setup${NC}"
    echo -e "${GREEN}✅ Bridge networking (nexus-br0)${NC}"
    echo -e "${GREEN}✅ Direct VM IP access (10.152.152.10)${NC}"
    echo -e "${GREEN}✅ True transparent proxy capability${NC}"
    echo -e "${GREEN}✅ Enterprise-grade network isolation${NC}"
    echo -e "${GREEN}✅ Support for multiple client machines${NC}"
    echo
    echo -e "${WHITE}Perfect for:${NC}"
    echo -e "${CYAN}• Professional proxy infrastructure${NC}"
    echo -e "${CYAN}• Multiple devices through same gateway${NC}"
    echo -e "${CYAN}• Advanced networking enthusiasts${NC}"
    echo -e "${CYAN}• Maximum anonymity features${NC}"
    echo
    echo -e "${RED}🔐 Requirements:${NC}"
    echo -e "${RED}• Admin privileges (doas password)${NC}"
    echo -e "${RED}• Bridge network setup${NC}"
    echo -e "${RED}• iptables configuration${NC}"
    echo
}

show_comparison() {
    echo -e "${WHITE}📊 QUICK COMPARISON${NC}"
    echo -e "${CYAN}╭────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${WHITE} Feature                  │ Basic    │ Enhanced      ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${WHITE} Admin privileges needed │ No       │ Yes           ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Setup time              │ 30 sec   │ 2-3 min       ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Anonymous torrenting    │ ✅       │ ✅            ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Web proxy browsing      │ ✅       │ ✅            ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Gateway VM isolation    │ ✅       │ ✅            ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Direct VM access        │ No       │ Yes           ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Transparent proxy       │ Limited  │ Full          ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Multiple clients        │ No       │ Yes           ${CYAN}│${NC}"
    echo -e "${CYAN}│${WHITE} Network complexity      │ Simple   │ Advanced      ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────╯${NC}"
    echo
}

get_user_choice() {
    while true; do
        echo -e "${WHITE}Choose your NeXuS proxy setup:${NC}"
        echo -e "${GREEN}1)${NC} Basic Anonymous Proxy ${GREEN}(Recommended for most users)${NC}"
        echo -e "${PURPLE}2)${NC} Enhanced Proxy Infrastructure ${PURPLE}(Advanced users)${NC}"
        echo -e "${CYAN}3)${NC} Show detailed comparison"
        echo -e "${YELLOW}4)${NC} Exit"
        echo
        read -p "Enter your choice [1-4]: " choice
        
        case $choice in
            1)
                return 1
                ;;
            2)
                return 2
                ;;
            3)
                clear
                show_banner
                show_comparison
                show_basic_option
                show_enhanced_option
                ;;
            4)
                echo -e "${CYAN}Exiting NeXuS proxy selector...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1, 2, 3, or 4.${NC}"
                echo
                ;;
        esac
    done
}

run_basic_setup() {
    print_fire "Starting Basic NeXuS Proxy Setup"
    echo -e "${GREEN}No admin privileges required!${NC}"
    echo
    
    # Check if hybrid launcher exists
    if [[ -f "$SCRIPT_DIR/nexus-hybrid-proxy-launcher.sh" ]]; then
        print_status "Launching basic setup..."
        # Run without bridge networking prompts
        NEXUS_BASIC_MODE=1 "$SCRIPT_DIR/nexus-hybrid-proxy-launcher.sh" start
    else
        print_warning "Hybrid launcher not found, running individual components..."
        
        # Start Gateway VM
        if [[ -f "/home/user/gateway-vm/scripts/start-gateway.sh" ]]; then
            print_status "Starting Gateway VM..."
            /home/user/gateway-vm/scripts/start-gateway.sh
        fi
        
        # Start user proxy
        if [[ -f "$SCRIPT_DIR/nexus-user-proxy.sh" ]]; then
            print_status "Starting user-level proxy..."
            "$SCRIPT_DIR/nexus-user-proxy.sh" start
        fi
        
        # Start web-proxy
        print_status "Starting web-proxy..."
        cd /home/user/git/web-proxy && npm start &
        
        echo
        print_success "Basic setup complete!"
        print_info "Access web interface: http://localhost:3000 or http://localhost:3001"
    fi
}

run_enhanced_setup() {
    print_fire "Starting Enhanced NeXuS Proxy Infrastructure"
    echo -e "${RED}This setup requires admin privileges${NC}"
    echo
    
    # Warning about admin requirements
    echo -e "${YELLOW}⚠️ This setup will prompt for your password to:${NC}"
    echo -e "${CYAN}   • Create bridge network (nexus-br0)${NC}"
    echo -e "${CYAN}   • Configure iptables rules${NC}"
    echo -e "${CYAN}   • Enable IP forwarding${NC}"
    echo
    
    echo -e "${WHITE}Continue with enhanced setup? [y/N]:${NC} \c"
    read confirm
    echo
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo -e "${CYAN}Switching to basic setup...${NC}"
        run_basic_setup
        return
    fi
    
    # Run enhanced setup
    if [[ -f "$SCRIPT_DIR/nexus-hybrid-proxy-launcher.sh" ]]; then
        print_status "Launching enhanced setup..."
        # Set environment variable to force enhanced mode
        NEXUS_ENHANCED_MODE=1 "$SCRIPT_DIR/nexus-hybrid-proxy-launcher.sh" start
    else
        print_warning "Hybrid launcher not found, running manual enhanced setup..."
        
        # Create bridge network
        if [[ -f "/home/user/gateway-vm/scripts/create-nexus-network.sh" ]]; then
            print_status "Creating bridge network..."
            doas /home/user/gateway-vm/scripts/create-nexus-network.sh
        fi
        
        # Start Gateway VM
        print_status "Starting Gateway VM with bridge networking..."
        /home/user/gateway-vm/scripts/start-gateway.sh
        
        # Configure transparent proxy in VM (requires SSH access)
        print_status "Enhanced networking requires additional VM configuration..."
        print_info "You may need to SSH into the VM to complete transparent proxy setup"
        print_info "SSH command: ssh user@10.152.152.10 (or ssh -p 2222 user@localhost)"
        
        # Start user proxy
        if [[ -f "$SCRIPT_DIR/nexus-user-proxy.sh" ]]; then
            "$SCRIPT_DIR/nexus-user-proxy.sh" start
        fi
        
        # Start web-proxy
        cd /home/user/git/web-proxy && HTTP_PROXY=http://10.152.152.10:8118 npm start &
        
        echo
        print_success "Enhanced setup initiated!"
        print_info "Gateway VM accessible at: 10.152.152.10"
        print_info "Web interface: http://localhost:3000 or http://localhost:3001"
    fi
}

show_status() {
    print_fire "Current NeXuS Proxy Status"
    
    # Check Gateway VM
    if pgrep -f "qemu.*gateway" > /dev/null; then
        print_success "Gateway VM: RUNNING"
    else
        print_warning "Gateway VM: NOT RUNNING"
    fi
    
    # Check user Tor
    if pgrep -f "user-torrc" > /dev/null; then
        print_success "User Tor: RUNNING"
    else
        print_warning "User Tor: NOT RUNNING"
    fi
    
    # Check web-proxy
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Web-Proxy: ACCESSIBLE (http://localhost:3000)"
    elif curl -s http://localhost:3001 > /dev/null 2>&1; then
        print_success "Web-Proxy: ACCESSIBLE (http://localhost:3001)"
    else
        print_warning "Web-Proxy: NOT ACCESSIBLE"
    fi
    
    # Check bridge network
    if ip link show nexus-br0 > /dev/null 2>&1; then
        print_success "Bridge Network: ACTIVE (nexus-br0)"
    else
        print_info "Bridge Network: NOT CONFIGURED (basic mode)"
    fi
    
    echo
}

main() {
    case "${1:-menu}" in
        "basic")
            run_basic_setup
            ;;
        "enhanced")
            run_enhanced_setup
            ;;
        "status")
            show_status
            ;;
        "menu"|*)
            show_banner
            show_basic_option
            show_enhanced_option
            get_user_choice
            choice=$?
            
            if [[ $choice -eq 1 ]]; then
                run_basic_setup
            elif [[ $choice -eq 2 ]]; then
                run_enhanced_setup
            fi
            ;;
    esac
}

# Run main function
main "$@"