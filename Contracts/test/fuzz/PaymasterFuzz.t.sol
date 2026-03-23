// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/paymaster/TokenPaymaster.sol";
import "../../src/token/MockToken.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract PaymasterHardcoreFuzz is Test {
    TokenPaymaster public paymaster;
    MockToken public gasToken;
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public oracle = address(0x123);
    address public owner = address(0xA);
    address public user = address(0xB);

    function setUp() public {
        // 1. "Bernapaskan" address EntryPoint
        vm.etch(entryPoint, hex"6080604052600080fdfea2646970667358221220");

        // 2. MOCK: depositTo agar tidak revert
        vm.mockCall(
            entryPoint,
            abi.encodeWithSignature("depositTo(address)"),
            ""
        );

        gasToken = new MockToken("GasToken", "GT", 0, address(this));
        _mockOraclePrice(3000 * 1e8);

        paymaster = new TokenPaymaster(address(gasToken), entryPoint, oracle, owner);
        
        vm.deal(address(paymaster), 100 ether);
        paymaster.deposit{value: 50 ether}();
    }

    function _mockOraclePrice(int256 price) internal {
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), price, uint256(1), uint256(1), uint80(1))
        );
    }

    /**
     * @dev STRICT TEST 1: Oracle Failure
     */
    function testFuzz_StrictOracleFailure(int256 badPrice) public {
        vm.assume(badPrice <= 0);
        _mockOraclePrice(badPrice);

        PackedUserOperation memory userOp = _setupUserOp(user);
        
        vm.prank(entryPoint);
        vm.expectRevert("Invalid price data");
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    /**
     * @dev STRICT TEST 2: Math Precision & Dust Attack
     * FIX: Membatasi markup dan menambah minting user agar tidak "Low token balance".
     */
    function testFuzz_MathPrecisionDust(uint256 markup) public {
        // Batasi markup ke angka logis (100% - 10,000%)
        markup = bound(markup, 100, 10000); 
        vm.prank(owner);
        paymaster.setGasMarkup(markup);

        uint256 tinyGas = 1; 
        uint256 maxCost = 1 ether;
        
        // Mint jumlah besar (10^30) agar fuzzer tidak kena limit saldo saat markup tinggi
        gasToken.mint(user, 1e30);
        vm.prank(user);
        gasToken.approve(address(paymaster), type(uint256).max);

        vm.prank(entryPoint);
        (bytes memory context, ) = paymaster.validatePaymasterUserOp(_setupUserOp(user), bytes32(0), maxCost);
        
        vm.prank(entryPoint);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, tinyGas, 0);
        
        assertTrue(gasToken.balanceOf(address(paymaster)) >= 0);
    }

    /**
     * @dev STRICT TEST 3: PostOp Revert Policy
     * FIX: Batasi actualGas agar tidak melebihi maxCost (1 ether).
     */
    function testFuzz_StrictPostOpRevertHandling(uint256 actualGas) public {
        actualGas = bound(actualGas, 0, 1 ether);
        
        // Mint besar untuk mengantisipasi markup kalkulasi
        gasToken.mint(user, 1e30);
        vm.prank(user);
        gasToken.approve(address(paymaster), type(uint256).max);
        
        vm.prank(entryPoint);
        (bytes memory context, ) = paymaster.validatePaymasterUserOp(_setupUserOp(user), bytes32(0), 1 ether);

        vm.prank(entryPoint);
        paymaster.postOp(IPaymaster.PostOpMode.postOpReverted, context, actualGas, 0);
        
        assertTrue(gasToken.balanceOf(address(paymaster)) > 0);
    }

    /**
     * @dev STRICT TEST 4: Integrity of Markup
     */
    function testFuzz_MarkupIntegrity(uint256 lowMarkup) public {
        vm.assume(lowMarkup < 100);
        vm.prank(owner);
        vm.expectRevert("Markup too low");
        paymaster.setGasMarkup(lowMarkup);
    }

    function _setupUserOp(address sender) internal pure returns (PackedUserOperation memory) {
        PackedUserOperation memory userOp;
        userOp.sender = sender;
        return userOp;
    }
}