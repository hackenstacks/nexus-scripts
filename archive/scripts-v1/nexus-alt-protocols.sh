#!/bin/bash
# NeXuS Alternative Protocols Manager
# Gopher, Gemini, txt blogger, OpenSnitch, and protocol gateway

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/nexus-stack"

# Container names
TXT_CONTAINER="nexus-txt-blogger"
GEMINI_CONTAINER="nexus-gemini"
GOPHER_CONTAINER="nexus-gopher"
OPENSNITCH_CONTAINER="nexus-opensnitch"
PROTOCOL_GATEWAY_CONTAINER="nexus-protocol-gateway"

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Alternative Protocols Manager 🔥"
    echo "txt • Gemini • Gopher • OpenSnitch • Protocol Gateway"
    echo -e "\e[0m"
}

# Get service status
get_alt_protocols_status() {
    echo "📊 NeXuS Alternative Protocols Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # txt Blogger
    if podman ps --format "{{.Names}}" | grep -q "^$TXT_CONTAINER$"; then
        echo "📝 txt Blogger:       🟢 RUNNING (http://localhost:8091)"
        local posts_count=$(curl -s http://127.0.0.1:8091/api/posts 2>/dev/null | jq '.posts | length' 2>/dev/null || echo "?")
        echo "   Posts: $posts_count"
    else
        echo "📝 txt Blogger:       🔴 STOPPED"
    fi
    
    # Gemini Server
    if podman ps --format "{{.Names}}" | grep -q "^$GEMINI_CONTAINER$"; then
        echo "💎 Gemini Server:     🟢 RUNNING (gemini://localhost:1965)"
        if openssl s_client -connect 127.0.0.1:1965 -quiet < /dev/null >/dev/null 2>&1; then
            echo "   TLS Status: ✅ WORKING"
        else
            echo "   TLS Status: ❌ ERROR"
        fi
    else
        echo "💎 Gemini Server:     🔴 STOPPED"
    fi
    
    # Gopher Server
    if podman ps --format "{{.Names}}" | grep -q "^$GOPHER_CONTAINER$"; then
        echo "🐹 Gopher Server:     🟢 RUNNING (gopher://localhost:70)"
        if nc -z 127.0.0.1 70 2>/dev/null; then
            echo "   Status: ✅ ACCESSIBLE"
        else
            echo "   Status: ❌ NOT ACCESSIBLE"
        fi
    else
        echo "🐹 Gopher Server:     🔴 STOPPED"
    fi
    
    # OpenSnitch
    if podman ps --format "{{.Names}}" | grep -q "^$OPENSNITCH_CONTAINER$"; then
        echo "🛡️ OpenSnitch:        🟢 RUNNING"
        local blocked_count=$(curl -s http://127.0.0.1:50052/stats 2>/dev/null | jq '.blocked' 2>/dev/null || echo "?")
        echo "   Blocked: $blocked_count connections"
    else
        echo "🛡️ OpenSnitch:        🔴 STOPPED"
    fi
    
    # Protocol Gateway
    if podman ps --format "{{.Names}}" | grep -q "^$PROTOCOL_GATEWAY_CONTAINER$"; then
        echo "🌐 Protocol Gateway:  🟢 RUNNING (http://localhost:8093)"
    else
        echo "🌐 Protocol Gateway:  🔴 STOPPED"
    fi
}

# Start txt blogger
start_txt_blogger() {
    echo "📝 Starting NeXuS txt Blogger..."
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$TXT_CONTAINER$"; then
        echo "⚠️  Stopping existing txt blogger..."
        podman stop "$TXT_CONTAINER" && podman rm "$TXT_CONTAINER"
    fi
    
    # Build and start txt blogger
    cd "$CONFIG_DIR"
    if podman build -f Dockerfile.txt -t nexus/txt-blogger .; then
        podman run -d \
            --name "$TXT_CONTAINER" \
            --publish "127.0.0.1:8091:8080" \
            --volume nexus-txt-posts:/var/txt/posts \
            --volume nexus-txt-static:/var/txt/static \
            --restart unless-stopped \
            --security-opt no-new-privileges \
            nexus/txt-blogger
        
        echo "✅ txt Blogger started"
        echo "📝 Web interface: http://localhost:8091"
        echo "💎 Gemini format: http://localhost:8091/gemini"
        echo "🐹 Gopher format: http://localhost:8091/gopher"
        
        # Wait and test
        sleep 3
        if curl -s http://127.0.0.1:8091/ >/dev/null; then
            echo "✅ txt Blogger is responding"
        else
            echo "⚠️  txt Blogger may still be starting..."
        fi
    else
        echo "❌ Failed to build txt blogger"
        return 1
    fi
}

# Start Gemini server
start_gemini() {
    echo "💎 Starting NeXuS Gemini Server..."
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$GEMINI_CONTAINER$"; then
        echo "⚠️  Stopping existing Gemini server..."
        podman stop "$GEMINI_CONTAINER" && podman rm "$GEMINI_CONTAINER"
    fi
    
    # Build and start Gemini server
    cd "$CONFIG_DIR"
    if podman build -f Dockerfile.gemini -t nexus/gemini .; then
        podman run -d \
            --name "$GEMINI_CONTAINER" \
            --publish "127.0.0.1:1965:1965" \
            --volume nexus-gemini-content:/var/gemini/content \
            --volume nexus-gemini-certs:/etc/ssl/gemini \
            --restart unless-stopped \
            --security-opt no-new-privileges \
            nexus/gemini
        
        echo "✅ Gemini server started"
        echo "💎 Access: gemini://localhost:1965"
        echo "🔒 TLS certificate auto-generated"
        
        # Wait and test TLS
        sleep 3
        if openssl s_client -connect 127.0.0.1:1965 -quiet < /dev/null >/dev/null 2>&1; then
            echo "✅ Gemini TLS is working"
        else
            echo "⚠️  Gemini server may still be starting..."
        fi
    else
        echo "❌ Failed to build Gemini server"
        return 1
    fi
}

# Start OpenSnitch
start_opensnitch() {
    echo "🛡️ Starting NeXuS OpenSnitch Application Firewall..."
    
    # Check if we have proper privileges
    if [[ $EUID -ne 0 ]]; then
        echo "❌ OpenSnitch requires root privileges for iptables"
        echo "   Run with doas/sudo or in privileged container"
        return 1
    fi
    
    # Stop existing if running
    if podman ps --format "{{.Names}}" | grep -q "^$OPENSNITCH_CONTAINER$"; then
        echo "⚠️  Stopping existing OpenSnitch..."
        podman stop "$OPENSNITCH_CONTAINER" && podman rm "$OPENSNITCH_CONTAINER"
    fi
    
    # Build and start OpenSnitch
    cd "$CONFIG_DIR"
    if podman build -f Dockerfile.opensnitch -t nexus/opensnitch .; then
        podman run -d \
            --name "$OPENSNITCH_CONTAINER" \
            --publish "127.0.0.1:50051:50051" \
            --publish "127.0.0.1:50052:50052" \
            --volume nexus-opensnitch-rules:/etc/opensnitchd/rules \
            --volume nexus-opensnitch-logs:/var/log/opensnitchd \
            --cap-add NET_ADMIN \
            --cap-add NET_RAW \
            --privileged \
            --restart unless-stopped \
            nexus/opensnitch
        
        echo "✅ OpenSnitch started"
        echo "🛡️ Application firewall active"
        echo "📊 Stats API: http://localhost:50052"
        echo "🔧 gRPC API: localhost:50051"
        
        # Wait and test
        sleep 5
        if nc -z 127.0.0.1 50051 2>/dev/null; then
            echo "✅ OpenSnitch API is responding"
        else
            echo "⚠️  OpenSnitch may still be starting..."
        fi
    else
        echo "❌ Failed to build OpenSnitch"
        return 1
    fi
}

# Start all alternative protocol services
start_all() {
    echo "🚀 Starting all NeXuS Alternative Protocol services..."
    
    start_txt_blogger
    echo ""
    start_gemini
    echo ""
    start_opensnitch
    echo ""
    
    echo "✅ All alternative protocol services started"
    echo ""
    get_alt_protocols_status
}

# Stop services
stop_service() {
    local service="$1"
    
    case "$service" in
        "txt"|"txt-blogger")
            echo "🛑 Stopping txt Blogger..."
            if podman ps --format "{{.Names}}" | grep -q "^$TXT_CONTAINER$"; then
                podman stop "$TXT_CONTAINER" && podman rm "$TXT_CONTAINER"
                echo "✅ txt Blogger stopped"
            else
                echo "⚠️  txt Blogger not running"
            fi
            ;;
        "gemini")
            echo "🛑 Stopping Gemini server..."
            if podman ps --format "{{.Names}}" | grep -q "^$GEMINI_CONTAINER$"; then
                podman stop "$GEMINI_CONTAINER" && podman rm "$GEMINI_CONTAINER"
                echo "✅ Gemini server stopped"
            else
                echo "⚠️  Gemini server not running"
            fi
            ;;
        "gopher")
            echo "🛑 Stopping Gopher server..."
            if podman ps --format "{{.Names}}" | grep -q "^$GOPHER_CONTAINER$"; then
                podman stop "$GOPHER_CONTAINER" && podman rm "$GOPHER_CONTAINER"
                echo "✅ Gopher server stopped"
            else
                echo "⚠️  Gopher server not running"
            fi
            ;;
        "opensnitch")
            echo "🛑 Stopping OpenSnitch..."
            if podman ps --format "{{.Names}}" | grep -q "^$OPENSNITCH_CONTAINER$"; then
                podman stop "$OPENSNITCH_CONTAINER" && podman rm "$OPENSNITCH_CONTAINER"
                echo "✅ OpenSnitch stopped"
            else
                echo "⚠️  OpenSnitch not running"
            fi
            ;;
        "all")
            stop_service "txt"
            stop_service "gemini" 
            stop_service "gopher"
            stop_service "opensnitch"
            ;;
        *)
            echo "❌ Unknown service: $service"
            echo "Available: txt, gemini, gopher, opensnitch, all"
            ;;
    esac
}

