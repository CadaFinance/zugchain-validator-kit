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
#    Master Setup Wizard v6.0 (Enterprise)
#    Orchestrates the entire validator installation process
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

# Configuration
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIGS_SRC="${PACKAGE_ROOT}/configs"
ZUG_DIR="/opt/zugchain-validator"
MAIN_NODE_IP="16.171.135.45"
NETWORK_ID=1843932

# Reopen stdin for interactive input
exec < /dev/tty

# ══════════════════════════════════════════════════════════════════════════════
# MODULES
# ══════════════════════════════════════════════════════════════════════════════

checks_preflight() {
    log_header "System Pre-flight Check"
    
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local cpu_cores=$(nproc)
    
    # RAM Check (warn if < 8GB)
    if [ $mem_kb -lt 8000000 ]; then
        log_warning "Detected RAM: $(format_bytes $(($mem_kb * 1024))) (Recommended: 16GB)"
    else
        log_success "RAM: $(format_bytes $(($mem_kb * 1024)))"
    fi
    
    # CPU Check
    log_success "CPU Cores: $cpu_cores"
    
    # Ubuntu Check
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "OS is not Ubuntu. This script is optimized for Ubuntu 22.04+"
    else
        log_success "OS: Ubuntu Detected"
    fi
    
    echo ""
}

