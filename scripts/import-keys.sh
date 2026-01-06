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
#    Import Keys Script v2.0
#    Import pre-generated validator keys (offline flow)
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"

# ══════════════════════════════════════════════════════════════════════════════
# IMPORT LOGIC
# ══════════════════════════════════════════════════════════════════════════════

import_keys() {
    local keys_dir=$1
    local keystore_password=$2
    
    log_header "Key Import Process"
    
    # 1. Validation
    local count=$(find "$keys_dir" -name "keystore-*.json" 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
        log_error "No keystores found in $keys_dir"
        exit 1
    fi
    log_info "Found $count keystore(s)"
    
    # 2. Setup Dirs
    mkdir -p ${ZUG_DIR}/data/validators/validator_keys/keystores
    mkdir -p ${ZUG_DIR}/data/validators/wallet
    mkdir -p ${ZUG_DIR}/secrets
    
    # 3. Copy Files
    log_info "Copying keystores..."
    cp "$keys_dir"/keystore-*.json ${ZUG_DIR}/data/validators/validator_keys/keystores/ 2>/dev/null
    log_success "Keystores copied"
    
    # Deposit Data
    DEPOSIT_FILE=$(find "$keys_dir" -name "deposit_data-*.json" | head -n1)
    if [ -f "$DEPOSIT_FILE" ]; then
        cp "$DEPOSIT_FILE" ${ZUG_DIR}/data/validators/validator_keys/
        log_success "Deposit data copied"
    fi
    
    # 4. Handle Passwords
    if [ -z "$keystore_password" ]; then
        if [ -f "$keys_dir/keystore_password.txt" ]; then
            keystore_password=$(cat "$keys_dir/keystore_password.txt")
            log_success "Keystore password loaded from file"
        else
            log_prompt "Enter password for these keystores"
            read -s -r keystore_password
            echo ""
        fi
    fi
    
    # Generate/Set Wallet Password
    if [ -f "${ZUG_DIR}/secrets/wallet_password" ]; then
         WALLET_PASSWORD=$(cat "${ZUG_DIR}/secrets/wallet_password")
    else
         WALLET_PASSWORD="zugchain_wallet_$(openssl rand -hex 8)"
         echo "$WALLET_PASSWORD" > ${ZUG_DIR}/secrets/wallet_password
    fi
    
    # Save Keystore Password
    echo "$keystore_password" > ${ZUG_DIR}/secrets/keystore_password
    chmod 600 ${ZUG_DIR}/secrets/*
    
    # Legacy compat
    cp ${ZUG_DIR}/secrets/wallet_password ${ZUG_DIR}/data/validators/wallet_password.txt
    cp ${ZUG_DIR}/secrets/keystore_password ${ZUG_DIR}/data/validators/keystore_password.txt
    
    # 5. Import to Wallet
    if command -v validator &> /dev/null; then
        # Create wallet if needed
        if [ ! -d "${ZUG_DIR}/data/validators/wallet/direct" ]; then
            log_info "Creating new wallet..."
            echo "" | validator wallet create \
                --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
                --wallet-password-file="${ZUG_DIR}/secrets/wallet_password" \
                --keymanager-kind=direct \
                --accept-terms-of-use > /dev/null 2>&1
        fi
        
        log_info "Importing accounts..."
        validator accounts import \
            --keys-dir="${ZUG_DIR}/data/validators/validator_keys/keystores" \
            --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
            --wallet-password-file="${ZUG_DIR}/secrets/wallet_password" \
            --account-password-file="${ZUG_DIR}/secrets/keystore_password" \
            --accept-terms-of-use > /dev/null 2>&1
            
        if [ $? -eq 0 ]; then
            log_success "Accounts imported to wallet"
        else
            log_warning "Import reported issues (Check logs)"
        fi
    else
        log_warning "Validator binary not found - skipping wallet import"
    fi
    
    # Ownership
    if id "zugchain" &>/dev/null; then
        chown -R zugchain:zugchain ${ZUG_DIR}
    fi
}

display_deposit_hex() {
    DEPOSIT_FILE="${ZUG_DIR}/data/validators/validator_keys/deposit_data.json"
    [ ! -f "$DEPOSIT_FILE" ] && DEPOSIT_FILE=$(find ${ZUG_DIR}/data/validators -name "deposit_data-*.json" | head -n1)
    
    if [ ! -f "$DEPOSIT_FILE" ]; then
        log_warning "Deposit data not found"
        return
    fi
    
    # Count validators
    local count=$(python3 -c "import json; print(len(json.load(open('$DEPOSIT_FILE'))))" 2>/dev/null || echo "?")
    
    echo ""
    echo -e "${ZUG_TEAL}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${ZUG_TEAL}║   ${ZUG_WHITE}${BOLD}DEPOSIT REQUIRED${RESET}${ZUG_TEAL}                                                        ║${RESET}"
    echo -e "${ZUG_TEAL}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${ZUG_WHITE}Found ${BOLD}${count}${RESET}${ZUG_WHITE} validator(s) requiring deposit.${RESET}"
    echo ""
    echo -e "  ${COLOR_WARNING}${BOLD}IMPORTANT:${RESET} Your validators will NOT become active until you"
    echo -e "  complete the deposit process on the ZugChain Launchpad."
    echo ""
    echo -e "  ${ZUG_TEAL}${BOLD}Next Steps:${RESET}"
    echo -e "  1. Go to ${BOLD}https://zugchain.io/launchpad${RESET}"
    echo -e "  2. Upload your ${BOLD}deposit_data.json${RESET} file"
    echo -e "  3. Send ${BOLD}32 ZUG${RESET} per validator to activate"
    echo ""
}

main() {
    check_root
    print_banner
    
    KEYS_DIR=""
    KEYSTORE_PASS=""
    SKIP_DEPOSIT=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keys-dir) KEYS_DIR="$2"; shift 2 ;;
            --keystore-password) KEYSTORE_PASS="$2"; shift 2 ;;
            --skip-deposit) SKIP_DEPOSIT=true; shift ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$KEYS_DIR" ]; then
        log_error "Usage: $0 --keys-dir <path>"
        exit 1
    fi
    
    if [ ! -d "$KEYS_DIR" ]; then
        log_error "Directory not found: $KEYS_DIR"
        exit 1
    fi
    
    import_keys "$KEYS_DIR" "$KEYSTORE_PASS"
    
    [ "$SKIP_DEPOSIT" = false ] && display_deposit_hex
    
    # Restart validator service if running (for adding new validators to existing setup)
    if systemctl is-active --quiet zugchain-validator 2>/dev/null; then
        log_header "Restarting Validator Service"
        log_info "Restarting to load new validator keys..."
        systemctl restart zugchain-validator
        sleep 3
        
        if systemctl is-active --quiet zugchain-validator; then
            log_success "Validator service restarted successfully"
            log_info "New validators will start attesting after activation"
        else
            log_error "Validator service failed to restart. Check: journalctl -u zugchain-validator"
        fi
    else
        log_info "Validator service not running. Start with: sudo systemctl start zugchain-validator"
    fi
    
    echo ""
    log_success "Import complete!"
    echo -e "  ${DIM}Run 'sudo ./health.sh' to verify all validators are active${RESET}"
    echo ""
}

main "$@"
