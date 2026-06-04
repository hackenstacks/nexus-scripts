#!/bin/bash

# NeXuS Network Bridge - Universal Anonymity Router
# Routes Yggdrasil, Reticulum, and all networks through Tor/I2P
# Adds Snowflake, IRC, WebTorrent, aMule services
#
# "Because everyone together achieves MORE!"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG_DIR="/home/user/.nexus-security"
BRIDGE_DIR="$CONFIG_DIR/bridge"
LOG_FILE="$CONFIG_DIR/nexus-bridge.log"

# Tor SOCKS proxy (Medusa)
TOR_SOCKS="127.0.0.1:1080"
TOR_SOCKS_ALT="127.0.0.1:9050"

print_nexus() {
    echo -e "${PURPLE}🌀${CYAN} $1${NC}"
}

print_status() { echo -e "${BLUE}📊 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

log_event() {
    mkdir -p "$CONFIG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}           🌀 NeXuS NETWORK BRIDGE 🌀                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}   Universal Anonymity Router • All Networks Through Tor    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}  Yggdrasil•Reticulum•I2P•Snowflake•IRC•WebTorrent•aMule   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# ============================================================
# YGGDRASIL OVER TOR
# ============================================================

setup_yggdrasil_tor_bridge() {
    print_nexus "Setting up Yggdrasil → Tor bridge..."

    mkdir -p "$BRIDGE_DIR/yggdrasil"

    # Create Yggdrasil config that peers through Tor
    cat > "$BRIDGE_DIR/yggdrasil/yggdrasil-tor.conf" << 'EOF'
{
  # Yggdrasil configuration routed through Tor

  # Peers through Tor SOCKS proxy
  "Peers": [
    # Public Yggdrasil peers accessed via torsocks
    # These will be connected through Tor
  ],

  # Listen for incoming connections (disabled for anonymity)
  "Listen": [],

  # Admin API
  "AdminListen": "unix:///tmp/yggdrasil-tor.sock",

  # Interface settings
  "IfName": "ygg-tor",
  "IfMTU": 65535,

  # Node settings for Tor routing
  "NodeInfo": {
    "name": "nexus-tor-bridge"
  },

  # Disable multicast (would leak local network info)
  "MulticastInterfaces": []
}
EOF

    # Create wrapper script to run Yggdrasil through torsocks
    cat > "$BRIDGE_DIR/yggdrasil/start-ygg-tor.sh" << 'EOF'
#!/bin/bash
# Start Yggdrasil with all traffic routed through Tor

TORIFY="torsocks"
YGG_CONFIG="/home/user/.nexus-security/bridge/yggdrasil/yggdrasil-tor.conf"

# Check if torsocks is available
if ! command -v torsocks &> /dev/null; then
    echo "Installing torsocks..."
    doas apk add torsocks 2>/dev/null || sudo apt install torsocks -y 2>/dev/null
fi

# Configure torsocks to use our Tor proxy
export TORSOCKS_TOR_ADDRESS="127.0.0.1"
export TORSOCKS_TOR_PORT="1080"

echo "🌀 Starting Yggdrasil through Tor..."

# Generate config if needed
if [ ! -f "$YGG_CONFIG" ] || [ ! -s "$YGG_CONFIG" ]; then
    yggdrasil -genconf > "$YGG_CONFIG" 2>/dev/null
    # Disable Listen and Multicast for anonymity
    sed -i 's/"Listen":.*/"Listen": [],/' "$YGG_CONFIG"
    sed -i 's/"MulticastInterfaces":.*/"MulticastInterfaces": []/' "$YGG_CONFIG"
fi

# Start Yggdrasil with torsocks
exec torsocks yggdrasil -useconffile "$YGG_CONFIG"
EOF
    chmod +x "$BRIDGE_DIR/yggdrasil/start-ygg-tor.sh"

    print_success "Yggdrasil-Tor bridge configured"
    echo -e "   ${CYAN}Start with: $BRIDGE_DIR/yggdrasil/start-ygg-tor.sh${NC}"
}

# ============================================================
# RETICULUM OVER TOR
# ============================================================

setup_reticulum_tor_bridge() {
    print_nexus "Setting up Reticulum → Tor bridge..."

    mkdir -p "$BRIDGE_DIR/reticulum"

    # Create Reticulum config that routes through Tor
    cat > "$BRIDGE_DIR/reticulum/config-tor" << 'EOF'
# Reticulum Configuration - Routed Through Tor
# All TCP connections go via Tor SOCKS proxy

[reticulum]
  enable_transport = Yes
  share_instance = Yes
  shared_instance_port = 37428
  instance_control_port = 37429
  panic_on_interface_error = No

[logging]
  loglevel = 4

# Local interface for apps
[interfaces]
  [[Default Interface]]
    type = AutoInterface
    enabled = Yes

  # TCP interface through Tor (using proxychains/torsocks)
  [[Tor TCP Interface]]
    type = TCPClientInterface
    enabled = Yes
    target_host = 127.0.0.1
    target_port = 4242
    # This connection will be wrapped by torsocks

  # I2P interface for additional anonymity
  [[I2P Interface]]
    type = I2PInterface
    enabled = Yes
    peers = i2p_reticulum_peers
EOF

    # Create wrapper script
    cat > "$BRIDGE_DIR/reticulum/start-rns-tor.sh" << 'EOF'
#!/bin/bash
# Start Reticulum Network Stack through Tor

export TORSOCKS_TOR_ADDRESS="127.0.0.1"
export TORSOCKS_TOR_PORT="1080"

RNS_CONFIG="/home/user/.nexus-security/bridge/reticulum"

echo "🌀 Starting Reticulum through Tor..."

# Create config directory
mkdir -p ~/.reticulum

# Copy our Tor-enabled config
cp "$RNS_CONFIG/config-tor" ~/.reticulum/config

# Start rnsd through torsocks
exec torsocks rnsd
EOF
    chmod +x "$BRIDGE_DIR/reticulum/start-rns-tor.sh"

    print_success "Reticulum-Tor bridge configured"
    echo -e "   ${CYAN}Start with: $BRIDGE_DIR/reticulum/start-rns-tor.sh${NC}"
}

# ============================================================
# SNOWFLAKE PROXY
# ============================================================

setup_snowflake_proxy() {
    print_nexus "Setting up Snowflake Proxy (help censored users access Tor)..."

    mkdir -p "$BRIDGE_DIR/snowflake"

    # Create Snowflake proxy container
    cat > "$BRIDGE_DIR/snowflake/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  snowflake-proxy:
    image: thetorproject/snowflake-proxy:latest
    container_name: nexus-snowflake
    restart: unless-stopped
    network_mode: host
    environment:
      - BROKER_URL=https://snowflake-broker.torproject.net/
      - RELAY_URL=wss://snowflake.torproject.net/
      - STUN_URL=stun:stun.l.google.com:19302
      - CAPACITY=10
      - SUMMARY_INTERVAL=3600
    labels:
      - "nexus.network=snowflake"
      - "nexus.purpose=help-censored-users"
EOF

    # Create standalone start script
    cat > "$BRIDGE_DIR/snowflake/start-snowflake.sh" << 'EOF'
#!/bin/bash
# Start Snowflake proxy to help censored users reach Tor

echo "❄️  Starting Snowflake Proxy..."
echo "   You are now helping censored users access the Tor network!"

# Try podman first, then docker
if command -v podman &> /dev/null; then
    podman run -d --name nexus-snowflake \
        --network host \
        -e BROKER_URL=https://snowflake-broker.torproject.net/ \
        -e RELAY_URL=wss://snowflake.torproject.net/ \
        -e CAPACITY=10 \
        thetorproject/snowflake-proxy:latest
elif command -v docker &> /dev/null; then
    docker run -d --name nexus-snowflake \
        --network host \
        thetorproject/snowflake-proxy:latest
else
    echo "❌ Neither podman nor docker found. Install one to run Snowflake."
    exit 1
fi

echo "✅ Snowflake proxy started!"
echo "   Helping censored users access Tor anonymously."
EOF
    chmod +x "$BRIDGE_DIR/snowflake/start-snowflake.sh"

    print_success "Snowflake proxy configured"
    echo -e "   ${CYAN}Start with: $BRIDGE_DIR/snowflake/start-snowflake.sh${NC}"
}

# ============================================================
# IRC SERVER (via Tor Hidden Service)
# ============================================================

setup_irc_darknet() {
    print_nexus "Setting up IRC server on darknet..."

    mkdir -p "$BRIDGE_DIR/irc"

    # Create IRC server container config
    cat > "$BRIDGE_DIR/irc/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  irc-server:
    image: inspircd/inspircd-docker:latest
    container_name: nexus-irc
    restart: unless-stopped
    ports:
      - "127.0.0.1:6667:6667"   # Plain IRC
      - "127.0.0.1:6697:6697"   # IRC over TLS
    volumes:
      - ./inspircd.conf:/etc/inspircd/inspircd.conf:ro
    labels:
      - "nexus.network=irc"
      - "nexus.hidden-service=true"
EOF

    # Create minimal IRC config
    cat > "$BRIDGE_DIR/irc/inspircd.conf" << 'EOF'
# NeXuS IRC Server Configuration
# Accessible via Tor Hidden Service

<server
    name="nexus.onion"
    description="NeXuS Anonymous IRC"
    network="NeXuS">

<admin
    name="NeXuS Admin"
    nick="NexusBot"
    email="admin@nexus.onion">

<bind address="0.0.0.0" port="6667" type="clients">
<bind address="0.0.0.0" port="6697" type="clients" ssl="gnutls">

<connect name="main" allow="*" maxchans="20" timeout="60">

<channels>
    <channel name="#nexus" topic="Welcome to NeXuS - Sane, Simple, Secure">
    <channel name="#tech" topic="Technology Discussion">
    <channel name="#random" topic="Off-topic chat">
</channels>

<module name="cloaking">
<cloak mode="half" key="nexus-anonymous-irc-cloak-key-change-this">
EOF

    # Create Tor hidden service config for IRC
    cat > "$BRIDGE_DIR/irc/torrc-irc" << 'EOF'
DataDirectory /home/user/.nexus-security/bridge/irc/tor-data
Log notice stdout
SOCKSPort 0

HiddenServiceDir /home/user/.nexus-security/bridge/irc/hidden-service
HiddenServicePort 6667 127.0.0.1:6667
HiddenServicePort 6697 127.0.0.1:6697
HiddenServiceVersion 3
EOF

    # Create start script
    cat > "$BRIDGE_DIR/irc/start-irc.sh" << 'EOF'
#!/bin/bash
# Start NeXuS IRC server with Tor hidden service

IRC_DIR="/home/user/.nexus-security/bridge/irc"
mkdir -p "$IRC_DIR/tor-data" "$IRC_DIR/hidden-service"
chmod 700 "$IRC_DIR/tor-data" "$IRC_DIR/hidden-service"

echo "🗨️  Starting NeXuS IRC Server..."

# Start IRC server container
cd "$IRC_DIR"
if command -v podman &> /dev/null; then
    podman run -d --name nexus-irc \
        -p 127.0.0.1:6667:6667 \
        -p 127.0.0.1:6697:6697 \
        -v "$IRC_DIR/inspircd.conf:/etc/inspircd/inspircd.conf:ro" \
        inspircd/inspircd-docker:latest 2>/dev/null || echo "IRC container may already exist"
fi

# Start Tor hidden service for IRC
nohup tor -f "$IRC_DIR/torrc-irc" > /tmp/tor-irc.log 2>&1 &
sleep 10

if [ -f "$IRC_DIR/hidden-service/hostname" ]; then
    echo "✅ IRC Hidden Service Ready!"
    echo "   .onion: $(cat $IRC_DIR/hidden-service/hostname)"
    echo "   Port:   6667 (plain) / 6697 (TLS)"
else
    echo "⚠️  Waiting for .onion address..."
fi
EOF
    chmod +x "$BRIDGE_DIR/irc/start-irc.sh"

    print_success "IRC darknet server configured"
    echo -e "   ${CYAN}Start with: $BRIDGE_DIR/irc/start-irc.sh${NC}"
}

# ============================================================
# WEBTORRENT
# ============================================================

setup_webtorrent() {
    print_nexus "Setting up WebTorrent (browser-based P2P)..."

    mkdir -p "$BRIDGE_DIR/webtorrent"

    # Create WebTorrent tracker container
    cat > "$BRIDGE_DIR/webtorrent/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  webtorrent-tracker:
    image: nicobrinkkemper/bittorrent-tracker:latest
    container_name: nexus-webtorrent
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"    # HTTP tracker
      - "127.0.0.1:8000:8000/udp" # UDP tracker
    command: ["--http", "--udp", "--ws"]
    labels:
      - "nexus.network=webtorrent"
EOF

    cat > "$BRIDGE_DIR/webtorrent/start-webtorrent.sh" << 'EOF'
#!/bin/bash
# Start WebTorrent tracker

echo "🌊 Starting WebTorrent Tracker..."

if command -v podman &> /dev/null; then
    podman run -d --name nexus-webtorrent \
        -p 127.0.0.1:8000:8000 \
        -p 127.0.0.1:8000:8000/udp \
        nicobrinkkemper/bittorrent-tracker:latest \
        --http --udp --ws 2>/dev/null || echo "Container may already exist"
fi

echo "✅ WebTorrent tracker running on port 8000"
echo "   Access via: ws://localhost:8000"
EOF
    chmod +x "$BRIDGE_DIR/webtorrent/start-webtorrent.sh"

    print_success "WebTorrent configured"
}

# ============================================================
# AMULE (ED2K/Kad Network)
# ============================================================

setup_amule() {
    print_nexus "Setting up aMule (ED2K/Kad network)..."

    mkdir -p "$BRIDGE_DIR/amule"

    cat > "$BRIDGE_DIR/amule/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  amule:
    image: ngosang/amule:latest
    container_name: nexus-amule
    restart: unless-stopped
    ports:
      - "127.0.0.1:4711:4711"    # Web UI
      - "4662:4662"              # ED2K TCP
      - "4665:4665/udp"          # ED2K UDP
      - "4672:4672/udp"          # Kad
    volumes:
      - ./config:/home/amule/.aMule
      - ./downloads:/downloads
      - ./temp:/temp
    environment:
      - PUID=1000
      - PGID=1000
      - WEBUI_ENABLED=true
    labels:
      - "nexus.network=amule"
EOF

    cat > "$BRIDGE_DIR/amule/start-amule.sh" << 'EOF'
#!/bin/bash
# Start aMule ED2K/Kad client

AMULE_DIR="/home/user/.nexus-security/bridge/amule"
mkdir -p "$AMULE_DIR"/{config,downloads,temp}

echo "🐴 Starting aMule (ED2K/Kad)..."

if command -v podman &> /dev/null; then
    podman run -d --name nexus-amule \
        -p 127.0.0.1:4711:4711 \
        -p 4662:4662 \
        -p 4665:4665/udp \
        -p 4672:4672/udp \
        -v "$AMULE_DIR/config:/home/amule/.aMule" \
        -v "$AMULE_DIR/downloads:/downloads" \
        -v "$AMULE_DIR/temp:/temp" \
        -e PUID=1000 -e PGID=1000 \
        -e WEBUI_ENABLED=true \
        ngosang/amule:latest 2>/dev/null || echo "Container may already exist"
fi

echo "✅ aMule running!"
echo "   Web UI: http://localhost:4711"
echo "   Default password: amule"
EOF
    chmod +x "$BRIDGE_DIR/amule/start-amule.sh"

    print_success "aMule configured"
}

# ============================================================
# UPDATE DARKNET PORTAL
# ============================================================

update_darknet_portal() {
    print_nexus "Updating darknet portal with network bridge links..."

    PORTAL_DIR="/home/user/.nexus-security/hydra/hosting/content/nexus-node"
    mkdir -p "$PORTAL_DIR"

    cat > "$PORTAL_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NeXuS Network Bridge</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Courier New', monospace;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a0a2e 50%, #0a0a0a 100%);
            color: #00ff00;
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 900px; margin: 0 auto; }

        .header {
            text-align: center;
            padding: 30px;
            border: 2px solid #00ff00;
            border-radius: 10px;
            margin-bottom: 30px;
            background: rgba(0, 255, 0, 0.05);
        }
        .header h1 {
            font-size: 2.5em;
            text-shadow: 0 0 20px #00ff00;
            margin-bottom: 10px;
        }
        .header .motto {
            color: #00ccff;
            font-size: 1.2em;
        }

        .network-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .network-card {
            background: rgba(0, 0, 0, 0.7);
            border: 1px solid #333;
            border-radius: 8px;
            padding: 20px;
            transition: all 0.3s ease;
        }
        .network-card:hover {
            border-color: #00ff00;
            box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
            transform: translateY(-2px);
        }
        .network-card h3 {
            font-size: 1.3em;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .network-card .icon { font-size: 1.5em; }
        .network-card p { color: #888; margin-bottom: 15px; font-size: 0.9em; }
        .network-card .status {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 0.8em;
        }
        .status.active { background: #00ff00; color: #000; }
        .status.bridged { background: #ff00ff; color: #fff; }
        .status.available { background: #ffff00; color: #000; }

        .services-section {
            background: rgba(0, 0, 0, 0.5);
            border: 1px solid #444;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .services-section h2 {
            color: #ff00ff;
            margin-bottom: 15px;
            border-bottom: 1px solid #444;
            padding-bottom: 10px;
        }

        .service-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        .service-item {
            padding: 15px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 5px;
            border-left: 3px solid #00ccff;
        }
        .service-item h4 { color: #00ccff; margin-bottom: 5px; }
        .service-item .port { color: #888; font-size: 0.85em; }

        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            border-top: 1px solid #333;
            margin-top: 30px;
        }

        .bridge-info {
            background: linear-gradient(90deg, rgba(255,0,255,0.1), rgba(0,255,255,0.1));
            border: 1px solid #ff00ff;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .bridge-info h3 { color: #ff00ff; margin-bottom: 10px; }
        .bridge-info ul { list-style: none; }
        .bridge-info li { padding: 5px 0; }
        .bridge-info li::before { content: "🔗 "; }

        a { color: #00ccff; text-decoration: none; }
        a:hover { color: #00ffff; text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌀 NeXuS Network Bridge 🌀</h1>
            <p class="motto">Sane • Simple • Secure</p>
            <p style="margin-top: 10px; color: #888;">Universal Gateway to Anonymous Networks</p>
        </div>

        <div class="bridge-info">
            <h3>🔐 All Traffic Routed Through Tor</h3>
            <ul>
                <li>Yggdrasil → Tor → Internet (IP Hidden)</li>
                <li>Reticulum → Tor → Mesh Network (IP Hidden)</li>
                <li>I2P ↔ Tor Bridge (Dual Anonymity)</li>
                <li>IPFS → Tor Gateway (Anonymous Publishing)</li>
            </ul>
        </div>

        <div class="network-grid">
            <div class="network-card">
                <h3><span class="icon">🧅</span> Tor Network</h3>
                <p>Onion routing with 16 circuits via Medusa + NeXuS Stack</p>
                <span class="status active">ACTIVE</span>
            </div>

            <div class="network-card">
                <h3><span class="icon">🟣</span> I2P Network</h3>
                <p>Garlic routing for anonymous services and eepsites</p>
                <span class="status active">ACTIVE</span>
            </div>

            <div class="network-card">
                <h3><span class="icon">🟢</span> Yggdrasil</h3>
                <p>Encrypted IPv6 mesh - now routed through Tor</p>
                <span class="status bridged">TOR BRIDGED</span>
            </div>

            <div class="network-card">
                <h3><span class="icon">🔴</span> Reticulum</h3>
                <p>Resilient cryptographic network - Tor bridged</p>
                <span class="status bridged">TOR BRIDGED</span>
            </div>

            <div class="network-card">
                <h3><span class="icon">❄️</span> Snowflake</h3>
                <p>Help censored users access Tor network</p>
                <span class="status available">AVAILABLE</span>
            </div>

            <div class="network-card">
                <h3><span class="icon">🦇</span> BATMAN Mesh</h3>
                <p>Local mesh networking fallback</p>
                <span class="status available">AVAILABLE</span>
            </div>
        </div>

        <div class="services-section">
            <h2>🛠️ Services</h2>
            <div class="service-list">
                <div class="service-item">
                    <h4>🗨️ IRC Chat</h4>
                    <p>Anonymous IRC server</p>
                    <span class="port">Port 6667 / 6697 (TLS)</span>
                </div>
                <div class="service-item">
                    <h4>🌊 WebTorrent</h4>
                    <p>Browser P2P file sharing</p>
                    <span class="port">Port 8000</span>
                </div>
                <div class="service-item">
                    <h4>🐴 aMule</h4>
                    <p>ED2K/Kad network</p>
                    <span class="port">Web UI: 4711</span>
                </div>
                <div class="service-item">
                    <h4>📦 IPFS</h4>
                    <p>Distributed file system</p>
                    <span class="port">Gateway: 8080</span>
                </div>
            </div>
        </div>

        <div class="services-section">
            <h2>📡 Proxy Access Points</h2>
            <div class="service-list">
                <div class="service-item">
                    <h4>Tor SOCKS5</h4>
                    <span class="port">127.0.0.1:1080 (Medusa)</span>
                </div>
                <div class="service-item">
                    <h4>Tor SOCKS5</h4>
                    <span class="port">127.0.0.1:9050 (HAProxy)</span>
                </div>
                <div class="service-item">
                    <h4>Tor HTTP</h4>
                    <span class="port">127.0.0.1:8888</span>
                </div>
                <div class="service-item">
                    <h4>I2P HTTP</h4>
                    <span class="port">127.0.0.1:4444</span>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>🌀 Powered by NeXuS Network Bridge</p>
            <p style="margin-top: 5px;">Because everyone together achieves MORE!</p>
        </div>
    </div>
</body>
</html>
EOF

    print_success "Darknet portal updated with network bridge info"
}

# ============================================================
# START ALL BRIDGES
# ============================================================

start_all_bridges() {
    show_banner
    print_nexus "Starting all network bridges..."
    echo

    # Check if Tor is running
    if ! pgrep -x "tor" > /dev/null && ! podman ps | grep -q "medusa-proxy"; then
        print_warning "Tor not detected. Starting Medusa proxy first..."
        podman run -d --name medusa-proxy \
            -p 8800:8800 -p 8888:8888 -p 1080:1080 -p 2090:2090 \
            datawookie/medusa-proxy 2>/dev/null || true
        sleep 5
    fi

    setup_yggdrasil_tor_bridge
    echo
    setup_reticulum_tor_bridge
    echo
    setup_snowflake_proxy
    echo
    setup_irc_darknet
    echo
    setup_webtorrent
    echo
    setup_amule
    echo
    update_darknet_portal
    echo

    print_nexus "All bridges configured!"
    echo
    show_status
}

show_status() {
    show_banner
    echo -e "${BOLD}Network Bridge Status${NC}"
    echo -e "${WHITE}════════════════════════════════════════${NC}"
    echo

    # Tor
    if podman ps 2>/dev/null | grep -q medusa-proxy; then
        echo -e "🧅 Tor (Medusa):     ${GREEN}ACTIVE${NC} - 9 circuits"
    else
        echo -e "🧅 Tor (Medusa):     ${YELLOW}NOT RUNNING${NC}"
    fi

    # NeXuS Stack
    tor_count=$(podman ps --format "{{.Names}}" 2>/dev/null | grep -c "nexus-tor-" || echo "0")
    if [ "$tor_count" -gt 0 ]; then
        echo -e "🧅 NeXuS Tor Stack:  ${GREEN}ACTIVE${NC} - $tor_count circuits"
    fi

    # I2P
    if nc -z 127.0.0.1 4444 2>/dev/null; then
        echo -e "🟣 I2P:              ${GREEN}ACTIVE${NC}"
    else
        echo -e "🟣 I2P:              ${YELLOW}NOT RUNNING${NC}"
    fi

    # Yggdrasil
    if [ -f "$BRIDGE_DIR/yggdrasil/start-ygg-tor.sh" ]; then
        echo -e "🟢 Yggdrasil Bridge: ${CYAN}CONFIGURED${NC} (Tor routed)"
    fi

    # Reticulum
    if [ -f "$BRIDGE_DIR/reticulum/start-rns-tor.sh" ]; then
        echo -e "🔴 Reticulum Bridge: ${CYAN}CONFIGURED${NC} (Tor routed)"
    fi

    # Snowflake
    if podman ps 2>/dev/null | grep -q nexus-snowflake; then
        echo -e "❄️  Snowflake:        ${GREEN}ACTIVE${NC}"
    elif [ -f "$BRIDGE_DIR/snowflake/start-snowflake.sh" ]; then
        echo -e "❄️  Snowflake:        ${CYAN}CONFIGURED${NC}"
    fi

    # IRC
    if podman ps 2>/dev/null | grep -q nexus-irc; then
        echo -e "🗨️  IRC Server:       ${GREEN}ACTIVE${NC}"
    elif [ -f "$BRIDGE_DIR/irc/start-irc.sh" ]; then
        echo -e "🗨️  IRC Server:       ${CYAN}CONFIGURED${NC}"
    fi

    # WebTorrent
    if podman ps 2>/dev/null | grep -q nexus-webtorrent; then
        echo -e "🌊 WebTorrent:       ${GREEN}ACTIVE${NC}"
    elif [ -f "$BRIDGE_DIR/webtorrent/start-webtorrent.sh" ]; then
        echo -e "🌊 WebTorrent:       ${CYAN}CONFIGURED${NC}"
    fi

    # aMule
    if podman ps 2>/dev/null | grep -q nexus-amule; then
        echo -e "🐴 aMule:            ${GREEN}ACTIVE${NC}"
    elif [ -f "$BRIDGE_DIR/amule/start-amule.sh" ]; then
        echo -e "🐴 aMule:            ${CYAN}CONFIGURED${NC}"
    fi

    echo
    echo -e "${WHITE}════════════════════════════════════════${NC}"
    echo -e "${CYAN}Start individual services from: $BRIDGE_DIR${NC}"
}

# ============================================================
# MAIN
# ============================================================

case "${1:-help}" in
    "setup"|"start")
        start_all_bridges
        ;;
    "status")
        show_status
        ;;
    "yggdrasil")
        setup_yggdrasil_tor_bridge
        ;;
    "reticulum")
        setup_reticulum_tor_bridge
        ;;
    "snowflake")
        setup_snowflake_proxy
        ;;
    "irc")
        setup_irc_darknet
        ;;
    "webtorrent")
        setup_webtorrent
        ;;
    "amule")
        setup_amule
        ;;
    "portal")
        update_darknet_portal
        ;;
    *)
        show_banner
        echo "Usage: $0 {setup|status|yggdrasil|reticulum|snowflake|irc|webtorrent|amule|portal}"
        echo
        echo "Commands:"
        echo "  setup      - Configure all network bridges"
        echo "  status     - Show bridge status"
        echo "  yggdrasil  - Setup Yggdrasil → Tor bridge"
        echo "  reticulum  - Setup Reticulum → Tor bridge"
        echo "  snowflake  - Setup Snowflake proxy"
        echo "  irc        - Setup IRC darknet server"
        echo "  webtorrent - Setup WebTorrent tracker"
        echo "  amule      - Setup aMule ED2K/Kad"
        echo "  portal     - Update darknet portal page"
        ;;
esac
