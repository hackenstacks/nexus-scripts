#!/bin/bash

# 🔱 NeXuS Enhanced AI-Nexus Launcher & Interactive Guide
# Beautiful, Offline-First AI Interface - Zero Dependencies, Maximum Beauty
# Built with NeXuS Philosophy: Sane, Simple, Secure

set -e

# Color definitions for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Smart project directory detection
detect_project_dir() {
    # If script is in the project directory (has package.json)
    if [[ -f "$SCRIPT_DIR/package.json" ]]; then
        PROJECT_DIR="$SCRIPT_DIR"
        return 0
    fi
    
    # If running from scripts directory, look for ai-nexus-enhanced
    if [[ -f "/home/user/git/ai-nexus-enhanced/package.json" ]]; then
        PROJECT_DIR="/home/user/git/ai-nexus-enhanced"
        return 0
    fi
    
    # Try current working directory
    if [[ -f "$(pwd)/package.json" ]]; then
        PROJECT_DIR="$(pwd)"
        return 0
    fi
    
    # Look in common locations
    local common_paths=(
        "/home/user/git/ai-nexus-enhanced"
        "/home/user/ai-nexus-enhanced"
        "/home/user/Projects/ai-nexus-enhanced"
        "$HOME/git/ai-nexus-enhanced"
        "$HOME/ai-nexus-enhanced"
    )
    
    for path in "${common_paths[@]}"; do
        if [[ -f "$path/package.json" ]]; then
            PROJECT_DIR="$path"
            return 0
        fi
    done
    
    # If nothing found, ask user
    echo -e "${RED}❌ Could not find ai-nexus-enhanced project directory${NC}"
    echo -e "${YELLOW}💡 Please specify the full path to your ai-nexus-enhanced directory:${NC}"
    read -r user_path
    
    if [[ -f "$user_path/package.json" ]]; then
        PROJECT_DIR="$user_path"
        return 0
    else
        echo -e "${RED}❌ package.json not found in $user_path${NC}"
        return 1
    fi
}

# Detect project directory
detect_project_dir

# Banner function
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🔱 AI-Nexus Enhanced - NeXuS Framework                    ║"
    echo "║              Beautiful, Offline-First AI Interface - Zero CDNs              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}🔥 Built with NeXuS Philosophy: ${BOLD}Sane • Simple • Secure${NC}"
    echo -e "${WHITE}📍 Project Directory: ${GREEN}$PROJECT_DIR${NC}"
    echo ""
}

# Main menu
show_main_menu() {
    echo -e "${BOLD}${BLUE}🚀 Choose Your Action:${NC}"
    echo ""
    echo -e "${WHITE}🏃 ${BOLD}LAUNCH OPTIONS:${NC}"
    echo -e "  ${CYAN}1${NC}) 🔥 Launch Development Mode (npm run dev)"
    echo -e "  ${CYAN}2${NC}) 🛡️ Launch Production HTTPS (recommended)"
    echo -e "  ${CYAN}3${NC}) ⚡ Quick Build Only"
    echo ""
    echo -e "${WHITE}📚 ${BOLD}INFORMATION & HELP:${NC}"
    echo -e "  ${CYAN}4${NC}) ✨ Show Enhanced Features Overview"
    echo -e "  ${CYAN}5${NC}) 🔒 Show Offline-First Architecture"
    echo -e "  ${CYAN}6${NC}) 🎨 Show Available Themes"
    echo -e "  ${CYAN}7${NC}) 🛡️ Show Security & Privacy Features"
    echo -e "  ${CYAN}8${NC}) 📋 Show Technical Specifications"
    echo -e "  ${CYAN}9${NC}) 🔧 Show Installation & Setup Guide"
    echo ""
    echo -e "${WHITE}🌀 ${BOLD}NEXUS UTILS:${NC}"
    echo -e "  ${CYAN}h${NC}) 📖 Show Complete Help Documentation"
    echo -e "  ${CYAN}s${NC}) 📊 Show System Status"
    echo -e "  ${CYAN}q${NC}) 🚪 Exit"
    echo ""
    echo -e -n "${YELLOW}Enter your choice: ${NC}"
}

