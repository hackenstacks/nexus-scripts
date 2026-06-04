#!/bin/bash
# NeXuS Hotspot — PirateBox-style Freedom AP
# WiFi AP + BATMAN-adv mesh + Tor proxy + captive portal + file share + QR
# One command: nexus-hotspot start [iface] [ssid] [pass]
# Sane • Simple • Secure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTAL_DIR="$SCRIPT_DIR/nexus-portal"
SHARE_DIR="$PORTAL_DIR/files"
HOSTAPD_CONF="/tmp/nexus-hostapd.conf"
DNSMASQ_CONF="/tmp/nexus-dnsmasq.conf"
DNSMASQ_PID="/tmp/nexus-dnsmasq.pid"
PORTAL_PID="/tmp/nexus-portal.pid"
HOTSPOT_STATE="/tmp/nexus-hotspot.state"

# Defaults
DEFAULT_IFACE="wlan0"
DEFAULT_SSID="NeXuS-Freedom"
DEFAULT_PASS=""    # empty = open network
AP_IP="192.168.88.1"
AP_SUBNET="192.168.88.0/24"
AP_DHCP_START="192.168.88.10"
AP_DHCP_END="192.168.88.99"
PORTAL_PORT="80"
FILE_PORT="8181"

# NeXuS stack proxy ports
TOR_SOCKS="9050"
PRIVOXY_PORT="8118"
I2P_PORT="4444"
IPFS_PORT="5001"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() {
    local level="$1" msg="$2"
    case "$level" in
        INFO)  echo -e "${GREEN}[✓]${NC} $msg" ;;
        WARN)  echo -e "${YELLOW}[!]${NC} $msg" ;;
        ERROR) echo -e "${RED}[✗]${NC} $msg" ;;
        START) echo -e "${CYAN}[➤]${NC} $msg" ;;
        STOP)  echo -e "${MAGENTA}[■]${NC} $msg" ;;
    esac
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: nexus-hotspot requires root (use: doas nexus-hotspot or sudo nexus-hotspot)${NC}"
        exit 1
    fi
}

# ── Check capabilities ────────────────────────────────────────────────────────

check_deps() {
    local missing=()
    for cmd in hostapd dnsmasq ip iptables; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "WARN" "Missing tools: ${missing[*]}"
        log "INFO" "Install: apk add hostapd dnsmasq iptables"
        return 1
    fi
    return 0
}

check_ap_capable() {
    local iface="$1"
    if command -v iw >/dev/null 2>&1; then
        if iw phy 2>/dev/null | grep -q "AP"; then
            log "INFO" "$iface: AP mode supported"
            return 0
        else
            log "WARN" "AP mode may not be supported — attempting anyway"
        fi
    fi
    return 0
}

check_batman() {
    if modprobe batman-adv 2>/dev/null; then
        log "INFO" "BATMAN-adv module loaded"
        return 0
    else
        log "WARN" "batman-adv module not available — skipping mesh"
        return 1
    fi
}

# ── Write configs ─────────────────────────────────────────────────────────────

write_hostapd_conf() {
    local iface="$1" ssid="$2" pass="$3"

    {
        echo "interface=$iface"
        echo "driver=nl80211"
        echo "ssid=$ssid"
        echo "hw_mode=g"
        echo "channel=6"
        echo "ieee80211n=1"
        echo "wmm_enabled=1"
        echo "ht_capab=[HT40+][SHORT-GI-20][DSSS_CCK-40]"
        echo "macaddr_acl=0"
        echo "ignore_broadcast_ssid=0"

        if [[ -n "$pass" ]]; then
            echo "auth_algs=1"
            echo "wpa=2"
            echo "wpa_passphrase=$pass"
            echo "wpa_key_mgmt=WPA-PSK"
            echo "rsn_pairwise=CCMP"
        else
            echo "auth_algs=1"
            # Open network
        fi
    } > "$HOSTAPD_CONF"

    log "INFO" "hostapd config written ($iface, SSID: $ssid)"
}

