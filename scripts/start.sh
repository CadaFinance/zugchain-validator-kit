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
#    Start Script v2.1
#    Enterprise-grade service startup with health verification
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

# Configuration
ZUG_DIR="/opt/zugchain-validator"
MAIN_NODE_IP="16.171.135.45"
NETWORK_ID=1843932
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"
MAIN_ENODE="enode://5a5927c4413f0a073d209c4721593109ae4375e10bfa68f53588c2f9a60c32e61f2a040433c341e5df29780d46f2ee070924b33393481e32214a430b69e38b7b@16.171.135.45:30303"
MAIN_ENR="enr:-Mq4QIFjlF_NMt3t8zgVcoKI8gp5Pxm63Yv6gCqzlnJWjPimA6V0L9UGuQS7eqZrLiOa7bP24_eAt1U7BhCp5ES8zUmGAZt_-DhUh2F0dG5ldHOIAAAAAIABAACEZXRoMpBIuSGSIAAABf__________gmlkgnY0gmlwhKwfLf-EcXVpY4IyyIlzZWNwMjU2azGhAxcmRn6UAdFt9sRL7cQ0i7K8afOjHSrEowD3RqIf4NAeiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g"

# ══════════════════════════════════════════════════════════════════════════════
# SYSTEMD MODE
# ══════════════════════════════════════════════════════════════════════════════

start_systemd() {
    log_header "Starting Systemd Services"
    
    # Start Geth
    log_info "Starting Geth..."
    systemctl start zugchain-geth.service
    sleep 3
    
    if systemctl is-active --quiet zugchain-geth.service; then
        log_success "Geth active"
    else
        log_error "Geth failed to start (Check 'journalctl -u zugchain-geth')"
        exit 1
    fi
    
    # Start Beacon
    log_info "Starting Beacon Chain..."
    systemctl start zugchain-beacon.service
    sleep 5
    
    if systemctl is-active --quiet zugchain-beacon.service; then
        log_success "Beacon active"
    else
        log_error "Beacon failed to start (Check 'journalctl -u zugchain-beacon')"
        exit 1
    fi
    
    # Start Validator
    log_info "Starting Validator..."
    systemctl start zugchain-validator.service
    sleep 3
    
    if systemctl is-active --quiet zugchain-validator.service; then
        log_success "Validator active"
    else
        log_error "Validator failed to start (Check 'journalctl -u zugchain-validator')"
        exit 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# LEGACY MODE (nohup fallback)
# ══════════════════════════════════════════════════════════════════════════════

start_legacy() {
    log_warning "Running in Legacy Mode (nohup)"
    log_info "Consider upgrading to systemd via 'setup.sh'"
    
    # Stop old processes
    pkill -f "geth.*zugchain" 2>/dev/null || true
    pkill -f "beacon-chain" 2>/dev/null || true
    pkill -f "validator.*wallet" 2>/dev/null || true
    sleep 3
    
    mkdir -p ${ZUG_DIR}/logs
    
    # JWT
    JWT_SECRET="${ZUG_DIR}/secrets/jwt.hex"
    [ ! -f "$JWT_SECRET" ] && JWT_SECRET="${ZUG_DIR}/data/jwt.hex"
    
    # 1. Start Geth
    log_info "Starting Geth..."
    nohup geth \
        --datadir="${ZUG_DIR}/data/geth" \
        --networkid=${NETWORK_ID} \
        --http --http.addr="0.0.0.0" --http.port=8545 \
        --http.api="eth,net,web3,admin,debug" \
        --http.corsdomain="*" --http.vhosts="*" \
        --authrpc.addr="127.0.0.1" --authrpc.port=8551 --authrpc.vhosts="*" \
        --authrpc.jwtsecret="$JWT_SECRET" \
        --syncmode=full \
        --gcmode=archive --state.scheme=path \
        --bootnodes="${MAIN_ENODE}" \
        > ${ZUG_DIR}/logs/geth.log 2>&1 &
    
    echo $! > ${ZUG_DIR}/geth.pid
    log_success "Geth started (PID: $!)"
    
    sleep 5
    
    # 2. Start Beacon
    log_info "Starting Beacon..."
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "0.0.0.0")
    
    nohup beacon-chain \
        --datadir="${ZUG_DIR}/data/beacon" \
        --genesis-state="${ZUG_DIR}/config/genesis.ssz" \
        --chain-config-file="${ZUG_DIR}/config/config.yml" \
        --execution-endpoint="http://127.0.0.1:8551" \
        --jwt-secret="$JWT_SECRET" \
        --accept-terms-of-use \
        --deposit-contract=${DEPOSIT_CONTRACT} \
        --contract-deployment-block=0 \
        --min-sync-peers=0 \
        --checkpoint-sync-url="http://${MAIN_NODE_IP}:3500" \
        --genesis-beacon-api-url="http://${MAIN_NODE_IP}:3500" \
        --bootstrap-node="${MAIN_ENR}" \
        --p2p-host-ip="${PUBLIC_IP}" \
        --monitoring-host=0.0.0.0 --monitoring-port=8080 \
        > ${ZUG_DIR}/logs/beacon.log 2>&1 &
    
    echo $! > ${ZUG_DIR}/beacon.pid
    log_success "Beacon started (PID: $!)"
    
    sleep 5
    
    # 3. Start Validator
    log_info "Starting Validator..."
    
    # wallet password
    PASS_FILE="${ZUG_DIR}/secrets/wallet_password"
    [ ! -f "$PASS_FILE" ] && PASS_FILE="${ZUG_DIR}/data/validators/wallet_password.txt"
    
    nohup validator \
        --datadir="${ZUG_DIR}/data/validators" \
        --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
        --wallet-password-file="$PASS_FILE" \
        --beacon-rpc-provider="127.0.0.1:4000" \
        --chain-config-file="${ZUG_DIR}/config/config.yml" \
        --accept-terms-of-use \
        > ${ZUG_DIR}/logs/validator.log 2>&1 &
    
    echo $! > ${ZUG_DIR}/validator.pid
    log_success "Validator started (PID: $!)"
}

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH CHECK
# ══════════════════════════════════════════════════════════════════════════════

wait_for_health() {
    echo ""
    log_info "Waiting for health checks..."
    
    # Spinner for Geth
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            http://127.0.0.1:8545 2>/dev/null | grep -q "result"; then
            log_success "Geth RPC online"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "Geth RPC slow to respond (This is normal during sync)"
    fi
}

main() {
    check_root
    print_banner
    
    SKIP_HEALTH=false
    LEGACY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-health) SKIP_HEALTH=true; shift ;;
            --legacy) LEGACY=true; shift ;;
            *) shift ;;
        esac
    done
    
    if [ "$LEGACY" = true ]; then
        start_legacy
    elif systemctl list-unit-files | grep -q "zugchain-geth.service"; then
        start_systemd
    else
        start_legacy
    fi
    
    if [ "$SKIP_HEALTH" = false ]; then
        wait_for_health
    fi
    
    echo ""
    log_success "Startup Sequence Complete"
}

main "$@"
