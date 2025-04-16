// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {AuctionMock} from "../mocks/AuctionMock.sol";
import {Swapper} from "../../Swapper.sol";
import {SiloV2LenderStrategy as Strategy, ERC20, ISilo} from "../../Strategy.sol";
import {SiloV2LenderStrategyFactory as StrategyFactory} from "../../StrategyFactory.sol";
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
    ERC20 public constant SILO = ERC20(0x53f753E4B17F4075D6fa2c6909033d224b81e698);
    ERC20 public constant WRAPPED_S = ERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    // // Silo - USDC (8)
    // address public siloLendToken = 0x4E216C15697C1392fE59e1014B009505E05810Df; // Borrowable USDC.e Deposit, SiloId: 8 (SILO1)
    // address public siloCollateralToken = 0xE223C8e92AA91e966CA31d5C6590fF7167E25801; // Borrowable wS Deposit, SiloId: 8 (SILO0)
    // address public siloIncentivesController = 0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752; // Borrowable USDC.e Deposit, SiloId: 8
    // string[] public incentiveProgramNames = ["wS_sUSDC_008", "SILO_sUSDC_008"];
    // bool public toSonic = false;

    // Silo - USDC (20)
    address public siloLendToken = 0x322e1d5384aa4ED66AeCa770B95686271de61dc3; // Borrowable USDC.e Deposit, SiloId: 20 (SILO1)
    address public siloCollateralToken = 0xf55902DE87Bd80c6a35614b48d7f8B612a083C12; // Borrowable wS Deposit, SiloId: 20 (SILO0)
    address public siloIncentivesController = 0x2D3d269334485d2D876df7363e1A50b13220a7D8; // Borrowable USDC.e Deposit, SiloId: 20
    string[] public incentiveProgramNames = ["wS_sUSDC_0020", "SILO_sUSDC_0020"];
    bool public toSonic = false;

    // // Silo - S
    // address public siloLendToken = 0x24F7692af5231d559219d07c65276Ad8C8ceE9A3; // Borrowable wS Deposit, SiloId: 40 (SILO1)
    // address public siloCollateralToken = 0x058766008d237faF3B05eeEebABc73C64d677bAE; // Borrowable PT-stS-29May Deposit, SiloId: 40 (SILO0)
    // address public siloIncentivesController = 0x4BeFBc8E3885f124C683a2ee4E0B69e785b2C83E; // Borrowable USDC.e Deposit, SiloId: 8
    // string[] public incentiveProgramNames = ["SILO_swS_0040"];
    // bool public toSonic = true;

    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    Strategy public strategyImpl;
    Swapper public swapper;
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
    int24 public TICK_SPACING = 50;

    // Fuzz from $10 of 1e6 coin up to 100 million of a 1e6 coin
    uint256 public maxFuzzAmount = 100_000_000 * 1e6;
    uint256 public minFuzzAmount = 10 * 1e6;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    // Indicates if should treat S as a reward token or not
    bool public isSonicReward = !toSonic;

    function setUp() public virtual {
        _setTokenAddrs();

        // Increase fuzz if 1e18 asset
        if (toSonic) {
            maxFuzzAmount *= 1e12;
            minFuzzAmount *= 1e12;
        }

        // Set asset
        asset = ERC20(tokenAddrs["USDC - Sonic"]);
        // asset = ERC20(tokenAddrs["wS"]);

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = new StrategyFactory(management, performanceFeeRecipient, keeper, emergencyAdmin);
        swapper = new Swapper(management, TICK_SPACING, toSonic);

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy(address(swapper)));
        strategyImpl = Strategy(address(strategy));

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

    function setUpStrategy(
        address _swapper
    ) public returns (address) {
        // we save the strategy as a IStrategyInterface to give it the needed interface
        vm.prank(management);
        IStrategyInterface _strategy = IStrategyInterface(
            address(
                strategyFactory.newStrategy(
                    address(asset), "Tokenized Strategy", siloLendToken, siloIncentivesController, _swapper
                )
            )
        );

        assertTrue(strategyFactory.isDeployedStrategy(address(_strategy)), "isDeployedStrategy");

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

    function airdropToSiloAndS(address _to, uint256 _amount, bool _airdropS) public {
        if (_amount < 1 ether) _amount = 1 ether; // NOTE: this might fail the S tests but required for USDC ones
        airdrop(SILO, _to, _amount);
        if (_airdropS) airdrop(WRAPPED_S, _to, _amount);
    }

    function assertSiloAndSBalance(address _from, bool _moreThanZero, bool _assertS) public {
        if (_moreThanZero) {
            assertGt(SILO.balanceOf(_from), 0, "assertSiloAndSBalance: TRUE, SILO");
            if (_assertS) assertGt(WRAPPED_S.balanceOf(_from), 0, "assertSiloAndSBalance: TRUE, S");
        } else {
            assertEq(SILO.balanceOf(_from), 0, "assertSiloAndSBalance: FALSE, SILO");
            if (_assertS) assertEq(WRAPPED_S.balanceOf(_from), 0, "assertSiloAndSBalance: FALSE, S");
        }
    }

    function assertSwapperZeroBalance() public {
        assertEq(SILO.balanceOf(address(swapper)), 0, "assertSwapperZeroBalance: SILO");
        assertEq(WRAPPED_S.balanceOf(address(swapper)), 0, "assertSwapperZeroBalance: S");
        assertEq(asset.balanceOf(address(swapper)), 0, "assertSwapperZeroBalance: asset");
    }

    function simulateMaxBorrow() public {
        ISilo _silo1 = ISilo(siloLendToken); // borrow from
        ISilo _silo0 = ISilo(siloCollateralToken); // deposit to

        address _usefulWhale = address(420);
        vm.startPrank(_usefulWhale);

        // Deposit collateral
        uint256 _collateralAmount = 1e30; // 1 trillion S
        airdrop(ERC20(_silo0.asset()), _usefulWhale, _collateralAmount);
        ERC20(_silo0.asset()).approve(address(_silo0), _collateralAmount);
        _silo0.deposit(_collateralAmount, _usefulWhale);

        // Borrow
        uint256 _borrowAmount = _silo1.getLiquidity();
        _silo1.borrow(_borrowAmount, _usefulWhale, _usefulWhale);
        vm.stopPrank();

        // make sure utilization is 100%
        assertEq(_silo1.getLiquidity(), 0, "!getLiquidity");
    }

    function unwindSimulateMaxBorrow() public {
        ISilo _silo1 = ISilo(siloLendToken); // borrow from

        address _usefulWhale = address(420);
        vm.startPrank(_usefulWhale);

        // Repay
        uint256 _sharesToRepay = _silo1.maxRepayShares(_usefulWhale);
        uint256 _assetsToRepay = _silo1.previewRepayShares(_sharesToRepay);
        airdrop(asset, _usefulWhale, _assetsToRepay);
        asset.approve(address(_silo1), _assetsToRepay);
        _silo1.repayShares(_assetsToRepay, _usefulWhale);

        vm.stopPrank();
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
        tokenAddrs["wS"] = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    }

}
