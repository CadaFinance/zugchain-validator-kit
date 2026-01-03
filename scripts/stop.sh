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
#    Graceful Shutdown v2.0
#    Enterprise-grade stop script with data protection
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"
TOOLS_DIR="${ZUG_DIR}/tools"
PRYSMCTL="${TOOLS_DIR}/prysmctl"
PRYSM_VERSION="v5.3.0"

# ══════════════════════════════════════════════════════════════════════════════
# DATA PROTECTION
# ══════════════════════════════════════════════════════════════════════════════

ensure_prysmctl() {
    [ -f "$PRYSMCTL" ] && return
    
    log_info "Fetching prysmctl for data export..."
    mkdir -p "$TOOLS_DIR"
    wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${PRYSM_VERSION}/prysmctl-${PRYSM_VERSION}-linux-amd64" -O "$PRYSMCTL"
    chmod +x "$PRYSMCTL"
}

export_slashing_db() {
    log_header "Slashing Protection Export"
    
    ensure_prysmctl
    if [ ! -f "$PRYSMCTL" ]; then
        log_warning "Could not download prysmctl - skipping export"
        return
    fi
    
    # Export only if validator data exists
    if [ ! -d "${ZUG_DIR}/data/validators" ]; then
        return
    fi
    
    BACKUP_DIR="${ZUG_DIR}/backups/stop-export-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    "$PRYSMCTL" validator slashing-protection-history export \
        --datadir="${ZUG_DIR}/data/validators" \
        --slashing-protection-export-dir="$BACKUP_DIR" > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        log_success "Database exported to: ${BACKUP_DIR##*/}"
    else
        log_warning "Export failed (Is validator active?)"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# SHUTDOWN LOGIC
# ══════════════════════════════════════════════════════════════════════════════

stop_service() {
    local name=$1
    local service=$2
    local process=$3
    
    # Try systemd first
    if systemctl is-active --quiet "$service"; then
        log_info "Stopping $name (Systemd)..."
        systemctl stop "$service"
        
        # Verify
        if ! systemctl is-active --quiet "$service"; then
            log_success "$name stopped"
        else
            log_warning "$name failed to stop"
        fi
        return
    fi
    
    # Fallback to Process Kill
    if pgrep -f "$process" > /dev/null; then
        log_info "Stopping $name (SIGTERM)..."
        pkill -TERM -f "$process"
        
        # Wait loop
        for i in {1..10}; do
            if ! pgrep -f "$process" > /dev/null; then
                log_success "$name stopped"
                return
            fi
            sleep 1
        done
        
        # Force Kill
        log_warning "$name stuck - forcing kill (SIGKILL)"
        pkill -KILL -f "$process"
        log_success "$name killed"
    else
        log_info "$name already stopped"
    fi
}

main() {
    check_root
    print_banner
    
    # Optional export
    export_slashing_db
    
    echo ""
    log_header "Stopping Services"
    
    # Stop Order: Validator -> Beacon -> Geth
    stop_service "Validator" "zugchain-validator" "validator.*wallet"
    stop_service "Beacon Chain" "zugchain-beacon" "beacon-chain"
    stop_service "Geth" "zugchain-geth" "geth.*zugchain"
    
    echo ""
    log_success "All services stopped"
}

main "$@"
