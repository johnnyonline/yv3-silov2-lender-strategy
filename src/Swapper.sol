// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IShadowRouter} from "./interfaces/IShadowRouter.sol";
import {IShadowCLRouter} from "./interfaces/IShadowCLRouter.sol";

contract Swapper is Ownable2Step {

    using SafeERC20 for IERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Tick spacing for Sonic to USDC swaps
    int24 public sonicToUsdcSwapTickSpacing;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice Reward tokens on Sonic to swap
    IERC20 public constant USDC = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
    IERC20 public constant SILO = IERC20(0x53f753E4B17F4075D6fa2c6909033d224b81e698);
    IERC20 public constant WRAPPED_S = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    /// @notice Address of the Shadow DEX V2 pools router on Sonic
    IShadowRouter public constant ROUTER = IShadowRouter(0x1D368773735ee1E678950B7A97bcA2CafB330CDc);

    /// @notice Address of the Shadow DEX CL pools router on Sonic
    IShadowCLRouter public constant CL_ROUTER = IShadowCLRouter(0x5543c6176FEb9B4b179078205d7C29EEa2e2d695);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _management The management address
    /// @param _sonicToUsdcSwapTickSpacing The tick spacing for Sonic to USDC swaps
    constructor(address _management, int24 _sonicToUsdcSwapTickSpacing) {
        _transferOwnership(_management);
        sonicToUsdcSwapTickSpacing = _sonicToUsdcSwapTickSpacing;
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Set the tick spacing for Sonic to USDC swaps
    /// @param _sonicToUsdcSwapTickSpacing The tick spacing to set
    function setSwapTickSpacing(
        int24 _sonicToUsdcSwapTickSpacing
    ) external onlyOwner {
        sonicToUsdcSwapTickSpacing = _sonicToUsdcSwapTickSpacing;
    }

    /// @notice Sweep tokens from the contract
    /// @dev This contract should never hold any tokens
    /// @param _token The token to sweep
    function sweep(
        IERC20 _token
    ) external onlyOwner {
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance > 0) _token.safeTransfer(owner(), _balance);
    }

    // ===============================================================
    // Mutative functions
    // ===============================================================

    /// @notice Swap SILO and Sonic rewards for USDC
    /// @dev The USDC is sent directly to the caller in `_swapSonicForUSDC`
    function swapRewards() external {
        uint256 _balance = SILO.balanceOf(msg.sender);
        if (_balance > 0) {
            SILO.safeTransferFrom(msg.sender, address(this), _balance);
            _swapSiloForSonic(_balance);
        }

        _balance = WRAPPED_S.balanceOf(msg.sender);
        if (_balance > 0) WRAPPED_S.safeTransferFrom(msg.sender, address(this), _balance);

        _balance = WRAPPED_S.balanceOf(address(this));
        if (_balance > 0) _swapSonicForUSDC(_balance); // dev: USDC is sent to msg.sender
    }

    // ===============================================================
    // Shadow DEX helpers
    // ===============================================================

    function _swapSiloForSonic(
        uint256 _balance
    ) internal {
        SILO.forceApprove(address(ROUTER), _balance);
        IShadowRouter.route[] memory _routes = new IShadowRouter.route[](1);
        _routes[0] = IShadowRouter.route({from: address(SILO), to: address(WRAPPED_S), stable: false});
        ROUTER.swapExactTokensForTokens(
            _balance,
            0, // minAmountOut
            _routes,
            address(this), // to
            block.timestamp // deadline
        );
    }

    function _swapSonicForUSDC(
        uint256 _balance
    ) internal {
        WRAPPED_S.forceApprove(address(CL_ROUTER), _balance);
        CL_ROUTER.exactInputSingle(
            IShadowCLRouter.ExactInputSingleParams({
                tokenIn: address(WRAPPED_S),
                tokenOut: address(USDC),
                tickSpacing: sonicToUsdcSwapTickSpacing,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _balance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

}
