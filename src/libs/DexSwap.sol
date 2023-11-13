// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPair} from "../interfaces/Uniswap/IPair.sol";

library DexSwap {
    using SafeTransferLib for ERC20;

    /**
     * @notice Swap directly through a Pair
     * @param amountIn input amount
     * @param fromToken address
     * @param toToken address
     * @param pairToken used for swap
     * @return output amount
     */
    function swap(
        uint256 amountIn,
        address fromToken,
        address toToken,
        address pairToken
    ) internal returns (uint256) {
        IPair pair = IPair(pairToken);
        (address token0, ) = sortTokens(fromToken, toToken);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        if (token0 != fromToken) (reserve0, reserve1) = (reserve1, reserve0);
        uint256 amountOut1 = 0;
        uint256 amountOut2 = getAmountOut(amountIn, reserve0, reserve1);
        if (token0 != fromToken) {
            (amountOut1, amountOut2) = (amountOut2, amountOut1);
        }
        ERC20(fromToken).safeTransfer(address(pair), amountIn);
        pair.swap(amountOut1, amountOut2, address(this), new bytes(0));
        return amountOut2 > amountOut1 ? amountOut2 : amountOut1;
    }

    /**
     * @notice Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
     * @dev Assumes swap fee is 0.30%
     * @param amountIn input amount
     * @param reserveIn reserves of the input asset
     * @param reserveOut reserves of the output asset
     * @return maximum output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Sorts two tokens addresses
     * @param tokenA  address
     * @param tokenB  address
     * @return sorted token addresses
     */

    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
