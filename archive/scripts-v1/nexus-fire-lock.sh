#!/bin/bash
# 🔥 NeXuS Screen Lock 🔥
# Random screensaver + bashlock authentication — terminal/TTY only
# Use as: set-option -g lock-command "~/scripts/nexus-fire-lock.sh"
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

# Wayland — hand off to swaylock, fire screen is TTY only
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$NEXUS_FORCE_FIRELOCK" ]; then
    command -v swaylock >/dev/null 2>&1 && exec swaylock
    exit 0
fi

# Restore cursor and terminal on exit
old_stty=$(stty -g 2>/dev/null)
cleanup() {
    tput cnorm 2>/dev/null
    stty "$old_stty" 2>/dev/null
    clear
}
trap cleanup EXIT INT TERM

clear
tput civis 2>/dev/null

# Pick a random screensaver
SAVERS="cacafire asciiquarium cbonsai cmatrix tty-clock nyancat bb"
COUNT=7
PICK=$(( $(od -An -N1 -tu1 /dev/urandom | tr -d ' ') % COUNT + 1 ))
SAVER=$(echo "$SAVERS" | tr ' ' '\n' | sed -n "${PICK}p")

# Run screensaver in background, kill on keypress
_run_saver() {
    case "$SAVER" in
        cacafire)     cacafire 2>/dev/null ;;
        asciiquarium) asciiquarium 2>/dev/null ;;
        cbonsai)      cbonsai -l -t 0.05 2>/dev/null ;;
        cmatrix)      cmatrix -s -C cyan 2>/dev/null ;;
        tty-clock)    tty-clock -s -c -C 6 2>/dev/null ;;
        nyancat)      nyancat 2>/dev/null ;;
        bb)           bb 2>/dev/null ;;
        *)            cmatrix -s 2>/dev/null ;;
    esac
}

# Loop screensaver until keypress
while true; do
    _run_saver &
    SAVER_PID=$!

    # Wait for any keypress
    stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null
    stty "$old_stty" 2>/dev/null

    kill "$SAVER_PID" 2>/dev/null
    wait "$SAVER_PID" 2>/dev/null

    # Show password prompt on same screen immediately after keypress
    tput cnorm 2>/dev/null
    ORANGE='\033[0;33m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; GRN='\033[0;32m'; NC='\033[0m'
    echo ""
    echo -e "${YELLOW}    🔥 NeXuS — Screen Locked${NC}"
    echo ""

    if command -v bashlock >/dev/null 2>&1; then
        bashlock && clear && exit 0
    elif command -v vlock >/dev/null 2>&1; then
        vlock && clear && exit 0
    else
        # Fallback — password prompt on same screen
        while true; do
            stty -echo 2>/dev/null
            printf "    Password: "
            IFS= read -r password
            stty "$old_stty" 2>/dev/null
            echo ""
            if echo "$password" | su -c "exit" "$USER" 2>/dev/null; then
                echo -e "${GRN}    ✓ Unlocked${NC}"
                sleep 0.5
                clear
                exit 0
            else
                echo -e "${RED}    ✗ Wrong password — press any key to try again${NC}"
                stty -echo -icanon min 1 time 0 2>/dev/null
                dd bs=1 count=1 2>/dev/null
                stty "$old_stty" 2>/dev/null
                # Loop back to screensaver
                break
            fi
        done
    fi
    # Wrong password — run screensaver again
    clear
done
