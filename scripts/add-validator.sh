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
#    Validator Scaler v2.0
#    Safely add new validators to your running node
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

# Configuration
ZUG_DIR="/opt/zugchain-validator"
DEPOSIT_CLI="/opt/ethstaker-deposit-cli/deposit"
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOGIC
# ══════════════════════════════════════════════════════════════════════════════

load_credentials() {
    log_header "Authentication"
    
    # Mnemonic
    if [ -f "${ZUG_DIR}/secrets/mnemonic.txt" ]; then
        MNEMONIC=$(cat "${ZUG_DIR}/secrets/mnemonic.txt")
        log_success "Mnemonic found in secrets"
    elif [ -f "${ZUG_DIR}/data/validators/mnemonic.txt" ]; then
        MNEMONIC=$(cat "${ZUG_DIR}/data/validators/mnemonic.txt")
        log_success "Mnemonic found (Legacy path)"
    else
        if [ "$SETUP_MODE" == "true" ]; then
            log_warning "No mnemonic found."
            log_prompt "Do you want to generate a NEW mnemonic? [Y/n]"
            read -r GEN_OPT
            if [[ "$GEN_OPT" =~ ^[Yy] || -z "$GEN_OPT" ]]; then
                 # Generate Mnemonic inline using Python
                 log_info "Generating new mnemonic..."
                 MNEMONIC=$(python3 -c "from mnemonic import Mnemonic; print(Mnemonic('english').generate(strength=256))" 2>/dev/null)
                 
                 if [ -z "$MNEMONIC" ]; then
                     # Try installing if missing
                     pip3 install mnemonic --quiet --break-system-packages 2>/dev/null
                     MNEMONIC=$(python3 -c "from mnemonic import Mnemonic; print(Mnemonic('english').generate(strength=256))" 2>/dev/null)
                 fi

                 if [ -n "$MNEMONIC" ]; then
                     echo ""
                     echo -e "${ZUG_TEAL}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
                     echo -e "${ZUG_TEAL}║  ${ZUG_WHITE}${BOLD}NEW MNEMONIC GENERATED${RESET}                                                  ${ZUG_TEAL}║${RESET}"
                     echo -e "${ZUG_TEAL}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
                     echo ""
                     echo -e "  ${COLOR_WARNING}WRITE THIS DOWN SAFELY:${RESET}"
                     echo -e "  $MNEMONIC"
                     echo ""
                     log_prompt "Press ENTER once saved"
                     read -r
                     
                     # Save it
                     mkdir -p "${ZUG_DIR}/secrets"
                     echo "$MNEMONIC" > "${ZUG_DIR}/secrets/mnemonic.txt"
                     chmod 600 "${ZUG_DIR}/secrets/mnemonic.txt"
                 else
                     log_error "Failed to generate mnemonic (python3-mnemonic missing?)"
                     log_prompt "Enter your 24-word Mnemonic manually"
                     read -r MNEMONIC
                 fi
            else
                 log_prompt "Enter your 24-word Mnemonic"
                 read -r MNEMONIC
            fi
        else
            log_warning "Mnemonic file not found!"
            log_prompt "Enter your 24-word Mnemonic"
            read -r MNEMONIC
        fi
    fi

    # Wallet Password
    if [ -f "${ZUG_DIR}/secrets/wallet_password" ]; then
        WALLET_PASSWORD=$(cat "${ZUG_DIR}/secrets/wallet_password")
    elif [ -f "${ZUG_DIR}/data/validators/wallet_password.txt" ]; then
        WALLET_PASSWORD=$(cat "${ZUG_DIR}/data/validators/wallet_password.txt")
    else
        echo -n "  ${ZUG_TEAL}${BOLD}?${RESET} Enter Wallet Password: "
        read -s -r WALLET_PASSWORD
        echo ""
    fi

    # Keystore Password
    if [ -f "${ZUG_DIR}/secrets/keystore_password" ]; then
        KEYSTORE_PASSWORD=$(cat "${ZUG_DIR}/secrets/keystore_password")
    elif [ -f "${ZUG_DIR}/data/validators/keystore_password.txt" ]; then
        KEYSTORE_PASSWORD=$(cat "${ZUG_DIR}/data/validators/keystore_password.txt")
    else
        echo -n "  ${ZUG_TEAL}${BOLD}?${RESET} Enter Keystore Password: "
        read -s -r KEYSTORE_PASSWORD
        echo ""
    fi
}

