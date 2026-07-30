#!/bin/sh
# nexus-ai-hub.sh — AI Window status hub + launcher
# Top pane of the AI window — proxy status, tool status, key handler
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'; BLU='\033[38;5;33m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

# Paths
PROXY_SCRIPT="$HOME/scripts/nexus-api-proxy.sh"
WEB_ROOT="$HOME/nexus-web"
PROXY_URL="https://localhost:8443"
CLI_CHAR_GEN="$HOME/Projects/adv-cli-char-gen"
CLI_CHAR_SCRIPT="$CLI_CHAR_GEN/incomplete-char-gen-enhanced-5k-v2.py"
GUI_CHAR_GEN="$HOME/Projects/advanced-ai-character-generator-terminal-access"
AI_FORGE="$HOME/Projects/ai-forge"
VAULT_CHARS="$CLI_CHAR_GEN/characters"
VAULT_IMAGES="$CLI_CHAR_GEN/generated_images"
VAULT_AVATARS="$CLI_CHAR_GEN/avatars"
AICHAT="$HOME/.cargo/bin/aichat"

_dot_path() { [ -f "$1" ] || [ -d "$1" ] && printf "${GRN}●${R}" || printf "${RED}●${R}"; }
_dot_proc() { pgrep -f "$1" >/dev/null 2>&1 && printf "${GRN}●${R}" || printf "${GRY}●${R}"; }
_count()    { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }

_proxy_running() { pgrep -f "nexus_web_server" >/dev/null 2>&1; }

_proxy_dot() {
    if _proxy_running; then
        printf "${GRN}●${R}"
    else
        printf "${GRY}●${R}"
    fi
}

_proxy_label() {
    if _proxy_running; then
        printf "${GRN}LIVE${R}  ${GRY}${PROXY_URL}${R}"
    else
        printf "${GRY}offline${R}  ${DIM}[p] to start${R}"
    fi
}

_app_dot() {
    # Check if a named app dir exists in the web root (real dir or symlink)
    [ -e "${WEB_ROOT}/$1" ] && _proxy_running && printf "${GRN}●${R}" || printf "${GRY}●${R}"
}

_tool_row() {
    printf "  ${CYN}${BOLD}[%s]${R}  %s  ${WHT}%-22s${R}  ${GRY}%s${R}\n" "$1" "$2" "$3" "$4"
}

draw() {
    clear
    ts=$(date '+%H:%M:%S')
    printf "\n  ${CYN}${BOLD}A I${R}  ${GRY}NeXuS Intelligence Hub  •  ${ts}${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n\n"

    # ── PROXY STATUS ─────────────────────────────────────────────
    printf "  ${MAG}${BOLD}NEXUS PROXY${R}  $(_proxy_dot)  $(_proxy_label)\n"
    printf "\n"

    # ── WEB APPS (proxy-served) ───────────────────────────────────
    printf "  ${MAG}${BOLD}WEB APPS${R}\n"
    _tool_row "w" "$(_app_dot manager)"  "Manager / Dashboard"  "${PROXY_URL}/manager/"
    _tool_row "F" "$(_app_dot forge)"    "AI Forge"             "${PROXY_URL}/forge/"
    _tool_row "G" "$(_app_dot chargen)"  "Char Gen (web)"       "${PROXY_URL}/chargen/"
    _tool_row "O" "$(_app_dot foundry)"  "AI Foundry"           "${PROXY_URL}/foundry/"
    _tool_row "C" "$(_app_dot charcard)" "Char Card Reader"     "${PROXY_URL}/charcard/"
    printf "\n"

    # ── INTERFACE ────────────────────────────────────────────────
    printf "  ${MAG}${BOLD}INTERFACE${R}\n"
    _tool_row "c" "$(_dot_path "$AICHAT")"  "Chat (aichat)"          "quick AI chat — bottom pane"
    _tool_row "t" "$(_dot_path "$AICHAT")"  "Think (reasoning)"      "step-by-step mode"
    _tool_row "/" "$(_dot_path "$AICHAT")"  "Search"                 "AI-powered doc + web search"
    printf "\n"

    # ── MEDIA ────────────────────────────────────────────────────
    printf "  ${MAG}${BOLD}MEDIA${R}\n"
    _tool_row "i" "$(_dot_path "$AICHAT")"  "Image Gen"              "generate images via aichat"
    _tool_row "u" "$(_dot_path "$AICHAT")"  "Doc Upload"             "ingest PDF/MD/TXT for context"
    printf "\n"

    # ── FORGE (CLI) ───────────────────────────────────────────────
    printf "  ${MAG}${BOLD}CLI FORGE${R}\n"
    _tool_row "f" "$(_dot_path "$CLI_CHAR_SCRIPT")" "CLI Char Gen" "terminal character creator"
    printf "\n"

    # ── VAULT ────────────────────────────────────────────────────
    printf "  ${MAG}${BOLD}VAULT${R}\n"
    char_count=$(_count "$VAULT_CHARS")
    img_count=$(_count "$VAULT_IMAGES")
    av_count=$(_count "$VAULT_AVATARS")
    shadow_count=$([ -f "$HOME/Projects/adv-cli-char-gen/shadowvault.json" ] && \
        python3 -c "import json,sys; d=json.load(open('$HOME/Projects/adv-cli-char-gen/shadowvault.json')); print(len(d) if isinstance(d,list) else len(d.get('characters',d)))" 2>/dev/null || echo "?")
    _tool_row "v" "$(_dot_path "$VAULT_CHARS")"    "Characters"       "${char_count} characters stored"
    _tool_row "V" "$(_dot_path "$VAULT_IMAGES")"   "Images"           "${img_count} generated  •  ${av_count} avatars"
    _tool_row "x" "$(_dot_path "$HOME/Projects/adv-cli-char-gen/shadowvault.json")" "Shadow Vault" "${shadow_count} entries"
    printf "\n"

    # ── FOOTER ───────────────────────────────────────────────────
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n"
    printf "  ${GRY}[p] proxy start/stop  •  [space] popup  •  [q] quit${R}\n\n"
}

# ── Proxy open in w3m (in the WEB window's w3m pane if available) ──────
_open_proxy_app() {
    url="${PROXY_URL}${1}"
    if ! _proxy_running; then
        tmux display-message "Proxy not running — press [p] to start"
        return
    fi
    # Try to reuse WEB window w3m pane, else open new window
    if tmux list-windows -F '#W' 2>/dev/null | grep -q '^WEB$'; then
        tmux select-window -t WEB
        tmux select-pane -t "WEB.1" 2>/dev/null
        tmux send-keys -t "WEB.1" "w3m -o ssl_verify_peer=0 '${url}'" Enter 2>/dev/null
        tmux select-window -t AI
    else
        tmux new-window -n "PROXY" "w3m -o ssl_verify_peer=0 '${url}'"
    fi
}

_toggle_proxy() {
    if _proxy_running; then
        tmux new-window -n "PROXY-CTL" "sh -c '
            echo \"Stopping NeXuS proxy...\"
            $PROXY_SCRIPT stop 2>/dev/null || pkill -f nexus_web_server
            echo \"Stopped.\"
            sleep 2
        '"
    else
        tmux new-window -n "PROXY-CTL" "sh -c '
            echo \"Starting NeXuS proxy...\"
            $PROXY_SCRIPT start 2>/dev/null
            echo \"Proxy started — ${PROXY_URL}\"
            echo \"Press enter to close this window\"
            read x
        '"
    fi
}

_open_chat() {
    tmux select-pane -t "AI.1" 2>/dev/null || \
    tmux new-window -n "CHAT" "$HOME/scripts/nexus-home-chat.sh"
}

_open_think() {
    tmux new-window -n "THINK" "sh -c '
        echo \"${CYN}Think Mode — step-by-step reasoning${R}\"
        echo \"────────────────────────────────────\"
        printf \"> \"
        while IFS= read -r q; do
            [ \"\$q\" = \"quit\" ] && break
            echo \"\$q\" | $AICHAT --no-stream -r \"Think step by step. Be thorough.\" 2>/dev/null
            printf \"> \"
        done
    '"
}

_open_search() {
    tmux new-window -n "SEARCH" "sh -c '
        echo \"${CYN}NeXuS Search — docs + AI${R}\"
        echo \"────────────────────────────────\"
        printf \"Query > \"
        while IFS= read -r q; do
            [ \"\$q\" = \"quit\" ] && break
            echo \"${GRY}--- Local docs ---${R}\"
            grep -rl \"\$q\" $HOME/Documents/nexus-docs/docs/ 2>/dev/null | \
                head -5 | while read f; do echo \"  \$(basename \$f)\"; done
            echo \"${GRY}--- AI ---${R}\"
            echo \"\$q\" | $AICHAT --no-stream 2>/dev/null
            printf \"Query > \"
        done
    '"
}

_open_image_gen() {
    tmux new-window -n "IMGGEN" "sh -c '
        echo \"${CYN}Image Generation${R}\"
        echo \"────────────────────────────────\"
        printf \"Prompt > \"
        while IFS= read -r prompt; do
            [ \"\$prompt\" = \"quit\" ] && break
            out=\"$HOME/.nexus/images/\$(date +%Y%m%d-%H%M%S).png\"
            mkdir -p \"\$(dirname \$out)\"
            echo \"\$prompt\" | $AICHAT --no-stream 2>/dev/null
            printf \"Prompt > \"
        done
    '"
}

_open_doc_upload() {
    tmux new-window -n "DOCS" "sh -c '
        echo \"${CYN}Doc Upload — inject context into AI${R}\"
        echo \"────────────────────────────────────\"
        file=\$(find $HOME -name \"*.pdf\" -o -name \"*.md\" -o -name \"*.txt\" 2>/dev/null | \
            grep -v node_modules | fzf --prompt=\"Pick doc > \" 2>/dev/null)
        [ -z \"\$file\" ] && echo \"No file selected\" && sleep 2 && exit
        echo \"Loaded: \$(basename \$file)\"
        echo \"Ask questions about this doc:\"
        printf \"> \"
        while IFS= read -r q; do
            [ \"\$q\" = \"quit\" ] && break
            (cat \"\$file\"; echo \"\\n---\\nQuestion: \$q\") | \
                $AICHAT --no-stream 2>/dev/null
            printf \"> \"
        done
    '"
}

_open_cli_char_gen() {
    if [ ! -f "$CLI_CHAR_SCRIPT" ]; then
        tmux display-message "CLI Char Gen not found: $CLI_CHAR_SCRIPT"
        return
    fi
    tmux new-window -n "CHARGEN" "cd $CLI_CHAR_GEN && python3 $CLI_CHAR_SCRIPT"
}

_open_vault_chars() {
    tmux new-window -n "VAULT" "sh -c '
        echo \"${CYN}Character Vault${R}\"
        echo \"────────────────────────────────\"
        while true; do
            char=\$(ls $VAULT_CHARS/*.json 2>/dev/null | fzf \
                --prompt=\"Character > \" \
                --preview=\"python3 -c \\\"import json,sys; d=json.load(open(\\\"{}\\\")); [print(k+\\\":\\\", str(v)[:80]) for k,v in d.items() if not k.startswith(\\\"_\\\")]\\\" 2>/dev/null\" \
                --preview-window=right:50% 2>/dev/null)
            [ -z \"\$char\" ] && break
            echo \"\\nSelected: \$(basename \$char)\"
            python3 -c \"import json; d=json.load(open(\\\"$char\\\")); [print(k+\\\": \\\", str(v)[:200]) for k,v in d.items()]\" 2>/dev/null
            printf \"\\n[e]dit [d]elete [c]hat [enter] back > \"
            read -r act
            case \"\$act\" in
                e) micro \"\$char\" ;;
                d) rm -i \"\$char\" ;;
                c) echo \"Chat as this character:\"
                   name=\$(python3 -c \"import json; d=json.load(open(\\\"$char\\\")); print(d.get(\\\"name\\\",\\\"Character\\\"))\" 2>/dev/null)
                   printf \"> \"
                   while IFS= read -r msg; do
                       [ \"\$msg\" = \"quit\" ] && break
                       (echo \"You are \$name. Stay in character.\"; echo \"\$msg\") | \
                           $AICHAT --no-stream 2>/dev/null
                       printf \"> \"
                   done ;;
            esac
        done
    '"
}

_open_vault_images() {
    tmux new-window -n "IMAGES" "sh -c '
        echo \"${CYN}Image Vault${R}\"
        echo \"────────────────────────────────\"
        all_imgs=\$(find $VAULT_IMAGES $VAULT_AVATARS $HOME/.nexus/images \
            -name \"*.png\" -o -name \"*.jpg\" -o -name \"*.webp\" 2>/dev/null)
        if [ -z \"\$all_imgs\" ]; then
            echo \"No images found\"
            sleep 3
            exit
        fi
        echo \"\$all_imgs\" | fzf \
            --prompt=\"Image > \" \
            --preview=\"echo {}\" 2>/dev/null
    '"
}

_open_shadow_vault() {
    tmux new-window -n "SHADOW" "sh -c '
        echo \"${MAG}Shadow Vault${R}\"
        echo \"────────────────────────────────\"
        python3 -c \"
import json, sys
try:
    with open(\\\"$HOME/Projects/adv-cli-char-gen/shadowvault.json\\\") as f:
        data = json.load(f)
    if isinstance(data, list):
        chars = data
    elif isinstance(data, dict):
        chars = data.get(\\\"characters\\\", list(data.values()))
    else:
        chars = []
    for i, c in enumerate(chars):
        if isinstance(c, dict):
            name = c.get(\\\"name\\\", c.get(\\\"id\\\", f\\\"entry {i}\\\"))
            print(f\\\"  [{i}] {name}\\\")
    print(f\\\"\\nTotal: {len(chars)} entries\\\")
except Exception as e:
    print(f\\\"Error: {e}\\\")
\" 2>/dev/null
        echo
        echo \"Press enter to exit\"
        read x
    '"
}

# ── Main loop ─────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
stty -echo -icanon min 0 time 0 2>/dev/null
trap 'stty "$old_stty" 2>/dev/null; clear; exit 0' INT TERM EXIT

while true; do
    draw

    i=0
    while [ $i -lt 50 ]; do
        key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
        if [ -n "$key" ]; then
            case "$key" in
                p|P)  _toggle_proxy ;;
                w)    _open_proxy_app "/manager/" ;;
                F)    _open_proxy_app "/forge/" ;;
                G)    _open_proxy_app "/chargen/" ;;
                O)    _open_proxy_app "/foundry/" ;;
                C)    _open_proxy_app "/charcard/" ;;
                c)    _open_chat ;;
                t|T)  _open_think ;;
                /)    _open_search ;;
                i|I)  _open_image_gen ;;
                u|U)  _open_doc_upload ;;
                f)    _open_cli_char_gen ;;
                v)    _open_vault_chars ;;
                V)    _open_vault_images ;;
                x|X)  _open_shadow_vault ;;
                ' ')  tmux display-popup -E -w 66 -h 30 "$HOME/scripts/nexus-home-popup.sh" ;;
                q|Q)  exit 0 ;;
            esac
            break
        fi
        sleep 0.1
        i=$((i+1))
    done
done
