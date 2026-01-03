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
#    External Validator Setup Script v5.0
#    
#===============================================================================

# Reopen stdin from tty for interactive input
exec < /dev/tty

# Don't exit on error for interactive sections
# set -e

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIGS_SRC="${PACKAGE_ROOT}/configs"

MAIN_NODE_IP="16.171.135.45"
CHAIN_ID=1843932
NETWORK_ID=1843932
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"
ZUG_DIR="/opt/zugchain-validator"
FORK_VERSION="0x20000000"

# Software Versions
# GETH_VERSION="latest" # Managed via PPA
PRYSM_VERSION="v5.3.0"
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
    echo "    ║                       External Validator Setup v5.0                           ║"
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

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "  ${CYAN}%c${NC}  Processing..." "${spinstr}"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r                              \r"
    done
    printf "\r"
}

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

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP FUNCTION - Run at start to avoid conflicts
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_old_files() {
    log_progress "Cleaning up old files that may cause conflicts..."
    
    # Aggressively remove anything named 'assignments' in target system paths
    # (Fixed the typo where IP address was listed as a path)
    rm -rf /root/assignments* /tmp/assignments* /var/tmp/assignments* ./assignments* assignments 2>/dev/null
    find /root /tmp /opt /var/tmp -maxdepth 2 -name "assignments*" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove old keystore residues
    rm -rf ${ZUG_DIR}/data/validators/validator_keys/keystores 2>/dev/null
    rm -rf /tmp/staking_deposit* /tmp/keystores* /tmp/eth2-val-* 2>/dev/null
    
    log_success "Cleanup completed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: SOFTWARE INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_dependencies() {
    print_step "1" "Installing Dependencies"
    
    log_progress "Updating package lists..."
    apt-get update -qq > /dev/null 2>&1
    
    log_progress "Installing base packages..."
    apt-get install -y -qq git curl wget build-essential jq openssl python3 python3-pip software-properties-common > /dev/null 2>&1
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
        log_progress "Installing Geth (via PPA)..."
        add-apt-repository -y ppa:ethereum/ethereum > /dev/null 2>&1
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y ethereum > /dev/null 2>&1
        log_success "Geth installed"
    else
        log_success "Geth already installed"
    fi
    
    # Install Prysm
    if ! command -v beacon-chain &> /dev/null; then
        log_progress "Installing Prysm ${PRYSM_VERSION}..."
        PRYSM_URL="https://github.com/prysmaticlabs/prysm/releases/download/${PRYSM_VERSION}"
        wget -q "${PRYSM_URL}/beacon-chain-${PRYSM_VERSION}-linux-amd64" -O /usr/local/bin/beacon-chain
        wget -q "${PRYSM_URL}/validator-${PRYSM_VERSION}-linux-amd64" -O /usr/local/bin/validator
        chmod +x /usr/local/bin/beacon-chain /usr/local/bin/validator
        log_success "Prysm installed"
    else
        log_success "Prysm already installed"
    fi
    
    # Install ethstaker-deposit-cli (new maintained fork from eth-educators)
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
    
    # Install expect for automation
    apt-get install -y expect -qq 2>/dev/null || true
    
    # Python dependencies
    log_progress "Installing Python dependencies..."
    pip3 install web3 eth-abi pyyaml --quiet --break-system-packages --ignore-installed typing_extensions 2>/dev/null || pip3 install web3 eth-abi pyyaml --quiet --ignore-installed typing_extensions 2>/dev/null
    log_success "Python dependencies installed"
    
    echo ""
    log_success "All dependencies installed successfully!"
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
# STEP 3: VALIDATOR KEY GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

generate_validator_keys() {
    print_step "3" "Generating Validator Keys"
    
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ${WHITE}IMPORTANT: You will need to enter a withdrawal address and     ${YELLOW}║${NC}"
    echo -e "${YELLOW}║  ${WHITE}create a keystore password. Keep these safe!                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
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
    log_progress "Generating keys with ZugChain fork version (0x20000000)..."
    echo ""
    
    # Generate mnemonic
    log_progress "Generating secure mnemonic..."
    pip3 install mnemonic --quiet --break-system-packages 2>/dev/null || pip3 install mnemonic --quiet 2>/dev/null
    MNEMONIC=$(python3 -c "from mnemonic import Mnemonic; m = Mnemonic('english'); print(m.generate(strength=256))")
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ${WHITE}${BOLD}CRITICAL: SAVE THESE MNEMONIC WORDS!${NC}${RED}                            ║${NC}"
    echo -e "${RED}║  ${WHITE}These are your ONLY backup to recover your validator.          ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}${MNEMONIC}${NC}"
    echo ""
    echo -e "${YELLOW}Write these words down and store them safely. Press ENTER when done...${NC}"
    read < /dev/tty
    
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
    WORK_DIR=$(mktemp -d -t zugchain-keygen-XXXXXX)
    mkdir -p "$WORK_DIR"
    log_progress "Workspace: $WORK_DIR"
    
    # ═══════════════════════════════════════════════════════════════════════════════
    # ZugChain Devnet Settings
    # ═══════════════════════════════════════════════════════════════════════════════
    
    DEVNET_SETTINGS='{"network_name":"zugchain","genesis_fork_version":"0x20000000","exit_fork_version":"0x20000000","genesis_validator_root":"0x0000000000000000000000000000000000000000000000000000000000000000"}'
    
    log_progress "Generating validator keys (this may take a minute)..."
    
    # ═══════════════════════════════════════════════════════════════════════════════
    # METHOD 1: Use ethstaker-deposit-cli with ALL parameters (fully non-interactive)
    # ═══════════════════════════════════════════════════════════════════════════════
    
    cd "$WORK_DIR"
    
    # Run with all arguments passed - this should be non-interactive
    /opt/ethstaker-deposit-cli/deposit existing-mnemonic \
        --num_validators 1 \
        --validator_start_index 0 \
        --mnemonic="$MNEMONIC" \
        --mnemonic_language=english \
        --keystore_password="$KEYSTORE_PASSWORD" \
        --withdrawal_address="$WITHDRAWAL_ADDR" \
        --devnet_chain_setting="$DEVNET_SETTINGS" \
        --folder="$WORK_DIR" 2>&1 | tee "$WORK_DIR/keygen.log"
    
    # Check if keys were generated
    if [ -d "$WORK_DIR/validator_keys" ] && ls "$WORK_DIR/validator_keys"/keystore-*.json 1>/dev/null 2>&1; then
        log_success "Keys generated successfully with ethstaker-deposit-cli!"
    else
        # ═══════════════════════════════════════════════════════════════════════════════
        # METHOD 2: Fallback to Python-based key generation using staking-deposit library
        # ═══════════════════════════════════════════════════════════════════════════════
        
        log_warning "ethstaker-deposit-cli failed, using Python fallback..."
        log_progress "Installing staking-deposit Python library..."
        
        pip3 install staking-deposit py_ecc ssz eth-utils --quiet --break-system-packages 2>/dev/null || \
        pip3 install staking-deposit py_ecc ssz eth-utils --quiet 2>/dev/null
        
        log_progress "Generating keys with Python..."
        
        mkdir -p "$WORK_DIR/validator_keys"
        
        python3 << PYEOF
import json
import os
import sys

# Try to use staking_deposit library
try:
    from staking_deposit.key_handling.key_derivation.mnemonic import get_seed
    from staking_deposit.key_handling.key_derivation.tree import derive_secret_key
    from staking_deposit.key_handling.keystore import ScryptKeystore
    from staking_deposit.utils.constants import DOMAIN_DEPOSIT
    from staking_deposit.utils.validation import validate_password_strength
    from staking_deposit.credentials import CredentialList
    from staking_deposit.settings import get_chain_setting
    
    # Use the library properly
    print("Using staking_deposit library...")
    
except ImportError:
    print("staking_deposit not available, using manual generation...")

# Manual BLS key generation
from py_ecc.bls import G2ProofOfPossession as bls
from hashlib import sha256, pbkdf2_hmac
import hmac
import uuid
import secrets

# EIP-2333 Key Derivation
def flip_bits_256(input_bytes):
    return bytes([b ^ 0xFF for b in input_bytes])

def IKM_to_lamport_SK(IKM, salt):
    assert len(IKM) >= 32
    OKM = pbkdf2_hmac('sha256', IKM, salt, 2, dklen=32 * 255)
    return [OKM[i:i+32] for i in range(0, len(OKM), 32)]

def parent_SK_to_lamport_PK(parent_SK, index):
    salt = index.to_bytes(4, 'big')
    IKM = parent_SK.to_bytes(32, 'big')
    lamport_0 = IKM_to_lamport_SK(IKM, salt)
    not_IKM = flip_bits_256(IKM)
    lamport_1 = IKM_to_lamport_SK(not_IKM, salt)
    lamport_PKs = [sha256(chunk).digest() for chunk in lamport_0 + lamport_1]
    return sha256(b''.join(lamport_PKs)).digest()

def HKDF_mod_r(IKM, key_info=b''):
    L = 48
    salt = b'BLS-SIG-KEYGEN-SALT-'
    SK = 0
    while SK == 0:
        salt = sha256(salt).digest()
        okm = pbkdf2_hmac('sha256', IKM + b'\\x00', salt + key_info + L.to_bytes(2, 'big'), 1, dklen=L)
        SK = int.from_bytes(okm, 'big') % 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
    return SK

def derive_child_SK(parent_SK, index):
    compressed_lamport_PK = parent_SK_to_lamport_PK(parent_SK, index)
    return HKDF_mod_r(compressed_lamport_PK)

def derive_master_SK(seed):
    return HKDF_mod_r(seed)

def mnemonic_to_seed(mnemonic, password=''):
    return pbkdf2_hmac('sha512', mnemonic.encode('utf-8'), ('mnemonic' + password).encode('utf-8'), 2048)

# Generate from mnemonic
mnemonic = """$MNEMONIC"""
password = """$KEYSTORE_PASSWORD"""
withdrawal_address = """$WITHDRAWAL_ADDR"""
work_dir = """$WORK_DIR"""

seed = mnemonic_to_seed(mnemonic)
master_SK = derive_master_SK(seed)

# EIP-2334 path: m/12381/3600/i/0/0 for signing key
# path components: 12381, 3600, validator_index, 0, 0
path = [12381, 3600, 0, 0, 0]
SK = master_SK
for index in path:
    SK = derive_child_SK(SK, index)

signing_key = SK
pubkey = bls.SkToPk(signing_key)

print(f"Generated pubkey: {pubkey.hex()}")

# Create keystore (EIP-2335 format with scrypt)
def create_keystore(secret_key, password, path_str, pubkey_bytes):
    salt = secrets.token_bytes(32)
    
    # Scrypt parameters
    n = 262144
    r = 8
    p = 1
    dklen = 32
    
    # Derive key using scrypt
    from hashlib import scrypt as hashlib_scrypt
    decryption_key = hashlib_scrypt(password.encode(), salt=salt, n=n, r=r, p=p, dklen=dklen)
    
    # AES-128-CTR encryption
    from Crypto.Cipher import AES
    iv = secrets.token_bytes(16)
    cipher = AES.new(decryption_key[:16], AES.MODE_CTR, nonce=iv[:8])
    secret_bytes = secret_key.to_bytes(32, 'big')
    ciphertext = cipher.encrypt(secret_bytes)
    
    # Checksum
    checksum = sha256(decryption_key[16:32] + ciphertext).hexdigest()
    
    keystore = {
        "crypto": {
            "kdf": {
                "function": "scrypt",
                "params": {
                    "dklen": dklen,
                    "n": n,
                    "r": r,
                    "p": p,
                    "salt": salt.hex()
                },
                "message": ""
            },
            "checksum": {
                "function": "sha256",
                "params": {},
                "message": checksum
            },
            "cipher": {
                "function": "aes-128-ctr",
                "params": {
                    "iv": iv.hex()
                },
                "message": ciphertext.hex()
            }
        },
        "pubkey": pubkey_bytes.hex(),
        "path": path_str,
        "uuid": str(uuid.uuid4()),
        "version": 4
    }
    return keystore

# Generate withdrawal credentials (0x01 type with ETH1 address)
withdrawal_creds = bytes.fromhex('01') + bytes(11) + bytes.fromhex(withdrawal_address[2:])

# Create signing data for deposit
fork_version = bytes.fromhex('20000000')
genesis_validators_root = bytes(32)

# Compute deposit message root
def compute_deposit_domain(fork_version, genesis_validators_root):
    domain_type = bytes.fromhex('03000000')  # DOMAIN_DEPOSIT
    fork_data_root = sha256(fork_version + bytes(28)).digest()[:4] + bytes(28)
    return domain_type + sha256(fork_version + genesis_validators_root).digest()[:28]

def compute_signing_root(message_root, domain):
    return sha256(message_root + domain).digest()

# Deposit message: pubkey (48) + withdrawal_credentials (32) + amount (8)
amount = 32000000000  # 32 ETH in gwei
deposit_message = pubkey + withdrawal_creds + amount.to_bytes(8, 'little')

# SSZ hash tree root for DepositMessage
def hash_tree_root_deposit_message(pubkey, withdrawal_creds, amount):
    # Chunks: pubkey (48 bytes padded to 64), withdrawal_creds (32), amount (8 padded to 32)
    pubkey_chunks = [pubkey[:32], pubkey[32:] + bytes(16)]
    wc_chunk = withdrawal_creds
    amount_chunk = amount.to_bytes(8, 'little') + bytes(24)
    
    pubkey_root = sha256(sha256(pubkey_chunks[0]).digest() + sha256(pubkey_chunks[1]).digest()).digest()
    
    left = sha256(pubkey_root + wc_chunk).digest()
    right = sha256(amount_chunk + bytes(32)).digest()
    return sha256(left + right).digest()

deposit_message_root = hash_tree_root_deposit_message(pubkey, withdrawal_creds, amount)

# Compute domain and signing root
domain = compute_deposit_domain(fork_version, genesis_validators_root)
signing_root = compute_signing_root(deposit_message_root, domain)

# Sign the deposit message
signature = bls.Sign(signing_key, signing_root)

# Compute deposit data root (includes signature)
def hash_tree_root_deposit_data(pubkey, withdrawal_creds, amount, signature):
    # DepositMessage root
    msg_root = hash_tree_root_deposit_message(pubkey, withdrawal_creds, amount)
    
    # Signature root (96 bytes = 3 chunks of 32)
    sig_chunks = [signature[:32], signature[32:64], signature[64:] + bytes(16)]
    sig_left = sha256(sha256(sig_chunks[0]).digest() + sha256(sig_chunks[1]).digest()).digest()
    sig_right = sha256(sha256(sig_chunks[2]).digest() + bytes(32)).digest()
    sig_root = sha256(sig_left + sig_right).digest()
    
    return sha256(msg_root + sig_root).digest()

deposit_data_root = hash_tree_root_deposit_data(pubkey, withdrawal_creds, amount, signature)

# Create deposit_data.json
deposit_data = [{
    "pubkey": pubkey.hex(),
    "withdrawal_credentials": withdrawal_creds.hex(),
    "amount": amount,
    "signature": signature.hex(),
    "deposit_message_root": deposit_message_root.hex(),
    "deposit_data_root": deposit_data_root.hex(),
    "fork_version": fork_version.hex(),
    "network_name": "zugchain",
    "deposit_cli_version": "2.7.0"
}]

# Save deposit data
deposit_path = os.path.join(work_dir, 'validator_keys', 'deposit_data.json')
with open(deposit_path, 'w') as f:
    json.dump(deposit_data, f, indent=2)
print(f"Deposit data saved: {deposit_path}")

# Save keystore
import time
timestamp = int(time.time() * 1000)
keystore = create_keystore(signing_key, password, "m/12381/3600/0/0/0", pubkey)
keystore_path = os.path.join(work_dir, 'validator_keys', f'keystore-m_12381_3600_0_0_0-{timestamp}.json')
with open(keystore_path, 'w') as f:
    json.dump(keystore, f, indent=2)
print(f"Keystore saved: {keystore_path}")

print("Key generation complete!")
PYEOF

        if [ $? -ne 0 ]; then
            log_error "Python key generation also failed!"
            exit 1
        fi
    fi
    
    # Verify keys exist
    if [ ! -d "$WORK_DIR/validator_keys" ] || ! ls "$WORK_DIR/validator_keys"/keystore-*.json 1>/dev/null 2>&1; then
        log_error "No keystore files found!"
        exit 1
    fi
    
    log_success "Validator keys generated!"
    
    # Setup ZugChain directory structure
    mkdir -p ${ZUG_DIR}/data/validators/validator_keys/keystores
    
    # Copy keystores
    cp "$WORK_DIR"/validator_keys/keystore-*.json ${ZUG_DIR}/data/validators/validator_keys/keystores/
    
    # Copy deposit data
    if [ -f "$WORK_DIR/validator_keys/deposit_data.json" ]; then
        cp "$WORK_DIR/validator_keys/deposit_data.json" ${ZUG_DIR}/data/validators/validator_keys/deposit_data.json
    else
        cp "$WORK_DIR"/validator_keys/deposit_data-*.json ${ZUG_DIR}/data/validators/validator_keys/deposit_data.json 2>/dev/null || true
    fi
    
    # Clean up workspace
    cd ~
    rm -rf "$WORK_DIR"
    
    # Import to wallet
    log_progress "Importing keys to validator wallet..."
    
    WALLET_PASSWORD="validator_wallet_pass"
    
    if [ ! -d "${ZUG_DIR}/data/validators/wallet" ] || [ ! -f "${ZUG_DIR}/data/validators/wallet/direct/accounts/all-accounts.keystore.json" ]; then
        validator wallet create \
            --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
            --wallet-password-file=<(echo "$WALLET_PASSWORD") \
            --accept-terms-of-use 2>/dev/null || true
    fi
    
    # Import accounts from keystores directory
    validator accounts import \
        --keys-dir="${ZUG_DIR}/data/validators/validator_keys/keystores" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file=<(echo "$WALLET_PASSWORD") \
        --account-password-file=<(echo "$KEYSTORE_PASSWORD") \
        --accept-terms-of-use 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Keys imported to wallet successfully!"
    else
        log_warning "Wallet import had issues, but keys are generated. Manual import may be needed."
    fi
    
    # Save wallet password for later use
    echo "$WALLET_PASSWORD" > ${ZUG_DIR}/data/validators/wallet_password.txt
    chmod 600 ${ZUG_DIR}/data/validators/wallet_password.txt
    
    # Store keystore password for reference
    echo "$KEYSTORE_PASSWORD" > ${ZUG_DIR}/data/validators/keystore_password.txt
    chmod 600 ${ZUG_DIR}/data/validators/keystore_password.txt
    
    # Save mnemonic securely (user should also have written it down)
    echo "$MNEMONIC" > ${ZUG_DIR}/data/validators/mnemonic.txt
    chmod 600 ${ZUG_DIR}/data/validators/mnemonic.txt
    log_warning "Mnemonic saved to ${ZUG_DIR}/data/validators/mnemonic.txt - KEEP THIS SAFE!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: GENERATE DEPOSIT DATA
# ═══════════════════════════════════════════════════════════════════════════════

generate_deposit_hex() {
    print_step "4" "Generating Deposit Data"
    
    # eth2-val-tools generates deposit_data.json (not deposit_data-*.json)
    DEPOSIT_FILE="${ZUG_DIR}/data/validators/validator_keys/deposit_data.json"
    
    if [ ! -f "$DEPOSIT_FILE" ]; then
        log_error "Deposit data file not found!"
        exit 1
    fi
    
    # Generate Metamask hex
    METAMASK_HEX=$(python3 << PYEOF
from eth_abi import encode
import json

with open('$DEPOSIT_FILE', 'r') as f:
    data = json.load(f)[0]

selector = '0x22895118'
pubkey = bytes.fromhex(data['pubkey'])
withdrawal = bytes.fromhex(data['withdrawal_credentials'])
signature = bytes.fromhex(data['signature'])
root = bytes.fromhex(data['deposit_data_root'])

encoded = encode(['bytes', 'bytes', 'bytes', 'bytes32'], [pubkey, withdrawal, signature, root])
print(selector + encoded.hex())
PYEOF
)
    
    # Get pubkey for display
    PUBKEY=$(jq -r '.[0].pubkey' "$DEPOSIT_FILE")
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}DEPOSIT DATA READY!${NC}${GREEN}                                                      ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Validator Public Key:${NC}"
    echo -e "${DIM}${PUBKEY}${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}METAMASK HEX DATA (copy this):${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}${METAMASK_HEX}${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}INSTRUCTIONS:${NC}"
    echo -e "  ${CYAN}1.${NC} Open Metamask"
    echo -e "  ${CYAN}2.${NC} Send ${YELLOW}32 ZUG${NC} to: ${CYAN}${DEPOSIT_CONTRACT}${NC}"
    echo -e "  ${CYAN}3.${NC} Click 'Hex Data' in advanced options"
    echo -e "  ${CYAN}4.${NC} Paste the hex data above"
    echo -e "  ${CYAN}5.${NC} Confirm the transaction"
    echo ""
    
    # Save hex for reference
    echo "$METAMASK_HEX" > ${ZUG_DIR}/deposit_hex.txt
    log_success "Deposit hex saved to ${ZUG_DIR}/deposit_hex.txt"
    
    echo ""
    echo -e "${YELLOW}After you've sent 32 ZUG, press ENTER to continue...${NC}"
    read </dev/tty
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: START SERVICES
# ═══════════════════════════════════════════════════════════════════════════════

start_services() {
    print_step "5" "Starting Validator Services"
    
    # Bootnodes from main chain
    MAIN_ENODE="enode://5a5927c4413f0a073d209c4721593109ae4375e10bfa68f53588c2f9a60c32e61f2a040433c341e5df29780d46f2ee070924b33393481e32214a430b69e38b7b@16.171.135.45:30303"
    MAIN_ENR="enr:-Mq4QIFjlF_NMt3t8zgVcoKI8gp5Pxm63Yv6gCqzlnJWjPimA6V0L9UGuQS7eqZrLiOa7bP24_eAt1U7BhCp5ES8zUmGAZt_-DhUh2F0dG5ldHOIAAAAAIABAACEZXRoMpBIuSGSIAAABf__________gmlkgnY0gmlwhKwfLf-EcXVpY4IyyIlzZWNwMjU2azGhAxcmRn6UAdFt9sRL7cQ0i7K8afOjHSrEowD3RqIf4NAeiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g"
    
    # Try to get latest bootnode info
    log_info "Getting bootnode information from main node..."
    ENODE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
        http://${MAIN_NODE_IP}:8545 2>/dev/null | jq -r '.result.enode' 2>/dev/null)
    
    if [ -n "$ENODE" ] && [ "$ENODE" != "null" ]; then
        MAIN_ENODE="$ENODE"
        log_success "Got ENODE from main node"
    else
        log_warning "Could not get ENODE - using fallback"
    fi
    
    # Initialize Geth
    log_progress "Initializing Geth..."
    geth init --datadir="${ZUG_DIR}/data/geth" --state.scheme=path "${ZUG_DIR}/config/genesis.json" 2>/dev/null
    log_success "Geth initialized"
    
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
        --syncmode=full \
        --bootnodes="${MAIN_ENODE}" \
        > ${ZUG_DIR}/logs/geth.log 2>&1 &
    GETH_PID=$!
    echo $GETH_PID > ${ZUG_DIR}/geth.pid
    log_success "Geth started (PID: $GETH_PID)"
    
    sleep 5
    
    # Start Beacon Chain
    log_progress "Starting Beacon Chain (Consensus Layer)..."
    
    # Get public IP for p2p
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
        --suggested-fee-recipient="${WITHDRAWAL_ADDR:-0x0000000000000000000000000000000000000000}" \
        > ${ZUG_DIR}/logs/validator.log 2>&1 &
    VAL_PID=$!
    echo $VAL_PID > ${ZUG_DIR}/validator.pid
    log_success "Validator started (PID: $VAL_PID)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

print_summary() {
    print_step "6" "Setup Complete!"
    
    GETH_PID=$(cat ${ZUG_DIR}/geth.pid 2>/dev/null || echo "N/A")
    BEACON_PID=$(cat ${ZUG_DIR}/beacon.pid 2>/dev/null || echo "N/A")
    VAL_PID=$(cat ${ZUG_DIR}/validator.pid 2>/dev/null || echo "N/A")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}🎉 ZUGCHAIN VALIDATOR IS NOW RUNNING! 🎉${NC}${GREEN}                                   ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Service Status:${NC}"
    echo -e "  ${CYAN}Geth PID:${NC}      $GETH_PID"
    echo -e "  ${CYAN}Beacon PID:${NC}    $BEACON_PID"
    echo -e "  ${CYAN}Validator PID:${NC} $VAL_PID"
    echo ""
    echo -e "${WHITE}${BOLD}Log Files:${NC}"
    echo -e "  ${CYAN}Geth:${NC}      ${ZUG_DIR}/logs/geth.log"
    echo -e "  ${CYAN}Beacon:${NC}    ${ZUG_DIR}/logs/beacon.log"
    echo -e "  ${CYAN}Validator:${NC} ${ZUG_DIR}/logs/validator.log"
    echo ""
    echo -e "${WHITE}${BOLD}Useful Commands:${NC}"
    echo -e "  ${CYAN}Watch logs:${NC}  tail -f ${ZUG_DIR}/logs/validator.log"
    echo -e "  ${CYAN}Check sync:${NC}  curl -s http://localhost:3500/eth/v1/node/syncing | jq"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Wait for the beacon to sync, then your validator will start proposing blocks!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    check_root
    
    echo -e "${WHITE}This script will set up your ZugChain validator node.${NC}"
    echo -e "${WHITE}Make sure you have copied the genesis files from the main node.${NC}"
    echo ""
    press_enter
    
    check_config_files
    cleanup_old_files
    install_dependencies
    setup_directories
    generate_validator_keys
    generate_deposit_hex
    start_services
    print_summary
}

# Run main
main "$@"
