// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SmartAccount} from "../../src/smart-account/SmartAccount.sol";
import {TokenPaymaster} from "../../src/paymaster/TokenPaymaster.sol";
import {MockToken} from "../../src/token/MockToken.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Interface untuk mock oracle
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

contract IntegratedFuzz is Test {
    SmartAccount public a; 
    TokenPaymaster public p; 
    MockToken public t;
    
    address ep = makeAddr("entryPoint");  // GANTI: pakai makeAddr bukan constant
    address oracle = makeAddr("oracle"); 
    address ownerPM = makeAddr("owner_paymaster");
    
    address user;
    uint256 userKey;

    function setUp() public {
        
        vm.chainId(1);
        
        (user, userKey) = makeAddrAndKey("user_guardian");
        
        vm.deal(ep, 100 ether);
        vm.mockCall(
            ep,
            abi.encodeWithSignature("depositTo(address)"),
            abi.encode()  
        );
        
        vm.mockCall(
            ep,
            abi.encodeWithSignature("getDepositInfo(address)"),
            abi.encode(uint112(50 ether), uint32(0), uint32(0), uint64(0))
        );

        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IAggregatorV3Local.decimals.selector),
            abi.encode(uint8(8))
        );
        _mockOraclePrice(3000 * 1e8);  

        t = new MockToken("GasToken", "GT", 1000e18, address(this));

        SmartAccount aImpl = new SmartAccount();
        address[] memory guardians = new address[](1);
        guardians[0] = user;
        
        bytes memory aInitData = abi.encodeWithSelector(
            SmartAccount.initialize.selector,
            user,           
            guardians,      
            uint256(1),     
            ep              
        );

        ERC1967Proxy aProxy = new ERC1967Proxy(address(aImpl), aInitData);
        a = SmartAccount(payable(address(aProxy)));
  
        TokenPaymaster pImpl = new TokenPaymaster();
        
        bytes memory pInitData = abi.encodeWithSelector(
            TokenPaymaster.initialize.selector,
            address(t),     
            ep,             
            oracle,         
            ownerPM         
        );

        ERC1967Proxy pProxy = new ERC1967Proxy(address(pImpl), pInitData);
        p = TokenPaymaster(payable(address(pProxy)));
        vm.deal(address(p), 100 ether);
        vm.deal(ownerPM, 100 ether);
        
        vm.prank(ownerPM);
        p.deposit{value: 10 ether}();

        t.mint(address(a), 1e36);
    }

    function _mockOraclePrice(int256 price) internal {
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(IAggregatorV3Local.latestRoundData.selector),
            abi.encode(uint80(1), price, uint256(1), uint256(1), uint80(1))
        );
    }

    function testFuzz_FlowStrict(int256 pr, uint256 mk, uint256 gasLimit) public {
        pr = bound(pr, 1e6, 1e15); 
        mk = bound(mk, 101, 1000); 
        gasLimit = bound(gasLimit, 100_000, 2_000_000); 

        _mockOraclePrice(pr);

        vm.prank(ownerPM); 
        p.setGasMarkup(mk);
        
        vm.prank(address(a)); 
        t.approve(address(p), type(uint256).max);

        PackedUserOperation memory op;
        op.sender = address(a);
        op.paymasterAndData = abi.encodePacked(address(p));
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(gasLimit), uint128(gasLimit)));
        op.preVerificationGas = 50_000;

        vm.startPrank(ep);
        uint256 bBefore = t.balanceOf(address(a));
        
        (bytes memory ctx, ) = p.validatePaymasterUserOp(op, bytes32(0), gasLimit);
        p.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, gasLimit, 0);
        vm.stopPrank();

        uint256 actualPaid = bBefore - t.balanceOf(address(a));
        uint256 expected = (gasLimit * uint256(pr) * mk) / (1e8 * 100); 
        
        assertApproxEqAbs(actualPaid, expected, 1000, "Math mismatch");
    }

    function test_SocialRecovery() public {
        address newOwner = makeAddr("new_owner");
        bytes[] memory sigs = new bytes[](1);
        bytes32 rawHash = keccak256(abi.encodePacked(newOwner, address(a), block.chainid));
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, ethSignedHash); 
        sigs[0] = abi.encodePacked(r, s, v);

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        a.recoverAccount(newOwner, sigs, indices);
        assertEq(a.owner(), newOwner);
    }

    function test_RevertIfNonOwnerSetsMarkup() public {
        vm.prank(makeAddr("hacker"));
        vm.expectRevert(); 
        p.setGasMarkup(200);
    }
}