// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Events
 * @notice Centralized event definitions for AAApps.
 */
abstract contract Events {
    // --- Token Events ---
    event TokenCreated(
        address indexed token,
        string name,
        string symbol,
        address indexed owner
    );

    event TokenMinted(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    event TokenBurned(
        address indexed token,
        address indexed from,
        uint256 amount
    );

    // --- Account Abstraction Core Events ---
    event AccountCreated(
        address indexed owner,
        address account
    );

    event UserOperationExecuted(
        address indexed sender, 
        uint256 nonce, 
        bytes result
    );

    event Executed(
        address indexed sender,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 nonce
    );

    // --- Paymaster & Finance Events ---
    event Deposit(address indexed sender, uint256 amount);
    
    event PaymasterCharge(
        address indexed paymaster,
        address indexed user,
        uint256 tokenAmount,
        string reason
    );

    // --- Admin Events ---
    event OwnerChanged(
        address indexed oldOwner, 
        address indexed newOwner
    );
}