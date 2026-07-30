#!/bin/sh
# nexus-home-popup.sh — Quick links popup, 3 pages
# []] or Tab → next page   [[] → prev page   [q] close
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'

[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

SCRIPTS="$HOME/scripts"
DARKNET="$HOME/Projects/nexus-network-stack/network/configs/darknet-stack"
ORCH="$HOME/claude/nexus-orchestrator"

# ── Page 1: AI · Proxy · Web ─────────────────────────────────────────
LINKS1="
a|AI HUB|Chat · think · forge · vault|$SCRIPTS/nexus-ai.sh
H|AI HOME|Web char system · HTTPS :8443|w3m -o ssl_verify_peer=0 https://localhost:8443/
p|PROXY|API Proxy status · start/stop|$SCRIPTS/nexus-api-proxy.sh status
k|DASHBOARD|Proxy manager dashboard|w3m -o ssl_verify_peer=0 https://localhost:8443/manager/
C|CHAR CARD|PNG² char card reader|w3m -o ssl_verify_peer=0 https://localhost:8443/charcard/
O|OPEN CHARS|OpenCharacters web chat|w3m -o ssl_verify_peer=0 https://localhost:8443/oc/play.html
x|AI PARTY|Character party via aichat|$HOME/claude/nexus-party/nexus-party.sh
V|VM FORGE|QEMU/KVM VM maker TUI|$HOME/git/nexus-vm-forge/nexus-vm-forge.sh
S|NXS SEARCH|Canonical file search :5000|w3m http://localhost:5000/
M|MEDIA|Feeds · newsboat · IRC · ticker|$SCRIPTS/nexus-media.sh
W|WEB|w3m · amfora · sacc · GUI browsers|$SCRIPTS/nexus-web.sh
A|AUDIO|mpv · yt-dlp · ncmpcpp · VLC|$SCRIPTS/nexus-media-av.sh
"

# ── Page 2: Darknet · Security · Tools ───────────────────────────────
LINKS2="
d|DARKNET TUI|Full darknet control panel|cd $DARKNET && ./nexus-darknet menu
j|DARKNET PANEL|Web control panel :8878|cd $DARKNET && python3 scripts/nexus-control-panel.py & sleep 1; w3m http://localhost:8878/
N|NET DOCTOR|Darknet diagnostics|cd $DARKNET && ./nexus-darknet doctor
D|DARKNET PUB|Host .onion/.i2p sites|$SCRIPTS/nexus-darknet-publish.sh
g|GHOST GATE|Issue permits & view audit log|cd $ORCH && python nexus.py
e|RETROSHARE|P2P mesh · friend certs · chat|$SCRIPTS/nexus-retroshare.sh
f|FORGE|Digital goods · sell via darknet|$SCRIPTS/nexus-forge.sh
l|AUDIT LOG|Live ghost gate event stream|tail -f $HOME/.nexus/audit.log
m|MONITOR|System resource monitor|htop
w|WIKI|Local docs (mkdocs serve)|cd $HOME/Documents/nexus-docs && mkdocs serve
n|NOTES|NeXuS notes (micro + glow)|ls $HOME/notes/nexus/ | fzf | xargs -I{} micro $HOME/notes/nexus/{}
r|RSS FEEDS|Quick feed pane|$SCRIPTS/nexus-media-feeds.sh
P|PUBLISH|Write · publish to darknet|$SCRIPTS/nexus-media-write.sh
t|TOR LOG|Live Tor bootstrap & circuits|tail -f $HOME/.local/share/tor/tor.log
i|I2P LOG|I2P tunnel status|tail -f $HOME/.nexus-security/i2p2/i2pd.log
"

# ── Page 3: tmux cheatsheet (read-only reference) ────────────────────
_draw_cheatsheet() {
    clear
    printf "\n  ${CYN}${BOLD}QUICK LAUNCH${R}  ${GRY}3/3  tmux reference${R}\n"
    printf "  ${GRY}────────────────────────────────────────────${R}\n\n"
    printf "  ${GRY}PREFIX = Ctrl+Space${R}\n\n"
    printf "  ${MAG}${BOLD}SESSIONS${R}\n"
    printf "  ${CYN}\$${R}  Rename   ${CYN}s${R}  List/switch   ${CYN}d${R}  Detach\n\n"
    printf "  ${MAG}${BOLD}WINDOWS${R}\n"
    printf "  ${CYN}c${R}  New   ${CYN},${R}  Rename   ${CYN}n/p${R}  Next/prev\n"
    printf "  ${CYN}0-9${R}  Jump   ${CYN}w${R}  Picker   ${CYN}&${R}  Kill\n\n"
    printf "  ${MAG}${BOLD}PANES${R}\n"
    printf "  ${CYN}|${R}  Split-v   ${CYN}-${R}  Split-h   ${CYN}z${R}  Zoom toggle\n"
    printf "  ${CYN}hjkl${R}  Navigate   ${CYN}x${R}  Kill   ${CYN}{}${R}  Swap\n\n"
    printf "  ${MAG}${BOLD}COPY MODE${R}\n"
    printf "  ${CYN}[${R}  Enter   ${CYN}v${R}  Select   ${CYN}y${R}  Yank   ${CYN}]${R}  Paste\n"
    printf "  ${CYN}/${R}  Search fwd   ${CYN}?${R}  Search back\n\n"
    printf "  ${MAG}${BOLD}PLUGINS${R}\n"
    printf "  ${CYN}F1${R}  Cheatsheet   ${CYN}F9${R}  Menus   ${CYN}u${R}  URL picker\n"
    printf "  ${CYN}Ctrl+s${R}  Save session   ${CYN}Ctrl+r${R}  Restore\n\n"
    printf "  ${GRY}────────────────────────────────────────────${R}\n"
    printf "  ${GRY}◀ [[] prev page  [q] close${R}\n\n"
}

# ── Shared draw for pages 1 & 2 ──────────────────────────────────────
_draw() {
    links="$1"; title="$2"; nav="$3"
    clear
    printf "\n  ${CYN}${BOLD}QUICK LAUNCH${R}  ${GRY}%s${R}\n" "$title"
    printf "  ${GRY}────────────────────────────────────────────${R}\n\n"
    echo "$links" | grep -v '^\s*$' | while IFS='|' read -r key label desc cmd; do
        [ -z "$key" ] && continue
        printf "  ${CYN}${BOLD}[%s]${R}  ${WHT}%-14s${R}  ${GRY}%s${R}\n" "$key" "$label" "$desc"
    done
    printf "\n  ${GRY}────────────────────────────────────────────${R}\n"
    printf "  ${GRY}%s${R}\n\n" "$nav"
}

_launch() {
    key="$1"
    cmd=$(printf '%s\n%s' "$LINKS1" "$LINKS2" \
        | grep -v '^\s*$' | awk -F'|' -v k="$key" '$1==k{print $5}' | head -1)
    label=$(printf '%s\n%s' "$LINKS1" "$LINKS2" \
        | grep -v '^\s*$' | awk -F'|' -v k="$key" '$1==k{print $2}' | head -1)
    [ -z "$cmd" ] && return 1
    tmux new-window -n "$label" "sh -c '$cmd; echo; echo \"Done — press Enter\"; read x'"
    return 0
}

page=1
old_stty=$(stty -g 2>/dev/null)
stty -echo -icanon min 1 time 0 2>/dev/null
trap 'stty "$old_stty" 2>/dev/null' EXIT INT TERM

while true; do
    case "$page" in
        1) _draw "$LINKS1" "1/3  AI · Proxy · Web"    "[]] Tab → next  [q] close" ;;
        2) _draw "$LINKS2" "2/3  Darknet · Tools"     "◀ [[]  []] Tab → next  [q] close" ;;
        3) _draw_cheatsheet ;;
    esac

    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    [ -z "$key" ] && continue
    case "$key" in
        ']'|'	')  # ] or Tab — next page (wraps 3→1)
            page=$(( page % 3 + 1 )) ;;
        '[')        # [ — prev page (wraps 1→3)
            page=$(( (page + 1) % 3 + 1 )) ;;
        q|Q) break ;;
        *) _launch "$key" && break ;;
    esac
done

stty "$old_stty" 2>/dev/null
