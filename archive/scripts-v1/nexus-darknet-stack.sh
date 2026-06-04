#!/bin/bash
# NeXuS Darknet Stack - Unified Multi-Network Launcher
# Orchestrates: Tor, I2P, Yggdrasil, IPFS, Reticulum, Medusa, Snowflake, BATMAN-adv
# Version: 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/darknet"
HYDRA_DIR="/home/user/.nexus-security/hydra"
BRIDGE_DIR="/home/user/.nexus-security/bridge"
LOG_DIR="/home/user/.nexus-security/logs"
DATA_DIR="/home/user/.nexus-security/darknet-data"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Service states
declare -A SERVICE_STATUS
declare -A SERVICE_PIDS

# NeXuS Fire Banner
show_banner() {
    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║  🔥 NeXuS DARKNET STACK - UNIFIED MULTI-NETWORK LAUNCHER 🔥   ║
    ║  Tor • I2P • Yggdrasil • IPFS • Reticulum • Medusa • Mesh    ║
    ║              Sane • Simple • Secure                           ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Initialize directories
init_dirs() {
    mkdir -p "$LOG_DIR" "$DATA_DIR" 2>/dev/null || true
    mkdir -p "$DATA_DIR"/{tor,i2p,yggdrasil,ipfs,reticulum} 2>/dev/null || true
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
}

# Log function
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_DIR/darknet-stack.log"

    case "$level" in
        "INFO")  echo -e "${GREEN}[✓]${NC} $msg" ;;
        "WARN")  echo -e "${YELLOW}[!]${NC} $msg" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $msg" ;;
        "START") echo -e "${CYAN}[➤]${NC} $msg" ;;
        "STOP")  echo -e "${MAGENTA}[■]${NC} $msg" ;;
    esac
}

# Check if a service is running
is_running() {
    local service="$1"
    case "$service" in
        "tor")
            pgrep -f "\\btor\\b" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-tor" ;;
        "i2p")
            pgrep -f "i2pd" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-i2p" ;;
        "yggdrasil")
            pgrep -f "yggdrasil" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-yggdrasil" ;;
        "ipfs")
            pgrep -f "ipfs daemon" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-ipfs" ;;
        "reticulum")
            pgrep -f "rnsd" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-reticulum" ;;
        "privoxy")
            pgrep -f "privoxy" >/dev/null 2>&1 || \
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-privoxy" ;;
        "snowflake")
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-snowflake" ;;
        "medusa")
            podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^nexus-medusa" ;;
        "batman")
            ip link show bat0 >/dev/null 2>&1 ;;
        *)
            return 1 ;;
    esac
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local port="$2"
    local timeout="${3:-30}"
    local count=0

    log "INFO" "Waiting for $service on port $port..."
    while ! nc -z 127.0.0.1 "$port" 2>/dev/null; do
        sleep 1
        count=$((count + 1))
        if [[ $count -ge $timeout ]]; then
            log "WARN" "$service did not start within ${timeout}s"
            return 1
        fi
    done
    log "INFO" "$service is ready on port $port"
    return 0
}

# ===== CORE SERVICES =====

# Start Tor (must be first for other services to use as outproxy)
start_tor() {
    if is_running "tor"; then
        log "WARN" "Tor is already running"
        return 0
    fi

    log "START" "Starting Tor network..."

    # Create torrc if not exists
    if [[ ! -f "$CONFIG_DIR/torrc" ]]; then
        cat > "$CONFIG_DIR/torrc" << 'EOF'
# NeXuS Tor Configuration
SocksPort 0.0.0.0:9050
ControlPort 9051
CookieAuthentication 1
DataDirectory /var/lib/tor

# Circuit settings for anonymity
NewCircuitPeriod 30
MaxCircuitDirtiness 600
EnforceDistinctSubnets 1

# Performance
NumEntryGuards 3
UseEntryGuards 1
HardwareAccel 1

# No exit traffic
ExitPolicy reject *:*
EOF
    fi

    podman run -d \
        --name "nexus-tor" \
        --network host \
        --security-opt no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        --tmpfs /var/lib/tor:rw,noexec,nosuid,size=200m \
        -v "$CONFIG_DIR/torrc:/etc/tor/torrc:ro" \
        --restart unless-stopped \
        docker.io/dperson/torproxy:latest 2>/dev/null || \
    podman run -d \
        --name "nexus-tor" \
        -p 127.0.0.1:9050:9050 \
        -p 127.0.0.1:9051:9051 \
        --security-opt no-new-privileges \
        -v "$CONFIG_DIR/torrc:/etc/tor/torrc:ro" \
        -v "nexus-tor-data:/var/lib/tor" \
        --restart unless-stopped \
        docker.io/dperson/torproxy:latest

    wait_for_service "Tor" 9050 60
    log "INFO" "Tor started - SOCKS5: 127.0.0.1:9050"
}

