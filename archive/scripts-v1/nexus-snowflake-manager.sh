#!/bin/bash
# NeXuS Multi-Network Relay Manager
# Manage Tor relays (snowflake, middle), I2P outproxy nodes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/darknet"
SNOWFLAKE_CONTAINER="nexus-snowflake-bridge"
MIDDLE_RELAY_CONTAINER="nexus-tor-middle-relay"
OUTPROXY_CONTAINER="nexus-tor-outproxy"
I2P_OUTPROXY_CONTAINER="nexus-i2p-outproxy"

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Multi-Network Relay Manager 🔥"
    echo "Snowflake Bridge • Middle Relay • I2P Outproxy • Node Selection"
    echo -e "\e[0m"
}

# Get bridge info from running snowflake
get_bridge_info() {
    if podman ps --format "{{.Names}}" | grep -q "^$SNOWFLAKE_CONTAINER$"; then
        echo "📋 Snowflake Bridge Information:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Get bridge line from container logs
        local bridge_line=$(podman logs "$SNOWFLAKE_CONTAINER" 2>/dev/null | grep -E "bridge.*snowflake" | tail -1 || echo "")
        if [[ -n "$bridge_line" ]]; then
            echo "🌉 Bridge Line:"
            echo "$bridge_line"
        else
            echo "⚠️  Bridge line not available yet (check logs later)"
        fi
        
        # Get fingerprint
        local fingerprint=$(podman exec "$SNOWFLAKE_CONTAINER" cat /var/lib/tor-snowflake/fingerprint 2>/dev/null || echo "Not available")
        echo "🔑 Fingerprint: $fingerprint"
        
        # Get stats
        echo ""
        echo "📊 Connection Stats:"
        podman exec "$SNOWFLAKE_CONTAINER" cat /var/lib/tor-snowflake/stats/bridge-stats 2>/dev/null | tail -5 || echo "Stats not available"
        
    else
        echo "❌ Snowflake bridge not running"
    fi
}

# Start Tor middle relay
start_middle_relay() {
    echo "🚀 Starting NeXuS Tor Middle Relay..."
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$MIDDLE_RELAY_CONTAINER$"; then
        echo "⚠️  Stopping existing middle relay..."
        podman stop "$MIDDLE_RELAY_CONTAINER" && podman rm "$MIDDLE_RELAY_CONTAINER"
    fi
    
    # Start middle relay
    podman run -d \
        --name "$MIDDLE_RELAY_CONTAINER" \
        --publish "9001:9001" \
        --publish "9030:9030" \
        --volume "$CONFIG_DIR/torrc-middle-relay:/etc/tor/torrc:ro" \
        --volume "nexus-middle-relay-data:/var/lib/tor-relay" \
        --volume "nexus-middle-relay-logs:/var/log/tor" \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        alpine/tor:latest
    
    echo "✅ Tor middle relay started"
    echo "🔗 ORPort: 9001 (for Tor network)"
    echo "📂 DirPort: 9030 (directory service)"
    echo "⚠️  This relay does NOT handle exit traffic (safer for home networks)"
    
    # Wait and show relay info
    sleep 5
    get_relay_info
}

# Get middle relay info
get_relay_info() {
    if podman ps --format "{{.Names}}" | grep -q "^$MIDDLE_RELAY_CONTAINER$"; then
        echo "📋 Middle Relay Information:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Get fingerprint
        local fingerprint=$(podman exec "$MIDDLE_RELAY_CONTAINER" cat /var/lib/tor-relay/fingerprint 2>/dev/null || echo "Generating...")
        echo "🔑 Fingerprint: $fingerprint"
        
        # Get relay status from logs
        echo "📡 Status:"
        podman logs "$MIDDLE_RELAY_CONTAINER" 2>/dev/null | grep -E "(Bootstrapped|bandwidth|Self-testing)" | tail -3 || echo "Starting up..."
        
        echo ""
        echo "🌐 Relay Type: Middle Relay (No Exit Traffic)"
        echo "🔗 Check status at: https://metrics.torproject.org/rs.html#search/$fingerprint"
        
    else
        echo "❌ Middle relay not running"
    fi
}

