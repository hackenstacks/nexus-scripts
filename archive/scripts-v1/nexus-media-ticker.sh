#!/bin/sh
# nexus-media-ticker.sh — scrolling ticker pane
# Shows: crypto prices + latest headline + GitHub activity
# Writes shared data to ~/.nexus/ticker.cache for HOME screen
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" YLW="$C_TERTIARY"

CACHE="$HOME/.nexus/ticker.cache"
REFRESH=120  # 2 min price refresh
mkdir -p "$HOME/.nexus"

# Tor proxy if available
_curl() {
    if ss -tln 2>/dev/null | grep -q ':9050'; then
        curl --socks5-hostname 127.0.0.1:9050 --silent --max-time 15 "$@"
    else
        curl --silent --max-time 15 "$@"
    fi
}

_get_price() {
    # CoinGecko free API — no key needed
    coin="$1" symbol="$2"
    price=$(_curl "https://api.coingecko.com/api/v3/simple/price?ids=${coin}&vs_currencies=usd" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('${coin}',{}).get('usd','?'))" 2>/dev/null)
    echo "${symbol}:\$${price:-?}"
}

_get_headline() {
    # Pull latest EFF or Tor blog headline
    _curl "https://www.eff.org/rss/updates.xml" 2>/dev/null | \
        grep -o '<title>[^<]*</title>' | sed 's/<[^>]*>//g' | \
        grep -v 'Electronic Frontier' | head -1 | \
        sed 's/&amp;/\&/g;s/&lt;/</g;s/&gt;/>/g' | \
        head -c 60
}

_get_github() {
    _curl "https://github.com/hackenstacks/nexus/commits/main.atom" 2>/dev/null | \
        grep -o '<title>[^<]*</title>' | sed 's/<[^>]*>//g' | \
        grep -v 'Recent Commits\|Commits to' | head -1 | \
        head -c 50
}

_fetch_all() {
    xmr=$(_get_price "monero" "XMR")
    btc=$(_get_price "bitcoin" "BTC")
    eth=$(_get_price "ethereum" "ETH")
    headline=$(_get_headline)
    github=$(_get_github)
    ts=$(date '+%H:%M')
    echo "${ts}|${xmr}|${btc}|${eth}|${headline}|${github}" > "$CACHE"
    echo "$xmr $btc $eth"
}

_read_cache() {
    [ -f "$CACHE" ] || return
    IFS='|' read -r ts xmr btc eth headline github < "$CACHE"
    printf "${GRY}%s${R}  " "$ts"
    printf "${YLW}${BOLD}%s${R}  " "$xmr"
    printf "${ORG}${BOLD}%s${R}  " "$btc"
    printf "${BLU}${BOLD}%s${R}" "$eth" 2>/dev/null || printf "${MAG}${BOLD}%s${R}" "$eth"
    [ -n "$headline" ] && printf "  ${GRY}│${R}  ${WHT}%s${R}" "$headline"
    [ -n "$github" ]   && printf "  ${GRY}│${R}  ${CYN}⎇ %s${R}" "$github"
}

# ── Scrolling ticker draw ──────────────────────────────────────────
draw_ticker() {
    tput cup 0 0 2>/dev/null || printf "\r"
    cols=$(tput cols 2>/dev/null || echo 80)

    # Build ticker string
    line=$( (
        printf " ◈ "
        _read_cache
        printf "  "
    ) )

    # Pad or truncate to terminal width
    printf "${line}"
    printf "%*s" $(( cols - ${#line} % cols )) ""
}

# ── Scroll animation ──────────────────────────────────────────────
last_fetch=0
offset=0

while true; do
    now=$(date +%s)
    # Refresh prices every REFRESH seconds
    if [ $(( now - last_fetch )) -ge $REFRESH ]; then
        _fetch_all >/dev/null 2>&1 &
        last_fetch=$now
    fi

    # If no cache yet, show loading
    if [ ! -f "$CACHE" ]; then
        printf "\r  ${GRY}Fetching prices...${R}%*s" 40 ""
        sleep 2
        continue
    fi

    draw_ticker
    sleep 10
done
