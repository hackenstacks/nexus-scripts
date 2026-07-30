#!/bin/sh
# nexus-web-hub.sh — WEB window hub strip
# Quick search, GUI browser launcher, clipper, bookmarks
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

CLIP_LOG="$HOME/.nexus/web-clips.log"
BOOKMARKS="$HOME/.nexus/web-bookmarks.txt"
SCRIPTS="$HOME/scripts"
TOR_PROXY="socks5h://127.0.0.1:9050"
TOR_RUNNING=0
mkdir -p "$HOME/.nexus"
touch "$CLIP_LOG" "$BOOKMARKS" 2>/dev/null

_in_gui()    { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_tor_up()    { ss -tln 2>/dev/null | grep -q ':9050' && TOR_RUNNING=1 || TOR_RUNNING=0; }
_proxy_dot() { pgrep -f nexus_web_server >/dev/null 2>&1 && printf "${GRN}●${R}" || printf "${GRY}●${R}"; }

_open_proxy() {
    url="$1"
    if tmux list-windows -F '#W' 2>/dev/null | grep -q '^WEB$'; then
        tmux select-pane -t "WEB.1" 2>/dev/null
        tmux send-keys -t "WEB.1" "w3m -o ssl_verify_peer=0 '${url}'" Enter 2>/dev/null
    else
        tmux new-window -n "PROXY" "w3m -o ssl_verify_peer=0 '${url}'"
    fi
}

# ── GUI browser picker ─────────────────────────────────────────────────
_gui_browsers() {
    printf "  ${BOLD}${WHT}GUI BROWSERS${R}\n"
    for b in \
        "M|Mullvad|net.mullvad.MullvadBrowser|flatpak" \
        "T|Tor Browser|org.torproject.torbrowser-launcher|flatpak" \
        "Z|Zen|app.zen_browser.zen|flatpak" \
        "B|Brave|com.brave.Browser|flatpak" \
        "U|Ungoogled|io.github.ungoogled_software.ungoogled_chromium|flatpak" \
        "F|Falkon|org.kde.falkon|flatpak" \
        "q|Qutebrowser|qutebrowser|native" \
        "f|Firefox|firefox|native"
    do
        key="${b%%|*}"; rest="${b#*|}"; name="${rest%%|*}"; rest="${rest#*|}"
        id="${rest%%|*}"; type="${rest##*|}"
        # Check available
        if [ "$type" = "flatpak" ]; then
            flatpak info "$id" >/dev/null 2>&1 && dot="${GRN}●${R}" || dot="${GRY}○${R}"
        else
            which "$id" >/dev/null 2>&1 && dot="${GRN}●${R}" || dot="${GRY}○${R}"
        fi
        printf "  ${CYN}[%s]${R} %s %s\n" "$key" "$dot" "$name"
    done
}

_launch_gui() {
    key="$1" url="${2:-}"
    case "$key" in
        M) flatpak run net.mullvad.MullvadBrowser $url >/dev/null 2>&1 & ;;
        T) flatpak run org.torproject.torbrowser-launcher $url >/dev/null 2>&1 & ;;
        Z) flatpak run app.zen_browser.zen $url >/dev/null 2>&1 & ;;
        B) flatpak run com.brave.Browser $url >/dev/null 2>&1 & ;;
        U) flatpak run io.github.ungoogled_software.ungoogled_chromium $url >/dev/null 2>&1 & ;;
        F) flatpak run org.kde.falkon $url >/dev/null 2>&1 & ;;
        q) qutebrowser $url >/dev/null 2>&1 & ;;
        f) firefox $url >/dev/null 2>&1 & ;;
    esac
}

