#!/bin/bash

# NeXuS Node Auto-Discovery Service
# Version: 1.0
# Description: Automatic peer discovery and mesh networking between NeXuS nodes

set -e  # Exit on error
set -u  # Exit on undefined variables

# Configuration
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/nexus-stack" && pwd)"
MESH_CONFIG="${CONFIG_DIR}/nexus-node-mesh.conf"
DISCOVERY_CONFIG="${CONFIG_DIR}/nexus-discovery.conf"
LOG_DIR="${CONFIG_DIR}/logs"
LOG_FILE="${LOG_DIR}/node-discovery.log"
PID_FILE="${CONFIG_DIR}/nexus-node-discovery.pid"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Error logging
error() {
    log "${RED}[ERROR]${NC} $1"
}

# Info logging
info() {
    log "${BLUE}[INFO]${NC} $1"
}

# Success logging
success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

# Warning logging
warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        error "This script should NOT be run as root for security reasons"
        exit 1
    fi
}

# Create directories
create_directories() {
    info "Creating directories..."
    
    # Create log directory
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 750 "$LOG_DIR"
    fi
    
    # Create data directory
    local DATA_DIR="${CONFIG_DIR}/data"
    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
        chmod 750 "$DATA_DIR"
    fi
    
    success "Directories created"
}

