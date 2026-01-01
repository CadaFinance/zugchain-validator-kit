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

- Ubuntu 20.04 or later
- 4 CPU Cores
- 8GB RAM (16GB recommended)
- 500GB SSD

## Network Requirements (Ports)

You must open the following ports on your firewall/router to allow the node to peer with other nodes:

| Service | Port | Protocol | Description |
| :--- | :--- | :--- | :--- |
| **Execution (Geth)** | `30303` | TCP & UDP | P2P peering for the Execution Layer |
| **Consensus (Beacon)** | `13000` | TCP | P2P peering for the Consensus Layer |
| **Consensus (Beacon)** | `12000` | UDP | P2P discovery for the Consensus Layer |

**Optional (Local Use Only):**
- `8545` TCP: Execution JSON-RPC (Keep closed or restricted)
- `3500` TCP: Beacon API (Keep closed or restricted)
- `4000` TCP: Beacon RPC (Keep closed or restricted)