reload_validator_service() {
    log_header "Updating Validator Service"
    
    if systemctl is-active --quiet zugchain-validator; then
        log_info "Restarting systemd service..."
        systemctl restart zugchain-validator
        log_success "Service restarted"
    else
        log_info "Reloading legacy process..."
        pkill validator 2>/dev/null
        sleep 3
        
        # Determine withdrawal address for fee recipient if possible, else skip
        FEE_RECIPIENT_FLAG=""
        if [ -n "$WITHDRAWAL_ADDR" ]; then
            FEE_RECIPIENT_FLAG="--suggested-fee-recipient=${WITHDRAWAL_ADDR}"
        fi

        nohup validator \
            --datadir="${ZUG_DIR}/data/validators" \
            --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
            --wallet-password-file=<(echo "$WALLET_PASSWORD") \
            --beacon-rpc-provider="127.0.0.1:4000" \
            --chain-config-file="${ZUG_DIR}/config/config.yml" \
            --accept-terms-of-use \
            $FEE_RECIPIENT_FLAG \
            > ${ZUG_DIR}/logs/validator.log 2>&1 &
            
        NEW_PID=$!
        echo $NEW_PID > ${ZUG_DIR}/validator.pid
        log_success "Validator started (PID: $NEW_PID)"
    fi
}

