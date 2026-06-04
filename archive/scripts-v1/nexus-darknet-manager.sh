#!/bin/bash
# NeXuS Darknet Services Manager
# Enable/disable and manage hidden services across Tor, I2P, IPFS, Yggdrasil, Reticulum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/darknet"
SERVICES_DIR="/home/user/nexus-services"
LOG_DIR="/var/log/nexus-darknet"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$SERVICES_DIR" "$LOG_DIR" 2>/dev/null || true

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Darknet Services Manager 🔥"
    echo "Multi-Network Hidden Services Controller"
    echo "Tor • I2P • IPFS • Yggdrasil • Reticulum"
    echo -e "\e[0m"
}

# Service status tracking
declare -A SERVICE_STATUS

# Check if service is running
check_service_status() {
    local service="$1"
    case "$service" in
        "tor")
            if pgrep -f "tor.*-f.*torrc" >/dev/null; then
                SERVICE_STATUS["tor"]="🟢 RUNNING"
            else
                SERVICE_STATUS["tor"]="🔴 STOPPED"
            fi
            ;;
        "i2p")
            if pgrep -f "i2p" >/dev/null || podman ps --format "{{.Names}}" | grep -q "nexus-i2p"; then
                SERVICE_STATUS["i2p"]="🟢 RUNNING"
            else
                SERVICE_STATUS["i2p"]="🔴 STOPPED"
            fi
            ;;
        "ipfs")
            if pgrep -f "ipfs daemon" >/dev/null || podman ps --format "{{.Names}}" | grep -q "nexus-ipfs"; then
                SERVICE_STATUS["ipfs"]="🟢 RUNNING"
            else
                SERVICE_STATUS["ipfs"]="🔴 STOPPED"
            fi
            ;;
        "yggdrasil")
            if pgrep -f "yggdrasil" >/dev/null || podman ps --format "{{.Names}}" | grep -q "nexus-yggdrasil"; then
                SERVICE_STATUS["yggdrasil"]="🟢 RUNNING"
            else
                SERVICE_STATUS["yggdrasil"]="🔴 STOPPED"
            fi
            ;;
        "reticulum")
            if pgrep -f "reticulum" >/dev/null || podman ps --format "{{.Names}}" | grep -q "nexus-reticulum"; then
                SERVICE_STATUS["reticulum"]="🟢 RUNNING"
            else
                SERVICE_STATUS["reticulum"]="🔴 STOPPED"
            fi
            ;;
    esac
}

# Update all service statuses
update_all_status() {
    for service in tor i2p ipfs yggdrasil reticulum; do
        check_service_status "$service"
    done
}

# Show current status
show_status() {
    echo "📊 NeXuS Darknet Services Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    update_all_status
    
    echo "🧅 Tor Hidden Service:     ${SERVICE_STATUS["tor"]}"
    echo "🔗 I2P Eepsite:           ${SERVICE_STATUS["i2p"]}"
    echo "🌐 IPFS Gateway:          ${SERVICE_STATUS["ipfs"]}"
    echo "🌲 Yggdrasil Service:     ${SERVICE_STATUS["yggdrasil"]}"
    echo "📡 Reticulum Node:        ${SERVICE_STATUS["reticulum"]}"
    echo ""
    
    # Show hidden service addresses if available
    if [[ "${SERVICE_STATUS["tor"]}" == *"RUNNING"* ]]; then
        local tor_hostname=$(find /var/lib/tor -name "hostname" 2>/dev/null | head -1)
        if [[ -f "$tor_hostname" ]]; then
            echo "🧅 Tor Address: $(cat "$tor_hostname")"
        fi
    fi
    
    if [[ "${SERVICE_STATUS["i2p"]}" == *"RUNNING"* ]]; then
        echo "🔗 I2P Address: [check tunnels.cfg]"
    fi
    
    if [[ "${SERVICE_STATUS["ipfs"]}" == *"RUNNING"* ]]; then
        local ipfs_id=$(ipfs id -f='<id>' 2>/dev/null || echo "unknown")
        echo "🌐 IPFS Node ID: $ipfs_id"
    fi
}

# Configure Tor hidden service
setup_tor_service() {
    local service_name="$1"
    local local_port="$2"
    local hidden_port="${3:-80}"
    
    echo "🧅 Setting up Tor hidden service: $service_name"
    
    # Create torrc configuration
    cat > "$CONFIG_DIR/torrc-$service_name" << EOF
# NeXuS Tor Hidden Service Configuration
SocksPort 9050
ControlPort 9051
CookieAuthentication 1
DataDirectory /var/lib/tor-$service_name

# Hidden Service
HiddenServiceDir /var/lib/tor-$service_name/hidden_service/
HiddenServicePort $hidden_port 127.0.0.1:$local_port
HiddenServiceVersion 3

# Security settings
ExitPolicy reject *:*
HardwareAccel 1
EOF

    echo "✅ Tor config created: $CONFIG_DIR/torrc-$service_name"
}

