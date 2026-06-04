#!/bin/bash
# 📦 NeXuS Container Security Stack
# Rootless security containers for OpenSnitch, Privoxy, and more
# P1.2.1 Container Health Monitoring System Enhanced

set -e

# 🎨 NeXuS Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📦 Container symbols  
CONTAINER_SYMBOL="📦"
SHIELD_SYMBOL="🛡️"
NETWORK_SYMBOL="🌐"
SUCCESS_SYMBOL="✅"
ROCKET_SYMBOL="🚀"
HEALTH_SYMBOL="🩺"
DAEMON_SYMBOL="👻"
METRICS_SYMBOL="📊"
WARNING_SYMBOL="⚠️"
FIRE_SYMBOL="🔥"

# 📁 Directories
CONTAINER_CONFIG_DIR="/home/user/.nexus-security/containers"
CONTAINER_DATA_DIR="/home/user/.local/share/containers/nexus-security"
HEALTH_LOG_DIR="/home/user/.nexus-backups"
HEALTH_LOG_FILE="$HEALTH_LOG_DIR/container-health.log"
DAEMON_PID_FILE="/tmp/nexus-container-health-daemon.pid"
DAEMON_LOG_FILE="$HEALTH_LOG_DIR/daemon.log"

# 📦 Container Names
CONTAINERS=("nexus-opensnitch" "nexus-privoxy" "nexus-tor")

# 🏗️ Initialize Container Infrastructure
init_container_infrastructure() {
    echo -e "${BLUE}${CONTAINER_SYMBOL} Initializing NeXuS Container Security...${NC}"
    
    mkdir -p "$CONTAINER_CONFIG_DIR"/{opensnitch,privoxy,tor}
    mkdir -p "$CONTAINER_DATA_DIR"/{opensnitch,privoxy,tor}
    
    # Initialize health monitoring
    mkdir -p "$HEALTH_LOG_DIR"
    if [ ! -f "$HEALTH_LOG_FILE" ]; then
        echo "# NeXuS Container Health Monitoring Log" > "$HEALTH_LOG_FILE"
        echo "# Format: [TIMESTAMP] [LEVEL] [CONTAINER] MESSAGE" >> "$HEALTH_LOG_FILE"
        log_health_event "INFO" "SYSTEM" "Health monitoring system initialized"
    fi
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Container directories created${NC}"
    echo -e "${GREEN}${HEALTH_SYMBOL} Health monitoring system ready${NC}"
}

# 🔍 OpenSnitch Application Firewall Container
setup_opensnitch_container() {
    echo -e "${BLUE}${SHIELD_SYMBOL} Setting up OpenSnitch Application Firewall...${NC}"
    
    # OpenSnitch configuration
    cat > "$CONTAINER_CONFIG_DIR/opensnitch/daemon.conf" << 'EOF'
{
    "Server": {
        "Address": "unix:///tmp/osui.sock",
        "LogFile": "/var/log/opensnitchd.log",
        "LogLevel": "info"
    },
    "DefaultAction": "allow",
    "InterceptUnknown": true,
    "ProcMonitorMethod": "audit",
    "LogUTC": false,
    "Stats": {
        "MaxEvents": 150,
        "MaxStats": 25
    }
}
EOF

    # OpenSnitch Podman container
    cat > "$CONTAINER_CONFIG_DIR/opensnitch-run.sh" << 'EOF'
#!/bin/bash
# Run OpenSnitch in rootless container
podman run -d \
    --name nexus-opensnitch \
    --network host \
    --privileged \
    --user $(id -u):$(id -g) \
    -v ~/.nexus-security/containers/opensnitch:/etc/opensnitchd:Z \
    -v ~/.local/share/containers/nexus-security/opensnitch:/var/log:Z \
    --restart unless-stopped \
    gustavo-iniguez-goya/opensnitch
EOF
    chmod +x "$CONTAINER_CONFIG_DIR/opensnitch-run.sh"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} OpenSnitch container configured${NC}"
}

