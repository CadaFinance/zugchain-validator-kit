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
            validator wallet create \
                --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
                --wallet-password-file="${ZUG_DIR}/secrets/wallet_password" \
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
        log_warning "Deposit data not found - skipping hex display"
        return
    fi
    
    echo ""
    echo -e "${ZUG_TEAL}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${ZUG_TEAL}║   ${ZUG_WHITE}${BOLD}DEPOSIT TRANSACTIONS REQUIRED${RESET}${ZUG_TEAL}                                            ║${RESET}"
    echo -e "${ZUG_TEAL}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    python3 << PYEOF
from eth_abi import encode
import json
with open('$DEPOSIT_FILE', 'r') as f:
    deposits = json.load(f)

print(f"\033[1;37mFound {len(deposits)} validator(s) requiring deposits:\033[0m")
selector = '0x22895118'

for i, data in enumerate(deposits):
    print(f"\n\033[1;33mVALIDATOR #{i+1}\033[0m")
    encoded = encode(['bytes', 'bytes', 'bytes', 'bytes32'], [bytes.fromhex(data['pubkey']), bytes.fromhex(data['withdrawal_credentials']), bytes.fromhex(data['signature']), bytes.fromhex(data['deposit_data_root'])])
    print(f"\033[0;36m{selector + encoded.hex()}\033[0m")
    print("\033[2m----------------------------------------\033[0m")
PYEOF

    echo ""
    echo -e "  ${ZUG_WHITE}${BOLD}INSTRUCTIONS:${RESET}"
    echo -e "  1. Send ${COLOR_WARNING}32 ZUG${RESET} to ${ZUG_TEAL}${DEPOSIT_CONTRACT}${RESET}"
    echo -e "  2. Use Hex Data above"
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
}

main "$@"
