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
#    Voluntary Exit v2.0
#    Safety-first validator exit procedure
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"
TOOLS_DIR="${ZUG_DIR}/tools"
PRYSMCTL="${TOOLS_DIR}/prysmctl"
PRYSM_VERSION="v5.3.0"

ensure_prysmctl() {
    [ -f "$PRYSMCTL" ] && return
    
    log_info "Downloading prysmctl..."
    mkdir -p "$TOOLS_DIR"
    wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${PRYSM_VERSION}/prysmctl-${PRYSM_VERSION}-linux-amd64" -O "$PRYSMCTL"
    chmod +x "$PRYSMCTL"
}

get_validator_info() {
    log_info "Fetching validator info..."
    
    # Simple check for active keys
    count=$(find ${ZUG_DIR}/data/validators/validator_keys/keystores -name "keystore-*.json" 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        log_error "No keys found to exit."
        exit 1
    fi
    
    log_success "Found $count validator(s)"
}

show_warning() {
    echo ""
    echo -e "${COLOR_ERROR}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${COLOR_ERROR}║   ${ZUG_WHITE}${BOLD}⚠️  VOLUNTARY EXIT - THIS ACTION IS IRREVERSIBLE ⚠️${RESET}${COLOR_ERROR}                       ║${RESET}"
    echo -e "${COLOR_ERROR}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${ZUG_WHITE}${BOLD}Implications:${RESET}"
    echo -e "  1. Your validator will enter the exit queue."
    echo -e "  2. You must keep running until exit epoch (~27 hours)."
    echo -e "  3. Stake + Rewards will be withdrawn to your withdrawal address."
    echo ""
}

confirm_exit() {
    echo -e "${COLOR_WARNING}Type '${ZUG_WHITE}I UNDERSTAND EXIT IS PERMANENT${COLOR_WARNING}' to proceed:${RESET}"
    read -r CONFIRM
    
    if [ "$CONFIRM" != "I UNDERSTAND EXIT IS PERMANENT" ]; then
        log_error "Confirmation failed. Aborting."
        exit 0
    fi
}

backup_slashing_protection() {
    log_info "Exporting safety backup..."
    BACKUP_DIR="${ZUG_DIR}/backups/pre-exit-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    "$PRYSMCTL" validator slashing-protection-history export \
        --datadir="${ZUG_DIR}/data/validators" \
        --slashing-protection-export-dir="$BACKUP_DIR" > /dev/null 2>&1
        
    log_success "Slashing DB backed up"
}

execute_exit() {
    WALLET_DIR="${ZUG_DIR}/data/validators/wallet"
    PASS_FILE="${ZUG_DIR}/secrets/wallet_password"
    [ ! -f "$PASS_FILE" ] && PASS_FILE="${ZUG_DIR}/data/validators/wallet_password.txt"
    
    log_header "Initiating Exit Protocol"
    echo -e "  ${DIM}Follow the prompts to select validators:${RESET}"
    echo ""
    
    "$PRYSMCTL" validator exit \
        --wallet-dir="$WALLET_DIR" \
        --beacon-rpc-provider="127.0.0.1:4000" \
        --wallet-password-file="$PASS_FILE"
        
    if [ $? -eq 0 ]; then
        log_success "Exit signal broadcasted"
        echo -e "  ${COLOR_WARNING}DO NOT STOP YOUR VALIDATOR YET!${RESET}"
        echo -e "  Wait until your exit epoch is passed (check explorer)."
    else
        log_error "Exit command failed"
    fi
}

main() {
    check_root
    print_banner
    
    ensure_prysmctl
    get_validator_info
    show_warning
    
    if [[ "$*" != *"--force"* ]]; then
        confirm_exit
    fi
    
    backup_slashing_protection
    execute_exit
}

main "$@"
