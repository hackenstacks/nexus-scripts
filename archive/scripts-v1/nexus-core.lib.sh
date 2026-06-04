#!/bin/bash
# 🌀 NeXuS Core Library (nexus-core.lib.sh)
# version: 2.0.0-alpha
#
# The central nervous system for the NeXuS ecosystem.
# Source this file at the top of your scripts:
# source "$(dirname "$0")/nexus-core.lib.sh"

# ==============================================================================
# 1. ENVIRONMENT & PATHS
# ==============================================================================

# Determine the absolute path of the script sourcing this library
export NEXUS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
export NEXUS_CONFIG="${NEXUS_CONFIG:-$HOME/.config/nexus}"
export NEXUS_LOGS="${NEXUS_LOGS:-$NEXUS_HOME/logs}"
export NEXUS_TMP="${NEXUS_TMP:-/tmp/nexus}"

# Create essential directories
mkdir -p "$NEXUS_HOME" "$NEXUS_CONFIG" "$NEXUS_LOGS" "$NEXUS_TMP"

# ==============================================================================
# 2. VISUAL DESIGN SYSTEM (Fire Theme)
# ==============================================================================

# ANSI Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export ORANGE='\033[0;91m'
export GREY='\033[0;90m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# Symbols
export SYMBOL_FIRE="🔥"
export SYMBOL_ICE="❄️"
export SYMBOL_SUCCESS="✅"
export SYMBOL_ERROR="❌"
export SYMBOL_WARNING="⚠️"
export SYMBOL_INFO="ℹ️"
export SYMBOL_NEXUS="🌀"
export SYMBOL_LOCK="🔒"
export SYMBOL_KEY="🔑"
export SYMBOL_ROCKET="🚀"
export SYMBOL_GHOST="👻"

# ==============================================================================
# 3. LOGGING & OUTPUT
# ==============================================================================

# Initialize log file for the calling script
SCRIPT_NAME=$(basename "$0" .sh)
CURRENT_LOG_FILE="$NEXUS_LOGS/${SCRIPT_NAME}_$(date +%Y%m%d).log"

# Internal log function
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$CURRENT_LOG_FILE"
}

# Public output functions
nexus::info() {
    echo -e "${BLUE}${SYMBOL_INFO} ${WHITE}$1${NC}"
    _log_to_file "INFO" "$1"
}

nexus::success() {
    echo -e "${GREEN}${SYMBOL_SUCCESS} ${WHITE}$1${NC}"
    _log_to_file "SUCCESS" "$1"
}

nexus::warn() {
    echo -e "${YELLOW}${SYMBOL_WARNING} $1${NC}"
    _log_to_file "WARNING" "$1"
}

nexus::error() {
    echo -e "${RED}${SYMBOL_ERROR} $1" >&2
    _log_to_file "ERROR" "$1"
}

nexus::fatal() {
    echo -e "${RED}${SYMBOL_FIRE} CRITICAL ERROR: $1" >&2
    _log_to_file "FATAL" "$1"
    exit 1
}

nexus::header() {
    local title="$1"
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${WHITE}%66s${CYAN}║${NC}\n" " "
    printf "${CYAN}║${WHITE}%*s ${SYMBOL_NEXUS} %s ${SYMBOL_NEXUS} %*s${CYAN}║${NC}\n" \
        $(( (60 - ${#title}) / 2 )) "" "$title" $(( (61 - ${#title}) / 2 )) ""
    printf "${CYAN}║${WHITE}%66s${CYAN}║${NC}\n" " "
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# ==============================================================================
# 4. UTILITY FUNCTIONS
# ==============================================================================

# Check if a command exists
nexus::check_dep() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        nexus::warn "Missing dependency: $cmd"
        return 1
    fi
    return 0
}

# Require a command to exist, or exit
nexus::require_dep() {
    local cmd="$1"
    if ! nexus::check_dep "$cmd"; then
        nexus::fatal "Required dependency '$cmd' is not installed. Please install it and try again."
    fi
}

# Check root privileges
nexus::require_root() {
    if [[ $EUID -ne 0 ]]; then
        nexus::fatal "This operation requires root privileges. Please run with sudo or doas."
    fi
}

# Create a spinner for long running tasks
nexus::spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ==============================================================================
# 5. INITIALIZATION
# ==============================================================================

# Log library load
_log_to_file "SYSTEM" "NeXuS Core Library v2.0.0-alpha loaded by $0"
