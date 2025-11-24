// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title SOLVIRA Timelock Controller
/// @notice 48-hour timelock for all critical governance operations on SOLVIRA token
/// @dev Inherits OpenZeppelin's battle-tested TimelockController
/// @custom:security-contact security@solvira.io
contract SolviraTimelock is TimelockController {
    
    /// @notice Minimum delay for all operations (48 hours)
    uint256 public constant MIN_DELAY = 172800; // 48 hours in seconds
    
    /// @notice Official Gnosis Safe Multi-sig Address (Base Mainnet)
    /// @dev This address will be the sole proposer and canceller
    address public constant GNOSIS_SAFE = 0xF1e029a360D2955B1Ea5bc0e2E210b706d1edBF7;
    
    /// @notice Emitted when the timelock is deployed
    /// @param minDelay The minimum delay in seconds before operations can be executed
    /// @param safe The Gnosis Safe address with proposer/canceller privileges
    event TimelockDeployed(uint256 minDelay, address indexed safe);
    
    /**
     * @notice Initializes the TimelockController with SOLVIRA-specific parameters
     * @dev Constructor sets up the timelock with:
     *      - 48-hour delay for all operations
     *      - Gnosis Safe as sole proposer (can schedule operations)
     *      - Gnosis Safe as sole canceller (can cancel pending operations)
     *      - Anyone can execute (address(0) in executors array)
     *      - Gnosis Safe as admin (can manage timelock roles)
     */
    constructor()
        TimelockController(
            MIN_DELAY,                    // minDelay: 48 hours
            new address[](0),             // proposers: empty array, will grant role manually
            new address[](0),             // executors: empty array, will grant role manually  
            GNOSIS_SAFE                   // admin: Gnosis Safe controls the timelock itself
        )
    {
        // Grant PROPOSER_ROLE to Gnosis Safe
        // This allows the Safe to schedule operations with 48h delay
        _grantRole(PROPOSER_ROLE, GNOSIS_SAFE);
        
        // Grant CANCELLER_ROLE to Gnosis Safe
        // This allows the Safe to cancel pending operations if needed
        _grantRole(CANCELLER_ROLE, GNOSIS_SAFE);
        
        // Grant EXECUTOR_ROLE to address(0)
        // This allows ANYONE to execute operations after the 48h delay
        // This is standard practice for transparency (anyone can verify execution)
        _grantRole(EXECUTOR_ROLE, address(0));
        
        emit TimelockDeployed(MIN_DELAY, GNOSIS_SAFE);
    }
    
    /**
     * @notice Returns human-readable delay time
     * @return The delay in hours (48)
     */
    function getDelayInHours() external pure returns (uint256) {
        return MIN_DELAY / 3600; // 172800 / 3600 = 48 hours
    }
    
    /**
     * @notice Check if the Gnosis Safe has proposer privileges
     * @return bool True if Safe can propose operations
     */
    function isSafeProposer() external view returns (bool) {
        return hasRole(PROPOSER_ROLE, GNOSIS_SAFE);
    }
    
    /**
     * @notice Check if the Gnosis Safe has canceller privileges
     * @return bool True if Safe can cancel operations
     */
    function isSafeCanceller() external view returns (bool) {
        return hasRole(CANCELLER_ROLE, GNOSIS_SAFE);
    }
}