# 🌐 Privoxy + uBlock Origin Container
setup_privoxy_container() {
    echo -e "${BLUE}${NETWORK_SYMBOL} Setting up Privoxy + uBlock Origin...${NC}"
    
    # Privoxy config with uBlock Origin rules
    cat > "$CONTAINER_CONFIG_DIR/privoxy/config" << 'EOF'
# NeXuS Privoxy Configuration with uBlock Origin Integration
listen-address 0.0.0.0:8118
toggle 1
enable-remote-toggle 0
enable-edit-actions 0

# Logging
logfile /var/log/privoxy/logfile
debug 1

# Filtering
filterfile default.filter
actionsfile match-all.action
actionsfile default.action
actionsfile user.action

# uBlock Origin-style blocking
+block{Blocked by NeXuS uBlock Integration}
+filter{privacy}
+filter{crude-parental}

# Headers for privacy
+hide-user-agent{Mozilla/5.0 (X11; Linux x86_64; NeXuS Security)}
+hide-referrer{conditional-block}
+session-cookies-only
+crunch-if-none-match
+crunch-etag-header
+force-text-mode
EOF

    # Privoxy actions for uBlock Origin rules
    cat > "$CONTAINER_CONFIG_DIR/privoxy/user.action" << 'EOF'
# NeXuS uBlock Origin Rules Integration
{+block{Tracking blocked}}
.googleadservices.com
.googlesyndication.com
.doubleclick.net
.facebook.com/tr/
.analytics.google.com

{+block{Social media tracking}}
.facebook.net
.twitter.com/i/
.linkedin.com/li/

{+filter{privacy}}
*

{+session-cookies-only}
*
EOF

    # Privoxy container run script
    cat > "$CONTAINER_CONFIG_DIR/privoxy-run.sh" << 'EOF'
#!/bin/bash
# Run Privoxy with uBlock Origin rules
podman run -d \
    --name nexus-privoxy \
    -p 8118:8118 \
    --user $(id -u):$(id -g) \
    -v ~/.nexus-security/containers/privoxy:/etc/privoxy:Z \
    -v ~/.local/share/containers/nexus-security/privoxy:/var/log/privoxy:Z \
    --restart unless-stopped \
    privoxy/privoxy
EOF
    chmod +x "$CONTAINER_CONFIG_DIR/privoxy-run.sh"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Privoxy + uBlock container configured${NC}"
}

# 🌐 Tor Container for Stealth Mode
setup_tor_container() {
    echo -e "${BLUE}👻 Setting up Tor for Stealth Mode...${NC}"
    
    # Tor configuration
    cat > "$CONTAINER_CONFIG_DIR/tor/torrc" << 'EOF'
# NeXuS Tor Configuration for Stealth Mode
User tor
DataDirectory /var/lib/tor

# SOCKS proxy
SocksPort 0.0.0.0:9050 IsolateDestAddr IsolateDestPort
SocksPolicy accept 127.0.0.1/8
SocksPolicy reject *

# Control port for monitoring
ControlPort 9051
CookieAuthentication 1

# Performance and security
MaxCircuitDirtiness 300
NewCircuitPeriod 60
CircuitBuildTimeout 60
KeepalivePeriod 60

# Exit node selection
ExitNodes {us},{ca},{gb},{de}
StrictNodes 1

# Security settings
AvoidDiskWrites 1
DisableAllSwap 1
HardwareAccel 1

Log notice file /var/log/tor/notices.log
EOF

    # Tor container run script
    cat > "$CONTAINER_CONFIG_DIR/tor-run.sh" << 'EOF'
#!/bin/bash
# Run Tor in rootless container
podman run -d \
    --name nexus-tor \
    -p 9050:9050 \
    -p 9051:9051 \
    --user $(id -u):$(id -g) \
    -v ~/.nexus-security/containers/tor:/etc/tor:Z \
    -v ~/.local/share/containers/nexus-security/tor:/var/log/tor:Z \
    --restart unless-stopped \
    alpine/tor:latest
EOF
    chmod +x "$CONTAINER_CONFIG_DIR/tor-run.sh"
    
    echo -e "${GREEN}${SUCCESS_SYMBOL} Tor stealth container configured${NC}"
}

