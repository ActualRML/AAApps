// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {TokenPaymaster} from "../../src/paymaster/TokenPaymaster.sol";
import {SmartAccount} from "../../src/smart-account/SmartAccount.sol";
import {MockToken} from "../../src/token/MockToken.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

// Import standar ERC-4337
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract TokenPaymasterTest is Test {
    TokenPaymaster public paymaster;
    SmartAccount public account;
    MockToken public token;
    MockV3Aggregator public oracle;
    
    // Alamat EntryPoint standar ERC-4337 v0.7
    address public entryPointAddr = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public owner;

    function setUp() public {
        owner = makeAddr("owner");

        // --- FIX: "Menghidupkan" EntryPoint di Alamat Standar ---
        EntryPoint realEntryPoint = new EntryPoint();
        vm.etch(entryPointAddr, address(realEntryPoint).code);
        
        // 1. Deploy MockToken (4 argumen)
        token = new MockToken(
            "Gas Token",      
            "GTKN",           
            1000000 ether,    
            address(this)     
        );
        
        // 2. Deploy Oracle ($3000)
        oracle = new MockV3Aggregator(8, 3000 * 1e8);
        
        // 3. Deploy Paymaster
        paymaster = new TokenPaymaster(
            address(token),
            entryPointAddr,
            address(oracle),
            address(this)
        );

        // 4. Setup Smart Account
        address[] memory guardians = new address[](1);
        guardians[0] = makeAddr("guardian");
        account = new SmartAccount(owner, guardians, entryPointAddr);

        // 5. Kasih Token & Approve
        token.mint(address(account), 1000 ether);
        vm.prank(address(account));
        token.approve(address(paymaster), type(uint256).max);

        // 6. Deposit ETH ke EntryPoint
        vm.deal(address(this), 10 ether);
        paymaster.deposit{value: 5 ether}();
    }

    function test_PostOp_ChargesCorrectTokenAmount() public {
        uint256 initialUserToken = token.balanceOf(address(account));
        uint256 actualGasCost = 0.001 ether; 

        bytes memory context = abi.encode(address(account));
        
        vm.prank(entryPointAddr);
        paymaster.postOp(
            IPaymaster.PostOpMode.opSucceeded, 
            context, 
            actualGasCost, 
            0
        );

        uint256 finalUserToken = token.balanceOf(address(account));
        assertEq(finalUserToken, initialUserToken - 3.3 ether);
    }

    function test_Validate_FailsIfNoToken() public {
        address poorUser = makeAddr("poorUser");
        
        PackedUserOperation memory op;
        op.sender = poorUser;
        op.nonce = 0;
        op.callData = "";
        op.accountGasLimits = bytes32(0);
        op.preVerificationGas = 0;
        op.gasFees = bytes32(0);

        vm.prank(entryPointAddr);
        vm.expectRevert("Low token balance");
        paymaster.validatePaymasterUserOp(op, bytes32(0), 1 ether);
    }

    /**
     * @notice Fix: Kasih token banyak agar cek balance lolos, tapi allowance tetap 0.
     */
    function test_Validate_FailsIfNoAllowance() public {
        address richUser = makeAddr("richUser");
        token.mint(richUser, 1000000 ether); // Pastikan balance lolos
        
        PackedUserOperation memory op;
        op.sender = richUser;

        vm.prank(entryPointAddr);
        // Tergantung urutan require di src/, ganti ekspektasi jika perlu
        vm.expectRevert("Low token allowance"); 
        paymaster.validatePaymasterUserOp(op, bytes32(0), 1 ether);
    }

    function test_PostOp_NoChargeOnRevert() public {
        uint256 initialBalance = token.balanceOf(address(account));
        bytes memory context = abi.encode(address(account));

        vm.prank(entryPointAddr);
        paymaster.postOp(
            IPaymaster.PostOpMode.postOpReverted, 
            context, 
            0.001 ether, 
            0
        );

        assertEq(token.balanceOf(address(account)), initialBalance, "Should not charge on revert");
    }

    function test_SetMarkup_OnlyOwner() public {
        address attacker = makeAddr("attacker");
        
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        paymaster.setGasMarkup(500);

        paymaster.setGasMarkup(150);
        assertEq(paymaster.gasMarkup(), 150);
    }
    
    /**
     * @notice Fix: Kontrak test sekarang bisa menerima ETH dari withdrawETH.
     */
    function test_WithdrawETH_OnlyOwner() public {
        uint256 initialOwnerBalance = address(this).balance;
        uint256 amount = 1 ether;
        
        paymaster.withdrawETH(payable(address(this)), amount);
        
        assertEq(address(this).balance, initialOwnerBalance + amount);
    }

    // Fungsi wajib agar kontrak test bisa menerima ETH
    receive() external payable {}

    /**
     * @notice Test Oracle Integrasi: Mastiin kalau harga di Oracle berubah, 
     * kalkulasi token di Paymaster juga ikut berubah (Dinamis).
     */
    function test_Oracle_PriceUpdate_ImpactsCharge() public {
        // 1. Set harga awal $3000 (8 desimal)
        oracle.updateAnswer(3000 * 1e8);
        uint256 priceAt3000 = paymaster.getLatestPrice(); 
        
        // 2. Update harga jadi $4000 (8 desimal)
        oracle.updateAnswer(4000 * 1e8);
        uint256 priceAt4000 = paymaster.getLatestPrice();
        
        // 3. FIX: Bandingkan dengan 18 desimal (karena Paymaster lo menormalkan harganya)
        // 4000 * 1e8 (oracle) * 1e10 (normalization) = 4000 * 1e18
        assertEq(priceAt4000, 4000 * 1e18, "Price should be normalized to 18 decimals");
        assertTrue(priceAt4000 > priceAt3000, "Price should increase");

        // 4. Test PostOp dengan harga baru ($4000)
        uint256 actualGasCost = 0.001 ether; 
        bytes memory context = abi.encode(address(account));
        uint256 initialUserToken = token.balanceOf(address(account));

        vm.prank(entryPointAddr);
        paymaster.postOp(
            IPaymaster.PostOpMode.opSucceeded, 
            context, 
            actualGasCost, 
            0
        );

        uint256 finalUserToken = token.balanceOf(address(account));
        
        // Kalkulasi: (ActualGas * Price * Markup) / 100
        // (0.001 ETH * 4000 USD * 110) / 100 = 4.4 Token
        assertEq(finalUserToken, initialUserToken - 4.4 ether);
    }
}