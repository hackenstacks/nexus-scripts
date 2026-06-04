#!/bin/bash

# NeXuS Unified Proxy Setup
# One script to rule them all - handles everything automatically
# Sane • Simple • Secure - Just run and go!

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
GATEWAY_SCRIPTS="/home/user/gateway-vm/scripts"
WEB_PROXY_DIR="/home/user/git/web-proxy"
LOG_FILE="/tmp/nexus-unified-setup.log"

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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}            🌐 NeXuS UNIFIED PROXY SETUP 🌐            ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}        One Script • Complete Anonymous Infrastructure     ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}              Sane • Simple • Secure • Just Run!          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

detect_setup_mode() {
    # Check if user can run doas without manual intervention
    print_status "Detecting optimal setup mode..."
    
    # Test if we already have doas access or if user prefers basic
    if [[ "${NEXUS_FORCE_BASIC:-0}" == "1" ]]; then
        echo "basic"
        return
    fi
    
    if [[ "${NEXUS_FORCE_ENHANCED:-0}" == "1" ]]; then
        echo "enhanced"
        return
    fi
    
    # Try to detect if doas is configured for passwordless access
    if timeout 2 doas true 2>/dev/null; then
        print_success "Detected passwordless doas access - using enhanced mode"
        echo "enhanced"
        return
    fi
    
    # Check if user wants enhanced features
    print_warning "Enhanced mode requires admin privileges for bridge networking"
    print_status "Basic mode works perfectly for anonymous torrenting (no admin needed)"
    print_status "Enhanced mode adds professional networking features (requires password)"
    echo
    echo -e "${WHITE}Choose setup mode:${NC}"
    echo -e "${GREEN}1) Basic Mode${NC} - Anonymous proxy, no admin needed ${GREEN}(Recommended)${NC}"
    echo -e "${PURPLE}2) Enhanced Mode${NC} - Full bridge networking, requires password"
    echo -e "${CYAN}3) Auto-detect${NC} - Try enhanced, fall back to basic if needed"
    echo
    read -p "Enter choice [1-3]: " mode_choice
    
    case $mode_choice in
        1)
            echo "basic"
            ;;
        2)
            echo "enhanced"
            ;;
        3|"")
            echo "auto"
            ;;
        *)
            print_warning "Invalid choice, using auto-detect mode"
            echo "auto"
            ;;
    esac
}

check_dependencies() {
    print_status "Checking NeXuS dependencies..."
    
    local missing=0
    
    # Check essential tools
    for tool in node npm tor curl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "Missing: $tool"
            missing=1
        fi
    done
    
    # Check gateway scripts
    if [[ ! -d "$GATEWAY_SCRIPTS" ]]; then
        print_error "Gateway scripts not found at $GATEWAY_SCRIPTS"
        missing=1
    fi
    
    # Check web-proxy
    if [[ ! -d "$WEB_PROXY_DIR" ]]; then
        print_error "Web-proxy not found at $WEB_PROXY_DIR"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        print_error "Missing dependencies - cannot continue"
        exit 1
    fi
    
    print_success "All dependencies available"
    log_event "Dependencies check passed"
}

setup_bridge_network_unified() {
    print_status "Setting up enhanced bridge networking..."
    
    # Check if bridge already exists
    if ip link show nexus-br0 >/dev/null 2>&1; then
        print_success "Bridge network already exists"
        return 0
    fi
    
    if [[ -f "$GATEWAY_SCRIPTS/create-nexus-network.sh" ]]; then
        print_warning "This requires admin privileges to create bridge network"
        echo -e "${CYAN}Running: doas $GATEWAY_SCRIPTS/create-nexus-network.sh${NC}"
        
        # Run with proper error handling
        if doas "$GATEWAY_SCRIPTS/create-nexus-network.sh"; then
            print_success "Bridge network created successfully"
            log_event "Bridge network setup completed"
            return 0
        else
            print_warning "Bridge setup failed - continuing with basic mode"
            log_event "Bridge network setup failed"
            return 1
        fi
    else
        print_error "Bridge setup script not found"
        return 1
    fi
}

