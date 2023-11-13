// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IStETH} from "../../interfaces/Lido/IStETH.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

import {ErrorsLib} from "../../libs/ErrorsLib.sol";

/// @title stETHERC4626
/// @notice Accepts WETH through ERC4626 interface, but can also accept ETH directly through different deposit() function signature
/// @notice Vault balance holds stEth. Value is updated for each accounting call
/// @notice Asset Under Management (totalAssets()) operates on rebasing balance.abi
/// @dev This Wrapper is a base implementation, providing ERC4626 interface for stETH without any additional logic

contract StETHERC4626 is ERC4626 {
    /* ========== Libraries ========== */
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /* ========== Immutables & Variables ========== */
    IStETH public stEth;
    ERC20 public stEthAsset;
    IWETH public weth;

    /* ========== Constructor ========== */

    /// @param weth_ weth address (Vault's underlying / deposit token)
    /// @param stEth_ stEth address (Vault's asset)
    constructor(
        address weth_,
        address stEth_
    ) ERC4626(ERC20(weth_), "ERC4626-Wrapped stETH", "wLstETH") {
        stEthAsset = ERC20(stEth_);
        stEth = IStETH(stEth_);
        weth = IWETH(weth_);
    }

    receive() external payable {}

    /* ========== Internal Hooks ========== */

    function _addLiquidity(
        uint256 ethAmount_,
        uint256
    ) internal returns (uint256 stEthAmount) {
        stEthAmount = stEth.submit{value: ethAmount_}(address(this));
    }

    /* ========== Override ========== */

    /// @notice Deposit WETH. Standard ERC4626 deposit can only accept ERC20
    /// @notice Vault's underlying is WETH (ERC20), Lido expects ETH (Native), we use WETH wrapper
    function deposit(
        uint256 assets_,
        address receiver_
    ) public override returns (uint256 shares) {
        if ((shares = previewDeposit(assets_)) == 0)
            revert ErrorsLib.ZERO_SHARES();

        asset.safeTransferFrom(msg.sender, address(this), assets_);

        weth.withdraw(assets_);

        _addLiquidity(assets_, shares);

        _mint(receiver_, shares);

        emit Deposit(msg.sender, receiver_, assets_, shares);
    }

    /// @notice Deposit function accepting ETH (Native)
    function deposit(
        address receiver_
    ) public payable returns (uint256 shares) {
        if ((shares = previewDeposit(msg.value)) == 0)
            revert ErrorsLib.ZERO_SHARES();

        shares = _addLiquidity(msg.value, shares);

        _mint(receiver_, shares);

        emit Deposit(msg.sender, receiver_, msg.value, shares);
    }

    /// @notice Mint amount of stEth / ERC4626-stEth
    function mint(
        uint256 shares_,
        address receiver_
    ) public override returns (uint256 assets) {
        assets = previewMint(shares_);

        asset.safeTransferFrom(msg.sender, address(this), assets);

        weth.withdraw(assets);

        _addLiquidity(assets, shares_);

        _mint(receiver_, shares_);

        emit Deposit(msg.sender, receiver_, assets, shares_);
    }

    /// @notice Withdraw amount of ETH represented by stEth / ERC4626-stEth. Output is stEth
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

        _burn(owner_, shares);

        emit Withdraw(msg.sender, receiver_, owner_, assets_, shares);

        stEthAsset.safeTransfer(receiver_, assets_);
    }

    /// @notice Redeem exact amount of stEth / ERC4626-stEth from this Vault. Output token is stEth
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) public override returns (uint256 assets) {
        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) {
                allowance[owner_][msg.sender] = allowed - shares_;
            }
        }

        if ((assets = previewRedeem(shares_)) == 0)
            revert ErrorsLib.ZERO_ASSETS();

        _burn(owner_, shares_);

        emit Withdraw(msg.sender, receiver_, owner_, assets, shares_);

        stEthAsset.safeTransfer(receiver_, assets);
    }

    /// @notice stEth is used as AUM of this Vault
    function totalAssets() public view virtual override returns (uint256) {
        return stEth.balanceOf(address(this));
    }

    /// @notice Calculate amount of stEth you get in exchange for ETH (WETH)
    function convertToShares(
        uint256 shares_
    ) public view virtual override returns (uint256) {
        return stEth.getSharesByPooledEth(shares_);
    }

    /// @notice Calculate amount of ETH you get in exchange for stEth (ERC4626-stEth)
    /// Used as "virtual" amount in base implementation. No ETH is ever withdrawn
    function convertToAssets(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        return stEth.getPooledEthByShares(assets_);
    }

    function previewDeposit(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        return convertToShares(assets_);
    }

    function previewWithdraw(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        return convertToShares(assets_);
    }

    function previewRedeem(
        uint256 shares_
    ) public view virtual override returns (uint256) {
        return convertToAssets(shares_);
    }

    function previewMint(
        uint256 shares_
    ) public view virtual override returns (uint256) {
        return convertToAssets(shares_);
    }
}
