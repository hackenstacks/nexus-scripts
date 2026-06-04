#!/bin/bash
# NeXuS Automated Backup Scheduler
# Periodic automated backups with smart rotation and monitoring

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# NeXuS symbols
FIRE_SYMBOL="🔥"
CLOCK_SYMBOL="⏰"
SHIELD_SYMBOL="🛡️"
GEAR_SYMBOL="⚙️"
ROCKET_SYMBOL="🚀"
NEXUS_SYMBOL="🌀"

# Configuration paths
SCHEDULER_CONFIG="/home/user/.config/nexus/backup-scheduler.conf"
SCHEDULER_LOG="/home/user/.nexus-backups/scheduler.log"
CRON_BACKUP_SCRIPT="/home/user/scripts/nexus-backup-cron.sh"
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"

print_color() {
    echo -e "${1}${2}${NC}"
}

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SCHEDULER_LOG"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║          ${CLOCK_SYMBOL} NeXuS Automated Backup Scheduler ${CLOCK_SYMBOL}        ║"
    print_color $CYAN "║               ${GEAR_SYMBOL} Set It and Forget It ${GEAR_SYMBOL}               ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

create_default_config() {
    mkdir -p "$(dirname "$SCHEDULER_CONFIG")"
    
    cat > "$SCHEDULER_CONFIG" << 'EOF'
# NeXuS Backup Scheduler Configuration
# Edit this file to customize your automated backup settings

# Backup schedule (cron format)
# Examples:
#   "0 2 * * *"     = Daily at 2:00 AM
#   "0 2 * * 0"     = Weekly on Sunday at 2:00 AM  
#   "0 2 1 * *"     = Monthly on 1st at 2:00 AM
#   "*/30 * * * *"  = Every 30 minutes (testing only!)
BACKUP_SCHEDULE="0 2 * * *"

# Backup retention (how many to keep)
LOCAL_BACKUP_KEEP=7
ENCRYPTED_BACKUP_KEEP=5

# Backup types to create
CREATE_LOCAL_BACKUP=true
CREATE_ENCRYPTED_BACKUP=false

# Notification settings
SEND_NOTIFICATIONS=true
NOTIFY_SUCCESS=false
NOTIFY_FAILURE=true

# Auto-cleanup old backups
AUTO_CLEANUP=true

# Backup naming
BACKUP_PREFIX="auto"
INCLUDE_HOSTNAME=true

# Log retention (days)
LOG_RETENTION_DAYS=30
EOF
    
    print_color $GREEN "✅ Default configuration created at $SCHEDULER_CONFIG"
}

load_config() {
    if [ ! -f "$SCHEDULER_CONFIG" ]; then
        create_default_config
    fi
    
    # Source the configuration
    source "$SCHEDULER_CONFIG"
}

