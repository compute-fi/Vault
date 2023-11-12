// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ICERC20} from "../../interfaces/Compound/ICERC20.sol";
import {LibCompound} from "../../libs/LibCompound.sol";
import {IComptroller} from "../../interfaces/Compound/IComptroller.sol";
import {ISwapRouter} from "../../interfaces/Uniswap/ISwapRouter.sol";
import {DexSwap} from "../../libs/DexSwap.sol";

import {EventsLib} from "../../libs/EventsLib.sol";
import {ErrorsLib} from "../../libs/ErrorsLib.sol";

/// @title CompoundV2ERC4626
/// @notice Custom implementation of the ERC4626 interface for Compound V2

contract CompoundV2ERC4626 is ERC4626 {
    /* ========== Libraries ========== */
    using LibCompound for ICERC20;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /* ========== Constants ========== */

    uint256 internal constant NO_ERROR = 0;

    /* ========== Variables ========== */
    /// @notice NFT Token Gated Address
    IERC721 public immutable nftToken;

    /// @notice Access control for harvest() route
    address public immutable manager;

    /// @notice The Comp-like token contract
    ERC20 public immutable reward;

    /// @notice The Compound cToken contract
    ICERC20 public immutable cToken;

    /// @notice Pointer to swapInfo
    bytes public swapPath;

    /// @notice The Compound Comptroller contract
    IComptroller public immutable comptroller;

    ISwapRouter public immutable swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /// Compact struct to make two swaps
    /// A => B (using pair1) then B => asset (of Wrapper) (using pair2)
    struct swapInfo {
        address asset;
        address pair1;
        address pair2;
    }

    /* ========== Mappings ========== */
    mapping(address => uint256) public nftIdOwner;

    /* ========== Constructor ========== */

    /// @notice Constructor for the CompoundV2ERC4626 contract
    /// @param asset_ The address of the underlying asset
    /// @param reward_ The address of the Comp-like token
    /// @param cToken_ The address of the Compound cToken
    /// @param comptroller_ The address of the Compound Comptroller
    /// @param manager_ The address of the manager
    constructor(
        ERC20 asset_,
        ERC20 reward_,
        ICERC20 cToken_,
        IComptroller comptroller_,
        address manager_
    ) ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_)) {
        reward = reward_;
        cToken = cToken_;
        comptroller = comptroller_;
        manager = manager_;
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.enterMarkets(cTokens);
        // nftToken = nftToken_;
    }

    /* ========== Modifier ========== */
    modifier onlyNFTOwner() {
        uint256 _nftId = nftIdOwner[msg.sender];
        if (IERC721(nftToken).ownerOf(_nftId) != msg.sender)
            revert ErrorsLib.INVALID_ACCESS();
        _;
    }

    /* ========== Functions ========== */
    /// @notice Sets the swap path for reinvesting rewards
    /// @param poolFee1_ The fee for the first swap
    /// @param tokenMid_ token for the first swap
    /// @param poolFee2_ The fee for the second swap
    function setRoute(
        uint24 poolFee1_,
        address tokenMid_,
        uint24 poolFee2_
    ) external {
        if (msg.sender != manager) revert ErrorsLib.INVALID_ACCESS_ERROR();
        if (poolFee1_ == 0) revert ErrorsLib.INVALID_FEE_ERROR();
        if (poolFee2_ == 0 || tokenMid_ == address(0)) {
            swapPath = abi.encodePacked(reward, poolFee1_, address(asset));
        } else {
            swapPath = abi.encodePacked(
                reward,
                poolFee1_,
                tokenMid_,
                poolFee2_,
                address(asset)
            );
        }
        ERC20(reward).approve(address(swapRouter), type(uint256).max);
    }

    /// @notice Claims liquidity mining rewards from Compound and perform low-level swap
    /// Calling harvest() claims COMP token through direct Pair swap for best control and lowest cost
    /// harvest() can be called by anyone. Ideally this function should be adjusted per needs(e.g add fee for harvesting)
    function harvest(uint256 minAmountOut_) external {
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.claimComp(address(this), cTokens);

        uint256 earned = ERC20(reward).balanceOf(address(this));
        uint256 reinvestAmount;
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: swapPath,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: earned,
                amountOutMinimum: minAmountOut_
            });

        /// Executes swap
        reinvestAmount = swapRouter.exactInput(params);
        if (reinvestAmount < minAmountOut_) revert ErrorsLib.MIN_AMOUNT_ERROR();
        afterDeposit(asset.balanceOf(address(this)), 0);
    }

    /* ========== ERC4626 Overrides ========== */

    function totalAssets() public view virtual override returns (uint256) {
        return cToken.viewUnderlyingBalanceOf(address(this));
    }

    function beforeWithdraw(
        uint256 assets_,
        uint256 /* shares_ */
    ) internal virtual override {
        uint256 errorCode = cToken.redeemUnderlying(assets_);
        if (errorCode != NO_ERROR) revert ErrorsLib.COMPOUND_ERROR(errorCode);
    }

    function afterDeposit(
        uint256 assets_,
        uint256 /* shares_ */
    ) internal virtual override {
        /// Approve cToken to spend asset
        asset.safeApprove(address(cToken), assets_);
        // deposit into cToken
        uint256 errorCode = cToken.mint(assets_);
        if (errorCode != NO_ERROR) revert ErrorsLib.COMPOUND_ERROR(errorCode);
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxWithdraw(
        address owner_
    ) public view override returns (uint256) {
        uint256 cash = cToken.getCash();
        uint256 assetsBalance = convertToAssets(balanceOf[owner_]);
        return cash < assetsBalance ? cash : assetsBalance;
    }

    function maxRedeem(address owner_) public view override returns (uint256) {
        uint256 cash = cToken.getCash();
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner_];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /* ========== Metadata ========== */
    function _vaultName(
        ERC20 asset_
    ) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("CompV2", asset_.symbol());
    }

    function _vaultSymbol(
        ERC20 asset_
    ) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("c-", asset_.symbol());
    }
}
