#!/bin/sh
# nexus-home-rss.sh — RSS feed pane for HOME window
# Fetches feeds via curl, parses with basic XML grep (no extra tools)
# Refreshes every 10 minutes
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m';  GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
ORG='\033[38;5;214m'

REFRESH=600   # 10 minutes
CACHE_DIR="$HOME/.nexus/rss"
mkdir -p "$CACHE_DIR"

# Feed list — privacy/security focused, Tor-proxied if available
# Format: "title|url"
FEEDS="
NeXuS Repo|https://github.com/hackenstacks/nexus/commits/main.atom
Tor Project|https://blog.torproject.org/rss.xml
EFF|https://www.eff.org/rss/updates.xml
Schneier|https://www.schneier.com/feed/atom/
HN Security|https://hnrss.org/newest?q=privacy+security&points=50
"

# Use Tor SOCKS proxy if running
_curl_opts() {
    if ss -tln 2>/dev/null | grep -q ':9050'; then
        echo "--socks5-hostname 127.0.0.1:9050 --silent --max-time 15"
    else
        echo "--silent --max-time 15"
    fi
}

_fetch_feed() {
    name="$1"
    url="$2"
    cache="$CACHE_DIR/$(echo "$name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]').xml"

    opts=$(_curl_opts)
    # Only fetch if cache is older than REFRESH seconds
    if [ ! -f "$cache" ] || [ $(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) )) -gt $REFRESH ]; then
        curl $opts -L "$url" -o "$cache" 2>/dev/null
    fi

    [ -f "$cache" ] || return

    # Extract titles — works for both RSS and Atom
    grep -oP '(?<=<title>)[^<]+' "$cache" 2>/dev/null | \
    grep -v '^\s*$' | \
    grep -v "^${name}$" | \
    head -5
}

draw() {
    clear
    printf "${CYN}${BOLD}  FEEDS${R}\n"
    printf "${GRY}  ──────────────────────────${R}\n\n"

    echo "$FEEDS" | grep -v '^\s*$' | while IFS='|' read -r name url; do
        [ -z "$name" ] && continue
        printf "  ${YLW}${BOLD}%s${R}\n" "$name"

        items=$(_fetch_feed "$name" "$url")
        if [ -z "$items" ]; then
            printf "  ${GRY}  (no data — check network)${R}\n"
        else
            echo "$items" | while IFS= read -r item; do
                # Truncate to pane width
                short=$(echo "$item" | head -c 26 | sed 's/&amp;/\&/g;s/&lt;/</g;s/&gt;/>/g')
                printf "  ${GRY}· ${WHT}%s${R}\n" "$short"
            done
        fi
        printf "\n"
    done

    ts=$(date '+%H:%M')
    printf "${GRY}  Updated: ${ts}${R}\n"
    printf "${DIM}  Tor-proxied when available${R}\n"
}

while true; do
    draw
    sleep $REFRESH
done
