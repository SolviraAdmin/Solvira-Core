# SOLVIRA – The Digital Silver Asset 🪙

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?style=for-the-badge&logo=solidity)
![Network](https://img.shields.io/badge/Network-Sepolia%20Testnet-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Audit](https://img.shields.io/badge/Internal%20Security%20Score-9.0%2F10-brightgreen?style=for-the-badge)

**SOLVIRA (SLV)** is a deflationary, silver-linked digital asset designed to bridge the speed of DeFi with the stability of **physical silver**.

This repository contains the smart-contract source code for **SOLVIRA V6 (Institutional-grade)**.

---

## 🌐 Vision

SOLVIRA aims to become a **Digital Silver Asset**:

- Rare & **deflationary** (fixed supply + burn on PoTT)
- **Transactional** and DeFi-compatible (ERC20 + ERC20Permit)
- **Intrinsically linked** to physical silver through the PoTT mechanism and merchant partnerships

---

## 🛡️ Institutional Security Architecture

SOLVIRA is built with a **security-first** approach, going beyond a standard ERC20.

### 1. 🏛️ Governance (Multi-Sig Safe)

Ownership and critical roles are assigned to a **Gnosis Safe multi-sig** from deployment:

- Deployer (EOA) has **no admin rights**
- All admin roles go directly to the Safe
- Governance can be migrated later (e.g. to a DAO or new Safe)

> **Initial Governance (Sepolia):** 
> `0x3207E30706F2C7FB47e992616fdBa9E85c888995`

### 2. 🔒 Security Ratchet (Anti-Rug Mechanism)

To prevent malicious fee changes, SOLVIRA enforces a **mathematical ratchet**:

- Fees (burn + treasury fee) **cannot increase by more than 0.50% (50 BPS)** in a single update
- Maximum total fee is **5%**
- Protects against “honeypot” style tax spikes

### 3. ⚡ Modern Standards (ERC20Permit – EIP-2612)

SOLVIRA implements **ERC20Permit**, enabling:

- **Gasless approvals** via signed messages
- 1 transaction instead of `approve + transferFrom`
- Compatibility with modern DeFi protocols (Uniswap v3, Aave, CowSwap, etc.)

### 4. 🎯 Precision Accounting (Basis Points)

All PoTT fees use **Basis Points (BPS)**:

- `1 BPS` = `0.01%`
- `100 BPS` = `1.00%`
- Allows precise configurations like `0.75%` burn + `1.25%` fee

---

## 💎 Tokenomics

- **Name:** SOLVIRA 
- **Symbol:** SLV 
- **Decimals:** 18 
- **Max Supply:** `336,000,000 SLV` (fixed & immutable) 

### Automated Initial Distribution

On deployment, the contract mints the full supply and automatically allocates it to 8 ecosystem wallets:

| Allocation Wallet      | Percentage | Amount (SLV) |
|------------------------|-----------:|-------------:|
| Community              | 28.00%     | 94,080,000   |
| Founder Vesting        | 15.02%     | 50,467,200   |
| Liquidity              | 15.00%     | 50,400,000   |
| Treasury               | 12.01%     | 40,336,000   |
| Marketing              | 12.00%     | 40,320,000   |
| Dev Team               | 10.00%     | 33,600,000   |
| Investors              | 5.00%      | 16,800,000   |
| Founder Personal       | 2.97%      | 9,979,200    |

Any rounding remainder is automatically added to the **Treasury** to guarantee that the total equals exactly `MAX_SUPPLY`.

---

## 🧠 Smart-Contract Overview

SOLVIRA is built using **OpenZeppelin v5.x**, deployed with **Solidity 0.8.26**, and integrates multiple institutional-grade guardrails:

- ✅ **ERC20Permit (EIP-2612)** – gasless approvals 
- ✅ **Security Ratchet** – caps fee increases to `+0.50%` per update 
- ✅ **Multi-Sig Governance (Gnosis Safe)** – set at deployment 
- ✅ **Reentrancy Protection** – `nonReentrant` on PoTT 
- ✅ **Role-Based Access Control** – `ADMIN_ROLE`, `PAUSER_ROLE`, `DEFAULT_ADMIN_ROLE` 
- ✅ **Anti-Whale Guard** – configurable `maxHoldAmount` with whitelist 
- ✅ **Emergency Pause** – full transfer freeze in case of incident 
- ✅ **Fixed Total Supply** – no mint, no inflation

### Contract Summary

| Property          | Value |
|-------------------|-------|
| Name              | SOLVIRA |
| Symbol            | SLV |
| Standard          | ERC20 + ERC20Burnable + ERC20Permit |
| Total Supply      | 336,000,000 SLV (fixed) |
| Decimals          | 18 |
| Network (Test)    | Sepolia Testnet |
| Contract Address  | `0x7A9Ef08ac4c851D02249Ef7c159A646C22a28388` |
| Governance Model  | Gnosis Safe multi-sig |
| Compiler          | Solidity `0.8.26` (0 warnings) |

---

## 🛍️ PoTT – Proof of Tangible Transaction

The **PoTT mechanism** powers real-world payments for physical silver.

When a user pays a merchant in SLV, the PoTT function:

1. **Burns** a programmable fraction of the amount (deflationary effect) 
2. Sends a **fee** to the **Treasury** (for backing, operations, & silver sourcing) 
3. Sends the **net amount** to the **merchant** 
4. Emits a detailed event for full on-chain transparency 

```solidity
function payForGoods(uint256 amount, address merchant)
    external
    nonReentrant
    whenNotPaused
{
    require(merchant != address(0), "Invalid merchant");
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");

    uint256 toBurn = (amount * burnRateBPS) / 10000;
    uint256 toFees = (amount * feeRateBPS) / 10000;
    uint256 toMerchant = amount - toBurn - toFees;

    address _treasury = treasuryWallet;

    _burn(msg.sender, toBurn);
    _transfer(msg.sender, _treasury, toFees);
    _transfer(msg.sender, merchant, toMerchant);

    emit PoTTPayment(msg.sender, merchant, amount, toBurn, toFees, block.timestamp);
}

---

## 📦 Contract Deployment (Testnet)

| Property | Value |
|----------|-------|
| Network | Sepolia Testnet |
| Contract Address | `0x7A9Ef08ac4c851D02249Ef7c159A646C22a28388` |
| Explorer | https://sepolia.etherscan.io/address/0x7A9Ef08ac4c851D02249Ef7c159A646C22a28388#code |
| Compiler | Solidity 0.8.26 (0 warnings) |
| Verification | Etherscan Verified |

---

## 🧪 Developer Guide

### 📦 Prerequisites
- Node.js & npm 
- Hardhat

---

### ⚙️ Installation

```bash
npm install
``` 

``` 🛠 Compile

npx hardhat compile

⸻

🧪 Run Tests

npx hardhat test

⸻

🔍 Verify on Etherscan

npx hardhat verify --network sepolia 0x7A9Ef08ac4c851D02249Ef7c159A646C22a28388

```

Replace the address if deploying a new version.

⸻

🧾 Audit & Security

Metric | Status
--- | ---
Internal Audit Score | ⭐ 9.0 / 10
Critical / High Issues | 🚫 None Found
Compiler Warnings | 0 (Solidity 0.8.26)
Governance | Gnosis Safe Multi-Sig
Reentrancy | Protected (`nonReentrant`)

⚠️ A professional third-party audit (OpenZeppelin / Trail of Bits / Certora) is strongly recommended before mainnet deployment.

📩 For security disclosures or inquiries: 
security@solvira.io

⸻

🗺️ Roadmap (Strategic Vision)

Phase | Timeline | Objective
--- | --- | ---
Phase 1 | Q4 2025 | Contract, internal audit, brand identity
Phase 2 | H1 2026 | Mainnet launch, Uniswap listing, first PoTT live with a physical partner
Phase 3 | H2 2026 | Merchant app, ecosystem expansion, silver partner network
Phase 4 | 2027+ | Tier-1 CEX listings, international rollout, Digital Silver standard

⸻

🤝 Contributors & Partners

We welcome: 
• Solidity & full-stack Web3 developers 
• Cybersecurity / smart-contract researchers 
• Precious-metal dealers & retail partners 
• Early supporters / angel investors 

📬 Contact 
• Investors: invest@solvira.io 
• Security: security@solvira.io 
• Twitter/X: @SolviraOfficial 

⸻

© 2025 SOLVIRA Project – All rights reserved.