# 🚀 Master Container Management
manage_containers() {
    local action="$1"
    
    case "$action" in
        "start")
            echo -e "${ROCKET_SYMBOL} Starting NeXuS Security Container Stack..."
            "$CONTAINER_CONFIG_DIR/tor-run.sh"
            sleep 5
            "$CONTAINER_CONFIG_DIR/privoxy-run.sh"
            sleep 3
            "$CONTAINER_CONFIG_DIR/opensnitch-run.sh"
            echo -e "${GREEN}${SUCCESS_SYMBOL} All security containers started${NC}"
            ;;
        "stop")
            echo -e "${YELLOW}Stopping security containers...${NC}"
            podman stop nexus-opensnitch nexus-privoxy nexus-tor 2>/dev/null || true
            echo -e "${GREEN}${SUCCESS_SYMBOL} Containers stopped${NC}"
            ;;
        "status")
            echo -e "${CYAN}NeXuS Security Container Status:${NC}"
            podman ps --filter name=nexus-
            ;;
        "logs")
            echo -e "${CYAN}Recent container logs:${NC}"
            podman logs --tail 10 nexus-privoxy 2>/dev/null || echo "Privoxy not running"
            echo "---"
            podman logs --tail 10 nexus-tor 2>/dev/null || echo "Tor not running"
            ;;
    esac
}

# 🩺 Health Monitoring Functions
log_health_event() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level="$1"
    local container="$2"
    local message="$3"
    
    echo "[$timestamp] [$level] [$container] $message" >> "$HEALTH_LOG_FILE"
}

