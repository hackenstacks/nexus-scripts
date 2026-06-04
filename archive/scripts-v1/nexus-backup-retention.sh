#!/bin/bash
# NeXuS Backup Retention Manager
# Intelligent backup cleanup with configurable policies
# Part of NeXuS P1.1 Backup System Integrity & Automation

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

# NeXuS symbols with fire aesthetics
FIRE_SYMBOL="🔥"
ROCKET_SYMBOL="🚀"
BACKUP_SYMBOL="💾"
NEXUS_SYMBOL="🌀"
SHIELD_SYMBOL="🛡️"
CHECK_SYMBOL="✅"
CROSS_SYMBOL="❌"
LIGHTNING_SYMBOL="⚡"
CRYSTAL_SYMBOL="💎"
GHOST_SYMBOL="👻"
GEAR_SYMBOL="⚙️"
TRASH_SYMBOL="🗑️"
ARCHIVE_SYMBOL="📦"
CLOCK_SYMBOL="⏰"

# Configuration
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
CONFIG_FILE="$NEXUS_BACKUP_ROOT/retention-policy.conf"
RETENTION_LOG="$NEXUS_BACKUP_ROOT/retention.log"
CLEANUP_REPORT="$NEXUS_BACKUP_ROOT/cleanup_report_$(date +%Y%m%d_%H%M%S).txt"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Default values (overridden by config file)
DAILY_RETENTION_DAYS=7
WEEKLY_RETENTION_WEEKS=4
MONTHLY_RETENTION_MONTHS=12
YEARLY_RETENTION_YEARS=3
MIN_FREE_SPACE_MB=1024
MAX_CLEANUP_FILES=50
REQUIRE_CONFIRMATION=true
DRY_RUN_MODE=false
VERIFY_BEFORE_DELETE=true

# Runtime tracking
TOTAL_FILES_SCANNED=0
FILES_TO_DELETE=0
SPACE_TO_FREE=0
SPACE_FREED=0
ERRORS_ENCOUNTERED=0

print_color() {
    echo -e "${1}${2}${NC}"
}

print_fire_header() {
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    print_color $YELLOW "    ${NEXUS_SYMBOL} NeXuS Backup Retention Manager ${NEXUS_SYMBOL}"
    print_color $WHITE "    ${CLOCK_SYMBOL} Intelligent Policy-Based Cleanup ${CLOCK_SYMBOL}"
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    echo
}

print_separator() {
    print_color $CYAN "    ${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}"
}

log_message() {
    local level=$1
    local message=$2
    echo "[$TIMESTAMP] [$level] $message" >> "$RETENTION_LOG"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        print_color $GREEN "${CHECK_SYMBOL} Configuration loaded: $CONFIG_FILE"
        log_message "INFO" "Configuration loaded from $CONFIG_FILE"
    else
        print_color $YELLOW "${GHOST_SYMBOL} Configuration file not found, using defaults"
        log_message "WARN" "Configuration file not found: $CONFIG_FILE"
    fi
}

show_help() {
    print_fire_header
    print_color $WHITE "Usage: nexus-backup-retention.sh [OPTION]"
    echo
    print_color $CYAN "OPTIONS:"
    print_color $GREEN "  analyze           Analyze current backup storage"
    print_color $GREEN "  cleanup           Run retention cleanup (respects dry-run setting)"
    print_color $GREEN "  force-cleanup     Force cleanup (ignores dry-run setting)"
    print_color $GREEN "  dry-run           Show what would be cleaned (safe preview)"
    print_color $GREEN "  policy            Show current retention policies"
    print_color $GREEN "  report            Generate retention analytics report"
    print_color $GREEN "  config            Show configuration file location"
    print_color $GREEN "  status            Show retention manager status"
    print_color $GREEN "  help              Show this help message"
    echo
    print_color $YELLOW "EXAMPLES:"
    print_color $WHITE "  $0 analyze       # Analyze backup storage usage"
    print_color $WHITE "  $0 dry-run       # Preview cleanup without deleting"
    print_color $WHITE "  $0 cleanup       # Run retention cleanup"
    print_color $WHITE "  $0 policy        # Show retention policies"
    print_color $WHITE "  $0 report        # Generate analytics report"
    echo
    print_separator
}

