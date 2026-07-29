#!/bin/sh
# nexus-ai-hub.sh — AI Window status hub + launcher
# Top pane of the AI window — shows tool status, handles key input
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[38;5;196m'; GRN='\033[38;5;82m';  YLW='\033[38;5;226m'
CYN='\033[38;5;51m';  GRY='\033[38;5;240m'; WHT='\033[38;5;255m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'; BLU='\033[38;5;33m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY" RED="$C_ERROR"

# Paths
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

_tool_row() {
    # $1=key $2=name $3=status_dot $4=detail
    printf "  ${CYN}${BOLD}[%s]${R}  %s  ${WHT}%-22s${R}  ${GRY}%s${R}\n" "$1" "$3" "$2" "$4"
}

draw() {
    clear
    ts=$(date '+%H:%M:%S')
    printf "\n  ${CYN}${BOLD}A I${R}  ${GRY}NeXuS Intelligence Hub  •  ${ts}${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n\n"

    # ── CHAT & REASONING ─────────────────────────────────────────
    printf "  ${MAG}${BOLD}INTERFACE${R}\n"
    _tool_row "c" "Chat (aichat)"       "$(_dot_path "$AICHAT")"  "quick AI chat — bottom pane always live"
    _tool_row "t" "Think (chain reasoning)" "$(_dot_path "$AICHAT")" "step-by-step reasoning mode"
    _tool_row "/" "Search"              "$(_dot_path "$AICHAT")"  "AI-powered doc + web search"
    printf "\n"

    # ── IMAGE & MEDIA ─────────────────────────────────────────────
    printf "  ${MAG}${BOLD}MEDIA${R}\n"
    _tool_row "i" "Image Gen"           "$(_dot_path "$AICHAT")"  "generate images via aichat model"
    _tool_row "u" "Doc Upload"          "$(_dot_path "$AICHAT")"  "ingest PDF/MD/TXT for context"
    printf "\n"

    # ── FORGE ────────────────────────────────────────────────────
    printf "  ${MAG}${BOLD}FORGE${R}\n"
    _tool_row "f" "CLI Char Gen"        "$(_dot_path "$CLI_CHAR_SCRIPT")" "terminal character creator"
    forge_running=$(_dot_proc "vite\|ai-forge")
    _tool_row "F" "AI Forge (GUI)"      "$forge_running"          "web UI: code + images + chat + vault"
    gui_chars=$(_dot_proc "serve\|http-server.*${GUI_CHAR_GEN}")
    _tool_row "G" "GUI Char Gen"        "$gui_chars"              "web character generator"
    printf "\n"

    # ── VAULT ────────────────────────────────────────────────────
    printf "  ${MAG}${BOLD}VAULT${R}\n"
    char_count=$(_count "$VAULT_CHARS")
    img_count=$(_count "$VAULT_IMAGES")
    av_count=$(_count "$VAULT_AVATARS")
    shadow_count=$([ -f "$HOME/Projects/adv-cli-char-gen/shadowvault.json" ] && \
        python3 -c "import json,sys; d=json.load(open('$HOME/Projects/adv-cli-char-gen/shadowvault.json')); print(len(d) if isinstance(d,list) else len(d.get('characters',d)))" 2>/dev/null || echo "?")
    _tool_row "v" "Characters"          "$(_dot_path "$VAULT_CHARS")"    "${char_count} characters stored"
    _tool_row "V" "Images"              "$(_dot_path "$VAULT_IMAGES")"   "${img_count} generated  •  ${av_count} avatars"
    _tool_row "x" "Shadow Vault"        "$(_dot_path "$HOME/Projects/adv-cli-char-gen/shadowvault.json")" "${shadow_count} entries"
    printf "\n"

    # ── FOOTER ───────────────────────────────────────────────────
    printf "  ${GRY}────────────────────────────────────────────────────${R}\n"
    printf "  ${GRY}Press key to launch  •  [space] popup menu  •  [q] quit${R}\n\n"
}

_open_chat() {
    # Focus the chat pane (pane 1)
    tmux select-pane -t "AI.1" 2>/dev/null || \
    tmux new-window -n "CHAT" "$HOME/scripts/nexus-home-chat.sh"
}

_open_think() {
    tmux new-window -n "THINK" "sh -c '
        echo \"${CYN}Think Mode — step-by-step reasoning${R}\"
        echo \"Model: reasoning (uses /think prefix)\"
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
            # Search local wiki first
            echo \"${GRY}--- Local docs ---${R}\"
            grep -rl \"\$q\" $HOME/Documents/nexus-docs/docs/ 2>/dev/null | \
                head -5 | while read f; do echo \"  $(basename \$f)\"; done
            # AI answer
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
        echo \"Uses aichat image model (set in ~/.config/aichat/config.yaml)\"
        printf \"Prompt > \"
        while IFS= read -r prompt; do
            [ \"\$prompt\" = \"quit\" ] && break
            out=\"$HOME/.nexus/images/$(date +%Y%m%d-%H%M%S).png\"
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

_open_ai_forge() {
    if [ ! -f "$AI_FORGE/package.json" ]; then
        tmux display-message "AI Forge not found: $AI_FORGE"
        return
    fi
    tmux new-window -n "FORGE" "sh -c '
        cd $AI_FORGE
        echo \"Starting AI Forge...\"
        npm run dev 2>&1 | tee /tmp/ai-forge.log &
        sleep 3
        echo \"Open: http://localhost:5173\"
        echo \"Log: /tmp/ai-forge.log\"
        tail -f /tmp/ai-forge.log
    '"
}

_open_gui_char_gen() {
    if [ ! -d "$GUI_CHAR_GEN" ]; then
        tmux display-message "GUI Char Gen not found: $GUI_CHAR_GEN"
        return
    fi
    tmux new-window -n "GUIGEN" "sh -c '
        cd $GUI_CHAR_GEN
        # Check for index.html or dist/index.html
        if [ -f dist/index.html ]; then
            echo \"Serving dist/index.html\"
            python3 -m http.server 8899 -d dist &
        elif [ -f index.html ]; then
            python3 -m http.server 8899 &
        else
            echo \"Build first? Running npm...\"
            npm run build 2>/dev/null && python3 -m http.server 8899 -d dist &
        fi
        sleep 1
        echo \"Open: http://localhost:8899\"
        wait
    '"
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
        echo \"Generated: $(_count "$VAULT_IMAGES") images  •  Avatars: $(_count "$VAULT_AVATARS")\"
        echo \"────────────────────────────────\"
        all_imgs=\$(find $VAULT_IMAGES $VAULT_AVATARS $HOME/.nexus/images \
            -name \"*.png\" -o -name \"*.jpg\" -o -name \"*.webp\" 2>/dev/null)
        if [ -z \"\$all_imgs\" ]; then
            echo \"No images found\"
            sleep 3
            exit
        fi
        # fzf with sixel preview if available, else just filename
        echo \"\$all_imgs\" | fzf \
            --prompt=\"Image > \" \
            --preview=\"echo {} | head -1\" 2>/dev/null
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
                c|C)  _open_chat ;;
                t|T)  _open_think ;;
                /)    _open_search ;;
                i|I)  _open_image_gen ;;
                u|U)  _open_doc_upload ;;
                f)    _open_cli_char_gen ;;
                F)    _open_ai_forge ;;
                G)    _open_gui_char_gen ;;
                v)    _open_vault_chars ;;
                V)    _open_vault_images ;;
                x|X)  _open_shadow_vault ;;
                ' ')  tmux display-popup -E -w 62 -h 26 "$HOME/scripts/nexus-home-popup.sh" ;;
                q|Q)  exit 0 ;;
            esac
            break
        fi
        sleep 0.1
        i=$((i+1))
    done
done
