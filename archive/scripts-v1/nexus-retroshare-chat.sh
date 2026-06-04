#!/bin/sh
# nexus-retroshare-chat.sh — RetroShare text companion
# Reads contacts, chat, forums, channels via RetroShare JSON API
# Requires: RetroShare → Plugins → JSON API enabled on port 9090
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

API="http://127.0.0.1:9090/api/v2"
MODE="contacts"   # contacts | chat | forums | channels
ACTIVE_PEER=""
ACTIVE_FORUM=""
REFRESH=10

_api() { curl -s --max-time 5 "${API}${1}" 2>/dev/null; }
_api_post() { curl -s --max-time 5 -X POST -H "Content-Type: application/json" \
    -d "$2" "${API}${1}" 2>/dev/null; }
_api_up() { _api "/peers" >/dev/null 2>&1; }

_anykey() {
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Waiting screen when API is offline ─────────────────────────────────
_wait_for_api() {
    while true; do
        clear
        printf "\n  ${MAG}${BOLD}◈  RETROSHARE TEXT${R}\n"
        printf "  ${GRY}────────────────────────────────────────────────${R}\n\n"
        printf "  ${GRY}Waiting for RetroShare JSON API...${R}\n\n"
        printf "  ${YLW}To enable:${R}\n"
        printf "  RetroShare → Plugins → Plugin Manager → JSON API\n"
        printf "  Set port ${CYN}9090${R} → restart RetroShare\n\n"
        printf "  ${DIM}Retrying every %ds  [q] quit${R}\n" "$REFRESH"

        i=0
        while [ $i -lt $REFRESH ]; do
            _api_up && return   # API came up — proceed
            old=$(stty -g 2>/dev/null); stty -echo -icanon min 0 time 1 2>/dev/null
            key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
            stty "$old" 2>/dev/null
            [ "$key" = "q" ] || [ "$key" = "Q" ] && exit 0
            i=$((i+1))
        done
    done
}

# ── Get contacts ────────────────────────────────────────────────────────
_get_contacts() {
    _api "/peers" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    peers = d if isinstance(d, list) else d.get('data', [])
    for p in peers:
        online = p.get('online', False)
        dot = '\033[38;5;82m●\033[0m' if online else '\033[38;5;240m○\033[0m'
        name = p.get('name', '?')[:20]
        pid = p.get('id', '')[:8]
        print(f'{dot} {name:<20} {pid}')
except: print('  error reading peers')
" 2>/dev/null
}

# ── Get chat messages with a peer ───────────────────────────────────────
_get_chat() {
    peer_id="$1"
    _api "/chat/messages/${peer_id}" | python3 -c "
import sys, json, time
try:
    d = json.load(sys.stdin)
    msgs = d if isinstance(d, list) else d.get('data', [])
    for m in msgs[-20:]:  # last 20
        ts = time.strftime('%H:%M', time.localtime(m.get('sendTime', 0)))
        author = m.get('authorId', '')[:8]
        body = m.get('msg', '').replace('<br/>', '\n').replace('<br>', '\n')
        # strip HTML tags
        import re
        body = re.sub('<[^>]+>', '', body)[:200]
        incoming = m.get('incoming', True)
        if incoming:
            print(f'  \033[38;5;51m{author}\033[0m \033[38;5;240m{ts}\033[0m  {body}')
        else:
            print(f'  \033[38;5;82m you\033[0m \033[38;5;240m{ts}\033[0m  {body}')
except: print('  no messages')
" 2>/dev/null
}

# ── Send chat message ───────────────────────────────────────────────────
_send_chat() {
    peer_id="$1"
    msg="$2"
    escaped=$(printf '%s' "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
    _api_post "/chat/messages/${peer_id}" "{\"msg\": ${escaped}}" >/dev/null 2>&1
}

# ── Get forums ──────────────────────────────────────────────────────────
_get_forums() {
    _api "/forums" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    forums = d if isinstance(d, list) else d.get('data', [])
    for f in forums[:15]:
        name = f.get('name', '?')[:30]
        fid = f.get('id', '')[:8]
        posts = f.get('numberOfMessages', 0)
        unread = f.get('unreadCount', 0)
        ur = f'\033[38;5;226m [{unread} new]\033[0m' if unread else ''
        print(f'  \033[38;5;51m{fid}\033[0m  {name:<30}  \033[38;5;240m{posts} posts\033[0m{ur}')
except: print('  no forums')
" 2>/dev/null
}

# ── Get forum posts ─────────────────────────────────────────────────────
_get_forum_posts() {
    forum_id="$1"
    _api "/forums/${forum_id}/posts" | python3 -c "
import sys, json, time
try:
    d = json.load(sys.stdin)
    posts = d if isinstance(d, list) else d.get('data', [])
    for p in posts[-15:]:
        ts = time.strftime('%m/%d %H:%M', time.localtime(p.get('mTime', 0)))
        author = p.get('authorName', '?')[:15]
        title = p.get('title', '?')[:50]
        print(f'  \033[38;5;82m{author:<15}\033[0m \033[38;5;240m{ts}\033[0m  {title}')
except: print('  no posts')
" 2>/dev/null
}

# ── Get channels ────────────────────────────────────────────────────────
_get_channels() {
    _api "/channels" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    chs = d if isinstance(d, list) else d.get('data', [])
    for c in chs[:15]:
        name = c.get('name', '?')[:30]
        cid = c.get('id', '')[:8]
        posts = c.get('numberOfMessages', 0)
        unread = c.get('unreadCount', 0)
        ur = f'\033[38;5;226m [{unread} new]\033[0m' if unread else ''
        print(f'  \033[38;5;177m{cid}\033[0m  {name:<30}  \033[38;5;240m{posts}\033[0m{ur}')
except: print('  no channels')
" 2>/dev/null
}

# ── Header bar ──────────────────────────────────────────────────────────
_header() {
    clear
    printf "  ${MAG}${BOLD}◈ RS TEXT${R}"
    case "$MODE" in
        contacts) printf "  ${CYN}[CONTACTS]${R}  ${GRY}[f]orums  [c]hannels${R}" ;;
        forums)   printf "  ${GRY}contacts  ${CYN}[FORUMS]${R}  ${GRY}[c]hannels${R}" ;;
        channels) printf "  ${GRY}contacts  forums  ${CYN}[CHANNELS]${R}" ;;
        chat)     printf "  ${GRY}contacts  ${CYN}[CHAT: %s]${R}" "$ACTIVE_PEER" ;;
    esac
    printf "  ${GRY}[tab] switch  [r] refresh  [q] quit${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n"
}

