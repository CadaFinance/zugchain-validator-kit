#!/bin/bash

# ==============================================================================
# ZugChain System Dashboard
# ==============================================================================
# Displays real-time status of all ZugChain components:
# - Core Blockchain Services (Geth, Beacon, Validator)
# - Explorer Containers (Blockscout)
# - Infrastructure (Redis, Nginx, Databases)
# - Workers & Bots
# ==============================================================================

# Configuration
REFRESH_RATE=5

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Icons
ICON_OK="●"
ICON_FAIL="✖"
ICON_WARN="!"

# Helper: Print Status Line
print_status() {
    local name=$1
    local status=$2
    local extra=$3
    local color=$RED
    local icon=$ICON_FAIL

    if [[ "$status" == "active" ]] || [[ "$status" == "running" ]]; then
        color=$GREEN
        icon=$ICON_OK
        status="ONLINE"
    elif [[ "$status" == "inactive" ]] || [[ "$status" == "dead" ]] || [[ "$status" == "exited" ]]; then
        color=$RED
        icon=$ICON_FAIL
        status="OFFLINE"
    elif [[ "$status" == "activating" ]]; then
        color=$YELLOW
        icon=$ICON_WARN
        status="STARTING"
    else
        color=$YELLOW
        icon="?"
        status=${status^^} # Uppercase
    fi

    printf "  ${color}%s${NC}  %-28s ${color}%-12s${NC} %s\n" "$icon" "$name" "$status" "$extra"
}

# Helper: Check Systemd Service OR Process
check_service_or_process() {
    local service_name=$1
    local process_name=$2
    local display_name=$3
    
    # 1. Check Systemd
    local status=$(systemctl is-active "$service_name" 2>/dev/null)
    
    if [[ "$status" == "active" ]]; then
        print_status "$display_name" "$status" "(Systemd)"
        return
    fi
    
    # 2. Check Process (Fallback)
    if pgrep -f "$process_name" > /dev/null; then
        local pid=$(pgrep -f "$process_name" | head -1)
        print_status "$display_name" "running" "(PID: $pid)"
    else
        print_status "$display_name" "inactive" ""
    fi
}

# Helper: Check Docker Container
check_container() {
    local container_name=$1
    local display_name=$2
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [[ -z "$status" ]]; then status="missing"; fi
    print_status "$display_name" "$status" ""
}

# Helper: Check Process (for non-systemd)
check_process() {
    local p_name=$1
    local display_name=$2
    if pgrep -f "$p_name" > /dev/null; then
        print_status "$display_name" "active" "(PID: $(pgrep -f "$p_name" | head -1))"
    else
        print_status "$display_name" "dead" ""
    fi
}

# Helper: System Resources
show_system_resources() {
    echo -e "${BLUE}▶ SYSTEM RESOURCES${NC}"
    echo "--------------------------------------------------------"
    
    # Load
    local load=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
    
    # Memory
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
    
    # Disk
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    
    printf "  CPU Load: %s\n" "$load"
    printf "  RAM Usage: %s / %s\n" "$mem_used" "$mem_total"
    printf "  Disk Usage: %s\n" "$disk_usage"
    echo ""
}

# Main Loop
while true; do
    clear
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                 ZUGCHAIN COMMAND CENTER                  ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "Last Update: $(date '+%H:%M:%S')"
    echo ""

    show_system_resources

    echo -e "${BLUE}▶ BLOCKCHAIN CORE SERVICES${NC}"
    echo "--------------------------------------------------------"
    # Note: Using "geth --" to be specific and avoid matching other geth strings if any
    check_service_or_process "zugchain-geth" "geth --" "Execution Client (Geth)"
    check_service_or_process "zugchain-beacon" "beacon-chain" "Consensus Client (Beacon)"
    check_service_or_process "zugchain-validator" "validator --" "Validator Client"
    check_service_or_process "zugchain-rewards" "zug-reward-daemon.py" "Reward Daemon"
    echo ""

    echo -e "${BLUE}▶ INFRASTRUCTURE${NC}"
    echo "--------------------------------------------------------"
    check_service_or_process "nginx" "nginx: master" "Nginx Web Server"
    # Checking for the specific Redis on port 6381
    check_service_or_process "redis-server" "redis-server.*:6381" "Redis (System 6381)"
    check_container "frontend-db" "Frontend DB (Docker)"
    echo ""

    echo -e "${BLUE}▶ WORKERS & BOTS${NC}"
    echo "--------------------------------------------------------"
    check_service_or_process "autocompound" "auto-compound-bot.js" "Auto-Compound Bot"
    check_process "queue-worker.js" "Queue Worker Script"
    echo ""

    echo -e "${BLUE}▶ EXPLORER (DOCKER)${NC}"
    echo "--------------------------------------------------------"
    check_container "blockscout-frontend" "Blockscout Frontend"
    check_container "blockscout-backend" "Blockscout Backend"
    check_container "blockscout-db" "Blockscout DB"
    check_container "blockscout-redis" "Blockscout Redis"
    check_container "blockscout-proxy" "Blockscout Proxy"
    check_container "blockscout-stats" "Blockscout Stats"
    check_container "blockscout-verifier" "Blockscout Verifier"
    echo ""

    echo -e "${WHITE}[Press Ctrl+C to Exit]${NC}"
    
    sleep $REFRESH_RATE
done
