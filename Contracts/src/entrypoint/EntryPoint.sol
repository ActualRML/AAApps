// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SmartAccount} from "../smart-account/SmartAccount.sol";

/**
 * @title EntryPoint
 * @author Ronaldio Melvern
 * @notice Central entry point for AAApps executing EIP-712 signed operations.
 * @dev Handles gas deposits and orchestrates smart account executions.
 */
contract EntryPoint {
    // ============ STORAGE ============
    
    mapping(address => uint256) public balances;

    // ============ EVENTS ============

    event OpsExecuted(address indexed sender, bool success, bytes result);
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, address to, uint256 amount);

    // ============ CORE FUNCTIONS ============

    /**
     * @notice Executes an operation via SmartAccount signature validation.
     * @param sender The address of the SmartAccount proxy.
     * @param target The target contract address to call.
     * @param value Native token amount to send.
     * @param data The calldata for the target execution.
     * @param nonce Transaction nonce for replay protection.
     * @param signature EIP-712 signature from the account owner.
     */
    function handleOps(
        address payable sender,
        address target,
        uint256 value,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external {
        try SmartAccount(sender).executeWithSignature(target, value, data, nonce, signature) returns (bytes memory result) {
            emit OpsExecuted(sender, true, result);
        } catch (bytes memory lowLevelData) {
            emit OpsExecuted(sender, false, lowLevelData);
            if (lowLevelData.length > 0) {
                assembly {
                    revert(add(lowLevelData, 32), mload(lowLevelData))
                }
            }
            revert("Execution failed");
        }
    }

    // ============ ACCOUNT MANAGEMENT ============

    /**
     * @notice Deposits ETH into the EntryPoint for gas compensation.
     * @param account The address to credit the deposit to.
     */
    function depositTo(address account) external payable {
        balances[account] += msg.value;
        emit Deposited(account, msg.value);
    }

    /**
     * @notice Withdraws deposited ETH from the EntryPoint.
     * @param to The destination address for the funds.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawTo(address payable to, uint256 amount) external {
        uint256 balance = balances[msg.sender];
        if (balance < amount) revert("Insufficient balance");
        
        balances[msg.sender] = balance - amount;
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawn(msg.sender, to, amount);
    }

    /**
     * @dev Returns the gas deposit balance of an account.
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}