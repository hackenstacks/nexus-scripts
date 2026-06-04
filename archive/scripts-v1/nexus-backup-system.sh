#!/bin/bash
# NeXuS Unified Backup System
# Centralized backup management for all NeXuS components

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
ROCKET_SYMBOL="🚀"
BACKUP_SYMBOL="💾"
NEXUS_SYMBOL="🌀"
SHIELD_SYMBOL="🛡️"

# Unified backup directory structure
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DAILY_BACKUP_DIR="$NEXUS_BACKUP_ROOT/daily"
MANUAL_BACKUP_DIR="$NEXUS_BACKUP_ROOT/manual"
RESTORE_BACKUP_DIR="$NEXUS_BACKUP_ROOT/restore-points"

# Component backup paths
CONFIGS_BACKUP="$NEXUS_BACKUP_ROOT/configs"
SCRIPTS_BACKUP="$NEXUS_BACKUP_ROOT/scripts"
SNIPPETS_BACKUP="$NEXUS_BACKUP_ROOT/snippets"
DOCUMENTS_BACKUP="$NEXUS_BACKUP_ROOT/documents"
SETTINGS_BACKUP="$NEXUS_BACKUP_ROOT/settings"

print_color() {
    echo -e "${1}${2}${NC}"
}

create_backup_structure() {
    print_color $CYAN "${BACKUP_SYMBOL} Creating NeXuS unified backup structure..."
    
    # Create main directories
    mkdir -p "$NEXUS_BACKUP_ROOT"/{daily,manual,restore-points,configs,scripts,snippets,documents,settings}
    
    # Create component subdirectories
    mkdir -p "$CONFIGS_BACKUP"/{tmux,kmscon,shell,git}
    mkdir -p "$SCRIPTS_BACKUP"/{nexus,claude,custom}
    mkdir -p "$SNIPPETS_BACKUP"/{single,multi,legacy}
    mkdir -p "$DOCUMENTS_BACKUP"/{manuals,action-reports,nexus-docs}
    mkdir -p "$SETTINGS_BACKUP"/{environment,preferences,keybindings}
    
    print_color $GREEN "✅ Backup structure created at $NEXUS_BACKUP_ROOT"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║           ${NEXUS_SYMBOL} NeXuS Unified Backup System ${NEXUS_SYMBOL}            ║"
    print_color $CYAN "║              ${SHIELD_SYMBOL} Protect Your Digital Universe ${SHIELD_SYMBOL}           ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

backup_tmux_config() {
    local backup_dir="$CONFIGS_BACKUP/tmux/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    if [ -f ~/.tmux.conf ]; then
        cp ~/.tmux.conf "$backup_dir/tmux.conf"
        print_color $GREEN "✅ tmux configuration backed up"
    fi
    
    if [ -d ~/.tmux ]; then
        cp -r ~/.tmux "$backup_dir/tmux-directory"
        print_color $GREEN "✅ tmux directory backed up"
    fi
}

backup_shell_config() {
    local backup_dir="$CONFIGS_BACKUP/shell/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # Backup shell configs
    for config in ~/.bashrc ~/.zshrc ~/.profile ~/.bash_profile ~/.zsh_profile; do
        if [ -f "$config" ]; then
            cp "$config" "$backup_dir/$(basename "$config")"
            print_color $GREEN "✅ $(basename "$config") backed up"
        fi
    done
}

backup_nexus_scripts() {
    local backup_dir="$SCRIPTS_BACKUP/nexus/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # Backup all NeXuS scripts
    if [ -d /home/user/scripts ]; then
        cp -r /home/user/scripts/* "$backup_dir/"
        print_color $GREEN "✅ NeXuS scripts backed up"
    fi
}

backup_snippets() {
    local backup_dir="$SNIPPETS_BACKUP/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    if [ -d /home/user/.config/nexus/snippets ]; then
        cp -r /home/user/.config/nexus/snippets/* "$backup_dir/"
        print_color $GREEN "✅ Snippet collection backed up"
    fi
    
    # Legacy snippet backups
    if [ -f ~/.snippetrc ]; then
        cp ~/.snippetrc "$backup_dir/legacy-snippetrc"
        print_color $GREEN "✅ Legacy snippetrc backed up"
    fi
    
    if [ -d ~/.multisnippet ]; then
        cp -r ~/.multisnippet "$backup_dir/legacy-multisnippet"
        print_color $GREEN "✅ Legacy multisnippet backed up"
    fi
}

backup_documents() {
    local backup_dir="$DOCUMENTS_BACKUP/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # NeXuS documentation and reports
    if [ -d /home/user/claude/documents ]; then
        cp -r /home/user/claude/documents/* "$backup_dir/"
        print_color $GREEN "✅ NeXuS documents backed up"
    fi
}

backup_kmscon_config() {
    local backup_dir="$CONFIGS_BACKUP/kmscon/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # KMSCON configuration
    if [ -f /etc/kmscon/kmscon.conf ]; then
        doas cp /etc/kmscon/kmscon.conf "$backup_dir/"
        print_color $GREEN "✅ KMSCON configuration backed up"
    fi
}

backup_git_config() {
    local backup_dir="$CONFIGS_BACKUP/git/$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    if [ -f ~/.gitconfig ]; then
        cp ~/.gitconfig "$backup_dir/"
        print_color $GREEN "✅ Git configuration backed up"
    fi
    
    if [ -f ~/.gitignore_global ]; then
        cp ~/.gitignore_global "$backup_dir/"
        print_color $GREEN "✅ Global gitignore backed up"
    fi
}

create_full_backup() {
    local backup_name="${1:-full_backup_$TIMESTAMP}"
    local backup_dir="$MANUAL_BACKUP_DIR/$backup_name"
    
    print_color $CYAN "${FIRE_SYMBOL} Creating full NeXuS system backup: $backup_name"
    echo
    
    create_backup_structure
    
    print_color $YELLOW "🔄 Backing up configurations..."
    backup_tmux_config
    backup_shell_config
    backup_kmscon_config
    backup_git_config
    
    print_color $YELLOW "🔄 Backing up scripts..."
    backup_nexus_scripts
    
    print_color $YELLOW "🔄 Backing up snippets..."
    backup_snippets
    
    print_color $YELLOW "🔄 Backing up documents..."
    backup_documents
    
    # Create manifest file
    cat > "$NEXUS_BACKUP_ROOT/BACKUP_MANIFEST_$TIMESTAMP.txt" << EOF
# NeXuS System Backup Manifest
Backup Name: $backup_name
Timestamp: $TIMESTAMP
Date: $(date)
System: $(uname -a)
User: $(whoami)

BACKUP CONTENTS:
├── configs/
│   ├── tmux/        - tmux.conf and plugins
│   ├── shell/       - bashrc, zshrc, profile files
│   ├── kmscon/      - terminal configuration
│   └── git/         - git configuration
├── scripts/
│   └── nexus/       - all NeXuS scripts and tools
├── snippets/        - FZF snippet system data
├── documents/       - manuals, reports, documentation
└── settings/        - preferences and environment

VERIFICATION:
Config files: $(find "$CONFIGS_BACKUP" -name "*$TIMESTAMP*" -type f | wc -l) files
Script files: $(find "$SCRIPTS_BACKUP" -name "*$TIMESTAMP*" -type f | wc -l) files  
Snippet files: $(find "$SNIPPETS_BACKUP" -name "*$TIMESTAMP*" -type f | wc -l) files
Document files: $(find "$DOCUMENTS_BACKUP" -name "*$TIMESTAMP*" -type f | wc -l) files

Total backup size: $(du -sh "$NEXUS_BACKUP_ROOT" | cut -f1)
EOF
    
    echo
    print_color $GREEN "${ROCKET_SYMBOL} Full backup completed successfully!"
    print_color $CYAN "📍 Backup location: $NEXUS_BACKUP_ROOT"
    print_color $CYAN "📋 Manifest: $NEXUS_BACKUP_ROOT/BACKUP_MANIFEST_$TIMESTAMP.txt"
}

list_backups() {
    clear
    show_banner
    print_color $WHITE "📋 Available NeXuS Backups:"
    echo
    
    if [ ! -d "$NEXUS_BACKUP_ROOT" ]; then
        print_color $RED "No backups found. Create your first backup!"
        return
    fi
    
    print_color $CYAN "🗓️  Daily Backups:"
    ls -la "$DAILY_BACKUP_DIR" 2>/dev/null | tail -n +2 | while read line; do
        echo "   $line"
    done || echo "   No daily backups found"
    
    print_color $CYAN "📦 Manual Backups:"  
    ls -la "$MANUAL_BACKUP_DIR" 2>/dev/null | tail -n +2 | while read line; do
        echo "   $line"
    done || echo "   No manual backups found"
    
    print_color $CYAN "📄 Backup Manifests:"
    ls -la "$NEXUS_BACKUP_ROOT"/BACKUP_MANIFEST_*.txt 2>/dev/null | while read line; do
        echo "   $line"
    done || echo "   No manifests found"
    
    echo
    local total_size=$(du -sh "$NEXUS_BACKUP_ROOT" 2>/dev/null | cut -f1 || echo "0")
    print_color $WHITE "💾 Total backup size: $total_size"
}

verify_backup() {
    local manifest_file="${1:-$(ls -t "$NEXUS_BACKUP_ROOT"/BACKUP_MANIFEST_*.txt 2>/dev/null | head -1)}"
    
    if [ -z "$manifest_file" ] || [ ! -f "$manifest_file" ]; then
        print_color $RED "No backup manifest found for verification"
        return 1
    fi
    
    print_color $CYAN "${SHIELD_SYMBOL} Verifying backup: $(basename "$manifest_file")"
    echo
    
    # Read backup timestamp from manifest
    local backup_timestamp=$(grep "Timestamp:" "$manifest_file" | cut -d' ' -f2)
    
    # Verify each component
    local errors=0
    
    print_color $YELLOW "🔍 Verifying configurations..."
    if [ -d "$CONFIGS_BACKUP/tmux/$backup_timestamp" ]; then
        print_color $GREEN "  ✅ tmux config verified"
    else
        print_color $RED "  ❌ tmux config missing"
        ((errors++))
    fi
    
    print_color $YELLOW "🔍 Verifying scripts..."
    if [ -d "$SCRIPTS_BACKUP/nexus/$backup_timestamp" ]; then
        print_color $GREEN "  ✅ NeXuS scripts verified"
    else
        print_color $RED "  ❌ NeXuS scripts missing"
        ((errors++))
    fi
    
    print_color $YELLOW "🔍 Verifying snippets..."
    if [ -d "$SNIPPETS_BACKUP/$backup_timestamp" ]; then
        print_color $GREEN "  ✅ Snippets verified"
    else
        print_color $RED "  ❌ Snippets missing"
        ((errors++))
    fi
    
    print_color $YELLOW "🔍 Verifying documents..."
    if [ -d "$DOCUMENTS_BACKUP/$backup_timestamp" ]; then
        print_color $GREEN "  ✅ Documents verified"
    else
        print_color $RED "  ❌ Documents missing"
        ((errors++))
    fi
    
    echo
    if [ $errors -eq 0 ]; then
        print_color $GREEN "${ROCKET_SYMBOL} Backup verification PASSED - All components present!"
    else
        print_color $RED "⚠️  Backup verification FAILED - $errors components missing!"
    fi
    
    return $errors
}

show_help() {
    clear
    show_banner
    print_color $WHITE "USAGE:"
    print_color $GREEN "  nexus-backup-system.sh create [name]     ${CYAN}# Create full backup"
    print_color $GREEN "  nexus-backup-system.sh list             ${CYAN}# List all backups"
    print_color $GREEN "  nexus-backup-system.sh verify [file]    ${CYAN}# Verify backup integrity"
    print_color $GREEN "  nexus-backup-system.sh structure        ${CYAN}# Create backup directories"
    print_color $GREEN "  nexus-backup-system.sh help             ${CYAN}# Show this help"
    echo
    
    print_color $WHITE "BACKUP LOCATIONS:"
    print_color $CYAN "  Root: $NEXUS_BACKUP_ROOT"
    print_color $CYAN "  Configs: $CONFIGS_BACKUP"
    print_color $CYAN "  Scripts: $SCRIPTS_BACKUP"  
    print_color $CYAN "  Snippets: $SNIPPETS_BACKUP"
    print_color $CYAN "  Documents: $DOCUMENTS_BACKUP"
    echo
    
    print_color $WHITE "EXAMPLES:"
    print_color $YELLOW "  nexus-backup-system.sh create pre-update"
    print_color $YELLOW "  nexus-backup-system.sh verify"
    print_color $YELLOW "  nexus-backup-system.sh list | grep $(date +%Y%m%d)"
}

# Main function
main() {
    case "${1:-help}" in
        "create"|"backup")
            show_banner
            create_full_backup "$2"
            ;;
        "list"|"ls")
            list_backups
            ;;
        "verify"|"check")
            show_banner
            verify_backup "$2"
            ;;
        "structure"|"init")
            show_banner
            create_backup_structure
            ;;
        "help"|"h"|*)
            show_help
            ;;
    esac
}

main "$@"