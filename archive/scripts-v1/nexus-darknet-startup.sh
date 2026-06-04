#!/bin/bash

# NeXuS Darknet VM - Comprehensive Startup Script
# Version: 1.0
# Description: Complete deployment and management script for the hardened darknet VM

set -e  # Exit on error
set -u  # Exit on undefined variables

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Configuration
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/nexus-stack" && pwd)"
DOC_COMPOSE="docker-compose.hardened-vm.yml"
LOG_DIR="${CONFIG_DIR}/logs"
BACKUP_DIR="${CONFIG_DIR}/backups"

# Functions

# Display header
show_header() {
    clear
    echo -e "${BLUE}
╔════════════════════════════════════════════════════════════════╗"
    echo -e "║  NeXuS Darknet VM - Comprehensive Startup Script v1.0       ║"
    echo -e "╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Check dependencies
check_dependencies() {
    echo -e "${YELLOW}[*] Checking dependencies...${NC}"
    
    local missing_deps=0
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[-] Docker not found. Please install Docker.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}[+] Docker: $(docker --version | cut -d' ' -f3)${NC}"
    fi
    
    # Check docker-compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}[-] Docker Compose not found. Please install Docker Compose.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}[+] Docker Compose: $(docker-compose --version | cut -d' ' -f3)${NC}"
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}[-] Git not found. Please install Git.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}[+] Git: $(git --version | cut -d' ' -f3)${NC}"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[-] Curl not found. Please install Curl.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}[+] Curl: $(curl --version | head -1 | cut -d' ' -f2)${NC}"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        echo -e "${RED}[!] Missing dependencies detected. Exiting.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[*] All dependencies satisfied.${NC}\n"
}

# Setup directories
setup_directories() {
    echo -e "${YELLOW}[*] Setting up directories...${NC}"
    
    # Create config directory if it doesn't exist
    if [ ! -d "${CONFIG_DIR}" ]; then
        echo -e "${BLUE}[i] Creating config directory...${NC}"
        mkdir -p "${CONFIG_DIR}"
    fi
    
    # Create log directory
    if [ ! -d "${LOG_DIR}" ]; then
        echo -e "${BLUE}[i] Creating log directory...${NC}"
        mkdir -p "${LOG_DIR}"
    fi
    
    # Create backup directory
    if [ ! -d "${BACKUP_DIR}" ]; then
        echo -e "${BLUE}[i] Creating backup directory...${NC}"
        mkdir -p "${BACKUP_DIR}"
    fi
    
    # Create monitoring directories
    if [ ! -d "${CONFIG_DIR}/grafana-dashboards" ]; then
        echo -e "${BLUE}[i] Creating Grafana dashboards directory...${NC}"
        mkdir -p "${CONFIG_DIR}/grafana-dashboards"
    fi
    
    echo -e "${GREEN}[*] Directory setup complete.${NC}\n"
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}[*] Installing system dependencies...${NC}"
    
    # Update system
    echo -e "${BLUE}[i] Updating system packages...${NC}"
    sudo apt update && sudo apt upgrade -y
    
    # Install required packages
    echo -e "${BLUE}[i] Installing required packages...${NC}"
    sudo apt install -y \
        docker.io \
        docker-compose \
        curl \
        git \
        net-tools \
        htop \
        tmux \
        openssl \
        ufw \
        zip \
        unzip
    
    # Add user to docker group
    if ! groups | grep -q docker; then
        echo -e "${BLUE}[i] Adding user to docker group...${NC}"
        sudo usermod -aG docker $USER
        echo -e "${YELLOW}[!] You may need to log out and back in for docker group changes to take effect.${NC}"
    fi
    
    echo -e "${GREEN}[*] Dependency installation complete.${NC}\n"
}