# Check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking system dependencies...${NC}"
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
        echo -e "${RED}❌ Error: package.json not found in $PROJECT_DIR${NC}"
        echo -e "${YELLOW}💡 Make sure you're running this script from the ai-nexus-enhanced directory${NC}"
        return 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js not found${NC}"
        echo -e "${YELLOW}💡 Please install Node.js 18+ to continue${NC}"
        return 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm not found${NC}"
        echo -e "${YELLOW}💡 Please install npm to continue${NC}"
        return 1
    fi
    
    # Check Python for HTTPS server
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        echo -e "${YELLOW}⚠️ Python not found - HTTPS server option will be unavailable${NC}"
    fi
    
    echo -e "${GREEN}✅ Dependencies check passed${NC}"
    return 0
}

# Install dependencies if needed
install_dependencies() {
    if [[ ! -d "$PROJECT_DIR/node_modules" ]]; then
        echo -e "${BLUE}📦 Installing npm dependencies...${NC}"
        cd "$PROJECT_DIR"
        npm install
        echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
    else
        echo -e "${GREEN}✅ Dependencies already installed${NC}"
    fi
}

# Launch development mode
launch_dev() {
    echo -e "${BLUE}🔥 Launching Development Mode...${NC}"
    echo -e "${CYAN}💡 This will start the Vite development server with hot reload${NC}"
    echo -e "${WHITE}🌐 URL will be: ${GREEN}http://localhost:5173${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo ""
    
    cd "$PROJECT_DIR"
    npm run dev
}

# Launch production HTTPS
launch_production() {
    echo -e "${BLUE}🛡️ Launching Production HTTPS Mode...${NC}"
    echo -e "${CYAN}💡 Building optimized production version...${NC}"
    
    cd "$PROJECT_DIR"
    
    # Build the project
    echo -e "${BLUE}⚡ Building project...${NC}"
    npm run build
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Build completed successfully${NC}"
        echo ""
        
        # Find Python command
        PYTHON_CMD=""
        if command -v python3 &> /dev/null; then
            PYTHON_CMD="python3"
        elif command -v python &> /dev/null; then
            PYTHON_CMD="python"
        else
            echo -e "${RED}❌ Python not found for HTTPS server${NC}"
            return 1
        fi
        
        echo -e "${BLUE}🚀 Starting HTTPS server...${NC}"
        echo -e "${WHITE}🌐 URL: ${GREEN}https://localhost:8443${NC}"
        echo -e "${CYAN}💡 You'll see a security warning - click 'Advanced' then 'Accept Risk'${NC}"
        echo -e "${YELLOW}⚠️ This uses a self-signed certificate for development${NC}"
        echo ""
        echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
        echo ""
        
        $PYTHON_CMD https_server.py dist 8443
    else
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    fi
}

# Quick build only
quick_build() {
    echo -e "${BLUE}⚡ Building project...${NC}"
    cd "$PROJECT_DIR"
    npm run build
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Build completed successfully${NC}"
        echo -e "${CYAN}📁 Built files are in: ${WHITE}$PROJECT_DIR/dist/${NC}"
        echo -e "${CYAN}💡 You can now serve the dist/ directory with any web server${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    fi
}

