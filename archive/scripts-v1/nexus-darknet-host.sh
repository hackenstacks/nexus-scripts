#!/bin/bash
# NeXuS Darknet Host Manager
# Manage your Tor hidden service, I2P eepsite, and IPFS hosting

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

HOSTING_DIR="/home/user/.nexus-security/hydra/hosting"
CONTENT_DIR="$HOSTING_DIR/content/nexus-node"
TORRC="$HOSTING_DIR/torrc-hidden-service"
ONION_FILE="$HOSTING_DIR/tor/nexus-node/hostname"

print_status() { echo -e "${CYAN}📊 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

show_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}          🧅 NeXuS DARKNET HOST MANAGER 🧅              ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}      Tor Hidden Services • I2P • IPFS Hosting          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

start_hosting() {
    show_banner
    print_status "Starting darknet hosting services..."

    # Start HTTP server if not running
    if ! pgrep -f "python3 -m http.server 8080" > /dev/null; then
        cd "$CONTENT_DIR"
        nohup python3 -m http.server 8080 > /tmp/darknet-server.log 2>&1 &
        print_success "HTTP server started on port 8080"
    else
        print_success "HTTP server already running"
    fi

    # Start Tor hidden service if not running
    if ! pgrep -f "$TORRC" > /dev/null; then
        nohup tor -f "$TORRC" > /tmp/tor-hidden-service.log 2>&1 &
        print_status "Waiting for Tor to bootstrap..."
        for i in {1..30}; do
            if [ -f "$ONION_FILE" ]; then
                break
            fi
            sleep 2
        done
        print_success "Tor hidden service started"
    else
        print_success "Tor hidden service already running"
    fi

    echo
    show_status
}

stop_hosting() {
    show_banner
    print_status "Stopping darknet hosting services..."

    # Stop HTTP server
    pkill -f "python3 -m http.server 8080" 2>/dev/null && print_success "HTTP server stopped" || print_warning "HTTP server not running"

    # Stop Tor hidden service
    pkill -f "$TORRC" 2>/dev/null && print_success "Tor hidden service stopped" || print_warning "Tor hidden service not running"
}

show_status() {
    show_banner

    echo -e "${BOLD}🧅 TOR HIDDEN SERVICE${NC}"
    if pgrep -f "$TORRC" > /dev/null; then
        echo -e "   Status:  ${GREEN}ACTIVE ✅${NC}"
        if [ -f "$ONION_FILE" ]; then
            echo -e "   Address: ${CYAN}$(cat "$ONION_FILE")${NC}"
        fi
    else
        echo -e "   Status:  ${YELLOW}STOPPED${NC}"
    fi
    echo

    echo -e "${BOLD}🌐 HTTP SERVER${NC}"
    if pgrep -f "python3 -m http.server 8080" > /dev/null; then
        echo -e "   Status:  ${GREEN}ACTIVE ✅${NC}"
        echo -e "   Port:    ${CYAN}8080${NC}"
    else
        echo -e "   Status:  ${YELLOW}STOPPED${NC}"
    fi
    echo

    echo -e "${BOLD}📁 CONTENT DIRECTORY${NC}"
    echo -e "   Path: ${CYAN}$CONTENT_DIR${NC}"
    echo -e "   Files: $(ls -1 "$CONTENT_DIR" 2>/dev/null | wc -l) files"
    echo

    if [ -f "$ONION_FILE" ]; then
        echo -e "${BOLD}🔗 ACCESS YOUR SITE${NC}"
        echo -e "   Tor Browser: ${CYAN}http://$(cat "$ONION_FILE")${NC}"
        echo -e "   CLI:         ${CYAN}curl --socks5-hostname 127.0.0.1:1080 http://$(cat "$ONION_FILE")/${NC}"
    fi
}

add_file() {
    local file="$1"
    if [ -z "$file" ]; then
        print_error "Usage: $0 add <file>"
        return 1
    fi

    if [ -f "$file" ]; then
        cp "$file" "$CONTENT_DIR/"
        print_success "Added $(basename "$file") to darknet site"
    else
        print_error "File not found: $file"
        return 1
    fi
}

case "${1:-status}" in
    "start")
        start_hosting
        ;;
    "stop")
        stop_hosting
        ;;
    "restart")
        stop_hosting
        sleep 2
        start_hosting
        ;;
    "status")
        show_status
        ;;
    "add")
        shift
        add_file "$1"
        ;;
    "edit")
        ${EDITOR:-nano} "$CONTENT_DIR/index.html"
        ;;
    "logs")
        echo "=== Tor Hidden Service Logs ==="
        tail -20 /tmp/tor-hidden-service.log 2>/dev/null
        echo
        echo "=== HTTP Server Logs ==="
        tail -20 /tmp/darknet-server.log 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|add <file>|edit|logs}"
        echo
        echo "Commands:"
        echo "  start   - Start darknet hosting services"
        echo "  stop    - Stop all hosting services"
        echo "  restart - Restart hosting services"
        echo "  status  - Show hosting status and .onion address"
        echo "  add     - Add a file to your darknet site"
        echo "  edit    - Edit the index.html page"
        echo "  logs    - View service logs"
        ;;
esac
