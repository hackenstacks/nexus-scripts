#!/bin/sh
# nexus-darknet-publish.sh — Darknet Publishing Manager
# Spins up Tor hidden service + I2P eepsite for any local content
# Ghost Gate permit auto-requested for egress
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

TORRC="/etc/tor/torrc"
TOR_HS_BASE="/var/lib/tor/nexus-sites"
I2P_TUNNELS="/etc/i2pd/tunnels.conf"
SERVE_BASE="$HOME/.nexus/darknet-sites"
SITES_DB="$HOME/.nexus/darknet-sites.cfg"
mkdir -p "$SERVE_BASE"
touch "$SITES_DB" 2>/dev/null

# ── Helpers ────────────────────────────────────────────────────────────────
_header() {
    clear
    printf "\n  ${MAG}${BOLD}🧅  DARKNET PUBLISH${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n"
    printf "  ${DIM}Tor Hidden Services  ·  I2P Eepsites${R}\n\n"
}

_get_onion() {
    name="$1"
    hs_dir="$TOR_HS_BASE/$name"
    f="${hs_dir}/hostname"
    if [ -r "$f" ]; then
        cat "$f"
    elif doas test -r "$f" 2>/dev/null; then
        doas cat "$f" 2>/dev/null
    else
        echo "pending"
    fi
}

_list_sites() {
    printf "  ${BOLD}${WHT}ACTIVE SITES${R}\n"
    found=0
    while IFS='|' read -r name port src desc; do
        [ -z "$name" ] && continue
        onion=$(_get_onion "$name")
        printf "  ${CYN}%-16s${R} " "$name"
        printf "${GRN}:%s${R}  " "$port"
        printf "${GRY}%.34s${R}\n" "$desc"
        printf "  ${GRY}  .onion:${R} ${MAG}%s${R}\n" "$onion"
        found=$((found+1))
    done < "$SITES_DB"
    [ "$found" -eq 0 ] && printf "  ${GRY}No sites yet — press [n] to create one${R}\n"
    printf "\n"
}

_tor_running() {
    pgrep -x tor >/dev/null 2>&1 || rc-service tor status 2>/dev/null | grep -q started
}

_i2p_running() {
    pgrep -x i2pd >/dev/null 2>&1 || rc-service i2pd status 2>/dev/null | grep -q started
}

_net_status() {
    printf "  "
    _tor_running && printf "${GRN}● Tor${R}" || printf "${RED}● Tor DOWN${R}"
    printf "  "
    _i2p_running && printf "${GRN}● I2P${R}" || printf "${GRY}● I2P stopped${R}"
    printf "\n\n"
}

# ── Add HiddenService block to torrc ──────────────────────────────────────
_add_tor_hs() {
    name="$1" port="$2"
    hs_dir="$TOR_HS_BASE/$name"
    # Check if already in torrc
    if grep -q "HiddenServiceDir ${hs_dir}" "$TORRC" 2>/dev/null || \
       doas grep -q "HiddenServiceDir ${hs_dir}" "$TORRC" 2>/dev/null; then
        printf "  ${GRY}Tor HS already configured for %s${R}\n" "$name"
        return 0
    fi
    block=$(printf "\n# NeXuS site: %s\nHiddenServiceDir %s\nHiddenServicePort 80 127.0.0.1:%s\n" \
        "$name" "$hs_dir" "$port")
    printf "%s" "$block" | doas tee -a "$TORRC" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        printf "  ${RED}⚠  Cannot write torrc — run as root or add doas permission${R}\n"
        printf "  ${GRY}Manual add to %s:${R}\n" "$TORRC"
        printf "%s\n" "$block"
        return 1
    fi
    # Reload Tor
    doas rc-service tor reload 2>/dev/null || doas pkill -HUP tor 2>/dev/null
    printf "  ${GRN}✓${R} Tor hidden service registered — address generating (~60s)...\n"
}

