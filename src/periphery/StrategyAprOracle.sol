// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloLens} from "../interfaces/ISiloLens.sol";
import {ISilo, IERC20Metadata} from "../interfaces/ISilo.sol";

contract SiloV2LenderStrategyAprOracle is AprOracleBase {

    mapping(address rewardAsset => AggregatorV3Interface oracle) public oracles;

    uint256 private constant _PRECISION = 1e18;
    uint256 private constant _SCALE_TO_PRECISION = 1e3;
    uint256 private constant _SECONDS_IN_YEAR = 60 * 60 * 24 * 365;

    ISiloLens public immutable SILO_LENS;

    // ===============================================================
    // Constructor
    // ===============================================================

    constructor(
        address _governance,
        address _siloLens
    ) AprOracleBase("Silo V2 Lender Strategy APR Oracle", _governance) {
        SILO_LENS = ISiloLens(_siloLens);
    }

    // ===============================================================
    // Mutative functions
    // ===============================================================

    /// @notice Set the oracle for a reward asset
    /// @param _oracle The oracle to set
    /// @param _asset The asset to set the oracle for
    function setRewardAssetPriceOracle(AggregatorV3Interface _oracle, address _asset) external onlyGovernance {
        (, int256 _rewardPrice,, uint256 _updatedAt,) = _oracle.latestRoundData();
        if (_rewardPrice <= 0 || (block.timestamp - _updatedAt) > 1 days) revert("!oracle");
        oracles[_asset] = _oracle;
        emit RewardAssetPriceOracleSet(_oracle, _asset);
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /**
     * @notice Will return the expected Apr of a strategy post a debt change.
     * @dev _delta is a signed integer so that it can also represent a debt
     * decrease.
     *
     * This should return the annual expected return at the current timestamp
     * represented as 1e18.
     *
     *      ie. 10% == 1e17
     *
     * _delta will be == 0 to get the current apr.
     *
     * This will potentially be called during non-view functions so gas
     * efficiency should be taken into account.
     *
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return . The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta) external view override returns (uint256) {
        IStrategyInterface _strategy = IStrategyInterface(_strategy);
        ISilo _silo = ISilo(_strategy.vault());
        uint256 _totalAssets = _silo.getCollateralAssets();
        if (_totalAssets == 0) return 0;
        if (_delta < 0) require(uint256(_delta * -1) < _totalAssets, "delta exceeds deposits");
        uint256 _totalAssetsAfterDelta = uint256(int256(_totalAssets) + _delta);
        return _lendAPR(_silo, _totalAssetsAfterDelta) + _rewardAPR(_strategy, _silo, _totalAssetsAfterDelta);
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    function _lendAPR(ISilo _silo, uint256 _totalAssetsAfterDelta) internal view returns (uint256 _apr) {
        ISiloConfig.ConfigData memory _cfg = _silo.config().getConfig((address(_silo)));
        _apr = SILO_LENS.getBorrowAPR(_silo) * _silo.getDebtAssets() / _totalAssetsAfterDelta;
        _apr = _apr * (_PRECISION - _cfg.daoFee - _cfg.deployerFee) / _PRECISION;
    }

    function _rewardAPR(
        IStrategyInterface _strategy,
        ISilo _silo,
        uint256 _totalAssetsAfterDelta
    ) internal view returns (uint256 _apr) {
        uint256 _sharePrecision = 10 ** _silo.decimals();
        uint256 _assetPrecision = 10 ** IERC20Metadata(_strategy.asset()).decimals();
        uint256 _totalSupplyAfterDelta =
            _silo.convertToAssets(_sharePrecision) * _totalAssetsAfterDelta / _assetPrecision;

        ISiloIncentivesController _incentivesController = _strategy.incentivesController();
        string[] memory _programs = _strategy.getAllProgramNames();
        uint256 _length = _programs.length;
        for (uint256 i = 0; i < _length; ++i) {
            ISiloIncentivesController.IncentiveProgramDetails memory _program =
                _incentivesController.incentivesProgram(_programs[i]);
            if (_program.distributionEnd <= block.timestamp || _program.emissionPerSecond == 0) continue;
            (uint256 _rewardPrice, uint256 _rewardOracleDecimals) = _getPrice(_program.rewardToken);
            _apr += _program.emissionPerSecond * _SECONDS_IN_YEAR * _assetPrecision / _totalSupplyAfterDelta
                * _rewardPrice / (10 ** _rewardOracleDecimals);
        }
    }

    function _getPrice(
        address _asset
    ) internal view returns (uint256, uint256) {
        AggregatorV3Interface _oracle = oracles[_asset];
        if (address(_oracle) == address(0)) return (0, 0);
        (, int256 _price,, uint256 _updatedAt,) = _oracle.latestRoundData();
        if (_price <= 0 || (block.timestamp - _updatedAt) > 1 days) revert("!oracle");
        return (uint256(_price), _oracle.decimals());
    }

    // ===============================================================
    // Events
    // ===============================================================

    event RewardAssetPriceOracleSet(AggregatorV3Interface _oracle, address _asset);

}
