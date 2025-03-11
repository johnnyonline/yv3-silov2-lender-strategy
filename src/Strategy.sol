// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";

import {IAuction} from "./interfaces/IAuction.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";
import {IShadowRouter} from "./interfaces/IShadowRouter.sol";
import {IShadowCLRouter} from "./interfaces/IShadowCLRouter.sol";

contract SiloV2LenderStrategy is Base4626Compounder, TradeFactorySwapper {

    using SafeERC20 for ERC20;

    enum SwapType {
        NULL,
        ATOMIC,
        AUCTION,
        TF
    }

    /// @notice Tick spacing for S to asset swaps on Shadow DEX
    int24 public sonicToAssetSwapTickSpacing;

    /// @notice Address for our reward token auction
    IAuction public auction;

    /// @notice Address for the Silo rewards distribution contract
    ISiloIncentivesController public incentivesController;

    /// @notice All reward tokens sold by this strategy by any metho
    address[] private allRewardTokens;

    /// @notice Names of reward programs to claim for this strategy
    string[] private programNames;

    /// @notice Mapping to be set by management for any reward tokens
    //          This can be used to set different mins for different tokens
    ///         or to set to uin256.max if selling a reward token is reverting
    mapping(address => uint256) public minAmountToSellMapping;

    /// @notice Mapping to be set by management for any reward tokens
    ///         Indicates the swap type for a given token.
    mapping(address => SwapType) public swapType;

    /// @notice Reward tokens that can be atomically sold
    address public constant SILO = 0x53f753E4B17F4075D6fa2c6909033d224b81e698;
    address public constant WRAPPED_S = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;

    /// @notice Address of the Shadow DEX V2 pools router on Sonic
    IShadowRouter public constant ROUTER = IShadowRouter(0x1D368773735ee1E678950B7A97bcA2CafB330CDc);

    /// @notice Address of the Shadow DEX CL pools router on Sonic
    IShadowCLRouter public constant CL_ROUTER = IShadowCLRouter(0x5543c6176FEb9B4b179078205d7C29EEa2e2d695);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _asset Underlying asset to use for this strategy.
    /// @param _name Name to use for this strategy. Ideally something human readable for a UI to use.
    /// @param _vault ERC4626 vault token to use. In Curve Lend, these are the base LP tokens.
    /// @param _incentivesController Address of the Silo rewards distribution contract.
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _incentivesController
    ) Base4626Compounder(_asset, _name, _vault) {
        incentivesController = ISiloIncentivesController(_incentivesController);
        require(incentivesController.share_token() == _vault, "!incentivesController");
        require(vault.asset() == _asset, "!vault");

        sonicToAssetSwapTickSpacing = 50;
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Claim rewards from all reward programs
    function managementClaimRewards() external onlyManagement {
        _claimRewards();
    }

    /// @notice Use to update our trade factory
    /// @dev Can only be called by management
    /// @param _tradeFactory Address of new trade factory
    function setTradeFactory(
        address _tradeFactory
    ) external onlyManagement {
        _setTradeFactory(_tradeFactory, address(asset));
    }

    /// @notice Sets tick spacing for S -> Asset swap
    /// @param _sonicToAssetSwapTickSpacing Tick spacing
    function setWethToAssetSwapTickSpacing(
        int24 _sonicToAssetSwapTickSpacing
    ) external onlyManagement {
        sonicToAssetSwapTickSpacing = _sonicToAssetSwapTickSpacing;
    }

    /// @notice Set the auction contract
    /// @param _auction The new auction contract
    function setAuction(
        IAuction _auction
    ) external onlyManagement {
        require(_auction.receiver() == address(this), "!receiver");
        require(_auction.want() == address(asset), "!want");
        auction = _auction;
    }

    /// @notice Set the Silo rewards distribution contract
    /// @param _incentivesController The new incentives controller
    function setIncentivesController(
        ISiloIncentivesController _incentivesController
    ) external onlyManagement {
        require(_incentivesController.share_token() == address(vault), "!incentivesController");
        incentivesController = _incentivesController;
    }

    /// @notice Set the swap type for a specific token
    /// @param _from The address of the token to set the swap type for
    /// @param _swapType The swap type to set
    function setSwapType(address _from, SwapType _swapType) external onlyManagement {
        require(_swapType != SwapType.NULL, "remove token instead");
        swapType[_from] = _swapType;
    }

    /// @notice Use to set the reward programs we claim rewards from
    /// @param _names Array of reward program names
    function setProgramNames(
        string[] memory _names
    ) external onlyManagement {
        programNames = _names;
    }

    /// @notice Set the `minAmountToSellMapping` for a specific `_token`
    /// @dev This can be used by management to adjust wether or not the
    ///      _claimAndSellRewards() function will attempt to sell a specific
    ///      reward token. This can be used if liquidity is to low, amounts
    ///      are to low or any other reason that may cause reverts.
    /// @param _token The address of the token to adjust.
    /// @param _amount Min required amount to sell.
    function setMinAmountToSellMapping(address _token, uint256 _amount) external onlyManagement {
        minAmountToSellMapping[_token] = _amount;
    }

    /// @notice Add a reward token to the strategy
    /// @param _token Address of the token to add
    /// @param _swapType The swap type for the token
    function addRewardToken(address _token, SwapType _swapType) external onlyManagement {
        require(_token != address(0) && _token != address(asset) && _token != address(vault), "!allowed");
        require(swapType[_token] == SwapType.NULL, "exists");
        require(_swapType != SwapType.NULL, "!swaptype");

        allRewardTokens.push(_token);
        swapType[_token] = _swapType;

        if (_swapType == SwapType.TF) _addToken(_token, address(asset));
    }

    /// @notice Remove a reward token from the strategy
    /// @param _token Address of the token to remove
    function removeRewardToken(
        address _token
    ) external onlyManagement {
        address[] memory _allRewardTokens = allRewardTokens;
        uint256 _length = _allRewardTokens.length;
        for (uint256 i = 0; i < _length; ++i) {
            if (_allRewardTokens[i] == _token) {
                allRewardTokens[i] = _allRewardTokens[_length - 1];
                allRewardTokens.pop();
            }
        }

        if (swapType[_token] == SwapType.TF) _removeToken(_token, address(asset));

        delete swapType[_token];
        delete minAmountToSellMapping[_token];
    }

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kicks off an auction, updating its status and making funds available for bidding
    /// @param _token The address of the token to be auctioned
    /// @return _available The available amount for bidding on in the auction
    function kickAuction(
        address _token
    ) external onlyKeepers returns (uint256) {
        require(swapType[_token] == SwapType.AUCTION, "!auction");

        uint256 _toAuction = ERC20(_token).balanceOf(address(this));
        require(_toAuction > 0, "!_toAuction");

        IAuction _auction = IAuction(auction);
        ERC20(_token).safeTransfer(address(_auction), _toAuction);
        return _auction.kick(_token);
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Get all incentive program names
    /// @return Array of program names
    function getAllProgramNames() external view returns (string[] memory) {
        return programNames;
    }

    /// @notice Get all reward tokens
    /// @return Array of reward tokens
    function getAllRewardTokens() external view returns (address[] memory) {
        return allRewardTokens;
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    /// @inheritdoc Base4626Compounder
    function _claimAndSellRewards() internal override {
        _claimRewards();

        address[] memory _allRewardTokens = allRewardTokens;
        uint256 _length = _allRewardTokens.length;
        for (uint256 i = 0; i < _length; ++i) {
            address _token = _allRewardTokens[i];
            SwapType _swapType = swapType[_token];
            uint256 _balance = ERC20(_token).balanceOf(address(this));
            if (_swapType == SwapType.ATOMIC && _balance > minAmountToSellMapping[_token]) {
                if (_token == SILO) _sellSiloForSonic();
                if (_token == WRAPPED_S) _sellSonicForUSDC();
            }
        }
    }

    /// @inheritdoc TradeFactorySwapper
    function _claimRewards() internal override {
        string[] memory _programNames = programNames;
        if (_programNames.length > 0) incentivesController.claimRewards(address(this), _programNames);
    }

    // ===============================================================
    // Shadow DEX helpers
    // ===============================================================

    function _sellSiloForSonic() internal {
        uint256 _balance = ERC20(SILO).balanceOf(address(this));
        if (_balance > 0) {
            ERC20(SILO).forceApprove(address(ROUTER), _balance);
            IShadowRouter.route[] memory _routes = new IShadowRouter.route[](1);
            _routes[0] = IShadowRouter.route({from: SILO, to: WRAPPED_S, stable: false});
            ROUTER.swapExactTokensForTokens(
                _balance,
                0, // minAmountOut
                _routes,
                address(this), // to
                block.timestamp // deadline
            );
        }
    }

    function _sellSonicForUSDC() internal {
        uint256 _balance = ERC20(WRAPPED_S).balanceOf(address(this));
        if (_balance > 0) {
            ERC20(WRAPPED_S).forceApprove(address(CL_ROUTER), _balance);
            CL_ROUTER.exactInputSingle(
                IShadowCLRouter.ExactInputSingleParams({
                    tokenIn: WRAPPED_S,
                    tokenOut: address(asset),
                    tickSpacing: sonicToAssetSwapTickSpacing,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: _balance,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        }
    }

}
