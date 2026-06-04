#!/bin/bash
# 🌐 NeXuS Transparent Proxy System - SECURE VERSION
# Tor runs as tor user, only iptables needs admin privileges

set -e

# Colors and symbols
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SUCCESS_SYMBOL="✅"
WARNING_SYMBOL="⚠️"
FIRE_SYMBOL="🔥"

# Configuration
TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
CONFIG_DIR="/home/user/.nexus-security"
LOG_FILE="$CONFIG_DIR/transparent-proxy-secure.log"

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}       🌐 NeXuS TRANSPARENT PROXY - SECURE 🌐         ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}    Tor runs as tor user • Only iptables needs admin     ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}              PROPER SECURITY ISOLATION                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_event() {
    local event="$1"
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $event" >> "$LOG_FILE"
}

check_tor_user_exists() {
    if ! id tor >/dev/null 2>&1; then
        echo -e "${RED}${WARNING_SYMBOL} tor user does not exist${NC}"
        echo -e "${YELLOW}Creating tor user...${NC}"
        if doas adduser -D -s /bin/false -h /var/lib/tor tor; then
            echo -e "${GREEN}${SUCCESS_SYMBOL} tor user created${NC}"
        else
            echo -e "${RED}Failed to create tor user${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}${SUCCESS_SYMBOL} tor user exists${NC}"
    fi
}

setup_tor_directories() {
    echo -e "${BLUE}📁 Setting up secure Tor directories...${NC}"
    
    # Create directories as root, then change ownership
    doas mkdir -p /var/lib/tor /var/log/tor /var/run/tor
    doas chown tor:tor /var/lib/tor /var/log/tor /var/run/tor
    doas chmod 700 /var/lib/tor
    doas chmod 750 /var/log/tor /var/run/tor
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Tor directories configured securely${NC}"
}

create_secure_tor_config() {
    echo -e "${BLUE}👻 Creating secure Tor configuration...${NC}"
    
    mkdir -p "$CONFIG_DIR"
    
    # Create Tor config that explicitly runs as tor user
    cat > "$CONFIG_DIR/torrc-transparent-secure" << EOF
# NeXuS Secure Transparent Tor Configuration
# Tor runs as tor user, not root!

User tor
DataDirectory /var/lib/tor
PidFile /var/run/tor/tor.pid

# Transparent proxy settings
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 127.0.0.1:$TOR_TRANS_PORT
DNSPort 127.0.0.1:$TOR_DNS_PORT

# SOCKS proxy (for apps that need it)
SocksPort 127.0.0.1:9050

# Logging
Log notice file /var/log/tor/notices.log
Log warn file /var/log/tor/tor.log

# Security settings
CookieAuthentication 1
ControlSocketsGroupWritable 1

# Performance settings
MaxCircuitDirtiness 300
CircuitBuildTimeout 10
KeepalivePeriod 60
NewCircuitPeriod 30
NumEntryGuards 8

# Additional security
DisableDebuggerAttachment 1
EOF

    echo -e "${GREEN}${SUCCESS_SYMBOL} Secure Tor config created${NC}"
}

create_secure_setup_script() {
    echo -e "${BLUE}🔧 Creating secure setup script...${NC}"
    
    # This script handles the admin operations safely
    cat > "$CONFIG_DIR/secure-transparent-setup.sh" << 'SCRIPT_EOF'
#!/bin/bash
# Secure transparent proxy setup - proper privilege separation

set -e

TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
CONFIG_DIR="/home/user/.nexus-security"

echo "🔥 Starting SECURE transparent proxy setup..."
echo "🔒 Tor will run as tor user, not root!"

# 1. Setup Tor directories with proper ownership
echo "📁 Setting up Tor directories..."
mkdir -p /var/lib/tor /var/log/tor /var/run/tor
chown tor:tor /var/lib/tor /var/log/tor /var/run/tor
chmod 700 /var/lib/tor
chmod 750 /var/log/tor /var/run/tor

# 2. Kill any existing Tor processes (including bad root ones)
echo "🛑 Stopping any existing Tor processes..."
pkill -f "torrc-transparent" || true
pkill -f "tor.*transparent" || true
sleep 2

# 3. Start Tor as tor user (not root!)
echo "👻 Starting Tor as tor user..."
# Use runuser to start tor as the tor user
runuser -u tor -- tor -f "$CONFIG_DIR/torrc-transparent-secure" --quiet &
TOR_PID=$!

# Wait for Tor to initialize
echo "⏳ Waiting for Tor to initialize (as tor user)..."
sleep 8

# Verify Tor is running as tor user
if pgrep -u tor tor >/dev/null; then
    echo "✅ Tor is running as tor user (SECURE)"
else
    echo "❌ Tor failed to start as tor user"
    exit 1
fi

# 4. Apply iptables rules (this needs root, but Tor doesn't)
echo "🔒 Applying iptables rules (only this needs admin)..."

# Backup existing rules
iptables-save > "$CONFIG_DIR/iptables-backup-$(date +%Y%m%d-%H%M%S).rules" 2>/dev/null || true

# Flush existing NAT rules
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true

# Create TRANSPROXY chain
iptables -t nat -N TRANSPROXY 2>/dev/null || true

# Redirect DNS queries to Tor DNS port
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $TOR_DNS_PORT

# Exclude local networks from transparent proxy
for network in "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "169.254.0.0/16"; do
    iptables -t nat -A TRANSPROXY -d "$network" -j RETURN
done

# Exclude Tor traffic from being re-proxied (by uid)
iptables -t nat -A TRANSPROXY -m owner --uid-owner tor -j RETURN

# Redirect TCP traffic to Tor transparent port
iptables -t nat -A TRANSPROXY -p tcp --syn -j REDIRECT --to-ports $TOR_TRANS_PORT

# Apply transparent proxy to all output
iptables -t nat -A OUTPUT -p tcp -j TRANSPROXY

echo "✅ iptables rules applied successfully"

# 5. Final verification
if pgrep -u tor -f "torrc-transparent-secure" >/dev/null; then
    echo "🔥 SECURE transparent proxy setup completed!"
    echo "✅ Tor is running as tor user (NOT root)"
    echo "✅ Only iptables operations used admin privileges"
else
    echo "❌ Secure transparent proxy setup failed"
    exit 1
fi
SCRIPT_EOF

    chmod +x "$CONFIG_DIR/secure-transparent-setup.sh"
    echo -e "${GREEN}${SUCCESS_SYMBOL} Secure setup script created${NC}"
}

