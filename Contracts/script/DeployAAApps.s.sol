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
        // 1. Tarik semua data dari .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address mockToken = vm.envAddress("MOCK_TOKEN_ADDR"); 
        address priceFeed = vm.envAddress("PRICE_FEED_ADDR"); 
        address deployerAddr = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 2. Deploy EntryPoint
        EntryPoint entryPoint = new EntryPoint();
        console.log("EntryPoint deployed at:", address(entryPoint));

        // 3. Deploy SmartAccount Factory
        SmartAccountFactory factory = new SmartAccountFactory(address(entryPoint));
        console.log("Factory deployed at:", address(factory));

        // 4. Deploy TokenPaymaster (Logic & Proxy)
        TokenPaymaster paymasterLogic = new TokenPaymaster();
        
        // Data inisialisasi untuk Proxy
        bytes memory initData = abi.encodeWithSelector(
            TokenPaymaster.initialize.selector,
            mockToken,
            address(entryPoint),
            priceFeed,
            deployerAddr
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(paymasterLogic), initData);
        TokenPaymaster paymaster = TokenPaymaster(payable(address(proxy)));
        console.log("Paymaster Proxy deployed at:", address(paymaster));

        // 5. Deposit Modal ETH ke Paymaster
        // Karena saldo lo cuma 0.101, kita deposit 0.05 aja biar sisa gas cukup
        paymaster.deposit{value: 0.05 ether}();
        console.log("Deposited 0.05 ETH to EntryPoint for Paymaster");

        vm.stopBroadcast();
    }
}