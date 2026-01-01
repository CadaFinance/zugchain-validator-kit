#!/bin/bash

# Configuration
ZUG_DIR="/opt/zugchain-validator"
MAIN_NODE_IP="16.171.13.62"
NETWORK_ID=4545072
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"

# Bootnodes
MAIN_ENODE="enode://f2bcea5ccd214e5b581c20b8c97f672b692157565e9eb2b8be5b771166716e3f37f20505aa92261399d17c10662119f291ada2d394dbac5c049292d1478e81e7@16.171.13.62:30303"
MAIN_ENR="enr:-Mq4QK7rdJRJZlCXsAuG0gPvsnMCG-U0RXRMDUhsWltzdkS3Fm18fh5UOAha01BPpgYSGMHNvwLY_faNWI2im6LNTaGGAZt6N7G9h2F0dG5ldHOIABgAAAAAAACEZXRoMpBIuSGSIAAABf__________gmlkgnY0gmlwhKwfJNSEcXVpY4IyyIlzZWNwMjU2azGhAnaP81GNKhHTvi07oWV_USlXSADLrDHZHUFhh8kJVTJoiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g"

# Styling
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Stopping old processes...${NC}"
pkill -f geth || true
pkill -f beacon-chain || true
pkill -f validator || true
sleep 3

# 1. Start Geth
echo -e "${GREEN}Starting Geth...${NC}"
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
echo "Geth PID: $!"

sleep 5

# 2. Start Beacon
echo -e "${GREEN}Starting Beacon Chain...${NC}"
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
echo "Beacon PID: $!"

sleep 5

# 3. Start Validator
echo -e "${GREEN}Starting Validator...${NC}"
WALLET_PASSWORD=$(cat ${ZUG_DIR}/data/validators/wallet_password.txt 2>/dev/null || echo "validator_wallet_pass")
WITHDRAWAL_ADDR="0x0000000000000000000000000000000000000000"

nohup validator \
    --datadir="${ZUG_DIR}/data/validators" \
    --wallet-dir="${ZUG_DIR}/data/validators/wallet" \
    --wallet-password-file=<(echo "$WALLET_PASSWORD") \
    --beacon-rpc-provider="127.0.0.1:4000" \
    --chain-config-file="${ZUG_DIR}/config/config.yml" \
    --accept-terms-of-use \
    --suggested-fee-recipient="${WITHDRAWAL_ADDR}" \
    > ${ZUG_DIR}/logs/validator.log 2>&1 &
echo "Validator PID: $!"

echo ""
echo -e "${CYAN}DONE! All services restarted.${NC}"
echo -e "Check logs: ${GREEN}tail -f /opt/zugchain-validator/logs/beacon.log${NC}"
