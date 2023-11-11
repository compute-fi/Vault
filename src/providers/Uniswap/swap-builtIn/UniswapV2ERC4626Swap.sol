// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {IUniswapV2Pair} from "../../../interfaces/Uniswap/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "../../../interfaces/Uniswap/IUniswapV2Router.sol";
import {UniswapV2Library} from "../../../libs/UniswapV2Library.sol";

import {IUniswapV3Pool} from "../../../interfaces/Uniswap/IUniswapV3.sol";
import {DexSwap} from "../../../libs/DexSwap.sol";
import {ErrorsLib} from "../../../libs/ErrorsLib.sol";
import {EventsLib} from "../../../libs/EventsLib.sol";

/// @title UniswapV2ERC4626Swap
/// @notice ERC4626 UniswapV2 Adapter - Allows exit & join to UniswapV2 LP Pools from ERC4626 interface. Single sided liquidity adapter
/// @notice Provides a set of helpful functions to calculate different aspects of liquidity providing to the UniswapV2-style pools
/// @notice Accept tokenX || tokenY as Asset. Uses UniswapV2Pair LP-TOKEN as AUM(totalAssets()
/// @notice BASIC FLOW: Deposit tokenX > tokenX swap to tokenX && tokenY optimal amount > tokenX/Y deposited into UniswapV2
/// @notice > shares minted to the Vault from Uniswap Pool > shares minted to the user from the Vault
/// @dev Example Pool :https://v2.info.uniswap.org/pair/0xae461ca67b15dc8dc81ce7615e0320da1a9ab8d5 (DAI-USDC LP/PAIR on ETH).

