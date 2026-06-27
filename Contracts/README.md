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

### Core Infrastructure
| Contract | Address | Link |
| :--- | :--- | :--- |
| **EntryPoint** | `0xc1F7d70229c2d3dAd694af874EfD5dbD746A5E36` | [Etherscan](https://sepolia.etherscan.io/address/0xc1f7d70229c2d3dad694af874efd5dbd746a5e36) |
| **SmartAccountFactory** | `0xEb4815A57E6d8Dc423E8aAE5213b685dd526c795` | [Etherscan](https://sepolia.etherscan.io/address/0xeb4815a57e6d8dc423e8aae5213b685dd526c795) |
| **Paymaster Proxy** | `0x198DD07F93a4D4DA7f8Df085221cc4ec05099496` | [Etherscan](https://sepolia.etherscan.io/address/0x198dd07f93a4d4da7f8df085221cc4ec05099496) |

### Supported Mock Tokens (for Testing)
| Asset | Address |
| :--- | :--- |
| **BTC (Mock)** | `0x883d0ceEb9ABbfd4Dba80305CBC8A6aaa9E76161` |
| **ETH (Mock)** | `0xD13a701dc4E06370586ce67856e588C7440aBd4d` |
| **USDT (Mock)** | `0xcd57f9BC91413Dee20f542F3977cb21a06B30c0a` |
| **SOL (Mock)** | `0x52c28816CaDc3c58Ec8fA360Dec0A947A746928B` |
| **ADA (Mock)** | `0x84f09287552185aB9e5d43c3880C7a27083CB309` |

---

##  Development Workflow

### Prerequisites
Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.

### Setup & Installation

Dependencies are managed as **git submodules** under `Contracts/lib/` (forge-std,
OpenZeppelin contracts + upgradeable, Chainlink, and eth-infinitism/account-abstraction).
Pinned versions are recorded in `foundry.lock`.

```bash
# 1. Clone the repo together with its submodules
git clone --recursive https://github.com/ActualRML/AAApps.git
cd AAApps/Contracts

# If you already cloned without --recursive, fetch the submodules:
git submodule update --init --recursive

# 2. Build and test
forge build
forge test
```
