#!/bin/bash
# NeXuS Off-Site Backup Encryption
# Secure your NeXuS backups for external storage and transport

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
SHIELD_SYMBOL="🛡️"
KEY_SYMBOL="🔑"
ARCHIVE_SYMBOL="📦"
NEXUS_SYMBOL="🌀"

# Paths
NEXUS_BACKUP_ROOT="/home/user/.nexus-backups"
ENCRYPTED_BACKUP_DIR="/home/user/encrypted-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

print_color() {
    echo -e "${1}${2}${NC}"
}

show_banner() {
    clear
    print_color $CYAN "╔══════════════════════════════════════════════════════════════════╗"
    print_color $CYAN "║        ${SHIELD_SYMBOL} NeXuS Off-Site Backup Encryption ${SHIELD_SYMBOL}         ║"
    print_color $CYAN "║           ${KEY_SYMBOL} Secure Your Digital Universe ${KEY_SYMBOL}            ║"
    print_color $CYAN "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

check_dependencies() {
    local missing_deps=()
    
    # Check for age (modern encryption tool)
    if ! command -v age >/dev/null 2>&1; then
        missing_deps+=("age")
    fi
    
    # Check for gzip/tar (compression)
    if ! command -v gzip >/dev/null 2>&1; then
        missing_deps+=("gzip")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_color $RED "❌ Missing dependencies: ${missing_deps[*]}"
        print_color $YELLOW "💡 Install with: doas apk add ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

create_encrypted_backup() {
    local backup_name="${1:-nexus-encrypted-$TIMESTAMP}"
    local output_file="$ENCRYPTED_BACKUP_DIR/$backup_name.tar.gz.age"
    
    show_banner
    print_color $CYAN "${FIRE_SYMBOL} Creating encrypted off-site backup: $backup_name"
    echo
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Check if backup source exists
    if [ ! -d "$NEXUS_BACKUP_ROOT" ]; then
        print_color $RED "❌ No NeXuS backups found at $NEXUS_BACKUP_ROOT"
        print_color $YELLOW "💡 Run: nexus-backup-system.sh create"
        return 1
    fi
    
    # Create encrypted backup directory
    mkdir -p "$ENCRYPTED_BACKUP_DIR"
    
    print_color $YELLOW "🔄 Step 1: Compressing NeXuS backups..."
    local temp_archive="/tmp/nexus-backup-$TIMESTAMP.tar.gz"
    
    if tar -czf "$temp_archive" -C "$(dirname "$NEXUS_BACKUP_ROOT")" "$(basename "$NEXUS_BACKUP_ROOT")"; then
        local archive_size=$(du -sh "$temp_archive" | cut -f1)
        print_color $GREEN "✅ Compression complete: $archive_size"
    else
        print_color $RED "❌ Compression failed"
        rm -f "$temp_archive"
        return 1
    fi
    
    print_color $YELLOW "🔄 Step 2: Encrypting with passphrase..."
    print_color $CYAN "💡 Choose a strong passphrase for off-site storage"
    
    if age -p -o "$output_file" "$temp_archive"; then
        local encrypted_size=$(du -sh "$output_file" | cut -f1)
        print_color $GREEN "✅ Encryption complete: $encrypted_size"
        
        # Clean up temporary file
        rm -f "$temp_archive"
        
        # Create info file
        cat > "$ENCRYPTED_BACKUP_DIR/$backup_name.info" << EOF
# NeXuS Encrypted Backup Info
Backup Name: $backup_name
Created: $(date)
Original Size: $archive_size
Encrypted Size: $encrypted_size
Encryption: age (ChaCha20-Poly1305)
Source: $NEXUS_BACKUP_ROOT

# Decryption Command:
age -d "$output_file" | tar -xzf - -C /restore/location/

# Verification:
age -d "$output_file" | tar -tzf - | head -10
EOF
        
        echo
        print_color $GREEN "${SHIELD_SYMBOL} Encrypted backup created successfully!"
        print_color $CYAN "📍 Location: $output_file"
        print_color $CYAN "📋 Info: $ENCRYPTED_BACKUP_DIR/$backup_name.info"
        print_color $YELLOW "🚨 Store passphrase securely - it cannot be recovered!"
        
    else
        print_color $RED "❌ Encryption failed"
        rm -f "$temp_archive" "$output_file"
        return 1
    fi
}

decrypt_backup() {
    local encrypted_file="$1"
    local output_dir="${2:-/tmp/nexus-restore-$TIMESTAMP}"
    
    show_banner
    print_color $CYAN "${KEY_SYMBOL} Decrypting NeXuS backup for restoration"
    echo
    
    if [ ! -f "$encrypted_file" ]; then
        print_color $RED "❌ Encrypted backup not found: $encrypted_file"
        return 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    print_color $YELLOW "🔄 Decrypting and extracting to: $output_dir"
    print_color $CYAN "🔑 Enter your backup passphrase:"
    
    if age -d "$encrypted_file" | tar -xzf - -C "$output_dir"; then
        print_color $GREEN "✅ Backup decrypted and extracted successfully!"
        print_color $CYAN "📂 Contents:"
        ls -la "$output_dir"
    else
        print_color $RED "❌ Decryption failed - check passphrase"
        return 1
    fi
}

verify_encrypted_backup() {
    local encrypted_file="$1"
    
    show_banner
    print_color $CYAN "${SHIELD_SYMBOL} Verifying encrypted backup integrity"
    echo
    
    if [ ! -f "$encrypted_file" ]; then
        print_color $RED "❌ Encrypted backup not found: $encrypted_file"
        return 1
    fi
    
    print_color $YELLOW "🔄 Testing decryption and archive integrity..."
    print_color $CYAN "🔑 Enter your backup passphrase:"
    
    if age -d "$encrypted_file" | tar -tzf - >/dev/null 2>&1; then
        print_color $GREEN "✅ Backup verification PASSED"
        print_color $CYAN "📋 Archive contents preview:"
        age -d "$encrypted_file" | tar -tzf - | head -10
        echo "..."
        local file_count=$(age -d "$encrypted_file" | tar -tzf - | wc -l)
        print_color $CYAN "📊 Total files in backup: $file_count"
    else
        print_color $RED "❌ Backup verification FAILED"
        print_color $YELLOW "💡 Check passphrase or file corruption"
        return 1
    fi
}

list_encrypted_backups() {
    show_banner
    print_color $WHITE "📦 Available Encrypted NeXuS Backups"
    echo
    
    if [ ! -d "$ENCRYPTED_BACKUP_DIR" ] || [ -z "$(ls -A "$ENCRYPTED_BACKUP_DIR" 2>/dev/null)" ]; then
        print_color $YELLOW "No encrypted backups found."
        print_color $CYAN "💡 Create one with: nexus-backup-encrypt.sh create"
        return
    fi
    
    print_color $CYAN "📍 Location: $ENCRYPTED_BACKUP_DIR"
    echo
    
    for file in "$ENCRYPTED_BACKUP_DIR"/*.age; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local size=$(du -sh "$file" | cut -f1)
            local date=$(stat -c %y "$file" | cut -d' ' -f1,2 | cut -d':' -f1,2)
            
            print_color $GREEN "🔒 $filename"
            print_color $CYAN "   📊 Size: $size"
            print_color $CYAN "   🕐 Created: $date"
            
            # Show info file if exists
            local info_file="${file%.age}.info"
            if [ -f "$info_file" ]; then
                local original_size=$(grep "Original Size:" "$info_file" | cut -d' ' -f3-)
                print_color $CYAN "   📦 Original: $original_size"
            fi
            echo
        fi
    done
    
    local total_encrypted_size=$(du -sh "$ENCRYPTED_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
    print_color $WHITE "💾 Total encrypted backup size: $total_encrypted_size"
}

clean_old_backups() {
    local keep_count="${1:-5}"
    
    show_banner
    print_color $CYAN "${FIRE_SYMBOL} Cleaning old encrypted backups (keeping $keep_count newest)"
    echo
    
    if [ ! -d "$ENCRYPTED_BACKUP_DIR" ]; then
        print_color $YELLOW "No encrypted backup directory found."
        return
    fi
    
    local backup_files=($(ls -t "$ENCRYPTED_BACKUP_DIR"/*.age 2>/dev/null))
    local total_files=${#backup_files[@]}
    
    if [ $total_files -le $keep_count ]; then
        print_color $GREEN "✅ Only $total_files backups found - no cleanup needed"
        return
    fi
    
    print_color $YELLOW "🗑️  Removing $((total_files - keep_count)) old backups..."
    
    for ((i=keep_count; i<total_files; i++)); do
        local file="${backup_files[$i]}"
        local info_file="${file%.age}.info"
        
        print_color $CYAN "  Removing: $(basename "$file")"
        rm -f "$file" "$info_file"
    done
    
    print_color $GREEN "✅ Cleanup complete - kept $keep_count newest backups"
}

show_help() {
    show_banner
    print_color $WHITE "USAGE:"
    print_color $GREEN "  nexus-backup-encrypt.sh create [name]     ${CYAN}# Create encrypted backup"
    print_color $GREEN "  nexus-backup-encrypt.sh decrypt <file>    ${CYAN}# Decrypt backup for restore"
    print_color $GREEN "  nexus-backup-encrypt.sh verify <file>     ${CYAN}# Verify backup integrity"
    print_color $GREEN "  nexus-backup-encrypt.sh list              ${CYAN}# List encrypted backups"
    print_color $GREEN "  nexus-backup-encrypt.sh clean [count]     ${CYAN}# Clean old backups (keep 5)"
    print_color $GREEN "  nexus-backup-encrypt.sh help              ${CYAN}# Show this help"
    echo
    
    print_color $WHITE "SECURITY FEATURES:"
    print_color $CYAN "  🔐 ChaCha20-Poly1305 encryption (age)"
    print_color $CYAN "  🗜️  Gzip compression (smaller backups)"
    print_color $CYAN "  🔑 Passphrase-based (no key management)"
    print_color $CYAN "  🛡️  Perfect for off-site storage"
    echo
    
    print_color $WHITE "EXAMPLES:"
    print_color $YELLOW "  nexus-backup-encrypt.sh create pre-travel-backup"
    print_color $YELLOW "  nexus-backup-encrypt.sh verify /path/to/backup.tar.gz.age"
    print_color $YELLOW "  nexus-backup-encrypt.sh decrypt backup.tar.gz.age /restore/here/"
    echo
    
    print_color $WHITE "WORKFLOW:"
    print_color $CYAN "  1. ${FIRE_SYMBOL} Create local backup: nexus-backup-system.sh create"
    print_color $CYAN "  2. 🔐 Encrypt for off-site: nexus-backup-encrypt.sh create"  
    print_color $CYAN "  3. 📤 Upload encrypted file to cloud/external drive"
    print_color $CYAN "  4. 🔑 Decrypt when needed: nexus-backup-encrypt.sh decrypt"
}

# Main function
main() {
    case "${1:-help}" in
        "create"|"encrypt")
            create_encrypted_backup "$2"
            ;;
        "decrypt"|"restore")
            if [ -z "$2" ]; then
                print_color $RED "Usage: nexus-backup-encrypt.sh decrypt <encrypted-file> [output-dir]"
                exit 1
            fi
            decrypt_backup "$2" "$3"
            ;;
        "verify"|"check")
            if [ -z "$2" ]; then
                # Verify newest backup
                local newest=$(ls -t "$ENCRYPTED_BACKUP_DIR"/*.age 2>/dev/null | head -1)
                if [ -n "$newest" ]; then
                    verify_encrypted_backup "$newest"
                else
                    print_color $RED "No encrypted backups found to verify"
                fi
            else
                verify_encrypted_backup "$2"
            fi
            ;;
        "list"|"ls")
            list_encrypted_backups
            ;;
        "clean"|"cleanup")
            clean_old_backups "$2"
            ;;
        "help"|"h"|*)
            show_help
            ;;
    esac
}

main "$@"