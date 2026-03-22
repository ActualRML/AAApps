// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ECDSA
 * @dev Library untuk pemulihan alamat dari signature ECDSA.
 */
library ECDSA {
    /**
     * @dev Menghasilkan hash pesan Ethereum ("\x19Ethereum Signed Message:\n32" + hash).
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Memulihkan alamat dari signature (r, s, v).
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        // Membagi signature menggunakan assembly
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // EIP-2: Memastikan s berada di rentang lower-half untuk mencegah malleability
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);

        return ecrecover(hash, v, r, s);
    }
}