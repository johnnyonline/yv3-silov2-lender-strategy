// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Swapper} from "../src/Swapper.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeploySwapper.s.sol:DeploySwapper --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

// verify:
// --constructor-args $(cast abi-encode "constructor(address)" 0xbACBBefda6fD1FbF5a2d6A79916F4B6124eD2D49)
// forge verify-contract --etherscan-api-key $KEY --watch --chain-id 42161 --compiler-version v0.8.18+commit.87f61d96 --verifier-url https://api.arbiscan.io/api 0x9a5eca1b228e47a15BD9fab07716a9FcE9Eebfb5 src/ERC404/BaseERC404.sol:BaseERC404

contract DeploySwapper is Script {

    bool private constant TO_SONIC = false;
    int24 private constant SONIC_TO_USDC_SWAP_TICK_SPACING = 50;
    address private constant MANAGEMENT = 0x2c36330954E7e891B8B22156011df6AC657F0abd; // SiloV2 Committee on Sonic

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        address _swapper = address(new Swapper(MANAGEMENT, SONIC_TO_USDC_SWAP_TICK_SPACING, TO_SONIC));

        console.log("-----------------------------");
        console.log("swapper deployed at: ", _swapper);
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

// Swapper:
// 0x71ccF86Cf63A5d55B12AA7E7079C22f39112Dd7D