# Test alternative protocols
test_protocols() {
    echo "🧪 Testing NeXuS Alternative Protocols..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Test txt Blogger
    echo "📝 Testing txt Blogger..."
    if curl -s http://127.0.0.1:8091/ >/dev/null; then
        echo "✅ txt Blogger HTTP: WORKING"
        
        # Test API
        if curl -s http://127.0.0.1:8091/api/posts >/dev/null; then
            echo "✅ txt Blogger API: WORKING"
        else
            echo "❌ txt Blogger API: FAILED"
        fi
        
        # Test Gemini format
        if curl -s http://127.0.0.1:8091/gemini >/dev/null; then
            echo "✅ txt Gemini format: WORKING"
        else
            echo "❌ txt Gemini format: FAILED"
        fi
        
    else
        echo "❌ txt Blogger: NOT ACCESSIBLE"
    fi
    
    echo ""
    
    # Test Gemini
    echo "💎 Testing Gemini server..."
    if openssl s_client -connect 127.0.0.1:1965 -quiet < /dev/null >/dev/null 2>&1; then
        echo "✅ Gemini TLS: WORKING"
    else
        echo "❌ Gemini TLS: FAILED"
    fi
    
    echo ""
    
    # Test OpenSnitch
    echo "🛡️ Testing OpenSnitch..."
    if nc -z 127.0.0.1 50051 2>/dev/null; then
        echo "✅ OpenSnitch gRPC: WORKING"
    else
        echo "❌ OpenSnitch gRPC: FAILED"
    fi
    
    if nc -z 127.0.0.1 50052 2>/dev/null; then
        echo "✅ OpenSnitch Stats: WORKING"
    else
        echo "❌ OpenSnitch Stats: FAILED"
    fi
}