# Start snowflake bridge
start_snowflake() {
    local capacity="${1:-10}"
    
    echo "🚀 Starting NeXuS Snowflake Bridge (capacity: $capacity)..."
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$SNOWFLAKE_CONTAINER$"; then
        echo "⚠️  Stopping existing snowflake bridge..."
        podman stop "$SNOWFLAKE_CONTAINER" && podman rm "$SNOWFLAKE_CONTAINER"
    fi
    
    # Start snowflake bridge
    podman run -d \
        --name "$SNOWFLAKE_CONTAINER" \
        --publish "8080:8080" \
        --publish "15000-35000:15000-35000/udp" \
        --volume "$CONFIG_DIR/torrc-snowflake-bridge:/etc/tor/torrc:ro" \
        --volume "nexus-snowflake-data:/var/lib/tor-snowflake" \
        --volume "nexus-snowflake-logs:/var/log/tor" \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        alpine/tor:latest
    
    echo "✅ Snowflake bridge started on port 8080"
    echo "📡 UDP ports 15000-35000 exposed for WebRTC"
    
    # Wait a moment then show bridge info
    sleep 5
    get_bridge_info
}

# Start I2P outproxy through Tor
start_i2p_outproxy() {
    echo "🚀 Starting I2P Outproxy through Tor..."
    
    # Start Tor outproxy first
    if ! podman ps --format "{{.Names}}" | grep -q "^$OUTPROXY_CONTAINER$"; then
        echo "Starting Tor outproxy node..."
        podman run -d \
            --name "$OUTPROXY_CONTAINER" \
            --publish "127.0.0.1:9052:9052" \
            --volume "$CONFIG_DIR/torrc-outproxy:/etc/tor/torrc:ro" \
            --volume "nexus-tor-outproxy-data:/var/lib/tor-outproxy" \
            --restart unless-stopped \
            --security-opt no-new-privileges \
            alpine/tor:latest
        
        echo "✅ Tor outproxy started"
        sleep 3
    fi
    
    # Start I2P with Tor outproxy
    if podman ps --format "{{.Names}}" | grep -q "^$I2P_OUTPROXY_CONTAINER$"; then
        echo "⚠️  Stopping existing I2P outproxy..."
        podman stop "$I2P_OUTPROXY_CONTAINER" && podman rm "$I2P_OUTPROXY_CONTAINER"
    fi
    
    podman run -d \
        --name "$I2P_OUTPROXY_CONTAINER" \
        --publish "127.0.0.1:7070:7070" \
        --publish "127.0.0.1:4444:4444" \
        --publish "127.0.0.1:4447:4447" \
        --publish "127.0.0.1:8090:8090" \
        --volume "$CONFIG_DIR/i2pd-outproxy.conf:/home/i2pd/conf/i2pd.conf:ro" \
        --volume "nexus-i2p-outproxy-data:/home/i2pd/data" \
        --link "$OUTPROXY_CONTAINER:tor-outproxy" \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        purplei2p/i2pd:latest
    
    echo "✅ I2P outproxy started with Tor backend"
    echo "🌐 I2P Console: http://localhost:7070"
    echo "🔗 I2P HTTP Proxy: 127.0.0.1:4444"
    echo "🧅 Outproxy via Tor: 127.0.0.1:8090"
}

# Stop services
stop_service() {
    local service="$1"
    
    case "$service" in
        "snowflake")
            echo "🛑 Stopping Snowflake bridge..."
            if podman ps --format "{{.Names}}" | grep -q "^$SNOWFLAKE_CONTAINER$"; then
                podman stop "$SNOWFLAKE_CONTAINER" && podman rm "$SNOWFLAKE_CONTAINER"
                echo "✅ Snowflake bridge stopped"
            else
                echo "⚠️  Snowflake bridge not running"
            fi
            ;;
        "outproxy")
            echo "🛑 Stopping I2P outproxy..."
            if podman ps --format "{{.Names}}" | grep -q "^$I2P_OUTPROXY_CONTAINER$"; then
                podman stop "$I2P_OUTPROXY_CONTAINER" && podman rm "$I2P_OUTPROXY_CONTAINER"
                echo "✅ I2P outproxy stopped"
            fi
            if podman ps --format "{{.Names}}" | grep -q "^$OUTPROXY_CONTAINER$"; then
                podman stop "$OUTPROXY_CONTAINER" && podman rm "$OUTPROXY_CONTAINER"
                echo "✅ Tor outproxy stopped"
            fi
            ;;
        "all")
            stop_service "snowflake"
            stop_service "outproxy"
            ;;
        *)
            echo "❌ Unknown service: $service"
            echo "Available: snowflake, outproxy, all"
            ;;
    esac
}