# ── Quick search ───────────────────────────────────────────────────────
_search() {
    printf "  ${CYN}Search${R} > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r query
    stty "$old" 2>/dev/null
    [ -z "$query" ] && return

    # Encode query
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query" 2>/dev/null || echo "$query")

    clear
    printf "\n  ${CYN}${BOLD}SEARCH: %s${R}\n\n" "$query"
    printf "  ${GRY}Where?${R}\n"
    printf "  ${CYN}[w]${R} w3m (DDG Lite)      ${CYN}[l]${R} lynx\n"
    printf "  ${CYN}[e]${R} elinks               ${CYN}[g]${R} Gemini search (amfora)\n"
    if _in_gui; then
        printf "  ${CYN}[M]${R} Mullvad Browser     ${CYN}[T]${R} Tor Browser\n"
        printf "  ${CYN}[B]${R} Brave               ${CYN}[Z]${R} Zen\n"
    fi
    printf "  ${CYN}[q]${R} cancel\n\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dest=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    ddg="https://lite.duckduckgo.com/lite/?q=${encoded}"
    _tor_up
    [ "$TOR_RUNNING" -eq 1 ] && proxy="-e set http_proxy=socks5h://127.0.0.1:9050" || proxy=""

    case "$dest" in
        w) tmux select-pane -t "WEB.1" 2>/dev/null; \
           tmux send-keys -t "WEB.1" "w3m '$ddg'" Enter 2>/dev/null ;;
        l) tmux new-window -n "LYNX" "lynx '$ddg'" ;;
        e) tmux new-window -n "ELINKS" "elinks '$ddg'" ;;
        g) tmux select-pane -t "WEB.2" 2>/dev/null; \
           tmux send-keys -t "WEB.2" ":go gemini://geminispace.info/search?${encoded}" Enter 2>/dev/null ;;
        M|T|Z|B|U|F|q_|f) _in_gui && _launch_gui "$dest" "$ddg" ;;
        q|Q) return ;;
    esac
    # Save to clip log
    printf "%s  SEARCH: %s\n" "$(date '+%H:%M')" "$query" >> "$CLIP_LOG"
}

# ── Open URL in chosen browser ─────────────────────────────────────────
_open_url() {
    printf "  ${CYN}URL${R} > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r url
    stty "$old" 2>/dev/null
    [ -z "$url" ] && return

    clear
    printf "\n  ${CYN}${BOLD}OPEN: %s${R}\n\n" "$url"
    printf "  ${CYN}[w]${R} w3m   ${CYN}[l]${R} lynx   ${CYN}[e]${R} elinks\n"
    printf "  ${CYN}[a]${R} amfora (Gemini)   ${CYN}[s]${R} sacc (Gopher)\n"
    if _in_gui; then
        printf "  ${CYN}[M]${R} Mullvad  ${CYN}[T]${R} Tor Browser  ${CYN}[B]${R} Brave  ${CYN}[Z]${R} Zen\n"
    fi
    printf "  ${CYN}[k]${R} clip it   ${CYN}[b]${R} bookmark   ${CYN}[q]${R} cancel\n\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dest=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    case "$dest" in
        w) tmux select-pane -t "WEB.1" 2>/dev/null
           tmux send-keys -t "WEB.1" "w3m '$url'" Enter 2>/dev/null ;;
        l) tmux new-window -n "LYNX" "lynx '$url'" ;;
        e) tmux new-window -n "ELINKS" "elinks '$url'" ;;
        a) tmux select-pane -t "WEB.2" 2>/dev/null
           tmux send-keys -t "WEB.2" ":go $url" Enter 2>/dev/null ;;
        s) tmux select-pane -t "WEB.3" 2>/dev/null
           tmux send-keys -t "WEB.3" "o $url" Enter 2>/dev/null ;;
        M|T|Z|B|U|F|q_|f) _in_gui && _launch_gui "$dest" "$url" ;;
        k) _clip_url "$url" ;;
        b) _bookmark_add "$url" ;;
        q|Q) return ;;
    esac
}

# ── Clipper ────────────────────────────────────────────────────────────
_clip_url() {
    url="${1:-}"
    if [ -z "$url" ]; then
        printf "  ${CYN}Clip URL${R} > "
        old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
        IFS= read -r url
        stty "$old" 2>/dev/null
    fi
    [ -z "$url" ] && return
    printf "  Label (optional) > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r label
    stty "$old" 2>/dev/null
    entry="${url}"
    [ -n "$label" ] && entry="${url}  # ${label}"
    printf "%s  %s\n" "$(date '+%Y-%m-%d %H:%M')" "$entry" >> "$CLIP_LOG"
    printf "  ${GRN}✓${R} Clipped\n"; sleep 1
}