# Clone repository
clone_repository() {
    echo -e "${YELLOW}[*] Cloning repository...${NC}"
    
    local repo_url="https://github.com/your-repo/nexus-darknet-vm.git"
    local target_dir="$(dirname "${CONFIG_DIR}")"
    
    if [ -d "${target_dir}/.git" ]; then
        echo -e "${BLUE}[i] Repository already exists. Pulling latest changes...${NC}"
        cd "${target_dir}"
        git pull
    else
        echo -e "${BLUE}[i] Cloning repository from ${repo_url}...${NC}"
        cd "$(dirname "${target_dir}")"
        git clone "${repo_url}" "$(basename "${target_dir}")"
    fi
    
    # Change to config directory
    cd "${CONFIG_DIR}"
    
    echo -e "${GREEN}[*] Repository setup complete.${NC}\n"
}

# Prepare configuration
prepare_configuration() {
    echo -e "${YELLOW}[*] Preparing configuration...${NC}"
    
    # Make scripts executable
    if [ -f "tor-manager.sh" ]; then
        echo -e "${BLUE}[i] Making scripts executable...${NC}"
        chmod +x tor-manager.sh
    fi
    
    # Check if docker-compose file exists
    if [ ! -f "${DOC_COMPOSE}" ]; then
        echo -e "${RED}[-] Docker compose file not found: ${DOC_COMPOSE}${NC}"
        echo -e "${RED}[!] Please ensure you have cloned the repository correctly.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[*] Configuration preparation complete.${NC}\n"
}

# Start services
default_start() {
    echo -e "${YELLOW}[*] Starting NeXuS Darknet VM services...${NC}"
    
    # Start all services
    echo -e "${BLUE}[i] Deploying containers...${NC}"
    docker-compose -f "${DOC_COMPOSE}" up -d
    
    # Wait for services to initialize
    echo -e "${BLUE}[i] Waiting for services to initialize...${NC}"
    sleep 15
    
    # Verify deployment
    echo -e "${BLUE}[i] Verifying service status...${NC}"
    local running_containers=$(docker-compose -f "${DOC_COMPOSE}" ps -q | wc -l)
    local expected_containers=15  # Adjust based on your actual service count
    
    if [ "$running_containers" -lt "$expected_containers" ]; then
        echo -e "${RED}[-] Only $running_containers/$expected_containers containers are running.${NC}"
        echo -e "${RED}[!] Check logs for errors.${NC}"
        docker-compose -f "${DOC_COMPOSE}" logs --tail=20
        return 1
    else
        echo -e "${GREEN}[+] All $running_containers containers are running successfully.${NC}"
    fi
    
    echo -e "${GREEN}[*] Service deployment complete.${NC}\n"
}

# Test connectivity
test_connectivity() {
    echo -e "${YELLOW}[*] Testing connectivity...${NC}"
    
    # Test Tor
    echo -e "${BLUE}[i] Testing Tor connectivity...${NC}"
    if curl --socks5 localhost:9050 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
        echo -e "${GREEN}[+] Tor: Connected successfully${NC}"
    else
        echo -e "${RED}[-] Tor: Connection failed${NC}"
    fi
    
    # Test I2P
    echo -e "${BLUE}[i] Testing I2P connectivity...${NC}"
    if curl --proxy http://localhost:4444 http://i2p-projekt.i2p/ 2>/dev/null | grep -q 'I2P'; then
        echo -e "${GREEN}[+] I2P: Connected successfully${NC}"
    else
        echo -e "${YELLOW}[!] I2P: Still connecting (may take 5-10 minutes)${NC}"
    fi
    
    # Test HAProxy
    echo -e "${BLUE}[i] Testing HAProxy...${NC}"
    if curl -s http://localhost:8404/stats 2>/dev/null | grep -q 'haproxy'; then
        echo -e "${GREEN}[+] HAProxy: Running successfully${NC}"
    else
        echo -e "${RED}[-] HAProxy: Not responding${NC}"
    fi
    
    echo -e "${GREEN}[*] Connectivity tests complete.${NC}\n"
}

# Show status
show_status() {
    echo -e "${YELLOW}[*] Service Status:${NC}"
    
    # Get service status
    docker-compose -f "${DOC_COMPOSE}" ps --format "table {{.Name}}\t{{.Status}}\t{{.Service}}"
    
    # Show resource usage
    echo -e "\n${YELLOW}[*] Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo -e "${GREEN}[*] Status display complete.${NC}\n"
}

