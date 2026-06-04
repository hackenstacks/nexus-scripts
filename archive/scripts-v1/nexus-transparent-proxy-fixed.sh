#!/bin/bash
# 🌐 NeXuS Transparent Proxy System - FIXED VERSION
# Combines multiple doas operations to avoid authentication timeout issues

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
USER_ID="$(id -u)"
CONFIG_DIR="/home/user/.nexus-security"
LOG_FILE="$CONFIG_DIR/transparent-proxy.log"

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      🌐 NeXuS TRANSPARENT PROXY SYSTEM (FIXED) 🌐      ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}      Zero App Configuration • Total Traffic Control     ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}         Single Admin Prompt • No Timeout Issues         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_event() {
    local event="$1"
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $event" >> "$LOG_FILE"
}

check_dependencies() {
    echo -e "${BLUE}🔍 Checking transparent proxy dependencies...${NC}"
    
    local missing=()
    
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

create_combined_setup_script() {
    echo -e "${BLUE}👻 Creating combined transparent proxy setup...${NC}"
    
    mkdir -p "$CONFIG_DIR"
    
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
CircuitBuildTimeout 10
KeepalivePeriod 60
NewCircuitPeriod 30
NumEntryGuards 8
EOF

    # Create combined setup script that runs everything with single doas call
    cat > "$CONFIG_DIR/combined-transparent-setup.sh" << 'SCRIPT_EOF'
#!/bin/bash
# Combined transparent proxy setup - runs with single admin session

set -e

TOR_TRANS_PORT="9040"
TOR_DNS_PORT="5353"
CONFIG_DIR="/home/user/.nexus-security"

echo "🔥 Starting combined transparent proxy setup..."

# 1. Kill any existing transparent Tor processes
pkill -f "torrc-transparent" || true
sleep 2

# 2. Start Tor with transparent config
echo "👻 Starting Tor transparent proxy..."
tor -f "$CONFIG_DIR/torrc-transparent" --quiet &
TOR_PID=$!
echo $TOR_PID > "$CONFIG_DIR/tor-transparent.pid"

# Wait for Tor to initialize
echo "⏳ Waiting for Tor to initialize..."
sleep 8

# 3. Apply iptables rules in same session
echo "🔒 Applying transparent proxy iptables rules..."

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

# Exclude Tor traffic from being re-proxied
iptables -t nat -A TRANSPROXY -m owner --uid-owner tor -j RETURN

# Redirect TCP traffic to Tor transparent port
iptables -t nat -A TRANSPROXY -p tcp --syn -j REDIRECT --to-ports $TOR_TRANS_PORT

# Apply transparent proxy to all output
iptables -t nat -A OUTPUT -p tcp -j TRANSPROXY

echo "✅ Transparent proxy iptables rules applied successfully"

# 4. Verify Tor is running
if pgrep -f "torrc-transparent" >/dev/null; then
    echo "✅ Tor transparent proxy is running"
else
    echo "❌ Tor transparent proxy failed to start"
    exit 1
fi

echo "🔥 Combined transparent proxy setup completed successfully!"
SCRIPT_EOF

    chmod +x "$CONFIG_DIR/combined-transparent-setup.sh"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Combined setup script created${NC}"
}

create_cleanup_script() {
    echo -e "${BLUE}🧹 Creating cleanup script...${NC}"
    
    cat > "$CONFIG_DIR/transparent-proxy-cleanup.sh" << 'CLEANUP_EOF'
#!/bin/bash
# Cleanup transparent proxy setup

echo "🛑 Cleaning up transparent proxy..."

# Stop Tor
pkill -f "torrc-transparent" || true
rm -f /home/user/.nexus-security/tor-transparent.pid

# Restore iptables rules
BACKUP_FILE=$(ls -t /home/user/.nexus-security/iptables-backup-*.rules 2>/dev/null | head -1)
if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    echo "🔄 Restoring iptables from backup..."
    iptables-restore < "$BACKUP_FILE"
else
    echo "🧹 Flushing iptables NAT rules..."
    iptables -t nat -F 2>/dev/null || true
    iptables -t nat -X 2>/dev/null || true
fi

echo "✅ Transparent proxy cleanup completed"
CLEANUP_EOF

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
    
    # Create scripts
    create_combined_setup_script
    create_cleanup_script
    
    # Run combined setup with single doas call
    echo -e "${YELLOW}${WARNING_SYMBOL} This will prompt for admin password ONCE${NC}"
    echo -e "${CYAN}Running combined transparent proxy setup...${NC}"
    
    if doas "$CONFIG_DIR/combined-transparent-setup.sh"; then
        echo
        echo -e "${GREEN}${FIRE_SYMBOL} NeXuS Transparent Proxy ACTIVE ${FIRE_SYMBOL}${NC}"
        echo -e "${CYAN}🌐 All network traffic automatically routed through Tor${NC}"
        echo -e "${YELLOW}📱 No application configuration needed${NC}"
        echo -e "${WHITE}🔍 Test with: curl -s https://check.torproject.org/api/ip${NC}"
        
        log_event "Transparent proxy system started successfully"
        return 0
    else
        echo -e "${RED}${WARNING_SYMBOL} Failed to start transparent proxy${NC}"
        log_event "Transparent proxy system failed to start"
        return 1
    fi
}

stop_transparent_proxy() {
    show_banner
    echo -e "${YELLOW}🛑 Stopping NeXuS Transparent Proxy System...${NC}"
    
    if [[ -f "$CONFIG_DIR/transparent-proxy-cleanup.sh" ]]; then
        echo -e "${YELLOW}${WARNING_SYMBOL} This will prompt for admin password to cleanup${NC}"
        if doas "$CONFIG_DIR/transparent-proxy-cleanup.sh"; then
            echo -e "${GREEN}${SUCCESS_SYMBOL} Transparent proxy stopped${NC}"
            log_event "Transparent proxy system stopped"
        else
            echo -e "${RED}${WARNING_SYMBOL} Cleanup may have failed${NC}"
        fi
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} Cleanup script not found - manual cleanup needed${NC}"
    fi
}

