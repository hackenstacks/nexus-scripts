#!/bin/sh
# nexus-av-hub.sh — Audio/Video hub pane
# Play · download · queue · stream · GUI launch
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

QUEUE_FILE="$HOME/.nexus/av-queue.m3u"
DL_DIR="$HOME/Downloads/media"
MPV_LOG="/tmp/nexus-mpv.log"
TOR_SOCKS="socks5://127.0.0.1:9050"
mkdir -p "$DL_DIR"
touch "$QUEUE_FILE" 2>/dev/null

_in_gui()   { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }
_tor_up()   { ss -tln 2>/dev/null | grep -q ':9050'; }
_mpv_run()  { pgrep -x mpv >/dev/null 2>&1; }
_mpd_run()  { pgrep -x mpd >/dev/null 2>&1; }

_anykey() {
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Now playing via mpv IPC ───────────────────────────────────────────
_now_playing() {
    if _mpv_run; then
        title=$(echo '{"command":["get_property","media-title"]}' | \
            socat - /tmp/nexus-mpv-ipc.sock 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data','')[:40])" 2>/dev/null)
        [ -n "$title" ] && printf "${GRN}▶${R} ${WHT}%s${R}" "$title" || printf "${GRN}▶${R} ${GRY}mpv running${R}"
    else
        printf "${GRY}■ stopped${R}"
    fi
}

# ── Status bar ────────────────────────────────────────────────────────
_status() {
    printf "  "
    _now_playing
    printf "   "
    _mpd_run && printf "${GRN}●${R} MPD" || printf "${GRY}○${R} MPD"
    printf "  "
    _tor_up && printf "${GRN}●${R} Tor" || printf "${GRY}○${R} Tor"
    printf "\n"
}

# ── Play a file or URL with mpv ───────────────────────────────────────
_play() {
    printf "\n  ${CYN}Play (file path or URL)${R} > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r target
    stty "$old" 2>/dev/null
    [ -z "$target" ] && return

    # Build mpv command
    mpv_opts="--input-ipc-server=/tmp/nexus-mpv-ipc.sock"
    if _in_gui; then
        # GUI: proper video window
        nohup mpv $mpv_opts "$target" >"$MPV_LOG" 2>&1 &
    else
        # CLI: audio only in terminal
        mpv $mpv_opts --no-video --term-osd-bar "$target" 2>"$MPV_LOG" &
    fi
    printf "  ${GRN}▶${R} Playing: ${WHT}%.50s${R}\n" "$target"
    echo "$target" >> "$QUEUE_FILE"
    sleep 1
}

# ── Play from queue ───────────────────────────────────────────────────
_play_queue() {
    [ ! -s "$QUEUE_FILE" ] && printf "  ${GRY}Queue is empty${R}\n" && sleep 1 && return
    if _in_gui; then
        nohup mpv --input-ipc-server=/tmp/nexus-mpv-ipc.sock \
            --playlist="$QUEUE_FILE" >"$MPV_LOG" 2>&1 &
    else
        mpv --no-video --term-osd-bar \
            --input-ipc-server=/tmp/nexus-mpv-ipc.sock \
            --playlist="$QUEUE_FILE" 2>"$MPV_LOG" &
    fi
    printf "  ${GRN}▶${R} Playing queue (%s items)\n" "$(wc -l < "$QUEUE_FILE" | tr -d ' ')"
    sleep 1
}

# ── yt-dlp download ───────────────────────────────────────────────────
_download() {
    printf "\n  ${YLW}${BOLD}DOWNLOAD${R}\n"
    printf "  URL > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r url
    stty "$old" 2>/dev/null
    [ -z "$url" ] && return

    printf "\n  ${GRY}[a]${R} audio only (mp3)   ${GRY}[v]${R} video (best)   ${GRY}[V]${R} video 720p\n"
    printf "  ${GRY}[l]${R} playlist            ${GRY}[s]${R} subtitles too\n\n"
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    fmt=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    # Tor proxy option
    proxy_arg=""
    _tor_up && proxy_arg="--proxy $TOR_SOCKS"

    case "$fmt" in
        a) opts="-x --audio-format mp3" ;;
        v) opts="-f bestvideo+bestaudio" ;;
        V) opts="-f 'bestvideo[height<=720]+bestaudio'" ;;
        l) opts="--yes-playlist" ;;
        s) opts="--write-sub --write-auto-sub" ;;
        *) opts="" ;;
    esac

    printf "\n  ${YLW}Downloading...${R}\n"
    tmux new-window -n "DL" \
        "yt-dlp $proxy_arg $opts -o '$DL_DIR/%(title)s.%(ext)s' '$url'; echo; echo '--- Done ---'; read x"
}

# ── Stream via yt-dlp → mpv (pipe) ───────────────────────────────────
_stream() {
    printf "\n  ${CYN}Stream URL${R} > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r url
    stty "$old" 2>/dev/null
    [ -z "$url" ] && return

    proxy_arg=""
    _tor_up && proxy_arg="--proxy $TOR_SOCKS"

    printf "\n  ${GRY}[a]${R} audio only   ${GRY}[v]${R} video\n"
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    fmt=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    if [ "$fmt" = "a" ]; then
        nohup mpv --no-video \
            --input-ipc-server=/tmp/nexus-mpv-ipc.sock \
            "$url" >"$MPV_LOG" 2>&1 &
    else
        nohup mpv \
            --input-ipc-server=/tmp/nexus-mpv-ipc.sock \
            "$url" >"$MPV_LOG" 2>&1 &
    fi
    printf "  ${GRN}▶${R} Streaming: %.50s\n" "$url"
    sleep 1
}

