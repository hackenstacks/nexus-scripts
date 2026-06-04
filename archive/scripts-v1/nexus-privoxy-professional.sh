#!/bin/bash

# NeXuS Professional Privoxy Container with uBlock Origin Integration
# Uses Andrwe Lord Weber's proven privoxy-blocklist script
# Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!

set -e

# Fire aesthetics
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/home/user/.nexus-security/privoxy-professional"
CONTAINER_NAME="nexus-privoxy-professional"
PRIVOXY_SCRIPT_SOURCE="/home/user/Documents/scripts/privoxy-blacklist.sh"
PRIVOXY_PORT="${PRIVOXY_PORT:-8118}"

print_fire() {
    echo -e "${RED}🔥${YELLOW}🔥${WHITE}🔥${CYAN} $1 ${PURPLE}🔥${YELLOW}🔥${RED}🔥${NC}"
}

print_status() {
    echo -e "${BLUE}📊 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_event() {
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$CONFIG_DIR/privoxy-professional.log"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}    🛡️ NeXuS PROFESSIONAL PRIVOXY + uBLOCK ORIGIN      ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}    Andrwe Lord Weber Script • Container Security       ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}   Sane • Simple • Secure NeXuS - Together MORE!        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

setup_container_environment() {
    print_status "Setting up NeXuS Professional Privoxy container environment..."
    
    mkdir -p "$CONFIG_DIR"/{config,data,logs,scripts}
    
    # Copy and adapt the professional privoxy-blocklist script
    if [[ -f "$PRIVOXY_SCRIPT_SOURCE" ]]; then
        cp "$PRIVOXY_SCRIPT_SOURCE" "$CONFIG_DIR/scripts/privoxy-blocklist.sh"
        chmod +x "$CONFIG_DIR/scripts/privoxy-blocklist.sh"
        print_success "Professional privoxy-blocklist script copied"
    else
        print_error "Could not find privoxy-blocklist script at $PRIVOXY_SCRIPT_SOURCE"
        return 1
    fi
    
    # Create NeXuS-specific configuration
    cat > "$CONFIG_DIR/config/privoxy-blocklist.conf" << 'EOF'
# NeXuS Privoxy Professional Configuration
# Enhanced with multiple filter sources

# array of URL for AdblockPlus lists (NeXuS Enhanced)
URLS=(
    "https://easylist-downloads.adblockplus.org/easylist.txt"
    "https://easylist-downloads.adblockplus.org/easyprivacy.txt"
    "https://easylist-downloads.adblockplus.org/easylistgermany.txt"
    "https://easylist-downloads.adblockplus.org/fanboy-annoyance.txt"
    "https://easylist-downloads.adblockplus.org/fanboy-social.txt"
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt"
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt"
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt"
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt"
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt"
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt"
)

# Content filters for advanced blocking (warning: can slow down browsing)
FILTERS=(
    "class_global"
    "id_global"
    "attribute_global_name"
)

# Container-specific paths
PRIVOXY_USER="privoxy"
PRIVOXY_GROUP="privoxy"
PRIVOXY_CONF="/etc/privoxy/config"

# NeXuS script name for logging
TMPNAME="nexus-privoxy-professional"
TMPDIR="/tmp/nexus-privoxy-professional"

# Debug level (0=normal, 1=verbose, 2=more verbose)
DBG=1
EOF

    # Create enhanced Privoxy main config
    cat > "$CONFIG_DIR/config/privoxy.conf" << EOF
# NeXuS Professional Privoxy Configuration
# Enhanced for container security and performance

# Network configuration
listen-address 0.0.0.0:8118
listen-address [::]:8118

# Basic settings
toggle 1
enable-remote-toggle 0
enable-edit-actions 0
enable-remote-http-toggle 0
buffer-limit 4096

# Logging
logfile /var/log/privoxy/privoxy.log
logdir /var/log/privoxy
debug 1    # Log errors
debug 1024 # Log actions (comment out for production)

# Security
accept-intercepted-requests 1
enforce-blocks 1
handle-as-empty-returns-ok 1

# Directories
confdir /etc/privoxy
templdir /etc/privoxy/templates

# Action files (order matters!)
actionsfile match-all.action
actionsfile default.action
# Note: Blocklist script will add its action files here

# Filter files
filterfile default.filter
# Note: Blocklist script will add its filter files here

# Forward to Tor (optional - enable if part of Tor chain)
# forward-socks5t / tor-container:9050 .

# Performance tuning
compression-level 1
keep-alive-timeout 5
socket-timeout 300

# Privacy headers
hide-console-prompts 1
EOF

    # Create container startup script
    cat > "$CONFIG_DIR/scripts/start-container.sh" << EOF
#!/bin/bash

# NeXuS Professional Privoxy Container Startup
CONTAINER_NAME="$CONTAINER_NAME"
CONFIG_DIR="$CONFIG_DIR"

# Clean up existing container
podman rm -f "\$CONTAINER_NAME" 2>/dev/null || true

# Create data directories
mkdir -p "\$CONFIG_DIR"/data/{etc/privoxy,var/log/privoxy,tmp}

# Copy configuration
cp "\$CONFIG_DIR/config/privoxy.conf" "\$CONFIG_DIR/data/etc/privoxy/config"

# Set proper permissions
chmod 755 "\$CONFIG_DIR/data/etc/privoxy"
chmod 644 "\$CONFIG_DIR/data/etc/privoxy/config"

# Start container with security hardening
podman run -d \\
    --name "\$CONTAINER_NAME" \\
    --security-opt no-new-privileges \\
    --cap-drop ALL \\
    --cap-add NET_BIND_SERVICE \\
    --read-only \\
    --tmpfs /tmp \\
    --tmpfs /run \\
    --network bridge \\
    -p $PRIVOXY_PORT:8118 \\
    -v "\$CONFIG_DIR/data/etc/privoxy":/etc/privoxy:Z \\
    -v "\$CONFIG_DIR/data/var/log/privoxy":/var/log/privoxy:Z \\
    -v "\$CONFIG_DIR/data/tmp":/tmp/nexus-privoxy-professional:Z \\
    --restart unless-stopped \\
    --health-cmd="curl -f http://localhost:8118 || exit 1" \\
    --health-interval=30s \\
    --health-timeout=10s \\
    --health-retries=3 \\
    docker.io/vimagick/privoxy:latest

if [ \$? -eq 0 ]; then
    echo "✅ NeXuS Professional Privoxy container started: \$CONTAINER_NAME"
    echo "🌐 Proxy available at: http://127.0.0.1:$PRIVOXY_PORT"
else
    echo "❌ Failed to start container"
    exit 1
fi
EOF

    chmod +x "$CONFIG_DIR/scripts/start-container.sh"
    
    # Create filter update script that runs inside container
    cat > "$CONFIG_DIR/scripts/update-filters.sh" << 'EOF'
#!/bin/bash

# NeXuS Professional Filter Update Script
# Runs the professional privoxy-blocklist script inside container

CONTAINER_NAME="nexus-privoxy-professional"

echo "🔄 Updating NeXuS Professional Privoxy filters..."

# Check if container is running
if ! podman ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container not running. Start it first."
    exit 1
fi

# Copy scripts and config into container
podman cp /home/user/.nexus-security/privoxy-professional/scripts/privoxy-blocklist.sh "$CONTAINER_NAME":/tmp/
podman cp /home/user/.nexus-security/privoxy-professional/config/privoxy-blocklist.conf "$CONTAINER_NAME":/tmp/

# Install dependencies in container
podman exec "$CONTAINER_NAME" sh -c "
    apk add --no-cache bash wget grep sed curl || 
    apt-get update && apt-get install -y bash wget grep sed curl ||
    echo 'Dependencies might already be installed'
"

# Run the professional blocklist script inside container
podman exec "$CONTAINER_NAME" bash -c "
    chmod +x /tmp/privoxy-blocklist.sh
    SCRIPTCONF=/tmp/privoxy-blocklist.conf /tmp/privoxy-blocklist.sh -v 1
"

# Restart Privoxy to reload configuration
echo "🔄 Reloading Privoxy configuration..."
podman exec "$CONTAINER_NAME" pkill -HUP privoxy 2>/dev/null || 
podman restart "$CONTAINER_NAME"

echo "✅ Filter update completed"
EOF

    chmod +x "$CONFIG_DIR/scripts/update-filters.sh"
    
    print_success "Container environment setup complete"
}

start_professional_privoxy() {
    show_banner
    print_fire "Starting NeXuS Professional Privoxy System"
    echo
    
    if ! setup_container_environment; then
        print_error "Failed to setup container environment"
        return 1
    fi
    
    print_status "Starting Professional Privoxy container..."
    if "$CONFIG_DIR/scripts/start-container.sh"; then
        sleep 5
        
        # Wait for container to be fully ready
        print_status "Waiting for Privoxy to initialize..."
        local count=0
        while [ $count -lt 30 ]; do
            if curl -s --connect-timeout 2 http://127.0.0.1:$PRIVOXY_PORT >/dev/null 2>&1; then
                break
            fi
            sleep 2
            count=$((count + 1))
        done
        
        if [ $count -ge 30 ]; then
            print_warning "Container started but Privoxy may not be fully ready"
        else
            print_success "Privoxy container is ready"
        fi
        
        # Update filters
        print_status "Updating professional filter lists..."
        if "$CONFIG_DIR/scripts/update-filters.sh"; then
            print_success "Professional filter lists updated"
        else
            print_warning "Filter update had issues (container may need restart)"
        fi
        
        echo
        print_fire "NeXuS Professional Privoxy ACTIVE"
        echo -e "${GREEN}🛡️ Professional-grade ad/tracker blocking enabled${NC}"
        echo -e "${CYAN}🔒 Multiple filter sources active (EasyList, uBlock, Fanboy)${NC}"
        echo -e "${YELLOW}🌐 Proxy available at: http://127.0.0.1:$PRIVOXY_PORT${NC}"
        echo -e "${WHITE}🧪 Test: curl -x http://127.0.0.1:$PRIVOXY_PORT http://httpbin.org/ip${NC}"
        
        log_event "Professional Privoxy system started with filters"
    else
        print_error "Failed to start Professional Privoxy container"
        return 1
    fi
}

stop_professional_privoxy() {
    print_status "Stopping NeXuS Professional Privoxy..."
    
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
    print_success "Professional Privoxy container stopped"
    log_event "Professional Privoxy system stopped"
}

update_filters() {
    print_fire "Updating Professional Filter Lists"
    echo
    
    if ! podman ps | grep -q "$CONTAINER_NAME"; then
        print_error "Container not running. Start it first with: $0 start"
        return 1
    fi
    
    if "$CONFIG_DIR/scripts/update-filters.sh"; then
        print_success "Professional filter lists updated successfully"
        log_event "Filter lists updated"
    else
        print_error "Failed to update filter lists"
        return 1
    fi
}

show_status() {
    show_banner
    print_fire "NeXuS Professional Privoxy Status"
    echo
    
    # Container status
    if podman ps | grep -q "$CONTAINER_NAME"; then
        print_success "Container Status: RUNNING"
        local container_id=$(podman ps | grep "$CONTAINER_NAME" | awk '{print $1}')
        echo -e "${CYAN}   Container ID: $container_id${NC}"
        
        # Health check
        local health=$(podman inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            print_success "Health Status: HEALTHY"
        elif [[ "$health" == "unhealthy" ]]; then
            print_error "Health Status: UNHEALTHY"
        else
            print_warning "Health Status: $health"
        fi
        
        # Resource usage
        local stats=$(podman stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}} {{.MemUsage}}" | tail -1)
        echo -e "${CYAN}   Resource Usage: $stats${NC}"
    else
        print_warning "Container Status: NOT RUNNING"
    fi
    
    # Proxy accessibility
    if curl -s --connect-timeout 2 http://127.0.0.1:$PRIVOXY_PORT >/dev/null 2>&1; then
        print_success "Proxy Port $PRIVOXY_PORT: ACCESSIBLE"
    else
        print_warning "Proxy Port $PRIVOXY_PORT: NOT ACCESSIBLE"
    fi
    
    # Check filter files in container
    if podman ps | grep -q "$CONTAINER_NAME"; then
        local filter_count=$(podman exec "$CONTAINER_NAME" find /etc/privoxy -name "*.script.action" 2>/dev/null | wc -l)
        if [[ "$filter_count" -gt 0 ]]; then
            print_success "Professional Filter Lists: $filter_count active blocklists"
        else
            print_warning "Professional Filter Lists: NOT CONFIGURED - run update"
        fi
    fi
    
    echo
    print_status "Available Commands:"
    echo -e "${WHITE}  Start:     $0 start${NC}"
    echo -e "${WHITE}  Stop:      $0 stop${NC}"
    echo -e "${WHITE}  Restart:   $0 restart${NC}"
    echo -e "${WHITE}  Update:    $0 update${NC}"
    echo -e "${WHITE}  Logs:      $0 logs${NC}"
    echo -e "${WHITE}  Shell:     $0 shell${NC}"
    echo
    echo -e "${WHITE}  Test Proxy: curl -x http://127.0.0.1:$PRIVOXY_PORT http://httpbin.org/ip${NC}"
    echo -e "${WHITE}  Check Tor:  curl -x http://127.0.0.1:$PRIVOXY_PORT https://check.torproject.org/api/ip${NC}"
}

manage_container() {
    local action="$1"
    
    case "$action" in
        "logs")
            if podman ps | grep -q "$CONTAINER_NAME"; then
                podman logs -f "$CONTAINER_NAME"
            else
                print_error "Container not running"
            fi
            ;;
        "shell")
            if podman ps | grep -q "$CONTAINER_NAME"; then
                echo "Entering NeXuS Professional Privoxy container..."
                podman exec -it "$CONTAINER_NAME" /bin/sh
            else
                print_error "Container not running"
            fi
            ;;
        "restart")
            stop_professional_privoxy
            sleep 3
            start_professional_privoxy
            ;;
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

