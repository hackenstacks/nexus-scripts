#!/bin/bash
# 🌈✨ NEXUS BEAUTIFUL WIKI LAUNCHER ✨🌈
# Launch the most gorgeous wiki system in the universe!

set -e

# 🎨 Beautiful colors and effects 🎨
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
PINK='\033[1;95m'
LIME='\033[1;92m'
BRIGHT_BLUE='\033[1;94m'

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# 🌟 Beautiful banner 🌟
show_banner() {
    # Only clear if we're in an interactive terminal
    if [[ -t 1 ]] && [[ "$TERM" != "dumb" ]]; then
        clear
    fi
    echo -e "${BRIGHT_BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║              🌈✨ NEXUS BEAUTIFUL WIKI LAUNCHER ✨🌈                        ║"
    echo "║                                                                              ║"
    echo "║                    🚀 The Most Gorgeous Wiki System 🚀                      ║"
    echo "║                          🌟 In The Universe! 🌟                             ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
}

# 🎨 Beautiful logging 🎨
log_beautiful() {
    local level="$1"
    local message="$2"
    local emoji=""
    local color=""
    
    case "$level" in
        "SUCCESS") emoji="🎉"; color="$GREEN" ;;
        "INFO") emoji="ℹ️"; color="$BRIGHT_BLUE" ;;
        "WARNING") emoji="⚠️"; color="$YELLOW" ;;
        "ERROR") emoji="❌"; color="$RED" ;;
        "MAGIC") emoji="✨"; color="$PURPLE" ;;
        "ROCKET") emoji="🚀"; color="$CYAN" ;;
    esac
    
    echo -e "${BOLD}${color}[$emoji $level$emoji]${RESET} ${WHITE}$message${RESET}"
}

# 🎆 Animated progress 🎆
show_progress() {
    local message="$1"
    local duration="${2:-3}"
    local spinners="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local colors=("$RED" "$YELLOW" "$GREEN" "$CYAN" "$BLUE" "$PURPLE")
    
    echo -n -e "${BOLD}${BRIGHT_BLUE}$message ${RESET}"
    
    for ((i=0; i<duration*10; i++)); do
        local spinner_char="${spinners:$((i % ${#spinners})):1}"
        local color="${colors[$((i % ${#colors[@]}))%6]}"
        echo -n -e "${color}${BOLD}$spinner_char${RESET}"
        sleep 0.1
        echo -n -e "\b"
    done
    
    echo -e "${GREEN}${BOLD}✅${RESET}"
}

# 🌟 Setup beautiful environment 🌟
setup_beautiful_environment() {
    log_beautiful "MAGIC" "🎨 Setting up the most beautiful wiki environment"
    
    # Create necessary directories
    mkdir -p ~/.nb/themes
    mkdir -p /tmp/beautiful_wiki
    
    # Install custom theme if not present
    if [[ ! -f ~/.nb/themes/nexus_beautiful.css ]]; then
        log_beautiful "INFO" "📦 Installing gorgeous Nexus Beautiful theme"
        show_progress "💄 Applying beautiful styling magic" 2
        
        # Theme should already be created by the previous script
        if [[ -f /home/user/.nb/themes/nexus_beautiful.css ]]; then
            log_beautiful "SUCCESS" "🎨 Beautiful theme installed successfully!"
        else
            log_beautiful "WARNING" "⚠️ Theme file not found, using default styling"
        fi
    fi
    
    # Check if beautiful monitor exists
    if [[ ! -f /home/user/scripts/beautiful_wiki_monitor.sh ]]; then
        log_beautiful "ERROR" "❌ Beautiful wiki monitor not found!"
        echo -e "${YELLOW}Please run the beautiful wiki setup first:${RESET}"
        echo -e "${CYAN}  ~/scripts/install_wiki_automation.sh${RESET}"
        exit 1
    fi
    
    log_beautiful "SUCCESS" "🌟 Beautiful environment ready!"
}

# 🚀 Launch beautiful wiki server 🚀
launch_beautiful_server() {
    log_beautiful "ROCKET" "🚀 Launching the most gorgeous wiki server"
    
    show_progress "🌐 Starting beautiful NB server" 3
    
    # Check if server is already running
    if curl -s http://localhost:6789 > /dev/null 2>&1; then
        log_beautiful "SUCCESS" "🌟 Beautiful wiki server already running!"
    else
        log_beautiful "INFO" "🔧 Starting new beautiful server instance"
        
        # Start NB server in background
        nohup nb browse --serve > /tmp/beautiful_wiki/server.log 2>&1 &
        sleep 3
        
        if curl -s http://localhost:6789 > /dev/null 2>&1; then
            log_beautiful "SUCCESS" "🎉 Beautiful wiki server launched successfully!"
        else
            log_beautiful "ERROR" "❌ Failed to launch beautiful server"
            return 1
        fi
    fi
    
    # Apply beautiful theme
    log_beautiful "MAGIC" "🎨 Applying gorgeous styling magic"
    show_progress "💅 Beautiful theme activation" 2
    
    log_beautiful "SUCCESS" "✨ Wiki server is now GORGEOUS and ready!"
    echo ""
    echo -e "${BOLD}${BRIGHT_BLUE}🌐 Access your beautiful wiki at:${RESET}"
    echo -e "${BOLD}${GREEN}   👉 http://localhost:6789${RESET}"
    echo ""
}