create_cron_script() {
    cat > "$CRON_BACKUP_SCRIPT" << 'EOF'
#!/bin/bash
# NeXuS Cron Backup Script - Called by cron scheduler
# This script runs the actual backup operations

# Load configuration
source /home/user/.config/nexus/backup-scheduler.conf

# Paths
LOG_FILE="/home/user/.nexus-backups/scheduler.log"
BACKUP_SCRIPT="/home/user/scripts/nexus-backup-system.sh"
ENCRYPT_SCRIPT="/home/user/scripts/nexus-backup-encrypt.sh"

# Function to log messages
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to send notifications
send_notification() {
    local message="$1"
    local is_error="$2"
    
    if [ "$SEND_NOTIFICATIONS" = "true" ]; then
        if [ "$is_error" = "true" ] && [ "$NOTIFY_FAILURE" = "true" ]; then
            /home/user/scripts/claude/secure_notify_manager.sh "NeXuS Backup Error" "$message" 2>/dev/null || true
        elif [ "$is_error" != "true" ] && [ "$NOTIFY_SUCCESS" = "true" ]; then
            /home/user/scripts/claude/secure_notify_manager.sh "NeXuS Backup Success" "$message" 2>/dev/null || true
        fi
    fi
}

# Generate backup name
generate_backup_name() {
    local name="${BACKUP_PREFIX:-auto}"
    if [ "$INCLUDE_HOSTNAME" = "true" ]; then
        name="${name}-$(hostname)"
    fi
    name="${name}-$(date +%Y%m%d_%H%M%S)"
    echo "$name"
}

# Main backup execution
main() {
    log_msg "🚀 Starting automated backup cycle"
    local backup_name=$(generate_backup_name)
    local errors=0
    
    # Create local backup
    if [ "$CREATE_LOCAL_BACKUP" = "true" ]; then
        log_msg "📦 Creating local backup: $backup_name"
        if "$BACKUP_SCRIPT" create "$backup_name" >> "$LOG_FILE" 2>&1; then
            log_msg "✅ Local backup completed successfully"
        else
            log_msg "❌ Local backup failed"
            send_notification "Local backup failed for $backup_name" true
            ((errors++))
        fi
    fi
    
    # Create encrypted backup
    if [ "$CREATE_ENCRYPTED_BACKUP" = "true" ]; then
        log_msg "🔐 Creating encrypted backup: $backup_name"
        if "$ENCRYPT_SCRIPT" create "$backup_name" >> "$LOG_FILE" 2>&1; then
            log_msg "✅ Encrypted backup completed successfully"
        else
            log_msg "❌ Encrypted backup failed"
            send_notification "Encrypted backup failed for $backup_name" true
            ((errors++))
        fi
    fi
    
    # Cleanup old backups
    if [ "$AUTO_CLEANUP" = "true" ]; then
        log_msg "🧹 Cleaning up old backups"
        
        # Clean local backups
        if [ -n "$LOCAL_BACKUP_KEEP" ] && [ "$LOCAL_BACKUP_KEEP" -gt 0 ]; then
            # Keep only the N newest backup manifests and their associated data
            find /home/user/.nexus-backups -name "BACKUP_MANIFEST_*.txt" -type f | \
                sort -r | tail -n +$((LOCAL_BACKUP_KEEP + 1)) | \
                while read manifest; do
                    local timestamp=$(basename "$manifest" .txt | sed 's/BACKUP_MANIFEST_//')
                    log_msg "  Removing old backup: $timestamp"
                    rm -f "$manifest"
                    # Clean up associated backup directories
                    find /home/user/.nexus-backups -name "*${timestamp}*" -type d -exec rm -rf {} \; 2>/dev/null || true
                done
        fi
        
        # Clean encrypted backups
        if [ -n "$ENCRYPTED_BACKUP_KEEP" ] && [ "$ENCRYPTED_BACKUP_KEEP" -gt 0 ] && [ -d "/home/user/encrypted-backups" ]; then
            find /home/user/encrypted-backups -name "*.age" -type f | \
                sort -r | tail -n +$((ENCRYPTED_BACKUP_KEEP + 1)) | \
                while read encrypted; do
                    log_msg "  Removing old encrypted backup: $(basename "$encrypted")"
                    rm -f "$encrypted" "${encrypted%.age}.info"
                done
        fi
        
        log_msg "✅ Cleanup completed"
    fi
    
    # Log rotation
    if [ -n "$LOG_RETENTION_DAYS" ] && [ "$LOG_RETENTION_DAYS" -gt 0 ]; then
        find "$(dirname "$LOG_FILE")" -name "scheduler.log*" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    fi
    
    # Final status
    if [ $errors -eq 0 ]; then
        log_msg "🎉 Automated backup cycle completed successfully"
        send_notification "Backup cycle completed: $backup_name" false
    else
        log_msg "⚠️ Automated backup cycle completed with $errors errors"
        send_notification "Backup cycle completed with $errors errors" true
    fi
}

# Run the backup
main "$@"
EOF
    
    chmod +x "$CRON_BACKUP_SCRIPT"
    print_color $GREEN "✅ Cron backup script created at $CRON_BACKUP_SCRIPT"
}