# Start I2P (uses Tor as outproxy)
start_i2p() {
    if is_running "i2p"; then
        log "WARN" "I2P is already running"
        return 0
    fi

    log "START" "Starting I2P network..."

    # Create i2pd config if not exists
    if [[ ! -f "$CONFIG_DIR/i2pd.conf" ]]; then
        cat > "$CONFIG_DIR/i2pd.conf" << 'EOF'
# NeXuS I2P Configuration
# Clearnet exit traffic routed through Tor SOCKS5 (never leaves Tor)

[httpproxy]
enabled = true
address = 0.0.0.0
port = 4444
# Route clearnet exit through Tor SOCKS5
outproxy = 127.0.0.1
outproxyport = 9050
outproxyenable = true

[socksproxy]
enabled = true
address = 0.0.0.0
port = 4447

[sam]
enabled = true
address = 127.0.0.1
port = 7656

[http]
enabled = true
address = 0.0.0.0
port = 7070

[precomputation]
elgamal = true

[limits]
transittunnels = 256
EOF
    fi

    podman run -d \
        --name "nexus-i2p" \
        -p 127.0.0.1:7070:7070 \
        -p 127.0.0.1:4444:4444 \
        -p 127.0.0.1:4447:4447 \
        -p 127.0.0.1:7656:7656 \
        --security-opt no-new-privileges \
        -v "$CONFIG_DIR/i2pd.conf:/home/i2pd/conf/i2pd.conf:ro" \
        -v "nexus-i2p-data:/home/i2pd/data" \
        --restart unless-stopped \
        docker.io/purplei2p/i2pd:latest

    wait_for_service "I2P" 7070 120
    log "INFO" "I2P started - HTTP: 4444, Console: 7070"
}

# Start Yggdrasil (routed over Tor)
start_yggdrasil() {
    if is_running "yggdrasil"; then
        log "WARN" "Yggdrasil is already running"
        return 0
    fi

    log "START" "Starting Yggdrasil mesh network..."

    # Create yggdrasil config if not exists
    if [[ ! -f "$CONFIG_DIR/yggdrasil.conf" ]]; then
        cat > "$CONFIG_DIR/yggdrasil.conf" << 'EOF'
{
  "Peers": [],
  "InterfacePeers": {},
  "Listen": ["tcp://0.0.0.0:9001"],
  "AdminListen": "tcp://127.0.0.1:9002",
  "MulticastInterfaces": [
    {
      "Regex": ".*",
      "Beacon": true,
      "Listen": true,
      "Port": 0,
      "Priority": 0
    }
  ],
  "AllowedPublicKeys": [],
  "IfName": "auto",
  "IfMTU": 65535,
  "NodeInfoPrivacy": true,
  "NodeInfo": {},
  "Proxy": "socks5://127.0.0.1:9050"
}
EOF
    fi

    podman run -d \
        --name "nexus-yggdrasil" \
        --cap-add NET_ADMIN \
        --device /dev/net/tun \
        -p 127.0.0.1:9001:9001 \
        -p 127.0.0.1:9002:9002 \
        --security-opt no-new-privileges \
        -v "$CONFIG_DIR/yggdrasil.conf:/etc/yggdrasil.conf:ro" \
        -v "nexus-yggdrasil-data:/var/lib/yggdrasil" \
        --restart unless-stopped \
        docker.io/yggdrasilnetwork/yggdrasil:latest

    wait_for_service "Yggdrasil" 9001 30
    log "INFO" "Yggdrasil started - Port: 9001, Admin: 9002"
}

