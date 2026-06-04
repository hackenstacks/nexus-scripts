#!/bin/bash
# 🔥 NeXuS Fire Login Manager 🔥
# Cacafire-powered login experience with animated flames
# Sane • Simple • Secure

# Colors
RED='\033[0;31m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Config
FIRE_DURATION=3
SCRIPT_DIR="/home/user/scripts"

# Trap to clean up background processes
cleanup() {
    pkill -P $$ 2>/dev/null
    tput cnorm  # Show cursor
    clear
    exit 0
}
trap cleanup EXIT INT TERM

# Hide cursor for cleaner look
tput civis

# Show cacafire splash
show_fire_splash() {
    if command -v cacafire >/dev/null 2>&1; then
        echo -e "${YELLOW}🔥 Igniting flames...${NC}"
        timeout $FIRE_DURATION cacafire 2>/dev/null || true
    elif command -v aafire >/dev/null 2>&1; then
        timeout $FIRE_DURATION aafire 2>/dev/null || true
    fi
    clear
}

# ASCII fire banner
show_fire_banner() {
    clear
    cat << 'FIRE'

    🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
    🔥                                                            🔥
    🔥    ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗            🔥
    🔥    ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝            🔥
    🔥    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗            🔥
    🔥    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║            🔥
    🔥    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║            🔥
    🔥    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝            🔥
    🔥                                                            🔥
    🔥           ⚡ FIRE LOGIN MANAGER ⚡                         🔥
    🔥              Sane • Simple • Secure                        🔥
    🔥                                                            🔥
    🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥

FIRE
}

# System info line
show_system_info() {
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | cut -c1-2)
    local mem=$(free -h | awk '/^Mem:/ {print $3"/"$2}')
    local time=$(date '+%H:%M:%S')

    echo -e "${ORANGE}    ┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${ORANGE}    │${NC} 🌡️  ${temp}°C  │  💾 ${mem}  │  🕐 ${time}  │  ⚡ READY ${ORANGE}│${NC}"
    echo -e "${ORANGE}    └────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Detect available sessions
declare -a WAYLAND_SESSIONS=()
declare -a X11_SESSIONS=()

detect_sessions() {
    # Detect Wayland sessions
    for wm in labwc sway wayfire hyprland river dwl hikari niri kwin_wayland; do
        if command -v "$wm" >/dev/null 2>&1; then
            WAYLAND_SESSIONS+=("$wm")
        fi
    done
    # Check for lxqt-wayland
    if [ -f /usr/share/wayland-sessions/lxqt-wayland.desktop ]; then
        WAYLAND_SESSIONS+=("lxqt-wayland")
    fi

    # Detect X11 sessions
    if [ -f /usr/share/xsessions/lxqt.desktop ]; then
        X11_SESSIONS+=("lxqt")
    fi
    if [ -f /usr/share/xsessions/mate.desktop ]; then
        X11_SESSIONS+=("mate")
    fi
    if command -v openbox >/dev/null 2>&1; then
        X11_SESSIONS+=("openbox")
    fi
    if [ -f /usr/share/xsessions/sxmo.desktop ]; then
        X11_SESSIONS+=("sxmo")
    fi
}

# Main menu
show_menu() {
    echo -e "${YELLOW}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}    ║${NC}              ${BOLD}🔥 SESSION LAUNCHER 🔥${NC}                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}    ║${NC}                                                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${GREEN}1.${NC} 🌀 NeXuS TUI Desktop    ${CYAN}(tmux environment)${NC}     ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${GREEN}2.${NC} 🖥️  Wayland Sessions     ${CYAN}(${#WAYLAND_SESSIONS[@]} available)${NC}       ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${GREEN}3.${NC} 📺 X11 Sessions         ${CYAN}(${#X11_SESSIONS[@]} available)${NC}          ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${GREEN}4.${NC} 🐚 Shell Only           ${CYAN}(zsh)${NC}                 ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${GREEN}5.${NC} 📺 Framebuffer Apps     ${CYAN}(Qt on /dev/fb0)${NC}       ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}                                                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}    ║${NC}   ${ORANGE}F.${NC} 🔥 Fire Animation       ${CYAN}(cacafire)${NC}            ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${ORANGE}S.${NC} ⚙️  System Settings     ${CYAN}(config)${NC}              ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${ORANGE}P.${NC} ⏻  Power Options        ${CYAN}(shutdown/reboot)${NC}     ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}   ${RED}Q.${NC} 🚪 Exit                                          ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ║${NC}                                                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Power menu
show_power_menu() {
    clear
    show_fire_banner
    echo -e "${RED}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}    ║${NC}              ${BOLD}⏻  POWER OPTIONS ⏻${NC}                       ${RED}║${NC}"
    echo -e "${RED}    ╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}    ║${NC}   ${YELLOW}1.${NC} 🔄 Reboot                                        ${RED}║${NC}"
    echo -e "${RED}    ║${NC}   ${YELLOW}2.${NC} ⏹️  Shutdown                                      ${RED}║${NC}"
    echo -e "${RED}    ║${NC}   ${YELLOW}3.${NC} 😴 Suspend                                       ${RED}║${NC}"
    echo -e "${RED}    ║${NC}   ${GREEN}B.${NC} 🔙 Back                                          ${RED}║${NC}"
    echo -e "${RED}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}    Select option: ${NC}"

    read -n 1 power_choice
    echo ""

    case "$power_choice" in
        1)
            echo -e "${ORANGE}    🔄 Rebooting in 3 seconds... (Ctrl+C to cancel)${NC}"
            sleep 3
            doas reboot
            ;;
        2)
            echo -e "${RED}    ⏹️  Shutting down in 3 seconds... (Ctrl+C to cancel)${NC}"
            sleep 3
            doas poweroff
            ;;
        3)
            echo -e "${CYAN}    😴 Suspending...${NC}"
            sleep 1
            doas zzz 2>/dev/null || doas pm-suspend 2>/dev/null || echo "Suspend not available"
            ;;
        *)
            return
            ;;
    esac
}