check_status() {
    show_banner
    echo -e "${BLUE}📊 NeXuS Transparent Proxy Status${NC}"
    echo -e "${WHITE}==================================================${NC}"
    
    # Check Tor transparent proxy
    if pgrep -f "torrc-transparent" >/dev/null; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Tor Transparent Proxy: RUNNING${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Tor Transparent Proxy: NOT RUNNING${NC}"
    fi
    
    # Check iptables rules
    if iptables -t nat -L TRANSPROXY >/dev/null 2>&1; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Transparent Proxy Rules: ACTIVE${NC}"
    else
        echo -e "${RED}${WARNING_SYMBOL} Transparent Proxy Rules: NOT ACTIVE${NC}"
    fi
    
    # Show current IP
    echo -e "${CYAN}🌐 Current Public IP:${NC}"
    timeout 10 curl -s https://check.torproject.org/api/ip 2>/dev/null || echo "Unable to check IP"
    
    # Show recent activity
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${CYAN}📝 Recent Activity:${NC}"
        tail -5 "$LOG_FILE" | while read line; do
            echo -e "  ${WHITE}$line${NC}"
        done
    fi
}

main() {
    case "${1:-status}" in
        "start")
            check_dependencies && start_transparent_proxy
            ;;
        "stop")
            stop_transparent_proxy
            ;;
        "status"|"check")
            check_status
            ;;
        "restart")
            stop_transparent_proxy
            sleep 2
            start_transparent_proxy
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo
            echo "Commands:"
            echo "  start   - Start transparent proxy (requires admin)"
            echo "  stop    - Stop transparent proxy (requires admin)"
            echo "  status  - Show current status"
            echo "  restart - Restart transparent proxy"
            exit 1
            ;;
    esac
}

# Initialize log
mkdir -p "$CONFIG_DIR"
log_event "NeXuS Transparent Proxy (Fixed) script started"

# Run main function
main "$@"