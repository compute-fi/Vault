// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {StETHERC4626Swap} from "../src/providers/Lido/stETHSwap.sol";
import {AddressLib} from "../src/libs/Constants.sol";

contract DeployStEthSwap is Script {
    function run() external returns (StETHERC4626Swap) {
        IERC721 dyNFT = IERC721(0xf5D7ef8A011AA683306ff237F26589a658Bce6fF);
        address manager = 0x6FC5113b55771b884880785042e78521B8b719fa;
        // address weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
        // address stEth = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
        // address curvePool = 0xCEB67769c63cfFc6C8a6c68e85aBE1Df396B7aDA;

        vm.startBroadcast();
        StETHERC4626Swap stEthSwap = new StETHERC4626Swap(
            AddressLib.weth,
            AddressLib.stEth,
            AddressLib.curvePool,
            manager,
            dyNFT
        );
        vm.stopBroadcast();
        return stEthSwap;
    }
}
