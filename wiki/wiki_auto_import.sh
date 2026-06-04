#!/bin/bash
# NEXUS Wiki Auto-Import Daemon
# Automatically monitors directories for new documentation and imports to wiki

set -e

# Configuration
WATCH_DIRS=(
    "/home/user/manuals"
    "/home/user/claude/documents"
    "/home/user/ai-character-generator"
    "/home/user/Projects"
)

IGNORE_PATTERNS=(
    "*.tmp"
    "*.bak"  
    "*.backup"
    "*~"
    "*.swp"
    ".git/*"
    "*.pyc"
    "__pycache__/*"
)

LOG_FILE="/tmp/wiki_auto_import.log"
PID_FILE="/tmp/wiki_auto_import.pid"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    
    case "$level" in
        "INFO")  color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARNING") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "IMPORT") color="$CYAN" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
}

# Smart document categorization
categorize_document() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    local dir_path=$(dirname "$file_path")
    
    # Determine target notebook based on path and content
    if [[ "$dir_path" == *"/manuals"* ]]; then
        echo "manuals"
    elif [[ "$dir_path" == *"/claude/documents"* ]]; then
        echo "nexus-docs"
    elif [[ "$dir_path" == *"/ai-character-generator"* ]] || [[ "$filename" == *"character"* ]] || [[ "$filename" == *"ai"* ]]; then
        echo "ai-projects"
    elif [[ "$filename" == *"nexus"* ]] || [[ "$filename" == *"NEXUS"* ]]; then
        echo "nexus-docs"
    else
        # Analyze content for smart categorization
        if [[ -f "$file_path" ]]; then
            local content=$(head -20 "$file_path" 2>/dev/null)
            if echo "$content" | grep -qi -E "(cli|command|terminal|shell|bash)"; then
                echo "manuals"
            elif echo "$content" | grep -qi -E "(ai|character|bot|llm|gpt|claude)"; then
                echo "ai-projects"
            elif echo "$content" | grep -qi -E "(nexus|system|architecture|config)"; then
                echo "nexus-docs"
            else
                echo "home"
            fi
        else
            echo "home"
        fi
    fi
}

# Generate smart title from filename and content
generate_title() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # Check if file has a title in first few lines
    if [[ -f "$file_path" ]]; then
        local first_line=$(head -1 "$file_path" 2>/dev/null | sed 's/^#* *//')
        if [[ -n "$first_line" && ${#first_line} -lt 100 ]]; then
            echo "$first_line"
            return
        fi
    fi
    
    # Generate title from filename
    local title=$(echo "$filename" | sed 's/\.[^.]*$//' | sed 's/_/ /g' | sed 's/-/ /g')
    
    # Add appropriate emoji based on content/type
    case "$filename" in
        *manual*|*guide*|*doc*) title="📚 $title" ;;
        *config*|*setup*) title="⚙️ $title" ;;
        *report*|*log*) title="📊 $title" ;;
        *nexus*|*NEXUS*) title="🌀 $title" ;;
        *cli*|*CLI*) title="💻 $title" ;;
        *ai*|*AI*|*character*) title="🤖 $title" ;;
        *security*|*backup*) title="🔐 $title" ;;
        *system*) title="⚡ $title" ;;
        *.md) title="📝 $title" ;;
        *) title="📄 $title" ;;
    esac
    
    echo "$title"
}

# Import document to appropriate notebook
import_document() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # Skip if file doesn't exist or is empty
    if [[ ! -f "$file_path" ]] || [[ ! -s "$file_path" ]]; then
        log_message "WARNING" "Skipping empty or non-existent file: $file_path"
        return
    fi
    
    # Skip if file matches ignore patterns
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            log_message "INFO" "Ignoring file matching pattern $pattern: $filename"
            return
        fi
    done
    
    # Only process documentation files
    case "$filename" in
        *.md|*.txt|*.rst|*.org|*.adoc)
            ;;
        *)
            log_message "INFO" "Skipping non-documentation file: $filename"
            return
            ;;
    esac
    
    local notebook=$(categorize_document "$file_path")
    local title=$(generate_title "$file_path")
    
    log_message "IMPORT" "Processing: $filename -> $notebook:$title"
    
    # Switch to target notebook
    if ! nb use "$notebook" &>/dev/null; then
        log_message "ERROR" "Failed to switch to notebook: $notebook"
        return
    fi
    
    # Check if document already exists (by title or filename)
    if nb list --no-color 2>/dev/null | grep -q "$title" || nb list --filenames --no-color 2>/dev/null | grep -q "$filename"; then
        log_message "INFO" "Document already exists, updating: $title"
        
        # Find existing entry and update
        local existing_id=$(nb list --no-color 2>/dev/null | grep "$title" | head -1 | awk '{print $1}' | tr -d '[]')
        if [[ -z "$existing_id" ]]; then
            existing_id=$(nb list --filenames --no-color 2>/dev/null | grep "$filename" | head -1 | awk '{print $1}' | tr -d '[]')
        fi
        
        if [[ -n "$existing_id" ]]; then
            if nb edit "$existing_id" --content "$(cat "$file_path")" &>/dev/null; then
                log_message "SUCCESS" "Updated existing document: $title (ID: $existing_id)"
            else
                log_message "ERROR" "Failed to update document: $title"
            fi
        else
            log_message "WARNING" "Could not find existing document ID for: $title"
        fi
    else
        # Import new document — copies actual file content into notebook
        if nb import "$file_path" &>/dev/null; then
            log_message "SUCCESS" "Imported new document: $title"
            update_wiki_references "$notebook" "$title"
        else
            log_message "ERROR" "Failed to import document: $title"
        fi
    fi
}

