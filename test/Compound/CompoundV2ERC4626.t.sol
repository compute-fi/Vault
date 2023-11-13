// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {CompoundV2ERC4626} from "../../src/providers/Compound/CompoundV2ERC4626.sol";
import {ICERC20} from "../../src/interfaces/Compound/ICERC20.sol";
import {IComptroller} from "../../src/interfaces/Compound/IComptroller.sol";

contract CompoundV2ERC4626Test is Test {
    uint256 public ethFork;
    uint256 public immutable ONE_THOUSAND_E18 = 1000 ether;
    uint256 public immutable HUNDRED_E18 = 100 ether;

    address public bob;

    string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");
    string ETH_RPC_URL = vm.envString("ETHEREUM_RPC_URL");

    CompoundV2ERC4626 public vault;

    // Goerli

    ERC20 public asset = ERC20(0x2899a03ffDab5C90BADc5920b4f53B0884EB13cC);
    ERC20 public reward = ERC20(0x3587b2F7E0E2D6166d6C14230e7Fe160252B0ba4);
    ICERC20 public cToken = ICERC20(0x0545a8eaF7ff6bB6F708CbB544EA55DBc2ad7b2a);
    IComptroller public comptroller =
        IComptroller(0x3cBe63aAcF6A064D32072a630A3eab7545C54d78);
    address public weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    // Mainnet

    // ERC20 public asset = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // ERC20 public reward = ERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    // ICERC20 public cToken = ICERC20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    // IComptroller public comptroller =
    //     IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    // address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        ethFork = vm.createFork(GOERLI_RPC_URL);
        vm.selectFork(ethFork);
        vault = new CompoundV2ERC4626(
            asset,
            reward,
            cToken,
            comptroller,
            address(this)
        );
        vault.setRoute(3000, weth, 3000);
        console.log("vault address: %s", address(vault));
        bob = address(0x1);
        deal(address(asset), bob, ONE_THOUSAND_E18);
    }

    function testDepositWithdraw() public {
        uint256 amount = HUNDRED_E18;

        vm.startPrank(bob);

        uint256 bobUnderlyingAmount = amount;

        asset.approve(address(vault), bobUnderlyingAmount);
        assertEq(asset.allowance(bob, address(vault)), bobUnderlyingAmount);

        uint256 bobShareAmount = vault.deposit(bobUnderlyingAmount, bob);
        uint256 bobAssetsToWithdraw = vault.convertToAssets(bobShareAmount);
        assertEq(bobUnderlyingAmount, bobShareAmount);
        assertEq(vault.totalSupply(), bobShareAmount);
        assertEq(vault.balanceOf(bob), bobShareAmount);

        vault.withdraw(bobAssetsToWithdraw, bob, bob);
    }

    function testHarvest() public {
        vm.startPrank(bob);

        uint256 bobUnderlyingAmount = HUNDRED_E18;

        asset.approve(address(vault), bobUnderlyingAmount);
        assertEq(asset.allowance(bob, address(vault)), bobUnderlyingAmount);

        uint256 bobShareAmount = vault.deposit(bobUnderlyingAmount, bob);
        uint256 bobAssetsToWithdraw = vault.convertToAssets(bobShareAmount);
        assertEq(bobUnderlyingAmount, bobShareAmount);
        assertEq(vault.totalSupply(), bobShareAmount);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        /// @dev Warp to make the account accrue some COMP
        // vm.warp(block.timestamp + 10 days);
        vm.roll(block.number + 100);
        vault.harvest(0);
        assertGt(vault.totalAssets(), bobUnderlyingAmount);
        vault.withdraw(bobAssetsToWithdraw, bob, bob);
    }
}
