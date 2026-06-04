#!/bin/bash

# NeXuS Hybrid Proxy Launcher
# Sane • Simple • Secure NeXuS proxy orchestration
# Combines Gateway VM + Transparent Proxy + Web-Proxy for anonymous torrenting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_SCRIPTS="/home/user/gateway-vm/scripts"
WEB_PROXY_DIR="/home/user/git/web-proxy"
LOG_FILE="/tmp/nexus-hybrid-proxy.log"

# Fire aesthetics for NeXuS
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

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

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Check if running as root (we don't want this)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root!"
        print_warning "This script manages permissions safely without requiring root access"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    print_status "Checking NeXuS Hybrid Proxy dependencies..."
    
    local missing=0
    
    # Check if gateway scripts exist
    if [[ ! -d "$GATEWAY_SCRIPTS" ]]; then
        print_error "Gateway scripts not found at $GATEWAY_SCRIPTS"
        missing=1
    fi
    
    # Check if web-proxy exists
    if [[ ! -d "$WEB_PROXY_DIR" ]]; then
        print_error "Web-proxy not found at $WEB_PROXY_DIR"
        missing=1
    fi
    
    # Check for node/npm
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found - required for web-proxy"
        missing=1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm not found - required for web-proxy"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        print_error "Missing dependencies - cannot continue"
        exit 1
    fi
    
    print_success "All dependencies available"
    log "Dependencies check passed"
}

# Start Gateway VM (no special permissions needed for basic VM)
start_gateway_vm() {
    print_status "Starting NeXuS Gateway VM..."
    
    # Check if gateway is already running
    if pgrep -f "qemu.*gateway" > /dev/null; then
        print_success "Gateway VM already running"
        log "Gateway VM already running"
        
        # Check if we're in basic mode (no prompts)
        if [[ "${NEXUS_BASIC_MODE:-0}" == "1" ]]; then
            print_success "Running in basic mode (no admin privileges needed)"
        elif [[ "${NEXUS_ENHANCED_MODE:-0}" == "1" ]]; then
            print_status "Running in enhanced mode - setting up bridge networking"
            setup_bridge_network
        else
            # Ask if user wants to set up bridge networking (requires admin)
            echo
            print_status "Optional: Bridge networking setup (requires admin privileges)"
            print_warning "Current VM uses user networking (works but limited)"
            echo -e "${WHITE}Do you want to set up bridge networking for better VM integration? [y/N]${NC}"
            read -t 10 -r setup_bridge || setup_bridge="n"
            
            if [[ "$setup_bridge" =~ ^[Yy] ]]; then
                setup_bridge_network
            else
                print_success "Continuing with user networking (no admin needed)"
            fi
        fi
        
        return 0
    fi
    
    if [[ -f "$GATEWAY_SCRIPTS/start-gateway.sh" ]]; then
        cd "$GATEWAY_SCRIPTS"
        if ./start-gateway.sh; then
            print_success "Gateway VM started successfully"
            log "Gateway VM started"
            sleep 3  # Give VM time to initialize
            
            # Offer bridge networking setup
            echo
            print_status "Optional: Enhanced networking setup"
            echo -e "${WHITE}Set up bridge networking for better VM integration? [y/N]${NC}"
            read -t 10 -r setup_bridge || setup_bridge="n"
            
            if [[ "$setup_bridge" =~ ^[Yy] ]]; then
                setup_bridge_network
            fi
            
            return 0
        else
            print_warning "Gateway VM start had issues, continuing anyway"
            log "Gateway VM start had issues"
            return 1
        fi
    else
        print_error "Gateway start script not found"
        return 1
    fi
}

# Optional bridge network setup (requires admin)
setup_bridge_network() {
    print_status "Setting up bridge networking (requires admin privileges)..."
    
    if [[ -f "$GATEWAY_SCRIPTS/create-nexus-network.sh" ]]; then
        print_warning "This will prompt for admin password to create bridge network"
        echo -e "${CYAN}Running: doas $GATEWAY_SCRIPTS/create-nexus-network.sh${NC}"
        echo -e "${YELLOW}Please enter your password when prompted...${NC}"
        
        # Run doas directly (preserves TTY)
        if doas "$GATEWAY_SCRIPTS/create-nexus-network.sh"; then
            print_success "Bridge network created successfully"
            log "Bridge network setup completed"
            
            # Restart VM with bridge networking
            print_status "Restarting VM with bridge networking..."
            if [[ -f "$GATEWAY_SCRIPTS/stop-gateway.sh" ]]; then
                "$GATEWAY_SCRIPTS/stop-gateway.sh"
                sleep 2
                
                # Start with bridge networking (if there's a bridge start script)
                if [[ -f "$GATEWAY_SCRIPTS/start-gateway-bridge.sh" ]]; then
                    "$GATEWAY_SCRIPTS/start-gateway-bridge.sh"
                else
                    "$GATEWAY_SCRIPTS/start-gateway.sh"
                fi
            fi
        else
            print_warning "Bridge setup failed, continuing with user networking"
            log "Bridge network setup failed"
        fi
    else
        print_warning "Bridge network script not found"
    fi
}

# Check if Gateway VM is accessible
check_gateway_connectivity() {
    print_status "Checking Gateway VM connectivity..."
    
    # Test if gateway is responding on SSH port (user networking uses localhost:2222)
    if timeout 5 nc -z localhost 2222 2>/dev/null; then
        print_success "Gateway VM accessible via SSH (localhost:2222)"
        log "Gateway VM connectivity confirmed"
        # For user networking, we can't directly access internal proxy
        # but we know the VM is running
        return 0
    else
        print_warning "Gateway VM not accessible, will use direct connection"
        log "Gateway connectivity failed"
        return 1
    fi
}