start_gateway_vm() {
    print_status "Starting NeXuS Gateway VM..."
    
    # Check if already running
    if pgrep -f "qemu.*gateway" >/dev/null; then
        print_success "Gateway VM already running"
        log_event "Gateway VM already running"
        return 0
    fi
    
    if [[ -f "$GATEWAY_SCRIPTS/start-gateway.sh" ]]; then
        if "$GATEWAY_SCRIPTS/start-gateway.sh"; then
            print_success "Gateway VM started successfully"
            log_event "Gateway VM started"
            sleep 3  # Give VM time to initialize
            return 0
        else
            print_error "Failed to start Gateway VM"
            return 1
        fi
    else
        print_error "Gateway start script not found"
        return 1
    fi
}

start_user_proxy() {
    print_status "Starting user-level Tor proxy..."
    
    if [[ -f "$SCRIPT_DIR/nexus-user-proxy.sh" ]]; then
        if "$SCRIPT_DIR/nexus-user-proxy.sh" start; then
            print_success "User Tor proxy started"
            log_event "User proxy started"
            
            # Source the proxy environment
            if [[ -f "/home/user/.nexus-security/proxy-env.sh" ]]; then
                source "/home/user/.nexus-security/proxy-env.sh"
                print_success "Proxy environment loaded"
            fi
            
            return 0
        else
            print_warning "User proxy had issues, continuing anyway"
            return 1
        fi
    else
        print_error "User proxy script not found"
        return 1
    fi
}

start_web_proxy() {
    print_status "Starting web-proxy torrent engine..."
    
    # Kill any existing instances
    pkill -f "node.*index.js" 2>/dev/null || true
    
    cd "$WEB_PROXY_DIR" || {
        print_error "Cannot access web-proxy directory"
        return 1
    }
    
    # Check if bridge networking is available
    local proxy_config=""
    if ip link show nexus-br0 >/dev/null 2>&1 && timeout 2 nc -z 10.152.152.10 8118 2>/dev/null; then
        proxy_config="HTTP_PROXY=http://10.152.152.10:8118 HTTPS_PROXY=http://10.152.152.10:8118"
        print_success "Using enhanced bridge proxy configuration"
    else
        print_success "Using user-level proxy configuration"
    fi
    
    # Start web-proxy with appropriate config
    if [[ -n "$proxy_config" ]]; then
        eval "$proxy_config nohup npm start > /tmp/web-proxy.log 2>&1 &"
    else
        nohup npm start > /tmp/web-proxy.log 2>&1 &
    fi
    
    local web_proxy_pid=$!
    echo $web_proxy_pid > /tmp/web-proxy.pid
    
    # Wait and verify
    sleep 3
    if ps -p $web_proxy_pid > /dev/null 2>&1; then
        print_success "Web-proxy started (PID: $web_proxy_pid)"
        log_event "Web-proxy started"
        
        # Test accessibility
        local port=""
        for test_port in 3000 3001; do
            if curl -s "http://localhost:$test_port" > /dev/null 2>&1; then
                port=$test_port
                break
            fi
        done
        
        if [[ -n "$port" ]]; then
            print_success "Web-proxy accessible at http://localhost:$port"
            echo $port > /tmp/web-proxy-port.txt
            return 0
        else
            print_warning "Web-proxy started but not yet accessible"
            return 1
        fi
    else
        print_error "Web-proxy failed to start"
        return 1
    fi
}

