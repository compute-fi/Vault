// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

library ErrorsLib {
    /// @notice Thrown when trying to deploy a contract with a 0 address
    error ATOKEN_NON_EXISTENT();
    /// @notice Thrown when reinvested amounts are not enough.
    error MIN_AMOUNT_ERROR();
    /// @notice Thrown when trying to call a function that is restricted
    error INVALID_ACCESS();
    /// @notice Thrown when trying to redeem shares worth 0 assets
    error ZERO_ASSETS();

    /// @notice Thrown when a call to Compound returned an error.
    /// @param errorCode The error code returned by Compound
    error COMPOUND_ERROR(uint256 errorCode);

    /// @notice Thrown when caller is not the manager.
    error INVALID_ACCESS_ERROR();
    /// @notice Thrown when swap path fee in reinvest is invalid.
    error INVALID_FEE_ERROR();
}
