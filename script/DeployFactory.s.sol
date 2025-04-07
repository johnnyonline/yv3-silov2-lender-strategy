// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {SiloV2LenderStrategyFactory} from "../src/StrategyFactory.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployFactory.s.sol:DeployFactory --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

// verify:
// --constructor-args $(cast abi-encode "constructor(address)" 0xbACBBefda6fD1FbF5a2d6A79916F4B6124eD2D49)
// forge verify-contract --etherscan-api-key $KEY --watch --chain-id 42161 --compiler-version v0.8.18+commit.87f61d96 --verifier-url https://api.arbiscan.io/api 0x9a5eca1b228e47a15BD9fab07716a9FcE9Eebfb5 src/ERC404/BaseERC404.sol:BaseERC404

contract DeployFactory is Script {

    address private constant MANAGEMENT = 0x2c36330954E7e891B8B22156011df6AC657F0abd; // SiloV2 Committee on Sonic

    address private constant KEEPER = 0x318d0059efE546b5687FA6744aF4339391153981; // Sonic // @todo -- change to yhaas?

    address private constant EMERGENCY_ADMIN = 0x35442eC4C1A0C4E864c2Bc45bfc5d17fCEE8ac4C; // SMS on Sonic

    address private constant PERFORMANCE_FEE_RECIPIENT = 0x318d0059efE546b5687FA6744aF4339391153981; // yearn deployer

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        address _factory =
            address(new SiloV2LenderStrategyFactory(MANAGEMENT, PERFORMANCE_FEE_RECIPIENT, KEEPER, EMERGENCY_ADMIN));

        console.log("-----------------------------");
        console.log("factory deployed at: ", _factory);
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

// Factory:
// 0x61810a90128Ee5c5F5a3730f0449Da9E9480f888
