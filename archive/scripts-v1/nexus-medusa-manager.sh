#!/bin/bash
# NeXuS Medusa Manager
# Control multi-head Tor proxy with HAProxy load balancing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs/nexus-stack"
MEDUSA_CONTAINER="nexus-medusa"
PRIVOXY_ENHANCED_CONTAINER="nexus-privoxy-enhanced"

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Medusa Multi-Head Manager 🔥"
    echo "HAProxy • Multi-Tor • Privoxy • Supervisor • Load Balancing"
    echo -e "\e[0m"
}

# Get Medusa status
get_medusa_status() {
    echo "📊 NeXuS Medusa Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if podman ps --format "{{.Names}}" | grep -q "^$MEDUSA_CONTAINER$"; then
        echo "🐙 Medusa Container:   🟢 RUNNING"
        
        # Get HAProxy stats
        echo ""
        echo "⚖️  HAProxy Load Balancer Status:"
        local haproxy_stats=$(curl -s http://127.0.0.1:8404/stats/;csv 2>/dev/null || echo "Stats unavailable")
        if [[ "$haproxy_stats" != "Stats unavailable" ]]; then
            echo "$haproxy_stats" | grep -E "(tor-head|socks-head)" | while IFS=',' read -r pxname svname qcur qmax scur smax slim stot bin bout dreq dresp ereq econ eresp wretr wredis status; do
                echo "   $svname: $status"
            done
        else
            echo "   HAProxy stats not available"
        fi
        
        # Get Supervisor status
        echo ""
        echo "👁️  Supervisor Services:"
        local supervisor_status=$(curl -s http://127.0.0.1:9001/RPC2 2>/dev/null || echo "Supervisor unavailable")
        if [[ "$supervisor_status" != "Supervisor unavailable" ]]; then
            echo "   Supervisor web interface: http://127.0.0.1:9001"
        else
            echo "   Supervisor not accessible"
        fi
        
        # Test proxy endpoints
        echo ""
        echo "🔗 Proxy Endpoints:"
        for port in 8881 8882 8883 8884 8885 8886 8887; do
            if nc -z 127.0.0.1 $port 2>/dev/null; then
                echo "   Port $port: 🟢 ACTIVE"
            else
                echo "   Port $port: 🔴 INACTIVE"
            fi
        done
        
    else
        echo "🐙 Medusa Container:   🔴 STOPPED"
    fi
    
    # Enhanced Privoxy status
    if podman ps --format "{{.Names}}" | grep -q "^$PRIVOXY_ENHANCED_CONTAINER$"; then
        echo ""
        echo "🕵️  Enhanced Privoxy:   🟢 RUNNING"
        echo "   Main interface: http://127.0.0.1:8118"
        echo "   API interface: http://127.0.0.1:8119"
    else
        echo ""
        echo "🕵️  Enhanced Privoxy:   🔴 STOPPED"
    fi
}

# Start Medusa stack
start_medusa() {
    echo "🚀 Starting NeXuS Medusa Multi-Head Stack..."
    
    # Check if Medusa image exists
    if ! podman images | grep -q "medusa"; then
        echo "❌ Medusa image not found. Please build or pull the Medusa container first."
        echo "   The Medusa container should include:"
        echo "   - Multiple Tor instances"
        echo "   - HAProxy load balancer"
        echo "   - Privoxy filtering"
        echo "   - Supervisor process management"
        return 1
    fi
    
    # Start using docker-compose
    cd "$CONFIG_DIR"
    if podman-compose -f medusa-integration.yml up -d; then
        echo "✅ Medusa stack started successfully"
        
        # Wait for services to initialize
        echo "⏳ Waiting for services to initialize..."
        sleep 10
        
        # Test endpoints
        test_medusa_connectivity
        
    else
        echo "❌ Failed to start Medusa stack"
        return 1
    fi
}

# Stop Medusa stack
stop_medusa() {
    echo "🛑 Stopping NeXuS Medusa Stack..."
    
    cd "$CONFIG_DIR"
    if podman-compose -f medusa-integration.yml down; then
        echo "✅ Medusa stack stopped successfully"
    else
        echo "❌ Failed to stop Medusa stack"
        return 1
    fi
}

# Test Medusa connectivity
test_medusa_connectivity() {
    echo "🧪 Testing NeXuS Medusa Connectivity..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Test HAProxy stats
    echo "📊 Testing HAProxy stats interface..."
    if curl -s http://127.0.0.1:8404/stats >/dev/null; then
        echo "✅ HAProxy stats: ACCESSIBLE"
    else
        echo "❌ HAProxy stats: FAILED"
    fi
    
    # Test HTTP proxy endpoints
    echo ""
    echo "🌐 Testing HTTP proxy endpoints..."
    for port in 8881 8882 8883; do
        echo -n "   Testing port $port: "
        if curl -s --proxy "127.0.0.1:$port" --max-time 10 http://httpbin.org/ip >/dev/null 2>&1; then
            echo "✅ WORKING"
        else
            echo "❌ FAILED"
        fi
    done
    
    # Test SOCKS5 proxy endpoints
    echo ""
    echo "🧦 Testing SOCKS5 proxy endpoints..."
    for port in 8884 8885 8886; do
        echo -n "   Testing port $port: "
        if curl -s --socks5 "127.0.0.1:$port" --max-time 10 http://httpbin.org/ip >/dev/null 2>&1; then
            echo "✅ WORKING"
        else
            echo "❌ FAILED"
        fi
    done
    
    # Test high-bandwidth endpoint
    echo ""
    echo "⚡ Testing high-bandwidth endpoint..."
    echo -n "   Testing port 8887: "
    if curl -s --socks5 "127.0.0.1:8887" --max-time 10 http://httpbin.org/ip >/dev/null 2>&1; then
        echo "✅ WORKING"
    else
        echo "❌ FAILED"
    fi
    
    # Test enhanced Privoxy
    echo ""
    echo "🕵️  Testing Enhanced Privoxy..."
    for port in 8118 8119; do
        echo -n "   Testing Privoxy port $port: "
        if curl -s --proxy "127.0.0.1:$port" --max-time 10 http://httpbin.org/ip >/dev/null 2>&1; then
            echo "✅ WORKING"
        else
            echo "❌ FAILED"
        fi
    done
}

# Get HAProxy detailed stats
get_haproxy_stats() {
    echo "📊 NeXuS Medusa HAProxy Detailed Statistics:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! nc -z 127.0.0.1 8404 2>/dev/null; then
        echo "❌ HAProxy stats interface not accessible"
        return 1
    fi
    
    # Get CSV stats and format nicely
    local stats=$(curl -s "http://127.0.0.1:8404/stats/;csv" 2>/dev/null)
    if [[ -n "$stats" ]]; then
        echo "Backend Health Status:"
        echo "$stats" | grep -E "(tor-head|socks-head)" | while IFS=',' read -r pxname svname qcur qmax scur smax slim stot bin bout dreq dresp ereq econ eresp wretr wredis status weight act bck; do
            local health_icon="❌"
            [[ "$status" == "UP" ]] && health_icon="✅"
            echo "   $health_icon $svname ($pxname): $status - Sessions: $scur/$smax, Total: $stot"
        done
        
        echo ""
        echo "Load Balancer Summary:"
        echo "$stats" | grep -E "(http_proxy_lb|socks_proxy_lb)" | while IFS=',' read -r pxname svname qcur qmax scur smax slim stot bin bout rest; do
            echo "   📊 $pxname: Active Sessions: $scur, Total Served: $stot"
        done
    else
        echo "❌ Unable to retrieve HAProxy statistics"
    fi
}

# Restart specific Tor head
restart_tor_head() {
    local head_number="$1"
    
    if [[ -z "$head_number" ]] || [[ ! "$head_number" =~ ^[1-6]$ ]]; then
        echo "❌ Invalid head number. Use 1-6."
        return 1
    fi
    
    echo "🔄 Restarting Tor head $head_number..."
    
    # Execute restart command in Medusa container
    if podman exec "$MEDUSA_CONTAINER" supervisorctl restart "tor-head-$head_number" 2>/dev/null; then
        echo "✅ Tor head $head_number restarted successfully"
        
        # Wait and test
        sleep 5
        local port=$((8100 + head_number))
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "✅ Tor head $head_number is responding on port $port"
        else
            echo "⚠️  Tor head $head_number may still be starting..."
        fi
    else
        echo "❌ Failed to restart Tor head $head_number"
        return 1
    fi
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        get_medusa_status
        echo ""
        echo "🎮 NeXuS Medusa Management Menu:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 🚀 Start Medusa Stack"
        echo "2) 🛑 Stop Medusa Stack"
        echo "3) 🔄 Restart Medusa Stack"
        echo "4) 🧪 Test Connectivity"
        echo "5) 📊 HAProxy Statistics"
        echo "6) 🔄 Restart Tor Head"
        echo "7) 🌐 Open Interfaces"
        echo "8) 📋 View Logs"
        echo "9) 📊 Refresh Status"
        echo "0) 🚪 Exit"
        echo ""
        read -p "Select option (0-9): " choice
        
        case "$choice" in
            1)
                start_medusa
                read -p "Press Enter to continue..."
                ;;
            2)
                stop_medusa
                read -p "Press Enter to continue..."
                ;;
            3)
                stop_medusa
                sleep 3
                start_medusa
                read -p "Press Enter to continue..."
                ;;
            4)
                test_medusa_connectivity
                read -p "Press Enter to continue..."
                ;;
            5)
                get_haproxy_stats
                read -p "Press Enter to continue..."
                ;;
            6)
                read -p "Enter Tor head number (1-6): " head_num
                restart_tor_head "$head_num"
                read -p "Press Enter to continue..."
                ;;
            7)
                echo "🌐 Opening NeXuS Medusa Interfaces:"
                echo "📊 HAProxy Stats: http://127.0.0.1:8404/stats"
                echo "👁️  Supervisor: http://127.0.0.1:9001"
                echo "🕵️  Privoxy Config: http://127.0.0.1:8118/show-status"
                read -p "Press Enter to continue..."
                ;;
            8)
                echo "Available logs: medusa, privoxy-enhanced, haproxy"
                read -p "Which logs to view: " log_choice
                case "$log_choice" in
                    "medusa")
                        podman logs --tail 50 "$MEDUSA_CONTAINER"
                        ;;
                    "privoxy-enhanced")
                        podman logs --tail 50 "$PRIVOXY_ENHANCED_CONTAINER"
                        ;;
                    *)
                        echo "Invalid log choice"
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            9)
                # Just refresh (loop will show updated status)
                ;;
            0)
                echo "👋 Exiting NeXuS Medusa Manager"
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
            start_medusa
            ;;
        "stop")
            stop_medusa
            ;;
        "restart")
            stop_medusa
            sleep 3
            start_medusa
            ;;
        "status")
            get_medusa_status
            ;;
        "test")
            test_medusa_connectivity
            ;;
        "stats")
            get_haproxy_stats
            ;;
        "restart-head")
            restart_tor_head "${2:-1}"
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS Medusa Multi-Head Manager"
            echo ""
            echo "Usage: $0 {start|stop|restart|status|test|stats|restart-head|menu|help}"
            echo ""
            echo "Commands:"
            echo "  start              - Start Medusa multi-head stack"
            echo "  stop               - Stop Medusa stack"
            echo "  restart            - Restart entire stack"
            echo "  status             - Show detailed status"
            echo "  test               - Test all proxy endpoints"
            echo "  stats              - Show HAProxy statistics"
            echo "  restart-head <num> - Restart specific Tor head (1-6)"
            echo "  menu               - Interactive management interface"
            echo "  help               - Show this help"
            echo ""
            echo "Proxy Endpoints:"
            echo "  HTTP:  8881, 8882, 8883"
            echo "  SOCKS: 8884, 8885, 8886"
            echo "  High-BW: 8887"
            echo "  Enhanced Privoxy: 8118, 8119"
            echo ""
            echo "Management Interfaces:"
            echo "  HAProxy Stats: http://127.0.0.1:8404/stats"
            echo "  Supervisor: http://127.0.0.1:9001"
            ;;
    esac
}

# Execute main function
main "$@"