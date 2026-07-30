#!/bin/sh
# nexus-home-status.sh — STATUS pane for HOME window
# Runs in a watch loop — do not call directly, use nexus-home.sh
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

# Theme: source matugen palette if available (GUI auto-theme),
# otherwise fall back to hardcoded ANSI (CLI/tmux safe)
R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
if [ -f "$HOME/.nexus/home_colors.sh" ] && [ -n "$COLORTERM" ]; then
    # GUI session — 24-bit color, use matugen palette
    . "$HOME/.nexus/home_colors.sh"
    GRN="$C_SECONDARY"; CYN="$C_PRIMARY"; MAG="$C_TERTIARY"
    RED="$C_ERROR";     YLW="$C_TERTIARY"; WHT="$C_SURFACE"
    GRY='\033[2m';      ORG="$C_TERTIARY"
else
    # CLI/tmux — safe 256-color fallback
    RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
    CYN='\033[38;5;51m';  ORG='\033[38;5;214m'; GRY='\033[38;5;240m'
    WHT='\033[38;5;255m'; MAG='\033[38;5;177m'
fi

_dot() {
    case "$1" in
        RUNNING|ACTIVE) printf "${GRN}●${R}" ;;
        STOPPED|INACTIVE) printf "${RED}●${R}" ;;
        *) printf "${YLW}●${R}" ;;
    esac
}

_svc() {
    for d in "$HOME/claude/nexus-darknet-go/scripts" "$HOME/scripts"; do
        [ -f "$d/$1" ] && { timeout 2 sh "$d/$1" status 2>/dev/null || echo "UNKNOWN"; return; }
    done
    echo "UNKNOWN"
}

_ghost() {
    [ -f /tmp/nexus_ghost.lock ] && echo "ACTIVE" && return
    nft list tables inet 2>/dev/null | grep -q nexus_ghost && echo "ACTIVE" && return
    echo "INACTIVE"
}

_score() {
    s=0
    [ "$(_ghost)" = "ACTIVE" ] && s=$((s+3))
    [ "$(_svc nexus-tor.sh)" = "RUNNING" ] && s=$((s+2))
    [ "$(_svc nexus-i2p.sh)" = "RUNNING" ] && s=$((s+2))
    [ "$(_svc nexus-dns.sh)" = "RUNNING" ] && s=$((s+1))
    [ "$(_svc nexus-snowflake.sh)" = "RUNNING" ] && s=$((s+1))
    [ -f "$HOME/.nexus/audit.log" ] && s=$((s+1))
    echo $s
}

_label() {
    case "$1" in
        0|1|2) echo "EXPOSED"  ;;
        3|4)   echo "GUARDED"  ;;
        5|6|7) echo "HARDENED" ;;
        8|9)   echo "FORTRESS" ;;
        10)    echo "SOVEREIGN";;
        *)     echo "UNKNOWN"  ;;
    esac
}

_bar() {
    filled=$1; i=0; bar=""
    while [ $i -lt $filled ]; do bar="${bar}█"; i=$((i+1)); done
    while [ $i -lt 10 ]; do bar="${bar}░"; i=$((i+1)); done
    echo "$bar"
}

_cpu() {
    # Read CPU usage across two snapshots 0.5s apart
    read cpu u n s i w x y z < /proc/stat
    sleep 0.5
    read cpu2 u2 n2 s2 i2 w2 x2 y2 z2 < /proc/stat
    total=$(( (u2+n2+s2+i2+w2+x2+y2+z2) - (u+n+s+i+w+x+y+z) ))
    idle=$(( i2 - i ))
    used=$(( total - idle ))
    [ "$total" -eq 0 ] && echo "0" && return
    echo $(( used * 100 / total ))
}

_cpu_bar() {
    pct=$1
    filled=$(( pct / 10 ))
    [ $filled -gt 10 ] && filled=10
    empty=$(( 10 - filled ))
    bar=""; i=0
    while [ $i -lt $filled ]; do bar="${bar}▓"; i=$((i+1)); done
    while [ $i -lt 10 ]; do bar="${bar}░"; i=$((i+1)); done
    # Color by threshold
    if [ $pct -ge 90 ]; then
        printf "${RED}${bar}${R} ${pct}%%"
    elif [ $pct -ge 70 ]; then
        printf "${YLW}${bar}${R} ${pct}%%"
    else
        printf "${GRN}${bar}${R} ${pct}%%"
    fi
}

