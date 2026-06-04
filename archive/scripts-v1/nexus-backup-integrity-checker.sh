#!/bin/bash
# NeXuS Backup Integrity Checker
# SHA256-based backup verification with corruption detection
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

# Configuration
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
INTEGRITY_LOG="$NEXUS_BACKUP_ROOT/integrity.log"
CHECKSUM_DB="$NEXUS_BACKUP_ROOT/checksums.db"
CORRUPTION_REPORT="$NEXUS_BACKUP_ROOT/corruption_report_$(date +%Y%m%d_%H%M%S).txt"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Performance tracking
START_TIME=$(date +%s)
TOTAL_FILES=0
VERIFIED_FILES=0
CORRUPTED_FILES=0
NEW_FILES=0
BYTES_PROCESSED=0

print_color() {
    echo -e "${1}${2}${NC}"
}

print_fire_header() {
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    print_color $YELLOW "    ${NEXUS_SYMBOL} NeXuS Backup Integrity Checker ${NEXUS_SYMBOL}"
    print_color $WHITE "    ${CRYSTAL_SYMBOL} SHA256 Verification & Corruption Detection ${CRYSTAL_SYMBOL}"
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    echo
}

print_separator() {
    print_color $CYAN "    ${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}"
}

log_message() {
    local level=$1
    local message=$2
    echo "[$TIMESTAMP] [$level] $message" >> "$INTEGRITY_LOG"
}

show_help() {
    print_fire_header
    print_color $WHITE "Usage: nexus-backup-integrity-checker.sh [OPTION] [PATH]"
    echo
    print_color $CYAN "OPTIONS:"
    print_color $GREEN "  init              Initialize checksum database"
    print_color $GREEN "  verify [PATH]     Verify backup integrity (default: all backups)"
    print_color $GREEN "  update [PATH]     Update checksums for new/modified files"
    print_color $GREEN "  report            Generate integrity status report"
    print_color $GREEN "  repair            Attempt to repair corrupted backups"
    print_color $GREEN "  status            Show integrity checker status"
    print_color $GREEN "  help              Show this help message"
    echo
    print_color $YELLOW "EXAMPLES:"
    print_color $WHITE "  $0 init                    # Initialize integrity system"
    print_color $WHITE "  $0 verify                  # Verify all backups"
    print_color $WHITE "  $0 verify /path/to/backup  # Verify specific backup"
    print_color $WHITE "  $0 update                  # Update checksums for new files"
    print_color $WHITE "  $0 report                  # Generate integrity report"
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

initialize_checksum_db() {
    print_color $CYAN "${BACKUP_SYMBOL} Initializing NeXuS checksum database..."
    
    # Create necessary directories
    mkdir -p "$(dirname "$CHECKSUM_DB")"
    mkdir -p "$(dirname "$INTEGRITY_LOG")"
    
    # Initialize database
    echo "# NeXuS Backup Integrity Database" > "$CHECKSUM_DB"
    echo "# Format: CHECKSUM|FILE_PATH|SIZE|TIMESTAMP" >> "$CHECKSUM_DB"
    echo "# Generated: $TIMESTAMP" >> "$CHECKSUM_DB"
    
    log_message "INFO" "Checksum database initialized"
    print_color $GREEN "${CHECK_SYMBOL} Checksum database initialized successfully"
}

calculate_checksum() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        sha256sum "$file_path" | cut -d' ' -f1
    else
        echo "FILE_NOT_FOUND"
    fi
}

get_file_size() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

add_to_checksum_db() {
    local file_path="$1"
    local checksum="$2"
    local size="$3"
    local timestamp="$4"
    
    echo "$checksum|$file_path|$size|$timestamp" >> "$CHECKSUM_DB"
}

get_stored_checksum() {
    local file_path="$1"
    grep "|$file_path|" "$CHECKSUM_DB" 2>/dev/null | cut -d'|' -f1 | tail -1
}

