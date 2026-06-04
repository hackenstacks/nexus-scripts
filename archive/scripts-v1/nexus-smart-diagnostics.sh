#!/bin/bash
# NeXuS Smart Diagnostic System
# Intelligent troubleshooting and auto-repair for NeXuS ecosystem

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# NeXuS symbols
FIRE_SYMBOL="🔥"
ROCKET_SYMBOL="🚀"
GEAR_SYMBOL="⚙️"
SHIELD_SYMBOL="🛡️"
BRAIN_SYMBOL="🧠"
NEXUS_SYMBOL="🌀"
DIAGNOSTIC_SYMBOL="🔍"
REPAIR_SYMBOL="🔧"
SUCCESS_SYMBOL="✅"
ERROR_SYMBOL="❌"
WARNING_SYMBOL="⚠️"
INFO_SYMBOL="💡"

# Configuration
DIAGNOSTIC_LOG="/home/user/.nexus-backups/diagnostics.log"
REPAIR_LOG="/home/user/.nexus-backups/repairs.log"
DIAGNOSTIC_REPORTS="/home/user/.nexus-backups/diagnostic-reports"

print_color() {
    echo -e "${1}${2}${NC}"
}

log_diagnostic() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIAGNOSTIC: $1" >> "$DIAGNOSTIC_LOG"
}

log_repair() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] REPAIR: $1" >> "$REPAIR_LOG"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║            ${BRAIN_SYMBOL} NeXuS Smart Diagnostic System ${BRAIN_SYMBOL}         ║"
    print_color $CYAN "║              ${GEAR_SYMBOL} Intelligent Troubleshooting ${GEAR_SYMBOL}            ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

# Initialize diagnostic system
init_diagnostics() {
    mkdir -p "$(dirname "$DIAGNOSTIC_LOG")"
    mkdir -p "$DIAGNOSTIC_REPORTS"
    touch "$DIAGNOSTIC_LOG" "$REPAIR_LOG"
}

