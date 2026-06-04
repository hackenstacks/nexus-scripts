#!/bin/bash
# NeXuS P2P Services Manager
# IPFS, RetroShare over Tor/I2P, OnionShare management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/darknet"

# Container names
IPFS_CONTAINER="nexus-ipfs"
RETROSHARE_CONTAINER="nexus-retroshare"
ONIONSHARE_CONTAINER="nexus-onionshare"

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS P2P Services Manager 🔥"
    echo "IPFS • RetroShare • OnionShare • Anonymous Communication"
    echo -e "\e[0m"
}

# Start IPFS node
start_ipfs() {
    echo "🌐 Starting NeXuS IPFS Node..."
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$IPFS_CONTAINER$"; then
        echo "⚠️  Stopping existing IPFS node..."
        podman stop "$IPFS_CONTAINER" && podman rm "$IPFS_CONTAINER"
    fi
    
    # Initialize IPFS if needed
    if ! podman volume exists nexus-ipfs-data; then
        echo "🔧 Initializing IPFS repository..."
        podman run --rm \
            --volume nexus-ipfs-data:/data/ipfs \
            ipfs/go-ipfs:latest \
            init --profile server
    fi
    
    # Start IPFS node
    podman run -d \
        --name "$IPFS_CONTAINER" \
        --publish "127.0.0.1:5001:5001" \
        --publish "127.0.0.1:8080:8080" \
        --publish "4001:4001" \
        --volume nexus-ipfs-data:/data/ipfs \
        --volume "$CONFIG_DIR/ipfs.json:/data/ipfs/config:ro" \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        ipfs/go-ipfs:latest
    
    echo "✅ IPFS node started"
    echo "🌐 Gateway: http://localhost:8080"
    echo "📡 API: http://localhost:5001"
    echo "🔗 WebUI: http://localhost:5001/webui"
    
    # Get peer ID
    sleep 3
    local peer_id=$(podman exec "$IPFS_CONTAINER" ipfs id -f='<id>' 2>/dev/null || echo "Initializing...")
    echo "🆔 Peer ID: $peer_id"
}

# Start RetroShare
start_retroshare() {
    local network="${1:-tor}"
    
    echo "🤝 Starting RetroShare over $network..."
    
    # Check if Tor/I2P is running
    if [[ "$network" == "tor" ]] && ! podman ps --format "{{.Names}}" | grep -q "nexus-tor"; then
        echo "❌ Tor not running. Start Tor first with darknet manager."
        return 1
    fi
    
    if [[ "$network" == "i2p" ]] && ! podman ps --format "{{.Names}}" | grep -q "nexus-i2p"; then
        echo "❌ I2P not running. Start I2P first with darknet manager."
        return 1
    fi
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$RETROSHARE_CONTAINER$"; then
        echo "⚠️  Stopping existing RetroShare..."
        podman stop "$RETROSHARE_CONTAINER" && podman rm "$RETROSHARE_CONTAINER"
    fi
    
    # Start RetroShare
    podman run -d \
        --name "$RETROSHARE_CONTAINER" \
        --publish "127.0.0.1:7022:7022" \
        --volume nexus-retroshare-data:/home/retroshare/.retroshare \
        --volume "$CONFIG_DIR/retroshare.conf:/home/retroshare/.retroshare/retroshare.conf:ro" \
        --link nexus-tor:tor-proxy \
        --link nexus-i2p:i2p-proxy \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        retroshare/retroshare:latest
    
    echo "✅ RetroShare started over $network"
    echo "🔒 Anonymous P2P communication enabled"
    echo "💬 Chat and file sharing ready"
    echo "🌐 Access: Connect via RetroShare client on port 7022"
}

