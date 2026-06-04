#!/bin/bash
# 🛡️ NeXuS Firewall Toggle - Quick On/Off Control
# Usage: ./nexus-firewall-toggle.sh [on|off|status]

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Symbols
SHIELD_ON="🛡️"
SHIELD_OFF="🔓"
STATUS_SYMBOL="📊"

CONFIG_DIR="/home/user/.nexus-security/containers/opensnitch"
CONFIG_FILE="$CONFIG_DIR/daemon.conf"
BACKUP_FILE="$CONFIG_DIR/daemon.conf.backup"
STATUS_FILE="/tmp/nexus-firewall-status"

show_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}     🛡️  NeXuS Firewall Control  🛡️     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
}

get_status() {
    if [ -f "$STATUS_FILE" ]; then
        cat "$STATUS_FILE"
    else
        echo "unknown"
    fi
}

firewall_on() {
    show_banner
    echo -e "${BLUE}🔒 Activating NeXuS Application Firewall...${NC}"
    
    # Create restrictive config
    cat > "$CONFIG_FILE" << 'EOF'
{
    "Server": {
        "Address": "0.0.0.0:50051",
        "LogFile": "/var/log/opensnitchd/opensnitch.log",
        "LogLevel": 2
    },
    "DefaultAction": "deny",
    "InterceptUnknown": true,
    "ProcMonitorMethod": "proc",
    "LogUTC": false
}
EOF
    
    echo "on" > "$STATUS_FILE"
    echo "$(date): FIREWALL_ON - Restrictive mode activated" >> /home/user/.nexus-security/fortress.log
    
    echo -e "${GREEN}${SHIELD_ON} Firewall ACTIVATED - Blocking unknown connections${NC}"
    echo -e "${YELLOW}📋 Use nexus-quick-allow.sh to permit specific connections${NC}"
}

firewall_off() {
    show_banner
    echo -e "${YELLOW}🔓 Deactivating NeXuS Application Firewall...${NC}"
    
    # Create permissive config
    cat > "$CONFIG_FILE" << 'EOF'
{
    "Server": {
        "Address": "0.0.0.0:50051", 
        "LogFile": "/var/log/opensnitchd/opensnitch.log",
        "LogLevel": 2
    },
    "DefaultAction": "allow",
    "InterceptUnknown": true,
    "ProcMonitorMethod": "proc", 
    "LogUTC": false
}
EOF
    
    echo "off" > "$STATUS_FILE"
    echo "$(date): FIREWALL_OFF - Permissive mode activated" >> /home/user/.nexus-security/fortress.log
    
    echo -e "${RED}${SHIELD_OFF} Firewall DEACTIVATED - Allowing all connections${NC}"
    echo -e "${YELLOW}⚠️  All network connections permitted${NC}"
}

show_status() {
    show_banner
    local current_status=$(get_status)
    
    echo -e "${STATUS_SYMBOL} ${BLUE}Current Firewall Status:${NC}"
    
    case "$current_status" in
        "on")
            echo -e "${GREEN}${SHIELD_ON} ACTIVE - Blocking unknown connections${NC}"
            ;;
        "off")
            echo -e "${RED}${SHIELD_OFF} INACTIVE - Allowing all connections${NC}"
            ;;
        *)
            echo -e "${YELLOW}❓ UNKNOWN - Check configuration${NC}"
            ;;
    esac
    
    # Show recent activity
    if [ -f "/home/user/.nexus-security/fortress.log" ]; then
        echo -e "\n${BLUE}📝 Recent Activity:${NC}"
        tail -5 /home/user/.nexus-security/fortress.log | grep -E "(FIREWALL|TEMP_ALLOW)" || echo "No recent firewall activity"
    fi
    
    # Show container status
    echo -e "\n${BLUE}📦 Container Status:${NC}"
    if podman ps --filter name=nexus-opensnitch --format "{{.Status}}" 2>/dev/null; then
        echo -e "${GREEN}✅ OpenSnitch container running${NC}"
    else
        echo -e "${YELLOW}⚠️  OpenSnitch container not running${NC}"
    fi
}

restart_container() {
    echo -e "${BLUE}🔄 Restarting OpenSnitch container to apply changes...${NC}"
    podman restart nexus-opensnitch 2>/dev/null || echo -e "${YELLOW}⚠️  Container not running - start it manually${NC}"
}

case "${1:-status}" in
    "on"|"enable"|"activate")
        firewall_on
        restart_container
        ;;
    "off"|"disable"|"deactivate") 
        firewall_off
        restart_container
        ;;
    "status"|"check")
        show_status
        ;;
    "restart")
        restart_container
        ;;
    *)
        show_banner
        echo -e "${YELLOW}Usage: $0 {on|off|status|restart}${NC}"
        echo
        echo -e "${BLUE}Commands:${NC}"
        echo -e "  ${GREEN}on${NC}      - Activate restrictive firewall mode"
        echo -e "  ${RED}off${NC}     - Deactivate firewall (allow all)"
        echo -e "  ${BLUE}status${NC}  - Show current firewall status"
        echo -e "  ${YELLOW}restart${NC} - Restart OpenSnitch container"
        echo
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  $0 on          # Block unknown connections"
        echo -e "  $0 off         # Allow all connections"
        echo -e "  $0 status      # Check current state"
        ;;
esac