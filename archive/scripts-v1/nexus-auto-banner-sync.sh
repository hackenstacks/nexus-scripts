#!/bin/bash
"""
NeXuS Auto Banner Sync Script
Automatically detects and syncs Hydra banner images to web interface
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SOURCE_DIR="/home/user/Downloads/images/hydra"
DEST_DIR="/home/user/.nexus-security/hydra/web/static"
LOG_FILE="/home/user/.nexus-security/hydra/banner-sync.log"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

echo -e "${CYAN}🔥 NeXuS Auto Banner Sync Started 🔥${NC}"
echo -e "${WHITE}Source: $SOURCE_DIR${NC}"
echo -e "${WHITE}Destination: $DEST_DIR${NC}"
echo ""

# Function to log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to sync banners
sync_banners() {
    local count=0
    local new_count=0
    local updated_count=0
    
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo -e "${RED}❌ Source directory not found: $SOURCE_DIR${NC}"
        log_message "ERROR" "Source directory not found: $SOURCE_DIR"
        return 1
    fi
    
    echo -e "${YELLOW}🔍 Scanning for Hydra banners...${NC}"
    
    # Find all image files
    for file in "$SOURCE_DIR"/hydra-*.{jpg,jpeg,png,gif,webp}; do
        # Skip if no files match (glob returns literal pattern)
        [[ ! -e "$file" ]] && continue
        
        filename=$(basename "$file")
        dest_file="$DEST_DIR/$filename"
        
        count=$((count + 1))
        
        # Check if file exists and compare
        if [[ ! -f "$dest_file" ]]; then
            # New file
            cp "$file" "$dest_file"
            echo -e "${GREEN}✅ NEW: $filename${NC}"
            log_message "INFO" "New banner copied: $filename"
            new_count=$((new_count + 1))
        elif [[ "$file" -nt "$dest_file" ]]; then
            # File is newer
            cp "$file" "$dest_file"
            echo -e "${BLUE}🔄 UPDATED: $filename${NC}"
            log_message "INFO" "Banner updated: $filename"
            updated_count=$((updated_count + 1))
        else
            echo -e "${WHITE}⚪ CURRENT: $filename${NC}"
        fi
    done
    
    echo ""
    echo -e "${PURPLE}📊 Sync Summary:${NC}"
    echo -e "${WHITE}  Total banners found: $count${NC}"
    echo -e "${GREEN}  New banners: $new_count${NC}"
    echo -e "${BLUE}  Updated banners: $updated_count${NC}"
    
    log_message "INFO" "Sync completed - Total: $count, New: $new_count, Updated: $updated_count"
    
    # Generate banner list for debugging
    if [[ $count -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}🎨 Available Banners:${NC}"
        ls -1 "$DEST_DIR"/hydra-*.{jpg,jpeg,png,gif,webp} 2>/dev/null | while read -r banner; do
            filename=$(basename "$banner")
            size=$(stat -f%z "$banner" 2>/dev/null || stat -c%s "$banner" 2>/dev/null || echo "unknown")
            echo -e "${WHITE}  📸 $filename ($(numfmt --to=iec $size)B)${NC}"
        done
    fi
}

# Function to watch for changes (continuous mode)
watch_mode() {
    echo -e "${YELLOW}👁️  Entering watch mode - monitoring for changes...${NC}"
    echo -e "${WHITE}Press Ctrl+C to stop${NC}"
    echo ""
    
    # Initial sync
    sync_banners
    
    # Watch for changes using inotify if available
    if command -v inotifywait >/dev/null 2>&1; then
        log_message "INFO" "Starting inotify watch mode"
        while true; do
            inotifywait -q -e modify,create,move "$SOURCE_DIR" 2>/dev/null
            echo -e "${YELLOW}🔄 Changes detected, syncing...${NC}"
            sync_banners
            echo ""
        done
    else
        # Fallback to polling every 30 seconds
        log_message "INFO" "Starting polling watch mode (install inotify-tools for better performance)"
        while true; do
            sleep 30
            sync_banners
            echo ""
        done
    fi
}

# Function to show banner statistics
show_stats() {
    echo -e "${CYAN}📊 NeXuS Banner Statistics${NC}"
    echo ""
    
    if [[ -d "$DEST_DIR" ]]; then
        local banner_count=$(ls -1 "$DEST_DIR"/hydra-*.{jpg,jpeg,png,gif,webp} 2>/dev/null | wc -l)
        local total_size=$(du -sh "$DEST_DIR" 2>/dev/null | cut -f1)
        
        echo -e "${WHITE}📁 Banner Directory: $DEST_DIR${NC}"
        echo -e "${GREEN}🎨 Total Banners: $banner_count${NC}"
        echo -e "${BLUE}💾 Total Size: $total_size${NC}"
        echo ""
        
        if [[ $banner_count -gt 0 ]]; then
            echo -e "${PURPLE}🖼️  Banner Details:${NC}"
            ls -1 "$DEST_DIR"/hydra-*.{jpg,jpeg,png,gif,webp} 2>/dev/null | sort -V | while read -r banner; do
                if [[ -f "$banner" ]]; then
                    filename=$(basename "$banner")
                    size=$(stat -f%z "$banner" 2>/dev/null || stat -c%s "$banner" 2>/dev/null || echo "0")
                    modified=$(stat -f%Sm -t"%Y-%m-%d %H:%M" "$banner" 2>/dev/null || stat -c%y "$banner" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
                    echo -e "${WHITE}  📸 $filename - $(numfmt --to=iec $size)B - $modified${NC}"
                fi
            done
        fi
    else
        echo -e "${RED}❌ Banner directory not found${NC}"
    fi
    
    # Show recent log entries
    if [[ -f "$LOG_FILE" ]]; then
        echo ""
        echo -e "${CYAN}📝 Recent Activity (last 10 entries):${NC}"
        tail -n 10 "$LOG_FILE" | while read -r line; do
            echo -e "${WHITE}  $line${NC}"
        done
    fi
}

# Main script logic
case "${1:-sync}" in
    "sync")
        log_message "INFO" "Manual sync started"
        sync_banners
        ;;
    "watch")
        log_message "INFO" "Watch mode started"
        watch_mode
        ;;
    "stats")
        show_stats
        ;;
    "help"|"-h"|"--help")
        echo -e "${CYAN}🔥 NeXuS Auto Banner Sync Help 🔥${NC}"
        echo ""
        echo -e "${WHITE}Usage: $0 [command]${NC}"
        echo ""
        echo -e "${YELLOW}Commands:${NC}"
        echo -e "${WHITE}  sync   - Sync banners once (default)${NC}"
        echo -e "${WHITE}  watch  - Continuous monitoring mode${NC}"
        echo -e "${WHITE}  stats  - Show banner statistics${NC}"
        echo -e "${WHITE}  help   - Show this help${NC}"
        echo ""
        echo -e "${GREEN}Examples:${NC}"
        echo -e "${WHITE}  $0           # Sync once${NC}"
        echo -e "${WHITE}  $0 sync      # Sync once${NC}"
        echo -e "${WHITE}  $0 watch     # Monitor continuously${NC}"
        echo -e "${WHITE}  $0 stats     # Show statistics${NC}"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo -e "${WHITE}Use '$0 help' for usage information${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🔥 NeXuS Banner Sync Complete 🔥${NC}"
log_message "INFO" "Script completed successfully"