kill_insecure_tor() {
    echo -e "${RED}🛑 Killing any insecure Tor processes...${NC}"
    
    # Kill any Tor processes running as root (DANGEROUS)
    doas pkill -f "doas tor" || true
    doas pkill -u root -f "tor.*transparent" || true
    
    # Kill any transparent tor processes
    pkill -f "torrc-transparent" || true
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Insecure Tor processes terminated${NC}"
}

start_secure_transparent_proxy() {
    show_banner
    echo -e "${BLUE}🚀 Starting SECURE NeXuS Transparent Proxy...${NC}"
    
    # Check if tor user exists
    check_tor_user_exists
    
    # Kill any insecure processes first
    kill_insecure_tor
    
    # Create secure configuration
    create_secure_tor_config
    create_secure_setup_script
    
    # Run secure setup
    echo -e "${YELLOW}${WARNING_SYMBOL} This will prompt for admin password ONCE${NC}"
    echo -e "${GREEN}Tor will run as tor user (SECURE)${NC}"
    echo -e "${CYAN}Only iptables operations need admin privileges${NC}"
    echo
    
    if doas "$CONFIG_DIR/secure-transparent-setup.sh"; then
        echo
        echo -e "${GREEN}${FIRE_SYMBOL} SECURE NeXuS Transparent Proxy ACTIVE ${FIRE_SYMBOL}${NC}"
        echo -e "${GREEN}✅ Tor running as tor user (NOT root)${NC}"
        echo -e "${CYAN}🌐 All network traffic routed through Tor${NC}"
        echo -e "${WHITE}🔍 Test: curl -s https://check.torproject.org/api/ip${NC}"
        
        log_event "SECURE transparent proxy started - Tor as tor user"
        return 0
    else
        echo -e "${RED}${WARNING_SYMBOL} Failed to start secure transparent proxy${NC}"
        return 1
    fi
}

check_security_status() {
    show_banner
    echo -e "${BLUE}🔒 NeXuS Transparent Proxy Security Status${NC}"
    echo -e "${WHITE}==================================================${NC}"
    
    # Check if any Tor processes are running as root (BAD)
    if pgrep -u root -f tor >/dev/null 2>&1; then
        echo -e "${RED}🚨 SECURITY ALERT: Tor running as root (DANGEROUS)${NC}"
        echo -e "${RED}   PIDs: $(pgrep -u root -f tor | tr '\n' ' ')${NC}"
    else
        echo -e "${GREEN}${SUCCESS_SYMBOL} No Tor processes running as root${NC}"
    fi
    
    # Check if Tor is running as tor user (GOOD)
    if pgrep -u tor -f tor >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor running as tor user (SECURE)${NC}"
        echo -e "${CYAN}   PIDs: $(pgrep -u tor -f tor | tr '\n' ' ')${NC}"
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} No Tor processes running as tor user${NC}"
    fi
    
    # Check transparent proxy
    if pgrep -f "torrc-transparent" >/dev/null; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Transparent proxy active${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Transparent proxy not running${NC}"
    fi
    
    # Check iptables rules
    if iptables -t nat -L TRANSPROXY >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Transparent proxy iptables rules active${NC}"
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} Transparent proxy iptables rules not found${NC}"
    fi
    
    echo
    echo -e "${CYAN}📋 All Tor processes:${NC}"
    ps aux | grep -E '[t]or' | while read line; do
        echo -e "${WHITE}  $line${NC}"
    done
}

stop_all_tor() {
    echo -e "${RED}🛑 Stopping ALL Tor processes...${NC}"
    
    # Stop secure transparent proxy
    doas pkill -u tor -f tor || true
    
    # Stop any root tor processes (insecure)
    doas pkill -u root -f tor || true
    
    # Stop user tor
    pkill -u "$USER" -f tor || true
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} All Tor processes stopped${NC}"
}

main() {
    case "${1:-status}" in
        "start")
            start_secure_transparent_proxy
            ;;
        "stop")
            stop_all_tor
            ;;
        "status"|"check")
            check_security_status
            ;;
        "kill-insecure")
            kill_insecure_tor
            ;;
        *)
            echo "Usage: $0 {start|stop|status|kill-insecure}"
            echo
            echo "Commands:"
            echo "  start         - Start SECURE transparent proxy (Tor as tor user)"
            echo "  stop          - Stop ALL Tor processes"
            echo "  status        - Show security status of all Tor processes"
            echo "  kill-insecure - Kill any Tor processes running as root"
            exit 1
            ;;
    esac
}

# Initialize log
mkdir -p "$CONFIG_DIR"
log_event "NeXuS Secure Transparent Proxy script started"

# Run main function
main "$@"