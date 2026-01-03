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
#    Security Hardening v2.1
#    Enterprise server protection (UFW, Fail2ban, SSH)
#
#===============================================================================

# Import Utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/utils.sh" || { echo "Error: utils.sh not found"; exit 1; }

# ══════════════════════════════════════════════════════════════════════════════
# FIREWALL
# ══════════════════════════════════════════════════════════════════════════════

setup_firewall() {
    log_header "Configuring Firewall (UFW)"
    
    # Reset
    echo "y" | ufw reset > /dev/null
    
    # Defaults
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH (Rate limited for safety)
    ufw allow ssh
    ufw limit ssh
    log_success "SSH Protected (Rate limited)"
    
    # Execution Client (Geth)
    ufw allow 30303/tcp
    ufw allow 30303/udp
    log_success "Geth P2P Allowed (Port 30303)"
    
    # Consensus Client (Beacon)
    ufw allow 13000/tcp
    ufw allow 12000/udp
    log_success "Beacon P2P Allowed (Ports 13000/12000)"
    
    # Monitoring (Grafana)
    ufw allow 3000/tcp
    log_success "Grafana Dashboard Allowed (Port 3000)"
    
    # Enable
    echo "y" | ufw enable > /dev/null
    
    if ufw status | grep -q "Status: active"; then
        log_success "Firewall Active"
    else
        log_error "Firewall failed to start"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# INTRUSION PREVENTION
# ══════════════════════════════════════════════════════════════════════════════

setup_fail2ban() {
    log_header "Installing Intrusion Prevention (Fail2ban)"
    
    apt-get update -qq && apt-get install -y fail2ban -qq > /dev/null
    
    # Configure Jail
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF

    systemctl restart fail2ban
    sleep 2
    
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban Active (Protecting SSH)"
    else
        log_warning "Fail2ban install failed"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# SYSTEM HARDENING
# ══════════════════════════════════════════════════════════════════════════════

harden_ssh() {
    log_header "Hardening SSH Configuration"
    
    # Disable Root Login
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Disable Password Auth (If keys exist)
    # Check if authorized_keys exists for current user or SUDO_USER
    TARGET_USER=${SUDO_USER:-$USER}
    AUTH_KEYS="/home/$TARGET_USER/.ssh/authorized_keys"
    
    if [ -f "$AUTH_KEYS" ] && [ -s "$AUTH_KEYS" ]; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        log_success "Password Auth Disabled (Keys found)"
    else
        log_warning "Keeping Password Auth (No SSH keys found for $TARGET_USER)"
    fi
    
    # Restart SSH
    systemctl restart sshd
    log_success "SSH Configuration Reloaded"
}

harden_sysctl() {
    log_header "Kernel Hardening"
    
    cat > /etc/sysctl.d/99-zugchain-security.conf <<EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
EOF

    sysctl -p /etc/sysctl.d/99-zugchain-security.conf > /dev/null
    log_success "Kernel parameters applied"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    
    setup_firewall
    setup_fail2ban
    harden_sysctl
    
    log_prompt "Disable Root SSH Login? (Recommended) [y/N]"
    read -r DISABLE_ROOT
    if [[ "$DISABLE_ROOT" =~ ^[Yy] ]]; then
        harden_ssh
    fi
    
    echo ""
    log_success "Security Hardening Complete"
}

main "$@"
