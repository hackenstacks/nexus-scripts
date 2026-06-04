#!/bin/bash
# 🔥 NeXuS Ultimate Script Launcher 🌀
# Advanced TUI script management system with intelligent environment detection
# 
# Features: List, Search, Launch, Edit with auto-editor detection
# Supports: CLI-only, GUI, and framebuffer environments

# NeXuS Colors and Symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Beautiful NeXuS symbols
NEXUS_SYMBOL="🌀"
FIRE_SYMBOL="🔥"
ROCKET_SYMBOL="🚀"
GEAR_SYMBOL="⚙️"
SEARCH_SYMBOL="🔍"
EDIT_SYMBOL="✏️"
LIST_SYMBOL="📋"
LAUNCH_SYMBOL="🎯"
EXIT_SYMBOL="🚪"
SCRIPT_SYMBOL="📜"
SUCCESS_SYMBOL="✅"
ERROR_SYMBOL="❌"
INFO_SYMBOL="💡"

# Configuration
SCRIPTS_DIR="/home/user/scripts"
TEMP_DIR="/tmp/nexus-launcher"
SEARCH_CACHE="$TEMP_DIR/search_cache"
SCRIPT_LIST="$TEMP_DIR/script_list"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Print colored text
print_color() {
    echo -e "${1}${2}${NC}"
}

# Print centered text
print_centered() {
    local text="$1"
    local color="$2"
    local width=70
    local padding=$(((width - ${#text}) / 2))
    printf "%*s" $padding
    print_color "$color" "$text"
}

# Detect environment capabilities
detect_environment() {
    local has_x11=false
    local has_wayland=false
    local has_display=false
    
    # Check for X11
    if [ -n "$DISPLAY" ] && command -v xset >/dev/null 2>&1; then
        if xset q >/dev/null 2>&1; then
            has_x11=true
            has_display=true
        fi
    fi
    
    # Check for Wayland
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wayland-info >/dev/null 2>&1; then
        has_wayland=true
        has_display=true
    fi
    
    echo "x11:$has_x11,wayland:$has_wayland,display:$has_display"
}

# Get available editors based on environment
get_available_editors() {
    local env_info="$1"
    local has_display=$(echo "$env_info" | grep -o "display:[^,]*" | cut -d: -f2)
    local editors=()
    
    # CLI editors (always available)
    command -v micro >/dev/null 2>&1 && editors+=("micro")
    command -v nano >/dev/null 2>&1 && editors+=("nano")
    command -v vim >/dev/null 2>&1 && editors+=("vim")
    command -v vi >/dev/null 2>&1 && editors+=("vi")
    
    # GUI editors
    if [ "$has_display" = "true" ]; then
        command -v kwrite >/dev/null 2>&1 && editors+=("kwrite")
        command -v notepadqq >/dev/null 2>&1 && editors+=("notepadqq")
        command -v gedit >/dev/null 2>&1 && editors+=("gedit")
        command -v kate >/dev/null 2>&1 && editors+=("kate")
    fi
    
    # Framebuffer editors (Qt apps with linuxfb)
    if command -v kwrite >/dev/null 2>&1; then
        editors+=("kwrite-fb")
    fi
    if command -v notepadqq >/dev/null 2>&1; then
        editors+=("notepadqq-fb")
    fi
    
    printf "%s\n" "${editors[@]}"
}

# Launch editor with environment detection
launch_editor() {
    local file="$1"
    local editor="$2"
    
    case "$editor" in
        "kwrite-fb")
            print_color "$INFO_SYMBOL $CYAN" "Launching KWrite in framebuffer mode..."
            kwrite --platform linuxfb "$file" 2>/dev/null &
            ;;
        "notepadqq-fb")
            print_color "$INFO_SYMBOL $CYAN" "Launching Notepadqq in framebuffer mode..."
            notepadqq --platform linuxfb "$file" 2>/dev/null &
            ;;
        "micro"|"nano"|"vim"|"vi")
            clear
            print_color "$INFO_SYMBOL $CYAN" "Launching $editor..."
            sleep 0.5
            "$editor" "$file"
            ;;
        *)
            print_color "$INFO_SYMBOL $CYAN" "Launching $editor..."
            "$editor" "$file" 2>/dev/null &
            ;;
    esac
}

# Show beautiful banner
show_banner() {
    clear
    print_color "$CYAN" "╔══════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                                                                  ║"
    print_color "$CYAN" "║  ${FIRE_SYMBOL}${NEXUS_SYMBOL} ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗ ${NEXUS_SYMBOL}${FIRE_SYMBOL}        ║"
    print_color "$CYAN" "║  ${SCRIPT_SYMBOL}  ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝  ${SCRIPT_SYMBOL}        ║"
    print_color "$CYAN" "║  ${GEAR_SYMBOL}  ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗  ${GEAR_SYMBOL}        ║"
    print_color "$CYAN" "║  ${ROCKET_SYMBOL}  ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║  ${ROCKET_SYMBOL}        ║"
    print_color "$CYAN" "║  ${LAUNCH_SYMBOL}  ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║  ${LAUNCH_SYMBOL}        ║"
    print_color "$CYAN" "║     ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝           ║"
    print_color "$CYAN" "║                                                                  ║"
    print_color "$CYAN" "║           ${BOLD}${YELLOW}Ultimate Script Launcher & Manager${NC}${CYAN}              ║"
    print_color "$CYAN" "║              ${WHITE}Intelligent Environment Detection${NC}${CYAN}               ║"
    print_color "$CYAN" "║                                                                  ║"
    print_color "$CYAN" "╚══════════════════════════════════════════════════════════════════╝"
    echo
}