# Start IPFS
start_ipfs() {
    if is_running "ipfs"; then
        log "WARN" "IPFS is already running"
        return 0
    fi

    log "START" "Starting IPFS node..."

    podman run -d \
        --name "nexus-ipfs" \
        -p 127.0.0.1:5001:5001 \
        -p 127.0.0.1:8080:8080 \
        -p 4001:4001 \
        --security-opt no-new-privileges \
        -v "nexus-ipfs-data:/data/ipfs" \
        -e IPFS_PROFILE=server \
        --restart unless-stopped \
        docker.io/ipfs/kubo:latest

    wait_for_service "IPFS" 5001 60
    log "INFO" "IPFS started - API: 5001, Gateway: 8080"
}

# Start Reticulum
start_reticulum() {
    if is_running "reticulum"; then
        log "WARN" "Reticulum is already running"
        return 0
    fi

    log "START" "Starting Reticulum network..."

    # Create reticulum config if not exists
    if [[ ! -f "$CONFIG_DIR/reticulum.conf" ]]; then
        cat > "$CONFIG_DIR/reticulum.conf" << 'EOF'
[reticulum]
enable_transport = True
share_instance = Yes
instance_control_port = 37428

[interfaces]
[[Local TCP Server]]
type = TCPServerInterface
enabled = True
listen_ip = 0.0.0.0
listen_port = 4965

[[Tor TCP Client]]
type = TCPClientInterface
enabled = True
target_host = 127.0.0.1
target_port = 9050
outgoing_proxy_type = socks5
EOF
    fi

    # Check if Dockerfile exists, build if needed
    if ! podman images | grep -q "nexus-reticulum"; then
        log "INFO" "Building Reticulum container..."
        if [[ -f "$CONFIG_DIR/Dockerfile.reticulum" ]]; then
            podman build -t nexus-reticulum -f "$CONFIG_DIR/Dockerfile.reticulum" "$CONFIG_DIR"
        else
            # Create Dockerfile
            cat > "$CONFIG_DIR/Dockerfile.reticulum" << 'EOF'
FROM python:3.11-slim
RUN pip install --no-cache-dir rns
RUN mkdir -p /root/.reticulum
EXPOSE 4965 37428
CMD ["rnsd", "--config", "/root/.reticulum"]
EOF
            podman build -t nexus-reticulum -f "$CONFIG_DIR/Dockerfile.reticulum" "$CONFIG_DIR"
        fi
    fi

    podman run -d \
        --name "nexus-reticulum" \
        -p 127.0.0.1:4965:4965 \
        -p 127.0.0.1:37428:37428 \
        --security-opt no-new-privileges \
        -v "$CONFIG_DIR/reticulum.conf:/root/.reticulum/config:ro" \
        -v "nexus-reticulum-data:/root/.reticulum" \
        --restart unless-stopped \
        localhost/nexus-reticulum:latest

    wait_for_service "Reticulum" 4965 30
    log "INFO" "Reticulum started - Port: 4965"
}

# Start Privoxy (routes I2P through Tor)
start_privoxy() {
    if is_running "privoxy"; then
        log "WARN" "Privoxy is already running"
        return 0
    fi

    log "START" "Starting Privoxy..."

    # Create privoxy config
    if [[ ! -f "$CONFIG_DIR/privoxy.conf" ]]; then
        cat > "$CONFIG_DIR/privoxy.conf" << 'EOF'
# NeXuS Privoxy - Multi-Network Router
listen-address 0.0.0.0:8118
toggle 1
enable-remote-toggle 0
enable-edit-actions 0
buffer-limit 4096

# Forward .onion to Tor
forward-socks5t .onion 127.0.0.1:9050 .

# Forward .i2p to I2P
forward .i2p 127.0.0.1:4444

# Forward everything else through Tor
forward-socks5t / 127.0.0.1:9050 .

# Logging
logfile /var/log/privoxy/privoxy.log
EOF
    fi

    podman run -d \
        --name "nexus-privoxy" \
        --network host \
        -p 127.0.0.1:8118:8118 \
        --security-opt no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=50m \
        --tmpfs /var/log/privoxy:rw,noexec,nosuid,size=50m \
        -v "$CONFIG_DIR/privoxy.conf:/etc/privoxy/config:ro" \
        --restart unless-stopped \
        docker.io/vimagick/privoxy:latest 2>/dev/null || \
    podman run -d \
        --name "nexus-privoxy" \
        -p 127.0.0.1:8118:8118 \
        --security-opt no-new-privileges \
        -v "$CONFIG_DIR/privoxy.conf:/etc/privoxy/config:ro" \
        --restart unless-stopped \
        docker.io/sameersbn/privoxy:latest

    wait_for_service "Privoxy" 8118 15
    log "INFO" "Privoxy started - HTTP: 127.0.0.1:8118"
}

