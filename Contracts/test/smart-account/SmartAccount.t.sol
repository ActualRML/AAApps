// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccount.sol";
// TAMBAHAN IMPORT: Supaya mengenali tipe data UserOp dan fungsi ECDSA
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "../../src/libraries/ECDSA.sol";

/**
 * @title MaliciousReentrant
 * @dev Kontrak buatan untuk ngetes proteksi reentrancy.
 */
contract MaliciousReentrant {
    SmartAccount public account;
    
    constructor(address payable _account) {
        account = SmartAccount(_account);
    }

    receive() external payable {
        account.execute(address(0), 0, "");
    }
}

contract SmartAccountTest is Test {
    SmartAccount public account;
    address public owner;
    uint256 public ownerKey;
    address public guardian;
    uint256 public guardianKey;
    
    // FIX: Deklarasi entryPointAddr agar tidak error di test_Security_SignatureTampering
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public entryPointAddr = entryPoint; 

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        (guardian, guardianKey) = makeAddrAndKey("guardian");
        
        address[] memory guardians = new address[](1);
        guardians[0] = guardian;

        vm.chainId(1); 

        account = new SmartAccount(owner, guardians, entryPoint);
        vm.deal(address(account), 10 ether);
    }

    // --- EIP-712 EXECUTION ---
    function test_ExecuteWithSignature() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory data = ""; 
        uint256 currentNonce = account.nonce();

        bytes32 domainSeparator = account.getDomainSeparator();
        bytes32 EXECUTE_TYPEHASH = keccak256("Execute(address target,uint256 value,bytes data,uint256 nonce)");

        bytes32 structHash = keccak256(
            abi.encode(EXECUTE_TYPEHASH, target, value, keccak256(data), currentNonce)
        );
        
        bytes32 eip712Hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        bytes32 finalHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", eip712Hash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, finalHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        account.executeWithSignature(target, value, data, currentNonce, signature);
        assertEq(target.balance, 1 ether);
    }

    // --- NONCE VALIDATION ---
    function test_Revert_InvalidNonce() public {
        address target = makeAddr("target");
        uint256 wrongNonce = 99; 
        
        bytes32 domainSeparator = account.getDomainSeparator();
        bytes32 EXECUTE_TYPEHASH = keccak256("Execute(address target,uint256 value,bytes data,uint256 nonce)");
        
        bytes32 structHash = keccak256(abi.encode(EXECUTE_TYPEHASH, target, 0, keccak256(""), wrongNonce));
        bytes32 eip712Hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        bytes32 finalHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", eip712Hash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, finalHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert("Invalid nonce");
        account.executeWithSignature(target, 0, "", wrongNonce, sig);
    }

    // --- SOCIAL RECOVERY ---
    function test_RecoverySuccess() public {
        address newOwner = makeAddr("successOwner");
        bytes32 messageHash = keccak256(abi.encodePacked(newOwner, address(account)));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardianKey, ethSignedHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes[] memory sigs = new bytes[](1);
        sigs[0] = sig;

        account.recoverAccount(newOwner, sigs);
        assertEq(account.owner(), newOwner);
    }

    function test_Revert_RecoveryDuplicateSigner() public {
        address newOwner = makeAddr("newOwnerFinal");
        bytes32 messageHash = keccak256(abi.encodePacked(newOwner, address(account)));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardianKey, ethSignedHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = sig;
        sigs[1] = sig; 

        vm.expectRevert("Duplicate/Unordered signer");
        account.recoverAccount(newOwner, sigs);
    }

    // --- BATCH & GAS ---
    function test_ExecuteBatch() public {
        address[] memory targets = new address[](2);
        targets[0] = makeAddr("a");
        targets[1] = makeAddr("b");
        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 1 ether;
        bytes[] memory datas = new bytes[](2);
        datas[0] = "";
        datas[1] = "";

        vm.prank(owner);
        account.executeBatch(targets, values, datas);
        assertEq(targets[0].balance, 1 ether);
        assertEq(targets[1].balance, 1 ether);
    }

    // --- ERC-4337 COMPLIANCE ---
    function test_ValidateUserOp_Success() public {
        PackedUserOperation memory op;
        bytes32 userOpHash = keccak256("userOpHash");
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, ethSignedHash);
        op.signature = abi.encodePacked(r, s, v);

        vm.prank(entryPoint);
        assertEq(account.validateUserOp(op, userOpHash, 0), 0);
    }

    function test_Revert_ValidateUserOp_NotEntryPoint() public {
        PackedUserOperation memory op;
        bytes32 hash = keccak256("test");
        vm.prank(makeAddr("stranger"));
        
        vm.expectRevert("Not EntryPoint");
        account.validateUserOp(op, hash, 0);
    }

    // --- SECURITY: REENTRANCY ---
    function test_Revert_Reentrancy() public {
        MaliciousReentrant attacker = new MaliciousReentrant(payable(address(account)));
        vm.deal(address(account), 1 ether);

        vm.prank(owner);
        vm.expectRevert(SmartAccount.Reentrancy.selector); 
        account.execute(address(attacker), 0.1 ether, "");
    }

    /**
     * @notice STRESS TEST: Memastikan validasi signature sangat ketat.
     */
    function test_Security_SignatureTampering() public {
        bytes32 messageHash = keccak256("Transaksi Rahasia");
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);

        uint256 ownerPrivateKey = 0xA11CE; 
        address actualOwner = vm.addr(ownerPrivateKey);
        
        address[] memory emptyGuardians = new address[](0);
        SmartAccount secureAccount = new SmartAccount(actualOwner, emptyGuardians, entryPointAddr);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        bytes memory validSignature = abi.encodePacked(r, s, v);

        // --- VALIDASI POSITIF ---
        // FIX: Harus menyamar jadi EntryPoint dulu
        vm.prank(entryPointAddr); 
        uint256 validationData = secureAccount.validateUserOp(
            _createEmptyUserOp(validSignature), 
            messageHash, 
            0
        );
        assertEq(validationData, 0, "Signature asli harusnya valid!");

        // --- VALIDASI NEGATIF ---
        bytes memory tamperedSignature = validSignature;
        tamperedSignature[0] = tamperedSignature[0] ^ 0x01; 

        // FIX: Harus menyamar jadi EntryPoint lagi (prank cuma berlaku buat 1 call berikutnya)
        vm.prank(entryPointAddr);
        uint256 invalidData = secureAccount.validateUserOp(
            _createEmptyUserOp(tamperedSignature), 
            messageHash, 
            0
        );
        
        assertEq(invalidData, 1, "Hacker masuk! Signature rusak harusnya ditolak.");
    }

    function _createEmptyUserOp(bytes memory sig) internal pure returns (PackedUserOperation memory) {
        PackedUserOperation memory op;
        op.signature = sig;
        return op;
    }
}