main() {
    case "${1:-status}" in
        "start")
            start_professional_privoxy
            ;;
        "stop")
            stop_professional_privoxy
            ;;
        "restart")
            manage_container "restart"
            ;;
        "update")
            update_filters
            ;;
        "status")
            show_status
            ;;
        "logs")
            manage_container "logs"
            ;;
        "shell")
            manage_container "shell"
            ;;
        *)
            echo "NeXuS Professional Privoxy + uBlock Origin Integration"
            echo "Using Andrwe Lord Weber's proven privoxy-blocklist script"
            echo "Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!"
            echo
            echo "Usage: $0 {start|stop|restart|update|status|logs|shell}"
            echo
            echo "Commands:"
            echo "  start    - Start Professional Privoxy container with filter updates"
            echo "  stop     - Stop Professional Privoxy container"
            echo "  restart  - Restart Professional Privoxy container"
            echo "  update   - Update filter lists (EasyList, uBlock, Fanboy, etc.)"
            echo "  status   - Show detailed system status"
            echo "  logs     - Show container logs (follow mode)"
            echo "  shell    - Enter container shell for debugging"
            echo
            echo "Features:"
            echo "  🛡️ Professional-grade AdblockPlus/uBlock Origin filter conversion"
            echo "  📦 Secure container with minimal privileges"
            echo "  🔄 Automatic filter updates from multiple sources"
            echo "  🎯 CSS selector blocking (classes, IDs, attributes)"
            echo "  🌐 Compatible with Tor and multi-network proxy chains"
            exit 1
            ;;
    esac
}

# Initialize log
mkdir -p "$CONFIG_DIR"
log_event "NeXuS Professional Privoxy script started"

# Run main function
main "$@"