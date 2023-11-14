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
    IUniswapV2Pair public pair =
        IUniswapV2Pair(0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5);
    IUniswapV2Router public router =
        IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address public bob;
    address public manager;

    uint256 public slippage = 30;

    function setUp() public {
        ethFork = vm.createFork(GOERLI_RPC_URL);
        vm.selectFork(ethFork);

        vault = new UniswapV2ERC4626(
            name,
            symbol,
            pairToken,
            dai,
            usdc,
            router,
            pair,
            slippage
        );
        bob = address(0x1);
        manager = msg.sender;

        deal(address(dai), bob, ONE_THOUSAND_E18 * 2);
        deal(address(usdc), bob, 1000e6 * 2);
    }

    function testDepositMath() public {
        uint256 uniLpRequest = 887_226_683_879_712;

        vm.startPrank(bob);

        (uint256 assets0, uint256 assets1) = vault.getAssetsAmounts(
            uniLpRequest
        );

        /// This returns min amount of LP, therefore can differ from the requested amount
        uint256 poolAmount = vault.getLiquidityAmountOutFor(assets0, assets1);

        console.log("poolAmount: %s", poolAmount);
        console.log("assets0: %s", assets0);
        console.log("assets1: %s", assets1);
    }
}
