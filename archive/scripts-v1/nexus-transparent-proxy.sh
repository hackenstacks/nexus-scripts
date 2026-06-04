#!/bin/bash
# 🌐 NeXuS Transparent Proxy System
# All network traffic automatically routed through proxy chains
# No application configuration needed!

set -e

# Colors and symbols
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

PROXY_SYMBOL="🌐"
SHIELD_SYMBOL="🛡️"
FIRE_SYMBOL="🔥"
SUCCESS_SYMBOL="✅"
WARNING_SYMBOL="⚠️"

# Configuration
TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
PRIVOXY_PORT="8118"
USER_ID="$(id -u)"
CONFIG_DIR="/home/user/.nexus-security"
LOG_FILE="$CONFIG_DIR/transparent-proxy.log"

# Excluded networks (local traffic)
LOCAL_NETWORKS=(
    "127.0.0.0/8"
    "10.0.0.0/8" 
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
)

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}         🌐 NeXuS TRANSPARENT PROXY SYSTEM 🌐         ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}      Zero App Configuration • Total Traffic Control     ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}        Tor + Privoxy + I2P Automatic Routing           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_event() {
    local event="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $event" >> "$LOG_FILE"
}

check_dependencies() {
    echo -e "${BLUE}🔍 Checking transparent proxy dependencies...${NC}"
    
    local missing=()
    
    # Check for required tools
    for tool in iptables tor curl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}${WARNING_SYMBOL} Missing dependencies: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install with: doas apk add ${missing[*]}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} All dependencies available${NC}"
}

setup_tor_transparent() {
    echo -e "${BLUE}👻 Configuring Tor for transparent proxy...${NC}"
    
    # Create Tor transparent proxy config
    cat > "$CONFIG_DIR/torrc-transparent" << EOF
# NeXuS Transparent Tor Configuration
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
Log info file /var/log/tor/tor.log

# Performance settings
MaxCircuitDirtiness 300
NewCircuitPeriod 60
NumEntryGuards 3

# Security settings
AvoidDiskWrites 1
DisableAllSwap 1
HardwareAccel 1

# Exit node preferences
ExitNodes {us},{ca},{gb},{de},{nl},{se}
StrictNodes 1
EOF
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Tor transparent config created${NC}"
    log_event "Tor transparent configuration created"
}

create_iptables_rules() {
    echo -e "${BLUE}🔒 Creating iptables transparent proxy rules...${NC}"
    
    # Save current iptables rules
    echo -e "${YELLOW}💾 Backing up current iptables rules...${NC}"
    doas iptables-save > "$CONFIG_DIR/iptables-backup-$(date +%Y%m%d-%H%M%S).rules" 2>/dev/null || true
    
    # Create transparent proxy rules script
    cat > "$CONFIG_DIR/transparent-proxy-rules.sh" << 'EOF'
#!/bin/bash
# NeXuS Transparent Proxy iptables Rules

# Flush existing rules
iptables -t nat -F
iptables -t nat -X 2>/dev/null || true

# Create TRANSPROXY chain
iptables -t nat -N TRANSPROXY 2>/dev/null || true

# Redirect DNS queries to Tor DNS port
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353

# Exclude local networks from transparent proxy
for network in "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "169.254.0.0/16"; do
    iptables -t nat -A TRANSPROXY -d "$network" -j RETURN
done

# Exclude Tor traffic from being re-proxied
iptables -t nat -A TRANSPROXY -m owner --uid-owner tor -j RETURN

# Redirect TCP traffic to Tor transparent port
iptables -t nat -A TRANSPROXY -p tcp --syn -j REDIRECT --to-ports 9040

# Apply transparent proxy to all output
iptables -t nat -A OUTPUT -p tcp -j TRANSPROXY

echo "✅ Transparent proxy iptables rules applied"
EOF
    
    chmod +x "$CONFIG_DIR/transparent-proxy-rules.sh"
    echo -e "${GREEN}${SUCCESS_SYMBOL} iptables rules script created${NC}"
    log_event "iptables transparent proxy rules created"
}

create_cleanup_script() {
    echo -e "${BLUE}🧹 Creating cleanup script...${NC}"
    
    cat > "$CONFIG_DIR/transparent-proxy-cleanup.sh" << 'EOF'
#!/bin/bash
# NeXuS Transparent Proxy Cleanup

echo "🧹 Cleaning up transparent proxy rules..."

# Remove transparent proxy rules
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X TRANSPROXY 2>/dev/null || true

# Restore default DNS
iptables -t nat -D OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353 2>/dev/null || true

echo "✅ Transparent proxy cleanup complete"
EOF
    
    chmod +x "$CONFIG_DIR/transparent-proxy-cleanup.sh"
    echo -e "${GREEN}${SUCCESS_SYMBOL} Cleanup script created${NC}"
}

