#!/bin/bash
# NEXUS Wiki Synchronization Script
# Syncs documentation between /home/user/manuals and NB knowledge base

set -e

# Configuration
MANUALS_DIR="/home/user/manuals"
CLAUDE_DOCS="/home/user/claude/documents"
NB_NOTEBOOKS=("manuals" "nexus-docs" "ai-projects" "home")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo_status() {
    echo -e "${BLUE}[WIKI-SYNC]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Backup current NB state
backup_nb() {
    echo_status "Creating NB backup..."
    BACKUP_DIR="/home/user/claude/backups/nb_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup each notebook
    for notebook in "${NB_NOTEBOOKS[@]}"; do
        if nb use "$notebook" &>/dev/null; then
            echo_status "Backing up notebook: $notebook"
            nb export --force "$BACKUP_DIR/$notebook.zip" &>/dev/null || echo_warning "Could not backup $notebook"
        fi
    done
    echo_success "NB backup created: $BACKUP_DIR"
}

# Sync manuals directory to NB
sync_manuals_to_nb() {
    echo_status "Syncing /home/user/manuals to NB manuals notebook..."
    
    nb use manuals
    
    # Find new or updated files
    find "$MANUALS_DIR" -name "*.md" -type f | while read -r file; do
        filename=$(basename "$file")
        title=$(head -n 1 "$file" | sed 's/^# //' | sed 's/^#//')
        
        # Check if file is already in NB (simple check by filename)
        if nb list | grep -q "$filename" 2>/dev/null; then
            echo_status "Updating existing: $filename"
            # Find the ID and update
            id=$(nb list --filenames | grep "$filename" | awk '{print $1}' | tr -d '[]')
            if [[ -n "$id" ]]; then
                nb edit "$id" --content "$(cat "$file")" &>/dev/null
            fi
        else
            echo_status "Adding new file: $filename"
            nb add "$file" --title "$title" &>/dev/null
        fi
    done
    
    echo_success "Manuals sync completed"
}

# Sync claude/documents to NB
sync_claude_docs_to_nb() {
    echo_status "Syncing claude/documents to NB nexus-docs notebook..."
    
    nb use nexus-docs
    
    # Sync key documents
    key_docs=(
        "action_report.md:📊 Nexus Master Action Report"
        "CLAUDE.md:🤖 Claude Configuration & Instructions"
        "NEXUS_MANIFESTO.md:🌀 Nexus System Manifesto"
        "NEXUS_TRANSACTION_REPORT.md:⚡ Nexus Transaction Report"
    )
    
    for doc_info in "${key_docs[@]}"; do
        IFS=':' read -r filename title <<< "$doc_info"
        file_path="$CLAUDE_DOCS/$filename"
        
        if [[ -f "$file_path" ]]; then
            # Check if already exists
            if nb list | grep -q "$title" 2>/dev/null; then
                echo_status "Updating: $title"
                id=$(nb list | grep "$title" | awk '{print $1}' | tr -d '[]')
                if [[ -n "$id" ]]; then
                    nb edit "$id" --content "$(cat "$file_path")" &>/dev/null
                fi
            else
                echo_status "Adding: $title"
                nb add "$file_path" --title "$title" &>/dev/null
            fi
        else
            echo_warning "File not found: $file_path"
        fi
    done
    
    echo_success "Claude documents sync completed"
}

# Update wiki index with current state
update_wiki_index() {
    echo_status "Updating wiki master index..."
    
    # Generate current stats
    total_notebooks=$(echo "${NB_NOTEBOOKS[@]}" | wc -w)
    total_files=0
    
    for notebook in "${NB_NOTEBOOKS[@]}"; do
        if nb use "$notebook" &>/dev/null; then
            count=$(nb list --no-color 2>/dev/null | wc -l || echo 0)
            total_files=$((total_files + count))
        fi
    done
    
    # Update the master index with current stats
    nb use home
    if nb list | grep -q "NEXUS Documentation Wiki" 2>/dev/null; then
        id=$(nb list | grep "NEXUS Documentation Wiki" | awk '{print $1}' | tr -d '[]' | head -n 1)
        if [[ -n "$id" ]]; then
            # Get current content and update stats section
            current_content=$(nb show "$id" --print 2>/dev/null)
            updated_content=$(echo "$current_content" | sed "s/Total Notebooks\*\*: [0-9]*/Total Notebooks**: $total_notebooks/" | sed "s/Documentation Files\*\*: [0-9]*/Documentation Files**: $total_files/")
            nb edit "$id" --content "$updated_content" &>/dev/null
            echo_success "Wiki index updated with current stats"
        fi
    fi
}

# Check NB web server status
check_web_server() {
    if curl -s http://localhost:6789 > /dev/null 2>&1; then
        echo_success "Wiki web server is running: http://localhost:6789"
        return 0
    else
        echo_warning "Wiki web server is not running"
        echo_status "Starting NB web server..."
        nohup nb browse --serve > /tmp/nb_server.log 2>&1 &
        sleep 2
        if curl -s http://localhost:6789 > /dev/null 2>&1; then
            echo_success "Wiki web server started: http://localhost:6789"
        else
            echo_error "Failed to start wiki web server"
            return 1
        fi
    fi
}

# Main sync function
main() {
    echo_status "Starting NEXUS Wiki Synchronization..."
    echo_status "Timestamp: $(date)"
    
    # Create backup
    backup_nb
    
    # Sync documentation
    sync_manuals_to_nb
    sync_claude_docs_to_nb
    
    # Update wiki
    update_wiki_index
    
    # Check web server
    check_web_server
    
    echo_success "Wiki synchronization completed successfully!"
    echo_status "Wiki available at: http://localhost:6789"
    echo_status "Total notebooks: ${#NB_NOTEBOOKS[@]}"
    echo ""
    echo_status "Quick access commands:"
    echo "  nb browse                    # Open wiki in terminal browser"
    echo "  nb search 'keyword'          # Search all documentation"
    echo "  nb use manuals && nb         # Browse manuals notebook"
    echo "  nb use nexus-docs && nb      # Browse NEXUS documentation"
}

# Handle arguments
case "${1:-}" in
    --backup-only)
        backup_nb
        ;;
    --check-server)
        check_web_server
        ;;
    --help|-h)
        echo "NEXUS Wiki Synchronization Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --backup-only    Create backup only"
        echo "  --check-server   Check/start web server only"  
        echo "  --help, -h       Show this help"
        echo ""
        echo "Default: Full sync (backup + sync + update + server check)"
        ;;
    *)
        main
        ;;
esac