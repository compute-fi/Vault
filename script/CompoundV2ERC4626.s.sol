// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {ICERC20} from "../src/interfaces/Compound/ICERC20.sol";
import {IComptroller} from "../src/interfaces/Compound/IComptroller.sol";
import {CompoundV2ERC4626} from "../src/providers/Compound/CompoundV2ERC4626.sol";
import {AddressLib} from "../src/libs/Constants.sol";

contract DeployCompoundV2ERC4626 is Script {
    function run() external returns (CompoundV2ERC4626) {
        IERC721 dyNFT = IERC721(0xf5D7ef8A011AA683306ff237F26589a658Bce6fF);
        ERC20 usdtToken = ERC20(0x79C950C7446B234a6Ad53B908fBF342b01c4d446);
        ERC20 rewardToken = ERC20(0x3587b2F7E0E2D6166d6C14230e7Fe160252B0ba4);
        ICERC20 cUSDT = ICERC20(0x5A74332C881Ea4844CcbD8458e0B6a9B04ddb716);
        IComptroller comptroller = IComptroller(
            0x05Df6C772A563FfB37fD3E04C1A279Fb30228621
        );
        address manager = 0x6FC5113b55771b884880785042e78521B8b719fa;

        vm.startBroadcast();
        CompoundV2ERC4626 compoundV2ERC4626 = new CompoundV2ERC4626(
            usdtToken,
            rewardToken,
            cUSDT,
            comptroller,
            manager,
            dyNFT
        );

        compoundV2ERC4626.addToken(
            ERC20(AddressLib.daiToken),
            ICERC20(AddressLib.cDAI)
        );
        compoundV2ERC4626.addToken(
            ERC20(AddressLib.uniToken),
            ICERC20(AddressLib.cUNI)
        );
        compoundV2ERC4626.addToken(
            ERC20(AddressLib.wethToken),
            ICERC20(AddressLib.cETH)
        );
        compoundV2ERC4626.addToken(
            ERC20(AddressLib.compToken),
            ICERC20(AddressLib.cCOMP)
        );

        vm.stopBroadcast();
        return compoundV2ERC4626;
    }
}
