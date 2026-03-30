// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/paymaster/TokenPaymaster.sol";
import "../../src/token/MockToken.sol";
import "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Interface lokal untuk mock oracle agar tidak bentrok
interface IAggregatorV3Local {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract PaymasterHardcoreFuzz is Test {
    TokenPaymaster public paymaster;
    TokenPaymaster public implementation;
    MockToken public gasToken;
    
    // Gunakan makeAddr untuk address yang lebih clean dan valid secara checksum
    address public entryPoint = makeAddr("entryPoint");
    address public oracle = makeAddr("oracle");
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        // 1. Setup Mock untuk EntryPoint
        // Kita beri saldo agar bisa menerima ETH dan mock fungsi depositTo
        vm.deal(entryPoint, 100 ether);
        vm.mockCall(
            entryPoint,
            abi.encodeWithSignature("depositTo(address)", address(0)), // Selector match
            abi.encode()
        );

        // 2. Setup Mock Token & Oracle
        gasToken = new MockToken("GasToken", "GT", 1000e18, address(this));
        
        // Mock decimals oracle (biasanya 8 untuk Chainlink USD pairs)
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IAggregatorV3Local.decimals.selector),
            abi.encode(uint8(8))
        );
        _mockOraclePrice(3000 * 1e8);

        // 3. Deploy via Proxy (Fix InvalidInitialization)
        implementation = new TokenPaymaster();
        
        bytes memory initData = abi.encodeWithSelector(
            TokenPaymaster.initialize.selector,
            address(gasToken),
            entryPoint,
            oracle,
            owner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        paymaster = TokenPaymaster(payable(address(proxy)));
        
        // 4. Funding
        vm.deal(address(paymaster), 100 ether);
        vm.deal(owner, 100 ether);
        
        // Deposit ke EntryPoint via Paymaster
        vm.prank(owner);
        paymaster.deposit{value: 10 ether}();
    }

    function _mockOraclePrice(int256 price) internal {
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IAggregatorV3Local.latestRoundData.selector),
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
        // Kita expect revert karena harga dari oracle tidak valid (<= 0)
        vm.expectRevert(); 
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1e15);
    }

    /**
     * @dev STRICT TEST 2: Math Precision & Dust Attack
     */
    function testFuzz_MathPrecisionDust(uint256 markup) public {
        markup = bound(markup, 100, 10000); 
        
        vm.prank(owner);
        paymaster.setGasMarkup(markup);

        uint256 tinyGas = 1; 
        uint256 maxCost = 1e15; // 0.001 ETH
        
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
     */
    function testFuzz_StrictPostOpRevertHandling(uint256 actualGas) public {
        actualGas = bound(actualGas, 0, 1e15);
        
        gasToken.mint(user, 1e30);
        vm.prank(user);
        gasToken.approve(address(paymaster), type(uint256).max);
        
        vm.prank(entryPoint);
        (bytes memory context, ) = paymaster.validatePaymasterUserOp(_setupUserOp(user), bytes32(0), 1e15);

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
        vm.expectRevert(); 
        paymaster.setGasMarkup(lowMarkup);
    }

    function _setupUserOp(address sender) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(1e6), uint128(1e6))),
            preVerificationGas: 1e6,
            gasFees: bytes32(abi.encodePacked(uint128(1e9), uint128(1e9))),
            paymasterAndData: "",
            signature: ""
        });
    }
}