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
#    Systemd Generator v2.0
#    Creates enterprise-grade service files
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"
SERVICE_USER="zugchain"

# ══════════════════════════════════════════════════════════════════════════════
# GENERATION LOGIC
# ══════════════════════════════════════════════════════════════════════════════

create_user() {
    log_header "User Configuration"
    
    if id "$SERVICE_USER" &>/dev/null; then
        log_info "User '$SERVICE_USER' already exists"
    else
        useradd --no-create-home --shell /bin/false "$SERVICE_USER"
        log_success "User '$SERVICE_USER' created"
    fi
    
    # Permissions
    chown -R $SERVICE_USER:$SERVICE_USER "$ZUG_DIR"
    chmod 700 "${ZUG_DIR}/secrets"
}

create_geth_service() {
    log_info "Creating Geth service..."
    
    cat > /etc/systemd/system/zugchain-geth.service <<EOF
[Unit]
Description=ZugChain Execution Client (Geth)
After=network-online.target
Wants=network-online.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/bin/geth \\
    --networkid=1843932 \\
    --datadir=${ZUG_DIR}/data/geth \\
    --http --http.addr=0.0.0.0 --http.port=8545 \\
    --http.api=eth,net,web3,admin,debug \\
    --http.corsdomain=* --http.vhosts=* \\
    --authrpc.addr=127.0.0.1 --authrpc.port=8551 --authrpc.vhosts=* \\
    --authrpc.jwtsecret=${ZUG_DIR}/secrets/jwt.hex \\
    --metrics --metrics.addr=127.0.0.1 --metrics.port=6060 \\
    --syncmode=full \\
    --gcmode=archive --state.scheme=path \\
    --bootnodes=enode://5a5927c4413f0a073d209c4721593109ae4375e10bfa68f53588c2f9a60c32e61f2a040433c341e5df29780d46f2ee070924b33393481e32214a430b69e38b7b@16.171.135.45:30303
    
# Security
# WaitStart removed (invalid directive)
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${ZUG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

create_beacon_service() {
    log_info "Creating Beacon Chain service..."
    
    cat > /etc/systemd/system/zugchain-beacon.service <<EOF
[Unit]
Description=ZugChain Consensus Client (Beacon)
After=network-online.target zugchain-geth.service
Wants=network-online.target
Requires=zugchain-geth.service

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/beacon-chain \\
    --datadir=${ZUG_DIR}/data/beacon \\
    --genesis-state=${ZUG_DIR}/config/genesis.ssz \\
    --chain-config-file=${ZUG_DIR}/config/config.yml \\
    --execution-endpoint=http://127.0.0.1:8551 \\
    --jwt-secret=${ZUG_DIR}/secrets/jwt.hex \\
    --accept-terms-of-use \\
    --contract-deployment-block=0 \\
    --min-sync-peers=0 \\
    --deposit-contract=0x00000000219ab540356cBB839Cbe05303d7705Fa \\
    --checkpoint-sync-url=http://16.171.135.45:3500 \\
    --genesis-beacon-api-url=http://16.171.135.45:3500 \\
    --bootstrap-node=enr:-Mq4QIFjlF_NMt3t8zgVcoKI8gp5Pxm63Yv6gCqzlnJWjPimA6V0L9UGuQS7eqZrLiOa7bP24_eAt1U7BhCp5ES8zUmGAZt_-DhUh2F0dG5ldHOIAAAAAIABAACEZXRoMpBIuSGSIAAABf__________gmlkgnY0gmlwhKwfLf-EcXVpY4IyyIlzZWNwMjU2azGhAxcmRn6UAdFt9sRL7cQ0i7K8afOjHSrEowD3RqIf4NAeiHN5bmNuZXRzD4N0Y3CCMsiDdWRwgi7g \\
    --monitoring-host=0.0.0.0 --monitoring-port=8080

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${ZUG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

create_validator_service() {
    log_info "Creating Validator service..."
    
    cat > /etc/systemd/system/zugchain-validator.service <<EOF
[Unit]
Description=ZugChain Validator Client
After=network-online.target zugchain-beacon.service
Wants=network-online.target
Requires=zugchain-beacon.service

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/validator \\
    --datadir=${ZUG_DIR}/data/validators \\
    --wallet-dir=${ZUG_DIR}/data/validators/wallet \\
    --wallet-password-file=${ZUG_DIR}/secrets/wallet_password \\
    --beacon-rpc-provider=127.0.0.1:4000 \\
    --chain-config-file=${ZUG_DIR}/config/config.yml \\
    --monitoring-host=0.0.0.0 --monitoring-port=8081 \\
    --accept-terms-of-use

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${ZUG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    log_header "Generating Service Definitions"
    
    create_user
    create_geth_service
    create_beacon_service
    create_validator_service
    
    log_info " reloading systemd..."
    systemctl daemon-reload
    
    log_success "Service files created successfully"
}

main "$@"