verify_file() {
    local file_path="$1"
    local current_checksum
    local stored_checksum
    local file_size
    
    # Skip if file doesn't exist
    if [[ ! -f "$file_path" ]]; then
        return 2
    fi
    
    ((TOTAL_FILES++))
    file_size=$(get_file_size "$file_path")
    ((BYTES_PROCESSED += file_size))
    
    # Calculate current checksum
    printf "${BLUE}${SHIELD_SYMBOL} Verifying: ${NC}$(basename "$file_path")..."
    current_checksum=$(calculate_checksum "$file_path")
    
    # Get stored checksum
    stored_checksum=$(get_stored_checksum "$file_path")
    
    if [[ -z "$stored_checksum" ]]; then
        # New file - add to database
        add_to_checksum_db "$file_path" "$current_checksum" "$file_size" "$TIMESTAMP"
        printf "\r${YELLOW}${ROCKET_SYMBOL} New file: ${NC}$(basename "$file_path") ${GREEN}[ADDED]${NC}\n"
        ((NEW_FILES++))
        log_message "INFO" "New file added: $file_path"
        return 0
    elif [[ "$current_checksum" == "$stored_checksum" ]]; then
        # File is intact
        printf "\r${GREEN}${CHECK_SYMBOL} Verified: ${NC}$(basename "$file_path") ${GREEN}[OK]${NC}       \n"
        ((VERIFIED_FILES++))
        return 0
    else
        # File is corrupted
        printf "\r${RED}${CROSS_SYMBOL} CORRUPTED: ${NC}$(basename "$file_path") ${RED}[FAIL]${NC}     \n"
        ((CORRUPTED_FILES++))
        
        # Log corruption details
        echo "CORRUPTION DETECTED: $file_path" >> "$CORRUPTION_REPORT"
        echo "  Expected: $stored_checksum" >> "$CORRUPTION_REPORT"
        echo "  Actual:   $current_checksum" >> "$CORRUPTION_REPORT"
        echo "  Size:     $file_size bytes" >> "$CORRUPTION_REPORT"
        echo "  Time:     $TIMESTAMP" >> "$CORRUPTION_REPORT"
        echo "" >> "$CORRUPTION_REPORT"
        
        log_message "ERROR" "Corruption detected: $file_path"
        return 1
    fi
}

verify_directory() {
    local dir_path="$1"
    local file_count=0
    
    print_color $CYAN "${FIRE_SYMBOL} Scanning directory: $dir_path"
    
    # Find all files and verify them
    while IFS= read -r -d '' file; do
        verify_file "$file"
        ((file_count++))
        
        # Progress indicator every 10 files
        if ((file_count % 10 == 0)); then
            print_color $BLUE "${LIGHTNING_SYMBOL} Progress: $file_count files processed..."
        fi
    done < <(find "$dir_path" -type f -print0 2>/dev/null)
    
    print_color $GREEN "${CHECK_SYMBOL} Directory scan complete: $file_count files processed"
}

verify_backups() {
    local target_path="$1"
    
    print_color $CYAN "${BACKUP_SYMBOL} Starting backup integrity verification..."
    
    if [[ -n "$target_path" && -e "$target_path" ]]; then
        if [[ -f "$target_path" ]]; then
            verify_file "$target_path"
        else
            verify_directory "$target_path"
        fi
    else
        # Verify all backup locations
        local backup_paths=(
            "$NEXUS_BACKUP_ROOT"
            "/home/user/claude/backups"
        )
        
        for backup_path in "${backup_paths[@]}"; do
            if [[ -d "$backup_path" ]]; then
                verify_directory "$backup_path"
            fi
        done
    fi
}

update_checksums() {
    local target_path="$1"
    
    print_color $CYAN "${ROCKET_SYMBOL} Updating checksums for new/modified files..."
    
    if [[ -n "$target_path" ]]; then
        if [[ -f "$target_path" ]]; then
            verify_file "$target_path"
        else
            verify_directory "$target_path"
        fi
    else
        verify_backups
    fi
    
    print_color $GREEN "${CHECK_SYMBOL} Checksum update completed"
}

generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local report_file="$NEXUS_BACKUP_ROOT/integrity_report_$(date +%Y%m%d_%H%M%S).txt"
    
    print_fire_header
    print_color $WHITE "${CRYSTAL_SYMBOL} INTEGRITY VERIFICATION REPORT ${CRYSTAL_SYMBOL}"
    print_separator
    
    {
        echo "NeXuS Backup Integrity Report"
        echo "Generated: $TIMESTAMP"
        echo "Duration: ${duration}s"
        echo ""
        echo "SUMMARY:"
        echo "  Total Files:     $TOTAL_FILES"
        echo "  Verified OK:     $VERIFIED_FILES"
        echo "  New Files:       $NEW_FILES"
        echo "  Corrupted:       $CORRUPTED_FILES"
        echo "  Bytes Processed: $BYTES_PROCESSED"
        echo ""
        
        if [[ $CORRUPTED_FILES -gt 0 ]]; then
            echo "CORRUPTION DETECTED!"
            echo "See: $CORRUPTION_REPORT"
        else
            echo "All backups verified successfully!"
        fi
    } | tee "$report_file"
    
    # Console output with colors
    print_color $GREEN "  Total Files:     $TOTAL_FILES"
    print_color $GREEN "  Verified OK:     $VERIFIED_FILES"
    print_color $YELLOW "  New Files:       $NEW_FILES"
    
    if [[ $CORRUPTED_FILES -gt 0 ]]; then
        print_color $RED "  Corrupted:       $CORRUPTED_FILES"
        print_color $RED "${GHOST_SYMBOL} CORRUPTION DETECTED! Check: $CORRUPTION_REPORT"
    else
        print_color $GREEN "  Corrupted:       $CORRUPTED_FILES"
        print_color $GREEN "${CHECK_SYMBOL} All backups verified successfully!"
    fi
    
    print_color $CYAN "  Duration:        ${duration}s"
    print_color $BLUE "  Bytes Processed: $BYTES_PROCESSED"
    print_separator
    
    log_message "INFO" "Integrity report generated: $report_file"
}

repair_corrupted_backups() {
    if [[ ! -f "$CORRUPTION_REPORT" ]]; then
        print_color $YELLOW "${GHOST_SYMBOL} No corruption report found. Run verification first."
        return 1
    fi
    
    print_color $RED "${FIRE_SYMBOL} Corruption repair feature requires manual intervention"
    print_color $YELLOW "${GHOST_SYMBOL} Corrupted files found in: $CORRUPTION_REPORT"
    print_color $CYAN "Recommended actions:"
    print_color $WHITE "  1. Review corruption report"
    print_color $WHITE "  2. Restore from older backups"
    print_color $WHITE "  3. Re-create backups from source"
    print_color $WHITE "  4. Update checksums after repair"
}

show_status() {
    print_fire_header
    print_color $CYAN "${BACKUP_SYMBOL} NeXuS Integrity Checker Status"
    print_separator
    
    if [[ -f "$CHECKSUM_DB" ]]; then
        local db_entries=$(grep -v '^#' "$CHECKSUM_DB" | wc -l)
        print_color $GREEN "${CHECK_SYMBOL} Checksum Database: $db_entries entries"
    else
        print_color $RED "${CROSS_SYMBOL} Checksum Database: Not initialized"
    fi
    
    if [[ -f "$INTEGRITY_LOG" ]]; then
        local log_size=$(du -h "$INTEGRITY_LOG" | cut -f1)
        print_color $GREEN "${CHECK_SYMBOL} Integrity Log: $log_size"
    else
        print_color $YELLOW "${GHOST_SYMBOL} Integrity Log: Empty"
    fi
    
    if [[ -f "$CORRUPTION_REPORT" ]]; then
        print_color $RED "${CROSS_SYMBOL} Corruption Report: $(basename "$CORRUPTION_REPORT")"
    else
        print_color $GREEN "${CHECK_SYMBOL} No corruption detected"
    fi
    
    print_separator
}

# Main execution
case "$1" in
    "init")
        cancel_timer 3 "Database Initialization"
        initialize_checksum_db
        ;;
    "verify")
        cancel_timer 5 "Integrity Verification"
        if [[ ! -f "$CHECKSUM_DB" ]]; then
            print_color $YELLOW "${GHOST_SYMBOL} Database not initialized. Initializing first..."
            initialize_checksum_db
        fi
        verify_backups "$2"
        generate_report
        ;;
    "update")
        cancel_timer 3 "Checksum Update"
        if [[ ! -f "$CHECKSUM_DB" ]]; then
            initialize_checksum_db
        fi
        update_checksums "$2"
        ;;
    "report")
        generate_report
        ;;
    "repair")
        cancel_timer 5 "Corruption Repair Analysis"
        repair_corrupted_backups
        ;;
    "status")
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
if [[ "$1" == "verify" || "$1" == "update" ]]; then
    if [[ $CORRUPTED_FILES -gt 0 ]]; then
        print_color $RED "${FIRE_SYMBOL} INTEGRITY CHECK FAILED - Corruption detected!"
        exit 2
    else
        print_color $GREEN "${FIRE_SYMBOL} INTEGRITY CHECK PASSED - All backups verified!"
        exit 0
    fi
fi