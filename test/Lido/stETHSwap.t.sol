// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StETHERC4626Swap} from "../../src/providers/Lido/stETHSwap.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

import {ICurve} from "../../src/interfaces/Lido/ICurve.sol";
import {IStETH} from "../../src/interfaces/Lido/IStETH.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {wstETH} from "../../src/interfaces/Lido/wstETH.sol";

contract stEthSwapTest is Test {
    uint256 public ethFork;
    uint256 public immutable ONE_THOUSAND_E18 = 1000 ether;
    uint256 public immutable HUNDRED_E18 = 100 ether;

    using FixedPointMathLib for uint256;

    string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");

    StETHERC4626Swap public vault;

    address public weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address public stEth = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
    address public wstEth = 0x6320cD32aA674d2898A68ec82e869385Fc5f7E2f;
    address public curvePool = 0xCEB67769c63cfFc6C8a6c68e85aBE1Df396B7aDA;

    address public alice;
    address public bob;
    address public manager;

    IWETH public _weth = IWETH(weth);
    IStETH public _stEth = IStETH(stEth);
    ICurve public _curvePool = ICurve(curvePool);
    IERC721 dyNFT = IERC721(0xf5D7ef8A011AA683306ff237F26589a658Bce6fF);

    function setUp() public {
        ethFork = vm.createFork(GOERLI_RPC_URL);
        vm.selectFork(ethFork);
        alice = address(0x1);
        bob = address(0x2);
        manager = msg.sender;

        vault = new StETHERC4626Swap(weth, stEth, curvePool, manager, dyNFT);
        console.log("vault address: %s", address(vault));

        deal(weth, alice, ONE_THOUSAND_E18);
        deal(weth, bob, ONE_THOUSAND_E18);
        deal(weth, manager, ONE_THOUSAND_E18);
    }

    function testDepositWithdraw() public {
        uint256 aliceUnderlyingAmount = HUNDRED_E18;
        uint256 bobUnderlyingAmount = 1000;

        vm.startPrank(bob);
        _weth.approve(address(vault), bobUnderlyingAmount);
        vault.deposit(bobUnderlyingAmount, bob);
        vm.stopPrank();

        vm.startPrank(alice);

        _weth.approve(address(vault), aliceUnderlyingAmount);
        assertEq(_weth.allowance(alice, address(vault)), aliceUnderlyingAmount);

        uint256 aliceShareAmount = vault.deposit(aliceUnderlyingAmount, alice);
        console.log("alice shares: %s", aliceShareAmount);

        uint256 aliceAssetsFromShares = vault.convertToAssets(aliceShareAmount);
        console.log("alice assets from shares: %s", aliceAssetsFromShares);

        vault.withdraw(aliceAssetsFromShares, alice, alice);
    }
}
