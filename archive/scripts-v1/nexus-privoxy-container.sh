#!/bin/bash
# NeXuS Privoxy Container Management Script
# Secure proxy with multi-network support for API access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"
CONTAINER_NAME="nexus-privoxy"
IMAGE_NAME="nexus/privoxy"
PROXY_PORT="8118"

# NeXuS Fire ASCII Art
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Privoxy Container Manager 🔥"
    echo "Multi-Network Secure Proxy with CORS & uBlock Filters"
    echo -e "\e[0m"
}

# Build the container image
build_image() {
    echo "🔨 Building NeXuS Privoxy image..."
    cd "$CONFIG_DIR"
    podman build -f Dockerfile.privoxy-nexus -t "$IMAGE_NAME" .
    echo "✅ Image built successfully!"
}

# Start the container
start_container() {
    echo "🚀 Starting NeXuS Privoxy container..."
    
    # Stop existing container if running
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "⚠️  Stopping existing container..."
        podman stop "$CONTAINER_NAME" 2>/dev/null || true
        podman rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Start new container
    podman run -d \
        --name "$CONTAINER_NAME" \
        --publish "127.0.0.1:${PROXY_PORT}:8118" \
        --restart unless-stopped \
        --security-opt no-new-privileges \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        --tmpfs /var/log/privoxy:rw,noexec,nosuid,size=50m \
        "$IMAGE_NAME"
    
    echo "✅ Container started on localhost:${PROXY_PORT}"
}

# Stop the container
stop_container() {
    echo "🛑 Stopping NeXuS Privoxy container..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || echo "Container not running"
    podman rm "$CONTAINER_NAME" 2>/dev/null || echo "Container not found"
    echo "✅ Container stopped"
}

# Show container status
status() {
    echo "📊 NeXuS Privoxy Status:"
    if podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "🟢 Container: RUNNING"
        echo "🌐 Proxy: http://localhost:${PROXY_PORT}"
        echo "📈 Stats:"
        podman stats --no-stream "$CONTAINER_NAME" | tail -n 1
    else
        echo "🔴 Container: STOPPED"
    fi
}

# Test the proxy
test_proxy() {
    echo "🧪 Testing NeXuS Privoxy..."
    
    if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ Container not running. Start it first."
        return 1
    fi
    
    echo "Testing basic connectivity..."
    if curl -s --proxy "localhost:${PROXY_PORT}" -I http://httpbin.org/ip | grep -q "HTTP/1.1 200"; then
        echo "✅ Basic proxy: WORKING"
    else
        echo "❌ Basic proxy: FAILED"
        return 1
    fi
    
    echo "Testing CORS headers..."
    CORS_TEST=$(curl -s --proxy "localhost:${PROXY_PORT}" -H "Origin: http://localhost:3000" -I http://httpbin.org/ip | grep -i "access-control-allow" || echo "")
    if [[ -n "$CORS_TEST" ]]; then
        echo "✅ CORS headers: WORKING"
    else
        echo "⚠️  CORS headers: Not detected (may still work for APIs)"
    fi
    
    echo "🎯 Proxy ready for API access!"
}

# Show logs
logs() {
    echo "📋 NeXuS Privoxy Logs:"
    podman logs --tail 50 -f "$CONTAINER_NAME"
}

# Show configuration for apps
show_config() {
    echo "⚙️  NeXuS Privoxy Configuration:"
    echo ""
    echo "🌐 Proxy URL: http://localhost:${PROXY_PORT}"
    echo ""
    echo "📝 For zombie apocalypse app, use these settings:"
    echo "   Story Provider: Custom"
    echo "   API URL: http://localhost:${PROXY_PORT}/https://api.mistral.ai/v1/chat/completions"
    echo "   API Key: your_mistral_key"
    echo ""
    echo "🔒 Supported networks:"
    echo "   • Clearnet (direct)"
    echo "   • Tor (via SOCKS5)"
    echo "   • I2P (via HTTP proxy)"
    echo "   • IPFS/Yggdrasil/Reticulum (when configured)"
    echo ""
    echo "🛡️  Privacy features:"
    echo "   • uBlock Origin filters"
    echo "   • Tracker blocking"
    echo "   • CORS headers for API access"
    echo "   • Anonymous user agent"
}

# Main command dispatcher
main() {
    show_banner
    
    case "${1:-help}" in
        "build")
            build_image
            ;;
        "start")
            build_image
            start_container
            test_proxy
            show_config
            ;;
        "stop")
            stop_container
            ;;
        "restart")
            stop_container
            sleep 2
            build_image
            start_container
            test_proxy
            ;;
        "status")
            status
            ;;
        "test")
            test_proxy
            ;;
        "logs")
            logs
            ;;
        "config")
            show_config
            ;;
        "help"|*)
            echo "🔥 NeXuS Privoxy Container Manager"
            echo ""
            echo "Usage: $0 {build|start|stop|restart|status|test|logs|config}"
            echo ""
            echo "Commands:"
            echo "  build    - Build the container image"
            echo "  start    - Build and start the container"
            echo "  stop     - Stop and remove the container"
            echo "  restart  - Restart the container"
            echo "  status   - Show container status"
            echo "  test     - Test proxy functionality"
            echo "  logs     - Show container logs"
            echo "  config   - Show proxy configuration info"
            echo ""
            echo "🌐 Access: http://localhost:${PROXY_PORT}"
            ;;
    esac
}

# Execute main function
main "$@"