cancel_timer() {
    local seconds=$1
    local operation=$2
    
    print_color $YELLOW "${FIRE_SYMBOL} ${operation} will start in $seconds seconds..."
    print_color $RED "${GHOST_SYMBOL} Press CTRL+C to cancel..."
    
    for ((i=seconds; i>0; i--)); do
        printf "\r${YELLOW}${FIRE_SYMBOL} Starting in: ${RED}%d${NC} seconds " $i
        sleep 1
    done
    printf "\r${GREEN}${ROCKET_SYMBOL} Starting ${operation}...             ${NC}\n"
}

get_file_age_days() {
    local file_path="$1"
    local file_time=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age_seconds=$((current_time - file_time))
    local age_days=$((age_seconds / 86400))
    echo $age_days
}

get_file_size() {
    local file_path="$1"
    stat -c %s "$file_path" 2>/dev/null || stat -f %z "$file_path" 2>/dev/null || echo 0
}

format_size() {
    local bytes=$1
    if command -v numfmt >/dev/null; then
        numfmt --to=iec "$bytes"
    else
        echo "${bytes} bytes"
    fi
}

is_backup_file() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # Check against known backup patterns
    case "$filename" in
        *.tar.gz|*.tar|*.zip) return 0 ;;
        *backup*) return 0 ;;
        *_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*) return 0 ;;
        *) return 1 ;;
    esac
}

categorize_backup() {
    local file_path="$1"
    local age_days=$(get_file_age_days "$file_path")
    
    if [[ $age_days -le $DAILY_RETENTION_DAYS ]]; then
        echo "daily"
    elif [[ $age_days -le $((WEEKLY_RETENTION_WEEKS * 7)) ]]; then
        echo "weekly"
    elif [[ $age_days -le $((MONTHLY_RETENTION_MONTHS * 30)) ]]; then
        echo "monthly"
    elif [[ $age_days -le $((YEARLY_RETENTION_YEARS * 365)) ]]; then
        echo "yearly"
    else
        echo "expired"
    fi
}

should_preserve_file() {
    local file_path="$1"
    local file_size=$(get_file_size "$file_path")
    local file_size_mb=$((file_size / 1048576))
    local age_hours=$(( $(get_file_age_days "$file_path") * 24 ))
    
    # Preserve very new files (safety buffer)
    if [[ -n "${SAFETY_BUFFER_HOURS:-}" && $age_hours -lt $SAFETY_BUFFER_HOURS ]]; then
        return 0
    fi
    
    # Preserve large files if configured
    if [[ -n "${PRESERVE_LARGE_FILES_MB:-}" && $file_size_mb -gt $PRESERVE_LARGE_FILES_MB ]]; then
        return 0
    fi
    
    return 1
}

verify_backup_integrity() {
    local file_path="$1"
    
    if [[ "$VERIFY_BEFORE_DELETE" == "true" && -x "/home/user/scripts/nexus-backup-integrity-checker.sh" ]]; then
        /home/user/scripts/nexus-backup-integrity-checker.sh verify "$file_path" >/dev/null 2>&1
        return $?
    fi
    
    return 0  # Skip verification if not enabled or tool not available
}

