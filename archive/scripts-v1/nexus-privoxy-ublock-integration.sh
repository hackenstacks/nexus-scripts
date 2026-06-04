#!/bin/bash

# NeXuS Privoxy uBlock Origin Blacklist Integration
# Downloads and converts uBlock Origin filter lists for Privoxy
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
CONFIG_DIR="/home/user/.nexus-security/privoxy"
CONTAINER_NAME="nexus-privoxy-ublock"
UBLOCK_FILTERS_DIR="$CONFIG_DIR/ublock-filters"
PRIVOXY_CONFIG_DIR="$CONFIG_DIR/config"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$CONFIG_DIR/privoxy-ublock.log"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      🛡️ NeXuS PRIVOXY + uBLOCK ORIGIN INTEGRATION      ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}   Advanced Ad/Tracker Blocking • Enhanced Privacy       ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}   Sane • Simple • Secure NeXuS - Together MORE!        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

download_ublock_filters() {
    print_status "Downloading uBlock Origin filter lists..."
    
    mkdir -p "$UBLOCK_FILTERS_DIR"
    cd "$UBLOCK_FILTERS_DIR"
    
    # EasyList - Primary ad blocking
    print_status "Downloading EasyList (ads)..."
    curl -s -L "https://easylist.to/easylist/easylist.txt" -o "easylist.txt" || print_warning "Failed to download EasyList"
    
    # EasyPrivacy - Tracking protection
    print_status "Downloading EasyPrivacy (tracking)..."
    curl -s -L "https://easylist.to/easylist/easyprivacy.txt" -o "easyprivacy.txt" || print_warning "Failed to download EasyPrivacy"
    
    # Malware Domain List
    print_status "Downloading Malware Domain List..."
    curl -s -L "https://www.malwaredomainlist.com/hostslist/hosts.txt" -o "malware-domains.txt" || print_warning "Failed to download Malware domains"
    
    # Peter Lowe's Blocklist
    print_status "Downloading Peter Lowe's ad/tracking servers..."
    curl -s -L "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" -o "yoyo-adservers.txt" || print_warning "Failed to download Peter Lowe's list"
    
    # Steven Black's Unified Hosts (ads + malware + fakenews + gambling + porn)
    print_status "Downloading Steven Black's Unified Hosts..."
    curl -s -L "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts" -o "stevenblack-unified.txt" || print_warning "Failed to download Steven Black's list"
    
    # Dan Pollock's hosts file
    print_status "Downloading Dan Pollock's hosts file..."
    curl -s -L "https://someonewhocares.org/hosts/zero/hosts" -o "someonewhocares.txt" || print_warning "Failed to download Dan Pollock's list"
    
    print_success "Filter lists downloaded"
}

