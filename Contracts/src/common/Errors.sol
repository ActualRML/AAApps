// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Errors
 * @notice Centralized custom errors for AAApps project.
 * @dev Menggunakan custom error jauh lebih hemat gas daripada require strings.
 */
interface Errors {
    // ============ SmartAccount Errors ============
    error Reentrancy();
    error NotOwner();
    error NotEntryPoint();
    error NotAuthorized();
    error InvalidTarget();
    error InvalidSignature();
    error InvalidNonce();
    error DuplicateSigner();
    error ThresholdNotMet();
    error ZeroAddress();
    error InvalidThreshold();
    error AlreadyInitialized();
    error NotGuardian();
    error InsufficientBalance();

    // ============ SmartAccountFactory Errors ============
    error DeploymentFailed();   
    error NoGuardians();      
    error ArrayMismatch();

    // ============ Paymaster Errors ============
    error PreChargeFailed();
    error PostOpReverted();
    error InvalidPriceData();
    error MarkupTooLow();
    error TransferFailed();
    error WithdrawFailed();
}   