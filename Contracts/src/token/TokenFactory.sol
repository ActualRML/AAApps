// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MockToken} from "./MockToken.sol";
import {Events} from "../events/Events.sol";

contract TokenFactory is Events {
    address[] public allTokens;
    
    // Gunakan hash dari simbol jika ingin tetap unik berdasarkan nama/simbol
    mapping(bytes32 => address) public tokenByHash;

    function createToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply
    ) external returns (address) {
        bytes32 symbolHash = keccak256(abi.encodePacked(symbol));
        require(tokenByHash[symbolHash] == address(0), "Symbol already exists");

        MockToken token = new MockToken(
            name,
            symbol,
            initialSupply,
            msg.sender
        );

        address tokenAddress = address(token);
        allTokens.push(tokenAddress);
        tokenByHash[symbolHash] = tokenAddress;

        emit TokenCreated(tokenAddress, name, symbol, msg.sender);
        return tokenAddress;
    }

    // --- FIX UNTUK ERROR TEST: Member "getAllTokens" not found ---
    /**
     * @notice Mengambil semua alamat token yang pernah di-deploy.
     * Digunakan oleh test script dan mempermudah tracking di awal development.
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    // Gunakan pagination untuk menghindari masalah gas limit di masa depan
    function getTokensCount() external view returns (uint256) {
        return allTokens.length;
    }

    function getTokensRange(uint256 start, uint256 end) external view returns (address[] memory) {
        require(start < end && end <= allTokens.length, "Invalid range");
        uint256 size = end - start;
        address[] memory batch = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            batch[i] = allTokens[start + i];
        }
        return batch;
    }
}