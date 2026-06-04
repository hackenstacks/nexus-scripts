#!/bin/bash
# NeXuS Docs Server
# Serves the MkDocs documentation site locally
# HTTP: http://localhost:8000 (mkdocs native)
# HTTPS: https://localhost:8443 (SSL wrapped via Python)
# Sane • Simple • Secure

DOCS_DIR="/home/user/Documents/nexus-docs"
CERT_DIR="/home/user/.nexus-security/certs"
HTTP_PORT="8000"
HTTPS_PORT="8443"
PID_FILE="/tmp/nexus-docs.pid"
HTTPS_PID_FILE="/tmp/nexus-docs-https.pid"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${CYAN}▸${NC} $1"; }

# ─── cert check / generate ──────────────────────────────────────────────────
ensure_certs() {
    if [[ -f "$CERT_DIR/nexus-hydra.crt" ]] && \
       openssl x509 -in "$CERT_DIR/nexus-hydra.crt" -checkend 86400 -noout 2>/dev/null; then
        ok "SSL certificate valid"
        return 0
    fi

    warn "Generating self-signed certificate..."
    mkdir -p "$CERT_DIR"
    cat > "$CERT_DIR/nexus.conf" << 'CONF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = localhost
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
CONF
    openssl genrsa -out "$CERT_DIR/nexus-hydra.key" 2048 2>/dev/null
    openssl req -new -x509 -key "$CERT_DIR/nexus-hydra.key" \
        -out "$CERT_DIR/nexus-hydra.crt" \
        -days 365 -config "$CERT_DIR/nexus.conf" \
        -extensions v3_req 2>/dev/null
    ok "Certificate generated (valid 365 days)"
}

# ─── status ─────────────────────────────────────────────────────────────────
status() {
    echo -e "\n${CYAN}NeXuS Docs Status${NC}"
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        ok "HTTP  running → http://localhost:${HTTP_PORT}  (PID $(cat $PID_FILE))"
    else
        warn "HTTP  not running"
    fi
    if [[ -f "$HTTPS_PID_FILE" ]] && kill -0 "$(cat $HTTPS_PID_FILE)" 2>/dev/null; then
        ok "HTTPS running → https://localhost:${HTTPS_PORT}  (PID $(cat $HTTPS_PID_FILE))"
    else
        warn "HTTPS not running"
    fi
}

# ─── stop ───────────────────────────────────────────────────────────────────
stop() {
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat $PID_FILE)" 2>/dev/null && ok "HTTP server stopped" || warn "HTTP was not running"
        rm -f "$PID_FILE"
    fi
    if [[ -f "$HTTPS_PID_FILE" ]]; then
        kill "$(cat $HTTPS_PID_FILE)" 2>/dev/null && ok "HTTPS server stopped" || warn "HTTPS was not running"
        rm -f "$HTTPS_PID_FILE"
    fi
    pkill -f "mkdocs serve" 2>/dev/null
    pkill -f "nexus-docs-https" 2>/dev/null
}

# ─── start ──────────────────────────────────────────────────────────────────
start() {
    local mode="${1:-both}"  # http | https | both

    # Already running?
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        warn "Already running — http://localhost:${HTTP_PORT}"
        [[ -f "$HTTPS_PID_FILE" ]] && kill -0 "$(cat $HTTPS_PID_FILE)" 2>/dev/null && \
            warn "HTTPS already running — https://localhost:${HTTPS_PORT}"
        return 0
    fi

    echo -e "\n${CYAN}🐉 NeXuS Docs${NC} ${WHITE}beta-v1${NC}\n"
    info "Docs dir: $DOCS_DIR"

    # Start mkdocs HTTP server
    cd "$DOCS_DIR" || { err "Docs dir not found: $DOCS_DIR"; exit 1; }
    mkdocs serve --dev-addr "127.0.0.1:${HTTP_PORT}" > /tmp/nexus-docs.log 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1

    if kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        ok "HTTP  → http://localhost:${HTTP_PORT}/nexus/"
    else
        err "mkdocs failed to start — check /tmp/nexus-docs.log"
        exit 1
    fi

    # HTTPS wrapper
    if [[ "$mode" != "http" ]]; then
        ensure_certs
        python3 - "$HTTP_PORT" "$HTTPS_PORT" \
            "$CERT_DIR/nexus-hydra.crt" "$CERT_DIR/nexus-hydra.key" << 'PYEOF' &
import sys, ssl, http.server, urllib.request, threading

http_port  = int(sys.argv[1])
https_port = int(sys.argv[2])
certfile   = sys.argv[3]
keyfile    = sys.argv[4]

class Proxy(http.server.BaseHTTPRequestHandler):
    def do_request(self):
        url = f"http://127.0.0.1:{http_port}{self.path}"
        try:
            with urllib.request.urlopen(url) as r:
                body = r.read()
                self.send_response(r.status)
                for k, v in r.headers.items():
                    if k.lower() not in ('transfer-encoding',):
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(body)
        except Exception as e:
            self.send_error(502, str(e))
    do_GET = do_request
    do_POST = do_request
    def log_message(self, *a): pass

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(certfile, keyfile)
srv = http.server.HTTPServer(('0.0.0.0', https_port), Proxy)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PYEOF
        echo $! > "$HTTPS_PID_FILE"
        sleep 1
        if kill -0 "$(cat $HTTPS_PID_FILE)" 2>/dev/null; then
            ok "HTTPS → https://localhost:${HTTPS_PORT}/nexus/"
        else
            warn "HTTPS wrapper failed — HTTP still available"
        fi
    fi

    echo ""
    echo -e "${WHITE}  Log:${NC} /tmp/nexus-docs.log"
    echo -e "${WHITE}  Stop:${NC} nexus-docs.sh stop"
    echo ""
}

# ─── main ───────────────────────────────────────────────────────────────────
case "${1:-start}" in
    start)  start "both" ;;
    http)   start "http" ;;
    https)  start "https" ;;
    stop)   stop ;;
    restart) stop; sleep 1; start "both" ;;
    status) status ;;
    log)    tail -f /tmp/nexus-docs.log ;;
    *)
        echo "Usage: nexus-docs.sh [start|http|https|stop|restart|status|log]"
        echo "  start   — HTTP + HTTPS (default)"
        echo "  http    — HTTP only (port ${HTTP_PORT})"
        echo "  stop    — stop all"
        echo "  restart — restart all"
        echo "  status  — show running status"
        echo "  log     — tail the mkdocs log"
        ;;
esac
