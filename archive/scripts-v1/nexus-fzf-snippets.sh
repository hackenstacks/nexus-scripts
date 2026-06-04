#!/bin/bash
# NeXuS FZF Snippet Manager
# Enhanced version based on gotbletu's fzf-snippet implementation
# 
# ORIGINAL WORK ATTRIBUTION:
# Author: gotbletu
# Source: https://github.com/gotbletu/shownotes
# Video: https://www.youtube.com/watch?v=Zew0mgJwAh8
# License: GPLv3 - https://www.gnu.org/licenses/gpl-3.0.txt
#
# NeXuS ENHANCEMENTS:
# - Integrated with NeXuS ecosystem
# - Enhanced UI with colors and symbols
# - Multiple clipboard system support
# - Backup and versioning
# - NeXuS-specific snippets and workflows

# Colors and symbols for NeXuS theme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# NeXuS symbols
FIRE_SYMBOL="🔥"
ROCKET_SYMBOL="🚀"
SNIPPET_SYMBOL="📋"
NEXUS_SYMBOL="🌀"

# Configuration paths
NEXUS_SNIPPETS_DIR="$HOME/.config/nexus/snippets"
SINGLE_SNIPPETS_FILE="$NEXUS_SNIPPETS_DIR/single_snippets.txt"
MULTI_SNIPPETS_DIR="$NEXUS_SNIPPETS_DIR/multi"
NEXUS_SCRIPTS_DIR="/home/user/scripts"

# Unified backup system integration
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
SNIPPETS_BACKUP_DIR="$NEXUS_BACKUP_ROOT/snippets"

print_color() {
    echo -e "${1}${2}${NC}"
}

# Create necessary directories and files
setup_snippets() {
    mkdir -p "$NEXUS_SNIPPETS_DIR"
    mkdir -p "$MULTI_SNIPPETS_DIR"
    touch "$SINGLE_SNIPPETS_FILE"
    
    # Create backup of existing snippets if they exist
    if [ -f ~/.snippetrc ]; then
        print_color $YELLOW "${SNIPPET_SYMBOL} Found existing ~/.snippetrc, backing up..."
        mkdir -p "$SNIPPETS_BACKUP_DIR/legacy"
        cp ~/.snippetrc "$SNIPPETS_BACKUP_DIR/legacy/snippetrc_backup_$(date +%Y%m%d_%H%M%S).txt"
        
        # Import existing snippets
        if [ ! -s "$SINGLE_SNIPPETS_FILE" ]; then
            cat ~/.snippetrc > "$SINGLE_SNIPPETS_FILE"
            print_color $GREEN "✓ Imported existing snippets to NeXuS system"
        fi
    fi
    
    # Import legacy multisnippets if they exist
    if [ -d ~/.multisnippet ]; then
        print_color $YELLOW "${SNIPPET_SYMBOL} Found existing ~/.multisnippet, importing..."
        cp -r ~/.multisnippet/* "$MULTI_SNIPPETS_DIR/" 2>/dev/null || true
        print_color $GREEN "✓ Imported existing multi-snippets to NeXuS system"
    fi
}

# Enhanced single-line snippet function (based on gotbletu's fzf-snippet)
nexus_fzf_snippet() {
    if [ ! -f "$SINGLE_SNIPPETS_FILE" ] || [ ! -s "$SINGLE_SNIPPETS_FILE" ]; then
        print_color $RED "No single-line snippets found. Create some first!"
        return 1
    fi
    
    local selected
    selected="$(cat "$SINGLE_SNIPPETS_FILE" | sed '/^$/d' | sort -n | fzf -e -i --prompt="${SNIPPET_SYMBOL} Single Snippet > " --header="NeXuS Snippet Manager - Single Line Snippets")"
    
    if [ -n "$selected" ]; then
        # Remove tags, leading and trailing spaces, also no newline (gotbletu's original logic)
        local clean_snippet
        clean_snippet="$(echo "$selected" | sed -e s/\;\;\.\*\$// | sed 's/^[ \t]*//;s/[ \t]*$//' | tr -d '\n')"
        
        # Enhanced clipboard system - multiple targets for compatibility
        echo "$clean_snippet" | /home/user/scripts/cli_clipboard.sh copy
        
        # Also try other clipboard methods for maximum compatibility
        echo "$clean_snippet" | xclip -selection clipboard 2>/dev/null || true
        echo "$clean_snippet" | wl-copy 2>/dev/null || true
        
        print_color $GREEN "${ROCKET_SYMBOL} Snippet copied to clipboard: $(echo "$clean_snippet" | cut -c1-50)..."
    fi
}

