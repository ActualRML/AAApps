// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccountFactory.sol";
import "../../src/smart-account/SmartAccount.sol";

contract SmartAccountFactoryTest is Test {
    SmartAccountFactory public factory;
    address public entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public owner;
    address[] public guardians;

    function setUp() public {
        factory = new SmartAccountFactory(entryPoint);
        owner = makeAddr("owner");
        guardians.push(makeAddr("guardian1"));
    }

    /**
     * @notice Mastiin alamat yang diprediksi getAddress() sama dengan kenyataan pas deploy.
     */
    function test_PredictableAddress() public {
        uint256 salt = 12345;
        
        // 1. Prediksi alamat dulu secara offline (counterfactual)
        address predictedAddress = factory.getAddress(owner, guardians, salt);

        // 2. Deploy beneran lewat factory
        SmartAccount account = factory.createAccount(owner, guardians, salt);

        // 3. Harus sama persis!
        assertEq(address(account), predictedAddress, "Address mismatch!");
        assertEq(account.owner(), owner, "Owner mismatch!");
    }

    /**
     * @notice Mastiin kalau dideploy 2x dengan salt & data sama, factory cuma return alamat lama.
     */
    function test_NoRedeployIfAlreadyExists() public {
        uint256 salt = 99;
        
        // Deploy pertama
        SmartAccount account1 = factory.createAccount(owner, guardians, salt);
        
        // Deploy kedua (data identik)
        SmartAccount account2 = factory.createAccount(owner, guardians, salt);

        // Harus return contract yang sama, bukan bikin baru (karena CREATE2 bakal revert kalo dipaksa)
        assertEq(address(account1), address(account2), "Should return existing address");
    }

    /**
     * @notice Mastiin salt yang sama tapi OWNER beda bakal ngasilin alamat beda (Namespace isolation).
     */
    function test_DifferentOwnerSameSalt_DifferentAddress() public {
        uint256 salt = 1010;
        address owner2 = makeAddr("owner2");

        address addr1 = factory.getAddress(owner, guardians, salt);
        address addr2 = factory.getAddress(owner2, guardians, salt);

        assertTrue(addr1 != addr2, "Address should be different for different owners");
    }

    /**
     * @notice Test guardrail: Tidak boleh deploy tanpa guardian.
     */
    function test_Revert_NoGuardians() public {
        address[] memory emptyGuardians;
        vm.expectRevert("At least one guardian required");
        factory.createAccount(owner, emptyGuardians, 1);
    }
}   