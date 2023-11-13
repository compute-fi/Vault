// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {IUniswapV2Pair} from "../../../interfaces/Uniswap/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "../../../interfaces/Uniswap/IUniswapV2Router.sol";
import {UniswapV2ERC4626Swap} from "./UniswapV2ERC4626Swap.sol";

import {IUniswapV3Factory} from "../../../interfaces/Uniswap/IUniswapV3.sol";
import {IUniswapV3Pool} from "../../../interfaces/Uniswap/IUniswapV3.sol";

import {ErrorsLib} from "../../../libs/ErrorsLib.sol";

/// @title UniswapV2ERC4626PoolFactory
/// @notice Uniswap V2 ERC4626 Pool Factory for instant deployment of adapter for two tokens for the pair
/// @notice Use for stress-free deployment of an adapter for a single uniswap v2 pair.

contract UniswapV2ERC4626PoolFactory {
    /* ========== Libraries ========== */
    IUniswapV2Router router;
    IUniswapV3Factory oracleFactory;

    /* ========== Constructor ========== */
    constructor(IUniswapV2Router router_, IUniswapV3Factory oracleFactory_) {
        router = router_;
        oracleFactory = oracleFactory_;
    }

    /* ========== External Functions ========== */
    function create(
        IUniswapV2Pair pair_,
        uint24 fee_
    )
        external
        returns (
            UniswapV2ERC4626Swap v0,
            UniswapV2ERC4626Swap v1,
            address oracle
        )
    {
        /// @dev Tokens sorted by UniswapV2Pair
        ERC20 token0 = ERC20(pair_.token0());
        ERC20 token1 = ERC20(pair_.token1());

        /// @dev Each UniV3 Pool is a twap oracle
        if (
            (oracle = twap(address(token0), address(token1), fee_)) ==
            address(0)
        ) revert ErrorsLib.TWAP_NON_EXISTENT();

        IUniswapV3Pool oracle_ = IUniswapV3Pool(oracle);

        /// @dev For uniswap V2 only two tokens pool
        /// @dev using symbol for naming to keep it short
        string memory name0 = string(
            abi.encodePacked("UniV2-", token0.symbol(), "-ERC4626")
        );
        string memory name1 = string(
            abi.encodePacked("UniV2-", token1.symbol(), "-ERC4626")
        );
        string memory symbol0 = string(
            abi.encodePacked("UniV2-", token0.symbol())
        );
        string memory symbol1 = string(
            abi.encodePacked("UniV2-", token1.symbol())
        );

        /// @dev For Uniswap V2 only two tokens pool
        v0 = new UniswapV2ERC4626Swap(
            token0,
            name0,
            symbol0,
            router,
            pair_,
            oracle_
        );

        v1 = new UniswapV2ERC4626Swap(
            token1,
            name1,
            symbol1,
            router,
            pair_,
            oracle_
        );
    }

    function twap(
        address token0_,
        address token1_,
        uint24 fee_
    ) public view returns (address) {
        return oracleFactory.getPool(token0_, token1_, fee_);
    }
}