_clip_view() {
    clear
    printf "\n  ${ORG}${BOLD}◈ CLIPS${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n\n"
    if [ ! -s "$CLIP_LOG" ]; then
        printf "  ${GRY}No clips yet — use [k] to clip a URL${R}\n"
    else
        tail -30 "$CLIP_LOG" | while IFS= read -r line; do
            printf "  ${GRY}%s${R}\n" "$line"
        done
    fi
    printf "\n  ${GRY}[o] open a clip  [c] clear all  [any] back${R}\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    case "$key" in
        o|O)
            url=$(grep -o 'https\?://[^ #]*\|gemini://[^ #]*\|gopher://[^ #]*' "$CLIP_LOG" | \
                fzf --prompt="Open > " 2>/dev/null)
            [ -n "$url" ] && _open_url_direct "$url" ;;
        c|C)
            printf "  ${RED}Clear all clips? [y/N]${R} "
            old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
            ans=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
            stty "$old" 2>/dev/null
            [ "$ans" = "y" ] || [ "$ans" = "Y" ] && > "$CLIP_LOG" && printf "\n  ${GRN}Cleared${R}\n" && sleep 1 ;;
    esac
}

_open_url_direct() {
    url="$1"
    case "$url" in
        gemini://*) tmux select-pane -t "WEB.2" 2>/dev/null
                    tmux send-keys -t "WEB.2" ":go $url" Enter 2>/dev/null ;;
        gopher://*)  tmux select-pane -t "WEB.3" 2>/dev/null
                    tmux send-keys -t "WEB.3" "o $url" Enter 2>/dev/null ;;
        *)          tmux select-pane -t "WEB.1" 2>/dev/null
                    tmux send-keys -t "WEB.1" "w3m '$url'" Enter 2>/dev/null ;;
    esac
}

# ── Bookmarks ──────────────────────────────────────────────────────────
_bookmark_add() {
    url="${1:-}"
    if [ -z "$url" ]; then
        printf "  ${CYN}Bookmark URL${R} > "
        old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
        IFS= read -r url; stty "$old" 2>/dev/null
    fi
    [ -z "$url" ] && return
    printf "  Label > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r label; stty "$old" 2>/dev/null
    [ -z "$label" ] && label="$url"
    printf "%s  %s\n" "$url" "$label" >> "$BOOKMARKS"
    printf "  ${GRN}✓${R} Bookmarked: %s\n" "$label"; sleep 1
}

_bookmarks_view() {
    url=$(grep -v '^$' "$BOOKMARKS" 2>/dev/null | \
        awk '{print $2"  "$1}' | \
        fzf --prompt="Bookmark > " --height=50% 2>/dev/null | \
        awk '{print $NF}')
    [ -n "$url" ] && _open_url_direct "$url"
}

# ── Darknet dashboard (Go web interface port 8800) ─────────────────────
_darknet_dash() {
    DARKNET="$HOME/claude/nexus-darknet-go"
    BINARY="$DARKNET/nexus-darknet"
    PID_FILE="/tmp/nexus-darknet-serve.pid"

    # Build if needed
    if [ ! -x "$BINARY" ]; then
        printf "  ${YLW}Building nexus-darknet...${R}\n"
        (cd "$DARKNET" && go build -o nexus-darknet . 2>/dev/null)
    fi

    # Start serve if not running
    if [ ! -f "$PID_FILE" ] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        nohup "$BINARY" serve --port 8800 >/tmp/nexus-darknet-serve.log 2>&1 &
        echo $! > "$PID_FILE"
        sleep 1
        printf "  ${GRN}● Darknet dashboard started${R}\n"
    fi

    # Open in w3m
    if [ -n "$TMUX" ]; then
        tmux select-pane -t "WEB.1" 2>/dev/null && \
            tmux send-keys -t "WEB.1" "w3m http://localhost:8800/" Enter 2>/dev/null
    fi
}

# ── Tor proxy status ───────────────────────────────────────────────────
_proxy_status() {
    _tor_up
    if [ "$TOR_RUNNING" -eq 1 ]; then
        printf "${GRN}●${R} Tor"
    else
        printf "${GRY}○${R} Tor down"
    fi
}

