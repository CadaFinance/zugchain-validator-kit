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
#    Monitoring Stack Setup v2.0
#    Prometheus + Grafana + Node Exporter
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

ZUG_DIR="/opt/zugchain-validator"

# ══════════════════════════════════════════════════════════════════════════════
# INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════

install_prometheus() {
    log_header "Installing Prometheus"
    
    if id "prometheus" &>/dev/null; then
        log_info "Prometheus user exists"
    else
        useradd --no-create-home --shell /bin/false prometheus
    fi
    
    mkdir -p /etc/prometheus
    mkdir -p /var/lib/prometheus
    chown prometheus:prometheus /etc/prometheus /var/lib/prometheus
    
    # Download
    cd /tmp
    wget -q https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xvf prometheus-2.45.0.linux-amd64.tar.gz > /dev/null
    
    cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
    cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
    chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
    
    cp -r prometheus-2.45.0.linux-amd64/consoles /etc/prometheus
    cp -r prometheus-2.45.0.linux-amd64/console_libraries /etc/prometheus
    chown -R prometheus:prometheus /etc/prometheus/consoles /etc/prometheus/console_libraries
    
    rm -rf prometheus-2.45.0.linux-amd64*
    
    # Config
    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'zugchain_geth'
    metrics_path: /debug/metrics/prometheus
    static_configs:
      - targets: ['localhost:6060']
  - job_name: 'zugchain_beacon'
    metrics_path: /metrics
    static_configs:
      - targets: ['localhost:8080']
  - job_name: 'zugchain_validator'
    metrics_path: /metrics
    static_configs:
      - targets: ['localhost:8081']
EOF
    chown prometheus:prometheus /etc/prometheus/prometheus.yml
    
    # Service
    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
    
    log_success "Prometheus installed"
}

install_node_exporter() {
    log_header "Installing Node Exporter"
    
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar xvf node_exporter-1.6.1.linux-amd64.tar.gz > /dev/null
    
    cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin
    chown prometheus:prometheus /usr/local/bin/node_exporter
    rm -rf node_exporter-1.6.1.linux-amd64*
    
    cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    
    log_success "Node Exporter installed"
}

install_grafana() {
    log_header "Installing Grafana"
    
    apt-get install -y apt-transport-https software-properties-common wget > /dev/null
    mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    
    apt-get update -qq > /dev/null
    apt-get install -y grafana -qq > /dev/null
    
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
    
    log_success "Grafana installed"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    
    log_info "Setting up monitoring stack..."
    
    install_prometheus
    install_node_exporter
    install_grafana
    
    echo ""
    log_success "Monitoring Setup Complete!"
    echo -e "  ${BOLD}Grafana URL:${RESET}   http://$(curl -s ifconfig.me):3000"
    echo -e "  ${BOLD}Username:${RESET}      admin"
    echo -e "  ${BOLD}Password:${RESET}      admin"
    echo ""
}

main "$@"
