// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface ISiloIncentivesController {

    struct IncentiveProgramDetails {
        uint256 index;
        address rewardToken;
        uint104 emissionPerSecond;
        uint40 lastUpdateTimestamp;
        uint40 distributionEnd;
    }

    function share_token() external view returns (address);
    function claimRewards(address _to, string[] calldata _programNames) external;
    function getAllProgramsNames() external view returns (string[] memory programsNames);
    function incentivesProgram(
        string calldata _incentivesProgram
    ) external view returns (IncentiveProgramDetails memory details);

}