# ── Add I2P HTTP tunnel ────────────────────────────────────────────────────
_add_i2p_tunnel() {
    name="$1" port="$2"
    if grep -q "^\[${name}\]" "$I2P_TUNNELS" 2>/dev/null || \
       doas grep -q "^\[${name}\]" "$I2P_TUNNELS" 2>/dev/null; then
        printf "  ${GRY}I2P tunnel already configured for %s${R}\n" "$name"
        return 0
    fi
    block=$(printf "\n[%s]\ntype = http\nhost = 127.0.0.1\nport = %s\nkeys = %s.dat\n" \
        "$name" "$port" "$name")
    if echo "$block" | doas tee -a "$I2P_TUNNELS" >/dev/null 2>&1; then
        doas rc-service i2pd reload 2>/dev/null || doas pkill -HUP i2pd 2>/dev/null
        printf "  ${GRN}✓${R} I2P eepsite registered — b32 address generating (~10min)\n"
    else
        printf "  ${YLW}⚠${R}  I2P tunnel requires doas — skipping\n"
    fi
}

# ── Start local HTTP server for a site ────────────────────────────────────
_serve_site() {
    name="$1" port="$2" src_dir="$3"
    # Kill existing server on that port
    fuser -k "${port}/tcp" 2>/dev/null || true
    nohup python3 -m http.server "$port" \
        --bind 127.0.0.1 \
        --directory "$src_dir" \
        >/tmp/nexus-site-${name}.log 2>&1 &
    echo $! > "/tmp/nexus-site-${name}.pid"
    printf "  ${GRN}✓${R} HTTP server on 127.0.0.1:%s serving %s\n" "$port" "$src_dir"
}

# ── Stop a site's server ──────────────────────────────────────────────────
_stop_server() {
    name="$1"
    pidfile="/tmp/nexus-site-${name}.pid"
    if [ -f "$pidfile" ]; then
        kill "$(cat "$pidfile")" 2>/dev/null
        rm -f "$pidfile"
        printf "  ${GRY}Server stopped: %s${R}\n" "$name"
    fi
}

# ── Find next free port from 8500 upward ─────────────────────────────────
_next_port() {
    p=8500
    while grep -q "|${p}|" "$SITES_DB" 2>/dev/null; do
        p=$((p+1))
    done
    echo $p
}

# ── Create new site ────────────────────────────────────────────────────────
_new_site() {
    _header
    printf "  ${CYN}${BOLD}NEW DARKNET SITE${R}\n\n"

    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    printf "  Site name (slug, no spaces) > "; IFS= read -r name
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    [ -z "$name" ] && printf "  ${RED}Cancelled${R}\n" && sleep 1 && return

    printf "  Description                 > "; IFS= read -r desc
    printf "  Source dir (blank=generate) > "; IFS= read -r src
    stty "$old" 2>/dev/null

    port=$(_next_port)
    site_dir="$SERVE_BASE/$name"

    if [ -z "$src" ] || [ ! -d "$src" ]; then
        # Generate a starter site
        mkdir -p "$site_dir"
        src="$site_dir"
        _generate_index "$name" "$desc" "$site_dir"
        printf "  ${GRN}✓${R} Starter site created at %s\n" "$site_dir"
    fi

    # Register
    printf "%s|%s|%s|%s\n" "$name" "$port" "$src" "$desc" >> "$SITES_DB"

    printf "\n  ${YLW}Networks:${R}\n"
    printf "  ${GRY}[t]${R} Tor only   ${GRY}[i]${R} I2P only   ${GRY}[b]${R} Both   ${GRY}[s]${R} Skip\n"
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    net=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null
    printf "\n"

    case "$net" in
        t|T) _add_tor_hs "$name" "$port" ;;
        i|I) _add_i2p_tunnel "$name" "$port" ;;
        b|B) _add_tor_hs "$name" "$port"; _add_i2p_tunnel "$name" "$port" ;;
    esac

    _serve_site "$name" "$port" "$src"
    printf "\n  ${GRN}${BOLD}Site '%s' is live.${R}\n" "$name"
    printf "  ${GRY}Log: /tmp/nexus-site-%s.log${R}\n\n" "$name"
    printf "  Press any key..."; old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null; dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Generate starter index.html from site name ────────────────────────────
