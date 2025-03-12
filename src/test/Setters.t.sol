// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
import {IAuction} from "../interfaces/IAuction.sol";

import {Setup, Strategy} from "./utils/Setup.sol";

contract SettersTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_SetWethToAssetSwapTickSpacing(
        int24 _sonicToUsdcSwapTickSpacing
    ) public {
        vm.expectRevert();
        swapper.setSwapTickSpacing(_sonicToUsdcSwapTickSpacing);

        vm.prank(management);
        swapper.setSwapTickSpacing(_sonicToUsdcSwapTickSpacing);
        assertEq(swapper.sonicToUsdcSwapTickSpacing(), _sonicToUsdcSwapTickSpacing);
    }

    function test_SetUseAuction(
        bool _useAuction
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setUseAuction(_useAuction);

        vm.prank(management);
        strategyImpl.setUseAuction(_useAuction);
        assertEq(strategyImpl.useAuction(), _useAuction);
    }

    function test_SetAuction(
        address _invalidAuction
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setAuction(IAuction(_invalidAuction));

        vm.startPrank(management);
        strategyImpl.setAuction(auction);
        assertEq(address(strategyImpl.auction()), address(auction));

        auction.setWant(address(0));
        vm.expectRevert("!want");
        strategyImpl.setAuction(auction);

        auction.setReceiver(address(0));
        vm.expectRevert("!receiver");
        strategyImpl.setAuction(auction);
        vm.stopPrank();
    }

    function test_SetIncentivesController() public {
        vm.expectRevert("!management");
        strategyImpl.setIncentivesController(ISiloIncentivesController(siloIncentivesController));

        vm.startPrank(management);
        strategyImpl.setIncentivesController(ISiloIncentivesController(siloIncentivesController));
        assertEq(address(strategyImpl.incentivesController()), address(siloIncentivesController));

        address _invalidIncentivesController = address(0x6Cb96f195cF92cFb749889681d885Fd6eaaB6f2D);
        vm.expectRevert("!incentivesController");
        strategyImpl.setIncentivesController(ISiloIncentivesController(_invalidIncentivesController));
        vm.stopPrank();
    }

    function test_SetProgramNames(
        string[] memory _names
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setProgramNames(_names);

        vm.prank(management);
        strategyImpl.setProgramNames(_names);
        string[] memory _programNames = strategyImpl.getAllProgramNames();
        for (uint256 i = 0; i < _names.length; ++i) {
            assertEq(_programNames[i], _names[i]);
        }
    }

}