install_cron_job() {
    load_config
    
    print_color $CYAN "${CLOCK_SYMBOL} Installing automated backup schedule (BusyBox crond)..."
    print_color $YELLOW "Schedule: $BACKUP_SCHEDULE"
    
    # Create the cron script if it doesn't exist
    if [ ! -f "$CRON_BACKUP_SCRIPT" ]; then
        create_cron_script
    fi
    
    # BusyBox crond: Add to user's crontab (works with both user and system cron)
    local temp_cron="/tmp/nexus_cron_$$"
    
    # Get existing crontab, remove old NeXuS entries
    crontab -l 2>/dev/null | grep -v "nexus-backup-cron.sh" > "$temp_cron" || touch "$temp_cron"
    
    # Add new NeXuS backup entry
    echo "$BACKUP_SCHEDULE $CRON_BACKUP_SCRIPT >/dev/null 2>&1" >> "$temp_cron"
    
    # Install new crontab
    crontab "$temp_cron"
    rm -f "$temp_cron"
    
    # Initialize log
    mkdir -p "$(dirname "$SCHEDULER_LOG")"
    log_message "🚀 NeXuS Backup Scheduler installed with BusyBox crond: $BACKUP_SCHEDULE"
    
    print_color $GREEN "✅ Automated backup schedule installed!"
    print_color $CYAN "📋 BusyBox crond will handle the schedule"
    print_color $CYAN "📝 Logs: $SCHEDULER_LOG"
    
    # Show next backup time if possible
    local hour=$(echo "$BACKUP_SCHEDULE" | awk '{print $2}')
    local minute=$(echo "$BACKUP_SCHEDULE" | awk '{print $1}')
    if [ "$hour" != "*" ] && [ "$minute" != "*" ]; then
        print_color $CYAN "🕐 Next backup: Today at $hour:$(printf "%02d" "$minute") (if not passed) or tomorrow"
    fi
}

remove_cron_job() {
    print_color $CYAN "${FIRE_SYMBOL} Removing automated backup schedule..."
    
    # Remove NeXuS backup cron jobs
    if crontab -l 2>/dev/null | grep -q "nexus-backup-cron.sh"; then
        crontab -l 2>/dev/null | grep -v "nexus-backup-cron.sh" | crontab -
        print_color $GREEN "✅ Automated backup schedule removed"
        log_message "🛑 NeXuS Backup Scheduler disabled"
    else
        print_color $YELLOW "No automated backup schedule found"
    fi
}

