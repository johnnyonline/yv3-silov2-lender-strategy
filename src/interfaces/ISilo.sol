// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ISiloConfig} from "./ISiloConfig.sol";

interface ISilo is IERC4626 {

    function config() external view returns (ISiloConfig siloConfig);
    function getDebtAssets() external view returns (uint256 totalDebtAssets);
    function getLiquidity() external view returns (uint256 liquidity);
    function maxRepayShares(address _borrower) external view returns (uint256 shares);
    function previewRepayShares(uint256 _shares) external view returns (uint256 assets);
    function borrow(uint256 _assets, address _receiver, address _borrower) external returns (uint256 shares);
    function repayShares(uint256 _shares, address _borrower) external returns (uint256 assets);
    function accrueInterest() external returns (uint256 accruedInterest);

}