# Settings menu
show_settings_menu() {
    clear
    show_fire_banner
    echo -e "${CYAN}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}    ║${NC}              ${BOLD}⚙️  SYSTEM SETTINGS ⚙️${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}    ╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}1.${NC} 🔔 Notification Manager                          ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}2.${NC} 🔊 Volume Control                                ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}3.${NC} 🌐 Network Settings                              ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}4.${NC} 🛡️  Security Fortress                            ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}5.${NC} 💾 Backup System                                 ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${GREEN}B.${NC} 🔙 Back                                          ${CYAN}║${NC}"
    echo -e "${CYAN}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}    Select option: ${NC}"

    read -n 1 settings_choice
    echo ""

    case "$settings_choice" in
        1) ~/secure_notify_manager.sh status ;;
        2) [ -x "$SCRIPT_DIR/volume_control.sh" ] && "$SCRIPT_DIR/volume_control.sh" ;;
        3) nmtui 2>/dev/null || echo "nmtui not available" ;;
        4) [ -x "$SCRIPT_DIR/nexus-security-fortress.sh" ] && "$SCRIPT_DIR/nexus-security-fortress.sh" ;;
        5) [ -x "$SCRIPT_DIR/nexus-backup-system.sh" ] && "$SCRIPT_DIR/nexus-backup-system.sh" ;;
        *) return ;;
    esac

    echo ""
    echo -e "${YELLOW}    Press any key to continue...${NC}"
    read -n 1
}

