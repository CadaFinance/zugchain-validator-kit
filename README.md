# ZugChain Validator Package

This package contains everything you need to join the ZugChain network as a validator.

## Contents

- `scripts/setup.sh`: **START HERE.** Installs dependencies, sets up the node, and generates your validator keys.
- `scripts/recover.sh`: recover an existing validator using your mnemonic phrase.
- `scripts/start.sh`: Start/Restart the validator services.
- `scripts/add-validator.sh`: Add more validators to your running node.
- `scripts/exit.sh`: Voluntarily exit the network (withdraw stake).
- `configs/`: Critical chain configuration files (genesis, config.yml).

## Installation

### Option 1: Quick Start (Recommended)

Run this one-liner on your Ubuntu machine to download and install:

```bash
git clone https://github.com/CadaFinance/zugchain-validator-kit.git && cd zugchain-validator-kit/scripts && chmod +x *.sh && sudo ./setup.sh
```

### Option 2: Manual Download

1.  Download the latest release from the [Releases Page](https://github.com/CadaFinance/zugchain-validator-kit/releases).
2.  Extract the archive:
    ```bash
    tar -xvf validator-package.tar.gz
    cd zugchain-validator-kit/scripts
    ```
3.  Run the setup script:
    ```bash
    sudo ./setup.sh
    ```

## Post-Installation

After the setup is complete, your services will be running in the background.

1.  **Check Sync Status**:
    ```bash
    tail -f /opt/zugchain-validator/logs/beacon.log
    ```

2.  **Validator Dashboard**:
    (Add link to your explorer/dashboard if available)

## Management

- **Start Services**: `sudo ./scripts/start.sh`
- **View Logs**: `tail -f /opt/zugchain-validator/logs/beacon.log`
- **Stop Services**: kill the processes manually or use `pkill -f 'geth|beacon-chain|validator'`

## Requirements

- Ubuntu 24.04 or later
- 2 CPU Cores (4 recommended)  
- 4GB RAM (16GB recommended)
- 100GB SSD (500GB recommended)

## Network Requirements (Ports)

You must open the following ports on your firewall/router to allow the node to peer with other nodes:

| Type | Protocol | Port | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| Custom TCP | TCP | **30303** | `0.0.0.0/0` | Receive Blocks (Geth P2P). |
| Custom UDP | UDP | **30303** | `0.0.0.0/0` | Network Discovery. |
| Custom TCP | TCP | **13000** | `0.0.0.0/0` | Vote/Attest (Beacon P2P). |
| Custom UDP | UDP | **12000** | `0.0.0.0/0` | Network Discovery. |
