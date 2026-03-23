// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {TokenFactory} from "../../src/token/TokenFactory.sol"; // Sesuaikan path-nya
import {MockToken} from "../../src/token/MockToken.sol";

contract TokenFactoryTest is Test {
    TokenFactory factory;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        factory = new TokenFactory();
    }

    // ✅ Test deploy 1 token (mETH)
    function testCreateMockETH() public {
        address tokenAddr = factory.createToken(
            "Mock ETH",
            "mETH",
            1_000_000 ether
        );

        MockToken token = MockToken(tokenAddr);

        // Cek balance creator (address(this) karena tidak pakai prank)
        assertEq(token.balanceOf(address(this)), 1_000_000 ether);

        // Cek symbol
        assertEq(token.symbol(), "mETH");
    }

    // ✅ Test deploy multiple tokens
    function testCreateMultipleTokens() public {
        factory.createToken("Mock USD", "mUSD", 1_000_000 ether);
        factory.createToken("Mock ETH", "mETH", 1_000_000 ether);
        factory.createToken("Mock IDR", "mIDR", 1_000_000 ether);

        address[] memory tokens = factory.getAllTokens();

        assertEq(tokens.length, 3);
    }

    // ✅ Test duplicate symbol (harus gagal)
    function test_RevertIf_DuplicateSymbol() public {
        factory.createToken("Mock ETH", "mETH", 1_000_000 ether);

        // FIX: Sesuaikan pesan revert dengan yang ada di TokenFactory.sol
        vm.expectRevert("Symbol already exists");
        factory.createToken("Mock ETH 2", "mETH", 1_000_000 ether);
    }

    // ✅ Test mint ke user lain (Memastikan Ownership Benar)
    function testMintToAnotherUser() public {
        address tokenAddr = factory.createToken(
            "Mock ETH",
            "mETH",
            1_000_000 ether
        );

        MockToken token = MockToken(tokenAddr);

        // Karena address(this) adalah owner, dia berhak nge-mint
        token.mint(user1, 100 ether);

        assertEq(token.balanceOf(user1), 100 ether);
    }

    // ✅ Test user lain deploy token melalui Factory
    function testDifferentUserCreatesToken() public {
        vm.prank(user1);
        address tokenAddr = factory.createToken(
            "Mock BTC",
            "mBTC",
            500_000 ether
        );

        MockToken token = MockToken(tokenAddr);

        // Balance harus masuk ke user1 (karena msg.sender di factory adalah user1)
        assertEq(token.balanceOf(user1), 500_000 ether);
        // Owner token harus user1
        assertEq(token.owner(), user1);
    }

    /**
     * @notice Test Case Sensitivity: Memastikan mETH dan METH dianggap berbeda.
     * (Penting biar lo tau perilaku factory lo kalau ada user iseng)
     */
    function test_DifferentCaseSymbols() public {
        factory.createToken("Mock ETH", "mETH", 1000 ether);
        
        // Ini harusnya BERHASIL karena hash-nya beda (case sensitive)
        address token2 = factory.createToken("Mock ETH", "METH", 1000 ether);
        
        assertTrue(token2 != address(0));
        assertEq(factory.getTokensCount(), 2);
    }

    /**
     * @notice Test Empty String: Apa yang terjadi kalau simbolnya kosong?
     */
    function test_CreateEmptySymbol() public {
        // Secara teknis Solidity ngebolehin, tapi apa lo mau?
        // Kalau lo mau blokir, tambahin require(bytes(symbol).length > 0) di src
        address emptyToken = factory.createToken("Empty", "", 1000 ether);
        assertTrue(emptyToken != address(0));
    }
}