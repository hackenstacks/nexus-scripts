#!/bin/bash
# NeXuS Network Doctor
# Automated network diagnosis and repair system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/nexus-network-doctor.log"
REPAIR_HISTORY="/var/log/nexus-repairs.log"

# Network interfaces and services to monitor
INTERFACES=("eth0" "wlan0" "bat0" "nexus-br0")
SERVICES=("nexus-tor" "nexus-i2p" "nexus-ipfs" "nexus-medusa" "nexus-wireguard")
CRITICAL_PORTS=(9050 7070 5001 8881 51820)

# NeXuS Fire Banner
show_banner() {
    echo -e "\e[31m"
    echo "🔥 NeXuS Network Doctor 🔥"
    echo "Automated Network Diagnosis & Repair"
    echo -e "\e[0m"
}

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Log repair action
log_repair() {
    local action="$1"
    local result="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] REPAIR: $action - $result" >> "$REPAIR_HISTORY"
}

# Check if we're running as root/with privileges
check_privileges() {
    if [[ $EUID -ne 0 ]] && ! command -v doas >/dev/null 2>&1; then
        log_message "ERROR" "Network Doctor requires root privileges for network repairs"
        echo "❌ Run with doas/sudo for full repair capabilities"
        return 1
    fi
    return 0
}

# Execute privileged command
exec_priv() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        doas "$@"
    fi
}

# Test basic connectivity
test_connectivity() {
    local test_hosts=("1.1.1.1" "8.8.8.8" "208.67.222.222")
    local working_hosts=0
    
    log_message "INFO" "Testing basic connectivity..."
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            ((working_hosts++))
            log_message "DEBUG" "Connectivity to $host: OK"
        else
            log_message "DEBUG" "Connectivity to $host: FAILED"
        fi
    done
    
    if [[ $working_hosts -eq 0 ]]; then
        log_message "ERROR" "No internet connectivity detected"
        return 1
    elif [[ $working_hosts -lt 2 ]]; then
        log_message "WARN" "Limited connectivity ($working_hosts/$working_hosts hosts reachable)"
        return 2
    else
        log_message "INFO" "Internet connectivity: OK ($working_hosts/${#test_hosts[@]} hosts reachable)"
        return 0
    fi
}

# Check network interfaces
check_interfaces() {
    local issues=0
    
    log_message "INFO" "Checking network interfaces..."
    
    for interface in "${INTERFACES[@]}"; do
        if ip link show "$interface" >/dev/null 2>&1; then
            local state=$(ip link show "$interface" | grep -oP 'state \K\w+')
            if [[ "$state" == "UP" ]]; then
                log_message "DEBUG" "Interface $interface: UP"
            else
                log_message "WARN" "Interface $interface: $state"
                ((issues++))
            fi
        else
            log_message "DEBUG" "Interface $interface: NOT PRESENT"
        fi
    done
    
    return $issues
}

# Check critical services
check_services() {
    local issues=0
    
    log_message "INFO" "Checking NeXuS services..."
    
    for service in "${SERVICES[@]}"; do
        if podman ps --format "{{.Names}}" | grep -q "^$service$"; then
            log_message "DEBUG" "Service $service: RUNNING"
        else
            log_message "WARN" "Service $service: NOT RUNNING"
            ((issues++))
        fi
    done
    
    return $issues
}

# Check critical ports
check_ports() {
    local issues=0
    
    log_message "INFO" "Checking critical ports..."
    
    for port in "${CRITICAL_PORTS[@]}"; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            log_message "DEBUG" "Port $port: LISTENING"
        else
            log_message "WARN" "Port $port: NOT LISTENING"
            ((issues++))
        fi
    done
    
    return $issues
}

# Check DNS resolution
check_dns() {
    local test_domains=("google.com" "cloudflare.com" "quad9.net")
    local working_dns=0
    
    log_message "INFO" "Testing DNS resolution..."
    
    for domain in "${test_domains[@]}"; do
        if nslookup "$domain" >/dev/null 2>&1; then
            ((working_dns++))
            log_message "DEBUG" "DNS resolution for $domain: OK"
        else
            log_message "DEBUG" "DNS resolution for $domain: FAILED"
        fi
    done
    
    if [[ $working_dns -eq 0 ]]; then
        log_message "ERROR" "DNS resolution completely broken"
        return 1
    elif [[ $working_dns -lt 2 ]]; then
        log_message "WARN" "Limited DNS resolution"
        return 2
    else
        log_message "INFO" "DNS resolution: OK"
        return 0
    fi
}