_generate_index() {
    name="$1" desc="$2" dir="$3"
    cat > "$dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NeXuS :: ${name}</title>
<style>
  body{background:#0a0a0a;color:#e0e0e0;font-family:monospace;max-width:720px;margin:60px auto;padding:0 20px}
  h1{color:#00e5ff;border-bottom:1px solid #1a1a1a;padding-bottom:12px}
  a{color:#82ff6a}
  .dim{color:#555;font-size:.85em}
  pre{background:#111;padding:16px;border-left:3px solid #00e5ff;overflow-x:auto}
  .tag{background:#1a1a1a;color:#b39ddb;padding:2px 8px;border-radius:3px;font-size:.8em}
</style>
</head>
<body>
<h1>◈ ${name}</h1>
<p class="dim">${desc}</p>
<p>Welcome to this NeXuS node. Content is published via Tor hidden service and I2P eepsite.</p>
<p><span class="tag">NeXuS</span> <span class="tag">darknet</span> <span class="tag">privacy</span></p>
<hr style="border-color:#1a1a1a">
<p class="dim">Powered by NeXuS · Sane · Simple · Secure · Stealthy · Beautiful</p>
</body>
</html>
HTML
}

# ── Manage existing site ───────────────────────────────────────────────────
_manage_site() {
    site=$(grep -v '^$' "$SITES_DB" | \
        awk -F'|' '{printf "%s  port:%s  %s\n", $1, $2, $4}' | \
        fzf --prompt="Site > " 2>/dev/null | awk '{print $1}')
    [ -z "$site" ] && return
    name="$site"
    line=$(grep "^${name}|" "$SITES_DB")
    port=$(echo "$line" | cut -d'|' -f2)
    src=$(echo "$line" | cut -d'|' -f3)
    onion=$(_get_onion "$name")

    _header
    printf "  ${CYN}${BOLD}%s${R}\n" "$name"
    printf "  ${GRY}Port:${R}   %s\n" "$port"
    printf "  ${GRY}Source:${R} %s\n" "$src"
    printf "  ${GRY}.onion:${R} ${MAG}%s${R}\n\n" "$onion"

    srv_pid="/tmp/nexus-site-${name}.pid"
    if [ -f "$srv_pid" ] && kill -0 "$(cat "$srv_pid")" 2>/dev/null; then
        printf "  ${GRN}● Server running${R}\n\n"
    else
        printf "  ${GRY}● Server not running${R}\n\n"
    fi

    printf "  ${CYN}[s]${R} Start server   ${CYN}[S]${R} Stop server\n"
    printf "  ${CYN}[e]${R} Edit index.html ${CYN}[o]${R} Open in browser (via Tor)\n"
    printf "  ${CYN}[d]${R} Delete site     ${CYN}[q]${R} Back\n\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    case "$key" in
        s) _serve_site "$name" "$port" "$src"; sleep 1 ;;
        S) _stop_server "$name"; sleep 1 ;;
        e) micro "$src/index.html" 2>/dev/null || micro "$src" ;;
        o)
            if [ "$onion" != "pending" ]; then
                torify curl -s "http://${onion}/" 2>/dev/null | head -20
            else
                printf "  ${YLW}.onion address still generating${R}\n"; sleep 2
            fi ;;
        d)
            printf "  ${RED}Delete %s? [y/N]${R} " "$name"
            old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
            ans=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
            stty "$old" 2>/dev/null
            if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
                _stop_server "$name"
                sed -i "/^${name}|/d" "$SITES_DB"
                printf "\n  ${GRN}Removed from registry.${R}\n"
                printf "  ${GRY}Note: torrc HiddenServiceDir entry must be removed manually${R}\n"
                sleep 2
            fi ;;
    esac
}

# ── Main loop ──────────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    _header
    _net_status
    _list_sites
    printf "  ${CYN}${BOLD}[n]${R}  New site / publish directory\n"
    printf "  ${CYN}${BOLD}[m]${R}  Manage existing site\n"
    printf "  ${CYN}${BOLD}[r]${R}  Restart all servers\n"
    printf "  ${CYN}${BOLD}[q]${R}  Quit\n\n"

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        n|N) _new_site ;;
        m|M) _manage_site ;;
        r|R)
            while IFS='|' read -r name port src desc; do
                [ -z "$name" ] && continue
                _serve_site "$name" "$port" "$src"
            done < "$SITES_DB"
            sleep 1 ;;
        q|Q) exit 0 ;;
    esac
done