show_final_status() {
    echo
    print_fire "NeXuS Unified Setup Complete"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    # Check all components
    local gateway_status="❌ NOT RUNNING"
    local tor_status="❌ NOT RUNNING"
    local webproxy_status="❌ NOT ACCESSIBLE"
    local bridge_status="ℹ️ NOT CONFIGURED (basic mode)"
    
    if pgrep -f "qemu.*gateway" >/dev/null; then
        gateway_status="✅ RUNNING"
    fi
    
    if pgrep -f "user-torrc" >/dev/null || nc -z localhost 9060 2>/dev/null; then
        tor_status="✅ RUNNING"
    fi
    
    local web_port=""
    if [[ -f /tmp/web-proxy-port.txt ]]; then
        web_port=$(cat /tmp/web-proxy-port.txt)
        webproxy_status="✅ ACCESSIBLE (http://localhost:$web_port)"
    fi
    
    if ip link show nexus-br0 >/dev/null 2>&1; then
        bridge_status="✅ ACTIVE (enhanced mode)"
    fi
    
    echo -e "${GREEN}$gateway_status${NC} Gateway VM"
    echo -e "${GREEN}$tor_status${NC} User Tor Proxy"
    echo -e "${GREEN}$webproxy_status${NC} Web-Proxy"
    echo -e "${CYAN}$bridge_status${NC} Bridge Network"
    
    echo
    print_fire "Usage Instructions"
    
    if [[ -n "$web_port" ]]; then
        echo -e "${WHITE}🌐 Web Interface: ${CYAN}http://localhost:$web_port${NC}"
        echo -e "${WHITE}🎬 Torrent Streaming: ${CYAN}http://localhost:$web_port/torrentStream?magnet=<your_magnet>${NC}"
        echo -e "${WHITE}🔒 Anonymous Browsing: Enter any website in the web form${NC}"
    fi
    
    echo -e "${WHITE}📊 Status Check: ${CYAN}$0 status${NC}"
    echo -e "${WHITE}🛑 Stop All: ${CYAN}$0 stop${NC}"
    echo -e "${WHITE}📋 Log File: ${CYAN}$LOG_FILE${NC}"
    
    echo
    print_success "Anonymous proxy infrastructure ready! 🚀"
}

run_unified_setup() {
    show_banner
    print_fire "Starting Unified NeXuS Proxy Setup"
    
    # Detect and set mode
    local mode=$(detect_setup_mode)
    log_event "Unified setup started in $mode mode"
    
    print_status "Setup mode: $mode"
    echo
    
    # Check dependencies
    check_dependencies
    
    # Start components in order
    start_gateway_vm
    
    # Try enhanced networking if requested
    local enhanced_success=0
    if [[ "$mode" == "enhanced" ]] || [[ "$mode" == "auto" ]]; then
        if setup_bridge_network_unified; then
            enhanced_success=1
            print_success "Enhanced networking configured"
        else
            if [[ "$mode" == "enhanced" ]]; then
                print_error "Enhanced mode failed - bridge networking not available"
                exit 1
            else
                print_warning "Enhanced mode failed - continuing with basic mode"
            fi
        fi
    fi
    
    start_user_proxy
    start_web_proxy
    
    show_final_status
    
    if [[ $enhanced_success -eq 1 ]]; then
        log_event "Unified setup completed successfully (enhanced mode)"
    else
        log_event "Unified setup completed successfully (basic mode)"
    fi
}

stop_all() {
    print_status "Stopping all NeXuS components..."
    
    # Stop web-proxy
    if [[ -f /tmp/web-proxy.pid ]]; then
        local pid=$(cat /tmp/web-proxy.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            rm -f /tmp/web-proxy.pid /tmp/web-proxy-port.txt
            print_success "Web-proxy stopped"
        fi
    fi
    
    # Stop user Tor
    if [[ -f "$SCRIPT_DIR/nexus-user-proxy.sh" ]]; then
        "$SCRIPT_DIR/nexus-user-proxy.sh" stop
    fi
    
    # Stop Gateway VM
    if [[ -f "$GATEWAY_SCRIPTS/stop-gateway.sh" ]]; then
        "$GATEWAY_SCRIPTS/stop-gateway.sh"
    fi
    
    print_success "All components stopped"
    log_event "All components stopped"
}

main() {
    case "${1:-start}" in
        "start")
            run_unified_setup
            ;;
        "stop")
            stop_all
            ;;
        "status")
            show_final_status
            ;;
        "basic")
            NEXUS_FORCE_BASIC=1 run_unified_setup
            ;;
        "enhanced")
            NEXUS_FORCE_ENHANCED=1 run_unified_setup
            ;;
        *)
            echo "Usage: $0 {start|stop|status|basic|enhanced}"
            echo
            echo "Commands:"
            echo "  start     - Auto-detect and start optimal setup"
            echo "  basic     - Force basic mode (no admin needed)"
            echo "  enhanced  - Force enhanced mode (requires admin)"
            echo "  stop      - Stop all components"
            echo "  status    - Show current status"
            exit 1
            ;;
    esac
}

# Initialize log
echo "$(date '+%Y-%m-%d %H:%M:%S'): NeXuS Unified Setup started" > "$LOG_FILE"

# Run main function
main "$@"