# Check routing table
check_routing() {
    log_message "INFO" "Checking routing table..."
    
    if ! ip route show default >/dev/null 2>&1; then
        log_message "ERROR" "No default route found"
        return 1
    fi
    
    local default_gw=$(ip route show default | head -1 | awk '{print $3}')
    if ping -c 1 -W 3 "$default_gw" >/dev/null 2>&1; then
        log_message "INFO" "Default gateway $default_gw: REACHABLE"
        return 0
    else
        log_message "ERROR" "Default gateway $default_gw: UNREACHABLE"
        return 1
    fi
}

# Repair network interface
repair_interface() {
    local interface="$1"
    
    log_message "INFO" "Attempting to repair interface $interface..."
    
    # Try to bring interface up
    if exec_priv ip link set "$interface" up 2>/dev/null; then
        log_repair "Interface $interface up" "SUCCESS"
        log_message "INFO" "Interface $interface brought up successfully"
        
        # For wireless, try to reconnect
        if [[ "$interface" == wlan* ]]; then
            if command -v wpa_supplicant >/dev/null 2>&1; then
                exec_priv pkill wpa_supplicant 2>/dev/null || true
                sleep 2
                exec_priv wpa_supplicant -B -i "$interface" -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true
                log_repair "WiFi reconnect $interface" "ATTEMPTED"
            fi
        fi
        
        return 0
    else
        log_repair "Interface $interface up" "FAILED"
        log_message "ERROR" "Failed to bring up interface $interface"
        return 1
    fi
}

# Repair service
repair_service() {
    local service="$1"
    
    log_message "INFO" "Attempting to repair service $service..."
    
    # Try to restart the service
    if podman restart "$service" >/dev/null 2>&1; then
        log_repair "Service $service restart" "SUCCESS"
        log_message "INFO" "Service $service restarted successfully"
        return 0
    else
        # Try to start if restart failed
        if podman start "$service" >/dev/null 2>&1; then
            log_repair "Service $service start" "SUCCESS" 
            log_message "INFO" "Service $service started successfully"
            return 0
        else
            log_repair "Service $service restart/start" "FAILED"
            log_message "ERROR" "Failed to repair service $service"
            return 1
        fi
    fi
}

# Repair DNS
repair_dns() {
    log_message "INFO" "Attempting to repair DNS..."
    
    # Backup current resolv.conf
    exec_priv cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    
    # Set reliable DNS servers
    cat << EOF | exec_priv tee /etc/resolv.conf >/dev/null
# NeXuS Network Doctor DNS repair
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 208.67.222.222
EOF
    
    # Flush DNS cache if available
    if command -v systemd-resolve >/dev/null 2>&1; then
        exec_priv systemd-resolve --flush-caches 2>/dev/null || true
    fi
    
    # Test DNS repair
    if nslookup google.com >/dev/null 2>&1; then
        log_repair "DNS configuration" "SUCCESS"
        log_message "INFO" "DNS repaired successfully"
        return 0
    else
        # Restore backup if repair failed
        exec_priv cp /etc/resolv.conf.backup /etc/resolv.conf 2>/dev/null || true
        log_repair "DNS configuration" "FAILED"
        log_message "ERROR" "DNS repair failed"
        return 1
    fi
}

# Repair routing
repair_routing() {
    log_message "INFO" "Attempting to repair routing..."
    
    # Get the primary interface
    local primary_if=$(ip route show default | head -1 | awk '{print $5}')
    
    if [[ -n "$primary_if" ]]; then
        # Try to renew DHCP lease
        if command -v dhclient >/dev/null 2>&1; then
            exec_priv dhclient -r "$primary_if" 2>/dev/null || true
            sleep 2
            exec_priv dhclient "$primary_if" 2>/dev/null || true
            log_repair "DHCP renewal $primary_if" "ATTEMPTED"
        fi
        
        # Test if repair worked
        if check_routing; then
            log_repair "Routing repair" "SUCCESS"
            return 0
        fi
    fi
    
    log_repair "Routing repair" "FAILED"
    return 1
}

