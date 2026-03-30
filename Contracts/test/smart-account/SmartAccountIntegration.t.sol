// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccount.sol";
import "../../src/smart-account/SmartAccountFactory.sol";
import "../../src/common/Errors.sol"; 

/**
 * @dev Kontrak pembantu buat ngetes bubble revert
 */
contract RevertingContract {
    error CustomTargetError(string message);
    
    function failWithMessage() external pure {
        revert CustomTargetError("Target contract failed!");
    }
}

contract SmartAccountIntegrationTest is Test {
    SmartAccountFactory factory;
    SmartAccount account;
    RevertingContract revertingContract;
    
    address owner;
    address payable receiver;
    address entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    function setUp() public {
        owner = makeAddr("owner");
        receiver = payable(makeAddr("receiver"));
        revertingContract = new RevertingContract();
        
        factory = new SmartAccountFactory(entryPoint);
        
        address[] memory guardians = new address[](1);
        guardians[0] = makeAddr("guardian");
        
        address accountAddr = factory.createAccount(owner, guardians, 1, 123);
        account = SmartAccount(payable(accountAddr));
        
        vm.deal(address(account), 10 ether); 
    }

    // ============ HAPPY PATH ============

    function test_TransferETH() public {
        uint256 initialBalance = receiver.balance;
        uint256 amount = 1 ether;

        vm.prank(owner);
        account.execute(receiver, amount, "");

        assertEq(receiver.balance, initialBalance + amount);
        assertEq(account.nonce(), 1);
    }

    function test_BatchTransferETH() public {
        address receiver2 = makeAddr("receiver2");
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = receiver;
        targets[1] = receiver2;
        values[0] = 1 ether;
        values[1] = 2 ether;
        datas[0] = "";
        datas[1] = "";

        vm.prank(owner);
        account.executeBatch(targets, values, datas);

        assertEq(receiver.balance, 1 ether);
        assertEq(receiver2.balance, 2 ether);
        assertEq(account.nonce(), 1);
    }

    // ============ SECURITY & ATOMICITY ============

    /**
     * @notice Mengetes atomicity: Jika satu gagal, semua harus revert.
     */
    function test_Revert_BatchAtomicity() public {
        uint256 initialBalance = receiver.balance;
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = receiver;
        values[0] = 1 ether;
        datas[0] = "";

        // Target kedua salah (address(0)), memicu InvalidTarget()
        targets[1] = address(0);
        values[1] = 1 ether;
        datas[1] = "";

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidTarget.selector);
        account.executeBatch(targets, values, datas);

        // Receiver pertama TIDAK BOLEH dapet saldo karena seluruh batch harus revert
        assertEq(receiver.balance, initialBalance, "Batch must be atomic");
        assertEq(account.nonce(), 0, "Nonce should not increase on failure");
    }

    /**
     * @notice Mastiin assembly InsufficientBalance lo jalan
     */
    function test_Revert_InsufficientBalance() public {
    vm.prank(owner);
    
    // Cara paling aman buat nangkep assembly revert yang "raw"
    vm.expectRevert(); 
    account.execute(receiver, 100 ether, "");
    
    // Verifikasi saldo tidak berubah (Safety check)
    assertEq(address(account).balance, 10 ether);
}

    /**
     * @notice Mastiin pesan error dari kontrak target "nembus" ke luar (Bubble Revert)
     */
    function test_Revert_BubbleUpTargetError() public {
        vm.prank(owner);
        // Kita expect error dari RevertingContract bukan dari SmartAccount
        vm.expectRevert(abi.encodeWithSelector(RevertingContract.CustomTargetError.selector, "Target contract failed!"));
        account.execute(address(revertingContract), 0, abi.encodeWithSelector(RevertingContract.failWithMessage.selector));
    }

    /**
     * @notice Tes otorisasi untuk eksekusi single
     */
    function test_Revert_UnauthorizedExecute() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(Errors.NotAuthorized.selector);
        account.execute(receiver, 1 ether, "");
    }

    /**
     * @notice Mastiin entrypoint juga bisa manggil (penting buat AA flow)
     */
    function test_EntryPointCanExecute() public {
        vm.prank(entryPoint);
        account.execute(receiver, 1 ether, "");
        assertEq(receiver.balance, 1 ether);
    }

    /**
     * @notice Test array mismatch pada batch
     */
    function test_Revert_ArrayMismatchBatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1); // Cuma 1
        bytes[] memory datas = new bytes[](2);

        vm.prank(owner);
        vm.expectRevert(Errors.ArrayMismatch.selector);
        account.executeBatch(targets, values, datas);
    }
}