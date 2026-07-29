#!/bin/sh
# nexus-home-chat.sh — AI chat pane for HOME window
# Wraps aichat with optional TTS (espeak/flite)
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
GRN='\033[38;5;82m'; CYN='\033[38;5;51m'; GRY='\033[38;5;240m'
WHT='\033[38;5;255m'; MAG='\033[38;5;177m'; YLW='\033[38;5;226m'

AICHAT="${HOME}/.cargo/bin/aichat"
HISTORY_FILE="${HOME}/.nexus/chat_history.txt"
TTS_ENABLED=1   # set to 0 to disable voice

# TTS: prefer flite (lighter), fall back to espeak
_speak() {
    [ "$TTS_ENABLED" -eq 0 ] && return
    text="$1"
    if command -v flite >/dev/null 2>&1; then
        echo "$text" | flite -t - -o /tmp/nexus-tts.wav 2>/dev/null && \
        aplay /tmp/nexus-tts.wav 2>/dev/null &
    elif command -v espeak >/dev/null 2>&1; then
        echo "$text" | espeak -s 160 -p 40 2>/dev/null &
    fi
}

_header() {
    clear
    printf "${CYN}${BOLD}  NeXuS AI  ${R}${GRY}[t]oggle voice  [c]lear  [/quit] exit${R}\n"
    printf "${GRY}  ─────────────────────────────────────────────${R}\n"
}

_prompt() {
    printf "${MAG}${BOLD}  you > ${R}"
}

_ai_response() {
    response="$1"
    printf "\n${CYN}${BOLD}  nexus > ${R}${WHT}%s${R}\n\n" "$response"
    # Speak first 200 chars to avoid long TTS
    short=$(echo "$response" | head -c 200 | tr '\n' ' ')
    _speak "$short"
}

mkdir -p "$(dirname "$HISTORY_FILE")"

_header

# Context: who we are
SYSTEM_CTX="You are the NeXuS AI assistant. NeXuS is a privacy-native darknet OS layer. \
You assist with security operations, darknet services, and system management. \
Be concise, direct, technical. NeXuS principles: Sane, Simple, Secure, Stealthy, Beautiful."

printf "${GRY}  TTS: "
[ "$TTS_ENABLED" -eq 1 ] && printf "${GRN}ON${R}" || printf "${YLW}OFF${R}"
printf "${GRY}  •  Type your message, Enter to send${R}\n\n"

while true; do
    _prompt
    IFS= read -r input

    # Handle empty
    [ -z "$input" ] && continue

    # Handle meta commands
    case "$input" in
        /quit|/exit|quit|exit) printf "\n${GRY}  Goodbye.${R}\n"; break ;;
        t|/tts)
            if [ "$TTS_ENABLED" -eq 1 ]; then
                TTS_ENABLED=0
                printf "  ${YLW}Voice OFF${R}\n"
            else
                TTS_ENABLED=1
                printf "  ${GRN}Voice ON${R}\n"
            fi
            continue
            ;;
        c|/clear) _header; continue ;;
        /status)
            gg=$([ -f /tmp/nexus_ghost.lock ] && echo "ACTIVE" || echo "INACTIVE")
            printf "  ${GRY}Ghost Gate: ${WHT}%s${R}\n" "$gg"
            continue
            ;;
    esac

    # Log input
    echo "[$(date '+%H:%M')] YOU: $input" >> "$HISTORY_FILE"

    # Send to aichat
    printf "\n${GRY}  ...${R}"
    response=$(echo "$input" | "$AICHAT" --no-stream -m "$(cat ~/.config/aichat/config.yaml 2>/dev/null | grep '^model:' | awk '{print $2}' || echo 'ollama:qwen2.5-coder:1.5b')" 2>/dev/null)

    # Fallback if aichat fails
    if [ -z "$response" ]; then
        response=$(echo "$input" | "$AICHAT" 2>/dev/null)
    fi
    if [ -z "$response" ]; then
        response="[No response — check aichat config: ~/.config/aichat/config.yaml]"
    fi

    # Clear the "..."
    printf "\r\033[K"

    _ai_response "$response"

    # Log response
    echo "[$(date '+%H:%M')] AI: $response" >> "$HISTORY_FILE"
done
