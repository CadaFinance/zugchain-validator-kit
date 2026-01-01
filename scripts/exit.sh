#!/bin/bash
#===============================================================================
# ZUG CHAIN - VALIDATOR EXIT SCRIPT
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

TOOLS_DIR="/opt/zugchain-validator/tools"
PRYSMCTL="${TOOLS_DIR}/prysmctl"
PRYSM_VERSION="v5.3.0"

log_info "Preparing Validator Exit Process..."

# 1. Prepare Directory & Download prysmctl if needed
if [ ! -f "$PRYSMCTL" ]; then
    log_info "Prysmctl not found. Downloading version ${PRYSM_VERSION}..."
    mkdir -p "$TOOLS_DIR"
    
    wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${PRYSM_VERSION}/prysmctl-${PRYSM_VERSION}-linux-amd64" -O "$PRYSMCTL"
    
    if [ $? -eq 0 ]; then
        chmod +x "$PRYSMCTL"
        log_success "Prysmctl installed to $PRYSMCTL"
    else
        log_error "Failed to download prysmctl. Check internet connection."
        exit 1
    fi
else
    log_info "Prysmctl found at $PRYSMCTL"
fi

# 2. Check Wallet Files
WALLET_DIR="/opt/zugchain-validator/data/validators/wallet"
PASS_FILE="/opt/zugchain-validator/data/validators/wallet_password.txt"

if [ ! -d "$WALLET_DIR" ]; then
    log_error "Wallet directory not found at $WALLET_DIR"
    exit 1
fi

if [ ! -f "$PASS_FILE" ]; then
    log_error "Password file not found at $PASS_FILE"
    exit 1
fi

# 3. Execute Exit
log_warning "==================================================="
log_warning " AUTHORIZATION REQUIRED"
log_warning "==================================================="
log_warning "You are about to exit your validator from the network."
log_warning "This action is IRREVERSIBLE."
log_warning "Your 32 ZUG + Rewards will be withdrawn to your address."
log_warning "Wait time: ~27 hours (256 epochs) after activation."
log_warning "==================================================="
echo ""
read -p "Type 'EXIT' to confirm and proceed: " CONFIRM

if [ "$CONFIRM" != "EXIT" ]; then
    log_error "Operation cancelled by user."
    exit 0
fi

echo ""
log_info "Starting exit procedure using local RPC (127.0.0.1:4000)..."
log_info "Follow the on-screen prompts to select your account."

"$PRYSMCTL" validator exit \
  --wallet-dir="$WALLET_DIR" \
  --beacon-rpc-provider="127.0.0.1:4000" \
  --wallet-password-file="$PASS_FILE"

if [ $? -eq 0 ]; then
    echo ""
    log_success "Exit command executed successfully."
    log_info "If you saw 'Success', your validator is now in the exit queue."
    log_info "Do NOT stop your validator service until the exit epoch is reached."
else
    echo ""
    log_error "Exit command failed."
    log_warning "If the error was 'not active long enough', please wait and try again later."
fi