write_dnsmasq_conf() {
    local iface="$1"

    {
        echo "interface=$iface"
        echo "bind-interfaces"
        echo "dhcp-range=$AP_DHCP_START,$AP_DHCP_END,255.255.255.0,24h"
        echo "dhcp-option=option:router,$AP_IP"
        echo "dhcp-option=option:dns-server,$AP_IP"
        echo "no-resolv"
        # All DNS queries → return AP_IP (captive portal redirect)
        echo "address=/#/$AP_IP"
        echo "pid-file=$DNSMASQ_PID"
        echo "log-facility=/dev/null"
    } > "$DNSMASQ_CONF"

    log "INFO" "dnsmasq config written"
}

# ── Start portal web server ───────────────────────────────────────────────────

start_portal_server() {
    mkdir -p "$PORTAL_DIR" "$SHARE_DIR"

    # Create minimal index if not present
    if [[ ! -f "$PORTAL_DIR/index.html" ]]; then
        cat > "$PORTAL_DIR/index.html" << 'EOF'
<!DOCTYPE html><html><head><title>NeXuS Freedom Node</title></head>
<body style="background:#1e1e2e;color:#cdd6f4;font-family:monospace;padding:20px">
<h1>NeXuS Freedom Node</h1>
<p>Tor SOCKS5: 192.168.88.1:9050</p>
<p>Privoxy HTTP: 192.168.88.1:8118</p>
</body></html>
EOF
        log "WARN" "Minimal portal index created (full portal missing)"
    fi

    log "START" "Starting captive portal on $AP_IP:$PORTAL_PORT..."

    # Use Python's built-in HTTP server
    python3 -c "
import http.server, socketserver, os, urllib.parse, json

PORTAL_DIR = '$PORTAL_DIR'
SHARE_DIR  = '$SHARE_DIR'

class NexusHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=PORTAL_DIR, **kw)

    def do_GET(self):
        # Captive portal redirect for Apple/Android detection URLs
        captive_urls = ['/hotspot-detect.html', '/generate_204',
                        '/ncsi.txt', '/connecttest.txt', '/redirect']
        if any(self.path.startswith(u) for u in captive_urls):
            self.send_response(302)
            self.send_header('Location', 'http://$AP_IP/')
            self.end_headers()
            return
        # File listing for /files
        if self.path == '/files':
            files = []
            try:
                for f in os.listdir(SHARE_DIR):
                    fp = os.path.join(SHARE_DIR, f)
                    files.append({'name': f, 'size': os.path.getsize(fp)})
            except Exception:
                pass
            body = json.dumps({'files': files}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path == '/files/upload':
            content_type = self.headers.get('Content-Type', '')
            length = int(self.headers.get('Content-Length', 0))
            if 'multipart/form-data' in content_type and length > 0:
                boundary = content_type.split('boundary=')[1].encode()
                body = self.rfile.read(length)
                # Simple multipart parsing
                parts = body.split(b'--' + boundary)
                saved = 0
                for part in parts[1:-1]:
                    if b'filename=\"' in part:
                        fname_start = part.index(b'filename=\"') + 10
                        fname_end = part.index(b'\"', fname_start)
                        fname = part[fname_start:fname_end].decode('utf-8', errors='replace')
                        fname = os.path.basename(fname.replace('\\\\', '/'))
                        if fname:
                            data_start = part.index(b'\r\n\r\n') + 4
                            data = part[data_start:].rstrip(b'\r\n')
                            dest = os.path.join(SHARE_DIR, fname)
                            with open(dest, 'wb') as f:
                                f.write(data)
                            saved += 1
                body = json.dumps({'saved': saved}).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', len(body))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_error(400)
            return
        self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # Suppress access logs for privacy

os.makedirs(SHARE_DIR, exist_ok=True)
with socketserver.TCPServer(('$AP_IP', $PORTAL_PORT), NexusHandler) as httpd:
    httpd.serve_forever()
" &
    echo $! > "$PORTAL_PID"
    log "INFO" "Portal running on http://$AP_IP:$PORTAL_PORT (PID: $!)"
}