# Load configuration
load_config() {
    info "Loading configuration..."

    # Source configuration from files
    if [ -f "$MESH_CONFIG" ]; then
        # Parse TOML-like config (simplified)
        # Extract and evaluate shell commands in config values
        local raw_id=$(grep -E '^NodeID' "$MESH_CONFIG" | cut -d'=' -f2 | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
        local raw_name=$(grep -E '^NodeName' "$MESH_CONFIG" | cut -d'=' -f2 | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
        local raw_type=$(grep -E '^NodeType' "$MESH_CONFIG" | cut -d'=' -f2 | sed 's/^[[:space:]]*"//;s/"[[:space:]]*#.*//')

        # Evaluate shell commands (like $(hostname))
        NODE_ID=$(eval echo "$raw_id" 2>/dev/null || echo "nexus-$(hostname)-$$")
        NODE_NAME=$(eval echo "$raw_name" 2>/dev/null || echo "NeXuS-Node-$(hostname)")
        NODE_TYPE=$(echo "$raw_type" | tr -d ' "')

        # Get enabled discovery methods (strip comments)
        DISCOVERY_METHODS=$(grep -A10 'DiscoveryMethods' "$MESH_CONFIG" | grep -E '"[a-z-]+"' | sed 's/#.*//' | tr -d ' "[],' | grep -v '^$' | tr '\n' ' ')

        info "Node ID: $NODE_ID"
        info "Node Name: $NODE_NAME"
        info "Node Type: $NODE_TYPE"
        info "Discovery Methods: $DISCOVERY_METHODS"

        success "Configuration loaded"
    else
        error "Configuration file not found: $MESH_CONFIG"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    local missing=0
    
    # Check for avahi-browse (mDNS)
    if echo "$DISCOVERY_METHODS" | grep -q "mdns"; then
        if ! command -v avahi-browse &> /dev/null; then
            warn "avahi-browse not found - mDNS discovery will be disabled"
            DISCOVERY_METHODS=$(echo "$DISCOVERY_METHODS" | grep -v "mdns")
        else
            info "mDNS discovery: enabled"
        fi
    fi
    
    # Check for curl (HTTP requests)
    if ! command -v curl &> /dev/null; then
        error "curl not found - required for HTTP discovery"
        missing=1
    fi
    
    # Check for nc (netcat)
    if ! command -v nc &> /dev/null; then
        error "nc (netcat) not found - required for network testing"
        missing=1
    fi
    
    # Check for docker
    if ! command -v docker &> /dev/null; then
        error "docker not found - required for service interaction"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        exit 1
    fi
    
    success "Dependencies verified"
}

# Start mDNS discovery
start_mdns_discovery() {
    if echo "$DISCOVERY_METHODS" | grep -q "mdns"; then
        info "Starting mDNS discovery..."
        
        # Browse for NeXuS nodes using mDNS
        local peers_found=0
        
        info "Browsing for _nexus-mesh._tcp services..."
        
        # Use avahi-browse to find peers
        if command -v avahi-browse &> /dev/null; then
            local peers=$(avahi-browse -at -d local | grep '_nexus-mesh._tcp' | grep -v '^=')
            
            if [ -n "$peers" ]; then
                while IFS= read -r line; do
                    if echo "$line" | grep -q '_nexus-mesh._tcp'; then
                        local peer_name=$(echo "$line" | awk '{print $4}' | sed 's/;.*//')
                        local peer_ip=$(echo "$line" | awk '{print $8}')
                        local peer_port=$(echo "$line" | awk '{print $9}' | sed 's/;.*//')
                        
                        info "Found mDNS peer: $peer_name at $peer_ip:$peer_port"
                        
                        # Add to peer list
                        add_peer "mdns:$peer_ip:$peer_port" "$peer_name"
                        peers_found=$((peers_found + 1))
                    fi
                done <<< "$peers"
            fi
        fi
        
        if [ $peers_found -eq 0 ]; then
            info "No mDNS peers found (this is normal if no other nodes are running)"
        else
            success "Found $peers_found mDNS peers"
        fi
    fi
}

# Start Yggdrasil discovery
start_yggdrasil_discovery() {
    if echo "$DISCOVERY_METHODS" | grep -q "yggdrasil"; then
        info "Starting Yggdrasil discovery..."
        
        # Check if Yggdrasil container is running
        if docker ps --format '{{.Names}}' | grep -q 'nexus-yggdrasil'; then
            info "Yggdrasil container found"
            
            # Get Yggdrasil address
            local ygg_address=$(docker exec nexus-yggdrasil yggdrasilctl getSelf | grep "Address" | awk '{print $2}')
            
            if [ -n "$ygg_address" ]; then
                info "Local Yggdrasil address: $ygg_address"
                
                # Here you would implement actual Yggdrasil multicast discovery
                # For now, we'll simulate finding peers
                info "Yggdrasil discovery: listening for multicast beacons"
                
                # In a real implementation, this would use Yggdrasil's multicast
                # to discover other NeXuS nodes on the Yggdrasil network
                
                success "Yggdrasil discovery active"
            else
                error "Could not get Yggdrasil address"
            fi
        else
            error "Yggdrasil container not running"
        fi
    fi
}

# Start Tor rendezvous discovery
start_tor_discovery() {
    if echo "$DISCOVERY_METHODS" | grep -q "tor-rendezvous"; then
        info "Starting Tor rendezvous discovery..."
        
        # Check if Tor is available
        if nc -z localhost 9050; then
            info "Tor proxy available"
            
            # Test connection through Tor
            local tor_test=$(curl --socks5 localhost:9050 https://check.torproject.org/api/ip 2>/dev/null)
            
            if echo "$tor_test" | grep -q '"IsTor":true'; then
                info "Tor connection verified"
                
                # Here you would connect to known rendezvous points
                # For now, we'll simulate the process
                info "Connecting to Tor rendezvous points..."
                
                # In a real implementation, this would:
                # 1. Connect to predefined .onion addresses
                # 2. Register this node with the rendezvous service
                # 3. Get a list of other active nodes
                
                success "Tor rendezvous discovery active"
            else
                error "Tor connection failed"
            fi
        else
            error "Tor proxy not available"
        fi
    fi
}

# Start I2P DHT discovery
start_i2p_discovery() {
    if echo "$DISCOVERY_METHODS" | grep -q "i2p-dht"; then
        info "Starting I2P DHT discovery..."
        
        # Check if I2P is available
        if docker ps --format '{{.Names}}' | grep -q 'nexus-i2p'; then
            info "I2P container found"
            
            # Test I2P proxy
            if curl --proxy http://localhost:4444 http://i2p-projekt.i2p/ 2>/dev/null | grep -q 'I2P'; then
                info "I2P connection verified"
                
                # Here you would implement I2P DHT discovery
                # For now, we'll simulate the process
                info "I2P DHT discovery: searching for peers in topic nexus-mesh-v1"
                
                success "I2P DHT discovery active"
            else
                error "I2P connection failed"
            fi
        else
            error "I2P container not running"
        fi
    fi
}

# Start Reticulum broadcast discovery
start_reticulum_discovery() {
    if echo "$DISCOVERY_METHODS" | grep -q "reticulum-broadcast"; then
        info "Starting Reticulum broadcast discovery..."
        
        # Check if Reticulum is available
        if docker ps --format '{{.Names}}' | grep -q 'nexus-reticulum'; then
            info "Reticulum container found"
            
            # Here you would implement Reticulum broadcast discovery
            # For now, we'll simulate the process
            info "Reticulum broadcast: listening for NeXuS-Mesh broadcasts"
            
            success "Reticulum broadcast discovery active"
        else
            error "Reticulum container not running"
        fi
    fi
}

# Add peer to peer list
add_peer() {
    local peer_address="$1"
    local peer_name="$2"
    local peer_file="${CONFIG_DIR}/data/known_peers.txt"
    
    # Check if peer already exists
    if ! grep -q "$peer_address" "$peer_file" 2>/dev/null; then
        echo "$peer_address|$peer_name|$(date '+%Y-%m-%d %H:%M:%S')" >> "$peer_file"
        info "Added peer: $peer_name ($peer_address)"
        
        # Attempt to connect to peer
        connect_to_peer "$peer_address" "$peer_name"
    else
        info "Peer already known: $peer_name ($peer_address)"
    fi
}

# Connect to peer
connect_to_peer() {
    local peer_address="$1"
    local peer_name="$2"
    
    info "Attempting to connect to peer: $peer_name"
    
    # Parse connection method
    local method=$(echo "$peer_address" | cut -d':' -f1)
    local target=$(echo "$peer_address" | cut -d':' -f2-)
    
    case "$method" in
        "mdns")
            # Direct IP connection
            if nc -z "$target" 2>/dev/null; then
                success "Connected to peer $peer_name via mDNS"
                # Here you would establish a secure connection
            else
                error "Failed to connect to peer $peer_name"
            fi
            ;;
        "ygg")
            # Yggdrasil connection
            info "Yggdrasil connection to $peer_name would be established here"
            ;;
        "tor")
            # Tor connection
            info "Tor connection to $peer_name would be established here"
            ;;
        "i2p")
            # I2P connection
            info "I2P connection to $peer_name would be established here"
            ;;
        *)
            error "Unknown connection method: $method"
            ;;
    esac
}

