// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccountFactory.sol";
import "../../src/smart-account/SmartAccount.sol";
import "../../src/common/Errors.sol"; 

contract SmartAccountFactoryTest is Test {
    SmartAccountFactory public factory;
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public owner;
    address[] public guardians;

    function setUp() public {
        factory = new SmartAccountFactory(entryPoint);
        owner = makeAddr("owner");
        guardians.push(makeAddr("guardian1"));
        guardians.push(makeAddr("guardian2"));
    }

    /**
     * @notice FUZZ TEST: Mencoba ribuan kombinasi owner & salt secara otomatis.
     * Forge bakal otomatis masukin random address & uint256 ke sini.
     */
    function testFuzz_PredictableAddress(address randomOwner, uint256 randomSalt) public {
        // Assume: Kita skip address(0) karena factory lo punya proteksi revert
        vm.assume(randomOwner != address(0));

        address predicted = factory.getAddress(randomOwner, randomSalt);
        
        // Deploy dengan threshold standar 1
        address deployed = factory.createAccount(randomOwner, guardians, 1, randomSalt);

        assertEq(predicted, deployed, "Deterministic address mismatch!");
        
        // Verifikasi owner di storage akun yang baru lahir
        assertEq(SmartAccount(payable(deployed)).owner(), randomOwner, "Owner state mismatch!");
    }

    /**
     * @notice STRICT TEST: Mastiin state di SmartAccount terinisialisasi dengan benar.
     */
    function test_StateInitialization() public {
        uint256 salt = 420;
        uint256 threshold = 2;
        
        address accountAddr = factory.createAccount(owner, guardians, threshold, salt);
        SmartAccount account = SmartAccount(payable(accountAddr));

        // Cek semua parameter penting
        assertEq(account.owner(), owner, "Owner not set");
        assertEq(address(account.entryPoint()), entryPoint, "EntryPoint not set");
        assertEq(account.recoveryThreshold(), threshold, "Threshold not set");
        assertEq(account.guardianCount(), guardians.length, "Guardian count mismatch");
        
        // Cek apakah guardianIndex terisi (guardianIndex mulai dari 1)
        assertTrue(account.guardianIndex(guardians[0]) > 0, "Guardian 1 not indexed");
        assertTrue(account.guardianIndex(guardians[1]) > 0, "Guardian 2 not indexed");
    }

    /**
     * @notice SECURITY TEST: Mastiin deployer ga bisa masukin owner address(0).
     */
    function test_Revert_ZeroAddressOwner() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.createAccount(address(0), guardians, 1, 123);
    }

    /**
     * @notice EDGE CASE: Test threshold yang pas banget sama jumlah guardian (Maximum threshold).
     */
    function test_MaxThreshold() public {
        uint256 maxThreshold = guardians.length;
        address accountAddr = factory.createAccount(owner, guardians, maxThreshold, 777);
        
        assertEq(SmartAccount(payable(accountAddr)).recoveryThreshold(), maxThreshold);
    }

    /**
     * @notice DIVERSITY TEST: Mastiin salt yang sama tapi owner beda menghasilkan alamat unik.
     */
    function test_SaltCollisionProtection() public {
        uint256 commonSalt = 1;
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");

        address addrA = factory.getAddress(userA, commonSalt);
        address addrB = factory.getAddress(userB, commonSalt);

        assertTrue(addrA != addrB, "Collision detected for different owners!");
    }

    /**
     * @notice REENTRANCY / DOUBLE DEPLOY: Mastiin factory ga mati kalau dipanggil 2x.
     */
    function test_Idempotency() public {
        uint256 salt = 1337;
        
        address first = factory.createAccount(owner, guardians, 1, salt);
        address second = factory.createAccount(owner, guardians, 1, salt);

        assertEq(first, second, "Factory should be idempotent");
        // Pastikan tidak ada re-initialization yang bisa ngerusak owner
        assertEq(SmartAccount(payable(first)).owner(), owner);
    }
}