# ── Network setup ─────────────────────────────────────────────────────────────

setup_network() {
    local iface="$1"

    log "START" "Configuring network..."

    # Assign IP to interface
    ip addr flush dev "$iface" 2>/dev/null || true
    ip addr add "$AP_IP/24" dev "$iface"
    ip link set up dev "$iface"

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    log "INFO" "IP forwarding enabled"

    # iptables rules
    # Flush existing hotspot rules
    iptables -t nat -F 2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true

    # Masquerade outbound traffic (via Tor's TransPort if available, else direct)
    if nc -z 127.0.0.1 9040 2>/dev/null; then
        # Route TCP through Tor transparent proxy
        iptables -t nat -A PREROUTING -i "$iface" ! -d "$AP_IP" -p tcp \
            --dport 80 -j DNAT --to-destination "$AP_IP:$PORTAL_PORT"
        iptables -t nat -A PREROUTING -i "$iface" ! -d "$AP_IP" -p tcp \
            -j REDIRECT --to-port 9040
        log "INFO" "iptables: TCP → Tor TransPort 9040"
    else
        # NAT masquerade (not anonymous but functional)
        local outif; outif=$(ip route show default 2>/dev/null | awk '/default/{print $5}' | head -1)
        if [[ -n "$outif" ]]; then
            iptables -t nat -A POSTROUTING -o "$outif" -j MASQUERADE
            iptables -A FORWARD -i "$iface" -o "$outif" -j ACCEPT
            iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
            log "WARN" "Tor TransPort not available — using plain NAT (not anonymous)"
            log "WARN" "Start nexus darknet first for full anonymity: nexus-darknet start"
        else
            log "WARN" "No default route found — clients may not have internet"
        fi
    fi

    # Redirect HTTP:80 to captive portal for non-gateway destinations
    iptables -t nat -A PREROUTING -i "$iface" -p tcp --dport 80 \
        ! -d "$AP_IP" -j DNAT --to-destination "$AP_IP:$PORTAL_PORT" 2>/dev/null || true

    log "INFO" "iptables rules applied"
}

# ── BATMAN-adv mesh ───────────────────────────────────────────────────────────

setup_batman() {
    local iface="$1"

    if ! check_batman; then
        return 0
    fi

    log "START" "Setting up BATMAN-adv mesh..."

    # Add interface to BATMAN mesh
    if command -v batctl >/dev/null 2>&1; then
        batctl if add "$iface" 2>/dev/null || true
        ip link set up dev bat0 2>/dev/null || true
        ip addr add 192.168.199.1/24 dev bat0 2>/dev/null || true
        log "INFO" "BATMAN-adv mesh: bat0 (192.168.199.1/24)"
    else
        log "WARN" "batctl not found — skipping BATMAN mesh (apk add batctl)"
    fi
}

# ── Print QR code ─────────────────────────────────────────────────────────────

print_qr() {
    local url="http://$AP_IP"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   Scan QR code to open NeXuS portal                ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t UTF8 -s 1 "$url"
    else
        echo "  URL: $url"
        echo "  (Install qrencode for QR display: apk add qrencode)"
    fi
    echo ""
}

# ── Show status ───────────────────────────────────────────────────────────────