show_status() {
    load_config
    show_banner
    print_color $WHITE "📊 NeXuS Backup Scheduler Status"
    echo
    
    # Check if cron job is installed
    if crontab -l 2>/dev/null | grep -q "nexus-backup-cron.sh"; then
        print_color $GREEN "✅ Status: ACTIVE"
        print_color $CYAN "📅 Schedule: $BACKUP_SCHEDULE"
        
        # Show schedule description
        case "$BACKUP_SCHEDULE" in
            "0 2 * * *") print_color $CYAN "📋 Description: Daily at 2:00 AM" ;;
            "0 2 * * 0") print_color $CYAN "📋 Description: Weekly on Sunday at 2:00 AM" ;;
            "0 2 1 * *") print_color $CYAN "📋 Description: Monthly on 1st at 2:00 AM" ;;
            *) print_color $CYAN "📋 Description: Custom schedule" ;;
        esac
        
    else
        print_color $RED "❌ Status: INACTIVE"
        print_color $YELLOW "💡 Run 'install' to enable automated backups"
    fi
    
    echo
    print_color $WHITE "⚙️ Current Configuration:"
    print_color $CYAN "  📦 Local backups: $([ "$CREATE_LOCAL_BACKUP" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    print_color $CYAN "  🔐 Encrypted backups: $([ "$CREATE_ENCRYPTED_BACKUP" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    print_color $CYAN "  🔔 Notifications: $([ "$SEND_NOTIFICATIONS" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    print_color $CYAN "  🧹 Auto cleanup: $([ "$AUTO_CLEANUP" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    print_color $CYAN "  📁 Keep local: ${LOCAL_BACKUP_KEEP:-∞} backups"
    print_color $CYAN "  🔒 Keep encrypted: ${ENCRYPTED_BACKUP_KEEP:-∞} backups"
    
    # Show recent activity
    echo
    print_color $WHITE "📈 Recent Activity:"
    if [ -f "$SCHEDULER_LOG" ]; then
        tail -10 "$SCHEDULER_LOG" | while read line; do
            if [[ "$line" =~ "✅" ]]; then
                print_color $GREEN "  $line"
            elif [[ "$line" =~ "❌" ]]; then
                print_color $RED "  $line"
            else
                print_color $CYAN "  $line"
            fi
        done
    else
        print_color $YELLOW "  No activity logs found"
    fi
}

edit_config() {
    load_config
    
    print_color $CYAN "${GEAR_SYMBOL} Opening backup scheduler configuration..."
    print_color $YELLOW "💡 Edit the schedule and settings, then run 'install' to apply changes"
    
    ${EDITOR:-nano} "$SCHEDULER_CONFIG"
    
    print_color $GREEN "✅ Configuration updated"
    print_color $YELLOW "🔄 Run 'nexus-backup-scheduler.sh install' to apply changes"
}

run_test_backup() {
    load_config
    
    print_color $CYAN "${ROCKET_SYMBOL} Running test backup cycle..."
    print_color $YELLOW "This will create a one-time backup using your current settings"
    echo
    
    # Run the cron script manually
    if [ -f "$CRON_BACKUP_SCRIPT" ]; then
        "$CRON_BACKUP_SCRIPT"
        echo
        print_color $GREEN "✅ Test backup completed! Check logs for details:"
        print_color $CYAN "📝 tail -f $SCHEDULER_LOG"
    else
        print_color $RED "❌ Cron script not found. Run 'install' first."
    fi
}

show_logs() {
    if [ -f "$SCHEDULER_LOG" ]; then
        print_color $CYAN "📝 NeXuS Backup Scheduler Logs (Press Ctrl+C to exit):"
        echo
        tail -f "$SCHEDULER_LOG"
    else
        print_color $YELLOW "No scheduler logs found yet"
        print_color $CYAN "💡 Logs will appear after first automated backup"
    fi
}

quick_setup_wizard() {
    show_banner
    print_color $CYAN "${GEAR_SYMBOL} NeXuS Backup Scheduler Quick Setup"
    echo
    
    # Backup frequency
    print_color $WHITE "1️⃣ Choose backup frequency:"
    echo "   1) Daily at 2:00 AM (recommended)"
    echo "   2) Weekly on Sunday at 2:00 AM"
    echo "   3) Monthly on 1st at 2:00 AM"
    echo "   4) Custom schedule"
    read -p "Select option (1-4): " freq_choice
    
    case "$freq_choice" in
        1) schedule="0 2 * * *" ;;
        2) schedule="0 2 * * 0" ;;
        3) schedule="0 2 1 * *" ;;
        4) 
            print_color $CYAN "Enter cron schedule (e.g., '0 3 * * *' for daily at 3 AM):"
            read -p "Schedule: " schedule
            ;;
        *) schedule="0 2 * * *" ;;
    esac
    
    # Backup types
    echo
    print_color $WHITE "2️⃣ Choose backup types:"
    read -p "Create local backups? (Y/n): " local_choice
    local_backup=$([ "${local_choice,,}" != "n" ] && echo "true" || echo "false")
    
    read -p "Create encrypted backups for off-site storage? (y/N): " encrypt_choice
    encrypt_backup=$([ "${encrypt_choice,,}" = "y" ] && echo "true" || echo "false")
    
    # Retention
    echo
    print_color $WHITE "3️⃣ Backup retention:"
    read -p "How many local backups to keep? (default: 7): " local_keep
    local_keep=${local_keep:-7}
    
    if [ "$encrypt_backup" = "true" ]; then
        read -p "How many encrypted backups to keep? (default: 5): " encrypt_keep
        encrypt_keep=${encrypt_keep:-5}
    else
        encrypt_keep=5
    fi
    
    # Notifications
    echo
    read -p "Enable backup notifications? (Y/n): " notify_choice
    notifications=$([ "${notify_choice,,}" != "n" ] && echo "true" || echo "false")
    
    # Generate configuration
    cat > "$SCHEDULER_CONFIG" << EOF
