// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {ISilo} from "./ISilo.sol";

interface ISiloLens {

    function getBorrowAPR(
        ISilo _silo
    ) external view returns (uint256 borrowAPR);

}
