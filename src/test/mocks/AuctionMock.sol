// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IAuction} from "../../interfaces/IAuction.sol";

contract AuctionMock is IAuction {

    address private _want;
    address private _receiver;

    constructor(address want_, address receiver_) {
        _want = want_;
        _receiver = receiver_;
    }

    function setWant(
        address want_
    ) external {
        _want = want_;
    }

    function setReceiver(
        address receiver_
    ) external {
        _receiver = receiver_;
    }

    function want() external view returns (address) {
        return _want;
    }

    function receiver() external view returns (address) {
        return _receiver;
    }

    function kick(
        address /*_token*/
    ) external pure returns (uint256) {
        return 0;
    }

}