# Nuclear option: full network restart
nuclear_network_restart() {
    log_message "WARN" "Executing nuclear network restart..."
    
    if ! check_privileges; then
        log_message "ERROR" "Cannot perform nuclear restart without privileges"
        return 1
    fi
    
    # Stop all network services
    log_message "INFO" "Stopping network services..."
    exec_priv systemctl stop networking 2>/dev/null || true
    exec_priv systemctl stop NetworkManager 2>/dev/null || true
    exec_priv systemctl stop wpa_supplicant 2>/dev/null || true
    
    # Flush all network configuration
    log_message "INFO" "Flushing network configuration..."
    for interface in $(ip link show | grep -oP '^\d+: \K[^:]+' | grep -v lo); do
        exec_priv ip addr flush dev "$interface" 2>/dev/null || true
        exec_priv ip link set "$interface" down 2>/dev/null || true
    done
    
    # Clear routing table
    exec_priv ip route flush table main 2>/dev/null || true
    
    # Wait a moment
    sleep 5
    
    # Restart network services
    log_message "INFO" "Restarting network services..."
    exec_priv systemctl start networking 2>/dev/null || true
    exec_priv systemctl start NetworkManager 2>/dev/null || true
    
    # Wait for network to come up
    sleep 10
    
    # Test if nuclear option worked
    if test_connectivity; then
        log_repair "Nuclear network restart" "SUCCESS"
        log_message "INFO" "Nuclear network restart successful"
        return 0
    else
        log_repair "Nuclear network restart" "FAILED"
        log_message "ERROR" "Nuclear network restart failed"
        return 1
    fi
}

# Comprehensive network diagnosis
diagnose_network() {
    local issues=0
    
    log_message "INFO" "Starting comprehensive network diagnosis..."
    
    echo "🔍 NeXuS Network Diagnosis Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Test connectivity
    echo -n "🌐 Internet Connectivity: "
    if test_connectivity; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
        ((issues++))
    fi
    
    # Check interfaces
    echo -n "🔗 Network Interfaces: "
    if check_interfaces; then
        echo "✅ OK"
    else
        echo "⚠️  ISSUES DETECTED"
        ((issues++))
    fi
    
    # Check services
    echo -n "🚀 NeXuS Services: "
    if check_services; then
        echo "✅ OK"
    else
        echo "⚠️  ISSUES DETECTED"
        ((issues++))
    fi
    
    # Check ports
    echo -n "🔌 Critical Ports: "
    if check_ports; then
        echo "✅ OK"
    else
        echo "⚠️  ISSUES DETECTED"
        ((issues++))
    fi
    
    # Check DNS
    echo -n "🔍 DNS Resolution: "
    case $(check_dns; echo $?) in
        0) echo "✅ OK" ;;
        1) echo "❌ FAILED"; ((issues++)) ;;
        2) echo "⚠️  LIMITED"; ((issues++)) ;;
    esac
    
    # Check routing
    echo -n "🛣️  Routing: "
    if check_routing; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
        ((issues++))
    fi
    
    echo ""
    echo "📊 Diagnosis Summary: $issues issues detected"
    
    if [[ $issues -eq 0 ]]; then
        echo "🎉 All systems operational!"
        log_message "INFO" "Network diagnosis complete: All systems operational"
        return 0
    else
        echo "⚠️  Network issues detected, repairs may be needed"
        log_message "WARN" "Network diagnosis complete: $issues issues detected"
        return $issues
    fi
}

# Automated repair process
auto_repair() {
    local repair_attempts=0
    local max_attempts=3
    
    log_message "INFO" "Starting automated network repair..."
    
    while [[ $repair_attempts -lt $max_attempts ]]; do
        ((repair_attempts++))
        echo "🔧 Repair attempt $repair_attempts/$max_attempts"
        
        # Diagnose current state
        if ! diagnose_network >/dev/null 2>&1; then
            echo "🩺 Issues detected, attempting repairs..."
            
            # Repair interfaces
            for interface in "${INTERFACES[@]}"; do
                if ip link show "$interface" >/dev/null 2>&1; then
                    local state=$(ip link show "$interface" | grep -oP 'state \K\w+')
                    if [[ "$state" != "UP" ]]; then
                        repair_interface "$interface"
                    fi
                fi
            done
            
            # Repair services
            for service in "${SERVICES[@]}"; do
                if ! podman ps --format "{{.Names}}" | grep -q "^$service$"; then
                    repair_service "$service"
                fi
            done
            
            # Repair DNS if needed
            if ! check_dns >/dev/null 2>&1; then
                repair_dns
            fi
            
            # Repair routing if needed
            if ! check_routing >/dev/null 2>&1; then
                repair_routing
            fi
            
            # Wait before re-testing
            sleep 10
            
            # Test if repairs worked
            if diagnose_network >/dev/null 2>&1; then
                echo "✅ Network repair successful!"
                log_message "INFO" "Automated repair successful after $repair_attempts attempts"
                return 0
            fi
        else
            echo "✅ Network is healthy, no repairs needed"
            log_message "INFO" "Network is healthy, no repairs needed"
            return 0
        fi
    done
    
    # If we get here, repairs failed
    echo "❌ Automated repairs failed after $max_attempts attempts"
    echo "🚨 Consider nuclear network restart or manual intervention"
    log_message "ERROR" "Automated repair failed after $max_attempts attempts"
    return 1
}

