#!/bin/sh
# nexus-diva-start.sh — Start the DIVA Chain devnet
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful
#
# DIVA requires glibc (sodium-native, classic-level have no musl prebuilds).
# On Alpine musl, DIVA runs in a Podman container stack:
#   - nexus-i2p-http  (divax/i2p:current) — I2P SAM + SOCKS
#   - nexus-i2p-udp   (divax/i2p:current) — I2P UDP
#   - nexus-diva-n0   (localhost/nexus-diva-dev:latest) — DIVA chain node
#
# I2P bootstrap: 10-30 min for tunnel establishment
# DIVA API: PUT /tx → HTTP 204 once chain has quorum

DIVACHAIN_SRC="$HOME/Projects/nexus-node/divachain"
DEVNET_DIR="$HOME/Projects/nexus-divachain"
COMPOSE_FILE="$DEVNET_DIR/configs/nexus-devnet.yml"
DOCKERFILE="$DEVNET_DIR/configs/Dockerfile.dev"
IMAGE="localhost/nexus-diva-dev:latest"

_log() { echo "[diva] $*"; }

_is_running() {
    podman ps --format "{{.Names}}" 2>/dev/null | grep -q "nexus-diva"
}

_build_image() {
    _log "Building DIVA image (glibc/Deno)..."
    podman build -f "$DOCKERFILE" -t "$IMAGE" "$DIVACHAIN_SRC" 2>&1 | tail -5
    if [ $? -ne 0 ]; then
        _log "ERROR: build failed"
        exit 1
    fi
    _log "Image built: $IMAGE"
}

_clear_locks() {
    _log "Clearing LevelDB locks..."
    find "$DIVACHAIN_SRC/test/data/" -name LOCK -delete 2>/dev/null
}

_wait_api() {
    _log "Waiting for DIVA API..."
    i=0
    while [ $i -lt 30 ]; do
        token=$(curl -sf http://127.0.0.1:19720/testnet/token 2>/dev/null)
        if [ -n "$token" ]; then
            _log "API ready. Token: ${token}"
            return 0
        fi
        sleep 2
        i=$((i+1))
    done
    _log "WARNING: API not yet responding — I2P bootstrap in progress (10-30 min)"
    return 1
}

case "${1:-start}" in
    start)
        if _is_running; then
            _log "Already running"
            exit 0
        fi

        # Build image if missing
        if ! podman image exists "$IMAGE" 2>/dev/null; then
            _build_image
        fi

        _clear_locks

        _log "Starting devnet (I2P + DIVA)..."
        podman-compose -f "$COMPOSE_FILE" up -d
        if [ $? -ne 0 ]; then
            _log "ERROR: podman-compose failed"
            exit 1
        fi

        _log "Containers up. I2P bootstrapping (10-30 min for full tunnel)..."
        _log "API check in 10s..."
        sleep 10
        _wait_api

        _log ""
        _log "PUT /tx example:"
        _log "  token=\$(curl -sf http://127.0.0.1:19720/testnet/token)"
        _log "  curl -X PUT http://127.0.0.1:19720/tx \\"
        _log "    -H \"diva-token-api: \$token\" \\"
        _log "    -H 'Content-Type: application/json' \\"
        _log "    -d '[{\"command\":\"data\",\"ns\":\"nexus:darknet:registry\",\"d\":\"hello\"}]'"
        ;;

    stop)
        _log "Stopping devnet..."
        podman-compose -f "$COMPOSE_FILE" down
        echo "STOPPED"
        ;;

    status)
        if _is_running; then
            echo "RUNNING"
            podman ps --format "  {{.Names}}\t{{.Status}}" | grep nexus
        else
            echo "STOPPED"
        fi
        ;;

    build)
        _build_image
        ;;

    logs)
        podman logs -f nexus-diva-n0
        ;;

    token)
        curl -sf http://127.0.0.1:19720/testnet/token || echo "API not responding"
        ;;

    *)
        echo "Usage: $0 {start|stop|status|build|logs|token}"
        exit 1
        ;;
esac
