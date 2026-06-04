#!/bin/bash

# NeXuS Meta-Blacklist Processor
# Processes Carlos Polop's daily updated comprehensive blacklist feed
# Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!

set -e

# Fire aesthetics
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/home/user/.nexus-security/meta-blacklists"
LOG_FILE="$CONFIG_DIR/meta-blacklist-processor.log"
DATA_DIR="$CONFIG_DIR/data"
FEEDS_DIR="$CONFIG_DIR/feeds"
PROCESSED_DIR="$CONFIG_DIR/processed"

# Meta-blacklist source
META_BLACKLIST_URL="https://malwareworld.com/textlists/blacklists.txt"
META_BLACKLIST_FILE="$FEEDS_DIR/malwareworld-blacklists.txt"

print_fire() {
    echo -e "${RED}🔥${YELLOW}🔥${WHITE}🔥${CYAN} $1 ${PURPLE}🔥${YELLOW}🔥${RED}🔥${NC}"
}

print_status() {
    echo -e "${BLUE}📊 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_event() {
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}       🛡️ NeXuS META-BLACKLIST PROCESSOR 🛡️           ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}   Carlos Polop's Daily Threat Intelligence Feed        ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}   Sane • Simple • Secure NeXuS - Together MORE!        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

setup_directories() {
    print_status "Setting up directory structure..."
    
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$FEEDS_DIR" "$PROCESSED_DIR"
    mkdir -p "$PROCESSED_DIR"/{domains,ips,combined}
    
    print_success "Directory structure created"
}

download_meta_blacklist() {
    print_status "Downloading meta-blacklist from malwareworld.com..."
    
    # Download with retry logic
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s -L --max-time 30 --retry 2 "$META_BLACKLIST_URL" -o "$META_BLACKLIST_FILE"; then
            print_success "Meta-blacklist downloaded successfully"
            log_event "Meta-blacklist downloaded: $(wc -l < "$META_BLACKLIST_FILE") sources"
            return 0
        else
            attempts=$((attempts + 1))
            print_warning "Download attempt $attempts failed, retrying..."
            sleep 5
        fi
    done
    
    print_error "Failed to download meta-blacklist after $max_attempts attempts"
    return 1
}

extract_blacklist_urls() {
    print_status "Extracting blacklist URLs from meta-feed..."
    
    if [[ ! -f "$META_BLACKLIST_FILE" ]]; then
        print_error "Meta-blacklist file not found"
        return 1
    fi
    
    # Extract URLs (skip comments and empty lines)
    grep -E '^https?://' "$META_BLACKLIST_FILE" | grep -v '^#' > "$DATA_DIR/blacklist-urls.txt"
    
    local url_count=$(wc -l < "$DATA_DIR/blacklist-urls.txt")
    print_success "Extracted $url_count blacklist URLs"
    log_event "Extracted $url_count URLs from meta-feed"
}

categorize_blacklist_sources() {
    print_status "Categorizing blacklist sources by type..."
    
    # Create category files
    > "$DATA_DIR/malware-sources.txt"
    > "$DATA_DIR/ip-sources.txt"
    > "$DATA_DIR/domain-sources.txt"
    > "$DATA_DIR/mixed-sources.txt"
    > "$DATA_DIR/tor-sources.txt"
    > "$DATA_DIR/botnet-sources.txt"
    
    while IFS= read -r url; do
        # Categorize based on URL patterns
        case "$url" in
            *"malware"*|*"virus"*|*"trojan"*)
                echo "$url" >> "$DATA_DIR/malware-sources.txt"
                ;;
            *"tor"*|*"exit"*)
                echo "$url" >> "$DATA_DIR/tor-sources.txt"
                ;;
            *"botnet"*|*"c2"*|*"cnc"*)
                echo "$url" >> "$DATA_DIR/botnet-sources.txt"
                ;;
            *"ip"*|*"/ips/"*|*"iplist"*)
                echo "$url" >> "$DATA_DIR/ip-sources.txt"
                ;;
            *"domain"*|*"host"*)
                echo "$url" >> "$DATA_DIR/domain-sources.txt"
                ;;
            *)
                echo "$url" >> "$DATA_DIR/mixed-sources.txt"
                ;;
        esac
    done < "$DATA_DIR/blacklist-urls.txt"
    
    print_success "Sources categorized by threat type"
}

