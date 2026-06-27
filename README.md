# AAApps — Account Abstraction (ERC-4337) Full Stack

[![Foundry](https://img.shields.io/badge/Contracts-Foundry-FFDB1C.svg)](https://book.getfoundry.sh/)
[![Next.js](https://img.shields.io/badge/Frontend-Next.js%2016-black.svg)](https://nextjs.org)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636.svg)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**AAApps** is a full-stack implementation of the **ERC-4337 Account Abstraction** standard:
a gas-optimized set of smart contracts (smart accounts, factory, and a token-based paymaster)
paired with a Next.js dApp that lets users sign in with email/social and operate a smart account
without ever touching a seed phrase.

The repository is a monorepo with two independent packages:

| Package | Stack | What it is |
| :--- | :--- | :--- |
| [`Contracts/`](./Contracts) | Foundry · Solidity 0.8.28 | The on-chain ERC-4337 infrastructure: EntryPoint, SmartAccount + Factory, TokenPaymaster, mock tokens. |
| [`frontend/`](./frontend) | Next.js 16 · wagmi · viem | The dApp: Privy embedded-wallet login, account-address derivation, and a dashboard. |

---

## Why Account Abstraction?

Traditional EOAs (externally owned accounts) couple identity to a single private key and force
the user to hold native ETH for gas. ERC-4337 moves account logic into smart contracts so an
account can:

- **Onboard with email/social** instead of a seed phrase (embedded wallets via Privy).
- **Pay gas in ERC-20 tokens** — the `TokenPaymaster` sponsors gas and charges the user in a
  token, priced through a Chainlink oracle.
- **Recover access** through a guardian-based **social recovery** scheme on the smart account.
- **Deploy deterministically** at a known address before it ever exists on-chain (`CREATE2`
  counterfactual addresses).

---

## Architecture

```
            ┌──────────────┐   UserOperation   ┌──────────────┐
   user ───▶│   frontend   │ ────────────────▶ │   Bundler    │
 (email/    │  (Next.js)   │                   │  (Pimlico)   │
  social)   └──────────────┘                   └──────┬───────┘
                                                      │ handleOps
                                                      ▼
                                              ┌────────────────┐
                                              │   EntryPoint   │
                                              └───┬────────┬───┘
                              validateUserOp      │        │   validate + postOp
                                       ┌──────────┘        └──────────┐
                                       ▼                              ▼
                              ┌─────────────────┐           ┌──────────────────┐
                              │  SmartAccount   │           │  TokenPaymaster  │
                              │  (per user)     │           │  (gas in token)  │
                              └────────┬────────┘           └─────────┬────────┘
                          deployed by  │                    price feed │
                                       ▼                              ▼
                            ┌─────────────────────┐         ┌──────────────────┐
                            │ SmartAccountFactory │         │ Chainlink Oracle │
                            │      (CREATE2)      │         └──────────────────┘
                            └─────────────────────┘
```

### On-chain components

| Component | File | Responsibility |
| :--- | :--- | :--- |
| **EntryPoint** | `Contracts/src/entrypoint/EntryPoint.sol` | Singleton that validates and executes `UserOperation`s. |
| **SmartAccount** | `Contracts/src/smart-account/SmartAccount.sol` | Per-user account: EIP-712 signature validation, execution, EIP-1153 transient-storage reentrancy guard, and guardian-based social recovery. |
| **SmartAccountFactory** | `Contracts/src/smart-account/SmartAccountFactory.sol` | Counterfactual (`CREATE2`) deployment of accounts at predictable addresses. |
| **TokenPaymaster** | `Contracts/src/paymaster/TokenPaymaster.sol` | Upgradeable/proxy-ready paymaster that sponsors gas and charges users in an ERC-20, priced via a Chainlink feed. |
| **MockToken / TokenFactory** | `Contracts/src/token/` | ERC-20 mock assets (BTC/ETH/USDT/SOL/ADA) used for testing the paymaster flow. |

### Frontend

A Next.js 16 (App Router) dApp wired up with:

- **[Privy](https://www.privy.io/)** — email/Google login with embedded wallets for users
  without an existing wallet.
- **wagmi + viem** — typed contract reads/writes (e.g. deriving the counterfactual smart-account
  address from the factory via `useSmartAccount`).
- **permissionless + Pimlico** — bundler/paymaster client for submitting `UserOperation`s.
- **RainbowKit · shadcn/ui · Tailwind** — wallet UI and component layer.

Both packages currently target the **Sepolia** testnet.

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (for `Contracts/`)
- [Node.js](https://nodejs.org/) 20+ and npm (for `frontend/`)
- Git (the contract dependencies are git submodules)

### 1. Clone with submodules

Contract dependencies (`forge-std`, OpenZeppelin contracts + upgradeable, Chainlink, and
`eth-infinitism/account-abstraction`) live under `Contracts/lib/` as git submodules.

```bash
# clone together with submodules
git clone --recursive https://github.com/ActualRML/AAApps.git
cd AAApps

# already cloned without --recursive? fetch them now:
git submodule update --init --recursive
```

### 2. Contracts

```bash
cd Contracts
forge build
forge test
```

See [`Contracts/README.md`](./Contracts/README.md) for the full contract docs, the deployment
scripts (`script/DeployAAApps.s.sol`, `script/DeployTokens.s.sol`), and the verified Sepolia
addresses.

### 3. Frontend

```bash
cd frontend
npm install
cp .env.local.example .env.local   # then fill in the values below
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

The frontend reads its configuration from `.env.local`. Required keys:

| Variable | Purpose |
| :--- | :--- |
| `NEXT_PUBLIC_PRIVY_APP_ID` | Privy app ID for email/social login. |
| `NEXT_PUBLIC_PIMLICO_API_KEY` | Pimlico bundler/paymaster API key. |
| `NEXT_PUBLIC_SEPOLIA_RPC_URL` | Sepolia RPC endpoint. |
| `NEXT_PUBLIC_ENTRY_POINT` | Deployed EntryPoint address. |
| `NEXT_PUBLIC_ACCOUNT_FACTORY` | Deployed SmartAccountFactory address. |
| `NEXT_PUBLIC_PAYMASTER` | Deployed TokenPaymaster (proxy) address. |
| `NEXT_PUBLIC_PRICE_FEED` | Chainlink price-feed address used by the paymaster. |
| `NEXT_PUBLIC_USDT_ADDR` / `BTC` / `ETH` / `SOL` / `ADA` | Mock token addresses. |

---

## Testing

The contracts ship with an extensive Foundry suite, including fuzz tests (256 runs per property)
covering social recovery, paymaster math/oracle handling, gas-drain protection, and factory
address predictability. A gas snapshot is checked in at `Contracts/.gas-snapshot`.

```bash
cd Contracts
forge test            # run all tests
forge snapshot        # regenerate the gas snapshot
```

---

## Deployment

The on-chain infrastructure is deployed and verified on **Sepolia**. The canonical, verified
addresses (EntryPoint, SmartAccountFactory, Paymaster proxy, and the mock tokens) are listed in
[`Contracts/README.md`](./Contracts/README.md#live-on-sepolia-testnet). The frontend points at
these via its `.env.local` configuration.

---

## Project Status

- ✅ Core ERC-4337 contracts implemented, fuzz-tested, and deployed to Sepolia.
- ✅ Frontend scaffold: Privy login + dashboard that derives the user's counterfactual
  smart-account address.
- 🚧 End-to-end `UserOperation` wiring (bundler submission + token-sponsored gas) and the full
  frontend account flow are in progress.

---

## License

[MIT](https://opensource.org/licenses/MIT)