analyze_storage() {
    print_color $CYAN "${GEAR_SYMBOL} Analyzing backup storage..."
    
    local total_files=0
    local total_size=0
    local daily_files=0 daily_size=0
    local weekly_files=0 weekly_size=0
    local monthly_files=0 monthly_size=0
    local yearly_files=0 yearly_size=0
    local expired_files=0 expired_size=0
    
    # Analyze each backup location
    for location in "${BACKUP_LOCATIONS[@]:-$NEXUS_BACKUP_ROOT}"; do
        if [[ ! -d "$location" ]]; then
            continue
        fi
        
        print_color $BLUE "${BACKUP_SYMBOL} Scanning: $location"
        
        while IFS= read -r -d '' file; do
            if is_backup_file "$file"; then
                ((total_files++))
                local size=$(get_file_size "$file")
                ((total_size += size))
                
                local category=$(categorize_backup "$file")
                case "$category" in
                    "daily")
                        ((daily_files++))
                        ((daily_size += size))
                        ;;
                    "weekly")
                        ((weekly_files++))
                        ((weekly_size += size))
                        ;;
                    "monthly")
                        ((monthly_files++))
                        ((monthly_size += size))
                        ;;
                    "yearly")
                        ((yearly_files++))
                        ((yearly_size += size))
                        ;;
                    "expired")
                        ((expired_files++))
                        ((expired_size += size))
                        ;;
                esac
            fi
        done < <(find "$location" -type f -print0 2>/dev/null)
    done
    
    # Display analysis
    print_separator
    print_color $WHITE "${CRYSTAL_SYMBOL} STORAGE ANALYSIS:"
    print_color $GREEN "  Total backups:   $total_files files ($(format_size $total_size))"
    print_color $CYAN "  Daily:           $daily_files files ($(format_size $daily_size))"
    print_color $CYAN "  Weekly:          $weekly_files files ($(format_size $weekly_size))"
    print_color $CYAN "  Monthly:         $monthly_files files ($(format_size $monthly_size))"
    print_color $CYAN "  Yearly:          $yearly_files files ($(format_size $yearly_size))"
    
    if [[ $expired_files -gt 0 ]]; then
        print_color $RED "  Expired:         $expired_files files ($(format_size $expired_size))"
        print_color $YELLOW "${GHOST_SYMBOL} Expired backups can be cleaned up"
    else
        print_color $GREEN "  Expired:         0 files (0 bytes)"
    fi
    
    print_separator
    
    # Set globals for other functions
    TOTAL_FILES_SCANNED=$total_files
    FILES_TO_DELETE=$expired_files
    SPACE_TO_FREE=$expired_size
}

