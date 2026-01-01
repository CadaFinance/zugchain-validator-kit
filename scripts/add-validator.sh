#!/bin/bash

# ===============================================================================
# ZugChain Validator Scaler
# Safely add more validators to your running node
# ===============================================================================

ZUG_DIR="/opt/zugchain-validator"
DEPOSIT_CLI="/opt/ethstaker-deposit-cli/deposit"
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

log_info() { echo -e "  ${CYAN}ℹ${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $1"; }
log_error() { echo -e "  ${RED}✗${NC}  $1"; }

main() {
    check_root
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     ZugChain Validator Scaler                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This script will add MORE validators to your existing node."
    echo "It will NOT stop Geth or Beacon chain (Sync will continue)."
    echo ""

    # 1. Load Secrets
    log_info "Loading credentials..."
    
    if [ -f "${ZUG_DIR}/data/validators/mnemonic.txt" ]; then
        MNEMONIC=$(cat "${ZUG_DIR}/data/validators/mnemonic.txt")
        log_success "Mnemonic found"
    else
        log_error "Mnemonic file not found!"
        echo -n "Enter your 24-word Mnemonic: "
        read MNEMONIC
    fi

    if [ -f "${ZUG_DIR}/data/validators/wallet_password.txt" ]; then
        WALLET_PASSWORD=$(cat "${ZUG_DIR}/data/validators/wallet_password.txt")
    else
        echo -n "Enter Wallet Password: "
        read -s WALLET_PASSWORD
        echo ""
    fi

    if [ -f "${ZUG_DIR}/data/validators/keystore_password.txt" ]; then
        KEYSTORE_PASSWORD=$(cat "${ZUG_DIR}/data/validators/keystore_password.txt")
    else
        echo -n "Enter Keystore Password: "
        read -s KEYSTORE_PASSWORD
        echo ""
    fi
    
    # 2. Determine Start Index
    CURRENT_KEYS=$(find ${ZUG_DIR}/data/validators/validator_keys/keystores -name "keystore-*.json" | wc -l)
    START_INDEX=$CURRENT_KEYS
    
    log_info "Found ${CURRENT_KEYS} existing validators."
    log_info "New keys will start from index: ${START_INDEX}"
    
    # 3. Ask user quantity
    echo ""
    echo -n "How many NEW validators do you want to add? (e.g. 1): "
    read NUM_TO_ADD
    
    if ! [[ "$NUM_TO_ADD" =~ ^[0-9]+$ ]] || [ "$NUM_TO_ADD" -lt 1 ]; then
        log_error "Invalid number."
        exit 1
    fi
    
    # 4. Generate Keys
    WORK_DIR=$(mktemp -d)
    log_info "Generating keys in temporary workspace..."
    
    DEVNET_SETTINGS='{"network_name":"zugchain","genesis_fork_version":"0x20000000","exit_fork_version":"0x20000000","genesis_validator_root":"0x0000000000000000000000000000000000000000000000000000000000000000"}'
    
    echo ""
    echo -n "Enter Withdrawal Address (0x...): "
    read WITHDRAWAL_ADDR
    
    cd "$WORK_DIR"
    $DEPOSIT_CLI existing-mnemonic \
        --num_validators $NUM_TO_ADD \
        --validator_start_index $START_INDEX \
        --mnemonic="$MNEMONIC" \
        --mnemonic_language=english \
        --keystore_password="$KEYSTORE_PASSWORD" \
        --withdrawal_address="$WITHDRAWAL_ADDR" \
        --devnet_chain_setting="$DEVNET_SETTINGS" \
        --folder="$WORK_DIR"
        
    if [ $? -ne 0 ]; then
        log_error "Key generation failed."
        rm -rf "$WORK_DIR"
        exit 1
    fi
    
    log_success "Generated $NUM_TO_ADD new keys."
    
    # 5. Move Keys & Import
    mkdir -p ${ZUG_DIR}/data/validators/validator_keys/keystores
    cp "$WORK_DIR"/validator_keys/keystore-*.json ${ZUG_DIR}/data/validators/validator_keys/keystores/
    
    # Find the newly generated deposit data file
    DEPOSIT_FILE=$(find "$WORK_DIR/validator_keys" -name "deposit_data-*.json" | head -n 1)
    
    log_info "Importing to wallet..."
    validator accounts import \
        --keys-dir="${ZUG_DIR}/data/validators/validator_keys/keystores" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --account-password-file=<(echo "$KEYSTORE_PASSWORD") \
        --accept-terms-of-use > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        log_success "Import successful!"
    else
        log_error "Import failed. Checking logs..."
    fi
    
    # 6. Display Deposit Hex Data (User Requested)
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}DEPOSIT TRANSACTIONS REQUIRED${NC}${GREEN}                                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "You must send 32 ZUG for EACH new validator."
    echo "Below is the HEX DATA for each transaction."
    echo ""

    python3 << PYEOF