show_status() {
    local iface="${1:-$DEFAULT_IFACE}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}           NeXuS Hotspot Status                     ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # hostapd
    if pgrep -f "hostapd.*nexus" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} hostapd     RUNNING"
    else
        echo -e "  ${RED}✗${NC} hostapd     STOPPED"
    fi

    # dnsmasq
    if [[ -f "$DNSMASQ_PID" ]] && kill -0 "$(cat "$DNSMASQ_PID" 2>/dev/null)" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} dnsmasq    RUNNING (DHCP: $AP_DHCP_START-$AP_DHCP_END)"
    else
        echo -e "  ${RED}✗${NC} dnsmasq    STOPPED"
    fi

    # portal
    if [[ -f "$PORTAL_PID" ]] && kill -0 "$(cat "$PORTAL_PID" 2>/dev/null)" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} portal     RUNNING (http://$AP_IP)"
    else
        echo -e "  ${RED}✗${NC} portal     STOPPED"
    fi

    # bat0
    if ip link show bat0 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} batman-adv  RUNNING (bat0)"
    else
        echo -e "  ${YELLOW}-${NC} batman-adv  not loaded"
    fi

    echo ""
    echo "  AP IP:  $AP_IP"
    echo "  Portal: http://$AP_IP"
    echo "  Proxy:  $AP_IP:$TOR_SOCKS (Tor) / $AP_IP:$PRIVOXY_PORT (HTTP)"
    echo ""

    # Connected clients
    if command -v arp >/dev/null 2>&1; then
        local clients; clients=$(arp -n 2>/dev/null | grep "$iface" | awk '{print $1}' | wc -l || echo "?")
        echo "  Connected clients: $clients"
    fi
    echo ""
}

# ── Start ─────────────────────────────────────────────────────────────────────

start_hotspot() {
    local iface="${1:-$DEFAULT_IFACE}"
    local ssid="${2:-$DEFAULT_SSID}"
    local pass="${3:-$DEFAULT_PASS}"

    require_root

    echo ""
    echo -e "${RED}    ╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}    ║  🔥 NeXuS Freedom Hotspot 🔥         ║${NC}"
    echo -e "${RED}    ║  Sane • Simple • Secure               ║${NC}"
    echo -e "${RED}    ╚══════════════════════════════════════╝${NC}"
    echo ""

    # Checks
    check_deps || { log "WARN" "Some dependencies missing — partial functionality"; }
    check_ap_capable "$iface"

    # Check interface exists
    if ! ip link show "$iface" >/dev/null 2>&1; then
        log "ERROR" "Interface $iface not found"
        log "INFO" "Available interfaces: $(ip link | grep '^[0-9]' | awk -F': ' '{print $2}' | tr '\n' ' ')"
        exit 1
    fi

    # Save state for cleanup
    echo "iface=$iface" > "$HOTSPOT_STATE"

    # Configure AP
    write_hostapd_conf "$iface" "$ssid" "$pass"
    write_dnsmasq_conf "$iface"

    # Start hostapd
    log "START" "Starting hostapd (SSID: $ssid)..."
    hostapd -B "$HOSTAPD_CONF" 2>/dev/null || {
        log "WARN" "hostapd failed — interface may need to be in managed mode first"
        ip link set down dev "$iface" 2>/dev/null || true
        sleep 1
        ip link set up dev "$iface" 2>/dev/null || true
        hostapd -B "$HOSTAPD_CONF" || { log "ERROR" "hostapd failed"; exit 1; }
    }
    log "INFO" "hostapd started (SSID: $ssid)"

    # Setup network interface
    setup_network "$iface"

    # Start dnsmasq
    log "START" "Starting dnsmasq DHCP..."
    dnsmasq -C "$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID"
    log "INFO" "dnsmasq started (DHCP: $AP_DHCP_START-$AP_DHCP_END)"

    # BATMAN mesh (optional)
    setup_batman "$iface"

    # Start portal
    start_portal_server

    # Print summary
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}       NeXuS Freedom Hotspot is UP! 🔥              ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  SSID:    $ssid$([ -z "$pass" ] && echo ' (open)' || echo ' (WPA2)')"
    echo "  Portal:  http://$AP_IP"
    echo "  Proxy:   $AP_IP:$TOR_SOCKS (Tor SOCKS5)"
    echo "  Proxy:   $AP_IP:$PRIVOXY_PORT (HTTP — auto .onion/.i2p)"
    echo ""

    print_qr

    echo -e "${CYAN}  Stop with: nexus-hotspot stop${NC}"
    echo ""
}

