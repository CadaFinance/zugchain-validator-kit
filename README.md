# ZugChain Enterprise Validator Suite

**Professional, secure, and production-ready validator infrastructure for the ZugChain network.**

This package provides a unified "Master Wizard" to orchestrate the entire setup process, featuring systemd integration, security hardening, offline key management, and real-time monitoring.

---

## 🚀 Quick Start

Launch the interactive Master Wizard to begin:

```bash
# Clone and run
git clone https://github.com/CadaFinance/zugchain-validator-kit.git
cd zugchain-validator-kit/scripts
git reset --hard origin/main
git pull
cd scripts
chmod +x *.sh
sudo ./setup.sh
```

**The wizard will guide you through:**
1.  **System Check:** Verifies OS, RAM, CPU, and Dependencies.
2.  **Mode Selection:** Choose between **Enterprise** (Recommended) or **Legacy** setup.
3.  **Security Hardening:** Auto-configures Firewall (UFW) and SSH protection (Fail2ban).
4.  **Key Management:** Supports importing air-gapped keys or generating strict local keys.
5.  **Monitoring:** One-click installation of Prometheus & Grafana dashboards.

---

## 🛡️ Enterprise Features

| Feature | Description |
| :--- | :--- |
| **Systemd Services** | Auto-restart, resource limits, and proper logging management. No more `nohup` or lost processes. |
| **Security First** | Runs as non-root `zugchain` user. Configures UFW firewall and Fail2ban automatically. |
| **Real-time Monitoring** | Built-in **Grafana Dashboard** (Port 3000) showing syncing status, peer count, and system health. |
| **Offline Keys** | Maximum security workflow: Generate keys on an offline machine, import safely to the validator. |
| **Slashing Protection** | Automated database exports during shutdown/exit to prevent double-signing. |

---

## 📊 Monitoring Dashboard

If selected during setup, access your dashboard at:
`http://<YOUR_SERVER_IP>:3000`

**Credentials:** `admin` / `admin` (Change on first login)

**What you will see:**
- **Sync Status:** Real-time blocks for Execution & Consensus clients.
- **Validator Health:** Active status, attestation performance.
- **System Metrics:** CPU, RAM, and Disk usage with alert thresholds.

---

## 📂 Scripts Reference

All scripts use a unified design system for a consistent experience.

| Script | Purpose |
| :--- | :--- |
| `setup.sh` | **Master Wizard** - Orchestrates installation, security, and monitoring. |
| `health.sh` | **Health Check** - `sudo ./health.sh` for status. Supports `--json` for automation. |
| `stop.sh` | **Graceful Shutdown** - Safely stops services and exports slashing protection DB. |
| `start.sh` | **Service Manager** - Starts services via systemd (or legacy fallback). |
| `add-validator.sh` | **Scaler** - Add more keys to a running node without downtime. |
| `exit.sh` | **Voluntary Exit** - Withdraw your 32 ZUG stake (Requires 27h wait). |
| `backup.sh` | **Full Backup** - Encrypts and archives keys, secrets, and databases. |
| `keygen-offline.sh` | **Air-Gapped Tool** - Generate mnemonic/keys on a disconnected machine. |

---

## 🔧 Post-Installation Management

### Managing Services
```bash
# Check status
sudo systemctl status zugchain-validator

# View logs (real-time)
journalctl -fu zugchain-beacon
```

### Updates & Maintenance
```bash
# Update scripts
git pull

# Check node health
sudo ./health.sh
```

---

## 🌐 Network Configuration (Ports)

For your validator to discover peers and sync successfully, you must allow traffic on the following ports. If you are using a Cloud Provider (AWS, DigitalOcean, etc.), configure your **Security Groups / Firewall** to allow these:

| Service | Port | Protocol | Source | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Geth (Execution)** | `30303` | **TCP & UDP** | `0.0.0.0/0` (Anywhere) | P2P Peer Discovery |
| **Beacon (Consensus)** | `13000` | **TCP** | `0.0.0.0/0` (Anywhere) | P2P Peer Connection |
| **Beacon (Consensus)** | `12000` | **UDP** | `0.0.0.0/0` (Anywhere) | P2P Peer Discovery |
| **Grafana** | `3000` | TCP | *Restricted IP* | Monitoring Dashboard (Optional) |
| **SSH** | `22` | TCP | *Restricted IP* | Server Access |

> [!WARNING]
> **DO NOT** open the following ports to the public internet:
> - `8545`, `8551` (Geth RPC)
> - `4000`, `3500` (Beacon RPC)
> - `8080`, `9090` (Metrics)

---

## ⚠️ Security Best Practices

1.  **Use Offline Keys:** Generate your mnemonic on a machine *never* connected to the internet using `./keygen-offline.sh`.
2.  **Firewall:** The script enables UFW. Ensure your cloud provider (AWS/DigitalOcean) firewall also allows ports `30303` (TCP/UDP) and `13000` (TCP) / `12000` (UDP).
3.  **Backups:** Run `./backup.sh --encrypt` regularly and store the artifact off-site.

---

*ZugChain Infrastructure Team*