# ── Input bar for sending messages ─────────────────────────────────────
_input_bar() {
    printf "\n  ${CYN}>${R} "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r msg
    stty "$old" 2>/dev/null
    echo "$msg"
}

# ── Select peer from contact list ──────────────────────────────────────
_select_peer() {
    _api "/peers" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    peers = d if isinstance(d, list) else d.get('data', [])
    for p in peers:
        print(p.get('id','') + ' ' + p.get('name','?'))
except: pass
" 2>/dev/null | fzf --prompt="Chat with > " --height=40% 2>/dev/null | awk '{print $1}'
}

# ── Select forum ────────────────────────────────────────────────────────
_select_forum() {
    _api "/forums" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    forums = d if isinstance(d, list) else d.get('data', [])
    for f in forums:
        print(f.get('id','') + ' ' + f.get('name','?'))
except: pass
" 2>/dev/null | fzf --prompt="Forum > " --height=40% 2>/dev/null | awk '{print $1}'
}

# ── Main draw loop ──────────────────────────────────────────────────────
_draw() {
    _header
    case "$MODE" in
        contacts)
            printf "  ${BOLD}${WHT}CONTACTS${R}\n\n"
            _get_contacts
            printf "\n  ${GRY}[enter] open chat  [f] forums  [c] channels${R}\n"
            ;;
        chat)
            printf "  ${BOLD}${WHT}CHAT — %s${R}\n\n" "$ACTIVE_PEER"
            _get_chat "$ACTIVE_PEER_ID"
            printf "\n  ${GRY}[m] send message  [b] back to contacts${R}\n"
            ;;
        forums)
            if [ -n "$ACTIVE_FORUM" ]; then
                printf "  ${BOLD}${WHT}FORUM — %s${R}\n\n" "$ACTIVE_FORUM"
                _get_forum_posts "$ACTIVE_FORUM"
                printf "\n  ${GRY}[b] back to forum list${R}\n"
            else
                printf "  ${BOLD}${WHT}FORUMS${R}\n\n"
                _get_forums
                printf "\n  ${GRY}[enter] open forum  [p] contacts  [c] channels${R}\n"
            fi
            ;;
        channels)
            printf "  ${BOLD}${WHT}CHANNELS${R}\n\n"
            _get_channels
            printf "\n  ${GRY}[p] contacts  [f] forums${R}\n"
            ;;
    esac
}

# ── Main loop ────────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

# Wait for API
_api_up || _wait_for_api

last_draw=0
while true; do
    now=$(date +%s)
    if [ $(( now - last_draw )) -ge $REFRESH ]; then
        _draw
        last_draw=$now
    fi

    stty -echo -icanon min 0 time 2 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    [ -z "$key" ] && continue

    case "$key" in
        # Tab — cycle modes
        "	") case "$MODE" in
                contacts) MODE="forums" ;;
                forums)   MODE="channels" ;;
                channels) MODE="contacts" ;;
                chat)     MODE="contacts" ;;
            esac; _draw; last_draw=$(date +%s) ;;

        r|R) _draw; last_draw=$(date +%s) ;;

        # Context-sensitive actions
        f|F) MODE="forums";   ACTIVE_FORUM=""; _draw; last_draw=$(date +%s) ;;
        c|C) MODE="channels"; _draw; last_draw=$(date +%s) ;;
        p|P) MODE="contacts"; _draw; last_draw=$(date +%s) ;;

        b|B)
            case "$MODE" in
                chat)   MODE="contacts"; ACTIVE_PEER=""; ACTIVE_PEER_ID="" ;;
                forums) ACTIVE_FORUM="" ;;
            esac
            _draw; last_draw=$(date +%s) ;;

        # Open chat with selected contact
        "") # Enter key
            case "$MODE" in
                contacts)
                    pid=$(_select_peer)
                    if [ -n "$pid" ]; then
                        ACTIVE_PEER_ID="$pid"
                        ACTIVE_PEER=$(echo "$pid" | cut -c1-8)
                        MODE="chat"
                        _draw; last_draw=$(date +%s)
                    fi ;;
                forums)
                    if [ -z "$ACTIVE_FORUM" ]; then
                        fid=$(_select_forum)
                        [ -n "$fid" ] && ACTIVE_FORUM="$fid"
                        _draw; last_draw=$(date +%s)
                    fi ;;
            esac ;;

        # Send message in chat mode
        m|M)
            if [ "$MODE" = "chat" ] && [ -n "$ACTIVE_PEER_ID" ]; then
                printf "\n  ${CYN}Message > ${R}"
                old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
                IFS= read -r msg
                stty "$old" 2>/dev/null
                [ -n "$msg" ] && _send_chat "$ACTIVE_PEER_ID" "$msg"
                _draw; last_draw=$(date +%s)
            fi ;;

        q|Q) exit 0 ;;
    esac
done