convert_to_privoxy_format() {
    print_status "Converting filter lists to Privoxy format..."
    
    mkdir -p "$PRIVOXY_CONFIG_DIR"
    
    # Create main Privoxy blocking actions file
    cat > "$PRIVOXY_CONFIG_DIR/ublock-actions.action" << 'EOF'
# NeXuS uBlock Origin Privoxy Integration
# Generated from multiple filter sources
#
# This file contains blocking rules converted from uBlock Origin filter lists
# Categories: Ads, Tracking, Malware, Social Media, Privacy

{{alias}}
# Block with specific reason
+block-as-ad = +block{Blocked: Advertisement}
+block-as-tracker = +block{Blocked: Tracking/Analytics}
+block-as-malware = +block{Blocked: Malware/Phishing}
+block-as-social = +block{Blocked: Social Media Tracking}
+block-as-misc = +block{Blocked: Miscellaneous}

# Privacy enhancing actions
+privacy-headers = +hide-user-agent{Mozilla/5.0 (NeXuS Security)} +hide-referrer{conditional-block}
+anti-tracking = +crunch-outgoing-cookies +crunch-incoming-cookies +session-cookies-only

# Default actions for all sites
{+privacy-headers +anti-tracking}
*

EOF

    # Convert each filter list
    local action_file="$PRIVOXY_CONFIG_DIR/ublock-actions.action"
    
    # Process EasyList
    if [[ -f "$UBLOCK_FILTERS_DIR/easylist.txt" ]]; then
        print_status "Converting EasyList..."
        echo "# EasyList Converted Rules" >> "$action_file"
        grep -E '^||[^/]+\^' "$UBLOCK_FILTERS_DIR/easylist.txt" | \
        sed 's/^||//' | sed 's/\^.*//' | \
        while read domain; do
            [[ -n "$domain" && "$domain" != *"*"* ]] && echo "{+block-as-ad}" >> "$action_file" && echo "$domain" >> "$action_file"
        done
        echo "" >> "$action_file"
    fi
    
    # Process EasyPrivacy  
    if [[ -f "$UBLOCK_FILTERS_DIR/easyprivacy.txt" ]]; then
        print_status "Converting EasyPrivacy..."
        echo "# EasyPrivacy Converted Rules" >> "$action_file"
        grep -E '^||[^/]+\^' "$UBLOCK_FILTERS_DIR/easyprivacy.txt" | \
        sed 's/^||//' | sed 's/\^.*//' | \
        while read domain; do
            [[ -n "$domain" && "$domain" != *"*"* ]] && echo "{+block-as-tracker}" >> "$action_file" && echo "$domain" >> "$action_file"
        done
        echo "" >> "$action_file"
    fi
    
    # Process hosts files format (malware, yoyo, stevenblack, someonewhocares)
    for hosts_file in malware-domains.txt yoyo-adservers.txt stevenblack-unified.txt someonewhocares.txt; do
        if [[ -f "$UBLOCK_FILTERS_DIR/$hosts_file" ]]; then
            print_status "Converting $hosts_file..."
            echo "# $hosts_file Converted Rules" >> "$action_file"
            grep -E '^(0\.0\.0\.0|127\.0\.0\.1)[[:space:]]+[^[:space:]]+' "$UBLOCK_FILTERS_DIR/$hosts_file" | \
            awk '{print $2}' | grep -v '^localhost' | grep -v '^#' | \
            while read domain; do
                [[ -n "$domain" && "$domain" != *"*"* ]] && echo "{+block-as-malware}" >> "$action_file" && echo "$domain" >> "$action_file"
            done
            echo "" >> "$action_file"
        fi
    done
    
    print_success "Filter lists converted to Privoxy format"
}

create_privoxy_config() {
    print_status "Creating enhanced Privoxy configuration..."
    
    # Main Privoxy config
    cat > "$PRIVOXY_CONFIG_DIR/config" << 'EOF'
# NeXuS Privoxy Configuration with uBlock Origin Integration
# Enhanced privacy and ad blocking

# Network settings
listen-address 0.0.0.0:8118
listen-address 127.0.0.1:8118

# Basic settings
toggle 1
enable-remote-toggle 0
enable-edit-actions 0
enable-remote-http-toggle 0
buffer-limit 4096

# Logging (comment out for production)
logfile /var/log/privoxy/privoxy.log
debug 1024  # Log actions

# Trust and filtering
confdir /etc/privoxy
templdir /etc/privoxy/templates

# Action files (order matters!)
actionsfile match-all.action
actionsfile default.action
actionsfile ublock-actions.action

# Filter files
filterfile default.filter
filterfile user.filter

# Forward to Tor (optional - enable if using with Tor)
# forward-socks5t / 127.0.0.1:9050 .
# forward-socks5  / 127.0.0.1:9050 .

# Advanced privacy settings
hide-console-prompts 1
compression-level 1
EOF

    # Create additional filter file for content filtering
    cat > "$PRIVOXY_CONFIG_DIR/user.filter" << 'EOF'
# NeXuS User Filter Rules
# Content-based filtering for enhanced privacy

# Remove tracking scripts and beacons
FILTER: privacy Privacy Protection
s|<script[^>]*google-analytics[^>]*>.*?</script>||gims
s|<script[^>]*googletagmanager[^>]*>.*?</script>||gims
s|<script[^>]*facebook[^>]*>.*?</script>||gims
s|<img[^>]*\.gif[^>]*1x1[^>]*>||gims

# Remove social media widgets
FILTER: social-widgets Social Media Widget Removal
s|<iframe[^>]*facebook\.com[^>]*>.*?</iframe>||gims
s|<iframe[^>]*twitter\.com[^>]*>.*?</iframe>||gims
s|<div[^>]*fb-like[^>]*>.*?</div>||gims

# Content Security
FILTER: security Security Enhancement
s|javascript:||gims
EOF

    print_success "Enhanced Privoxy configuration created"
}