# Start user-level proxy (no root required)
start_user_proxy() {
    print_status "Starting user-level proxy system..."
    
    # Check if user proxy script exists
    if [[ -f "/home/user/scripts/nexus-user-proxy.sh" ]]; then
        if /home/user/scripts/nexus-user-proxy.sh start; then
            print_success "User-level proxy started successfully"
            log "User-level proxy started"
            return 0
        else
            print_warning "User-level proxy had issues, continuing anyway"
            log "User-level proxy failed"
            return 1
        fi
    else
        print_warning "User-level proxy script not found"
        print_warning "Run without proxy (direct connection)"
        return 1
    fi
}

# Start web-proxy with appropriate proxy configuration
start_web_proxy() {
    print_status "Starting web-proxy with hybrid configuration..."
    
    cd "$WEB_PROXY_DIR" || {
        print_error "Cannot access web-proxy directory"
        return 1
    }
    
    # Kill any existing web-proxy processes
    pkill -f "node.*index.js" 2>/dev/null || true
    
    # Check if gateway is available for proxy
    local use_gateway=0
    if check_gateway_connectivity; then
        use_gateway=1
    fi
    
    # Start web-proxy with appropriate configuration
    if [[ $use_gateway -eq 1 ]]; then
        print_success "Starting web-proxy with Gateway VM available (user networking mode)"
        # Note: In user networking mode, we can't directly proxy through the VM
        # but the VM provides Tor exit point via SSH tunneling if configured
        nohup npm start > /tmp/web-proxy.log 2>&1 &
        log "Web-proxy started with gateway VM available"
    else
        print_success "Starting web-proxy with direct connection"
        nohup npm start > /tmp/web-proxy.log 2>&1 &
        log "Web-proxy started direct"
    fi
    
    local web_proxy_pid=$!
    echo $web_proxy_pid > /tmp/web-proxy.pid
    
    # Wait a moment and check if it started
    sleep 3
    if ps -p $web_proxy_pid > /dev/null 2>&1; then
        print_success "Web-proxy started successfully (PID: $web_proxy_pid)"
        return 0
    else
        print_error "Web-proxy failed to start"
        return 1
    fi
}

# Check web-proxy accessibility
check_web_proxy() {
    print_status "Verifying web-proxy accessibility..."
    
    for i in {1..10}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            print_success "Web-proxy accessible at http://localhost:3000"
            log "Web-proxy accessibility confirmed"
            return 0
        fi
        sleep 1
    done
    
    print_warning "Web-proxy not responding on http://localhost:3000"
    return 1
}

# Show status
show_status() {
    echo
    print_fire "NeXuS Hybrid Proxy Status"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    # Check Gateway VM
    if pgrep -f "qemu.*gateway" > /dev/null; then
        print_success "Gateway VM: RUNNING"
    else
        print_warning "Gateway VM: NOT RUNNING"
    fi
    
    # Check Gateway Proxy
    if timeout 2 nc -z 10.152.152.10 8118 2>/dev/null; then
        print_success "Gateway Proxy: ACCESSIBLE (10.152.152.10:8118)"
    else
        print_warning "Gateway Proxy: NOT ACCESSIBLE"
    fi
    
    # Check Web-proxy
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Web-Proxy: ACCESSIBLE (http://localhost:3000)"
    else
        print_warning "Web-Proxy: NOT ACCESSIBLE"
    fi
    
    # Check transparent proxy
    if pgrep tor > /dev/null; then
        print_success "Tor: RUNNING"
    else
        print_warning "Tor: NOT RUNNING"
    fi
    
    echo
    print_fire "Usage Instructions"
    echo -e "${WHITE}• Access web interface: ${CYAN}http://localhost:3000${NC}"
    echo -e "${WHITE}• Add magnet links for anonymous torrenting${NC}"
    echo -e "${WHITE}• Log file: ${CYAN}$LOG_FILE${NC}"
    echo
}

# Stop function
stop_hybrid_proxy() {
    print_status "Stopping NeXuS Hybrid Proxy..."
    
    # Stop web-proxy
    if [[ -f /tmp/web-proxy.pid ]]; then
        local pid=$(cat /tmp/web-proxy.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            rm -f /tmp/web-proxy.pid
            print_success "Web-proxy stopped"
        fi
    fi
    
    # Stop gateway VM
    if [[ -f "$GATEWAY_SCRIPTS/stop-gateway.sh" ]]; then
        cd "$GATEWAY_SCRIPTS"
        ./stop-gateway.sh
        print_success "Gateway VM stopped"
    fi
    
    log "Hybrid proxy stopped"
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            print_fire "NeXuS Hybrid Proxy Launcher"
            echo -e "${CYAN}Sane • Simple • Secure Anonymous Torrenting${NC}"
            echo
            
            check_not_root
            check_dependencies
            start_gateway_vm
            start_user_proxy
            start_web_proxy
            check_web_proxy
            show_status
            ;;
        "stop")
            stop_hybrid_proxy
            ;;
        "status")
            show_status
            ;;
        "restart")
            stop_hybrid_proxy
            sleep 2
            main start
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo
            echo "Commands:"
            echo "  start   - Start the hybrid proxy system"
            echo "  stop    - Stop all components"
            echo "  status  - Show current status"
            echo "  restart - Restart the system"
            exit 1
            ;;
    esac
}

# Initialize log
echo "$(date '+%Y-%m-%d %H:%M:%S'): NeXuS Hybrid Proxy Launcher started" > "$LOG_FILE"

# Run main function
main "$@"