# ── Stop ──────────────────────────────────────────────────────────────────────

stop_hotspot() {
    require_root

    log "STOP" "Stopping NeXuS Hotspot..."

    # Load saved iface
    local iface="$DEFAULT_IFACE"
    if [[ -f "$HOTSPOT_STATE" ]]; then
        source "$HOTSPOT_STATE"
    fi

    # Stop portal
    if [[ -f "$PORTAL_PID" ]]; then
        kill "$(cat "$PORTAL_PID")" 2>/dev/null || true
        rm -f "$PORTAL_PID"
        log "INFO" "Portal stopped"
    fi

    # Stop dnsmasq
    if [[ -f "$DNSMASQ_PID" ]]; then
        kill "$(cat "$DNSMASQ_PID")" 2>/dev/null || true
        rm -f "$DNSMASQ_PID"
        log "INFO" "dnsmasq stopped"
    fi

    # Stop hostapd
    pkill -f "hostapd.*nexus" 2>/dev/null || true
    log "INFO" "hostapd stopped"

    # Tear down BATMAN
    if ip link show bat0 >/dev/null 2>&1; then
        ip link set down dev bat0 2>/dev/null || true
        rmmod batman_adv 2>/dev/null || true
        log "INFO" "BATMAN-adv removed"
    fi

    # Restore networking
    iptables -t nat -F 2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true
    echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

    # Reset interface
    ip addr flush dev "$iface" 2>/dev/null || true
    log "INFO" "Interface $iface reset"

    rm -f "$HOSTAPD_CONF" "$DNSMASQ_CONF" "$HOTSPOT_STATE"
    log "INFO" "NeXuS Hotspot stopped"
}

# ── Share file ────────────────────────────────────────────────────────────────

share_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log "ERROR" "File not found: $file"
        exit 1
    fi

    mkdir -p "$SHARE_DIR"
    local basename; basename=$(basename "$file")
    cp "$file" "$SHARE_DIR/$basename"
    log "INFO" "File shared: $basename → http://$AP_IP/files/$basename"

    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        qrencode -t UTF8 -s 1 "http://$AP_IP/files/$basename"
        echo ""
    fi
}

# ── Help ──────────────────────────────────────────────────────────────────────

show_help() {
    echo ""
    echo "Usage: nexus-hotspot {start|stop|status|share|qr|help} [args]"
    echo ""
    echo "Commands:"
    echo "  start [iface] [ssid] [pass]   Start hotspot (defaults: wlan0, NeXuS-Freedom, open)"
    echo "  stop                           Teardown + restore networking"
    echo "  status                         Show connected clients + service status"
    echo "  share <file>                   Add file to portal's share dir"
    echo "  qr                             Reprint QR code for portal URL"
    echo "  help                           Show this help"
    echo ""
    echo "Examples:"
    echo "  doas nexus-hotspot start                          # open network"
    echo "  doas nexus-hotspot start wlan0 MyNet password123 # WPA2"
    echo "  nexus-hotspot share ~/myfile.pdf                  # share file"
    echo ""
    echo "Requirements:"
    echo "  hostapd dnsmasq iptables ip python3"
    echo "  Optional: batctl qrencode"
    echo ""
    echo "Privacy:"
    echo "  TCP traffic routed through Tor (if nexus-darknet is running)"
    echo "  DNS queries answered locally (no DNS leak)"
    echo "  Portal served locally (no remote deps)"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    case "${1:-help}" in
        start)
            shift
            start_hotspot "${1:-}" "${2:-}" "${3:-}"
            ;;
        stop)
            stop_hotspot
            ;;
        status)
            show_status "${2:-}"
            ;;
        share)
            shift
            share_file "${1:-}"
            ;;
        qr)
            print_qr
            ;;
        help|*)
            show_help
            ;;
    esac
}

main "$@"
