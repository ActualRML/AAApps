// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {SmartAccount} from "../../src/smart-account/SmartAccount.sol";
import {TokenPaymaster} from "../../src/paymaster/TokenPaymaster.sol";
import {MockToken} from "../../src/token/MockToken.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";

contract IntegratedFuzz is Test {
    SmartAccount a; 
    TokenPaymaster p; 
    MockToken t;
    
    address ep = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address or = address(0x123); 
    address ow = address(0xA);
    address user;

    function setUp() public {
        // Sinkronkan user dengan private key 1 agar vm.sign di test recovery valid
        user = vm.addr(1);

        vm.etch(ep, hex"6080604052600080fdfea2646970667358221220");
        vm.mockCall(ep, abi.encodeWithSignature("depositTo(address)"), "");
        
        t = new MockToken("GasToken", "GT", 18, address(this));

        address[] memory guardians = new address[](1);
        guardians[0] = user;

        // Constructor: (owner, guardians, entryPoint)
        a = new SmartAccount(user, guardians, ep); 
        p = new TokenPaymaster(address(t), ep, or, ow);

        vm.deal(address(p), 100 ether);
        p.deposit{value: 50 ether}();
    }

    /**
     * @dev STRICT FUZZ TEST
     * Menguji kalkulasi biaya gas secara matematis dengan input acak (Fuzzing).
     */
    function testFuzz_FlowStrict(int256 pr, uint256 mk, uint256 gas) public {
        // 1. BOUNDING (Strict)
        pr = bound(pr, 1e6, 1e15); 
        mk = bound(mk, 101, 1000); 
        gas = bound(gas, 21_000, 5_000_000); 

        // 2. MOCK ORACLE
        vm.mockCall(or, abi.encodeWithSignature("latestRoundData()"), 
            abi.encode(uint80(1), pr, uint256(1), uint256(1), uint80(1)));

        vm.prank(ow); 
        p.setGasMarkup(mk);
        
        t.mint(address(a), 1e36); 
        vm.prank(address(a)); 
        t.approve(address(p), type(uint256).max);

        PackedUserOperation memory op;
        op.sender = address(a);
        op.paymasterAndData = abi.encodePacked(address(p));

        // 3. EXECUTION
        vm.startPrank(ep);
        uint256 balanceBefore = t.balanceOf(address(a));
        uint256 pBalanceBefore = t.balanceOf(address(p));
        
        (bytes memory ctx, ) = p.validatePaymasterUserOp(op, bytes32(0), gas + 1e15);
        p.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, gas, 0);
        
        uint256 balanceAfter = t.balanceOf(address(a));
        uint256 pBalanceAfter = t.balanceOf(address(p));
        vm.stopPrank();

        // 4. ASSERTIONS (Presisi Matematika)
        uint256 expectedDebt = (gas * uint256(pr) * mk) / (1e8 * 100); 
        
        assertApproxEqAbs(balanceBefore - balanceAfter, expectedDebt, 100, "Math mismatch");
        assertEq(pBalanceAfter - pBalanceBefore, balanceBefore - balanceAfter, "Sync mismatch");
    }

    /**
     * @dev UNIT TEST: Saldo Tidak Cukup
     */
    function test_RevertIfInsufficientBalance() public {
    // 1. Masuk sebagai 'a' (SmartAccount)
    vm.prank(address(a)); 
    
    // 2. Bakar semua token yang dimiliki 'a'
    // Cukup 1 argumen: jumlahnya saja
    t.burn(t.balanceOf(address(a))); 
    
    PackedUserOperation memory op;
    op.sender = address(a);
    op.paymasterAndData = abi.encodePacked(address(p));

    vm.prank(ep);
    vm.expectRevert(); 
    p.validatePaymasterUserOp(op, bytes32(0), 1e18);
}

    /**
     * @dev LOGIC TEST: Social Recovery
     */
    function test_SocialRecovery() public {
    address newOwner = address(0x99);
    bytes[] memory sigs = new bytes[](1);
    
    // 1. Buat raw hash-nya
    bytes32 rawHash = keccak256(abi.encodePacked(newOwner, address(a)));
    
    // 2. BUNGKUS hash-nya sesuai standar Ethereum (EIP-191)
    // Ini yang bikin address hasil ecrecover jadi sinkron
    bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
    );
    
    // 3. Sign hash yang sudah dibungkus
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethSignedHash); 
    sigs[0] = abi.encodePacked(r, s, v);

    // 4. Eksekusi recovery
    a.recoverAccount(newOwner, sigs);
    
    assertEq(a.owner(), newOwner, "Recovery failed: Owner not updated");
}

    /**
     * @dev SECURITY TEST: Access Control (Owner-only)
     */
    function test_RevertIfNonOwnerSetsMarkup() public {
        address hacker = address(0xDEAD);
        vm.prank(hacker);
        
        // Fix Error 6160: Gunakan tanpa argumen
        vm.expectRevert(); 
        p.setGasMarkup(1000);
    }
}