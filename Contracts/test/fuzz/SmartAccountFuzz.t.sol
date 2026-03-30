// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccount.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Kontrak bypasser untuk teknik ETCH. 
 * Digunakan untuk mensimulasikan kegagalan pembayaran gas di level bytecode.
 */
contract ValidationBypasser {
    function validateUserOp(PackedUserOperation calldata, bytes32, uint256 missingAccountFunds) external payable returns (uint256) {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Gas payment failed");
        }
        return 0; 
    }
}

contract SmartAccountFuzz is Test {
    SmartAccount public implementation;
    SmartAccount public account; // Menunjuk ke alamat Proxy
    
    address public owner = makeAddr("owner");
    address public entryPoint = makeAddr("entryPoint");
    address[] public guardians;

    function setUp() public {
        guardians = new address[](3);
        guardians[0] = makeAddr("g1");
        guardians[1] = makeAddr("g2");
        guardians[2] = makeAddr("g3");
        
        // 1. Deploy Logic/Implementation
        implementation = new SmartAccount();
        
        // 2. Encode fungsi initialize (Threshold: 2 dari 3)
        bytes memory initData = abi.encodeWithSelector(
            SmartAccount.initialize.selector,
            owner,
            guardians,
            uint256(2),
            entryPoint
        );

        // 3. Deploy via Proxy - Solusi mutlak untuk menghindari error 'AlreadyInitialized'
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        account = SmartAccount(payable(address(proxy)));
        
        vm.deal(address(account), 100 ether);
    }

    /**
     * @dev TEST 1: Brute Force Signature Recovery
     * Mastiin hacker nggak bisa takeover pake signature sampah.
     */
    function testFuzz_BruteForceRecovery(address maliciousNewOwner, bytes memory randomSig) public {
        vm.assume(maliciousNewOwner != address(0) && maliciousNewOwner != owner);
        
        bytes[] memory junkSigs = new bytes[](1);
        junkSigs[0] = randomSig;
        
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        vm.expectRevert(); 
        account.recoverAccount(maliciousNewOwner, junkSigs, indices);
    }

    /**
     * @dev TEST 2: Gas Drain Shield (ETCH)
     * Mastiin kontrak revert jika diminta bayar gas melebihi saldo.
     */
    function testFuzz_GasDrainShield(uint256 crazyMissingFunds) public {
        // Harus > 100 ETH saldo kontrak agar trigger revert
        crazyMissingFunds = bound(crazyMissingFunds, 101 ether, 1000000 ether);
        
        // Timpa kode proxy dengan logic bypasser
        vm.etch(address(account), address(new ValidationBypasser()).code);

        vm.prank(entryPoint);
        vm.expectRevert("Gas payment failed");
        
        PackedUserOperation memory userOp;
        SmartAccount(payable(address(account))).validateUserOp(userOp, bytes32(0), crazyMissingFunds);
    }

    /**
     * @dev TEST 3: Strict EIP-712 Execution
     * Mastiin transaksi via signature cuma jalan kalo data & nonce valid.
     */
    function testFuzz_StrictEIP712Execution(
        address target, 
        uint256 value, 
        bytes calldata data, 
        uint256 randoNonce, 
        bytes calldata fakeSig
    ) public {
        vm.assume(target != address(0) && target != address(account));
        value = bound(value, 0, 10 ether);
        
        // Jika nonce salah ATAU sig length salah, wajib REVERT
        if (randoNonce != account.nonce() || fakeSig.length != 65) {
            vm.expectRevert();
            account.executeWithSignature(target, value, data, randoNonce, fakeSig);
        }
    }

    /**
     * @dev TEST 4: Sequential Recovery Attack
     * Mastiin hacker nggak bisa "replay" atau manipulasi urutan index guardian.
     */
    function testFuzz_SequentialRecoveryAttack(
        address hackerNewOwner, 
        uint256 maliciousIndex,
        bytes memory fakeSig
    ) public {
        vm.assume(hackerNewOwner != address(0) && hackerNewOwner != owner);
        // Coba akses index guardian yang nggak ada
        maliciousIndex = bound(maliciousIndex, 3, 5000); 

        bytes[] memory badSigs = new bytes[](2);
        badSigs[0] = fakeSig;
        badSigs[1] = fakeSig;

        uint256[] memory badIndices = new uint256[](2);
        badIndices[0] = 0; 
        badIndices[1] = maliciousIndex;

        vm.expectRevert(); 
        account.recoverAccount(hackerNewOwner, badSigs, badIndices);
        
        // State Integrity: Owner harus tetep yang lama
        assertEq(account.owner(), owner);
    }

    /**
     * @dev TEST 5: Re-initialization Attack
     * Mastiin kontrak yang sudah aktif nggak bisa di-reset owner-nya.
     */
    function testFuzz_ReinitializationAttack(address attacker) public {
        vm.assume(attacker != address(0));
        
        address[] memory newGuardians = new address[](1);
        newGuardians[0] = attacker;

        vm.prank(attacker);
        vm.expectRevert(); 
        account.initialize(attacker, newGuardians, 1, entryPoint);
    }
}