# Get all scripts
get_all_scripts() {
    find "$SCRIPTS_DIR" -name "*.sh" -o -name "*.py" -o -name "*.js" -o -type f -executable | \
    grep -v "backup" | grep -v "\.git" | sort > "$SCRIPT_LIST"
}

# Display numbered script list
show_numbered_scripts() {
    local scripts_file="$1"
    local title="$2"
    
    echo
    print_color "$BOLD$CYAN" "╔═══ $title ═══╗"
    echo
    
    local count=1
    while IFS= read -r script; do
        local basename=$(basename "$script")
        local description=""
        
        # Try to extract description from script
        if [[ "$script" == *.sh ]]; then
            description=$(head -n 10 "$script" | grep -i "^#.*[Dd]escription\|^# .*" | head -n 1 | sed 's/^#[[:space:]]*//' | cut -c1-40)
        fi
        
        if [ -z "$description" ]; then
            description="Script file"
        fi
        
        printf "${GREEN}%2d${NC}) ${YELLOW}%-30s${NC} ${DIM}%s${NC}\n" "$count" "$basename" "$description"
        count=$((count + 1))
    done < "$scripts_file"
    echo
}

# Search scripts
search_scripts() {
    local search_term="$1"
    print_color "$SEARCH_SYMBOL $CYAN" "Searching for: $search_term"
    
    grep -i "$search_term" "$SCRIPT_LIST" > "$SEARCH_CACHE"
    
    if [ -s "$SEARCH_CACHE" ]; then
        show_numbered_scripts "$SEARCH_CACHE" "Search Results for '$search_term'"
        return 0
    else
        print_color "$ERROR_SYMBOL $RED" "No scripts found matching '$search_term'"
        return 1
    fi
}

# Select script from numbered list
select_script_from_list() {
    local scripts_file="$1"
    local prompt="$2"
    
    print_color "$LAUNCH_SYMBOL $YELLOW" "$prompt"
    read -p "Enter number: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        local script=$(sed -n "${selection}p" "$scripts_file")
        if [ -n "$script" ]; then
            echo "$script"
            return 0
        fi
    fi
    
    print_color "$ERROR_SYMBOL $RED" "Invalid selection!"
    return 1
}

# Launch script
launch_script() {
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        print_color "$ERROR_SYMBOL $RED" "Script not found: $script_path"
        return 1
    fi
    
    local basename=$(basename "$script_path")
    print_color "$ROCKET_SYMBOL $GREEN" "Launching: $basename"
    
    # Make executable if needed
    chmod +x "$script_path" 2>/dev/null
    
    # Launch based on file type
    case "$script_path" in
        *.py)
            python3 "$script_path"
            ;;
        *.js)
            node "$script_path"
            ;;
        *)
            "$script_path"
            ;;
    esac
}

# Edit script
edit_script() {
    local scripts_file="$1"
    
    show_numbered_scripts "$scripts_file" "Select Script to Edit"
    
    local script_path
    script_path=$(select_script_from_list "$scripts_file" "Select script to edit:")
    
    if [ $? -eq 0 ]; then
        local env_info=$(detect_environment)
        local editors=($(get_available_editors "$env_info"))
        
        if [ ${#editors[@]} -eq 0 ]; then
            print_color "$ERROR_SYMBOL $RED" "No editors available!"
            return 1
        fi
        
        echo
        print_color "$EDIT_SYMBOL $CYAN" "Available Editors:"
        for i in "${!editors[@]}"; do
            local editor="${editors[$i]}"
            local desc=""
            case "$editor" in
                *-fb) desc=" (Framebuffer Mode)" ;;
                micro|nano|vim|vi) desc=" (Terminal)" ;;
                *) desc=" (GUI)" ;;
            esac
            printf "${GREEN}%d${NC}) ${YELLOW}%s${NC}${DIM}%s${NC}\n" $((i+1)) "$editor" "$desc"
        done
        
        echo
        read -p "Select editor (1-${#editors[@]}): " editor_choice
        
        if [[ "$editor_choice" =~ ^[0-9]+$ ]] && [ "$editor_choice" -ge 1 ] && [ "$editor_choice" -le "${#editors[@]}" ]; then
            local selected_editor="${editors[$((editor_choice-1))]}"
            launch_editor "$script_path" "$selected_editor"
        else
            print_color "$ERROR_SYMBOL $RED" "Invalid editor selection!"
        fi
    fi
}