identify_cleanup_candidates() {
    local candidates=()
    
    print_color $BLUE "${TRASH_SYMBOL} Identifying cleanup candidates..."
    
    for location in "${BACKUP_LOCATIONS[@]:-$NEXUS_BACKUP_ROOT}"; do
        if [[ ! -d "$location" ]]; then
            continue
        fi
        
        while IFS= read -r -d '' file; do
            if is_backup_file "$file"; then
                local category=$(categorize_backup "$file")
                
                if [[ "$category" == "expired" ]]; then
                    # Check if file should be preserved
                    if ! should_preserve_file "$file"; then
                        candidates+=("$file")
                    fi
                fi
            fi
        done < <(find "$location" -type f -print0 2>/dev/null)
    done
    
    # Sort candidates by age (oldest first)
    if [[ ${#candidates[@]} -gt 0 ]]; then
        IFS=$'\n' candidates=($(sort <<<"${candidates[*]}"))
    fi
    
    # Limit cleanup size if configured
    if [[ ${#candidates[@]} -gt $MAX_CLEANUP_FILES ]]; then
        print_color $YELLOW "${GHOST_SYMBOL} Limiting cleanup to $MAX_CLEANUP_FILES files"
        candidates=("${candidates[@]:0:$MAX_CLEANUP_FILES}")
    fi
    
    printf '%s\n' "${candidates[@]}"
}

perform_cleanup() {
    local dry_run="$1"
    local candidates
    readarray -t candidates < <(identify_cleanup_candidates)
    
    if [[ ${#candidates[@]} -eq 0 ]]; then
        print_color $GREEN "${CHECK_SYMBOL} No cleanup needed - all backups within retention policy"
        return 0
    fi
    
    print_color $CYAN "${TRASH_SYMBOL} Found ${#candidates[@]} files for cleanup"
    
    if [[ "$dry_run" == "true" ]]; then
        print_color $YELLOW "${GHOST_SYMBOL} DRY RUN MODE - No files will be deleted"
    fi
    
    # Show what will be cleaned
    local preview_size=0
    print_color $WHITE "Files to be cleaned:"
    
    for file in "${candidates[@]}"; do
        local size=$(get_file_size "$file")
        local age_days=$(get_file_age_days "$file")
        ((preview_size += size))
        
        if [[ "$dry_run" == "true" ]]; then
            print_color $YELLOW "  [DRY RUN] $(basename "$file") ($(format_size $size), ${age_days} days old)"
        else
            print_color $RED "  [DELETE] $(basename "$file") ($(format_size $size), ${age_days} days old)"
        fi
        
        # Limit preview output
        if [[ ${#candidates[@]} -gt 10 ]]; then
            print_color $BLUE "  ... and $((${#candidates[@]} - 10)) more files"
            break
        fi
    done
    
    print_color $CYAN "Total space to free: $(format_size $preview_size)"
    
    # Confirmation for real cleanup
    if [[ "$dry_run" != "true" && "$REQUIRE_CONFIRMATION" == "true" ]]; then
        print_color $YELLOW "${FIRE_SYMBOL} This will permanently delete ${#candidates[@]} backup files!"
        read -p "Are you sure? (yes/no): " confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            print_color $BLUE "${GHOST_SYMBOL} Cleanup cancelled by user"
            return 0
        fi
    fi
    
    # Perform actual cleanup
    if [[ "$dry_run" != "true" ]]; then
        local deleted_count=0
        local freed_space=0
        
        for file in "${candidates[@]}"; do
            # Verify integrity before deletion if enabled
            if ! verify_backup_integrity "$file"; then
                print_color $YELLOW "${GHOST_SYMBOL} Skipping corrupt backup: $(basename "$file")"
                ((ERRORS_ENCOUNTERED++))
                continue
            fi
            
            local size=$(get_file_size "$file")
            
            if rm "$file" 2>/dev/null; then
                ((deleted_count++))
                ((freed_space += size))
                log_message "INFO" "Deleted expired backup: $file ($(format_size $size))"
                print_color $GREEN "${CHECK_SYMBOL} Deleted: $(basename "$file")"
            else
                print_color $RED "${CROSS_SYMBOL} Failed to delete: $(basename "$file")"
                ((ERRORS_ENCOUNTERED++))
                log_message "ERROR" "Failed to delete: $file"
            fi
        done
        
        SPACE_FREED=$freed_space
        print_color $GREEN "${ROCKET_SYMBOL} Cleanup completed: $deleted_count files deleted, $(format_size $freed_space) freed"
    else
        print_color $BLUE "${GHOST_SYMBOL} Dry run completed - no files were deleted"
    fi
}

show_policy() {
    print_fire_header
    print_color $WHITE "${GEAR_SYMBOL} CURRENT RETENTION POLICIES:"
    print_separator
    
    print_color $GREEN "  Daily backups:   Keep for $DAILY_RETENTION_DAYS days"
    print_color $GREEN "  Weekly backups:  Keep for $WEEKLY_RETENTION_WEEKS weeks"
    print_color $GREEN "  Monthly backups: Keep for $MONTHLY_RETENTION_MONTHS months"
    print_color $GREEN "  Yearly backups:  Keep for $YEARLY_RETENTION_YEARS years"
    echo
    print_color $CYAN "  Configuration:   $CONFIG_FILE"
    print_color $CYAN "  Dry run mode:    $DRY_RUN_MODE"
    print_color $CYAN "  Verification:    $VERIFY_BEFORE_DELETE"
    print_color $CYAN "  Max cleanup:     $MAX_CLEANUP_FILES files"
    print_color $CYAN "  Min free space:  ${MIN_FREE_SPACE_MB}MB"
    
    print_separator
}

generate_report() {
    local report_time=$(date +"%Y-%m-%d %H:%M:%S")
    
    print_fire_header
    print_color $WHITE "${CRYSTAL_SYMBOL} RETENTION ANALYTICS REPORT ${CRYSTAL_SYMBOL}"
    print_separator
    
    {
        echo "NeXuS Backup Retention Analytics Report"
        echo "Generated: $report_time"
        echo ""
        echo "RETENTION POLICIES:"
        echo "  Daily retention:     $DAILY_RETENTION_DAYS days"
        echo "  Weekly retention:    $WEEKLY_RETENTION_WEEKS weeks"
        echo "  Monthly retention:   $MONTHLY_RETENTION_MONTHS months"
        echo "  Yearly retention:    $YEARLY_RETENTION_YEARS years"
        echo ""
        echo "STORAGE ANALYSIS:"
        echo "  Total files scanned: $TOTAL_FILES_SCANNED"
        echo "  Files eligible for cleanup: $FILES_TO_DELETE"
        echo "  Space that can be freed: $(format_size $SPACE_TO_FREE)"
        
        if [[ $SPACE_FREED -gt 0 ]]; then
            echo "  Space actually freed: $(format_size $SPACE_FREED)"
        fi
        
        if [[ $ERRORS_ENCOUNTERED -gt 0 ]]; then
            echo "  Errors encountered: $ERRORS_ENCOUNTERED"
        fi
        
        echo ""
        echo "RECOMMENDATIONS:"
        
        if [[ $FILES_TO_DELETE -gt 0 ]]; then
            echo "  - Run cleanup to free $(format_size $SPACE_TO_FREE)"
        else
            echo "  - No cleanup needed"
        fi
        
        if [[ $ERRORS_ENCOUNTERED -gt 0 ]]; then
            echo "  - Check logs for cleanup errors"
        fi
        
    } | tee "$CLEANUP_REPORT"
    
    # Console summary
    print_color $GREEN "  Files scanned:       $TOTAL_FILES_SCANNED"
    print_color $YELLOW "  Cleanup candidates:  $FILES_TO_DELETE"
    print_color $BLUE "  Potential savings:   $(format_size $SPACE_TO_FREE)"
    
    if [[ $SPACE_FREED -gt 0 ]]; then
        print_color $GREEN "  Space freed:         $(format_size $SPACE_FREED)"
    fi
    
    print_separator
    
    log_message "INFO" "Retention report generated: $CLEANUP_REPORT"
}

show_status() {
    print_fire_header
    print_color $CYAN "${BACKUP_SYMBOL} NeXuS Retention Manager Status"
    print_separator
    
    if [[ -f "$CONFIG_FILE" ]]; then
        print_color $GREEN "${CHECK_SYMBOL} Configuration: Active"
    else
        print_color $RED "${CROSS_SYMBOL} Configuration: Not found"
    fi
    
    if [[ -f "$RETENTION_LOG" ]]; then
        local log_entries=$(wc -l < "$RETENTION_LOG" 2>/dev/null || echo 0)
        print_color $GREEN "${CHECK_SYMBOL} Log entries: $log_entries"
    else
        print_color $YELLOW "${GHOST_SYMBOL} Log: Empty"
    fi
    
    # Check backup locations
    local active_locations=0
    for location in "${BACKUP_LOCATIONS[@]:-$NEXUS_BACKUP_ROOT}"; do
        if [[ -d "$location" ]]; then
            ((active_locations++))
        fi
    done
    
    print_color $GREEN "${CHECK_SYMBOL} Active backup locations: $active_locations"
    
    # Check available space
    local available_space=$(df -m /home 2>/dev/null | awk 'NR==2{print $4}' || echo "Unknown")
    print_color $BLUE "${GEAR_SYMBOL} Available space: ${available_space}MB"
    
    print_separator
}

# Main execution
case "$1" in
    "analyze")
        load_config
        analyze_storage
        ;;
    "cleanup")
        load_config
        cancel_timer 5 "Retention Cleanup"
        analyze_storage
        perform_cleanup "$DRY_RUN_MODE"
        generate_report
        ;;
    "force-cleanup")
        load_config
        cancel_timer 5 "FORCED Retention Cleanup"
        analyze_storage
        perform_cleanup "false"
        generate_report
        ;;
    "dry-run")
        load_config
        analyze_storage
        perform_cleanup "true"
        ;;
    "policy")
        load_config
        show_policy
        ;;
    "report")
        load_config
        analyze_storage
        generate_report
        ;;
    "config")
        print_color $CYAN "${GEAR_SYMBOL} Configuration file: $CONFIG_FILE"
        if [[ -f "$CONFIG_FILE" ]]; then
            print_color $GREEN "${CHECK_SYMBOL} Configuration file exists"
        else
            print_color $RED "${CROSS_SYMBOL} Configuration file not found"
        fi
        ;;
    "status")
        load_config
        show_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        show_help
        print_color $RED "${GHOST_SYMBOL} Invalid option: $1"
        exit 1
        ;;
esac

# Final status
if [[ "$1" == "cleanup" || "$1" == "force-cleanup" ]]; then
    if [[ $ERRORS_ENCOUNTERED -gt 0 ]]; then
        print_color $YELLOW "${FIRE_SYMBOL} CLEANUP COMPLETED WITH WARNINGS"
        exit 1
    else
        print_color $GREEN "${FIRE_SYMBOL} RETENTION CLEANUP SUCCESSFUL"
        exit 0
    fi
fi