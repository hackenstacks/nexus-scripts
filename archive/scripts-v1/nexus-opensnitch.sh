#!/bin/bash
# nexus-opensnitch.sh — Start OpenSnitch in a Debian container
# NeXuS Security Stack

CONTAINER="nexus-opensnitch"
IMAGE="docker.io/debian:bookworm-slim"
VERSION="1.6.6"
CONFIG_DIR="$HOME/.nexus-security/containers/opensnitch"
LOG_DIR="$HOME/.local/share/containers/nexus-security/opensnitch"

mkdir -p "$CONFIG_DIR" "$LOG_DIR"

status() {
    podman ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"
}

install_opensnitch() {
    echo "📦 Installing OpenSnitch inside container..."
    podman exec "$CONTAINER" bash -c "
        apt-get update -qq &&
        apt-get install -y -qq curl iptables kmod &&
        curl -sLO https://github.com/evilsocket/opensnitch/releases/download/v${VERSION}/opensnitch_${VERSION}-1_amd64.deb &&
        dpkg -i opensnitch_${VERSION}-1_amd64.deb &&
        rm opensnitch_${VERSION}-1_amd64.deb &&
        echo 'OpenSnitch installed'
    "
}

start() {
    echo "=== NeXuS OpenSnitch ==="

    # Remove dead container if exists
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        if ! status; then
            echo "🔄 Removing stopped container..."
            podman rm "$CONTAINER" >/dev/null
        fi
    fi

    if status; then
        echo "✅ Already running"
        return
    fi

    echo "🚀 Starting container..."
    podman run -d \
        --name "$CONTAINER" \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        --cap-add=SYS_MODULE \
        --network host \
        --volume "$CONFIG_DIR:/etc/opensnitchd:Z" \
        --volume "$LOG_DIR:/var/log/opensnitchd:Z" \
        "$IMAGE" \
        /bin/bash -c "tail -f /dev/null"

    echo "⏳ Waiting for container..."
    sleep 3

    # Check if opensnitch is installed
    if ! podman exec "$CONTAINER" which opensnitchd >/dev/null 2>&1; then
        install_opensnitch
    fi

    echo "🔒 Starting opensnitchd..."
    podman exec -d "$CONTAINER" opensnitchd -config /etc/opensnitchd/daemon.conf

    echo "✅ OpenSnitch running"
    echo "📋 Logs: podman exec $CONTAINER tail -f /var/log/opensnitchd/daemon.log"
}

stop() {
    echo "🛑 Stopping OpenSnitch..."
    podman stop "$CONTAINER" 2>/dev/null
    podman rm "$CONTAINER" 2>/dev/null
    echo "✅ Stopped"
}

logs() {
    podman exec "$CONTAINER" tail -f /var/log/opensnitchd/daemon.log 2>/dev/null || \
    podman logs -f "$CONTAINER"
}

case "${1:-start}" in
    start)  start ;;
    stop)   stop ;;
    restart) stop; sleep 2; start ;;
    logs)   logs ;;
    status) status && echo "✅ Running" || echo "❌ Not running" ;;
    shell)  podman exec -it "$CONTAINER" bash ;;
    *)      echo "Usage: $0 {start|stop|restart|logs|status|shell}" ;;
esac
