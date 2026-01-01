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
#    Validator Recovery Script v1.0
#    ("External Validator Setup" - Recovery Edition)
#    
#===============================================================================

# Reopen stdin from tty for interactive input
exec < /dev/tty

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIGS_SRC="${PACKAGE_ROOT}/configs"

MAIN_NODE_IP="16.171.13.62"
CHAIN_ID=4545072
NETWORK_ID=4545072
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"
ZUG_DIR="/opt/zugchain-validator"
FORK_VERSION="0x20000000"

# Software Versions
GETH_VERSION="1.14.12"
PRYSM_VERSION="v5.1.2"
GO_VERSION="1.22.4"

# ═══════════════════════════════════════════════════════════════════════════════
# COLORS & STYLING
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "    ╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "    ║                                                                               ║"
    echo "    ║   ███████╗ ██╗   ██╗  ██████╗      ██████╗ ██╗  ██╗  █████╗  ██╗ ███╗   ██╗   ║"
    echo "    ║   ╚══███╔╝ ██║   ██║ ██╔════╝     ██╔════╝ ██║  ██║ ██╔══██╗ ██║ ████╗  ██║   ║"
    echo "    ║     ███╔╝  ██║   ██║ ██║  ███╗    ██║      ███████║ ███████║ ██║ ██╔██╗ ██║   ║"
    echo "    ║    ███╔╝   ██║   ██║ ██║   ██║    ██║      ██╔══██║ ██╔══██║ ██║ ██║╚██╗██║   ║"
    echo "    ║   ███████╗ ╚██████╔╝ ╚██████╔╝    ╚██████╗ ██║  ██║ ██║  ██║ ██║ ██║ ╚████║   ║"
    echo "    ║   ╚══════╝  ╚═════╝   ╚═════╝      ╚═════╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝ ╚═╝  ╚═══╝   ║"
    echo "    ║                                                                               ║"
    echo "    ║                    Validator Recovery Script v1.0                             ║"
    echo "    ║                                                                               ║"
    echo "    ╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    local step_num=$1
    local step_name=$2
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}  STEP ${step_num}: ${step_name}${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $1"; }
log_error() { echo -e "  ${RED}✗${NC}  $1"; }
log_warning() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_progress() { echo -e "  ${CYAN}➜${NC}  $1"; }

press_enter() {
    echo ""
    echo -e "${DIM}Press ENTER to continue...${NC}"
    read < /dev/tty
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_config_files() {
    local missing=0
    
    if [ ! -d "$CONFIGS_SRC" ]; then
        log_error "Configs directory not found at $CONFIGS_SRC"
        exit 1
    fi

    if [ ! -f "$CONFIGS_SRC/genesis.json" ]; then
        log_error "genesis.json not found in package configs!"
        missing=1
    fi
    
    if [ ! -f "$CONFIGS_SRC/genesis.ssz" ]; then
        log_error "genesis.ssz not found in package configs!"
        missing=1
    fi
    
    if [ ! -f "$CONFIGS_SRC/config.yml" ]; then
        log_error "config.yml not found in package configs!"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Package is incomplete. Please redownload."
        exit 1
    fi
    
    log_success "All configuration files found in package"
}

cleanup_old_files() {
    log_progress "Cleaning up old files that may cause conflicts..."
    
    # Aggressively remove anything named 'assignments' in target system paths
    rm -rf /root/assignments* /tmp/assignments* /var/tmp/assignments* ./assignments* assignments 2>/dev/null
    find /root /tmp /opt /var/tmp -maxdepth 2 -name "assignments*" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove old keystore residues
    rm -rf ${ZUG_DIR}/data/validators/validator_keys/keystores 2>/dev/null
    rm -rf /tmp/staking_deposit* /tmp/keystores* /tmp/eth2-val-* 2>/dev/null
    
    log_success "Cleanup completed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: SOFTWARE INSTALLATION (Same as v5)
# ═══════════════════════════════════════════════════════════════════════════════

install_dependencies() {
    print_step "1" "Installing Dependencies"
    
    log_progress "Updating package lists..."
    apt-get update -qq > /dev/null 2>&1
    
    log_progress "Installing base packages..."
    apt-get install -y -qq git curl wget build-essential jq openssl python3 python3-pip > /dev/null 2>&1
    log_success "Base packages installed"
    
    # Install Go
    if [ ! -f "/usr/local/go/bin/go" ]; then
        log_progress "Installing Go ${GO_VERSION}..."
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
        rm -rf /usr/local/go
        tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
        rm "go${GO_VERSION}.linux-amd64.tar.gz"
        log_success "Go installed"
    else
        log_success "Go already installed"
    fi
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile 2>/dev/null || true
    
    # Install Geth
    if ! command -v geth &> /dev/null; then
        log_progress "Installing Geth ${GETH_VERSION}..."
        wget -q "https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-${GETH_VERSION}-293a300d.tar.gz" -O geth.tar.gz
        tar -xzf geth.tar.gz
        find . -name "geth" -type f -executable | head -1 | xargs -I {} cp {} /usr/local/bin/
        rm -rf geth*
        log_success "Geth installed"
    else
        log_success "Geth already installed"
    fi
    
    # Install Prysm
    if ! command -v beacon-chain &> /dev/null; then
        log_progress "Installing Prysm ${PRYSM_VERSION}..."
        PRYSM_URL="https://github.com/prysmaticlabs/prysm/releases/download/${PRYSM_VERSION}"
        
        # Remove if partially exists
        rm -f /usr/local/bin/beacon-chain /usr/local/bin/validator

        wget -q "${PRYSM_URL}/beacon-chain-${PRYSM_VERSION}-linux-amd64" -O /usr/local/bin/beacon-chain
        wget -q "${PRYSM_URL}/validator-${PRYSM_VERSION}-linux-amd64" -O /usr/local/bin/validator
        
        # Verify download size (rough check)
        if [ ! -s /usr/local/bin/beacon-chain ] || [ ! -s /usr/local/bin/validator ]; then
             log_error "Prysm download failed!"
             return 1
        fi

        chmod +x /usr/local/bin/beacon-chain /usr/local/bin/validator
        log_success "Prysm installed"
    else
        # Ensure permissions even if already installed
        chmod +x /usr/local/bin/beacon-chain /usr/local/bin/validator
        log_success "Prysm already installed"
    fi
    
    # Install ethstaker-deposit-cli
    if [ ! -f "/opt/ethstaker-deposit-cli/deposit" ]; then
        log_progress "Installing ethstaker-deposit-cli v1.2.2..."
        rm -rf /opt/ethstaker-deposit-cli /opt/staking-deposit-cli /tmp/ethstaker*
        mkdir -p /opt/ethstaker-deposit-cli
        wget -q https://github.com/eth-educators/ethstaker-deposit-cli/releases/download/v1.2.2/ethstaker_deposit-cli-b13dcb9-linux-amd64.tar.gz -O /tmp/ethstaker_deposit.tar.gz
        tar -xzf /tmp/ethstaker_deposit.tar.gz -C /tmp/
        mv /tmp/ethstaker_deposit-cli-b13dcb9-linux-amd64/* /opt/ethstaker-deposit-cli/
        rm -rf /tmp/ethstaker*
        chmod +x /opt/ethstaker-deposit-cli/deposit
        log_success "ethstaker-deposit-cli installed"
    else
        log_success "ethstaker-deposit-cli already installed"
    fi
    
    # Python dependencies
    log_progress "Installing Python dependencies..."
    pip3 install web3 eth_abi pyyaml --quiet --break-system-packages 2>/dev/null || pip3 install web3 eth_abi pyyaml --quiet 2>/dev/null
    log_success "Python dependencies installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: DIRECTORY SETUP
# ═══════════════════════════════════════════════════════════════════════════════

setup_directories() {
    print_step "2" "Setting Up Directories"
    
    log_progress "Creating directory structure..."
    mkdir -p ${ZUG_DIR}/{data,config,logs}
    mkdir -p ${ZUG_DIR}/data/{geth,beacon,validators}
    mkdir -p ${ZUG_DIR}/data/validators/{validator_keys,wallet}
    
    # Copy config files
    log_progress "Copying configuration files from package..."
    cp "$CONFIGS_SRC/genesis.json" "${ZUG_DIR}/config/"
    cp "$CONFIGS_SRC/genesis.ssz" "${ZUG_DIR}/config/"
    cp "$CONFIGS_SRC/config.yml" "${ZUG_DIR}/config/"
    
    # Generate JWT secret
    if [ ! -f "${ZUG_DIR}/data/jwt.hex" ]; then
        log_progress "Generating JWT secret..."
        openssl rand -hex 32 > ${ZUG_DIR}/data/jwt.hex
    fi
    
    log_success "Directory structure created"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: RECOVER VALIDATOR KEYS
# ═══════════════════════════════════════════════════════════════════════════════

recover_validator_keys() {
    print_step "3" "Recovering Validator Keys"
    
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ${WHITE}RECOVERY MODE: You will need your 24-word Mnemonic Phrase.    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║  ${WHITE}This will regenerate your keys to continue validating.        ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get Mnemonic
    echo -e "${CYAN}Enter your 24-word Mnemonic Phrase (separate with spaces):${NC}"
    echo -n "  ➜ "
    read MNEMONIC < /dev/tty
    
    # Simple validation (count words)
    WORD_COUNT=$(echo "$MNEMONIC" | wc -w)
    if [ "$WORD_COUNT" -ne 24 ]; then
        log_error "Invalid mnemonic! Expected 24 words, got $WORD_COUNT."
        echo -e "${YELLOW}Please check your mnemonic and try again.${NC}"
        exit 1
    fi
    
    echo ""
    
    # Get withdrawal address
    echo -e "${CYAN}Enter your EVM Withdrawal Address (where rewards will go):${NC}"
    echo -e "${DIM}Example: 0xYourMetamaskAddress${NC}"
    echo -n "  ➜ "
    read WITHDRAWAL_ADDR < /dev/tty
    
    if [[ ! $WITHDRAWAL_ADDR =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        log_error "Invalid address format. Must be 0x followed by 40 hex characters."
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}Create a keystore password (minimum 8 characters):${NC}"
    echo -n "  ➜ "
    read -s KEYSTORE_PASSWORD < /dev/tty
    echo ""
    
    if [ ${#KEYSTORE_PASSWORD} -lt 8 ]; then
        log_error "Password must be at least 8 characters!"
        exit 1
    fi
    
    # Create working directories
    WORK_DIR=$(mktemp -d -t zugchain-recovery-XXXXXX)
    mkdir -p "$WORK_DIR"
    log_progress "Workspace: $WORK_DIR"
    
    DEVNET_SETTINGS='{"network_name":"zugchain","genesis_fork_version":"0x20000000","exit_fork_version":"0x20000000","genesis_validator_root":"0x0000000000000000000000000000000000000000000000000000000000000000"}'
    
    log_progress "Recovering keys (this may take a minute)..."
    
    cd "$WORK_DIR"
    
    # Use ethstaker-deposit-cli non-interactively
    /opt/ethstaker-deposit-cli/deposit existing-mnemonic \
        --num_validators 1 \
        --validator_start_index 0 \
        --mnemonic="$MNEMONIC" \
        --mnemonic_language=english \
        --keystore_password="$KEYSTORE_PASSWORD" \
        --withdrawal_address="$WITHDRAWAL_ADDR" \
        --devnet_chain_setting="$DEVNET_SETTINGS" \
        --folder="$WORK_DIR" 2>&1 | tee "$WORK_DIR/recovery.log"
    
    # Check if keys were generated
    if [ -d "$WORK_DIR/validator_keys" ] && ls "$WORK_DIR/validator_keys"/keystore-*.json 1>/dev/null 2>&1; then
        log_success "Keys recovered successfully!"
    else
        log_error "Key recovery failed! Check inputs and try again."
        exit 1
    fi
    
    # Setup ZugChain directory structure
    mkdir -p ${ZUG_DIR}/data/validators/validator_keys/keystores
    
    # Copy keystores
    cp "$WORK_DIR"/validator_keys/keystore-*.json ${ZUG_DIR}/data/validators/validator_keys/keystores/
    
    # Copy deposit data (for reference)
    if [ -f "$WORK_DIR/validator_keys/deposit_data.json" ]; then
        cp "$WORK_DIR/validator_keys/deposit_data.json" ${ZUG_DIR}/data/validators/validator_keys/deposit_data.json
    else
        cp "$WORK_DIR"/validator_keys/deposit_data-*.json ${ZUG_DIR}/data/validators/validator_keys/deposit_data.json 2>/dev/null || true
    fi
    
    # Clean up workspace
    cd ~
    rm -rf "$WORK_DIR"
    
    # Import to wallet
    log_progress "Importing recovered keys to wallet..."
    
    WALLET_PASSWORD="validator_wallet_pass"
    
    if [ ! -d "${ZUG_DIR}/data/validators/wallet" ] || [ ! -f "${ZUG_DIR}/data/validators/wallet/direct/accounts/all-accounts.keystore.json" ]; then
        validator wallet create \
            --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
            --wallet-password-file=<(echo "$WALLET_PASSWORD") \
            --accept-terms-of-use 2>/dev/null || true
    fi
    
    validator accounts import \
        --keys-dir="${ZUG_DIR}/data/validators/validator_keys/keystores" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --account-password-file=<(echo "$KEYSTORE_PASSWORD") \
        --accept-terms-of-use 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Keys imported to wallet successfully!"
    else
        log_warning "Wallet import had issues. Please check logs."
    fi
    
    # Save passwords for reference
    echo "$WALLET_PASSWORD" > ${ZUG_DIR}/data/validators/wallet_password.txt
    chmod 600 ${ZUG_DIR}/data/validators/wallet_password.txt
    
    echo "$KEYSTORE_PASSWORD" > ${ZUG_DIR}/data/validators/keystore_password.txt
    chmod 600 ${ZUG_DIR}/data/validators/keystore_password.txt
    
    # Save mnemonic securely (for future recovery)
    echo "$MNEMONIC" > ${ZUG_DIR}/data/validators/mnemonic.txt
    chmod 600 ${ZUG_DIR}/data/validators/mnemonic.txt
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: START SERVICES (Same as v5)
# ═══════════════════════════════════════════════════════════════════════════════

start_services() {
    print_step "4" "Starting Validator Services"
    
    # Bootnodes from main chain
    MAIN_ENODE="enode://47a17c0103b04d6091d4a12d686f7dd70b0b921de79c55b95ce8a7c58fbf50a8a71254902f1233efd02b0dfdbf80794ba7234b0764ea94a648fee6860fd58bd2@45.151.155.216:30303"
    MAIN_ENR="enr:-Mq4QDzEHBApbHwpwNWXfOcNDPP1xD20Du0q6fWEda-1IH6mEilreU9PqBAhWPt8PPxfWuTKVNhpriu9b9pflKue5XyGAZtRHUuRh2F0dG5ldHOIAAAAMAAAAACEZXRoMpDm_BAkIAAABf__________gmlkgnY0gmlwhC2Xm9iEcXVpY4IyyIlzZWNwMjU2azGhAnSsXx5CrkvE1DvbxQWKR0cH507ap3D1ujUvYtOG_o-qiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g"

    log_info "Getting bootnode information from main node..."
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        apt-get install -y jq > /dev/null 2>&1
    fi

    ENODE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
        http://${MAIN_NODE_IP}:8545 2>/dev/null | jq -r '.result.enode' 2>/dev/null)
    
    if [ -n "$ENODE" ] && [ "$ENODE" != "null" ] && [ "$ENODE" != "" ]; then
        MAIN_ENODE="$ENODE"
        log_success "Got ENODE from main node"
    else
        log_warning "Could not fetch ENODE from main node, using hardcoded fallback."
    fi

    # Create static-nodes.json for persistent connection
    log_progress "Configuring static peers..."
    mkdir -p "${ZUG_DIR}/data/geth"
    echo "[\"$MAIN_ENODE\"]" > "${ZUG_DIR}/data/geth/static-nodes.json"
    
    # Initialize Geth
    log_progress "Initializing Geth..."
    # Remove existing chain data if it exists to ensure clean init on recovery
    # rm -rf "${ZUG_DIR}/data/geth/geth" 2>/dev/null 
    geth init --datadir="${ZUG_DIR}/data/geth" --state.scheme=path "${ZUG_DIR}/config/genesis.json" 2>/dev/null
    
    # Start Geth
    log_progress "Starting Geth (Execution Layer)..."
    nohup geth \
        --datadir="${ZUG_DIR}/data/geth" \
        --networkid=${NETWORK_ID} \
        --http --http.addr="0.0.0.0" --http.port=8545 \
        --http.api="eth,net,web3,admin,debug" \
        --http.corsdomain="*" --http.vhosts="*" \
        --authrpc.addr="127.0.0.1" --authrpc.port=8551 --authrpc.vhosts="*" \
        --authrpc.jwtsecret="${ZUG_DIR}/data/jwt.hex" \
        --syncmode=snap \
        --bootnodes="${MAIN_ENODE}" \
        > ${ZUG_DIR}/logs/geth.log 2>&1 &
    GETH_PID=$!
    echo $GETH_PID > ${ZUG_DIR}/geth.pid
    log_success "Geth started (PID: $GETH_PID)"
    
    sleep 5
    
    # Start Beacon Chain
    log_progress "Starting Beacon Chain (Consensus Layer)..."
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
    
    nohup beacon-chain \
        --datadir="${ZUG_DIR}/data/beacon" \
        --genesis-state="${ZUG_DIR}/config/genesis.ssz" \
        --chain-config-file="${ZUG_DIR}/config/config.yml" \
        --execution-endpoint="http://127.0.0.1:8551" \
        --jwt-secret="${ZUG_DIR}/data/jwt.hex" \
        --accept-terms-of-use \
        --deposit-contract=${DEPOSIT_CONTRACT} \
        --contract-deployment-block=0 \
        --min-sync-peers=0 \
        --checkpoint-sync-url="http://${MAIN_NODE_IP}:3500" \
        --genesis-beacon-api-url="http://${MAIN_NODE_IP}:3500" \
        --bootstrap-node="${MAIN_ENR}" \
        --p2p-host-ip="${PUBLIC_IP}" \
        > ${ZUG_DIR}/logs/beacon.log 2>&1 &
    BEACON_PID=$!
    echo $BEACON_PID > ${ZUG_DIR}/beacon.pid
    log_success "Beacon started (PID: $BEACON_PID)"
    
    sleep 5
    
    # Start Validator
    log_progress "Starting Validator..."
    WALLET_PASSWORD=$(cat ${ZUG_DIR}/data/validators/wallet_password.txt 2>/dev/null || echo "validator_wallet_pass")
    
    nohup validator \
        --datadir="${ZUG_DIR}/data/validators" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --beacon-rpc-provider="127.0.0.1:4000" \
        --chain-config-file="${ZUG_DIR}/config/config.yml" \
        --accept-terms-of-use \
        --suggested-fee-recipient="${WITHDRAWAL_ADDR}" \
        > ${ZUG_DIR}/logs/validator.log 2>&1 &
    VAL_PID=$!
    echo $VAL_PID > ${ZUG_DIR}/validator.pid
    log_success "Validator started (PID: $VAL_PID)"
}

print_summary() {
    print_step "5" "Recovery Complete!"
    
    GETH_PID=$(cat ${ZUG_DIR}/geth.pid 2>/dev/null || echo "N/A")
    BEACON_PID=$(cat ${ZUG_DIR}/beacon.pid 2>/dev/null || echo "N/A")
    VAL_PID=$(cat ${ZUG_DIR}/validator.pid 2>/dev/null || echo "N/A")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}🎉 VALIDATOR RECOVERED AND RUNNING! 🎉${NC}${GREEN}                                     ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Service Status:${NC}"
    echo -e "  ${CYAN}Geth PID:${NC}      $GETH_PID"
    echo -e "  ${CYAN}Beacon PID:${NC}    $BEACON_PID"
    echo -e "  ${CYAN}Validator PID:${NC} $VAL_PID"
    echo ""
    echo -e "${WHITE}${BOLD}Logs:${NC}"
    echo -e "  ${CYAN}Validator:${NC} ${ZUG_DIR}/logs/validator.log"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    check_root
    
    echo -e "${WHITE}This script will RECOVER your ZugChain validator on this machine.${NC}"
    echo -e "${WHITE}You must have your 24-word mnemonic ready.${NC}"
    echo ""
    press_enter
    
    check_config_files
    cleanup_old_files
    install_dependencies
    setup_directories
    recover_validator_keys
    start_services
    print_summary
}

main "$@"
