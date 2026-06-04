#!/bin/bash
# nexus-jitsi.sh — Self-hosted Jitsi Meet stack via Podman
# NeXuS Communications Stack

JITSI_DIR="$HOME/.config/nexus/jitsi"
COMPOSE_FILE="$JITSI_DIR/docker-compose.yml"
ENV_FILE="$JITSI_DIR/.env"

# Jitsi config
DOMAIN="${JITSI_DOMAIN:-meet.nexusnet.network}"
HTTP_PORT="${JITSI_HTTP_PORT:-8880}"
HTTPS_PORT="${JITSI_HTTPS_PORT:-8443}"

setup() {
    echo "=== NeXuS Jitsi Setup ==="
    mkdir -p "$JITSI_DIR"
    mkdir -p "$JITSI_DIR"/{web,prosody,jicofo,jvb}

    # Generate secrets
    SECRET1=$(openssl rand -hex 16)
    SECRET2=$(openssl rand -hex 16)
    SECRET3=$(openssl rand -hex 16)

    cat > "$ENV_FILE" <<EOF
# NeXuS Jitsi Config
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
PUBLIC_URL=https://${DOMAIN}:${HTTPS_PORT}
DOCKER_HOST_ADDRESS=127.0.0.1
XMPP_DOMAIN=${DOMAIN}
XMPP_AUTH_DOMAIN=auth.${DOMAIN}
XMPP_BOSH_URL_BASE=http://xmpp.${DOMAIN}:5280
XMPP_MUC_DOMAIN=muc.${DOMAIN}
JICOFO_AUTH_USER=focus
JICOFO_AUTH_PASSWORD=${SECRET1}
JVB_AUTH_USER=jvb
JVB_AUTH_PASSWORD=${SECRET2}
JIBRI_RECORDER_PASSWORD=${SECRET3}
ENABLE_LETSENCRYPT=0
ENABLE_HTTP_REDIRECT=0
DISABLE_HTTPS=1
TZ=UTC
EOF

    cat > "$COMPOSE_FILE" <<'EOF'
version: '3'

services:
  web:
    image: docker.io/jitsi/web:stable
    ports:
      - "${HTTP_PORT}:80"
    volumes:
      - ./web:/config
    environment:
      - DISABLE_HTTPS=1
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_BOSH_URL_BASE
      - XMPP_MUC_DOMAIN
      - TZ
    networks:
      jitsi:
        aliases:
          - meet.jitsi

  prosody:
    image: docker.io/jitsi/prosody:stable
    volumes:
      - ./prosody:/config
    environment:
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_MUC_DOMAIN
      - JICOFO_AUTH_USER
      - JICOFO_AUTH_PASSWORD
      - JVB_AUTH_USER
      - JVB_AUTH_PASSWORD
      - TZ
    networks:
      jitsi:
        aliases:
          - xmpp.meet.jitsi

  jicofo:
    image: docker.io/jitsi/jicofo:stable
    volumes:
      - ./jicofo:/config
    environment:
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_MUC_DOMAIN
      - JICOFO_AUTH_USER
      - JICOFO_AUTH_PASSWORD
      - TZ
    depends_on:
      - prosody
    networks:
      - jitsi

  jvb:
    image: docker.io/jitsi/jvb:stable
    ports:
      - "10000:10000/udp"
    volumes:
      - ./jvb:/config
    environment:
      - XMPP_AUTH_DOMAIN
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - JVB_AUTH_USER
      - JVB_AUTH_PASSWORD
      - DOCKER_HOST_ADDRESS
      - TZ
    depends_on:
      - prosody
    networks:
      - jitsi

networks:
  jitsi:
EOF

    echo "✅ Config created at $JITSI_DIR"
    echo "📝 Edit $ENV_FILE to change ports/domain"
}

start() {
    echo "=== NeXuS Jitsi Meet ==="

    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "⚙️  First run — running setup..."
        setup
    fi

    cd "$JITSI_DIR"
    podman-compose --env-file "$ENV_FILE" up -d

    echo ""
    echo "✅ Jitsi Meet running!"
    echo "🌐 Open: http://localhost:${HTTP_PORT}"
    echo "📋 Logs: $0 logs"
}

stop() {
    echo "🛑 Stopping Jitsi..."
    cd "$JITSI_DIR"
    podman-compose down
    echo "✅ Stopped"
}

logs() {
    cd "$JITSI_DIR"
    podman-compose logs -f
}

status() {
    podman ps --format "table {{.Names}}\t{{.Status}}" | grep -E "web|prosody|jicofo|jvb" || echo "❌ Not running"
}

case "${1:-start}" in
    start)  start ;;
    stop)   stop ;;
    restart) stop; sleep 2; start ;;
    setup)  setup ;;
    logs)   logs ;;
    status) status ;;
    *)      echo "Usage: $0 {start|stop|restart|setup|logs|status}" ;;
esac
