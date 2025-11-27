// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Minimal ERC20 interface
interface IERC20 {
   function transfer(address to, uint256 amount) external returns (bool);
   function balanceOf(address account) external view returns (uint256);
}

/**
* @title OperationalVesting
* @notice Secures 42% of SOLVIRA treasury with progressive unlock schedules
* @dev Three categories: Community (28%), Marketing (12%), Dev (10%)
* @dev CRITICAL SECURITY: Prevents instant drainage of operational funds
*/
contract OperationalVesting is AccessControl, Pausable, ReentrancyGuard {

   // ---------------------- ROLES ----------------------
   bytes32 public constant VESTING_MANAGER_ROLE = keccak256("VESTING_MANAGER_ROLE");

   // ---------------------- IMMUTABLES ----------------------
   IERC20 public svraToken;  // Set once during initialization
   uint256 public immutable deploymentTimestamp;
   bool public tokenInitialized;

   // ---------------------- VESTING CONSTANTS ----------------------
   // Community Budget (28%) - 3 months cliff + 24 months linear (27 months total)
   uint256 public constant COMMUNITY_CLIFF = 90 days;            // ~3 months
   uint256 public constant COMMUNITY_VESTING_DURATION = 720 days; // ~24 months
   uint256 public constant COMMUNITY_TOTAL_DURATION = COMMUNITY_CLIFF + COMMUNITY_VESTING_DURATION; // 810 days

   // Marketing Budget (12%) - 1 month cliff + 12 months linear (13 months total)
   uint256 public constant MARKETING_CLIFF = 30 days;            // ~1 month
   uint256 public constant MARKETING_VESTING_DURATION = 360 days; // ~12 months
   uint256 public constant MARKETING_TOTAL_DURATION = MARKETING_CLIFF + MARKETING_VESTING_DURATION; // 390 days

   // Development Budget (10%) - 1 month cliff + 18 months linear (19 months total)
   uint256 public constant DEV_CLIFF = 30 days;            // ~1 month
   uint256 public constant DEV_VESTING_DURATION = 540 days; // ~18 months
   uint256 public constant DEV_TOTAL_DURATION = DEV_CLIFF + DEV_VESTING_DURATION; // 570 days

   // 🔐 SECURITY: Expected allocations (must match SOLVIRA.sol distribution)
   // Total Supply: 336,000,000 SVRA (with 18 decimals)
   uint256 public constant EXPECTED_COMMUNITY_ALLOCATION = 94_080_000 * 10**18;  // 28%
   uint256 public constant EXPECTED_MARKETING_ALLOCATION = 40_320_000 * 10**18;  // 12%
   uint256 public constant EXPECTED_DEV_ALLOCATION = 33_600_000 * 10**18;        // 10%
   uint256 public constant EXPECTED_TOTAL_OPERATIONAL = 168_000_000 * 10**18;    // 50% total (42% vested + 8% for rounding)

   // ---------------------- STRUCTURES ----------------------
   struct VestingSchedule {
       address beneficiary;
       uint256 totalAllocation;
       uint256 claimed;
       uint256 startTimestamp;
       uint256 cliffDuration;
       uint256 vestingDuration;
   }

   // ---------------------- STATE ----------------------
   VestingSchedule public communityVesting;
   VestingSchedule public marketingVesting;
   VestingSchedule public devVesting;

   // 🔐 SECURITY: Prevents withdrawal of vested tokens before allocations are locked
   bool public allocationsFinalized;

   // ---------------------- EVENTS ----------------------
   event BeneficiaryUpdated(string indexed category, address indexed oldBeneficiary, address indexed newBeneficiary);
   event TokensClaimed(address indexed beneficiary, string category, uint256 amount);
   event UnassignedWithdrawn(address indexed to, uint256 amount);
   event AllocationsFinalized(uint256 communityAlloc, uint256 marketingAlloc, uint256 devAlloc, uint256 timestamp);
   event TokenInitialized(address indexed tokenAddress);

   // ---------------------- CONSTRUCTOR ----------------------
   constructor() {
       deploymentTimestamp = block.timestamp;

       // Grant initial roles
       _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
       _grantRole(VESTING_MANAGER_ROLE, msg.sender);

       // Initialize vesting schedules (start at deployment)
       communityVesting = VestingSchedule({
           beneficiary: address(0),
           totalAllocation: 0,
           claimed: 0,
           startTimestamp: block.timestamp,
           cliffDuration: COMMUNITY_CLIFF,
           vestingDuration: COMMUNITY_VESTING_DURATION
       });

       marketingVesting = VestingSchedule({
           beneficiary: address(0),
           totalAllocation: 0,
           claimed: 0,
           startTimestamp: block.timestamp,
           cliffDuration: MARKETING_CLIFF,
           vestingDuration: MARKETING_VESTING_DURATION
       });

       devVesting = VestingSchedule({
           beneficiary: address(0),
           totalAllocation: 0,
           claimed: 0,
           startTimestamp: block.timestamp,
           cliffDuration: DEV_CLIFF,
           vestingDuration: DEV_VESTING_DURATION
       });
   }

   // ---------------------- TOKEN INITIALIZATION ----------------------
   
   /// @notice Initialize SVRA token address (can only be called once)
   /// @dev MUST be called after SOLVIRA deployment (which mints 168M SVRA to this address)
   /// @dev SECURITY: Verifies contract received expected 168M SVRA allocation
   function initializeToken(address _svraToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(!tokenInitialized, "OperationalVesting: token already initialized");
       require(_svraToken != address(0), "OperationalVesting: zero address");
       require(!allocationsFinalized, "OperationalVesting: allocations already finalized");
       
       svraToken = IERC20(_svraToken);
       
       // 🔐 CRITICAL SECURITY CHECK: Verify contract received full 168M SVRA from SOLVIRA deployment
       uint256 currentBalance = svraToken.balanceOf(address(this));
       require(
           currentBalance == EXPECTED_TOTAL_OPERATIONAL,
           "OperationalVesting: incorrect token balance - SOLVIRA must mint 168M SVRA first"
       );
       
       tokenInitialized = true;
       
       emit TokenInitialized(_svraToken);
   }

   // ---------------------- BENEFICIARY MANAGEMENT ----------------------
   
   /// @notice Set beneficiary wallet for Community budget
   function setCommunityBeneficiary(address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(_beneficiary != address(0), "OperationalVesting: zero address");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       address old = communityVesting.beneficiary;
       communityVesting.beneficiary = _beneficiary;
       emit BeneficiaryUpdated("Community", old, _beneficiary);
   }

   /// @notice Set beneficiary wallet for Marketing budget
   function setMarketingBeneficiary(address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(_beneficiary != address(0), "OperationalVesting: zero address");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       address old = marketingVesting.beneficiary;
       marketingVesting.beneficiary = _beneficiary;
       emit BeneficiaryUpdated("Marketing", old, _beneficiary);
   }

   /// @notice Set beneficiary wallet for Development budget
   function setDevBeneficiary(address _beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(_beneficiary != address(0), "OperationalVesting: zero address");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       address old = devVesting.beneficiary;
       devVesting.beneficiary = _beneficiary;
       emit BeneficiaryUpdated("Dev", old, _beneficiary);
   }

   // ---------------------- ALLOCATION MANAGEMENT ----------------------
   
   /// @notice Set allocation for Community budget (28%)
   /// @dev Can only be called ONCE before finalization
   function setCommunityAllocation(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(tokenInitialized, "OperationalVesting: token not initialized");
       require(communityVesting.beneficiary != address(0), "OperationalVesting: beneficiary not set");
       require(communityVesting.totalAllocation == 0, "OperationalVesting: already set");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       require(_amount == EXPECTED_COMMUNITY_ALLOCATION, "OperationalVesting: must be 94080000 SVRA");
       communityVesting.totalAllocation = _amount;
   }

   /// @notice Set allocation for Marketing budget (12%)
   /// @dev Can only be called ONCE before finalization
   function setMarketingAllocation(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(tokenInitialized, "OperationalVesting: token not initialized");
       require(marketingVesting.beneficiary != address(0), "OperationalVesting: beneficiary not set");
       require(marketingVesting.totalAllocation == 0, "OperationalVesting: already set");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       require(_amount == EXPECTED_MARKETING_ALLOCATION, "OperationalVesting: must be 40320000 SVRA");
       marketingVesting.totalAllocation = _amount;
   }

   /// @notice Set allocation for Development budget (10%)
   /// @dev Can only be called ONCE before finalization
   function setDevAllocation(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(tokenInitialized, "OperationalVesting: token not initialized");
       require(devVesting.beneficiary != address(0), "OperationalVesting: beneficiary not set");
       require(devVesting.totalAllocation == 0, "OperationalVesting: already set");
       require(!allocationsFinalized, "OperationalVesting: allocations finalized");
       require(_amount == EXPECTED_DEV_ALLOCATION, "OperationalVesting: must be 33600000 SVRA");
       devVesting.totalAllocation = _amount;
   }

   // 🔐 SECURITY FIX: Lock allocations to prevent withdrawal exploit
   /// @notice Finalizes all allocations and prevents withdrawUnassignedTokens from draining vested funds
   /// @dev CRITICAL: Verifies EXACT allocations match expected values AND contract balance
   /// @dev Must be called after setting all three allocations, before any withdrawals
   function finalizeAllocations() external onlyRole(DEFAULT_ADMIN_ROLE) {
       require(tokenInitialized, "OperationalVesting: token not initialized");
       require(!allocationsFinalized, "OperationalVesting: already finalized");
       
       // 🔐 CRITICAL: Verify EXACT amounts (prevents admin from setting 1 token and draining the rest)
       require(
           communityVesting.totalAllocation == EXPECTED_COMMUNITY_ALLOCATION,
           "OperationalVesting: community allocation mismatch"
       );
       require(
           marketingVesting.totalAllocation == EXPECTED_MARKETING_ALLOCATION,
           "OperationalVesting: marketing allocation mismatch"
       );
       require(
           devVesting.totalAllocation == EXPECTED_DEV_ALLOCATION,
           "OperationalVesting: dev allocation mismatch"
       );
       
       // 🔐 CRITICAL: Verify sum of allocations matches expected total
       uint256 totalAllocations = communityVesting.totalAllocation + 
                                   marketingVesting.totalAllocation + 
                                   devVesting.totalAllocation;
       require(
           totalAllocations == EXPECTED_TOTAL_OPERATIONAL,
           "OperationalVesting: total allocations must equal 168M SVRA"
       );
       
       // 🔐 CRITICAL: Verify contract still holds the full 168M SVRA (prevents pre-finalization drainage)
       uint256 currentBalance = svraToken.balanceOf(address(this));
       require(
           currentBalance == EXPECTED_TOTAL_OPERATIONAL,
           "OperationalVesting: contract balance mismatch - tokens may have been drained"
       );
       
       allocationsFinalized = true;
       emit AllocationsFinalized(
           communityVesting.totalAllocation,
           marketingVesting.totalAllocation,
           devVesting.totalAllocation,
           block.timestamp
       );
   }

   // ---------------------- UNLOCKED AMOUNT CALCULATION ----------------------
   
   /// @notice Calculate unlocked amount for a vesting schedule
   /// @param schedule The vesting schedule to calculate for
   /// @return The amount of tokens currently unlocked
   function _calculateUnlocked(VestingSchedule memory schedule) private view returns (uint256) {
       if (schedule.totalAllocation == 0) return 0;
       
       uint256 elapsed = block.timestamp - schedule.startTimestamp;
       
       // Before cliff: nothing unlocked
       if (elapsed < schedule.cliffDuration) {
           return 0;
       }
       
       // After full vesting: everything unlocked
       if (elapsed >= schedule.cliffDuration + schedule.vestingDuration) {
           return schedule.totalAllocation;
       }
       
       // During vesting period: linear unlock
       uint256 vestingElapsed = elapsed - schedule.cliffDuration;
       uint256 unlocked = (schedule.totalAllocation * vestingElapsed) / schedule.vestingDuration;
       
       return unlocked;
   }

   /// @notice Get unlocked amount for Community budget
   function communityUnlocked() public view returns (uint256) {
       return _calculateUnlocked(communityVesting);
   }

   /// @notice Get unlocked amount for Marketing budget
   function marketingUnlocked() public view returns (uint256) {
       return _calculateUnlocked(marketingVesting);
   }

   /// @notice Get unlocked amount for Development budget
   function devUnlocked() public view returns (uint256) {
       return _calculateUnlocked(devVesting);
   }

   // ---------------------- CLAIMING ----------------------
   
   /// @notice Claim unlocked Community tokens
   function claimCommunity() external nonReentrant whenNotPaused {
       require(msg.sender == communityVesting.beneficiary, "OperationalVesting: not beneficiary");
       
       uint256 unlocked = communityUnlocked();
       uint256 claimable = unlocked - communityVesting.claimed;
       require(claimable > 0, "OperationalVesting: nothing to claim");
       
       communityVesting.claimed += claimable;
       require(svraToken.transfer(msg.sender, claimable), "OperationalVesting: transfer failed");
       
       emit TokensClaimed(msg.sender, "Community", claimable);
   }

   /// @notice Claim unlocked Marketing tokens
   function claimMarketing() external nonReentrant whenNotPaused {
       require(msg.sender == marketingVesting.beneficiary, "OperationalVesting: not beneficiary");
       
       uint256 unlocked = marketingUnlocked();
       uint256 claimable = unlocked - marketingVesting.claimed;
       require(claimable > 0, "OperationalVesting: nothing to claim");
       
       marketingVesting.claimed += claimable;
       require(svraToken.transfer(msg.sender, claimable), "OperationalVesting: transfer failed");
       
       emit TokensClaimed(msg.sender, "Marketing", claimable);
   }

   /// @notice Claim unlocked Development tokens
   function claimDev() external nonReentrant whenNotPaused {
       require(msg.sender == devVesting.beneficiary, "OperationalVesting: not beneficiary");
       
       uint256 unlocked = devUnlocked();
       uint256 claimable = unlocked - devVesting.claimed;
       require(claimable > 0, "OperationalVesting: nothing to claim");
       
       devVesting.claimed += claimable;
       require(svraToken.transfer(msg.sender, claimable), "OperationalVesting: transfer failed");
       
       emit TokensClaimed(msg.sender, "Dev", claimable);
   }

   // ---------------------- EMERGENCY WITHDRAWAL ----------------------
   
   /// @notice Withdraw tokens that are NOT allocated to any vesting schedule
   /// @dev SECURITY: Can only be called AFTER allocations are finalized to prevent draining vested funds
   function withdrawUnassignedTokens(address to, uint256 amount)
       external
       onlyRole(DEFAULT_ADMIN_ROLE)
       nonReentrant
   {
       require(allocationsFinalized, "OperationalVesting: allocations not finalized");
       require(to != address(0), "Zero address");
       require(amount > 0, "Zero amount");

       // Calculate total tokens reserved for all vesting schedules
       uint256 communityReserved = communityVesting.totalAllocation - communityVesting.claimed;
       uint256 marketingReserved = marketingVesting.totalAllocation - marketingVesting.claimed;
       uint256 devReserved = devVesting.totalAllocation - devVesting.claimed;

       uint256 totalReserved = communityReserved + marketingReserved + devReserved;

       uint256 currentBalance = svraToken.balanceOf(address(this));

       // Critical Security Check: Ensure balance after withdrawal >= tokens reserved for future claims
       require(currentBalance >= totalReserved + amount, "Exceeds unassigned tokens");

       require(svraToken.transfer(to, amount), "Transfer failed");
       emit UnassignedWithdrawn(to, amount);
   }

   // ---------------------- ADMIN CONTROLS ----------------------
   
   /// @notice Pause all claiming operations (emergency only)
   function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
       _pause();
   }

   /// @notice Resume claiming operations
   function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
       _unpause();
   }

   // ---------------------- VIEW FUNCTIONS ----------------------
   
   /// @notice Get claimable amount for Community budget
   function communityClaimable() external view returns (uint256) {
       uint256 unlocked = communityUnlocked();
       return unlocked > communityVesting.claimed ? unlocked - communityVesting.claimed : 0;
   }

   /// @notice Get claimable amount for Marketing budget
   function marketingClaimable() external view returns (uint256) {
       uint256 unlocked = marketingUnlocked();
       return unlocked > marketingVesting.claimed ? unlocked - marketingVesting.claimed : 0;
   }

   /// @notice Get claimable amount for Development budget
   function devClaimable() external view returns (uint256) {
       uint256 unlocked = devUnlocked();
       return unlocked > devVesting.claimed ? unlocked - devVesting.claimed : 0;
   }

   /// @notice Get total vesting progress summary
   function getVestingStatus() external view returns (
       uint256 communityTotal,
       uint256 communityClaimed,
       uint256 communityUnlocked_,
       uint256 marketingTotal,
       uint256 marketingClaimed,
       uint256 marketingUnlocked_,
       uint256 devTotal,
       uint256 devClaimed,
       uint256 devUnlocked_
   ) {
       return (
           communityVesting.totalAllocation,
           communityVesting.claimed,
           communityUnlocked(),
           marketingVesting.totalAllocation,
           marketingVesting.claimed,
           marketingUnlocked(),
           devVesting.totalAllocation,
           devVesting.claimed,
           devUnlocked()
       );
   }
}