# Start Snowflake bridge
start_snowflake() {
    if is_running "snowflake"; then
        log "WARN" "Snowflake is already running"
        return 0
    fi

    log "START" "Starting Snowflake bridge..."

    podman run -d \
        --name "nexus-snowflake" \
        -p 127.0.0.1:8080:8080 \
        --security-opt no-new-privileges \
        --restart unless-stopped \
        docker.io/thetorproject/snowflake-proxy:latest

    log "INFO" "Snowflake bridge started - helping censored users access Tor"
}

# Start Medusa (multi-head Tor proxy)
start_medusa() {
    log "START" "Starting Medusa multi-head proxy..."

    if [[ -x "$SCRIPT_DIR/nexus-medusa-manager.sh" ]]; then
        "$SCRIPT_DIR/nexus-medusa-manager.sh" start
    else
        log "WARN" "Medusa manager not found, skipping"
    fi
}

# Enable BATMAN-adv mesh
enable_batman() {
    if is_running "batman"; then
        log "WARN" "BATMAN-adv is already enabled"
        return 0
    fi

    log "START" "Enabling BATMAN-adv mesh networking..."

    if ! lsmod | grep -q batman_adv; then
        sudo modprobe batman-adv 2>/dev/null || {
            log "ERROR" "Failed to load batman-adv module"
            return 1
        }
    fi

    # Find wireless interface
    local wlan_if=$(ip link | grep -oP 'wlan\d+' | head -1)
    if [[ -z "$wlan_if" ]]; then
        log "WARN" "No wireless interface found for mesh"
        return 1
    fi

    sudo batctl if add "$wlan_if" 2>/dev/null || true
    sudo ip link set up dev bat0 2>/dev/null || true
    sudo ip addr add 192.168.199.1/24 dev bat0 2>/dev/null || true

    log "INFO" "BATMAN-adv mesh enabled on bat0"
}

# ===== STOP SERVICES =====

stop_service() {
    local service="$1"
    local container="nexus-$service"
    local stopped=0

    log "STOP" "Stopping $service..."

    # Stop container if running
    if podman ps --format "{{.Names}}" 2>/dev/null | grep -qE "^$container$"; then
        podman stop "$container" 2>/dev/null || true
        podman rm "$container" 2>/dev/null || true
        stopped=1
    fi

    # Stop native process if running
    case "$service" in
        "tor")
            pkill -f "^tor " 2>/dev/null && stopped=1 || true ;;
        "i2p")
            pkill -f "i2pd" 2>/dev/null && stopped=1 || true ;;
        "yggdrasil")
            pkill -f "yggdrasil" 2>/dev/null && stopped=1 || true ;;
        "reticulum")
            pkill -f "rnsd" 2>/dev/null && stopped=1 || true ;;
        "privoxy")
            pkill -f "privoxy" 2>/dev/null && stopped=1 || true ;;
        "snowflake")
            pkill -f "snowflake-proxy" 2>/dev/null && stopped=1 || true ;;
        "ipfs")
            pkill -f "ipfs daemon" 2>/dev/null && stopped=1 || true ;;
        "batman")
            sudo ip link set down dev bat0 2>/dev/null && stopped=1 || true ;;
    esac

    if [[ $stopped -eq 1 ]]; then
        log "INFO" "$service stopped"
    else
        log "WARN" "$service was not running"
    fi
}