_mem_bar() {
    total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    used=$(( total - avail ))
    pct=$(( used * 100 / total ))
    used_g=$(awk "BEGIN{printf \"%.1f\", $used/1024/1024}")
    total_g=$(awk "BEGIN{printf \"%.1f\", $total/1024/1024}")
    filled=$(( pct / 10 ))
    [ $filled -gt 10 ] && filled=10
    empty=$(( 10 - filled ))
    bar=""; i=0
    while [ $i -lt $filled ]; do bar="${bar}▓"; i=$((i+1)); done
    while [ $i -lt 10 ]; do bar="${bar}░"; i=$((i+1)); done
    if [ $pct -ge 90 ]; then
        printf "${RED}${bar}${R} ${used_g}/${total_g}GB"
    elif [ $pct -ge 75 ]; then
        printf "${YLW}${bar}${R} ${used_g}/${total_g}GB"
    else
        printf "${GRN}${bar}${R} ${used_g}/${total_g}GB"
    fi
}

_disk_bar() {
    pct=$(df "$HOME" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    free=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
    [ -z "$pct" ] && echo "?" && return
    used=$(( pct / 10 ))
    [ $used -gt 10 ] && used=10
    bar=""; i=0
    while [ $i -lt $used ]; do bar="${bar}▓"; i=$((i+1)); done
    while [ $i -lt 10 ]; do bar="${bar}░"; i=$((i+1)); done
    if [ $pct -ge 90 ]; then
        printf "${RED}${bar}${R} ${free} free"
    elif [ $pct -ge 75 ]; then
        printf "${YLW}${bar}${R} ${free} free"
    else
        printf "${GRN}${bar}${R} ${free} free"
    fi
}

_temp() {
    # Best available temp source
    t=""
    for f in /sys/class/hwmon/hwmon0/temp1_input \
              /sys/class/thermal/thermal_zone0/temp; do
        [ -r "$f" ] && t=$(cat "$f") && break
    done
    [ -z "$t" ] && echo "N/A" && return
    deg=$(( t / 1000 ))
    if [ $deg -ge 90 ]; then
        printf "${RED}${deg}°C !!${R}"
    elif [ $deg -ge 75 ]; then
        printf "${YLW}${deg}°C${R}"
    else
        printf "${GRN}${deg}°C${R}"
    fi
}

_load() {
    read one five fifteen rest < /proc/loadavg
    cores=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo)
    # Color if load > cores
    hi=$(awk "BEGIN{print ($one > $cores) ? 1 : 0}")
    if [ "$hi" -eq 1 ]; then
        printf "${YLW}${one}${R} ${GRY}${five} ${fifteen}${R} ${GRY}(${cores}c)${R}"
    else
        printf "${GRN}${one}${R} ${GRY}${five} ${fifteen}${R} ${GRY}(${cores}c)${R}"
    fi
}

_net_io() {
    # Find active non-loopback interface
    iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    [ -z "$iface" ] && iface=$(cat /proc/net/dev | awk -F: 'NR>2 && $1 !~ /lo/{gsub(/ /,"",$1); print $1; exit}')
    [ -z "$iface" ] && echo "N/A" && return
    rx1=$(awk -F: "/$iface:/{gsub(/ /,\"\",\$2); print \$2}" /proc/net/dev | awk '{print $1}')
    tx1=$(awk -F: "/$iface:/{gsub(/ /,\"\",\$2); print \$2}" /proc/net/dev | awk '{print $10}')
    sleep 1
    rx2=$(awk -F: "/$iface:/{gsub(/ /,\"\",\$2); print \$2}" /proc/net/dev | awk '{print $1}')
    tx2=$(awk -F: "/$iface:/{gsub(/ /,\"\",\$2); print \$2}" /proc/net/dev | awk '{print $10}')
    rx_bps=$(( (rx2 - rx1) ))
    tx_bps=$(( (tx2 - tx1) ))
    rx_h=$(awk "BEGIN{v=$rx_bps; if(v>1048576) printf \"%.1fMB/s\",v/1048576; else if(v>1024) printf \"%.0fKB/s\",v/1024; else printf \"%dB/s\",v}")
    tx_h=$(awk "BEGIN{v=$tx_bps; if(v>1048576) printf \"%.1fMB/s\",v/1048576; else if(v>1024) printf \"%.0fKB/s\",v/1024; else printf \"%dB/s\",v}")
    printf "${GRY}↓${GRN}${rx_h}${R} ${GRY}↑${CYN}${tx_h}${R} ${GRY}(${iface})${R}"
}

