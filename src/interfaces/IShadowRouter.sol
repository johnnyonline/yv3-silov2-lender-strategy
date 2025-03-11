// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IShadowRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

}