# 🎨 Launch beautiful monitoring 🎨
launch_beautiful_monitoring() {
    log_beautiful "MAGIC" "🎯 Launching beautiful auto-import monitoring"
    
    # Check if monitor is already running
    if /home/user/scripts/beautiful_wiki_monitor.sh status &>/dev/null; then
        log_beautiful "SUCCESS" "🌟 Beautiful monitor already running!"
    else
        log_beautiful "INFO" "🚀 Starting beautiful monitoring daemon"
        show_progress "👁️ Activating beautiful file watching magic" 3
        
        # Start beautiful monitor in background
        nohup /home/user/scripts/beautiful_wiki_monitor.sh start > /tmp/beautiful_wiki/monitor.log 2>&1 &
        sleep 2
        
        if /home/user/scripts/beautiful_wiki_monitor.sh status &>/dev/null; then
            log_beautiful "SUCCESS" "🎉 Beautiful monitoring activated!"
        else
            log_beautiful "WARNING" "⚠️ Monitor may need manual activation"
        fi
    fi
}

# 🌈 Show beautiful status 🌈
show_beautiful_status() {
    show_banner
    
    log_beautiful "INFO" "📊 BEAUTIFUL WIKI SYSTEM STATUS"
    echo ""
    
    # Check server status
    if curl -s http://localhost:6789 > /dev/null 2>&1; then
        log_beautiful "SUCCESS" "🌐 Wiki Server: GORGEOUSLY RUNNING ✨"
        echo -e "   ${CYAN}URL: ${BOLD}http://localhost:6789${RESET}"
    else
        log_beautiful "ERROR" "🌐 Wiki Server: NOT RUNNING"
    fi
    
    # Check monitor status
    if /home/user/scripts/beautiful_wiki_monitor.sh status &>/dev/null; then
        log_beautiful "SUCCESS" "👁️ Auto-Monitor: BEAUTIFULLY WATCHING ✨"
    else
        log_beautiful "ERROR" "👁️ Auto-Monitor: NOT RUNNING"
    fi
    
    # Show beautiful statistics
    echo ""
    log_beautiful "MAGIC" "📈 BEAUTIFUL STATISTICS"
    
    # Count notebooks
    if command -v nb >/dev/null 2>&1; then
        local notebooks=$(nb notebooks 2>/dev/null | wc -l || echo "0")
        echo -e "   ${PURPLE}📚 Notebooks: ${BOLD}$notebooks${RESET}"
        
        # Count total entries
        local total_entries=0
        for notebook in $(nb notebooks 2>/dev/null); do
            local count=$(nb use "$notebook" && nb list --no-color 2>/dev/null | wc -l || echo "0")
            total_entries=$((total_entries + count))
        done
        echo -e "   ${GREEN}📄 Total Entries: ${BOLD}$total_entries${RESET}"
    fi
    
    echo ""
    log_beautiful "INFO" "🎆 Your beautiful wiki is ready to serve gorgeous knowledge!"
}

