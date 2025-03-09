// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface ISiloIncentivesController {
    function share_token() external view returns (address);
    function claimRewards(address _to, string[] _programNames) external;
}