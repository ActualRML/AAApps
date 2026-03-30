// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/paymaster/TokenPaymaster.sol";
import "../../src/token/MockToken.sol";
import "./mocks/MockV3Aggregator.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TokenPaymasterTest is Test {
    TokenPaymaster paymaster;
    TokenPaymaster implementation; // Logic contract
    MockToken token;
    MockV3Aggregator priceFeed;
    
    address entryPoint = makeAddr("entryPoint"); 
    address user = makeAddr("user");
    address stranger = makeAddr("stranger");

    function setUp() public {
        // 1. Deploy Mocks
        token = new MockToken("GasToken", "GTK", 1000e18, address(this));
        priceFeed = new MockV3Aggregator(8, 2000e8); 
        
        // 2. Deploy Implementation (Logic)
        implementation = new TokenPaymaster();
        
        // 3. Prepare Init Data
        bytes memory initData = abi.encodeWithSelector(
            TokenPaymaster.initialize.selector,
            address(token),
            entryPoint,
            address(priceFeed),
            address(this)
        );

        // 4. Deploy Proxy & Cast with Payable
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        
        // FIX: Tambahkan payable agar compiler nggak protes
        paymaster = TokenPaymaster(payable(address(proxy))); 
        
        // 5. Setup EntryPoint Mock
        vm.deal(entryPoint, 10 ether);
        vm.mockCall(
            entryPoint,
            abi.encodeWithSignature("depositTo(address)", address(paymaster)),
            abi.encode()
        );

        // 6. Deposit ETH ke EntryPoint
        vm.deal(address(this), 10 ether);
        paymaster.deposit{value: 5 ether}();
    }

    // ============ BASIC LOGIC TESTS ============

    function test_GetLatestPrice() public view {
        uint256 price = paymaster.getLatestPrice();
        assertEq(price, 2000e18); 
    }

    // ============ SECURITY & ACCESS CONTROL ============

    function test_Revert_UnauthorizedCalls() public {
        PackedUserOperation memory userOp = _createDummyUserOp(user);

        vm.prank(stranger);
        vm.expectRevert(); 
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1e15);

        vm.prank(stranger);
        vm.expectRevert();
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, "", 0, 0);
    }

    // ============ CORE FLOW TESTS ============

    function test_ValidatePaymasterUserOp_Full() public {
        uint256 userInitialBalance = 100e18;
        token.transfer(user, userInitialBalance);
        
        vm.prank(user);
        token.approve(address(paymaster), type(uint256).max);

        PackedUserOperation memory userOp = _createDummyUserOp(user);
        uint256 maxCost = 1e15; // 0.001 ETH

        vm.prank(entryPoint);
        (bytes memory context, uint256 validationData) = paymaster.validatePaymasterUserOp(
            userOp, 
            bytes32(0), 
            maxCost
        );
        
        uint256 expectedPreCharge = 2.2e18; // 0.001 * 2000 * 1.1

        assertEq(token.balanceOf(address(paymaster)), expectedPreCharge);
        assertEq(token.balanceOf(user), userInitialBalance - expectedPreCharge);
        assertEq(validationData, 0); 
        
        (address decodedUser, uint256 preCharged) = abi.decode(context, (address, uint256));
        assertEq(decodedUser, user);
        assertEq(preCharged, expectedPreCharge);
    }

    function test_PostOp_WithRefund_PriceChanged() public {
        test_ValidatePaymasterUserOp_Full();
        
        // Harga ETH naik jadi $4000
        priceFeed.updateAnswer(4000e8); 
        
        uint256 preCharged = 2.2e18;
        bytes memory context = abi.encode(user, preCharged);
        uint256 actualGasCost = 0.00025 ether;
        
        vm.prank(entryPoint);
        paymaster.postOp(
            IPaymaster.PostOpMode.opSucceeded,
            context,
            actualGasCost,
            0
        );

        // actualTokenCost = 0.00025 * 4000 * 1.1 = 1.1 GTK
        // refund = 2.2 - 1.1 = 1.1 GTK
        uint256 expectedRefund = 1.1e18;
        uint256 userBalanceAfterPrecharge = 100e18 - 2.2e18;

        assertEq(token.balanceOf(user), userBalanceAfterPrecharge + expectedRefund);
    }

    function _createDummyUserOp(address sender) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(0),
            preVerificationGas: 50000,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: abi.encodePacked("dummy_signature")
        });
    }
}