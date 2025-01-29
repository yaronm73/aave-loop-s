// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ISwapRouter} from "@uniswap/contracts/interfaces/ISwapRouter.sol";

contract MockSwapRouter is ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256 amountOut) {
        return params.amountIn;
    }

    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        return params.amountIn;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata) external payable override returns (uint256) {
        return 0;
    }

    function exactOutput(ExactOutputParams calldata) external payable override returns (uint256) {
        return 0;
    }

    // Placeholder for other required ISwapRouter functions
    function uniswapV3SwapCallback(int256, int256, bytes calldata) external override {}
}
