// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {ILendingPool} from "../../interfaces/Aave/ILendingPool.sol";
import {IAaveMining} from "../../interfaces/Aave/IAaveMining.sol";

import {AddressLib} from "../../libs/Constants.sol";
import {DexSwap} from "../../libs/DexSwap.sol";
import {ErrorsLib} from "../../libs/ErrorsLib.sol";

/// @title AaveV2ERC626
/// @notice Reinvests rewards accrued for higher APY
contract AaveV2ERC4626 is ERC4626 {
    /* ========== Libraries ========== */
    using SafeTransferLib for ERC20;

    /* ========== Immutables & Variables ========== */

    uint256 internal constant ACTIVE_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;

    /// @notice The Aave aToken contract
    ERC20 public immutable aToken;

    /// @notice NFT Token Gated Address
    IERC721 public immutable nftToken;

    /// @notice The Aave mining contract
    IAaveMining public immutable rewards;

    /// @notice Check if rewards have been set before harvest() and setRoutes()
    bool public rewardsSet;

    /// @notice The Aave LendingPool contract
    ILendingPool public immutable lendingPool;

    /// @notice Pointer to swapinfo
    swapInfo public SwapInfo;

    /// @notice struct to make two swaps
    /// A => B (using pair1) then B => asset (of Wrapper) (using pair2)
    struct swapInfo {
        address asset;
        address pair1;
        address pair2;
    }

    /// @notice Manager for setting swap routes for harvest() per each vault
    address public immutable manager;

    /// @notice address of reward token from Aave liquidity mining
    address public rewardToken;

    /* ========== Mappings ========== */
    mapping(address => uint256) public nftIdOwner;

    /* ========== Constructor ========== */

    /// @notice Create a new AaveV2ERC4626 contract
    /// @param asset_ The underlying asset
    /// @param aToken_ The Aave aToken contract
    /// @param rewards_ The Aave liquidity mining contract
    /// @param lendingPool_ The Aave lending pool contract
    /// @param rewardToken_ The reward token from Aave liquidity mining
    /// @param manager_ The manager for setting swap routes for harvest per each vault
    /// @param nftToken_ The NFT token gated address
    constructor(
        ERC20 asset_,
        ERC20 aToken_,
        IAaveMining rewards_,
        ILendingPool lendingPool_,
        address rewardToken_,
        address manager_,
        IERC721 nftToken_
    ) ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_)) {
        aToken = aToken_;
        rewards = rewards_;
        rewardToken = rewardToken_;
        manager = manager_;
        lendingPool = lendingPool_;
        nftToken = nftToken_;

        rewardsSet = false;
    }

    /* ========== Modifier ========== */

    modifier onlyNFTOwner() {
        uint256 _nftId = nftIdOwner[msg.sender];
        if (IERC721(nftToken).ownerOf(_nftId) != msg.sender)
            revert ErrorsLib.INVALID_ACCESS();
        _;
    }

    /* ========== Functions ========== */

    /// @notice Set swap routes for selling rewards
    /// @dev Setting wrong address here will revert harvest() calls
    /// @param token_ address of intermediary token with high liquidity (no direct pools )
    /// @param pair1_ address of pairToken (pool) for first swap (rewardToken => high liquidity token)
    /// @param pair2_ address of pairToken (pool) for second swap (high liquidity token => asset)
    function setRoute(address token_, address pair1_, address pair2_) external {
        if (msg.sender != manager) revert ErrorsLib.INVALID_ACCESS();
        SwapInfo = swapInfo(token_, pair1_, pair2_);
        rewardsSet = true;
    }

    /// @notice Claims liquidity providing rewards from Aave and performs low level with instant reinvesting
    /// @param minAmountOut_ The minimum amount of asset to receive after 2 swaps
    function harvest(uint256 minAmountOut_) external {
        /// @dev Claim rewards
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        uint256 earned = rewards.claimRewards(
            assets,
            type(uint256).max,
            address(this)
        );

        ERC20 rewardToken_ = ERC20(rewardToken);
        uint256 reinvestAmount;

        /// If one swap needed (high liquidity pair) - set swapInfo.token0/token/pair2 to 0x
        /// @dev Swap Aave token for asset
        if (SwapInfo.asset == address(asset)) {
            rewardToken_.approve(SwapInfo.pair1, earned);
            /// max approves address

            reinvestAmount = DexSwap.swap(
                earned,
                /// Rewards amount to swap
                rewardToken,
                address(asset),
                /// to target underlying asset
                SwapInfo.pair1
            );
        } else {
            rewardToken_.approve(SwapInfo.pair1, type(uint256).max);
            /// max approves address

            uint256 swapTokenAmount = DexSwap.swap(
                earned,
                rewardToken,
                SwapInfo.asset,
                /// to intermediary token with high liquidity (no direct pools)
                SwapInfo.pair1
            );
            /// pairToken (pool)
            ERC20(SwapInfo.asset).approve(SwapInfo.pair2, swapTokenAmount);

            reinvestAmount = DexSwap.swap(
                swapTokenAmount,
                SwapInfo.asset,
                address(asset),
                /// to target underlying asset
                SwapInfo.pair2
            );
            /// pairToken (pool)
        }
        if (reinvestAmount < minAmountOut_) revert ErrorsLib.MIN_AMOUNT_ERROR();

        /// reinvest() without minting (no asset.totalSupply() increase == profit)
        afterDeposit(asset.balanceOf(address(this)), 0);
    }

    /// @notice Check how much rewards are available to claim, useful before harvest()
    function getRewardsAccrued() external view returns (uint256) {
        return rewards.getUserUnclaimedRewards(address(this));
    }

    /* ========== ERC4626 Overrides ========== */

    /// @notice Withdraw assets from Aave and burn shares
    /// @param assets_ Amount of assets to withdraw
    /// @param receiver_ Address to receive assets
    /// @param owner_ Address to burn shares from
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    ) public override returns (uint256 shares) {
        shares = previewWithdraw(assets_); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner_][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets_, shares);

        _burn(owner_, shares);

        emit Withdraw(msg.sender, receiver_, owner_, assets_, shares);

        /// @dev Withdraw assets from Aave
        lendingPool.withdraw(address(asset), assets_, receiver_);
    }

    /// @notice Redeem assets from Aave and burn shares
    /// @param shares_ Amount of shares to redeem
    /// @param receiver_ Address to receive assets
    /// @param owner_ Address to burn shares from
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) public virtual override returns (uint256 assets) {
        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner_][msg.sender] = allowed - shares_;
        }

        // Check for rounding error since we round down in previewRedeem.
        if ((assets = previewRedeem(shares_)) == 0)
            revert ErrorsLib.ZERO_ASSETS();

        beforeWithdraw(assets, shares_);

        _burn(owner_, shares_);

        emit Withdraw(msg.sender, receiver_, owner_, assets, shares_);

        /// withdraw assets directly from Aave
        lendingPool.withdraw(address(asset), assets, receiver_);
    }

    /// @notice returns total aToken in the vault
    function totalAssets() public view virtual override returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    /// @notice called by deposit and mint to deposit assets into Aave
    /// @param assets_ Amount of assets to deposit
    function afterDeposit(
        uint256 assets_,
        uint256 /*shares_*/
    ) internal virtual override {
        /// @dev Deposit assets to Aave

        /// @dev approve to lendingPool
        asset.approve(address(lendingPool), assets_);

        /// @dev deposit to lendingPool
        lendingPool.deposit(address(asset), assets_, address(this), 0);
    }

    /// @notice returns max amount of assets that can be deposited
    function maxDeposit(
        address
    ) public view virtual override returns (uint256) {
        // check if pool is paused
        if (lendingPool.paused()) return 0;

        // check if asset is paused
        uint256 configData = lendingPool
            .getReserveData(address(asset))
            .configuration
            .data;
        if (!(_getActive(configData) && !_getFrozen(configData))) return 0;

        return type(uint256).max;
    }

    /// @notice returns max amount of assets that can be minted
    function maxMint(address) public view virtual override returns (uint256) {
        // check if pool is paused
        if (lendingPool.paused()) return 0;

        // check if asset is paused
        uint256 configData = lendingPool
            .getReserveData(address(asset))
            .configuration
            .data;
        if (!(_getActive(configData) && !_getFrozen(configData))) return 0;

        return type(uint256).max;
    }

    /// @notice returns max amount of assets that can be withdrawn
    /// @param owner_ Address to check max withdrawable assets for
    function maxWithdraw(
        address owner_
    ) public view virtual override returns (uint256) {
        // check if pool is paused
        if (lendingPool.paused()) return 0;

        // check if asset is paused
        uint256 configData = lendingPool
            .getReserveData(address(asset))
            .configuration
            .data;
        if (!_getActive(configData)) return 0;

        uint256 cash = asset.balanceOf(address(aToken));
        uint256 assetsBalance = convertToAssets(balanceOf[owner_]);
        return cash < assetsBalance ? cash : assetsBalance;
    }

    /// @notice returns max amount of shares that can be redeemed
    /// @param owner_ Address to check max redeemable shares for
    function maxRedeem(
        address owner_
    ) public view virtual override returns (uint256) {
        // check if pool is paused
        if (lendingPool.paused()) return 0;

        // check if asset is paused
        uint256 configData = lendingPool
            .getReserveData(address(asset))
            .configuration
            .data;
        if (!_getActive(configData)) return 0;

        uint256 cash = asset.balanceOf(address(aToken));
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner_];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /* ========== ERC20 Metadata ========== */

    function _vaultName(
        ERC20 asset_
    ) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("Wrapped Aave V2", asset_.symbol());
    }

    function _vaultSymbol(
        ERC20 asset_
    ) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("wa2-", asset_.symbol());
    }

    /* ========== Helpers ========== */

    function _getActive(uint256 configData) internal pure returns (bool) {
        return configData & ~ACTIVE_MASK != 0;
    }

    function _getFrozen(uint256 configData) internal pure returns (bool) {
        return configData & ~FROZEN_MASK != 0;
    }
}