# Framebuffer session picker
show_framebuffer_menu() {
    clear
    show_fire_banner
    echo -e "${GREEN}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}    ║${NC}              ${BOLD}📺 FRAMEBUFFER APPS 📺${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}           ${CYAN}Direct rendering on /dev/fb0${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}    ╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}    ║${NC}                                                        ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}1.${NC} 🖥️  QTerminal            ${CYAN}(terminal emulator)${NC}   ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}2.${NC} 📝 Kate                  ${CYAN}(text editor)${NC}         ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}3.${NC} 🪶 FeatherPad            ${CYAN}(lightweight editor)${NC}  ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}4.${NC} 📁 PCManFM-Qt            ${CYAN}(file manager)${NC}        ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}5.${NC} ⚙️  Qt Platform Launcher  ${CYAN}(pick any app)${NC}        ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${YELLOW}6.${NC} 🖼️  Kmscon Enhanced       ${CYAN}(GPU terminal)${NC}        ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}                                                        ${GREEN}║${NC}"
    echo -e "${GREEN}    ║${NC}   ${RED}B.${NC} 🔙 Back                                          ${GREEN}║${NC}"
    echo -e "${GREEN}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}    Select framebuffer app: ${NC}"

    read -n 1 fb_choice
    echo ""

    local fb_opts="--platform linuxfb:fb=/dev/fb0"

    case "$fb_choice" in
        1)
            echo -e "${GREEN}    🖥️  Launching QTerminal on framebuffer...${NC}"
            sleep 1
            tput cnorm
            if command -v qterminal >/dev/null; then
                exec qterminal $fb_opts
            else
                echo -e "${RED}    QTerminal not installed${NC}"
                sleep 2
            fi
            ;;
        2)
            echo -e "${GREEN}    📝 Launching Kate on framebuffer...${NC}"
            sleep 1
            tput cnorm
            if command -v kate >/dev/null; then
                exec kate $fb_opts
            else
                echo -e "${RED}    Kate not installed${NC}"
                sleep 2
            fi
            ;;
        3)
            echo -e "${GREEN}    🪶 Launching FeatherPad on framebuffer...${NC}"
            sleep 1
            tput cnorm
            if command -v featherpad >/dev/null; then
                exec featherpad $fb_opts
            else
                echo -e "${RED}    FeatherPad not installed${NC}"
                sleep 2
            fi
            ;;
        4)
            echo -e "${GREEN}    📁 Launching PCManFM-Qt on framebuffer...${NC}"
            sleep 1
            tput cnorm
            if command -v pcmanfm-qt >/dev/null; then
                exec pcmanfm-qt $fb_opts
            else
                echo -e "${RED}    PCManFM-Qt not installed${NC}"
                sleep 2
            fi
            ;;
        5)
            if [ -x "$SCRIPT_DIR/qt-platform-launcher.sh" ]; then
                tput cnorm
                exec "$SCRIPT_DIR/qt-platform-launcher.sh"
            else
                echo -e "${RED}    Qt Platform Launcher not found${NC}"
                sleep 2
            fi
            ;;
        6)
            echo -e "${GREEN}    🖼️  Launching Kmscon enhanced terminal...${NC}"
            sleep 1
            tput cnorm
            # Try without doas first (may work if user has permissions)
            # Then try with doas if needed
            if kmscon --help >/dev/null 2>&1; then
                # Check if we can run without root
                /usr/bin/kmscon --no-drm --font-name "DejaVu Sans Mono" --font-size 16 2>/dev/null && exit 0
            fi
            # Need root - inform user and try with doas
            echo -e "${YELLOW}    Kmscon requires root access...${NC}"
            echo -e "${YELLOW}    You may need to enter your password.${NC}"
            echo ""
            # Use script to provide a TTY for doas
            exec script -qc "doas /usr/bin/kmscon --no-drm --font-name 'DejaVu Sans Mono' --font-size 16" /dev/null
            ;;
        [Bb])
            return
            ;;
        *)
            echo -e "${RED}    Invalid option${NC}"
            sleep 1
            ;;
    esac
}

# Wayland session picker
show_wayland_menu() {
    clear
    show_fire_banner
    echo -e "${CYAN}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}    ║${NC}              ${BOLD}🖥️  WAYLAND SESSIONS 🖥️${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}    ╠════════════════════════════════════════════════════════╣${NC}"

    local i=1
    for session in "${WAYLAND_SESSIONS[@]}"; do
        local icon="🌊"
        case "$session" in
            labwc) icon="🏷️" ;;
            sway) icon="🌀" ;;
            wayfire) icon="🔥" ;;
            hyprland) icon="💎" ;;
            river) icon="🌊" ;;
            dwl) icon="🎯" ;;
            niri) icon="✨" ;;
            kwin_wayland) icon="🦎" ;;
            lxqt-wayland) icon="🖼️" ;;
        esac
        printf "${CYAN}    ║${NC}   ${GREEN}%d.${NC} %s %-18s                           ${CYAN}║${NC}\n" "$i" "$icon" "$session"
        ((i++))
    done

    echo -e "${CYAN}    ║${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}    ║${NC}   ${RED}B.${NC} 🔙 Back                                          ${CYAN}║${NC}"
    echo -e "${CYAN}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}    Select Wayland session: ${NC}"

    read -n 1 wl_choice
    echo ""

    if [[ "$wl_choice" =~ ^[Bb]$ ]]; then
        return
    fi

    if [[ "$wl_choice" =~ ^[0-9]+$ ]] && [ "$wl_choice" -ge 1 ] && [ "$wl_choice" -le "${#WAYLAND_SESSIONS[@]}" ]; then
        local selected="${WAYLAND_SESSIONS[$((wl_choice-1))]}"
        echo -e "${GREEN}    🖥️  Launching ${selected}...${NC}"
        sleep 1
        tput cnorm

        case "$selected" in
            lxqt-wayland)
                export XDG_SESSION_TYPE=wayland
                exec startlxqtwayland
                ;;
            kwin_wayland)
                exec startplasma-wayland 2>/dev/null || exec kwin_wayland
                ;;
            *)
                exec "$selected"
                ;;
        esac
    fi
}