# 📊 Container Health Check
check_container_health() {
    local container="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if container exists and is running
    if ! podman ps --filter name="$container" --filter status=running --format "{{.Names}}" | grep -q "^$container$"; then
        log_health_event "ERROR" "$container" "Container not running or not found"
        return 1
    fi
    
    # Get container stats
    local stats=$(podman stats --no-stream --format "json" "$container" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_health_event "ERROR" "$container" "Failed to get container stats"
        return 1
    fi
    
    # Parse CPU and Memory usage
    local cpu_percent=$(echo "$stats" | jq -r '.CPU' | sed 's/%//' 2>/dev/null || echo "0")
    local mem_usage=$(echo "$stats" | jq -r '.MemUsage' 2>/dev/null || echo "0B / 0B")
    local mem_percent=$(echo "$stats" | jq -r '.MemPerc' | sed 's/%//' 2>/dev/null || echo "0")
    
    # Container-specific health checks
    case "$container" in
        "nexus-opensnitch")
            # Check if OpenSnitch socket is accessible
            if podman exec "$container" test -S /tmp/osui.sock 2>/dev/null; then
                log_health_event "INFO" "$container" "Socket accessible, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            else
                log_health_event "WARNING" "$container" "Socket not accessible, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            fi
            ;;
        "nexus-privoxy")
            # Check if Privoxy is responding on port 8118
            if podman exec "$container" netstat -ln 2>/dev/null | grep -q :8118; then
                log_health_event "INFO" "$container" "Port 8118 listening, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            else
                log_health_event "WARNING" "$container" "Port 8118 not listening, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            fi
            ;;
        "nexus-tor")
            # Check if Tor is responding on SOCKS port 9050
            if podman exec "$container" netstat -ln 2>/dev/null | grep -q :9050; then
                log_health_event "INFO" "$container" "SOCKS port 9050 listening, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            else
                log_health_event "WARNING" "$container" "SOCKS port 9050 not listening, CPU: ${cpu_percent}%, Memory: ${mem_usage}"
            fi
            ;;
    esac
    
    # Check for high resource usage
    if (( $(echo "$cpu_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
        log_health_event "WARNING" "$container" "High CPU usage: ${cpu_percent}%"
    fi
    
    if (( $(echo "$mem_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
        log_health_event "WARNING" "$container" "High memory usage: ${mem_percent}%"
    fi
    
    return 0
}

# 📊 Comprehensive Health Check
run_health_check() {
    echo -e "${BLUE}${HEALTH_SYMBOL} Running NeXuS Container Health Check...${NC}"
    log_health_event "INFO" "SYSTEM" "Health check initiated"
    
    local healthy_count=0
    local total_count=${#CONTAINERS[@]}
    
    for container in "${CONTAINERS[@]}"; do
        echo -e "${CYAN}Checking $container...${NC}"
        if check_container_health "$container"; then
            echo -e "${GREEN}${SUCCESS_SYMBOL} $container: Healthy${NC}"
            ((healthy_count++))
        else
            echo -e "${RED}${WARNING_SYMBOL} $container: Unhealthy${NC}"
        fi
    done
    
    echo -e "${WHITE}Health Status: $healthy_count/$total_count containers healthy${NC}"
    log_health_event "INFO" "SYSTEM" "Health check completed: $healthy_count/$total_count healthy"
    
    if [ "$healthy_count" -eq "$total_count" ]; then
        echo -e "${GREEN}${FIRE_SYMBOL} All containers are running optimally!${NC}"
        return 0
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} Some containers need attention${NC}"
        return 1
    fi
}

# 👻 Daemon Mode Functions
start_daemon() {
    if [ -f "$DAEMON_PID_FILE" ] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}${DAEMON_SYMBOL} Health monitoring daemon already running (PID: $(cat "$DAEMON_PID_FILE"))${NC}"
        return 1
    fi
    
    echo -e "${BLUE}${DAEMON_SYMBOL} Starting NeXuS Container Health Monitoring Daemon...${NC}"
    
    # Start daemon in background
    nohup bash -c '
        trap "rm -f $DAEMON_PID_FILE; exit" INT TERM
        echo $$ > "$DAEMON_PID_FILE"
        
        log_health_event "INFO" "DAEMON" "Health monitoring daemon started (PID: $$)"
        
        while true; do
            for container in "${CONTAINERS[@]}"; do
                check_container_health "$container" >/dev/null 2>&1
            done
            sleep 60  # Check every minute
        done
    ' >> "$DAEMON_LOG_FILE" 2>&1 &
    
    # Wait a moment to ensure daemon started
    sleep 2
    
    if [ -f "$DAEMON_PID_FILE" ] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}${SUCCESS_SYMBOL} Health monitoring daemon started (PID: $(cat "$DAEMON_PID_FILE"))${NC}"
        log_health_event "INFO" "DAEMON" "Daemon successfully started"
        return 0
    else
        echo -e "${RED}${WARNING_SYMBOL} Failed to start health monitoring daemon${NC}"
        return 1
    fi
}

stop_daemon() {
    if [ ! -f "$DAEMON_PID_FILE" ]; then
        echo -e "${YELLOW}${DAEMON_SYMBOL} Health monitoring daemon not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$DAEMON_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${BLUE}${DAEMON_SYMBOL} Stopping health monitoring daemon (PID: $pid)...${NC}"
        kill "$pid"
        rm -f "$DAEMON_PID_FILE"
        log_health_event "INFO" "DAEMON" "Health monitoring daemon stopped"
        echo -e "${GREEN}${SUCCESS_SYMBOL} Daemon stopped${NC}"
        return 0
    else
        echo -e "${YELLOW}${WARNING_SYMBOL} Daemon PID file exists but process not found${NC}"
        rm -f "$DAEMON_PID_FILE"
        return 1
    fi
}

daemon_status() {
    if [ -f "$DAEMON_PID_FILE" ] && kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        local pid=$(cat "$DAEMON_PID_FILE")
        echo -e "${GREEN}${SUCCESS_SYMBOL} Health monitoring daemon running (PID: $pid)${NC}"
        
        # Show recent health events
        if [ -f "$HEALTH_LOG_FILE" ]; then
            echo -e "${CYAN}Recent health events:${NC}"
            tail -5 "$HEALTH_LOG_FILE" | while read line; do
                echo -e "  ${WHITE}$line${NC}"
            done
        fi
        return 0
    else
        echo -e "${RED}${WARNING_SYMBOL} Health monitoring daemon not running${NC}"
        return 1
    fi
}

# 📊 Health Metrics Display
show_health_metrics() {
    echo -e "${CYAN}${METRICS_SYMBOL} NeXuS Container Health Metrics${NC}"
    echo -e "${WHITE}=$(printf '%.0s=' {1..50})${NC}"
    
    if [ ! -f "$HEALTH_LOG_FILE" ]; then
        echo -e "${YELLOW}No health metrics available yet${NC}"
        return 1
    fi
    
    # Summary statistics
    local total_events=$(wc -l < "$HEALTH_LOG_FILE")
    local error_events=$(grep -c "ERROR" "$HEALTH_LOG_FILE" || echo 0)
    local warning_events=$(grep -c "WARNING" "$HEALTH_LOG_FILE" || echo 0)
    local info_events=$(grep -c "INFO" "$HEALTH_LOG_FILE" || echo 0)
    
    echo -e "${WHITE}Total Events: ${CYAN}$total_events${NC}"
    echo -e "${RED}Errors: $error_events${NC} | ${YELLOW}Warnings: $warning_events${NC} | ${GREEN}Info: $info_events${NC}"
    echo
    
    # Recent events by container
    for container in "${CONTAINERS[@]}"; do
        echo -e "${BLUE}$container Recent Status:${NC}"
        grep "\[$container\]" "$HEALTH_LOG_FILE" | tail -3 | while read line; do
            if echo "$line" | grep -q "ERROR"; then
                echo -e "  ${RED}$line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${GREEN}$line${NC}"
            fi
        done
        echo
    done
}

# 📋 Main execution
main() {
    case "${1:-menu}" in
        "init")
            init_container_infrastructure
            setup_opensnitch_container
            setup_privoxy_container  
            setup_tor_container
            echo -e "${GREEN}${ROCKET_SYMBOL} NeXuS Container Security Stack ready!${NC}"
            ;;
        "start")
            manage_containers "start"
            ;;
        "stop")
            manage_containers "stop"
            ;;
        "status")
            manage_containers "status"
            ;;
        "logs")
            manage_containers "logs"
            ;;
        "health")
            run_health_check
            ;;
        "metrics")
            show_health_metrics
            ;;
        "daemon")
            case "${2:-status}" in
                "start")
                    start_daemon
                    ;;
                "stop")
                    stop_daemon
                    ;;
                "status")
                    daemon_status
                    ;;
                "restart")
                    stop_daemon
                    sleep 2
                    start_daemon
                    ;;
                *)
                    echo -e "${CYAN}NeXuS Health Daemon Management${NC}"
                    echo -e "${WHITE}Usage: $0 daemon {start|stop|status|restart}${NC}"
                    ;;
            esac
            ;;
        "--daemon")
            start_daemon
            ;;
        *)
            echo -e "${CYAN}${FIRE_SYMBOL} NeXuS Container Security Management ${FIRE_SYMBOL}${NC}"
            echo -e "${WHITE}Usage: $0 {init|start|stop|status|logs|health|metrics|daemon}${NC}"
            echo
            echo -e "${YELLOW}${CONTAINER_SYMBOL} Container Management:${NC}"
            echo -e "  ${CYAN}init${NC}     - Initialize container infrastructure"
            echo -e "  ${CYAN}start${NC}    - Start all security containers"
            echo -e "  ${CYAN}stop${NC}     - Stop all security containers"  
            echo -e "  ${CYAN}status${NC}   - Show container status"
            echo -e "  ${CYAN}logs${NC}     - Show recent container logs"
            echo
            echo -e "${YELLOW}${HEALTH_SYMBOL} Health Monitoring (P1.2.1):${NC}"
            echo -e "  ${CYAN}health${NC}   - Run comprehensive health check"
            echo -e "  ${CYAN}metrics${NC}  - Show health metrics and statistics"
            echo -e "  ${CYAN}daemon${NC}   - Daemon management {start|stop|status|restart}"
            echo -e "  ${CYAN}--daemon${NC} - Start health monitoring daemon"
            echo
            echo -e "${GREEN}${FIRE_SYMBOL} Enhanced with P1.2.1 Container Health Monitoring System${NC}"
            ;;
    esac
}

main "$@"