# Backup configuration
backup_configuration() {
    echo -e "${YELLOW}[*] Creating backup...${NC}"
    
    local backup_name="nexus-backup-$(date +%Y%m%d-%H%M%S).zip"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    echo -e "${BLUE}[i] Backing up configuration files...${NC}"
    
    # Create backup
    cd "${CONFIG_DIR}"
    zip -r "${backup_path}" \
        *.yml \
        *.cfg \
        *.conf \
        *.sh \
        grafana-dashboards/
    
    echo -e "${GREEN}[+] Backup created: ${backup_path}${NC}"
    
    # Show backup info
    ls -lh "${backup_path}"
    
    echo -e "${GREEN}[*] Backup complete.${NC}\n"
}

# Restore configuration
restore_configuration() {
    echo -e "${YELLOW}[*] Restoring configuration...${NC}"
    
    # List available backups
    echo -e "${BLUE}[i] Available backups:${NC}"
    ls -lh "${BACKUP_DIR}"/nexus-backup-*.zip
    
    # Ask for backup to restore
    read -p "Enter backup filename to restore: " backup_file
    
    if [ ! -f "${BACKUP_DIR}/${backup_file}" ]; then
        echo -e "${RED}[-] Backup file not found.${NC}"
        return 1
    fi
    
    # Confirm restoration
    read -p "Are you sure you want to restore from ${backup_file}? (y/n): " confirm
    if [ "${confirm}" != "y" ]; then
        echo -e "${YELLOW}[!] Restoration cancelled.${NC}"
        return 0
    fi
    
    echo -e "${BLUE}[i] Restoring configuration...${NC}"
    
    # Extract backup
    cd "${CONFIG_DIR}"
    unzip -o "${BACKUP_DIR}/${backup_file}"
    
    echo -e "${GREEN}[+] Configuration restored successfully.${NC}"
    echo -e "${YELLOW}[!] You may need to restart services for changes to take effect.${NC}"
    
    echo -e "${GREEN}[*] Restoration complete.${NC}\n"
}

# Update services
update_services() {
    echo -e "${YELLOW}[*] Updating services...${NC}"
    
    # Backup current configuration
    echo -e "${BLUE}[i] Creating pre-update backup...${NC}"
    backup_configuration
    
    # Pull latest images
    echo -e "${BLUE}[i] Pulling latest container images...${NC}"
    docker-compose -f "${DOC_COMPOSE}" pull
    
    # Recreate containers
    echo -e "${BLUE}[i] Recreating containers with latest images...${NC}"
    docker-compose -f "${DOC_COMPOSE}" up -d --force-recreate
    
    # Clean up unused images
    echo -e "${BLUE}[i] Cleaning up unused images...${NC}"
    docker system prune -f
    
    echo -e "${GREEN}[*] Update complete.${NC}\n"
}

# Show access information
show_access_info() {
    echo -e "${YELLOW}[*] Access Information:${NC}"
    
    cat << EOF

┌─────────────────────────────────────────────────────────────────┐
│                    NeXuS Darknet VM - Access Points              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🌐 PROXY SERVICES:                                               │
│    • Tor SOCKS:      socks5://localhost:9050                     │
│    • HTTP Proxy:     http://localhost:8118                        │
│    • High BW:       socks5://localhost:8887                     │
│    • I2P HTTP:      http://localhost:4444                        │
│                                                                  │
│  📊 MONITORING:                                                   │
│    • Grafana:       http://localhost:3000   (admin/admin)        │
│    • Prometheus:    http://localhost:9090                        │
│    • HAProxy Stats: http://localhost:8404   (admin/NeXuS@dm1n!23) │
│    • Alertmanager:  http://localhost:9093                        │
│                                                                  │
│  🔧 MANAGEMENT:                                                  │
│    • Discovery API: http://localhost:8765                        │
│    • I2P Console:   http://localhost:7070                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

EOF
    
    echo -e "${GREEN}[*] Access information displayed.${NC}\n"
}

