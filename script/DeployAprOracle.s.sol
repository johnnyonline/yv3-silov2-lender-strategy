// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

import {SiloV2LenderStrategyAprOracle} from "../src/periphery/StrategyAprOracle.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/DeployAprOracle.s.sol:DeployAprOracle --verify --legacy --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

contract DeployAprOracle is Script {

    address public constant MANAGEMENT = 0x2c36330954E7e891B8B22156011df6AC657F0abd; // SiloV2 Committee on Sonic
    address public constant SILO_LENS = 0xB6AdBb29f2D8ae731C7C72036A7FD5A7E970B198;
    address public constant SONIC_USD_CL_ORACLE = 0xc76dFb89fF298145b417d221B2c747d84952e01d;
    address public constant WRAPPED_S = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;

    function run() external {
        uint256 _pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address _deployer = vm.addr(_pk);

        vm.startBroadcast(_pk);

        SiloV2LenderStrategyAprOracle _aprOracle = new SiloV2LenderStrategyAprOracle(_deployer, SILO_LENS);
        _aprOracle.setAssetPriceOracle(AggregatorV3Interface(SONIC_USD_CL_ORACLE), WRAPPED_S);
        _aprOracle.transferGovernance(MANAGEMENT);

        console.log("-----------------------------");
        console.log("apr oracle deployed at: %s", address(_aprOracle));
        console.log("-----------------------------");

        vm.stopBroadcast();
    }

}

// apr oracle deployed at: 0xDd737dADA46F3A111074dCE29B9430a7EA000092