# Create new blog post
create_post() {
    local title="$1"
    local content="$2"
    local author="${3:-Anonymous}"
    
    echo "✍️ Creating new blog post: $title"
    
    local post_data=$(cat <<EOF
{
    "title": "$title",
    "content": "$content", 
    "author": "$author",
    "tags": ["nexus", "blog"]
}
EOF
)
    
    if curl -s -X POST -H "Content-Type: application/json" \
        -d "$post_data" http://127.0.0.1:8091/api/posts >/dev/null; then
        echo "✅ Blog post created successfully"
        echo "📝 View at: http://localhost:8091"
    else
        echo "❌ Failed to create blog post"
        return 1
    fi
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        get_alt_protocols_status
        echo ""
        echo "🎮 NeXuS Alternative Protocols Menu:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 📝 Start txt Blogger"
        echo "2) 💎 Start Gemini Server"
        echo "3) 🛡️ Start OpenSnitch"
        echo "4) 🚀 Start All Services"
        echo "5) 🛑 Stop Service"
        echo "6) 🧪 Test Protocols"
        echo "7) ✍️ Create Blog Post"
        echo "8) 🌐 Open Interfaces"
        echo "9) 📊 Refresh Status"
        echo "0) 🚪 Exit"
        echo ""
        read -p "Select option (0-9): " choice
        
        case "$choice" in
            1)
                start_txt_blogger
                read -p "Press Enter to continue..."
                ;;
            2)
                start_gemini
                read -p "Press Enter to continue..."
                ;;
            3)
                start_opensnitch
                read -p "Press Enter to continue..."
                ;;
            4)
                start_all
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Available services: txt, gemini, gopher, opensnitch, all"
                read -p "Service to stop: " service
                stop_service "$service"
                read -p "Press Enter to continue..."
                ;;
            6)
                test_protocols
                read -p "Press Enter to continue..."
                ;;
            7)
                read -p "Post title: " title
                read -p "Post content: " content
                read -p "Author (optional): " author
                create_post "$title" "$content" "${author:-Anonymous}"
                read -p "Press Enter to continue..."
                ;;
            8)
                echo "🌐 NeXuS Alternative Protocol Interfaces:"
                echo "📝 txt Blogger: http://localhost:8091"
                echo "💎 Gemini: gemini://localhost:1965"
                echo "🐹 Gopher: gopher://localhost:70"
                echo "🛡️ OpenSnitch Stats: http://localhost:50052"
                read -p "Press Enter to continue..."
                ;;
            9)
                # Just refresh (loop will show updated status)
                ;;
            0)
                echo "👋 Exiting NeXuS Alternative Protocols Manager"
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
            case "${2:-all}" in
                "txt"|"txt-blogger")
                    start_txt_blogger
                    ;;
                "gemini")
                    start_gemini
                    ;;
                "opensnitch")
                    start_opensnitch
                    ;;
                "all")
                    start_all
                    ;;
                *)
                    echo "Usage: $0 start {txt|gemini|opensnitch|all}"
                    ;;
            esac
            ;;
        "stop")
            stop_service "${2:-all}"
            ;;
        "status")
            get_alt_protocols_status
            ;;
        "test")
            test_protocols
            ;;
        "post")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 post 'title' 'content' [author]"
                exit 1
            fi
            create_post "$2" "$3" "${4:-Anonymous}"
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS Alternative Protocols Manager"
            echo ""
            echo "Usage: $0 {start|stop|status|test|post|menu|help}"
            echo ""
            echo "Commands:"
            echo "  start {txt|gemini|opensnitch|all} - Start services"
            echo "  stop {txt|gemini|opensnitch|all}  - Stop services"
            echo "  status                             - Show service status"
            echo "  test                               - Test all protocols"
            echo "  post 'title' 'content' [author]   - Create blog post"
            echo "  menu                               - Interactive menu"
            echo "  help                               - Show this help"
            echo ""
            echo "Services:"
            echo "  📝 txt Blogger: Simple markdown blogging"
            echo "  💎 Gemini: Privacy-focused protocol"
            echo "  🐹 Gopher: Minimal text protocol"
            echo "  🛡️ OpenSnitch: Application firewall"
            echo ""
            echo "Interfaces:"
            echo "  txt:       http://localhost:8091"
            echo "  Gemini:    gemini://localhost:1965"
            echo "  Gopher:    gopher://localhost:70"
            echo "  OpenSnitch: http://localhost:50052"
            ;;
    esac
}

# Execute main function
main "$@"