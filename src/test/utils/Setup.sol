// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {AuctionMock} from "../mocks/AuctionMock.sol";
import {SiloV2LenderStrategy, ERC20} from "../../Strategy.sol";
import {StrategyFactory} from "../../StrategyFactory.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {

    function governance() external view returns (address);

    function set_protocol_fee_bps(
        uint16
    ) external;

    function set_protocol_fee_recipient(
        address
    ) external;

}

contract Setup is ExtendedTest, IEvents {

    // Reward tokens
    ERC20 public SILO = ERC20(0x53f753E4B17F4075D6fa2c6909033d224b81e698);
    ERC20 public WRAPPED_S = ERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    // Silo
    address public siloShareToken = 0x4E216C15697C1392fE59e1014B009505E05810Df; // Borrowable USDC.e Deposit, SiloId: 8
    address public siloIncentivesController = 0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752; // Borrowable USDC.e Deposit, SiloId: 8
    string[] public incentiveProgramNames = ["wS_sUSDC_008", "SILO_sUSDC_008"];

    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    SiloV2LenderStrategy public strategyImpl;
    AuctionMock public auction;

    StrategyFactory public strategyFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $10 of 1e6 stable coins up to 10 million of a 1e6 coin
    uint256 public maxFuzzAmount = 10_000_000 * 1e6;
    uint256 public minFuzzAmount = 10 * 1e6;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["USDC - Sonic"]);

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = new StrategyFactory(management, performanceFeeRecipient, keeper, emergencyAdmin);

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());
        strategyImpl = SiloV2LenderStrategy(address(strategy));

        auction = new AuctionMock(address(asset), address(strategy));
        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(auction), "_auction");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(address(strategyImpl), "strategyImpl");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategy() public returns (address) {
        // we save the strategy as a IStrategyInterface to give it the needed interface
        IStrategyInterface _strategy = IStrategyInterface(
            address(
                strategyFactory.newStrategy(
                    address(asset), "Tokenized Strategy", siloShareToken, siloIncentivesController
                )
            )
        );

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(address(_strategy));
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function airdropToSiloAndS(address _to, uint256 _amount) public {
        airdrop(SILO, _to, _amount);
        airdrop(WRAPPED_S, _to, _amount);
    }

    function assertSiloAndSBalance(address _from, bool _moreThanZero) public {
        if (_moreThanZero) {
            assertGt(SILO.balanceOf(_from), 0, "assertSiloAndSBalance: TRUE, SILO");
            assertGt(WRAPPED_S.balanceOf(_from), 0, "assertSiloAndSBalance: TRUE, S");
        } else {
            assertEq(SILO.balanceOf(_from), 0, "assertSiloAndSBalance: FALSE, SILO");
            assertEq(WRAPPED_S.balanceOf(_from), 0, "assertSiloAndSBalance: FALSE, S");
        }
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["USDC - Sonic"] = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    }

    function _addRewardTokens() internal {
        vm.startPrank(management);
        strategyImpl.addRewardToken(address(SILO), SiloV2LenderStrategy.SwapType.ATOMIC);
        strategyImpl.addRewardToken(address(WRAPPED_S), SiloV2LenderStrategy.SwapType.ATOMIC);
        vm.stopPrank();
    }

}
