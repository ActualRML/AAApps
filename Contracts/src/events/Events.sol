// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Events {
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

    event Deposit(address indexed sender, uint256 amount);

    event Executed(
        address indexed sender,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 nonce
    );

    event AccountCreated(
        address indexed owner,
        address account
    );

    event UserOperationExecuted(
        address indexed sender, 
        uint256 nonce, 
        bytes result
    );
}