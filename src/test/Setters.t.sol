// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
import {IAuction} from "../interfaces/IAuction.sol";

import {Setup, SiloV2LenderStrategy} from "./utils/Setup.sol";

contract SettersTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_SetTradeFactory(
        address _tradeFactory
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setTradeFactory(_tradeFactory);

        vm.prank(management);
        strategyImpl.setTradeFactory(_tradeFactory);
        assertEq(strategyImpl.tradeFactory(), _tradeFactory);
    }

    function test_SetWethToAssetSwapTickSpacing(
        int24 _sonicToAssetSwapTickSpacing
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setWethToAssetSwapTickSpacing(_sonicToAssetSwapTickSpacing);

        vm.prank(management);
        strategyImpl.setWethToAssetSwapTickSpacing(_sonicToAssetSwapTickSpacing);
        assertEq(strategyImpl.sonicToAssetSwapTickSpacing(), _sonicToAssetSwapTickSpacing);
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

    function test_SetSwapType(
        address _from
    ) public {
        vm.expectRevert("!management");
        strategyImpl.setSwapType(_from, SiloV2LenderStrategy.SwapType.NULL);

        vm.startPrank(management);
        vm.expectRevert("!swaptype");
        strategyImpl.setSwapType(_from, SiloV2LenderStrategy.SwapType.NULL);

        strategyImpl.setSwapType(_from, SiloV2LenderStrategy.SwapType.ATOMIC);
        assertEq(uint8(strategyImpl.swapType(_from)), uint8(SiloV2LenderStrategy.SwapType.ATOMIC));

        strategyImpl.setSwapType(_from, SiloV2LenderStrategy.SwapType.AUCTION);
        assertEq(uint8(strategyImpl.swapType(_from)), uint8(SiloV2LenderStrategy.SwapType.AUCTION));

        strategyImpl.setSwapType(_from, SiloV2LenderStrategy.SwapType.TF);
        assertEq(uint8(strategyImpl.swapType(_from)), uint8(SiloV2LenderStrategy.SwapType.TF));
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

    function test_SetMinAmountToSellMapping(address _token, uint256 _amount) public {
        vm.expectRevert("!management");
        strategyImpl.setMinAmountToSellMapping(_token, _amount);

        vm.prank(management);
        strategyImpl.setMinAmountToSellMapping(_token, _amount);
        assertEq(strategyImpl.minAmountToSellMapping(_token), _amount);
    }

    function test_AddRewardToken(address _token, uint8 _swapType) public {
        vm.assume(_swapType > 0 && _swapType < 4);
        vm.assume(_token != address(0));

        vm.expectRevert("!management");
        strategyImpl.addRewardToken(_token, SiloV2LenderStrategy.SwapType(_swapType));

        vm.startPrank(management);

        vm.expectRevert("!swaptype");
        strategyImpl.addRewardToken(_token, SiloV2LenderStrategy.SwapType.NULL);

        strategyImpl.addRewardToken(_token, SiloV2LenderStrategy.SwapType(_swapType));
        assertEq(uint8(strategyImpl.swapType(_token)), _swapType);

        vm.expectRevert("exists");
        strategyImpl.addRewardToken(_token, SiloV2LenderStrategy.SwapType(_swapType));

        vm.expectRevert("!allowed");
        strategyImpl.addRewardToken(address(asset), SiloV2LenderStrategy.SwapType(_swapType));

        vm.expectRevert("!allowed");
        strategyImpl.addRewardToken(siloShareToken, SiloV2LenderStrategy.SwapType(_swapType));

        vm.expectRevert("!allowed");
        strategyImpl.addRewardToken(address(0), SiloV2LenderStrategy.SwapType(_swapType));

        address[] memory _allRewardTokens = strategyImpl.getAllRewardTokens();
        assertEq(_allRewardTokens.length, 1);
        assertEq(_allRewardTokens[0], _token);

        if (SiloV2LenderStrategy.SwapType(_swapType) == SiloV2LenderStrategy.SwapType.TF) {
            address[] memory _rewardTokens = strategyImpl.rewardTokens();
            assertEq(_rewardTokens.length, 1);
            assertEq(_rewardTokens[0], _token);
        }

        vm.stopPrank();
    }

    function test_RemoveRewardToken(address _token, uint8 _swapType) public {
        vm.expectRevert("!management");
        strategyImpl.removeRewardToken(_token);

        test_AddRewardToken(_token, _swapType);

        vm.startPrank(management);
        strategyImpl.removeRewardToken(_token);
        assertEq(uint8(strategyImpl.swapType(_token)), 0);
        assertEq(strategyImpl.minAmountToSellMapping(_token), 0);
    }

}