# Show service status
show_status() {
    echo "📊 NeXuS Bridge & Outproxy Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Snowflake status
    if podman ps --format "{{.Names}}" | grep -q "^$SNOWFLAKE_CONTAINER$"; then
        echo "❄️  Snowflake Bridge:  🟢 RUNNING"
        local clients=$(podman logs "$SNOWFLAKE_CONTAINER" 2>/dev/null | grep -c "new client" || echo "0")
        echo "   Active clients: $clients"
    else
        echo "❄️  Snowflake Bridge:  🔴 STOPPED"
    fi
    
    # I2P Outproxy status
    if podman ps --format "{{.Names}}" | grep -q "^$I2P_OUTPROXY_CONTAINER$"; then
        echo "🔗 I2P Outproxy:      🟢 RUNNING"
        echo "   Console: http://localhost:7070"
    else
        echo "🔗 I2P Outproxy:      🔴 STOPPED"
    fi
    
    # Tor Outproxy status
    if podman ps --format "{{.Names}}" | grep -q "^$OUTPROXY_CONTAINER$"; then
        echo "🧅 Tor Outproxy:      🟢 RUNNING"
    else
        echo "🧅 Tor Outproxy:      🔴 STOPPED"
    fi
    
    echo ""
    echo "🌐 Network Configuration:"
    echo "   I2P → Tor → Clearnet (layered anonymity)"
    echo "   Snowflake helps censored users access Tor"
}

# Interactive node selector
select_nodes() {
    echo "🎯 NeXuS Node Selection Menu:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1) 🌉 Bridge Provider (Snowflake)"
    echo "2) 🔗 I2P Outproxy (to Tor)"
    echo "3) 🧅 Tor Exit Relay"
    echo "4) 📡 Combined Bridge + Outproxy"
    echo "5) 🛑 Stop All Services"
    echo "6) 📊 Show Status"
    echo "7) 🚪 Exit"
    echo ""
    
    read -p "Select node type (1-7): " choice
    
    case "$choice" in
        1)
            read -p "Bridge capacity (default 10): " capacity
            start_snowflake "${capacity:-10}"
            ;;
        2)
            start_i2p_outproxy
            ;;
        3)
            echo "⚠️  Running a Tor exit relay requires careful consideration"
            echo "    and proper legal/technical preparation."
            echo "    This will expose your IP as a Tor exit."
            read -p "Continue? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "🚧 Tor exit relay setup not implemented yet"
                echo "    Use standard Tor relay configuration"
            fi
            ;;
        4)
            echo "🚀 Starting combined bridge and outproxy..."
            start_snowflake 15
            sleep 3
            start_i2p_outproxy
            echo "✅ Combined services started"
            ;;
        5)
            stop_service "all"
            ;;
        6)
            show_status
            echo ""
            get_bridge_info
            ;;
        7)
            echo "👋 Exiting node selector"
            return
            ;;
        *)
            echo "❌ Invalid option"
            ;;
    esac
    
    if [[ "$choice" != "7" ]]; then
        echo ""
        read -p "Press Enter to continue..."
        select_nodes
    fi
}

# Main command dispatcher
main() {
    show_banner
    
    case "${1:-menu}" in
        "start")
            case "${2:-snowflake}" in
                "snowflake")
                    start_snowflake "${3:-10}"
                    ;;
                "outproxy")
                    start_i2p_outproxy
                    ;;
                "both")
                    start_snowflake "${3:-10}"
                    sleep 3
                    start_i2p_outproxy
                    ;;
                *)
                    echo "Usage: $0 start {snowflake|outproxy|both} [capacity]"
                    ;;
            esac
            ;;
        "stop")
            stop_service "${2:-all}"
            ;;
        "status")
            show_status
            get_bridge_info
            ;;
        "info"|"bridge")
            get_bridge_info
            ;;
        "select"|"menu")
            select_nodes
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS Snowflake & Outproxy Manager"
            echo ""
            echo "Usage: $0 {start|stop|status|info|select|help}"
            echo ""
            echo "Commands:"
            echo "  start snowflake [capacity]  - Start snowflake bridge"
            echo "  start outproxy              - Start I2P→Tor outproxy"
            echo "  start both [capacity]       - Start both services"
            echo "  stop {snowflake|outproxy|all} - Stop services"
            echo "  status                      - Show service status"
            echo "  info                        - Show bridge information"
            echo "  select                      - Interactive node selector"
            echo "  help                        - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 start snowflake 20    # High capacity bridge"
            echo "  $0 start both 15         # Combined services"
            echo "  $0 select                # Interactive menu"
            ;;
    esac
}

# Execute main function
main "$@"