download_and_process_feeds() {
    print_status "Downloading and processing individual blacklist feeds..."
    
    local total_domains=0
    local total_ips=0
    local processed_feeds=0
    local failed_feeds=0
    
    # Create consolidated files
    > "$PROCESSED_DIR/domains/all-malicious-domains.txt"
    > "$PROCESSED_DIR/ips/all-malicious-ips.txt"
    > "$PROCESSED_DIR/combined/nexus-threat-intelligence.txt"
    
    # Process each URL with timeout and error handling
    while IFS= read -r url; do
        print_status "Processing: $(basename "$url")"
        
        local filename=$(echo "$url" | sed 's|https\?://||g' | tr '/' '_' | tr ':' '_')
        local temp_file="$FEEDS_DIR/$filename.tmp"
        
        # Download with timeout
        if timeout 30 curl -s -L --max-time 20 "$url" -o "$temp_file" 2>/dev/null; then
            if [[ -s "$temp_file" ]]; then
                # Process based on content type
                local domains_found=0
                local ips_found=0
                
                # Extract domains (basic pattern matching)
                grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$temp_file" 2>/dev/null | \
                grep -v '^[0-9.]*$' | \
                sort -u >> "$PROCESSED_DIR/domains/all-malicious-domains.txt"
                domains_found=$(grep -cE '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$temp_file" 2>/dev/null || echo 0)
                
                # Extract IPs
                grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$temp_file" 2>/dev/null | \
                sort -u >> "$PROCESSED_DIR/ips/all-malicious-ips.txt"
                ips_found=$(grep -cE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$temp_file" 2>/dev/null || echo 0)
                
                total_domains=$((total_domains + domains_found))
                total_ips=$((total_ips + ips_found))
                processed_feeds=$((processed_feeds + 1))
                
                # Create source-specific files
                mv "$temp_file" "$FEEDS_DIR/$filename"
                
                echo "# Source: $url (Domains: $domains_found, IPs: $ips_found)" >> "$PROCESSED_DIR/combined/nexus-threat-intelligence.txt"
            else
                print_warning "Empty response from $url"
                failed_feeds=$((failed_feeds + 1))
                rm -f "$temp_file"
            fi
        else
            print_warning "Failed to download: $url"
            failed_feeds=$((failed_feeds + 1))
            rm -f "$temp_file"
        fi
        
        # Rate limiting - be nice to servers
        sleep 2
    done < "$DATA_DIR/blacklist-urls.txt"
    
    # Remove duplicates and clean up
    sort -u "$PROCESSED_DIR/domains/all-malicious-domains.txt" -o "$PROCESSED_DIR/domains/all-malicious-domains.txt"
    sort -u "$PROCESSED_DIR/ips/all-malicious-ips.txt" -o "$PROCESSED_DIR/ips/all-malicious-ips.txt"
    
    # Final counts
    local final_domains=$(wc -l < "$PROCESSED_DIR/domains/all-malicious-domains.txt")
    local final_ips=$(wc -l < "$PROCESSED_DIR/ips/all-malicious-ips.txt")
    
    print_success "Processing complete:"
    echo -e "${WHITE}  📊 Feeds processed: $processed_feeds${NC}"
    echo -e "${WHITE}  ❌ Feeds failed: $failed_feeds${NC}"
    echo -e "${WHITE}  🌐 Malicious domains: $final_domains${NC}"
    echo -e "${WHITE}  🔢 Malicious IPs: $final_ips${NC}"
    
    log_event "Processing complete: $processed_feeds feeds, $final_domains domains, $final_ips IPs"
}

create_privoxy_format() {
    print_status "Converting to Privoxy format..."
    
    # Create Privoxy action file
    cat > "$PROCESSED_DIR/combined/nexus-meta-blacklist.action" << 'EOF'
# NeXuS Meta-Blacklist (Generated from malwareworld.com daily feed)
# Professional threat intelligence from 70+ sources
# Generated: $(date)

{+block{NeXuS Meta-Blacklist: Malicious Domain}}
EOF
    
    # Add domains in Privoxy format
    if [[ -f "$PROCESSED_DIR/domains/all-malicious-domains.txt" ]]; then
        while IFS= read -r domain; do
            # Convert to Privoxy format
            echo ".$domain" >> "$PROCESSED_DIR/combined/nexus-meta-blacklist.action"
        done < "$PROCESSED_DIR/domains/all-malicious-domains.txt"
    fi
    
    print_success "Privoxy format created"
}

create_hosts_format() {
    print_status "Creating hosts file format..."
    
    cat > "$PROCESSED_DIR/combined/nexus-meta-blacklist.hosts" << EOF
# NeXuS Meta-Blacklist (Hosts format)
# Generated from malwareworld.com daily feed
# Generated: $(date)
# Domains: $(wc -l < "$PROCESSED_DIR/domains/all-malicious-domains.txt" 2>/dev/null || echo 0)
# IPs: $(wc -l < "$PROCESSED_DIR/ips/all-malicious-ips.txt" 2>/dev/null || echo 0)

EOF
    
    # Add domains in hosts format
    if [[ -f "$PROCESSED_DIR/domains/all-malicious-domains.txt" ]]; then
        while IFS= read -r domain; do
            echo "0.0.0.0 $domain" >> "$PROCESSED_DIR/combined/nexus-meta-blacklist.hosts"
        done < "$PROCESSED_DIR/domains/all-malicious-domains.txt"
    fi
    
    print_success "Hosts format created"
}

create_statistics_report() {
    print_status "Generating statistics report..."
    
    cat > "$PROCESSED_DIR/nexus-meta-blacklist-stats.txt" << EOF
NeXuS Meta-Blacklist Processing Report
Generated: $(date)
Source: $META_BLACKLIST_URL

SUMMARY:
- Total blacklist sources: $(wc -l < "$DATA_DIR/blacklist-urls.txt" 2>/dev/null || echo 0)
- Malicious domains found: $(wc -l < "$PROCESSED_DIR/domains/all-malicious-domains.txt" 2>/dev/null || echo 0)
- Malicious IPs found: $(wc -l < "$PROCESSED_DIR/ips/all-malicious-ips.txt" 2>/dev/null || echo 0)

CATEGORIES:
- Malware sources: $(wc -l < "$DATA_DIR/malware-sources.txt" 2>/dev/null || echo 0)
- IP blacklists: $(wc -l < "$DATA_DIR/ip-sources.txt" 2>/dev/null || echo 0)
- Domain blacklists: $(wc -l < "$DATA_DIR/domain-sources.txt" 2>/dev/null || echo 0)
- Tor exit nodes: $(wc -l < "$DATA_DIR/tor-sources.txt" 2>/dev/null || echo 0)
- Botnet sources: $(wc -l < "$DATA_DIR/botnet-sources.txt" 2>/dev/null || echo 0)
- Mixed sources: $(wc -l < "$DATA_DIR/mixed-sources.txt" 2>/dev/null || echo 0)

FILES GENERATED:
- Privoxy format: $PROCESSED_DIR/combined/nexus-meta-blacklist.action
- Hosts format: $PROCESSED_DIR/combined/nexus-meta-blacklist.hosts
- Domain list: $PROCESSED_DIR/domains/all-malicious-domains.txt
- IP list: $PROCESSED_DIR/ips/all-malicious-ips.txt

INTEGRATION:
Copy the Privoxy action file to your Privoxy configuration directory and add:
actionsfile nexus-meta-blacklist.action

AUTOMATION:
Add to crontab for daily updates:
0 6 * * * /home/user/scripts/nexus-meta-blacklist-processor.sh update >/dev/null 2>&1
EOF

    print_success "Statistics report generated"
}

integrate_with_nexus_system() {
    print_status "Integrating with NeXuS Privoxy system..."
    
    local privoxy_config_dir="/home/user/.nexus-security/privoxy-professional/config"
    
    if [[ -d "$privoxy_config_dir" ]]; then
        # Copy action file to Privoxy config
        cp "$PROCESSED_DIR/combined/nexus-meta-blacklist.action" "$privoxy_config_dir/"
        
        # Update Privoxy config if not already included
        local privoxy_conf="$privoxy_config_dir/privoxy.conf"
        if [[ -f "$privoxy_conf" ]] && ! grep -q "nexus-meta-blacklist.action" "$privoxy_conf"; then
            echo "actionsfile nexus-meta-blacklist.action" >> "$privoxy_conf"
        fi
        
        print_success "Integrated with NeXuS Privoxy system"
        
        # Restart Privoxy container if running
        if podman ps | grep -q "nexus-privoxy"; then
            print_status "Restarting Privoxy to load new blacklists..."
            podman restart nexus-privoxy-professional 2>/dev/null || true
        fi
    else
        print_warning "NeXuS Privoxy config directory not found"
    fi
}

run_full_update() {
    show_banner
    print_fire "Starting NeXuS Meta-Blacklist Update Process"
    echo
    
    setup_directories
    
    if download_meta_blacklist; then
        extract_blacklist_urls
        categorize_blacklist_sources
        download_and_process_feeds
        create_privoxy_format
        create_hosts_format
        create_statistics_report
        integrate_with_nexus_system
        
        echo
        print_fire "NeXuS Meta-Blacklist Processing COMPLETE"
        echo -e "${GREEN}🛡️ Professional threat intelligence active${NC}"
        echo -e "${CYAN}📊 Daily updates from 70+ security sources${NC}"
        echo -e "${YELLOW}🔒 Enhanced protection against malware & threats${NC}"
        
        log_event "Full meta-blacklist update completed successfully"
    else
        print_error "Meta-blacklist update failed"
        return 1
    fi
}

show_status() {
    show_banner
    print_fire "NeXuS Meta-Blacklist Status"
    echo
    
    if [[ -f "$PROCESSED_DIR/nexus-meta-blacklist-stats.txt" ]]; then
        cat "$PROCESSED_DIR/nexus-meta-blacklist-stats.txt"
    else
        print_warning "No statistics available. Run update first."
    fi
    
    echo
    print_status "Recent log entries:"
    if [[ -f "$LOG_FILE" ]]; then
        tail -5 "$LOG_FILE"
    else
        echo "No log entries found."
    fi
}

setup_automation() {
    print_status "Setting up automated daily updates..."
    
    # Create systemd service
    cat > "/tmp/nexus-meta-blacklist.service" << EOF
[Unit]
Description=NeXuS Meta-Blacklist Daily Update
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/nexus-meta-blacklist-processor.sh update
User=user
WorkingDirectory=/home/user

[Install]
WantedBy=default.target
EOF

    # Create systemd timer
    cat > "/tmp/nexus-meta-blacklist.timer" << EOF
[Unit]
Description=NeXuS Meta-Blacklist Daily Update Timer
Requires=nexus-meta-blacklist.service

[Timer]
OnCalendar=*-*-* 06:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    print_success "Automation files created in /tmp/"
    print_status "To install: sudo cp /tmp/nexus-meta-blacklist.* /etc/systemd/system/"
    print_status "Then: sudo systemctl enable --now nexus-meta-blacklist.timer"
}

main() {
    case "${1:-status}" in
        "update")
            run_full_update
            ;;
        "status")
            show_status
            ;;
        "setup-automation")
            setup_automation
            ;;
        "quick-stats")
            if [[ -f "$PROCESSED_DIR/domains/all-malicious-domains.txt" ]]; then
                echo "Domains: $(wc -l < "$PROCESSED_DIR/domains/all-malicious-domains.txt")"
                echo "IPs: $(wc -l < "$PROCESSED_DIR/ips/all-malicious-ips.txt")"
                echo "Last update: $(stat -c %y "$PROCESSED_DIR/domains/all-malicious-domains.txt" 2>/dev/null || echo "Never")"
            else
                echo "No data available. Run update first."
            fi
            ;;
        *)
            echo "NeXuS Meta-Blacklist Processor"
            echo "Processes Carlos Polop's daily threat intelligence feed"
            echo "Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!"
            echo
            echo "Usage: $0 {update|status|setup-automation|quick-stats}"
            echo
            echo "Commands:"
            echo "  update           - Download and process latest threat intelligence"
            echo "  status           - Show detailed processing statistics"
            echo "  setup-automation - Create systemd timer for daily updates"
            echo "  quick-stats      - Show brief statistics"
            echo
            echo "Features:"
            echo "  🛡️ 70+ professional threat intelligence sources"
            echo "  📅 Daily automated updates available"
            echo "  🎯 Categorized by threat type (malware, botnets, etc.)"
            echo "  🔗 Automatic NeXuS Privoxy integration"
            echo "  📊 Comprehensive statistics and reporting"
            exit 1
            ;;
    esac
}

# Initialize log
mkdir -p "$CONFIG_DIR"
log_event "NeXuS Meta-Blacklist Processor started"

# Run main function
main "$@"