#!/bin/bash

#===============================================================================
#
#    ███████╗ ██╗   ██╗  ██████╗      ██████╗ ██╗  ██╗ █████╗ ██╗███╗   ██╗
#    ╚══███╔╝ ██║   ██║ ██╔════╝     ██╔════╝ ██║  ██║ ██╔══██╗██║████╗  ██║
#      ███╔╝  ██║   ██║ ██║  ███╗    ██║      ███████║ ███████║██║██╔██╗ ██║
#     ███╔╝   ██║   ██║ ██║   ██║    ██║      ██╔══██║ ██╔══██║██║██║╚██╗██║
#    ███████╗ ╚██████╔╝ ╚██████╔╝    ╚██████╗ ██║  ██║██║  ██║██║██║ ╚████║
#    ╚══════╝ ╚═════╝   ╚═════╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
#
#    Shared Utilities v1.0
#    Common functions, colors, and styling for ZugChain Validator Scripts
#
#===============================================================================

# ══════════════════════════════════════════════════════════════════════════════
# COLOR PALETTE (Enterprise Theme)
# ══════════════════════════════════════════════════════════════════════════════

# Primary Identity
export ZUG_TEAL='\033[0;36m'       # Deep Cyan/Teal (Logo/Headers)
export ZUG_BLUE='\033[0;34m'       # Primary Blue (Info)
export ZUG_WHITE='\033[1;37m'      # Bright White (Text)

# States
export COLOR_SUCCESS='\033[0;32m'  # Emerald Green
export COLOR_WARNING='\033[1;33m'  # Amber
export COLOR_ERROR='\033[0;31m'    # Alert Red
export COLOR_MUTED='\033[0;90m'    # Dark Gray (Comments/Debug)

# Text Formatting
export BOLD='\033[1m'
export DIM='\033[2m'
export RESET='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# LOGGING FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

log_header() {
    echo ""
    echo -e "${ZUG_TEAL}${BOLD}:: $1 ${RESET}"
    echo -e "${ZUG_TEAL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

log_info() { 
    echo -e "  ${ZUG_BLUE}${BOLD}INFO${RESET}    │ $1" 
}

log_success() { 
    echo -e "  ${COLOR_SUCCESS}${BOLD}SUCCESS${RESET} │ $1" 
}

log_warning() { 
    echo -e "  ${COLOR_WARNING}${BOLD}WARNING${RESET} │ $1" 
}

log_error() { 
    echo -e "  ${COLOR_ERROR}${BOLD}ERROR${RESET}   │ $1" 
}

log_progress() {
    echo -e "  ${ZUG_TEAL}>>${RESET} $1"
}

log_step() {
    echo ""
    echo -e "  ${ZUG_WHITE}${BOLD}→ Step $1:${RESET} $2"
}

log_prompt() {
    echo -ne "  ${ZUG_TEAL}${BOLD}?${RESET} $1: "
}

# ══════════════════════════════════════════════════════════════════════════════
# UI COMPONENTS
# ══════════════════════════════════════════════════════════════════════════════

print_banner() {
    clear
    echo -e "${ZUG_TEAL}"
    echo "    ███████╗ ██╗   ██╗  ██████╗      ██████╗ ██╗  ██╗ █████╗ ██╗███╗   ██╗"
    echo "    ╚══███╔╝ ██║   ██║ ██╔════╝     ██╔════╝ ██║  ██║ ██╔══██╗██║████╗  ██║"
    echo "      ███╔╝  ██║   ██║ ██║  ███╗    ██║      ███████║ ███████║██║██╔██╗ ██║"
    echo "     ███╔╝   ██║   ██║ ██║   ██║    ██║      ██╔══██║ ██╔══██║██║██║╚██╗██║"
    echo "    ███████╗ ╚██████╔╝ ╚██████╔╝    ╚██████╗ ██║  ██║██║  ██║██║██║ ╚████║"
    echo "    ╚══════╝ ╚═════╝   ╚═════╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo -e "    ${ZUG_WHITE}${BOLD}Enterprise Validator Suite${RESET} ${DIM}v2.0${RESET}"
    echo ""
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    tput civis # Hide cursor
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "  ${ZUG_TEAL}%c${RESET}  Processing..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r\033[K"
    done
    
    tput cnorm # Show cursor
}

wait_with_spinner() {
    local pid=$1
    local message=$2
    
    tput civis
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r  ${ZUG_TEAL}%c${RESET}  %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r\033[K"
    tput cnorm
}

show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r  ${ZUG_TEAL}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${RESET} %3d%%" "$percent"
}

# ══════════════════════════════════════════════════════════════════════════════
# SYSTEM HELPERS
# ══════════════════════════════════════════════════════════════════════════════

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
}

check_dependencies() {
    local deps=("$@")
    local missing=0
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_warning "Dependency missing: $cmd"
            missing=1
        fi
    done
    
    return $missing
}

format_bytes() {
    awk -v bytes="$1" '
    function human(x) {
        if (x<1000) {return x}
        else {x/=1024}
        s="kMGTEPZY";
        while (x>=1000 && length(s)>1) {x/=1024; s=substr(s,2)}
        return int(x+0.5) substr(s,1,1) "iB"
    }
    BEGIN {print human(bytes)}'
}
