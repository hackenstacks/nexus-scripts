#!/bin/sh
# nexus-serve.sh — NeXuS local HTTPS server
# Serves ~/.nexus/www/ on https://localhost:8443
# Uses nexus-https from ~/ai-character-chat/nexus-https/
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

NEXUS_HTTPS="$HOME/ai-character-chat/nexus-https/nexus-https"
WWW_ROOT="$HOME/.nexus/www"
PORT="8443"
PID_FILE="/tmp/nexus-serve.pid"
LOG_FILE="/tmp/nexus-serve.log"

R='\033[0m'; BOLD='\033[1m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'
YLW='\033[38;5;226m'; GRY='\033[38;5;240m'
RED='\033[38;5;196m'; WHT='\033[38;5;255m'

mkdir -p "$WWW_ROOT"

# Ensure forge store is linked into www root
if [ ! -e "$WWW_ROOT/forge" ] && [ -d "$HOME/.nexus/forge/store" ]; then
    ln -s "$HOME/.nexus/forge/store" "$WWW_ROOT/forge"
fi
if [ ! -e "$WWW_ROOT/friend-cert" ] && [ -d "$HOME/.nexus/forge/store/nexus-friend-cert" ]; then
    ln -s "$HOME/.nexus/forge/store/nexus-friend-cert" "$WWW_ROOT/friend-cert"
fi

_is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

_status() {
    if _is_running; then
        printf "${GRN}● running${R}  https://localhost:%s\n" "$PORT"
        printf "  ${GRY}PID: %s  root: %s${R}\n" "$(cat "$PID_FILE")" "$WWW_ROOT"
    else
        printf "${GRY}○ stopped${R}\n"
    fi
}

_start() {
    if _is_running; then
        printf "  ${YLW}Already running — https://localhost:%s${R}\n" "$PORT"
        return
    fi
    if [ ! -x "$NEXUS_HTTPS" ]; then
        printf "  ${RED}nexus-https not found at %s${R}\n" "$NEXUS_HTTPS"
        exit 1
    fi
    printf "  ${CYN}Starting NeXuS HTTPS server...${R}\n"
    nohup "$NEXUS_HTTPS" -p "$PORT" -d "$WWW_ROOT" >"$LOG_FILE" 2>&1 &
    pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 1
    if _is_running; then
        printf "  ${GRN}● Up — https://localhost:%s${R}\n" "$PORT"
        printf "  ${GRY}Serving: %s${R}\n" "$WWW_ROOT"
        printf "  ${GRY}Log: %s${R}\n" "$LOG_FILE"
    else
        printf "  ${RED}Failed to start — check %s${R}\n" "$LOG_FILE"
        rm -f "$PID_FILE"
    fi
}

_stop() {
    if _is_running; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
        printf "  ${GRY}Stopped${R}\n"
    else
        printf "  ${GRY}Not running${R}\n"
    fi
}

_open() {
    _start
    # Open in w3m in WEB pane if in tmux
    if [ -n "$TMUX" ]; then
        tmux select-pane -t "WEB.1" 2>/dev/null && \
            tmux send-keys -t "WEB.1" "w3m -o ssl_verify_server=0 https://localhost:$PORT/" Enter 2>/dev/null || \
            tmux new-window -n "PORTAL" "w3m -o ssl_verify_server=0 https://localhost:$PORT/"
    fi
}

case "${1:-status}" in
    start)   _start  ;;
    stop)    _stop   ;;
    restart) _stop; sleep 1; _start ;;
    status)  _status ;;
    open)    _open   ;;
    log)     tail -f "$LOG_FILE" ;;
    *)
        printf "  Usage: %s {start|stop|restart|status|open|log}\n" "$(basename "$0")"
        exit 1
        ;;
esac
