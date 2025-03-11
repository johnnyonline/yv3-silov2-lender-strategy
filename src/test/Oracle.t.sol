pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup} from "./utils/Setup.sol";

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

import {SiloV2LenderStrategyAprOracle} from "../periphery/StrategyAprOracle.sol";

contract OracleTest is Setup {

    SiloV2LenderStrategyAprOracle public oracle;

    address public constant SILO_LENS = 0xB6AdBb29f2D8ae731C7C72036A7FD5A7E970B198;
    address public constant SONIC_USD_CL_ORACLE = 0xc76dFb89fF298145b417d221B2c747d84952e01d;

    function setUp() public override {
        super.setUp();
        oracle = new SiloV2LenderStrategyAprOracle(management, SILO_LENS);
    }

    function checkOracle(address _strategy, uint256 _delta) public {
        // Check set up
        // TODO: Add checks for the setup
        vm.prank(management);
        oracle.setAssetPriceOracle(AggregatorV3Interface(SONIC_USD_CL_ORACLE), address(WRAPPED_S));

        // Set program names
        vm.prank(management);
        strategyImpl.setProgramNames(incentiveProgramNames);

        uint256 currentApr = oracle.aprAfterDebtChange(_strategy, 0);

        // Should be greater than 0 but likely less than 100%
        assertGt(currentApr, 0, "ZERO");
        assertLt(currentApr, 1e18, "+100%");
        console2.log("Current APR: %s", currentApr);

        // TODO: Uncomment to test the apr goes up and down based on debt changes
        /**
         * uint256 negativeDebtChangeApr = oracle.aprAfterDebtChange(_strategy, -int256(_delta));
         *
         *     // The apr should go up if deposits go down
         *     assertLt(currentApr, negativeDebtChangeApr, "negative change");
         *
         *     uint256 positiveDebtChangeApr = oracle.aprAfterDebtChange(_strategy, int256(_delta));
         *
         *     assertGt(currentApr, positiveDebtChangeApr, "positive change");
         */

        // TODO: Uncomment if there are setter functions to test.
        /**
         * vm.expectRevert("!governance");
         *     vm.prank(user);
         *     oracle.setterFunction(setterVariable);
         *
         *     vm.prank(management);
         *     oracle.setterFunction(setterVariable);
         *
         *     assertEq(oracle.setterVariable(), setterVariable);
         */
    }

    function test_oracle(uint256 _amount, uint16 _percentChange) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _percentChange = uint16(bound(uint256(_percentChange), 10, MAX_BPS));

        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _delta = (_amount * _percentChange) / MAX_BPS;

        checkOracle(address(strategy), _delta);
    }

    // TODO: Deploy multiple strategies with different tokens as `asset` to test against the oracle.

}
