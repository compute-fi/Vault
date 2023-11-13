// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StETHERC4626} from "../../src/providers/Lido/stETH.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ICurve} from "../../src/interfaces/Lido/ICurve.sol";
import {IStETH} from "../../src/interfaces/Lido/IStETH.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {wstETH} from "../../src/interfaces/Lido/wstETH.sol";

contract stEthTest is Test {
    uint256 public ethFork;
    uint256 public immutable ONE_THOUSAND_E18 = 1000 ether;
    uint256 public immutable HUNDRED_E18 = 100 ether;

    using FixedPointMathLib for uint256;

    string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");

    StETHERC4626 public vault;

    address public weth = 0x0B1ba0af832d7C05fD64161E0Db78E85978E8082;
    address public stEth = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;

    address public bob;
    address public manager;

    IWETH public _weth = IWETH(weth);
    IStETH public _stEth = IStETH(stEth);

    function setUp() public {
        ethFork = vm.createFork(GOERLI_RPC_URL);
        vm.selectFork(ethFork);

        vault = new StETHERC4626(weth, stEth);
        bob = address(0x1);
        manager = msg.sender;

        deal(weth, bob, ONE_THOUSAND_E18);
        deal(weth, manager, ONE_THOUSAND_E18);
    }

    function testDepositWithdraw() public {
        uint256 bobUnderlyingAmount = HUNDRED_E18;

        vm.startPrank(bob);

        _weth.approve(address(vault), bobUnderlyingAmount);
        assertEq(_weth.allowance(bob, address(vault)), bobUnderlyingAmount);

        uint256 expectedSharesFromAssets = vault.previewDeposit(
            bobUnderlyingAmount
        );
        uint256 bobShareAmount = vault.deposit(bobUnderlyingAmount, bob);

        assertEq(expectedSharesFromAssets, bobShareAmount);
        console.log("bob shares: %s", bobShareAmount);

        uint256 bobAssetsFromShares = vault.previewRedeem(bobShareAmount);
        console.log("bob assets from shares: %s", bobAssetsFromShares);

        vault.withdraw(bobAssetsFromShares, bob, bob);
    }
}