create_container_scripts() {
    print_status "Creating container management scripts..."
    
    # Container startup script
    cat > "$CONFIG_DIR/start-privoxy-ublock.sh" << EOF
#!/bin/bash

# NeXuS Privoxy + uBlock Origin Container
# Secure containerized web filtering

CONTAINER_NAME="$CONTAINER_NAME"
CONFIG_DIR="$PRIVOXY_CONFIG_DIR"

# Clean up existing container
podman rm -f "\$CONTAINER_NAME" 2>/dev/null || true

# Create container with security restrictions
podman run -d \\
    --name "\$CONTAINER_NAME" \\
    --security-opt no-new-privileges \\
    --cap-drop ALL \\
    --cap-add NET_BIND_SERVICE \\
    --read-only \\
    --tmpfs /tmp \\
    --tmpfs /var/tmp \\
    --tmpfs /var/log/privoxy \\
    --network bridge \\
    -p 8118:8118 \\
    -v "\$CONFIG_DIR":/etc/privoxy:ro,Z \\
    --restart unless-stopped \\
    --user \$(id -u):\$(id -g) \\
    --health-cmd="curl -f http://localhost:8118 || exit 1" \\
    --health-interval=30s \\
    --health-timeout=10s \\
    --health-retries=3 \\
    docker.io/vimagick/privoxy

echo "NeXuS Privoxy + uBlock Origin container started: \$CONTAINER_NAME"
echo "Proxy available at: http://127.0.0.1:8118"
EOF

    chmod +x "$CONFIG_DIR/start-privoxy-ublock.sh"
    
    # Container management script
    cat > "$CONFIG_DIR/manage-privoxy.sh" << 'EOF'
#!/bin/bash

CONTAINER_NAME="nexus-privoxy-ublock"

case "${1:-status}" in
    "start")
        /home/user/.nexus-security/privoxy/start-privoxy-ublock.sh
        ;;
    "stop")
        podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
        echo "Container stopped: $CONTAINER_NAME"
        ;;
    "restart")
        podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
        sleep 2
        /home/user/.nexus-security/privoxy/start-privoxy-ublock.sh
        ;;
    "status")
        if podman ps | grep -q "$CONTAINER_NAME"; then
            echo "✅ $CONTAINER_NAME is running"
            podman ps | grep "$CONTAINER_NAME"
        else
            echo "❌ $CONTAINER_NAME is not running"
        fi
        ;;
    "logs")
        podman logs "$CONTAINER_NAME"
        ;;
    "shell")
        podman exec -it "$CONTAINER_NAME" /bin/sh
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|shell}"
        ;;
esac
EOF

    chmod +x "$CONFIG_DIR/manage-privoxy.sh"
    
    print_success "Container management scripts created"
}

update_filters() {
    print_fire "Updating uBlock Origin Filter Lists"
    echo
    
    download_ublock_filters
    convert_to_privoxy_format
    
    # Restart container if running to reload config
    if podman ps | grep -q "$CONTAINER_NAME"; then
        print_status "Restarting container to reload filters..."
        "$CONFIG_DIR/manage-privoxy.sh" restart
    fi
    
    print_success "Filter lists updated successfully"
    log_event "Filter lists updated"
}

