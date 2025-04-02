// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface ISwapper {

    function toSonic() external view returns (bool);
    function swapRewards() external;

}
