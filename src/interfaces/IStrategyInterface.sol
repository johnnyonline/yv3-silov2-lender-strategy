// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

import {ISiloIncentivesController} from "./ISiloIncentivesController.sol";
import {ISilo} from "./ISilo.sol";

interface IStrategyInterface is IStrategy {

    function vault() external view returns (ISilo);
    function incentivesController() external view returns (ISiloIncentivesController);
    function getAllProgramNames() external view returns (string[] memory);
    function setUseAuction(
        bool _useAuction
    ) external;

}
