// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../smart-account/SmartAccount.sol";

contract EntryPoint {
    event OpsExecuted(address indexed sender, bool success, bytes result);

    function handleOps(
        address sender,
        address target,
        uint256 value,
        bytes calldata data,
        uint256 nonce,
        bytes calldata signature
    ) external {
        SmartAccount wallet = SmartAccount(payable(sender));

        // Menggunakan try-catch agar jika transaksi wallet gagal, 
        // EntryPoint tetap bisa memberikan info success/fail (opsional)
        try wallet.executeWithSignature(target, value, data, nonce, signature) returns (bytes memory result) {
            emit OpsExecuted(sender, true, result);
        } catch {
            emit OpsExecuted(sender, false, "");
            revert("Execution failed");
        }
    }
}