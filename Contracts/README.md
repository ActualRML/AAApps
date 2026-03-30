# AAApps: Account Abstraction (ERC-4337) Infrastructure

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://book.getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**AAApps** is a high-performance implementation of the ERC-4337 Account Abstraction standard. This project focuses on modularity, gas efficiency, and secure deployment patterns for Smart Accounts on Ethereum-compatible networks.

---

##  Core Features

- **ERC-4337 Full Integration:** Complete workflow from UserOperation validation to execution.
- **Deterministic Deployment:** Uses `CREATE2` via `SmartAccountFactory` for predictable contract addresses.
- **Proxy-Based Paymaster:** Enables flexible gas sponsorship logic with an upgradable proxy pattern.
- **Battle-Tested Security:** Extensive fuzz testing (10,000+ runs) to ensure robust state handling.

---

##  Architecture & Components

| Component | Responsibility |
| :--- | :--- |
| **EntryPoint** | The central singleton that orchestrates UserOperation validation and execution. |
| **SmartAccount** | The modular vault that executes transactions and handles custom signature validation. |
| **Factory** | Handles the counterfactual deployment of Smart Accounts using Salt/Nonce. |
| **Paymaster** | Manages gas sponsorship, allowing users to pay fees in ERC20 or bypass them entirely. |

---

##  Live on Sepolia Testnet

The following contracts are deployed and verified on the Sepolia network:

- **EntryPoint:** `0x08aAB491efE130f7760412c5708602A03d85feD0`
- **SmartAccountFactory:** `0x23d67D5b1F62A98601eE7A4bE7d69a2963b0a9Ad`
- **Paymaster Proxy:** `0xeCd6220145236CBA1a3e9bA47A53726b3F41D779`

---

##  Development Workflow

### Prerequisites
Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.

### Setup & Installation
```bash
git clone [https://github.com/ActualRML/AAApps.git](https://github.com/ActualRML/AAApps.git)
cd AAApps/contracts
forge install