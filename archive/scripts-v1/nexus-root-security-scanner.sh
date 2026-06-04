#!/bin/bash

# NeXuS Root Security Scanner
# Comprehensive security audit of all root processes and services
# Identifies potential security risks and privilege escalation issues

set -e

# Fire aesthetics for NeXuS
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="/tmp/nexus-security-report-$(date +%Y%m%d-%H%M%S).log"

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

print_critical() {
    echo -e "${RED}🚨 CRITICAL: $1${NC}"
}

print_high() {
    echo -e "${PURPLE}🔴 HIGH: $1${NC}"
}

print_medium() {
    echo -e "${YELLOW}🟡 MEDIUM: $1${NC}"
}

print_low() {
    echo -e "${CYAN}🔵 LOW: $1${NC}"
}

log_to_report() {
    echo "$1" >> "$REPORT_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}           🔒 NeXuS ROOT SECURITY SCANNER 🔒            ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}      Comprehensive Root Process Security Audit          ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}         Identify Privilege Escalation Risks             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Known services that should run as root (whitelist)
EXPECTED_ROOT_SERVICES=(
    "systemd"
    "kthreadd"
    "rcu_"
    "migration"
    "ksoftirqd"
    "watchdog"
    "sshd"
    "dbus"
    "NetworkManager"
    "systemd-"
    "kernel"
    "init"
    "kworker"
    "ksmd"
    "khugepaged"
    "crypto"
    "irq/"
    "acpi"
    "usb"
    "scsi"
    "md"
    "raid"
    "ext4"
    "jbd2"
    "flush"
    "bioset"
    "kblockd"
    "ata_sff"
    "kvm"
    "vhost"
    "chronyd"
    "crond"
    "rsyslog"
    "udevd"
    "polkit"
    "lightdm"
    "gdm"
    "sddm"
    "doas"
    "sudo"
)

# Services that should NEVER run as root (blacklist)
DANGEROUS_ROOT_SERVICES=(
    "tor"
    "firefox"
    "chrome"
    "chromium"
    "node"
    "npm"
    "python"
    "java"
    "ruby"
    "perl"
    "php"
    "apache"
    "nginx"
    "mysql"
    "postgres"
    "redis"
    "memcached"
    "mongodb"
    "elasticsearch"
    "docker"
    "qemu"
    "virtualbox"
    "wine"
    "steam"
    "discord"
    "slack"
    "spotify"
    "vlc"
    "mpv"
    "gimp"
    "libreoffice"
    "thunderbird"
    "transmission"
    "deluge"
    "rtorrent"
    "aria2"
)

is_expected_root_service() {
    local process="$1"
    for service in "${EXPECTED_ROOT_SERVICES[@]}"; do
        if [[ "$process" == *"$service"* ]]; then
            return 0
        fi
    done
    return 1
}

is_dangerous_root_service() {
    local process="$1"
    for service in "${DANGEROUS_ROOT_SERVICES[@]}"; do
        if [[ "$process" == *"$service"* ]]; then
            return 0
        fi
    done
    return 1
}

scan_root_processes() {
    print_status "Scanning all root processes..."
    echo
    
    local critical_count=0
    local high_count=0
    local medium_count=0
    local safe_count=0
    
    log_to_report "=== NeXuS Root Security Scan Report ==="
    log_to_report "Date: $(date)"
    log_to_report "System: $(uname -a)"
    log_to_report ""
    log_to_report "=== ROOT PROCESS ANALYSIS ==="
    
    # Get all root processes
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
        local process_name=$(echo "$cmd" | awk '{print $1}' | xargs basename)
        
        # Skip if empty
        [[ -z "$cmd" ]] && continue
        
        # Analyze security risk
        if is_dangerous_root_service "$cmd"; then
            print_critical "DANGEROUS: $process_name (PID: $pid)"
            echo -e "${RED}   Command: $cmd${NC}"
            echo -e "${RED}   Risk: Application should NEVER run as root${NC}"
            log_to_report "CRITICAL: $cmd (PID: $pid) - Should never run as root"
            ((critical_count++))
            echo
        elif is_expected_root_service "$cmd"; then
            print_success "SAFE: $process_name (PID: $pid)"
            echo -e "${GREEN}   Command: $cmd${NC}"
            echo -e "${GREEN}   Status: Expected system service${NC}"
            log_to_report "SAFE: $cmd (PID: $pid) - Expected system service"
            ((safe_count++))
        else
            # Unknown root process - needs investigation
            if [[ "$cmd" == *"doas"* ]] || [[ "$cmd" == *"sudo"* ]]; then
                print_high "INVESTIGATE: $process_name (PID: $pid)"
                echo -e "${PURPLE}   Command: $cmd${NC}"
                echo -e "${PURPLE}   Risk: Privilege escalation tool - check what it's running${NC}"
                log_to_report "HIGH: $cmd (PID: $pid) - Privilege escalation tool"
                ((high_count++))
            elif [[ "$cmd" == *"script"* ]] || [[ "$cmd" == *".sh"* ]]; then
                print_medium "REVIEW: $process_name (PID: $pid)"
                echo -e "${YELLOW}   Command: $cmd${NC}"
                echo -e "${YELLOW}   Risk: Script running as root - verify necessity${NC}"
                log_to_report "MEDIUM: $cmd (PID: $pid) - Script with root privileges"
                ((medium_count++))
            else
                print_medium "UNKNOWN: $process_name (PID: $pid)"
                echo -e "${YELLOW}   Command: $cmd${NC}"
                echo -e "${YELLOW}   Risk: Unknown application with root privileges${NC}"
                log_to_report "MEDIUM: $cmd (PID: $pid) - Unknown root process"
                ((medium_count++))
            fi
        fi
        echo
    done < <(ps aux | grep "^root" | grep -v "\[")
    
    # Summary
    echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                    SECURITY SCAN SUMMARY                   ║${NC}"
    echo -e "${WHITE}╠════════════════════════════════════════════════════════════╣${NC}"
    
    if [[ $critical_count -gt 0 ]]; then
        echo -e "${WHITE}║ ${RED}🚨 CRITICAL ISSUES: $critical_count${NC}$(printf "%*s" $((42-${#critical_count})) "")${WHITE}║${NC}"
    fi
    if [[ $high_count -gt 0 ]]; then
        echo -e "${WHITE}║ ${PURPLE}🔴 HIGH RISK:       $high_count${NC}$(printf "%*s" $((42-${#high_count})) "")${WHITE}║${NC}"
    fi
    if [[ $medium_count -gt 0 ]]; then
        echo -e "${WHITE}║ ${YELLOW}🟡 MEDIUM RISK:     $medium_count${NC}$(printf "%*s" $((42-${#medium_count})) "")${WHITE}║${NC}"
    fi
    echo -e "${WHITE}║ ${GREEN}✅ SAFE PROCESSES:  $safe_count${NC}$(printf "%*s" $((42-${#safe_count})) "")${WHITE}║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    log_to_report ""
    log_to_report "=== SUMMARY ==="
    log_to_report "Critical Issues: $critical_count"
    log_to_report "High Risk: $high_count"
    log_to_report "Medium Risk: $medium_count"
    log_to_report "Safe Processes: $safe_count"
}

scan_suid_binaries() {
    print_status "Scanning SUID/SGID binaries..."
    echo
    
    log_to_report ""
    log_to_report "=== SUID/SGID BINARY ANALYSIS ==="
    
    # Find SUID binaries
    local suid_files=$(find /usr /bin /sbin 2>/dev/null -perm -4000 -type f 2>/dev/null || true)
    local sgid_files=$(find /usr /bin /sbin 2>/dev/null -perm -2000 -type f 2>/dev/null || true)
    
    echo -e "${CYAN}🔍 SUID Binaries (run as owner):${NC}"
    if [[ -n "$suid_files" ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                local perms=$(ls -la "$file" | awk '{print $1}')
                local owner=$(ls -la "$file" | awk '{print $3}')
                
                if [[ "$owner" == "root" ]]; then
                    echo -e "${YELLOW}   $file ($perms)${NC}"
                    log_to_report "SUID: $file ($perms) - owned by root"
                else
                    echo -e "${GREEN}   $file ($perms) - owner: $owner${NC}"
                    log_to_report "SUID: $file ($perms) - owned by $owner"
                fi
            fi
        done <<< "$suid_files"
    else
        echo -e "${GREEN}   No SUID binaries found${NC}"
    fi
    
    echo
    echo -e "${CYAN}🔍 SGID Binaries (run as group):${NC}"
    if [[ -n "$sgid_files" ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                local perms=$(ls -la "$file" | awk '{print $1}')
                local group=$(ls -la "$file" | awk '{print $4}')
                echo -e "${CYAN}   $file ($perms) - group: $group${NC}"
                log_to_report "SGID: $file ($perms) - group $group"
            fi
        done <<< "$sgid_files"
    else
        echo -e "${GREEN}   No SGID binaries found${NC}"
    fi
}

scan_listening_services() {
    print_status "Scanning listening services..."
    echo
    
    log_to_report ""
    log_to_report "=== LISTENING SERVICES ANALYSIS ==="
    
    echo -e "${CYAN}🌐 Network Services (listening ports):${NC}"
    
    # Check for netstat or ss
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep LISTEN | while IFS= read -r line; do
            local port=$(echo "$line" | awk '{print $4}' | sed 's/.*://')
            local process=$(echo "$line" | awk '{print $6}' | sed 's/.*"//' | sed 's/".*//')
            
            if [[ -n "$process" && "$process" != "-" ]]; then
                local pid=$(echo "$process" | grep -o '[0-9]*' | head -1)
                if [[ -n "$pid" ]]; then
                    local user=$(ps -o user= -p "$pid" 2>/dev/null || echo "unknown")
                    if [[ "$user" == "root" ]]; then
                        echo -e "${YELLOW}   Port $port: $process (running as root)${NC}"
                        log_to_report "LISTENING: Port $port - $process (root)"
                    else
                        echo -e "${GREEN}   Port $port: $process (running as $user)${NC}"
                        log_to_report "LISTENING: Port $port - $process ($user)"
                    fi
                fi
            fi
        done
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | grep LISTEN | while IFS= read -r line; do
            local port=$(echo "$line" | awk '{print $4}' | sed 's/.*://')
            local process=$(echo "$line" | awk '{print $7}')
            echo -e "${CYAN}   Port $port: $process${NC}"
            log_to_report "LISTENING: Port $port - $process"
        done
    else
        echo -e "${YELLOW}   netstat/ss not available - cannot scan listening services${NC}"
    fi
}

scan_systemd_services() {
    print_status "Scanning systemd services..."
    echo
    
    log_to_report ""
    log_to_report "=== SYSTEMD SERVICES ANALYSIS ==="
    
    if command -v systemctl >/dev/null 2>&1; then
        echo -e "${CYAN}🔧 Active systemd services:${NC}"
        
        systemctl list-units --type=service --state=running --no-pager --no-legend | while IFS= read -r line; do
            local service=$(echo "$line" | awk '{print $1}')
            local description=$(echo "$line" | cut -d' ' -f4-)
            
            # Check if service runs as root
            local user=$(systemctl show "$service" -p User --value 2>/dev/null || echo "")
            if [[ -z "$user" || "$user" == "root" ]]; then
                echo -e "${YELLOW}   $service (root) - $description${NC}"
                log_to_report "SYSTEMD: $service (root) - $description"
            else
                echo -e "${GREEN}   $service ($user) - $description${NC}"
                log_to_report "SYSTEMD: $service ($user) - $description"
            fi
        done
    else
        echo -e "${YELLOW}   systemctl not available - cannot scan systemd services${NC}"
    fi
}

generate_recommendations() {
    print_fire "Security Recommendations"
    echo
    
    log_to_report ""
    log_to_report "=== SECURITY RECOMMENDATIONS ==="
    
    echo -e "${WHITE}🛡️ General Security Recommendations:${NC}"
    echo
    echo -e "${GREEN}1. Principle of Least Privilege:${NC}"
    echo -e "   • Run applications with minimum required permissions"
    echo -e "   • Use dedicated users for services (e.g., 'tor' user for Tor)"
    echo -e "   • Avoid running user applications as root"
    
    echo
    echo -e "${GREEN}2. Service-Specific Recommendations:${NC}"
    echo -e "   • Tor: Must run as 'tor' user, never root"
    echo -e "   • Web browsers: Always run as regular user"
    echo -e "   • Development tools: Use virtual environments, not root"
    echo -e "   • Databases: Use dedicated service users"
    
    echo
    echo -e "${GREEN}3. System Hardening:${NC}"
    echo -e "   • Regularly audit SUID/SGID binaries"
    echo -e "   • Monitor root processes with this scanner"
    echo -e "   • Use containers/sandboxing for untrusted applications"
    echo -e "   • Implement mandatory access controls (SELinux/AppArmor)"
    
    echo
    echo -e "${GREEN}4. Monitoring:${NC}"
    echo -e "   • Run this scanner regularly (daily/weekly)"
    echo -e "   • Set up alerts for unexpected root processes"
    echo -e "   • Monitor system logs for privilege escalation"
    echo -e "   • Use process monitoring tools"
    
    log_to_report "Generated security recommendations"
}

kill_dangerous_processes() {
    print_status "Scanning for immediately dangerous processes..."
    echo
    
    local killed=0
    
    # Check for dangerous applications running as root
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
        
        if is_dangerous_root_service "$cmd"; then
            print_critical "Found dangerous root process: $cmd (PID: $pid)"
            echo -e "${RED}This process should NEVER run as root!${NC}"
            echo -e "${YELLOW}Recommend immediate termination.${NC}"
            echo
            echo -e "${WHITE}Kill this process? [y/N]:${NC} \c"
            read -r kill_confirm
            
            if [[ "$kill_confirm" =~ ^[Yy] ]]; then
                if doas kill -TERM "$pid" 2>/dev/null; then
                    print_success "Process $pid terminated gracefully"
                    ((killed++))
                    sleep 2
                    # Check if still running, force kill if needed
                    if ps -p "$pid" >/dev/null 2>&1; then
                        if doas kill -KILL "$pid" 2>/dev/null; then
                            print_success "Process $pid force-killed"
                        fi
                    fi
                else
                    print_warning "Failed to kill process $pid"
                fi
            else
                print_warning "Process $pid left running (USER CHOICE)"
            fi
            echo
        fi
    done < <(ps aux | grep "^root" | grep -v "\[")
    
    if [[ $killed -eq 0 ]]; then
        print_success "No dangerous root processes found"
    else
        print_success "Terminated $killed dangerous root processes"
    fi
    
    log_to_report "Killed $killed dangerous root processes"
}

main() {
    case "${1:-scan}" in
        "scan")
            show_banner
            print_fire "Starting Comprehensive Root Security Scan"
            echo
            
            scan_root_processes
            echo
            scan_suid_binaries
            echo
            scan_listening_services
            echo
            scan_systemd_services
            echo
            generate_recommendations
            
            echo
            print_fire "Security Scan Complete"
            echo -e "${WHITE}📋 Full report saved to: ${CYAN}$REPORT_FILE${NC}"
            ;;
        "kill-dangerous")
            show_banner
            print_fire "Dangerous Process Termination Mode"
            echo
            kill_dangerous_processes
            ;;
        "processes"|"proc")
            show_banner
            scan_root_processes
            ;;
        "suid")
            show_banner
            scan_suid_binaries
            ;;
        "services")
            show_banner
            scan_listening_services
            scan_systemd_services
            ;;
        *)
            echo "Usage: $0 {scan|kill-dangerous|processes|suid|services}"
            echo
            echo "Commands:"
            echo "  scan           - Complete security scan (default)"
            echo "  kill-dangerous - Find and kill dangerous root processes"
            echo "  processes      - Scan root processes only"
            echo "  suid           - Scan SUID/SGID binaries only"
            echo "  services       - Scan listening services only"
            exit 1
            ;;
    esac
}

# Initialize report
echo "NeXuS Root Security Scanner Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Host: $(hostname)" >> "$REPORT_FILE"
echo "User: $(whoami)" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"

# Run main function
main "$@"