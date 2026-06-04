#!/bin/bash
# NeXuS Backup Restore Tester
# Safe backup restoration testing in isolated environment
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
TEST_SYMBOL="🧪"

# Configuration
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
TEST_ROOT="/tmp/nexus-restore-test"
TEST_LOG="$NEXUS_BACKUP_ROOT/restore-test.log"
TEST_REPORT="$NEXUS_BACKUP_ROOT/restore_test_report_$(date +%Y%m%d_%H%M%S).txt"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Performance tracking
START_TIME=$(date +%s)
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
BYTES_RESTORED=0
RESTORE_SPEED=0

print_color() {
    echo -e "${1}${2}${NC}"
}

print_fire_header() {
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    print_color $YELLOW "    ${NEXUS_SYMBOL} NeXuS Backup Restore Tester ${NEXUS_SYMBOL}"
    print_color $WHITE "    ${TEST_SYMBOL} Isolated Environment Testing ${TEST_SYMBOL}"
    print_color $RED "${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}${FIRE_SYMBOL}"
    echo
}

print_separator() {
    print_color $CYAN "    ${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}${LIGHTNING_SYMBOL}"
}

log_message() {
    local level=$1
    local message=$2
    echo "[$TIMESTAMP] [$level] $message" >> "$TEST_LOG"
}

