// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";

import {IAuction} from "./interfaces/IAuction.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";

contract SiloV2LenderStrategy is Base4626Compounder, TradeFactorySwapper {

    using SafeERC20 for ERC20;

    enum SwapType {
        NULL,
        ATOMIC,
        AUCTION,
        TF
    }

    /// @notice Address for our reward token auction
    IAuction public auction;

    /// @notice Address for the Silo rewards distribution contract.
    ISiloIncentivesController public immutable siloIncentivesController;

    /// @notice All reward tokens sold by this strategy by any method.
    address[] public allRewardTokens;

    /// @notice Names of reward programs to claim for this strategy
    string[] internal programNames; // @todo: Add public view getter for this

    /// @notice Mapping to be set by management for any reward tokens.
    //          This can be used to set different mins for different tokens
    ///         or to set to uin256.max if selling a reward token is reverting
    mapping(address => uint256) public minAmountToSellMapping;

    /// @notice Mapping to be set by management for any reward tokens.
    ///         Indicates the swap type for a given token.
    mapping(address => SwapType) public swapType;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _asset Underlying asset to use for this strategy.
    /// @param _name Name to use for this strategy. Ideally something human readable for a UI to use.
    /// @param _vault ERC4626 vault token to use. In Curve Lend, these are the base LP tokens.
    /// @param _siloIncentivesController Address of the Silo rewards distribution contract.
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _siloIncentivesController
    ) Base4626Compounder(_asset, _name, _vault) {
        siloIncentivesController = ISiloIncentivesController(_siloIncentivesController);
        assert(siloIncentivesController.share_token() == _vault, "!incentivesController");
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Claim rewards from all reward programs
    function managementClaimRewards() external onlyManagement {
        _claimRewards();
    }

    /// @notice Add a reward token to the strategy
    /// @param _token Address of the token to add
    /// @param _swapType The swap type for the token
    function addRewardToken(address _token, SwapType _swapType) external onlyManagement {
        require(_token != address(asset) && _token != address(vault), "!allowed");
        require(swapType[_token] == SwapType.NULL, "exists");
        require(_swapType != SwapType.NULL, "null");

        allRewardTokens.push(_token);
        swapType[_token] = _swapType;

        if (_swapType == SwapType.TF) _addToken(_token, address(asset));
    }

    // @todo -- make sure this works
    /// @notice Remove a reward token from the strategy
    /// @param _token Address of the token to remove
    function removeRewardToken(
        address _token
    ) external onlyManagement {
        address[] memory _allRewardTokens = allRewardTokens;
        uint256 _length = _allRewardTokens.length;
        bool _found = false;
        for (uint256 i = 0; i < _length; ++i) {
            if (_allRewardTokens[i] == _token) {
                allRewardTokens[i] = _allRewardTokens[_length - 1];
                allRewardTokens.pop();
                _found = true;
            }
        }
        require(_found, "!found");

        if (swapType[_token] == SwapType.TF) _removeToken(_token, address(asset));

        delete swapType[_token];
        delete minAmountToSellMapping[_token];
    }

    /// @notice Use to update our trade factory
    /// @dev Can only be called by management
    /// @param _tradeFactory Address of new trade factory
    function setTradeFactory(
        address _tradeFactory
    ) external onlyManagement {
        _setTradeFactory(_tradeFactory, address(asset));
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

    /// @notice Set the swap type for a specific token
    /// @param _from The address of the token to set the swap type for
    /// @param _swapType The swap type to set
    function setSwapType(
        address _from,
        SwapType _swapType
    ) external onlyManagement {
        require(_swapType != SwapType.NULL, "remove token instead");
        swapType[_from] = _swapType;
    }

    // @todo -- make sure names are correct
    /// @notice Use to set the reward programs we claim rewards from
    /// @param _names Array of reward program names
    function setProgramNames(
        string[] calldata _names
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

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /**
     * @notice Kicks off an auction, updating its status and making funds available for bidding.
     * @param _from The address of the token to be auctioned.
     * @return _available The available amount for bidding on in the auction.
     */
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

    /// @inheritdoc Base4626Compounder
    function balanceOfStake() public view virtual override returns (uint256) {
        return 0;
    }

    // ===============================================================
    // Mutative functions
    // ===============================================================

    /// @inheritdoc Base4626Compounder
    function _stake() internal virtual override {
        return;
    }

    /// @inheritdoc Base4626Compounder
    function _unStake(
        uint256 /* _amount */
    ) internal virtual override {
        return;
    }

    /// @inheritdoc Base4626Compounder
    function _claimAndSellRewards() internal override {
        _claimRewards();

        address[] memory _allRewardTokens = allRewardTokens;
        uint256 _length = _allRewardTokens.length;
        for (uint256 i = 0; i < _length; ++i) {
            address _token = _allRewardTokens[i];
            SwapType _swapType = swapType[_token];
            uint256 _balance = ERC20(_token).balanceOf(address(this));
            if (_swapType == SwapType.ATOMIC && _balance > minAmountToSellMapping[_token]) return;
            // @todo: add swap logic on Shadow similar to FP's Aerodrome on Moonwell
            // SILO => S (V2 pool), S => USDC.e (CL pool)
            // https://github.com/fp-crypto/yearn-v3-levfarming-strategy/blob/levmoonwell/src/LevMoonwellStrategy.sol
        }
    }

    /// @inheritdoc TradeFactorySwapper
    function _claimRewards() internal override {
        string[] memory _programNames = programNames;
        if (_programNames.length > 0) siloIncentivesController.claimRewards(address(this), _programNames);
    }

}
