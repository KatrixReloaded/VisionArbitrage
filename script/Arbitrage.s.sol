// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../src/Arbitrage.sol";

contract DeployFlashLoanArbitrage is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new FlashLoanArbitrage();

        vm.stopBroadcast();
    }
}