from eth_abi import encode
import json
import sys

# Load deposit file
with open('$DEPOSIT_FILE', 'r') as f:
    deposits = json.load(f)

print(f"${BOLD}Found {len(deposits)} new validators to fund:${NC}")

selector = '0x22895118'

for i, data in enumerate(deposits):
    pubkey = bytes.fromhex(data['pubkey'])
    withdrawal = bytes.fromhex(data['withdrawal_credentials'])
    signature = bytes.fromhex(data['signature'])
    root = bytes.fromhex(data['deposit_data_root'])

    encoded = encode(['bytes', 'bytes', 'bytes', 'bytes32'], [pubkey, withdrawal, signature, root])
    hex_data = selector + encoded.hex()
    
    print("")
    print(f"${YELLOW}VALIDATOR #{i+1} (Pubkey: {data['pubkey'][:12]}...)${NC}")
    print(f"${CYAN}{hex_data}${NC}")
    print(f"${DIM}----------------------------------------${NC}")

PYEOF

    echo ""
    echo -e "${WHITE}${BOLD}INSTRUCTIONS FOR EACH TRANSACTION:${NC}"
    echo -e "  ${CYAN}1.${NC} Open Metamask"
    echo -e "  ${CYAN}2.${NC} Send ${YELLOW}32 ZUG${NC} to Deposit Contract: ${CYAN}${DEPOSIT_CONTRACT}${NC}"
    echo -e "  ${CYAN}3.${NC} Click 'Hex Data' in advanced options"
    echo -e "  ${CYAN}4.${NC} Paste the ${CYAN}HEX DATA${NC} shown above"
    echo -e "  ${CYAN}5.${NC} Confirm transaction"
    echo ""
    
    # Clean up
    rm -rf "$WORK_DIR"
    
    # 7. Reload Validator
    log_info "Reloading Validator process..."
    
    # Secure way: Get PID, Kill, Start
    VAL_PID=$(cat ${ZUG_DIR}/validator.pid 2>/dev/null)
    if [ -n "$VAL_PID" ]; then
        kill $VAL_PID 2>/dev/null
    fi
    pkill validator 2>/dev/null
    
    sleep 3
    
    nohup validator \
        --datadir="${ZUG_DIR}/data/validators" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --beacon-rpc-provider="127.0.0.1:4000" \
        --chain-config-file="${ZUG_DIR}/config/config.yml" \
        --accept-terms-of-use \
        --suggested-fee-recipient="${WITHDRAWAL_ADDR}" \
        > ${ZUG_DIR}/logs/validator.log 2>&1 &
        
    NEW_PID=$!
    echo $NEW_PID > ${ZUG_DIR}/validator.pid
    
    log_success "Validator re-started with NEW keys! (PID: $NEW_PID)"
    echo -e "${GREEN}Total Validators: $(($CURRENT_KEYS + $NUM_TO_ADD))${NC}"
}

main