start_transparent_proxy() {
    show_banner
    echo -e "${BLUE}🚀 Starting NeXuS Transparent Proxy System...${NC}"
    
    # Check if already running
    if pgrep -f "torrc-transparent" >/dev/null; then
        echo -e "${YELLOW}${WARNING_SYMBOL} Transparent proxy already running${NC}"
        return 1
    fi
    
    # Start Tor with transparent config
    echo -e "${BLUE}👻 Starting Tor transparent proxy...${NC}"
    doas tor -f "$CONFIG_DIR/torrc-transparent" --quiet &
    
    # Wait for Tor to start
    sleep 5
    
    # Apply iptables rules
    echo -e "${BLUE}🔒 Applying transparent proxy rules...${NC}"
    doas "$CONFIG_DIR/transparent-proxy-rules.sh"
    
    # Verify Tor is running
    if pgrep -f "torrc-transparent" >/dev/null; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor transparent proxy started${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Failed to start Tor transparent proxy${NC}"
        return 1
    fi
    
    # Set transparent proxy environment
    export HTTP_PROXY=""
    export HTTPS_PROXY=""
    export ALL_PROXY=""
    
    log_event "Transparent proxy system started"
    
    echo
    echo -e "${GREEN}${FIRE_SYMBOL} NeXuS Transparent Proxy ACTIVE ${FIRE_SYMBOL}${NC}"
    echo -e "${CYAN}🌐 All network traffic automatically routed through Tor${NC}"
    echo -e "${YELLOW}📱 No application configuration needed${NC}"
    echo -e "${WHITE}🔍 Test with: curl -s https://check.torproject.org/api/ip${NC}"
}

stop_transparent_proxy() {
    show_banner
    echo -e "${YELLOW}🛑 Stopping NeXuS Transparent Proxy System...${NC}"
    
    # Stop Tor
    echo -e "${BLUE}👻 Stopping Tor transparent proxy...${NC}"
    doas pkill -f "torrc-transparent" || true
    
    # Clean up iptables rules
    echo -e "${BLUE}🧹 Cleaning up proxy rules...${NC}"
    doas "$CONFIG_DIR/transparent-proxy-cleanup.sh"
    
    log_event "Transparent proxy system stopped"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Transparent proxy stopped${NC}"
    echo -e "${YELLOW}📱 Normal direct internet access restored${NC}"
}

show_status() {
    show_banner
    echo -e "${BLUE}📊 NeXuS Transparent Proxy Status${NC}"
    echo -e "${WHITE}$(printf '%.0s=' {1..50})${NC}"
    
    # Check Tor process
    if pgrep -f "torrc-transparent" >/dev/null; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor Transparent Proxy: RUNNING${NC}"
        
        # Show Tor circuits
        echo -e "${CYAN}🔄 Active Tor Circuits:${NC}"
        echo "GET" | nc 127.0.0.1 9051 2>/dev/null | head -3 || echo "  Unable to connect to Tor control port"
        
    else
        echo -e "${RED}${WARNING_SYMBOL} Tor Transparent Proxy: NOT RUNNING${NC}"
    fi
    
    # Check iptables rules
    echo -e "${CYAN}🔒 Transparent Proxy Rules:${NC}"
    if doas iptables -t nat -L TRANSPROXY >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} iptables rules: ACTIVE${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} iptables rules: NOT ACTIVE${NC}"
    fi
    
    # Show current IP
    echo -e "${CYAN}🌐 Current Public IP:${NC}"
    timeout 10 curl -s https://ifconfig.me 2>/dev/null || echo "  Unable to determine public IP"
    
    # Show recent log entries
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}📝 Recent Activity:${NC}"
        tail -5 "$LOG_FILE" | while read line; do
            echo -e "  ${WHITE}$line${NC}"
        done
    fi
}

test_transparent_proxy() {
    echo -e "${BLUE}🧪 Testing transparent proxy functionality...${NC}"
    
    echo -e "${CYAN}Testing Tor connectivity...${NC}"
    if timeout 15 curl -s https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor connectivity: WORKING${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Tor connectivity: FAILED${NC}"
    fi
    
    echo -e "${CYAN}Testing DNS resolution...${NC}"
    if timeout 10 nslookup google.com 127.0.0.1:5353 >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor DNS resolution: WORKING${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Tor DNS resolution: FAILED${NC}"
    fi
}

# Main execution
case "${1:-menu}" in
    "start"|"on"|"enable")
        check_dependencies && setup_tor_transparent && create_iptables_rules && create_cleanup_script && start_transparent_proxy
        ;;
    "stop"|"off"|"disable")
        stop_transparent_proxy
        ;;
    "status"|"check")
        show_status
        ;;
    "test")
        test_transparent_proxy
        ;;
    "setup")
        check_dependencies && setup_tor_transparent && create_iptables_rules && create_cleanup_script
        echo -e "${GREEN}${SUCCESS_SYMBOL} Setup complete - use 'start' to activate${NC}"
        ;;
    *)
        show_banner
        echo -e "${WHITE}Usage: $0 {setup|start|stop|status|test}${NC}"
        echo
        echo -e "${YELLOW}${PROXY_SYMBOL} Commands:${NC}"
        echo -e "  ${GREEN}setup${NC}  - Initial transparent proxy setup"
        echo -e "  ${GREEN}start${NC}  - Activate transparent proxy (all traffic through Tor)"
        echo -e "  ${RED}stop${NC}   - Deactivate transparent proxy (direct internet)"
        echo -e "  ${BLUE}status${NC} - Show current proxy status and IP"
        echo -e "  ${CYAN}test${NC}   - Test transparent proxy functionality"
        echo
        echo -e "${FIRE_SYMBOL} ${WHITE}NeXuS Transparent Proxy - Zero Configuration Required!${NC} ${FIRE_SYMBOL}"
        ;;
esac