# NeXuS Backup Scheduler Configuration - Generated by Quick Setup
BACKUP_SCHEDULE="$schedule"
LOCAL_BACKUP_KEEP=$local_keep
ENCRYPTED_BACKUP_KEEP=$encrypt_keep
CREATE_LOCAL_BACKUP=$local_backup
CREATE_ENCRYPTED_BACKUP=$encrypt_backup
SEND_NOTIFICATIONS=$notifications
NOTIFY_SUCCESS=false
NOTIFY_FAILURE=true
AUTO_CLEANUP=true
BACKUP_PREFIX="auto"
INCLUDE_HOSTNAME=true
LOG_RETENTION_DAYS=30
EOF
    
    echo
    print_color $GREEN "✅ Configuration saved!"
    print_color $CYAN "📋 Summary:"
    print_color $CYAN "   Schedule: $schedule"
    print_color $CYAN "   Local backups: $local_backup (keep $local_keep)"
    print_color $CYAN "   Encrypted backups: $encrypt_backup (keep $encrypt_keep)"
    print_color $CYAN "   Notifications: $notifications"
    echo
    
    read -p "Install this schedule now? (Y/n): " install_choice
    if [ "${install_choice,,}" != "n" ]; then
        install_cron_job
    else
        print_color $YELLOW "💡 Run 'nexus-backup-scheduler.sh install' when ready"
    fi
}

show_help() {
    show_banner
    print_color $WHITE "COMMANDS:"
    print_color $GREEN "  nexus-backup-scheduler.sh setup      ${CYAN}# Quick setup wizard"
    print_color $GREEN "  nexus-backup-scheduler.sh install    ${CYAN}# Install/update schedule"
    print_color $GREEN "  nexus-backup-scheduler.sh remove     ${CYAN}# Remove automated backups"
    print_color $GREEN "  nexus-backup-scheduler.sh status     ${CYAN}# Show current status"
    print_color $GREEN "  nexus-backup-scheduler.sh config     ${CYAN}# Edit configuration"
    print_color $GREEN "  nexus-backup-scheduler.sh test       ${CYAN}# Run test backup now"
    print_color $GREEN "  nexus-backup-scheduler.sh logs       ${CYAN}# View live logs"
    print_color $GREEN "  nexus-backup-scheduler.sh help       ${CYAN}# Show this help"
    echo
    
    print_color $WHITE "SCHEDULE EXAMPLES:"
    print_color $YELLOW "  '0 2 * * *'      = Daily at 2:00 AM"
    print_color $YELLOW "  '0 2 * * 0'      = Weekly on Sunday at 2:00 AM"
    print_color $YELLOW "  '0 2 1 * *'      = Monthly on 1st at 2:00 AM"
    print_color $YELLOW "  '0 */6 * * *'    = Every 6 hours"
    echo
    
    print_color $WHITE "FILES:"
    print_color $CYAN "  Config: $SCHEDULER_CONFIG"
    print_color $CYAN "  Logs: $SCHEDULER_LOG"
    print_color $CYAN "  Cron script: $CRON_BACKUP_SCRIPT"
}

# Main function
main() {
    case "${1:-help}" in
        "setup"|"wizard")
            quick_setup_wizard
            ;;
        "install"|"enable")
            show_banner
            install_cron_job
            ;;
        "remove"|"disable"|"uninstall")
            show_banner
            remove_cron_job
            ;;
        "status"|"info")
            show_status
            ;;
        "config"|"edit")
            edit_config
            ;;
        "test"|"run")
            show_banner
            run_test_backup
            ;;
        "logs"|"log")
            show_logs
            ;;
        "help"|"h"|*)
            show_help
            ;;
    esac
}

main "$@"