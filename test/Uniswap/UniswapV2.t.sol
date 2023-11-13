// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {UniswapV2ERC4626} from "../../src/providers//Uniswap/no-swap/UniswapV2ERC4626.sol";
import {IUniswapV2Pair} from "../../src/interfaces/Uniswap/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "../../src/interfaces/Uniswap/IUniswapV2Router.sol";

contract UniswapV2Test is Test {
    uint256 public ethFork;
    uint256 public immutable ONE_THOUSAND_E18 = 1000 ether;
    uint256 public immutable HUNDRED_E18 = 100 ether;
    uint256 public immutable ONE_E18 = 1 ether;

    using FixedPointMathLib for uint256;

    string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");

    UniswapV2ERC4626 public vault;

    string name = "UniV2ERC4626Wrapper";
    string symbol = "UFC4626";
    ERC20 public dai = ERC20(0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60);
    ERC20 public usdc = ERC20(0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C);
    ERC20 public pairToken = ERC20(0x993b6502813b5A58ED7Aa39EbF121540076cbFD1);
    IUniswapV2Pair public pair = IUniswapV2Pair()
}
