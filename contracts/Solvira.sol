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
    address public constant INITIAL_SAFE = 0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7;

    address public governance;

    // --- WALLET ADDRESSES (8) ---
    address public treasuryWallet;     
    address public communityWallet;     
    address public founderVestingWallet;
    address public liquidityWallet;     
    address public marketingWallet;     
    address public devWallet;           
    address public investorWallet;     
    address public founderPersonalWallet;

    // --- CONFIGURATION ---
    uint16 public burnRateBPS = 100; // 100 Basis Points = 1.00%
    uint16 public feeRateBPS = 100;  // 100 Basis Points = 1.00%

    // Security Ratchet: Max increase of 0.5% per update to prevent sudden hikes
    uint16 public constant MAX_RATE_CHANGE = 50;

    bool public antiWhaleActive = true;
    uint256 public constant MAX_SUPPLY = 336_000_000 * 10**18;
    uint256 public maxHoldAmount;

    mapping(address => bool) public isWhitelisted;

    // --- EVENTS ---
    event PoTTPayment(address indexed buyer, address indexed merchant, uint256 amount, uint256 burned, uint256 fees, uint256 timestamp);
    event RatesUpdated(uint16 oldBurnBPS, uint16 newBurnBPS, uint16 oldFeeBPS, uint16 newFeeBPS);
    event GovernanceChanged(address indexed oldGov, address indexed newGov);
    event MaxHoldUpdated(uint256 newMaxHold);
    event AntiWhaleToggled(bool isActive);
    event WhitelistUpdated(address indexed account, bool status);

    constructor(
        address _treasury,
        address _community,
        address _founderVesting,
        address _liquidity,
        address _marketing,
        address _dev,
        address _investor,
        address _founderPersonal
    )
    ERC20("SOLVIRA", "SLV")
    ERC20Permit("SOLVIRA")
    {
        // 1. SAFETY CHECKS
        require(_treasury != address(0), "Treasury Zero");
        require(_community != address(0), "Community Zero");
        require(_founderVesting != address(0), "Vesting Zero");
        require(_liquidity != address(0), "Liquidity Zero");
        require(_marketing != address(0), "Marketing Zero");
        require(_dev != address(0), "Dev Zero");
        require(_investor != address(0), "Investor Zero");
        require(_founderPersonal != address(0), "Founder Zero");

        treasuryWallet = _treasury;
        communityWallet = _community;
        founderVestingWallet = _founderVesting;
        liquidityWallet = _liquidity;
        marketingWallet = _marketing;
        devWallet = _dev;
        investorWallet = _investor;
        founderPersonalWallet = _founderPersonal;

        // 2. GOVERNANCE SETUP
        governance = INITIAL_SAFE;

        // Grant roles to Governance (Safe)
        _grantRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(ADMIN_ROLE, governance);
        _grantRole(PAUSER_ROLE, governance);

        // Whitelisting
        isWhitelisted[governance] = true;
        isWhitelisted[address(this)] = true;
        isWhitelisted[treasuryWallet] = true;
        isWhitelisted[communityWallet] = true;
        isWhitelisted[founderVestingWallet] = true;
        isWhitelisted[liquidityWallet] = true;
        isWhitelisted[marketingWallet] = true;
        isWhitelisted[devWallet] = true;
        isWhitelisted[investorWallet] = true;
        isWhitelisted[founderPersonalWallet] = true;

        // Anti-Whale Setup
        maxHoldAmount = MAX_SUPPLY / 100;

        // 3. DISTRIBUTION
        uint256 communityShare = (MAX_SUPPLY * 2800) / 10000;       
        uint256 liquidityShare = (MAX_SUPPLY * 1500) / 10000;       
        uint256 founderVestingShare = (MAX_SUPPLY * 1502) / 10000;
        uint256 treasuryShare = (MAX_SUPPLY * 1200) / 10000;       
        uint256 marketingShare = (MAX_SUPPLY * 1200) / 10000;       
        uint256 devShare = (MAX_SUPPLY * 1000) / 10000;             
        uint256 investorShare = (MAX_SUPPLY * 500) / 10000;         
        uint256 founderPersonalShare = (MAX_SUPPLY * 297) / 10000;

        uint256 allocated = communityShare + liquidityShare + founderVestingShare + treasuryShare + marketingShare + devShare + investorShare + founderPersonalShare;
        uint256 remainder = MAX_SUPPLY - allocated;
        treasuryShare += remainder;

        _mint(communityWallet, communityShare);
        _mint(liquidityWallet, liquidityShare);
        _mint(founderVestingWallet, founderVestingShare);
        _mint(treasuryWallet, treasuryShare);
        _mint(marketingWallet, marketingShare);
        _mint(devWallet, devShare);
        _mint(investorWallet, investorShare);
        _mint(founderPersonalWallet, founderPersonalShare);
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

        address _treasury = treasuryWallet;

        _burn(msg.sender, toBurn);
        _transfer(msg.sender, _treasury, toFees);
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

    function setAntiWhaleActive(bool _active) external onlyRole(ADMIN_ROLE) {
        antiWhaleActive = _active;
        emit AntiWhaleToggled(_active);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function _update(address from, address to, uint256 value) internal override(ERC20) whenNotPaused {
        if (from != address(0) && to != address(0) && antiWhaleActive) {
            if (!isWhitelisted[to]) {
                require(balanceOf(to) + value <= maxHoldAmount, "Anti-Whale: Limit exceeded");
            }
        }
        super._update(from, to, value);
    }
}

