#!/bin/sh
# nexus-media-feeds.sh — dedicated feed pane
# Shows GitHub commits + security headlines, auto-refreshes
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; MAG='\033[38;5;177m'
ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" YLW="$C_TERTIARY"

REFRESH=300  # 5 min
FEED_CACHE="$HOME/.nexus/feeds"
mkdir -p "$FEED_CACHE"

_curl() {
    if ss -tln 2>/dev/null | grep -q ':9050'; then
        curl --socks5-hostname 127.0.0.1:9050 --silent --max-time 20 "$@"
    else
        curl --silent --max-time 20 "$@"
    fi
}

_fetch_feed() {
    name="$1" url="$2" count="${3:-5}"
    cache="$FEED_CACHE/$(echo "$name" | tr ' /' '__').xml"
    age=0
    [ -f "$cache" ] && age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
    [ $age -lt $REFRESH ] || _curl -L "$url" -o "$cache" 2>/dev/null

    [ -f "$cache" ] || return

    # Extract titles (RSS + Atom)
    grep -oP '(?<=<title>)[^<]+' "$cache" 2>/dev/null | \
        grep -v '^\s*$' | \
        sed "s/^$(echo "$name" | sed 's/[^^]/[&]/g;s/\^/\\^/g')$//" | \
        grep -v '^\s*$' | \
        sed 's/&amp;/\&/g;s/&lt;/</g;s/&gt;/>/g;s/&#[0-9]*;//g' | \
        head -"$count"
}

_section() {
    icon="$1" color="$2" name="$3"
    printf "\n  ${color}${BOLD}${icon} %s${R}\n" "$name"
}

draw() {
    clear
    ts=$(date '+%H:%M')
    printf "  ${CYN}${BOLD}FEEDS${R}  ${GRY}${ts}  (refreshes every 5 min)${R}\n"
    printf "  ${GRY}──────────────────────────────────────${R}\n"

    _section "⎇" "$CYN" "NeXuS GitHub"
    _fetch_feed "nexus-github" "https://github.com/hackenstacks/nexus/commits/main.atom" 5 | \
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            printf "  ${GRY}·${R} ${WHT}%.42s${R}\n" "$item"
        done

    _section "🔒" "$YLW" "Security"
    _fetch_feed "eff" "https://www.eff.org/rss/updates.xml" 4 | \
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            printf "  ${GRY}·${R} %.42s\n" "$item"
        done

    _section "🧅" "$MAG" "Tor Project"
    _fetch_feed "tor" "https://blog.torproject.org/rss.xml" 3 | \
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            printf "  ${GRY}·${R} %.42s\n" "$item"
        done

    _section "🔐" "$GRN" "Schneier"
    _fetch_feed "schneier" "https://www.schneier.com/feed/atom/" 3 | \
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            printf "  ${GRY}·${R} %.42s\n" "$item"
        done

    _section "⚡" "$ORG" "HN Security"
    _fetch_feed "hn-sec" "https://hnrss.org/newest?q=privacy+security&points=50" 4 | \
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            printf "  ${GRY}·${R} %.42s\n" "$item"
        done

    printf "\n  ${GRY}[r] refresh now  [n] open in newsboat  [q] quit${R}\n"
}

old_stty=$(stty -g 2>/dev/null)
stty -echo -icanon min 0 time 0 2>/dev/null
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    draw
    i=0
    while [ $i -lt $(( REFRESH / 1 )) ]; do
        key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
        if [ -n "$key" ]; then
            case "$key" in
                r|R) rm -f "$FEED_CACHE"/*.xml; break ;;
                n|N) tmux new-window -n "NEWSBOAT" "newsboat" ;;
                q|Q) exit 0 ;;
            esac
        fi
        sleep 1
        i=$((i+1))
    done
done
