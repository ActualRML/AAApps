// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory} from "../src/token/TokenFactory.sol";
import {MockToken} from "../src/token/MockToken.sol";

contract DeployTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        console.log("Deploying tokens using address:", deployerAddr);

        vm.startBroadcast(deployerPrivateKey);

        TokenFactory factory = new TokenFactory();
        console.log("TokenFactory deployed at:", address(factory));

        uint256 supply = 1_000_000 * 10 ** 18;

        address btcAddr = factory.createToken("Bitcoin Mock", "BTC", supply);
        address ethAddr = factory.createToken("Ethereum Mock", "ETH", supply);
        address usdtAddr = factory.createToken("Tether Mock", "USDT", supply);
        address solAddr = factory.createToken("Solana Mock", "SOL", supply);
        address adaAddr = factory.createToken("Cardano Mock", "ADA", supply);

        console.log("-------------------------------------");
        console.log("BTC_ADDRESS=", btcAddr);
        console.log("ETH_ADDRESS=", ethAddr);
        console.log("USDT_ADDRESS=", usdtAddr);
        console.log("SOL_ADDRESS=", solAddr);
        console.log("ADA_ADDRESS=", adaAddr);
        console.log("-------------------------------------");

        vm.stopBroadcast();
    }
}
