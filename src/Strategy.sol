// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";

import {IAuction} from "./interfaces/IAuction.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";

contract SiloV2LenderStrategy is Base4626Compounder {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Flag to enable/disable the use of the auction contract. If false, the strategy will use the `Swapper` to sell rewards
    bool public useAuction;

    /// @notice Address for the auction contract
    IAuction public auction;

    /// @notice Address for the Silo rewards distribution contract
    ISiloIncentivesController public incentivesController;

    /// @notice Names of reward programs to claim from the Silo rewards distribution contract
    string[] private programNames;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice Address of the Swapper contract. Used to swap S and SILO rewards for the strategy's asset
    ISwapper public immutable SWAPPER;

    /// @notice Reward tokens on Sonic that can be atomically sold using Shadow DEX
    ERC20 private constant SILO = ERC20(0x53f753E4B17F4075D6fa2c6909033d224b81e698);
    ERC20 private constant WRAPPED_S = ERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _asset Underlying asset to use for this strategy
    /// @param _name Name to use for this strategy. Ideally something human readable for a UI to use
    /// @param _vault ERC4626 vault token to use. Silo's share token one recieves on borrowable deposits
    /// @param _incentivesController Address of the Silo rewards distribution contract
    /// @param _swapper Address of the Swapper contract
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _incentivesController,
        address _swapper
    ) Base4626Compounder(_asset, _name, _vault) {
        incentivesController = ISiloIncentivesController(_incentivesController);
        require(incentivesController.share_token() == _vault, "!incentivesController");
        require(vault.asset() == _asset, "!vault");

        SWAPPER = ISwapper(_swapper);

        SILO.forceApprove(address(_swapper), type(uint256).max);
        WRAPPED_S.forceApprove(address(_swapper), type(uint256).max);
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Set the flag to enable/disable the use of the auction contract
    /// @param _useAuction True to enable the auction contract, false to disable
    function setUseAuction(
        bool _useAuction
    ) external onlyManagement {
        useAuction = _useAuction;
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

    /// @notice Set the reward programs we claim rewards from
    /// @param _names Array of reward program names
    function setProgramNames(
        string[] memory _names
    ) external onlyManagement {
        programNames = _names;
    }

    // ===============================================================
    // Keeper functions
    // ===============================================================

    /// @notice Kicks off an auction, updating its status and making funds available for bidding
    /// @param _token The address of the token to be auctioned
    /// @return The available amount for bidding on in the auction
    function kickAuction(
        address _token
    ) external onlyKeepers returns (uint256) {
        require(_token != address(asset) && _token != address(vault), "!_token");
        require(useAuction, "!useAuction");

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
    function getAllProgramNames() public view returns (string[] memory) {
        return programNames;
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    /// @inheritdoc Base4626Compounder
    function _unStake(
        uint256 /* _amount */
    ) internal override {
        ISilo(address(vault)).accrueInterest();
    }

    /// @inheritdoc Base4626Compounder
    function _claimAndSellRewards() internal override {
        string[] memory _programNames = getAllProgramNames();
        if (_programNames.length > 0) incentivesController.claimRewards(address(this), _programNames);
        if (!useAuction) SWAPPER.swapRewards();
    }

}