# ── Main draw ──────────────────────────────────────────────────────────
_draw() {
    clear
    printf "\n  ${CYN}${BOLD}◈  WEB${R}  $(_proxy_status)"
    printf "  ${GRY}w3m · amfora · sacc${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n\n"

    printf "  ${CYN}[/]${R}  Search           ${CYN}[u]${R}  Open URL\n"
    printf "  ${CYN}[k]${R}  Clip a URL        ${CYN}[K]${R}  View clips\n"
    printf "  ${CYN}[b]${R}  Add bookmark      ${CYN}[B]${R}  Browse bookmarks\n"
    printf "\n  ${MAG}${BOLD}NEXUS PROXY${R}  $(_proxy_dot)  ${GRY}localhost:8443${R}\n"
    printf "  ${MAG}[H]${R}  AI Home           ${MAG}[P]${R}  Manager/Dashboard\n"
    printf "  ${MAG}[O]${R}  OpenCharacters    ${MAG}[C]${R}  Char Card Reader\n"
    printf "  ${CYN}[S]${R}  NXS Search        ${GRY}(localhost:5000)${R}\n"
    printf "  ${MAG}[D]${R}  Darknet Dashboard ${GRY}(localhost:8800)${R}\n"
    if _in_gui; then
        printf "\n"
        printf "  ${MAG}${BOLD}GUI BROWSERS${R}\n"
        printf "  ${CYN}[M]${R} Mullvad  ${CYN}[T]${R} Tor  ${CYN}[Z]${R} Zen  ${CYN}[v]${R} Brave\n"
        printf "  ${CYN}[U]${R} Ungoogled  ${CYN}[F]${R} Falkon  ${CYN}[q]${R} Qutebrowser\n"
    fi
    printf "\n"
    printf "  ${GRY}PANES${R}\n"
    printf "  ${GRY}↓ w3m (text)  →↑ amfora (Gemini)  →↓ sacc (Gopher)${R}\n"
    printf "\n  ${GRY}[Q] quit window${R}\n\n"

    # Recent clips preview
    if [ -s "$CLIP_LOG" ]; then
        printf "  ${GRY}Recent clips:${R}\n"
        tail -3 "$CLIP_LOG" | while IFS= read -r line; do
            printf "  ${GRY}· %.58s${R}\n" "$line"
        done
    fi
}

# ── Main loop ──────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    _draw

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        /)   _search ;;
        u|U) _open_url ;;
        k)   _clip_url ;;
        K)   _clip_view ;;
        b)   _bookmark_add ;;
        B)   _bookmarks_view ;;
        H)   _open_proxy "https://localhost:8443/" ;;
        P)   _open_proxy "https://localhost:8443/manager/" ;;
        O)   _open_proxy "https://localhost:8443/oc/play.html" ;;
        C)   _open_proxy "https://localhost:8443/charcard/" ;;
        S)   tmux select-pane -t "WEB.1" 2>/dev/null
             tmux send-keys -t "WEB.1" "w3m 'http://localhost:5000/'" Enter 2>/dev/null ;;
        D)   _darknet_dash ;;
        # GUI browser direct launches
        M)   _in_gui && { printf "  Opening Mullvad...\n"; _launch_gui M; sleep 1; } ;;
        T)   _in_gui && { printf "  Opening Tor Browser...\n"; _launch_gui T; sleep 1; } ;;
        Z)   _in_gui && { printf "  Opening Zen...\n"; _launch_gui Z; sleep 1; } ;;
        v|V) _in_gui && { printf "  Opening Brave...\n"; _launch_gui B; sleep 1; } ;;
        U)   _in_gui && { printf "  Opening Ungoogled Chromium...\n"; _launch_gui U; sleep 1; } ;;
        F)   _in_gui && { printf "  Opening Falkon...\n"; _launch_gui F; sleep 1; } ;;
        q)   _in_gui && { printf "  Opening Qutebrowser...\n"; _launch_gui q; sleep 1; } ;;
        Q)   exit 0 ;;
    esac
done
