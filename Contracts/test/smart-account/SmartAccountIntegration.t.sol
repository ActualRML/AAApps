// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/smart-account/SmartAccount.sol";
import "../../src/smart-account/SmartAccountFactory.sol";

contract SmartAccountIntegrationTest is Test {
    SmartAccountFactory factory;
    SmartAccount account;
    address owner;
    address payable receiver;

    function setUp() public {
        owner = makeAddr("owner");
        receiver = payable(makeAddr("receiver"));
        
        factory = new SmartAccountFactory(address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789));
        
        address[] memory guardians = new address[](1);
        guardians[0] = makeAddr("guardian");
        
        account = factory.createAccount(owner, guardians, 1);
        vm.deal(address(account), 10 ether); // Kasih modal buat test
    }

    function test_TransferETH() public {
        uint256 initialBalance = receiver.balance;
        uint256 amount = 1 ether;

        vm.prank(owner);
        account.execute(receiver, amount, "");

        assertEq(receiver.balance, initialBalance + amount);
        assertEq(account.nonce(), 1);
    }

    function test_BatchTransferETH() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = receiver;
        targets[1] = makeAddr("receiver2");
        values[0] = 1 ether;
        values[1] = 2 ether;
        datas[0] = "";
        datas[1] = "";

        vm.prank(owner);
        account.executeBatch(targets, values, datas);

        assertEq(receiver.balance, 1 ether);
        assertEq(targets[1].balance, 2 ether);
        assertEq(account.nonce(), 1);
    }
}