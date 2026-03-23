// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./SmartAccount.sol";

contract SmartAccountFactory {
    address public immutable entryPoint;

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    function createAccount(
        address owner,
        address[] memory guardians,
        uint256 salt
    ) external returns (SmartAccount) {
        // 🔥 VALIDASI: Minimal harus ada 1 guardian biar ga deadlock
        require(guardians.length > 0, "At least one guardian required");
        
        address addr = getAddress(owner, guardians, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SmartAccount(payable(addr));
        }

        // Pakai keccak256(owner, salt) sebagai salt asli CREATE2 
        // Biar alamat unik per owner meskipun angka salt-nya sama
        bytes32 finalSalt = keccak256(abi.encode(owner, salt));

        return new SmartAccount{salt: finalSalt}(owner, guardians, entryPoint);
    }

    function getAddress(
        address owner,
        address[] memory guardians,
        uint256 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(SmartAccount).creationCode,
            abi.encode(owner, guardians, entryPoint)
        );
        
        bytes32 finalSalt = keccak256(abi.encode(owner, salt));

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                finalSalt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}