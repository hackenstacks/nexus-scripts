#!/bin/bash

# NeXuS Tor User Setup - Proper Tor user environment
# Creates secure Tor directories and permissions for tor user

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SUCCESS_SYMBOL="✅"
WARNING_SYMBOL="⚠️"
ERROR_SYMBOL="❌"

print_status() {
    echo -e "${BLUE}📊 $1${NC}"
}

print_success() {
    echo -e "${GREEN}${SUCCESS_SYMBOL} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING_SYMBOL} $1${NC}"
}

print_error() {
    echo -e "${RED}${ERROR_SYMBOL} $1${NC}"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              🔒 NeXuS TOR USER SETUP 🔒                ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}        Secure Tor Environment Configuration             ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}           tor user • Proper Permissions                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

check_tor_user() {
    print_status "Checking tor user..."
    
    if id tor >/dev/null 2>&1; then
        print_success "tor user exists ($(id tor))"
        return 0
    else
        print_warning "tor user does not exist"
        return 1
    fi
}

create_tor_user() {
    print_status "Creating tor user..."
    
    if doas adduser -D -s /bin/false -h /var/lib/tor -g "Tor daemon" tor; then
        print_success "tor user created successfully"
        
        # Add tor user to necessary groups if they exist
        for group in ssl-cert debian-tor; do
            if getent group "$group" >/dev/null 2>&1; then
                doas adduser tor "$group" 2>/dev/null || true
            fi
        done
        
        return 0
    else
        print_error "Failed to create tor user"
        return 1
    fi
}

setup_tor_directories() {
    print_status "Setting up Tor directories..."
    
    # Create directories with proper ownership
    print_status "Creating /var/lib/tor (data directory)..."
    doas mkdir -p /var/lib/tor
    doas chown tor:tor /var/lib/tor
    doas chmod 700 /var/lib/tor
    
    print_status "Creating /var/log/tor (log directory)..."
    doas mkdir -p /var/log/tor
    doas chown tor:tor /var/log/tor
    doas chmod 750 /var/log/tor
    
    print_status "Creating /var/run/tor (runtime directory)..."
    doas mkdir -p /var/run/tor
    doas chown tor:tor /var/run/tor
    doas chmod 750 /var/run/tor
    
    # Create empty log files with proper permissions
    doas touch /var/log/tor/tor.log /var/log/tor/notices.log
    doas chown tor:tor /var/log/tor/tor.log /var/log/tor/notices.log
    doas chmod 640 /var/log/tor/tor.log /var/log/tor/notices.log
    
    print_success "Tor directories created with secure permissions"
}

create_tor_config() {
    print_status "Creating secure Tor configuration..."
    
    local config_dir="/home/user/.nexus-security"
    mkdir -p "$config_dir"
    
    cat > "$config_dir/torrc-secure" << 'EOF'
# NeXuS Secure Tor Configuration
# Runs as tor user with proper permissions

User tor
DataDirectory /var/lib/tor
PidFile /var/run/tor/tor.pid

# SOCKS proxy for applications
SocksPort 127.0.0.1:9050
SocksPolicy accept 127.0.0.1/32

# Control port for management (optional)
ControlPort 127.0.0.1:9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1

# Logging
Log notice file /var/log/tor/notices.log
Log warn file /var/log/tor/tor.log

# Security settings
DisableDebuggerAttachment 1
Sandbox 1

# Performance settings
MaxCircuitDirtiness 300
CircuitBuildTimeout 10
KeepalivePeriod 60
NewCircuitPeriod 30
NumEntryGuards 8

# Exit policy (relay settings)
ExitPolicy reject *:*
EOF

    print_success "Secure Tor configuration created"
}

create_transparent_proxy_config() {
    print_status "Creating transparent proxy configuration..."
    
    local config_dir="/home/user/.nexus-security"
    
    cat > "$config_dir/torrc-transparent-secure" << 'EOF'
# NeXuS Secure Transparent Proxy Configuration
# Runs as tor user with transparent proxy support

User tor
DataDirectory /var/lib/tor
PidFile /var/run/tor/tor.pid

# Transparent proxy settings
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:5353

# SOCKS proxy (for apps that need it)
SocksPort 127.0.0.1:9050

# Control port
ControlPort 127.0.0.1:9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1

# Logging
Log notice file /var/log/tor/notices.log
Log warn file /var/log/tor/tor.log

# Security settings
DisableDebuggerAttachment 1
Sandbox 1

# Performance settings
MaxCircuitDirtiness 300
CircuitBuildTimeout 10
KeepalivePeriod 60
NewCircuitPeriod 30
NumEntryGuards 8

# Exit policy
ExitPolicy reject *:*
EOF

    print_success "Transparent proxy configuration created"
}

