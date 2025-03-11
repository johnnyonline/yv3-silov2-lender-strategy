// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ISiloConfig} from "./ISiloConfig.sol";

interface ISilo is IERC4626 {

    function config() external view returns (ISiloConfig siloConfig);
    function getDebtAssets() external view returns (uint256 totalDebtAssets);
    function accrueInterest() external returns (uint256 accruedInterest);

}
