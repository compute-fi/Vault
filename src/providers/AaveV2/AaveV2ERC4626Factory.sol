// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

import {AaveV2ERC4626} from "./AaveV2ERC4626.sol";
import {ILendingPool} from "../../interfaces/Aave/ILendingPool.sol";
import {IAaveMining} from "../../interfaces/Aave/IAaveMining.sol";

import {EventsLib} from "../../libs/EventsLib.sol";
import {ErrorsLib} from "../../libs/ErrorsLib.sol";

/// @title AaveV2ERC4626Factory
/// @notice Deploys AaveV2ERC4626 contracts
contract AaveV2ERC4626Factory {
    /* ========== Variables ========== */

    /// @notice The Aave liquidity mining contract
    IAaveMining public immutable aaveMining;

    /// @notice The Aave LendingPool contract
    ILendingPool public immutable lendingPool;

    /// @notice Manager for setting swap routes for harvest() per each vault
    address public immutable manager;

    /// @notice address of reward token from Aave liquidity mining
    address public rewardToken;

    /// @notice NFT Token Gated Address
    IERC721 public immutable nftToken;

    /* ========== Constructor ========== */

    /// @notice Create a new AaveV2ERC4626Factory contract
    /// @param aaveMining_ The address of the Aave liquidity mining contract
    /// @param lendingPool_ The address of the Aave LendingPool contract
    /// @param rewardToken_ The address of the Aave reward token
    /// @param manager_ Manager for setting swap routes for harvest() per each vault

    constructor(
        IAaveMining aaveMining_,
        ILendingPool lendingPool_,
        address rewardToken_,
        address manager_,
        IERC721 nftToken_
    ) {
        aaveMining = aaveMining_;
        lendingPool = lendingPool_;
        rewardToken = rewardToken_;
        manager = manager_;
        nftToken = IERC721(nftToken_);
    }

    /* ========== Functions ========== */

    /// @notice Create a new AaveV2ERC4626 vault
    /// @param asset_ The address of the underlying asset
    function createVault(
        ERC20 asset_
    ) external virtual returns (ERC4626 vault) {
        if (msg.sender != manager) revert ErrorsLib.INVALID_ACCESS();
        ILendingPool.ReserveData memory reserveData = lendingPool
            .getReserveData(address(asset_));
        address aTokenAddress = reserveData.aTokenAddress;
        if (aTokenAddress == address(0)) revert ErrorsLib.ATOKEN_NON_EXISTENT();

        vault = new AaveV2ERC4626{salt: bytes32(0)}(
            asset_,
            ERC20(aTokenAddress),
            aaveMining,
            lendingPool,
            rewardToken,
            address(this),
            nftToken
        );

        emit EventsLib.CreateVault(asset_, vault);
    }

    /// @notice Set swap routes for selling rewards
    /// @dev Centralizes setRoute on all created vaults
    /// @param vault_ The vault to set the route for
    /// @param token_ The token to swap
    /// @param pair1_ The address of the pool pair containing harvested token
    /// @param pair2_ The address of the pool pair containing the token to swap to
    function setRoute(
        AaveV2ERC4626 vault_,
        address token_,
        address pair1_,
        address pair2_
    ) external {
        if (msg.sender != manager) revert ErrorsLib.INVALID_ACCESS();
        vault_.setRoute(token_, pair1_, pair2_);

        emit EventsLib.RoutesSet(vault_);
    }

    /// @notice Harvest rewards from specified vault
    /// @param vault_ The vault to harvest rewards from
    /// @param minAmountOut_ The minimum amount of reward tokens to receive
    function harvestFrom(AaveV2ERC4626 vault_, uint256 minAmountOut_) external {
        vault_.harvest(minAmountOut_);

        emit EventsLib.HarvestReward(vault_);
    }
}
