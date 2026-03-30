// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {TokenFactory} from "../../src/token/TokenFactory.sol";
import {MockToken} from "../../src/token/MockToken.sol";

contract TokenFactoryTest is Test {
    TokenFactory factory;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        factory = new TokenFactory();
    }

    // ============ 1. BASIC DEPLOYMENT TESTS ============

    /**
     * @notice Test deploy 1 token dan verifikasi datanya.
     */
    function test_CreateMockETH() public {
        address tokenAddr = factory.createToken("Mock ETH", "mETH", 1_000_000 ether);
        MockToken token = MockToken(tokenAddr);

        assertEq(token.balanceOf(address(this)), 1_000_000 ether);
        assertEq(token.symbol(), "mETH");
        assertEq(token.name(), "Mock ETH");
    }

    /**
     * @notice Verifikasi fungsi getAllTokens() dan getTokensCount().
     */
    function test_CreateMultipleTokens() public {
        factory.createToken("Mock USD", "mUSD", 1_000_000 ether);
        factory.createToken("Mock ETH", "mETH", 1_000_000 ether);
        factory.createToken("Mock IDR", "mIDR", 1_000_000 ether);

        address[] memory tokens = factory.getAllTokens();
        assertEq(tokens.length, 3);
        assertEq(factory.getTokensCount(), 3);
    }

    // ============ 2. SECURITY & OWNERSHIP (STRICT) ============

    /**
     * @notice CRITICAL: Mastiin orang asing (user2) GAK BISA nge-mint token user1.
     */
    function test_Revert_StrangerCannotMint() public {
        vm.prank(user1);
        address tokenAddr = factory.createToken("User1 Token", "U1T", 100 ether);
        MockToken token = MockToken(tokenAddr);

        // User2 mencoba menyerang/menambah supply
        vm.prank(user2);
        vm.expectRevert(); // Harusnya gagal karena bukan owner
        token.mint(user2, 1_000_000 ether);
        
        assertEq(token.balanceOf(user2), 0, "Stranger successfully minted tokens!");
    }

    /**
     * @notice Mastiin kepemilikan token berpindah ke msg.sender, bukan nyangkut di factory.
     */
    function test_DifferentUserCreatesToken_AndOwnsIt() public {
        vm.prank(user1);
        address tokenAddr = factory.createToken("Mock BTC", "mBTC", 500_000 ether);
        MockToken token = MockToken(tokenAddr);

        assertEq(token.balanceOf(user1), 500_000 ether);
        assertEq(token.owner(), user1, "User1 must be the contract owner");
    }

    // ============ 3. FUZZING & EDGE CASES (PRO) ============

    /**
     * @notice FUZZ TEST: Mencoba ribuan kombinasi nama, simbol, dan amount secara otomatis.
     */
    function testFuzz_CreateToken(string memory name, string memory symbol, uint256 amount) public {
        // Constraints: Simbol jangan kosong dan jangan kepanjangan, amount realistis
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length < 32);
        vm.assume(amount > 0 && amount < 1e36); 

        vm.prank(user1);
        address tokenAddr = factory.createToken(name, symbol, amount);
        
        MockToken token = MockToken(tokenAddr);
        assertEq(token.symbol(), symbol);
        assertEq(token.owner(), user1);
    }

    /**
     * @notice Mastiin duplikasi simbol ditolak oleh factory.
     */
    function test_Revert_DuplicateSymbol() public {
        factory.createToken("First", "SAME", 1_000_000 ether);

        vm.expectRevert("Symbol already exists");
        factory.createToken("Second", "SAME", 1_000_000 ether);
    }

    /**
     * @notice Case Sensitivity check (mETH vs METH).
     */
    function test_SymbolCaseSensitivity() public {
        factory.createToken("Token 1", "mETH", 1000 ether);
        
        // Harusnya berhasil karena hash-nya berbeda
        address token2 = factory.createToken("Token 2", "METH", 1000 ether);
        
        assertTrue(token2 != address(0));
        assertEq(factory.getTokensCount(), 2);
    }

    /**
     * @notice Perilaku terhadap simbol kosong.
     */
    function test_CreateEmptySymbol() public {
        // Jika src belum di-fix, ini akan pass. Jika sudah ditambah require, update ke expectRevert
        address emptyToken = factory.createToken("Empty", "", 1000 ether);
        assertTrue(emptyToken != address(0));
    }
}