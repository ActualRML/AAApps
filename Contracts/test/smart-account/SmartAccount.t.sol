// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/smart-account/SmartAccount.sol";
import "../../src/common/Errors.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SmartAccountTest is Test {
    SmartAccount public account;
    address public owner;
    uint256 public ownerKey;
    address public guardian;
    uint256 public guardianKey;
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    bytes32 public constant EXECUTE_TYPEHASH = keccak256("Execute(address target,uint256 value,bytes data,uint256 nonce)");

    function setUp() public {
        vm.chainId(1); 
        (owner, ownerKey) = makeAddrAndKey("owner");
        (guardian, guardianKey) = makeAddrAndKey("guardian");
        
        address[] memory guardians = new address[](1);
        guardians[0] = guardian;

        SmartAccount implementation = new SmartAccount();
        bytes memory initData = abi.encodeWithSelector(
            SmartAccount.initialize.selector,
            owner,
            guardians,
            1,
            entryPoint
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        account = SmartAccount(payable(address(proxy)));
        
        vm.deal(address(account), 10 ether);
    }

    // ============ TEST EXECUTE WITH SIGNATURE ============
    
    function test_ExecuteWithSignature() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory data = ""; 
        uint256 _nonce = account.nonce();

        // SAMA PERSIS dengan contract executeWithSignature:
        // bytes32 structHash = keccak256(abi.encode(_EXECUTE_TYPEHASH, target, value, keccak256(data), _nonce));
        // bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
        
        bytes32 dataHash = keccak256(data);
        bytes32 structHash = keccak256(abi.encode(EXECUTE_TYPEHASH, target, value, dataHash, _nonce));
        
        // INI YANG PENTING: Contract pakai cara manual, bukan toTypedDataHash
        bytes32 domainSep = account.domainSeparator();
        bytes32 finalHash = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));

        console.log("=== EXECUTE HASH COMPARISON ===");
        console.log("Test FinalHash:", uint256(finalHash));
        
        // Sign dengan owner key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, finalHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        account.executeWithSignature(target, value, data, _nonce, signature);
        assertEq(target.balance, 1 ether);
    }

    // ============ TEST RECOVERY ============

    function test_RecoverySuccess() public {
        address newOwner = makeAddr("successOwner");
        
        // SAMA PERSIS dengan contract recoverAccount:
        // bytes32 messageHash = keccak256(abi.encodePacked(
        //     "\x19Ethereum Signed Message:\n32",
        //     keccak256(abi.encodePacked(_newOwner, address(this), block.chainid))
        // ));
        
        bytes32 innerHash = keccak256(abi.encodePacked(newOwner, address(account), block.chainid));
        
        // Contract pakai cara manual dengan string length
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            innerHash
        ));

        console.log("=== RECOVERY HASH COMPARISON ===");
        console.log("Test MessageHash:", uint256(messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardianKey, messageHash);
        
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = abi.encodePacked(r, s, v);
        
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        account.recoverAccount(newOwner, sigs, indices);
        assertEq(account.owner(), newOwner);
    }

    // ============ TEST VALIDATE USER OP ============

    function test_ValidateUserOp_Success() public {
        // userOpHash dari EntryPoint adalah bytes32 yang sudah final
        // Tapi contract menggunakan SignatureChecker.isValidSignatureNow
        
        // Coba dengan Ethereum Signed Message format (karena mungkin EntryPoint pakai ini)
        bytes32 userOpHash = keccak256("userOpHash");
        
        // Coba sign dengan toEthSignedMessageHash
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        
        console.log("=== VALIDATE USEROP HASH COMPARISON ===");
        console.log("Raw UserOpHash:", uint256(userOpHash));
        console.log("EthSignedHash:", uint256(ethSignedHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, ethSignedHash);
        
        PackedUserOperation memory op;
        op.signature = abi.encodePacked(r, s, v);

        vm.prank(entryPoint);
        uint256 validationData = account.validateUserOp(op, userOpHash, 0);
        
        if (validationData != 0) {
            // Coba dengan raw hash
            (v, r, s) = vm.sign(ownerKey, userOpHash);
            op.signature = abi.encodePacked(r, s, v);
            
            vm.prank(entryPoint);
            validationData = account.validateUserOp(op, userOpHash, 0);
            
            console.log("With raw hash, ValidationData:", validationData);
        }
        
        assertEq(validationData, 0); 
    }

    // ============ HELPER TESTS ============

    function test_HashComparison() public {
        // Debug: Bandingkan hash calculation
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory data = "";
        uint256 _nonce = 0;

        bytes32 dataHash = keccak256(data);
        bytes32 structHash = keccak256(abi.encode(EXECUTE_TYPEHASH, target, value, dataHash, _nonce));
        bytes32 domainSep = account.domainSeparator();

        // Cara test
        bytes32 testHash1 = keccak256(abi.encodePacked(bytes2(0x1901), domainSep, structHash));
        bytes32 testHash2 = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        bytes32 testHash3 = MessageHashUtils.toTypedDataHash(domainSep, structHash);

        console.log("=== HASH COMPARISON ===");
        console.log("TestHash (bytes2):", uint256(testHash1));
        console.log("TestHash (string):", uint256(testHash2));
        console.log("TestHash (OZ):", uint256(testHash3));
        
        // Coba recover
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, testHash2);
        address recovered = ECDSA.recover(testHash2, v, r, s);
        console.log("Recovered with testHash2:", recovered);
        console.log("Expected owner:", owner);
    }

    function test_RecoveryHashComparison() public {
        address newOwner = makeAddr("successOwner");
        
        bytes32 innerHash = keccak256(abi.encodePacked(newOwner, address(account), block.chainid));
        
        // Cara contract
        bytes32 contractStyle = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            innerHash
        ));
        
        // Cara OZ
        bytes32 ozStyle = MessageHashUtils.toEthSignedMessageHash(innerHash);
        
        console.log("=== RECOVERY HASH COMPARISON ===");
        console.log("Contract style:", uint256(contractStyle));
        console.log("OZ style:", uint256(ozStyle));
        console.log("Match:", contractStyle == ozStyle);
    }

    function test_Revert_InvalidNonce() public {
        vm.expectRevert(Errors.InvalidNonce.selector);
        account.executeWithSignature(address(0), 0, "", 999, "");
    }

    function test_Revert_Reentrancy() public {
        MaliciousReentrant attacker = new MaliciousReentrant(payable(address(account)));
        vm.prank(owner);
        vm.expectRevert(); 
        account.execute(address(attacker), 0.1 ether, "");
    }

    function test_Security_SignatureTampering() public {
        bytes32 userOpHash = keccak256("CriticalTransaction");
        
        // Coba dengan eth signed message hash
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, ethSignedHash);
        
        bytes memory tamperedSig = abi.encodePacked(r, s, v);
        tamperedSig[tamperedSig.length - 1] = tamperedSig[tamperedSig.length - 1] ^ 0x01; 

        PackedUserOperation memory op;
        op.signature = tamperedSig;

        vm.prank(entryPoint);
        uint256 result = account.validateUserOp(op, userOpHash, 0);
        assertEq(result, 1); 
    }
}

contract MaliciousReentrant {
    SmartAccount public account;
    constructor(address payable _account) { account = SmartAccount(_account); }
    receive() external payable {
        account.execute(address(0), 0, "");
    }
}