// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IShadowRouter {

    struct route {
        /// @dev token from
        address from;
        /// @dev token to
        address to;
        /// @dev is stable route
        bool stable;
    }

    /// @param amountIn amount to send ideally
    /// @param amountOutMin slippage of amount out
    /// @param routes the hops the swap should take
    /// @param to the address the liquidity tokens should be minted to
    /// @param deadline timestamp deadline
    /// @return amounts amounts returned
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

}