# Start OnionShare
start_onionshare() {
    local share_dir="${1:-/tmp/nexus-share}"
    
    echo "🧅 Starting OnionShare for quick anonymous sharing..."
    
    # Create share directory
    mkdir -p "$share_dir"
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$ONIONSHARE_CONTAINER$"; then
        echo "⚠️  Stopping existing OnionShare..."
        podman stop "$ONIONSHARE_CONTAINER" && podman rm "$ONIONSHARE_CONTAINER"
    fi
    
    # Start OnionShare
    podman run -d \
        --name "$ONIONSHARE_CONTAINER" \
        --publish "127.0.0.1:17600:17600" \
        --volume "$share_dir:/share:ro" \
        --volume nexus-onionshare-data:/onionshare \
        --link nexus-tor:tor \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        micahflee/onionshare:latest \
        --local-only --stay-open --public /share
    
    echo "✅ OnionShare started"
    echo "📁 Share directory: $share_dir"
    echo "🧅 Anonymous sharing enabled"
    echo "🌐 Web interface: http://localhost:17600"
    
    # Get onion address
    sleep 5
    local onion_addr=$(podman logs "$ONIONSHARE_CONTAINER" 2>/dev/null | grep -E "\.onion" | tail -1 || echo "Generating...")
    echo "🔗 Onion address: $onion_addr"
}

# Stop services
stop_service() {
    local service="$1"
    
    case "$service" in
        "ipfs")
            echo "🛑 Stopping IPFS..."
            if podman ps --format "{{.Names}}" | grep -q "^$IPFS_CONTAINER$"; then
                podman stop "$IPFS_CONTAINER" && podman rm "$IPFS_CONTAINER"
                echo "✅ IPFS stopped"
            else
                echo "⚠️  IPFS not running"
            fi
            ;;
        "retroshare")
            echo "🛑 Stopping RetroShare..."
            if podman ps --format "{{.Names}}" | grep -q "^$RETROSHARE_CONTAINER$"; then
                podman stop "$RETROSHARE_CONTAINER" && podman rm "$RETROSHARE_CONTAINER"
                echo "✅ RetroShare stopped"
            else
                echo "⚠️  RetroShare not running"
            fi
            ;;
        "onionshare")
            echo "🛑 Stopping OnionShare..."
            if podman ps --format "{{.Names}}" | grep -q "^$ONIONSHARE_CONTAINER$"; then
                podman stop "$ONIONSHARE_CONTAINER" && podman rm "$ONIONSHARE_CONTAINER"
                echo "✅ OnionShare stopped"
            else
                echo "⚠️  OnionShare not running"
            fi
            ;;
        "all")
            stop_service "ipfs"
            stop_service "retroshare"
            stop_service "onionshare"
            ;;
        *)
            echo "❌ Unknown service: $service"
            echo "Available: ipfs, retroshare, onionshare, all"
            ;;
    esac
}

# Show service status
show_status() {
    echo "📊 NeXuS P2P Services Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # IPFS status
    if podman ps --format "{{.Names}}" | grep -q "^$IPFS_CONTAINER$"; then
        echo "🌐 IPFS Node:         🟢 RUNNING"
        local peer_id=$(podman exec "$IPFS_CONTAINER" ipfs id -f='<id>' 2>/dev/null || echo "unknown")
        echo "   Peer ID: ${peer_id:0:20}..."
        echo "   Gateway: http://localhost:8080"
        echo "   API: http://localhost:5001"
    else
        echo "🌐 IPFS Node:         🔴 STOPPED"
    fi
    
    # RetroShare status
    if podman ps --format "{{.Names}}" | grep -q "^$RETROSHARE_CONTAINER$"; then
        echo "🤝 RetroShare:        🟢 RUNNING"
        echo "   Anonymous P2P communication active"
        echo "   Port: 7022"
    else
        echo "🤝 RetroShare:        🔴 STOPPED"
    fi
    
    # OnionShare status
    if podman ps --format "{{.Names}}" | grep -q "^$ONIONSHARE_CONTAINER$"; then
        echo "🧅 OnionShare:        🟢 RUNNING"
        echo "   Anonymous file sharing active"
        echo "   Interface: http://localhost:17600"
    else
        echo "🧅 OnionShare:        🔴 STOPPED"
    fi
    
    echo ""
    echo "🔗 P2P Network Features:"
    echo "   • IPFS: Distributed file system"
    echo "   • RetroShare: Anonymous chat & file sharing"
    echo "   • OnionShare: Quick anonymous file drops"
}

