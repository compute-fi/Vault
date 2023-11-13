// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {AaveV2ERC4626} from "../providers/AaveV2/AaveV2ERC4626.sol";

library EventsLib {
    /// @notice Emitted when a new AaveV2ERC4626 vault is created
    /// @param asset The base asset used by the vault
    /// @param vault The address of the new vault
    event CreateVault(ERC20 indexed asset, ERC4626 vault);

    /// @notice Emitted when swap routes have been set for a given token vault
    event RoutesSet(AaveV2ERC4626 indexed vault);

    /// @notice Emitted when harvest has been called for a given token vault
    event HarvestReward(AaveV2ERC4626 vault);
}
