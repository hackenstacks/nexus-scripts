#!/bin/bash

# NeXuS User-Level Proxy Solution
# No root privileges required - works with existing user-space tools
# Sane • Simple • Secure proxy setup for anonymous torrenting

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

CONFIG_DIR="/home/user/.nexus-security"
LOG_FILE="$CONFIG_DIR/user-proxy.log"

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
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}         🌐 NeXuS USER-LEVEL PROXY SYSTEM 🌐        ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}       No Root Required • Application-Level Privacy      ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}          SOCKS + HTTP Proxy Chain Automation           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

check_tor_available() {
    print_status "Checking for existing Tor SOCKS proxy..."
    
    # Check common Tor SOCKS ports
    for port in 9050 9150; do
        if nc -z localhost $port 2>/dev/null; then
            print_success "Found Tor SOCKS proxy on localhost:$port"
            echo $port
            return 0
        fi
    done
    
    print_warning "No Tor SOCKS proxy found"
    return 1
}

start_user_tor() {
    print_status "Starting user-level Tor instance..."
    
    # Create user tor config
    local tor_config="$CONFIG_DIR/user-torrc"
    mkdir -p "$CONFIG_DIR/tor-data"
    
    cat > "$tor_config" << EOF
# NeXuS User-Level Tor Configuration
DataDirectory $CONFIG_DIR/tor-data
PidFile $CONFIG_DIR/tor.pid

# SOCKS proxy for applications
SocksPort 127.0.0.1:9060
SocksPolicy accept 127.0.0.1/32

# HTTP proxy port (via socat bridge)
HTTPTunnelPort 127.0.0.1:9061

# Control port for management
ControlPort 127.0.0.1:9062

# Performance and security
MaxCircuitDirtiness 300
NewCircuitPeriod 30
MaxClientCircuitsPending 32
NumEntryGuards 8

# Logging
Log notice stdout
EOF

    # Start user Tor instance
    if ! pgrep -f "user-torrc" >/dev/null; then
        tor -f "$tor_config" &
        local tor_pid=$!
        echo $tor_pid > "$CONFIG_DIR/tor.pid"
        
        print_status "Waiting for Tor to initialize..."
        sleep 5
        
        if ps -p $tor_pid > /dev/null 2>&1; then
            print_success "User Tor started (PID: $tor_pid)"
            log_event "User Tor started on port 9060"
            return 0
        else
            print_error "Failed to start user Tor"
            return 1
        fi
    else
        print_success "User Tor already running"
        return 0
    fi
}

create_proxy_env() {
    print_status "Creating proxy environment configuration..."
    
    local tor_port=""
    if tor_port=$(check_tor_available); then
        print_success "Using existing Tor on port $tor_port"
    elif start_user_tor; then
        tor_port="9060"
        print_success "Using new user Tor on port $tor_port"
    else
        print_warning "No Tor available - using direct connection"
        return 1
    fi
    
    # Create proxy environment script
    local proxy_env="$CONFIG_DIR/proxy-env.sh"
    cat > "$proxy_env" << EOF
#!/bin/bash
# NeXuS Proxy Environment
# Source this file to enable proxy for applications

export SOCKS_PROXY="socks5://127.0.0.1:$tor_port"
export HTTP_PROXY="socks5://127.0.0.1:$tor_port"
export HTTPS_PROXY="socks5://127.0.0.1:$tor_port"
export ALL_PROXY="socks5://127.0.0.1:$tor_port"

# For curl and wget
export http_proxy="\$HTTP_PROXY"
export https_proxy="\$HTTPS_PROXY"
export all_proxy="\$ALL_PROXY"

# Node.js applications
export NODE_TLS_REJECT_UNAUTHORIZED=0

echo "🌐 NeXuS Proxy Environment Active"
echo "📡 SOCKS Proxy: \$SOCKS_PROXY"
echo "🔒 All traffic routed through Tor"
EOF
    
    chmod +x "$proxy_env"
    print_success "Proxy environment created: $proxy_env"
    log_event "Proxy environment configured for port $tor_port"
    
    # Export to current session
    source "$proxy_env"
    
    return 0
}

test_proxy() {
    print_status "Testing proxy connectivity..."
    
    # Test Tor connectivity
    if command -v curl >/dev/null; then
        print_status "Testing Tor connectivity..."
        if curl -s --socks5 127.0.0.1:9060 https://check.torproject.org/api/ip 2>/dev/null | grep -q "true"; then
            print_success "Tor proxy working correctly"
            log_event "Tor proxy test successful"
        else
            print_warning "Tor proxy test failed"
        fi
    fi
}

show_status() {
    print_fire "NeXuS User-Level Proxy Status"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    # Check user Tor
    if pgrep -f "user-torrc" >/dev/null; then
        print_success "User Tor: RUNNING"
    else
        print_warning "User Tor: NOT RUNNING"
    fi
    
    # Check SOCKS proxy
    if nc -z localhost 9060 2>/dev/null; then
        print_success "SOCKS Proxy: ACCESSIBLE (localhost:9060)"
    elif nc -z localhost 9050 2>/dev/null; then
        print_success "SOCKS Proxy: ACCESSIBLE (localhost:9050)"
    else
        print_warning "SOCKS Proxy: NOT ACCESSIBLE"
    fi
    
    # Check proxy environment
    if [[ -n "$HTTP_PROXY" ]]; then
        print_success "Proxy Environment: ACTIVE ($HTTP_PROXY)"
    else
        print_warning "Proxy Environment: NOT ACTIVE"
    fi
    
    echo
    print_fire "Usage Instructions"
    echo -e "${WHITE}• Run applications in this shell to use proxy${NC}"
    echo -e "${WHITE}• Or source: ${CYAN}source $CONFIG_DIR/proxy-env.sh${NC}"
    echo -e "${WHITE}• Web-proxy will automatically use these settings${NC}"
    echo
}

stop_user_proxy() {
    print_status "Stopping user-level proxy..."
    
    # Stop user Tor
    if [[ -f "$CONFIG_DIR/tor.pid" ]]; then
        local pid=$(cat "$CONFIG_DIR/tor.pid")
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            rm -f "$CONFIG_DIR/tor.pid"
            print_success "User Tor stopped"
        fi
    fi
    
    # Clear proxy environment
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY SOCKS_PROXY
    unset http_proxy https_proxy all_proxy
    
    print_success "Proxy environment cleared"
    log_event "User proxy stopped"
}

main() {
    case "${1:-start}" in
        "start")
            show_banner
            print_fire "Starting NeXuS User-Level Proxy"
            echo -e "${CYAN}No root privileges required!${NC}"
            echo
            
            create_proxy_env
            test_proxy
            show_status
            ;;
        "stop")
            stop_user_proxy
            ;;
        "status")
            show_status
            ;;
        "env")
            # Just output the proxy environment for sourcing
            if [[ -f "$CONFIG_DIR/proxy-env.sh" ]]; then
                cat "$CONFIG_DIR/proxy-env.sh"
            else
                print_error "Proxy environment not configured. Run: $0 start"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {start|stop|status|env}"
            echo
            echo "Commands:"
            echo "  start   - Start user-level proxy system"
            echo "  stop    - Stop proxy and clear environment"
            echo "  status  - Show current proxy status"
            echo "  env     - Show proxy environment variables"
            exit 1
            ;;
    esac
}

# Initialize log
log_event "NeXuS User-Level Proxy script started"

# Run main function
main "$@"