stop_all() {
    log "STOP" "Stopping all NeXuS darknet services..."

    # Stop in reverse dependency order
    stop_service "snowflake"
    stop_service "medusa"
    stop_service "privoxy"
    stop_service "reticulum"
    stop_service "ipfs"
    stop_service "yggdrasil"
    stop_service "i2p"
    stop_service "tor"

    # Disable BATMAN-adv
    if ip link show bat0 >/dev/null 2>&1; then
        sudo ip link set down dev bat0 2>/dev/null || true
        log "INFO" "BATMAN-adv disabled"
    fi

    log "INFO" "All services stopped"
}

# ===== START ALL =====

start_all() {
    log "START" "Starting NeXuS Darknet Stack..."
    echo ""

    # Start in dependency order
    start_tor       # Base layer - other services depend on this
    sleep 2
    start_i2p       # Uses Tor as outproxy
    start_privoxy   # Routes traffic through Tor/I2P
    start_yggdrasil # Mesh network
    start_ipfs      # Distributed storage
    start_reticulum # Mesh communication
    start_snowflake # Help censored users

    echo ""
    log "INFO" "NeXuS Darknet Stack started successfully!"
    echo ""
    show_status
}

# ===== STATUS =====

show_status() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                NeXuS DARKNET STACK STATUS              ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local services=("tor" "i2p" "yggdrasil" "ipfs" "reticulum" "privoxy" "snowflake" "batman")
    local icons=("🧅" "🔗" "🌲" "🌐" "📡" "🕵️" "❄️" "🦇")
    local ports=("9050" "4444" "9001" "5001" "4965" "8118" "8080" "-")

    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local icon="${icons[$i]}"
        local port="${ports[$i]}"

        if is_running "$service"; then
            echo -e "  $icon ${GREEN}$service${NC}: 🟢 RUNNING ${BLUE}(port $port)${NC}"
        else
            echo -e "  $icon ${RED}$service${NC}: 🔴 STOPPED"
        fi
    done

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "📡 Proxy Endpoints:"
    echo "   Tor SOCKS5:    127.0.0.1:9050"
    echo "   I2P HTTP:      127.0.0.1:4444"
    echo "   Privoxy HTTP:  127.0.0.1:8118 (routes .onion/.i2p)"
    echo "   IPFS Gateway:  127.0.0.1:8080"
    echo ""
}

# ===== HEALTH CHECK =====

health_check() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}              NeXuS DARKNET HEALTH CHECK               ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Test Tor
    echo -n "🧅 Tor connectivity: "
    if curl -s --socks5 127.0.0.1:9050 --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
        echo -e "${GREEN}✓ Connected to Tor network${NC}"
    else
        echo -e "${RED}✗ Not connected${NC}"
    fi

    # Test I2P
    echo -n "🔗 I2P connectivity: "
    if curl -s --proxy 127.0.0.1:4444 --max-time 15 http://i2p-projekt.i2p/ 2>/dev/null | grep -qi "i2p"; then
        echo -e "${GREEN}✓ Connected to I2P network${NC}"
    else
        echo -e "${YELLOW}⏳ I2P may still be building tunnels (takes 5-10 min)${NC}"
    fi

    # Test IPFS
    echo -n "🌐 IPFS connectivity: "
    if curl -s http://127.0.0.1:5001/api/v0/id 2>/dev/null | grep -q "ID"; then
        echo -e "${GREEN}✓ IPFS node operational${NC}"
    else
        echo -e "${RED}✗ IPFS not responding${NC}"
    fi

    # Test Privoxy
    echo -n "🕵️ Privoxy proxy: "
    if curl -s --proxy 127.0.0.1:8118 --max-time 10 http://httpbin.org/ip 2>/dev/null | grep -q "origin"; then
        echo -e "${GREEN}✓ Privoxy operational${NC}"
    else
        echo -e "${RED}✗ Privoxy not responding${NC}"
    fi

    echo ""
}

# ===== INTERACTIVE MENU =====

interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        show_status
        echo ""
        echo -e "${YELLOW}🎮 NeXuS Darknet Stack Menu:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 🚀 Start All Services"
        echo "2) 🛑 Stop All Services"
        echo "3) 🔄 Restart All Services"
        echo "4) 🩺 Health Check"
        echo "5) 📊 Refresh Status"
        echo ""
        echo "Individual Services:"
        echo "6) 🧅 Start/Stop Tor"
        echo "7) 🔗 Start/Stop I2P"
        echo "8) 🌲 Start/Stop Yggdrasil"
        echo "9) 🌐 Start/Stop IPFS"
        echo "a) 📡 Start/Stop Reticulum"
        echo "b) ❄️ Start/Stop Snowflake"
        echo "c) 🦇 Enable/Disable BATMAN-adv"
        echo ""
        echo "0) 🚪 Exit"
        echo ""
        read -p "Select option: " choice

        case "$choice" in
            1) start_all; read -p "Press Enter..." ;;
            2) stop_all; read -p "Press Enter..." ;;
            3) stop_all; sleep 2; start_all; read -p "Press Enter..." ;;
            4) health_check; read -p "Press Enter..." ;;
            5) ;; # Just refresh
            6) if is_running "tor"; then stop_service "tor"; else start_tor; fi; read -p "Press Enter..." ;;
            7) if is_running "i2p"; then stop_service "i2p"; else start_i2p; fi; read -p "Press Enter..." ;;
            8) if is_running "yggdrasil"; then stop_service "yggdrasil"; else start_yggdrasil; fi; read -p "Press Enter..." ;;
            9) if is_running "ipfs"; then stop_service "ipfs"; else start_ipfs; fi; read -p "Press Enter..." ;;
            a|A) if is_running "reticulum"; then stop_service "reticulum"; else start_reticulum; fi; read -p "Press Enter..." ;;
            b|B) if is_running "snowflake"; then stop_service "snowflake"; else start_snowflake; fi; read -p "Press Enter..." ;;
            c|C) enable_batman; read -p "Press Enter..." ;;
            0) echo "👋 Exiting NeXuS Darknet Stack"; exit 0 ;;
            *) echo "❌ Invalid option"; sleep 1 ;;
        esac
    done
}

# ===== MAIN =====

main() {
    init_dirs

    case "${1:-menu}" in
        "start")
            show_banner
            if [[ -n "${2:-}" ]]; then
                case "$2" in
                    "tor") start_tor ;;
                    "i2p") start_i2p ;;
                    "yggdrasil") start_yggdrasil ;;
                    "ipfs") start_ipfs ;;
                    "reticulum") start_reticulum ;;
                    "privoxy") start_privoxy ;;
                    "snowflake") start_snowflake ;;
                    "medusa") start_medusa ;;
                    "batman") enable_batman ;;
                    "all") start_all ;;
                    *) echo "Unknown service: $2" ;;
                esac
            else
                start_all
            fi
            ;;
        "stop")
            show_banner
            if [[ -n "${2:-}" ]]; then
                stop_service "$2"
            else
                stop_all
            fi
            ;;
        "restart")
            show_banner
            stop_all
            sleep 3
            start_all
            ;;
        "status")
            show_banner
            show_status
            ;;
        "health")
            show_banner
            health_check
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            show_banner
            echo ""
            echo "Usage: $0 {start|stop|restart|status|health|menu|help} [service]"
            echo ""
            echo "Commands:"
            echo "  start [service]   - Start all or specific service"
            echo "  stop [service]    - Stop all or specific service"
            echo "  restart           - Restart entire stack"
            echo "  status            - Show service status"
            echo "  health            - Run health checks"
            echo "  menu              - Interactive menu"
            echo ""
            echo "Services: tor, i2p, yggdrasil, ipfs, reticulum, privoxy, snowflake, batman"
            echo ""
            echo "Examples:"
            echo "  $0 start          # Start all services"
            echo "  $0 start tor      # Start only Tor"
            echo "  $0 health         # Check connectivity"
            echo "  $0 menu           # Interactive mode"
            ;;
    esac
}

main "$@"
