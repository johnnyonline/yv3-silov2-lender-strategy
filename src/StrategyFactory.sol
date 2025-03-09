// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {SiloV2LenderStrategy} from "./Strategy.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract StrategyFactory {

    event NewStrategy(address indexed strategy, address indexed asset);

    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    /// @notice Track the deployments. asset => pool => strategy
    mapping(address => address) public deployments;

    constructor(address _management, address _performanceFeeRecipient, address _keeper, address _emergencyAdmin) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    /// @notice Deploy a new Strategy
    /// @param _asset The underlying asset for the strategy to use
    /// @param _name Name to use for this strategy. Ideally something human readable for a UI to use
    /// @param _vault Silo ERC4626 vault share token to use
    /// @param _siloIncentivesController Address of the Silo rewards distribution contract
    /// @return . The address of the new strategy
    function newStrategy(
        address _asset,
        string calldata _name,
        address _vault,
        address _siloIncentivesController
    ) external virtual returns (address) {
        IStrategyInterface _newStrategy =
            IStrategyInterface(address(new SiloV2LenderStrategy(_asset, _name, _vault, _siloIncentivesController)));

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _asset);

        deployments[_asset] = address(_newStrategy);
        return address(_newStrategy);
    }

    function setAddresses(address _management, address _performanceFeeRecipient, address _keeper) external {
        require(msg.sender == management, "!management");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        address _asset = IStrategyInterface(_strategy).asset();
        return deployments[_asset] == _strategy;
    }

}