# Show help
show_help() {
    cat << EOF

${BLUE}NeXuS Darknet VM - Startup Script Help${NC}

${YELLOW}Usage:${NC}
    $0 [OPTION]

${YELLOW}Options:${NC}
    start           Start all services (default)
    stop            Stop all services
    restart         Restart all services
    status          Show service status
    test            Test connectivity
    backup          Create configuration backup
    restore         Restore configuration from backup
    update          Update all services
    install         Install dependencies and setup
    access          Show access information
    help            Show this help message

${YELLOW}Examples:${NC}
    $0 start                # Start all services
    $0 test                 # Test connectivity
    $0 backup               # Create backup
    $0 update               # Update services

${YELLOW}Quick Commands:${NC}
    # Check logs:           docker-compose logs --tail=50
    # Manual Tor cycle:     docker exec nexus-tor-manager /usr/local/bin/tor-manager.sh
    # View resources:       docker stats $(docker ps -q)

EOF
}

# Main menu
main_menu() {
    show_header
    
    cat << EOF

${YELLOW}Main Menu:${NC}

1.  Start Services (Default)
2.  Stop Services
3.  Restart Services
4.  Show Status
5.  Test Connectivity
6.  Create Backup
7.  Restore Backup
8.  Update Services
9.  Show Access Info
10. Install Dependencies
11. Full Setup (Install + Start)
12. Exit

EOF
    
    read -p "Enter your choice [1-12]: " choice
    
    case $choice in
        1|"") start_services ;;
        2) stop_services ;;
        3) restart_services ;;
        4) show_status ;;
        5) test_connectivity ;;
        6) backup_configuration ;;
        7) restore_configuration ;;
        8) update_services ;;
        9) show_access_info ;;
        10) install_dependencies ;;
        11) full_setup ;;
        12) exit 0 ;;
        *) echo -e "${RED}[!] Invalid choice.${NC}" ;;
    esac
}

# Service management functions
start_services() {
    show_header
    echo -e "${YELLOW}[*] Starting services...${NC}"
    
    cd "${CONFIG_DIR}"
    prepare_configuration
    default_start
    test_connectivity
    show_status
    
    read -p "Press Enter to continue..."
    main_menu
}

stop_services() {
    show_header
    echo -e "${YELLOW}[*] Stopping services...${NC}"
    
    cd "${CONFIG_DIR}"
    docker-compose -f "${DOC_COMPOSE}" down
    
    echo -e "${GREEN}[*] Services stopped.${NC}"
    
    read -p "Press Enter to continue..."
    main_menu
}

restart_services() {
    show_header
    echo -e "${YELLOW}[*] Restarting services...${NC}"
    
    cd "${CONFIG_DIR}"
    docker-compose -f "${DOC_COMPOSE}" restart
    
    echo -e "${GREEN}[*] Services restarted.${NC}"
    
    read -p "Press Enter to continue..."
    main_menu
}

full_setup() {
    show_header
    echo -e "${YELLOW}[*] Running full setup...${NC}"
    
    check_dependencies
    install_dependencies
    setup_directories
    clone_repository
    prepare_configuration
    default_start
    test_connectivity
    show_status
    show_access_info
    
    read -p "Press Enter to continue..."
    main_menu
}

# Main execution

# Check if we're in the right directory
if [ -f "${CONFIG_DIR}/docker-compose.hardened-vm.yml" ]; then
    cd "${CONFIG_DIR}"
fi

# Handle command line arguments
if [ $# -gt 0 ]; then
    case $1 in
        start) start_services ;;
        stop) stop_services ;;
        restart) restart_services ;;
        status) show_status ;;
        test) test_connectivity ;;
        backup) backup_configuration ;;
        restore) restore_configuration ;;
        update) update_services ;;
        install) install_dependencies ;;
        access) show_access_info ;;
        help|--help|-h) show_help ;;
        *) show_help ;;
    esac
else
    # Interactive menu
    while true; do
        main_menu
    done
fi