# Monitor mode - continuous network monitoring
monitor_mode() {
    local check_interval="${1:-60}"
    
    echo "👁️  Starting NeXuS Network Monitor (checking every ${check_interval}s)"
    echo "Press Ctrl+C to stop..."
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] Checking network health..."
        
        if ! diagnose_network >/dev/null 2>&1; then
            echo "⚠️  Issues detected, attempting automatic repair..."
            auto_repair
        else
            echo "✅ Network healthy"
        fi
        
        sleep "$check_interval"
    done
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        echo ""
        echo "🎮 NeXuS Network Doctor Menu:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1) 🔍 Diagnose Network"
        echo "2) 🔧 Auto Repair"
        echo "3) 👁️  Monitor Mode"
        echo "4) 🚨 Nuclear Restart"
        echo "5) 📋 View Logs"
        echo "6) 📊 Repair History"
        echo "7) 🧪 Test Connectivity"
        echo "8) ⚙️  Manual Repairs"
        echo "9) 🚪 Exit"
        echo ""
        read -p "Select option (1-9): " choice
        
        case "$choice" in
            1)
                diagnose_network
                read -p "Press Enter to continue..."
                ;;
            2)
                auto_repair
                read -p "Press Enter to continue..."
                ;;
            3)
                read -p "Check interval in seconds (default 60): " interval
                monitor_mode "${interval:-60}"
                ;;
            4)
                echo "⚠️  This will restart all network services!"
                read -p "Continue? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    nuclear_network_restart
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "📋 Recent Network Doctor logs:"
                tail -20 "$LOG_FILE" 2>/dev/null || echo "No logs found"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "📊 Repair History:"
                tail -20 "$REPAIR_HISTORY" 2>/dev/null || echo "No repair history found"
                read -p "Press Enter to continue..."
                ;;
            7)
                test_connectivity
                read -p "Press Enter to continue..."
                ;;
            8)
                echo "Manual repair options:"
                echo "1) Repair DNS"
                echo "2) Repair Routing"
                echo "3) Restart Services"
                read -p "Select repair: " repair_choice
                case "$repair_choice" in
                    1) repair_dns ;;
                    2) repair_routing ;;
                    3) for service in "${SERVICES[@]}"; do repair_service "$service"; done ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            9)
                echo "👋 Exiting NeXuS Network Doctor"
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
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "${1:-menu}" in
        "diagnose"|"check")
            diagnose_network
            ;;
        "repair"|"fix")
            auto_repair
            ;;
        "monitor")
            monitor_mode "${2:-60}"
            ;;
        "nuclear")
            echo "⚠️  Nuclear network restart will disrupt all connections!"
            read -p "Continue? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                nuclear_network_restart
            fi
            ;;
        "test")
            test_connectivity
            ;;
        "menu"|"interactive")
            interactive_menu
            ;;
        "help"|*)
            echo ""
            echo "🔥 NeXuS Network Doctor"
            echo ""
            echo "Usage: $0 {diagnose|repair|monitor|nuclear|test|menu|help}"
            echo ""
            echo "Commands:"
            echo "  diagnose           - Run comprehensive network diagnosis"
            echo "  repair             - Attempt automated network repair"
            echo "  monitor [interval] - Continuous monitoring (default 60s)"
            echo "  nuclear            - Nuclear network restart (last resort)"
            echo "  test               - Test basic connectivity"
            echo "  menu               - Interactive management interface"
            echo "  help               - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 diagnose       # Check network health"
            echo "  $0 repair         # Fix detected issues"
            echo "  $0 monitor 30     # Monitor every 30 seconds"
            echo "  $0 menu           # Interactive interface"
            echo ""
            echo "Logs:"
            echo "  Diagnosis: $LOG_FILE"
            echo "  Repairs:   $REPAIR_HISTORY"
            ;;
    esac
}

# Execute main function
main "$@"