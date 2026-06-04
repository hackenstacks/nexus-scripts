#!/bin/sh
# nexus-home-settings.sh — Settings popup for HOME window
# Called via: tmux display-popup -E -w 64 -h 30 'nexus-home-settings.sh'
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

NEXUS_CFG="$HOME/.nexus"
CHAT_HIST="$NEXUS_CFG/chat_history.txt"
SCRIPTS="$HOME/scripts"

_header() {
    printf "\n  ${CYN}${BOLD}SETTINGS${R}\n"
    printf "  ${GRY}──────────────────────────────────────────────────${R}\n\n"
}

_section() { printf "  ${MAG}${BOLD}%s${R}\n" "$1"; }

_opt() {
    # $1=key  $2=label  $3=current value
    printf "  ${CYN}[%s]${R}  %-28s ${GRY}%s${R}\n" "$1" "$2" "$3"
}

_read_cfg() {
    key="$1"; default="$2"
    val=$(grep "^${key}=" "$NEXUS_CFG/home.cfg" 2>/dev/null | cut -d= -f2-)
    echo "${val:-$default}"
}

_write_cfg() {
    key="$1"; val="$2"
    mkdir -p "$NEXUS_CFG"
    touch "$NEXUS_CFG/home.cfg"
    if grep -q "^${key}=" "$NEXUS_CFG/home.cfg" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$NEXUS_CFG/home.cfg"
    else
        echo "${key}=${val}" >> "$NEXUS_CFG/home.cfg"
    fi
}

draw() {
    clear
    _header

    # Theme
    _section "THEME"
    current_wall=$(cat "$NEXUS_CFG/current_wallpaper" 2>/dev/null || echo "none")
    wall_base=$(basename "$current_wall" 2>/dev/null || echo "none")
    _opt "t" "Change theme (matugen)"     "$wall_base"
    _opt "T" "Cycle preset theme"         "dark / ember / ghost / ice"
    printf "\n"

    # TTS
    _section "VOICE"
    tts=$(_read_cfg TTS_ENABLED 1)
    tts_label="ON (flite)"; [ "$tts" = "0" ] && tts_label="OFF"
    tts_engine=$(_read_cfg TTS_ENGINE "flite")
    _opt "v" "Toggle voice"               "$tts_label"
    _opt "V" "Voice engine"               "$tts_engine  (flite/espeak)"
    printf "\n"

    # AI model
    _section "AI"
    model=$(_read_cfg AI_MODEL "auto")
    _opt "a" "AI model for chat"          "$model"
    _opt "A" "Clear chat history"         "$(wc -l < "$CHAT_HIST" 2>/dev/null || echo 0) lines"
    printf "\n"

    # HOME layout
    _section "LAYOUT"
    refresh=$(_read_cfg HOME_REFRESH 5)
    rss=$(_read_cfg RSS_ENABLED 1)
    rss_label="ON"; [ "$rss" = "0" ] && rss_label="OFF"
    _opt "r" "Status refresh interval"    "${refresh}s"
    _opt "R" "RSS feed pane"              "$rss_label"
    printf "\n"

    # System
    _section "SYSTEM"
    _opt "n" "Node name"                  "$(hostname)"
    _opt "k" "Reload tmux theme now"      "(sources matugen-colors.conf)"
    _opt "w" "Window wizard"              "coming soon"
    printf "\n"

    printf "  ${GRY}──────────────────────────────────────────────────${R}\n"
    printf "  ${GRY}Press key to change setting • [q] close${R}\n\n"
}

_pick_wallpaper() {
    # fzf picker over common wallpaper dirs
    wall=$(find "$HOME/Pictures" "$HOME/.local/share/wallpapers" /usr/share/wallpapers \
        -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null \
        | fzf --prompt="Wallpaper > " --preview="echo {}" 2>/dev/null)
    [ -z "$wall" ] && return
    printf "\n  Applying theme from: %s\n" "$(basename "$wall")"
    "$SCRIPTS/nexus-theme.sh" "$wall" 2>/dev/null &
    echo "$wall" > "$NEXUS_CFG/current_wallpaper"
    sleep 1
}

_cycle_preset() {
    presets="dark ember ghost ice"
    current=$(_read_cfg PRESET_THEME "dark")
    # find next in list
    next=""
    found=0
    for p in $presets; do
        [ $found -eq 1 ] && next="$p" && found=2 && break
        [ "$p" = "$current" ] && found=1
    done
    [ -z "$next" ] && next=$(echo "$presets" | awk '{print $1}')
    _write_cfg PRESET_THEME "$next"
    # Map to wallpaper presets if they exist
    wall="$HOME/Pictures/nexus-${next}.png"
    [ -f "$wall" ] && "$SCRIPTS/nexus-theme.sh" "$wall" 2>/dev/null &
    printf "\n  Preset: %s\n" "$next"
    sleep 1
}

_change_model() {
    printf "\n  ${WHT}AI model (Enter to confirm):${R}\n"
    printf "  Examples: ollama:qwen2.5-coder:1.5b  claude:claude-sonnet-4-6\n"
    printf "  Current: $(_read_cfg AI_MODEL auto)\n"
    printf "  > "
    read -r model
    [ -n "$model" ] && _write_cfg AI_MODEL "$model" && printf "  Saved: %s\n" "$model"
    sleep 1
}

# Main
old_stty=$(stty -g 2>/dev/null)
stty -echo -icanon min 1 time 0 2>/dev/null
trap 'stty "$old_stty" 2>/dev/null' EXIT INT TERM

while true; do
    draw
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    [ -z "$key" ] && continue
    case "$key" in
        q|Q) break ;;
        t)   stty "$old_stty" 2>/dev/null; _pick_wallpaper; stty -echo -icanon min 1 time 0 2>/dev/null ;;
        T)   _cycle_preset ;;
        v)   tts=$(_read_cfg TTS_ENABLED 1)
             [ "$tts" = "1" ] && _write_cfg TTS_ENABLED 0 || _write_cfg TTS_ENABLED 1 ;;
        V)   eng=$(_read_cfg TTS_ENGINE flite)
             [ "$eng" = "flite" ] && _write_cfg TTS_ENGINE espeak || _write_cfg TTS_ENGINE flite ;;
        a)   stty "$old_stty" 2>/dev/null; _change_model; stty -echo -icanon min 1 time 0 2>/dev/null ;;
        A)   rm -f "$CHAT_HIST"; printf "\n  Chat history cleared.\n"; sleep 1 ;;
        r)   ref=$(_read_cfg HOME_REFRESH 5)
             next=$(( (ref % 10) + 1 ))
             [ $next -lt 2 ] && next=2
             _write_cfg HOME_REFRESH "$next" ;;
        R)   rss=$(_read_cfg RSS_ENABLED 1)
             [ "$rss" = "1" ] && _write_cfg RSS_ENABLED 0 || _write_cfg RSS_ENABLED 1 ;;
        k)   tmux source-file "$HOME/.config/tmux/matugen-colors.conf" 2>/dev/null
             printf "\n  ${GRN}tmux theme reloaded${R}\n"; sleep 1 ;;
        w)   printf "\n  ${YLW}Window wizard — coming soon${R}\n"; sleep 2 ;;
    esac
done

stty "$old_stty" 2>/dev/null