# Show enhanced features
show_enhanced_features() {
    clear
    echo -e "${PURPLE}${BOLD}✨ ENHANCED FEATURES OVER ORIGINAL AI-NEXUS${NC}"
    echo ""
    
    echo -e "${CYAN}🎨 ${BOLD}Custom CSS Framework (Replaces TailwindCSS CDN):${NC}"
    echo -e "   • Complete utility framework built from scratch"
    echo -e "   • Enhanced component library with animations"
    echo -e "   • 6 stunning professional themes"
    echo -e "   • Responsive design for all device sizes"
    echo -e "   • WCAG accessibility compliance"
    echo ""
    
    echo -e "${CYAN}🔒 ${BOLD}Offline-First Architecture:${NC}"
    echo -e "   • Service Worker caching for instant loading"
    echo -e "   • Progressive Web App (PWA) capabilities"
    echo -e "   • Local font embedding (no Google Fonts CDN)"
    echo -e "   • Graceful fallback strategies"
    echo -e "   • Import maps for module resolution"
    echo ""
    
    echo -e "${CYAN}🛡️ ${BOLD}Security & Privacy Enhancements:${NC}"
    echo -e "   • Zero external CDN dependencies"
    echo -e "   • Self-signed HTTPS server included"
    echo -e "   • No tracking or analytics"
    echo -e "   • Complete data sovereignty"
    echo ""
    
    echo -e "${CYAN}🎯 ${BOLD}User Experience Improvements:${NC}"
    echo -e "   • Sticky navigation toolbar"
    echo -e "   • Enhanced modal system with proper z-index"
    echo -e "   • Beautiful loading animations"
    echo -e "   • Graceful error boundaries"
    echo -e "   • Theme persistence across sessions"
    echo ""
    
    echo -e "${GREEN}🔐 ${BOLD}ENCRYPTION REMAINS 100% IDENTICAL:${NC}"
    echo -e "   • Same master password system"
    echo -e "   • Same zero-knowledge encryption"
    echo -e "   • Same IndexedDB security"
    echo -e "   • Same encrypted backups"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show offline-first architecture
show_offline_architecture() {
    clear
    echo -e "${PURPLE}${BOLD}🌐 OFFLINE-FIRST ARCHITECTURE${NC}"
    echo ""
    
    echo -e "${CYAN}📱 ${BOLD}First Visit Experience:${NC}"
    echo -e "   1. Browser downloads all critical files (CSS, JS, fonts)"
    echo -e "   2. Service Worker caches everything locally"
    echo -e "   3. PWA manifest enables mobile installation"
    echo ""
    
    echo -e "${CYAN}⚡ ${BOLD}Subsequent Visits:${NC}"
    echo -e "   1. Instant loading from cache (even offline)"
    echo -e "   2. Full functionality maintained without internet"
    echo -e "   3. Automatic sync when connection restored"
    echo ""
    
    echo -e "${CYAN}🔌 ${BOLD}Network Failure Handling:${NC}"
    echo -e "   • Continues working seamlessly when internet drops"
    echo -e "   • Graceful fallbacks for missing resources"
    echo -e "   • No broken layouts or missing fonts"
    echo ""
    
    echo -e "${CYAN}📁 ${BOLD}What Gets Cached:${NC}"
    echo -e "   • NeXuS CSS Framework (38KB optimized)"
    echo -e "   • JavaScript modules and React components"
    echo -e "   • Embedded Inter font family"
    echo -e "   • All theme variations and assets"
    echo ""
    
    echo -e "${GREEN}🏆 ${BOLD}RESULT: Works everywhere, even on airplanes!${NC}"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show available themes
show_themes() {
    clear
    echo -e "${PURPLE}${BOLD}🎨 AVAILABLE THEMES${NC}"
    echo ""
    
    echo -e "${WHITE}1. ${BOLD}Default Light/Dark${NC}"
    echo -e "   Clean, professional appearance with smooth transitions"
    echo ""
    
    echo -e "${PURPLE}2. ${BOLD}Catppuccin${NC}"
    echo -e "   Soothing pastel colors with purple accents"
    echo ""
    
    echo -e "${GREEN}3. ${BOLD}Cyber Green${NC}"
    echo -e "   Matrix-inspired green glow effects and animations"
    echo ""
    
    echo -e "${GREEN}4. ${BOLD}Matrix${NC}"
    echo -e "   Authentic Matrix theme with flicker animations"
    echo ""
    
    echo -e "${PURPLE}5. ${BOLD}Cosmic Purple${NC}"
    echo -e "   Gradient space theme with purple nebula effects"
    echo ""
    
    echo -e "${BLUE}6. ${BOLD}Ocean Blue${NC}"
    echo -e "   Calming ocean-inspired blue gradients"
    echo ""
    
    echo -e "${YELLOW}7. ${BOLD}Sunset${NC}"
    echo -e "   Warm orange/red gradient theme"
    echo ""
    
    echo -e "${CYAN}💡 ${BOLD}Theme Features:${NC}"
    echo -e "   • Automatic dark/light mode detection"
    echo -e "   • Smooth transitions between themes"
    echo -e "   • Persistent theme selection"
    echo -e "   • Consistent design language across all themes"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show security features
show_security() {
    clear
    echo -e "${PURPLE}${BOLD}🛡️ SECURITY & PRIVACY FEATURES${NC}"
    echo ""
    
    echo -e "${RED}🔒 ${BOLD}ENCRYPTION (UNCHANGED):${NC}"
    echo -e "   ✅ Master Password system - Same zero-knowledge encryption"
    echo -e "   ✅ IndexedDB encryption - All data encrypted before storage"
    echo -e "   ✅ Character data protection - AI personalities encrypted"
    echo -e "   ✅ Chat history security - Messages encrypted with master password"
    echo -e "   ✅ Plugin data safety - Custom plugins encrypted"
    echo -e "   ✅ Import/Export security - Same encrypted backup system"
    echo ""
    
    echo -e "${BLUE}🛡️ ${BOLD}PRIVACY ENHANCEMENTS:${NC}"
    echo -e "   ✅ Zero external CDN dependencies"
    echo -e "   ✅ No tracking or analytics"
    echo -e "   ✅ No external requests (except your AI APIs)"
    echo -e "   ✅ Complete data sovereignty"
    echo -e "   ✅ Local font embedding (no Google Fonts)"
    echo ""
    
    echo -e "${GREEN}🔐 ${BOLD}HTTPS & SECURITY:${NC}"
    echo -e "   ✅ Self-signed HTTPS server included"
    echo -e "   ✅ Service Worker requires secure context"
    echo -e "   ✅ Modern security headers"
    echo -e "   ✅ Content Security Policy ready"
    echo ""
    
    echo -e "${YELLOW}⚠️ ${BOLD}SECURITY PROMISE:${NC}"
    echo -e "   🌀 Enhanced = Visual Layer Only"
    echo -e "   🔒 Same master password unlocks everything"
    echo -e "   🛡️ Same 'forget password = lose data' security"
    echo -e "   🔐 Enhanced beauty, identical security"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show technical specifications
show_technical_specs() {
    clear
    echo -e "${PURPLE}${BOLD}📋 TECHNICAL SPECIFICATIONS${NC}"
    echo ""
    
    echo -e "${CYAN}🏗️ ${BOLD}Enhanced Project Structure:${NC}"
    echo -e "   📁 styles/               # NeXuS CSS Framework"
    echo -e "   ├── nexus-variables.css  # Design tokens & CSS variables"
    echo -e "   ├── nexus-utilities.css  # Utility classes (replaces Tailwind)"
    echo -e "   ├── nexus-components.css # Enhanced component styles"
    echo -e "   └── nexus-themes.css     # 6 beautiful theme variations"
    echo -e "   📄 index-enhanced.css    # Main stylesheet (imports all)"
    echo -e "   📄 sw.js                 # Service Worker for offline"
    echo -e "   📄 https_server.py       # Included HTTPS server"
    echo ""
    
    echo -e "${CYAN}⚙️ ${BOLD}Build Optimizations:${NC}"
    echo -e "   • Relative paths for static serving compatibility"
    echo -e "   • Asset organization with proper chunking"
    echo -e "   • Performance optimized with resource preloading"
    echo -e "   • Compressed builds with Vite optimization"
    echo ""
    
    echo -e "${CYAN}🎨 ${BOLD}CSS Framework Benefits:${NC}"
    echo -e "   • 38KB of beautiful, optimized CSS (vs TailwindCSS CDN)"
    echo -e "   • Design system with consistent tokens"
    echo -e "   • Component library with animations"
    echo -e "   • Utility classes covering all layout needs"
    echo -e "   • Built-in dark mode support"
    echo ""
    
    echo -e "${CYAN}⚡ ${BOLD}JavaScript Enhancements:${NC}"
    echo -e "   • Modern ES modules with import maps"
    echo -e "   • React 19.1.1 with latest features"
    echo -e "   • TypeScript for type safety"
    echo -e "   • Error boundaries for graceful failures"
    echo ""
    
    echo -e "${GREEN}📊 ${BOLD}Performance Metrics:${NC}"
    echo -e "   • First load: ~677KB (cached for offline)"
    echo -e "   • Subsequent loads: <1KB (from cache)"
    echo -e "   • CSS: 38KB (vs 200KB+ TailwindCSS)"
    echo -e "   • Fonts: Embedded (vs external CDN calls)"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show installation guide
show_installation_guide() {
    clear
    echo -e "${PURPLE}${BOLD}🔧 INSTALLATION & SETUP GUIDE${NC}"
    echo ""
    
    echo -e "${CYAN}📋 ${BOLD}Prerequisites:${NC}"
    echo -e "   • Node.js 18+ (for npm and development)"
    echo -e "   • Python 3.x (for HTTPS server)"
    echo -e "   • Modern browser with ES modules support"
    echo ""
    
    echo -e "${CYAN}🚀 ${BOLD}Quick Start:${NC}"
    echo -e "   1. ${WHITE}cd /home/user/git/ai-nexus-enhanced${NC}"
    echo -e "   2. ${WHITE}./nexus-enhanced-launcher.sh${NC}"
    echo -e "   3. Choose option 2 (Production HTTPS) for best experience"
    echo ""
    
    echo -e "${CYAN}🔥 ${BOLD}Development Mode:${NC}"
    echo -e "   ${WHITE}npm install${NC}      # Install dependencies"
    echo -e "   ${WHITE}npm run dev${NC}      # Start dev server"
    echo -e "   ${WHITE}# Visit: http://localhost:5173${NC}"
    echo ""
    
    echo -e "${CYAN}🛡️ ${BOLD}Production HTTPS Mode (Recommended):${NC}"
    echo -e "   ${WHITE}npm run build${NC}                    # Build optimized version"
    echo -e "   ${WHITE}python https_server.py dist 8443${NC} # Start HTTPS server"
    echo -e "   ${WHITE}# Visit: https://localhost:8443${NC}"
    echo ""
    
    echo -e "${CYAN}📱 ${BOLD}PWA Installation:${NC}"
    echo -e "   1. Visit the HTTPS URL in your browser"
    echo -e "   2. Look for 'Install' or '+' icon in address bar"
    echo -e "   3. Click to install as mobile/desktop app"
    echo -e "   4. Enjoy offline-first experience!"
    echo ""
    
    echo -e "${YELLOW}💡 ${BOLD}Tips:${NC}"
    echo -e "   • Always use HTTPS for full PWA features"
    echo -e "   • First visit downloads everything for offline use"
    echo -e "   • Your encryption/data remains unchanged"
    echo -e "   • Themes persist across browser sessions"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show complete help
show_complete_help() {
    clear
    echo -e "${PURPLE}${BOLD}📖 COMPLETE HELP DOCUMENTATION${NC}"
    echo ""
    
    echo -e "${WHITE}🔱 ${BOLD}NeXuS Enhanced AI-Nexus${NC}"
    echo -e "The ultimate offline-first AI interface built with NeXuS philosophy"
    echo ""
    
    echo -e "${CYAN}🔥 ${BOLD}What Makes It Special:${NC}"
    echo -e "• ${GREEN}Simple:${NC} Clean interface, intuitive design"
    echo -e "• ${BLUE}Secure:${NC} Zero CDNs, privacy-focused, same encryption"
    echo -e "• ${PURPLE}Beautiful:${NC} 6 professional themes, smooth animations"
    echo ""
    
    echo -e "${CYAN}🚀 ${BOLD}Launch Options:${NC}"
    echo -e "• ${WHITE}Development:${NC} Hot reload, debugging (port 5173)"
    echo -e "• ${WHITE}Production:${NC} Optimized, HTTPS, PWA features (port 8443)"
    echo ""
    
    echo -e "${CYAN}✨ ${BOLD}Key Features:${NC}"
    echo -e "• Works completely offline after first visit"
    echo -e "• Installable as mobile/desktop app"
    echo -e "• 6 beautiful themes with dark/light modes"
    echo -e "• Custom CSS framework (no TailwindCSS CDN)"
    echo -e "• Enhanced UX with sticky toolbar and smooth scrolling"
    echo -e "• Same security and encryption as original"
    echo ""
    
    echo -e "${CYAN}🛡️ ${BOLD}Security Promise:${NC}"
    echo -e "• Your master password and encryption unchanged"
    echo -e "• All data remains local and encrypted"
    echo -e "• Zero external dependencies or tracking"
    echo -e "• Enhanced beauty, identical security"
    echo ""
    
    echo -e "${CYAN}🌐 ${BOLD}Perfect For:${NC}"
    echo -e "• Privacy-conscious users"
    echo -e "• Offline/unreliable internet environments"
    echo -e "• Mobile deployment as PWA"
    echo -e "• Professional applications"
    echo -e "• Beautiful, secure AI interfaces"
    echo ""
    
    echo -e "${GREEN}🎯 ${BOLD}Quick Start: ./nexus-enhanced-launcher.sh${NC}"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Show system status
show_system_status() {
    clear
    echo -e "${PURPLE}${BOLD}📊 SYSTEM STATUS${NC}"
    echo ""
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✅ Node.js: ${WHITE}$NODE_VERSION${NC}"
    else
        echo -e "${RED}❌ Node.js: Not installed${NC}"
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        echo -e "${GREEN}✅ npm: ${WHITE}$NPM_VERSION${NC}"
    else
        echo -e "${RED}❌ npm: Not installed${NC}"
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        echo -e "${GREEN}✅ Python: ${WHITE}$PYTHON_VERSION${NC}"
    elif command -v python &> /dev/null; then
        PYTHON_VERSION=$(python --version)
        echo -e "${GREEN}✅ Python: ${WHITE}$PYTHON_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠️ Python: Not found (HTTPS server unavailable)${NC}"
    fi
    
    echo ""
    
    # Check project files
    echo -e "${CYAN}📁 ${BOLD}Project Status:${NC}"
    
    if [[ -f "$PROJECT_DIR/package.json" ]]; then
        echo -e "${GREEN}✅ package.json found${NC}"
    else
        echo -e "${RED}❌ package.json missing${NC}"
    fi
    
    if [[ -d "$PROJECT_DIR/node_modules" ]]; then
        echo -e "${GREEN}✅ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️ Dependencies not installed${NC}"
    fi
    
    if [[ -d "$PROJECT_DIR/dist" ]]; then
        echo -e "${GREEN}✅ Built version available${NC}"
    else
        echo -e "${YELLOW}⚠️ No built version (run build first)${NC}"
    fi
    
    if [[ -f "$PROJECT_DIR/https_server.py" ]]; then
        echo -e "${GREEN}✅ HTTPS server script available${NC}"
    else
        echo -e "${RED}❌ HTTPS server script missing${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}📍 Project Directory: ${GREEN}$PROJECT_DIR${NC}"
    echo ""
    
    echo ""
    echo -e "${CYAN}Press Enter to return to main menu...${NC}"
    read -r
}

# Main execution
main() {
    # Check if project directory detection was successful
    if [[ -z "$PROJECT_DIR" ]] || [[ ! -d "$PROJECT_DIR" ]]; then
        echo -e "${RED}❌ Failed to detect project directory. Exiting.${NC}"
        exit 1
    fi
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    while true; do
        show_banner
        
        # Check dependencies first
        if ! check_dependencies; then
            echo ""
            echo ""
            echo -e "${CYAN}Press Enter to exit...${NC}"
            read -r
            exit 1
        fi
        
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                install_dependencies
                echo ""
                launch_dev
                ;;
            2)
                install_dependencies
                echo ""
                launch_production
                ;;
            3)
                install_dependencies
                echo ""
                quick_build
                echo ""
                echo -e "${CYAN}Press Enter to return to main menu...${NC}"
                read -r
                ;;
            4)
                show_enhanced_features
                ;;
            5)
                show_offline_architecture
                ;;
            6)
                show_themes
                ;;
            7)
                show_security
                ;;
            8)
                show_technical_specs
                ;;
            9)
                show_installation_guide
                ;;
            h|H)
                show_complete_help
                ;;
            s|S)
                show_system_status
                ;;
            q|Q)
                echo -e "${GREEN}🔱 Thanks for using NeXuS Enhanced AI-Nexus!${NC}"
                echo -e "${CYAN}💫 Individual freedom through beautiful, secure, simple tools${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"