install_dependencies() {
    log_header "Installing Core Dependencies"
    
    log_info "Updating package lists..."
    apt-get update -qq > /dev/null 2>&1
    
    local deps=(curl wget git jq python3-pip build-essential ufw fail2ban)
    for dep in "${deps[@]}"; do
        log_prompt "Installing $dep..."
        apt-get install -y $dep -qq > /dev/null 2>&1
        echo -e "${COLOR_SUCCESS} Done${RESET}"
    done
    
    # Install Geth
    if ! command -v geth &> /dev/null; then
        log_info "Installing Geth..."
        add-apt-repository -y ppa:ethereum/ethereum > /dev/null 2>&1
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y geth -qq > /dev/null 2>&1
    fi
    log_success "Geth installed ($(geth version | head -n1 | awk '{print $3}'))"
    
    # Install Prysm
    if ! command -v beacon-chain &> /dev/null; then
        log_info "Installing Prysm..."
        mkdir -p /opt/zugchain-validator/tools
        curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh &> /dev/null
        chmod +x prysm.sh
        ./prysm.sh beacon-chain --download-only &> /dev/null
        ./prysm.sh validator --download-only &> /dev/null
        mv ./dist/beacon-chain /usr/local/bin/
        mv ./dist/validator /usr/local/bin/
        rm -rf prysm.sh dist
    fi
    log_success "Prysm installed"
    
    # Install Deposit CLI (Binary Release)
    if [ ! -f "/opt/ethstaker-deposit-cli/deposit" ]; then
        log_info "Installing Deposit CLI..."
        rm -rf /opt/ethstaker-deposit-cli
        mkdir -p /opt/ethstaker-deposit-cli
        
        cd /tmp
        wget -q https://github.com/eth-educators/ethstaker-deposit-cli/releases/download/v1.2.2/ethstaker_deposit-cli-b13dcb9-linux-amd64.tar.gz -O deposit_cli.tar.gz
        tar -xzf deposit_cli.tar.gz
        mv ethstaker_deposit-cli-b13dcb9-linux-amd64/* /opt/ethstaker-deposit-cli/
        chmod +x /opt/ethstaker-deposit-cli/deposit
        rm -rf deposit_cli.tar.gz ethstaker_deposit-cli*
    fi
    log_success "Deposit CLI installed"
    
    # Python helpers
    pip3 install eth-utils --quiet --break-system-packages 2>/dev/null || pip3 install eth-utils --quiet 2>/dev/null
}

setup_directories() {
    log_header "Directory Configuration"
    
    # Create structure
    mkdir -p ${ZUG_DIR}/{data,logs,config,secrets,backups,tools}
    mkdir -p ${ZUG_DIR}/data/{geth,beacon,validators}
    
    # Copy configs
    cp "${CONFIGS_SRC}/genesis.json" "${ZUG_DIR}/config/"
    cp "${CONFIGS_SRC}/genesis.ssz" "${ZUG_DIR}/config/"
    cp "${CONFIGS_SRC}/config.yml" "${ZUG_DIR}/config/"
    
    # Generate JWT
    if [ ! -f "${ZUG_DIR}/secrets/jwt.hex" ]; then
        openssl rand -hex 32 | tr -d "\n" > "${ZUG_DIR}/secrets/jwt.hex"
        chmod 600 "${ZUG_DIR}/secrets/jwt.hex"
        
        # Legacy compat
        cp "${ZUG_DIR}/secrets/jwt.hex" "${ZUG_DIR}/data/jwt.hex"
    fi
    
    log_success "Directories and configurations active"
}

handle_keys() {
    log_header "Validator Key Management"
    
    echo -e "  ${ZUG_WHITE}How would you like to handle validator keys?${RESET}"
    echo -e "  ${DIM}(Recommended: Option 1 for maximum security)${RESET}"
    echo ""
    echo -e "  ${ZUG_TEAL}[1]${RESET} Import keys generated OFFLINE (Air-gapped)"
    echo -e "  ${ZUG_TEAL}[2]${RESET} Generate keys LOCALLY on this server"
    echo ""
    log_prompt "Select option [1-2]"
    read -r KEY_OPT
    
    if [ "$KEY_OPT" == "1" ]; then
        log_info "Starting Import Wizard..."
        echo ""
        log_prompt "Enter path to offline keys folder"
        read -r KEYS_PATH
        
        if [ -d "$KEYS_PATH" ]; then
            bash "${SCRIPT_DIR}/import-keys.sh" --keys-dir "$KEYS_PATH"
        else
            log_error "Directory not found. Falling back to local generation menu."
            handle_keys
        fi
        
    else
        log_warning "Generating keys on an online machine has risks."
        bash "${SCRIPT_DIR}/add-validator.sh" --setup-mode
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN FLOW
# ══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    print_banner
    checks_preflight
    
    # Mode Selection
    echo -e "  ${ZUG_WHITE}${BOLD}Select Installation Mode:${RESET}"
    echo -e "  ${ZUG_TEAL}[1] Enterprise Setup${RESET} (Recommended)"
    echo -e "      ${DIM}• Systemd Services (Auto-restart, Logging)${RESET}"
    echo -e "      ${DIM}• Security Hardening (Firewall, Fail2ban)${RESET}"
    echo -e "      ${DIM}• Monitoring Stack (Prometheus, Grafana)${RESET}"
    echo -e "      ${DIM}• Offline Key Support${RESET}"
    echo ""
    echo -e "  ${ZUG_TEAL}[2] Legacy Setup${RESET}"
    echo -e "      ${DIM}• Basic nohup background processes${RESET}"
    echo -e "      ${DIM}• No enhanced security or monitoring${RESET}"
    echo ""
    
    log_prompt "Enter choice [1-2]"
    read -r MODE
    
    # Start Installation
    install_dependencies
    setup_directories
    
    if [ "$MODE" == "1" ]; then
        # ENTERPRISE FLOW
        
        # 1. Security Hardening
        log_header "Security Hardening"
        bash "${SCRIPT_DIR}/security-harden.sh"
        
        # 2. Key Management
        handle_keys
        
        # 3. Service Setup
        log_header "Systemd Service Configuration"
        bash "${SCRIPT_DIR}/zugchain-services.sh"
        
        # 4. Monitoring
        log_header "Monitoring Setup"
        log_prompt "Install Prometheus & Grafana dashboard? [Y/n]"
        read -r MON_OPT
        if [[ "$MON_OPT" =~ ^[Yy] || -z "$MON_OPT" ]]; then
            bash "${SCRIPT_DIR}/monitor-setup.sh"
        else
            log_info "Skipping monitoring setup"
        fi
        
        # 5. Start Services
        log_header "Starting Services"
        systemctl daemon-reload
        systemctl enable zugchain-geth zugchain-beacon zugchain-validator
        systemctl start zugchain-geth zugchain-beacon zugchain-validator
        
        # 6. Verify Health
        bash "${SCRIPT_DIR}/health.sh" --quiet
        
    else
        # LEGACY FLOW (Fallback)
        log_warning "Running in Legacy Mode..."
        handle_keys
        bash "${SCRIPT_DIR}/start.sh" --legacy
    fi
    
    # FINAL SUMMARY
    clear
    log_header "Installation Complete"
    
    echo -e "  ${ZUG_WHITE}${BOLD}Congratulations! Your ZugChain Validator is active.${RESET}"
    echo ""
    echo -e "  ${ZUG_TEAL}Useful Commands:${RESET}"
    echo -e "    • Check Status:    ${BOLD}sudo ./health.sh${RESET}"
    echo -e "    • Stop Node:       ${BOLD}sudo ./stop.sh${RESET}"
    echo -e "    • View Logs:       ${BOLD}journalctl -fu zugchain-beacon${RESET}"
    
    if [ "$MODE" == "1" ] && [[ "$MON_OPT" =~ ^[Yy] || -z "$MON_OPT" ]]; then
        IP=$(curl -s ifconfig.me)
        echo -e "    • Dashboard:       ${BOLD}http://${IP}:3000${RESET} (admin/admin)"
    fi
    
    echo ""
    echo -e "  ${COLOR_WARNING}Don't forget to backup your mnemonic offline!${RESET}"
    echo ""
}

main "$@"