# Enhanced multi-line snippet function (based on gotbletu's fzf-multisnippet)
nexus_fzf_multisnippet() {
    if [ ! -d "$MULTI_SNIPPETS_DIR" ] || [ -z "$(ls -A "$MULTI_SNIPPETS_DIR" 2>/dev/null)" ]; then
        print_color $RED "No multi-line snippets found. Create some first!"
        return 1
    fi
    
    # Merge filename and tags into single line (gotbletu's original approach)
    local results
    results=$(for FILE in "$MULTI_SNIPPETS_DIR"/*; do
        [ -f "$FILE" ] || continue
        local getname=$(basename "$FILE")
        local gettags=$(head -n 1 "$FILE")
        echo "$getname \t $gettags" 
    done)
    
    if [ -z "$results" ]; then
        print_color $RED "No valid multi-line snippets found."
        return 1
    fi
    
    # Select snippet with enhanced UI
    local selection
    selection=$(echo "$results" | fzf -e -i --prompt="${SNIPPET_SYMBOL} Multi Snippet > " --header="NeXuS Snippet Manager - Multi-Line Snippets")
    
    if [ -n "$selection" ]; then
        local filename
        filename=$(echo "$selection" | cut -d' ' -f 1)
        
        # Copy content into clipboard without tags (gotbletu's original logic)
        if [ -f "$MULTI_SNIPPETS_DIR/$filename" ]; then
            local content
            content=$(sed 1d "$MULTI_SNIPPETS_DIR/$filename")
            
            # Enhanced clipboard system
            echo "$content" | /home/user/scripts/cli_clipboard.sh copy
            echo "$content" | xclip -selection clipboard 2>/dev/null || true
            echo "$content" | wl-copy 2>/dev/null || true
            
            print_color $GREEN "${ROCKET_SYMBOL} Multi-snippet '$filename' copied to clipboard"
        fi
    fi
}

# Create new single-line snippet
create_single_snippet() {
    print_color $CYAN "${SNIPPET_SYMBOL} Creating new single-line snippet..."
    echo "Enter your snippet text:"
    read -r snippet_text
    echo "Enter tags (separated by spaces, will be prefixed with ;;):"
    read -r snippet_tags
    
    if [ -n "$snippet_text" ]; then
        if [ -n "$snippet_tags" ]; then
            echo "$snippet_text;;$snippet_tags" >> "$SINGLE_SNIPPETS_FILE"
        else
            echo "$snippet_text" >> "$SINGLE_SNIPPETS_FILE"
        fi
        print_color $GREEN "${ROCKET_SYMBOL} Single-line snippet added successfully!"
    fi
}

# Create new multi-line snippet
create_multi_snippet() {
    print_color $CYAN "${SNIPPET_SYMBOL} Creating new multi-line snippet..."
    echo "Enter snippet filename:"
    read -r filename
    
    if [ -z "$filename" ]; then
        print_color $RED "Filename cannot be empty!"
        return 1
    fi
    
    local filepath="$MULTI_SNIPPETS_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        print_color $YELLOW "File already exists. Edit it? (y/n)"
        read -r confirm
        [ "$confirm" != "y" ] && return 0
    fi
    
    ${EDITOR:-nano} "$filepath"
    
    if [ -f "$filepath" ]; then
        print_color $GREEN "${ROCKET_SYMBOL} Multi-line snippet '$filename' created/updated successfully!"
    fi
}

# List all snippets
list_snippets() {
    print_color $CYAN "${NEXUS_SYMBOL} NeXuS Snippet Collection:"
    echo
    
    print_color $WHITE "📝 Single-line snippets:"
    if [ -f "$SINGLE_SNIPPETS_FILE" ] && [ -s "$SINGLE_SNIPPETS_FILE" ]; then
        wc -l < "$SINGLE_SNIPPETS_FILE" | xargs -I{} echo "   {} snippets available"
    else
        echo "   No single-line snippets found"
    fi
    
    print_color $WHITE "📄 Multi-line snippets:"
    if [ -d "$MULTI_SNIPPETS_DIR" ]; then
        local count=$(ls -1 "$MULTI_SNIPPETS_DIR" 2>/dev/null | wc -l)
        echo "   $count snippets available"
        if [ $count -gt 0 ]; then
            ls -1 "$MULTI_SNIPPETS_DIR" | sed 's/^/   - /'
        fi
    else
        echo "   No multi-line snippets found"
    fi
}

# Show help
show_help() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║                 ${NEXUS_SYMBOL} NeXuS FZF Snippet Manager ${NEXUS_SYMBOL}                 ║"
    print_color $CYAN "║            Enhanced version based on gotbletu's work             ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
    
    print_color $WHITE "ORIGINAL WORK:"
    print_color $YELLOW "  Author: gotbletu (https://github.com/gotbletu)"
    print_color $YELLOW "  License: GPLv3"
    print_color $YELLOW "  Tutorial: https://www.youtube.com/watch?v=Zew0mgJwAh8"
    echo
    
    print_color $WHITE "COMMANDS:"
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh single       ${CYAN}# Select single-line snippet"
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh multi        ${CYAN}# Select multi-line snippet"  
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh create-single${CYAN}# Create single-line snippet"
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh create-multi ${CYAN}# Create multi-line snippet"
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh list         ${CYAN}# List all snippets"
    print_color $GREEN "  ${FIRE_SYMBOL} nexus-fzf-snippets.sh setup        ${CYAN}# Initialize snippet system"
    echo
    
    print_color $WHITE "TMUX INTEGRATION:"
    print_color $YELLOW "  Add to ~/.tmux.conf:"
    print_color $GREEN "  bind-key \"'\" new-window -n snippet \\; send-keys \"nexus-fzf-snippets.sh single && tmux kill-window\\n\""
    print_color $GREEN "  bind-key '\"' new-window -n multisnippet \\; send-keys \"nexus-fzf-snippets.sh multi && tmux kill-window\\n\""
    echo
    
    print_color $WHITE "FILES:"
    print_color $CYAN "  Single snippets: $SINGLE_SNIPPETS_FILE"
    print_color $CYAN "  Multi snippets:  $MULTI_SNIPPETS_DIR/"
}

# Main function
main() {
    case "${1:-help}" in
        "single"|"s")
            setup_snippets
            nexus_fzf_snippet
            ;;
        "multi"|"m")
            setup_snippets
            nexus_fzf_multisnippet
            ;;
        "create-single"|"cs")
            setup_snippets
            create_single_snippet
            ;;
        "create-multi"|"cm")
            setup_snippets
            create_multi_snippet
            ;;
        "list"|"l")
            setup_snippets
            list_snippets
            ;;
        "setup")
            setup_snippets
            print_color $GREEN "${ROCKET_SYMBOL} NeXuS snippet system initialized!"
            ;;
        "help"|"h"|*)
            show_help
            ;;
    esac
}

main "$@"