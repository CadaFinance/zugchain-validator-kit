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
#    Enterprise Backup v2.0
#    Full node backup with encryption support
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"
export BACKUP_ROOT="${ZUG_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="zugchain_backup_${TIMESTAMP}"
TEMP_DIR="/tmp/${BACKUP_NAME}"

# ══════════════════════════════════════════════════════════════════════════════
# COMPONENT BACKUPS
# ══════════════════════════════════════════════════════════════════════════════

backup_slashing_protection() {
    log_info "Exporting slashing protection DB..."
    mkdir -p "${TEMP_DIR}/slashing_protection"
    
    # Check if tools exist
    if [ -f "${ZUG_DIR}/tools/prysmctl" ]; then
        ${ZUG_DIR}/tools/prysmctl validator slashing-protection-history export \
            --datadir="${ZUG_DIR}/data/validators" \
            --slashing-protection-export-dir="${TEMP_DIR}/slashing_protection" > /dev/null 2>&1
            
        if [ $? -eq 0 ]; then
            log_success "Slashing DB exported"
        else
            log_warning "Slashing DB export failed (Service might be stopped?)"
        fi
    else
        log_warning "prysmctl not found - skipping slashing DB export"
    fi
}

backup_keys_and_secrets() {
    log_info "Backing up keys and secrets..."
    
    # Keystores
    mkdir -p "${TEMP_DIR}/validator_keys"
    if [ -d "${ZUG_DIR}/data/validators/validator_keys" ]; then
        cp -r "${ZUG_DIR}/data/validators/validator_keys/"* "${TEMP_DIR}/validator_keys/" 2>/dev/null
        log_success "Keystores backed up"
    fi
    
    # Wallet
    mkdir -p "${TEMP_DIR}/wallet"
    if [ -d "${ZUG_DIR}/data/validators/wallet" ]; then
        cp -r "${ZUG_DIR}/data/validators/wallet/"* "${TEMP_DIR}/wallet/" 2>/dev/null
        log_success "Wallet backed up"
    fi
    
    # Secrets
    mkdir -p "${TEMP_DIR}/secrets"
    if [ -d "${ZUG_DIR}/secrets" ]; then
        cp -r "${ZUG_DIR}/secrets/"* "${TEMP_DIR}/secrets/" 2>/dev/null
        log_success "Secrets backed up"
    fi
}

backup_config() {
    log_info "Backing up configuration..."
    mkdir -p "${TEMP_DIR}/config"
    cp -r "${ZUG_DIR}/config/"* "${TEMP_DIR}/config/" 2>/dev/null
}

encrypt_backup() {
    local archive="$1"
    log_header "Encryption"
    
    log_prompt "Enter password for backup encryption"
    read -s -r ENC_PASS
    echo ""
    log_prompt "Confirm password"
    read -s -r ENC_PASS2
    echo ""
    
    if [ "$ENC_PASS" != "$ENC_PASS2" ]; then
        log_error "Passwords do not match"
        exit 1
    fi
    
    openssl enc -aes-256-cbc -salt -in "$archive" -out "${archive}.enc" -pass pass:"$ENC_PASS"
    
    if [ $? -eq 0 ]; then
        rm "$archive"
        log_success "Encryption successful (${archive##*/}.enc)"
    else
        log_error "Encryption failed"
        exit 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    print_banner
    
    ENCRYPT=false
    OUTPUT_DIR="$BACKUP_ROOT"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --encrypt) ENCRYPT=true; shift ;;
            --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    mkdir -p "$TEMP_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    log_header "Starting Backup"
    log_info "Temp ID: ${BACKUP_NAME}"
    
    backup_slashing_protection
    backup_keys_and_secrets
    backup_config
    
    # Create Archive
    log_info "Creating archive..."
    tar -czf "${OUTPUT_DIR}/${BACKUP_NAME}.tar.gz" -C "/tmp" "${BACKUP_NAME}"
    
    rm -rf "$TEMP_DIR"
    
    FINAL_FILE="${OUTPUT_DIR}/${BACKUP_NAME}.tar.gz"
    
    if [ "$ENCRYPT" = true ]; then
        encrypt_backup "$FINAL_FILE"
        FINAL_FILE="${FINAL_FILE}.enc"
    fi
    
    echo ""
    log_success "Backup Complete!"
    echo -e "  ${BOLD}Location:${RESET} $FINAL_FILE"
    echo -e "  ${BOLD}Size:${RESET}     $(du -h "$FINAL_FILE" | cut -f1)"
}

main "$@"
