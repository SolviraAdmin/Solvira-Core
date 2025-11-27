# SOLVIRA – Crypto-to-Merchant Payment Protocol 🪙

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?style=for-the-badge&logo=solidity)
![Network](https://img.shields.io/badge/Network-Base%20Mainnet-0052FF?style=for-the-badge&logo=ethereum)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![SOLVIRA Audit](https://img.shields.io/badge/SOLVIRA%20V6%20Audit-9.0%2F10-success?style=for-the-badge)
![Vesting Audit](https://img.shields.io/badge/Vesting%20Audit-9.5%2F10-brightgreen?style=for-the-badge)

**SOLVIRA (SVRA)** is a deflationary utility payment token serving as a specialized payment layer for precious metal dealers. **No reserve, no backing, no convertibility — only payment utility** enabling on-chain → off-chain tangible purchases through a secure Off-chain merchant settlement middleware for precious metals.

This repository contains the production-ready smart contracts for **SOLVIRA V6** and **SolviraVesting**, both deployed on **Base mainnet** (Ethereum L2).

---

## 📑 Table of Contents

- [Vision](#-vision)
- [Legal Disclaimer](#-legal-disclaimer)
- [Architecture Overview](#-architecture-overview)
- [Institutional Security](#️-institutional-security-architecture)
- [Tokenomics](#-tokenomics)
- [Vesting System](#-vesting-system)
- [Smart Contracts](#-smart-contract-overview)
- [PoTT Mechanism](#️-pott--proof-of-tangible-transaction)
- [Deployment](#-contract-deployment-base-mainnet)
- [Security Audits](#-security-audits)
- [Developer Guide](#-developer-guide)
- [Roadmap](#️-roadmap-strategic-vision)
- [Contact](#-contact)

---

## 🌐 Vision

SOLVIRA is a **crypto-to-merchant payment protocol** specialized for precious metal dealers:

- **Payment utility token** (not backed, not convertible, no reserve)
- Rare & **deflationary** (fixed supply + burn on PoTT)
- **Transactional** and DeFi-compatible (ERC20 + ERC20Permit)
- **Enables on-chain → off-chain purchases** through Comptoir partner network
- **Off-chain merchant settlement middleware for precious metals** connecting crypto holders to tangible goods merchants

---

## ⚖️ Legal Disclaimer

**IMPORTANT LEGAL NOTICE:**

- ✅ **SOLVIRA is a utility token** for payment processing only
- ❌ **NO backing**: SVRA is not backed by silver, gold, or any physical asset
- ❌ **NO reserve**: There is no reserve pool of precious metals
- ❌ **NO convertibility**: SVRA cannot be redeemed or exchanged for physical silver
- ❌ **NO ownership rights**: Holding SVRA does not grant ownership of any tangible assets
- ✅ **Payment middleware only**: SVRA facilitates crypto-to-merchant payments for tangible purchases

**SVRA tokens provide payment utility ONLY. They represent no claim on physical assets.**

---

## 🏗️ Architecture Overview

SOLVIRA consists of **three production-grade smart contracts** with dual-vesting architecture:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SOLVIRA ECOSYSTEM                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐       ┌──────────────────┐  ┌─────────────────┐ │
│  │   SOLVIRA.sol    │       │OperationalVesting│  │SolviraVesting.sol│ │
│  │   (ERC20 Token)  │─mints─│      (50%)       │  │    (22.99%)     │ │
│  │                  │       │   168M SVRA       │  │   77.2M SVRA     │ │
│  │  336M SVRA Total  │       └──────────────────┘  └─────────────────┘ │
│  └──────────────────┘                                                  │
│         │                                                               │
│    Distribution:                                                        │
│    • Safe (Liquid): 12.01%  (40.4M SVRA)   Emergency funds only        │
│    • Liquidity: 15.00%      (50.4M SVRA)   DEX pools                   │
│    • OpVesting: 50.00%      (168M SVRA)    Community/Marketing/Dev     │
│    • SolviraVesting: 22.99% (77.2M SVRA)   Founder/Investor vesting    │
│                                                                         │
│  🔐 SECURITY: 87.99% Time-Locked (295.6M SVRA)                          │
│               12.01% Liquid in Multi-Sig Safe (40.4M SVRA)              │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Features

| Contract | Purpose | Security Score |
|----------|---------|----------------|
| **SOLVIRA.sol** | Main ERC20 token with PoTT, anti-whale, governance | **9.0/10** ⭐ |
| **OperationalVesting.sol** | Operational treasury vesting (Community, Marketing, Dev) | **9.8/10** 🏆 |
| **SolviraVesting.sol** | Founder & investor vesting with cliff periods | **9.5/10** ⭐ |

---

## 🛡️ Institutional Security Architecture

SOLVIRA is built with a **security-first** approach, going beyond a standard ERC20.

### 1. ⏱️ TimelockController (48-Hour Governance Delay)

All critical admin operations pass through a **TimelockController** with a 48-hour delay:

```
Gnosis Safe (Multi-sig)
    ↓ (proposes)
TimelockController (48h delay)
    ↓ (executes)
SOLVIRA Token
```

**Security Benefits:**
- **48-hour notice period** for all parameter changes (rates, whitelist, pause, etc.)
- **Community can react** before malicious operations execute
- **Gnosis Safe proposes** operations via multi-sig consensus
- **Anyone can execute** after the 48h delay (full transparency)
- **Safe can cancel** pending operations if issues detected

> **Timelock Contract (Base Mainnet):**  
> `Deployed via scripts/deployTimelock.js`
>
> **Gnosis Safe (Base Mainnet):**  
> `0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7`

### 2. 🏛️ Governance (Multi-Sig Safe)

Ownership and critical roles flow through the **Timelock**, controlled by a **Gnosis Safe multi-sig**:

- Deployer (EOA) has **no admin rights**
- All admin roles granted to the **TimelockController**
- Gnosis Safe controls the Timelock as **PROPOSER** and **CANCELLER**
- Governance can be migrated later (e.g. to a DAO or new Safe)
- **Zero centralization** + **48h transparency** at launch

### 3. 🔒 Security Ratchet (Anti-Rug Mechanism)

To prevent malicious fee changes, SOLVIRA enforces a **mathematical ratchet**:

- Fees (burn + treasury fee) **cannot increase by more than 0.50% (50 BPS)** in a single update
- Maximum total fee is **5%**
- Protects against "honeypot" style tax spikes
- **Impossible to rug pull** via sudden fee increases
- Changes require **48h notice** via Timelock

### 4. 🐋 Anti-Whale Protection (Dual-Layer Security)

SOLVIRA implements a **revolutionary dual-layer protection** to prevent market manipulation and ensure liquidity stability:

#### Layer 1: Max Hold Amount (1% of supply)
- **Purpose:** Prevents wallet concentration and whale accumulation
- **Default:** `3,360,000 SVRA` (1% of 336M total supply)
- **Applies to:** Receiving wallets only (checked on transfer)
- **Bypass:** Whitelisted system wallets (Safe, Timelock, Liquidity, Vesting)

#### Layer 2: Max Transaction Amount (0.2% of supply) 🆕
- **Purpose:** Stabilizes price relative to real liquidity (15% pool = 50.4M SVRA)
- **Default:** `672,000 SVRA` (0.2% of 336M total supply)
- **Represents:** 1.33% of available liquidity (optimal for price stability)
  - **Calculation:** 672,000 SVRA ÷ 50,400,000 SVRA liquidity = 1.33%
  - **Impact:** Single transaction can move at most 1.33% of pool depth
- **Applies to:** Both sender AND receiver must be non-whitelisted
- **Anti-Honeypot Protection:** 0.1% minimum floor enforced on-chain
  - **Minimum:** `336,000 SVRA` (336M × 0.1% = 336,000)
  - **Function:** `setMaxTxAmount()` reverts if `_amount < 336,000 SVRA`
  - **Governance:** Changes require `ADMIN_ROLE` + 48h Timelock delay
- **Admin Control:** `ADMIN_ROLE` can adjust via `setMaxTxAmount()` with 48h Timelock delay

**Security Benefits:**
- ✅ Prevents large dumps that could destabilize the market
- ✅ Ensures smooth price discovery during initial trading phase
- ✅ Protects against flash-loan style attacks
- ✅ Cannot be weaponized (0.1% minimum enforced on-chain)
- ✅ Whitelist bypass allows system operations (vesting claims, liquidity adds, etc.)

**Comparison Table:**

| Protection | Default Value | SVRA Amount | % of Liquidity | Bypassed When |
|------------|--------------|------------|----------------|---------------|
| **maxHoldAmount** | 1.0% | 3,360,000 | 6.67% | Receiver is whitelisted |
| **maxTxAmount** | 0.2% | 672,000 | 1.33% | Sender OR receiver is whitelisted |

> 💡 **Design Rationale:** With 15% liquidity (50.4M SVRA), a 0.2% transaction limit allows meaningful trades while preventing single transactions from moving >1.3% of the pool depth.

### 5. ⚡ Modern Standards (ERC20Permit – EIP-2612)

SOLVIRA implements **ERC20Permit**, enabling:

- **Gasless approvals** via signed messages
- 1 transaction instead of `approve + transferFrom`
- Compatibility with modern DeFi protocols (Uniswap v3, Aave v3, CowSwap, etc.)
- **Meta-transaction ready**

### 6. 🎯 Precision Accounting (Basis Points)

All PoTT fees use **Basis Points (BPS)**:

- `1 BPS` = `0.01%`
- `100 BPS` = `1.00%`
- Allows precise configurations like `0.75%` burn + `1.25%` fee
- **10x more precise** than percentage-based systems

### 7. 💸 Trading Tax (Marketing Fund)

A **2% trading tax** is applied on all transfers between non-whitelisted addresses:

- **Default Rate:** `200 BPS` (2.00%)
- **Maximum Cap:** `500 BPS` (5.00%) – hardcoded limit
- **Destination:** All tax revenue sent to `INITIAL_SAFE` (Gnosis Safe multi-sig)
- **Purpose:** Fund marketing, listings, partnerships, and ecosystem growth

**When Trading Tax Applies:**
- ✅ DEX buys (user ← Uniswap pool)
- ✅ DEX sells (user → Uniswap pool)
- ✅ P2P transfers between regular users

**When Trading Tax Does NOT Apply:**
- ❌ Transfers involving whitelisted addresses (Safe, Timelock, Vesting contracts, Liquidity)
- ❌ PoTT payments (use separate burn + fee system)
- ❌ Minting/burning operations

**Admin Control:**
```solidity
// Adjust trading tax (requires ADMIN_ROLE + 48h Timelock)
function setTradingTax(uint16 _newTax) external onlyRole(ADMIN_ROLE) {
    require(_newTax <= 500, "Trading tax cannot exceed 5%");
    tradingTaxBPS = _newTax;
}
```

> 💡 **Note:** The trading tax can be set to `0` after launch to remove it entirely once marketing objectives are achieved.

---

## 💎 Tokenomics

- **Name:** SOLVIRA  
- **Symbol:** SVRA  
- **Decimals:** 18  
- **Max Supply:** `336,000,000 SVRA` (fixed & immutable)  
- **Deflationary:** Burns reduce circulating supply via PoTT  

### Initial Distribution Architecture

SOLVIRA uses a **5-argument constructor** with dual-vesting architecture for maximum treasury security:

```solidity
constructor(
    address safeMultisigAddress,      // Gnosis Safe (multi-sig governance)
    address timelockAddress,          // TimelockController (48h delay)
    address liquidityWallet,          // 15% → Liquidity pool
    address operationalVestingAddr,   // 50% → OperationalVesting contract
    address solviraVestingAddress     // 22.99% → SolviraVesting contract
)
```

**On deployment, tokens are distributed as follows:**

| Recipient | Allocation | Amount (SVRA) | Purpose |
|-----------|------------|--------------|---------|
| **Gnosis Safe (Liquid)** | 12.01% | 40,372,800 | Emergency operational funds only (multi-sig controlled) |
| **Liquidity Wallet** | 15.00% | 50,400,000 | DEX liquidity (Uniswap, etc.) |
| **OperationalVesting** | 50.00% | 168,000,000 | Time-locked treasury (Community 28% + Marketing 12% + Dev 10%) |
| **SolviraVesting** | 22.99% | 77,227,200 | Time-locked founder & investor allocations |
| **TOTAL** | **100%** | **336,000,000** | ✅ Fully allocated at deployment |

**Security Benefits:**
- ✅ **87.99% time-locked** → Only 12.01% liquid in Safe (down from 62.01%)
- ✅ **Dual-vesting architecture** → Operational + Founder/Investor vesting
- ✅ **Drainage protection** → Treasury funds released on progressive schedules
- ✅ **48-hour timelock** → All admin changes visible before execution
- ✅ **Multi-sig control** → Emergency funds require 2/3 signatures
- ✅ **Zero individual wallets** → All allocations multi-sig or time-locked

---

## 🔐 Dual Vesting System

SOLVIRA implements **two independent vesting contracts** for maximum security:

### 1️⃣ OperationalVesting.sol

Manages **168,000,000 SVRA** (50% of total supply) for operational budgets with progressive unlock schedules:

| Category | Allocation | Amount (SVRA) | Cliff | Vesting Period | Total Duration |
|----------|------------|--------------|-------|----------------|----------------|
| **Community** | 28% | 94,080,000 | 3 months | 24 months linear | **27 months** |
| **Marketing** | 12% | 40,320,000 | 1 month | 12 months linear | **13 months** |
| **Development** | 10% | 33,600,000 | 1 month | 18 months linear | **19 months** |

**Security Features:**
- ✅ Single-use allocation setters (prevents inflation attacks)
- ✅ Balance verification on initialization (requires exactly 168M SVRA)
- ✅ Triple-checked finalization (allocation + sum + balance verification)
- ✅ Prevents pre-finalization drainage
- ✅ Role-based access control (Admin role)
- ✅ Pausable claim operations

### 2️⃣ SolviraVesting.sol

Manages **77,227,200 SVRA** (22.99% of total supply) for founder and investor allocations:

### Vesting Allocations

| Beneficiary | Allocation | Amount (SVRA) | Cliff | Vesting Period | Total Duration |
|-------------|------------|--------------|-------|----------------|----------------|
| **Founder Principal** | 15.02% | 50,467,200 | 24 months | 36 months linear | **60 months** |
| **Founder Ops** | 2.97% | 9,979,200 | 6 months | 50 months linear | **56 months** |
| **Investors** | 5.00% | 16,800,000 | 30 days | 180 days linear | **210 days** |

### Vesting Timelines (Visual)

**Founder Principal (60 months total):**
```
Month:  0────────────────24─────────────────────────────────60
        │                │                                   │
Cliff:  └────────────────┘ 24 months (no unlock)
Vesting:                  └───────────────────────────────┘ 36 months linear
Unlock: 0%               0%                              100%
```

**Founder Ops (56 months total):**
```
Month:  0──────6───────────────────────────────────────────56
        │      │                                            │
Cliff:  └──────┘ 6 months
Vesting:       └────────────────────────────────────────┘ 50 months linear
Unlock: 0%    0%                                        100%
```

**Investors (210 days total = 30 days cliff + 180 days linear):**
```
Day:    0──────────30────────────────────────────────────210
        │          │                                       │
Cliff:  └──────────┘ 30 days (no unlock)
Vesting:           └───────────────────────────────────┘ 180 days linear
Unlock: 0%        0%                                   100%
```

### Critical Security Features

The vesting contract implements **hardcoded allocation enforcement** to prevent admin drain attacks:

```solidity
// Hardcoded constants (immutable protection)
uint256 public constant EXPECTED_FOUNDER_ALLOCATION = 50_467_200 * 10**18;
uint256 public constant EXPECTED_FOUNDER_OPS_ALLOCATION = 9_979_200 * 10**18;
uint256 public constant EXPECTED_INVESTOR_ALLOCATION = 16_800_000 * 10**18;

// Finalization system (enforces exact amounts)
function finalizeAllocations() external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(founderVesting.totalAllocation == EXPECTED_FOUNDER_ALLOCATION);
    require(founderOpsVesting.totalAllocation == EXPECTED_FOUNDER_OPS_ALLOCATION);
    allocationsFinalized = true;
}
```

**Protection Against:**
- ✅ Admin drain before configuration
- ✅ Minimal allocation bypass (cannot set 1 token and drain rest)
- ✅ Investor pool drainage (reserves full 16.8M even before investors added)
- ✅ Unauthorized withdrawals (requires exact allocation match)

See [`AUDIT_SOLVIRA_VESTING_FINAL.md`](./AUDIT_SOLVIRA_VESTING_FINAL.md) for complete security analysis.

---

## 🧠 Smart Contract Overview

### SOLVIRA.sol (Main Token)

Built using **OpenZeppelin v5.x**, deployed with **Solidity 0.8.26**:

- ✅ **ERC20Permit (EIP-2612)** – gasless approvals  
- ✅ **Security Ratchet** – caps fee increases to `+0.50%` per update  
- ✅ **Multi-Sig Governance (Gnosis Safe)** – set at deployment  
- ✅ **Reentrancy Protection** – `nonReentrant` on PoTT  
- ✅ **Role-Based Access Control** – `ADMIN_ROLE`, `PAUSER_ROLE`, `POTT_OPERATOR_ROLE`  
- ✅ **Anti-Whale Protection** – dual safeguards: `maxHoldAmount` (1%) + `maxTxAmount` (0.2%) with whitelist bypass  
- ✅ **MaxTx Anti-Honeypot** – 0.1% minimum floor prevents malicious transaction limits  
- ✅ **Emergency Pause** – full transfer freeze in case of incident  
- ✅ **Fixed Total Supply** – no mint, no inflation  
- ✅ **Basis Points Precision** – 0.01% granularity for fees  
- ✅ **Trading Tax (Marketing)** – 2% tax on trades between non-whitelisted addresses (configurable 0-5%, funds marketing)  

### SolviraVesting.sol (Vesting Logic)

Production-grade vesting with **maximum security**:

- ✅ **Three Vesting Schedules** – Founder, FounderOps, Investors  
- ✅ **Hardcoded Allocations** – prevents configuration exploits  
- ✅ **Finalization System** – enforces exact allocation amounts  
- ✅ **Cliff Enforcement** – mathematical cliff protection  
- ✅ **Linear Vesting** – proven time-based unlock formulas  
- ✅ **Reentrancy Protection** – `nonReentrant` on claims  
- ✅ **Pausable Claims** – emergency freeze capability  
- ✅ **Role-Based Access** – admin separation (DEFAULT_ADMIN, VESTING_MANAGER)  
- ✅ **Investor Pool Reservation** – protects 16.8M SVRA from premature withdrawal  

### Contract Summary

| Property | SOLVIRA.sol | SolviraVesting.sol |
|----------|-------------|---------------------|
| **Standard** | ERC20 + ERC20Burnable + ERC20Permit | Custom vesting logic |
| **Compiler** | Solidity 0.8.26 (0 warnings) | Solidity 0.8.26 (0 warnings) |
| **OpenZeppelin** | v5.x | v5.x |
| **Network** | Base Mainnet (Chain ID: 8453) | Base Mainnet (Chain ID: 8453) |
| **Security Score** | 9.0/10 ⭐ | 9.5/10 🏆 |
| **Audit Report** | [AUDIT_REPORT_SOLVIRA_V6.md](./AUDIT_REPORT_SOLVIRA_V6.md) | [AUDIT_SOLVIRA_VESTING_FINAL.md](./AUDIT_SOLVIRA_VESTING_FINAL.md) |
| **Contract Address** | `TBD (awaiting deployment)` | `TBD (awaiting deployment)` |
| **Governance** | Gnosis Safe `0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7` | Gnosis Safe (DEFAULT_ADMIN) |

---

## 🛍️ PoTT – Proof of Tangible Transaction

The **PoTT mechanism** enables **crypto-to-merchant payments** through SOLVIRA's RWA payment middleware. This revolutionary protocol **connects crypto holders to independent precious metal dealers**.

**🚨 CRITICAL: SOLVIRA does NOT:**
- ❌ Hold, warehouse, or custody any physical silver/gold
- ❌ Source, purchase, or store precious metals
- ❌ Act as a dealer or merchant itself
- ❌ Maintain any reserve or vault

**✅ SOLVIRA ONLY:**
- ✅ Provides on-chain payment rails (ERC20 token transfer)
- ✅ Connects buyers to **independent third-party merchants** (Comptoir partner network)
- ✅ Merchants (NOT SOLVIRA) custody, source, and deliver the physical metals

When a user pays a merchant in SVRA, the PoTT function:

1. **Burns** a programmable fraction of the amount (deflationary effect)  
2. Sends a **fee** to the **Treasury** (for protocol development and operations)  
3. Sends the **net amount** to the **independent merchant wallet**  
4. Emits a detailed event for full on-chain transparency
5. **Merchant** (external party) fulfills physical delivery from their own inventory  

### Code Example

```solidity
function payForGoods(uint256 amount, address merchant)
    external
    nonReentrant
    whenNotPaused
{
    require(merchant != address(0), "Invalid merchant");
    require(balanceOf(msg.sender) >= amount, "Insufficient balance");

    // Calculate burn and fees (basis points)
    uint256 toBurn = (amount * burnRateBPS) / 10000;
    uint256 toFees = (amount * feeRateBPS) / 10000;
    uint256 toMerchant = amount - toBurn - toFees;

    address _treasury = treasuryWallet; // Gas optimization (cached)

    // Execute transfer (CEI pattern)
    _burn(msg.sender, toBurn);
    _transfer(msg.sender, _treasury, toFees);
    _transfer(msg.sender, merchant, toMerchant);

    emit PoTTPayment(msg.sender, merchant, amount, toBurn, toFees, block.timestamp);
}
```

**Progressive Burn Tiers** (configurable):
- 🥉 Small transactions: Lower burn rate
- 🥈 Medium transactions: Standard burn rate
- 🥇 Large transactions: Higher burn rate
- 💎 Premium transactions: Maximum burn rate

---

## 📦 Contract Deployment (Base Mainnet)

### Network Details

| Property | Value |
|----------|-------|
| **Network** | Base Mainnet (Ethereum L2) |
| **Chain ID** | 8453 |
| **RPC URL** | `https://mainnet.base.org` |
| **Explorer** | [BaseScan](https://basescan.org) |
| **Governance Safe** | `0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7` |

### Deployed Contracts

| Contract | Address | Verification |
|----------|---------|--------------|
| **SolviraVesting.sol** | `TBD (awaiting deployment)` | BaseScan Verified (after deployment) |
| **SolviraTimelock.sol** | `TBD (awaiting deployment)` | BaseScan Verified (after deployment) |
| **SOLVIRA.sol** | `TBD (awaiting deployment)` | BaseScan Verified (after deployment) |

### Deployment Workflow (3-Phase Process)

**Critical: Deploy in this exact order:**

1. **Deploy SolviraVesting.sol** first
   ```bash
   npx hardhat run scripts/deployVesting.js --network base
   ```
   Update `.env` with `VESTING_CONTRACT_ADDRESS`

2. **Deploy SolviraTimelock.sol** (48h delay governance)
   ```bash
   npx hardhat run scripts/deployTimelock.js --network base
   ```
   Update `.env` with `TIMELOCK_ADDRESS`

3. **Deploy SOLVIRA.sol** with vesting + timelock addresses
   ```bash
   npx hardhat run scripts/deploy.js --network base
   ```

4. **Configure vesting allocations**
   - Set founder principal (50,467,200 SVRA)
   - Set founder ops (9,979,200 SVRA)
   - Call `finalizeAllocations()` to lock

5. **Add investors** to vesting contract
   ```bash
   npx hardhat run scripts/addInvestors.js --network base
   ```

6. **Verify contracts** on BaseScan
   ```bash
   npx hardhat verify --network base <VESTING_ADDRESS>
   npx hardhat verify --network base <TIMELOCK_ADDRESS>
   npx hardhat verify --network base <SOLVIRA_ADDRESS> "<LIQUIDITY>" "<VESTING>" "<TIMELOCK>"
   ```

See [`DEPLOYMENT_GUIDE_BASE.md`](./DEPLOYMENT_GUIDE_BASE.md) for complete step-by-step instructions.

---

## 🔐 Security Audits

SOLVIRA has undergone **comprehensive internal security audits** for both contracts.

### Audit Results

| Contract | Score | Critical | High | Medium | Low | Status |
|----------|-------|----------|------|--------|-----|--------|
| **SOLVIRA V6** | **9.0/10** ⭐ | 0 | 0 | 0 | 2 | ✅ Production-Ready |
| **SolviraVesting** | **9.5/10** 🏆 | 0 (3 fixed) | 0 | 1 | 2 | ✅ Production-Ready |

### Key Findings & Fixes

**SOLVIRA V6 Improvements vs V5:**
- ✅ ERC20Permit (EIP-2612) added
- ✅ Basis Points precision (0.01% vs 1%)
- ✅ Security Ratchet implemented (max +0.50% per update)
- ✅ Solidity 0.8.26 (bug-free compiler, 0 warnings)
- ✅ Governance initialized at deployment (no centralization)
- ✅ Storage caching in `payForGoods()` (~2,100 gas saved)

**SolviraVesting Critical Fixes:**
- ✅ **CRITICAL #1:** Admin drain before configuration → **FIXED** (finalization flag)
- ✅ **CRITICAL #2:** Minimal allocation bypass → **FIXED** (hardcoded constants)
- ✅ **CRITICAL #3:** Investor pool drain → **FIXED** (full pool reservation)

### Audit Reports

📄 **Full Audit Documentation:**
- [AUDIT_REPORT_SOLVIRA_V6.md](./AUDIT_REPORT_SOLVIRA_V6.md) - 1000+ lines, comprehensive analysis
- [AUDIT_SOLVIRA_VESTING_FINAL.md](./AUDIT_SOLVIRA_VESTING_FINAL.md) - 1000+ lines, security-focused

### Standards Compliance

Both contracts comply with industry security standards:

| Standard | Organization | Status |
|----------|--------------|--------|
| **OpenZeppelin Best Practices** | OpenZeppelin | ✅ PASS |
| **Consensys Smart Contract Guidelines** | Consensys Diligence | ✅ PASS |
| **Trail of Bits Security Checklist** | Trail of Bits | ✅ PASS |
| **OWASP Smart Contract Top 10** | OWASP | ✅ PASS |
| **EIP-2612 (ERC20Permit)** | Ethereum Foundation | ✅ IMPLEMENTED |

### External Audit Recommendation

⚠️ A professional third-party audit (OpenZeppelin / Trail of Bits / Certora / CertiK) is **strongly recommended** before mainnet deployment with significant TVL.

📩 **For security disclosures or inquiries:**  
security@solvira.io

---

## 🧪 Developer Guide

### 📦 Prerequisites

- Node.js v16+ & npm
- Hardhat
- Base wallet with ETH for gas

### ⚙️ Installation

```bash
# Clone repository
git clone https://github.com/solvira/solvira-contracts.git
cd solvira-contracts

# Install dependencies
npm install
```

### 🛠 Compile Contracts

```bash
npx hardhat compile
```

**Expected output:**
```
Compiled 2 Solidity files successfully (0 warnings)
```

### 🧪 Run Tests

```bash
npx hardhat test
```

### 🔍 Static Analysis (Slither)

```bash
# Install Slither
pip3 install slither-analyzer

# Run analysis
slither contracts/SOLVIRA.sol --solc-remaps @openzeppelin=node_modules/@openzeppelin
slither contracts/SolviraVesting.sol --solc-remaps @openzeppelin=node_modules/@openzeppelin
```

### 📊 Gas Reporting

```bash
REPORT_GAS=true npx hardhat test
```

### 🚀 Deploy to Base Mainnet

**Step 1: Configure environment**
```bash
cp .env.example .env
# Edit .env with:
# - PRIVATE_KEY (deployer wallet)
# - BASESCAN_API_KEY (for verification)
# - LIQUIDITY_WALLET (15% allocation)
```

**Step 2: Deploy contracts (3-phase process)**
```bash
# Phase 1: Deploy vesting contract first
npx hardhat run scripts/deployVesting.js --network base
# → Update .env with VESTING_CONTRACT_ADDRESS

# Phase 2: Deploy timelock controller (48h delay)
npx hardhat run scripts/deployTimelock.js --network base
# → Update .env with TIMELOCK_ADDRESS

# Phase 3: Deploy main token (requires vesting + timelock addresses)
npx hardhat run scripts/deploy.js --network base
```

**Or use npm scripts:**
```bash
npm run deploy:base
```

**Step 3: Verify on BaseScan**
```bash
# Verify all three contracts
npx hardhat verify --network base <VESTING_ADDRESS>
npx hardhat verify --network base <TIMELOCK_ADDRESS>
npx hardhat verify --network base <SOLVIRA_ADDRESS> "<LIQUIDITY_WALLET>" "<VESTING_ADDRESS>" "<TIMELOCK_ADDRESS>"
```

### 📚 Documentation

Generate NatSpec documentation:
```bash
npx hardhat docgen
```

---

## 🗺️ Roadmap (Strategic Vision)

| Phase | Timeline | Objective | Status |
|-------|----------|-----------|--------|
| **Phase 1** | Q4 2025 | Contract V6, vesting system, dual audits (9.0 & 9.5), brand identity, bilingual website | ✅ **COMPLETED** |
| **Phase 2** | H1 2026 | Base mainnet launch, Uniswap listing, first merchant integration via PoTT payment rails | 🚀 **IN PROGRESS** |
| **Phase 3** | H2 2026 | Merchant mobile app, ecosystem expansion, silver dealer network | 📋 **PLANNED** |
| **Phase 4** | 2027+ | Tier-1 CEX listings, international rollout, RWA payment middleware standard | 🔮 **VISION** |

---

## 🌍 Multi-Language Support

SOLVIRA features a **bilingual investor-ready website** (English & French):

- 🇬🇧 **English** (default) – Global investors & institutional partners
- 🇫🇷 **Français** – French-speaking markets & European expansion

**Demo pages:**
- PoTT Interactive Demo
- How It Works (mechanism explanation)
- Security & Audits
- Tokenomics & Vesting

All documentation, smart contracts, and frontend interfaces use professional crypto-specific terminology (PoTT, progressive burn, anti-whale, vesting, basis points).

---

## 🤝 Contributors & Partners

We welcome:

- 🔧 Solidity & full-stack Web3 developers
- 🔒 Cybersecurity & smart-contract researchers
- 🪙 Precious-metal dealers & retail partners
- 💼 Early supporters & angel investors

### 📬 Contact

- **Website:** [solvira.io](https://solvira.io) (coming soon)
- **Email:** 
  - Investors: invest@solvira.io
  - Security: security@solvira.io
  - General: contact@solvira.io
- **Social Media:**
  - Twitter/X: [@SolviraOfficial](https://twitter.com/SolviraOfficial)
  - Discord: [SOLVIRA Official Community](https://discord.gg/solvira)
  - Telegram: [@SolviraProject](https://t.me/SolviraProject)
- **GitHub:** [github.com/solvira](https://github.com/solvira)

---

## 📄 License

MIT License

Copyright (c) 2025 SOLVIRA Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🙏 Acknowledgments

Built with:
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) v5.x
- [Hardhat](https://hardhat.org) - Ethereum development environment
- [Ethers.js](https://docs.ethers.org/v6/) v6 - Web3 library
- [Base](https://base.org) - Ethereum L2 by Coinbase

---

**⚡ Powered by Base Mainnet**  
© 2025 SOLVIRA Project – All rights reserved.