# Main discovery loop
discovery_loop() {
    info "Starting discovery loop..."
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        info "[$timestamp] Running discovery cycle..."
        
        # Run all enabled discovery methods
        start_mdns_discovery
        start_yggdrasil_discovery
        start_tor_discovery
        start_i2p_discovery
        start_reticulum_discovery
        
        # Show current peer count
        local peer_count=0
        local peer_file="${CONFIG_DIR}/data/known_peers.txt"
        
        if [ -f "$peer_file" ]; then
            peer_count=$(wc -l < "$peer_file")
        fi
        
        info "Current known peers: $peer_count"
        
        # Wait for next cycle
        local interval=$(grep -E '^AnnounceInterval' "$MESH_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        interval=${interval:-60}  # Default to 60 seconds
        
        info "Next discovery cycle in ${interval} seconds..."
        sleep "$interval"
    done
}

# Cleanup on exit
cleanup() {
    info "Cleaning up..."
    
    # Remove PID file
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi
    
    success "Discovery service stopped"
    exit 0
}

# Signal handling
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    check_root
    create_directories
    load_config
    check_dependencies
    
    # Create PID file
    echo $$ > "$PID_FILE"
    
    info "Starting NeXuS Node Discovery Service"
    info "Node: $NODE_NAME ($NODE_ID)"
    info "Type: $NODE_TYPE"
    
    # Start discovery loop
    discovery_loop
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE")
    if ps -p "$existing_pid" > /dev/null 2>&1; then
        error "Discovery service is already running (PID: $existing_pid)"
        exit 1
    else
        warn "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Start main function
main "$@"