contract UniswapV2ERC4626Swap is ERC4626 {
    /* ========== Libraries ========== */
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /* ========== Variables ========== */
    address public immutable manager;

    /// Note: Hardcoded workaround to ensure execution within changing pair reserves - 0.4% (4000/1000000)
    uint256 public fee = 4000;
    uint256 public immutable slippageFloat = 1_000_000;

    IUniswapV2Pair public immutable pair;
    IUniswapV2Router public immutable router;
    IUniswapV3Pool public immutable oracle;

    ERC20 public token0;
    ERC20 public token1;

    /* ========== Constructor ========== */

    /// @notice Construct a new UniswapV2ERC4626Swap contract
    /// @param asset_ The address of the underlying asset
    /// @param name_ The name of the ERC4626 token
    /// @param symbol_ The symbol of the ERC4626 token
    /// @param router_ The address of the UniswapV2 router
    /// @param pair_ The address of the UniswapV2 pair
    /// @param oracle_ The address of the UniswapV3 oracle
    constructor(
        ERC20 asset_,
        string memory name_,
        string memory symbol_,
        IUniswapV2Router router_,
        IUniswapV2Pair pair_,
        IUniswapV3Pool oracle_
    ) ERC4626(asset_, name_, symbol_) {
        manager = msg.sender;

        pair = pair_;
        router = router_;
        oracle = oracle_;

        address token0_ = pair.token0();
        address token1_ = pair.token1();

        if (address(asset) == token0_) {
            token0 = asset;
            token1 = ERC20(token1_);
        } else {
            token0 = ERC20(token0_);
            token1 = asset;
        }
    }

    /* ========== Functions ========== */
    /// @notice Non-ERC4626 deposit function taking additional protection parameters for execution
    /// @dev Caller can calculate minSharesOut using previewDeposit function range of outputs
    function deposit(
        uint256 assets_,
        address receiver_,
        uint256 minSharesOut_
    ) public returns (uint256 shares) {
        asset.safeTransferFrom(msg.sender, address(this), assets_);

        /// @dev caller calculates minSwapOut from uniswapV2Library off-chain, reverts if swap is manipulated
        (uint256 a0, uint256 a1) = _swapJoin(assets_);

        shares = _liquidityAdd(a0, a1);

        /// @dev caller calculates minSharesOut off-chain, this contracts functions can be used to retrieve reserves over the past blocks
        if (shares < minSharesOut_) revert ErrorsLib.NOT_MIN_SHARES_OUT();

        /// @dev we just pass uniswap lp-token amount to user
        _mint(receiver_, shares);

        emit Deposit(msg.sender, receiver_, assets_, shares);
    }

    /// @notice receives tokenX of UniV2 pair and mints shares of this vault for deposited tokenX/Y into UniV2 pair
    /// @dev unsecure deposit function, trusting external asset reserves
    /// @dev Standard ERC4626 deposit is prone to manipulation because of no minSharesOut argument allwoed
    /// @dev Caller can calculate shares through previewDeposit and trust previewDeposit returned value to revert here
    function deposit(
        uint256 assets_,
        address receiver_
    ) public override returns (uint256 shares) {
        /// @dev can be manipulated before making deposit() call
        shares = previewDeposit(assets_);

        /// @dev 100% of tokenX/Y is transferred to this contract
        asset.safeTransferFrom(msg.sender, address(this), assets_);

        /// @dev swap from 100% to ~50% of tokenX/Y
        (uint256 a0, uint256 a1) = _swapJoin(assets_);

        /// NOTE: Pool reserve could be manipulated
        uint256 uniShares = _liquidityAdd(a0, a1);

        /// @dev totalAssets holds sum of all UniLP,
        if (uniShares < shares) revert ErrorsLib.NOT_MIN_SHARES_OUT();

        _mint(receiver_, uniShares);

        emit Deposit(msg.sender, receiver_, assets_, uniShares);
    }

    /// @notice Non-ERC4626 mint function taking additional protection parameters for execution
    function mint(
        uint256 shares_,
        address receiver_,
        uint256 minSharesOut_
    ) public returns (uint256 assets) {
        assets = previewMint(shares_);

        asset.safeTransferFrom(msg.sender, address(this), assets);

        (uint256 a0, uint256 a1) = _swapJoin(assets);

        uint256 uniShares = _liquidityAdd(a0, a1);

        /// @dev Protected mint, caller can calculate minSharesOut off-chain
        if (uniShares < minSharesOut_) revert ErrorsLib.NOT_MIN_SHARES_OUT();

        _mint(receiver_, uniShares);

        emit Deposit(msg.sender, receiver_, assets, uniShares);
    }

    /// @notice mint exact amount of this Vault shares and effectively UniswapV2Pair shares (1:1 relation)
    /// @dev Requires caller to have a prior knowledge of what amount of 'assets' to approve
    function mint(
        uint256 shares_,
        address receiver_
    ) public override returns (uint256 assets) {
        assets = previewMint(shares_);

        asset.safeTransferFrom(msg.sender, address(this), assets);

        (uint256 a0, uint256 a1) = _swapJoin(assets);

        uint256 uniShares = _liquidityAdd(a0, a1);

        /// NOTE: PreviewMint needs to output reasonable amount of shares
        if (uniShares < shares_) revert ErrorsLib.NOT_MIN_SHARES_OUT();

        _mint(receiver_, uniShares);

        emit Deposit(msg.sender, receiver_, assets, uniShares);
    }

    /// @notice Non-ERC4626 withdraw function taking additional protection parameters for execution
    /// @dev Caller specifies minAmountOut_ of this Vault's underlying to receive for burning Vault's shares (and UniswapV2Pair shares)
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 minAmountOut_
    ) public returns (uint256 shares) {
        shares = previewWithdraw(assets_);

        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) {
                allowance[owner_][msg.sender] = allowed - shares;
            }
        }

        (uint256 assets0, uint256 assets1) = _liquidityRemove(assets_, shares);

        _burn(owner_, shares);

        uint256 amount = asset == token0
            ? _swapExit(assets1) + assets0
            : _swapExit(assets0) + assets1;

        /// @dev Protected amountOut check
        if (amount < minAmountOut_) revert ErrorsLib.NOT_MIN_AMOUNT_OUT();

        asset.safeTransfer(receiver_, amount);

        emit Withdraw(msg.sender, receiver_, owner_, amount, shares);
    }

    /// @notice Receive amounts of 'assets' of underlying token of this Vault (token0 or token1 of underlying UniswapV2Pair)
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    ) public override returns (uint256 shares) {
        shares = previewWithdraw(assets_);

        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) {
                allowance[owner_][msg.sender] = allowed - shares;
            }
        }

        (uint256 assets0, uint256 assets1) = _liquidityRemove(assets_, shares);

        _burn(owner_, shares);

        /// @dev Ideally contract for token0/token1 should know what assets amount to use without conditional checks, gas overhead
        uint256 amount = asset == token0
            ? _swapExit(assets1) + assets0
            : _swapExit(assets0) + assets1;

        asset.safeTransfer(receiver_, amount);

        emit Withdraw(msg.sender, receiver_, owner_, amount, shares);
    }

    /// @notice Non-ERC4626 redeem function taking additional protection parameters for execution
    /// @dev Caller specifies minAmountOut_ of this Vault's underlying to receive for burning Vault's shares (and UniswapV2Pair shares)
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_,
        uint256 amountOut_
    ) public returns (uint256 assets) {
        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) {
                allowance[owner_][msg.sender] = allowed - shares_;
            }
        }

        if ((assets = previewRedeem(shares_)) == 0)
            revert ErrorsLib.ZERO_ASSETS();

        (uint256 assets0, uint256 assets1) = _liquidityRemove(assets, shares_);

        _burn(owner_, shares_);

        uint256 amount = asset == token0
            ? _swapExit(assets1) + assets0
            : _swapExit(assets0) + assets1;

        /// @dev Protected amountOut check
        if (amount < amountOut_) revert ErrorsLib.NOT_MIN_AMOUNT_OUT();

        asset.safeTransfer(receiver_, amount);

        emit Withdraw(msg.sender, receiver_, owner_, amount, shares_);
    }

    /// @notice Burn amount of 'shares' of this Vault (and UniswapV2Pair shares) and receive amounts of 'assets' of underlying token of this Vault
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares_;
            }
        }

        if ((assets = previewRedeem(shares_)) == 0)
            revert ErrorsLib.ZERO_ASSETS();

        (uint256 assets0, uint256 assets1) = _liquidityRemove(assets, shares_);

        _burn(owner, shares_);

        uint256 amount = asset == token0
            ? _swapExit(assets1) + assets0
            : _swapExit(assets0) + assets1;

        asset.safeTransfer(receiver_, amount);

        emit Withdraw(msg.sender, receiver_, owner, amount, shares_);
    }

    /* ========== Accounting ========== */
    /// @notice totalAssets is equal to UniswapV2Pair lp tokens minted through this adapter
    function totalAssets() public view override returns (uint256) {
        return pair.balanceOf(address(this));
    }

    /// @notice for this many asset (ie token0) we get this many shares
    function previewDeposit(
        uint256 assets_
    ) public view override returns (uint256 shares) {
        return getSharesFromAssets(assets_);
    }

    /// @notice for this many shares/uniLp we need to pay at least this many asset (ie token0)
    /// @dev adds slippage for over-approving asset to cover possible fluctuation. value is returned to the user in full
    function previewMint(
        uint256 shares_
    ) public view override returns (uint256 assets) {
        assets = mintAssets(shares_);
    }

    /// @notice calculate value of shares of this vault as the sum of token0/token1 of UniV2 pair simulated as t0 or t1 total amount after swap
    function mintAssets(uint256 shares_) public view returns (uint256 assets) {
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );
        /// shares of uni pair contract
        uint256 pairSupply = pair.totalSupply();

        /// amount of token0 to provide to receive poolLpAmount_
        uint256 assets0_ = (reserveA * shares_) / pairSupply;
        uint256 a0 = assets0_ + _getSlippage(assets0_);

        /// amount of token1 to provide to receive poolLpAmount_
        uint256 assets1_ = (reserveB * shares_) / pairSupply;
        uint256 a1 = assets1_ + _getSlippage(assets1_);

        if (a1 == 0 || a0 == 0) return 0;

        (reserveA, reserveB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );

        return a0 + UniswapV2Library.getAmountOut(a1, reserveB, reserveA);
    }

    /// @notice separate from mintAssets virtual assets calculation from shares, but with omitted slippage to stop overwithdraw from Vault's balance
    function redeemAssets(
        uint256 shares_
    ) public view returns (uint256 assets) {
        (uint256 a0, uint256 a1) = getAssetsAmounts(shares_);

        if (a1 == 0 || a0 == 0) return 0;

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );

        return a0 + UniswapV2Library.getAmountOut(a1, reserveB, reserveA);
    }

    /* ========== Uniswap Pair Calculations ========== */

    /// @notice for requested 100 UniLp tokens, how much token0/token1 we need to give?
    function getAssetsAmounts(
        uint256 poolLpAmount_
    ) public view returns (uint256 assets0, uint256 assets1) {
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );

        /// shares of uni pair contract
        uint256 pairSupply = pair.totalSupply();

        /// amount of token0 to provide to receive poolLpAmount_
        assets0 = (reserveA * poolLpAmount_) / pairSupply;

        /// amount of token1 to provide to receive poolLpAmount_
        assets1 = (reserveB * poolLpAmount_) / pairSupply;
    }

    /// @notice Take amount of token0 > split to token0/token1 amounts > calculate how much shares to burn
    function getSharesFromAssets(
        uint256 assets_
    ) public view returns (uint256 poolLpAmount) {
        (uint256 assets0, uint256 assets1) = getSplitAssetAmounts(assets_);

        poolLpAmount = getLiquidityAmountOutFor(assets0, assets1);
    }

    /// @notice Take amount of token0 (underlying) > split to token0/token1 (virtual) amounts
    function getSplitAssetAmounts(
        uint256 assets_
    ) public view returns (uint256 assets0, uint256 assets1) {
        (uint256 resA, uint256 resB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );

        uint256 toSwapForUnderlying = UniswapV2Library.getSwapAmount(
            _getReserves(),
            /// either resA or resB
            assets_
        );

        if (token0 == asset) {
            /// @dev we use getMountOut because it includes 0.3 fee
            uint256 resultOfSwap = UniswapV2Library.getAmountOut(
                toSwapForUnderlying,
                resA,
                resB
            );

            assets0 = assets_ - toSwapForUnderlying;
            assets1 = resultOfSwap;
        } else {
            uint256 resultOfSwap = UniswapV2Library.getAmountOut(
                toSwapForUnderlying,
                resB,
                resA
            );

            assets0 = resultOfSwap;
            assets1 = assets_ - toSwapForUnderlying;
        }
    }

    /// @notice Calculate amount of UniswapV2Pair lp-token you will get for supply X & Y amount of token0/token1
    function getLiquidityAmountOutFor(
        uint256 assets0_,
        uint256 assets1_
    ) public view returns (uint256 poolLpAmount) {
        uint256 pairSupply = pair.totalSupply();

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            address(pair),
            address(token0),
            address(token1)
        );
        poolLpAmount = min(
            ((assets0_ * pairSupply) / reserveA),
            ((assets1_ * pairSupply) / reserveB)
        );
    }

    /* ========== Internal ========== */

    /// @notice Remove liquidity from the underlying UniswapV2Pair. Receive both token0 and token 1 on the Vault address
    function _liquidityRemove(
        uint256,
        uint256 shares_
    ) internal returns (uint256 assets0, uint256 assets1) {
        /// @dev Values are sorted becuase we sort if token0/token1 == asset at runtime
        (assets0, assets1) = getAssetsAmounts(shares_);

        pair.approve(address(router), shares_);

        (assets0, assets1) = router.removeLiquidity(
            address(token0),
            address(token1),
            shares_,
            assets0 - _getSlippage(assets0),
            /// NOTE: No MEV protection, only ensuring execution within certain range to avoid revert
            assets1 - _getSlippage(assets1),
            /// NOTE: No MEV protection, only ensuring execution within certain range to avoid revert
            address(this),
            block.timestamp + 100
        );
    }

    /// @notice Add liquidity to the underlying UniswapV2Pair. Send both token0 and token1 from the Vault
    function _liquidityAdd(
        uint256 assets0_,
        uint256 assets1_
    ) internal returns (uint256 li) {
        token0.approve(address(router), assets0_);
        token1.approve(address(router), assets1_);

        (, , li) = router.addLiquidity(
            address(token0),
            address(token1),
            assets0_,
            assets1_,
            assets0_ - _getSlippage(assets0_),
            /// NOTE: No MEV protection, only ensuring execution within certain range to avoid revert
            assets1_ - _getSlippage(assets1_),
            /// NOTE: No MEV protection, only ensuring execution within certain range to avoid revert
            address(this),
            block.timestamp + 100
        );
    }

    /* ========== Internal Swap Logic for Token X/Y ========== */

    /// @notice directional swap from asset to opposite token (asset != tokenX)
    /// @notice calculates optimal (for the current block) amount of token0/token1 to deposit into UniswapV2Pair and
    /// splits provided assets according to the formula
    function _swapJoin(
        uint256 assets_
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint256 reserve = _getReserves();

        /// NOTE:
        /// resA if asset == token0
        /// resB if asset == token1
        uint256 amountToSwap = UniswapV2Library.getSwapAmount(reserve, assets_);

        (address fromToken, address toToken) = _getJoinToken();
        /// NOTE: amount1 == amount of token other than asset to deposit
        amount1 = DexSwap.swap(
            /// amount to swap
            amountToSwap,
            /// from asset
            fromToken,
            /// to asset
            toToken,
            /// pair address
            address(pair)
        );

        /// NOTE: amount0 == amount of underlying asset after swap to required asset
        amount0 = assets_ - amountToSwap;
    }

    /// @notice directional swap from asset to opposite token (asset != tokenX)
    /// @notice exit is in opposite direction to Join but we don't need to calculate splitting, just swap provided
    /// assets, check happens in withdraw/redeem
    function _swapExit(uint256 assets_) internal returns (uint256 amounts) {
        (address fromToken, address toToken) = _getExitToken();
        amounts = DexSwap.swap(assets_, fromToken, toToken, address(pair));
    }

    /// @notice Sort function for this Vault Uniswap pair exit operation
    function _getExitToken() internal view returns (address t0, address t1) {
        if (token0 == asset) {
            t0 = address(token1);
            t1 = address(token0);
        } else {
            t0 = address(token0);
            t1 = address(token1);
        }
    }

    /// @notice Sort function for this Vault Uniswap pair join operation
    function _getJoinToken() internal view returns (address t0, address t1) {
        if (token0 == asset) {
            t0 = address(token0);
            t1 = address(token1);
        } else {
            t0 = address(token1);
            t1 = address(token0);
        }
    }

    /// @notice Selector for reserve of underlying asset
    function _getReserves() internal view returns (uint256 assetReserves) {
        if (token0 == asset) {
            (assetReserves, ) = UniswapV2Library.getReserves(
                address(pair),
                address(token0),
                address(token1)
            );
        } else {
            (, assetReserves) = UniswapV2Library.getReserves(
                address(pair),
                address(token0),
                address(token1)
            );
        }
    }

    /* ========== Helper ========== */
    function _getSlippage(uint256 amount_) internal view returns (uint256) {
        return (amount_ * fee) / slippageFloat;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}