test_tor_startup() {
    print_status "Testing Tor startup as tor user..."
    
    local config_file="/home/user/.nexus-security/torrc-secure"
    
    # Kill any existing tor processes
    doas pkill -u tor tor 2>/dev/null || true
    pkill -f "user-torrc" 2>/dev/null || true
    sleep 2
    
    print_status "Starting Tor as tor user..."
    
    # Start Tor as tor user using runuser
    if doas runuser -u tor -- tor -f "$config_file" --verify-config; then
        print_success "Tor configuration is valid"
        
        # Start Tor in background
        doas runuser -u tor -- tor -f "$config_file" &
        local tor_pid=$!
        
        # Wait for startup
        sleep 5
        
        # Check if running
        if pgrep -u tor tor >/dev/null; then
            print_success "Tor is running as tor user!"
            print_success "PID: $(pgrep -u tor tor)"
            print_success "SOCKS proxy available at: 127.0.0.1:9050"
            return 0
        else
            print_error "Tor failed to start"
            return 1
        fi
    else
        print_error "Tor configuration is invalid"
        return 1
    fi
}

test_tor_connectivity() {
    print_status "Testing Tor connectivity..."
    
    # Wait for Tor to initialize
    sleep 10
    
    # Test SOCKS proxy
    if curl --socks5 127.0.0.1:9050 -s --max-time 15 https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
        print_success "Tor connectivity test PASSED"
        print_success "Anonymous connection established"
        return 0
    else
        print_warning "Tor connectivity test failed"
        print_warning "Tor may still be initializing or have connection issues"
        return 1
    fi
}

show_tor_status() {
    echo
    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                      TOR STATUS SUMMARY                    ║${NC}"
    echo -e "${WHITE}╠════════════════════════════════════════════════════════════╣${NC}"
    
    # Check tor user
    if id tor >/dev/null 2>&1; then
        echo -e "${WHITE}║ ${GREEN}✅ Tor User:        EXISTS${NC}$(printf "%*s" 26 "")${WHITE}║${NC}"
    else
        echo -e "${WHITE}║ ${RED}❌ Tor User:        MISSING${NC}$(printf "%*s" 25 "")${WHITE}║${NC}"
    fi
    
    # Check directories
    if [[ -d /var/lib/tor && -d /var/log/tor && -d /var/run/tor ]]; then
        echo -e "${WHITE}║ ${GREEN}✅ Directories:     CONFIGURED${NC}$(printf "%*s" 21 "")${WHITE}║${NC}"
    else
        echo -e "${WHITE}║ ${RED}❌ Directories:     MISSING${NC}$(printf "%*s" 24 "")${WHITE}║${NC}"
    fi
    
    # Check if tor is running as tor user
    if pgrep -u tor tor >/dev/null 2>&1; then
        local tor_pid=$(pgrep -u tor tor)
        echo -e "${WHITE}║ ${GREEN}✅ Tor Process:     RUNNING (PID: $tor_pid)${NC}$(printf "%*s" $((13-${#tor_pid})) "")${WHITE}║${NC}"
    else
        echo -e "${WHITE}║ ${RED}❌ Tor Process:     NOT RUNNING${NC}$(printf "%*s" 20 "")${WHITE}║${NC}"
    fi
    
    # Check SOCKS proxy
    if nc -z 127.0.0.1 9050 2>/dev/null; then
        echo -e "${WHITE}║ ${GREEN}✅ SOCKS Proxy:     ACCESSIBLE (9050)${NC}$(printf "%*s" 15 "")${WHITE}║${NC}"
    else
        echo -e "${WHITE}║ ${RED}❌ SOCKS Proxy:     NOT ACCESSIBLE${NC}$(printf "%*s" 17 "")${WHITE}║${NC}"
    fi
    
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if pgrep -u tor tor >/dev/null 2>&1; then
        echo -e "${GREEN}🎯 SUCCESS: Tor is running securely as tor user!${NC}"
        echo -e "${CYAN}📡 SOCKS proxy: socks5://127.0.0.1:9050${NC}"
        echo -e "${CYAN}🔍 Test: curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip${NC}"
    else
        echo -e "${RED}⚠️ Tor is not running as tor user${NC}"
        echo -e "${YELLOW}Run: $0 setup${NC}"
    fi
}

stop_tor() {
    print_status "Stopping all Tor processes..."
    
    # Stop tor user processes
    doas pkill -u tor tor 2>/dev/null || true
    
    # Stop user tor processes
    pkill -f "user-torrc" 2>/dev/null || true
    pkill -f "torrc-secure" 2>/dev/null || true
    
    print_success "All Tor processes stopped"
}

main() {
    case "${1:-status}" in
        "setup")
            show_banner
            echo -e "${CYAN}🔧 Setting up secure Tor environment...${NC}"
            echo
            
            # Check/create tor user
            if ! check_tor_user; then
                create_tor_user
            fi
            
            # Setup directories and configs
            setup_tor_directories
            create_tor_config
            create_transparent_proxy_config
            
            # Test startup
            test_tor_startup
            test_tor_connectivity
            
            show_tor_status
            ;;
        "start")
            print_status "Starting Tor as tor user..."
            test_tor_startup
            show_tor_status
            ;;
        "stop")
            stop_tor
            ;;
        "test")
            test_tor_connectivity
            ;;
        "status")
            show_tor_status
            ;;
        *)
            echo "Usage: $0 {setup|start|stop|test|status}"
            echo
            echo "Commands:"
            echo "  setup  - Complete Tor user environment setup"
            echo "  start  - Start Tor as tor user"
            echo "  stop   - Stop all Tor processes"
            echo "  test   - Test Tor connectivity"
            echo "  status - Show current Tor status"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"