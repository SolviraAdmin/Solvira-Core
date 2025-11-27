// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Minimal ERC20 interface (with balanceOf added for secure withdrawal checks)
interface IERC20 {
   function transfer(address to, uint256 amount) external returns (bool);
   function balanceOf(address account) external view returns (uint256);
}

/**
* @title SolviraVesting
* @notice Production-grade vesting contract for SOLVIRA (SVRA) token
* @dev Features: Founder (5-year), FounderOps (56-month), Investors (30-day cliff + 180-day linear)
*/
contract SolviraVesting is AccessControl, Pausable, ReentrancyGuard {

   // ---------------------- ROLES ----------------------
   bytes32 public constant VESTING_MANAGER_ROLE = keccak256("VESTING_MANAGER_ROLE");

   // ---------------------- IMMUTABLES ----------------------
   IERC20 public immutable svraToken;
   uint256 public immutable deploymentTimestamp;

   // ---------------------- VESTING CONSTANTS ----------------------
   // Founder Principal (15.02%) - 24 months cliff + 36 months linear
   uint256 public constant FOUNDER_CLIFF = 730 days;            // ~24 months
   uint256 public constant FOUNDER_VESTING_DURATION = 1095 days; // ~36 months
   uint256 public constant FOUNDER_TOTAL_DURATION = 1825 days;   // ~60 months

   // Founder Ops Personal (2.97%) - 6 months cliff + 50 months linear
   uint256 public constant FOUNDER_OPS_CLIFF = 180 days;            // ~6 months
   uint256 public constant FOUNDER_OPS_VESTING_DURATION = 1500 days; // ~50 months
   uint256 public constant FOUNDER_OPS_TOTAL_DURATION = FOUNDER_OPS_CLIFF + FOUNDER_OPS_VESTING_DURATION; // 56 months total

   // Investor Vesting (5%) - 30 days cliff + 180 days linear
   uint256 public constant INVESTOR_CLIFF_DURATION = 30 days;           // 1 month cliff
   uint256 public constant INVESTOR_VESTING_DURATION = 180 days;        // 6 months linear vesting
   uint256 public constant INVESTOR_TOTAL_DURATION = INVESTOR_CLIFF_DURATION + INVESTOR_VESTING_DURATION; // 210 days total

   // 🔐 SECURITY: Expected allocations (must match SOLVIRA.sol distribution)
   // Total Supply: 336,000,000 SVRA (with 18 decimals)
   uint256 public constant EXPECTED_FOUNDER_ALLOCATION = 50_467_200 * 10**18;     // 15.02%
   uint256 public constant EXPECTED_FOUNDER_OPS_ALLOCATION = 9_979_200 * 10**18;  // 2.97%
   uint256 public constant EXPECTED_INVESTOR_ALLOCATION = 16_800_000 * 10**18;    // 5.00%
   uint256 public constant EXPECTED_TOTAL_VESTING = 77_246_400 * 10**18;          // 23% (Founder + FounderOps + Investors)

   // ---------------------- STRUCTURES ----------------------
   // Structure réutilisée pour le fondateur principal et les opérations perso
   struct FounderVesting {
       uint256 totalAllocation;
       uint256 claimed;
       uint256 startTimestamp;
   }

   struct InvestorVesting {
       uint256 totalAllocation;
       uint256 claimed;
       uint256 startTimestamp;
   }

   // ---------------------- STATE ----------------------
   address public founder;
   address public founderOps; // 🔥 ADDED: Founder Personal Ops Wallet

   FounderVesting public founderVesting;
   FounderVesting public founderOpsVesting; // 🔥 ADDED: Data for personal allocation

   mapping(address => InvestorVesting) public investors;
   uint256 public totalInvestorAllocation;
   uint256 public totalInvestorClaimed;

   // 🔐 SECURITY: Prevents withdrawal of vested tokens before allocations are locked
   bool public allocationsFinalized;

   // ---------------------- EVENTS ----------------------
   event FounderUpdated(address indexed oldFounder, address indexed newFounder);
   event FounderOpsUpdated(address indexed oldOps, address indexed newOps);
   event InvestorAdded(address indexed investor, uint256 amount);
   event InvestorBatchAdded(uint256 count);
   event TokensClaimed(address indexed wallet, uint256 amount);
   event UnassignedWithdrawn(address indexed to, uint256 amount);
   event AllocationsFinalized(uint256 founderAlloc, uint256 founderOpsAlloc, uint256 timestamp);

   // ---------------------- CONSTRUCTOR ----------------------
   constructor(address _svraTokenAddress) {
       require(_svraTokenAddress != address(0), "SolviraVesting: zero address");
       svraToken = IERC20(_svraTokenAddress);

       deploymentTimestamp = block.timestamp;

       // Grant initial roles
       _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
       _grantRole(VESTING_MANAGER_ROLE, msg.sender);

       // Vesting starts at deployment
       founderVesting.startTimestamp = block.timestamp;
       founderOpsVesting.startTimestamp = block.timestamp; // 🔥 Start both schedules at deployment
   }

   // ---------------------- FOUNDER MANAGEMENT ----------------------
   function setFounder(address _founder) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(_founder != address(0), "SolviraVesting: zero address");
       address old = founder;
       founder = _founder;
       emit FounderUpdated(old, _founder);
   }

   function setFounderAllocation(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(founder != address(0), "SolviraVesting: founder not set");
       require(founderVesting.totalAllocation == 0, "SolviraVesting: already set");
       founderVesting.totalAllocation = _amount;
   }

   // 🔥 NEW FUNCTION for Founder Ops Allocation (2.97%)
   function setFounderOpsWallet(address _founderOpsWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(_founderOpsWallet != address(0), "SolviraVesting: zero address");
       address old = founderOps;
       founderOps = _founderOpsWallet;
       emit FounderOpsUpdated(old, _founderOpsWallet);
   }

   function setFounderOpsAllocation(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(founderOps != address(0), "SolviraVesting: founder ops wallet not set");
       require(founderOpsVesting.totalAllocation == 0, "SolviraVesting: allocation already set");
       founderOpsVesting.totalAllocation = _amount;
   }

   // 🔐 SECURITY FIX: Lock allocations to prevent withdrawal exploit
   /// @notice Finalizes all allocations and prevents withdrawUnassignedTokens from draining vested funds
   /// @dev CRITICAL SECURITY: Verifies allocations match EXACT expected amounts from SOLVIRA.sol
   /// @dev Must be called after setting founder and founderOps allocations, before any withdrawals
   function finalizeAllocations() external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(!allocationsFinalized, "SolviraVesting: already finalized");
       
       // 🔐 CRITICAL: Verify EXACT amounts (prevents admin from setting 1 token and draining the rest)
       require(
           founderVesting.totalAllocation == EXPECTED_FOUNDER_ALLOCATION,
           "SolviraVesting: founder allocation mismatch"
       );
       require(
           founderOpsVesting.totalAllocation == EXPECTED_FOUNDER_OPS_ALLOCATION,
           "SolviraVesting: founder ops allocation mismatch"
       );
       
       allocationsFinalized = true;
       emit AllocationsFinalized(
           founderVesting.totalAllocation,
           founderOpsVesting.totalAllocation,
           block.timestamp
       );
   }

   // ---------------------- INVESTOR MANAGEMENT (unchanged) ----------------------
   function addInvestor(address wallet, uint256 amount)
       external
       onlyRole(VESTING_MANAGER_ROLE)
   {
       require(wallet != address(0), "Zero address");
       require(amount > 0, "Zero amount");
       require(investors[wallet].totalAllocation == 0, "Already assigned");

       investors[wallet] = InvestorVesting({
           totalAllocation: amount,
           claimed: 0,
           startTimestamp: block.timestamp
       });

       totalInvestorAllocation += amount;
       emit InvestorAdded(wallet, amount);
   }

   function batchAddInvestors(address[] calldata wallets, uint256[] calldata amounts)
       external
       onlyRole(VESTING_MANAGER_ROLE)
   {
       require(wallets.length == amounts.length, "Length mismatch");

       for (uint256 i = 0; i < wallets.length; i++) {
           require(wallets[i] != address(0), "Zero address");
           require(amounts[i] > 0, "Zero amount");
           require(investors[wallets[i]].totalAllocation == 0, "Already assigned");

           investors[wallets[i]] = InvestorVesting({
               totalAllocation: amounts[i],
               claimed: 0,
               startTimestamp: block.timestamp
           });

           totalInvestorAllocation += amounts[i];
           emit InvestorAdded(wallets[i], amounts[i]);
       }

       emit InvestorBatchAdded(wallets.length);
   }

   // ---------------------- CLAIM FUNCTION (Integrated) ----------------------
   function claim() external nonReentrant whenNotPaused {
       uint256 claimable;

       // 1) Founder Principal (15.02%)
       if (msg.sender == founder) {
           uint256 unlocked = _founderUnlocked();
           claimable = unlocked - founderVesting.claimed;
           require(claimable > 0, "Nothing to claim (FP)");
           founderVesting.claimed += claimable;
       }
       // 2) Founder Ops Personal (2.97%) - 🔥 NEW BLOCK
       else if (msg.sender == founderOps) {
           uint256 unlocked = _founderOpsUnlocked();
           claimable = unlocked - founderOpsVesting.claimed;
           require(claimable > 0, "Nothing to claim (FOP)");
           founderOpsVesting.claimed += claimable;
       }
       // 3) Investor classic (5%)
       else if (investors[msg.sender].totalAllocation > 0) {
           uint256 unlocked = _investorUnlocked(msg.sender);
           claimable = unlocked - investors[msg.sender].claimed;
           require(claimable > 0, "Nothing to claim (INV)");
           investors[msg.sender].claimed += claimable;
           totalInvestorClaimed += claimable;
       }
       else {
           revert("Not authorized");
       }

       require(svraToken.transfer(msg.sender, claimable), "Transfer failed");
       emit TokensClaimed(msg.sender, claimable);
   }

   // ---------------------- WITHDRAW UNASSIGNED TOKENS (Secure Fix) ----------------------
   /// @notice Withdraw tokens that are NOT allocated to any vesting schedule
   /// @dev SECURITY: Can only be called AFTER allocations are finalized to prevent draining vested funds
   function withdrawUnassignedTokens(address to, uint256 amount)
       external
       onlyRole(DEFAULT_ADMIN_ROLE)
       nonReentrant
   {
       require(allocationsFinalized, "SolviraVesting: allocations not finalized");
       require(to != address(0), "Zero address");
       require(amount > 0, "Zero amount");

       // Calculate total tokens reserved for all vesting periods (allocated but not yet claimed)
       uint256 founderReserved = founderVesting.totalAllocation - founderVesting.claimed;
       uint256 founderOpsReserved = founderOpsVesting.totalAllocation - founderOpsVesting.claimed;
       
       // 🔐 CRITICAL SECURITY FIX: Reserve the ENTIRE investor pool (5%), not just allocated investors
       // This prevents draining the 16.8M SVRA investor pool before investors are added
       uint256 investorPoolReserved = EXPECTED_INVESTOR_ALLOCATION - totalInvestorClaimed;

       uint256 totalReserved = founderReserved + founderOpsReserved + investorPoolReserved;

       uint256 currentBalance = svraToken.balanceOf(address(this));

       // Critical Security Check: Ensure balance after withdrawal >= tokens reserved for future claims
       require(currentBalance >= totalReserved + amount, "Exceeds unassigned tokens");

       require(svraToken.transfer(to, amount), "Transfer failed");
       emit UnassignedWithdrawn(to, amount);
   }

   // ---------------------- VIEW FUNCTIONS - FOUNDER PRINCIPAL ----------------------
   function founderUnlocked() external view returns (uint256) {
       return _founderUnlocked();
   }

   function founderClaimable() external view returns (uint256) {
       uint256 unlocked = _founderUnlocked();
       return unlocked > founderVesting.claimed ? unlocked - founderVesting.claimed : 0;
   }

   function _founderUnlocked() internal view returns (uint256) {
       if (founderVesting.totalAllocation == 0) return 0;

       uint256 elapsed = block.timestamp - founderVesting.startTimestamp;

       if (elapsed < FOUNDER_CLIFF) return 0;
       if (elapsed >= FOUNDER_TOTAL_DURATION) return founderVesting.totalAllocation;

       uint256 timeAfterCliff = elapsed - FOUNDER_CLIFF;
       return (founderVesting.totalAllocation * timeAfterCliff) / FOUNDER_VESTING_DURATION;
   }

   // ---------------------- VIEW FUNCTIONS - FOUNDER OPS PERSONAL (2.97%) ----------------------
   // 🔥 NEW FUNCTIONS
   function founderOpsUnlocked() external view returns (uint256) {
       return _founderOpsUnlocked();
   }

   // 👇 FONCTION AJOUTÉE POUR LE FRONT-END (RÉCLAMABLE) 👇
   function founderOpsClaimable() external view returns (uint256) {
       uint256 unlocked = _founderOpsUnlocked();
       return unlocked > founderOpsVesting.claimed ? unlocked - founderOpsVesting.claimed : 0;
   }

   function _founderOpsUnlocked() internal view returns (uint256) {
       if (founderOpsVesting.totalAllocation == 0) return 0;

       uint256 elapsed = block.timestamp - founderOpsVesting.startTimestamp;

       if (elapsed < FOUNDER_OPS_CLIFF) return 0;
       if (elapsed >= FOUNDER_OPS_TOTAL_DURATION) return founderOpsVesting.totalAllocation;

       uint256 timeAfterCliff = elapsed - FOUNDER_OPS_CLIFF;
       return (founderOpsVesting.totalAllocation * timeAfterCliff) / FOUNDER_OPS_VESTING_DURATION;
   }

   // ---------------------- VIEW FUNCTIONS - INVESTOR (unchanged) ----------------------
   function investorUnlocked(address wallet) external view returns (uint256) {
       return _investorUnlocked(wallet);
   }

   function investorClaimable(address wallet) external view returns (uint256) {
       uint256 unlocked = _investorUnlocked(wallet);
       return unlocked > investors[wallet].claimed ? unlocked - investors[wallet].claimed : 0;
   }

   function _investorUnlocked(address wallet) internal view returns (uint256) {
       InvestorVesting memory vesting = investors[wallet];
       if (vesting.totalAllocation == 0) return 0;

       uint256 elapsed = block.timestamp - vesting.startTimestamp;

       // Cliff period: no tokens unlocked during first 30 days
       if (elapsed < INVESTOR_CLIFF_DURATION) return 0;

       // After total duration (210 days): 100% unlocked
       if (elapsed >= INVESTOR_TOTAL_DURATION) return vesting.totalAllocation;

       // Linear vesting after cliff: (allocation × time_after_cliff) / vesting_duration
       uint256 timeAfterCliff = elapsed - INVESTOR_CLIFF_DURATION;
       return (vesting.totalAllocation * timeAfterCliff) / INVESTOR_VESTING_DURATION;
   }

   // ---------------------- ADMIN CONTROLS (unchanged) ----------------------
   function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
       _pause();
   }

   function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
       _unpause();
   }
}