setup_complete_system() {
    show_banner
    print_fire "Setting up NeXuS Privoxy + uBlock Origin Integration"
    echo
    
    mkdir -p "$CONFIG_DIR" "$UBLOCK_FILTERS_DIR" "$PRIVOXY_CONFIG_DIR"
    
    download_ublock_filters
    convert_to_privoxy_format
    create_privoxy_config
    create_container_scripts
    
    echo
    print_fire "NeXuS Privoxy + uBlock Origin Integration COMPLETE"
    echo -e "${GREEN}🛡️ Enhanced ad/tracker blocking enabled${NC}"
    echo -e "${CYAN}🔒 Privacy-focused filtering active${NC}"
    echo -e "${YELLOW}🌐 Proxy available at: http://127.0.0.1:8118${NC}"
    echo
    print_status "Quick Start Commands:"
    echo -e "${WHITE}  Start:    $CONFIG_DIR/manage-privoxy.sh start${NC}"
    echo -e "${WHITE}  Status:   $CONFIG_DIR/manage-privoxy.sh status${NC}"
    echo -e "${WHITE}  Update:   $0 update${NC}"
    echo -e "${WHITE}  Test:     curl -x http://127.0.0.1:8118 http://httpbin.org/ip${NC}"
    echo
    
    log_event "Complete system setup finished"
}

show_status() {
    show_banner
    print_fire "NeXuS Privoxy + uBlock Origin Status"
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
        else
            print_warning "Health Status: $health"
        fi
    else
        print_warning "Container Status: NOT RUNNING"
    fi
    
    # Check proxy accessibility
    if nc -z 127.0.0.1 8118 2>/dev/null; then
        print_success "Proxy Port 8118: ACCESSIBLE"
    else
        print_warning "Proxy Port 8118: NOT ACCESSIBLE"
    fi
    
    # Check filter files
    if [[ -f "$PRIVOXY_CONFIG_DIR/ublock-actions.action" ]]; then
        local filter_count=$(grep -c '^[^#].*\.' "$PRIVOXY_CONFIG_DIR/ublock-actions.action" 2>/dev/null || echo "0")
        print_success "Filter Rules: $filter_count active blocking rules"
    else
        print_warning "Filter Rules: NOT CONFIGURED"
    fi
    
    echo
    print_status "Available Commands:"
    echo -e "${WHITE}  Start:    $CONFIG_DIR/manage-privoxy.sh start${NC}"
    echo -e "${WHITE}  Stop:     $CONFIG_DIR/manage-privoxy.sh stop${NC}"
    echo -e "${WHITE}  Restart:  $CONFIG_DIR/manage-privoxy.sh restart${NC}"
    echo -e "${WHITE}  Logs:     $CONFIG_DIR/manage-privoxy.sh logs${NC}"
    echo -e "${WHITE}  Update:   $0 update${NC}"
}

main() {
    case "${1:-status}" in
        "setup")
            setup_complete_system
            ;;
        "update")
            update_filters
            ;;
        "start")
            "$CONFIG_DIR/manage-privoxy.sh" start
            ;;
        "stop")
            "$CONFIG_DIR/manage-privoxy.sh" stop
            ;;
        "restart")
            "$CONFIG_DIR/manage-privoxy.sh" restart
            ;;
        "status")
            show_status
            ;;
        "logs")
            "$CONFIG_DIR/manage-privoxy.sh" logs
            ;;
        *)
            echo "NeXuS Privoxy + uBlock Origin Integration"
            echo "Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!"
            echo
            echo "Usage: $0 {setup|update|start|stop|restart|status|logs}"
            echo
            echo "Commands:"
            echo "  setup    - Initial setup with filter downloads"
            echo "  update   - Update filter lists from internet"
            echo "  start    - Start Privoxy container"
            echo "  stop     - Stop Privoxy container"
            echo "  restart  - Restart Privoxy container"
            echo "  status   - Show detailed system status"
            echo "  logs     - Show container logs"
            exit 1
            ;;
    esac
}

# Initialize log
mkdir -p "$CONFIG_DIR"
log_event "NeXuS Privoxy uBlock Integration script started"

# Run main function
main "$@"