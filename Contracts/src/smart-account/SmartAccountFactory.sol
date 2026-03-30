// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SmartAccount} from "./SmartAccount.sol";
import {Errors} from "../common/Errors.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract SmartAccountFactory {
    address public immutable ENTRY_POINT;
    address public immutable IMPLEMENTATION;
    
    constructor(address _entryPoint) payable {
        if (_entryPoint == address(0)) revert Errors.ZeroAddress();
        ENTRY_POINT = _entryPoint;
        IMPLEMENTATION = address(new SmartAccount());
    }

    function createAccount(
        address owner,
        address[] calldata guardians,
        uint256 threshold,
        uint256 salt
    ) external payable returns (address account) {
        if (owner == address(0)) revert Errors.ZeroAddress();
        
        bytes32 finalSalt = keccak256(abi.encode(owner, salt));
        account = Clones.predictDeterministicAddress(IMPLEMENTATION, finalSalt, address(this));
        
        // Cek apakah sudah deploy
        if (account.code.length > 0) {
            return account;
        }

        // Deploy menggunakan library Clones (EIP-1167 + CREATE2)
        account = Clones.cloneDeterministic(IMPLEMENTATION, finalSalt);

        // Langsung panggil pengecekan threshold sebelum initialize
        if (threshold == 0 || threshold > guardians.length) revert Errors.InvalidThreshold();

        // Initialize state
        SmartAccount(payable(account)).initialize(owner, guardians, threshold, ENTRY_POINT);
        
        return account;
    }

    function getAddress(address owner, uint256 salt) public view returns (address predicted) {
        bytes32 finalSalt = keccak256(abi.encode(owner, salt));
        return Clones.predictDeterministicAddress(IMPLEMENTATION, finalSalt, address(this));
    }
}