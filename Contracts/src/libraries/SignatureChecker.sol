// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ECDSA.sol";

/**
 * @title SignatureChecker
 * @dev Helper untuk memvalidasi apakah signature sesuai dengan owner.
 */
library SignatureChecker {
    using ECDSA for bytes32;

    /**
     * @dev Fungsi bantuan untuk mendapatkan alamat signer dari sebuah hash dan signature.
     * Sangat berguna untuk fitur Social Recovery (Guardian).
     */
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Otomatis mengubah hash mentah menjadi Ethereum Signed Message Hash
        bytes32 ethSignedHash = hash.toEthSignedMessageHash();
        return ECDSA.recover(ethSignedHash, signature);
    }

    /**
     * @dev Verifikasi signature secara standar (EOA).
     * Digunakan oleh SmartAccount untuk memvalidasi UserOperation.
     */
    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (bool) {
        // Cek apakah hasil recover sama dengan signer yang diharapkan
        address recovered = recoverSigner(hash, signature);
        
        return recovered != address(0) && recovered == signer;
    }
}