# Main menu
show_main_menu() {
    local env_info=$(detect_environment)
    local has_display=$(echo "$env_info" | grep -o "display:[^,]*" | cut -d: -f2)
    
    echo
    print_color "$BOLD$WHITE" "╔═══════════════════════════════════════════════════════════════╗"
    print_color "$BOLD$WHITE" "║                        MAIN MENU                             ║"
    print_color "$BOLD$WHITE" "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    printf "${GREEN}1${NC}) ${LIST_SYMBOL} ${YELLOW}List All Scripts${NC}           ${DIM}Browse complete script collection${NC}\n"
    printf "${GREEN}2${NC}) ${SEARCH_SYMBOL} ${YELLOW}Search Scripts${NC}            ${DIM}Find scripts by name or content${NC}\n"
    printf "${GREEN}3${NC}) ${LAUNCH_SYMBOL} ${YELLOW}Launch Script${NC}             ${DIM}Execute script by name${NC}\n"
    printf "${GREEN}4${NC}) ${EDIT_SYMBOL} ${YELLOW}Edit Script${NC}               ${DIM}Modify scripts with smart editor${NC}\n"
    printf "${GREEN}5${NC}) ${INFO_SYMBOL} ${YELLOW}Environment Info${NC}          ${DIM}Display system capabilities${NC}\n"
    printf "${GREEN}6${NC}) ${EXIT_SYMBOL} ${YELLOW}Exit${NC}                      ${DIM}Return to NeXuS${NC}\n"
    
    echo
    print_color "$DIM" "Environment: Display=$has_display | Scripts: $(wc -l < "$SCRIPT_LIST") found"
    echo
}

# Show environment info
show_environment_info() {
    local env_info=$(detect_environment)
    local has_x11=$(echo "$env_info" | grep -o "x11:[^,]*" | cut -d: -f2)
    local has_wayland=$(echo "$env_info" | grep -o "wayland:[^,]*" | cut -d: -f2)
    local has_display=$(echo "$env_info" | grep -o "display:[^,]*" | cut -d: -f2)
    
    echo
    print_color "$BOLD$CYAN" "╔═══ ENVIRONMENT CAPABILITIES ═══╗"
    echo
    print_color "$INFO_SYMBOL $WHITE" "Display Systems:"
    printf "  X11:     ${GREEN}%s${NC}\n" "$has_x11"
    printf "  Wayland: ${GREEN}%s${NC}\n" "$has_wayland"
    printf "  Display: ${GREEN}%s${NC}\n" "$has_display"
    
    echo
    print_color "$INFO_SYMBOL $WHITE" "Available Editors:"
    local editors=($(get_available_editors "$env_info"))
    for editor in "${editors[@]}"; do
        printf "  ${GREEN}✓${NC} %s\n" "$editor"
    done
    
    echo
    print_color "$INFO_SYMBOL $WHITE" "Script Directory: $SCRIPTS_DIR"
    print_color "$INFO_SYMBOL $WHITE" "Total Scripts: $(wc -l < "$SCRIPT_LIST")"
    echo
}

# Main program loop
main() {
    # Initialize
    get_all_scripts
    
    while true; do
        show_banner
        show_main_menu
        
        read -p "Select option (1-6): " choice
        
        case "$choice" in
            1)
                show_numbered_scripts "$SCRIPT_LIST" "All Available Scripts"
                read -p "Press Enter to continue..."
                ;;
            2)
                echo
                read -p "Enter search term: " search_term
                if [ -n "$search_term" ]; then
                    if search_scripts "$search_term"; then
                        echo
                        read -p "Launch a script from results? (y/N): " launch_choice
                        if [[ "$launch_choice" =~ ^[Yy]$ ]]; then
                            local script_path
                            script_path=$(select_script_from_list "$SEARCH_CACHE" "Select script to launch:")
                            if [ $? -eq 0 ]; then
                                launch_script "$script_path"
                                read -p "Press Enter to continue..."
                            fi
                        fi
                    fi
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                echo
                read -p "Enter script name (partial match OK): " script_name
                if [ -n "$script_name" ]; then
                    local found_script=$(grep -i "$script_name" "$SCRIPT_LIST" | head -n 1)
                    if [ -n "$found_script" ]; then
                        launch_script "$found_script"
                    else
                        print_color "$ERROR_SYMBOL $RED" "Script not found: $script_name"
                    fi
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                edit_script "$SCRIPT_LIST"
                read -p "Press Enter to continue..."
                ;;
            5)
                show_environment_info
                read -p "Press Enter to continue..."
                ;;
            6)
                print_color "$SUCCESS_SYMBOL $GREEN" "Returning to NeXuS ecosystem..."
                break
                ;;
            *)
                print_color "$ERROR_SYMBOL $RED" "Invalid option! Please select 1-6."
                sleep 1
                ;;
        esac
    done
    
    # Cleanup
    rm -f "$SEARCH_CACHE" "$SCRIPT_LIST"
}

# Run the main program
main "$@"