_procs() {
    total=$(ls /proc | grep -c '^[0-9]' 2>/dev/null || echo "?")
    printf "${WHT}${total}${R}"
}

_warnings() {
    # Collect operational warnings
    warn=0
    gg=$(_ghost)
    [ "$gg" = "INACTIVE" ] && printf "  ${RED}⚠${R}  Ghost Gate ${RED}INACTIVE${R} — traffic unguarded\n" && warn=$((warn+1))
    [ "$(_svc nexus-tor.sh)" != "RUNNING" ] && printf "  ${RED}⚠${R}  Tor is ${RED}DOWN${R}\n" && warn=$((warn+1))
    [ "$(_svc nexus-i2p.sh)" != "RUNNING" ] && printf "  ${YLW}⚠${R}  I2P is ${YLW}STOPPED${R}\n" && warn=$((warn+1))
    [ "$(_svc nexus-dns.sh)" != "RUNNING" ] && printf "  ${YLW}⚠${R}  DNS is ${YLW}STOPPED${R} — possible leak\n" && warn=$((warn+1))
    anomalies=0
    [ -f "$HOME/.nexus/anomalies.jsonl" ] && anomalies=$(wc -l < "$HOME/.nexus/anomalies.jsonl")
    [ "$anomalies" -gt 0 ] 2>/dev/null && printf "  ${ORG}⚠${R}  ${ORG}${anomalies} anomalies${R} in audit log\n" && warn=$((warn+1))
    # Hardware warnings
    for f in /sys/class/hwmon/hwmon0/temp1_input /sys/class/thermal/thermal_zone0/temp; do
        [ -r "$f" ] && t=$(cat "$f") && deg=$(( t / 1000 ))
        [ "$deg" -ge 90 ] 2>/dev/null && printf "  ${RED}⚠${R}  CPU temp ${RED}${deg}°C — critical${R}\n" && warn=$((warn+1)) && break
        [ "$deg" -ge 75 ] 2>/dev/null && printf "  ${YLW}⚠${R}  CPU temp ${YLW}${deg}°C${R}\n" && warn=$((warn+1)) && break
    done
    disk_pct=$(df "$HOME" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    [ "$disk_pct" -ge 90 ] 2>/dev/null && printf "  ${RED}⚠${R}  Disk ${RED}${disk_pct}%% full${R}\n" && warn=$((warn+1))
    mem_pct=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d", (t-a)*100/t}' /proc/meminfo)
    [ "$mem_pct" -ge 90 ] 2>/dev/null && printf "  ${RED}⚠${R}  RAM ${RED}${mem_pct}%% used${R}\n" && warn=$((warn+1))
    [ "$warn" -eq 0 ] && printf "  ${GRN}✓${R}  All systems nominal\n"
}

while true; do
    score=$(_score)
    label=$(_label $score)
    ts=$(date '+%H:%M:%S')

    # Score color
    case "$label" in
        EXPOSED)   sc="$RED"  ;;
        GUARDED)   sc="$YLW"  ;;
        HARDENED)  sc="$GRN"  ;;
        FORTRESS)  sc="$CYN"  ;;
        SOVEREIGN) sc="$MAG"  ;;
        *)         sc="$GRY"  ;;
    esac

    clear
    printf "${BOLD}${CYN}  H O M E${R}  ${GRY}${ts}${R}\n"
    printf "${GRY}  $(_bar 40 ─)${R}\n\n"

    # Security score
    printf "  ${BOLD}${WHT}SECURITY${R}\n"
    printf "  ${sc}${BOLD}$(_bar $score)${R}  ${sc}${BOLD}${score}/10  ${label}${R}\n\n"

    # Warnings / status
    printf "  ${BOLD}${WHT}STATUS${R}\n"
    _warnings
    printf "\n"

    # Services
    printf "  ${BOLD}${WHT}SERVICES${R}\n"
    # Inline service checks for non-script processes
    _proxy_st()   { pgrep -f nexus_web_server >/dev/null 2>&1 && echo "RUNNING" || echo "STOPPED"; }
    _search_st()  { curl -s --max-time 1 http://localhost:5000/ -o /dev/null 2>/dev/null && echo "RUNNING" || echo "STOPPED"; }
    _panel_st()   { curl -s --max-time 1 http://localhost:8878/ -o /dev/null 2>/dev/null && echo "RUNNING" || echo "STOPPED"; }
    printf "  $(_dot $(_proxy_st))  %-14s  ${GRY}:8443 API proxy${R}\n"  "NeXuS Proxy"
    printf "  $(_dot $(_search_st)) %-14s  ${GRY}:5000 file search${R}\n" "NXS Search"
    printf "  $(_dot $(_panel_st))  %-14s  ${GRY}:8878 darknet panel${R}\n" "Darknet Panel"
    for svc_pair in \
        "Ghost Gate:nexus-ghostgate.sh:gg" \
        "Tor:nexus-tor.sh" \
        "I2P:nexus-i2p.sh" \
        "Snowflake:nexus-snowflake.sh" \
        "DNS:nexus-dns.sh" \
        "Yggdrasil:nexus-yggdrasil.sh" \
        "Medusa:nexus-medusa.sh" \
        "DIVA:nexus-diva.sh"
    do
        name="${svc_pair%%:*}"
        rest="${svc_pair#*:}"
        script="${rest%%:*}"
        # Special case for ghost gate
        if [ "$name" = "Ghost Gate" ]; then
            st=$(_ghost)
        else
            st=$(_svc "$script")
        fi
        printf "  $(_dot "$st")  %-12s  ${GRY}%s${R}\n" "$name" "$st"
    done

    # System health
    printf "  ${BOLD}${WHT}HEALTH${R}\n"
    cpu_pct=$(_cpu)
    printf "  CPU  "; _cpu_bar "$cpu_pct"; printf "\n"
    printf "  MEM  "; _mem_bar;            printf "\n"
    printf "  DSK  "; _disk_bar;           printf "\n"
    printf "  TMP  "; _temp;               printf "\n"
    printf "  LOAD "; _load;               printf "\n"
    printf "  NET  "; _net_io;             printf "\n"
    printf "  PROC %s processes\n" "$(_procs)"

    # Ticker from media window cache
    if [ -f "$HOME/.nexus/ticker.cache" ]; then
        IFS='|' read -r _ts _xmr _btc _eth _hl _gh < "$HOME/.nexus/ticker.cache"
        printf "\n  ${BOLD}${WHT}TICKER${R}\n"
        printf "  ${YLW}${BOLD}%s${R}  ${ORG}${BOLD}%s${R}  ${MAG}${BOLD}%s${R}\n" "$_xmr" "$_btc" "$_eth"
        [ -n "$_hl" ] && printf "  ${GRY}%s${R}\n" "$_hl"
    fi

    # Quick launch reminder
    printf "\n${GRY}  [space] Launch  [s]ettings  [d]arknet [g]ate [a]i [M]edia [q]uit${R}\n"

    # Poll for keys during sleep
    i=0
    while [ $i -lt 50 ]; do
        key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
        if [ -n "$key" ]; then
            case "$key" in
                ' ') tmux display-popup -E -w 66 -h 30 "$HOME/scripts/nexus-home-popup.sh"; break ;;
                s|S) tmux display-popup -E -w 66 -h 32 "$HOME/scripts/nexus-home-settings.sh"; break ;;
                d|D) tmux new-window -n "DARKNET" "cd $HOME/claude/nexus-darknet-go && ./nexus-darknet tui"; break ;;
                g|G) tmux new-window -n "GATE" "cd $HOME/claude/nexus-orchestrator && python nexus.py"; break ;;
                o|O) tmux new-window -n "ORCH" "cd $HOME/claude/nexus-orchestrator && python nexus.py"; break ;;
                l|L) tmux new-window -n "LOGS" "tail -f $HOME/.nexus/audit.log"; break ;;
                a|A) "$HOME/scripts/nexus-ai.sh"; break ;;
                M)   "$HOME/scripts/nexus-media.sh"; break ;;
                m)   tmux new-window -n "MON" "htop"; break ;;
                q|Q) exit 0 ;;
            esac
        fi
        sleep 0.1
        i=$((i+1))
    done
done