# Configure I2P eepsite
setup_i2p_service() {
    local service_name="$1"
    local local_port="$2"
    
    echo "🔗 Setting up I2P eepsite: $service_name"
    
    # Create I2P tunnel configuration
    cat > "$CONFIG_DIR/i2ptunnel-$service_name.config" << EOF
# NeXuS I2P Tunnel Configuration
tunnel.0.description=$service_name Hidden Service
tunnel.0.interface=127.0.0.1
tunnel.0.listenPort=7658
tunnel.0.name=$service_name
tunnel.0.option.i2cp.reduceOnIdle=true
tunnel.0.option.inbound.length=3
tunnel.0.option.outbound.length=3
tunnel.0.startOnLoad=true
tunnel.0.targetHost=127.0.0.1
tunnel.0.targetPort=$local_port
tunnel.0.type=server
EOF

    echo "✅ I2P config created: $CONFIG_DIR/i2ptunnel-$service_name.config"
}

# Configure IPFS service
setup_ipfs_service() {
    local service_name="$1"
    local local_port="$2"
    
    echo "🌐 Setting up IPFS gateway service: $service_name"
    
    # Create IPFS configuration
    cat > "$CONFIG_DIR/ipfs-$service_name.json" << EOF
{
  "API": {
    "HTTPHeaders": {
      "Access-Control-Allow-Origin": ["*"],
      "Access-Control-Allow-Methods": ["GET", "POST", "PUT", "DELETE"],
      "Access-Control-Allow-Headers": ["Authorization"]
    }
  },
  "Addresses": {
    "API": "/ip4/127.0.0.1/tcp/5001",
    "Gateway": "/ip4/127.0.0.1/tcp/8080",
    "Swarm": ["/ip4/0.0.0.0/tcp/4001", "/ip6/::/tcp/4001"]
  },
  "Gateway": {
    "HTTPHeaders": {
      "Access-Control-Allow-Origin": ["*"],
      "Access-Control-Allow-Methods": ["GET"],
      "Access-Control-Allow-Headers": ["X-Requested-With", "Range", "User-Agent"]
    },
    "PathPrefixes": [],
    "RootRedirect": "",
    "Writable": false
  }
}
EOF

    echo "✅ IPFS config created: $CONFIG_DIR/ipfs-$service_name.json"
}

# Start service
start_service() {
    local network="$1"
    local service_name="${2:-nexus-service}"
    local local_port="${3:-8080}"
    
    echo "🚀 Starting $network service: $service_name"
    
    case "$network" in
        "tor")
            setup_tor_service "$service_name" "$local_port"
            # Start tor with custom config
            podman run -d \
                --name "nexus-tor-$service_name" \
                --publish "127.0.0.1:9050:9050" \
                --volume "$CONFIG_DIR/torrc-$service_name:/etc/tor/torrc:ro" \
                --volume "nexus-tor-$service_name-data:/var/lib/tor-$service_name" \
                --restart unless-stopped \
                alpine/tor:latest
            echo "✅ Tor service started"
            ;;
        "i2p")
            setup_i2p_service "$service_name" "$local_port"
            # Start I2P with custom tunnel
            podman run -d \
                --name "nexus-i2p-$service_name" \
                --publish "127.0.0.1:7657:7657" \
                --publish "127.0.0.1:4444:4444" \
                --volume "$CONFIG_DIR/i2ptunnel-$service_name.config:/opt/i2p/i2ptunnel.config:ro" \
                --restart unless-stopped \
                purplei2p/i2pd:latest
            echo "✅ I2P service started"
            ;;
        "ipfs")
            setup_ipfs_service "$service_name" "$local_port"
            # Start IPFS node
            podman run -d \
                --name "nexus-ipfs-$service_name" \
                --publish "127.0.0.1:5001:5001" \
                --publish "127.0.0.1:8080:8080" \
                --volume "nexus-ipfs-$service_name-data:/data/ipfs" \
                --restart unless-stopped \
                ipfs/go-ipfs:latest
            echo "✅ IPFS service started"
            ;;
        *)
            echo "❌ Unsupported network: $network"
            echo "Available: tor, i2p, ipfs"
            return 1
            ;;
    esac
}

# Stop service
stop_service() {
    local network="$1"
    local service_name="${2:-nexus-service}"
    
    echo "🛑 Stopping $network service: $service_name"
    
    local container_name="nexus-$network-$service_name"
    if podman ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        podman stop "$container_name"
        podman rm "$container_name"
        echo "✅ $network service stopped"
    else
        echo "⚠️  Service not running: $container_name"
    fi
}

