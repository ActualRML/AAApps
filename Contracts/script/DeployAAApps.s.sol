// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SmartAccount} from "../src/smart-account/SmartAccount.sol";
import {SmartAccountFactory} from "../src/smart-account/SmartAccountFactory.sol";
import {TokenPaymaster} from "../src/paymaster/TokenPaymaster.sol";
import {EntryPoint} from "../src/entrypoint/EntryPoint.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAAApps is Script {
    function run() external {
        // 1. Setup Environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address mockToken = vm.envAddress("MOCK_TOKEN_ADDR");
        address priceFeed = vm.envAddress("PRICE_FEED_ADDR");
        address deployerAddr = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 2. Deploy EntryPoint
        EntryPoint entryPoint = new EntryPoint();

        // 3. Deploy SmartAccountFactory
        SmartAccountFactory factory = new SmartAccountFactory(address(entryPoint));

        // 4. Deploy TokenPaymaster (Logic & Proxy)
        TokenPaymaster paymasterLogic = new TokenPaymaster();

        bytes memory initData = abi.encodeWithSelector(
            TokenPaymaster.initialize.selector, mockToken, address(entryPoint), priceFeed, deployerAddr
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(paymasterLogic), initData);
        TokenPaymaster paymaster = TokenPaymaster(payable(address(proxy)));

        // 5. Deposit ETH ke EntryPoint untuk operasional Paymaster
        // User bayar gas pakai MockToken, Paymaster talangi pakai ETH ini
        paymaster.deposit{value: 0.05 ether}();

        vm.stopBroadcast();

        // 6. Log untuk .env update
        console.log("\n--- DEPLOYMENT SUCCESSFUL ---");
        console.log("ENTRY_POINT_ADDR=%s", address(entryPoint));
        console.log("ACCOUNT_FACTORY_ADDR=%s", address(factory));
        console.log("PAYMASTER_LOGIC_ADDR=%s", address(paymasterLogic));
        console.log("PAYMASTER_PROXY_ADDR=%s", address(paymaster));
        console.log("-----------------------------\n");
    }
}
