#!/bin/sh
# nexus-api-proxy.sh — manage the NeXuS Web Server (universal API proxy) in a tmux session.
#
# The server is a pure-Python stdlib HTTPS host that:
#   • serves a web-root (--root) over HTTPS
#   • injects API keys server-side from ~/.config/nexus/secrets/nexus.env
#   • proxies all AI providers at /api/llm/<provider>/v1/chat/completions
#
# Usage:  nexus-api-proxy.sh {start|stop|restart|logs|status}
# Alias:  api-proxy <action>   (add to ~/.config/fish/config.fish or ~/.bashrc)

SESSION="nexus-proxy"

SERVER="$HOME/Projects/nexus-web-server/nexus_web_server.py"
CHARGEN="$HOME/Projects/adv-ai-nexus/advanced-ai-character-generator-terminal-access"
ROOT="$HOME/nexus-web"
CERT="$CHARGEN/cert.pem"
KEY="$CHARGEN/key.pem"
PORT=8443

# PNG² Character Card editor (Flask, proxied at /charcard/)
CHARCARD_DIR="$HOME/Projects/NeXuS-png2-editor"
CHARCARD_PORT=7420
CHARCARD_SESSION="nexus-charcard"

HEALTH_URL="https://localhost:${PORT}/api/health"

_have_session()        { tmux has-session -t "$SESSION" 2>/dev/null; }
_have_charcard()       { tmux has-session -t "$CHARCARD_SESSION" 2>/dev/null; }
_server_pid()          { pgrep -af nexus_web_server | grep -v grep | head -1; }
_charcard_pid()        { pgrep -af "nexus_png2_editor" | grep -v grep | head -1; }
_charcard_alive()      { curl -s --max-time 2 "http://localhost:${CHARCARD_PORT}/" -o /dev/null 2>/dev/null; }
_server_alive()        { curl -sk --max-time 2 "$HEALTH_URL" -o /dev/null 2>/dev/null; }

_start_charcard() {
    if _have_charcard; then return; fi
    if [ ! -f "$CHARCARD_DIR/nexus_png2_editor.py" ]; then
        echo "nexus-api-proxy: charcard editor not found at $CHARCARD_DIR — skipping"
        return
    fi
    tmux new-session -d -s "$CHARCARD_SESSION" \
        "exec python3 $CHARCARD_DIR/nexus_png2_editor.py"
    echo "nexus-api-proxy: ● charcard editor starting on http://localhost:$CHARCARD_PORT"
}

_stop_charcard() {
    pid=$(_charcard_pid)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null && echo "nexus-api-proxy: stopped charcard (pid $pid)"
    _have_charcard && tmux kill-session -t "$CHARCARD_SESSION" 2>/dev/null
}

_status_body() {
    if _have_session; then echo "tmux session '$SESSION' : ● running"
    else                    echo "tmux session '$SESSION' : ○ stopped"; fi
    pid=$(_server_pid)
    if [ -n "$pid" ]; then echo "python3 server        : ● $pid"
    else                   echo "python3 server        : ○ not found"; fi
    cpid=$(_charcard_pid)
    if [ -n "$cpid" ]; then echo "charcard editor       : ● $cpid (port $CHARCARD_PORT)"
    else                    echo "charcard editor       : ○ not running"; fi
    if _server_alive; then
        echo "HTTPS :$PORT           : ● live"
        curl -sk --max-time 4 "$HEALTH_URL" 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
k=d.get('providers_with_keys',{})
ready=[p for p,v in k.items() if v]
locked=[p for p,v in k.items() if not v]
print('  ready :', ', '.join(ready))
if locked: print('  no key:', ', '.join(locked))
" 2>/dev/null
    else
        echo "HTTPS :$PORT           : ✗ not responding"
    fi
}

case "${1:-status}" in

start)
    if _have_session; then
        echo "nexus-api-proxy: already running (session '$SESSION')"
        _status_body
        exit 0
    fi
    for f in "$SERVER" "$ROOT" "$CERT" "$KEY"; do
        [ -e "$f" ] || { echo "nexus-api-proxy: missing: $f" >&2; exit 1; }
    done
    cmd="exec python3 $SERVER --root $ROOT --cert $CERT --key $KEY --port $PORT"
    tmux new-session -d -s "$SESSION" "$cmd"
    _start_charcard
    sleep 2
    if _server_alive; then
        echo "nexus-api-proxy: ● started on https://localhost:$PORT"
        _status_body
    else
        echo "nexus-api-proxy: started tmux session but server not yet answering — check logs:"
        echo "  api-proxy logs"
    fi
    ;;

stop)
    pid=$(_server_pid)
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null
        echo "nexus-api-proxy: sent SIGTERM to $pid"
    fi
    if _have_session; then
        tmux kill-session -t "$SESSION" 2>/dev/null
        echo "nexus-api-proxy: killed session '$SESSION'"
    else
        echo "nexus-api-proxy: session '$SESSION' was not running"
    fi
    _stop_charcard
    ;;

restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;

logs)
    if _have_session; then
        if [ -n "$TMUX" ]; then
            tmux switch-client -t "$SESSION"
        else
            tmux attach -t "$SESSION"
        fi
    else
        echo "nexus-api-proxy: session '$SESSION' is not running — use: api-proxy start"
        exit 1
    fi
    ;;

status)
    _status_body
    ;;

*)
    echo "Usage: $(basename "$0") {start|stop|restart|logs|status}"
    exit 1
    ;;
esac
