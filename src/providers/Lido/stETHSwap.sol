// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IStETH} from "../../interfaces/Lido/IStETH.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {ICurve} from "../../interfaces/Lido/ICurve.sol";

import {AddressLib} from "../../libs/Constants.sol";
import {ErrorsLib} from "../../libs/ErrorsLib.sol";

/// @title Lido's stETH ERC4626 wrapper
/// @notice Accepts WETH through ERC4626 interface, but can also accept ETH directly through different deposit() function signature
/// @notice Returns assets as ETH for brevity (community-version should return stETH)
/// @notice Usess ETH/stETH CurvePol for a fast-exist with 1% slippage
contract StETHERC4626Swap is ERC4626 {
    /* ========== Libraries ========== */
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /* ========== Variables ========== */

    IERC721 public immutable nftToken;

    address manager;

    IStETH public stEth;
    IWETH public weth;
    ICurve public curvePool;

    uint256 public slippage;
    uint256 public immutable slippageFloat = 10_000; // 1% slippage

    int128 public immutable ethIndex = 0;

    int128 public immutable stEthIndex = 1;

    /* ========== Mappings ========== */
    mapping(address => uint256) public nftIdOwner;

    /* ========== Constructor ========== */

    /// @param weth_ weth address (Vault's underlying / deposit token)
    /// @param stEth_ stETH (Lido contract) address
    /// @param curvePool_ CurvePool address
    /// @param manager_ manager address

    constructor(
        address weth_,
        address stEth_,
        address curvePool_,
        address manager_,
        IERC721 nftToken_
    ) ERC4626(ERC20(weth_), "ERC4626-Wrapped stETH", "wLstETH") {
        stEth = IStETH(stEth_);
        weth = IWETH(weth_);
        curvePool = ICurve(curvePool_);
        stEth.approve(address(curvePool), type(uint256).max);
        manager = manager_;
        slippage = 9900;
        nftToken = nftToken_;
    }

    receive() external payable {}

    /* ========== Modifier ========== */
    modifier onlyNFTOwner() {
        uint256 _nftId = nftIdOwner[msg.sender];
        if (IERC721(nftToken).ownerOf(_nftId) != msg.sender)
            revert ErrorsLib.INVALID_ACCESS();
        _;
    }

    /* ========== Overrides ========== */

    function beforeWithdraw(uint256 assets_, uint256) internal override {
        uint256 min_dy = _getSlippage(
            curvePool.get_dy(stEthIndex, ethIndex, assets_)
        );
        curvePool.exchange(stEthIndex, ethIndex, assets_, min_dy);
    }

    function afterDeposit(uint256 ethAmount, uint256) internal override {
        stEth.submit{value: ethAmount}(address(this));
        /// Lido's submit() accepts only native ETH
    }

    /// @notice Standard ERC4626 deposit can only accept ERC20
    /// @notice Vault's underlying is WETH (ERC20), Lido expects ETH (Native), we use WETH wrapper
    function deposit(
        uint256 assets_,
        address receiver_
    ) public override returns (uint256 shares) {
        if ((shares = previewDeposit(assets_)) == 0)
            revert ErrorsLib.ZERO_SHARES();

        asset.safeTransferFrom(msg.sender, address(this), assets_);

        weth.withdraw(assets_);

        _mint(receiver_, shares);

        emit Deposit(msg.sender, receiver_, assets_, shares);

        afterDeposit(assets_, shares);
    }

    /// @notice Deposit function accepting ETH (Native) directly
    function deposit(
        address receiver_
    ) public payable returns (uint256 shares) {
        if (msg.value == 0) revert ErrorsLib.ZERO_DEPOSIT();

        if ((shares = previewDeposit(msg.value)) == 0)
            revert ErrorsLib.ZERO_SHARES();

        _mint(receiver_, shares);

        emit Deposit(msg.sender, receiver_, msg.value, shares);

        afterDeposit(msg.value, shares);
    }

    function mint(
        uint256 shares_,
        address receiver_
    ) public override returns (uint256 assets) {
        assets = previewMint(shares_);

        asset.safeTransferFrom(msg.sender, address(this), assets);

        weth.withdraw(assets);

        _mint(receiver_, shares_);

        emit Deposit(msg.sender, receiver_, shares_, assets);

        afterDeposit(assets, shares_);
    }

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

        beforeWithdraw(assets_, shares);

        _burn(owner_, shares);

        emit Withdraw(msg.sender, receiver_, owner_, assets_, shares);

        /// how safe is doing address(this).balance?
        SafeTransferLib.safeTransferETH(receiver_, address(this).balance);
    }

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

        beforeWithdraw(assets, shares_);

        _burn(owner_, shares_);

        emit Withdraw(msg.sender, receiver_, owner_, assets, shares_);

        SafeTransferLib.safeTransferETH(receiver_, address(this).balance);
    }

    function totalAssets() public view virtual override returns (uint256) {
        return stEth.balanceOf(address(this));
    }

    function convertToShares(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        uint256 supply = totalSupply;

        return
            supply == 0 ? assets_ : assets_.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        uint256 supply = totalSupply;

        return
            supply == 0 ? assets_ : assets_.mulDivDown(totalAssets(), supply);
    }

    function previewMint(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        uint256 supply = totalSupply;

        return supply == 0 ? assets_ : assets_.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(
        uint256 assets_
    ) public view virtual override returns (uint256) {
        uint256 supply = totalSupply;

        return supply == 0 ? assets_ : assets_.mulDivUp(supply, totalAssets());
    }

    function setSlippage(uint256 amount_) external {
        if (msg.sender != manager) revert ErrorsLib.INVALID_ACCESS();
        if (amount_ > 10_000 || amount_ < 9000)
            revert ErrorsLib.INVALID_SLIPPAGE();
        slippage = amount_;
    }

    function _getSlippage(uint256 amount_) internal view returns (uint256) {
        return (amount_ * slippage) / slippageFloat;
    }
}
