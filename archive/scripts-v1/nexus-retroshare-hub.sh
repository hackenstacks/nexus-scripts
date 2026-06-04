#!/bin/sh
# nexus-retroshare-hub.sh — RetroShare management pane
# Launch GUI, cert management, API status, friend cert site
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

RS_FLATPAK="cc.retroshare.retroshare-gui"
RS_API="http://127.0.0.1:9090"
RS_CERT_DIR="$HOME/.nexus/rs-certs"
RS_CERT_SITE="$HOME/.nexus/forge/store/nexus-friend-cert"
RS_DATA="$HOME/.retroshare"
SCRIPTS="$HOME/scripts"

_in_gui()     { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_rs_running() { pgrep -f "retroshare\|RetroShare" >/dev/null 2>&1; }
_api_up()     { curl -s --max-time 2 "$RS_API/api/v2/peers" >/dev/null 2>&1; }

_launch_gui() {
    if ! _in_gui; then
        printf "  ${RED}No display — not a GUI session${R}\n"; sleep 2; return
    fi
    if _rs_running; then
        printf "  ${GRY}RetroShare already running${R}\n"; sleep 1; return
    fi
    printf "  ${YLW}Launching RetroShare GUI...${R}\n"
    flatpak run "$RS_FLATPAK" >/dev/null 2>&1 &
    sleep 3
    _rs_running && printf "  ${GRN}✓ RetroShare launched${R}\n" || \
        printf "  ${RED}Launch failed — check flatpak${R}\n"
    sleep 1
}

_stop_rs() {
    pkill -f "retroshare\|RetroShare" 2>/dev/null
    printf "  ${GRY}RetroShare stopped${R}\n"; sleep 1
}

_rs_status_line() {
    # Single-line status for bottom strip
    if _rs_running; then
        printf "${GRN}● RS RUNNING${R}"
    else
        printf "${GRY}● RS stopped${R}"
    fi
    if _api_up; then
        peers=$(curl -s --max-time 2 "$RS_API/api/v2/peers" 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',d) if isinstance(d,dict) else d))" 2>/dev/null || echo "?")
        printf "  ${CYN}API ●${R}  ${WHT}%s peers${R}" "$peers"
    else
        printf "  ${GRY}API offline — enable: RetroShare → Plugins → JSON API → port 9090${R}"
    fi
}

# Called as status_line mode from launcher
[ "$1" = "status_line" ] && printf "  " && _rs_status_line && printf "\n" && exit 0

_list_profiles() {
    printf "  ${BOLD}${WHT}PROFILES${R}\n"
    for d in "$RS_DATA"/HID06_*; do
        [ -d "$d" ] || continue
        id=$(basename "$d")
        # Try to get name from peers.cfg
        name=$(grep -m1 'name=' "$d/config/peers.cfg" 2>/dev/null | cut -d= -f2 | tr -d ' ')
        [ -z "$name" ] && name="${id:0:12}..."
        printf "  ${GRY}·${R} ${WHT}%-20s${R} ${GRY}%s${R}\n" "$name" "$id"
    done
    printf "\n"
}

_list_certs() {
    count=$(ls "$RS_CERT_DIR"/*.rsc 2>/dev/null | wc -l | tr -d ' ')
    printf "  ${BOLD}${WHT}FRIEND CERTS${R}  ${GRY}(%s stored)${R}\n" "$count"
    for f in "$RS_CERT_DIR"/*.rsc; do
        [ -f "$f" ] || continue
        printf "  ${GRY}·${R} ${WHT}%s${R}\n" "$(basename "$f" .rsc)"
    done
    [ "$count" -eq 0 ] && printf "  ${GRY}None yet${R}\n"
    printf "\n"
}

_export_cert() {
    printf "\n  ${CYN}Paste your RetroShare certificate${R}\n"
    printf "  ${GRY}RetroShare → People → Your Certificate → Copy${R}\n"
    printf "  ${GRY}(blank line to finish)${R}\n\n"
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    cert=""; prev=""
    while IFS= read -r line; do
        [ -z "$line" ] && [ -n "$cert" ] && break
        cert="${cert}${line}
"
        prev="$line"
    done
    stty "$old" 2>/dev/null
    [ -z "$cert" ] && return
    printf "%s" "$cert" > "$RS_CERT_DIR/nexus-node.rsc"
    # Build the friend cert site
    _build_cert_site "$cert"
    printf "\n  ${GRN}✓${R} Saved as nexus-node.rsc\n"
    printf "  ${GRN}✓${R} Friend cert site rebuilt at:\n"
    printf "  ${GRY}  %s${R}\n" "$RS_CERT_SITE"
    printf "\n  ${YLW}Now publish it:${R} press [d] to open darknet publisher\n"
    printf "\n  Press any key..."; _anykey
}

_add_friend() {
    printf "\n  ${CYN}Add a friend certificate${R}\n"
    printf "  ${GRY}Paste their cert (blank line to finish):${R}\n\n"
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    cert=""; prev=""
    while IFS= read -r line; do
        [ -z "$line" ] && [ -n "$cert" ] && break
        cert="${cert}${line}
"
    done
    stty "$old" 2>/dev/null
    [ -z "$cert" ] && return
    fname="friend-$(date +%Y%m%d%H%M%S)"
    # Try to extract name from cert
    name=$(echo "$cert" | grep -o 'name:[^;]*' | cut -d: -f2 | head -1 | tr -d ' ' 2>/dev/null)
    [ -n "$name" ] && fname="$name"
    printf "%s" "$cert" > "$RS_CERT_DIR/${fname}.rsc"
    printf "\n  ${GRN}✓${R} Saved: ${fname}.rsc\n"
    printf "  ${GRY}Import in RetroShare: People → Add Friend → paste cert${R}\n"
    printf "\n  Press any key..."; _anykey
}

_build_cert_site() {
    cert_content="$1"
    mkdir -p "$RS_CERT_SITE"
    cat > "$RS_CERT_SITE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>NeXuS — Join the Mesh</title>
<style>
  *{box-sizing:border-box}
  body{background:#0a0a0a;color:#e0e0e0;font-family:monospace;max-width:680px;
       margin:60px auto;padding:0 24px;line-height:1.6}
  h1{color:#00e5ff;border-bottom:1px solid #1a1a2e;padding-bottom:12px;margin-bottom:8px}
  h2{color:#82ff6a;font-size:.9em;letter-spacing:.1em;text-transform:uppercase;margin-top:28px}
  .badge{background:#0d1117;border:1px solid #00e5ff;color:#00e5ff;
         font-size:.75em;padding:3px 10px;display:inline-block;margin-bottom:20px}
  .step{background:#0d1117;border-left:3px solid #ff9800;padding:12px 16px;margin:10px 0}
  .step strong{color:#ff9800}
  pre{background:#0d1117;padding:16px;border-left:3px solid #00e5ff;
      white-space:pre-wrap;word-break:break-all;font-size:.8em;
      max-height:200px;overflow-y:auto}
  .copy-btn{background:#00e5ff;color:#000;border:none;padding:6px 14px;
            font-family:monospace;cursor:pointer;margin-top:8px;font-size:.85em}
  a{color:#b39ddb}
  hr{border:none;border-top:1px solid #1a1a2e;margin:28px 0}
  .dim{color:#444;font-size:.8em}
  .online{color:#82ff6a}
</style>
</head>
<body>
<span class="badge">◈ NeXuS Node</span>
<h1>Join the NeXuS Mesh</h1>
<p>Add this certificate in RetroShare and you become part of the NeXuS network.
Once connected you can reach every other NeXuS node — no central server, no registration.</p>

<h2>Step 1 — Get RetroShare</h2>
<div class="step">
  <strong>Linux:</strong><br>
  <code>flatpak install flathub cc.retroshare.retroshare-gui</code><br><br>
  <strong>Windows / Mac:</strong> <a href="https://retroshare.cc" target="_blank">retroshare.cc</a>
</div>

<h2>Step 2 — Add the NeXuS Certificate</h2>
<div class="step">
  Open RetroShare → <strong>People</strong> tab → <strong>Add Friend</strong> → paste the certificate below
</div>
<pre id="cert">${cert_content}</pre>
<button class="copy-btn" onclick="navigator.clipboard.writeText(document.getElementById('cert').innerText)">Copy Certificate</button>

<h2>Step 3 — You're In</h2>
<p>Once RetroShare shows the connection as <span class="online">● online</span>, you're on the NeXuS mesh.
Other NeXuS nodes will appear automatically as mutual connections are discovered.</p>

<h2>Share Back (Optional)</h2>
<p>Export your own certificate from RetroShare → People → Your Certificate → Copy,
then send it back via the mesh, I2P, or Tor so we can confirm the connection from our side.</p>

<hr>
<p class="dim">◈ NeXuS: Sane · Simple · Secure · Stealthy · Beautiful<br>
End-to-end encrypted · No central server · No logs · Tor/I2P transport</p>
</body>
</html>
HTML
    # Raw cert for programmatic import
    printf "%s" "$cert_content" > "$RS_CERT_SITE/nexus-node.rsc"
}

_enable_api_guide() {
    clear
    printf "\n  ${CYN}${BOLD}Enable RetroShare JSON API${R}\n\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n"
    printf "  This enables the text chat companion pane.\n\n"
    printf "  ${YLW}In RetroShare GUI:${R}\n"
    printf "  1. Menu → Plugins → Plugin Manager\n"
    printf "  2. Find ${WHT}JSON API${R} → Enable it\n"
    printf "  3. Set port to ${CYN}9090${R}\n"
    printf "  4. Restart RetroShare\n\n"
    printf "  ${GRY}OR — in the config file:${R}\n"
    for d in "$RS_DATA"/HID06_*; do
        cfg="$d/config/general.cfg"
        [ -f "$cfg" ] && printf "  ${GRY}%s${R}\n" "$cfg"
    done
    printf "\n  Add to general.cfg:\n"
    printf "  ${GRN}[jsonapi]${R}\n"
    printf "  ${GRN}enabled=1${R}\n"
    printf "  ${GRN}listenport=9090${R}\n"
    printf "  ${GRN}listenaddress=127.0.0.1${R}\n\n"
    printf "  Press any key..."; _anykey
}

_anykey() {
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

_header() {
    clear
    printf "\n  ${CYN}${BOLD}◈  RETROSHARE${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n\n"
}

_draw_status() {
    # RS running?
    if _rs_running; then
        printf "  ${GRN}●${R} ${WHT}RetroShare${R}  ${GRN}RUNNING${R}"
    else
        printf "  ${RED}●${R} ${WHT}RetroShare${R}  ${GRY}stopped${R}"
    fi
    # GUI available?
    _in_gui && printf "  ${GRY}[GUI session]${R}" || printf "  ${GRY}[CLI session]${R}"
    printf "\n"
    # API?
    if _api_up; then
        printf "  ${GRN}●${R} ${WHT}JSON API${R}    ${GRN}UP${R}  ${GRY}→ text pane active${R}\n"
    else
        printf "  ${GRY}●${R} ${WHT}JSON API${R}    ${GRY}offline${R}  ${DIM}[j] to enable guide${R}\n"
    fi
    # Cert site
    if [ -f "$RS_CERT_SITE/index.html" ]; then
        printf "  ${GRN}●${R} ${WHT}Friend site${R} ${GRN}ready${R}  ${GRY}%s${R}\n" "$RS_CERT_SITE"
    else
        printf "  ${GRY}●${R} ${WHT}Friend site${R} ${GRY}not built${R}  ${DIM}[e] export cert to build it${R}\n"
    fi
    printf "\n"
}

# ── Main loop ──────────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    _header
    _draw_status
    _list_profiles
    _list_certs

    if _in_gui; then
        printf "  ${CYN}[g]${R}  Launch RetroShare GUI\n"
    fi
    printf "  ${CYN}[S]${R}  Stop RetroShare\n"
    printf "  ${CYN}[e]${R}  Export MY cert → build friend site\n"
    printf "  ${CYN}[a]${R}  Add friend cert\n"
    printf "  ${CYN}[j]${R}  How to enable JSON API\n"
    printf "  ${CYN}[d]${R}  Publish friend cert site to darknet\n"
    printf "  ${CYN}[q]${R}  Quit\n\n"

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        g|G) _launch_gui ;;
        S)   _stop_rs ;;
        e|E) _export_cert ;;
        a|A) _add_friend ;;
        j|J) _enable_api_guide ;;
        d|D) tmux new-window -n "DKPUB" "$SCRIPTS/nexus-darknet-publish.sh" ;;
        q|Q) exit 0 ;;
    esac
done
