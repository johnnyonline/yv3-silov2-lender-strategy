// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IStrategyInterface} from "../src/interfaces/IStrategyInterface.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/Report.s.sol:Report --rpc-url $RPC_URL --broadcast

contract Report is Script {

    IStrategyInterface public strategy = IStrategyInterface(0x3FfA0C3fba4Adfe2b6e4D7E2f8E6e6324bE5305B); // S/USDC (8)
    // IStrategyInterface public strategy = IStrategyInterface(0xf1dF9a0390Fd65984F311f17230B9F6B85497C6e); // S/USDC (20)

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        strategy.report();

        vm.stopBroadcast();
    }

}
