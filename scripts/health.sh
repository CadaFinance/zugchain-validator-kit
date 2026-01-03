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
#    Health Monitor v2.0
#    Integrated health checks with JSON support
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Only source utils if not in JSON or Quiet mode to avoid polluting stdout
if [[ "$*" != *"--json"* ]] && [[ "$*" != *"--quiet"* ]]; then
    source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }
fi

ZUG_DIR="/opt/zugchain-validator"

# Custom colors for isolated runs (if utils not loaded)
# This ensures JSON output stays pure
if [ -z "$ZUG_TEAL" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    ZUG_TEAL=$BLUE
    COLOR_SUCCESS=$GREEN
    COLOR_WARNING=$YELLOW
    COLOR_ERROR=$RED
    RESET=$NC
    BOLD=''
    log_info() { echo "INFO: $1"; }
    log_success() { echo "SUCCESS: $1"; }
    log_header() { echo "--- $1 ---"; }
fi

# ══════════════════════════════════════════════════════════════════════════════
# METRICS COLLECTION
# ══════════════════════════════════════════════════════════════════════════════

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

get_memory_usage() {
    free | grep Mem | awk '{print $3/$2 * 100.0}' | awk -F. '{print $1}'
}

check_service_pid() {
    local pid_file="$1"
    local process_name="$2"
    local service_name="$3"
    
    # Check Systemd first
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo "running"
        return
    fi
    
    # Check PID file
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "running"
            return
        fi
    fi
    
    # Check process name
    if pgrep -f "$process_name" > /dev/null; then
        echo "running"
        return
    fi
    
    echo "stopped"
}

get_geth_status() {
    local status="unknown"
    local block="0"
    local peers="0"
    local sync="false"
    
    # Try RPC
    local response=$(curl -s -m 2 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://127.0.0.1:8545 2>/dev/null)
        
    if [ -n "$response" ]; then
        status="active"
        if [[ "$response" == *"false"* ]]; then
            sync="synced"
            # Get block height
            block=$(curl -s -m 1 -X POST -H "Content-Type: application/json" \
                --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
                http://127.0.0.1:8545 | jq -r '.result' | xargs printf "%d")
        else
            sync="syncing"
            block=$(echo "$response" | jq -r '.result.currentBlock' | xargs printf "%d")
        fi
        
        # Get Peer Count
        peers=$(curl -s -m 1 -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
            http://127.0.0.1:8545 | jq -r '.result' | xargs printf "%d")
    else
        status="down"
    fi
    
    echo "$status|$sync|$block|$peers"
}

get_beacon_status() {
    local status="unknown"
    local sync="false"
    local peers="0"
    
    local health=$(curl -s -m 2 http://127.0.0.1:3500/eth/v1/node/health 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        status="active"
        # Check sync
        local sync_resp=$(curl -s -m 1 http://127.0.0.1:3500/eth/v1/node/syncing 2>/dev/null)
        if [[ "$sync_resp" == *"is_syncing\":false"* ]]; then
             sync="synced"
        else
             sync="syncing"
        fi
        
        # Check peers
        local peers_resp=$(curl -s -m 1 http://127.0.0.1:3500/eth/v1/node/peers 2>/dev/null)
        peers=$(echo "$peers_resp" | jq -r '.data | length' 2>/dev/null || echo "0")
    else
        status="down"
    fi
    
    echo "$status|$sync|$peers"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOGIC
# ══════════════════════════════════════════════════════════════════════════════

main() {
    IS_QUIET=false
    IS_JSON=false
    
    for arg in "$@"; do
        case $arg in
            --quiet) IS_QUIET=true ;;
            --json) IS_JSON=true ;;
        esac
    done
    
    # Collect System Metrics
    DISK=$(get_disk_usage)
    MEM=$(get_memory_usage)
    
    # Collect Service Status
    # Status format: status|sync|block/peers|peers
    
    IFS='|' read -r GETH_STATUS GETH_SYNC GETH_BLOCK GETH_PEERS <<< "$(get_geth_status)"
    IFS='|' read -r BEACON_STATUS BEACON_SYNC BEACON_PEERS <<< "$(get_beacon_status)"
    VAL_STATUS=$(check_service_pid "${ZUG_DIR}/validator.pid" "validator.*wallet" "zugchain-validator")
    
    # --------------------------------------------------------------------------
    # OUTPUT: QUIET MODE (Exit Codes)
    # --------------------------------------------------------------------------
    if [ "$IS_QUIET" = true ]; then
        if [ "$GETH_STATUS" == "active" ] && [ "$BEACON_STATUS" == "active" ]; then
            echo "healthy"
            exit 0
        else
            echo "unhealthy"
            exit 1
        fi
    fi
    
    # --------------------------------------------------------------------------
    # OUTPUT: JSON MODE
    # --------------------------------------------------------------------------
    if [ "$IS_JSON" = true ]; then
        cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "system": {
    "disk_usage_percent": $DISK,
    "memory_usage_percent": $MEM
  },
  "services": {
    "geth": {
      "status": "$GETH_STATUS",
      "sync_state": "$GETH_SYNC",
      "block_height": "$GETH_BLOCK",
      "peers": $GETH_PEERS
    },
    "beacon": {
      "status": "$BEACON_STATUS",
      "sync_state": "$BEACON_SYNC",
      "peers": $BEACON_PEERS
    },
    "validator": {
      "status": "$VAL_STATUS"
    }
  }
}
EOF
        exit 0
    fi
    
    # --------------------------------------------------------------------------
    # OUTPUT: HUMAN READABLE (WIZARD STYLE)
    # --------------------------------------------------------------------------
    if [ -z "$ZUG_TEAL" ]; then print_banner; fi # Should have printed if utils loaded
    
    log_header "System Health"
    
    # System
    echo -ne "  ${BOLD}Disk Usage:${RESET}   "
    if [ "$DISK" -gt 85 ]; then echo -e "${COLOR_ERROR}${DISK}%${RESET}"; else echo -e "${COLOR_SUCCESS}${DISK}%${RESET}"; fi
    
    echo -ne "  ${BOLD}Memory Usage:${RESET} "
    if [ "$MEM" -gt 90 ]; then echo -e "${COLOR_ERROR}${MEM}%${RESET}"; else echo -e "${COLOR_SUCCESS}${MEM}%${RESET}"; fi
    
    echo ""
    log_header "Blockchain Components"
    
    # Geth
    echo -ne "  ${BOLD}Execution (Geth):${RESET}   "
    if [ "$GETH_STATUS" == "active" ]; then
        echo -e "${COLOR_SUCCESS}● Active${RESET} | Sync: ${BOLD}$GETH_SYNC${RESET} | Block: ${BOLD}$GETH_BLOCK${RESET} | Peers: ${ZUG_TEAL}$GETH_PEERS${RESET}"
    else
        echo -e "${COLOR_ERROR}● Down${RESET}"
    fi

    # Beacon
    echo -ne "  ${BOLD}Consensus (Beacon):${RESET} "
    if [ "$BEACON_STATUS" == "active" ]; then
        echo -e "${COLOR_SUCCESS}● Active${RESET} | Sync: ${BOLD}$BEACON_SYNC${RESET} | Peers: ${ZUG_TEAL}$BEACON_PEERS${RESET}"
    else
        echo -e "${COLOR_ERROR}● Down${RESET}"
    fi
    
    # Validator
    echo -ne "  ${BOLD}Validator Process:${RESET}  "
    if [ "$VAL_STATUS" == "running" ]; then
        echo -e "${COLOR_SUCCESS}● Running${RESET}"
    else
        echo -e "${COLOR_ERROR}● Stopped${RESET}"
    fi
    
    echo ""
}

main "$@"