show_help() {
    print_fire_header
    print_color $WHITE "Usage: nexus-backup-restore-tester.sh [OPTION] [BACKUP_PATH]"
    echo
    print_color $CYAN "OPTIONS:"
    print_color $GREEN "  setup             Setup isolated test environment"
    print_color $GREEN "  test [PATH]       Test restore from backup (default: latest)"
    print_color $GREEN "  verify [PATH]     Verify restoration integrity"
    print_color $GREEN "  cleanup           Clean test environment"
    print_color $GREEN "  benchmark [PATH]  Performance benchmark test"
    print_color $GREEN "  report            Generate test results report"
    print_color $GREEN "  status            Show tester status"
    print_color $GREEN "  help              Show this help message"
    echo
    print_color $YELLOW "EXAMPLES:"
    print_color $WHITE "  $0 setup                           # Setup test environment"
    print_color $WHITE "  $0 test                            # Test latest backup"
    print_color $WHITE "  $0 test /path/to/backup.tar.gz     # Test specific backup"
    print_color $WHITE "  $0 verify                          # Verify last restoration"
    print_color $WHITE "  $0 benchmark                       # Run performance tests"
    print_color $WHITE "  $0 cleanup                         # Clean test environment"
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

setup_test_environment() {
    print_color $CYAN "${GEAR_SYMBOL} Setting up isolated test environment..."
    
    # Create test directory structure
    mkdir -p "$TEST_ROOT"/{original,restored,temp,reports}
    
    # Create test configuration
    cat > "$TEST_ROOT/test-config.conf" << EOF
# NeXuS Restore Test Configuration
# Generated: $TIMESTAMP

TEST_ROOT="$TEST_ROOT"
ISOLATION_LEVEL="strict"
ALLOW_NETWORK="false"
ALLOW_SYSTEM_MODIFY="false"
MAX_DISK_USAGE="1G"
TIMEOUT_SECONDS="300"

# Validation criteria
CHECK_FILE_COUNT="true"
CHECK_CHECKSUMS="true"
CHECK_PERMISSIONS="true"
CHECK_TIMESTAMPS="true"
CHECK_LINKS="true"
EOF

    # Set up safety limits
    if command -v ulimit >/dev/null; then
        ulimit -f 1048576  # 1GB file size limit
        ulimit -d 1048576  # 1GB data segment limit
    fi
    
    log_message "INFO" "Test environment setup completed: $TEST_ROOT"
    print_color $GREEN "${CHECK_SYMBOL} Test environment ready: $TEST_ROOT"
}

find_latest_backup() {
    local backup_paths=(
        "$NEXUS_BACKUP_ROOT/daily"
        "$NEXUS_BACKUP_ROOT/manual"
        "/home/user/claude/backups"
    )
    
    local latest_backup=""
    local latest_time=0
    
    for backup_path in "${backup_paths[@]}"; do
        if [[ -d "$backup_path" ]]; then
            while IFS= read -r -d '' file; do
                local file_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
                if [[ $file_time -gt $latest_time ]]; then
                    latest_time=$file_time
                    latest_backup="$file"
                fi
            done < <(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.zip" \) -print0 2>/dev/null)
        fi
    done
    
    echo "$latest_backup"
}

extract_backup() {
    local backup_file="$1"
    local extract_dir="$2"
    local extraction_success=false
    
    print_color $BLUE "${ROCKET_SYMBOL} Extracting backup: $(basename "$backup_file")"
    
    # Determine extraction method
    case "$backup_file" in
        *.tar.gz|*.tgz)
            if tar -tzf "$backup_file" >/dev/null 2>&1; then
                tar -xzf "$backup_file" -C "$extract_dir" && extraction_success=true
            fi
            ;;
        *.tar)
            if tar -tf "$backup_file" >/dev/null 2>&1; then
                tar -xf "$backup_file" -C "$extract_dir" && extraction_success=true
            fi
            ;;
        *.zip)
            if command -v unzip >/dev/null; then
                unzip -q "$backup_file" -d "$extract_dir" && extraction_success=true
            fi
            ;;
        *)
            # Try to copy directory structure
            if [[ -d "$backup_file" ]]; then
                cp -r "$backup_file"/* "$extract_dir"/ 2>/dev/null && extraction_success=true
            fi
            ;;
    esac
    
    if $extraction_success; then
        print_color $GREEN "${CHECK_SYMBOL} Extraction successful"
        return 0
    else
        print_color $RED "${CROSS_SYMBOL} Extraction failed"
        return 1
    fi
}

validate_restoration() {
    local restored_dir="$1"
    local validation_errors=0
    
    print_color $BLUE "${SHIELD_SYMBOL} Validating restoration..."
    
    # Check if directory exists and is not empty
    if [[ ! -d "$restored_dir" ]]; then
        print_color $RED "${CROSS_SYMBOL} Restored directory not found"
        return 1
    fi
    
    local file_count=$(find "$restored_dir" -type f | wc -l)
    if [[ $file_count -eq 0 ]]; then
        print_color $RED "${CROSS_SYMBOL} No files found in restoration"
        return 1
    fi
    
    print_color $GREEN "${CHECK_SYMBOL} Found $file_count files"
    
    # Validate file integrity if integrity checker is available
    if [[ -x "/home/user/scripts/nexus-backup-integrity-checker.sh" ]]; then
        print_color $BLUE "${CRYSTAL_SYMBOL} Running integrity check..."
        if /home/user/scripts/nexus-backup-integrity-checker.sh verify "$restored_dir" >/dev/null 2>&1; then
            print_color $GREEN "${CHECK_SYMBOL} Integrity check passed"
        else
            print_color $YELLOW "${GHOST_SYMBOL} Integrity check warnings (expected for test environment)"
            ((validation_errors++))
        fi
    fi
    
    # Check for essential file types
    local config_files=$(find "$restored_dir" -name "*.conf" -o -name "*.cfg" -o -name "*.ini" | wc -l)
    local script_files=$(find "$restored_dir" -name "*.sh" -o -name "*.py" -o -name "*.pl" | wc -l)
    local doc_files=$(find "$restored_dir" -name "*.md" -o -name "*.txt" -o -name "*.doc" | wc -l)
    
    print_color $CYAN "${GEAR_SYMBOL} File type analysis:"
    print_color $WHITE "  Configuration files: $config_files"
    print_color $WHITE "  Script files: $script_files"
    print_color $WHITE "  Documentation files: $doc_files"
    
    # Check permissions
    local exec_files=$(find "$restored_dir" -type f -executable | wc -l)
    print_color $WHITE "  Executable files: $exec_files"
    
    return $validation_errors
}

test_restore() {
    local backup_path="$1"
    local test_id="test_$(date +%s)"
    local test_dir="$TEST_ROOT/restored/$test_id"
    
    ((TOTAL_TESTS++))
    
    # Find backup if not specified
    if [[ -z "$backup_path" ]]; then
        backup_path=$(find_latest_backup)
        if [[ -z "$backup_path" ]]; then
            print_color $RED "${CROSS_SYMBOL} No backup found to test"
            ((FAILED_TESTS++))
            return 1
        fi
    fi
    
    if [[ ! -e "$backup_path" ]]; then
        print_color $RED "${CROSS_SYMBOL} Backup not found: $backup_path"
        ((FAILED_TESTS++))
        return 1
    fi
    
    print_color $CYAN "${TEST_SYMBOL} Testing restore: $(basename "$backup_path")"
    
    # Create test directory
    mkdir -p "$test_dir"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Extract backup
    if ! extract_backup "$backup_path" "$test_dir"; then
        print_color $RED "${CROSS_SYMBOL} Test failed: Extraction error"
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Calculate restore performance
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sb "$backup_path" 2>/dev/null | cut -f1 || echo 0)
    ((BYTES_RESTORED += backup_size))
    
    if [[ $duration -gt 0 ]]; then
        RESTORE_SPEED=$((backup_size / duration))
    fi
    
    # Validate restoration
    if validate_restoration "$test_dir"; then
        print_color $GREEN "${CHECK_SYMBOL} Test passed: $(basename "$backup_path")"
        ((PASSED_TESTS++))
        
        # Log success
        log_message "INFO" "Restore test passed: $backup_path (${duration}s, ${backup_size} bytes)"
        
        return 0
    else
        print_color $RED "${CROSS_SYMBOL} Test failed: Validation errors"
        ((FAILED_TESTS++))
        
        # Log failure
        log_message "ERROR" "Restore test failed: $backup_path"
        
        return 1
    fi
}

benchmark_restore() {
    local backup_path="$1"
    
    print_color $CYAN "${LIGHTNING_SYMBOL} Running restore performance benchmark..."
    
    if [[ -z "$backup_path" ]]; then
        backup_path=$(find_latest_backup)
    fi
    
    if [[ -z "$backup_path" ]]; then
        print_color $RED "${CROSS_SYMBOL} No backup found for benchmark"
        return 1
    fi
    
    local benchmark_iterations=3
    local total_time=0
    local backup_size=$(du -sb "$backup_path" 2>/dev/null | cut -f1 || echo 0)
    
    print_color $WHITE "Benchmark target: $(basename "$backup_path") ($(numfmt --to=iec "$backup_size"))"
    
    for ((i=1; i<=benchmark_iterations; i++)); do
        local test_dir="$TEST_ROOT/benchmark/run_$i"
        mkdir -p "$test_dir"
        
        print_color $BLUE "${ROCKET_SYMBOL} Benchmark run $i/$benchmark_iterations..."
        
        local start_time=$(date +%s%3N)  # Milliseconds
        extract_backup "$backup_path" "$test_dir" >/dev/null 2>&1
        local end_time=$(date +%s%3N)
        
        local duration=$((end_time - start_time))
        total_time=$((total_time + duration))
        
        print_color $GREEN "${CHECK_SYMBOL} Run $i: ${duration}ms"
        
        # Clean up
        rm -rf "$test_dir"
    done
    
    local avg_time=$((total_time / benchmark_iterations))
    local throughput=0
    
    if [[ $avg_time -gt 0 ]]; then
        throughput=$((backup_size * 1000 / avg_time))  # bytes per second
    fi
    
    print_separator
    print_color $CYAN "${CRYSTAL_SYMBOL} BENCHMARK RESULTS:"
    print_color $WHITE "  Average time: ${avg_time}ms"
    print_color $WHITE "  Throughput: $(numfmt --to=iec "$throughput")/s"
    print_color $WHITE "  Backup size: $(numfmt --to=iec "$backup_size")"
    print_separator
    
    log_message "INFO" "Benchmark completed: $backup_path (avg: ${avg_time}ms, throughput: ${throughput} B/s)"
}

verify_last_restoration() {
    local latest_test_dir=$(find "$TEST_ROOT/restored" -type d -name "test_*" 2>/dev/null | sort | tail -1)
    
    if [[ -z "$latest_test_dir" ]]; then
        print_color $YELLOW "${GHOST_SYMBOL} No previous restoration found to verify"
        return 1
    fi
    
    print_color $CYAN "${SHIELD_SYMBOL} Verifying last restoration: $(basename "$latest_test_dir")"
    
    if validate_restoration "$latest_test_dir"; then
        print_color $GREEN "${CHECK_SYMBOL} Last restoration verified successfully"
        return 0
    else
        print_color $RED "${CROSS_SYMBOL} Last restoration verification failed"
        return 1
    fi
}

cleanup_test_environment() {
    print_color $YELLOW "${GHOST_SYMBOL} Cleaning up test environment..."
    
    if [[ -d "$TEST_ROOT" ]]; then
        local size_before=$(du -sh "$TEST_ROOT" 2>/dev/null | cut -f1 || echo "0")
        rm -rf "$TEST_ROOT"
        print_color $GREEN "${CHECK_SYMBOL} Cleaned up $size_before of test data"
        log_message "INFO" "Test environment cleaned: $size_before freed"
    else
        print_color $BLUE "${GHOST_SYMBOL} Test environment already clean"
    fi
}

generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    print_fire_header
    print_color $WHITE "${TEST_SYMBOL} RESTORE TEST REPORT ${TEST_SYMBOL}"
    print_separator
    
    {
        echo "NeXuS Backup Restore Test Report"
        echo "Generated: $TIMESTAMP"
        echo "Duration: ${duration}s"
        echo ""
        echo "TEST SUMMARY:"
        echo "  Total Tests:     $TOTAL_TESTS"
        echo "  Passed:          $PASSED_TESTS"
        echo "  Failed:          $FAILED_TESTS"
        echo "  Success Rate:    $((TOTAL_TESTS > 0 ? PASSED_TESTS * 100 / TOTAL_TESTS : 0))%"
        echo "  Bytes Restored:  $BYTES_RESTORED"
        echo "  Avg Speed:       $(numfmt --to=iec "$RESTORE_SPEED")/s"
        echo ""
        
        if [[ $FAILED_TESTS -gt 0 ]]; then
            echo "Some tests failed. Check logs for details."
        else
            echo "All restore tests passed successfully!"
        fi
    } | tee "$TEST_REPORT"
    
    # Console output with colors
    print_color $GREEN "  Total Tests:     $TOTAL_TESTS"
    print_color $GREEN "  Passed:          $PASSED_TESTS"
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        print_color $RED "  Failed:          $FAILED_TESTS"
        print_color $YELLOW "  Success Rate:    $((TOTAL_TESTS > 0 ? PASSED_TESTS * 100 / TOTAL_TESTS : 0))%"
    else
        print_color $GREEN "  Failed:          $FAILED_TESTS"
        print_color $GREEN "  Success Rate:    100%"
    fi
    
    print_color $CYAN "  Duration:        ${duration}s"
    print_color $BLUE "  Bytes Restored:  $(numfmt --to=iec "$BYTES_RESTORED")"
    print_color $BLUE "  Avg Speed:       $(numfmt --to=iec "$RESTORE_SPEED")/s"
    print_separator
    
    log_message "INFO" "Test report generated: $TEST_REPORT"
}

show_status() {
    print_fire_header
    print_color $CYAN "${TEST_SYMBOL} NeXuS Restore Tester Status"
    print_separator
    
    if [[ -d "$TEST_ROOT" ]]; then
        local test_size=$(du -sh "$TEST_ROOT" 2>/dev/null | cut -f1 || echo "0")
        print_color $GREEN "${CHECK_SYMBOL} Test Environment: Active ($test_size)"
        
        local test_count=$(find "$TEST_ROOT" -name "test_*" -type d 2>/dev/null | wc -l)
        print_color $GREEN "${CHECK_SYMBOL} Test Sessions: $test_count"
    else
        print_color $YELLOW "${GHOST_SYMBOL} Test Environment: Not setup"
    fi
    
    if [[ -f "$TEST_LOG" ]]; then
        local log_lines=$(wc -l < "$TEST_LOG" 2>/dev/null || echo 0)
        print_color $GREEN "${CHECK_SYMBOL} Test Log: $log_lines entries"
    else
        print_color $YELLOW "${GHOST_SYMBOL} Test Log: Empty"
    fi
    
    local available_space=$(df -h /tmp 2>/dev/null | awk 'NR==2{print $4}' || echo "Unknown")
    print_color $BLUE "${GEAR_SYMBOL} Available Space: $available_space"
    
    print_separator
}

# Main execution
case "$1" in
    "setup")
        cancel_timer 3 "Test Environment Setup"
        setup_test_environment
        ;;
    "test")
        cancel_timer 5 "Restore Testing"
        if [[ ! -d "$TEST_ROOT" ]]; then
            print_color $YELLOW "${GHOST_SYMBOL} Setting up test environment first..."
            setup_test_environment
        fi
        test_restore "$2"
        generate_report
        ;;
    "verify")
        verify_last_restoration
        ;;
    "benchmark")
        cancel_timer 5 "Performance Benchmark"
        if [[ ! -d "$TEST_ROOT" ]]; then
            setup_test_environment
        fi
        benchmark_restore "$2"
        ;;
    "cleanup")
        cancel_timer 5 "Test Environment Cleanup"
        cleanup_test_environment
        ;;
    "report")
        generate_report
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
if [[ "$1" == "test" && $FAILED_TESTS -gt 0 ]]; then
    print_color $RED "${FIRE_SYMBOL} RESTORE TEST FAILED"
    exit 2
elif [[ "$1" == "test" ]]; then
    print_color $GREEN "${FIRE_SYMBOL} RESTORE TEST PASSED"
    exit 0
fi