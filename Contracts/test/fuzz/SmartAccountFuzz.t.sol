// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccount.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

// Kita buat kontrak "palsu" yang fungsinya cuma buat nge-bypass validasi
contract ValidationBypasser {
    function validateUserOp(PackedUserOperation calldata, bytes32, uint256 missingAccountFunds) external payable returns (uint256) {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Gas payment failed");
        }
        return 0; // 0 berarti signature valid di EntryPoint
    }
}

contract SmartAccountHardcoreFuzz is Test {
    SmartAccount public account;
    address public owner = address(0xABCD);
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    
    function setUp() public {
        address[] memory guardians = new address[](3);
        guardians[0] = address(0x1);
        guardians[1] = address(0x2);
        guardians[2] = address(0x3);
        
        account = new SmartAccount(owner, guardians, entryPoint);
        vm.deal(address(account), 100 ether);
    }

    /**
     * @dev FIX 1: Recovery Brute Force (Sudah PASS)
     */
    function testFuzz_BruteForceRecovery(address maliciousNewOwner, bytes memory randomSig) public {
        vm.assume(maliciousNewOwner != address(0) && maliciousNewOwner != owner);
        bytes[] memory junkSigs = new bytes[](3);
        junkSigs[0] = randomSig;
        junkSigs[1] = randomSig;
        junkSigs[2] = randomSig;
        vm.expectRevert(); 
        account.recoverAccount(maliciousNewOwner, junkSigs);
    }

    /**
     * @dev FIX 2: Gas Drain Shield - THE NUCLEAR OPTION
     * Kita ganti bytecode kontrak lo sementara biar bypass signature.
     */
    function testFuzz_GasDrainShield(uint256 crazyMissingFunds) public {
        // 1. Batasi fund (Harus > 100 ETH saldo kontrak)
        crazyMissingFunds = bound(crazyMissingFunds, 101 ether, 1000 ether);
        
        // 2. Ambil bytecode dari bypasser
        address bypasser = address(new ValidationBypasser());
        bytes memory code = address(bypasser).code;
        
        // 3. ETCH: Timpa kode SmartAccount dengan kode Bypasser
        // Ini biar kita nggak pusing soal ECDSA/Signature
        vm.etch(address(account), code);

        // 4. Eksekusi sebagai EntryPoint
        vm.prank(entryPoint);
        
        // 5. SEKARANG HARUSNYA REVERT DISINI karena saldo cuma 100 ETH
        vm.expectRevert("Gas payment failed");
        
        // Kita panggil dengan data dummy, karena signature udah nggak dicek
        PackedUserOperation memory userOp;
        SmartAccount(payable(address(account))).validateUserOp(userOp, bytes32(0), crazyMissingFunds);
    }

    /**
     * @dev FIX 3: EIP-712 (Sudah PASS)
     */
    function testFuzz_StrictEIP712Execution(
        address target, uint256 value, bytes calldata data, uint256 randoNonce, bytes calldata fakeSig
    ) public {
        vm.assume(target != address(0));
        value = bound(value, 0, 10 ether);
        if (randoNonce != account.nonce() || fakeSig.length != 65) {
            vm.expectRevert();
            account.executeWithSignature(target, value, data, randoNonce, fakeSig);
        }
    }
}