generate_keys() {
    local num_to_add=$1
    local start_index=$2
    local setup_mode=$3
    
    WORK_DIR=$(mktemp -d)
    log_info "Generating keys in temporary workspace..."
    
    DEVNET_SETTINGS='{"network_name":"zugchain","genesis_fork_version":"0x20000000","exit_fork_version":"0x20000000","genesis_validator_root":"0x0000000000000000000000000000000000000000000000000000000000000000"}'
    
    echo ""
    log_prompt "Enter Withdrawal Address (0x...)"
    read -r RAW_WITHDRAWAL_ADDR
    
    # Checksum the address using Python to avoid issues
    # First try to verify if module exists, if not install it
    if ! python3 -c "import eth_utils" 2>/dev/null; then
         log_info "Installing missing python utils..."
         pip3 install eth-utils --quiet --break-system-packages 2>/dev/null || pip3 install eth-utils --quiet 2>/dev/null
    fi

    WITHDRAWAL_ADDR=$(python3 -c "from eth_utils import to_checksum_address; print(to_checksum_address('${RAW_WITHDRAWAL_ADDR}'))" 2>/dev/null)
    
    if [ -z "$WITHDRAWAL_ADDR" ]; then
        log_warning "Address checksum failed (Python error). Using raw input."
        WITHDRAWAL_ADDR="$RAW_WITHDRAWAL_ADDR"
    else
        log_info "Address formatted: $WITHDRAWAL_ADDR"
    fi
    
    cd "$WORK_DIR"
    
    log_info "Running key generation..."
    
    log_info "Running key generation (v2.5 FINAL)..."
    
    # We use the OFFICIAL flags (Corrected):
    # --language=English (Global)
    # Reverting to --devnet_chain_setting (Required for custom chain)
    # Using pipe '\ny\n' (Enter for language default, y for confirmation)
    
    rm -rf "$WORK_DIR/deposit_cli.log"
    
    printf "\ny\n" | $DEPOSIT_CLI \
        --language=English \
        existing-mnemonic \
        --num_validators $num_to_add \
        --validator_start_index $start_index \
        --mnemonic="$MNEMONIC" \
        --mnemonic_language=english \
        --keystore_password="$KEYSTORE_PASSWORD" \
        --withdrawal_address="$WITHDRAWAL_ADDR" \
        --devnet_chain_setting="$DEVNET_SETTINGS" \
        --folder="$WORK_DIR" > "$WORK_DIR/deposit_cli.log" 2>&1
        
    if [ $? -ne 0 ]; then
        log_error "Key generation failed!"
        echo -e "${RED}Detailed Error Log:${NC}"
        echo -e "${DIM}--------------------------------------------------${NC}"
        cat "$WORK_DIR/deposit_cli.log"
        echo -e "${DIM}--------------------------------------------------${NC}"
        rm -rf "$WORK_DIR"
        exit 1
    fi
    
    log_success "Generated $num_to_add new keys"
    
    # Import
    mkdir -p ${ZUG_DIR}/data/validators/validator_keys/keystores
    cp "$WORK_DIR"/validator_keys/keystore-*.json ${ZUG_DIR}/data/validators/validator_keys/keystores/
    
    # Save deposit data for later display
    DEPOSIT_FILE=$(find "$WORK_DIR/validator_keys" -name "deposit_data-*.json" | head -n 1)
    cp "$DEPOSIT_FILE" ${ZUG_DIR}/data/validators/validator_keys/latest_deposit_data.json
    
    log_info "Importing keys to wallet..."
    validator accounts import \
        --keys-dir="${ZUG_DIR}/data/validators/validator_keys/keystores" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --account-password-file=<(echo "$KEYSTORE_PASSWORD") \
        --accept-terms-of-use > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        log_success "Import successful"
    else
        log_error "Import failed (Check logs)"
    fi
    
    # Display Deposit Data
    echo ""
    echo -e "${ZUG_TEAL}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${ZUG_TEAL}║   ${ZUG_WHITE}${BOLD}DEPOSIT TRANSACTIONS REQUIRED${RESET}${ZUG_TEAL}                                            ║${RESET}"
    echo -e "${ZUG_TEAL}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    python3 << PYEOF
from eth_abi import encode
import json
import sys

with open('${ZUG_DIR}/data/validators/validator_keys/latest_deposit_data.json', 'r') as f:
    deposits = json.load(f)

print(f"\033[1;37mFound {len(deposits)} new validators to fund:\033[0m")
selector = '0x22895118'

for i, data in enumerate(deposits):
    print(f"\n\033[1;33mVALIDATOR #{i+1}\033[0m (Pubkey: {data['pubkey'][:12]}...)")
    pubkey = bytes.fromhex(data['pubkey'])
    withdrawal = bytes.fromhex(data['withdrawal_credentials'])
    signature = bytes.fromhex(data['signature'])
    root = bytes.fromhex(data['deposit_data_root'])
    encoded = encode(['bytes', 'bytes', 'bytes', 'bytes32'], [pubkey, withdrawal, signature, root])
    print(f"\033[0;36m{selector + encoded.hex()}\033[0m")
    print("\033[2m----------------------------------------\033[0m")
PYEOF

    echo ""
    echo -e "  ${ZUG_WHITE}${BOLD}INSTRUCTIONS:${RESET}"
    echo -e "  1. Send ${COLOR_WARNING}32 ZUG${RESET} to ${ZUG_TEAL}${DEPOSIT_CONTRACT}${RESET}"
    echo -e "  2. Include the ${ZUG_TEAL}Hex Data${RESET} above in the transaction"
    echo ""
    
    rm -rf "$WORK_DIR"
    
    # If not setup mode, reload service
    if [ "$setup_mode" != "true" ]; then
        reload_validator_service
    fi
}

main() {
    check_root
    
    SETUP_MODE="false"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-mode) SETUP_MODE="true"; shift ;;
            *) shift ;;
        esac
    done

    if [ "$SETUP_MODE" != "true" ]; then
        print_banner
    fi
    
    load_credentials
    
    # Count existing keys
    CURRENT_KEYS=$(find ${ZUG_DIR}/data/validators/validator_keys/keystores -name "keystore-*.json" 2>/dev/null | wc -l)
    log_info "Existing validators: $CURRENT_KEYS"
    
    log_prompt "How many NEW validators to add? (e.g., 1)"
    read -r NUM_TO_ADD
    
    if ! [[ "$NUM_TO_ADD" =~ ^[0-9]+$ ]] || [ "$NUM_TO_ADD" -lt 1 ]; then
        log_error "Invalid number"
        exit 1
    fi
    
    generate_keys "$NUM_TO_ADD" "$CURRENT_KEYS" "$SETUP_MODE"
}

main "$@"