# X11 session picker
show_x11_menu() {
    clear
    show_fire_banner
    echo -e "${MAGENTA}    ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}    ║${NC}              ${BOLD}📺 X11 SESSIONS 📺${NC}                       ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}    ╠════════════════════════════════════════════════════════╣${NC}"

    local i=1
    for session in "${X11_SESSIONS[@]}"; do
        local icon="📺"
        case "$session" in
            lxqt) icon="🖼️" ;;
            mate) icon="🧉" ;;
            openbox) icon="📦" ;;
            sxmo) icon="📱" ;;
        esac
        printf "${MAGENTA}    ║${NC}   ${GREEN}%d.${NC} %s %-18s                           ${MAGENTA}║${NC}\n" "$i" "$icon" "$session"
        ((i++))
    done

    echo -e "${MAGENTA}    ║${NC}                                                        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}    ║${NC}   ${RED}B.${NC} 🔙 Back                                          ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}    ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${YELLOW}    Select X11 session: ${NC}"

    read -n 1 x11_choice
    echo ""

    if [[ "$x11_choice" =~ ^[Bb]$ ]]; then
        return
    fi

    if [[ "$x11_choice" =~ ^[0-9]+$ ]] && [ "$x11_choice" -ge 1 ] && [ "$x11_choice" -le "${#X11_SESSIONS[@]}" ]; then
        local selected="${X11_SESSIONS[$((x11_choice-1))]}"
        echo -e "${GREEN}    📺 Launching ${selected}...${NC}"
        sleep 1
        tput cnorm

        export XDG_SESSION_TYPE=x11
        case "$selected" in
            lxqt)
                exec startlxqt
                ;;
            mate)
                exec mate-session
                ;;
            openbox)
                exec openbox-session
                ;;
            sxmo)
                exec sxmo-x11
                ;;
            *)
                exec startx
                ;;
        esac
    fi
}

# Launch session
launch_session() {
    local choice="$1"

    case "$choice" in
        1)
            echo -e "${GREEN}    🌀 Launching NeXuS TUI Desktop...${NC}"
            sleep 1
            tput cnorm
            if [ -x "$SCRIPT_DIR/nexus" ]; then
                exec "$SCRIPT_DIR/nexus"
            elif [ -x "$SCRIPT_DIR/nexus-tui-desktop.sh" ]; then
                exec "$SCRIPT_DIR/nexus-tui-desktop.sh"
            else
                echo -e "${RED}    NeXuS TUI not found, launching shell...${NC}"
                exec zsh
            fi
            ;;
        2)
            if [ ${#WAYLAND_SESSIONS[@]} -eq 0 ]; then
                echo -e "${RED}    No Wayland sessions detected${NC}"
                sleep 2
                return
            elif [ ${#WAYLAND_SESSIONS[@]} -eq 1 ]; then
                echo -e "${GREEN}    🖥️  Launching ${WAYLAND_SESSIONS[0]}...${NC}"
                sleep 1
                tput cnorm
                exec "${WAYLAND_SESSIONS[0]}"
            else
                show_wayland_menu
            fi
            ;;
        3)
            if [ ${#X11_SESSIONS[@]} -eq 0 ]; then
                echo -e "${RED}    No X11 sessions detected${NC}"
                sleep 2
                return
            elif [ ${#X11_SESSIONS[@]} -eq 1 ]; then
                echo -e "${GREEN}    📺 Launching ${X11_SESSIONS[0]}...${NC}"
                sleep 1
                tput cnorm
                exec startx
            else
                show_x11_menu
            fi
            ;;
        4)
            echo -e "${GREEN}    🐚 Launching Shell...${NC}"
            sleep 1
            tput cnorm
            clear
            exec zsh
            ;;
        5)
            show_framebuffer_menu
            ;;
    esac
}

# Main loop
main() {
    # Detect available sessions
    detect_sessions

    # Show fire splash on first run
    if [ "$1" != "--no-splash" ]; then
        show_fire_splash
    fi

    while true; do
        show_fire_banner
        show_system_info
        show_menu

        echo -ne "${YELLOW}    🔥 Select option: ${NC}"
        read -n 1 choice
        echo ""

        case "$choice" in
            1|2|3|4|5)
                launch_session "$choice"
                ;;
            [Ff])
                echo -e "${ORANGE}    🔥 Launching fire animation (Ctrl+C to exit)...${NC}"
                sleep 1
                tput cnorm
                cacafire 2>/dev/null || aafire 2>/dev/null || echo "No fire animation available"
                tput civis
                ;;
            [Ss])
                show_settings_menu
                ;;
            [Pp])
                show_power_menu
                ;;
            [Qq])
                echo -e "${GREEN}    👋 Goodbye from NeXuS Fire Login!${NC}"
                sleep 1
                cleanup
                ;;
            *)
                echo -e "${RED}    Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Entry point
main "$@"