# Get service info
get_service_info() {
    local service="$1"
    
    case "$service" in
        "ipfs")
            if podman ps --format "{{.Names}}" | grep -q "^$IPFS_CONTAINER$"; then
                echo "📋 IPFS Node Information:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                podman exec "$IPFS_CONTAINER" ipfs id
                echo ""
                echo "📊 Stats:"
                podman exec "$IPFS_CONTAINER" ipfs stats bw
            else
                echo "❌ IPFS not running"
            fi
            ;;
        "retroshare")
            if podman ps --format "{{.Names}}" | grep -q "^$RETROSHARE_CONTAINER$"; then
                echo "📋 RetroShare Information:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🔒 Anonymous P2P Network: ACTIVE"
                echo "💬 Secure Chat: ENABLED"
                echo "📁 File Sharing: ENABLED"
                echo "🌐 Connect via Tor/I2P: YES"
                echo ""
                echo "📋 Recent logs:"
                podman logs "$RETROSHARE_CONTAINER" --tail 5
            else
                echo "❌ RetroShare not running"
            fi
            ;;
        "onionshare")
            if podman ps --format "{{.Names}}" | grep -q "^$ONIONSHARE_CONTAINER$"; then
                echo "📋 OnionShare Information:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🧅 Anonymous Sharing: ACTIVE"
                local onion_addr=$(podman logs "$ONIONSHARE_CONTAINER" 2>/dev/null | grep -E "\.onion" | tail -1 || echo "Check logs")
                echo "🔗 Onion Address: $onion_addr"
                echo "📁 Files ready for anonymous download"
            else
                echo "❌ OnionShare not running"
            fi
            ;;
        *)
            echo "❌ Unknown service: $service"
            echo "Available: ipfs, retroshare, onionshare"
            ;;
    esac
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        show_status
        echo ""
        echo "🎮 NeXuS P2P Services Menu:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 🌐 Start IPFS Node"
        echo "2) 🤝 Start RetroShare (Tor)"
        echo "3) 🤝 Start RetroShare (I2P)"
        echo "4) 🧅 Start OnionShare"
        echo "5) 🛑 Stop Service"
        echo "6) ℹ️  Service Information"
        echo "7) 📊 Refresh Status"
        echo "8) 🚪 Exit"
        echo ""
        read -p "Select option (1-8): " choice
        
        case "$choice" in
            1)
                start_ipfs
                read -p "Press Enter to continue..."
                ;;
            2)
                start_retroshare "tor"
                read -p "Press Enter to continue..."
                ;;
            3)
                start_retroshare "i2p"
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Share directory (default /tmp/nexus-share): " share_dir
                start_onionshare "${share_dir:-/tmp/nexus-share}"
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Available services: ipfs, retroshare, onionshare, all"
                read -p "Service to stop: " service
                stop_service "$service"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "Available services: ipfs, retroshare, onionshare"
                read -p "Service info: " service
                get_service_info "$service"
                read -p "Press Enter to continue..."
                ;;
            7)
                # Just refresh (loop will show updated status)
                ;;
            8)
                echo "👋 Exiting NeXuS P2P Manager"
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
            case "${2:-ipfs}" in
                "ipfs")
                    start_ipfs
                    ;;
                "retroshare")
                    start_retroshare "${3:-tor}"
                    ;;
                "onionshare")
                    start_onionshare "${3:-/tmp/nexus-share}"
                    ;;
                *)
                    echo "Usage: $0 start {ipfs|retroshare|onionshare} [network/path]"
                    ;;
            esac
            ;;
        "stop")
            stop_service "${2:-all}"
            ;;
        "status")
            show_status
            ;;
        "info")
            get_service_info "${2:-ipfs}"
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS P2P Services Manager"
            echo ""
            echo "Usage: $0 {start|stop|status|info|menu|help}"
            echo ""
            echo "Commands:"
            echo "  start ipfs                    - Start IPFS node"
            echo "  start retroshare [tor|i2p]   - Start RetroShare over network"
            echo "  start onionshare [directory] - Start OnionShare"
            echo "  stop {ipfs|retroshare|onionshare|all} - Stop services"
            echo "  status                        - Show service status"
            echo "  info <service>               - Show service information"
            echo "  menu                         - Interactive menu"
            echo "  help                         - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 start retroshare tor      # Anonymous chat via Tor"
            echo "  $0 start onionshare /docs    # Share /docs anonymously"
            echo "  $0 menu                      # Interactive interface"
            ;;
    esac
}

# Execute main function
main "$@"