# Stop all services
stop_all() {
    echo "🛑 Stopping all NeXuS darknet services..."
    
    for network in tor i2p ipfs yggdrasil reticulum; do
        # Find all containers for this network
        local containers=$(podman ps --format "{{.Names}}" | grep "^nexus-$network" || echo "")
        if [[ -n "$containers" ]]; then
            echo "$containers" | while read -r container; do
                echo "Stopping $container..."
                podman stop "$container" && podman rm "$container"
            done
        fi
    done
    
    echo "✅ All services stopped"
}

# List hidden service addresses
list_addresses() {
    echo "🌐 NeXuS Hidden Service Addresses:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Tor addresses
    echo "🧅 Tor Hidden Services:"
    if podman volume ls --format "{{.Name}}" | grep -q "nexus-tor.*data"; then
        podman volume ls --format "{{.Name}}" | grep "nexus-tor.*data" | while read -r volume; do
            local hostname_file="/var/lib/containers/storage/volumes/$volume/_data/hidden_service/hostname"
            if [[ -f "$hostname_file" ]]; then
                echo "   $(cat "$hostname_file")"
            fi
        done
    else
        echo "   No Tor services configured"
    fi
    
    # I2P addresses
    echo ""
    echo "🔗 I2P Eepsites:"
    echo "   Check I2P router console: http://localhost:7657"
    
    # IPFS addresses
    echo ""
    echo "🌐 IPFS Gateway:"
    if podman ps --format "{{.Names}}" | grep -q "nexus-ipfs"; then
        echo "   Gateway: http://localhost:8080"
        echo "   API: http://localhost:5001"
    else
        echo "   No IPFS services running"
    fi
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        show_status
        echo ""
        echo "🎮 NeXuS Darknet Manager Options:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 🚀 Start Tor Hidden Service"
        echo "2) 🚀 Start I2P Eepsite"
        echo "3) 🚀 Start IPFS Gateway"
        echo "4) 🛑 Stop Service"
        echo "5) 🛑 Stop All Services"
        echo "6) 🌐 List Service Addresses"
        echo "7) 📊 Refresh Status"
        echo "8) 🚪 Exit"
        echo ""
        read -p "Select option (1-8): " choice
        
        case "$choice" in
            1)
                read -p "Service name: " service_name
                read -p "Local port (default 8080): " local_port
                start_service "tor" "${service_name:-nexus-service}" "${local_port:-8080}"
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Service name: " service_name
                read -p "Local port (default 8080): " local_port
                start_service "i2p" "${service_name:-nexus-service}" "${local_port:-8080}"
                read -p "Press Enter to continue..."
                ;;
            3)
                read -p "Service name: " service_name
                start_service "ipfs" "${service_name:-nexus-service}"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo "Available networks: tor, i2p, ipfs"
                read -p "Network: " network
                read -p "Service name: " service_name
                stop_service "$network" "${service_name:-nexus-service}"
                read -p "Press Enter to continue..."
                ;;
            5)
                stop_all
                read -p "Press Enter to continue..."
                ;;
            6)
                list_addresses
                read -p "Press Enter to continue..."
                ;;
            7)
                # Just refresh (loop will show updated status)
                ;;
            8)
                echo "👋 Exiting NeXuS Darknet Manager"
                break
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Main command dispatcher
main() {
    show_banner
    
    case "${1:-menu}" in
        "start")
            start_service "${2:-tor}" "${3:-nexus-service}" "${4:-8080}"
            ;;
        "stop")
            if [[ "${2:-}" == "all" ]]; then
                stop_all
            else
                stop_service "${2:-tor}" "${3:-nexus-service}"
            fi
            ;;
        "status")
            show_status
            ;;
        "list"|"addresses")
            list_addresses
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS Darknet Services Manager"
            echo ""
            echo "Usage: $0 {start|stop|status|list|menu|help}"
            echo ""
            echo "Commands:"
            echo "  start <network> [service_name] [port]  - Start hidden service"
            echo "  stop <network> [service_name]          - Stop specific service"
            echo "  stop all                               - Stop all services"
            echo "  status                                 - Show service status"
            echo "  list                                   - List service addresses"
            echo "  menu                                   - Interactive menu"
            echo "  help                                   - Show this help"
            echo ""
            echo "Networks: tor, i2p, ipfs"
            echo ""
            echo "Examples:"
            echo "  $0 start tor my-blog 8080"
            echo "  $0 stop tor my-blog"
            echo "  $0 menu"
            ;;
    esac
}

# Execute main function
main "$@"