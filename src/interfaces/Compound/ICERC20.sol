// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IInterestRateModel} from "./IIntersetRateModel.sol";

abstract contract ICERC20 is ERC20 {
    function mint(uint256 underlyingAmount) external virtual returns (uint256);

    function underlying() external view virtual returns (ERC20);

    function getCash() external view virtual returns (uint256);

    function totalBorrows() external view virtual returns (uint256);

    function totalReserves() external view virtual returns (uint256);

    function exchangeRateStored() external view virtual returns (uint256);

    function accrualBlockNumber() external view virtual returns (uint256);

    function redeemUnderlying(
        uint256 underlyingAmount
    ) external virtual returns (uint256);

    function balanceOfUnderlying(address) external virtual returns (uint256);

    function reserveFactorMantissa() external view virtual returns (uint256);

    function interestRateModel()
        external
        view
        virtual
        returns (IInterestRateModel);

    function initialExchangeRateMantissa()
        external
        view
        virtual
        returns (uint256);
}
