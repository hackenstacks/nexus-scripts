#!/bin/sh
# nexus-home-popup.sh — Quick links popup for HOME window
# Called via: tmux display-popup -E -w 60 -h 24 'nexus-home-popup.sh'
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'

# Source matugen theme if available
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

SCRIPTS="$HOME/scripts"
DARKNET="$HOME/claude/nexus-darknet-go"
ORCH="$HOME/claude/nexus-orchestrator"

# Quick link definitions: "KEY|LABEL|DESCRIPTION|COMMAND"
LINKS="
d|DARKNET TUI|Full darknet control panel|cd $DARKNET && ./nexus-darknet tui
a|AI HUB|Chat · think · forge · vault|$SCRIPTS/nexus-ai.sh
M|MEDIA|Feeds · newsboat · IRC · ticker|$SCRIPTS/nexus-media.sh
W|WEB|w3m · amfora · sacc · GUI browsers|$SCRIPTS/nexus-web.sh
A|AUDIO/VIDEO|mpv · yt-dlp · ncmpcpp · VLC|$SCRIPTS/nexus-media-av.sh
e|RETROSHARE|P2P mesh · friend certs · chat|$SCRIPTS/nexus-retroshare.sh
g|GHOST GATE|Issue permits & view audit log|cd $ORCH && python nexus.py
o|ORCHESTRATOR|NeXuS command center|cd $ORCH && python nexus.py
l|AUDIT LOG|Live ghost gate event stream|tail -f $HOME/.nexus/audit.log
m|MONITOR|System resource monitor|htop
w|WIKI|Local docs (mkdocs serve)|cd $HOME/Documents/nexus-docs && mkdocs serve
t|TOR LOG|Live Tor bootstrap & circuits|tail -f $HOME/.local/share/tor/tor.log
i|I2P LOG|I2P tunnel status|tail -f $HOME/.nexus-security/i2p2/i2pd.log
r|RSS FEEDS|Quick feed pane|$SCRIPTS/nexus-media-feeds.sh
P|PUBLISH|Write · publish to wiki/IPFS/net|$SCRIPTS/nexus-media-write.sh
f|FORGE|Digital goods · sell via darknet|$SCRIPTS/nexus-forge.sh
R|RETROSHARE|P2P mesh · friend certificates|$SCRIPTS/nexus-retroshare.sh hub
D|DARKNET PUB|Host .onion/.i2p sites|$SCRIPTS/nexus-darknet-publish.sh
n|NOTES|NeXuS notes (micro + glow)|ls $HOME/notes/nexus/ | fzf | xargs -I{} micro $HOME/notes/nexus/{}
"

_header() {
    printf "\n"
    printf "  ${CYN}${BOLD}QUICK LAUNCH${R}\n"
    printf "  ${GRY}──────────────────────────────────────────────${R}\n\n"
}

_draw_links() {
    echo "$LINKS" | grep -v '^\s*$' | while IFS='|' read -r key label desc cmd; do
        [ -z "$key" ] && continue
        printf "  ${CYN}${BOLD}[%s]${R}  ${WHT}%-16s${R}  ${GRY}%s${R}\n" "$key" "$label" "$desc"
    done
}

_footer() {
    printf "\n  ${GRY}──────────────────────────────────────────────${R}\n"
    printf "  ${GRY}Press key to launch in new window • [q] close${R}\n\n"
}

_launch() {
    key="$1"
    cmd=$(echo "$LINKS" | grep -v '^\s*$' | awk -F'|' -v k="$key" 'tolower($1)==tolower(k){print $5}' | head -1)
    label=$(echo "$LINKS" | grep -v '^\s*$' | awk -F'|' -v k="$key" 'tolower($1)==tolower(k){print $2}' | head -1)
    [ -z "$cmd" ] && return 1
    tmux new-window -n "$label" "sh -c '$cmd; echo; echo Done — press Enter; read x'"
    return 0
}

# Draw
clear
_header
_draw_links
_footer

# Input loop
old_stty=$(stty -g 2>/dev/null)
stty -echo -icanon min 1 time 0 2>/dev/null
trap 'stty "$old_stty" 2>/dev/null' EXIT INT TERM

while true; do
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    [ -z "$key" ] && continue
    case "$key" in
        q|Q) break ;;
        *)
            if _launch "$key"; then
                break
            fi
            ;;
    esac
done

stty "$old_stty" 2>/dev/null