# 🎊 Beautiful quick actions 🎊
show_beautiful_menu() {
    show_banner
    
    echo -e "${BOLD}${BRIGHT_BLUE}✨ BEAUTIFUL WIKI QUICK ACTIONS ✨${RESET}"
    echo ""
    echo -e "${BOLD}${GREEN}1.${RESET} 🚀 Launch Complete Beautiful System"
    echo -e "${BOLD}${GREEN}2.${RESET} 🌐 Start Beautiful Wiki Server Only"
    echo -e "${BOLD}${GREEN}3.${RESET} 👁️ Start Beautiful Monitoring Only"
    echo -e "${BOLD}${GREEN}4.${RESET} 📊 Show Beautiful Status"
    echo -e "${BOLD}${GREEN}5.${RESET} 🧪 Run Beautiful Tests"
    echo -e "${BOLD}${GREEN}6.${RESET} 🛑 Stop All Beautiful Services"
    echo -e "${BOLD}${GREEN}7.${RESET} 🌈 Open Beautiful Wiki in Browser"
    echo -e "${BOLD}${GREEN}8.${RESET} ❓ Beautiful Help"
    echo ""
    echo -n -e "${BOLD}${CYAN}Choose your beautiful adventure (1-8): ${RESET}"
    
    read -r choice
    
    case "$choice" in
        1)
            log_beautiful "ROCKET" "🚀 Launching COMPLETE beautiful system!"
            setup_beautiful_environment
            launch_beautiful_server
            launch_beautiful_monitoring
            show_beautiful_status
            ;;
        2)
            setup_beautiful_environment
            launch_beautiful_server
            ;;
        3)
            launch_beautiful_monitoring
            ;;
        4)
            show_beautiful_status
            ;;
        5)
            log_beautiful "MAGIC" "🧪 Running beautiful tests"
            /home/user/scripts/beautiful_wiki_monitor.sh test
            ;;
        6)
            log_beautiful "INFO" "🛑 Stopping all beautiful services"
            /home/user/scripts/beautiful_wiki_monitor.sh stop 2>/dev/null || true
            pkill -f "nb browse --serve" 2>/dev/null || true
            log_beautiful "SUCCESS" "😴 All services stopped gracefully"
            ;;
        7)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open http://localhost:6789 2>/dev/null &
            elif command -v open >/dev/null 2>&1; then
                open http://localhost:6789 2>/dev/null &
            else
                log_beautiful "INFO" "🌐 Please open: http://localhost:6789"
            fi
            ;;
        8)
            show_beautiful_help
            ;;
        *)
            log_beautiful "WARNING" "⚠️ Invalid choice. Please select 1-8"
            sleep 2
            show_beautiful_menu
            ;;
    esac
}

# 🎆 Beautiful help 🎆
show_beautiful_help() {
    show_banner
    
    echo -e "${BOLD}${BRIGHT_BLUE}💡 BEAUTIFUL WIKI HELP 💡${RESET}"
    echo ""
    echo -e "${BOLD}${GREEN}🌟 What is this magical system?${RESET}"
    echo -e "   This is the most gorgeous wiki system ever created!"
    echo -e "   It automatically imports your documentation and makes it beautiful."
    echo ""
    echo -e "${BOLD}${GREEN}🚀 Quick Start:${RESET}"
    echo -e "   1. Choose option 1 to launch the complete system"
    echo -e "   2. Visit http://localhost:6789 for beautiful wiki"
    echo -e "   3. Add new docs to watched folders - they auto-import!"
    echo ""
    echo -e "${BOLD}${GREEN}📂 Watched Directories:${RESET}"
    echo -e "   • /home/user/manuals"
    echo -e "   • /home/user/claude/documents" 
    echo -e "   • /home/user/ai-character-generator"
    echo -e "   • /home/user/Projects"
    echo ""
    echo -e "${BOLD}${GREEN}✨ Features:${RESET}"
    echo -e "   • 🌈 Gorgeous rainbow styling"
    echo -e "   • 🎨 Automatic beautiful categorization"
    echo -e "   • 🔗 Smart wiki cross-references"
    echo -e "   • 📱 Mobile-friendly responsive design"
    echo -e "   • ⚡ Real-time auto-import monitoring"
    echo -e "   • 🔍 Powerful search capabilities"
    echo ""
    echo -e "${BOLD}${GREEN}🛠️ Manual Commands:${RESET}"
    echo -e "   • ~/scripts/beautiful_wiki_monitor.sh start/stop/status"
    echo -e "   • nb browse --serve (start server)"
    echo -e "   • nb search 'keyword' (search wiki)"
    echo ""
    echo -n -e "${BOLD}${CYAN}Press Enter to return to menu...${RESET}"
    read -r
    show_beautiful_menu
}

# 🌈 Main execution 🌈
main() {
    case "${1:-menu}" in
        start|launch)
            setup_beautiful_environment
            launch_beautiful_server
            launch_beautiful_monitoring
            show_beautiful_status
            ;;
        server)
            setup_beautiful_environment
            launch_beautiful_server
            ;;
        monitor)
            launch_beautiful_monitoring
            ;;
        status)
            show_beautiful_status
            ;;
        stop)
            log_beautiful "INFO" "🛑 Stopping beautiful services"
            /home/user/scripts/beautiful_wiki_monitor.sh stop 2>/dev/null || true
            pkill -f "nb browse --serve" 2>/dev/null || true
            log_beautiful "SUCCESS" "😴 Services stopped"
            ;;
        help|--help|-h)
            show_beautiful_help
            ;;
        menu|*)
            show_beautiful_menu
            ;;
    esac
}

# 🚀 Launch the beautiful adventure! 🚀
main "$@"