# Update wiki cross-references for major documents
update_wiki_references() {
    local notebook="$1"
    local title="$2"
    
    # Only update references for major documents
    case "$title" in
        *"Manual"*|*"Guide"*|*"Report"*|*"Index"*|*"Nexus"*|*"System"*)
            log_message "INFO" "Updating wiki cross-references for: $title"
            
            # Add reference to master wiki index
            nb use home
            local wiki_index_id=$(nb list --no-color 2>/dev/null | grep "NEXUS Documentation Wiki" | head -1 | awk '{print $1}' | tr -d '[]')
            
            if [[ -n "$wiki_index_id" ]]; then
                local current_content=$(nb show "$wiki_index_id" --print 2>/dev/null)
                local reference_line="- [[$notebook:$title]] - Auto-imported documentation"
                
                # Add reference if not already present
                if ! echo "$current_content" | grep -q "$title"; then
                    local updated_content=$(echo "$current_content" | sed "/### 📖 \*\*Recently Added\*\*/a\\
$reference_line")
                    
                    # If "Recently Added" section doesn't exist, add it
                    if ! echo "$current_content" | grep -q "Recently Added"; then
                        updated_content=$(echo "$current_content" | sed "/## 📊 \*\*Quick Stats\*\*/i\\
\\
### 📖 **Recently Added**\\
$reference_line\\")
                    fi
                    
                    nb edit "$wiki_index_id" --content "$updated_content" &>/dev/null
                    log_message "SUCCESS" "Updated wiki index with new reference: $title"
                fi
            fi
            ;;
    esac
}

# Monitor directories for changes
start_monitoring() {
    log_message "INFO" "Starting Wiki Auto-Import Daemon"
    log_message "INFO" "PID: $$"
    
    # Save PID
    echo $$ > "$PID_FILE"
    
    # Monitor all watch directories
    for watch_dir in "${WATCH_DIRS[@]}"; do
        if [[ -d "$watch_dir" ]]; then
            log_message "INFO" "Monitoring directory: $watch_dir"
        else
            log_message "WARNING" "Watch directory not found: $watch_dir"
        fi
    done
    
    # Start inotify monitoring
    inotifywait -m -r -e create,moved_to,modify --format '%w%f %e' "${WATCH_DIRS[@]}" 2>/dev/null | while read file event; do
        # Process the file change
        case "$event" in
            CREATE|MOVED_TO)
                log_message "INFO" "New file detected: $file ($event)"
                sleep 1  # Brief delay to ensure file is fully written
                import_document "$file"
                ;;
            MODIFY)
                log_message "INFO" "File modified: $file"
                sleep 1  # Brief delay to ensure file is fully written  
                import_document "$file"
                ;;
        esac
        
        # Run a quick sync to ensure consistency
        if [[ -f "/home/user/scripts/wiki_sync.sh" ]]; then
            /home/user/scripts/wiki_sync.sh --check-server &>/dev/null || true
        fi
    done
}

# Stop monitoring
stop_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "INFO" "Stopping Wiki Auto-Import Daemon (PID: $pid)"
            kill "$pid"
            rm -f "$PID_FILE"
            log_message "SUCCESS" "Wiki Auto-Import Daemon stopped"
        else
            log_message "WARNING" "Daemon not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        log_message "WARNING" "No PID file found"
    fi
}

# Check daemon status
check_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "SUCCESS" "Wiki Auto-Import Daemon is running (PID: $pid)"
            log_message "INFO" "Log file: $LOG_FILE"
            echo ""
            echo "Recent activity:"
            tail -10 "$LOG_FILE" 2>/dev/null || echo "No recent activity"
            return 0
        else
            log_message "ERROR" "Daemon not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log_message "INFO" "Wiki Auto-Import Daemon is not running"
        return 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    start)
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log_message "WARNING" "Daemon already running"
            exit 1
        fi
        start_monitoring
        ;;
    stop)
        stop_monitoring
        ;;
    restart)
        stop_monitoring
        sleep 2
        start_monitoring
        ;;
    status)
        check_status
        ;;
    test)
        log_message "INFO" "Testing import on all watched directories..."
        for watch_dir in "${WATCH_DIRS[@]}"; do
            if [[ -d "$watch_dir" ]]; then
                find "$watch_dir" -name "*.md" -type f -mtime -1 | head -5 | while read -r file; do
                    log_message "INFO" "Testing import: $file"
                    import_document "$file"
                done
            fi
        done
        log_message "SUCCESS" "Test import completed"
        ;;
    --help|-h)
        echo "NEXUS Wiki Auto-Import Daemon"
        echo ""
        echo "Automatically monitors directories for new documentation files"
        echo "and imports them into the appropriate NB notebook."
        echo ""
        echo "Usage: $0 {start|stop|restart|status|test}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the monitoring daemon"
        echo "  stop     - Stop the monitoring daemon"
        echo "  restart  - Restart the monitoring daemon"
        echo "  status   - Check daemon status and show recent activity"
        echo "  test     - Test import functionality on recent files"
        echo ""
        echo "Watched directories:"
        printf "  %s\n" "${WATCH_DIRS[@]}"
        echo ""
        echo "Log file: $LOG_FILE"
        echo "PID file: $PID_FILE"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|test|--help}"
        echo "Run '$0 --help' for detailed information"
        exit 1
        ;;
esac