# ── Queue management ──────────────────────────────────────────────────
_queue_view() {
    clear
    printf "\n  ${CYN}${BOLD}QUEUE${R}  ${GRY}(%s items)${R}\n\n" \
        "$(wc -l < "$QUEUE_FILE" 2>/dev/null | tr -d ' ')"
    cat -n "$QUEUE_FILE" 2>/dev/null | while IFS= read -r line; do
        printf "  ${GRY}%s${R}\n" "$line"
    done
    printf "\n  ${GRY}[c] clear  [a] add  [p] play  [q] back${R}\n"
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null
    case "$key" in
        c|C) > "$QUEUE_FILE"; printf "  ${GRN}Cleared${R}\n"; sleep 1 ;;
        a|A) printf "  URL/path > "; old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
             IFS= read -r item; stty "$old" 2>/dev/null
             [ -n "$item" ] && echo "$item" >> "$QUEUE_FILE" ;;
        p|P) _play_queue ;;
    esac
}

# ── MPD control ───────────────────────────────────────────────────────
_mpd_control() {
    if ! _mpd_run; then
        printf "  ${YLW}Starting MPD...${R}\n"; mpd 2>/dev/null; sleep 1
        _mpd_run && printf "  ${GRN}✓ MPD started${R}\n" || \
            printf "  ${RED}MPD failed — check ~/.config/mpd/mpd.conf${R}\n"
        sleep 1
    else
        clear
        printf "\n  ${CYN}${BOLD}MPD CONTROL${R}\n\n"
        printf "  ${GRY}Using ncmpcpp in right pane → select pane and use it directly${R}\n\n"
        printf "  Quick controls:\n"
        printf "  ${CYN}[t]${R} toggle play/pause   ${CYN}[n]${R} next   ${CYN}[p]${R} prev\n"
        printf "  ${CYN}[s]${R} stop                ${CYN}[u]${R} update library\n\n"
        old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
        key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
        stty "$old" 2>/dev/null
        case "$key" in
            t) mpc toggle 2>/dev/null ;;
            n) mpc next 2>/dev/null ;;
            p) mpc prev 2>/dev/null ;;
            s) mpc stop 2>/dev/null ;;
            u) mpc update 2>/dev/null && printf "  ${GRN}Library updated${R}\n" && sleep 1 ;;
        esac
    fi
}

# ── GUI launchers ──────────────────────────────────────────────────────
_launch_strawberry() {
    flatpak run org.strawberrymusicplayer.strawberry >/dev/null 2>&1 &
    printf "  ${GRN}▶${R} Strawberry launching...\n"; sleep 1
}

_launch_vlc() {
    vlc >/dev/null 2>&1 &
    printf "  ${GRN}▶${R} VLC launching...\n"; sleep 1
}

# ── Browse media files ─────────────────────────────────────────────────
_browse_media() {
    dirs="$HOME/Music $HOME/Videos $HOME/Downloads/media"
    file=$(find $dirs -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.ogg" \
        -o -name "*.wav" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \
        -o -name "*.m4a" -o -name "*.opus" \) 2>/dev/null | \
        fzf --prompt="Play > " --height=60% \
            --preview="file {}" 2>/dev/null)
    [ -n "$file" ] || return
    printf "\n  ${GRY}[p]${R} play now   ${GRY}[q]${R} add to queue\n"
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null
    case "$key" in
        p|P) nohup mpv --input-ipc-server=/tmp/nexus-mpv-ipc.sock \
                 "$file" >"$MPV_LOG" 2>&1 &
             printf "  ${GRN}▶${R} %.50s\n" "$(basename "$file")"; sleep 1 ;;
        q|Q) echo "$file" >> "$QUEUE_FILE"
             printf "  ${GRN}+${R} Added to queue\n"; sleep 1 ;;
    esac
}

# ── Stop all playback ──────────────────────────────────────────────────
_stop_all() {
    pkill -x mpv 2>/dev/null; mpc stop 2>/dev/null
    printf "  ${GRY}Stopped all playback${R}\n"; sleep 1
}

# ── Main loop ──────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    clear
    printf "\n  ${ORG}${BOLD}◈  AUDIO / VIDEO${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n"
    _status
    printf "  ${GRY}────────────────────────────────────────────────${R}\n\n"

    printf "  ${ORG}PLAY${R}\n"
    printf "  ${CYN}[p]${R}  Play file or URL (mpv)\n"
    printf "  ${CYN}[s]${R}  Stream URL → mpv\n"
    printf "  ${CYN}[f]${R}  Browse media files\n"
    printf "  ${CYN}[Q]${R}  Queue — view/play/manage\n"
    printf "\n"
    printf "  ${ORG}DOWNLOAD${R}\n"
    printf "  ${CYN}[d]${R}  Download (yt-dlp)\n"
    printf "\n"
    printf "  ${ORG}CONTROL${R}\n"
    printf "  ${CYN}[m]${R}  MPD (start / quick controls)\n"
    printf "  ${CYN}[x]${R}  Stop all playback\n"
    printf "  ${CYN}[a]${R}  alsamixer\n"
    if _in_gui; then
        printf "\n"
        printf "  ${ORG}GUI${R}\n"
        printf "  ${CYN}[S]${R}  Strawberry  ${CYN}[V]${R}  VLC\n"
    fi
    printf "\n  ${GRY}[q] quit${R}\n\n"
    printf "  ${GRY}Downloads: %s${R}\n" "$DL_DIR"

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        p|P) _play ;;
        s)   _stream ;;
        f|F) _browse_media ;;
        Q)   _queue_view ;;
        d|D) _download ;;
        m)   _mpd_control ;;
        x|X) _stop_all ;;
        a|A) tmux new-window -n "MIXER" "alsamixer" ;;
        S)   _in_gui && _launch_strawberry ;;
        V)   _in_gui && _launch_vlc ;;
        q)   exit 0 ;;
    esac
done
