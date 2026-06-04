#!/bin/bash
"""
NeXuS HTTPS Launcher - Simple & Secure
Launch the Hydra interface with transparent HTTPS support
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
CERT_DIR="/home/user/.nexus-security/certs"
DOMAIN="localhost"
HTTPS_PORT="8443"
HTTP_PORT="8080"

echo -e "${CYAN}🔥 NeXuS Transparent HTTPS Server 🔥${NC}"
echo -e "${WHITE}Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!${NC}"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate self-signed certificate
generate_certificates() {
    echo -e "${YELLOW}🔐 Generating SSL certificates...${NC}"
    
    # Generate private key
    openssl genrsa -out "$CERT_DIR/nexus-hydra.key" 2048 2>/dev/null
    
    # Generate certificate signing request
    cat > "$CERT_DIR/nexus.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = NeXuS
L = Hydra Network
O = NeXuS Multi-Network Proxy
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = 127.0.0.1
DNS.3 = nexus-hydra
DNS.4 = hydra.nexus
DNS.5 = *.nexus
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF

    # Generate self-signed certificate
    openssl req -new -x509 -key "$CERT_DIR/nexus-hydra.key" \
        -out "$CERT_DIR/nexus-hydra.crt" \
        -days 365 \
        -config "$CERT_DIR/nexus.conf" \
        -extensions v3_req 2>/dev/null
    
    if [[ -f "$CERT_DIR/nexus-hydra.crt" ]]; then
        echo -e "${GREEN}✅ SSL certificates generated successfully${NC}"
        echo -e "${WHITE}   Certificate: $CERT_DIR/nexus-hydra.crt${NC}"
        echo -e "${WHITE}   Private Key: $CERT_DIR/nexus-hydra.key${NC}"
    else
        echo -e "${RED}❌ Failed to generate certificates${NC}"
        exit 1
    fi
}

# Check if certificates exist
if [[ ! -f "$CERT_DIR/nexus-hydra.crt" ]] || [[ ! -f "$CERT_DIR/nexus-hydra.key" ]]; then
    generate_certificates
else
    echo -e "${GREEN}✅ SSL certificates already exist${NC}"
fi

# Check certificate validity
if openssl x509 -in "$CERT_DIR/nexus-hydra.crt" -checkend 86400 -noout >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Certificate is valid${NC}"
else
    echo -e "${YELLOW}⚠️ Certificate expired, regenerating...${NC}"
    generate_certificates
fi

echo ""
echo -e "${PURPLE}📊 Certificate Information:${NC}"
openssl x509 -in "$CERT_DIR/nexus-hydra.crt" -noout -subject -dates -fingerprint | while read line; do
    echo -e "${WHITE}   $line${NC}"
done

echo ""
echo -e "${CYAN}🚀 Starting NeXuS Hydra HTTPS Server...${NC}"
echo -e "${WHITE}🔐 HTTPS: https://localhost:$HTTPS_PORT${NC}"
echo -e "${WHITE}🎨 Features: 20 Banners + 1,640 Icons + SSL Encryption${NC}"
echo -e "${WHITE}🦆 Nine-headed duck proxy beast with transparent HTTPS!${NC}"
echo ""

# Launch the HTTPS server using uvicorn with SSL
cd /home/user/scripts

# Kill any existing servers
pkill -f "nexus-hydra-ultimate-interface.py" 2>/dev/null

# Start HTTPS server
echo -e "${GREEN}🔥 Launching HTTPS server...${NC}"
python3 -c "
import uvicorn
import sys
sys.path.append('/home/user/scripts')

try:
    from nexus_hydra_ultimate_interface import app
    print('✅ NeXuS Hydra app loaded successfully')
    
    uvicorn.run(
        app,
        host='0.0.0.0',
        port=$HTTPS_PORT,
        ssl_keyfile='$CERT_DIR/nexus-hydra.key',
        ssl_certfile='$CERT_DIR/nexus-hydra.crt',
        access_log=True
    )
except ImportError as e:
    print(f'❌ Failed to import app: {e}')
except Exception as e:
    print(f'❌ Server error: {e}')
"