# Smart WiFi Diagnostics and Auto-Repair
diagnose_wifi() {
    local issues_found=0
    local fixes_applied=0
    
    print_color $CYAN "${DIAGNOSTIC_SYMBOL} NeXuS WiFi Smart Diagnostics"
    print_color $CYAN "============================================"
    echo
    
    log_diagnostic "Starting WiFi diagnostic scan"
    
    # 1. Check if WiFi interface exists
    print_color $YELLOW "🔍 Checking WiFi interface..."
    local wifi_interface=$(ip link show | grep -E "(wlan|wifi|wlp)" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [ -z "$wifi_interface" ]; then
        print_color $RED "${ERROR_SYMBOL} No WiFi interface found"
        log_diagnostic "CRITICAL: No WiFi interface detected"
        ((issues_found++))
        
        print_color $YELLOW "${REPAIR_SYMBOL} Attempting to load WiFi drivers..."
        if doas modprobe -r iwlwifi && doas modprobe iwlwifi; then
            print_color $GREEN "${SUCCESS_SYMBOL} WiFi driver reloaded"
            log_repair "WiFi driver reloaded successfully"
            ((fixes_applied++))
            sleep 2
            wifi_interface=$(ip link show | grep -E "(wlan|wifi|wlp)" | head -1 | cut -d: -f2 | tr -d ' ')
        fi
    else
        print_color $GREEN "${SUCCESS_SYMBOL} WiFi interface found: $wifi_interface"
    fi
    
    if [ -n "$wifi_interface" ]; then
        # 2. Check if interface is up
        print_color $YELLOW "🔍 Checking interface status..."
        if ! ip link show "$wifi_interface" | grep -q "state UP"; then
            print_color $RED "${ERROR_SYMBOL} WiFi interface is down"
            ((issues_found++))
            
            print_color $YELLOW "${REPAIR_SYMBOL} Bringing up WiFi interface..."
            if doas ip link set "$wifi_interface" up; then
                print_color $GREEN "${SUCCESS_SYMBOL} WiFi interface activated"
                log_repair "WiFi interface $wifi_interface brought up"
                ((fixes_applied++))
                sleep 2
            fi
        else
            print_color $GREEN "${SUCCESS_SYMBOL} WiFi interface is up"
        fi
        
        # 3. Check for available networks
        print_color $YELLOW "🔍 Scanning for available networks..."
        local networks=$(doas iw dev "$wifi_interface" scan 2>/dev/null | grep "SSID:" | wc -l)
        
        if [ "$networks" -eq 0 ]; then
            print_color $RED "${ERROR_SYMBOL} No WiFi networks detected"
            ((issues_found++))
            
            print_color $YELLOW "${REPAIR_SYMBOL} Attempting to reset WiFi..."
            doas ip link set "$wifi_interface" down
            sleep 1
            doas ip link set "$wifi_interface" up
            sleep 3
            
            networks=$(doas iw dev "$wifi_interface" scan 2>/dev/null | grep "SSID:" | wc -l)
            if [ "$networks" -gt 0 ]; then
                print_color $GREEN "${SUCCESS_SYMBOL} WiFi reset successful, $networks networks found"
                log_repair "WiFi reset resolved network detection"
                ((fixes_applied++))
            fi
        else
            print_color $GREEN "${SUCCESS_SYMBOL} Found $networks available networks"
        fi
        
        # 4. Check NetworkManager/wpa_supplicant status
        print_color $YELLOW "🔍 Checking WiFi management services..."
        if command -v networkctl >/dev/null 2>&1; then
            # systemd-networkd
            local networkd_status=$(systemctl is-active systemd-networkd 2>/dev/null || echo "inactive")
            if [ "$networkd_status" != "active" ]; then
                print_color $YELLOW "${WARNING_SYMBOL} systemd-networkd not active"
                ((issues_found++))
            else
                print_color $GREEN "${SUCCESS_SYMBOL} systemd-networkd is active"
            fi
        fi
        
        if command -v wpa_supplicant >/dev/null 2>&1; then
            if ! pgrep -x wpa_supplicant >/dev/null; then
                print_color $YELLOW "${WARNING_SYMBOL} wpa_supplicant not running"
                print_color $YELLOW "${REPAIR_SYMBOL} Starting wpa_supplicant..."
                
                # Check for wpa_supplicant config
                local wpa_conf="/etc/wpa_supplicant/wpa_supplicant.conf"
                if [ -f "$wpa_conf" ]; then
                    doas wpa_supplicant -B -i "$wifi_interface" -c "$wpa_conf" >/dev/null 2>&1
                    if pgrep -x wpa_supplicant >/dev/null; then
                        print_color $GREEN "${SUCCESS_SYMBOL} wpa_supplicant started"
                        log_repair "wpa_supplicant started successfully"
                        ((fixes_applied++))
                    fi
                fi
            else
                print_color $GREEN "${SUCCESS_SYMBOL} wpa_supplicant is running"
            fi
        fi
        
        # 5. Check current connection
        print_color $YELLOW "🔍 Checking current WiFi connection..."
        local connected_ssid=$(iw dev "$wifi_interface" link 2>/dev/null | grep "SSID:" | cut -d: -f2 | tr -d ' ')
        
        if [ -n "$connected_ssid" ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} Connected to: $connected_ssid"
            
            # Test internet connectivity
            print_color $YELLOW "🔍 Testing internet connectivity..."
            if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
                print_color $GREEN "${SUCCESS_SYMBOL} Internet connectivity confirmed"
            else
                print_color $RED "${ERROR_SYMBOL} No internet access"
                ((issues_found++))
                
                print_color $YELLOW "${REPAIR_SYMBOL} Attempting to renew DHCP lease..."
                if doas dhclient -r "$wifi_interface" && doas dhclient "$wifi_interface"; then
                    sleep 3
                    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
                        print_color $GREEN "${SUCCESS_SYMBOL} DHCP renewal successful"
                        log_repair "DHCP lease renewed, internet restored"
                        ((fixes_applied++))
                    fi
                fi
            fi
        else
            print_color $RED "${ERROR_SYMBOL} Not connected to any network"
            ((issues_found++))
            
            # Show available networks for manual connection
            print_color $CYAN "${INFO_SYMBOL} Available networks:"
            doas iw dev "$wifi_interface" scan 2>/dev/null | grep -E "(SSID|signal)" | grep -A1 "SSID" | head -10
        fi
    fi
    
    # Summary
    echo
    print_color $CYAN "📊 WiFi Diagnostic Summary:"
    print_color $CYAN "   Issues found: $issues_found"
    print_color $CYAN "   Fixes applied: $fixes_applied"
    
    if [ $issues_found -eq 0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} WiFi system is healthy!"
    elif [ $fixes_applied -gt 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Some issues were automatically resolved"
        print_color $CYAN "${INFO_SYMBOL} Consider running diagnostics again to verify fixes"
    else
        print_color $RED "${ERROR_SYMBOL} Issues detected that require manual intervention"
    fi
    
    log_diagnostic "WiFi diagnostic completed: $issues_found issues, $fixes_applied fixes"
}

# Network Connectivity Diagnostics
diagnose_network() {
    local issues_found=0
    local fixes_applied=0
    
    print_color $CYAN "${DIAGNOSTIC_SYMBOL} NeXuS Network Connectivity Diagnostics"
    print_color $CYAN "================================================="
    echo
    
    log_diagnostic "Starting network connectivity diagnostic"
    
    # 1. Check network interfaces
    print_color $YELLOW "🔍 Checking network interfaces..."
    local interfaces=$(ip link show | grep -E "(eth|wlan|wifi|wlp|enp)" | cut -d: -f2 | tr -d ' ')
    
    if [ -z "$interfaces" ]; then
        print_color $RED "${ERROR_SYMBOL} No network interfaces found"
        ((issues_found++))
    else
        print_color $GREEN "${SUCCESS_SYMBOL} Network interfaces detected:"
        for iface in $interfaces; do
            local status=$(ip link show "$iface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
            if [ "$status" = "UP" ]; then
                print_color $GREEN "   ✅ $iface: $status"
            else
                print_color $YELLOW "   ⚠️ $iface: $status"
            fi
        done
    fi
    
    # 2. Check IP addresses
    print_color $YELLOW "🔍 Checking IP address assignment..."
    local has_ip=false
    
    for iface in $interfaces; do
        local ip_addr=$(ip addr show "$iface" | grep -o "inet [0-9.]*" | cut -d' ' -f2)
        if [ -n "$ip_addr" ] && [ "$ip_addr" != "127.0.0.1" ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} $iface has IP: $ip_addr"
            has_ip=true
        fi
    done
    
    if [ "$has_ip" = false ]; then
        print_color $RED "${ERROR_SYMBOL} No IP addresses assigned"
        ((issues_found++))
        
        print_color $YELLOW "${REPAIR_SYMBOL} Attempting DHCP on active interfaces..."
        for iface in $interfaces; do
            if ip link show "$iface" | grep -q "state UP"; then
                print_color $CYAN "   Requesting DHCP for $iface..."
                if doas dhclient "$iface" >/dev/null 2>&1; then
                    sleep 3
                    local new_ip=$(ip addr show "$iface" | grep -o "inet [0-9.]*" | cut -d' ' -f2)
                    if [ -n "$new_ip" ]; then
                        print_color $GREEN "${SUCCESS_SYMBOL} DHCP successful: $new_ip"
                        log_repair "DHCP lease obtained for $iface: $new_ip"
                        ((fixes_applied++))
                        has_ip=true
                    fi
                fi
            fi
        done
    fi
    
    # 3. Check default gateway
    print_color $YELLOW "🔍 Checking default gateway..."
    local gateway=$(ip route | grep "default" | head -1 | awk '{print $3}')
    
    if [ -z "$gateway" ]; then
        print_color $RED "${ERROR_SYMBOL} No default gateway configured"
        ((issues_found++))
    else
        print_color $GREEN "${SUCCESS_SYMBOL} Default gateway: $gateway"
        
        # Test gateway connectivity
        if ping -c 1 -W 3 "$gateway" >/dev/null 2>&1; then
            print_color $GREEN "${SUCCESS_SYMBOL} Gateway is reachable"
        else
            print_color $RED "${ERROR_SYMBOL} Gateway is not reachable"
            ((issues_found++))
        fi
    fi
    
    # 4. Check DNS resolution
    print_color $YELLOW "🔍 Checking DNS resolution..."
    if [ -f /etc/resolv.conf ] && grep -q "nameserver" /etc/resolv.conf; then
        local dns_server=$(grep "nameserver" /etc/resolv.conf | head -1 | awk '{print $2}')
        print_color $GREEN "${SUCCESS_SYMBOL} DNS server configured: $dns_server"
        
        # Test DNS resolution
        if nslookup google.com >/dev/null 2>&1; then
            print_color $GREEN "${SUCCESS_SYMBOL} DNS resolution working"
        else
            print_color $RED "${ERROR_SYMBOL} DNS resolution failed"
            ((issues_found++))
            
            print_color $YELLOW "${REPAIR_SYMBOL} Attempting DNS fix..."
            echo "nameserver 8.8.8.8" | doas tee /etc/resolv.conf.nexus >/dev/null
            if nslookup google.com >/dev/null 2>&1; then
                doas mv /etc/resolv.conf.nexus /etc/resolv.conf
                print_color $GREEN "${SUCCESS_SYMBOL} DNS fixed with Google DNS"
                log_repair "DNS resolution fixed using 8.8.8.8"
                ((fixes_applied++))
            else
                doas rm -f /etc/resolv.conf.nexus
            fi
        fi
    else
        print_color $RED "${ERROR_SYMBOL} No DNS servers configured"
        ((issues_found++))
    fi
    
    # 5. Test internet connectivity
    print_color $YELLOW "🔍 Testing internet connectivity..."
    local test_sites=("8.8.8.8" "1.1.1.1" "google.com")
    local connectivity=false
    
    for site in "${test_sites[@]}"; do
        if ping -c 1 -W 5 "$site" >/dev/null 2>&1; then
            print_color $GREEN "${SUCCESS_SYMBOL} Internet connectivity confirmed ($site)"
            connectivity=true
            break
        fi
    done
    
    if [ "$connectivity" = false ]; then
        print_color $RED "${ERROR_SYMBOL} No internet connectivity"
        ((issues_found++))
    fi
    
    # Summary
    echo
    print_color $CYAN "📊 Network Diagnostic Summary:"
    print_color $CYAN "   Issues found: $issues_found"
    print_color $CYAN "   Fixes applied: $fixes_applied"
    
    if [ $issues_found -eq 0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} Network system is healthy!"
    elif [ $fixes_applied -gt 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Some network issues were automatically resolved"
    else
        print_color $RED "${ERROR_SYMBOL} Network issues detected that require manual intervention"
    fi
    
    log_diagnostic "Network diagnostic completed: $issues_found issues, $fixes_applied fixes"
}

# Audio System Diagnostics
diagnose_audio() {
    local issues_found=0
    local fixes_applied=0
    
    print_color $CYAN "${DIAGNOSTIC_SYMBOL} NeXuS Audio System Diagnostics"
    print_color $CYAN "==========================================="
    echo
    
    log_diagnostic "Starting audio system diagnostic"
    
    # 1. Check audio devices
    print_color $YELLOW "🔍 Checking audio devices..."
    if command -v aplay >/dev/null 2>&1; then
        local audio_devices=$(aplay -l 2>/dev/null | grep "card" | wc -l)
        if [ "$audio_devices" -gt 0 ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} Found $audio_devices audio device(s)"
            aplay -l 2>/dev/null | grep "card" | while read line; do
                print_color $CYAN "   $line"
            done
        else
            print_color $RED "${ERROR_SYMBOL} No audio devices found"
            ((issues_found++))
        fi
    else
        print_color $YELLOW "${WARNING_SYMBOL} ALSA utilities not available"
        ((issues_found++))
    fi
    
    # 2. Check PipeWire status
    print_color $YELLOW "🔍 Checking PipeWire audio system..."
    if command -v pipewire >/dev/null 2>&1; then
        if pgrep -x pipewire >/dev/null; then
            print_color $GREEN "${SUCCESS_SYMBOL} PipeWire is running"
            
            # Check WirePlumber
            if pgrep -x wireplumber >/dev/null; then
                print_color $GREEN "${SUCCESS_SYMBOL} WirePlumber is running"
            else
                print_color $YELLOW "${WARNING_SYMBOL} WirePlumber not running"
                ((issues_found++))
                
                print_color $YELLOW "${REPAIR_SYMBOL} Starting WirePlumber..."
                if wireplumber >/dev/null 2>&1 & then
                    sleep 2
                    if pgrep -x wireplumber >/dev/null; then
                        print_color $GREEN "${SUCCESS_SYMBOL} WirePlumber started"
                        log_repair "WirePlumber audio session manager started"
                        ((fixes_applied++))
                    fi
                fi
            fi
            
            # Check pipewire-pulse
            if pgrep -f "pipewire-pulse" >/dev/null; then
                print_color $GREEN "${SUCCESS_SYMBOL} PipeWire PulseAudio compatibility running"
            else
                print_color $YELLOW "${WARNING_SYMBOL} PipeWire PulseAudio compatibility not running"
                ((issues_found++))
                
                print_color $YELLOW "${REPAIR_SYMBOL} Starting PipeWire PulseAudio..."
                if pipewire-pulse >/dev/null 2>&1 & then
                    sleep 2
                    if pgrep -f "pipewire-pulse" >/dev/null; then
                        print_color $GREEN "${SUCCESS_SYMBOL} PipeWire PulseAudio started"
                        log_repair "PipeWire PulseAudio compatibility started"
                        ((fixes_applied++))
                    fi
                fi
            fi
        else
            print_color $RED "${ERROR_SYMBOL} PipeWire not running"
            ((issues_found++))
            
            print_color $YELLOW "${REPAIR_SYMBOL} Starting PipeWire..."
            if pipewire >/dev/null 2>&1 & then
                sleep 2
                if pgrep -x pipewire >/dev/null; then
                    print_color $GREEN "${SUCCESS_SYMBOL} PipeWire started"
                    log_repair "PipeWire audio server started"
                    ((fixes_applied++))
                    
                    # Start related services
                    wireplumber >/dev/null 2>&1 &
                    pipewire-pulse >/dev/null 2>&1 &
                    sleep 2
                fi
            fi
        fi
    else
        print_color $YELLOW "${WARNING_SYMBOL} PipeWire not available"
    fi
    
    # 3. Check PulseAudio (if no PipeWire)
    if ! pgrep -x pipewire >/dev/null && command -v pulseaudio >/dev/null 2>&1; then
        print_color $YELLOW "🔍 Checking PulseAudio..."
        if pgrep -x pulseaudio >/dev/null; then
            print_color $GREEN "${SUCCESS_SYMBOL} PulseAudio is running"
        else
            print_color $YELLOW "${WARNING_SYMBOL} PulseAudio not running"
            ((issues_found++))
            
            print_color $YELLOW "${REPAIR_SYMBOL} Starting PulseAudio..."
            if pulseaudio --start >/dev/null 2>&1; then
                sleep 2
                if pgrep -x pulseaudio >/dev/null; then
                    print_color $GREEN "${SUCCESS_SYMBOL} PulseAudio started"
                    log_repair "PulseAudio started successfully"
                    ((fixes_applied++))
                fi
            fi
        fi
    fi
    
    # 4. Test audio output
    print_color $YELLOW "🔍 Testing audio output..."
    if command -v speaker-test >/dev/null 2>&1; then
        print_color $CYAN "${INFO_SYMBOL} Running quick audio test (2 seconds)..."
        if timeout 2 speaker-test -t sine -f 1000 -c 2 >/dev/null 2>&1; then
            print_color $GREEN "${SUCCESS_SYMBOL} Audio output test successful"
        else
            print_color $YELLOW "${WARNING_SYMBOL} Audio test inconclusive"
            ((issues_found++))
        fi
    fi
    
    # 5. Check volume levels
    if command -v amixer >/dev/null 2>&1; then
        print_color $YELLOW "🔍 Checking volume levels..."
        local master_vol=$(amixer get Master 2>/dev/null | grep -o "\[.*%\]" | head -1 | tr -d '[]%')
        
        if [ -n "$master_vol" ]; then
            if [ "$master_vol" -eq 0 ]; then
                print_color $RED "${ERROR_SYMBOL} Master volume is muted/zero"
                ((issues_found++))
                
                print_color $YELLOW "${REPAIR_SYMBOL} Setting master volume to 50%..."
                if amixer set Master 50% unmute >/dev/null 2>&1; then
                    print_color $GREEN "${SUCCESS_SYMBOL} Master volume set to 50%"
                    log_repair "Master audio volume restored to 50%"
                    ((fixes_applied++))
                fi
            else
                print_color $GREEN "${SUCCESS_SYMBOL} Master volume: ${master_vol}%"
            fi
        fi
    fi
    
    # Summary
    echo
    print_color $CYAN "📊 Audio Diagnostic Summary:"
    print_color $CYAN "   Issues found: $issues_found"
    print_color $CYAN "   Fixes applied: $fixes_applied"
    
    if [ $issues_found -eq 0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} Audio system is healthy!"
    elif [ $fixes_applied -gt 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Some audio issues were automatically resolved"
    else
        print_color $RED "${ERROR_SYMBOL} Audio issues detected that require manual intervention"
    fi
    
    log_diagnostic "Audio diagnostic completed: $issues_found issues, $fixes_applied fixes"
}

# Backup System Diagnostics
diagnose_backups() {
    local issues_found=0
    local fixes_applied=0
    
    print_color $CYAN "${DIAGNOSTIC_SYMBOL} NeXuS Backup System Diagnostics"
    print_color $CYAN "=========================================="
    echo
    
    log_diagnostic "Starting backup system diagnostic"
    
    # 1. Check backup directory structure
    print_color $YELLOW "🔍 Checking backup directory structure..."
    local backup_root="/home/user/.nexus-backups"
    
    if [ ! -d "$backup_root" ]; then
        print_color $RED "${ERROR_SYMBOL} Backup root directory missing"
        ((issues_found++))
        
        print_color $YELLOW "${REPAIR_SYMBOL} Creating backup directory structure..."
        if /home/user/scripts/nexus-backup-system.sh structure >/dev/null 2>&1; then
            print_color $GREEN "${SUCCESS_SYMBOL} Backup structure created"
            log_repair "Backup directory structure initialized"
            ((fixes_applied++))
        fi
    else
        print_color $GREEN "${SUCCESS_SYMBOL} Backup root directory exists"
        
        # Check subdirectories
        local required_dirs=("configs" "scripts" "snippets" "documents")
        for dir in "${required_dirs[@]}"; do
            if [ ! -d "$backup_root/$dir" ]; then
                print_color $YELLOW "${WARNING_SYMBOL} Missing backup subdirectory: $dir"
                mkdir -p "$backup_root/$dir"
                ((fixes_applied++))
            fi
        done
    fi
    
    # 2. Check recent backups
    print_color $YELLOW "🔍 Checking recent backup activity..."
    local recent_backups=$(find "$backup_root" -name "BACKUP_MANIFEST_*.txt" -mtime -7 2>/dev/null | wc -l)
    
    if [ "$recent_backups" -eq 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} No recent backups found (last 7 days)"
        ((issues_found++))
        
        print_color $CYAN "${INFO_SYMBOL} Consider running: nexus-backup-system.sh create"
    else
        print_color $GREEN "${SUCCESS_SYMBOL} Found $recent_backups recent backup(s)"
    fi
    
    # 3. Check backup scripts
    print_color $YELLOW "🔍 Checking backup scripts..."
    local backup_scripts=(
        "/home/user/scripts/nexus-backup-system.sh"
        "/home/user/scripts/nexus-backup-encrypt.sh"
        "/home/user/scripts/nexus-backup-scheduler.sh"
    )
    
    for script in "${backup_scripts[@]}"; do
        if [ ! -x "$script" ]; then
            print_color $RED "${ERROR_SYMBOL} Missing or non-executable: $(basename "$script")"
            ((issues_found++))
        else
            print_color $GREEN "${SUCCESS_SYMBOL} $(basename "$script") is executable"
        fi
    done
    
    # 4. Check scheduled backups
    print_color $YELLOW "🔍 Checking automated backup schedule..."
    if crontab -l 2>/dev/null | grep -q "nexus-backup-cron.sh"; then
        print_color $GREEN "${SUCCESS_SYMBOL} Automated backups are scheduled"
        local schedule=$(crontab -l 2>/dev/null | grep "nexus-backup-cron.sh" | awk '{print $1" "$2" "$3" "$4" "$5}')
        print_color $CYAN "   Schedule: $schedule"
    else
        print_color $YELLOW "${WARNING_SYMBOL} No automated backup schedule found"
        print_color $CYAN "${INFO_SYMBOL} Consider running: nexus-backup-scheduler.sh setup"
    fi
    
    # 5. Check encryption capability
    print_color $YELLOW "🔍 Checking backup encryption capability..."
    if command -v age >/dev/null 2>&1; then
        print_color $GREEN "${SUCCESS_SYMBOL} Age encryption available"
        
        # Check encrypted backups
        local encrypted_dir="/home/user/encrypted-backups"
        if [ -d "$encrypted_dir" ]; then
            local encrypted_count=$(find "$encrypted_dir" -name "*.age" 2>/dev/null | wc -l)
            if [ "$encrypted_count" -gt 0 ]; then
                print_color $GREEN "${SUCCESS_SYMBOL} Found $encrypted_count encrypted backup(s)"
            else
                print_color $CYAN "${INFO_SYMBOL} No encrypted backups found"
            fi
        fi
    else
        print_color $RED "${ERROR_SYMBOL} Age encryption not available"
        ((issues_found++))
        print_color $CYAN "${INFO_SYMBOL} Install with: doas apk add age"
    fi
    
    # 6. Check disk space
    print_color $YELLOW "🔍 Checking backup storage space..."
    local backup_size=$(du -sh "$backup_root" 2>/dev/null | cut -f1 || echo "0")
    local available_space=$(df -h "$(dirname "$backup_root")" | awk 'NR==2 {print $4}')
    
    print_color $GREEN "${SUCCESS_SYMBOL} Backup size: $backup_size"
    print_color $GREEN "${SUCCESS_SYMBOL} Available space: $available_space"
    
    # Summary
    echo
    print_color $CYAN "📊 Backup System Diagnostic Summary:"
    print_color $CYAN "   Issues found: $issues_found"
    print_color $CYAN "   Fixes applied: $fixes_applied"
    
    if [ $issues_found -eq 0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} Backup system is healthy!"
    elif [ $fixes_applied -gt 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Some backup issues were automatically resolved"
    else
        print_color $RED "${ERROR_SYMBOL} Backup issues detected that require attention"
    fi
    
    log_diagnostic "Backup system diagnostic completed: $issues_found issues, $fixes_applied fixes"
}

# Quick system health check
quick_health_check() {
    print_color $CYAN "${BRAIN_SYMBOL} NeXuS Quick Health Check"
    print_color $CYAN "============================="
    echo
    
    local total_issues=0
    local total_fixes=0
    
    # CPU and Memory
    print_color $YELLOW "🔍 System Resources..."
    local cpu_usage=$(top -bn1 | grep "load average" | awk '{print $10}' | cut -d, -f1)
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    
    print_color $GREEN "${SUCCESS_SYMBOL} CPU Load: $cpu_usage"
    print_color $GREEN "${SUCCESS_SYMBOL} Memory Usage: ${mem_usage}%"
    
    # Disk Usage
    print_color $YELLOW "🔍 Disk Usage..."
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_usage" -gt 90 ]; then
        print_color $RED "${ERROR_SYMBOL} Disk usage critical: ${disk_usage}%"
        ((total_issues++))
    elif [ "$disk_usage" -gt 80 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Disk usage high: ${disk_usage}%"
    else
        print_color $GREEN "${SUCCESS_SYMBOL} Disk usage: ${disk_usage}%"
    fi
    
    # Services
    print_color $YELLOW "🔍 Essential Services..."
    local services=("crond")
    for service in "${services[@]}"; do
        if pgrep -x "$service" >/dev/null; then
            print_color $GREEN "${SUCCESS_SYMBOL} $service is running"
        else
            print_color $RED "${ERROR_SYMBOL} $service is not running"
            ((total_issues++))
        fi
    done
    
    # Network connectivity
    print_color $YELLOW "🔍 Network Connectivity..."
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        print_color $GREEN "${SUCCESS_SYMBOL} Internet connectivity OK"
    else
        print_color $RED "${ERROR_SYMBOL} No internet connectivity"
        ((total_issues++))
    fi
    
    echo
    if [ $total_issues -eq 0 ]; then
        print_color $GREEN "${ROCKET_SYMBOL} NeXuS System is running optimally!"
    else
        print_color $YELLOW "${WARNING_SYMBOL} $total_issues issue(s) detected"
        print_color $CYAN "${INFO_SYMBOL} Run specific diagnostics for detailed analysis"
    fi
}

# Generate diagnostic report
generate_report() {
    local report_file="$DIAGNOSTIC_REPORTS/nexus-diagnostic-$(date +%Y%m%d_%H%M%S).md"
    
    print_color $CYAN "${DIAGNOSTIC_SYMBOL} Generating comprehensive diagnostic report..."
    
    cat > "$report_file" << EOF
# NeXuS System Diagnostic Report
**Generated:** $(date)
**System:** $(uname -a)
**User:** $(whoami)

---

## System Overview
EOF
    
    # Add system information
    {
        echo "### Hardware Information"
        echo "\`\`\`"
        lscpu | head -20
        echo "\`\`\`"
        echo
        echo "### Memory Information"
        echo "\`\`\`"
        free -h
        echo "\`\`\`"
        echo
        echo "### Disk Usage"
        echo "\`\`\`"
        df -h
        echo "\`\`\`"
        echo
    } >> "$report_file"
    
    print_color $GREEN "${SUCCESS_SYMBOL} Diagnostic report generated: $report_file"
    print_color $CYAN "${INFO_SYMBOL} View with: cat \"$report_file\""
}

# Main diagnostic menu
show_main_menu() {
    show_banner
    print_color $WHITE "🧠 NeXuS Smart Diagnostic System"
    echo
    print_color $CYAN "Select diagnostic module:"
    echo
    echo -e "${GREEN}1.${NC} ${FIRE_SYMBOL} Quick Health Check"
    echo -e "${GREEN}2.${NC} 📶 WiFi Diagnostics & Auto-Repair"
    echo -e "${GREEN}3.${NC} 🌐 Network Connectivity Diagnostics"
    echo -e "${GREEN}4.${NC} 🔊 Audio System Diagnostics"
    echo -e "${GREEN}5.${NC} 💾 Backup System Diagnostics"
    echo -e "${GREEN}6.${NC} 🖥️ Terminal/Tmux Diagnostics"
    echo -e "${GREEN}7.${NC} 📊 System Performance Analysis"
    echo -e "${GREEN}8.${NC} 📋 Generate Full Diagnostic Report"
    echo -e "${GREEN}L.${NC} 📝 View Diagnostic Logs"
    echo -e "${GREEN}H.${NC} 📖 Help & Documentation"
    echo -e "${GREEN}Q.${NC} 🚪 Quit"
    echo
}

# Show help
show_help() {
    show_banner
    print_color $WHITE "NeXuS Smart Diagnostic System Help"
    print_color $CYAN "=================================="
    echo
    
    cat << 'EOF'
The NeXuS Smart Diagnostic System provides intelligent troubleshooting
and automatic repair capabilities for common system issues.

FEATURES:
🧠 Intelligent problem detection
🔧 Automatic repair attempts  
📊 Comprehensive system analysis
📋 Detailed diagnostic reports
📝 Complete activity logging

DIAGNOSTIC MODULES:
📶 WiFi - Interface detection, driver issues, connectivity problems
🌐 Network - IP assignment, gateway, DNS, internet connectivity
🔊 Audio - PipeWire, PulseAudio, device detection, volume levels
💾 Backup - Directory structure, script integrity, scheduled backups
🖥️ Display - Framebuffer, Qt/kmscon conflicts, input issues
🖥️ Terminal - Tmux, shell configuration, display issues
📊 Performance - CPU, memory, disk usage, system resources

USAGE:
- Run diagnostics when experiencing issues
- Use Quick Health Check for routine monitoring
- Enable auto-repair for common problems
- Generate reports for troubleshooting history

LOG FILES:
EOF

    print_color $CYAN "Diagnostic Log: $DIAGNOSTIC_LOG"
    print_color $CYAN "Repair Log: $REPAIR_LOG"
    print_color $CYAN "Reports: $DIAGNOSTIC_REPORTS/"
    
    echo
    print_color $YELLOW "💡 Tip: Run diagnostics regularly to maintain system health"
}

# Framebuffer Display Diagnostic - Based on 2025-09-25 breakthrough session
diagnose_framebuffer_display() {
    print_color $BLUE "${DIAGNOSTIC_SYMBOL} NeXuS Framebuffer Display Diagnostic ${DIAGNOSTIC_SYMBOL}"
    print_color $CYAN "Advanced display troubleshooting for Qt/kmscon environments"
    echo
    
    log_diagnostic "Starting framebuffer display diagnostic"
    
    local issues_found=0
    local repairs_available=0
    
    # Phase 1: Display Environment Analysis
    print_color $YELLOW "📊 PHASE 1: Display Environment Analysis"
    echo "════════════════════════════════════════"
    
    # Check framebuffer device
    if [ -e /dev/fb0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} Framebuffer device: /dev/fb0 available"
        if command -v fbset >/dev/null 2>&1; then
            local fb_info=$(fbset 2>/dev/null | head -3)
            echo "  Current resolution: $(echo "$fb_info" | grep 'mode' | awk '{print $2}' | tr -d '"')"
        fi
    else
        print_color $RED "${ERROR_SYMBOL} No framebuffer device found (/dev/fb0 missing)"
        ((issues_found++))
    fi
    
    # Check Qt platform configuration
    echo
    print_color $BLUE "🖥️ Qt Platform Configuration:"
    echo "  QT_QPA_PLATFORM: ${QT_QPA_PLATFORM:-not set}"
    echo "  QT_QPA_FB_FORCE_FULLSCREEN: ${QT_QPA_FB_FORCE_FULLSCREEN:-not set}"
    echo "  QT_QPA_EGLFS_FORCE444: ${QT_QPA_EGLFS_FORCE444:-not set}"
    
    # Check for competing display services
    echo
    print_color $YELLOW "🔍 PHASE 2: Display Service Competition Analysis"
    echo "════════════════════════════════════════════════"
    
    # Check kmscon
    local kmscon_pid=$(pgrep kmscon 2>/dev/null)
    if [ -n "$kmscon_pid" ]; then
        local kmscon_cmd=$(ps -p $kmscon_pid -o args --no-headers 2>/dev/null)
        print_color $GREEN "${SUCCESS_SYMBOL} kmscon running (PID: $kmscon_pid)"
        echo "  Command: $kmscon_cmd"
        if echo "$kmscon_cmd" | grep -q "hwacc"; then
            print_color $GREEN "  ${SUCCESS_SYMBOL} Hardware acceleration enabled"
        fi
    else
        print_color $BLUE "${INFO_SYMBOL} kmscon not running (direct framebuffer mode)"
    fi
    
    # Check for Sxmo interference
    if command -v sxmo_version.sh >/dev/null 2>&1 || [ -f /etc/profile.d/sxmo_init.sh ]; then
        print_color $RED "${ERROR_SYMBOL} Sxmo components detected - may interfere with framebuffer"
        print_color $YELLOW "  Sxmo files found:"
        [ -f /etc/profile.d/sxmo_init.sh ] && echo "    /etc/profile.d/sxmo_init.sh"
        [ -f /etc/modprobe.d/sxmo.conf ] && echo "    /etc/modprobe.d/sxmo.conf"
        ((issues_found++))
        ((repairs_available++))
    else
        print_color $GREEN "${SUCCESS_SYMBOL} No Sxmo interference detected"
    fi
    
    # Check tmux competition
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | wc -l)
    if [ "$tmux_sessions" -gt 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} tmux sessions active ($tmux_sessions)"
        echo "  May compete with Qt framebuffer - consider detaching: tmux detach-client -a"
    fi
    
    # Phase 3: Service Interference Check
    echo
    print_color $YELLOW "🔧 PHASE 3: Service Interference Analysis"
    echo "══════════════════════════════════════════"
    
    # Check PipeWire status (known to cause display interruptions)
    local pipewire_status=$(rc-service pipewire status 2>/dev/null | grep -o "started\|stopped\|crashed" || echo "unknown")
    case "$pipewire_status" in
        "crashed")
            print_color $RED "${ERROR_SYMBOL} PipeWire service crashed - causes display interruptions"
            ((issues_found++))
            ((repairs_available++))
            ;;
        "started")
            print_color $YELLOW "${WARNING_SYMBOL} PipeWire running - monitor for display interruptions"
            ;;
        "stopped")
            print_color $GREEN "${SUCCESS_SYMBOL} PipeWire stopped - no audio interference"
            ;;
    esac
    
    # Phase 4: Input/Display Conflict Detection
    echo
    print_color $YELLOW "⌨️ PHASE 4: Input/Display Conflict Detection"
    echo "══════════════════════════════════════════════"
    
    # Check cursor blink setting
    if [ -r /sys/class/graphics/fbcon/cursor_blink ]; then
        local cursor_blink=$(cat /sys/class/graphics/fbcon/cursor_blink 2>/dev/null)
        if [ "$cursor_blink" = "0" ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} Cursor blink disabled (prevents refresh conflicts)"
        else
            print_color $YELLOW "${WARNING_SYMBOL} Cursor blink enabled (may cause input conflicts)"
            ((repairs_available++))
        fi
    fi
    
    # Check console blanking
    if [ -r /sys/module/kernel/parameters/consoleblank ]; then
        local consoleblank=$(cat /sys/module/kernel/parameters/consoleblank 2>/dev/null)
        if [ "$consoleblank" = "0" ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} Console blanking disabled"
        else
            print_color $YELLOW "${WARNING_SYMBOL} Console blanking: $consoleblank (recommend 0)"
        fi
    fi
    
    # Phase 5: Qt Platform Compatibility
    echo
    print_color $YELLOW "🎨 PHASE 5: Qt Platform Compatibility Assessment"
    echo "═════════════════════════════════════════════════"
    
    # Check available Qt platforms
    local qt_platforms=("linuxfb" "eglfs" "minimal" "minimalegl" "offscreen")
    for platform in "${qt_platforms[@]}"; do
        if [ -f "/usr/lib/qt5/plugins/platforms/libq${platform//-/}.so" ] || [ -f "/usr/lib/qt6/plugins/platforms/libq${platform//-/}.so" ]; then
            print_color $GREEN "${SUCCESS_SYMBOL} Qt platform available: $platform"
        else
            print_color $RED "${ERROR_SYMBOL} Qt platform missing: $platform"
        fi
    done
    
    # Recommend best platform based on environment
    echo
    print_color $CYAN "💡 Platform Recommendations:"
    if [ -n "$kmscon_pid" ]; then
        print_color $GREEN "  ✓ For kmscon: Use eglfs platform (QT_QPA_PLATFORM=eglfs)"
        print_color $GREEN "  ✓ Enable: QT_QPA_EGLFS_FORCE444=1 and QT_QPA_EGLFS_DISABLE_INPUT=1"
    else
        print_color $GREEN "  ✓ For direct framebuffer: Use linuxfb platform (QT_QPA_PLATFORM=linuxfb)"
        print_color $GREEN "  ✓ Disable fullscreen: QT_QPA_FB_FORCE_FULLSCREEN=0"
    fi
    
    # Phase 6: Auto-Repair Options
    echo
    print_color $YELLOW "${REPAIR_SYMBOL} PHASE 6: Auto-Repair Options Available"
    echo "═══════════════════════════════════════════════"
    
    if [ $repairs_available -gt 0 ]; then
        print_color $CYAN "Available automatic repairs:"
        echo "  1. Fix PipeWire service interference"
        echo "  2. Configure optimal Qt platform settings"
        echo "  3. Disable cursor blink and screen blanking"
        echo "  4. Clean up Sxmo remnants (requires root)"
        echo
        read -p "Apply auto-repairs? (y/n): " apply_repairs
        
        if [[ $apply_repairs =~ ^[Yy]$ ]]; then
            apply_framebuffer_repairs
        fi
    else
        print_color $GREEN "${SUCCESS_SYMBOL} No repairs needed - system optimally configured!"
    fi
    
    # Summary
    echo
    print_color $CYAN "📋 DIAGNOSTIC SUMMARY"
    echo "═══════════════════════"
    if [ $issues_found -eq 0 ]; then
        print_color $GREEN "${SUCCESS_SYMBOL} Framebuffer display system: HEALTHY"
        print_color $GREEN "Your dual-terminal setup is optimally configured!"
    else
        print_color $YELLOW "${WARNING_SYMBOL} Issues found: $issues_found"
        print_color $CYAN "Run auto-repairs or check /home/user/scripts/fix-framebuffer-input.sh"
    fi
    
    log_diagnostic "Framebuffer diagnostic completed: $issues_found issues found, $repairs_available repairs available"
}

# Apply automatic framebuffer repairs
apply_framebuffer_repairs() {
    print_color $BLUE "${REPAIR_SYMBOL} Applying Framebuffer Auto-Repairs..."
    echo
    
    local repairs_applied=0
    
    # Check if we have root access
    if [ "$EUID" -ne 0 ]; then
        print_color $YELLOW "${WARNING_SYMBOL} Some repairs require root access"
        print_color $CYAN "Available repairs without root:"
    fi
    
    # Repair 1: Configure Qt platform for current environment
    print_color $YELLOW "1. Configuring Qt platform..."
    local backup_file="$HOME/.profile.backup-nexus-$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$HOME/.profile" ]; then
        cp "$HOME/.profile" "$backup_file"
        print_color $GREEN "  ✓ Profile backed up: $backup_file"
    fi
    
    # Detect optimal Qt configuration
    if pgrep kmscon >/dev/null; then
        # kmscon running - use eglfs
        export QT_QPA_PLATFORM=eglfs
        export QT_QPA_EGLFS_FORCE444=1
        export QT_QPA_EGLFS_DISABLE_INPUT=1
        export QT_QPA_FONTDIR=/usr/share/fonts
        
        echo "# NeXuS Framebuffer Auto-Config (kmscon compatible) - $(date)" >> "$HOME/.profile"
        echo "export QT_QPA_PLATFORM=eglfs" >> "$HOME/.profile"
        echo "export QT_QPA_EGLFS_FORCE444=1" >> "$HOME/.profile" 
        echo "export QT_QPA_EGLFS_DISABLE_INPUT=1" >> "$HOME/.profile"
        echo "export QT_QPA_FONTDIR=/usr/share/fonts" >> "$HOME/.profile"
        
        print_color $GREEN "  ✓ Configured Qt for kmscon compatibility (eglfs platform)"
    else
        # Direct framebuffer - use linuxfb
        export QT_QPA_PLATFORM=linuxfb
        export QT_QPA_FB_FORCE_FULLSCREEN=0
        export QT_QPA_FONTDIR=/usr/share/fonts
        
        echo "# NeXuS Framebuffer Auto-Config (direct framebuffer) - $(date)" >> "$HOME/.profile"
        echo "export QT_QPA_PLATFORM=linuxfb" >> "$HOME/.profile"
        echo "export QT_QPA_FB_FORCE_FULLSCREEN=0" >> "$HOME/.profile"
        echo "export QT_QPA_FONTDIR=/usr/share/fonts" >> "$HOME/.profile"
        
        print_color $GREEN "  ✓ Configured Qt for direct framebuffer (linuxfb platform)"
    fi
    ((repairs_applied++))
    
    # Repair 2: Service management (if root)
    if [ "$EUID" -eq 0 ]; then
        print_color $YELLOW "2. Managing interfering services..."
        
        # Stop crashed PipeWire if needed
        if rc-service pipewire status 2>/dev/null | grep -q "crashed"; then
            rc-service pipewire stop 2>/dev/null
            rc-update del pipewire 2>/dev/null
            print_color $GREEN "  ✓ Stopped crashed PipeWire service"
            ((repairs_applied++))
        fi
        
        # Fix cursor blink
        if [ -w /sys/class/graphics/fbcon/cursor_blink ]; then
            echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null
            print_color $GREEN "  ✓ Disabled cursor blink"
            ((repairs_applied++))
        fi
        
    else
        print_color $CYAN "2. Root-level repairs available:"
        print_color $CYAN "   Run: sudo /home/user/scripts/fix-framebuffer-input.sh"
    fi
    
    print_color $GREEN "${SUCCESS_SYMBOL} Auto-repairs completed: $repairs_applied fixes applied"
    print_color $CYAN "💡 Restart terminal or source ~/.profile to activate changes"
    
    log_repair "Framebuffer auto-repairs applied: $repairs_applied fixes"
}

# Main program loop
main() {
    init_diagnostics
    
    case "${1:-menu}" in
        "wifi"|"w")
            show_banner
            diagnose_wifi
            ;;
        "network"|"net"|"n")
            show_banner
            diagnose_network
            ;;
        "audio"|"sound"|"a")
            show_banner
            diagnose_audio
            ;;
        "backup"|"backups"|"b")
            show_banner
            diagnose_backups
            ;;
        "display"|"framebuffer"|"d")
            show_banner
            diagnose_framebuffer_display
            ;;
        "health"|"quick"|"q")
            show_banner
            quick_health_check
            ;;
        "report"|"r")
            show_banner
            generate_report
            ;;
        "logs"|"log"|"l")
            print_color $CYAN "📝 Recent Diagnostic Activity:"
            echo
            if [ -f "$DIAGNOSTIC_LOG" ]; then
                tail -20 "$DIAGNOSTIC_LOG"
            else
                print_color $YELLOW "No diagnostic logs found"
            fi
            ;;
        "help"|"h")
            show_help
            ;;
        "menu"|*)
            while true; do
                show_main_menu
                read -p "Select option: " choice
                
                case "$choice" in
                    1) clear; quick_health_check; read -p "Press any key..." -n 1 ;;
                    2) clear; diagnose_wifi; read -p "Press any key..." -n 1 ;;
                    3) clear; diagnose_network; read -p "Press any key..." -n 1 ;;
                    4) clear; diagnose_audio; read -p "Press any key..." -n 1 ;;
                    5) clear; diagnose_backups; read -p "Press any key..." -n 1 ;;
                    6) print_color $YELLOW "Terminal diagnostics coming soon..."; sleep 2 ;;
                    7) print_color $YELLOW "Performance analysis coming soon..."; sleep 2 ;;
                    8) clear; generate_report; read -p "Press any key..." -n 1 ;;
                    [Ll]) clear; main logs; read -p "Press any key..." -n 1 ;;
                    [Hh]) clear; show_help; read -p "Press any key..." -n 1 ;;
                    [Qq]|"") print_color $GREEN "${NEXUS_SYMBOL} NeXuS diagnostics complete!"; exit 0 ;;
                    *) print_color $RED "Invalid option"; sleep 1 ;;
                esac
            done
            ;;
    esac
}

main "$@"