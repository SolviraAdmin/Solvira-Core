// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SOLVIRA Token (SLV)
/// @notice Deflationary ERC20 with PoTT settlement, Safe-governed parameters.
/// @custom:security-contact security@solvira.io
contract SolviraToken is ERC20, ERC20Burnable, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // --- GOVERNANCE & SECURITY ---
    // Official Gnosis Safe Multi-sig Address (Base Mainnet)
    // This Safe receives all operational funds (Treasury, Community, Marketing, Dev)
    address public constant INITIAL_SAFE = 0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7;

    address public governance;
    address public timelock; // TimelockController (48h delay for all admin operations)

    // --- WALLET ADDRESSES (2 only) ---
    address public liquidityWallet;
    address public vestingContractAddress;

    // --- CONFIGURATION ---
    uint16 public burnRateBPS = 100; // 100 Basis Points = 1.00%
    uint16 public feeRateBPS = 100;  // 100 Basis Points = 1.00%

    // Security Ratchet: Max increase of 0.5% per update to prevent sudden hikes
    uint16 public constant MAX_RATE_CHANGE = 50;

    bool public antiWhaleActive = true;
    uint256 public constant MAX_SUPPLY = 336_000_000 * 10**18;
    uint256 public maxHoldAmount;
    uint256 public maxTxAmount;

    mapping(address => bool) public isWhitelisted;

    // --- EVENTS ---
    event PoTTPayment(address indexed buyer, address indexed merchant, uint256 amount, uint256 burned, uint256 fees, uint256 timestamp);
    event RatesUpdated(uint16 oldBurnBPS, uint16 newBurnBPS, uint16 oldFeeBPS, uint16 newFeeBPS);
    event GovernanceChanged(address indexed oldGov, address indexed newGov);
    event TimelockConfigured(address indexed timelockAddress);
    event MaxHoldUpdated(uint256 newMaxHold);
    event MaxTxUpdated(uint256 newMaxTx);
    event AntiWhaleToggled(bool isActive);
    event WhitelistUpdated(address indexed account, bool status);

    constructor(
        address _liquidityWallet,
        address _vestingContractAddress,
        address _timelockAddress
    )
    ERC20("SOLVIRA", "SLV")
    ERC20Permit("SOLVIRA")
    {
        // 1. SAFETY CHECKS
        require(_liquidityWallet != address(0), "Liquidity Zero");
        require(_vestingContractAddress != address(0), "Vesting Zero");
        require(_timelockAddress != address(0), "Timelock Zero");

        liquidityWallet = _liquidityWallet;
        vestingContractAddress = _vestingContractAddress;
        timelock = _timelockAddress;

        // 2. GOVERNANCE SETUP (Timelock Architecture)
        // The Gnosis Safe remains the governance address for reference/tracking
        governance = INITIAL_SAFE;

        // ALL SENSITIVE ROLES GO TO TIMELOCK (48h delay)
        // This ensures all critical operations have a 48-hour notice period
        _grantRole(DEFAULT_ADMIN_ROLE, timelock);  // Admin of admins (role management)
        _grantRole(ADMIN_ROLE, timelock);          // Parameter changes (setRates, whitelist, etc.)
        _grantRole(PAUSER_ROLE, timelock);         // Emergency pause (with 48h delay)
        
        // Note: The Gnosis Safe controls the Timelock as PROPOSER
        // Safe → proposes → Timelock (48h) → executes → SOLVIRA

        emit TimelockConfigured(timelock);

        // Whitelisting (simplified - only essential addresses)
        isWhitelisted[governance] = true;              // Safe multi-sig
        isWhitelisted[timelock] = true;                // Timelock controller
        isWhitelisted[address(this)] = true;           // Token contract
        isWhitelisted[liquidityWallet] = true;         // Liquidity provider
        isWhitelisted[vestingContractAddress] = true;  // Vesting contract

        // Anti-Whale Setup (1% of total supply)
        maxHoldAmount = MAX_SUPPLY / 100;
        
        // Max Transaction Amount (0.2% of total supply for liquidity stabilization)
        maxTxAmount = MAX_SUPPLY / 500;

        // 3. DISTRIBUTION BLOCK
        // All percentages use basis points for precision (1 BP = 0.01%)
        
        // Operational wallets → INITIAL_SAFE (Gnosis Safe manages everything)
        uint256 communityShare = (MAX_SUPPLY * 2800) / 10000;    // 28.00%
        uint256 treasuryShare = (MAX_SUPPLY * 1200) / 10000;     // 12.00%
        uint256 marketingShare = (MAX_SUPPLY * 1200) / 10000;    // 12.00%
        uint256 devShare = (MAX_SUPPLY * 1000) / 10000;          // 10.00%
        
        // Liquidity wallet (external DEX/AMM)
        uint256 liquidityShare = (MAX_SUPPLY * 1500) / 10000;    // 15.00%
        
        // Vesting allocations → Vesting Contract (manages all vesting logic)
        uint256 founderVestingShare = (MAX_SUPPLY * 1502) / 10000;    // 15.02%
        uint256 founderPersonalShare = (MAX_SUPPLY * 297) / 10000;    // 2.97%
        uint256 investorShare = (MAX_SUPPLY * 500) / 10000;           // 5.00%

        // Calculate total vesting
        uint256 totalVestingShare = founderVestingShare + founderPersonalShare + investorShare;
        
        // Calculate Safe allocation (all operational funds)
        uint256 safeShare = communityShare + treasuryShare + marketingShare + devShare;

        // Calculate total allocated and add remainder to Safe
        uint256 allocated = safeShare + liquidityShare + totalVestingShare;
        uint256 remainder = MAX_SUPPLY - allocated;
        safeShare += remainder;

        // MINT DISTRIBUTION
        _mint(INITIAL_SAFE, safeShare);                    // 62.01% + remainder → Safe multi-sig
        _mint(liquidityWallet, liquidityShare);            // 15.00% → Liquidity
        _mint(vestingContractAddress, totalVestingShare);  // 23.00% → Vesting Contract
    }

    // ==========================================
    // PoTT FUNCTION (The only place where tax applies)
    // ==========================================
    function payForGoods(uint256 amount, address merchant) external nonReentrant whenNotPaused {
        require(merchant != address(0), "Invalid merchant");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 toBurn = (amount * burnRateBPS) / 10000;
        uint256 toFees = (amount * feeRateBPS) / 10000;
        uint256 toMerchant = amount - toBurn - toFees;

        // All PoTT fees go to the Governance Safe (treasury operations)
        _burn(msg.sender, toBurn);
        _transfer(msg.sender, INITIAL_SAFE, toFees);
        _transfer(msg.sender, merchant, toMerchant);

        emit PoTTPayment(msg.sender, merchant, amount, toBurn, toFees, block.timestamp);
    }

    // ==========================================
    // GOVERNANCE & ADMIN
    // ==========================================

    function changeGovernance(address newGov) external {
        require(msg.sender == governance, "Only governance");
        require(newGov != address(0), "Zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, newGov);
        _grantRole(ADMIN_ROLE, newGov);
        _grantRole(PAUSER_ROLE, newGov);

        _revokeRole(DEFAULT_ADMIN_ROLE, governance);
        _revokeRole(ADMIN_ROLE, governance);
        _revokeRole(PAUSER_ROLE, governance);

        emit GovernanceChanged(governance, newGov);
        governance = newGov;
    }

    function setRates(uint16 _burnRateBPS, uint16 _feeRateBPS) external onlyRole(ADMIN_ROLE) {
        require(_burnRateBPS + _feeRateBPS <= 500, "Security: Max 5% total");

        require(_burnRateBPS <= burnRateBPS + MAX_RATE_CHANGE, "Ratchet: Burn rate hike too high");
        require(_feeRateBPS <= feeRateBPS + MAX_RATE_CHANGE, "Ratchet: Fee rate hike too high");

        emit RatesUpdated(burnRateBPS, _burnRateBPS, feeRateBPS, _feeRateBPS);

        burnRateBPS = _burnRateBPS;
        feeRateBPS = _feeRateBPS;
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function setWhitelist(address _account, bool _status) external onlyRole(ADMIN_ROLE) {
        isWhitelisted[_account] = _status;
        emit WhitelistUpdated(_account, _status);
    }

    function setMaxHold(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        maxHoldAmount = _amount;
        emit MaxHoldUpdated(_amount);
    }

    function setMaxTxAmount(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        require(_amount >= MAX_SUPPLY / 1000, "MaxTx: too low (min 0.1%)");
        maxTxAmount = _amount;
        emit MaxTxUpdated(_amount);
    }

    function setAntiWhaleActive(bool _active) external onlyRole(ADMIN_ROLE) {
        antiWhaleActive = _active;
        emit AntiWhaleToggled(_active);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function _update(address from, address to, uint256 value) internal override(ERC20) whenNotPaused {
        if (from != address(0) && to != address(0) && antiWhaleActive) {
            // Max Transaction Amount check (both sender and receiver must not be whitelisted)
            if (!isWhitelisted[from] && !isWhitelisted[to]) {
                require(value <= maxTxAmount, "Exceeds MaxTx");
            }
            
            // Max Hold Amount check (only receiver)
            if (!isWhitelisted[to]) {
                require(balanceOf(to) + value <= maxHoldAmount, "Anti-Whale: Limit exceeded");
            }
        }
        super._update(from, to, value);
    }
}

